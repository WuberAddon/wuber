-- Design round 2, group C: the pages make room for the header's buttons. A pushed page (Settings, Help, the driver's
-- screens) has its back chevron and title in the header zone and no cog; a root page keeps its first row clear of
-- the buttons. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function rect(f) return { l = f:GetLeft(), b = f:GetBottom(), w = f:GetWidth(), h = f:GetHeight() } end
local function near(a, b, x) return math.abs(a - b) <= (x or 0.6) end

local function openRider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

-- a and b share no point (frames or regions)
local function apart(a, b)
	local x, y = rect(a), rect(b)
	return x.l + x.w <= y.l + 0.5 or y.l + y.w <= x.l + 0.5 or x.b + x.h <= y.b + 0.5 or y.b + y.h <= x.b + 0.5
end

test("d2 c: Settings is a pushed page: chevron and title in the header zone, the hint under the title, no cog, the x stays", function()
	local w, r, ui, UI = openRider()
	UI.OpenSettings() w:advance(1)
	local st = r.W.Mod("UI.Settings.Rows").st
	local win, bar = rect(ui.win), rect(ui.tabbar)
	local top = win.b + win.h
	local p = rect(st.panel)
	ok(near(p.b + p.h, top), "the page starts at the top of the screen")
	ok(near(p.b, bar.b + bar.h), "and ends at the tab bar")
	for name, f in pairs({ chevron = st.back, title = st.title, hint = st.hint }) do
		ok(H.visible(f), "the " .. name .. " shows")
	end
	local cr = rect(st.back)
	ok(cr.b >= top - 56 - 0.5 and cr.b + cr.h <= top + 0.5, "the chevron is in the header zone")
	ok(not H.visible(ui.gear), "no cog on a pushed page")
	ok(H.visible(ui.close), "the x stays")
	local tr, hr = rect(st.title), rect(st.hint)
	ok(tr.b + tr.h <= top - 44 + 0.5, "the title is on the page below the header")
	ok(hr.b + hr.h <= tr.b + 2, "the hint is under the title")
	ok(near(hr.l, tr.l, 1), "at the title's left")
	eq(st.hint:GetText(), "Hover over anything for help", "its words are the same")
	local room = win.l + win.w - UI.HeadRoom()
	ok(hr.l + (st.hint:GetStringWidth() or hr.w) <= win.l + win.w, "the hint fits in the window")
	ok(tr.l + (st.title:GetStringWidth() or tr.w) <= win.l + win.w, "the title fits in the window")
	ok(apart(st.back, ui.close), "chevron and x do not meet")
	UI.CloseSettings() w:advance(1)
	ok(H.visible(ui.gear), "the cog is back on the tab")
	-- Help: the same
	UI.OpenHelp() w:advance(1)
	ok(not H.visible(ui.gear), "Help: no cog")
	local hp = r:findText("^" .. UI.HELP_TITLE:gsub("%p", "%%%0") .. "$", true)[1]
	ok(hp, "Help's title shows")
	local hr2 = rect(hp)
	ok(hr2.b >= top - 56 - 0.5, "Help's title is in the header zone")
	T.clean(w)
end)

test("d2 c: a driver's screen is a pushed page: chevron and title in the header zone, no cog; back on the console the cog returns", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	a.W.db.coach = true
	T.openDrive(a)
	local UI, D = a.W.UI, a.W.Driver
	local ui = UI.state
	ok(H.visible(ui.gear), "the console is a root page: the cog shows")
	D.ShowScreen("crew") w:advance(1)
	local win = rect(ui.win)
	local top = win.b + win.h
	ok(not H.visible(ui.gear), "no cog on the Crew screen")
	ok(H.visible(ui.close), "the x stays")
	local title = a:findText("^Your crew$", true)[1]
	ok(title, "the title shows")
	local tr = rect(title)
	ok(tr.b >= top - 56 - 0.5 and tr.b + tr.h <= top + 0.5, "the title is in the header zone: " .. (top - tr.b - tr.h) .. " to " .. (top - tr.b))
	ok(tr.l + (title:GetStringWidth() or tr.w) <= win.l + win.w - UI.HeadRoom(), "and ends before the buttons")
	D.ShowScreen("console") w:advance(1)
	ok(H.visible(ui.gear), "the cog is back")
	T.clean(w)
end)

