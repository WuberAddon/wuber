-- Final home: tests/ui/driver/console_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: D.ShowScreen pushes a page / "console" pops it; unknown or broken screens are refused and reported (W.Error), not raised.
-- Pins: D.CurrentScreen, D.Slot (no slot for the big button while a page or sheet is over the console), D.PageOver, D.SheetOpen.
-- Pins: D.ShowSheet opens one sheet at a time; PAGE fires on open and close; the Messages page marks messages seen.
-- Pins: D.Refresh / D.RefreshNow / the OnUpdate throttle (a quarter second when dirty, a second when quiet), the roster event dirties it.
-- Pins: in combat D.SyncDock leaves the big button alone, ShowScreen swaps at once, and the dock is laid again after the fight.
-- Pins: the crew chip (You / short name / "no Wuber" / shards / whose turn), D.LaySideChips rows and reuse, the unfolded side pane's takings and summons average, D.WideLayout, D.Build, D.Toggle.
-- Why it matters to a player: the driver's console is the one screen they live in. If a page push, a sheet or the dock broke, the big
-- GO button would sit on top of a page, a price sheet could never be closed, the console would not redraw after a ride was paid, or the
-- crew list would show the wrong name or shard count.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- a Warlock driver with the Drive tab open on the console (folded, or unfolded with opts.wide), as tests/ui/driver/* do
local function open(opts)
	opts = opts or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if opts.wide then
		a.wide = true -- the harness keeps old tests folded unless they opt in
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, W.Driver
end

local SHIFT = { rides = 3, copper = 15000, tips = 0, open = 3600, crewRides = 0, crewCopper = 0, at = 1 } -- the shift card's data (sheets_test.lua)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: contract (registered, deps = header Uses, public names)", function()
	local W, w, r, Mod = T.contract("UI.Driver.Console", "tests/ui/driver/console_test.lua", {
		["D.ShowScreen"] = "function", ["D.CurrentScreen"] = "function", ["D.ShowSheet"] = "function", ["D.SheetOpen"] = "function",
		["D.PageOver"] = "function", ["D.Slot"] = "function", ["D.SyncDock"] = "function", ["D.Refresh"] = "function",
		["D.RefreshNow"] = "function", ["D.Build"] = "function", ["D.Toggle"] = "function", ["D.SideChip"] = "function",
		["D.PaintSideChip"] = "function", ["D.LaySideChips"] = "function", ["D.SidePane"] = "function",
		["D.WideLayout"] = "function", ["D.FOLD"] = "table", ["D.screens"] = "table",
	})
	ok(type(W.Driver.FOLD.console) == "table" and type(W.Driver.FOLD.console.build) == "function"
		and type(W.Driver.FOLD.console.layout) == "function", "the console registers its side pane with UI.Fold (Console.lua D.FOLD.console)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: ShowScreen pushes a page over the console, 'console' pops it, and the big button's slot waits", function()
	local w, a, W, D = open()
	local ui = D.ui
	ok(ui.console:IsShown(), "control: a set-up Warlock sees the console")
	eq(D.CurrentScreen(), "console", "starts on the console")
	ok(D.Slot() ~= nil, "control: the console on screen has a slot for the big button")
	local pages = 0
	W.Listen("PAGE", function() pages = pages + 1 end)
	eq(D.ShowScreen("crew"), true, "the crew page opens")
	eq(D.CurrentScreen(), "crew", "now on the crew page")
	eq(D.Slot(), nil, "no slot while a page is over the console") -- Console.lua:203 (D.sub)
	ok(pages >= 1, "PAGE fired so UI.Fold re-reads the page") -- Console.lua:45 pageChanged
	eq(D.PageOver("crew"), false, "a page is not over itself") -- Console.lua:181
	eq(D.PageOver("earnings"), true, "but it is over every other page's list")
	eq(D.PageOver(nil), true, "and over the console")
	w:advance(1)
	ok(ui.subs.crew.frame:IsShown(), "the page is on screen once it arrived")
	eq(D.Slot(), nil, "still no slot")
	local n = pages
	eq(D.ShowScreen("console"), true, "back")
	ok(pages > n, "PAGE fired again on the way back")
	eq(D.CurrentScreen(), "console", "on the console again")
	w:advance(1)
	ok(not ui.subs.crew.frame:IsShown(), "the page is gone")
	ok(ui.console:IsShown(), "the console is back")
	ok(D.Slot() ~= nil, "the slot is back for the big button")
	eq(D.PageOver("crew"), false, "nothing is over any page now")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: showing the same page twice does not push it again; a second page replaces the first", function()
	local w, a, W, D = open()
	local ui = D.ui
	D.ShowScreen("crew") w:advance(1)
	eq(D.pageMoving, nil, "the first push is over")
	eq(D.ShowScreen("crew"), true, "asking for the page already shown")
	eq(D.pageMoving, nil, "no second travel") -- Console.lua:~127 (was == name and shown: just Show)
	ok(ui.subs.crew.frame:IsShown(), "it stays")
	eq(D.ShowScreen("earnings"), true, "another page")
	eq(D.CurrentScreen(), "earnings", "now on it")
	w:advance(1.5)
	ok(ui.subs.earnings.frame:IsShown(), "the new page is shown")
	ok(not ui.subs.crew.frame:IsShown(), "the old page is hidden, only one page at a time")
	D.ShowScreen("console") w:advance(1.5)
	ok(not ui.subs.earnings.frame:IsShown() and ui.console:IsShown(), "'console' goes back to the console, not to the page before")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: an unknown screen is refused; a page or sheet whose maker fails is reported and leaves the console alone", function()
	local w, a, W, D = open()
	eq(D.ShowScreen("nope"), false, "no such page") -- Console.lua:107
	eq(D.CurrentScreen(), "console", "still on the console")
	eq(D.ShowSheet("nope"), false, "no such sheet") -- Console.lua:144
	eq(D.ShowScreen(nil), true, "no name means the console") -- Console.lua:91 (S(name) or "console")
	D.screens.zzbad = function() return {} end -- a table without a frame
	eq(D.ShowScreen("zzbad"), false, "a maker that returns no frame is refused")
	eq(W.lastError, "drive screen zzbad: no frame", "and reported by name") -- Console.lua:112
	W.lastError = nil
	eq(D.ui.subs.zzbad, nil, "nothing is kept of it")
	eq(D.CurrentScreen(), "console", "the console stays")
	D.screens.zzboom = function() error("boom") end
	eq(D.ShowScreen("zzboom"), false, "a maker that raises is refused")
	ok(tostring(W.lastError):find("drive screen zzboom: ", 1, true) and tostring(W.lastError):find("boom", 1, true), "the error names the page and says why: " .. tostring(W.lastError))
	W.lastError = nil
	D.screens.zzsheet = function() return {} end
	eq(D.ShowSheet("zzsheet"), false, "a sheet maker with no frame is refused")
	eq(W.lastError, "drive sheet zzsheet: no frame", "and reported by name") -- Console.lua:149
	W.lastError = nil
	eq(D.SheetOpen(), false, "no sheet is open")
	D.screens.zzbad, D.screens.zzboom, D.screens.zzsheet = nil, nil, nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: opening the Messages page marks messages seen (the footer glow stops)", function()
	local w, a, W, D = open()
	W.db.msgSeen = nil
	D.ShowScreen("messages")
	eq(W.db.msgSeen, true, "msgSeen is saved") -- Console.lua:92
	D.ShowScreen("console") w:advance(1)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: a sheet over the console: SheetOpen, no slot for the big button, PageOver, PAGE on open and close", function()
	local w, a, W, D = open()
	D.lastShift = SHIFT
	local pages = 0
	W.Listen("PAGE", function() pages = pages + 1 end)
	eq(D.SheetOpen(), false, "no sheet yet")
	eq(D.PageOver("crew"), false, "nothing over a page yet")
	ok(D.Slot() ~= nil, "control: the slot")
	eq(D.ShowSheet("shift"), true, "the shift card opens")
	w:advance(1)
	eq(D.SheetOpen(), true, "a sheet is open")
	eq(D.Slot(), nil, "the big button leaves its slot while the sheet is over it") -- Console.lua:203,206 (D.Slot)
	eq(D.PageOver("crew"), true, "an open sheet is over every page") -- Console.lua:181-185 (D.PageOver, D.SheetOpen)
	ok(pages >= 1, "PAGE fired on open")
	local n = pages
	D.ui.sheets.shift.frame:Close(true)
	w:advance(1)
	eq(D.SheetOpen(), false, "closed")
	ok(pages > n, "PAGE fired on close (the sheet's onClose hook)") -- Console.lua:156-160
	ok(D.Slot() ~= nil, "the slot is back")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: ShowScreen('sheet') is ShowSheet; opening a second sheet closes the first (one at a time)", function()
	local w, a, W, D = open()
	D.lastShift = SHIFT
	eq(D.ShowScreen("sheet"), true, "the price sheet opens through ShowScreen") -- Console.lua:93
	w:advance(1)
	local price = D.ui.sheets.sheet
	ok(price and price.frame.open, "the price sheet is open")
	eq(D.CurrentScreen(), "console", "a sheet is not a page")
	eq(D.ShowSheet("shift"), true, "the shift card")
	w:advance(1)
	ok(D.ui.sheets.shift.frame.open, "the shift card is open")
	ok(not price.frame.open, "the price sheet was closed for it") -- Console.lua:164
	eq(D.SheetOpen(), true, "one sheet open")
	D.ui.sheets.shift.frame:Close(true)
	eq(D.SheetOpen(), false, "none open")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: Refresh marks the console dirty; RefreshNow draws it and clears that; a dirty console redraws within a quarter second", function()
	local w, a, W, D = open()
	local ui = D.ui
	D.RefreshNow()
	eq(ui.dirty, false, "RefreshNow clears dirty") -- Console.lua:603
	D.Refresh()
	eq(ui.dirty, true, "Refresh marks it")
	D.RefreshNow()
	D.Refresh(true)
	eq(ui.at, 0, "Refresh(true) asks for the next tick") -- D.Refresh(soon): ui.at = 0
	D.RefreshNow()
	local at0 = ui.at
	D.Refresh()
	w:advance(0.1)
	eq(ui.dirty, true, "not yet: under a quarter second since the last draw") -- Console.lua:642 (0.25)
	w:advance(0.5)
	eq(ui.dirty, false, "drawn within a quarter second")
	ok(ui.at > at0, "the draw time moved")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: a roster change and entering a fight dirty the console (the roster draws soon, the fight at once)", function()
	local w, a, W, D = open()
	local ui = D.ui
	D.RefreshNow()
	a:fire("GROUP_ROSTER_UPDATE")
	eq(ui.dirty, true, "the group changed: redraw") -- Console.lua:W.On GROUP_ROSTER_UPDATE
	D.RefreshNow()
	w:enterCombat(a)
	eq(ui.dirty, true, "a fight began: redraw") -- Console.lua:W.On PLAYER_REGEN_DISABLED
	eq(ui.at, 0, "and at the next tick, not in a quarter second")
	w:leaveCombat(a)
	w:advance(1)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: in a fight SyncDock leaves the big button alone and a page swaps at once; after it the dock is laid again", function()
	local w, a, W, D = open()
	local ui = D.ui
	w:enterCombat(a)
	D.dockSig = "marker"
	D.SyncDock(true)
	eq(D.dockSig, "marker", "in combat the dock is not touched (a fight freezes the secure button)") -- Console.lua:225 inCombat
	eq(D.ShowScreen("crew"), true, "a page opens in combat")
	ok(ui.subs.crew.frame:IsShown(), "it is on screen at once, nothing travels") -- Console.lua header: in combat the swap is at once
	eq(D.pageMoving, nil, "no travel in progress")
	w:leaveCombat(a)
	w:advance(1)
	ok(D.dockSig ~= "marker", "PLAYER_REGEN_ENABLED lays the dock again after 0.2 s") -- Console.lua W.After(0.2, SyncDock(true))
	D.ShowScreen("console") w:advance(1.5)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: D.Build is the same tab for the same parent; the old names point at the console", function()
	local w, a, W, D = open()
	local ui = D.ui
	eq(D.Build(ui.parent), ui.root, "building twice for one parent gives the one tab") -- Console.lua:D.Build first line
	eq(D.ui, ui, "and keeps the one ui")
	eq(ui.drive, ui.console, "ui.drive is the console (compat)")
	eq(ui.go, ui.console.open, "ui.go is the console's Open pill (compat)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: Toggle opens the Wuber window on the Drive tab", function()
	local w, a, W, D = open()
	W.UI.Toggle(false)
	w:advance(2)
	ok(not W.UI.IsShown(), "control: the window is shut")
	D.Toggle()
	w:advance(2.5)
	ok(W.UI.IsShown(), "the window opened") -- Console.lua:D.Toggle (tabbed: W.UI.Show("drive"))
	eq(W.UI.state and W.UI.state.tab, "Drive", "on the Drive tab")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: a Wuber-less rider class sees the welcome page, not the console", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local D = r.W.Driver
	T.openDrive(r)
	r.W.UI.ShowDrive("console")
	w:advance(2)
	D.RefreshNow()
	eq(D.ui.mode, "welcome", "no Warlock, no service set up: the welcome page") -- State.lua D.Mode: role ~= driver
	ok(D.ui.welcome:IsShown(), "the welcome page shows")
	ok(not D.ui.console:IsShown(), "the console does not") -- Console.lua refreshNow setShown
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: a crew chip says You for me, the short name for others, 'no Wuber' for a Warlock without the app, and stars whose turn it is", function()
	local w, a, W, D = open()
	local parent = D.ui.root
	local me = { key = W.myKey, name = T.ANITA, role = "lock", shards = 7, app = true }
	local vex = { key = "vex shade", name = "Vex Shade", role = "lock", app = false }
	local ann = { key = "ann smith", name = "Ann Smith", role = "helper", silent = true }
	local zero = { key = "zed low", name = "Zed Low", role = "lock", shards = 0, app = true }
	local b = D.SideChip(parent)
	ok(b and b.name and b.count and b.cut and b.star, "the chip has name, count, cut and star")
	D.PaintSideChip(b, me, W.myKey)
	eq(plain(b.name:GetText()), "You", "my own chip says You") -- Console.lua:PaintSideChip
	eq(plain(b.count:GetText()), "7 shards", "my shards") -- Draw.lua:296 ChipCount
	eq(b.turn, true, "it is my turn to cast")
	ok(b.star:IsShown(), "the star shows on whose turn it is")
	D.PaintSideChip(b, vex, W.myKey)
	eq(plain(b.name:GetText()), "Vex", "others by first name (W.Short)")
	eq(plain(b.count:GetText()), "no Wuber", "a Warlock without Wuber: nobody sees their shards")
	eq(b.turn, false, "not their turn")
	ok(not b.star:IsShown(), "no star")
	D.PaintSideChip(b, ann, nil)
	eq(b.turn, false, "no turn known: nobody has the star")
	eq(plain(b.count:GetText()), "", "a helper has no shard count")
	D.PaintSideChip(b, zero, nil)
	eq(plain(b.count:GetText()), "0 shards", "zero shards is said, not hidden")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: LaySideChips lays one chip per row 46 apart, returns the y under them, reuses chips and hides the extras", function()
	local w, a, W, D = open()
	local parent = D.ui.root
	local list = { { key = W.myKey, name = T.ANITA, role = "lock", shards = 3, app = true },
		{ key = "vex shade", name = "Vex Shade", role = "lock", shards = 5, app = true },
		{ key = "ann smith", name = "Ann Smith", role = "helper" } }
	local pool = {}
	local y = D.LaySideChips(pool, parent, list, 10, nil)
	eq(y, 10 + 3 * 46, "the y under three chips") -- Console.lua:LaySideChips
	eq(#pool, 3, "three chips made")
	for i = 1, 3 do ok(pool[i]:IsShown(), "chip " .. i .. " shows") end
	local _, _, _, _, y2 = pool[2]:GetPoint(1)
	eq(y2, -(10 + 46), "the second chip sits 46 under the first")
	local first = pool[1]
	y = D.LaySideChips(pool, parent, { list[1] }, 0, nil)
	eq(y, 46, "one chip: 46 under y 0")
	ok(pool[1] == first, "the chip is reused, not made again")
	eq(#pool, 3, "the pool keeps the spare chips")
	ok(pool[1]:IsShown() and not pool[2]:IsShown() and not pool[3]:IsShown(), "the extra chips are hidden, not shown stale")
	eq(D.LaySideChips({}, parent, {}, 12, nil), 12, "an empty crew takes no room")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: the unfolded side pane shows today's takings and the summons average only from the third counted summon", function()
	local w, a, W, D = open({ wide = true })
	ok(D.Wide("console"), "control: the console is drawn unfolded")
	ok(#a:findText("Today's takings", false, true) > 0, "today's takings card on the right") -- Console.lua:buildConsoleSide
	ok(#a:findText("Today's takings · 0 rides", false, true) > 0, "nothing taken: 0 rides") -- Console.lua: plural(rides, "ride")
	ok(#a:findText("^0g$") > 0, "and the figure is 0g, never 'free'") -- Console.lua: c0 > 0 and Money or "0g"
	eq(#a:findText("Your summons:", false, true), 0, "no summons line yet")
	W.db.drive.summons = { { total = 40, cast = 10 }, { total = 45, cast = 12 } }
	D.RefreshNow() w:advance(1)
	eq(#a:findText("Your summons:", false, true), 0, "two counted summons are not enough (SUMMON.MIN = 3)") -- Drive/Log.lua:452,520
	W.db.drive.summons = { { total = 40, cast = 10 }, { total = 45, cast = 12 }, { total = 50, cast = 11 } }
	D.RefreshNow() w:advance(1)
	local fs = a:findText("Your summons:", false, true)[1]
	ok(fs and H.visible(fs), "from the third summon the line shows")
	eq(plain(fs:GetText()), "Your summons: about 45 sec", "the average of 40, 45, 50 in seconds") -- Console.lua words(): sec < 60
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.console: WideLayout remembers whether a page is drawn unfolded and redraws now", function()
	local w, a, W, D = open()
	local lay = D.WideLayout("zzpage")
	D.Refresh()
	lay(true)
	eq(D.wide.zzpage, true, "unfolded is remembered") -- Console.lua:wideLayout
	eq(D.ui.dirty, false, "and the console was redrawn at once")
	lay(false)
	eq(D.wide.zzpage, false, "folded")
	lay("yes")
	eq(D.wide.zzpage, false, "only true counts as unfolded")
	D.wide.zzpage = nil
	T.clean(w)
end)

-- NEEDS FAKE-GAME: the real bits below could not be pinned from the harness as read:
-- * root OnHide closing every open sheet (Console.lua D.Build OnHide) - needs the harness to fire OnHide on a child when the window shuts;
--   sketch: ShowSheet("shift"); W.UI.Toggle(false); w:advance(2); eq(D.SheetOpen(), false)
-- * D.Toggle's own "Wuber Drive" window (Console.lua D.Toggle, tabbed == false) - only reachable when W.UI.AddTab is missing at load.
