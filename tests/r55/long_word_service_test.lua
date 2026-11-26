local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
-- #236: a driver whose service name is ONE long word ("Wolfgangbertson's Rides" has "Wolfgangbertson's") shows whole in the
-- rider list row: the row's words never end in "..." (the title wraps by space; a lone word wider than the room used to be
-- counted as 1 line and cut by the game).

local function drv(env, name, service, price)
	return { name = name, key = name:lower(), short = name, dest = "Feathermoon Stronghold", price = price, state = "open",
		team = 3, service = service, heard = env.GetTime(), queue = 0 }
end

local function world(service, price)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local UI = c.W.UI
	local list = { drv(c.env, "Wolfgangbertson", service, price) }
	UI.Drivers = function() return list end
	UI.Driver = function(key) if key == list[1].key then return list[1] end end
	c.W.Usual = function() return nil end
	c.W.AlreadyAt = function() return nil end
	UI.Toggle(true)
	w:advance(3)
	UI.Refresh(true)
	w:advance(2)
	return w, c, c.W.UI.state.cards[list[1].key]
end

local function whole(row, what)
	eq(row.title:GetText(), row.titleText, what .. ": the whole name is set")
	ok(H.truncation(row.title) == nil, what .. ": the title is not cut (flat margin)")
	ok(H.truncation(row.title, true) == nil, what .. ": the title is not cut (as the game measures it)")
	ok(not row.title:IsTruncated(), what .. ": IsTruncated says no")
	local R, Ti = H.rect(row), H.rect(row.title)
	ok(Ti.b >= R.b - 0.01, what .. ": the title's words end inside the row")
end

test("r55 236: a one-word service name too long for the narrowest row (price, heart, chevron) is shown whole", function()
	local w, c, row = world("Wolfgangbertson's Rides", 1234567)
	ok(row and H.visible(row), "the driver's row shows")
	if row then
		ok(not row.priceOnLine, "this is the narrowest row: the price stands in its own column")
		whole(row, "Wolfgangbertson's Rides")
		ok(H.visible(row.price) and H.visible(row.heart) and H.visible(row.chevron), "price, heart and chevron still show")
		local R, P, Hh, Ti = H.rect(row), H.rect(row.price), H.rect(row.heart), H.rect(row.title)
		ok(P.l >= R.l and Hh.l + Hh.w <= R.l + R.w + 0.01 and P.b >= R.b - 0.01 and P.b + P.h <= R.b + R.h + 0.01, "the price and the heart stay inside the row")
		ok(P.b + P.h <= Ti.b + 0.01 or P.l >= Ti.l + Ti.w, "the price does not sit over the name")
	end
	T.clean(w)
end)

test("r55 236: a longer one-word name still shows whole", function()
	local w, c, row = world("Wolfgangbertsonsteinhausen", 1234567)
	ok(row and H.visible(row), "the driver's row shows")
	if row then whole(row, "one long word") end
	T.clean(w)
end)

-- guard: a short name stays on one line next to the price (unchanged path)
test("r55 236 guard: a short service name stays one line with the price on its line", function()
	local w, c, row = world("Mia's Rides", 5000)
	ok(row and H.visible(row), "the driver's row shows")
	if row then
		ok(row.priceOnLine, "the price stands on the name's line")
		eq(row.title.paraLines, 1, "one line")
		whole(row, "Mia's Rides")
	end
	T.clean(w)
end)

-- guard: a long name of several words wraps by space as before (two lines, never cut)
test("r55 236 guard: a long several-word name wraps by its spaces", function()
	local w, c, row = world("The Fastest Summoning Service In All Of Azeroth", 1234567)
	ok(row and H.visible(row), "the driver's row shows")
	if row then
		ok((row.title.paraLines or 1) >= 2, "wraps to 2 or more lines")
		whole(row, "several words")
	end
	T.clean(w)
end)

-- the Founder badge joins the price under the words: nothing overlaps, everything shows
test("r55 236: a founder with a one-word long name: name whole, badge and price both inside the row", function()
	local w, c, row = world("Wolfgangbertson's Rides", 1234567)
	local d = c.W.UI.Drivers()[1]
	d.creator = true
	c.W.UI.Refresh(true)
	w:advance(2)
	row = c.W.UI.state.cards[d.key]
	ok(row and H.visible(row), "the driver's row shows")
	if row then
		whole(row, "founder")
		local R, P = H.rect(row), H.rect(row.price)
		ok(row.royal and H.visible(row.royal.chip), "the Founder badge shows")
		local C = H.rect(row.royal.chip)
		ok(C.b >= R.b - 0.01 and C.l + C.w <= R.l + R.w + 0.01, "the badge is inside the row")
		ok(P.b >= R.b - 0.01 and P.l + P.w <= R.l + R.w + 0.01, "the price is inside the row")
		local overlap = not (C.l + C.w <= P.l or P.l + P.w <= C.l or C.b + C.h <= P.b or P.b + P.h <= C.b)
		ok(not overlap, "the badge and the price do not overlap")
	end
	T.clean(w)
end)