-- every visible text of the window's pages that shares more than 2 x 2 with a header button that shows
local function underButtons(c, ui)
	local S = H.state
	local function within(obj, root)
		local p = obj
		while p do
			if p == root then return true end
			p = S[p] and S[p].parent
		end
		return false
	end
	local bad = {}
	for _, b in ipairs({ ui.close, ui.gear, ui.phone.fold }) do
		if H.visible(b) then
			local br = H.rect(b)
			for _, obj in ipairs(c.widgets) do
				local s = S[obj]
				if s and s.otype == "FontString" and s.text and tostring(s.text):match("%S") and H.visible(obj)
					and within(obj, ui.win) and not within(obj, ui.top) and not within(obj, ui.tabbar) then
					local fr = H.rect(obj)
					-- the drawn words inside the string's box, by how it is justified
					local k = fr.w / math.max(1, obj:GetWidth() or 1)
					local sw = math.min(fr.w, (obj:GetStringWidth() or 0) * k)
					local j = obj:GetJustifyH()
					local l = j == "RIGHT" and (fr.l + fr.w - sw) or (j == "CENTER" and (fr.l + (fr.w - sw) / 2) or fr.l)
					local w = math.min(l + sw, br.l + br.w) - math.max(l, br.l)
					local h = math.min(fr.b + fr.h, br.b + br.h) - math.max(fr.b, br.b)
					if fr.w and w > 2 and h > 2 then bad[#bad + 1] = tostring(s.text) end
				end
			end
		end
	end
	return table.concat(bad, " | ")
end

test("d2 c: root pages keep their words clear of the header's buttons: Trips, and Home wide (the Here / World switch)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	r.wide = true
	T.settle(w)
	r.W.db.coach = true
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	local ui = UI.state
	eq(ui.win:GetWidth(), 720, "Home is wide")
	ok(H.visible(ui.phone.fold), "the fold button shows")
	eq(underButtons(r, ui), "", "Home, wide: words under the buttons")
	ok(#r:findText("^Here$", true) > 0 and #r:findText("^World$", true) > 0, "the Here / World switch is there")
	UI.SelectTab("Trips") w:advance(1.5)
	eq(underButtons(r, ui), "", "Trips, wide: words under the buttons")
	ui.phone.fold:Click() w:advance(1)
	eq(ui.win:GetWidth(), 360, "Trips is narrow")
	eq(underButtons(r, ui), "", "Trips, narrow: words under the buttons")
	ok(#r:findText("^Time saved$", true) > 0, "Time saved shows")
	UI.SelectTab("Ride") w:advance(1.5)
	eq(underButtons(r, ui), "", "Home: words under the buttons")
	T.clean(w)
end)

test("d2 c: the Drive console's words keep clear of the header's buttons; the status strip starts under them (the switch is beside them: d2 p2)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	a.W.db.coach = true
	T.openDrive(a)
	local UI = a.W.UI
	local ui = UI.state
	eq(ui.tab, "Drive", "on the Drive tab")
	ok(#a:findText("^Sell summons$", true) > 0 and #a:findText("^Raid summons$", true) > 0, "the switch keeps its words")
	eq(underButtons(a, ui), "", "console: words under the buttons")
	local strip = a.W.Driver.ui.console.up
	ok(strip:GetTop() <= ui.win:GetTop() - (UI.HEAD_ROW or 44) + 0.5, "the status strip is under the buttons' line")
	T.clean(w)
end)

test("d2 c: the login tip card sits above the tab bar", function()
	local w, r, ui, UI = openRider()
	local Tips = r.W.Mod("UI.Tips")
	UI.Show("home") w:advance(1)
	r.W.db.tipsOn = true
	r.W.db.tipsSeen = {}
	local t = Tips.Longest()
	local shown, why = Tips.ShowNow(t and t.id)
	w:advance(1)
	ok(shown, "the tip card shows: " .. tostring(why))
	local card = Tips.Card()
	ok(card, "the tip card exists")
	ok(H.visible(card), "and is on screen")
	local cr, br = H.rect(card), H.rect(ui.tabbar)
	ok(cr.b >= br.b + br.h - 0.5, "its bottom is above the tab bar: " .. cr.b .. " vs " .. (br.b + br.h))
	T.clean(w)
end)
