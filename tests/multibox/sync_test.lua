-- Multibox safety, sync (Drive.Team): crew facts and settings travel only between windows the author marked as their own (a crew
-- offer each window answered yes to), never from another Warlock in the same party, and never twice after a reload.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANA, BEA, CAL = T.ANA, T.BEA, T.CAL

-- Ana (captain) and Bea (her own other window); Cal is a third Warlock with Wuber who leads the party and is NOT in the crew.
local function party(joinBea)
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "WARLOCK" })
	w:group({ CAL, ANA, BEA })
	T.settle(w)
	if joinBea then
		ok(ana.W.Drive.OfferCrew(BEA), "setup: the crew offer to Bea")
		w:advance(3)
		bea.W.Drive.AnswerOffer(ANA, true)
		w:advance(3)
		ok(bea.W.Drive.char().captain ~= "", "setup: Bea says yes and is in Ana's crew")
	end
	return w, ana, bea, cal
end

test("multibox sync: an offer nobody answered yes to changes nothing on the other window", function()
	local w, ana, bea = party(false)
	ok(ana.W.Drive.OfferCrew(BEA), "the offer goes out")
	w:advance(3)
	ana.W.Drive.SetPrice(77000)
	ana.W.Drive.SendConfig()
	w:advance(5)
	eq(bea.W.Drive.char().captain, "", "Bea never said yes: no captain")
	ok(bea.W.Char().price ~= 77000, "Bea's price is not the captain's")
	T.clean(w)
end)

test("multibox sync: a Warlock who leads the party but is no crew member cannot set a window's price, place or block list", function()
	local w, ana, bea, cal = party(true)
	ana.W.Drive.SetPrice(20000)
	ana.W.Drive.SendConfig()
	w:advance(5)
	eq(bea.W.Char().price, 20000, "control: the captain's price reaches the own window")
	cal.W.Drive.SetPrice(99000)
	cal.W.Drive.SetDest("Undercity")
	cal.W.Drive.SendConfig()
	cal.W.Drive.SendService()
	cal.W.Drive.Blacklist("Dan Miller", "test")
	w:advance(8)
	eq(bea.W.Char().price, 20000, "Cal's price did not reach Bea")
	eq(ana.W.Char().price, 20000, "nor Ana")
	ok(bea.W.Drive.Dest() ~= "Undercity", "Cal's place did not reach Bea")
	ok(not bea.W.Drive.db.blocklist[T.H.key("Dan Miller")], "Cal's block did not reach Bea")
	ok(not ana.W.Drive.db.blocklist[T.H.key("Dan Miller")], "nor Ana")
	T.clean(w)
end)

test("multibox sync: another Warlock in the party cannot make the own windows think a stranger was whispered", function()
	local w, ana, bea, cal = party(true)
	cal.W.Drive.Send("RPL", "dan miller")
	w:advance(5)
	local key = T.H.key("Dan Miller")
	for _, c in ipairs({ ana, bea }) do
		local r = c.env.WuberDB.drive.replied
		ok(not (type(r) == "table" and r[key]), c.player.name .. ": no stamp from a window that is not in the crew")
	end
	ana.W.Drive.Send("RPL", "eve stone")
	w:advance(5)
	local r = bea.env.WuberDB.drive.replied
	ok(type(r) == "table" and r[T.H.key("Eve Stone")], "control: the same fact from the captain is believed")
	T.clean(w)
end)

test("multibox sync: a block set on one own window reaches the other once, and a reload does not send it back as news", function()
	local w, ana, bea = party(true)
	ana.W.Drive.Blacklist("Dan Miller", "rude")
	w:advance(8)
	local k = T.H.key("Dan Miller")
	ok(bea.W.Drive.db.blocklist[k], "control: the block reached the own window")
	local at = bea.W.Drive.db.blocklist[k].at
	local nb = w:reload(bea)
	w:advance(10)
	ok(nb.W.Drive.db.blocklist[k], "still blocked after the reload")
	eq(nb.W.Drive.db.blocklist[k].at, at, "the block's date did not change on the reload")
	T.clean(w)
end)

test("multibox sync: a window that left the crew hears nothing more from the old captain", function()
	local w, ana, bea = party(true)
	bea.W.Drive.LeaveCrew()
	w:advance(4)
	ana.W.Drive.SetPrice(33000)
	ana.W.Drive.SendConfig()
	w:advance(5)
	ok(bea.W.Char().price ~= 33000, "after leaving, the old captain's price is not followed")
	T.clean(w)
end)
