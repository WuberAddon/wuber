local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- two unanswered raincheck offers (from two drivers) waiting in the rider's saved rainchecks
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	T.settle(w)
	local W = r.W
	w:addBot("Boris Vane", { spot = "Orgrimmar" })
	w:addBot("Anita Lift", { spot = "Orgrimmar" })
	w:advance(2)
	local t = W.Mod("Net.Base").clock()
	W.db.rainchecks = {
		Rc000001 = { driverKey = W.Key("Boris Vane"), driver = "Boris Vane", addr = "Boris Vane", service = "boris", cover = 5000, expires = t + 6 * 86400, state = "offered", rideId = "Ride0001", at = t },
		Rc000002 = { driverKey = W.Key("Anita Lift"), driver = "Anita Lift", addr = "Anita Lift", service = "anita", cover = 6000, expires = t + 6 * 86400, state = "offered", rideId = "Ride0002", at = t - 5 },
	}
	local card = W.UI.RaincheckOffer()
	w:advance(1)
	return w, r, card
end

test("r47 f3: accepting the first of two raincheck offers: the kept toast names the OTHER driver", function()
	local w, r, card = setup()
	ok(card and H.visible(card), "control: the first offer card shows")
	ok(#r:findText("Boris offers a raincheck", nil, true) > 0, "control: the card is Boris's offer, it reads: " .. T.list(r:visibleTexts()):sub(1, 200))
	card.yes:Click()
	local toast
	for _ = 1, 10 do
		w:advance(1)
		local f = r:findText("Raincheck kept", nil, true)
		if #f > 0 then toast = f[1]:GetText() break end
	end
	ok(toast, "control: a Raincheck kept toast shows")
	ok(toast:find("Boris", 1, true), "the player accepted Boris's raincheck but the toast reads '" .. tostring(toast) .. "'")
	T.clean(w)
end)

test("r47 f3: declining the first of two raincheck offers hides the second offer (nothing brings it back)", function()
	local w, r, card = setup()
	ok(card and H.visible(card), "control: the first offer card shows")
	card.no:Click()
	w:advance(3)
	local list = r.W.Raincheck.Mine()
	local left
	for _, e in ipairs(list) do if e.state == "offered" then left = e end end
	ok(left, "control: one offer is still waiting, unanswered")
	ok(#r:findText("offers a raincheck", nil, true) > 0,
		"the second offer (" .. tostring(left and left.driver) .. ") is still waiting but no offer card is on screen; the player sees: " .. T.list(r:visibleTexts()):sub(1, 200))
	T.clean(w)
end)


test("r47 f3: an Accept refused (3 held already) retires the offer for the session, even after a slot frees", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	T.settle(w)
	local W = r.W
	for _, n in ipairs({ "Boris Vane", "Cara Dunn", "Dmitri Orlov", "Anita Lift" }) do w:addBot(n, { spot = "Orgrimmar" }) end
	w:advance(2)
	local t = W.Mod("Net.Base").clock()
	local function rc(name, state, at, rid)
		return { driverKey = W.Key(name), driver = name, addr = name, service = name:lower(), cover = 5000, expires = t + 6 * 86400, state = state, rideId = rid, at = at }
	end
	W.db.rainchecks = {
		Rc000001 = rc("Boris Vane", "active", t - 100, "Ride0001"),
		Rc000002 = rc("Cara Dunn", "active", t - 101, "Ride0002"),
		Rc000003 = rc("Dmitri Orlov", "active", t - 102, "Ride0003"),
		Rc000004 = rc("Anita Lift", "offered", t, "Ride0004"),
	}
	local card = W.UI.RaincheckOffer()
	w:advance(1)
	ok(card and H.visible(card), "control: the offer card shows")
	card.yes:Click()
	w:advance(1)
	ok(#r:findText("Couldn't answer right now", nil, true) > 0, "control: the refused Accept says so")
	eq(W.Raincheck.Mine()[1].state, "offered", "control: the offer is still unanswered in the rider's copy")
	-- a held raincheck is used up: there is a free slot now
	ok(W.Raincheck.Used("Rc000001"), "a held raincheck is used")
	w:advance(2)
	local back = W.UI.RaincheckOffer()
	w:advance(1)
	ok(back and H.visible(back), "a slot is free and Anita's offer (30 minutes) is unanswered, but no offer card comes back; the player sees: " .. T.list(r:visibleTexts()):sub(1, 150))
	T.clean(w)
end)
