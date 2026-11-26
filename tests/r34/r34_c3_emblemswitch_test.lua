-- Round 34 c3: HUNT-73, the chat command moves an open Settings switch at once.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r34 c3: /wuber emblem off|on and mine off|on move the open Settings switches at once (HUNT-73)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.W.PIONEERS = { riders = { ["EU-PvE"] = { T.TESTCHAR } }, drivers = { ["EU-PvE"] = {} } }
	r.W.UI.settings.panel = nil
	r.W.UI.BuildSettings(r.W.UI.state.win)
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.OpenSettings()
	w:advance(1)
	local c = r.W.UI.settings.controls
	-- (Settings diet) "Pioneer emblems over heads" merged into "Badges over heads" (plates; it also writes emblems)
	ok(c.plates and c.myEmblem, "both rows exist")
	eq(c.emblems, nil, "the old emblems row is gone")
	eq(c.myEmblem.on, true)
	r.W.SlashCommand("emblem off")
	eq(r.W.db.emblems, false, "the command saves emblems off")
	r.W.SlashCommand("emblem on")
	eq(r.W.db.emblems, nil, "and back")
	r.W.SlashCommand("emblem mine off")
	eq(c.myEmblem.on, false, "mine switch follows the command")
	r.W.SlashCommand("emblem mine on")
	eq(c.myEmblem.on, true, "and back")
	T.clean(w)
end)
