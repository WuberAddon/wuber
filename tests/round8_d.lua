-- Wuber 2.3.0 round eight, agent D (driver UI, SPEC7 sections 2 and 5): the fuel gauge (5.4),
-- the cut UI (5.5), the demand line and sheet (5.3), the passphrase on queue rows (5.7), the PvP
-- chip (5.6), the raincheck menu item, alert and counts (5.8), and the driver pages' unfolded
-- layouts (2.8). Loaded by run.lua with the round-six helpers. Test names start "r8 driver:".
-- The engine and the network are stubbed (DR.* / W.* replaced at run time): these tests pin
-- what the driver's screens show for given answers, nil-safe while those owners' modules are
-- stubs.

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, clean = T.newWorld, T.clean

local DAN, EVE = "Dan Rider", "Eve Night"
local FARRA, HAYLEY = "Farra Lock", "Hayley Lock"

local function key(n) return n:lower() end

-- a driver with the console open; o.queue = the customers, o.shards = my shards (nil: unknown)
local function console(o)
	o = o or {}
	local w = newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local cs = o.queue or {}
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return o.closed ~= true end
	DR.Shards = function() return o.shards end
	if o.crew then DR.Crew = function() return o.crew end end
	if o.prepare then o.prepare(a, W, DR) end
	-- (2.3) the harness screen is 1920 wide: the console unfolds by itself unless told not to
	if o.wide then
		a.wide = true -- the harness keeps old tests folded unless they opt in
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI and W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR
end

local function texts(c) return table.concat(c:visibleTexts(), " | ") end

