local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function setup(w)
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.Heatmap = function()
		return { { wday = 3, hour = 20, copper = 29000, rides = 5, open = 60, asks = 6 },
		         { wday = 4, hour = 9, copper = 1000, rides = 1, open = 60, asks = 0 } }
	end
	W.UI.WindowWide(false)
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	local hm = W.UI.drive.screens.earnings.heat
	local function cell(wd, h) for _, b in ipairs(hm.cells) do if b.wday == wd and b.hour == h then return b end end end
	return a, W, hm, cell
end

test("r47 f: audit C58r-1: tapping a busy square after a short one draws its numbers in tiny type inside a wide pill", function()
	local w = T.newWorld()
	local a, W, hm, cell = setup(w)
	a:click(cell(4, 9)) w:advance(0.5)
	local _, ctl = hm.info:GetFont()
	eq(ctl, 11, "control: a square with a short line is drawn at 11")
	a:click(cell(1, 0)) w:advance(0.5)          -- a quiet square: a narrow pill
	a:click(cell(3, 20)) w:advance(0.5)         -- the busy one: its line is longer than that pill
	local _, size = hm.info:GetFont()
	ok(size >= 11, "the numbers of the busy square are drawn at size " .. tostring(size) .. " (not 11) although the pill is "
		.. tostring(hm.pill:GetWidth()) .. " wide and the same tap from a fresh page fits at 11")
	T.clean(w)
end)
