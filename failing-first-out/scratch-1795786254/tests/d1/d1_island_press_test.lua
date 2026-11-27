-- Issue #130: the live ride pill (ph.island, UI/Phone.lua) is a Button with an OnClick but no T.Press, so pressing it makes no
-- click sound and has no pressed look, unlike every other control (Design round 1, group L; see d1_l_press_test.lua).
-- This test fails on today's code (0 clicks) and passes with the one-line fix: T.Press(ph.island) after its OnClick in Phone.lua.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local CLICK = 856

local function clicks(c, from)
	local n = 0
	for i = from + 1, #c.sounds do
		if c.sounds[i] == CLICK then n = n + 1 end
	end
	return n
end

-- Pending: it FAILS on today's code (0 clicks) and PASSES with the one-line fix (T.Press(ph.island) after line 311 of Phone.lua).
T.pending("d1 island press: the live ride pill clicks once for a whole press", "#130: the island has no T.Press (Wuber/UI/Phone.lua); un-pend when fixed", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	local W, UI = r.W, r.W.UI
	W.db.sound = true
	if not r.env.WuberFrame or not r.env.WuberFrame:IsShown() then UI.Toggle(true) w:advance(2.5) end
	-- a ride request out: the island grows into the live pill ("Invited") and takes the mouse
	pcall(W.RequestRide, d.W.myKey)
	w:advance(3)
	local isl = UI.state.phone.island
	ok(isl and isl:IsVisible(), "the island is up")
	ok(isl:IsMouseEnabled(), "and live: it takes the mouse while a ride runs")
	ok(isl.words and isl.words:IsVisible(), "the live pill shows its words")
	eq(r:topAt(isl), isl, "the mouse reaches the island itself")
	local n0 = #r.sounds
	r:clickOn(isl) -- a whole press: mouse down, mouse up, the click script
	w:advance(0.5)
	eq(clicks(r, n0), 1, "one click sound for the whole press of the island")
	T.clean(w)
end)
