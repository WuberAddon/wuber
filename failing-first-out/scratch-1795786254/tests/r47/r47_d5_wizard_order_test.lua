local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
test("r47 d5: AUD-176 Step 3 shows a Warlock ticked when she says Yes while it is open, and Done keeps her the summoner", function()
	local w = T.newWorld()
	local m = w:addClient("Mick Mage", { spot = "Ratchet", class = "MAGE", money = 100000 })
	local wd = w:addClient("Wanda Lock", { spot = "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
	w:group({ "Mick Mage", "Wanda Lock" })
	T.settle(w)
	m.W.Drive.SetRunner(true)
	T.openDrive(m)
	m.W.Driver.ShowScreen("wizard") w:advance(1)
	m:clickText("A Warlock friend") w:advance(0.5)
	m:clickText("^Next$", { pattern = true }) w:advance(1)
	m:clickText("^Send offers$", { pattern = true }) w:advance(3)
	ok(wd.W.Drive.pendingOffers and wd.W.Drive.pendingOffers[key("Mick Mage")], "control: Wanda got the crew card")
	m:clickText("^Next$", { pattern = true }) w:advance(1) -- on to Step 3 before she answers
	ok(#m:findText("Who summons%?") > 0, "control: Step 3 is open")
	wd.W.Drive.AnswerOffer("Mick Mage", true) w:advance(4) -- she taps Yes
	eq(table.concat(m.W.Drive.Summoners() or {}, ","), "wanda lock", "control: the engine made Wanda the summoner")
	ok(#m:findText("main caster") > 0 and #m:findText("Tick at least one Warlock") == 0,
		"Wanda is already the summoner but Step 3 shows her unticked and says 'Tick at least one Warlock': " .. T.list(m:visibleTexts()):sub(-330))
	m:clickText("^Done$", { pattern = true }) w:advance(1)
	eq(table.concat(m.W.Drive.Summoners() or {}, ","), "wanda lock", "Done on the stale Step 3 wiped the summoner")
	T.clean(w)
end)

test("r47 d5: AUD-176 a Warlock alone can still untick herself on Step 3 (the order is not re-read over her click)", function()
	local w = T.newWorld()
	local a = w:addClient("Ada Lock", { spot = "Undercity", class = "WARLOCK", shards = 5 })
	w:advance(15)
	a.W.Char().wizard = true
	T.openDrive(a)
	a.W.UI.ShowDrive("wizard", 3)
	w:advance(1)
	local wz = a.W.UI.drive.wizard
	eq(wz.step, 3, "control: opened on step 3")
	local me
	for _, r in ipairs(wz.summoners.list) do if r:IsShown() and r.p and r.p.me then me = r end end
	ok(me and me.toggle.on, "control: a Warlock alone starts ticked")
	a:clickOn(me.toggle)
	w:advance(0.5)
	ok(not me.toggle.on, "her own row stays unticked after her click")
	eq(#wz.order, 0, "nobody ticked")
	a:clickOn(me.toggle)
	w:advance(0.5)
	ok(me.toggle.on, "ticks again")
	eq(table.concat(wz.order, ","), a.W.myKey, "just her")
	T.clean(w)
end)


test("r47 d5: AUD-176 the captain's own unsaved tick stays when a friend Warlock says Yes on Step 3", function()
	local w = T.newWorld()
	local c = w:addClient("Cora Lock", { spot = "Ratchet", class = "WARLOCK", shards = 5, money = 100000 })
	local f = w:addClient("Fred Lock", { spot = "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
	w:group({ "Cora Lock", "Fred Lock" })
	T.settle(w)
	c.W.Drive.SetRunner(true)
	T.openDrive(c)
	c.W.Drive.OfferCrew("Fred Lock", "raid") w:advance(3) -- a raid pick summons, even beside a Warlock captain
	ok(f.W.Drive.pendingOffers and f.W.Drive.pendingOffers[key("Cora Lock")], "control: Fred got the crew card")
	c.W.Char().wizard = true
	c.W.UI.ShowDrive("wizard", 3) w:advance(1)
	local wz = c.W.UI.drive.wizard
	eq(wz.step, 3, "control: on Step 3")
	local me
	for _, r in ipairs(wz.summoners.list) do if r:IsShown() and r.p and r.p.me then me = r end end
	ok(me, "control: her own row is there")
	if not me.toggle.on then c:clickOn(me.toggle) w:advance(0.5) end
	eq(table.concat(wz.order, ","), c.W.myKey, "control: she ticked herself, not saved")
	f.W.Drive.AnswerOffer("Cora Lock", true) w:advance(4)
	eq(table.concat(wz.order, ","), c.W.myKey .. "," .. key("Fred Lock"), "both ticked, the captain first")
	-- (the test harness does not clip the scrolled Step 3 page, so a click at Done would land on a bell pill
	-- drawn below the scroll area: run the button's own click)
	wz.next:GetScript("OnClick")()
	w:advance(1)
	eq(table.concat(c.W.Drive.Summoners() or {}, ","), c.W.myKey .. "," .. key("Fred Lock"), "Done saved both")
	T.clean(w)
end)
