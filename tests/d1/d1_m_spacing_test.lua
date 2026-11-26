-- Design round 1, group M: the line spacing's fallout. Wrapped text is taller now (T.Spacing between its lines):
-- the frames that hold it grow, or what sits below it moves down. Nothing is shortened, shrunk or cut.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local TL = dofile("tools/preview/textlayout.lua")
local function withMetrics(px, fn)
	local old, oldPX, s1, s2 = H.textMetrics, TL.PX, TL.SNAP, TL.SIZE_SNAP
	TL.PX = (px or 768) / 768
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	H.textMetrics = TL
	local good, err = pcall(fn)
	H.textMetrics, TL.PX, TL.SNAP, TL.SIZE_SNAP = old, oldPX, s1, s2
	if not good then error(err, 0) end
end
local function wrapH(Th, n, size) return n * Th.DrawnSize(size) + (n - 1) * Th.Spacing(size) end


local function driverWorld(spot)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = spot or "Ratchet" })
	T.settle(w)
	return w, d
end

-- 1. Home: the bell button and the list start the same way below the heading, however many lines it takes
test("d1 m: Home's bell button sits the same gap under a two-line heading as under a one-line one", function()
	withMetrics(1080, function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1920, screenH = 1080 })
		T.settle(w)
		T.goOnline(d) w:advance(5)
		r.W.UI.Toggle(true) w:advance(2.5)
		local function gap(place, pattern)
			for _, dv in pairs(r.W.drivers) do dv.dest = place end
			r.W.UI.Show("home") w:advance(1)
			r.W.UI.SetSearch(place) w:advance(1)
			r.W.UI.RefreshNow() w:advance(0.3)
			local hd = r:findText(pattern, true)[1]
			ok(hd, "control: the heading is drawn for " .. place)
			local label = r:findText("^Tell me when one opens$", true)[1]
			ok(label, "the bell button is up for " .. place)
			return hd, hd:GetBottom() - label:GetParent():GetTop()
		end
		local h1, g1 = gap("Ratchet", "^Drivers to Ratchet")
		ok(not h1.wuberWrapped, "control: a short place is one line")
		local h2, g2 = gap("Feathermoon Stronghold", "^Drivers to Feathermoon")
		ok(h2.wuberWrapped, "control: the long place wraps to two lines")
		ok(g2 >= 0, "the button is under the heading")
		ok(math.abs(g2 - g1) <= 0.5, "the gap under a two-line heading (" .. g2 .. ") is the gap under a one-line one (" .. g1 .. ")")
		T.clean(w)
	end)
end)

