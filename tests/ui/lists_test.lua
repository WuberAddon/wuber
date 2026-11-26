-- Round 9, S6 (the author: "common bug, we need a global thing for this"): no list row is ever cut by a
-- hard edge. Plays one Warlock's window through every page (the eight that unfold, plus Home with a
-- long driver list, Help, Crew, Blocked and the summoner picker), folded and unfolded, at the top
-- of each list and scrolled, and runs tests/lib/listfade.lua over it: every visible row part that
-- is partly outside the list it sits in must have that list's soft fade (T.EdgeFade) at that edge.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local check = dofile(T.dir .. "/lib/listfade.lua")(H)

-- scrolls every visible list a few notches down (mouse wheel), then lets it settle
local function wheel(c, w, notches)
	local S = H.state
	for _, f in ipairs(c.frames) do
		local s = S[f]
		if s and s.clips and H.visible(f) and s.scripts.OnMouseWheel then
			for _ = 1, notches do pcall(s.scripts.OnMouseWheel, f, -1) end
		end
	end
	w:advance(1.5)
end

local function scene()
	local w = T.newWorld()
	local c = w:addClient("Wuber TestCharacter", { spot = "Orgrimmar", class = "WARLOCK", screenW = 1920, screenH = 1080, money = 1000000 })
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	c.wide = true
	local W = c.W
	W.db.coach = true
	W.db.openMapHint = true
	local t0 = c.env.GetTime()
	local names = { "Anita Lift", "Mia Runner", "Bob Stone", "Cal Brown", "Dee Moon", "Eve Star", "Fay Wind", "Gus Hill" }
	for i, n in ipairs(names) do
		local k = n:lower()
		W.drivers[k] = { name = n, key = k, dest = i % 2 == 0 and "Ratchet" or "Undercity", price = 5000 + i * 100,
			state = "open", team = (i % 3) + 1, service = n:match("^(%a+)") .. "'s Rides", heard = t0 }
	end
	return w, c, W
end

local function fold(W, wide)
	W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
	W.UI.Fold.Apply()
end

