local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-31: a crew window's "Remove riders after the thanks" follows the captain: a click changes nothing
-- and the row says so; a captain's click still saves.

local function openDriving(w, c)
	c.W.db.coach = true
	c.W.UI.OpenSettings("drive")
	w:advance(1)
	return c.W.UI.settings
end

test("r32 h3: a crew member's Remove-riders switch follows the captain and keeps its value", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	DR.IsCaptain = function() return false end
	local st = openDriving(w, a)
	local t = st.controls["drive.kickAfter"]
	ok(t, "the switch exists")
	DR.opts().kickAfter = true
	a.W.UI.UpdateSettings()
	w:advance(1)
	ok(t.row.desc:GetText():find("Follows your captain", 1, true), "row says it follows the captain: " .. tostring(t.row.desc:GetText()))
	t:Click()
	w:advance(1)
	eq(DR.opts().kickAfter, true, "crew click leaves the value")
	eq(t.on, true, "knob back on")
	T.clean(w)
end)

test("r32 h3: a captain's Remove-riders switch still saves", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	local st = openDriving(w, a)
	local t = st.controls["drive.kickAfter"]
	DR.opts().kickAfter = true
	a.W.UI.UpdateSettings()
	t:Click()
	w:advance(1)
	eq(DR.opts().kickAfter, false, "captain click saves")
	T.clean(w)
end)
