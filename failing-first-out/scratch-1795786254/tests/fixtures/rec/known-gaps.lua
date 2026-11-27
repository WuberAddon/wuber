-- The known gaps between the real game and the fake game (tests/harness.lua), found by the flight
-- recorder's tests (tests/rec/replay_test.lua, tests/rec/conform_test.lua) on fixtures recorded in the
-- real game (tests/fixtures/rec/game-*.lua).
--
-- The rule: a gap is listed ONLY with a reason. Each line is
--     ["<fact id or replay mismatch id>"] = "why the fake game differs and what is planned",
-- A fact id is CF.facts' id (e.g. "taxi.frame.size"); a replay mismatch id is "replay:<field>" (every
-- fixture) or "replay:<fixture file name>:<field>" (one fixture). Removing a line (because the fake
-- now does what the real game does) is the goal; a test fails on any difference not listed here.
return {
}
