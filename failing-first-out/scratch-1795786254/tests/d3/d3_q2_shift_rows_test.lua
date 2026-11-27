-- Design round 3, group Q2: the Shift complete sheet keeps all three helper rows (the tiles got taller for Inter).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local ROOM = tonumber(os.getenv("Q2ROOM") or "") or 444
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

test("d3 q2: the Shift complete sheet with three helpers shows three rows, no '+1 more', and Fair split sits 12 under the tiles", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local D = W.Driver
	local me = W.myKey
	local rows = { { key = me, name = T.ANITA, casts = 7, clicks = 2, share = 18200 },
		{ key = "vex", name = "Vex", casts = 2, clicks = 7, share = 15400 },
		{ key = "nyla", name = "Nyla", casts = 0, clicks = 9, share = 14400 } }
	D.lastShift = { rides = 9, copper = 48000, tips = 3000, open = 7200, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = rows, rule = "clicks", pct = 40 } }
	-- the folded phone: the card may reach 444 units up from the root's bottom edge (the status strip's bottom less 10)
	local sb, root = D.ui.console.statusBox, D.ui.root
	sb.GetBottom = function() return ROOM + 10 end
	root.GetBottom = function() return 0 end
	ok(D.ShowSheet("shift"), "opens")
	w:advance(1)
	local s = W.UI.drive.screens.shift
	local shown = 0
	for _, l in ipairs(s.split.lines) do if l.name:IsShown() then shown = shown + 1 end end
	eq(shown, 3, "three rows")
	ok(not plain(s.split.rule.wuberText):find("more in Earnings", 1, true), "no '+N more': " .. plain(s.split.rule.wuberText))
	-- the heading is 12 under the lowest tile that shows
	local low = 0
	for _, t in ipairs(s.tiles) do
		if t:IsShown() then local _, _, _, _, y = t:GetPoint(1); low = math.max(low, -y + t:GetHeight()) end
	end
	local _, _, _, _, hy = s.split.head:GetPoint(1)
	eq(-hy - low, 12, "Fair split is 12 under the tiles")
	s.frame:Close(true)
	T.clean(w)
end)
