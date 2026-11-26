-- Final home: tests/ui/secure_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the contract (UI.SyncSecure and the internals later modules bind) and the exact block lines a rider reads
--   requestBlock: an unknown driver is "gone", an online one may be asked; requestMacro is one plain /w line
--   the Request overlay sits over Confirm's pill with an empty macro; a click whispers by macro, books, and empties it
--   a driver gone between opening Confirm and the click: no whisper, the "gone offline" line
--   the Request overlay goes when Confirm is left; hideOverlays empties every macro out of combat, touches nothing in combat
--   a click in combat (lockdown before the overlay was put away) books without a whisper, once
-- Why it matters to a player: these are the only buttons that may whisper a driver. If they broke, a rider's click
-- would do nothing, whisper the wrong driver or a stale line, book twice, or trip the game's
-- "action blocked" error in a fight.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR
local AKEY = "anita lift"

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Secure", "tests/ui/secure_test.lua", {
		["UI.SyncSecure"] = "function",
		["Mod.BLOCK_TEXT"] = "table",
		["Mod.buildSecure"] = "function",
		["Mod.doCancel"] = "function",
		["Mod.hideOverlays"] = "function",
		["Mod.requestBlock"] = "function",
		["Mod.requestMacro"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Secure\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: the lines a blocked Request click shows", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local B = r.W.Mod("UI.Secure").BLOCK_TEXT
	eq(B.gone, "That driver has gone offline", "gone") -- Secure.lua:52-60
	eq(B.self, "That's you!", "self")
	eq(B.paused, "That driver has paused for now", "paused")
	eq(B.active, "You already have a ride under way", "active")
	eq(B.group, "Leave your group first", "group")
	eq(B.offline, "The network is unavailable", "offline")
	eq(B.here, "You're already there", "here")
	T.clean(w)
end)

-- a driver (Anita, Ratchet) online and a rider (Wuber, Orgrimmar) who has heard her
local function setup()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	return w, r, d, r.W.Mod("UI.Secure")
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: requestBlock: an unknown driver is gone, an online one may be asked; the macro is one plain /w line", function()
	local w, r, _, Mod = setup()
	eq(Mod.requestBlock("nobody here"), "gone", "an unknown driver") -- Secure.lua:42
	local why, d = Mod.requestBlock(AKEY)
	eq(why, nil, "Anita may be asked")
	ok(d and d.key == AKEY, "her record")
	local macro, line = Mod.requestMacro(AKEY, d)
	ok(type(macro) == "string" and macro:match("^/w %S+ .+$"), "a /w line: " .. tostring(macro)) -- checkMacro, Secure.lua:63-72
	ok(not macro:find("[\r\n|]"), "one line, no escape codes")
	ok(#macro <= 255, "fits a macro")
	ok(type(line) == "string" and macro:sub(-#line) == line, "the second value is the whispered line")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: the Request overlay sits over Confirm's pill with no macro; a click whispers by macro, books and empties it", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "the overlay is up over the Request pill")
	eq(b:GetAttribute("macrotext"), "", "no macro until the click itself") -- set only in PreClick, Secure.lua:289-300
	local before = #w:whispersTo(ANITA, "macro")
	T.requestVia(r, AKEY)
	w:advance(1)
	eq(#w:whispersTo(ANITA, "macro") - before, 1, "one whisper by the macro")
	ok(r.W.ride, "a ride is booked")
	eq(b:GetAttribute("macrotext"), "", "emptied after the click") -- PostClick, Secure.lua:271
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: the driver is gone between opening Confirm and the click: no whisper, the gone-offline line", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "setup: the overlay is up")
	local before = #w:whispersTo(ANITA, "macro")
	r.W.drivers[AKEY] = nil -- (no DRIVERS fired: the overlay is still up when the click comes)
	r:click(b)
	w:advance(0.5)
	eq(#w:whispersTo(ANITA, "macro"), before, "no whisper")
	eq(r.W.ride, nil, "no ride")
	ok(#r:findText("That driver has gone offline", false, true) > 0, "the rider is told why") -- Secure.lua:311
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: the Request overlay goes when Confirm is left", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "setup: up")
	r.W.UI.Show("home")
	w:advance(1)
	r.W.UI.SyncSecure()
	ok(not H.visible(b), "gone with the Confirm screen") -- overlayTarget: Secure.lua:152
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: hideOverlays empties every macro and hides every overlay out of combat, and touches nothing in combat", function()
	local w, r, _, Mod = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "setup: up")
	Mod.hideOverlays()
	ok(not H.visible(b), "hidden")
	for _, name in ipairs({ "WuberRequestButton", "WuberCancelButton", "WuberGoButton", "WuberAdvertButton", "WuberShareButton" }) do
		local f = r.env[name]
		ok(f, name .. " exists") -- buildSecure, Secure.lua:283-385
		eq(f:GetAttribute("macrotext"), "", name .. ": no macro")
		ok(not H.visible(f), name .. ": hidden")
	end
	-- in combat (lockdown set with no event, so the overlay is still up): neither call may touch it
	T.openConfirm(r, AKEY)
	ok(H.visible(b), "up again")
	local macro = b:GetAttribute("macrotext")
	r.player.combat = true
	Mod.hideOverlays()
	r.W.UI.SyncSecure()
	ok(H.visible(b), "in combat neither call hides the protected button") -- Secure.lua:223, 235
	eq(b:GetAttribute("macrotext"), macro, "nor changes its macro")
	r.player.combat = false
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.secure: a click in combat books without a whisper, once; a second click books nothing more", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "setup: up")
	local before = #w:whispersTo(ANITA, "macro")
	-- the lockdown came before the overlay was put away (no PLAYER_REGEN_DISABLED yet): Secure.lua:195-199
	r.player.combat = true
	r:click(b)
	-- the toast is up at once (it has gone again by 0.5 s), so look before advancing
	ok(#r:findText("Request sent. No whisper in combat.", false, true) > 0, "the rider is told")
	w:advance(0.5)
	eq(#w:whispersTo(ANITA, "macro"), before, "no whisper in combat")
	ok(r.W.ride, "the request went") -- combatRequest: Secure.lua:216
	-- a second click: the screen went home after the first (Secure.lua:235), so the stale overlay is not over the Request pill any more
	-- and combatRequest refuses it (Secure.lua:222-225); the "ride under way" line is not reachable from here
	local ride = r.W.ride
	r:click(b)
	ok(#r:findText("Can't request in combat", false, true) > 0, "a second click is refused")
	eq(r.W.ride, ride, "the same single ride")
	w:advance(0.5)
	eq(#w:whispersTo(ANITA, "macro"), before, "the second click whispers nothing either")
	T.clean(w)
end)

-- NEEDS FAKE-GAME: a Cancel test needs the ride screen's cancel pill (ui.screens[...].cancel) drawn under
-- WuberCancelButton while the ride is still cancellable; the fixtures for that screen were not checked in this round.
-- test("ui.secure: Cancel whispers the cancel line by macro (never a line with 'summon') and clears the ride", function()
-- 	local w, r = setup()
-- 	T.requestVia(r, AKEY)
-- 	w:advance(1)
-- 	local b = r.env.WuberCancelButton
-- 	ok(H.visible(b), "the cancel overlay")
-- 	r:click(b)
-- 	local last = w:whispersTo(ANITA, "macro")
-- 	ok(last[#last] and not tostring(last[#last].text):lower():find("summon"), "never reads as a request") -- Secure.lua:99
-- 	eq(r.W.ride, nil, "cleared")
-- 	T.clean(w)
-- end)
