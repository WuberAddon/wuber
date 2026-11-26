-- Job 2807, issue #151: player words that said something the code does not do. Each test asserts the words the
-- player reads, on the screen or in the chat line that shows them. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function val(v, f)
	if type(v) == "function" then local good, r = pcall(v, f) return good and r or nil end
	return v
end

-- the tooltip text of the first frame of c whose tooltip title is title (and whose text contains must, when given)
local function tipOf(c, title, must)
	for _, f in ipairs(c.frames) do
		local tip = rawget(f, "wuberTip") or f.wuberTip
		if type(tip) == "table" and val(tip.title, f) == title then
			local t = val(tip.text, f)
			if type(t) == "string" and (not must or t:find(must, 1, true)) then return t, f end
		end
	end
end

local function has(c, text) return #c:findText(text, true, true) > 0 end

local function homeWorld()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(1.5)
	return w, r
end

local function driverWorld(screen)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	DR.customers = {}
	DR.IsOpen = function() return true end
	W.UI.WindowWide(false)
	T.openDrive(a)
	if W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	if screen then W.Driver.ShowScreen(screen) w:advance(1) end
	return w, a
end

test("c2807 #151 1 Where to? tip on the rider's search box says only drivers going there are listed", function()
	local w, r = homeWorld()
	local t = tipOf(r, "Where to?")
	ok(t, "the search box has its tip")
	eq(t, "Type a place, like Undercity or Booty Bay. Only drivers who match are listed.", "the search tip")
	T.clean(w)
end)

test("c2807 #151 1 Where to? coach card says only drivers going there are listed", function()
	local w, r = homeWorld()
	r.W.UI.ReplayCoach()
	w:advance(2)
	ok(has(r, "Type a place, like Undercity."), "control: the coach card shows")
	ok(has(r, "Type a place, like Undercity. Only drivers who match are listed."), "the coach card's words")
	ok(not has(r, "show first"), "no 'show first' left")
	T.clean(w)
end)

test("c2807 #151 2 the driver console's tip names the Options button, not '...'", function()
	local w, a = driverWorld()
	ok(has(a, "Tip: hold a name (or tap its"), "control: the tip is on the console")
	ok(has(a, "Tip: hold a name (or tap its Options button) for more."), "the tip names the Options button")
	ok(not has(a, "tap its ..."), "no '...' button named")
	T.clean(w)
end)

test("c2807 #151 3 the Get Wuber message says when it is sent: on the next big-button click", function()
	local w, a = driverWorld("messages")
	ok(has(a, "Get Wuber"), "control: the Get Wuber message is in the list")
	ok(has(a, "on your next big-button click after you tap Invite to Wuber on their row"), "the new words")
	ok(not has(a, "when you tap Invite to Wuber on their row"), "the old words are gone")
	T.clean(w)
end)

test("c2807 #151 4 Reset and Save tips say the crew part is for the crew leader", function()
	local w, a = driverWorld("messages")
	a.W.UI.drive.screens.messages.edit("greet")
	eq(tipOf(a, "Reset to default"), "Puts back Wuber's own wording for this message (your crew gets it too if you lead the crew).", "Reset tip")
	eq(tipOf(a, "Save"), "Uses this message from now on. If you lead the crew, every window of your crew uses it too.", "Save tip")
	T.clean(w)
end)

local function miniWorld(raid)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	DR.IsPaused = function() return false end
	DR.IsOpen = function() return true end
	D.CanPause = function() return true end
	if D.kit then D.kit.RaidMode = function() return raid end end
	D.UpdateMini()
	local m = a.W.UI.drive.mini
	if m then m.dirty = true end
	D.UpdateMini()
	return w, a, a.W.UI.drive.mini
end

test("c2807 #151 5 the mini console's Pause tip in raid mode says nobody is summoned", function()
	local w, a, m = miniWorld(true)
	ok(m and m.pause, "control: the mini console has its Pause pill")
	local tip = m.pause.wuberTip
	eq(val(tip.text, m.pause), "Pause: no new summons. Resume: summon raiders again.", "raid mode Pause tip")
	T.clean(w)
end)

test("c2807 #151 5 the mini console's Pause tip is unchanged outside raid mode", function()
	local w, a, m = miniWorld(false)
	local tip = m.pause.wuberTip
	eq(val(tip.text, m.pause), "Pause: no new invites, riders in your group are still summoned. Resume: invite again.", "normal Pause tip")
	T.clean(w)
end)

