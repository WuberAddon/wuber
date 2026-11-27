-- Job 2747 #12: the merged "Badges over heads" switch shows ON only when what it controls
-- (plates and emblems) is all on, in every order of /wuber emblem off|on and switch clicks.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function open()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.W.UI.settings.panel = nil
	r.W.UI.BuildSettings(r.W.UI.state.win)
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.OpenSettings()
	w:advance(1)
	return w, r, r.W.UI.settings.controls.plates
end

test("o2747 #12: Badges over heads shows on only when badges and emblems are both on (every order)", function()
	local w, r, sw = open()
	eq(sw.on, true, "starts on")
	r.W.SlashCommand("emblem off")
	eq(sw.on, false, "emblem off: the switch shows off")
	r.W.SlashCommand("emblem on")
	eq(sw.on, true, "emblem on: back on")
	sw:Click()
	eq(r.W.db.plates, false, "click turns badges off")
	eq(r.W.db.emblems, false, "click turns emblems off")
	eq(sw.on, false)
	r.W.SlashCommand("emblem on")
	eq(sw.on, false, "emblems on but badges still off: the switch stays off")
	r.W.SlashCommand("emblem off")
	eq(sw.on, false)
	sw:Click()
	eq(r.W.db.plates, true, "click turns badges on")
	eq(r.W.db.emblems, true, "click turns emblems on")
	eq(sw.on, true)
	r.W.SlashCommand("emblem off")
	eq(sw.on, false)
	sw:Click()
	eq(sw.on, true, "a click from the half state turns both on")
	eq(r.W.db.emblems ~= false and r.W.db.plates ~= false, true)
	T.clean(w)
end)
