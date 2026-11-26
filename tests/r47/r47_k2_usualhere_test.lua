local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function home(spot)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity" })
	T.goOnline(d)
	w:advance(5)
	local r = T.rider(w, T.TESTCHAR, { spot = spot, screenW = 1365, screenH = 768, saved = { Wuber = { coach = false } } })
	w:advance(15)
	local W = r.W
	local MIA = T.ANITA
	W.db.rides = {}
	for i = 1, 3 do
		W.db.rides[i] = { dest = "Undercity", driver = MIA, driverKey = W.Key(MIA), price = 5000, at = r.env.time() - i * 3600, saved = 600 }
	end
	if W.RebuildTotals then W.RebuildTotals() end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(3)
	W.UI.Refresh(true)
	w:advance(3)
	return w, r, W, W.UI.state.screens.home
end

test("r47 k2: control, standing in Orgrimmar the usual Undercity driver is offered", function()
	local w, r, W, s = home("Orgrimmar")
	eq(W.AlreadyAt("Undercity"), nil, "not in Undercity")
	ok(H.visible(s.usual), "the Your usual card shows: " .. T.list(r:visibleTexts()):sub(1, 200))
end)

test("r47 k2: standing in Undercity, Home does not offer 'Your usual' ride to Undercity", function()
	local w, r, W, s = home("Undercity")
	ok(W.AlreadyAt("Undercity") ~= nil, "control: the rider is standing in Undercity")
	ok(not H.visible(s.usual), "Home offers the gold usual card (" .. tostring(s.usual.title:GetText()) .. ") for the city the rider is standing in: " .. T.list(r:visibleTexts()):sub(1, 200))
	T.clean(w)
end)