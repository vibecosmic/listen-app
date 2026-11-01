"""Standalone PR decision gate. Generic workflow utility; no project/runtime code."""

import json
import os
import re
import subprocess
import sys
from pathlib import PurePosixPath
from typing import Any

MARKER = "<!-- aos:merge-decision:v1 -->\n"
AGENTS = {"codex", "claude", "human", "antigravity", "copilot"}
PROTECTED = (
    ".github/",
    ".aos/",
    "aos/",
    "migrations/",
    "infra/",
    "terraform/",
    "deploy/",
    "scripts/merge_gate.py",
    "tests/test_merge_gate.py",
    "AGENTS.md",
    "docs/GOVERNANCE.md",
    "docs/MERGE_POLICY.md",
    "docs/prompts/",
    "docs/CONTINUOUS_OPERATIONS.md",
    "docs/decisions/",
    "docs/templates/",
)
SENSITIVE = re.compile(
    r"(^|[/_.-])(auth|oidc|secret|credential|payment|billing|migration|token)([/_.-]|$)", re.I
)
DESTRUCTIVE = re.compile(
    r"\b(DROP\s+(TABLE|DATABASE)|TRUNCATE\s+|DELETE\s+FROM|shutil\.rmtree|os\.remove|rm\s+-rf)\b",
    re.I,
)


def field(body: str, name: str) -> str:
    values = re.findall(r"^" + re.escape(name) + r":\s*(.+?)\s*$", body, re.M)
    if len(values) > 1:
        raise ValueError("duplicate " + name)
    return values[0].strip() if values else ""


def classify(files: list[dict[str, Any]], requested: str) -> str:
    if not files:
        raise ValueError("empty or incomplete changed-file list")
    lane = "author"
    lines = 0
    for item in files:
        for path in (item["filename"], item.get("previous_filename", item["filename"])):
            if path.startswith("/") or ".." in PurePosixPath(path).parts:
                raise ValueError("invalid changed path")
            if any(path == p or path.startswith(p) for p in PROTECTED) or (
                not path.endswith((".md", ".rst", ".txt")) and SENSITIVE.search(path)
            ):
                lane = "protected"
        # Deletions and opaque patches require independent review at minimum.
        patch = item.get("patch")
        if item.get("status") in {"removed", "renamed"} or not isinstance(patch, str):
            if lane != "protected":
                lane = "review"
        elif DESTRUCTIVE.search(
            "\n".join(line[1:] for line in patch.splitlines() if line.startswith("+"))
        ):
            lane = "protected"
        lines += item.get("additions", 0) + item.get("deletions", 0)
    if lane == "author" and (len(files) > 3 or lines > 80):
        lane = "review"
    if requested not in {"", "author", "review", "protected"}:
        raise ValueError("unknown AOS-Merge lane")
    order = {"author": 0, "review": 1, "protected": 2}
    # Missing explicit author opt-in defaults to review, not silent self-approval.
    declared = requested or "review"
    return max((lane, declared), key=order.__getitem__)


