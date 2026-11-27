local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r47 l3: AUD-174 Undercity to Booty Bay route header says boat for a trip that takes the Undercity zeppelin", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity" })
	T.settle(w)
	local B = r.W.Mod("UI.Rider.Booking")
	local route = r.W.FlightRoute(nil, "Booty Bay")
	eq(table.concat(route, ","), "11,20,18", "route: Undercity tower, Grom'gol tower, Booty Bay")
	local h = B.RouteHeader(r.env.UIParent, 324)
	h:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	-- control: Undercity to Orgrimmar crosses the sea by zeppelin and says so
	h:Update("Orgrimmar")
	eq(h.viaText, "zeppelin", "control: Orgrimmar")
	h:Update("Booty Bay")
	w:advance(0.1)
	eq(h.viaText ~= nil, true, "the header carries a crossing tag")
	eq(h.viaText, "zeppelin", "the route header for Undercity to Booty Bay reads [" .. tostring(h.viaText)
		.. "] and its tooltip says 'Flying there takes a " .. tostring(h.viaText) .. " on the way', but the first hop (11 to 20) is the Undercity-Grom'gol zeppelin")
	T.clean(w)
end)
