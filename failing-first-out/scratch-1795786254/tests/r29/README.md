# tests/r29: round 29's tests (the 2.3.4 line)

Every `*_test.lua` here is loaded by tests/run.lua in name order, after tests/r27 (no line to add there).
One file per round group, named `r29_<group>_<topic>_test.lua`. Each starts with `local T = ...`; the helpers
are the ones tests/r27/README.md lists.
