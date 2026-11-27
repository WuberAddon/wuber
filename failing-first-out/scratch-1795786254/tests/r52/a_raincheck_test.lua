local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

-- r52 audit #1: Raincheck.Accept took its offlineUntil snapshot after W.SendTo, and a send that
-- delivers at once to a driver cached as offline (Net.Transport tellNotFound) has already moved
-- that stamp: the lost ok then read as "no change" and showed Raincheck kept.
local function offered()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	ok(d.W.AcceptRequest(ride.id, 5), "accepted")
	w:group({ ANITA, TESTCHAR })
	w:advance(1)
	w:move(ANITA, "Orgrimmar")
	w:advance(1)
	ok(w:openTrade(w:player(ANITA), w:player(TESTCHAR)), "a trade opens")
	w:tradeMoney(w:player(TESTCHAR), ride.price)
	w:tradeAccept(w:player(ANITA))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(6)
	ok(r.W.CancelRide(), "the ride ends before arrival")
	w:advance(1)
	d.W.Listen("RAINCHECK", function(op, a, key, addr)
		if op == "ask" then
			d.W.Raincheck.Give(a, addr, "Rc000001", d.env.time() + 7 * 86400, 5000, "Anita Lift")
		end
	end)
	ok(r.W.Raincheck.Ask(ride.id), "asked")
	w:advance(2)
	eq(r.W.Raincheck.Mine()[1].state, "offered", "Wuber has the offer")
	return w, d, r
end

local function kept(r) return #r:findText("Raincheck kept", nil, true) > 0 end

test("r52 a1: an Accept whose send already learned the driver is offline never says kept; the offer comes back", function()
	local w, d, r = offered()
	local fb = r.W.Mod("Net.Base").fb
	local real = r.W.SendTo
	-- the send delivers at once to a driver cached offline: the game's not-found line lands inside it
	r.W.SendTo = function(to, kind, ...)
		if kind == "V" then fb.offlineUntil["anita lift"] = r.env.time() + 300 return true end
		return real(to, kind, ...)
	end
	ok(r.W.Raincheck.Accept("Rc000001"), "the accept goes")
	local said = false
	for _ = 1, 12 do
		w:advance(1)
		said = said or kept(r)
	end
	r.W.SendTo = real
	ok(not said, "no Raincheck kept for an ok the driver never got")
	eq(r.W.Raincheck.Mine()[1].state, "offered", "the offer is back")
	T.clean(w)
end)

-- guard: the normal online accept still says kept (the unchanged path)
test("r52 a1: an Accept to an online driver still says Raincheck kept", function()
	local w, d, r = offered()
	local card = r.W.UI.RaincheckOffer()
	ok(card and card:IsShown(), "the raincheck card shows")
	card.yes:Click()
	local said = false
	for _ = 1, 8 do
		w:advance(1)
		said = said or kept(r)
	end
	ok(said, "Raincheck kept shows")
	eq(r.W.Raincheck.Mine()[1].state, "active", "active")
	T.clean(w)
end)

-- r52 audit #9: a crew window that never heard of a raincheck gets only IOU "u" from the join sync;
-- it must count toward the 3-a-day cap like an "i" does.
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
local function crewScene()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	w:group(names)
	w:advance(15)
	return w, cs[2], cs[1]
end

local function book(c) return (c.W.db.drive and c.W.db.drive.iou) or {} end

test("r52 a9: the join sync sends a used raincheck as i then u, so a new window counts it toward the day's cap", function()
	local w, bea, ana = crewScene()
	local DR = ana.W.Drive
	DR.SetOpen(true)
	w:advance(8)
	local exp = ana.env.time() + 7 * 86400
	DR.RaincheckFact(key(ANA), true, "i", "Used0001", "rider a", 5000, exp, "")
	DR.RaincheckFact(key(ANA), true, "u", "Used0001", "rider a", 5000, exp, "")
	local before = #w.addonLog
	DR.RaincheckSync()
	w:advance(45)
	local ops = {}
	for k = before + 1, #w.addonLog do
		local e = w.addonLog[k]
		local op = e.prefix == "WUBERT" and e.from == ANA and e.text:match("^IOU~1~(%a)~Used0001")
		if op then ops[#ops + 1] = op end
	end
	eq(table.concat(ops), "iu", "i then u went out")
	T.clean(w)
end)

-- guard: a window that joins and hears i then u counts it, and a lone u for a stranger still makes nothing
test("r52 a9: i then u counts toward the cap; a lone u or v for a stranger makes no entry", function()
	local w, bea = crewScene()
	local DR = bea.W.Drive
	local exp = bea.env.time() + 7 * 86400
	DR.RaincheckFact(key(ANA), false, "u", "Lone0001", "rider z", 5000, exp, "")
	eq(book(bea).Lone0001, nil, "a lone u makes no entry")
	DR.RaincheckFact(key(ANA), false, "i", "Norm0001", "rider a", 5000, exp, "")
	DR.RaincheckFact(key(ANA), false, "u", "Norm0001", "rider a", 5000, exp, "")
	DR.RaincheckFact(key(ANA), false, "i", "Norm0002", "rider c", 5000, exp, "")
	DR.RaincheckFact(key(ANA), false, "i", "Norm0003", "rider d", 5000, exp, "")
	ok(book(bea).Norm0003, "the 3rd is taken")
	DR.RaincheckFact(key(ANA), false, "i", "Norm0004", "rider e", 5000, exp, "")
	eq(book(bea).Norm0004, nil, "the 4th is refused")
	T.clean(w)
end)
