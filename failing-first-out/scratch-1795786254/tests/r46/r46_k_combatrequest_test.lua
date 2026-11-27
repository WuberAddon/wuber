-- Round 46 k (HUNT-34): the Request button in a fight. In combat the card's Request pill reads
-- "Request summon · 50s (in combat: no whisper)" and its tooltip "Sends your request now...". A card opened during the
-- fight has no secure overlay over it, so the pill itself books (R goes, no whisper). A card that was already open when
-- the fight began keeps the secure overlay over the pill (it cannot be hidden or moved in combat) with an empty macro:
-- its click only said "Can't request in combat" and sent nothing. Now that click books too, with the same toast, once
-- per click, and only while the card under it is really the open Request card for a driver who is still there.
-- The fake game fires PLAYER_REGEN_DISABLED before the lockdown (as the game does), and UI.Window puts the overlays
-- away then; an overlay still over the pill in a fight is modelled by the lockdown already being on when that event
-- comes (fightLocked below).
local T = ...
local H, test, ok, eq = T.H, T.test, T.ok, T.eq
local DRIVER = "anita lift"

-- the rider's card for Anita is open (and the overlay over its pill) before the fight; then the fight starts
-- the lockdown is already on when PLAYER_REGEN_DISABLED reaches the addon: the overlay can't be put away
local function fightLocked(w, r)
	r.player.combat = true
	r:fire("PLAYER_REGEN_DISABLED")
end

local function openThenFight(plain)
	local w = T.newWorld()
	local d = T.driver(w)
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	T.openConfirm(r, DRIVER)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "control: the secure Request button is over its pill before the fight")
	local said = {}
	local UI = r.W.UI
	local toast = UI.Toast
	UI.Toast = function(text, ...) said[#said + 1] = tostring(text) return toast(text, ...) end
	if plain then w:enterCombat(r) else fightLocked(w, r) end
	w:advance(1)
	return w, d, r, b, said
end

local function has(said, text)
	for _, t in ipairs(said) do if t == text then return true end end
	return false
end

test("r46 k: card open when the fight began - a click on Request sends the request, once, with no whisper", function()
	local w, d, r, b, said = openThenFight()
	local v0 = #w.violations
	local hits = r:findText("(in combat: no whisper)", nil, true)
	ok(#hits > 0, "the pill says in combat: no whisper (" .. T.list(r:visibleTexts()) .. ")")
	ok(H.visible(b), "the overlay is still over the pill in combat (it cannot be hidden)")
	local hit = hits[1] and r:clickOn(hits[1]) or r:click(b)
	ok(T.S[hit].secure, "the click lands on the secure overlay")
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 1, "the request (R) is sent in combat")
	eq(#T.whispersTo(w, T.ANITA, "macro"), 0, "no whisper in combat")
	ok(has(said, "Request sent. No whisper in combat."), "the toast says the request went (" .. table.concat(said, " | ") .. ")")
	ok(not has(said, "Can't request in combat"), "no 'Can't request in combat' toast")
	ok(({ requesting = 1, accepted = 1, invited = 1, ingroup = 1 })[T.rideState(r) or ""], "the ride is on: " .. tostring(T.rideState(r)))
	eq(#w.violations, v0, "nothing protected was touched")
	-- a second click on the overlay at once, and again a moment later, sends nothing more
	if H.visible(b) then r:click(b) end
	eq(#T.msgs(w, "R", T.TESTCHAR), 1, "one request only, after a quick second click")
	if H.visible(b) then r:click(b) end
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 1, "one request only, after a second click")
	w:leaveCombat(r)
	w:advance(2)
	eq(#T.whispersTo(w, T.ANITA, "macro"), 0, "no whisper sent later by itself")
	eq(#T.msgs(w, "R", T.TESTCHAR), 1, "still one request after the fight")
	T.clean(w)
end)

test("r46 k: card open when the fight began - the overlay left over a closed window sends nothing", function()
	local w, d, r, b, said = openThenFight()
	r.W.UI.Toggle()
	w:advance(1)
	ok(not (r.W.UI.state.win and r.W.UI.state.win:IsShown()), "the window is closed")
	if H.visible(b) then
		r:click(b)
		w:advance(1)
		ok(has(said, "Can't request in combat"), "the old toast for a click on nothing (" .. table.concat(said, " | ") .. ")")
	end
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "no request from an overlay over a closed window")
	eq(T.rideState(r), nil, "no ride")
	T.clean(w)
end)

test("r46 k: card open when the fight began - a driver gone in the fight gets no request", function()
	local w, d, r, b, said = openThenFight()
	r.W.drivers[DRIVER] = nil
	ok(H.visible(b), "the overlay is still there")
	r:click(b)
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "no request to a driver who has gone")
	ok(has(said, "That driver has gone offline"), "the toast says why (" .. table.concat(said, " | ") .. ")")
	T.clean(w)
end)

test("r46 k: control - a fight that starts normally puts the overlay away and the pill itself books", function()
	local w, d, r, b, said = openThenFight(true)
	ok(not H.visible(b), "the overlay was put away as the fight began")
	local hits = r:findText("(in combat: no whisper)", nil, true)
	ok(#hits > 0, "the pill says in combat: no whisper")
	local hit = hits[1] and r:clickOn(hits[1])
	ok(hit and not T.S[hit].secure, "the click lands on the ordinary pill")
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 1, "the request (R) is sent in combat")
	eq(#T.whispersTo(w, T.ANITA, "macro"), 0, "no whisper in combat")
	ok(has(said, "Request sent. No whisper in combat."), "the same toast (" .. table.concat(said, " | ") .. ")")
	T.clean(w)
end)