-- a control's tooltip, as the player hovers it (all its lines, joined)
local function tipOf(c, f)
	local S = H.state
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	local fn = S[f].scripts and S[f].scripts.OnEnter
	ok(fn, "the control has a tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- 5.4 fuel: the Soul Shard gauge
---------------------------------------------------------------------------

test("r8 driver: fuel - the gauge's number and colour at 25 / 6 / 3 / unknown (lowShards 3)", function()
	local w, a, W, DR = console({ shards = 25 })
	local D = W.Driver
	DR.opts().lowShards = 3
	local g = D.ui.console.status.fuel
	ok(g and H.visible(g), "the gauge shows in the status strip")
	-- (design 1 J) the count in words, no battery; an unknown count shows nothing
	local want = { { 25, "25 shards", "accent" }, { 6, "6 shards", "amber" }, { 3, "3 shards", "red" }, { nil, "", "off" } }
	for _, x in ipairs(want) do
		DR.Shards = function() return x[1] end
		D.RefreshNow()
		local n, colour = D.FuelInfo()
		eq(n, x[1], "the number for " .. tostring(x[1]))
		eq(colour, x[3], "the colour for " .. tostring(x[1]))
		eq(g.num.wuberText, x[2], "the number on the gauge")
		eq(g.colour, x[3], "the gauge painted " .. x[3])
	end
	-- its words are the gauge (the frame is as wide as they are; nothing scaled)
	DR.Shards = function() return 25 end
	D.RefreshNow()
	ok(g:GetWidth() > 34, "wide enough for the words: " .. g:GetWidth())
	eq(g:GetHeight(), 16, "16 high")
	eq(g.num.wuberPx, 11, "the number is 11 pt")
	clean(w)
end)

test("r8 driver: fuel - the tip names me and the crew's Warlocks (unknown counts are not added up)", function()
	local crew = {
		{ name = T.ANITA, key = key(T.ANITA), role = "lock", me = true },
		{ name = FARRA, key = key(FARRA), role = "lock", shards = 9 },
		{ name = HAYLEY, key = key(HAYLEY), role = "lock", shards = 10 },
		{ name = "Pat Helper", key = "pat helper", role = "helper" },
	}
	local w, a, W, DR = console({ shards = 12, crew = crew })
	local _, _, tip = W.Driver.FuelInfo()
	eq(tip, "Soul Shards: you 12 · crew 19 (Farra 9, Hayley 10). Each summon uses one.", "the tip")
	ok(tipOf(a, W.Driver.ui.console.status.fuel):find("you 12 · crew 19", 1, true), "the gauge's own tooltip")
	crew[3].shards = nil
	_, _, tip = W.Driver.FuelInfo()
	eq(tip, "Soul Shards: you 12 · crew 9 (Farra 9, Hayley ?). Each summon uses one.", "an unknown count shows ? and adds nothing")
	DR.Shards = function() return nil end
	_, _, tip = W.Driver.FuelInfo()
	eq(tip, "Soul Shards: not known yet. Each summon uses one.", "unknown")
	clean(w)
end)

test("r8 driver: fuel - a runner who isn't a Warlock, and raid summons, show the summoners' total", function()
	local w, a, W, DR = console({ shards = 4 })
	local D = W.Driver
	-- raid summons: the chosen summoners' shards (me 4, Farra 9)
	DR.Mode = function() return "raid" end
	DR.Summoners = function() return { key(T.ANITA), key(FARRA) } end
	DR.RaidWarlocks = function() return { { key = key(FARRA), name = FARRA, shards = 9, app = true } } end
	local n, colour, tip = D.FuelInfo()
	eq(n, 13, "raid: the summoners' total")
	eq(colour, "accent", "violet")
	ok(tip:find("your summoners 13", 1, true), tip)
	D.RefreshNow()
	eq(D.ui.console.status.fuel.num.wuberText, "13 shards", "on the raid console's gauge")
	-- a runner who isn't a Warlock: the crew's Warlocks
	DR.Mode = function() return "sell" end
	W.IsWarlock = function() return false end
	DR.IsWarlock = function() return false end
	DR.Crew = function() return { { name = FARRA, key = key(FARRA), role = "lock", shards = 2 } } end
	n, colour = D.FuelInfo()
	eq(n, 2, "the summoners' total")
	eq(colour, "red", "at or below lowShards: red")
	clean(w)
end)

test("r8 driver: fuel - the floating mini console has a small gauge (words, 12 high, 9 pt) between Pause and Close", function()
	local w, a, W, DR = console({ shards = 5 })
	local D = W.Driver
	DR.opts().lowShards = 3
	DR.button = DR.button or a.env.WuberDriveButton
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.Button.docked = nil
	DR.button:Show()
	D.UpdateMini()
	local mini = W.UI.drive.mini
	ok(mini and mini.fuel, "the mini console and its gauge")
	ok(mini.fuel:GetWidth() > 24, "as wide as its words")
	-- (design 3: the smallest text is 11, and the gauge is 16 high to hold it; the test keeps its name)
	eq(mini.fuel:GetHeight(), 16, "16 high")
	eq(mini.fuel.num.wuberPx, 11, "11 pt")
	ok(mini.fuel.num:GetStringHeight() <= mini.fuel:GetHeight() + 0.01, "the words are no taller than the gauge")
	eq(mini.fuel.num.wuberText, "5 shards", "the count in words")
	eq(mini.fuel.colour, "amber", "5 <= 2 x 3: amber")
	clean(w)
end)

---------------------------------------------------------------------------
-- 5.5 cut: casts and clicks, the fair split, "Post to party"
---------------------------------------------------------------------------

local CUT = {
	{ name = T.ANITA, key = key(T.ANITA), casts = 5, clicks = 0, share = 21000 },
	{ name = FARRA, key = key(FARRA), casts = 0, clicks = 9, share = 14000 },
	{ name = HAYLEY, key = key(HAYLEY), casts = 0, clicks = 8, share = 13000 },
}
local CUT_TEXT = "Shift split: Anita 2g 10s, Farra 1g 40s, Hayley 1g 30s"

local function crewOf()
	return {
		{ name = T.ANITA, key = key(T.ANITA), role = "lock", me = true },
		{ name = FARRA, key = key(FARRA), role = "lock", shards = 9 },
		{ name = HAYLEY, key = key(HAYLEY), role = "helper" },
	}
end

test("r8 driver: cut - the crew chips' tips and Earnings' Crew view show this shift's casts and clicks", function()
	local w, a, W, DR = console({ shards = 12, crew = crewOf(), prepare = function(_, W2, DR2)
		DR2.Cut = function() return CUT, "clicks" end
	end })
	local D = W.Driver
	eq(D.CutWords(5, 0), "5 casts", "casts only")
	eq(D.CutWords(1, 9), "1 cast · 9 clicks", "both")
	eq(D.CutWords(0, 0), "no clicks yet", "nothing")
	local casts, clicks = D.CutFor(key(FARRA))
	eq(casts, 0)
	eq(clicks, 9)
	-- the console's crew chip: the tip says it
	local chip
	for _, b in ipairs(D.ui.console.chips) do if b:IsShown() and b.m and b.m.key == key(FARRA) then chip = b end end
	ok(chip, "Farra's chip")
	local tip = tipOf(a, chip)
	ok(tip:find("This shift: 9 clicks.", 1, true), tip)
	-- Earnings, Crew view
	D.ShowScreen("earnings")
	w:advance(1)
	local s = W.UI.drive.screens.earnings
	-- (2.3.2, S4) folded too, the Me view shows the fair split card (as unfolded)
	ok(s.cut and T.H.visible(s.cut), "Me view: the fair split card, folded")
	eq(s.cut.title.wuberText, "Fair split, this shift", "its title")
	-- "Crew" is never cut to "Cre..."
	ok(not T.H.truncation(s.who.buttons[2].label), "the Crew pill is not truncated")
	-- the target label keeps clear of a bar that rises above the line
	DR.Hours = function()
		local h = {}
		for i = 0, 23 do h[i] = { copper = 0, rides = 0, open = 0, asks = 0 } end
		h[20] = { copper = 1000000, rides = 9, open = 120, asks = 0 }
		return h
	end
	s.update()
	local tr, br = T.H.rect(s.dash.targetText), T.H.rect(s.dash.bars[20])
	ok(tr.l + tr.w <= br.l + 0.5 or tr.l >= br.l + br.w - 0.5, "the target label is clear of the tall bar")
	s.who:SetValue("crew")
	s.scope = "crew"
	s.update()
	ok(s.cut and T.H.visible(s.cut), "the This shift card")
	eq(s.cut.lines[1].name.wuberText, "You", "me first")
	eq(s.cut.lines[1].what.wuberText:match("^5 casts"), "5 casts", "my casts (then the share)")
	eq(s.cut.lines[2].name.wuberText, "Farra", "Farra")
	eq(s.cut.lines[2].what.wuberText:match("^9 clicks"), "9 clicks", "her clicks (then the share)")
	clean(w)
end)

test("r8 driver: earnings - (2.3.2, S4) the headline gold-per-hour figure is never cut and stays clear of Me | Crew", function()
	local w, a, W, DR = console({ shards = 12, crew = crewOf() })
	local D = W.Driver
	D.ShowScreen("earnings")
	w:advance(1)
	local s = W.UI.drive.screens.earnings
	for _, per in ipairs({ 9999, 99999, 12340000, 123450000 }) do
		DR.LogTotals = function() return { copper = per, tips = 0, rides = 3, asks = 0, match = 0, open = 60, wreq = 0, wdec = 0, rivals = 0 } end
		s.update()
		local what = s.per.wuberText .. " (" .. per .. "c/h)"
		ok(not T.H.truncation(s.per), what .. " is not cut short")
		local need = W.Theme.MeasureText(s.per.wuberText, s.per.wuberPx or 40, "bold")
		ok(need <= s.per:GetWidth(), what .. " needs " .. need .. ", the label has " .. s.per:GetWidth())
		ok(s.per:GetLeft() + s.per:GetWidth() <= s.who:GetLeft(), what .. " runs under Me | Crew")
	end
	clean(w)
end)

test("r8 driver: cut - the shift card's fair split, the rule, 'never moves gold' and Post to party (once)", function()
	local registered = {}
	local w, a, W, DR = console({ shards = 12, crew = crewOf(), prepare = function(_, W2, DR2)
		DR2.Cut = function() return CUT, { rule = "clicks", pct = 40 } end
		DR2.CutText = function() return CUT_TEXT end
		W2.InGroup = function() return true end
		W2.UI.Share.Register = function(pill, fn, opts) registered[#registered + 1] = { pill = pill, fn = fn, opts = opts } end
		W2.UI.Share.State = function() return nil end
	end })
	local D = W.Driver
	D.ShiftEnded({ rides = 3, copper = 48000, crewRides = 2, crewCopper = 20000 })
	w:advance(1)
	local s = W.UI.drive.screens.shift
	ok(s and s.frame.open, "the shift card opened")
	local p = s.split
	ok(p and T.H.visible(p.head), "Fair split")
	eq(p.lines[1].name.wuberText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), "You · 5 casts", "my row")
	eq(p.lines[1].what.wuberText, "2g 10s", "my share")
	eq(p.lines[2].what.wuberText, "1g 40s", "Farra's share")
	ok(p.rule.wuberText:find("Casters 40%, clickers 60%.", 1, true), p.rule.wuberText)
	eq(p.note.wuberText, "Pay your helpers by trade.", "the note")
	ok(T.H.visible(p.post), "Post to party shows in a group")
	eq(p.post.label.wuberText, "Post to party", "its words")
	-- registered with UI.Share; its line is the split, <= 240 and clean
	eq(#registered, 1, "one share pill registered")
	eq(registered[1].pill, p.post, "the pill")
	local line = registered[1].fn()
	eq(line, CUT_TEXT, "the line")
	ok(#line <= 240, "<= 240")
	-- shared once: the pill says Posted and has nothing more to share
	eq(registered[1].opts.label, "Post to party", "the pill's words for UI.Share")
	registered[1].opts.onShared(line)
	eq(registered[1].fn(), nil, "once per card")
	eq(p.post.label.wuberText, "Posted", "Posted")
	-- the card fits the window body (544 under the top bar)
	ok(s.frame.card:GetHeight() <= 540, "fits: " .. s.frame.card:GetHeight())
	-- not grouped: no pill, Nice full width
	W.InGroup = function() return false end
	s.update()
	ok(not p.post:IsShown(), "no Post to party when not in a group")
	eq(s.done:GetWidth(), 320, "Nice full width")
	clean(w)
end)

test("r8 driver: cut - closing takes the split before the engine clears it; no crew counts: the 2.2 card", function()
	local w, a, W, DR = console({ shards = 12, crew = crewOf(), prepare = function(_, W2, DR2)
		local open = true
		DR2.IsOpen = function() return open end
		DR2.SetOpen = function(on) open = on return true end
		DR2.Cut = function() if open then return CUT, "clicks" end return {}, nil end
		DR2.ShiftSummary = function() return { rides = 2, copper = 30000 } end
	end })
	local D = W.Driver
	D.SetOnline(false)
	w:advance(1)
	local s = W.UI.drive.screens.shift
	ok(s and s.frame.open, "the shift card")
	ok(D.lastShift.cut and #D.lastShift.cut.rows == 3, "the split taken before the close")
	ok(T.H.visible(s.split.head), "Fair split shows")
	-- a shift with no casts or clicks counted: as before (352 high, no split)
	DR.Cut = function() return {}, nil end
	D.ShiftEnded({ rides = 1, copper = 5000 })
	s.update()
	ok(not s.split.head:IsShown(), "no split")
	eq(s.frame.card:GetHeight(), 352, "the 2.2 height")
	clean(w)
end)

---------------------------------------------------------------------------
-- 5.8 iou: the row menu's Give raincheck, the alert, Earnings' counts
---------------------------------------------------------------------------

test("r8 driver: iou - Give raincheck in the row menu only for an eligible ride; the click asks the book", function()
	local t0 = 0
	local dan = { name = DAN, key = key(DAN), state = "done", at = t0, source = "wuber", wuberRide = "r123", wuberBuyer = DAN, paid = 5000 }
	local eve = { name = EVE, key = key(EVE), state = "queued", at = t0, source = "whisper" }
	local given = {}
	local w, a, W, DR = console({ queue = { dan, eve }, prepare = function(_, W2, DR2)
		DR2.RaincheckEligible = function(id) if id == "r123" then return true end return false, "not paid by trade" end
		DR2.GiveRaincheck = function(id) given[#given + 1] = id return true end
	end })
	local D = W.Driver
	D.OpenMenu(dan)
	w:advance(1)
	local m = W.UI.drive.menu
	ok(m.items.raincheck and T.H.visible(m.items.raincheck), "Give raincheck shows")
	a:clickOn(m.items.raincheck)
	w:advance(1)
	eq(given[1], "r123", "the book was asked for that ride")
	ok(texts(a):find("Raincheck offered to Dan", 1, true), texts(a))
	-- a whisper rider (no ride id): no raincheck
	D.OpenMenu(eve)
	w:advance(1)
	ok(not m.items.raincheck:IsShown(), "not for a ride without an id")
	-- not eligible: not offered
	DR.RaincheckEligible = function() return false, "arrived" end
	D.OpenMenu(dan)
	w:advance(1)
	ok(not m.items.raincheck:IsShown(), "not when the book says no")
	clean(w)
end)

test("r8 driver: iou - the raincheck alert (DRIVE_ALERT kind raincheck) opens Give raincheck for that ride", function()
	local given = {}
	local w, a, W, DR = console({ prepare = function(_, W2, DR2)
		DR2.RaincheckEligible = function(id) return id == "r9" end
		DR2.GiveRaincheck = function(id) given[#given + 1] = id return true end
	end })
	local D = W.Driver
	W.Fire("DRIVE_ALERT", "Dan asks for a raincheck: his paid ride failed.", "raincheck", { rideId = "r9", name = DAN })
	w:advance(0.5)
	ok(texts(a):find("Dan asks for a raincheck", 1, true), "the alert shows: " .. texts(a))
	a:clickText("Dan asks for a raincheck", { pattern = true })
	w:advance(1)
	local m = W.UI.drive.menu
	ok(m and m.frame.open, "the menu opened")
	ok(T.H.visible(m.items.raincheck), "with Give raincheck")
	for id, r in pairs(m.items) do if id ~= "raincheck" then ok(not r:IsShown(), id .. " hidden") end end
	a:clickOn(m.items.raincheck)
	w:advance(1)
	eq(given[1], "r9", "given for that ride")
	clean(w)
end)

test("r8 driver: iou - Earnings counts the rainchecks given and used", function()
	local w, a, W, DR = console({ prepare = function(a2, W2, DR2)
		local t = a2.env.time()
		DR2.Rainchecks = function()
			return {
				{ id = "a", state = "active", issued = t - 60 }, { id = "b", state = "used", issued = t - 120 },
				{ id = "c", state = "offered", issued = t - 30 },
			}
		end
	end })
	local D = W.Driver
	eq(select(1, D.RaincheckCounts()), 2, "given (an offer still waiting is not)")
	eq(select(2, D.RaincheckCounts()), 1, "used")
	D.ShowScreen("earnings")
	w:advance(1)
	local s = W.UI.drive.screens.earnings
	ok(s.iou and T.H.visible(s.iou), "the line")
	eq(s.iou.text.wuberText, "Rainchecks: given 2 · used 1", "its words")
	DR.Rainchecks = function() return {} end
	s.update()
	ok(not s.iou:IsShown(), "none given: no line")
	clean(w)
end)

---------------------------------------------------------------------------
-- 5.7 pass: the passphrase on an app rider's row, its tip and the menu's header
---------------------------------------------------------------------------

test("r8 driver: pass - an app rider's row shows '· Violet Otter' on its second line, in its tip and the menu", function()
	local dan = { name = DAN, key = key(DAN), state = "joined", at = 0, source = "wuber", wuberRide = "ride42", wuberBuyer = DAN }
	local eve = { name = EVE, key = key(EVE), state = "queued", at = 0, source = "whisper" }
	local asked = {}
	local w, a, W, DR = console({ queue = { dan, eve }, prepare = function(_, W2)
		W2.Passphrase = function(id, rk) asked[#asked + 1] = id .. "|" .. tostring(rk) return "Violet Otter" end
		W2.Drive.SetOpt("showPass", true) -- (round 9) the words show only with "Show ride passphrase" on
	end })
	local D = W.Driver
	local r1, r2 = D.ui.console.rows[1], D.ui.console.rows[2]
	ok(r1.pass and T.H.visible(r1.pass), "the passphrase shows")
	eq(r1.pass.wuberText, "· Violet Otter", "its words")
	eq(asked[1], "ride42|dan rider", "asked with the ride id and the rider's key")
	ok(r1.pass:GetTop() < r1.name:GetBottom() + 1, "on the second line")
	ok(not (r2.pass and r2.pass:IsShown()), "not for a whisper rider")
	ok(D.RowTip(dan):find("Passphrase: Violet Otter", 1, true), "in the tip")
	D.OpenMenu(dan)
	w:advance(1)
	ok(W.UI.drive.menu.frame.sub.wuberText:find("Violet Otter", 1, true), "in the menu's header")
	-- an old network (no words): nothing
	W.Passphrase = function() return nil end
	D.RefreshNow()
	ok(not r1.pass:IsShown(), "no words, no line")
	clean(w)
end)

---------------------------------------------------------------------------
-- 5.6 pvp: the console's chip
---------------------------------------------------------------------------

test("r8 driver: pvp - 'PvP nearby · riders are warned' on the console at level 1 (amber) and 2 (red)", function()
	local level = 2
	local w, a, W, DR = console({ prepare = function(_, W2, DR2)
		DR2.DangerLevel = function() return level, 120 end
	end })
	local D = W.Driver
	local v = D.ui.console
	ok(v.pvp and T.H.visible(v.pvp), "the chip shows")
	ok(tipOf(a, v.pvp):find("fought enemy players 2 min ago", 1, true), "the tip says when")
	eq(v.pvp.label.wuberText, "PvP nearby · riders are warned", "its words")
	eq(v.pvp.colour, "red", "red at level 2")
	level = 1
	D.RefreshNow()
	eq(v.pvp.colour, "amber", "amber at level 1")
	level = 0
	D.RefreshNow()
	ok(not v.pvp:IsShown(), "gone at level 0")
	clean(w)
end)

---------------------------------------------------------------------------
-- 2.8 the unfolded driver pages (console, raid, earnings, messages), PAGE, and 2.9 item 9
---------------------------------------------------------------------------

local function queueOf(n)
	local out = {}
	for i = 1, n do
		out[i] = { name = "Rider" .. string.char(64 + i) .. " Test", key = "rider" .. string.char(96 + i) .. " test", state = "queued",
			at = i, source = "whisper" }
	end
	return out
end

local function shownRows(rows)
	local n = 0
	for _, r in ipairs(rows) do if r:IsShown() then n = n + 1 end end
	return n
end

local function pages(W)
	local list = {}
	W.Listen("PAGE", function() list[#list + 1] = tostring(W.UI.Fold.Page()) end)
	return list
end

test("r8 driver: fold - the unfolded console: no rows left (round 13, I4); the full queue, crew chips and Wanted nearby right", function()
	local w, a, W, DR = console({ wide = true, queue = queueOf(5), crew = crewOf(), shards = 12, prepare = function(_, W2, DR2)
		DR2.Cut = function() return CUT, "clicks" end
		W2.Bounty.Demand = function() return { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 0 } } end
	end })
	local D, UI = W.Driver, W.UI
	eq(UI.Fold.Page(), "console", "the console page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	eq(a.env.WuberFrame:GetWidth(), 720, "720 wide")
	ok(D.Wide("console"), "drawn wide")
	local v = D.ui.console
	-- (r18, the author 00:33) the riders are on the left under the buttons, once; the right has crew, takings, best hours
	eq(shownRows(v.rows), 5, "the left lists the five riders")
	ok(not v.crewHead:IsShown(), "no crew chips left")
	ok(not (v.demand and v.demand:IsShown()), "no demand line left")
	local all = texts(a)
	ok(not all:find("Queue (5)", 1, true), "no second queue on the right: " .. all)
	ok(all:find("Today's takings", 1, true) and all:find("Best hours, last 7 days", 1, true), "takings and best hours on the right")
	ok(all:find("RiderE", 1, true), "its fifth rider")
	ok(all:find("Farra", 1, true) and all:find("9 clicks", 1, true), "Farra's chip with her clicks")
	ok(all:find("Wanted nearby", 1, true), "the Wanted nearby card")
	-- the big button's slot does not move when the window unfolds
	local l0, t0 = v.slot:GetLeft(), v.slot:GetTop()
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded by the button")
	D.RefreshNow()
	eq(v.slot:GetLeft(), l0, "the slot's left")
	eq(v.slot:GetTop(), t0, "the slot's top")
	ok(shownRows(v.rows) >= 5, "folded: every row on the console")
	ok(v.crewHead:IsShown(), "folded: the crew chips are back")
	ok(not texts(a):find("Today's takings", 1, true), "the side pane is gone")
	clean(w)
end)

test("r8 driver: fold - raid summons unfold to the raid page (side: the raiders, Summoners)", function()
	local w, a, W, DR = console({ wide = true })
	local D, UI = W.Driver, W.UI
	local seen = pages(W)
	DR.SetMode("raid")
	w:advance(1)
	eq(seen[#seen], "raid", "DRIVE_MODE fired PAGE, now raid")
	eq(UI.Fold.Page(), "raid", "the raid page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	ok(D.Wide("raid"), "drawn wide")
	D.RefreshNow()
	ok(texts(a):find("Summoners", 1, true), "the summoner strip on the right: " .. texts(a))
	DR.SetMode("sell")
	w:advance(1)
	eq(seen[#seen], "console", "and back to the console")
	ok(not D.Wide("raid"), "the raid page is not wide any more")
	clean(w)
end)

test("r8 driver: fold - Earnings unfolded: numbers left, the heatmap and the shift's split right", function()
	local w, a, W, DR = console({ wide = true, crew = crewOf(), prepare = function(_, W2, DR2)
		DR2.Cut = function() return CUT, "clicks" end
	end })
	local D, UI = W.Driver, W.UI
	D.ShowScreen("earnings")
	w:advance(1)
	eq(UI.Fold.Page(), "earnings", "the earnings page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	local s = W.UI.drive.screens.earnings
	ok(s.side, "its side pane")
	ok(s.heatW and T.H.visible(s.heatW) and s.heatW:GetParent() == s.side.content, "the heatmap is on the right")
	ok(not s.heat:IsShown(), "not under the numbers")
	eq(s.heatW:GetWidth(), 324, "324 wide (18 px padding)")
	local pane = UI.Fold.Pane()
	eq(math.floor(s.heatW:GetLeft() - pane:GetLeft() + 0.5), 18, "18 from the pane's left")
	ok(s.cutW and T.H.visible(s.cutW) and s.cutW:GetParent() == s.side.content, "the shift's split on the right (any view)")
	ok(math.abs(pane:GetRight() - s.cutW:GetRight() - 18) < 0.5, "18 from the pane's right")
	ok(s.frame.bgMid:IsShown(), "the screen's background has no right edge (no divider)")
	UI.Fold.Toggle()
	w:advance(1)
	s.update()
	ok(T.H.visible(s.heat) and s.heat:GetParent() == s.content, "folded: the heatmap is back under the numbers")
	-- (2.3.2, S4) folded, the Me view shows the fair split too (in the one column, not the side pane)
	ok(s.cut and s.cut:IsShown() and not s.cutW:IsShown(), "folded, Me view: the fair split card, in the column")
	ok(not s.frame.bgMid:IsShown(), "folded: the one background as before")
	clean(w)
end)

test("r8 driver: fold - Messages unfolded: the list left, the editor right; the draft survives a fold", function()
	local w, a, W, DR = console({ wide = true })
	local D, UI = W.Driver, W.UI
	D.ShowScreen("messages")
	w:advance(1)
	eq(UI.Fold.Page(), "messages", "the messages page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	local s = W.UI.drive.screens.messages
	local e = s.editor
	eq(shownRows(s.rows), #s.rows, "every message listed")
	ok(T.H.visible(e), "the editor shows")
	ok(e ~= s.foldEd and e:GetParent() ~= s.content, "in the side pane")
	ok(e:GetLeft() >= s.rows[1]:GetRight(), "right of the list")
	local pane = UI.Fold.Pane()
	eq(math.floor(e.field:GetLeft() - pane:GetLeft() + 0.5), 18, "the field 18 from the pane's left")
	ok(math.abs(pane:GetRight() - e.field:GetRight() - 18) < 0.5, "and 18 from its right")
	ok(not s.foldEd:IsShown(), "the folded editor is hidden")
	eq(s.kind, "greet", "the first one is chosen")
	eq(e.when.wuberText, "Greeting · sent when you start their summon.", "the editor says which")
	eq(s.title.wuberText, "Messages", "the title stays")
	-- pick another: the editor follows, the list stays
	a:clickOn(s.rows[2])
	w:advance(0.5)
	eq(s.kind, "price", "Price chosen")
	eq(shownRows(s.rows), #s.rows, "the list stays")
	ok(e.when.wuberText:find("^Price"), e.when.wuberText)
	e.field:SetText("{price}, ask away")
	s.preview()
	-- fold: the editor comes back over the list with the draft
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded")
	e = s.editor
	eq(e, s.foldEd, "the folded editor")
	ok(T.H.visible(e), "shows")
	eq(shownRows(s.rows), 0, "folded editor: no list")
	eq(s.title.wuberText, "Price", "titled")
	eq(e.field:Text(), "{price}, ask away", "the draft kept")
	-- Back folded: the list
	a:clickOn(s.back)
	w:advance(0.5)
	eq(s.kind, nil, "back to the list")
	eq(shownRows(s.rows), #s.rows, "the list")
	ok(not e:IsShown(), "no editor")
	clean(w)
end)

test("r8 driver: fold - PAGE from D.ShowScreen, D.ShowSheet (open and close) and DRIVE_MODE", function()
	local w, a, W, DR = console({ wide = true })
	local D, UI = W.Driver, W.UI
	local seen = pages(W)
	D.ShowScreen("earnings")
	eq(seen[#seen], "earnings", "ShowScreen")
	D.ShowScreen("console")
	eq(seen[#seen], "console", "back to the console")
	local n = #seen
	D.ShowSheet("sheet")
	eq(#seen, n + 1, "the sheet's open fired PAGE")
	eq(seen[#seen], "nil", "a sheet has no page")
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded under the sheet")
	n = #seen
	W.UI.drive.screens.sheet.frame:Close(true)
	eq(#seen, n + 1, "its close fired PAGE")
	eq(seen[#seen], "console", "the console again")
	w:advance(1)
	ok(UI.Fold.IsUnfolded(), "unfolded again")
	n = #seen
	W.Fire("DRIVE_MODE", "sell")
	eq(#seen, n + 1, "DRIVE_MODE fired PAGE")
	clean(w)
end)

test("r8 driver: fold - each driver page's layout(true) then layout(false) twice makes no new frames (SPEC7 2.9 #9)", function()
	local w, a, W, DR = console({ wide = true, queue = queueOf(4), crew = crewOf() })
	local D, UI = W.Driver, W.UI
	local function twice(what)
		UI.Fold.Toggle() w:advance(1)
		UI.Fold.Toggle() w:advance(1)
		D.RefreshNow()
		ok(UI.Fold.IsUnfolded(), what .. ": unfolded")
		local n = #a.widgets
		UI.Fold.Toggle() w:advance(1)
		UI.Fold.Toggle() w:advance(1)
		D.RefreshNow()
		eq(#a.widgets, n, what .. ": no new frames the second time")
	end
	twice("console")
	D.ShowScreen("earnings") w:advance(1)
	twice("earnings")
	D.ShowScreen("messages") w:advance(1)
	twice("messages")
	D.ShowScreen("console") w:advance(1)
	DR.SetMode("raid") w:advance(1)
	eq(UI.Fold.Page(), "raid", "raid")
	twice("raid")
	clean(w)
end)

---------------------------------------------------------------------------
-- SPEC7 8.2: two-client scenarios over the real wire (the driver's screens only)
---------------------------------------------------------------------------

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- a three-window crew (open, Ana captain) with their own Soul Shards, and a 2.3.0 rider at Orgrimmar
local function crewWorld(shards)
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", shards = shards[i],
			saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
	r.W.VERSION = "2.3.0"
	w:group(names)
	w:advance(15)
	cs[1].W.Drive.SetOpen(true)
	w:advance(8)
	return w, cs[1], cs[2], cs[3], r
end

-- the Drive tab open on this window, folded unless wide
local function openConsole(c, wide)
	if wide then
		c.wide = true
		c.W.db.coach = true
	end
	c.W.UI.WindowWide(wide == true)
	T.openDrive(c)
	c.world:advance(2)
	c.W.Driver.RefreshNow()
end

test("r8 driver e2e: a rider's bounty reaches the console: the line folded, Wanted nearby unfolded, the sheet", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity" })
	local r = T.rider(w)
	T.settle(w)
	eq(r.W.Bounty.Pin("Gadgetzan", 7500), true, "Wuber pins a bounty for Gadgetzan")
	w:advance(2)
	openConsole(d)
	local D = d.W.Driver
	local v = D.ui.console
	ok(v.demand and H.visible(v.demand), "the demand line shows: " .. texts(d))
	ok(v.demand.text.wuberText:find("Gadgetzan", 1, true), v.demand.text.wuberText)
	-- unfolded: the card on the right instead
	d.wide = true
	d.W.UI.WindowWide(true)
	w:advance(1)
	D.RefreshNow()
	ok(d.W.UI.Fold.IsUnfolded(), "unfolded")
	ok(not v.demand:IsShown(), "no line on the left")
	local all = texts(d)
	ok(all:find("Wanted nearby", 1, true) and all:find("Gadgetzan", 1, true), "Wanted nearby lists it: " .. all)
	-- folded again, the line opens the sheet
	d.W.UI.WindowWide(false)
	w:advance(1)
	D.RefreshNow()
	d:clickOn(v.demand)
	w:advance(1)
	local s = d.W.UI.drive.screens.demand
	ok(s and s.frame.open, "the sheet opened")
	ok(texts(d):find("Gadgetzan", 1, true), "it names the place")
	clean(w)
end)

test("r8 driver e2e: Cal fights an enemy player; Ana's console shows the PvP chip", function()
	local w, ana, bea, cal, r = crewWorld({ 12, 9, 7 })
	openConsole(ana)
	local v = ana.W.Driver.ui.console
	ok(not (v.pvp and v.pvp:IsShown()), "calm: no chip")
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:advance(1)
	w:pvpFight(cal, "Ally Foe")
	w:advance(8)
	ana.W.Driver.RefreshNow()
	ok(v.pvp and H.visible(v.pvp), "the chip shows on Ana's console: " .. texts(ana))
	eq(v.pvp.label.wuberText, "PvP nearby · riders are warned", "its words")
	eq(v.pvp.colour, "red", "a hot drop: red")
	T.clean(w)
end)

test("r8 driver e2e: fuel - Ana's gauge is her own shards; its tip names Bea's and Cal's from their windows", function()
	local w, ana, bea, cal, r = crewWorld({ 12, 9, 2 })
	openConsole(ana)
	local D = ana.W.Driver
	local g = D.ui.console.status.fuel
	ok(g and H.visible(g), "the gauge shows")
	eq(g.num.wuberText, "12 shards", "Ana's own 12")
	local tip = tipOf(ana, g)
	ok(tip:find("Bea", 1, true) and tip:find("9", 1, true), "Bea's 9 in the tip: " .. tip)
	ok(tip:find("Cal", 1, true) and tip:find("2", 1, true), "Cal's 2 in the tip: " .. tip)
	T.clean(w)
end)

test("r8 driver e2e: raincheck - Wuber's paid ride fails; Ana's alert opens Give raincheck; Wuber accepts; Earnings counts it", function()
	local w, ana, bea, cal, r = crewWorld({ 12, 9, 7 })
	local TESTCHAR = T.TESTCHAR
	openConsole(ana)
	local DR, D = ana.W.Drive, ana.W.Driver
	-- Wuber books Ana and pays by trade (Ana steps over to Orgrimmar for it, then back)
	ok(r.W.RequestRide(key(ANA)), "Wuber asks Ana")
	w:advance(9)
	local c = DR.customers[key(TESTCHAR)]
	ok(c and c.wuberRide, "Ana took the Wuber ride")
	local ride = c and c.wuberRide
	w:move(ANA, "Orgrimmar")
	w:advance(1)
	ok(w:openTrade(w:player(ANA), w:player(TESTCHAR)), "a trade")
	w:tradeMoney(w:player(TESTCHAR), tonumber(c.price) or 5000)
	w:tradeAccept(w:player(ANA))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(1)
	ok(r.W.ride and r.W.ride.paid, "Wuber paid by trade")
	w:move(ANA, SPOT)
	w:advance(1)
	-- the summon never comes: Wuber gives up; Ana's window has the paid ride, ended
	ok(r.W.CancelRide(), "Wuber cancels")
	w:advance(3)
	local okE, why = DR.RaincheckEligible(ride)
	ok(okE, "the book: eligible (" .. tostring(why) .. ")")
	-- Wuber asks (the real V ask); Ana's alert
	ok(r.W.Raincheck.Ask(r.W.ride.id), "Wuber asks for a raincheck")
	w:advance(2)
	ok(texts(ana):find("asks for a raincheck", 1, true), "Ana's alert: " .. texts(ana))
	ana:clickText("asks for a raincheck", { pattern = true })
	w:advance(1)
	local m = ana.W.UI.drive.menu
	ok(m and m.frame.open and H.visible(m.items.raincheck), "Give raincheck for that ride")
	ana:clickOn(m.items.raincheck)
	w:advance(2)
	ok(texts(ana):find("Raincheck offered to Wuber", 1, true), "Ana's note: " .. texts(ana))
	local id, mine
	for k, v in pairs(r.W.db.rainchecks or {}) do id, mine = k, v end
	ok(mine and mine.state == "offered", "Wuber's copy: offered")
	-- Wuber accepts: active in Ana's book, counted on her Earnings
	ok(r.W.Raincheck.Accept(id), "Wuber accepts")
	w:advance(2)
	eq(ana.W.db.drive.iou[id] and ana.W.db.drive.iou[id].state, "active", "Ana's book: active")
	D.ShowScreen("earnings")
	w:advance(1)
	local s = ana.W.UI.drive.screens.earnings
	s.update()
	ok(s.iou and H.visible(s.iou), "the rainchecks line shows")
	eq(s.iou.text.wuberText, "Rainchecks: given 1 · used 0", "given 1")
	T.clean(w)
end)
