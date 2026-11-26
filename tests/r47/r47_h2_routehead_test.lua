local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function right(f) local r = H.rect(f) return r.l + r.w end

test("r47 h2: AUD-166 a long destination with a zeppelin tag pushes the tag out of the route pill", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local B = r.W.Mod("UI.Rider.Booking")
	local h = B.RouteHeader(r.env.UIParent, 324)
	h:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	-- control: the usual short trip inside the full-width pill
	h:Set("Orgrimmar", "Undercity", "zeppelin")
	w:advance(0.1)
	ok(right(h.via) <= right(h) + 0.5, "control: the tag sits inside the pill for Orgrimmar to Undercity")
	-- the unfolded booking card's header is 46 px narrower (Confirm.lua:460)
	h:SetMaxWidth(324 - 46)
	h:Set("Orgrimmar", "Feathermoon Stronghold", "zeppelin")
	w:advance(0.1)
	local over = right(h.via) - right(h)
	ok(over <= 0.5, "the route pill reads 'Orgrimmar to Feathermoon Stronghold [zeppelin]' but the zeppelin tag sticks out "
		.. string.format("%.0f", over) .. " px past the pill's right edge (origin shrunk to '" .. tostring(h.fromShown) .. "')")
	T.clean(w)
end)