test("r9 S6: no list row is cut by a hard edge on any page, folded or unfolded, at the top or scrolled", function()
	local w, c, W = scene()
	local UI = W.UI
	local bad, looked = {}, 0
	local function look(name)
		w:advance(1)
		for _, b in ipairs(check(c, name)) do bad[#bad + 1] = b end
		looked = looked + 1
		wheel(c, w, 3)
		for _, b in ipairs(check(c, name .. " scrolled")) do bad[#bad + 1] = b end
		wheel(c, w, 40)
		for _, b in ipairs(check(c, name .. " at the end")) do bad[#bad + 1] = b end
	end
	local function both(name, go)
		for _, wide in ipairs({ false, true }) do
			fold(W, wide)
			w:advance(1)
			go()
			w:advance(1)
			look(name .. (wide and " unfolded" or " folded"))
		end
	end
	UI.Toggle(true)
	w:advance(3)
	both("ride", function() UI.Show("home") end)
	both("confirm", function() UI.Show("confirm", "anita lift") end)
	-- (round 13, I18) the pay screen ('Waiting for Mia to open tra...' in a reviewer's shot 13)
	both("pay", function()
		W.ride = { id = "r13", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = "arrived",
			at = c.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
		W.Fire("RIDE")
		w:advance(1)
		UI.Show("found")
	end)
	W.ride = nil
	W.Fire("RIDE")
	w:advance(1)
	both("trips", function() UI.Show("home") w:advance(1) UI.SelectTab("Trips") end)
	both("settings", function() UI.OpenSettings() end)
	both("help", function() UI.OpenHelp("settings") end)
	both("drive", function()
		if UI.HelpShown() then UI.CloseHelp() end
		UI.CloseSettings(true)
		w:advance(1)
		W.Char().wizard = true
		UI.SelectTab("Drive")
	end)
	both("raid", function() W.Drive.SetMode("raid") end)
	both("earnings", function() W.Drive.SetMode("sell") w:advance(1) W.Driver.ShowScreen("earnings") end)
	both("messages", function() W.Driver.ShowScreen("messages") end)
	for _, scr in ipairs({ "crew", "blocked", "raidpick" }) do
		both(scr, function() pcall(W.Driver.ShowScreen, scr) end)
	end
	ok(looked >= 24, "every page was looked at, folded and unfolded (" .. looked .. ")")
	eq(#bad, 0, "list rows cut by a hard edge (no soft fade there):\n  " .. table.concat(bad, "\n  "))
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
end)

test("r9 S6: the check itself fails on a row cut by a plain clip, and passes once the list has the fade", function()
	local w, c, W = scene()
	local env = c.env
	local v = env.CreateFrame("Frame", nil, env.UIParent)
	v:SetSize(200, 100)
	v:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	v:SetClipsChildren(true)
	local row = W.Theme.Text(v, 13, "white", "LEFT", "medium")
	row:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -90)
	row:SetSize(200, 20)
	row:SetText("A row half off the bottom")
	local bad = check(c, "plain")
	eq(#bad, 1, "one cut row: " .. table.concat(bad, "; "))
	ok(bad[1]:find("bottom edge", 1, true), "at the bottom: " .. bad[1])
	W.Theme.EdgeFade(v, { source = function() return 0, 50 end })
	w:advance(0.5)
	eq(#check(c, "faded"), 0, "the fade is showing: fine")
	v.edgeFade.bottom:Hide()
	eq(#check(c, "hidden fade"), 1, "a fade that is not showing does not count")
end)

-- (round 9 previews) a fade sits above its own rows but under any screen opened over its list: the
-- console's rider list showed its bottom fade through Earnings (it cut the heat map's Sunday row),
-- Messages, Crew, Customers and Blocked; Trips' through the Wrapped story.
test("r9 previews: a list's fade never shows through a screen opened over it (driver screens, Wrapped)", function()
	local w, c, W = scene()
	local UI = W.UI
	local D, DR = W.Driver, W.Drive
	local cs = {}
	for i = 1, 8 do
		local n = "Rider " .. string.char(64 + i)
		cs[i] = { name = n, key = n:lower(), state = "queued", source = "public", at = 0, price = 5000, paid = 0 }
	end
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, x in ipairs(cs) do DR.customers[x.key] = x end
	DR.IsOpen = function() return true end
	W.Char().wizard = true
	fold(W, false)
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(2)
	D.RefreshNow()
	w:advance(1.5)
	local fd = D.ui.drive.scroll.edgeFade
	ok(fd:Shown("bottom"), "the console's rider list runs past its foot (its bottom fade shows)")
	ok(fd.holder:GetFrameLevel() > D.ui.drive.scroll.content:GetFrameLevel() + 3, "the fade is above the rows")
	for _, name in ipairs({ "earnings", "messages", "crew", "customers", "blocked" }) do
		D.ShowScreen(name)
		w:advance(1)
		local s = (D.ui.subs and D.ui.subs[name]) or UI.drive.screens[name]
		ok(s and H.visible(s.frame), name .. " is open")
		ok(s.frame:GetFrameLevel() > fd.holder:GetFrameLevel(),
			name .. " is drawn over the console's fade (" .. s.frame:GetFrameLevel() .. " > " .. fd.holder:GetFrameLevel() .. ")")
	end
	D.ShowScreen("console")
	w:advance(1)
	-- Trips and the Wrapped story over it
	W.db.rides = {}
	for i = 1, 12 do
		W.db.rides[i] = { at = os.time({ year = 2026, month = 10, day = i, hour = 20 }), dest = "Undercity", driver = "Mia Runner",
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.RebuildTotals()
	UI.SelectTab("Trips")
	w:advance(1.5)
	local tf = UI.trips.clip.edgeFade
	ok(tf:Shown("bottom"), "Trips runs past its foot")
	local Wr = W.Mod("UI.Rider.Wrapped")
	ok(Wr.Open(2026, 10), "Wrapped opens")
	w:advance(1)
	local st = Wr.Story()
	ok(st:GetFrameLevel() > tf.holder:GetFrameLevel(), "the story is drawn over Trips' fade")
	Wr.Close()
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
end)

-- (round 9 previews) unfolded, the OpenMap hint sat on the World view's legend at the side pane's foot
test("r9 previews: unfolded Home - the OpenMap hint stays clear of the World view's legend", function()
	local w, c, W = scene()
	local UI = W.UI
	W.db.openMapHint = false
	fold(W, true)
	UI.Toggle(true)
	w:advance(3)
	UI.Show("home")
	w:advance(1)
	local WorldMod = W.Mod("UI.Rider.WorldMap")
	WorldMod.Show("world")
	w:advance(1)
	local hint = UI.state.screens.home.mapHint
	ok(H.visible(hint), "the hint shows (no OpenMap)")
	local wm
	for _, m in pairs(WorldMod.cache.maps) do if m.legend and m.view and H.visible(m.view) then wm = m end end
	ok(wm and #wm.legend == 4, "the World view and its legend")
	local hr = H.rect(hint)
	for _, fs in ipairs(wm.legend) do
		local r = H.rect(fs)
		ok(r.b + r.h <= hr.b or r.b >= hr.b + hr.h, "'" .. tostring(fs:GetText()) .. "' is not under the hint")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
end)

-- (round 13, I18) the check also fails on words the game cuts short with "...", and lets a label
-- that says its ellipsis is meant (fs.wuberEllipsis) or one that has the room pass
test("r13 I18: the check fails on a label cut short with '...', and passes once it has room", function()
	local w, c, W = scene()
	local env = c.env
	local v = env.CreateFrame("Frame", nil, env.UIParent)
	v:SetSize(300, 100)
	v:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	local fs = W.Theme.Text(v, 13, "white", "LEFT", "medium")
	fs:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0)
	fs:SetWidth(120)
	fs:SetText("Waiting for Mia to open trade...")
	local bad = check(c, "cut")
	eq(#bad, 1, "one cut label: " .. table.concat(bad, "; "))
	ok(bad[1] and bad[1]:find("cut short", 1, true), "it says so: " .. tostring(bad[1]))
	ok(fs:IsTruncated(), "the harness's font string says it is truncated")
	fs:SetWidth(290)
	eq(#check(c, "room"), 0, "with room: fine")
	ok(not fs:IsTruncated(), "not truncated now")
	-- two lines allowed, three needed
	local p = W.Theme.Text(v, 13, "white", "LEFT", "medium")
	p:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -40)
	p:SetWidth(100)
	p:SetWordWrap(true)
	p:SetMaxLines(2)
	p:SetText("One two three four five six seven eight nine ten eleven")
	eq(#check(c, "lines"), 1, "more lines than allowed")
	p.wuberEllipsis = "a test: the rest is in its tooltip"
	eq(#check(c, "allowed"), 0, "a label that says its ellipsis is meant passes")
	-- (round 13 review) a wrapping label held to a fixed height (no SetMaxLines): the height is the limit
	local q = W.Theme.Text(v, 13, "white", "LEFT", "medium")
	q:SetPoint("TOPLEFT", v, "TOPLEFT", 150, -40)
	q:SetWidth(100)
	q:SetWordWrap(true)
	q:SetHeight(18)
	q:SetText("One two three four five six seven")
	eq(#check(c, "height"), 1, "more lines than its height holds")
	q:SetHeight(80)
	eq(#check(c, "tall enough"), 0, "with the height for them: fine")
	T.clean(w)
end)

-- (round 13, I18) the reviewer's cut words, each with room now: the pay pill ('Waiting for Mia to open
-- tra...'), Earnings' top window ('Top window: 17:00-20:...'), the console's fare ('50s to
-- Orgrim...') and word, and the crew's add field ('Add by name (Name-Realm or Nam...'). (The
-- crew's shard counts, '14 sh...', are reworded by round 13's I10.)
test("r13 I18: the reviewer's cut words have room (pay, top window, fare, crew's add field)", function()
	local w, c, W = scene()
	local UI, D = W.UI, W.Driver
	local S = H.state
	local function find(text)
		for _, obj in ipairs(c.widgets) do
			local s = S[obj]
			if s and s.otype == "FontString" and s.text == text and H.visible(obj) then return obj end
		end
	end
	UI.Toggle(true)
	w:advance(3)
	-- the pay pill
	W.ride = { id = "r13", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = "arrived",
		at = c.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	W.Fire("RIDE")
	w:advance(1)
	UI.Show("found")
	w:advance(1)
	local pill = find("Waiting for Mia to trade")
	ok(pill, "the pay pill's words")
	ok(pill and not H.truncation(pill), "not cut")
	W.ride = nil
	W.Fire("RIDE")
	w:advance(1)
	-- the console: its word and fare
	W.Char().wizard = true
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	D.RefreshNow()
	w:advance(1)
	local v = D.ui.drive
	ok(v and v.fare and H.visible(v.fare.text), "the fare shows")
	eq(H.truncation(v.fare.text), nil, "the fare is not cut: " .. tostring(v.fare.text:GetText()))
	eq(H.truncation(v.status.word), nil, "the word is not cut: " .. tostring(v.status.word:GetText()))
	-- Earnings' top window: its words are never held to a width
	D.ShowScreen("earnings")
	w:advance(1)
	local s = (D.ui.subs and D.ui.subs.earnings) or UI.drive.screens.earnings
	s.top:Set("Top window: 17:00–20:00", "white")
	eq(H.textRoom(s.top.text), nil, "the top window's words are not held to a width")
	-- (design round 4, F) the tip is caption text now, not a pill: its label shows the whole sentence, is not cut, and sits inside the page
	eq(s.top.text:GetText(), "Top window: 17:00–20:00", "the label holds the whole sentence")
	eq(H.truncation(s.top.text), nil, "the top window's label is not cut")
	ok(s.top:GetWidth() >= W.Theme.MeasureText("Top window: 17:00–20:00", "caption", "regular") + 2, "its frame has room for the words")
	local rcv = s.top:GetParent()
	local pr = rcv and rcv.GetRight and rcv:GetRight()
	local tr = s.top:GetLeft() and (s.top:GetLeft() + s.top:GetWidth())
	ok(not pr or not tr or tr <= pr + 0.5, "the label sits inside the page (right edge " .. tostring(tr) .. " of " .. tostring(pr) .. ")")
	-- the crew's add field
	D.ShowScreen("crew")
	w:advance(1)
	local hint = find("Name or Name-Realm")
	ok(hint, "the add field's hint")
	ok(hint and not H.truncation(hint), "not cut")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)


-- (round 13, merged) every state round 13 changed, folded and unfolded, checked for cut words by the
-- same check: a crew of Warlocks with shards ('14 sh...' in a reviewer's shot), riders who want things,
-- raid summons with waits, the end-of-shift card, the row menu (Gifted), the Note sheet, Home's
-- chips and bounty, the world map's legend, Confirm by zeppelin, the portal, Trips and Settings'
-- Driving section ('Driving: riders and notes').
test("r13 I18: no words cut with '...' on any page round 13 changed (crew, raid waits, shift, Home, map, Confirm, portal)", function()
	local w, c, W = scene()
	local UI, D, DR = W.UI, W.Driver, W.Drive
	local bad, looked = {}, 0
	local function both(name, go)
		for _, wide in ipairs({ false, true }) do
			fold(W, wide)
			w:advance(1)
			local okGo, err = pcall(go)
			ok(okGo, name .. ": " .. tostring(err))
			w:advance(1)
			local where = name .. (wide and " unfolded" or " folded")
			for _, b in ipairs(check(c, where)) do bad[#bad + 1] = b end
			looked = looked + 1
		end
	end
	local t0, now = c.env.time(), c.env.GetTime()
	local cs = {
		{ name = "Dan Rider", key = "dan rider", state = "joined", source = "whisper", at = now - 40, price = 5000, paid = 0 },
		{ name = "Eve Night", key = "eve night", state = "arrived", source = "wuber", wuberRide = "abcdef", at = now - 300, price = 5000, paid = 0 },
		{ name = "Gus Hill", key = "gus hill", state = "lead", wantsPrice = true, source = "public", at = now - 20, price = 5000, paid = 0 },
		{ name = "Ivy Moss", key = "ivy moss", state = "queued", source = "whisper", at = now - 30, price = 5000, paid = 0 },
	}
	local open = true
	DR.Shards = function() return 12 end
	DR.Sorted = function() return open and cs or {} end
	DR.customers = {}
	for _, x in ipairs(cs) do DR.customers[x.key] = x end
	DR.IsOpen = function() return open end
	DR.Crew = function()
		return { { name = "Wuber TestCharacter", key = W.myKey, role = "lock", app = true, me = true, here = true, captain = true, shards = 12 },
			{ name = "Vex Shade", key = "vex shade", role = "lock", app = true, here = true, shards = 14 },
			{ name = "Nyla Dusk", key = "nyla dusk", role = "lock", app = true, here = false, shards = 9 },
			{ name = "Bea Jones", key = "bea jones", role = "helper", app = true, here = true } }
	end
	W.Bounty = W.Bounty or {}
	W.Bounty.Demand = function()
		return { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 120 },
			{ place = "Booty Bay", riders = 1, low = 7500, high = 7500, newest = 30 } }
	end
	W.FlightCost = function() return 2300, 1 end
	W.TravelSaved = function() return 300, "by zeppelin" end
	W.Char().wizard = true
	local function closeSheets()
		local ui = D.ui
		if not ui or not ui.sheets then return end
		for _, s in pairs(ui.sheets) do if s.frame.open then s.frame:Close(true) end end
	end
	UI.Toggle(true)
	w:advance(3)
	-- the rider's side
	both("home chips", function() UI.Show("home") end)
	both("world map", function() UI.Show("home") w:advance(1) W.Mod("UI.Rider.WorldMap").Show("world") end)
	pcall(W.Mod("UI.Rider.WorldMap").Show, "here")
	both("home bounty", function()
		W.Bounty.Mine = function() return { place = "Gadgetzan", copper = 5000, at = c.env.time() - 120, left = 1680 } end
		UI.Show("home") w:advance(1)
		UI.SetSearch("Gadgetzan") w:advance(1)
		UI.Refresh(true)
	end)
	W.Bounty.Mine = function() return nil end
	pcall(UI.SetSearch, "")
	both("confirm by zeppelin", function() UI.Show("confirm", "mia runner") end)
	both("portal", function()
		W.ride = { id = "p13", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = "portal",
			portalUp = true, at = now, payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
		W.Fire("RIDE") w:advance(1)
		UI.Show("found")
	end)
	both("summoning", function()
		W.ride.state = "summoning"
		W.Fire("RIDE") w:advance(1)
		UI.Show("found")
	end)
	W.ride = nil
	W.Fire("RIDE")
	w:advance(1)
	both("trips", function() UI.Show("home") w:advance(1) UI.SelectTab("Trips") w:advance(2) end)
	both("settings driving", function() UI.OpenSettings("driving") end)
	UI.CloseSettings(true)
	w:advance(1)
	-- the driver's side
	local function console() closeSheets() D.ShowScreen("console") w:advance(1) D.RefreshNow() end
	both("console with riders", function() UI.SelectTab("Drive") w:advance(1) open = true console() end)
	local chip
	for _, obj in ipairs(c.widgets) do
		local s = H.state[obj]
		if s and s.otype == "FontString" and type(s.text) == "string" and s.text:find("14 shards", 1, true) and H.visible(obj) then chip = obj end
	end
	ok(chip, "the crew's chips show, so the check covers them (Vex: 14 shards)")
	both("console closed", function() open = false console() end)
	both("row menu", function() open = true console() D.OpenMenu(cs[1]) end)
	both("row menu (app)", function() console() D.OpenMenu(cs[2]) end)
	both("note", function() console() D.ShowSheet("note", cs[1]) end)
	both("crew", function() closeSheets() D.ShowScreen("crew") end)
	both("customers", function() closeSheets() D.ShowScreen("customers") end)
	both("shift card", function()
		open = false
		console()
		local me = W.myKey
		D.lastShift = { rides = 7, copper = 31000, tips = 0, open = 7200, crewRides = 2, crewCopper = 10000, at = t0, bestHour = 20,
			bestCopper = 15000, cut = { rule = "clicks", pct = 40, rows = { { key = me, name = "Wuber TestCharacter", casts = 7, clicks = 0, share = 21000 },
				{ key = "vex shade", name = "Vex Shade", casts = 2, clicks = 1, share = 12000 },
				{ key = "nyla dusk", name = "Nyla Dusk", casts = 0, clicks = 8, share = 8000 } } } }
		D.ShowSheet("shift")
	end)
	both("raid waits", function()
		open = true
		closeSheets()
		D.ShowScreen("console") w:advance(1)
		DR.SetMode("raid") w:advance(1)
		DR.RaidQueue = function()
			return { { name = "Dan Rider", asked = now - 30, state = "queued", tries = 0 },
				{ name = "Gus Hill", asked = now - 50, state = "summoning", claimedBy = W.myKey, tries = 0 },
				{ name = "Ivy Moss", asked = now - 70, state = "queued", tries = 1 } }
		end
		D.RefreshNow()
	end)
	local wait
	for _, obj in ipairs(c.widgets) do
		local s = H.state[obj]
		if s and s.otype == "FontString" and type(s.text) == "string" and s.text:match("^%d+:%d%d$") and s.text ~= "0:00" and H.visible(obj) then wait = s.text end
	end
	ok(wait, "the raid rows show their waits (as '0:30'), so the check covers them")
	both("raid pick", function() pcall(D.ShowScreen, "raidpick") end)
	ok(looked >= 36, "every state was looked at, folded and unfolded (" .. looked .. ")")
	eq(#bad, 0, "words cut short:\n  " .. table.concat(bad, "\n  "))
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