-- 2. Settings: the scroll to Check my game follows the row's real place
test("d1 m: Check my game scrolls to the row's real place, not the place the build counted", function()
	withMetrics(1080, function()
		local w = T.newWorld()
		local r = w:addClient(T.TESTCHAR, { spot = "Undercity", class = "WARLOCK", screenW = 1920, screenH = 1080 })
		w:advance(15)
		r.W.SelfTest = function() return { { name = "Drawing", ok = true }, { name = "Map", ok = true }, { name = "Network", ok = true } } end
		-- the page goes on under the results (the Pioneers' credits), so the scroll is not held at the page's end
		r.W.PioneerNames = function()
			local d, rd = {}, {}
			for i = 1, 90 do d[i] = "Driver" .. i .. "name" rd[i] = "Rider" .. i .. "name" end
			return { drivers = d, riders = rd }
		end
		local UI = r.W.UI
		UI.OpenSettings()
		local st = UI.settings
		local P = r.W.Mod("UI.Settings.Panel")
		P.search("Check my game")
		local m
		for _, x in ipairs(st.find.list) do if x.label == "Check my game" then m = x end end
		ok(m, "found the row")
		P.openResult(m)
		-- what the build counted above the row is not what is drawn (a wrapped line is as tall as the game says): the row sits 20 higher than counted, and so does its card
		local row = st.controls.check:GetParent()
		local cnt = 0
		for _, f in ipairs({ row, st.results }) do
			local pt, rel, rp, x, y = f:GetPoint(1)
			f:ClearAllPoints()
			f:SetPoint(pt, rel, rp, x, y + 20)
			cnt = cnt + 1
		end
		eq(cnt, 2, "control: both moved")
		st.controls.check:GetScript("OnClick")(st.controls.check, "LeftButton", false)
		for _ = 1, 30 do w:advance(0.1) end
		ok(st.results:IsShown(), "results shown")
		local lab, top = row.label:GetTop(), st.clip:GetTop()
		ok(lab <= top + 0.01, "the Check my game label (" .. lab .. ") is not cut by the view's top (" .. top .. ")")
		T.clean(w)
	end)
end)

-- 3. Wizard and crew: a row grows with a two-line "No answer" line
test("d1 m: a person row with the two-line 'No answer' line is tall enough for it", function()
	withMetrics(1080, function()
		local w, d = driverWorld()
		local WM = d.W.Mod("UI.Driver.Wizard")
		local key = "wolfgangbertwolf-x"
		d.W.Drive.offers = { [key] = { name = "Wolfgangbertwolf", at = 0, state = "noapp" } }
		local parent = d.env.CreateFrame("Frame", nil, d.env.UIParent)
		parent:SetSize(400, 400)
		parent:SetPoint("CENTER", d.env.UIParent, "CENTER", 0, 0)
		local row = WM.personRow(parent)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		WM.paintPerson(row, { name = "Wolfgangbertwolf", key = key, class = "WARLOCK" }, "pick", {})
		ok(row.sub:GetText():find("No answer", 1, true), "control: the offer's line is up")
		ok(row.sub.wuberWrapped, "control: it wraps")
		ok(row.sub:GetStringHeight() >= 2 * 10, "control: two lines tall (" .. row.sub:GetStringHeight() .. ")")
		ok(row.sub:GetBottom() >= row:GetBottom() - 0.01, "the line (" .. row.sub:GetBottom() .. ") is inside its row (" .. row:GetBottom() .. ")")
		T.clean(w)
	end)
end)

-- 4a. Screens: T.Para-like paragraph (Screens.para) holds its wrapped lines
test("d1 m: Screens.para's box holds its wrapped text with the line spacing", function()
	withMetrics(1080, function()
		local w, d = driverWorld()
		local SM = d.W.Mod("UI.Driver.Screens")
		local parent = d.env.CreateFrame("Frame", nil, d.env.UIParent)
		for _, px in ipairs({ 11, 12, 13 }) do
			local fs = SM.para(parent, px, "muted", 120)
			fs:SetText("A summon needs three: you and two who click the portal. Pick what fits; you can change it later, and again.")
			ok(fs:GetNumLines() >= 3, "control: wraps (" .. px .. ")")
			ok(fs:GetHeight() >= fs:GetStringHeight() - 0.01, "px " .. px .. ": box " .. fs:GetHeight() .. " holds the text " .. fs:GetStringHeight())
			ok(fs:GetHeight() >= wrapH(d.W.Theme, fs:GetNumLines(), px), "px " .. px .. ": at least n lines + (n - 1) gaps")
		end
		T.clean(w)
	end)
end)

-- 4b. Booking: the route pill's origin
test("d1 m: the route pill's origin box holds its wrapped lines with the spacing", function()
	withMetrics(1080, function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1920, screenH = 1080 })
		T.settle(w)
		local BM = r.W.Mod("UI.Rider.Booking")
		local Th = r.W.Theme
		local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
		local h = BM.RouteHeader(parent, 324)
		h:Set(string.rep("Thousand Needles Great Lift Elevator Rise Platform Camp Mojache Roads ", 3), "Undercity")
		local n = h.from:GetNumLines()
		ok(n >= 3, "control: the origin wraps to " .. n)
		ok(h.from:GetHeight() >= h.from:GetStringHeight() - 0.01, "the origin box (" .. h.from:GetHeight() .. ") holds its text (" .. h.from:GetStringHeight() .. ")")
		ok(h:GetHeight() >= wrapH(Th, n, 12) + 4 - 0.01, "the pill (" .. h:GetHeight() .. ") holds " .. n .. " lines of 12 and their gaps (" .. wrapH(Th, n, 12) .. ") and its 4 of padding")
		T.clean(w)
	end)
