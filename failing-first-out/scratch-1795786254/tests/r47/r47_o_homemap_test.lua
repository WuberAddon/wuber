local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- C24r-1: on Home's folded map the route line is drawn from y * 252 (frame height) but the fractions were made
-- with 212 (m.mapH), so it starts below the rider's dot.
test("r47 o: AUD-165 peeking at Home during a ride, the route line starts at the rider's dot", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	local W = r.W
	local ends = {}
	local route = W.Map.RouteOnPanel
	W.Map.RouteOnPanel = function(m, a, b, o)
		if a then ends.m, ends.from, ends.to = m, a, b end
		return route(m, a, b, o)
	end
	W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(0.5)
	W.ride.state = "accepted"
	W.ride.dest = "Ratchet"
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.RefreshNow()
	W.UI.Show("home") -- a peek at Home during the ride
	w:advance(1)
	W.UI.RefreshNow()
	w:advance(0.5)
	local s = W.Mod("UI.Window").screens.home
	local m = s and s.map
	ok(m, "home map")
	ok(H.visible(m.me), "control: the rider's dot shows on Home's map")
	ok(ends.from, "control: a route is drawn on Home's map")
	local mt = H.rect(m)
	local dr = H.rect(m.me)
	local mh = m:GetHeight()
	local dotY = ((mt.b + mt.h) - (dr.b + dr.h / 2)) / mt.h * mh
	local lineY = ends.from[2] * mh
	ok(math.abs(lineY - dotY) < 2, string.format("the route line starts %.0f px below the rider's dot (dot at y %.0f, line at y %.0f, panel %d high, mapH %d)", lineY - dotY, dotY, lineY, mh, m.mapH))
	T.clean(w)
end)


-- C24r-2: Home's hero picture (shown when the place has no map art) is cropped once for the folded 360x252 panel;
-- on the unfolded ride page the same panel is docked as a 360x512 side pane and the picture is stretched.
local function stretch(hero, w, h)
	local l, r, t, b = hero:GetTexCoord()
	local srcAspect = ((r - l) * 1024) / ((b - t) * 512) -- the header picture is 1024x512
	return srcAspect / (w / h) -- 1 = true to shape; 2 = stretched 2x tall
end

test("r47 o: AUD-170 in a dungeon with the ride page unfolded, the side-pane backdrop is not stretched tall", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	local W = r.W
	W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(0.5)
	W.ride.state = "accepted"
	W.ride.dest = "Ratchet"
	r.env.C_Map.GetBestMapForUnit = function() return nil end -- an instance: no map art
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.RefreshNow()
	w:advance(0.5)
	local s = W.Mod("UI.Window").screens.home
	local m = s and s.map
	ok(m and m.hero, "home map hero")
	W.UI.Show("home") -- a peek at Home folded
	w:advance(1)
	W.UI.RefreshNow()
	ok(H.visible(m.hero), "control: the no-art backdrop shows when folded")
	local f = stretch(m.hero, m:GetWidth(), m:GetHeight())
	ok(math.abs(f - 1) < 0.05, "control: folded, the backdrop keeps its shape (stretch " .. f .. ")")
	r.wide = true
	local tg = W.UI.Fold.Toggle()
	w:advance(1)
	W.UI.RefreshNow()
	w:advance(0.5)
	ok(W.UI.Fold.IsUnfolded(), "control: unfolded (page " .. tostring(W.UI.Fold.Page()) .. ", toggle " .. tostring(tg) .. ")")
	W.Mod("UI.Rider.WorldMap").Show("here") -- the pane's Here tab: the zone map (an instance has no art: the backdrop)
	w:advance(1)
	W.UI.RefreshNow()
	w:advance(0.5)
	ok(m.docked, "control: the map is docked in the side pane")
	do local p, chain = m, ""
		while p do chain = chain .. (p:GetName() or "?") .. ":" .. tostring(p:IsShown()) .. "/" .. tostring(p.GetAlpha and p:GetAlpha()) .. " " p = p:GetParent() end
		ok(H.visible(m.hero), "control: the backdrop shows in the side pane; hero shown " .. tostring(m.hero:IsShown()) .. " chain " .. chain) end
	local g = stretch(m.hero, m:GetWidth(), m:GetHeight())
	ok(math.abs(g - 1) < 0.05, string.format("unfolded, the %dx%d side-pane backdrop is stretched %.1fx taller than its picture", m:GetWidth(), m:GetHeight(), g))
	T.clean(w)
end)
