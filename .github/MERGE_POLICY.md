# Agile PR acceptance

CI executes merges after tests and a current-head decision. Default: one independent
rapid review. Small reversible changes (at most 3 files/80 changed lines, no protected
paths, deletion, opaque patches or data impact) may use author acceptance. Workflows,
policy/auth/infrastructure and destructive operations need explicit Operator authority.
This script is a generic workflow helper, not an application runtime or data service.

Author body fields: `AOS-Agent`, `AOS-Merge: author`, `AOS-Data-Impact: none`, plus
substantive `AOS-Acceptance`, `AOS-Verification`, `AOS-Rollback`. Use real evidence;
missing author opt-in defaults to review. Classifier is a lower bound; raise the
lane for semantic risks not detected by paths. Prelaunch is not permission to
modify real user data or infrastructure without authorization.

Review budget: one consolidated pass, one repair verification; P2 style/optional
improvements are follow-ups. After two rounds or 24h waiting, route noncritical
choices to Director disposition. No approval by timeout, no invented checks and
no dismissal of material data/security findings. Round/time budgets are role
procedures, not a new watchdog.

Post an unedited PR conversation comment:

```text
<!-- aos:merge-decision:v1 -->
{"head_sha":"CURRENT_40_CHARACTER_SHA","agent":"claude","role":"reviewer","decision":"accept","blockers":[],"evidence":"Actual checks, results and limitations."}
```

A reviewer or Director must be a different logical agent from the author; a new
session is not independence. Protected acceptance uses `agent: human`, `role:
operator`, and a real `authorization_source`, recorded by the write-authorized
repository owner. Existing instructions can be recorded faithfully; agents must
not fabricate approval. Logical identities remain trusted assertions on a shared
GitHub account, not cryptographic identity proofs.

Only concrete P0/P1 blockers with `finding`, `evidence` and `acceptance` veto merging.
P2/incomplete block records are not a veto or an acceptance; resolve material
findings with the original reviewer. Latest unedited decision per logical agent/role
at this head supersedes its previous decision. Old-head decisions cannot approve
new commits. Draft/hold/fork/head checks always apply. Agents do not manually merge.

The privileged merge job runs trusted default-branch gate code, not PR code. The
decision-comment workflow re-runs failed CI jobs at the same head without redoing
passed tests. The first gate installation only bootstraps on the exact trusted
pre-gate base SHA. Missing gate code on any other base fails closed. No new credential,
deployment, paid service or personal-data operation is authorized by this change.
