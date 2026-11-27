# ROLES.md: who does what

Methods and skills are written by role. Any capable tool or person can play a role; the limits below apply to whoever does. The maintainer picks the work: issues are the work list and nothing is handed from one tool to another. Several contributors and tools may work in this repository at the same time, each on their own branch; GitHub is the only shared place.

## Roles
| Role | What it does |
|---|---|
| Planner / lead | Reads the issue, splits the work into groups (about 10 minutes each), judges real failures, merges after the checks pass, writes the summary |
| Builder | Makes one group's change in its own worktree with its tests; check.lua and its tests green before hand-back |
| Test runner | Runs check.lua, filtered tests, the suite, layout sweeps and greps; reports only the short result; never designs a fix |
| Reviewer | Reads a branch's diff (code, screens, new-player read, security) and lists findings with "not proven" / "to prove it:"; never the one that built the change |
| Live checker | Runs a group's tests the moment it reports |
| Advisor when stuck | Consulted after two failed attempts, or for secure-click/taint and cross-window races |

The test runner and live checker run and report; design, root causes and real code stay with the lead or the builder.

## Limits
- Work happens in your own clone or git worktree, on your own branch (`claude/<n>`, `author/<topic>`), and comes back as a pull request. The checks and the lead judge it.
- A run is small: 1 to 3 issues, then stop and say what is left.
- Nobody waits for another tool, and no tool starts, drives or reads another.
- **Neither tool marks its own homework.** The checks (check.lua, the suite, layout check) decide, and a review is done by someone other than the builder.
- Releases, tags, pushes to main and anything public are the maintainer's.
