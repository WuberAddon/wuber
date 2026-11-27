-- Design round 4, group C (audit item 16): the tab bar hides while the rider's live ride is the page on screen, the ride
-- page uses the room the bar leaves, and a back chevron leads out to Home with the tabs (the ride carries on; the black
-- pill is the way back in). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local LIVE = { "accepted", "invited", "ingroup", "summoning", "portal", "arrived", "paying" }

local function open(opts, who, asDriver)
	local w = T.newWorld()
	local r
	if asDriver then
		r = T.driver(w, who or T.ANITA, opts or { spot = "Orgrimmar", screenW = 1024, screenH = 768 })
	else
		r = T.rider(w, who or T.TESTCHAR, opts or { screenW = 1024, screenH = 768 })
	end
	T.settle(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, t, secs)
	local base = { id = "d4c", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted",
		at = r.env.GetTime(), service = "Bea's Rides" }
	for k, v in pairs(t or {}) do base[k] = v end
	r.W.ride = base
	r.W.Fire("RIDE")
	r.W.UI.RefreshNow()
	w:advance(secs or 2)
end

local function near(a, b, x) return math.abs(a - b) <= (x or 0.6) end

-- a table as one line of text, keys in order (the ride before and after)
local function dump(v, seen)
	if type(v) ~= "table" then return tostring(v) end
	seen = seen or {}
	if seen[v] then return "<again>" end
	seen[v] = true
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	local out = {}
	for _, k in ipairs(keys) do
		local val = v[k]
		if val == nil then val = v[tonumber(k)] end
		out[#out + 1] = k .. "=" .. dump(val, seen)
	end
	return "{" .. table.concat(out, ",") .. "}"
end

local function tabOf(ui, name)
	for _, tab in ipairs(ui.tabs) do if tab.name == name then return tab.button end end
end

-- counts the calls that move, show or hide a frame from now on
local function watch(f)
	local calls = { SetPoint = 0, ClearAllPoints = 0, Show = 0, Hide = 0, SetAlpha = 0, SetSize = 0 }
	for name in pairs(calls) do
		local real = f[name]
		f[name] = function(self, ...)
			calls[name] = calls[name] + 1
			return real(self, ...)
		end
	end
	return calls
end

test("d4 c: the tab bar is hidden on every live ride state and shows on Home, Finding, Done, Sorry, Trips and Drive", function()
	local w, r, ui, UI = open()
	eq(type(UI.TabsHidden), "function", "UI.TabsHidden exists")
	ok(H.visible(ui.tabbar) and not UI.TabsHidden(), "no ride, Home: the tab bar shows")
	ride(r, w, { state = "requesting" })
	eq(ui.screen, "finding", "asking: the Finding screen")
	ok(H.visible(ui.tabbar) and not UI.TabsHidden(), "Finding (no driver yet): the tab bar shows")
	for _, st in ipairs(LIVE) do
		ride(r, w, { state = st })
		eq(ui.screen, "found", st .. ": the ride page")
		ok(not H.visible(ui.tabbar), st .. ": the tab bar is hidden")
		ok(UI.TabsHidden(), st .. ": UI.TabsHidden() says so")
		for _, tab in ipairs(ui.tabs) do ok(not H.visible(tab.button), st .. ": no " .. tab.name .. " button to click") end
	end
	-- another tab during the ride (UI.SelectTab, as /wuber drive does), and the pill back in
	for _, name in ipairs({ "Trips", "Drive" }) do
		eq(UI.SelectTab(name), true, name .. " opens during a ride")
		w:advance(1)
		ok(H.visible(ui.tabbar) and not UI.TabsHidden(), name .. " during a ride: the tab bar shows")
		ui.phone.island:Click()
		w:advance(1)
		eq(ui.screen, "found", "the pill opens the ride from " .. name)
		ok(not H.visible(ui.tabbar), "and the tab bar hides again")
	end
	-- Settings over the ride page: the bar is back under it
	UI.OpenSettings()
	w:advance(1)
	ok(ui.settingsOpen and H.visible(ui.tabbar), "Settings during a ride: the tab bar shows")
	UI.CloseSettings()
	w:advance(1)
	ok(not H.visible(ui.tabbar), "Settings closed on the ride page: hidden again")
	ride(r, w, { state = "done", paid = true })
	eq(ui.screen, "done", "the ride ended: Done")
	ok(H.visible(ui.tabbar) and not UI.TabsHidden(), "Done: the tab bar shows")
	ride(r, w, { id = "d4c2", state = "declined" })
	eq(ui.screen, "sorry", "a ride that failed: Sorry")
	ok(H.visible(ui.tabbar), "Sorry: the tab bar shows")
	UI.Dismiss()
	w:advance(1)
	eq(ui.screen, "home", "back on the empty Ride screen")
	ok(H.visible(ui.tabbar), "the empty Ride screen: the tab bar shows")
	eq(ui.tabbar:GetAlpha(), 1, "drawn solid")
	ok(near(ui.tabbar:GetBottom(), ui.win:GetBottom()), "at its place")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 c: the bar drops by its height and fades in 0.28 s, and comes back the same way", function()
	local w, r, ui, UI = open()
	r.W.db.reduceMotion = false
	local bar, win = ui.tabbar, ui.win
	ride(r, w, { state = "requesting" })
	r.W.ride.state = "accepted"
	UI.RefreshNow()
	eq(ui.screen, "found", "the ride page")
	ok(bar:IsShown() and near(bar:GetBottom(), win:GetBottom(), 2) and bar:GetAlpha() > 0.9, "it starts where it was")
	w:advance(0.1)
	local drop = win:GetBottom() - bar:GetBottom()
	ok(drop > 5 and drop < 56, "half-way it is part of the way down: " .. drop)
	ok(bar:GetAlpha() < 1 and bar:GetAlpha() > 0, "and part faded: " .. bar:GetAlpha())
	w:advance(0.1)
	ok(bar:IsShown(), "still on its way at 0.2 s")
	w:advance(0.1)
	ok(not bar:IsShown(), "gone at 0.3 s (0.28 s)")
	ok(near(win:GetBottom() - bar:GetBottom(), 56), "a whole bar's height down")
	-- back
	UI.Show("home")
	ok(bar:IsShown(), "Home: it is on its way back at once")
	w:advance(0.1)
	drop = win:GetBottom() - bar:GetBottom()
	ok(drop > 0 and drop < 51, "half-way back up: " .. drop)
	w:advance(0.4)
	ok(near(bar:GetBottom(), win:GetBottom()) and bar:GetAlpha() == 1, "in its place, solid")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 c: Reduce motion: the bar fades for a moment and never travels", function()
	local w, r, ui, UI = open()
	r.W.db.reduceMotion = true
	local bar, win = ui.tabbar, ui.win
	ride(r, w, { state = "requesting" })
	r.W.ride.state = "accepted"
	UI.RefreshNow()
	w:advance(0.05)
	ok(bar:IsShown() and bar:GetAlpha() < 1, "fading: " .. bar:GetAlpha())
	ok(near(bar:GetBottom(), win:GetBottom()), "in place while it fades")
	w:advance(0.1)
	ok(not bar:IsShown(), "gone after 0.12 s")
	UI.Show("home")
	w:advance(0.05)
	ok(bar:IsShown() and near(bar:GetBottom(), win:GetBottom()), "back: in place from the start")
	ok(bar:GetAlpha() < 1, "fading in")
	w:advance(0.2)
	eq(bar:GetAlpha(), 1, "solid")
	T.clean(w)
end)

test("d4 c: the ride page uses the room: its main button stands where the bar's foot was, the link above it", function()
	local w, r, ui, UI = open()
	local Th = r.W.Theme
	local body, win = UI.GetTab("Ride"), ui.win
	ok(near(body:GetHeight(), 544), "Home: the body ends at the tab bar: " .. body:GetHeight())
	for _, st in ipairs(LIVE) do
		ride(r, w, { state = st })
		local s = ui.screens.found
		ok(near(body:GetHeight(), 600), st .. ": the ride page has the whole screen: " .. body:GetHeight())
		ok(near(body:GetBottom(), win:GetBottom()), st .. ": down to the phone's foot")
		ok(H.visible(s.action), st .. ": the main button shows")
		ok(near(s.action:GetBottom() - win:GetBottom(), Th.MAIN.foot), st .. ": the main button's foot is " .. Th.MAIN.foot .. " above the phone's foot: "
			.. (s.action:GetBottom() - win:GetBottom()))
		for _, link in ipairs({ s.cancel, s.endRide }) do
			if H.visible(link) then
				ok(link:GetBottom() >= s.action:GetBottom() + s.action:GetHeight() + 4, st .. ": the link is above the main button")
				ok(link:GetBottom() - win:GetBottom() < 80, st .. ": and came down with it")
			end
		end
	end
	UI.Show("home")
	w:advance(1)
	ok(near(body:GetHeight(), 544), "Home during the ride: the body ends at the tab bar again")
	local hf = ui.screens.home.frame
	ok(hf:GetBottom() >= ui.tabbar:GetBottom() + ui.tabbar:GetHeight() - 0.6, "Home ends over the bar, not under it")
	T.clean(w)
end)

-- one run of "a ride, then (maybe) Back": the ride as text, the count of addon messages and of whispers
local function backRun(click)
	local w, r, ui, UI = open()
	ride(r, w, { state = "ingroup" })
	local s = ui.screens.found
	local before = dump(r.W.ride)
	local n0, w0 = #w.addonLog, #w.whispers
	if click then r:clickOn(s.back) end
	local now = { ride = dump(r.W.ride), msgs = #w.addonLog - n0, whispers = #w.whispers - w0, screen = ui.screen }
	w:advance(3)
	local out = { before = before, now = now, ride = dump(r.W.ride), msgs = #w.addonLog - n0, whispers = #w.whispers - w0 }
	return w, r, ui, UI, out
end

test("d4 c: the ride page has the pushed pages' back chevron; Back shows Home with the tabs and the ride carries on untouched", function()
	local w0, _, _, _, plain = backRun(false)
	T.clean(w0)
	local w, r, ui, UI, got = backRun(true)
	local s = ui.screens.found
	ok(s.back ~= nil, "the ride page has a back chevron")
	local like = ui.screens.confirm.back
	eq(s.back:GetWidth(), like:GetWidth(), "as large as Confirm's")
	eq(s.back.wuberTip and s.back.wuberTip.title, like.wuberTip.title, "the same tooltip title")
	eq(s.back.wuberTip and s.back.wuberTip.text, like.wuberTip.text, "the same tooltip words")
	eq(got.now.screen, "home", "Back: Home")
	eq(got.now.ride, got.before, "the click changed nothing in the ride")
	eq(got.now.msgs, 0, "the click sent no addon message")
	eq(got.now.whispers, 0, "and no whisper")
	eq(got.ride, got.before, "three seconds on the ride is still the same")
	eq(got.ride, plain.ride, "and the same as with no click")
	eq(got.msgs, plain.msgs, "as many addon messages as with no click")
	eq(got.whispers, plain.whispers, "as many whispers as with no click")
	eq(ui.screen, "home", "still on Home")
	ok(H.visible(ui.tabbar) and not UI.TabsHidden(), "with the tabs")
	ok(ui.phone.island:IsMouseEnabled() and ui.phone.island:GetWidth() > 92, "the pill is alive: the way back in")
	-- the router lets the rider go anywhere while the ride runs
	for _, name in ipairs({ "Trips", "Drive", "Ride" }) do
		r:clickOn(tabOf(ui, name))
		w:advance(1)
		eq(ui.tab, name, "a click on " .. name .. " during the ride")
		ok(H.visible(UI.GetTab(name)), name .. "'s page shows")
	end
	eq(ui.screen, "home", "Ride again: still Home (the look lasts until the ride's next step)")
	ok(H.visible(ui.gear), "the cog is there on Home")
	r:clickOn(ui.gear)
	w:advance(1)
	ok(ui.settingsOpen, "Settings opens during the ride")
	UI.CloseSettings()
	w:advance(1)
	-- the pill, from Home after Back
	ui.phone.island:Click()
	w:advance(1)
	eq(ui.screen, "found", "the pill opens the ride page from Home")
	ok(not H.visible(ui.tabbar), "and the tabs hide again")
	eq(dump(r.W.ride), got.before, "the ride is still the same")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 c: the chevron stands at the top left, clear of the route, the title, the warning and the window's x, in every state", function()
	local w, r, ui, UI = open()
	local s = ui.screens.found
	for _, st in ipairs(LIVE) do
		ride(r, w, { state = st })
		ok(s.back and H.visible(s.back), st .. ": the chevron shows")
		local b, win, x = H.rect(s.back), H.rect(ui.win), H.rect(ui.close)
		ok(b.l - win.l < 20 and (win.b + win.h) - (b.b + b.h) < 16, st .. ": top left")
		ok(b.b >= win.b + win.h - UI.HEAD_H - 0.5, st .. ": inside the header zone")
		ok(b.l + b.w <= x.l, st .. ": left of the x")
		for name, obj in pairs({ route = s.route, title = s.title, chip = s.tier, warning = s.alert }) do
			if H.visible(obj) then
				local o = H.rect(obj)
				local apart = o.l >= b.l + b.w - 0.5 or o.b + o.h <= b.b + 0.5 or o.b >= b.b + b.h - 0.5
				ok(apart, st .. ": the " .. name .. " keeps clear of the chevron (" .. o.l .. " against " .. (b.l + b.w) .. ")")
			end
		end
		if s.mode == "live" then
			-- the route has the row under the chevron to itself, from the page's left edge: the chevron costs it nothing
			local o = H.rect(s.route)
			ok(H.visible(s.route) and o.b + o.h <= b.b + 0.5, st .. ": the route is on the row under the chevron")
			local k = win.w / 360 -- H.rect is in screen units: the window's scale
			ok(near((o.l - win.l) / k, 18, 1), st .. ": from the page's left edge: " .. ((o.l - win.l) / k))
			ok(o.b >= H.rect(s.bar).b - 0.5, st .. ": inside the dark bar")
		end
	end
	T.clean(w)
end)

test("d4 c: the level chip keeps both its words beside the chevron, and a long route is whole under it", function()
	local w, r, ui, UI = open()
	local s = ui.screens.found
	r.W.Tier = function() return 2 end
	r.env.GetRealZoneText = function() return "Stranglethorn Vale" end
	r.env.GetZoneText = r.env.GetRealZoneText
	ride(r, w, { state = "summoning", dest = "Feathermoon Stronghold" })
	ok(H.visible(s.tier), "the level chip shows")
	local words = {}
	for _, reg in ipairs({ s.tier:GetRegions() }) do
		if reg.GetText and reg:IsVisible() and (reg:GetText() or "") ~= "" then words[#words + 1] = reg:GetText() end
	end
	local text = table.concat(words, " ")
	ok(text:find("rider", 1, true) ~= nil, "it says the level and 'rider', not the short form: " .. text)
	local c, b, x, o = H.rect(s.tier), H.rect(s.back), H.rect(ui.close), H.rect(s.route)
	ok(c.l >= b.l + b.w and c.l + c.w <= x.l, "between the chevron and the x")
	local win = H.rect(ui.win)
	ok((o.l + o.w - win.l) / (win.w / 360) <= 360 - 17, "the route ends inside the page: " .. ((o.l + o.w - win.l) / (win.w / 360)))
	for _, reg in ipairs({ s.route:GetRegions() }) do
		if reg.IsTruncated and reg:IsVisible() then ok(not reg:IsTruncated(), "no part of the route is cut: " .. tostring(reg:GetText())) end
	end
	T.clean(w)
end)

test("d4 c: the ride's next step still brings the ride forward from Home, as before", function()
	local w, r, ui, UI = open()
	ride(r, w, { state = "accepted" })
	r:clickOn(ui.screens.found.back)
	w:advance(1)
	eq(ui.screen, "home", "Home after Back")
	UI.RefreshNow()
	w:advance(3)
	eq(ui.screen, "home", "it stays Home while nothing happens")
	r.W.ride.state = "invited"
	r.W.Fire("RIDE")
	w:advance(1)
	eq(ui.screen, "found", "a new step: the ride page comes forward")
	ok(not H.visible(ui.tabbar), "and the tabs hide")
	T.clean(w)
end)

test("d4 c: a driver riding in someone else's car reaches the console through Back and the Drive tab", function()
	local w, d, ui, UI = open(nil, T.ANITA, true)
	ride(d, w, { state = "summoning", driver = "Mia Runner", driverKey = "mia runner" })
	eq(ui.tab, "Ride", "on the Ride tab")
	eq(ui.screen, "found", "on the ride page")
	ok(not H.visible(ui.tabbar), "no tabs on the ride page")
	local before = dump(d.W.ride)
	d:clickOn(ui.screens.found.back)
	w:advance(1)
	ok(H.visible(tabOf(ui, "Drive")), "Back: the Drive tab is there")
	d:clickOn(tabOf(ui, "Drive"))
	w:advance(1)
	eq(ui.tab, "Drive", "the Drive tab opens")
	ok(H.visible(UI.GetTab("Drive")), "the console's page shows")
	ok(H.visible(ui.tabbar), "with the tabs")
	eq(dump(d.W.ride), before, "the ride is untouched")
	ui.phone.island:Click()
	w:advance(1)
	eq(ui.tab, "Ride", "the pill: back on the Ride tab")
	eq(ui.screen, "found", "on the ride page")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 c: the wide window: the ride page is one pane wide with no tabs; Home during the ride has the bar across the window", function()
	local w, r, ui, UI = open({ screenW = 1920, screenH = 1080, wide = true })
	r.wide = true
	UI.Fold.Apply()
	w:advance(1)
	ride(r, w, { state = "portal" })
	eq(ui.screen, "found", "the ride page")
	eq(ui.win:GetWidth(), 360, "the ride page is folded")
	ok(not H.visible(ui.tabbar), "no tabs")
	r:clickOn(ui.screens.found.back)
	w:advance(2)
	eq(ui.screen, "home", "Home")
	ok(H.visible(ui.tabbar), "the tabs are back")
	ok(near(ui.tabbar:GetWidth(), ui.win:GetWidth()), "across the window, whatever its width: " .. ui.win:GetWidth())
	ok(near(ui.tabbar:GetBottom(), ui.win:GetBottom()), "at the bottom")
	T.clean(w)
end)

test("d4 c: in combat the bar may hide and show; no secure button sits on it, on the page, or is touched", function()
	local w, r, ui, UI = open()
	local body = UI.GetTab("Ride")
	local n = 0
	for name, b in pairs(UI.secure) do
		n = n + 1
		local p = b:GetParent()
		while p do
			ok(p ~= ui.tabbar and p ~= body and p ~= ui.win, name .. " is not inside the bar, the page or the window")
			p = p:GetParent()
		end
	end
	ok(n >= 3, "the secure buttons were looked at")
	ride(r, w, { state = "requesting" })
	w.violations = {}
	w:enterCombat(r)
	w:advance(1)
	local calls = {}
	for name, b in pairs(UI.secure) do calls[name] = watch(b) end
	r.W.ride.state = "accepted"
	r.W.Fire("RIDE")
	w:advance(1)
	eq(ui.screen, "found", "the ride page in a fight")
	ok(not H.visible(ui.tabbar), "the bar hides in a fight")
	r:clickOn(ui.screens.found.back)
	w:advance(1)
	eq(ui.screen, "home", "Back in a fight")
	ok(H.visible(ui.tabbar), "the bar shows in a fight")
	ui.phone.island:Click()
	w:advance(1)
	ok(not H.visible(ui.tabbar), "and hides again")
	for name, c in pairs(calls) do
		eq(c.SetPoint + c.ClearAllPoints + c.Show + c.Hide + c.SetAlpha + c.SetSize, 0, name .. " was not moved, shown, hidden or sized in the fight")
	end
	eq(#w.violations, 0, "nothing protected was touched: " .. table.concat(w.violations, "; "))
	w:leaveCombat(r)
	w:advance(2)
	-- after the fight the Cancel overlay lies on the Cancel link where it stands now
	local s, b = ui.screens.found, r.env.WuberCancelButton
	if H.visible(s.cancel) and b:IsShown() then
		local a, c = H.rect(s.cancel), H.rect(b)
		ok(near(a.l, c.l, 1) and near(a.b, c.b, 1), "the Cancel overlay is on the link's new place")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 c: the layout sweep has the two scenes: the ride with the tabs hidden, and Home during a ride", function()
	local f = io.open("tests/layout/d4_c_screens.lua", "r")
	ok(f ~= nil, "tests/layout/d4_c_screens.lua exists")
	local text = f and f:read("*a") or ""
	if f then f:close() end
	ok(text:find('"d4c_ride_tabs"', 1, true), "the scene d4c_ride_tabs")
	ok(text:find('"d4c_home_ride"', 1, true), "the scene d4c_home_ride")
	local x = io.open("tests/layout/extra_screens.lua", "r")
	local xt = x and x:read("*a") or ""
	if x then x:close() end
	ok(xt:find("d4_c_screens.lua", 1, true), "installed by tests/layout/extra_screens.lua")
end)

test("d4 c e3b-09: sheets and cards rest on the phone's foot when the tab bar is hidden, and on the tab bar when visible", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	local W = r.W
	local UI, ui = W.UI, W.UI.state
	local Tips = W.Mod("UI.Tips")
	local rcOffer = { id = "rc-e3b09", state = "offered", driver = "Anita Lift", cover = 5000,
		expires = os.time({ year = 2026, month = 11, day = 28, hour = 12, min = 0, sec = 0 }) }
	W.Raincheck.Mine = function() return { rcOffer } end
	UI.Toggle(true)
	for _ = 1, 400 do
		if ui.coach and ui.coaching then break end
		w:advance(0.05)
	end
	w:advance(1)
	local win = ui.win
	local wb = win:GetBottom()
	local tabH = UI.TABBAR_H or 56

	-- 1. Tabs visible (Home): Coach, Tips, Moments, Bug all rest on the tab bar
	ok(not UI.TabsHidden(), "Home: tabs are visible")
	ok(ui.coach and H.visible(ui.coach), "Coach bubble is shown on Home")
	ok(near(ui.coach:GetBottom(), wb + tabH + 8), "Coach rests 8 above the tab bar when tabs are visible")
	UI.EndCoach()
	w:advance(1)

	ok(Tips.ShowNow(), "Tips opens on Home")
	w:advance(1)
	local tipCard = r.env.WuberTipCard
	ok(tipCard and H.visible(tipCard), "Tips card is visible on Home")
	ok(near(tipCard:GetBottom(), wb + tabH), "Tips rests on the tab bar when tabs are visible")

	local rc = UI.RaincheckOffer()
	w:advance(1)
	ok(rc and H.visible(rc), "Raincheck sheet opens on Home")
	ok(near(rc:GetParent():GetBottom(), wb + tabH), "Raincheck rests on the tab bar when tabs are visible")
	rc:Close(true)
	w:advance(1)

	ok(UI.Bug.Open(), "Bug opens on Home")
	w:advance(1)
	ok(near(UI.Bug.frame.holder:GetBottom(), wb + tabH), "Bug holder rests on the tab bar when tabs are visible")
	UI.Bug.Close()
	w:advance(1)

	-- Tips re-anchors when switching between Home (tabs visible) and live ride (tabs hidden)
	ok(Tips.ShowNow(), "Tips opens again on Home")
	w:advance(1)
	ok(H.visible(tipCard), "Tips card visible on Home")
	ok(near(tipCard:GetBottom(), wb + tabH), "Tips rests on tab bar before ride")
	r.W.ride = { id = "d4c", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted",
		at = r.env.GetTime(), service = "Bea's Rides" }
	UI.RefreshNow()
	ok(UI.TabsHidden(), "on live ride page: tabs hidden")
	ok(H.visible(tipCard), "Tips card still visible")
	ok(near(tipCard:GetBottom(), wb), "Tips re-anchors to phone foot when tabs hide")
	-- the page slides in; the player presses the arrow once it has landed (the tip closes by itself within a moment of the live ride showing, before the arrow lands)
	local back = ui.screens.found.back
	for _ = 1, 40 do
		if r:topAt(back) == back then break end
		w:advance(0.05)
	end
	ok(r:topAt(back) == back, "the back arrow has slid into reach")
	r:clickOn(ui.screens.found.back)
	ok(not UI.TabsHidden(), "back on Home during ride: tabs visible")
	-- a tip is a Home card: it is gone by the time the player can press the arrow (at any step size), so there is nothing to
	-- re-anchor (its rest on the tab bar is checked above, before the ride)
	ok(not H.visible(tipCard), "the tip closed itself while the live ride showed")
	Tips.Hide()
	w:advance(1)

	-- 2. Live ride page (tabs hidden): Bug, Moments, Coach rest on the phone's foot
	ride(r, w, { state = "accepted" })
	ok(UI.TabsHidden(), "live ride page: tabs are hidden")

	-- Bug on live ride page, and switching to Settings (tabs back) and back to ride (tabs hidden)
	ok(UI.Bug.Open(), "Bug opens on live ride page")
	w:advance(1)
	ok(near(UI.Bug.frame.holder:GetBottom(), wb), "Bug holder rests on phone foot when tabs are hidden")
	UI.OpenSettings()
	w:advance(1)
	ok(not UI.TabsHidden(), "Settings over live ride: tabs visible")
	ok(near(UI.Bug.frame.holder:GetBottom(), wb + tabH), "Bug holder re-anchors to tab bar when Settings opens")
	UI.CloseSettings()
	w:advance(1)
	ok(UI.TabsHidden(), "Settings closed: tabs hidden again")
	ok(near(UI.Bug.frame.holder:GetBottom(), wb), "Bug holder re-anchors to phone foot when Settings closes")
	UI.Bug.Close()
	w:advance(1)

	-- Moments (Raincheck) on live ride page, and switching to Settings and back
	ui.rcSeen = {}
	rc = UI.RaincheckOffer()
	w:advance(1)
	ok(rc and H.visible(rc), "Raincheck opens on live ride page")
	ok(near(rc:GetParent():GetBottom(), wb), "Raincheck rests on phone foot when tabs are hidden")
	UI.OpenSettings()
	w:advance(1)
	ok(near(rc:GetParent():GetBottom(), wb + tabH), "Raincheck re-anchors to tab bar when Settings opens")
	UI.CloseSettings()
	w:advance(1)
	ok(near(rc:GetParent():GetBottom(), wb), "Raincheck re-anchors to phone foot when Settings closes")
	rc:Close(true)
	w:advance(1)

	-- Coach while tabs are hidden (point tip 5 at the top-right close button so the bubble sits at the bottom)
	local origTarget = UI.COACH[5].target
	UI.COACH[5].target = function() return ui.close end
	ui.coaching = true
	UI.CoachStep(5)
	UI.COACH[5].target = origTarget
	ok(ui.coach and ui.coach:IsShown(), "Coach bubble shown")
	ok(near(ui.coach:GetBottom(), wb + 8), "Coach rests 8 above phone foot when tabs are hidden")

	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
