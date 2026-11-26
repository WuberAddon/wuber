-- A failure the bug hunt found (written by hand in job 146 from the generated form: the sweep counts this promise as
-- known elsewhere, so it makes no file for it; NOT part of the normal suite).
-- KNOWN: queue.lead_click_invites--opt_autoInvite-off--role-warlock | queue.lead_click_invites | opt_autoInvite=off,role=warlock | You tap a chat buyer's row and they are not invited.
-- Promise: A tap on a grey chat buyer's row invites them.
-- Run alone from the repo root: lua5.1 tests/hunt/repro/queue.lead_click_invites--opt_autoInvite-off--role-warlock.lua  [--verbose] [--addon <Wuber folder>]
-- Exit 1 and the plain line while the bug exists, 0 when it is fixed, 2 when it cannot tell (the hunt itself changed).
local here = ((arg and arg[0]) or ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local lib = here .. "/../lib.lua"
local f = io.open(lib, "rb")
if f then f:close() else lib = "tests/hunt/lib.lua" end
local Hunt = dofile(lib)
os.exit(Hunt.repro({
	found = "--one",
	id = "queue.lead_click_invites--opt_autoInvite-off--role-warlock",
	promise = "queue.lead_click_invites",
	seed = 1,
	seen = "You tap a chat buyer's row and they are not invited.",
	situation = { opt_autoInvite = "off", role = "warlock" },
	text = "A tap on a grey chat buyer's row invites them.",
}))
