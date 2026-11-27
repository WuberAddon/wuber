-- Design round 2, group C: the tabs in a bar at the bottom with icons, three tabs and a cog at the top right, no top
-- bar. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function openWindow(wide)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, wide and { screenW = 1920, screenH = 1080 } or { screenW = 1024, screenH = 768 })
	r.wide = wide and true or nil
	T.settle(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

-- a frame's or a region's place in the window's own units
local function rect(f) return { l = f:GetLeft(), b = f:GetBottom(), w = f:GetWidth(), h = f:GetHeight() } end

local function near(a, b, x) return math.abs(a - b) <= (x or 0.6) end

local function colourIs(Th, r, g, b, name)
	local cr, cg, cb = Th.RGB(name)
	return math.abs(r - cr) + math.abs(g - cg) + math.abs(b - cb) < 0.03
end

local function isGold(r, g, b)
	return type(r) == "number" and r > 0.85 and g > 0.6 and g < 0.9 and b < 0.5
end

local function tabOf(ui, name)
	for _, tab in ipairs(ui.tabs) do if tab.name == name then return tab.button end end
end

test("d2 c: the tabs are in a 56-high bar at the bottom of the screen, a glyph over the word, a third of the width each", function()
	local w, r, ui, UI = openWindow()
	local win = rect(ui.win)
	eq(UI.TABBAR_H, 56, "UI.TABBAR_H")
	eq(UI.HEAD_H, 56, "UI.HEAD_H")
	ok(ui.tabbar and H.visible(ui.tabbar), "the tab bar is up")
	local bar = rect(ui.tabbar)
	ok(near(bar.h, 56), "56 high: " .. bar.h)
	ok(near(bar.b, win.b), "at the bottom of the screen")
	ok(near(bar.w, win.w), "as wide as the screen")
	eq(#ui.tabs, 3, "three tabs")
	local names = {}
	for i, tab in ipairs(ui.tabs) do
		names[i] = tab.name
		local b = tab.button
		local br = rect(b)
		ok(H.visible(b), tab.name .. " shows")
		ok(near(br.w, 120), tab.name .. " is a third of 360 wide: " .. br.w)
		ok(near(br.l, win.l + (i - 1) * 120), tab.name .. " is in place " .. i)
		ok(br.b >= bar.b - 0.5 and br.b + br.h <= bar.b + bar.h + 0.5, tab.name .. " is inside the bar")
		ok(b.glyph and H.visible(b.glyph), tab.name .. " has a glyph")
		local gr, lr = rect(b.glyph), rect(b.label)
		ok(gr.w >= 20 and gr.w <= 24, tab.name .. "'s glyph is about 22: " .. gr.w)
		ok(gr.b >= lr.b + lr.h - 0.5, tab.name .. "'s glyph is over its word")
		eq(b.label:GetText(), tab.name, "the word is the tab's name")
		ok(b.wuberTip ~= nil, tab.name .. " has a tooltip")
	end
	eq(table.concat(names, " "), "Ride Trips Drive", "Ride, Trips, Drive")
	-- the body is above the bar, from the top of the screen, as high as before
	local body = rect(UI.GetTab("Ride"))
	ok(near(body.b + body.h, win.b + win.h), "the body starts at the top of the screen")
	ok(near(body.h, 544), "and keeps its height: " .. body.h)
	ok(near(body.b, bar.b + bar.h), "it ends where the tab bar starts")
	T.clean(w)
end)

test("d2 c: no tab and no logo in the top strip, which still drags the window", function()
	local w, r, ui = openWindow()
	local win = rect(ui.win)
	for _, tab in ipairs(ui.tabs) do
		local br = rect(tab.button)
		ok(br.b + br.h <= win.b + 56.5, tab.name .. " is not at the top")
		ok(tab.button:GetParent() ~= ui.top, tab.name .. " is not in the top strip")
	end
	ok(ui.logo == nil, "no logo")
	local drawn = 0
	for _, t in ipairs({ ui.top:GetRegions() }) do
		if t:IsVisible() then drawn = drawn + 1 end
	end
	eq(drawn, 0, "the top strip draws nothing of its own (no fill, no logo)")
	ok(type(ui.top:GetScript("OnDragStart")) == "function", "it is still the handle")
	local tr = rect(ui.top)
	ok(near(tr.h, 56) and near(tr.b + tr.h, win.b + win.h), "56 high at the top")
	T.clean(w)
end)

test("d2 c: the chosen tab has a violet glyph and a violet word, the others are grey; no pill", function()
	local w, r, ui, UI = openWindow()
	local Th = r.W.Theme
	local function check(want, when)
		eq(ui.tab, want, when .. ": the open tab")
		for _, tab in ipairs(ui.tabs) do
			local b = tab.button
			local c = tab.name == want and "accent" or "offText"
			local lr, lg, lb = b.label:GetTextColor()
			ok(colourIs(Th, lr, lg, lb, c), when .. ": " .. tab.name .. "'s word is " .. c)
			local gr, gg, gb, ga = b.glyph:GetVertexColor()
			ok(colourIs(Th, gr, gg, gb, c), when .. ": " .. tab.name .. "'s glyph is " .. c)
			ok((ga or 1) > 0.99, when .. ": drawn solid")
			local fills = 0
			for _, t in ipairs({ b:GetRegions() }) do
				if t:GetObjectType() == "Texture" and t ~= b.glyph and t:IsVisible() then fills = fills + 1 end
			end
			eq(fills, 0, when .. ": no pill behind " .. tab.name)
		end
	end
	check("Ride", "at open")
	for _, name in ipairs({ "Trips", "Drive", "Ride" }) do
		r:clickOn(tabOf(ui, name))
		w:advance(1)
		check(name, "a click on " .. name)
	end
	-- changed while the window is shut
	UI.Toggle(false) w:advance(1)
	UI.SelectTab("Trips")
	UI.Toggle(true) w:advance(3)
	check("Trips", "reopened on Trips")
	T.clean(w)
end)

test("d2 c: the cog is not gold while Settings shows, and the tab you came from stays lit", function()
	local w, r, ui, UI = openWindow()
	local Th = r.W.Theme
	r:clickOn(tabOf(ui, "Trips")) w:advance(1)
	UI.OpenSettings()
	w:advance(1)
	ok(ui.settingsOpen, "Settings is open")
	ok(not isGold(ui.gear.glyph:GetVertexColor()), "the cog's glyph is not gold")
	ok(not isGold(ui.gear.bg:GetVertexColor()), "nor its disc")
	eq(ui.tab, "Trips", "the tab is still Trips")
	local lr, lg, lb = tabOf(ui, "Trips").label:GetTextColor()
	ok(colourIs(Th, lr, lg, lb, "accent"), "and Trips is still violet in the bar")
	ok(H.visible(ui.tabbar), "the tab bar shows under Settings")
	UI.CloseSettings() w:advance(1)
	ok(not isGold(ui.gear.glyph:GetVertexColor()), "not gold after")
	T.clean(w)
end)

test("d2 c: the header buttons (Wide, the cog, the x) are 32 high, 8 apart, 16 from the edge, and never overlap", function()
	local w, r, ui, UI = openWindow(true)
	local function check(label)
		local win = rect(ui.win)
		local list = { ui.close, ui.gear, ui.phone.fold }
		local edge = win.l + win.w - 16
		for i, b in ipairs(list) do
			ok(H.visible(b), label .. ": button " .. i .. " shows")
			local br = rect(b)
			ok(near(br.h, 32), label .. ": button " .. i .. " is 32 high: " .. br.h)
			ok(near(br.l + br.w, edge), label .. ": button " .. i .. " ends at " .. edge .. ": " .. (br.l + br.w))
			ok(br.b >= win.b + win.h - 56 and br.b + br.h <= win.b + win.h, label .. ": inside the 56 at the top")
			edge = br.l - 8
		end
		local room = UI.HeadRoom("side")
		if win.w < 400 then room = UI.HeadRoom() end
		ok(near(room, win.l + win.w - rect(ui.phone.fold).l), label .. ": UI.HeadRoom is what they take: " .. tostring(room))
	end
	eq(ui.win:GetWidth(), 720, "wide")
	check("wide")
	eq(UI.HeadRoom(), 0, "wide: nothing over the left pane")
	ok(ui.phone.fold.word:GetText() == "Narrow", "the fold button keeps its word")
	ui.phone.fold:Click() w:advance(1)
	eq(ui.win:GetWidth(), 360, "narrow")
	check("narrow")
	eq(ui.phone.fold.word:GetText(), "Wide", "and says Wide")
	ok(UI.HeadRoom("most") >= UI.HeadRoom(), "the most is never less")
	-- the wide window: the bar spans it, the three tabs stay in the left pane
	ui.phone.fold:Click() w:advance(1)
	local win, bar = rect(ui.win), rect(ui.tabbar)
	ok(near(bar.w, 720), "wide: the tab bar spans the window")
	for _, tab in ipairs(ui.tabs) do
		local br = rect(tab.button)
		ok(br.l + br.w <= win.l + 360.5, "wide: " .. tab.name .. " is in the left pane")
	end
	local pane = rect(UI.Fold.Pane())
	ok(near(pane.b + pane.h, win.b + win.h) and near(pane.b, bar.b + bar.h), "wide: the side pane is above the bar, from the top")
	T.clean(w)
end)