end)

-- 4c. Tips: the login card holds its text
test("d1 m: the tip card holds a long wrapped text with the line spacing", function()
	withMetrics(1080, function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1920, screenH = 1080 })
		T.settle(w)
		local TM = r.W.Mod("UI.Tips")
		local Th = r.W.Theme
		local c = TM.Card()
		c.text:SetText("Wuber only says what to type. The trade needs your own steps, and the driver sees the same words, so nothing is paid in one click. Take your time and read each line; the next tip comes after this one is done.")
		local wd, ht = TM.Layout(c)
		local n = c.text:GetNumLines()
		ok(n >= 4, "control: wraps to " .. n)
		-- the card's 118 holds three lines of text (53 high); each line past that must add its size and spacing
		ok(ht >= 118 + (wrapH(Th, n, 12) - 53), "the card (" .. ht .. ") grew for " .. n .. " lines of " .. wrapH(Th, n, 12))
		T.clean(w)
	end)
end)

-- 4d. Coach: a tip card holds its title and text
test("d1 m: every coach tip card holds its wrapped title and text", function()
	withMetrics(1080, function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1920, screenH = 1080 })
		T.settle(w)
		r.W.UI.Toggle(true) w:advance(2.5)
		r.W.UI.ReplayCoach() w:advance(1)
		local ui = r.W.UI.state
		local b = ui.coach
		ok(b and b:IsShown(), "control: the coach card is up")
		for i = 1, #r.W.UI.COACH do
			r.W.UI.CoachStep(i) w:advance(0.5)
			ok(b.text:GetBottom() >= b:GetBottom() - 0.01, "tip " .. i .. ": the text ends inside the card")
			ok(b.title:GetBottom() >= b.text:GetTop() - 0.01, "tip " .. i .. ": the title is above the text (" .. b.title:GetBottom() .. " vs " .. b.text:GetTop() .. ")")
		end
		T.clean(w)
	end)
end)

-- 4e. Customers: a row with a long note grows by the lines' size and spacing
test("d1 m: a Customers row with a long note holds its wrapped sub line", function()
	withMetrics(1080, function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		T.settle(w)
		local log = d.W.db.drive.log
		log.rides = log.rides or {}
		table.insert(log.rides, (d.env.time() - 86400) .. ",5000,Tess Regular,Ratchet,t,5000")
		d.W.Drive.SetNote("Tess Regular", string.rep("Likes a quiet portal and always tips well after a long raid night. ", 3))
		d.W.Drive.Customers("tess")
		d.W.UI.Toggle(true) w:advance(2.5)
		d.W.UI.ShowDrive("customers") w:advance(1)
		local fs = d:findText("^last ", true)[1]
		ok(fs, "control: the customer's line is drawn")
		local n = fs:GetNumLines()
		ok(n >= 4, "control: the note wraps to " .. n .. " lines")
		ok(fs:GetHeight() >= wrapH(d.W.Theme, n, 10) - 0.01, "the line's box (" .. fs:GetHeight() .. ") holds " .. n .. " lines and their gaps (" .. wrapH(d.W.Theme, n, 10) .. ")")
		local row = fs:GetParent()
		ok(fs:GetBottom() >= row:GetBottom() - 0.01, "and the row holds it")
		-- a one-line customer is the base height; a row with n lines is that plus (n - 1) steps of size and spacing
		table.insert(log.rides, (d.env.time() - 86400) .. ",5000,Uma Plain,Ratchet,t,5000")
		d.W.Drive.Customers("uma")
		d.W.UI.ShowDrive("customers") w:advance(1)
		local base
		for _, f in ipairs(d:findText("^last ", true)) do
			if f:GetNumLines() == 1 then base = f:GetParent():GetHeight() else fs, row = f, f:GetParent() end
		end
		n = fs:GetNumLines()
		ok(base, "control: a one-line customer row is up too")
		ok(row:GetHeight() >= base + wrapH(d.W.Theme, n, 10) - 13 - 0.01, "the row (" .. row:GetHeight() .. ") grew by the extra lines and their gaps over a one-line row (" .. base .. ", whose line box is 13)")
		T.clean(w)
	end)
end)
