local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function run(payee)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	w:advance(15)
	local MIA = "Mia Runner"
	w:addBot(MIA, { spot = "Orgrimmar" })
	w:addBot("Bea Jones", { spot = "Orgrimmar" })
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), service = "Mia's Rides" }
	if payee then r.W.ride.payee, r.W.ride.payto, r.W.ride.summoner = "Bea Jones", "Bea", "Bea Jones" end
	r.W.db.tipPct = 0
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local toasts = {}
	local orig = r.W.UI.Toast
	r.W.UI.Toast = function(text, ...) toasts[#toasts + 1] = tostring(text) return orig(text, ...) end
	local who = payee and "Bea Jones" or MIA
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(who), r.player), "the trade opens")
	w:advance(1.5)
	return w, r, toasts
end

test("r47 g2: control: a plain ride's trade toast names the driver", function()
	local w, r, toasts = run(false)
	local t = table.concat(toasts, " | ")
	ok(t:find("Trade Mia", 1, true), "control: toast names Mia: " .. t)
	T.clean(w)
end)

test("r47 g2: crew summon: the trade toast tells the rider to trade the driver, not the summoner who is paid", function()
	local w, r, toasts = run(true)
	local t = table.concat(toasts, " | ")
	ok(t:find("Trade ", 1, true), "control: a trade toast shows: " .. t)
	ok(t:find("Trade Bea", 1, true), "Bea cast the summon and is paid (the pay card says Pay Bea) but the toast reads: " .. t)
	T.clean(w)
end)
