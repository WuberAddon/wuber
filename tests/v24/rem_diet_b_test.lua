-- Wuber 2.4, Settings diet step B: merged rows, inline action buttons, conditional nameplates button, Help URL box and search keywords. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function openSettings(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end

local function hasText(c, text)
	return #c:findText(text, false, true) > 0
end

local function findResult(st, lbl)
	for _, b in ipairs(st.find.items) do
		if H.visible(b) and b.m and b.m.label == lbl then return b end
	end
	return nil
end

local function listStr(v)
	if type(v) == "table" then return table.concat(v, " ") end
	return tostring(v or "")
end

local function moveSlider(sl, v)
	local down = type(sl.GetScript) == "function" and sl:GetScript("OnMouseDown")
	local vc = type(sl.GetScript) == "function" and sl:GetScript("OnValueChanged")
	local up = type(sl.GetScript) == "function" and sl:GetScript("OnMouseUp")
	if type(sl.SetValue) == "function" then
		if type(down) == "function" then down(sl, "LeftButton") end
		sl:SetValue(v)
		if type(vc) == "function" then vc(sl, v, true) end
		if type(up) == "function" then up(sl, "LeftButton") end
	else
		sl:Set(v)
		if type(sl.onChange) == "function" then sl.onChange(v) end
	end
end

local function setFriendlyPlates(c, val)
	if type(c.env.C_CVar) == "table" and type(c.env.C_CVar.SetCVar) == "function" then
		c.env.C_CVar.SetCVar("nameplateShowFriends", val)
	end
	if type(c.env.SetCVar) == "function" then
		c.env.SetCVar("nameplateShowFriends", val)
	end
end

test("v24 diet b: Riding shows Tips with Replay button and no Login tips; This window has no Replay tips", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local st = openSettings(r, w, "riding")
	ok(hasText(r, "Tips"), "Riding shows Tips")
	local replay = r:button("Replay")
	ok(replay and H.visible(replay), "Replay button visible on Tips row")
	eq(replay:GetParent(), st.controls.tips.row, "Replay sits on the Tips row")
	eq(#r:findText("Login tips", true, true), 0, "no Login tips text")
	r.W.UI.OpenSettings("window")
	w:advance(0.5)
	eq(#r:findText("Replay tips", true, true), 0, "This window has no Replay tips")
	T.clean(w)
end)

test("v24 diet b: Flight offers combines birdTip and flightOffers with no Flight master tip", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { saved = { Wuber = { birdTip = false } } })
	T.settle(w)
	local st = openSettings(r, w, "riding")
	eq(#r:findText("Flight master tip", true, true), 0, "no Flight master tip text in Settings")
	eq(st.controls.birdTip, nil, "birdTip key left st.controls")
	local sw = st.controls.flightOffers
	ok(sw, "flightOffers switch exists")
	eq(sw.on, false, "reads off when WuberDB.birdTip is false")
	r:click(sw)
	w:advance(0.5)
	ok(r.env.WuberDB.birdTip ~= false, "turning on makes birdTip not false")
	ok(r.env.WuberDB.flightOffers ~= false, "turning on makes flightOffers not false")
	eq(sw.on, true, "switch reads on")
	r:click(sw)
	w:advance(0.5)
	eq(r.env.WuberDB.birdTip, false, "turning off makes birdTip false")
	eq(r.env.WuberDB.flightOffers, false, "turning off makes flightOffers false")
	eq(sw.on, false, "switch reads off")
	T.clean(w)
end)

test("v24 diet b: Group size slider covers One at a time, Auto, numbered size and slash command sync", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local st = openSettings(d, w, "driving")
	ok(hasText(d, "Group size"), "Group size row shown")
	eq(#d:findText("One rider at a time", true, true), 0, "no One rider at a time row")
	eq(#d:findText("Largest group", true, true), 0, "no Largest group row")
	eq(st.controls["drive.oneAtATime"], nil, "drive.oneAtATime key removed")
	local sl = st.controls["drive.maxGroup"]
	ok(sl, "drive.maxGroup slider exists")
	moveSlider(sl, 1)
	w:advance(0.2)
	eq(d.W.Drive.opts().oneAtATime, true, "stop 1 turns oneAtATime on")
	ok(hasText(d, "One at a time"), "stop 1 shows One at a time")
	moveSlider(sl, 2)
	w:advance(0.2)
	eq(d.W.Drive.opts().oneAtATime, false, "stop 2 turns oneAtATime off")
	eq(d.W.Drive.opts().maxGroup, 0, "stop 2 sets maxGroup to 0")
	ok(hasText(d, "Auto"), "stop 2 shows Auto")
	moveSlider(sl, 7)
	w:advance(0.2)
	eq(d.W.Drive.opts().oneAtATime, false, "stop 7 keeps oneAtATime off")
	eq(d.W.Drive.opts().maxGroup, 7, "stop 7 sets maxGroup to 7")
	ok(hasText(d, "7 people"), "stop 7 shows 7 people")
	d:slash("/wuber drive oneatatime on")
	d.W.UI.UpdateSettings()
	w:advance(0.2)
	eq(sl.value, 1, "slider moves to stop 1")
	ok(hasText(d, "One at a time"), "slash command then UpdateSettings shows One at a time")
	T.clean(w)
end)

test("v24 diet b: Chat channels holds Read these and Advertise in these boxes independently", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local st = openSettings(d, w, "driving")
	ok(hasText(d, "Chat channels"), "Chat channels row shown")
	ok(hasText(d, "Read these"), "Read these box label shown")
	ok(hasText(d, "Advertise in these"), "Advertise in these box label shown")
	eq(#d:findText("Channels to watch", true, true), 0, "no Channels to watch row")
	eq(#d:findText("Advert channels", true, true), 0, "no Advert channels row")
	local wf = st.controls["drive.watchChannels"]
	local af = st.controls["drive.adChannels"]
	ok(wf and af, "both channel boxes exist")
	eq(wf:GetParent(), af:GetParent(), "both boxes share the Chat channels row")
	local adBefore = listStr(d.W.Drive.opts().adChannels)
	d:type(wf.edit, "trade, general")
	w:advance(0.2)
	local watchAfter = listStr(d.W.Drive.opts().watchChannels)
	ok(watchAfter:find("trade", 1, true) and watchAfter:find("general", 1, true), "first box updated watchChannels")
	eq(listStr(d.W.Drive.opts().adChannels), adBefore, "first box left adChannels untouched")
	local watchBefore = listStr(d.W.Drive.opts().watchChannels)
	d:type(af.edit, "services, trade")
	w:advance(0.2)
	local adAfter = listStr(d.W.Drive.opts().adChannels)
	ok(adAfter:find("services", 1, true) and adAfter:find("trade", 1, true), "second box updated adChannels")
	eq(listStr(d.W.Drive.opts().watchChannels), watchBefore, "second box left watchChannels untouched")
	T.clean(w)
end)

test("v24 diet b: Riders who leave without paying three-way choice sets autoBlock and tellBlocked", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local st = openSettings(d, w, "driving")
	ok(hasText(d, "Riders who leave without paying"), "merged row shown")
	eq(#d:findText("Block riders who leave without paying", true, true), 0, "old autoBlock row gone")
	eq(#d:findText("Tell blocked players why", true, true), 0, "old tellBlocked row gone")
	eq(st.controls["drive.autoBlock"], nil, "drive.autoBlock key removed")
	eq(st.controls["drive.tellBlocked"], nil, "drive.tellBlocked key removed")
	local seg = st.controls["drive.leavers"]
	ok(seg, "drive.leavers control exists")
	do local b = d:button("Block and tell them"); ok(d:scrollIntoView(b), "Block and tell them scrolls into view"); d:click(b) end
	w:advance(0.2)
	eq(d.W.Drive.opts().autoBlock, true, "Block and tell them sets autoBlock on")
	eq(d.W.Drive.opts().tellBlocked, true, "Block and tell them sets tellBlocked on")
	do local b = d:button("Block quietly"); ok(d:scrollIntoView(b), "Block quietly scrolls into view"); d:click(b) end
	w:advance(0.2)
	eq(d.W.Drive.opts().autoBlock, true, "Block quietly sets autoBlock on")
	eq(d.W.Drive.opts().tellBlocked, false, "Block quietly sets tellBlocked off")
	do local b = d:button("Block and tell them"); ok(d:scrollIntoView(b), "Block and tell them scrolls into view"); d:click(b) end
	w:advance(0.2)
	do local b = d:button("Do nothing"); ok(d:scrollIntoView(b), "Do nothing scrolls into view"); d:click(b) end
	w:advance(0.2)
	eq(d.W.Drive.opts().autoBlock, false, "Do nothing sets autoBlock off")
	eq(d.W.Drive.opts().tellBlocked, true, "Do nothing leaves tellBlocked untouched")
	do local b = d:button("Block and tell them"); ok(d:scrollIntoView(b), "Block and tell them scrolls into view"); d:click(b) end
	w:advance(0.2)
	d.W.Drive.opts().autoBlock = false
	d.W.UI.UpdateSettings()
	eq(seg.value, "off", "autoBlock off reads Do nothing")
	T.clean(w)
end)

test("v24 diet b: Big button on screen three-way choice sets shown and keepClosed", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local st = openSettings(d, w, "driving")
	ok(hasText(d, "Big button on screen"), "Big button on screen row shown")
	eq(#d:findText("Show the big button", true, true), 0, "old Show the big button row gone")
	eq(#d:findText("Keep it on screen when closed", true, true), 0, "old Keep it on screen row gone")
	eq(st.controls["drive.shown"], nil, "drive.shown key removed")
	eq(st.controls["drive.keepClosed"], nil, "drive.keepClosed key removed")
	local seg = st.controls["drive.onScreen"]
	ok(seg, "drive.onScreen control exists")
	do local b = d:button("Always"); ok(d:scrollIntoView(b), "Always scrolls into view"); d:click(b) end
	w:advance(0.2)
	eq(d.env.WuberDB.drive.button.shown, true, "Always sets shown on")
	eq(d.env.WuberDB.drive.button.keepClosed, true, "Always sets keepClosed on")
	do local b = d:button("When riders wait"); ok(d:scrollIntoView(b), "When riders wait scrolls into view"); d:click(b) end
	w:advance(0.2)
	eq(d.env.WuberDB.drive.button.shown, true, "When riders wait sets shown on")
	eq(d.env.WuberDB.drive.button.keepClosed, false, "When riders wait sets keepClosed off")
	do local b = d:button("Always"); ok(d:scrollIntoView(b), "Always scrolls into view"); d:click(b) end
	w:advance(0.2)
	do local b = d:button("Only in Wuber"); ok(d:scrollIntoView(b), "Only in Wuber scrolls into view"); d:click(b) end
	w:advance(0.2)
	eq(d.env.WuberDB.drive.button.shown, false, "Only in Wuber sets shown off")
	eq(d.env.WuberDB.drive.button.keepClosed, true, "Only in Wuber leaves keepClosed untouched")
	do local b = d:button("Always"); ok(d:scrollIntoView(b), "Always scrolls into view"); d:click(b) end
	w:advance(0.2)
	d.env.WuberDB.drive.button.shown = false
	d.W.UI.UpdateSettings()
	eq(seg.value, "wuber", "shown off reads Only in Wuber")
	T.clean(w)
end)

test("v24 diet b: inline buttons on Lock the big button, Big button size and Alert character replace old rows", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local st = openSettings(d, w, "driving")
	ok(hasText(d, "Lock the big button"), "Lock the big button shown")
	local resetPlace = d:button("Reset place")
	ok(resetPlace and H.visible(resetPlace), "Reset place button visible")
	eq(resetPlace:GetParent(), st.controls["drive.locked"].row, "Reset place sits on Lock the big button row")
	ok(hasText(d, "Big button size"), "Big button size shown")
	local fit = d:button("Fit")
	ok(fit and H.visible(fit), "Fit button visible")
	eq(fit:GetParent(), st.controls["drive.scale"].holder:GetParent(), "Fit sits on Big button size row")
	ok(hasText(d, "Alert character"), "Alert character shown")
	local testBtn = d:button("Test")
	local forgetBtn = d:button("Forget")
	ok(testBtn and H.visible(testBtn), "Test button visible")
	ok(forgetBtn and H.visible(forgetBtn), "Forget button visible")
	eq(testBtn:GetParent(), st.controls["drive.bell"]:GetParent(), "Test sits on Alert character row")
	eq(forgetBtn:GetParent(), st.controls["drive.bell"]:GetParent(), "Forget sits on Alert character row")
	for _, old in ipairs({ "Big button position", "Fit the window", "Test the alert", "Forget the crew it learned" }) do
		eq(#d:findText(old, true, true), 0, "old row removed: " .. old)
	end
	T.clean(w)
end)

test("v24 diet b: Drivers on the world map shows OpenMap status with no separate OpenMap row", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local st = openSettings(r, w, "map")
	r.env.OpenMapAPI = nil
	r.W.UI.UpdateSettings()
	ok(hasText(r, "Best with OpenMap: not installed"), "says not installed without OpenMap")
	for _, row in ipairs(st.rows) do
		ok((row.label and row.label:GetText()) ~= "OpenMap", "no separate OpenMap row")
	end
	r.env.OpenMapAPI = {}
	r.W.UI.UpdateSettings()
	ok(hasText(r, "Best with OpenMap: installed"), "says installed with OpenMap")
	eq(#r:findText("Best with OpenMap: not installed", false, true), 0, "not installed text replaced")
	T.clean(w)
end)

test("v24 diet b: Badges over heads writes plates and emblems; Turn on friendly nameplates hides when on", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local st = openSettings(r, w, "sound")
	ok(hasText(r, "Badges over heads"), "Badges over heads row shown")
	eq(#r:findText("Crowns and badges over heads", true, true), 0, "old Crowns and badges row gone")
	eq(#r:findText("Pioneer emblems over heads", true, true), 0, "old Pioneer emblems row gone")
	eq(st.controls.emblems, nil, "emblems key left st.controls")
	r:click(st.controls.plates)
	w:advance(0.5)
	eq(r.env.WuberDB.plates, false, "WuberDB.plates set false")
	eq(r.env.WuberDB.emblems, false, "WuberDB.emblems set false")
	setFriendlyPlates(r, "0")
	r.W.UI.UpdateSettings()
	ok(H.visible(st.controls.nameplates), "Turn on friendly nameplates visible when off")
	ok(hasText(r, "Turn on friendly nameplates"), "button text visible when off")
	local hOff = st.sound:GetHeight()
	setFriendlyPlates(r, "1")
	r.W.UI.UpdateSettings()
	eq(H.visible(st.controls.nameplates), false, "Turn on friendly nameplates hidden when on")
	eq(#r:findText("Turn on friendly nameplates", false, true), 0, "button text hidden when on")
	ok(st.sound:GetHeight() < hOff, "Sound and effects frame shrinks when button is hidden")
	T.clean(w)
end)

test("v24 diet b: Window size has Reset button, no Window position row, and Reset clears WuberDB.pos", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.env.WuberDB.pos = { "CENTER", 0, 120 }
	local st = openSettings(r, w, "window")
	ok(hasText(r, "Window size"), "Window size shown")
	eq(#r:findText("Window position", true, true), 0, "no Window position row")
	local resetBtn = st.controls.resetPos
	ok(resetBtn and H.visible(resetBtn), "Reset button visible")
	eq(resetBtn:GetParent(), st.controls.scale.holder:GetParent(), "Reset sits on Window size row")
	r:click(resetBtn)
	w:advance(0.5)
	eq(r.env.WuberDB.pos, nil, "clicking Reset puts WuberDB.pos back to nil")
	T.clean(w)
end)

test("v24 diet b: Help shows Where to get Wuber with W.UPDATE_URL in a box", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(1)
	r.W.UI.OpenHelp("settings")
	w:advance(1)
	ok(hasText(r, "Where to get Wuber"), "Help shows Where to get Wuber")
	local help = r.W.UI.settings.help
	ok(help and help.urlBox and H.visible(help.urlBox), "address box is visible on Help")
	ok(type(r.W.UPDATE_URL) == "string" and #r.W.UPDATE_URL > 0, "W.UPDATE_URL is non-empty")
	eq(help.urlBox:Text(), r.W.UPDATE_URL, "address box holds W.UPDATE_URL")
	eq(help.urlBox.edit:GetText(), r.W.UPDATE_URL, "edit box holds W.UPDATE_URL")
	T.clean(w)
end)

test("v24 diet b: Search finds Group size, Chat channels and Tips from old terms", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.db.fold = { v = 1, pages = {}, narrow = true }
	local st = openSettings(d, w)
	d:type(st.find.box.edit, "largest group", false)
	w:advance(0.5)
	ok(findResult(st, "Group size"), "largest group finds Group size")
	d:type(st.find.box.edit, "advert channels", false)
	w:advance(0.5)
	ok(findResult(st, "Chat channels"), "advert channels finds Chat channels")
	d:type(st.find.box.edit, "replay", false)
	w:advance(0.5)
	ok(findResult(st, "Tips"), "replay finds Tips")
	T.clean(w)
end)
