local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H or require and nil

-- Round 33, group c4 (HUNT-82): on a free ride (price 0) a stranger's trade used to get the warning toast
-- but not the amber "isn't your driver" card.

local function texts(c) return table.concat(c:visibleTexts(), " | ") end

local function strangerOnRide(price)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.ride = { id = "c4", driver = "Mia Stone", driverKey = "mia stone", dest = "Undercity", price = price,
		state = "arrived", at = r.env.GetTime(), payee = "Mia Stone", payto = "Mia", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(2)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.H.state[r.env.TradeFrame].shown = true
	w:openTrade(w:player("Sly Fox"), r.player)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	return w, r
end

for _, price in ipairs({ 5000, 0 }) do
	test("r33 c4: a stranger's trade gets the amber card at price " .. price, function()
		local w, r = strangerOnRide(price)
		local s = r.W.UI.state.screens.found
		ok(T.H.visible(s.alert) and #r:findText("Sly isn't your driver", false, true) > 0, "the amber card: " .. texts(r))
		T.clean(w)
	end)
end
