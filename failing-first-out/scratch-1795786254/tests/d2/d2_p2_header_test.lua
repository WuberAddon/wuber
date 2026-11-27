-- Design round 2, group P2: the header zone carries the page's own first thing. On the Drive console the Sell summons /
-- Raid summons switch sits in the header zone, left of the window's buttons (and the page under it starts higher);
-- Trips has its title there, as Settings has. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function near(a, b, x) return math.abs(a - b) <= (x or 0.6) end

local function console(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	if o.raid then
		DR.SetMode("raid")
		w:advance(1)
	end
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR
end

-- the switch: in the header zone, 16 from the left, on the buttons' line, its words whole at their size
local function checkSwitch(name, a, W, wantWidth)
	local UI, ui = W.UI, W.UI.state
	local v = W.Driver.ui.console
	local seg = v.modeBar
	ok(H.visible(seg), name .. ": the switch shows")
	local top = ui.win:GetTop()
	ok(seg:GetTop() <= top + 0.5 and seg:GetBottom() >= top - UI.HEAD_H - 0.5,
		name .. ": the switch is inside the header zone (" .. (top - seg:GetTop()) .. " to " .. (top - seg:GetBottom()) .. " down)")
	ok(near(seg:GetLeft(), ui.win:GetLeft() + 16), name .. ": 16 from the left edge: " .. (seg:GetLeft() - ui.win:GetLeft()))
	local mid = seg:GetBottom() + seg:GetHeight() / 2
	local bmid = ui.close:GetBottom() + ui.close:GetHeight() / 2
	ok(near(mid, bmid, 1), name .. ": centred on the header's buttons: " .. mid .. " / " .. bmid)
	local room = UI.HeadRoom()
	if room > 0 then
		ok(seg:GetLeft() + seg:GetWidth() <= ui.win:GetLeft() + ui.win:GetWidth() - room - 8 + 0.5,
			name .. ": ends at least 8 before the leftmost button (" .. (seg:GetLeft() + seg:GetWidth() - ui.win:GetLeft()) .. ", buttons take " .. room .. ")")
	end
	if wantWidth then ok(near(seg:GetWidth(), wantWidth), name .. ": its width: " .. seg:GetWidth()) end
	local words = {}
	for i, b in ipairs(seg.buttons) do
		local text = b.label:GetText()
		words[i] = text
		local _, px = b.label:GetFont()
		eq(px, W.Theme.SIZE.small, name .. ": '" .. text .. "' keeps its size")
		local need = W.Theme.MeasureText(text, px, "medium")
		ok(need <= b.label:GetWidth() + 0.5, name .. ": '" .. text .. "' is whole: " .. need .. " in " .. b.label:GetWidth())
		ok(b:GetLeft() >= seg:GetLeft() - 0.5 and b:GetLeft() + b:GetWidth() <= seg:GetLeft() + seg:GetWidth() + 0.5, name .. ": '" .. text .. "' is inside the switch")
	end
	eq(table.concat(words, " / "), "Sell summons / Raid summons", name .. ": the words")
	-- what is under it starts under the buttons' line and close under the switch
	local strip = v.up:GetTop()
	ok(strip <= top - UI.HEAD_ROW + 0.5, name .. ": the status strip starts under the buttons")
	ok(strip >= top - UI.HEAD_H + 0.5, name .. ": and inside the header zone's height, not 36 lower: " .. (top - strip))
end

test("d2 p2: the folded console's switch is in the header zone, left of the buttons by at least 8, both words whole (sell, raid, with and without the fold button)", function()
	local w, a, W = console({})
	eq(W.UI.state.win:GetWidth(), 360, "folded")
	checkSwitch("folded", a, W)
	T.clean(w)
	w, a, W = console({ raid = true })
	checkSwitch("raid mode", a, W)
	T.clean(w)
	-- a screen with room to unfold: the fold button shows on the folded window too, and the switch is narrower
	w, a, W = console({ wide = true })
	local ui = W.UI.state
	ui.phone.fold:Click() w:advance(1.5)
	eq(ui.win:GetWidth(), 360, "folded again")
	ok(H.visible(ui.phone.fold), "the fold button shows")
	checkSwitch("folded beside the fold button", a, W)
	-- and it follows when the window unfolds again
	ui.phone.fold:Click() w:advance(1.5)
	eq(ui.win:GetWidth(), 720, "unfolded again")
	checkSwitch("unfolded again", a, W, 328)
	T.clean(w)
end)

test("d2 p2: the unfolded console's switch is in the header zone too, as wide as the pane (sell and raid)", function()
	for _, raid in ipairs({ false, true }) do
		local w, a, W = console({ wide = true, raid = raid })
		eq(W.UI.state.win:GetWidth(), 720, "unfolded")
		eq(W.UI.HeadRoom(), 0, "the buttons are over the side pane")
		checkSwitch(raid and "unfolded raid" or "unfolded", a, W, 328)
		T.clean(w)
	end
end)

test("d2 p2: a console without the switch (a helper's) keeps its first row under the buttons", function()
	local w, a, W = console({})
	local v = W.Driver.ui.console
	W.Driver.Role = function() return "helper" end
	W.Driver.RefreshNow() w:advance(1)
	ok(not v.modeBar:IsShown(), "no switch")
	ok(near(v.up:GetTop(), W.UI.state.win:GetTop() - W.UI.HEAD_ROW), "the strip starts at the buttons' line")
	T.clean(w)
end)

test("d2 p2: folded console with three riders: the page visibly goes on (the Crew or Your business heading starts well inside the view)", function()
	local w, a, W, DR = console({})
	local t0 = (w.now and w.now()) or 0
	local cs = {}
	for i, n in ipairs({ "Dan Rider", "Eve Night", "Gus Hill" }) do
		cs[i] = { name = n, key = n:lower(), state = i == 1 and "lead" or "queued", at = t0 - 10 * i, wantsPrice = true }
	end
	W.Char().wizard = true
	W.db.holdTip = true
	DR.SkipTarget = function() return cs[1], "cast" end
	DR.Active = function() return true end
	DR.RideCount = function(n) return n == "Dan Rider" and 2 or 0 end
	DR.Plan = function() return { marks = {}, type = "macro", macrotext = "/target Dan Rider\n/cast Ritual of Summoning", color = "go", title = "Summon Dan", sub = "click: targets and casts  -  12 shards" } end
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return true end
	W.Driver.RefreshNow()
	w:advance(2)
	local v = W.Driver.ui.console
	local UI, ui = W.UI, W.UI.state
	local edge = v.scroll:GetBottom()
	-- the view is everything from the strip, the big button and the pills down to the tab bar
	ok(near(edge, ui.tabbar:GetTop(), 1), "the view ends at the tab bar")
	local top = ui.win:GetTop()
	ok(top - v.scroll:GetTop() <= UI.HEAD_H + 2 + v.up:GetHeight() + 0.5, "the riders start right under the strip, the big button and the pills: "
		.. (top - v.scroll:GetTop()) .. " down (the header zone " .. UI.HEAD_H .. ", those rows " .. v.up:GetHeight() .. ")")
	local head = v.businessHead:GetTop()
	local crew = v.crewHead and v.crewHead:IsShown() and v.crewHead:GetTop() or nil
	local first = math.max(head, crew or -1e9)
	-- (before: 22 BELOW the view's edge; the switch's row is what was won)
	ok(first - edge >= 10, "the heading after the riders starts at least 10 inside the view: " .. (first - edge))
	T.clean(w)
end)

test("d2 p2: Trips has its title on the page below the header, at display size (folded and unfolded)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	r.wide = true
	T.settle(w)
	r.W.db.coach = true
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	local ui = UI.state
	UI.SelectTab("Trips") w:advance(1.5)
	local function check(name)
		local title
		for _, fs in ipairs(r:findText("^Trips$", true)) do
			local p, inBar = fs, false
			while p do
				if p == ui.tabbar then inBar = true end
				p = H.state[p] and H.state[p].parent
			end
			if not inBar then title = title or fs end
		end
		ok(title, name .. ": a title 'Trips' besides the tab's word")
		if not title then return end
		local top = ui.win:GetTop()
		ok(title:GetTop() <= top - UI.HEAD_ROW + 0.5, name .. ": on the page below the header buttons")
		ok(near(title:GetLeft(), ui.win:GetLeft() + 18), name .. ": 18 from the left: " .. (title:GetLeft() - ui.win:GetLeft()))
		local _, px = title:GetFont()
		eq(math.floor((px or 0) + 0.5), r.W.Theme.SIZE.display, name .. ": display size")
		ok(#r:findText("^Time saved$", true) > 0, name .. ": Time saved still shows")
		local ts = r:findText("^Time saved$", true)[1]
		ok(ts:GetTop() <= title:GetBottom() + 0.5, name .. ": Time saved sits below the title")
	end
	eq(ui.win:GetWidth(), 720, "Trips is wide")
	check("unfolded")
	ui.phone.fold:Click() w:advance(1)
	eq(ui.win:GetWidth(), 360, "Trips is narrow")
	check("folded")
	T.clean(w)
end)
