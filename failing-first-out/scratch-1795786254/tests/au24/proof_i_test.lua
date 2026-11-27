-- Proof tests of job 2620 (audit-241), area I: Rider screens.
local T = ...
local test = T.test
local ok, H = T.ok, T.H
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

test("AU24-08: a trade opened a moment before the arrival is noticed still gets its how-to-pay strip", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "summoning",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	w:addBot(MIA, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(MIA), r.player), "the driver opens trade")
	w:advance(1.5)
	r.W.ride.state = "arrived"
	r.W.Fire("RIDE")
	w:advance(3)
	local strip = r:findText("Wuber: ")
	ok(#strip > 0, "the trade is open and the ride has arrived: the strip says what to type. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	T.clean(w)
end)

test("AU24-25: typing a driver's whole name finds that driver even when the name starts a place's name", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["gadget runner"] = { name = "Gadget Runner", key = "gadget runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Gadget's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(1.5)
	local e = r.W.UI.state.screens.home.search.edit
	e:SetText("Gadget")
	e:GetScript("OnEnterPressed")(e)
	w:advance(1)
	local seen = T.list(r:visibleTexts())
	ok(seen:find("Gadget's Rides", 1, true), "the driver the player typed is listed. Visible: " .. seen:sub(1, 400))
	T.clean(w)
end)

proof("AU24-18", "a flight time that is only worked out is 'about' wherever the booking card states it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	-- an estimate: not measured (third value nil)
	r.W.TravelSaved = function() return 600, "same continent", nil end
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	T.openConfirm(r, "mia runner")
	w:advance(1.5)
	local seen = T.list(r:visibleTexts())
	local verdict, line
	for _, t in ipairs(r:visibleTexts()) do
		if t:find("Summon wins by", 1, true) then verdict = t end
		if t:find(" faster", 1, true) then line = t end
	end
	ok(verdict and verdict:find("about", 1, true), "control: the verdict says about. Visible: " .. seen:sub(1, 500))
	ok(line, "control: the line under the verdict shows. Visible: " .. seen:sub(1, 500))
	local before = line:match("^(.-)%d+ min faster")
	ok(before and before:find("about", 1, true), "the verdict says about but the line under it gives the same time as exact: " .. line)
	T.clean(w)
end)

proof("AU24-17", "the Cancel ride tip does not say nothing is owed on a ride the rider already paid for", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "ingroup",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides", paid = 5000, paidSoFar = 5000 }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local cancel = r.W.UI.state.screens.found.cancel
	ok(cancel:IsShown(), "control: the player can still cancel before the summon. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	local tip = cancel.wuberTip
	local words = type(tip.text) == "function" and tip.text(cancel) or tip.text
	ok(not tostring(words):find("Nothing to pay", 1, true), "paid in full, yet the tip says: " .. tostring(words))
	T.clean(w)
end)
