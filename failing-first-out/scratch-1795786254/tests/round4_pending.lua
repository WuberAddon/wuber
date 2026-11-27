-- Tests that wait on a fact the fake game cannot give yet. Not in round4.lua: round6 ("r6 engine: paths (#30)")
-- forbids pending tests in the files it lists. Each one keeps its reason; when the fact is known, make it a real test.
-- Loaded by run.lua with the same helpers as round4.lua.
-- (none pending now: scenario 14 after the reload is a real test in tests/round4/r244_s14_after_reload_test.lua)

local T = ...
