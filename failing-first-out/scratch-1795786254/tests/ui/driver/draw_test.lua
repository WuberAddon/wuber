-- Tests of UI.Driver.Draw (round 13, agent B: a reviewer's in-game screenshot findings). Loaded by
-- tests/run.lua with its helper table T. The console drawn each refresh: the unfolded console lists
-- the riders once (the side pane), what riders want shows folded, the crew's shard total, and the
-- controls that can't be used while closed look dimmed. The engine's queue is stubbed.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local DAN, EVE, GUS = "Dan Rider", "Eve Night", "Gus Hill"

local function key(n) return n:lower() end

local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function count(a, text)
	local n = 0
	for _, t in ipairs(a:visibleTexts()) do if plain(t) == text then n = n + 1 end end
	return n
end

local function has(a, text)
	for _, t in ipairs(a:visibleTexts()) do if plain(t):find(text, 1, true) then return true end end
	return false
end

local function texts(a) return table.concat(a:visibleTexts(), " | ") end

local function rider(name, o)
	local c = { name = name, key = key(name), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	for k, v in pairs(o or {}) do c[k] = v end
	return c
end

local function threeRiders()
	return { rider(DAN, { state = "joined" }), rider(EVE, { state = "arrived" }), rider(GUS, { wantsPrice = true }) }
end

-- a driver with the console up; o.queue (stubbed DR.Sorted), o.open, o.wide, o.raid, o.crew
-- (stubbed DR.Crew after me), o.demand (stubbed W.Bounty.Demand)
local function console(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 12 end
	local cs = o.queue or {}
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	local open = o.open ~= false
	DR.IsOpen = function() return open end
	if o.crew then
		local crew = o.crew
		DR.Crew = function()
			local out = { { name = T.ANITA, key = W.myKey, role = "lock", app = true, here = true, shards = 12, me = true } }
			for _, m in ipairs(crew) do out[#out + 1] = m end
			return out
		end
	end
	if o.demand then W.Bounty.Demand = function() return o.demand end end
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI and W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	if o.raid then
		W.Drive.SetMode("raid")
		w:advance(1)
		local t0 = a.env.GetTime() -- the queue's clock (Drive.Raid stamps asked with GetTime)
		DR.RaidQueue = function()
			return { { name = DAN, asked = t0 - 30, state = "queued", tries = 0 },
				{ name = GUS, asked = t0 - 50, state = "queued", tries = 0 },
				{ name = EVE, asked = t0 - 70, state = "queued", tries = 1 } }
		end
	end
	W.Driver.RefreshNow()
	w:advance(1)
	W.Driver.RefreshNow()
	return w, a, W, DR
end

---------------------------------------------------------------------------
-- I4: unfolded, the riders are listed once, in the side pane (open, closed and raid)
---------------------------------------------------------------------------

test("ui.driver.draw: I4 unfolded console lists each rider once (the side pane), open, closed and raid", function()
	for _, case in ipairs({ { what = "open" }, { what = "closed", open = false }, { what = "raid", raid = true } }) do
		local w, a, W = console({ wide = true, queue = threeRiders(), open = case.open, raid = case.raid })
		local D = W.Driver
		ok(D.Wide(case.raid and "raid" or "console"), case.what .. ": unfolded")
		for _, n in ipairs({ "Dan", "Eve", "Gus" }) do
			eq(count(a, n), 1, case.what .. ": " .. n .. " once: " .. texts(a))
		end
		if not case.raid then
			local v = D.ui.console
			ok(v.qhead:IsShown(), case.what .. ": the Riders heading on the left (r18)")
			ok(not has(a, "Queue ("), case.what .. ": no second queue on the right")
			local shown = 0
			for _, r in ipairs(v.rows) do if r:IsShown() and r.c then shown = shown + 1 end end
			eq(shown, 3, case.what .. ": the left has the three rows")
		end
		T.clean(w)
	end
	-- folded: the Riders list is the console's own
	local w, a, W = console({ queue = threeRiders() })
	ok(not W.Driver.Wide("console"), "folded")
	eq(count(a, "Dan"), 1, "folded: Dan once")
	ok(W.Driver.ui.console.qhead:IsShown(), "folded: the Riders heading")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- I9: what riders want shows on a normal-size (folded) console with riders listed, and unfolded
-- every wanted place is inside the window
---------------------------------------------------------------------------

local WANT = { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 60 }, { place = "Booty Bay", riders = 1, low = 7500, high = 7500, newest = 30 } }

-- inside the console's scroll viewport (not cut by its bottom edge)
local function inView(f, scroll)
	return f:GetBottom() >= scroll:GetBottom() - 0.5 and f:GetTop() <= scroll:GetTop() + 0.5
end

test("ui.driver.demand line: I9 folded with three riders, the demand line sits above them, in view", function()
	local w, a, W = console({ queue = threeRiders(), demand = WANT })
	local v = W.Driver.ui.console
	ok(not W.Driver.Wide("console"), "folded")
	ok(v.demand and T.H.visible(v.demand), "the line shows: " .. texts(a))
	eq(v.demand.text.wuberText, "3 riders want Gadgetzan · +1 more", "its words")
	ok(v.demand:GetBottom() >= v.qhead:GetTop(), "above the Riders heading")
	ok(inView(v.demand, v.scroll), "inside the scroll's view, no scrolling needed")
	T.clean(w)
end)

test("ui.driver.demand card: I9 unfolded, Wanted nearby tops the side pane (r18), every place in view", function()
	local w, a, W = console({ wide = true, queue = threeRiders(), demand = WANT })
	local D = W.Driver
	ok(D.Wide("console"), "unfolded")
	local v = D.ui.console
	eq(count(a, "Wanted nearby"), 1, "the card, once: " .. texts(a))
	ok(not (v.demand and v.demand:IsShown()), "no folded line as well")
	local card = v.wanted
	ok(card and card:IsVisible(), "the card is the side pane's")
	local side = card and card:GetParent() and card:GetParent():GetParent()
	for i, r in ipairs(card and card.rows or {}) do
		if r:IsShown() then ok(inView(r, side), "place " .. i .. " (" .. tostring(r.place.wuberText) .. ") not cut by the window's edge") end
	end
	ok(card and card.rows[2] and card.rows[2]:IsShown(), "Booty Bay is listed")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- I10: the crew's shard count is the team's total, the sum of the chips under it
---------------------------------------------------------------------------

local function crewOf3()
	return { { name = "Vex Shade", key = "vex shade", role = "lock", app = true, here = true, shards = 14 },
		{ name = "Nyla Dusk", key = "nyla dusk", role = "lock", app = true, here = true, shards = 9 },
		{ name = "Bea Jones", key = "bea jones", role = "helper", app = true, here = true },
		-- not here, or no Wuber (nobody sees their shards): not counted
		{ name = "Ivy Moss", key = "ivy moss", role = "lock", app = true, here = false, shards = 20 },
		{ name = "Kai Ash", key = "kai ash", role = "lock", app = false, here = true } }
end

test("ui.driver.draw: I10 the crew header counts the team's shards (You 12 + Vex 14 + Nyla 9 = 35), folded and unfolded", function()
	for _, wide in ipairs({ false, true }) do
		local w, a, W, DR = console({ wide = wide, queue = threeRiders(), crew = crewOf3() })
		DR.peers = {} -- the crew's HI not heard (DR.TeamShards would say 12)
		W.Driver.RefreshNow()
		local what = wide and "unfolded" or "folded"
		ok(has(a, "14 shards") and has(a, "9 shards"), what .. ": the chips: " .. texts(a))
		if wide then
			ok(has(a, "· 35 shards"), what .. ": Crew · 35 shards: " .. texts(a))
		else
			ok(has(a, "35 shards in the team"), what .. ": 35 shards in the team: " .. texts(a))
		end
		ok(not has(a, "12 shards in the team"), what .. ": never only mine")
		if wide then eq(count(a, "· 12 shards"), 0, what .. ": not Crew · 12 shards") end
		eq(W.Driver.CrewShards({ { role = "lock", shards = 3 }, { role = "lock", app = false, shards = 5 }, { role = "helper", shards = 4 }, { role = "lock", shards = -1 } }), 3, "the sum rule")
		eq(W.Driver.CrewShards({ { role = "helper" } }), nil, "no Warlock's count known: nil")
		T.clean(w)
	end
end)

test("ui.driver.draw: (2.3.2) the crew header's shard count is anchored, and no rider row is cut by the list's bottom edge under the demand line", function()
	local t0 = os.time()
	local w, a, W = console({ queue = threeRiders(), crew = crewOf3(),
		demand = { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = t0 } } })
	local v = W.Driver.ui.console
	ok(v.shards:IsShown() and v.shards:GetNumPoints() >= 1, "the shards line has an anchor")
	ok(v.demand and v.demand:IsShown(), "the demand line shows")
	local vb = v.scroll:GetBottom()
	for i, r in ipairs(v.rows) do
		if r:IsShown() and i > 1 then -- (the first row is always where it falls)
			ok(not (r:GetTop() > vb + 1 and r:GetBottom() < vb - 1), "row " .. i .. " is not cut by the bottom edge")
		end
	end
	T.clean(w)
end)

---------------------------------------------------------------------------
-- I24: closed, Pause and Advertise look dimmed (they do nothing until you open)
---------------------------------------------------------------------------

test("ui.driver.draw: I24 closed, Pause and Advertise are dimmed; open, they are not; raid stopped dims Pause", function()
	local w, a, W, DR = console({ open = false })
	local v = W.Driver.ui.console
	ok(v.pause:GetAlpha() <= 0.6, "closed: Pause dimmed (" .. v.pause:GetAlpha() .. ")")
	ok(v.advert:GetAlpha() <= 0.6, "closed: Advertise dimmed (" .. v.advert:GetAlpha() .. ")")
	eq(v.open:GetAlpha(), 1, "Open stays bright")
	ok(v.pause.inactive and v.advert.inactive, "and they don't click")
	DR.IsOpen = function() return true end
	W.Driver.RefreshNow()
	eq(v.pause:GetAlpha(), 1, "open: Pause bright")
	eq(v.advert:GetAlpha(), 1, "open: Advertise bright")
	T.clean(w)
	local w2, a2, W2, DR2 = console({ open = false, raid = true })
	local v2 = W2.Driver.ui.console
	ok(v2.pause:GetAlpha() <= 0.6, "raid stopped: Pause dimmed")
	eq(v2.pick:GetAlpha(), 1, "the summoner picker stays bright (it works while stopped)")
	T.clean(w2)
end)

---------------------------------------------------------------------------
-- r18 (the author 00:33): the unfolded Drive tab has no hole under the buttons: Riders right under them
-- (the narrow screen's list), the side pane holds the crew, today's takings and the best hours
---------------------------------------------------------------------------

test("ui.driver.draw: r18 unfolded layout - riders right under the buttons, crew + takings + best hours right, nothing off the frame", function()
	local w, a, W, DR = console({ wide = true, queue = threeRiders(), crew = crewOf3() })
	local D = W.Driver
	ok(D.Wide("console"), "unfolded")
	local v = D.ui.console
	local frame = a.env.WuberFrame
	-- no gap: the first rider's top is within 60 px of where the scroll (right under the buttons) starts
	local first = v.rows[1]
	ok(first and first:IsShown(), "the first rider is listed on the left")
	local gap = v.scroll:GetTop() - first:GetTop() - (v.ready:IsShown() and (v.ready:GetHeight() + 12) or 0) -- the checklist is content, not a hole
	ok(gap >= 0 and gap <= 60, "gap between the buttons and the list: " .. tostring(gap))
	ok(first:GetLeft() >= v.scroll:GetLeft() and first:GetRight() <= v.scroll:GetRight() + 0.5, "the rows stay in the left column")
	for _, n in ipairs({ "Dan", "Eve", "Gus" }) do eq(count(a, n), 1, n .. " once") end
	-- the right column
	ok(has(a, "· 35 shards"), "Crew in the side pane")
	ok(has(a, "Today's takings") and has(a, "rides"), "today's takings")
	ok(has(a, "Best hours, last 7 days"), "the best-hours heatmap")
	ok(has(a, "Open a few hours") or has(a, "Top window"), "the top window line")
	local sp = W.UI.drive and W.UI.drive.sides and W.UI.drive.sides.console
	local tp = sp and sp.top or (D.ui and D.ui.consoleSide and D.ui.consoleSide.top)
	if tp and tp.GetStringWidth then ok(tp:GetStringWidth() <= 316, "the Drive tab's tip line fits its column") end
	for _, fs in ipairs(a:findText("Best hours, last 7 days", false, true)) do
		local h = fs:GetParent()
		ok(h:GetRight() <= frame:GetRight() + 0.5, "the heatmap card is inside the frame")
		ok(h:GetWidth() <= 324 + 0.5, "and as wide as the pane")
	end
	-- folded: the same list, no side pane
	W.UI.Fold.Toggle()
	w:advance(1)
	D.RefreshNow()
	ok(not D.Wide("console"), "folded")
	ok(not has(a, "Today's takings"), "folded: no takings card")
	ok(v.rows[1]:IsShown(), "folded: the riders are listed")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- r18 (the author 01:00): Earnings' tip strip (top window + "Try ...") stays inside its pane, folded and unfolded
---------------------------------------------------------------------------

test("ui.driver.draw: r18 Earnings tips stay inside the pane (no cut-off second tip)", function()
	for _, wide in ipairs({ false, true }) do
		local w, a, W, DR = console({ wide = wide, queue = {} })
		local D = W.Driver
		DR.TryHours = function() return { { wday = 6, hour = 21 } } end
		D.TopWindow = function() return nil end
		local paint = D.PaintHeatmap
		D.PaintHeatmap = function(...) paint(...) return true end -- some rides logged, none yet in a top window: both tips show
		W.UI.ShowDrive("earnings")
		w:advance(1)
		D.RefreshNow()
		local e = W.UI.drive and W.UI.drive.screens and W.UI.drive.screens.earnings
		ok(e and e.top and e.try, "the tip chips exist")
		if e and e.top and e.try then
			local rc = e.rc
			for _, c in ipairs({ e.top, e.try }) do
				if c:IsShown() then
					ok(c:GetRight() <= rc:GetRight() + 0.5, (wide and "unfolded" or "folded") .. ": a tip stays inside its pane")
					ok(c:GetLeft() >= rc:GetLeft() - 0.5, "and not left of it")
				end
			end
			ok(e.top:IsShown() and e.try:IsShown(), "both tips are shown")
			if e.top:IsShown() and e.try:IsShown() then
				ok(e.try:GetTop() < e.top:GetBottom() + 0.5 or e.try:GetLeft() >= e.top:GetRight(), "the tips never overlap")
			end
		end
		T.clean(w)
	end
end)

---------------------------------------------------------------------------
-- (20 Nov, the author) the empty Riders radar turns once every 6 s, however often it is redrawn
---------------------------------------------------------------------------

test("ui.driver.draw: the empty radar keeps one 6 s turn through open, pause, fold, tabs, close and reopen", function()
	local w, a, W, DR = console({ wide = true })
	local D = W.Driver
	local icon = D.ui.console.empty.icon
	local sp = icon.wuberSpin
	ok(sp and sp.driver, "the radar has its spinner")
	local driver, n = sp.driver, 0
	-- the turn, in radians, over one second of the clock
	local function perSecond()
		w:advance(1)
		local before = icon:GetRotation()
		w:advance(1)
		local d = (before - icon:GetRotation()) % (2 * math.pi)
		return d
	end
	local want = 2 * math.pi / 6
	local function check(what)
		n = n + 1
		ok(icon.wuberSpin == sp and sp.driver == driver, what .. ": still the one driver")
		eq(sp.period, 6, what .. ": the period is 6 s")
		local d = perSecond()
		ok(math.abs(d - want) < 0.05, what .. ": " .. string.format("%.3f", d) .. " rad/s, wanted " .. string.format("%.3f", want))
	end
	check("start")
	for i = 1, 40 do W.Driver.RefreshNow() end
	w:advance(0.3)
	check("40 redraws")
	-- close and open (the radar stops and starts again)
	DR.IsOpen = function() return false end
	W.Driver.RefreshNow()
	w:advance(1)
	DR.IsOpen = function() return true end
	W.Driver.RefreshNow()
	w:advance(0.37)
	check("closed then open")
	-- pause and resume
	W.Drive.SetPaused(true) W.Driver.RefreshNow() w:advance(1)
	W.Drive.SetPaused(false) W.Driver.RefreshNow() w:advance(0.21)
	check("paused then resumed")
	-- fold and unfold
	W.UI.Fold.Toggle() w:advance(1) W.Driver.RefreshNow()
	W.UI.Fold.Toggle() w:advance(1) W.Driver.RefreshNow()
	check("folded then unfolded")
	-- other tabs and back, window closed and reopened
	for _, s in ipairs({ "raid", "console" }) do
		W.UI.ShowDrive(s) w:advance(0.4) W.Driver.RefreshNow()
	end
	W.UI.Toggle(false) w:advance(1)
	W.UI.Toggle(true) w:advance(2.5) a:clickText("Drive") w:advance(1)
	W.UI.ShowDrive("console") w:advance(0.3) W.Driver.RefreshNow()
	check("tabs, window closed and reopened")
	-- the engine itself: spinning again, or twice, never adds a driver or changes the turn time
	for i = 1, 5 do ok(W.Theme.Animate.Spin(icon, 6) == sp, "Spin again gives the same handle") end
	sp:Start() sp:Start()
	check("Spin and Start again")
	T.clean(w)
end)

-- (r19, tour 43) folded with the PvP warning (or any card) above, no rider row is cut by the bottom of the list
test("ui.driver.draw r19: folded with the PvP warning, no rider row is sliced by the bottom of the list", function()
	for _, withDemand in ipairs({ false, true }) do
		local w, a, W = console({ queue = threeRiders(), demand = withDemand and WANT or nil })
		W.Drive.DangerLevel = function() return 2, 30 end
		W.Driver.RefreshNow()
		local v = W.Driver.ui.console
		ok(v.pvp and T.H.visible(v.pvp), "the PvP pill shows")
		local sb = v.scroll:GetBottom()
		for i, r in ipairs(v.rows) do
			if r:IsShown() then
				local sliced = r:GetTop() > sb + 0.5 and r:GetBottom() < sb - 0.5
				ok(not sliced, "row " .. i .. " is not cut by the list bottom (demand=" .. tostring(withDemand) .. ")")
			end
		end
		T.clean(w)
	end
end)

---------------------------------------------------------------------------
-- Design round 1: the Options button never costs a row its words
---------------------------------------------------------------------------

test("d1 lead: a row keeps its longest words beside the Options button; when they do not fit there the button goes down a line", function()
	local w, a, W = console({ queue = threeRiders(), demand = WANT })
	local v = W.Driver.ui.console
	ok(has(a, "asks the price · whisper"), "the price asker's row still says where they asked: " .. texts(a))
	local row
	for _, r in ipairs(v.rows) do
		if r:IsShown() and plain(r.what.wuberText or ""):find("asks the price", 1, true) then row = r end
	end
	ok(row, "the row is there")
	ok(T.H.visible(row.more), "its Options button shows")
	-- the words and the button do not share a line when the words need the room
	local wl, wr = row.what:GetLeft(), row.what:GetLeft() + W.Theme.TextWidth(row.what)
	local sameLine = math.abs((row.more:GetTop() + row.more:GetBottom()) / 2 - (row.what:GetTop() + row.what:GetBottom()) / 2) < 6
	ok(not (sameLine and wr > row.more:GetLeft()), "the words do not run under the Options button")
	T.clean(w)
end)
