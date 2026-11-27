local T = ...
local test, ok, eq, H = T.test, T.ok, T.eq, T.H

local function cardUp(Mod)
	local c = Mod.Card()
	return c and H.visible(c) and c or nil
end

-- a game /reload: PLAYER_ENTERING_WORLD(false, true), as the hunt's ctx:reload does
local function asReload(client)
	local orig = client.fire
	client.fire = function(self, ev, ...)
		if ev == "PLAYER_ENTERING_WORLD" then return orig(self, ev, false, true) end
		return orig(self, ev, ...)
	end
end

-- log in with the coach marks done, spend a minute, then /reload (the saved data kept)
local function reloaded(w)
	local r = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(60)
	if r.alive then r:fire("PLAYER_LOGOUT") end
	local saved = { Wuber = rawget(r.env, "WuberDB") }
	w:closeClient(r, false)
	r.player.online = true
	local r2 = w:addClient(T.TESTCHAR, { saved = saved, prepare = function(_, client) asReload(client) end })
	w:advance(2)
	return r2.W, r2.W.Mod("UI.Tips")
end

local function why(Mod) return tostring(Mod.Why and Mod.Why()) end

-- a fake "Skip the bird" card that the common gate (UI.MayOpen) sees: the tip waits for it, then comes
local function fakeBird(W)
	local up = { v = true }
	local fb = { IsShown = function() return up.v end }
	W.Mod("UI.Bird").Card = function() return fb end
	return up
end

-- Promise: a first open on Trips with the bird card up still gets its tip once the card is gone (the move to Home
-- is kept while the gate is shut). It has no job once the player picks a tab (guard at the end).
local function tripsBirdThenTip(step)
	local w = T.newWorld()
	local W, Mod = reloaded(w)
	local up = fakeBird(W)
	W.UI.Show("trips")
	w:advance(0.3)
	for _ = 1, math.ceil(8 / step) do w:advance(step) end
	ok(not cardUp(Mod), "the tip showed over the bird card")
	up.v = false
	for _ = 1, math.ceil(6 / step) do w:advance(step) end
	ok(cardUp(Mod), "no tip after the bird card went; why: " .. why(Mod))
	T.clean(w)
end

test("r3a tips: first open on Trips while the bird card is up gets the tip when it goes (advance 1 s)", function() tripsBirdThenTip(1) end)
test("r3a tips: first open on Trips while the bird card is up gets the tip when it goes (advance 5 s)", function() tripsBirdThenTip(5) end)

-- guard: no bird card in the way, a first open on Trips already worked on the base
test("r3a tips guard: first open on Trips after login + /reload shows the tip", function()
	local w = T.newWorld()
	local W, Mod = reloaded(w)
	W.UI.Show("trips")
	w:advance(0.3)
	for _ = 1, 8 do w:advance(1) end
	ok(cardUp(Mod), "no tip card; why: " .. why(Mod))
	T.clean(w)
end)

-- guard: opened on Home, the first open still shows one tip
test("r3a tips guard: first open on Home after login + /reload still shows one tip", function()
	local w = T.newWorld()
	local W, Mod = reloaded(w)
	W.UI.Toggle(true)
	w:advance(10)
	ok(cardUp(Mod), "no tip card on Home; why: " .. why(Mod))
	T.clean(w)
end)

-- guard: opened directly on Drive (/wuber drive) the tip waits for the next open
test("r3a tips guard: opened directly on Drive the first open shows no tip, the next open does", function()
	local w = T.newWorld()
	local W, Mod = reloaded(w)
	W.UI.Show("drive")
	w:advance(10)
	ok(not cardUp(Mod), "a tip showed over a Drive open")
	W.UI.Toggle(false) w:advance(1)
	W.UI.Toggle(true) w:advance(10)
	ok(cardUp(Mod), "the next open shows the tip; why: " .. why(Mod))
	T.clean(w)
end)

-- guard: the same wait on Home (always worked)
test("r3a tips guard: first open on Home while the bird card is up gets the tip when it goes", function()
	local w = T.newWorld()
	local W, Mod = reloaded(w)
	local up = fakeBird(W)
	W.UI.Toggle(true)
	w:advance(8)
	ok(not cardUp(Mod), "the tip showed over the bird card")
	up.v = false
	w:advance(4)
	ok(cardUp(Mod), "no tip after the bird card went; why: " .. why(Mod))
	T.clean(w)
end)

-- guard: a tab the player picks while the gate is shut is kept (no jump back to Home)
test("r3a tips guard: a tab picked while the bird card is up is not moved to Home afterwards", function()
	local w = T.newWorld()
	local W = reloaded(w)
	local up = fakeBird(W)
	W.UI.Show("trips")
	w:advance(3)
	local K = W.Mod("UI.Kit")
	for _, tab in ipairs(K.ui.tabs) do
		if tab.name == "Trips" and tab.button and tab.button.Click then tab.button:Click() end
	end
	w:advance(1)
	up.v = false
	w:advance(5)
	eq(K.ui.tab, "Trips", "the player's tab stays")
	T.clean(w)
end)