test("c2807 #151 6 the block reason box says what Block and tell them does", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	local row = d.env.WuberDriveMini.rows[1]
	ok(row and H.visible(row), "control: a rider row shows")
	d:clickOn(row.more) w:advance(1)
	d:click((d:button("Block...")))
	w:advance(1)
	ok(has(d, "Why ("), "control: the reason box is up")
	ok(has(d, "Why (they're told if you chose Block and tell them)"), "the new placeholder")
	ok(not has(d, "Tell blocked players why"), "the old setting name is gone")
	T.clean(w)
end)

test("c2807 #151 7 /wuber why names where Replay is: the Tips row of Settings, Riding", function()
	local w, r = homeWorld()
	local Coach = r.W.Mod("UI.Coach")
	r.W.db.coach = false
	r.W.UI.state.coaching = nil
	r.W.UI.state.coachTried = true
	local line = Coach.Why()
	ok(line and line:find("The Replay button on the Tips row of Settings, Riding, starts it again.", 1, true), "why line: " .. tostring(line))
	T.clean(w)
end)

test("c2807 #151 8 the hidden-drivers row says right-click works in Advanced mode", function()
	local w, r = homeWorld()
	r.W.UI.OpenSettings("riding")
	w:advance(1)
	r.W.UI.UpdateSettings()
	w:advance(0.5)
	local row = r.W.UI.settings.hiddenRow:GetParent()
	ok(row.subText and row.subText:find("ight-click a card to hide a driver.", 1, true), "control: the row's line is set: " .. tostring(row.subText))
	eq(row.subText, "In Advanced mode, right-click a card to hide a driver.", "the row's words")
	T.clean(w)
end)

local function pauseWorld(raid)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d)
	if raid then d:slash("/wuber drive raid") end
	return w, d
end

test("c2807 #151 9 /wuber drive pause in raid mode says nobody is summoned", function()
	local w, d = pauseWorld(true)
	eq(d.W.Drive.Mode(), "raid", "control: raid mode")
	d:slash("/wuber drive pause")
	ok(d:said("Paused: nobody is summoned until you resume."), "raid pause line")
	ok(not d:said("Paused: nobody new is invited"), "not the selling line")
	T.clean(w)
end)

test("c2807 #151 9 /wuber drive pause outside raid mode keeps today's line", function()
	local w, d = pauseWorld(false)
	d:slash("/wuber drive pause")
	ok(d:said("Paused: nobody new is invited. Riders already with you carry on."), "normal pause line")
	T.clean(w)
end)

test("c2807 #151 11 /wuber drive add for a player who cannot be added says so plainly", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d, { price = 500 })
	w:addBot("Dan Miller", { spot = "Ratchet" })
	d:slash("/wuber drive block Dan Miller")
	d:slash("/wuber drive add Dan Miller")
	ok(d:said("Dan Miller can't be added to the list right now."), "the new words")
	ok(not d:said("in your crew, or blocked"), "the old words are gone")
	T.clean(w)
end)

test("c2807 #151 10 /wuber drive ad none says timed adverts are off and Advertise still posts to the first channel", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d, { price = 500 })
	d.env.JoinChannelByName("Trade")
	w:advance(1)
	d:slash("/wuber drive ad none")
	eq(d.W.Drive.opts().adChannels, "", "control: no channel is saved")
	eq(#d.W.Drive.AdTargets(), 0, "no timed target")
	ok(not d.W.Drive.AdvertDue(), "the timed reminder is off")
	ok(d:said("Timed adverts are off. Advertise still posts to the first channel joined."), "the new line")
	ok(not d:said("Adverts go to: the first channel joined"), "not the old line")
	w:advance(16 * 60) -- the network's 15 minute gap after going online
	local plan, why = d.W.AdvertPlan("Undercity", 500, {})
	ok(plan and plan.index and plan.base == "trade", "a manual Advertise still targets the joined channel: " .. tostring(why))
	T.clean(w)
end)

test("c2807 #151 10 /wuber drive ad with channels set keeps today's line", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d:slash("/wuber drive ad trade")
	ok(d:said("Adverts go to: trade, in turn."), "today's line")
	T.clean(w)
end)
