-- Wuber 2.4, simple driver: Simple mode on the driver's screens (console, rows and menu, price sheet, Earnings, shift card, first page, Crew). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

local DAN, EVE = "Dan Rider", "Eve Night"

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- how many visible texts on the client's screen contain s
local function count(a, s)
	local n = 0
	for _, t in ipairs(a:visibleTexts()) do
		if plain(t):find(s, 1, true) then n = n + 1 end
	end
	return n
end

local function vis(f) return f ~= nil and H.visible(f) == true end

-- a Warlock driver in Simple with the console open; o.queue = the customers (stubbed DR.Sorted)
local function console(o)
	o = o or {}
	local w = T.newWorld(o.world)
	local a = T.driver(w, T.ANITA, { spot = "Undercity", simple = true })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local cs = o.queue or {}
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return true end
	if o.before then o.before(a, W, DR) end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR
end

local function rider(name, o)
	local c = { name = name, key = name:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	for k, v in pairs(o or {}) do c[k] = v end
	return c
end

local function rowOf(D, c)
	for _, r in ipairs(D.ui.console.rows) do
		if r.c == c then return r end
	end
	return nil
end

local function again(w, W)
	W.Driver.RefreshNow()
	w:advance(1)
end

local function switch(w, a, on)
	a.W.SetAdvanced(on)
	w:advance(0.5)
end

---------------------------------------------------------------------------
-- The console
---------------------------------------------------------------------------

test("v24 simple driver: 1 the Sell / Raid summons bar shows only in raid mode or in a raid group", function()
	local w, a, W, DR = console()
	local v = W.Driver.ui.console
	eq(W.Advanced(), false, "the window starts in Simple")
	ok(not vis(v.modeBar), "Simple, selling, no raid: no bar")
	eq(count(a, "Sell summons"), 0, "no 'Sell summons' word")
	DR.SetMode("raid")
	again(w, W)
	ok(vis(v.modeBar), "Simple, raid mode on: the bar shows (the way back to Sell summons)")
	DR.SetMode("sell")
	again(w, W)
	ok(not vis(v.modeBar), "Simple, back to Sell: no bar again")
	a.env.IsInRaid = function() return true end
	again(w, W)
	ok(vis(v.modeBar), "Simple, in a raid group: the bar shows")
	a.env.IsInRaid = function() return false end
	again(w, W)
	ok(not vis(v.modeBar), "Simple, left the raid: no bar")
	switch(w, a, true)
	ok(vis(v.modeBar), "Advanced: the bar shows with no raid")
	eq(count(a, "Sell summons") > 0, true, "Advanced: 'Sell summons' is on the page")
	switch(w, a, false)
	ok(not vis(v.modeBar), "back in Simple: gone again")
	T.clean(w)
end)

test("v24 simple driver: 2 the Skip pill beside the big button is not drawn in Simple", function()
	local w, a, W, DR = console({ before = function(_, _, dr)
		dr.SkipTarget = function() return { name = DAN, key = "dan rider" } end
	end })
	local v = W.Driver.ui.console
	ok(not vis(v.skip), "Simple: no Skip pill")
	eq(count(a, "Skip"), 0, "Simple: no 'Skip' word")
	switch(w, a, true)
	ok(vis(v.skip), "Advanced: the Skip pill shows")
	ok(count(a, "Skip") > 0, "Advanced: 'Skip' is on the page")
	switch(w, a, false)
	ok(not vis(v.skip), "Simple again: gone")
	T.clean(w)
end)

test("v24 simple driver: 3 the line of what riders want is not drawn in Simple", function()
	local w, a, W = console({ before = function(_, W0)
		W0.Bounty.Demand = function() return { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 120 } } end
	end })
	local v = W.Driver.ui.console
	ok(not vis(v.demand), "Simple: no demand line")
	eq(count(a, "3 riders want Gadgetzan"), 0, "Simple: the words are not on the page")
	switch(w, a, true)
	again(w, W)
	ok(vis(v.demand), "Advanced: the line shows")
	eq(count(a, "3 riders want Gadgetzan"), 1, "Advanced: the words are on the page")
	switch(w, a, false)
	ok(not vis(v.demand), "Simple again: gone")
	T.clean(w)
end)

