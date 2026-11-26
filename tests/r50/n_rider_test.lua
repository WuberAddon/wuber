-- r50 group N: AU24-17, AU24-18, AU24-33 (Rider Confirm and Ride), the proofs as normal tests plus guards.
local T = ...
local test = T.test
local ok = T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local MIA = "Mia Runner"

local function confirmLine(measured)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	r.W.TravelSaved = function() return 600, "same continent", measured end
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	T.openConfirm(r, "mia runner")
	w:advance(1.5)
	local verdict, line
	for _, t in ipairs(r:visibleTexts()) do
		if t:find("Summon wins by", 1, true) then verdict = t end
		if t:find(" faster", 1, true) then line = t end
	end
	T.clean(w)
	return verdict, line
end

test("AU24-18 r50: a worked-out flight time is 'about' under the verdict too", function()
	local verdict, line = confirmLine(nil)
	ok(verdict and verdict:find("about", 1, true), "control: the verdict says about: " .. tostring(verdict))
	ok(line, "control: the line shows")
	local before = line:match("^(.-)%d+ min faster")
	ok(before and before:find("about", 1, true), "the verdict says about but the line under it gives the same time as exact: " .. line)
end)

-- guard: a measured flight time was never "about" in the verdict, and its line stays exact
test("AU24-18 r50 guard: a measured time stays exact", function()
	local verdict, line = confirmLine(true)
	ok(verdict and line, "both lines show")
	if not verdict:find("about", 1, true) then
		ok(not line:find("about", 1, true), "verdict exact, line should be exact: " .. line)
	end
end)

test("AU24-33 r50: every stop of the Custom tip picker has a tooltip", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local s = r.W.UI.state.screens.found
	ok(s.tipKeys[4]:IsShown(), "control: the Custom key shows (Advanced). Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	ok(s.tipKeys[1].wuberTip, "control: the quick keys have tips")
	s.tipKeys[4]:GetScript("OnClick")(s.tipKeys[4])
	w:advance(1)
	ok(s.pick:IsShown(), "the picker opens")
	local bare = 0
	for _, b in ipairs(s.pick.keys) do
		if b:IsShown() and not b.wuberTip then bare = bare + 1 end
	end
	ok(bare == 0, bare .. " of " .. #s.pick.keys .. " picker stops show no tooltip")
	T.clean(w)
end)

test("AU24-33 r50: the 0 and 100 stops say what they do", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local s = r.W.UI.state.screens.found
	local first, last = s.pick.keys[1].wuberTip, s.pick.keys[#s.pick.keys].wuberTip
	ok(first and tostring(first.title):find("No tip", 1, true), "0 stop: " .. tostring(first and first.title))
	ok(last and tostring(last.title):find("100%", 1, true), "100 stop: " .. tostring(last and last.title))
	T.clean(w)
end)

test("AU24-17 r50: the Cancel ride tip does not say nothing is owed on a ride the rider already paid for", function()
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

-- guard: before paying anything the Cancel tip still says nothing is owed
test("AU24-17 r50 guard: an unpaid ride's Cancel tip says nothing to pay", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "ingroup",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local cancel = r.W.UI.state.screens.found.cancel
	local tip = cancel.wuberTip
	local words = type(tip.text) == "function" and tip.text(cancel) or tip.text
	ok(tostring(words):find("Nothing to pay", 1, true), "unpaid: " .. tostring(words))
	T.clean(w)
end)