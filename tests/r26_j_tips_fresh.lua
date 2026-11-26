-- Round 26 group J: the tip card's move to Home happens once, on the first open after login. Settings
-- up on that open, or any later PAGE/RIDE event, never pulls the player off Drive; a splash on the
-- first open still switches once it ends; all tips seen clears the pending flag.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function login(w)
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } }, class = "WARLOCK" })
	w:advance(2)
	return c, c.W, c.W.Mod("UI.Tips")
end

test("r26 J: first open with Settings up, then Drive: a PAGE event does not move to Home", function()
	local w = T.newWorld()
	local _, W, Mod = login(w)
	local ui = W.Mod("UI.Kit").ui
	W.UI.Toggle(true)
	W.UI.OpenSettings()
	w:advance(1.2) -- the first look: Settings is up
	W.UI.CloseSettings(true)
	W.UI.SelectTab("Drive")
	W.Fire("PAGE")
	w:advance(3)
	eq(ui.tab, "Drive", "still on Drive")
	T.clean(w)
end)

test("r26 J: first open with the splash up on Drive: moves to Home once it ends", function()
	local w = T.newWorld()
	local _, W, Mod = login(w)
	local ui = W.Mod("UI.Kit").ui
	W.UI.Toggle(true)
	W.UI.SelectTab("Drive")
	ui.splashing = true
	w:advance(1.2)
	eq(ui.tab, "Drive", "not moved while the splash is up")
	ui.splashing = false
	w:advance(1.5)
	eq(ui.tab, "Ride", "moved to the Ride tab once the splash ended")
	eq(ui.screen, "home", "on Home")
	T.clean(w)
end)

test("r26 J: all tips seen: a look clears tipsPending", function()
	local w = T.newWorld()
	local _, W, Mod = login(w)
	local seen = {}
	for _, t in ipairs(Mod.Eligible()) do seen[t.id] = true end
	W.db.tipsSeen = seen
	W.db.tipsPending = true
	Mod.state.armed = true
	W.UI.Toggle(true)
	w:advance(5)
	eq(W.db.tipsPending, nil, "nothing left: no longer pending")
	T.clean(w)
end)