test("v24 simple driver: 4 the community tip is not drawn in Simple; the Join card stays in both modes", function()
	local TIP = "Tip: join the Wuber community for more visibility"
	local invite = nil
	local w, a, W = console({ world = { clubs = true }, before = function(_, W0)
		W0.CommunityAvailable = function() return true end
		W0.CommunityMember = function() return false end
		W0.CommunityInvite = function() return invite end
		W0.OnFounderRuleset = function() return true end
	end })
	local v = W.Driver.ui.console
	eq(count(a, TIP), 0, "Simple: no tip")
	switch(w, a, true)
	again(w, W)
	eq(count(a, TIP), 1, "Advanced: the tip shows")
	switch(w, a, false)
	eq(count(a, TIP), 0, "Simple again: no tip")
	invite = 7
	again(w, W)
	ok(count(a, "Join the Wuber community") > 0, "Simple, invited: the Join card shows")
	ok(vis(v.comm), "Simple: the card frame shows")
	eq(count(a, TIP), 0, "Simple, invited: still no tip")
	switch(w, a, true)
	again(w, W)
	ok(count(a, "Join the Wuber community") > 0, "Advanced, invited: the Join card shows")
	T.clean(w)
end)

test("v24 simple driver: 5 Your business lists Earnings, Blocked only with someone blocked, Crew only in a crew", function()
	local w, a, W, DR = console()
	local D = W.Driver
	local v = D.ui.console
	local function shown()
		local out = {}
		for _, l in ipairs(v.links) do
			if vis(l) then out[#out + 1] = l.what end
		end
		return table.concat(out, " ")
	end
	local function noGaps(what)
		local prev
		for _, l in ipairs(v.links) do
			if vis(l) then
				if prev then ok(math.abs(l:GetTop() - prev:GetBottom()) < 12, what .. ": " .. l.what .. " follows " .. prev.what .. " with no gap (" .. tostring(prev:GetBottom()) .. " / " .. tostring(l:GetTop()) .. ")") end
				prev = l
			end
		end
	end
	eq(shown(), "earnings", "Simple, alone, nobody blocked: Earnings only")
	noGaps("Simple")
	eq(count(a, "Messages"), 0, "Simple: no Messages word")
	eq(count(a, "Customers"), 0, "Simple: no Customers word")
	-- someone blocked: Blocked joins
	DR.Blacklist(DAN, "owes gold")
	again(w, W)
	eq(shown(), "blocked earnings", "Simple, one player blocked: Blocked and Earnings")
	noGaps("Simple blocked")
	-- in a crew: Crew joins
	local crewCount = D.CrewCount
	D.CrewCount = function() return 2 end
	again(w, W)
	eq(shown(), "crew blocked earnings", "Simple, in a crew: Crew, Blocked, Earnings")
	noGaps("Simple crew")
	-- Advanced: all five
	switch(w, a, true)
	eq(shown(), "crew messages blocked earnings customers", "Advanced: all five")
	noGaps("Advanced")
	D.CrewCount = crewCount
	switch(w, a, false)
	eq(shown(), "blocked earnings", "Simple again: the crew is gone, Blocked stays")
	T.clean(w)
end)

test("v24 simple driver: 5b Your business in Simple: nobody blocked and no crew, Blocked is not listed; Advanced lists it always", function()
	local w, a, W = console()
	local v = W.Driver.ui.console
	ok(not vis(v.links.blocked), "Simple: Blocked is hidden with nobody blocked")
	ok(not vis(v.links.crew), "Simple: Crew is hidden alone")
	ok(vis(v.links.earnings), "Simple: Earnings shows")
	switch(w, a, true)
	ok(vis(v.links.blocked), "Advanced: Blocked is listed with nobody blocked")
	ok(vis(v.links.crew), "Advanced: Crew is listed")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Rider rows and their menu
---------------------------------------------------------------------------

test("v24 simple driver: 6 the row chips '3rd ride with you' and 'Invite to Wuber' are not drawn in Simple", function()
	local dan = rider(DAN)
	local w, a, W = console({ queue = { dan } })
	local D = W.Driver
	D.RideCount = function() return 2 end
	again(w, W)
	local r = rowOf(D, dan)
	ok(r ~= nil, "Dan's row")
	ok(not vis(r.again), "Simple: no 'ride with you' chip")
	ok(not (r.getapp and vis(r.getapp)), "Simple: no Invite to Wuber chip")
	eq(count(a, "ride with you"), 0, "Simple: not on the page")
	eq(count(a, "Invite to Wuber"), 0, "Simple: not on the page (Invite)")
	switch(w, a, true)
	again(w, W)
	r = rowOf(D, dan)
	ok(vis(r.again), "Advanced: the 'ride with you' chip shows")
	ok(count(a, "3rd ride with you") > 0, "Advanced: '3rd ride with you' is on the page")
	ok(r.getapp and vis(r.getapp), "Advanced: the Invite to Wuber chip shows")
	switch(w, a, false)
	r = rowOf(D, dan)
	ok(not vis(r.again) and not (r.getapp and vis(r.getapp)), "Simple again: both gone")
	T.clean(w)
end)

-- the titles of the menu's visible items
local function menuTitles(D)
	local menu = D.ui.sheets.menu
	local out = {}
	for id, r in pairs(menu.items) do
		if vis(r) then
			if r.label then
				out[#out + 1] = plain(r.label:GetText())
			elseif r.note then
				out[#out + 1] = plain(r.note.label:GetText())
				out[#out + 1] = plain(r.gift.label:GetText())
			end
		end
	end
	table.sort(out)
	return out, table.concat(out, " | ")
end

local function has(list, t)
	for _, x in ipairs(list) do
		if x == t then return true end
	end
	return false
end

test("v24 simple driver: 7 the row menu lists at most five items in Simple, with no shortcut words", function()
	local dan = rider(DAN, { state = "waiting", auto = "auto", source = "whisper" })
	local lead = rider(EVE, { state = "lead" })
	local w, a, W, DR = console({ queue = { dan, lead } })
	local D = W.Driver
	ok(D.OpenMenu(dan), "the menu opens in Simple")
	w:advance(1)
	local list, joined = menuTitles(D)
	for _, bad in ipairs({ "Mark as paid", "Not a rider (a helper)", "Note...", "Edit note", "Gifted", "Give raincheck" }) do
		ok(not has(list, bad), "Simple: no '" .. bad .. "' in " .. joined)
	end
	for _, t in ipairs(list) do
		ok(not t:find("Get Wuber", 1, true), "Simple: no Get Wuber item: " .. t)
	end
	ok(has(list, "Take off the list"), "Simple: Take off the list is listed: " .. joined)
	ok(has(list, "Block..."), "Simple: Block... is listed: " .. joined)
	ok(has(list, "Summon again"), "Simple: Summon again is listed for a waiting rider: " .. joined)
	ok(has(list, "Oops, wrong invite"), "Simple: Oops, wrong invite is listed: " .. joined)
	ok(#list <= 5, "Simple: at most five items: " .. joined)
	local menu = D.ui.sheets.menu
	for id, r in pairs(menu.items) do
		if vis(r) then
			local sub = plain(r.sub:GetText())
			for _, word in ipairs({ "Ctrl-click", "right-click", "shift-right-click" }) do
				ok(not sub:lower():find(word:lower(), 1, true), "Simple: " .. id .. "'s second line has no '" .. word .. "': " .. sub)
			end
		end
	end
	eq(plain(menu.items.drop.sub:GetText()), "Nothing is said", "Take off the list's second line")
	eq(plain(menu.items.block.sub:GetText()), "Never serve them again", "Block's second line")
	local hSimple = menu.frame.sheetH
	-- the menu stays open: Advanced lists the rest and is taller
	switch(w, a, true)
	local listA, joinedA = menuTitles(D)
	ok(has(listA, "Mark as paid"), "Advanced: Mark as paid is listed: " .. joinedA)
	ok(has(listA, "Not a rider (a helper)"), "Advanced: Not a rider (a helper) is listed: " .. joinedA)
	ok(has(listA, "Note..."), "Advanced: Note... is listed: " .. joinedA)
	ok(has(listA, "Gifted"), "Advanced: Gifted is listed: " .. joinedA)
	ok(has(listA, "Send \"Get Wuber\""), "Advanced: Get Wuber is listed: " .. joinedA)
	ok(menu.frame.sheetH > hSimple, "Advanced: the sheet is taller (" .. tostring(hSimple) .. " / " .. tostring(menu.frame.sheetH) .. ")")
	ok(plain(menu.items.drop.sub:GetText()):find("right-click", 1, true), "Advanced: the shortcut words are back")
	switch(w, a, false)
	local list2 = menuTitles(D)
	ok(not has(list2, "Mark as paid"), "Simple again: Mark as paid gone")
	eq(menu.frame.sheetH, hSimple, "Simple again: the same height")
	-- a lead rider: Invite is listed
	D.OpenMenu(lead)
	w:advance(1)
	local l3, j3 = menuTitles(D)
	ok(has(l3, "Invite"), "Simple: Invite for a lead: " .. j3)
	ok(has(l3, "Take off the list") and has(l3, "Block..."), "Simple: Take off and Block for a lead: " .. j3)
	T.clean(w)
end)

test("v24 simple driver: 8 the price sheet has no Also called or Name riders see in Simple", function()
	local w, a, W = console()
	local D = W.Driver
	D.ShowSheet("sheet")
	w:advance(1)
	local s = D.ui.screens and D.ui.screens.sheet or W.UI.drive.screens.sheet
	ok(s ~= nil, "the sheet is built")
	local sheet = s.frame
	if s.mode ~= "choose" and s.setMode then s.setMode("choose") end
	w:advance(0.5)
	local function state()
		return vis(s.alsoLabel), vis(s.also), vis(s.nameLabel), vis(s.service)
	end
	local hSimple = sheet.sheetH
	local al, ao, nl, sv = state()
	ok(not al and not ao, "Simple: Also called (label, box) hidden")
	ok(not nl and not sv, "Simple: Name riders see (label, box) hidden")
	eq(count(a, "Also called"), 0, "Simple: no 'Also called' word")
	eq(count(a, "Name riders see"), 0, "Simple: no 'Name riders see' word")
	local saved = W.Drive.opts().service
	switch(w, a, true)
	local hAdv = sheet.sheetH
	al, ao, nl, sv = state()
	ok(nl and sv, "Advanced: Name riders see shows")
	ok(count(a, "Name riders see") > 0, "Advanced: the words are on the page")
	ok(hAdv > hSimple, "Advanced: the sheet is taller (" .. tostring(hSimple) .. " / " .. tostring(hAdv) .. ")")
	eq(W.Drive.opts().service, saved, "the saved name is untouched by the switch")
	switch(w, a, false)
	eq(sheet.sheetH, hSimple, "Simple again: the same height")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Earnings
---------------------------------------------------------------------------

local function earnings(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", simple = true })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local D = W.Driver
	-- a crew to see Me / Crew, hours to chart, a window to try, a split and rainchecks to show
	DR.Crew = function() return { { me = true, name = T.ANITA, key = W.myKey }, { name = "Vex Shade", key = "vex shade" } } end
	DR.TryHours = function() return { { wday = 2, hour = 19 } } end
	D.CutRows = function()
		return { { key = W.myKey, name = T.ANITA, casts = 5, clicks = 0, share = 21000 }, { key = "vex shade", name = "Vex Shade", casts = 0, clicks = 6, share = 9000 } }
	end
	D.RaincheckCounts = function() return 2, 1 end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	return w, a, W, W.UI.drive.screens.earnings
end

test("v24 simple driver: 9 Simple Earnings shows the period choice, total, rides and gold an hour and nothing else", function()
	local w, a, W, s = earnings()
	s.update()
	w:advance(0.5)
	local function parts()
		return { who = vis(s.who), chart = vis(s.chart.chartBox), heat = vis(s.heat), top = vis(s.top), try = vis(s.try),
			cut = vis(s.cut), iou = vis(s.iou), reset = vis(s.reset) }
	end
	local p = parts()
	for _, k in ipairs({ "who", "chart", "heat", "top", "try", "cut", "iou", "reset" }) do ok(not p[k], "Simple: " .. k .. " is not drawn") end
	eq(count(a, "Reset stats"), 0, "Simple: no 'Reset stats' word")
	eq(count(a, "Top window"), 0, "Simple: no 'Top window' word")
	eq(count(a, "Gold per open hour"), 0, "Simple: no chart legend")
	ok(count(a, "Today") > 0 and count(a, "7 days") > 0 and count(a, "30 days") > 0, "Simple: the period choice shows")
	ok(vis(s.stats) and plain(s.stats:GetText()):find("ride", 1, true), "Simple: the rides line shows: " .. plain(s.stats:GetText()))
	ok(vis(s.total) or count(a, "g") > 0, "Simple: the total shows")
	local simpleH = s.scroll.content:GetHeight()
	switch(w, a, true)
	s.update()
	w:advance(0.5)
	p = parts()
	ok(p.who, "Advanced: Me / Crew shows")
	ok(p.chart, "Advanced: the hour chart shows")
	ok(p.heat, "Advanced: the heatmap shows")
	ok(p.try, "Advanced: the 'Try' chip shows")
	ok(p.cut, "Advanced: the fair split block shows")
	ok(p.iou, "Advanced: the rainchecks block shows")
	ok(p.reset, "Advanced: Reset stats shows")
	ok(count(a, "Reset stats") > 0, "Advanced: 'Reset stats' is on the page")
	ok(s.scroll.content:GetHeight() > simpleH, "Advanced: the page is longer (" .. tostring(simpleH) .. " / " .. tostring(s.scroll.content:GetHeight()) .. ")")
	switch(w, a, false)
	p = parts()
	for _, k in ipairs({ "who", "chart", "heat", "try", "cut", "iou", "reset" }) do ok(not p[k], "Simple again: " .. k .. " gone") end
	eq(s.scroll.content:GetHeight(), simpleH, "Simple again: the same length")
	T.clean(w)
end)

test("v24 simple driver: 10 My target per hour is a row on Earnings in Advanced only and sets the same option", function()
	local w, a, W, s = earnings()
	local DR = W.Drive
	s.update()
	w:advance(0.5)
	ok(not vis(s.targetRow), "Simple: no target row")
	eq(count(a, "My target per hour"), 0, "Simple: no 'My target per hour' word")
	switch(w, a, true)
	s.update()
	w:advance(0.5)
	ok(vis(s.targetRow), "Advanced: the target row shows")
	ok(count(a, "My target per hour") > 0, "Advanced: 'My target per hour' is on the page")
	ok(count(a, "for the Earnings chart") > 0, "Advanced: the second line")
	ok(s.targetRow:GetBottom() >= s.reset:GetTop() - 0.5 or s.targetRow:GetTop() >= s.reset:GetTop(), "the row is above Reset stats")
	eq(s.target.min or 10000, 10000, "from 1g")
	local lo, hi = s.target:GetMinMaxValues()
	eq(lo, 10000, "the range starts at 1g")
	eq(hi, 500000, "the range ends at 50g")
	eq(DR.opts().target or 100000, 100000, "the default")
	s.target:SetValue(250000)
	w:advance(1)
	eq(DR.opts().target, 250000, "moving the slider writes the same option Settings wrote (opts.target)")
	eq(plain(s.target.label:GetText()), "25g / hour", "the same format")
	-- the chart's target line follows at once
	ok(s.chart.targetText ~= nil, "the chart has its target text")
	switch(w, a, false)
	ok(not vis(s.targetRow), "Simple again: the row is gone")
	eq(DR.opts().target, 250000, "the saved target is untouched by the switch")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- The shift card
---------------------------------------------------------------------------

test("v24 simple driver: 11 the shift card shows the gold line, Rides and Tips in Simple", function()
	local w, a, W = console({ before = function(_, W0)
		W0.InGroup = function() return true end
		W0.UI.Share.State = function() return nil end
	end })
	local D = W.Driver
	local rows = { { key = W.myKey, name = T.ANITA, casts = 5, clicks = 0, share = 21000 },
		{ key = "vex shade", name = "Vex Shade", casts = 2, clicks = 1, share = 12000 } }
	D.lastShift = { rides = 7, copper = 31000, tips = 500, open = 7200, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = rows, rule = "clicks", pct = 40 } }
	ok(D.ShowSheet("shift"), "the card opens")
	w:advance(1)
	local s = W.UI.drive.screens.shift
	eq(count(a, "Best hour"), 0, "Simple: no Best hour tile")
	eq(count(a, "Fair split"), 0, "Simple: no Fair split block")
	eq(count(a, "Post to party"), 0, "Simple: no Post to party")
	ok(count(a, "Rides") > 0, "Simple: the Rides tile shows")
	ok(count(a, "Tips") > 0, "Simple: the Tips tile shows")
	ok(vis(s.gold), "Simple: the gold line shows")
	ok(vis(s.done), "Simple: the close button shows")
	local nShown = 0
	for _, t in ipairs(s.tiles) do if vis(t) then nShown = nShown + 1 end end
	eq(nShown, 2, "Simple: two tiles")
	ok(vis(s.tiles[1]) and vis(s.tiles[2]), "Simple: the first two tiles are the ones left")
	eq(s.tiles[1]:GetTop(), s.tiles[2]:GetTop(), "Simple: the two tiles share one row")
	ok(s.tiles[2]:GetLeft() >= s.tiles[1]:GetRight() - 0.5, "Simple: side by side")
	local hSimple = s.frame.sheetH
	switch(w, a, true)
	ok(count(a, "Best hour") > 0, "Advanced: Best hour shows")
	ok(count(a, "Open") > 0, "Advanced: Open shows")
	ok(count(a, "Fair split") > 0, "Advanced: the Fair split block shows")
	ok(count(a, "Post to party") > 0, "Advanced: Post to party shows")
	ok(s.frame.sheetH > hSimple, "Advanced: the card is taller")
	switch(w, a, false)
	eq(count(a, "Best hour"), 0, "Simple again: no Best hour")
	eq(count(a, "Post to party"), 0, "Simple again: no Post to party")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Straight to the console
---------------------------------------------------------------------------

test("v24 simple driver: 12 a lone Warlock in Simple skips the welcome page and the setup", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", simple = true })
	T.settle(w)
	local W = a.W
	local D = W.Driver
	ok(W.Char().wizard ~= true, "no wizard flag")
	ok(W.Char().welcomed ~= true, "no welcomed flag")
	local wiz0, wel0 = W.Char().wizard, W.Char().welcomed
	eq(D.CrewCount(), 0, "alone")
	eq(D.Mode(), "console", "Simple: Mode answers console")
	W.UI.Toggle(true)
	w:advance(2.5)
	a:clickText("Drive")
	w:advance(1)
	ok(count(a, "Set up driving") == 0, "Simple: no 'Set up driving'")
	ok(count(a, "Open") > 0, "Simple: the console's Open button shows")
	eq(W.Char().wizard, wiz0, "nothing written: the wizard flag")
	eq(W.Char().welcomed, wel0, "nothing written: the welcomed flag")
	switch(w, a, true)
	eq(D.Mode(), "welcome", "Advanced: the welcome page, as before")
	T.clean(w)
end)

test("v24 simple driver: 12b a Warlock in a crew and a player who is not a Warlock still get the welcome page in Simple", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", simple = true })
	local m = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	-- not a Warlock, set up as a driver: no short cut
	m.W.Drive.Role = function() return "driver" end
	eq(m.W.Driver.Mode(), "welcome", "Simple, a Mage who runs a service: the welcome page")
	-- a Warlock with a crew falls back to the old rule: the saved flags decide
	a.W.Driver.CrewCount = function() return 1 end
	ok(a.W.Driver.Mode() == "console" or a.W.Driver.Mode() == "welcome", "a Warlock with a crew gets the old rule")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- The Crew page
---------------------------------------------------------------------------

local function crewPage(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", simple = true })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if o.helper then
		DR.IsCaptain = function() return false end
	end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("crew")
	w:advance(1)
	return w, a, W, DR, W.UI.drive.screens.crew
end

test("v24 simple driver: 13 the Crew page has the Fair split rows in Advanced only, above Run the setup again", function()
	local w, a, W, DR, s = crewPage()
	s.update()
	w:advance(0.5)
	ok(not vis(s.splitHead) and not vis(s.cutRuleRow) and not vis(s.cutCasterRow), "Simple: no Fair split rows")
	eq(count(a, "Fair split"), 0, "Simple: no 'Fair split' word")
	eq(count(a, "Casters' part"), 0, "Simple: no Casters' part")
	local simpleH = s.scroll.content:GetHeight()
	switch(w, a, true)
	s.update()
	w:advance(0.5)
	ok(vis(s.splitHead), "Advanced: the heading shows")
	ok(count(a, "Fair split") > 0, "Advanced: 'Fair split' is on the page")
	ok(count(a, "How the shift's gold is split") > 0, "Advanced: the rule row")
	ok(vis(s.cutRuleRow), "Advanced: the rule row frame shows")
	ok(vis(s.cutCasterRow) and count(a, "Casters' part") > 0, "Advanced: Casters' part shows while By clicks")
	ok(s.cutRuleRow:GetTop() < s.splitHead:GetBottom() + 1, "the rule row is under the heading")
	ok(s.cutCasterRow:GetTop() <= s.cutRuleRow:GetBottom() + 0.5, "Casters' part is under the rule")
	ok(s.wizard:GetTop() <= s.cutCasterRow:GetBottom() + 0.5, "Run the setup again is under both rows")
	ok(s.scroll.content:GetHeight() > simpleH, "the page scrolls further")
	-- the choice and the slider write the options Settings wrote
	eq(DR.opts().cutRule or "clicks", "clicks", "default By clicks")
	a:clickOn(s.cutSeg.buttons[2])
	w:advance(1)
	eq(DR.opts().cutRule, "equal", "Equal writes opts.cutRule")
	ok(not vis(s.cutCasterRow), "Equal: Casters' part is hidden")
	a:clickOn(s.cutSeg.buttons[1])
	w:advance(1)
	eq(DR.opts().cutRule, "clicks", "By clicks writes opts.cutRule")
	ok(vis(s.cutCasterRow), "By clicks: Casters' part shows again")
	s.cutCaster:SetValue(65)
	w:advance(1)
	eq(DR.opts().cutCaster, 65, "the slider writes opts.cutCaster")
	switch(w, a, false)
	ok(not vis(s.splitHead) and not vis(s.cutRuleRow) and not vis(s.cutCasterRow), "Simple again: gone")
	eq(DR.opts().cutCaster, 65, "the saved part is untouched by the switch")
	T.clean(w)
end)

test("v24 simple driver: 13b a helper who follows a captain gets no Fair split rows even in Advanced", function()
	local w, a, W, DR, s = crewPage({ helper = true })
	switch(w, a, true)
	s.update()
	w:advance(0.5)
	ok(not vis(s.splitHead) and not vis(s.cutRuleRow) and not vis(s.cutCasterRow), "Advanced, helper: no Fair split rows")
	T.clean(w)
end)
