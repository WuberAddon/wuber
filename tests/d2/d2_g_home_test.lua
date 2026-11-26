-- Design round 2, group G (items 9 and 10): the Ride screen. Drivers are rows of ONE card with thin dividers (the
-- driver's picture, the name and the Founder badge, the second line with the state words, the price, the heart, a
-- chevron); "Your usual" is one flat card without a button; Home has one main button at the foot ("Ride again ·
-- <place> · <price>", "Ping drivers", "Pin <price>", or none); your bounty is a plain row with "Take down" as a link;
-- the OpenMap line is the last row of the list.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function drv(env, name, dest, price, extra)
	local d = { name = name, key = name:lower(), short = name, dest = dest, price = price, state = "open", team = 3,
		service = name .. "'s Rides", heard = env.GetTime(), queue = 0 }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d
end

-- a rider with Home open and the drivers given (UI.Drivers / UI.Driver answer from the list); usual: { dest, driverKey }
local function world(make, usual)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local UI = c.W.UI
	local list = make and make(c.env) or {}
	UI.Drivers = function() return list end
	UI.Driver = function(key)
		for _, d in ipairs(list) do if d.key == key then return d end end
	end
	c.W.Usual = function() return usual end
	c.W.AlreadyAt = function() return nil end
	UI.Toggle(true)
	w:advance(3)
	UI.Refresh(true)
	w:advance(2)
	return w, c, UI.state.screens.home, list
end

local function three(env)
	return {
		drv(env, "Anita", "Undercity", 5000, { creator = true, service = "Anita's Portals" }),
		drv(env, "Mia", "Thunder Bluff", 1234567),
		drv(env, "Zed", "Feathermoon Stronghold", 7500, { state = "busy", queue = 40, seats = 0, team = 1 }),
	}
end

-- the primary pills that show anywhere under Home
local function primaries(home)
	local out, seen = {}, {}
	local function walk(f)
		if seen[f] then return end
		seen[f] = true
		if f.style == "primary" and type(f.SetLabel) == "function" and H.visible(f) then out[#out + 1] = f end
		if f.GetChildren then for _, ch in ipairs({ f:GetChildren() }) do walk(ch) end end
	end
	walk(home.frame)
	return out
end

local function atFoot(home, b, what)
	local page = home.sheet -- the page body's bottom is the sheet's (units of the window, as tests/d2/d2_f_main_test.lua)
	eq(b.style, "primary", what .. ": the main kind")
	ok(math.abs(b:GetHeight() - 46) < 0.01, what .. ": 46 high, is " .. tostring(b:GetHeight()))
	ok(math.abs((b:GetBottom() - page:GetBottom()) - 12) < 0.01, what .. ": 12 above the page's bottom, is " .. tostring(b:GetBottom() - page:GetBottom()))
	ok(math.abs((b:GetLeft() - page:GetLeft()) - 16) < 0.01 and math.abs((page:GetRight() - b:GetRight()) - 16) < 0.01, what .. ": 16 from each side")
end

test("d2 g: drivers are rows of one card, one divider fewer than rows, and no row's words are cut", function()
	local w, c, home, list = world(three)
	local cards = c.W.UI.state.cards
	local group = home.rows
	ok(group and type(group.Row) == "function" and H.visible(group), "the drivers' card (a T.RowGroup) shows")
	local shown, dividers = 0, 0
	for _, row in ipairs(group and group.rows or {}) do
		if not row.off and H.visible(row) then
			shown = shown + 1
			if row.divider:IsShown() then dividers = dividers + 1 end
		end
	end
	ok(shown >= 3, "three drivers (and the OpenMap line) are rows: " .. shown)
	eq(dividers, shown - 1, "one divider fewer than rows")
	local G = group and H.rect(group)
	for _, d in ipairs(list) do
		local row = cards[d.key]
		ok(row and row.group == group, d.name .. ": a row of the one card")
		if row and row.group == group then
			local R = H.rect(row)
			ok(R.l >= G.l - 0.01 and R.l + R.w <= G.l + G.w + 0.01 and R.b >= G.b - 0.01 and R.b + R.h <= G.b + G.h + 0.01, d.name .. ": inside the card")
			eq(row.title:GetText(), d.service, d.name .. ": the whole name")
			local sub = row.sub:GetText()
			ok(not sub:find("...", 1, true) and not row.title:GetText():find("...", 1, true), d.name .. ": no dots")
			ok(sub:find("To " .. d.dest, 1, true), d.name .. ": the second line says the place: " .. sub)
			ok(row.sub.paraLines and row.sub:GetHeight() >= row.sub.paraH, d.name .. ": the second line has the height of its lines")
			ok(R.h >= row.title:GetHeight() + row.sub:GetHeight(), d.name .. ": the row is as tall as its words")
			ok(row.avatar and H.visible(row.avatar) and row.avatar:GetWidth() == 32, d.name .. ": a round picture at the left")
			ok(H.visible(row.price) and H.visible(row.heart) and row.chevron and H.visible(row.chevron), d.name .. ": the price, the heart, a chevron")
			local P, Hh, Ch = H.rect(row.price), H.rect(row.heart), H.rect(row.chevron)
			ok(P.l + P.w <= Hh.l + 0.01 and Hh.l + Hh.w <= Ch.l + 0.01, d.name .. ": in that order")
			ok(not (row.crown and row.crown:IsShown()) and not (row.pioneer and row.pioneer:IsShown()), d.name .. ": no emblem after the name")
		end
	end
	-- the busy, full driver: the state words are plain words of the second line, and the row grew
	local zed = cards.zed
	ok(zed and zed.sub:GetText():find("Busy · 40 waiting · Group full", 1, true), "the state words are in the second line: " .. tostring(zed and zed.sub:GetText()))
	ok(zed and zed:GetHeight() > 56, "a row with three lines of words is taller than 56")
	-- the founder: the Founder badge after the name, a thin gold outline; the crown's words are in the tooltip
	local an = cards.anita
	local chip = an and an.royal and an.royal.chip
	ok(chip and H.visible(chip) and chip.edge, "the Founder badge with its outline")
	if chip then
		eq(chip.label:GetText(), "Founder", "its word")
		local Tt, Cc = H.rect(an.title), H.rect(chip)
		ok(Cc.l > Tt.l and Cc.l + Cc.w <= H.rect(an.price).l, "after the name, before the price")
	end
	-- (r54 B) no badge of their own: a founder's picture is the crown, not the initial
	ok(an.crownMark and H.visible(an.crownMark) and not H.visible(an.avatar.initial), "no badge of their own: the crown")
	T.clean(w)
end)

test("d2 g: a driver's own badge is their picture; what a click and the heart do stays", function()
	local shownFor
	local w, c, home = world(function(env) return { drv(env, "Mia", "Undercity", 5000) } end)
	local UI = c.W.UI
	local id = type(c.W.BADGES) == "table" and c.W.BADGES[1] and c.W.BADGES[1].id
	local row = UI.state.cards.mia
	ok(row and row.avatar, "the row has a picture")
	if id and row and row.avatar then
		row.view.badge = id
		UI.Refresh(true)
		w:advance(1)
		ok(row.mark and H.visible(row.mark) and row.mark:GetParent() == row.avatar, "the badge is inside the picture")
		eq(row.mark:GetWidth(), 32, "at the picture's size")
		ok(not H.visible(row.avatar.initial), "no initial under it")
	end
	local real = UI.Show
	UI.Show = function(screen, key) shownFor = { screen, key } end
	row:Click("LeftButton")
	UI.Show = real
	eq(shownFor and shownFor[1], "confirm", "a click books")
	eq(shownFor and shownFor[2], "mia", "this driver")
	ok(row.heart and row.heart.key == "mia", "the heart is this driver's")
	T.clean(w)
end)

test("d2 g: Your usual is one flat card without a button; Ride again is the main button at the foot", function()
	local w, c, home = world(three, { dest = "Thunder Bluff", driverKey = "mia" })
	local UI = c.W.UI
	local u = home.usual
	ok(H.visible(u), "the usual card shows")
	eq(u.go, nil, "no button inside the card")
	local inside = 0
	for _, fs in ipairs(c:findText("Ride again", true, true) or {}) do
		local p = fs:GetParent()
		while p do
			if p == u then inside = inside + 1 end
			p = p.GetParent and p:GetParent() or nil
		end
	end
	eq(inside, 0, "no 'Ride again' inside the card")
	eq(u.title:GetText(), "Thunder Bluff", "the place")
	ok(u.sub:GetText():find("with Mia's Rides", 1, true), "with the driver")
	local b = home.main
	ok(b and H.visible(b), "the main button shows")
	eq(b.label:GetText(), "Ride again · Thunder Bluff · " .. c.W.Money(1234567), "its words")
	atFoot(home, b, "Ride again")
	-- the list ends above it
	ok(home.clip:GetBottom() >= b:GetTop(), "the list ends above the main button")
	eq(#primaries(home), 1, "one main button on Home")
	local shownFor = {}
	local real = UI.Show
	UI.Show = function(screen, key) shownFor[#shownFor + 1] = screen .. ":" .. tostring(key) end
	b:Click()
	u:Click()
	UI.Show = real
	eq(shownFor[1], "confirm:mia", "the main button books the usual")
	eq(shownFor[2], "confirm:mia", "the whole card still opens the booking")
	T.clean(w)
end)

test("d2 g: drivers listed and no usual: no main button, the list uses the room", function()
	local w, c, home = world(three, nil)
	eq(#primaries(home), 0, "no main button")
	ok(not (home.main and H.visible(home.main)), "Ride again is hidden")
	ok(home.clip:GetBottom() - home.sheet:GetBottom() <= 8.01, "the list runs to the page's foot")
	T.clean(w)
end)

test("d2 g: nobody online: Ping drivers is the main button at the foot, same words and action", function()
	local w, c, home = world(nil, nil)
	local e = home.empty
	ok(H.visible(e) and H.visible(e.ping), "the empty screen and its button")
	eq(e.ping.label:GetText(), "Ping drivers", "the words")
	atFoot(home, e.ping, "Ping drivers")
	local P = primaries(home)
	eq(#P, 1, "one main button on Home")
	eq(P[1], e.ping, "it is Ping drivers")
	local pinged = 0
	c.W.Ping = function() pinged = pinged + 1 return true end
	e.ping:Click()
	eq(pinged, 1, "it pings")
	T.clean(w)
end)

test("d2 g: setting a bounty: Pin is the main button; your bounty is a plain row with Take down as a link", function()
	local w, c, home = world(nil, nil)
	local UI = c.W.UI
	UI.SetSearch("Gadgetzan")
	w:advance(1)
	local bb = home.empty.bounty
	ok(H.visible(bb) and H.visible(bb.pin), "the bounty set-up and its button")
	eq(bb.pin.label:GetText(), "Pin " .. c.W.Money(5000), "Pin and the price")
	atFoot(home, bb.pin, "Pin")
	local P = primaries(home)
	eq(#P, 1, "one main button on Home")
	eq(P[1], bb.pin, "it is Pin")
	local pinned, cancelled
	local mine = nil
	UI.PinBounty = function(place, copper) pinned = { place, copper } end
	UI.CancelBounty = function() cancelled = true end
	UI.BountyMine = function() return mine end
	bb.pin:Click()
	eq(pinned and pinned[1], "Gadgetzan", "it pins the place")
	eq(pinned and pinned[2], 5000, "for the price")
	-- the bounty is up
	mine = { place = "Gadgetzan", copper = 5000, at = c.env.time(), left = 24 * 60 }
	UI.Refresh(true)
	w:advance(1)
	local row = home.bountyChip
	ok(H.visible(row) and row.row and type(row.Row) == "function", "your bounty is a row of a card")
	eq(row.text:GetText(), "Your bounty: " .. c.W.Money(5000) .. " for Gadgetzan", "its words")
	ok(row.row.icon and H.visible(row.row.icon), "the coin")
	ok(row.row.sub:GetText():find("24 min", 1, true), "the minutes left")
	eq(row.close.label:GetText(), "Take down", "Take down")
	eq(row.close.style, "ghost", "as a link")
	eq(row.close.x, nil, "no x")
	ok(not H.visible(bb.pin), "no Pin while it is up")
	eq(#primaries(home), 0, "and no other main button")
	row.close:Click()
	ok(cancelled, "Take down takes it down")
	T.clean(w)
end)

test("d2 g: the OpenMap line is the last row of the drivers list, with its x", function()
	local w, c, home, list = world(three)
	-- the first-open tips cover the x: the player skips them first
	if c.W.UI.state.coaching then
		c:clickText("Skip tips")
		w:advance(1)
	end
	local hint = home.mapHint
	ok(hint and H.visible(hint), "the line shows")
	eq(hint.group, home.rows, "it is a row of the drivers' card")
	eq(hint.title:GetText(), "Get OpenMap to see drivers on your world map", "its words")
	local lowest = H.rect(hint).b
	for _, d in ipairs(list) do
		ok(H.rect(c.W.UI.state.cards[d.key]).b > lowest, d.name .. " is above it")
	end
	ok(not hint.divider:IsShown(), "the last row has no divider")
	-- it no longer floats over the map: it stands under the list's top
	ok(hint:GetTop() <= home.clip:GetTop() + 0.01, "inside the list, not over the map")
	ok(hint.close and H.visible(hint.close), "its x")
	c:click(hint.close)
	w:advance(1)
	ok(not H.visible(hint), "the x hides it")
	eq(c.W.db.openMapHint, true, "for good")
	T.clean(w)
end)

test("d2 p1: every driver's row shows its price, in gold, right of the name, left of the chevron, inside the row", function()
	local w, c, home, list = world(three)
	local cards = c.W.UI.state.cards
	local Th = c.W.Theme
	local gold = Th.C.gold
	for _, d in ipairs(list) do
		local row = cards[d.key]
		eq(row.price:GetText(), c.W.Money(d.price), d.name .. ": the price words are on the row")
		ok(H.visible(row.price), d.name .. ": the price shows")
		local r, g = row.price:GetTextColor()
		ok(math.abs(r - gold[1]) < 0.01 and math.abs(g - gold[2]) < 0.01, d.name .. ": in gold")
		local R, P, Ch, Tt = H.rect(row), H.rect(row.price), H.rect(row.chevron), H.rect(row.title)
		ok(P.w > 4, d.name .. ": the price has room: " .. P.w)
		ok(P.l >= R.l and P.l + P.w <= R.l + R.w + 0.01 and P.b >= R.b - 0.01 and P.b + P.h <= R.b + R.h + 0.01, d.name .. ": inside the row")
		ok(P.l + P.w <= Ch.l + 0.01, d.name .. ": left of the chevron")
		ok(P.l >= Tt.l + 20, d.name .. ": right of the name's start")
		local pw = math.ceil(Th.MeasureText(c.W.Money(d.price), 13, "bold"))
		ok(P.w >= pw, d.name .. ": wide enough for its words (" .. P.w .. " for " .. pw .. ")")
	end
	T.clean(w)
end)

test("d2 p1: the main button of Home and of the empty Home use the bold font", function()
	local function bold(home, what)
		local ps = primaries(home)
		ok(#ps >= 1, what .. ": a main button shows")
		for _, b in ipairs(ps) do
			ok(b.label.wuberWeight == "bold" and tostring(b.label:GetFont()):find("Bold", 1, true), what .. ": bold words (" .. tostring(b.label:GetFont()) .. ")")
		end
	end
	local w, c, home = world(three, { dest = "Thunder Bluff", driverKey = "mia" })
	bold(home, "home")
	T.clean(w)
	w, c, home = world(function() return {} end)
	bold(home, "empty home")
	T.clean(w)
end)

test("d2 p1: the empty Home has room: 12 under the heading, 12 above the main button, no line on another", function()
	for _, usual in ipairs({ { dest = "Undercity", driverKey = "mia" }, false }) do
		local w, c, home = world(function() return {} end, usual or nil)
		local e = home.empty
		local ping = H.rect(e.ping)
		local u = ping.h / 46 -- rects are in screen units: one window unit is this many
		local what = usual and "with a usual place" or "plain"
		local hd = H.rect(home.header)
		local tt = H.rect(e.title)
		ok(hd.b - (tt.b + tt.h) >= 12 * u - 0.5, what .. ": 12 between the heading and the first line (" .. (hd.b - (tt.b + tt.h)) / u .. ")")
		local note = home.usualNote
		local lines = { e.title, e.sub, e.watch, e.bountyGo, e.why, note }
		local shown = {}
		for _, f in ipairs(lines) do if f and f:IsShown() and H.visible(f) then shown[#shown + 1] = f end end
		if usual then ok(not note:IsShown(), what .. ": no Your usual line while nobody is listed (the word rule)") end
		for i = 1, #shown - 1 do
			local a, b = H.rect(shown[i]), H.rect(shown[i + 1])
			ok(a.b >= b.b + b.h - 0.01, what .. ": line " .. i .. " ends above line " .. (i + 1))
		end
		local last = H.rect(shown[#shown])
		ok(last.b - (ping.b + ping.h) >= 12 * u - 0.5, what .. ": at least 12 between the last line and the main button (" .. (last.b - (ping.b + ping.h)) / u .. ")")
		T.clean(w)
	end
end)
