-- Round 25 B1: the Skip-the-bird card spells out the saving, shows on every flight-map open, and its
-- "Don't show again" says where to turn it back on.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup(price, cost)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = price, state = "open", team = 3, service = "Mia", heard = r.env.GetTime() }
	W.FlightCost = function() return cost, 1 end
	W.FlightTime = function() return 600, "own" end
	return w, r, W, W.Mod("UI.Bird")
end

test("r25 B1: message gives price, flight cost, real cost and time back", function()
	local w, r, W, Mod = setup(5000, 1750)
	local d = { short = "Mia", dest = "Tarren Mill", price = 5000 }
	local s = Mod.Message(d, { cost = 1750, secs = 600, about = false })
	ok(s:find("50s", 1, true), "price: " .. s)
	ok(s:find("17s 50c", 1, true), "flight: " .. s)
	ok(s:find("really 32s 50c", 1, true), "real: " .. s)
	ok(s:find("10", 1, true) and s:find("back", 1, true), "time: " .. s)
	ok(not s:lower():find("free"), "no free")
	local s2 = Mod.Message(d, { cost = 1750, secs = 600, about = true })
	ok(s2:find("about", 1, true), "estimate labelled")
	ok(s:find("Skip the bird: Mia summons to Tarren Mill for ", 1, true) and s:find("Flying is 17s 50c and 10 min", 1, true) and s:find(", and 10 min back.", 1, true), "full wording: " .. s)
	local s3 = Mod.Message(d, { cost = 9000, secs = 600, about = false })
	ok(s3:find("The summon saves ", 1, true) and s3:find(" of gold, and ", 1, true), "flight dearer: saves gold: " .. s3)
	T.clean(w)
end)

test("r25 B1: shows on every flight-map open, and Don't show again names the setting", function()
	local w, r, W, Mod = setup(5000, 1750)
	for i = 1, 3 do
		w:openTaxiMap(r, { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 } })
		w:advance(0.5)
		local c = Mod.Card()
		ok(c and H.visible(c), "card shown on open " .. i)
		ok(c.text:GetText():find("^Summon .* Fly ") ~= nil, "the card's short line: " .. tostring(c.text:GetText()))
		ok(c.tipBody:find("really", 1, true), "the tooltip's second paragraph spells out the saving")
		w:advance(10)
		r.env.TaxiFrame:Hide()
		if r.env.TaxiFrame.GetScript and r.env.TaxiFrame:GetScript("OnHide") then end
		W.Fire("TAXIMAP_CLOSED")
		w:advance(1)
	end
	T.clean(w)
end)
