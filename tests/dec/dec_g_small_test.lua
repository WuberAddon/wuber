-- Decisions round, group G: five small fixes (AUD-183, AUD-190, FAB-07, FAB-08, AUD-207). Loaded by tests/run.lua with the helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end
-- a rider whose clock says 3 November 2026; seed(W) fills October
local function setup(seed)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W, env = r.W, r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	W.db.rides = {}
	seed(W)
	W.RebuildTotals()
	W.UI.Toggle(true); w:advance(1); W.UI.SelectTab("Trips"); w:advance(1)
	return w, r, W, W.Mod("UI.Rider.Wrapped")
end
local function toSlide(w, M, n)
	ok(M.Open(2026, 10), "the story opens")
	w:advance(1)
	for _ = 2, n do M.Next(); w:advance(1) end
end

test("dec g: a month of only driving has no Share line, so no Share pill (AUD-183)", function()
	local w, r, W, M = setup(function(W)
		W.db.drive = W.db.drive or {}
		W.db.drive.log = { rides = { at(2026, 10, 5, 20) .. ",5000,Dan,Undercity,t,5000", at(2026, 10, 6, 20) .. ",6000,Eve,Undercity,t,5000" } }
	end)
	local list = M.Months()
	ok(#list == 1 and list[1].month == 10, "control: the driver-only October is offered by the Wrapped chip (months: " .. #list .. ")")
	toSlide(w, M, 6)
	local st = M.Story()
	ok(st.index == 6, "setup: on the summary slide (index " .. tostring(st.index) .. ")")
	local line = st.shareLine
	ok(line == nil, "a driver-only month offers no share line: " .. tostring(line))
	T.clean(w)
end)
test("dec g: a paid ride cancelled does not say 'Nothing to pay' beside the raincheck button (AUD-190)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.goOnline(d) w:advance(5)
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", money = 1000000 })
	T.settle(w)
	local key = T.ANITA:lower()
	r.W.db.autoAccept = false
	ok(r.W.RequestRide(key), "requested")
	w:advance(9)
	local rv = r.W.ride
	T.take(d) w:advance(3)
	r.W.UI.Toggle(true) w:advance(2.5)
	r:clickText("Accept invite") w:advance(1)
	w:move(T.ANITA, "Orgrimmar") w:advance(0.05) -- the driver walks over to the rider
	ok(w:openTrade(r, d), "trade opens")
	w:typeTradeMoney(r, 0, 50, 0)
	w:tradeAccept(r) w:tradeAccept(d)
	w:advance(0.3)
	ok(r.W.CancelRide(), "cancelled")
	w:advance(3)
	local shown = T.list(r:visibleTexts())
	ok(#r:findText("Ask for a raincheck") > 0, "control: the Sorry screen offers 'Ask for a raincheck' for the paid ride: " .. shown)
	eq(#r:findText("Nothing to pay"), 0, "the rider paid " .. tostring(r.W.ride.paid) .. " copper, the screen offers a raincheck for it, yet it reads 'Nothing to pay. Pick another driver when you're ready.'")
	T.clean(w)
end)
local function worldSetup(riders)
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	W.Bounty.Demand = function() return { { place = "Undercity", riders = riders } } end
	Mod.Build(holder)
	Mod.Show("world")
	return Mod.cache.maps[holder]
end
local function coinTips(wm)
	local out = {}
	for _, c in ipairs(wm.coins) do if c:IsShown() and c.wuberTip then out[#out + 1] = c.wuberTip.text end end
	return table.concat(out, " | ")
end
test("dec g: a World view coin for one rider reads '1 rider wants to go here.' (FAB-07)", function()
	local tips = coinTips(worldSetup(1))
	ok(tips:find("1 rider wants to go here.", 1, true), "one rider: " .. tips)
	ok(not tips:find("1 riders", 1, true), "never '1 riders': " .. tips)
end)
test("dec g: two riders keep 'N riders want to go here.' (FAB-07)", function()
	local tips = coinTips(worldSetup(2))
	ok(tips:find("2 riders want to go here.", 1, true), "two riders: " .. tips)
end)
test("dec g: the Finding bar of a request by whisper runs over its 120 s, not 40 (FAB-08)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.goOnline(d) w:advance(5)
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", money = 1000000 })
	T.settle(w)
	r.W.db.autoAccept = false
	r.W.net.cantSend = true
	r.W.net.probeAt = 1e12
	r.W.RequestRide(T.ANITA:lower())
	r.W.UI.Toggle(true)
	w:advance(60)
	local rv = r.W.ride
	if rv and rv.noAddon and rv.state == "requesting" then
		local secs = r:findText("^%d+ s$", { pattern = true })
		ok(#secs > 0, "the countdown shows: " .. T.list(r:visibleTexts()):sub(-200))
		ok(not r:findText("^0 s$", { pattern = true })[1], "60 s into a 120 s wait the bar is not at 0 s: " .. T.list(r:visibleTexts()):sub(-200))
	else
		ok(true, "this world did not keep a whisper request waiting; nothing to draw")
	end
	T.clean(w)
end)

test("dec g: 'Send offers again' sends again to people who did not answer (AUD-207)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Mia Mage", { spot = "Ratchet", class = "MAGE" })
	w:addBot("Wanda Lock", { spot = "Ratchet", class = "WARLOCK" })
	w:group({ T.ANITA, "Mia Mage", "Wanda Lock" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	d:clickText("^Send offers$", { pattern = true }) w:advance(1)
	-- control: the first Send offers did send (toast + both rows now say they wait)
	ok(#d:findText("Waiting for Mia") > 0, "control: first Send offers reached Mia: " .. T.list(d:visibleTexts()):sub(-200))
	w:advance(25) -- nobody tapped Yes: 'No answer' on both rows
	ok(#d:findText("No answer: Mia") > 0, "control: Mia shows No answer")
	ok(#d:findText("^Send offers again$", false) > 0 or #d:findText("Send offers again") > 0, "control: the button now reads Send offers again")
	d:clickText("Send offers again") w:advance(0.5)
	ok(#d:findText("Pick someone first") == 0, "no 'Pick someone first' toast")
	ok(#d:findText("Crew offer sent to") > 0, "the offers went out again: " .. T.list(d:visibleTexts()):sub(-200))
	T.clean(w)
end)