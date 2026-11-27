-- Comfort and accessibility (job 2903): Escape closes the top sheet first, then the window. One test per sheet kind.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function listClean(a, where)
	for i, n in ipairs(a.env.UISpecialFrames) do
		ok(not tostring(n):find("^WuberSheet%d+$"), where .. ": no sheet name left in the Escape list at " .. i)
	end
	local seen = {}
	for _, n in ipairs(a.env.UISpecialFrames) do seen[n] = true end
	ok(seen.WuberFrame, where .. ": the window is back in the Escape list")
end

local function riderWith(mine)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	c.W.Raincheck.Mine = function() return mine(c) end
	return w, c
end
local function offer(c) return { { id = "rcC1", state = "offered", driver = "Anita Lift", cover = 5000, expires = c.env.time() + 6 * 86400 } } end

test("comfort.escape: the Report a bug sheet closes on the first Escape and leaves the window; the second closes the window", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.Bug.Open()
	w:advance(1)
	ok(UI.Bug.Shown(), "control: Report a bug is open")
	c:pressEscape()
	w:advance(1)
	ok(not UI.Bug.Shown(), "the first Escape closed the report")
	ok(UI.IsShown(), "the window is still up after the first Escape")
	listClean(c, "bug")
	c:pressEscape()
	w:advance(1)
	ok(not UI.IsShown(), "the second Escape closes the window")
	T.clean(w)
end)

test("comfort.escape: the Raincheck offer sheet closes on the first Escape and leaves the window", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and T.H.visible(f), "control: the raincheck offer shows")
	c:pressEscape()
	w:advance(1)
	ok(not (f.open and T.H.visible(f)), "the first Escape closed the offer")
	ok(UI.IsShown(), "the window is still up after the first Escape")
	listClean(c, "raincheck")
	c:pressEscape()
	w:advance(1)
	ok(not UI.IsShown(), "the second Escape closes the window")
	T.clean(w)
end)

test("comfort.escape: every bottom sheet of the Drive tab closes alone on the first Escape", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local D = W.Driver
	local opened = 0
	for _, spec in ipairs({
		{ "sheet" }, { "note", { name = "Quinn" } }, { "gflist" }, { "raidpick" }, { "demand" }, { "shift" },
		{ "menu", { name = "Quinn", key = "quinn" } },
	}) do
		if D.ShowSheet(spec[1], spec[2]) and D.SheetOpen() then
			opened = opened + 1
			w:advance(1)
			a:pressEscape()
			w:advance(1)
			ok(not D.SheetOpen(), spec[1] .. ": the first Escape closed the sheet")
			ok(W.UI.IsShown(), spec[1] .. ": the window is still up")
			listClean(a, spec[1])
		end
	end
	ok(opened >= 4, "control: at least four sheets opened, got " .. opened)
	T.clean(w)
end)

test("comfort.escape: the login tip card closes on the first Escape and leaves the window", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	c.W.Raincheck.Mine = function() return {} end
	UI.Toggle(true)
	w:advance(3)
	local Tips = c.W.Mod("UI.Tips")
	if not Tips.ShowNow() then return T.clean(w) end
	w:advance(1)
	local card = c.env.WuberTipCard
	ok(card and T.H.visible(card), "control: the tip card shows")
	c:pressEscape()
	w:advance(1)
	ok(not T.H.visible(card), "the first Escape closed the tip card")
	ok(UI.IsShown(), "the window is still up")
	listClean(c, "tips")
	T.clean(w)
end)
