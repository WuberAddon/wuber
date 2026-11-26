-- Design round 2, group A: Settings as grouped rows with switches. The home is four groups (the Advanced mode switch;
-- the sections; the most used switches; this window, Help, the bug report); every page is groups of rows with quiet headings that do
-- not say the page's name again; a search match gets a soft wash; the Reduce motion switch.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function open(warlock, where)
	local w = T.newWorld()
	local c = warlock and T.driver(w, T.BOB) or T.rider(w, T.TESTCHAR)
	T.settle(w)
	c.W.db.coach = true
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return w, c, c.W.UI.settings
end
local function keys(group)
	local list = {}
	for _, r in ipairs(group.rows) do if r:IsShown() then list[#list + 1] = r.key end end
	return table.concat(list, " ")
end

test("d2 a: the Settings home is four groups of rows: Advanced mode, sections, the most used switches, this window and help", function()
	local w, c, st = open(true)
	local f = st.find
	ok(type(f.groups) == "table" and #f.groups == 4, "four groups")
	eq(keys(f.groups[1]), "advanced", "group 1: the Advanced mode switch")
	eq(keys(f.groups[2]), "riding driving map sound", "group 2: the section rows")
	eq(keys(f.groups[3]), "autoAccept mapPins sound", "group 3: the most used switches (autoAccept shows in Advanced)")
	eq(keys(f.groups[4]), "window help bug", "group 4: this window, help, the bug report")
	for _, b in ipairs(f.cards) do
		eq(b:GetParent(), b.group, b.key .. ": a row in a group's card, no card of its own")
		ok(b.bg == nil, b.key .. ": no card fill of its own")
		ok(b.icon and b.disc and b.chevron, b.key .. ": icon disc and chevron")
		ok(b.sub:GetText() ~= "", b.key .. ": what it is set to")
	end
	-- 12 between the groups, in order
	for i = 2, 4 do
		ok(math.abs(f.groups[i - 1]:GetBottom() - f.groups[i]:GetTop() - 12) < 0.01, "12 between group " .. (i - 1) .. " and " .. i)
	end
	ok(f.ver:IsShown() and f.ver:GetText():find("Wuber", 1, true), "the version line stays")
	T.clean(w)
	-- a rider has no Driving row, and the row takes no room
	local w2, _, st2 = open(false)
	eq(keys(st2.find.groups[2]), "riding map sound", "no Driving row for a rider")
	eq(st2.find.groups[2]:GetHeight(), 3 * 56, "three rows of 56")
	T.clean(w2)
end)

test("d2 a: the home's switches are the SAME settings as on their pages: same title, same tooltip, both in step", function()
	local w, c, st = open(false)
	local f = st.find
	eq(#f.quick, 4, "Advanced mode and the three most used switches")
	local dbKey = { autoAccept = "autoAccept", mapPins = "mapPins", sound = "sound" }
	for _, r in ipairs(f.quick) do
		if r.key == "advanced" then
			local page = st.controls.advanced
			ok(page and page.row, "advanced: the page's switch")
			eq(r.title:GetText(), page.row.title:GetText(), "advanced: the page's exact title")
			eq(r.wuberTip.text, page.row.wuberTip.text, "advanced: the page's exact tooltip")
		else
			local page = st.controls[r.key]
			ok(page and page.row, r.key .. ": the page's switch")
			eq(r.title:GetText(), page.row.title:GetText(), r.key .. ": the page's exact title")
			eq(r.wuberTip.text, page.row.wuberTip.text, r.key .. ": the page's exact tooltip")
			ok(r.wuberTip.text and r.wuberTip.text ~= "", r.key .. ": has a tooltip")
			ok(r.switch.on == true and page.on == true, r.key .. ": both start on")
			local heard
			c.W.Listen("SETTINGS", function(k) heard = k end)
			r.switch:Click()
			eq(c.W.db[dbKey[r.key]], false, r.key .. ": the home's switch saves the setting")
			eq(heard, dbKey[r.key], r.key .. ": SETTINGS fired")
			eq(page.on, false, r.key .. ": the page's switch follows")
			-- and back from the page's own switch
			page:Click()
			c.W.UI.UpdateSettings()
			eq(c.W.db[dbKey[r.key]], true, r.key .. ": on again from its page")
			eq(r.switch.on, true, r.key .. ": the home's switch follows")
		end
	end
	T.clean(w)
end)

test("d2 a: every Settings page is groups of rows; headings are quiet, sentence case and do not repeat the page name", function()
	local w, c, st = open(true, "driving")
	ok(#st.rows > 30, "the rows: " .. #st.rows)
	local groups = {}
	for i, r in ipairs(st.rows) do
		ok(r.group and r:GetParent() == r.group, "row " .. i .. " (" .. tostring(r.label and r.label:GetText()) .. ") is in a group's card")
		ok(r.bg == nil, "row " .. i .. " has no card of its own")
		groups[r.group] = (groups[r.group] or 0) + 1
	end
	local n, most = 0, 0
	for _, count in pairs(groups) do n, most = n + 1, math.max(most, count) end
	ok(n < #st.rows / 2, "far fewer cards than rows: " .. n .. " cards for " .. #st.rows .. " rows")
	ok(most >= 3, "a card holds several rows")
	-- the control at the right: a switch 12 from its card's edge
	local t = st.controls.autoAccept
	ok(math.abs(t.row.group:GetRight() - t:GetRight() - 12) < 0.01, "the switch sits 12 from the card's right edge")
	-- headings
	local seen = {}
	local muted = c.W.Theme.C.muted
	for _, h in ipairs(st.headings) do
		local words = h:GetText()
		seen[words] = true
		ok(not words:find("^Driving"), "no heading says the page's name again: " .. words)
		ok(words ~= "Riding" and words ~= "Map" and words ~= "This window", "no heading that is only the page's name: " .. words)
		ok(words:sub(1, 1) == words:sub(1, 1):upper() and words ~= words:upper(), "sentence case: " .. words)
		local r, g, b = h:GetTextColor()
		ok(math.abs(r - muted[1]) < 0.01 and math.abs(g - muted[2]) < 0.01 and math.abs(b - muted[3]) < 0.01, "grey: " .. words)
	end
	-- (the Settings diet) "Most used" and "Your card" are no longer drawn; the others only lose the page's name
	ok(not seen["Most used"] and not seen["Your card"], "no Most used, no Your card")
	ok(seen["Riders and notes"] and seen["Inviting"], "the others only lose the page's name")
	eq(#c:findText("Driving: ", true, true), 0, "no 'Driving: ...' text is left on the page")
	T.clean(w)
end)

test("d2 a: Reduce motion is a switch row on Sound and effects: saves W.db.reduceMotion, fires SETTINGS, search finds it", function()
	local w, c, st = open(false, "sound")
	local t = st.controls.reduceMotion
	ok(t and t.row, "the Reduce motion switch")
	eq(t.row.title:GetText(), "Reduce motion", "its title")
	eq(t.row.wuberTip.text, "Pages and sheets fade in place instead of sliding.", "its tooltip")
	eq(t.wuberTip.text, "Pages and sheets fade in place instead of sliding.", "on the switch too")
	eq(t.on, false, "off by default")
	local fx = st.controls.fx
	eq(t.row.group, fx:GetParent().group, "beside the effects setting: the same card")
	local heard
	c.W.Listen("SETTINGS", function(k) heard = k end)
	t:Click()
	eq(c.W.db.reduceMotion, true, "on: true")
	eq(heard, "reduceMotion", "SETTINGS fired with its key")
	heard = nil
	t:Click()
	eq(c.W.db.reduceMotion, false, "off: false (never nil)")
	eq(heard, "reduceMotion", "SETTINGS again")
	c.W.db.reduceMotion = true
	c.W.UI.UpdateSettings()
	eq(t.on, true, "the switch shows the saved value")
	local found = false
	for _, m in ipairs(c.W.Mod("UI.Settings.Find").match("reduce motion")) do
		if m.label == "Reduce motion" then
			found = true
			eq(m.key, "sound", "found on Sound and effects")
		end
	end
	ok(found, "Settings search finds it")
	T.clean(w)
end)

test("d2 a: a search match gets a soft violet wash that fades away, not a solid violet card", function()
	local w, c, st = open(false)
	local P, F = c.W.Mod("UI.Settings.Panel"), c.W.Mod("UI.Settings.Find")
	P.search("sounds")
	w:advance(0.3)
	local m
	for _, hit in ipairs(F.match("sounds")) do if hit.label == "Sounds" then m = hit end end
	ok(m, "the Sounds row matches")
	P.openResult(m)
	w:advance(0.1)
	local row = m.rec.frame
	ok(row.wash and row.wash:IsShown(), "the row is washed")
	local _, part = next(row.wash.fill.parts)
	local r, g, b, a = part:GetVertexColor()
	local v = c.W.Theme.C.accent
	ok(math.abs(r - v[1]) < 0.01 and math.abs(g - v[2]) < 0.01 and math.abs(b - v[3]) < 0.01, "violet")
	ok(a * part:GetAlpha() <= 0.2, "soft: at most 20%, got " .. a * part:GetAlpha())
	eq(row.bg, nil, "the row's own look is untouched: it has no card to turn violet")
	w:advance(3)
	ok(not row.wash:IsShown(), "faded away")
	T.clean(w)
end)