def evaluate(
    pr: dict[str, Any],
    files: list[dict[str, Any]],
    comments: list[dict[str, Any]],
    writable: set[str],
    repository: str,
    expected_sha: str,
) -> dict[str, str]:
    if (
        pr.get("state") != "open"
        or pr.get("draft")
        or pr["head"]["repo"]["full_name"] != repository
        or pr["base"]["repo"]["full_name"] != repository
        or pr["head"]["sha"] != expected_sha
    ):
        raise ValueError("PR is closed, draft, forked or head moved")
    if {label["name"] for label in pr.get("labels", [])} & {"aos:hold", "aos:no-automerge"}:
        raise ValueError("PR is held")
    if pr["user"]["login"] not in writable:
        raise ValueError("author lacks repository write permission")
    body = pr.get("body") or ""
    author = field(body, "AOS-Agent")
    lane = classify(files, field(body, "AOS-Merge"))
    latest: dict[tuple[str, str], dict[str, Any]] = {}
    owner = repository.split("/")[0]
    for comment in sorted(comments, key=lambda c: c["id"]):
        if comment["user"]["login"] not in writable or not (comment.get("body") or "").startswith(
            MARKER
        ):
            continue
        try:
            decision = json.loads(comment["body"][len(MARKER) :])
        except (ValueError, TypeError) as exc:
            raise ValueError(
                "malformed trusted merge decision; post a valid record or remove it"
            ) from exc
        if not isinstance(decision, dict):
            raise ValueError("merge decision must be an object")
        if decision.get("head_sha") != expected_sha:
            continue
        agent, role = decision.get("agent"), decision.get("role")
        if agent not in AGENTS or role not in {"reviewer", "director", "operator"}:
            raise ValueError("invalid decision role/agent")
        decision = {
            **decision,
            "actor": comment["user"]["login"],
            "edited": comment.get("created_at") != comment.get("updated_at"),
        }
        latest[agent, role] = decision
    accepted = []
    for (agent, role), decision in latest.items():
        # Another job with the same logical agent is not an independent reviewer.
        if role != "operator" and (not author or agent == author):
            continue
        if role == "operator" and (agent != "human" or decision["actor"] != owner):
            continue
        if decision["edited"]:
            raise ValueError("edited decision is invalid; post a new decision")
        if (
            decision.get("decision") not in {"accept", "block"}
            or not str(decision.get("evidence", "")).strip()
        ):
            raise ValueError("decision needs outcome and evidence")
        blockers = decision.get("blockers")
        if not isinstance(blockers, list):
            raise ValueError("decision requires blockers list")
        material = [
            blocker
            for blocker in blockers
            if isinstance(blocker, dict)
            and blocker.get("severity") in {"P0", "P1"}
            and all(
                str(blocker.get(key, "")).strip() for key in ("finding", "evidence", "acceptance")
            )
        ]
        if material:
            raise ValueError(
                "unresolved material blocker; repair or obtain a new decision from its reviewer"
            )
        # Style/aspirational/incomplete findings are follow-ups, not a veto.
        # A block record without a material finding is not an acceptance either.
        if decision["decision"] == "block":
            continue
        if role == "operator" and not str(decision.get("authorization_source", "")).strip():
            raise ValueError("operator decision requires explicit authorization source")
        accepted.append(role)
    if lane == "protected":
        if "operator" not in accepted:
            raise ValueError("protected change requires explicit Operator acceptance of this SHA")
    elif lane == "review":
        if not ({"reviewer", "director", "operator"} & set(accepted)):
            raise ValueError("waiting for one independent rapid review or Director disposition")
    else:
        if author not in AGENTS or field(body, "AOS-Data-Impact") != "none":
            raise ValueError("author lane requires known author agent and explicit no-data-impact")
        for name in ("AOS-Acceptance", "AOS-Verification", "AOS-Rollback"):
            if len(field(body, name)) < 8:
                raise ValueError("author lane requires substantive " + name)
    return {"lane": lane, "head_sha": expected_sha, "decision": "merge-eligible"}


def query(path: str) -> Any:
    result = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    if result.returncode:
        raise ValueError("GitHub metadata query failed; no merge")
    return json.loads(result.stdout)


def pages(path: str) -> list[dict[str, Any]]:
    items = []
    separator = "&" if "?" in path else "?"
    for page in range(1, 101):
        data = query(f"{path}{separator}per_page=100&page={page}")
        if not isinstance(data, list):
            raise ValueError("invalid GitHub list")
        items.extend(data)
        if len(data) < 100:
            return items
    raise ValueError("pagination limit; refuse incomplete evidence")


def main() -> int:
    try:
        repo, number, sha = os.environ["REPO"], int(os.environ["PR"]), os.environ["SHA"]
        if (
            not re.fullmatch(r"[\w.-]+/[\w.-]+", repo)
            or not re.fullmatch(r"[a-f0-9]{40}", sha)
            or number < 1
        ):
            raise ValueError("invalid merge request")
        prefix = f"repos/{repo}"
        pr = query(f"{prefix}/pulls/{number}")
        comments = pages(f"{prefix}/issues/{number}/comments")
        files = pages(f"{prefix}/pulls/{number}/files")
        if len(files) != pr.get("changed_files"):
            raise ValueError("incomplete changed-file evidence")
        actors = {pr["user"]["login"]} | {
            c["user"]["login"] for c in comments if (c.get("body") or "").startswith(MARKER)
        }
        writable = {
            actor
            for actor in actors
            if query(f"{prefix}/collaborators/{actor}/permission").get("permission")
            in {"write", "maintain", "admin"}
        }
        print(json.dumps(evaluate(pr, files, comments, writable, repo, sha)))
        return 0
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(f"Merge gate: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
