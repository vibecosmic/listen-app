import copy
import json
import runpy
import unittest

GATE = runpy.run_path("scripts/merge_gate.py")


class MergeGateTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.repo = "owner/project"
        self.pr = {
            "state": "open",
            "draft": False,
            "labels": [],
            "head": {"sha": self.sha, "repo": {"full_name": self.repo}},
            "base": {"repo": {"full_name": self.repo}},
            "user": {"login": "owner"},
            "body": "AOS-Agent: codex\nAOS-Merge: author\nAOS-Data-Impact: none\n"
            "AOS-Acceptance: Small isolated fix verified.\n"
            "AOS-Verification: Targeted regression passed.\n"
            "AOS-Rollback: Revert this commit safely.\n",
        }
        self.files = [
            {
                "filename": "src/view.py",
                "status": "modified",
                "additions": 4,
                "deletions": 2,
                "patch": "+return value",
            }
        ]

    def decision(
        self,
        *,
        agent="claude",
        role="reviewer",
        outcome="accept",
        sha=None,
        blockers=None,
        actor="owner",
        number=1,
    ):
        record = {
            "head_sha": sha or self.sha,
            "agent": agent,
            "role": role,
            "decision": outcome,
            "evidence": "Checked the current diff and regression.",
            "blockers": blockers or [],
        }
        if role == "operator":
            record["authorization_source"] = "Explicit Operator instruction in linked session."
        return {
            "id": number,
            "user": {"login": actor},
            "created_at": "t",
            "updated_at": "t",
            "body": GATE["MARKER"] + json.dumps(record),
        }

    def evaluate(self, comments=None, writable=None):
        return GATE["evaluate"](
            self.pr, self.files, comments or [], writable or {"owner"}, self.repo, self.sha
        )

    def test_small_reversible_author_change_needs_no_reviewer(self):
        self.assertEqual(self.evaluate()["lane"], "author")

    def test_author_lane_requires_acceptance_verification_rollback_and_data_assertion(self):
        body = self.pr["body"]
        for key in (
            "AOS-Agent",
            "AOS-Acceptance",
            "AOS-Verification",
            "AOS-Rollback",
            "AOS-Data-Impact",
        ):
            self.pr["body"] = "\n".join(
                line for line in body.splitlines() if not line.startswith(key + ":")
            )
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.evaluate()
        self.pr["body"] = body.replace("AOS-Data-Impact: none", "AOS-Data-Impact: user-data")
        with self.assertRaises(ValueError):
            self.evaluate()

    def test_missing_opt_in_defaults_to_rapid_review(self):
        self.pr["body"] = "AOS-Agent: codex"
        with self.assertRaisesRegex(ValueError, "rapid review"):
            self.evaluate()
        self.assertEqual(self.evaluate([self.decision()])["lane"], "review")

    def test_size_or_opaque_patch_cannot_be_downgraded_by_author(self):
        for change in ({"additions": 81}, {"patch": None}, {"status": "removed"}):
            original = copy.deepcopy(self.files)
            self.files[0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.evaluate()
            self.assertEqual(self.evaluate([self.decision()])["lane"], "review")
            self.files = original

    def test_workflows_permissions_data_operations_and_renames_are_protected(self):
        for path in (
            ".github/workflows/ci.yml",
            ".aos/admission.json",
            "aos/runtime.py",
            "migrations/001.sql",
            "src/auth/login.py",
            "scripts/merge_gate.py",
        ):
            self.files[0]["filename"] = path
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Operator"):
                self.evaluate([self.decision()])
        self.files[0].update(
            filename="src/view.py", previous_filename="aos/policy.py", status="renamed"
        )
        with self.assertRaisesRegex(ValueError, "Operator"):
            self.evaluate([self.decision()])
        del self.files[0]["previous_filename"]
        self.files[0].update(status="modified", patch="+db.execute('DELETE FROM users')")
        with self.assertRaisesRegex(ValueError, "Operator"):
            self.evaluate()

    def test_explicit_operator_acceptance_is_scoped_to_current_sha(self):
        self.files[0]["filename"] = ".github/workflows/ci.yml"
        with self.assertRaises(ValueError):
            self.evaluate([self.decision(agent="human", role="operator", sha="b" * 40)])
        accepted = self.decision(agent="human", role="operator")
        self.assertEqual(self.evaluate([accepted])["lane"], "protected")
        accepted["user"]["login"] = "other"
        with self.assertRaises(ValueError):
            self.evaluate([accepted], {"owner", "other"})

    def test_self_review_and_untrusted_comment_cannot_release_review_lane(self):
        self.pr["body"] = "AOS-Agent: codex\nAOS-Merge: review"
        for comment in (self.decision(agent="codex"), self.decision(actor="outsider")):
            with self.assertRaises(ValueError):
                self.evaluate([comment])

    def test_new_head_invalidates_old_review(self):
        self.pr["body"] = "AOS-Agent: codex\nAOS-Merge: review"
        with self.assertRaises(ValueError):
            self.evaluate([self.decision(sha="b" * 40)])

    def test_real_blocker_prevents_even_author_lane_until_same_reviewer_resolves(self):
        blockers = [
            {
                "severity": "P1",
                "finding": "Recording is lost on repeated stop.",
                "evidence": "A reproducible failing test.",
                "acceptance": "Add and pass the regression.",
            }
        ]
        blocked = self.decision(outcome="block", blockers=blockers)
        with self.assertRaisesRegex(ValueError, "material blocker"):
            self.evaluate([blocked])
        with self.assertRaises(ValueError):
            self.evaluate([blocked, self.decision(agent="human", role="operator", number=2)])
        self.assertEqual(
            self.evaluate([blocked, self.decision(number=3)])["decision"], "merge-eligible"
        )

    def test_style_nits_are_followups_and_director_can_dispose_ordinary_review(self):
        self.pr["body"] = "AOS-Agent: codex\nAOS-Merge: review"
        comment = self.decision(role="director")
        self.assertEqual(self.evaluate([comment])["lane"], "review")
        bad = [
            {
                "severity": "P2",
                "finding": "Prefer a different name.",
                "evidence": "Style preference",
                "acceptance": "Rename it",
            }
        ]
        with self.assertRaisesRegex(ValueError, "rapid review"):
            self.evaluate([self.decision(outcome="block", blockers=bad)])
        self.assertEqual(
            self.evaluate(
                [
                    self.decision(outcome="block", blockers=bad),
                    self.decision(agent="human", role="director", number=2),
                ]
            )["lane"],
            "review",
        )

    def test_unsubstantiated_block_cannot_veto_author_fast_lane(self):
        self.assertEqual(self.evaluate([self.decision(outcome="block")])["lane"], "author")
        nits = [
            {"severity": "P2", "finding": "Style", "evidence": "Preference", "acceptance": "Rename"}
        ]
        self.assertEqual(
            self.evaluate([self.decision(outcome="block", blockers=nits)])["lane"], "author"
        )

    def test_live_draft_hold_fork_and_head_movement_prevent_merge(self):
        original = copy.deepcopy(self.pr)
        for change in ("draft", "hold", "fork", "head", "closed"):
            self.pr = copy.deepcopy(original)
            if change == "draft":
                self.pr["draft"] = True
            elif change == "hold":
                self.pr["labels"] = [{"name": "aos:hold"}]
            elif change == "fork":
                self.pr["head"]["repo"]["full_name"] = "other/project"
            elif change == "head":
                self.pr["head"]["sha"] = "b" * 40
            else:
                self.pr["state"] = "closed"
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.evaluate()

    def test_edited_approval_and_duplicate_author_metadata_are_rejected(self):
        self.pr["body"] = "AOS-Agent: codex\nAOS-Merge: review"
        comment = self.decision()
        comment["updated_at"] = "later"
        with self.assertRaises(ValueError):
            self.evaluate([comment])
        self.pr["body"] += "\nAOS-Agent: claude"
        with self.assertRaises(ValueError):
            self.evaluate()


if __name__ == "__main__":
    unittest.main()
