local T = ...
-- Round 31 group K: HUNT-20 the trade toast names the pay card's amount (fare plus tip, less part paid);
-- HUNT-21 Show me on the Open tip rings the Drive screen's Open button, not the Drive tab.
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function toastsFor(c)
	local seen = {}
	local orig = c.W.UI.Toast
	c.W.UI.Toast = function(text, kind, onClick)
		seen[#seen + 1] = tostring(text)
		return orig(text, kind, onClick)
	end
	return seen
end

local function lastTrade(seen)
	local out
	for _, t in ipairs(seen) do if t:find("^Trade ") then out = t end end
	return out
end

test("r31 K HUNT-20: the Trade toast names fare plus tip, and what is left after a part payment", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local MIA, BEA = "Mia Runner", "Bea Jones"
	r.W.ride = { id = "r31", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = BEA, payto = "Bea", summoner = BEA, service = "Mia's Rides" }
	r.W.db.tipPct = 20
	r.W.Fire("RIDE")
	local seen = toastsFor(r)
	r.W.ride.state = "paying"
	r.W.Fire("RIDE")
	local t = lastTrade(seen)
	ok(t, "a Trade toast")
	ok(t:find(r.W.Money(6000), 1, true), "fare 50s plus a 10s tip is 60s: " .. tostring(t))
	-- part paid: 20s paid, 30s left, plus the tip
	r.W.ride.paidSoFar = 2000
	r.W.ride.state = "arrived"
	r.W.Fire("RIDE")
	r.W.ride.state = "paying"
	r.W.Fire("RIDE")
	local want = r.W.UI.PayTotal(r.W.Mod("UI.Kit").rideView())
	t = lastTrade(seen)
	ok(t:find(r.W.Money(want), 1, true), "the toast matches the pay card: " .. tostring(t) .. " vs " .. r.W.Money(want))
	T.clean(w)
end)

test("r31 K HUNT-21: Show me on the Open tip rings the Open button on the Drive screen", function()
	local w = T.newWorld()
	local d = w:addClient("Ana Lock", { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:advance(15)
	d.W.db.coach = true
	d.W.Char().welcomed = true -- past the welcome page: the console with its Open button
	d.W.UI.Toggle(true)
	w:advance(2.5)
	d:clickText("Drive")
	w:advance(1)
	local M = d.W.Mod("UI.TipTexts")
	ok(M.Show("drive_open"), "Show me opens the Drive screen")
	w:advance(2)
	local v = d.W.Driver.ui and d.W.Driver.ui.console
	ok(v and v.open and v.open:IsVisible(), "the Open button is on screen")
	eq(M.Target("drive_open"), v.open, "the ring is on Open")
	T.clean(w)
end)
