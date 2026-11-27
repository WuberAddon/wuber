-- A failure the bug hunt found (judged by hand, job 2680; F023 of walk-s22, rebuilt as a short repro; NOT part of the normal suite).
-- KNOWN: universal.layout--fold-narrow--phone-trips--saved-acct1_warlock-f023 | universal.layout | fold=narrow,phone=trips,saved=acct1_warlock (after 4 wheel steps down) | A layout problem (emptycue): Trips.lua:342(Tokens.lua) label "Scroll for your trips". | F023
-- Promise: Nothing of Wuber is off the screen, cut off or on top of something else.
-- Run alone from the repo root: lua5.1 tests/hunt/repro/universal.layout--fold-narrow--phone-trips--saved-acct1_warlock-f023.lua  [--verbose] [--addon <Wuber folder>]
-- Exit 1 and the plain line while the bug exists, 0 when it is fixed, 2 when it cannot tell (the hunt itself changed).
local here = ((arg and arg[0]) or ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local lib = here .. "/../lib.lua"
local f = io.open(lib, "rb")
if f then f:close() else lib = "tests/hunt/lib.lua" end
local Hunt = dofile(lib)
os.exit(Hunt.repro({
	found = "walk-s22 (job 2680, by hand)",
	id = "universal.layout--fold-narrow--phone-trips--saved-acct1_warlock-f023",
	match = "A layout problem (emptycue): Trips.lua:#(Tokens.lua) label \"Scroll for your trips\".",
	promise = "universal.layout",
	seed = 5,
	seen = "A layout problem (emptycue): Trips.lua:342(Tokens.lua) label \"Scroll for your trips\".",
	situation = {
		advertOnline = "on",
		autoAccept = "on",
		birdTip = "off",
		button_locked = "off",
		char_starter = "off",
		combat = "after",
		day = "midnight_soon",
		enemies = "near",
		fold = "narrow",
		mapPins = "on",
		minimapHidden = "off",
		myEmblem = "on",
		net = "none",
		opt_acceptUnder = "off",
		opt_adChannels = "services_only",
		opt_adEvery = "fifteen",
		opt_autoAccept = "on",
		opt_autoBlock = "off",
		opt_autoInvite = "on",
		opt_autoPublic = "off",
		opt_autoTrade = "on",
		opt_awayGuard = "off",
		opt_kickAfter = "off",
		opt_raidclick = "off",
		opt_raidsum = "off",
		opt_remindPay = "on",
		opt_shareNotes = "off",
		opt_showPass = "off",
		opt_tellBlocked = "off",
		opt_watchPublic = "off",
		opt_whisperMode = "off",
		phone = "trips",
		pos = "corner",
		ride = "timedout",
		role = "crew",
		saved = "acct1_warlock",
		size = "2662x2089@2.2",
		timeValue = "low",
		tipsOn = "on",
	},
	steps = {
		{ args = { delta = -1, ord = 1 }, id = "scroll" },
		{ args = { secs = 1 }, id = "wait" },
		{ args = { delta = -1, ord = 1 }, id = "scroll" },
		{ args = { secs = 1 }, id = "wait" },
		{ args = { delta = -1, ord = 1 }, id = "scroll" },
		{ args = { secs = 1 }, id = "wait" },
		{ args = { delta = -1, ord = 1 }, id = "scroll" },
		{ args = { secs = 1 }, id = "wait" },
	},
	text = "Nothing of Wuber is off the screen, cut off or on top of something else.",
}))
