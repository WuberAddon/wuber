-- Run 1, group g: the mid-flight card can be dragged, keeps its spot, sits above the zone text.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
	{ name = "Hammerfall, Arathi", type = "REACHABLE", cost = 530 },
	{ name = "Kalimdor's Nowhere, Somewhere", type = "REACHABLE", cost = 100 },
}

local function setTime(r, secs)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = secs, tat = r.env.time(), tsrc = "own" }
end

local function setDriver(r, key, name, dest, price)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key] = {
		name = name,
		key = key,
		dest = dest,
		price = price or 5000,
		state = "open",
		team = 3,
		service = name .. "'s Rides",
		heard = r.env.GetTime(),
	}
end

local function setupRider(secs)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	if secs then setTime(r, secs) end
	return w, r
end

local function flyAndShow(w, r, setupNew)
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	return r.env.WuberInFlight
end

test("run1 g: mid-flight card is dragged, saves its spot, returns there next flight, falls back when off screen", function()
	local w, r = setupRider(240)
	local W = r.W
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	local c = flyAndShow(w, r)
	ok(c and H.visible(c), "card visible")
	eq(c:GetFrameStrata(), "HIGH", "card strata HIGH (clears the zone text)")
	local dl, db = c:GetLeft(), c:GetBottom()
	r:drag(c, -120, -60)
	local p = W.db.flightCardPos
	ok(type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number", "flightCardPos saved")
	ok(math.abs(c:GetLeft() - (dl - 120)) <= 2 and math.abs(c:GetBottom() - (db - 60)) <= 2, "card moved by the drag: " .. dl .. "," .. db .. " -> " .. c:GetLeft() .. "," .. c:GetBottom())
	local sl, sb = c:GetLeft(), c:GetBottom()
	w:advance(245)
	c = flyAndShow(w, r)
	ok(c and H.visible(c), "card back on second flight")
	ok(math.abs(c:GetLeft() - sl) <= 2 and math.abs(c:GetBottom() - sb) <= 2, "card at the saved spot: " .. c:GetLeft() .. "," .. c:GetBottom() .. " vs " .. sl .. "," .. sb)
	w:advance(245)
	W.db.flightCardPos = { 90000, 90000 }
	c = flyAndShow(w, r)
	ok(c and H.visible(c), "card shown with an off-screen saved spot")
	ok(math.abs(c:GetLeft() - dl) <= 2 and math.abs(c:GetBottom() - db) <= 2, "falls back to the default spot")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("run1 g: mid-flight card drags from hit-tested body points (Client:frameAt) while buttons still click", function()
	local w, r = setupRider(240)
	local W = r.W
	local S = H.state
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	local c = flyAndShow(w, r)
	ok(c and H.visible(c), "card visible")
	local cr = H.rect(c)
	local pts = {
		{ cr.l + 14, cr.b + cr.h - 14, "top-left" },
		{ cr.l + cr.w / 2, cr.b + cr.h - 36, "body-centre" },
		{ cr.l + 10, cr.b + cr.h / 2, "left-margin" },
		{ cr.l + cr.w - 10, cr.b + cr.h - 50, "right-margin" },
	}
	for _, pt in ipairs(pts) do
		local hit = r:frameAt(pt[1], pt[2])
		ok(hit ~= nil, "frameAt(" .. pt[3] .. ") hits a frame")
		local hs = S[hit]
		ok(hs and hs.drag and #hs.drag > 0, "frameAt(" .. pt[3] .. ") is registered for drag")
		ok(hit.wuberTip and hit.wuberTip.title == "Drag to move", "frameAt(" .. pt[3] .. ") carries 'Drag to move' tip")
	end
	local bodyHit = r:frameAt(cr.l + cr.w / 2, cr.b + cr.h - 36)
	local dl, db = c:GetLeft(), c:GetBottom()
	r:drag(bodyHit, -80, -40)
	ok(math.abs(c:GetLeft() - (dl - 80)) <= 2 and math.abs(c:GetBottom() - (db - 40)) <= 2,
		"card moved when dragged from hit-tested body frame")
	local p = W.db.flightCardPos
	ok(type(p) == "table" and math.abs(p[1] - (dl - 80)) <= 2 and math.abs(p[2] - (db - 40)) <= 2,
		"flightCardPos saved after hit-tested drag")
	for _, btn in ipairs({ { c.book, "book" }, { c.x, "close" }, { c.never, "never" } }) do
		local br = H.rect(btn[1])
		eq(r:frameAt(br.l + br.w / 2, br.b + br.h / 2), btn[1], btn[2] .. " button is topmost at its centre")
	end
	r:clickOn(c.x)
	ok(not H.visible(c), "close button still clicks and hides the card")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)
