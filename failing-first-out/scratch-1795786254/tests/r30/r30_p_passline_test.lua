local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function topOf(fr)
	local _, _, _, _, y = fr:GetPoint(1)
	return -(y or 0)
end

test("r30 P HUNT-05: the passphrase line goes back up when the PvP warning card goes away", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local ANA = "Ana Smith"
	r.W.ride = { id = "r30p", driver = ANA, driverKey = key(ANA), dest = "Ratchet", price = 5000, state = "accepted",
		at = r.env.GetTime(), position = 2, eta = 50, ritual = { danger = 3 } }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local s = r.W.UI.state.screens.found
	ok(H.visible(s.alert) and H.visible(s.queue), "control: card and queue line both show")
	s.pass:Show()
	s.placeStack()
	-- (design 4, A2) the live stack moves down with the portal's size: places are told from the driver card's
	eq(topOf(s.pass) - topOf(s.card), 394 - 192, "both up: the passphrase line is below the card")
	-- the danger goes away: the card hides, the queue line stays
	r.W.ride.ritual = { danger = 0 }
	r.W.Fire("RIDE")
	w:advance(3)
	ok(not s.alertHead, "control: the card is gone")
	ok(H.visible(s.queue), "control: the queue line is still up")
	eq(topOf(s.pass) - topOf(s.card), 350 - 192, "card gone: the passphrase line is back at its place")
	-- card up, queue line gone
	r.W.ride.ritual = { danger = 3 }
	r.W.ride.position = nil
	r.W.Fire("RIDE")
	w:advance(3)
	ok(s.alertHead, "control: the card is up again")
	s.pass:Show()
	s.placeStack()
	eq(topOf(s.pass) - topOf(s.card), 350 - 192, "card up, no queue line: the passphrase line is at its place")
	T.clean(w)
end)
