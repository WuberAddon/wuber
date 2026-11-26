local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

-- HUNT-81: "Raincheck kept" showed as soon as the rider's V ok was queued. The driver says nothing
-- back to an ok, so the rider's Wuber now waits a few seconds for the game's "No player named"
-- about the driver: none, and the toast says kept; one, and the ok was lost: the offer is back.

-- Anita (Net only) takes Wuber's ride; Wuber pays the whole fare by a completed trade, then cancels
-- before he arrives; he asks for a raincheck and a stand-in for the book offers one
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
	local book = { answers = {} }
	d.W.Listen("RAINCHECK", function(op, a, key, addr)
		if op == "ask" then
			d.W.Raincheck.Give(a, addr, "Rc000001", d.env.time() + 7 * 86400, 5000, "Anita Lift")
		elseif op == "accept" or op == "decline" then
			book.answers[#book.answers + 1] = op .. ":" .. a
		end
	end)
	ok(r.W.Raincheck.Ask(ride.id), "asked")
	w:advance(2)
	local mine = r.W.Raincheck.Mine()[1]
	eq(mine and mine.state, "offered", "Wuber has the offer")
	local card = r.W.UI.RaincheckOffer()
	ok(card and card:IsShown(), "the raincheck card shows")
	return w, d, r, book, card
end

local function kept(r) return #r:findText("Raincheck kept", nil, true) > 0 end

test("r34 b2: HUNT-81: an Accept lost to a driver who logged off never says Raincheck kept, and the offer comes back", function()
	local w, d, r, book, card = offered()
	w:closeClient(d, true) -- Anita logs off before Wuber answers
	card.yes:Click()
	local said, warned = false, false
	for _ = 1, 12 do
		w:advance(1)
		said = said or kept(r)
		warned = warned or #r:findText("Couldn't answer right now", nil, true) > 0
	end
	ok(not said, "no Raincheck kept toast for an ok the driver never got")
	eq(#book.answers, 0, "control: Anita never heard the ok")
	local mine = r.W.Raincheck.Mine()[1]
	eq(mine and mine.state, "offered", "the rider's copy is an offer again, not a raincheck held")
	eq(r.W.Raincheck.ForDriver("anita lift"), nil, "nothing to use with Anita")
	ok(warned, "a toast says the answer didn't go")
	ok(card:IsShown(), "the card is back to answer again")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("r34 b2: HUNT-81: an Accept the driver got says Raincheck kept once the game had time to say she is not on", function()
	local w, d, r, book, card = offered()
	card.yes:Click()
	w:advance(1)
	eq(book.answers[1], "accept:Rc000001", "Anita heard the ok")
	local said = false
	for _ = 1, 8 do
		w:advance(1)
		said = said or kept(r)
	end
	ok(said, "Raincheck kept shows")
	eq(r.W.Raincheck.Mine()[1].state, "active", "active")
	eq(r.W.Raincheck.ForDriver("anita lift"), "Rc000001", "usable with Anita")
	eq(#r:findText("Couldn't answer right now", nil, true), 0, "no warning")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("r34 b2: HUNT-81: a lost Accept can be answered again once the driver is back", function()
	local w, d, r, book, card = offered()
	w:closeClient(d, true)
	card.yes:Click()
	w:advance(12)
	eq(r.W.Raincheck.Mine()[1].state, "offered", "offered again")
	w:player(ANITA).online = true -- (her window is closed; the game still delivers to her)
	local d2 = w:addClient(ANITA, { saved = w.savedOf and w.savedOf[ANITA] })
	w:advance(2)
	ok(r.W.Raincheck.Accept("Rc000001"), "a second Accept goes")
	w:advance(10)
	eq(r.W.Raincheck.Mine()[1].state, "active", "kept this time")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
