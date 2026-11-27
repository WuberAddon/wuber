-- Group Finder (group A): the core module Net/GroupFinder.lua and the fake Group Finder (tests/lib/fake_lfglist.lua).
-- Design: docs/DESIGN-GROUP-FINDER.md. Every promise is its own test.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local NOTE = "Wuber summons to Ashenvale"

-- a driver online, a rider who hears him; on: the rider's setting
local function world(on)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	if on then r.W.db.groupFinder = true end
	return w, d, r
end

-- the player's own click: Search (or any call) made inside a hardware click
local function clicked(c, fn)
	c.world.hardware = c
	local a, b = fn()
	c.world.hardware = nil
	return a, b
end

local function search(r)
	local a, b = clicked(r, function() return r.W.GroupFinder.Search() end)
	r.world:advance(1.5)
	return a, b
end

local function calls(w, name)
	local n = 0
	for _, c in ipairs(w.lfg.calls) do
		if name == nil or c == name then n = n + 1 end
	end
	return n
end

test("gf a1: setting off (default): Search says off and no Group Finder call happens in a whole session", function()
	local w, d, r = world(false)
	local GF = r.W.GroupFinder
	ok(GF, "W.GroupFinder exists")
	eq(GF.On(), false)
	local a, b = clicked(r, function() return GF.Search() end)
	eq(a, false)
	eq(b, "off")
	d:lfgPost(NOTE, 1001, "Ashenvale")
	for _, c in ipairs({ d, r }) do
		c:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
		c:fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
		c:fire("LFG_LIST_SEARCH_FAILED")
	end
	w:advance(120)
	eq(GF.MyListing(), false)
	eq(GF.StillListed(), false)
	eq(GF.ListedZone(r.W.Key(T.ANITA)), nil)
	eq(calls(w), 0, "C_LFGList calls with the setting off")
	T.clean(w)
end)

test("gf a2: a known driver whose note mentions Wuber is listed with his zone after a search from a click", function()
	local w, d, r = world(true)
	ok(r.W.drivers[r.W.Key(T.ANITA)], "the rider hears the driver")
	d:lfgPost(NOTE, 1001, "Ashenvale")
	eq(search(r), true)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), "Ashenvale")
	eq(#w.lfg.searches, 1)
	T.clean(w)
end)

test("gf a3: the GROUPFINDER message fires when the listed drivers change", function()
	local w, d, r = world(true)
	local n = 0
	r.W.Listen("GROUPFINDER", function() n = n + 1 end)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	search(r)
	ok(n >= 1, "GROUPFINDER fired")
	T.clean(w)
end)

test("gf b1: a known driver whose note does not mention Wuber is not listed", function()
	local w, d, r = world(true)
	d:lfgPost("LFM dungeon run", 1001, "Ashenvale")
	search(r)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), nil)
	eq(r.W.GroupFinder.ExtraCount(), 0)
	T.clean(w)
end)

test("gf b2: an unknown leader whose note mentions Wuber only adds to the count, no driver entry", function()
	local w, d, r = world(true)
	local bob = T.rider(w, T.BOB)
	T.settle(w)
	bob:lfgPost("wuber portals, whisper me", 1001, "Duskwood")
	search(r)
	local GF = r.W.GroupFinder
	eq(GF.ExtraCount(), 1)
	eq(GF.ListedZone(r.W.Key(T.BOB)), nil)
	eq(r.W.drivers[r.W.Key(T.BOB)], nil)
	T.clean(w)
end)

test("gf c1: Search outside a click is refused by the game (the screens must call it from a click)", function()
	local w, d, r = world(true)
	r.W.GroupFinder.Search()
	eq(#w.violations, 1)
	ok(tostring(w.violations[1]):find("without a hardware click", 1, true), "violation: " .. tostring(w.violations[1]))
	eq(#w.lfg.searches, 0)
	w.violations = {} -- deliberately: this test expected exactly that violation
	T.clean(w)
end)

test("gf c2: ten minutes of timers and events with the setting on: Wuber never searches by itself", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	for _ = 1, 10 do
		w:advance(60)
		r:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
		r:fire("PLAYER_ENTERING_WORLD")
		d:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	end
	eq(calls(w, "Search"), 0)
	eq(#w.lfg.searches, 0)
	T.clean(w)
end)

test("gf d1: a search made by Blizzard's own window is ignored", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	r:lfgForeignSearch()
	w:advance(2)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), nil)
	T.clean(w)
end)

test("gf e1: lockdown (every field secret): no error, nothing listed", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	r:lfgLockdown(true)
	eq(search(r), true)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), nil)
	eq(r.W.GroupFinder.ExtraCount(), 0)
	T.clean(w)
end)

test("gf f1: a second search where the driver is gone clears him", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	search(r)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), "Ashenvale")
	w.lfg.listings[T.ANITA] = nil
	search(r)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), nil)
	T.clean(w)
end)

test("gf f2: an entry older than 10 minutes expires", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	search(r)
	w:advance(500)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), "Ashenvale")
	w:advance(120)
	eq(r.W.GroupFinder.ListedZone(r.W.Key(T.ANITA)), nil)
	T.clean(w)
end)

test("gf g1: a second Search while one is pending is busy; after 15 s without an answer it is free again", function()
	local w, d, r = world(true)
	w.lfg.silent = true
	local GF = r.W.GroupFinder
	eq(clicked(r, function() return GF.Search() end), true)
	local a, b = clicked(r, function() return GF.Search() end)
	eq(a, false)
	eq(b, "busy")
	w:advance(16)
	eq(clicked(r, function() return GF.Search() end), true)
	T.clean(w)
end)

test("gf g2: a failed search ends the pending search", function()
	local w, d, r = world(true)
	w.lfg.failNext = true
	search(r)
	eq(clicked(r, function() return r.W.GroupFinder.Search() end), true)
	T.clean(w)
end)

test("gf h1: SearchCategory: own entry first, then the probed constant, then the first available category", function()
	local w, d, r = world(true)
	local GF = r.W.GroupFinder
	eq(GF.CATEGORY, nil)
	eq(GF.SearchCategory(), 10)
	GF.CATEGORY = 20
	eq(GF.SearchCategory(), 20)
	r:lfgPost("x", 1001, "Orgrimmar")
	eq(GF.SearchCategory(), 10)
	T.clean(w)
end)

test("gf h2: no category at all: Search says nocategory and makes no search call", function()
	local w, d, r = world(true)
	w.lfg.available = {}
	local a, b = clicked(r, function() return r.W.GroupFinder.Search() end)
	eq(a, false)
	eq(b, "nocategory")
	eq(calls(w, "Search"), 0)
	T.clean(w)
end)

test("gf i1: the driver's own listing: MyListing, Delist from a click removes it", function()
	local w, d, r = world(true)
	d.W.db.groupFinder = true
	local GF = d.W.GroupFinder
	eq(GF.MyListing(), false)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	eq(GF.MyListing(), true)
	clicked(d, function() return GF.Delist() end)
	eq(GF.MyListing(), false)
	eq(w.lfg.listings[T.ANITA], nil)
	T.clean(w)
end)

test("gf i2: Delist with the setting off makes no call", function()
	local w, d, r = world(false)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	clicked(d, function() return d.W.GroupFinder.Delist() end)
	eq(calls(w), 0)
	ok(w.lfg.listings[T.ANITA], "the listing is still there")
	T.clean(w)
end)

test("gf i3: Delist when the game raises an error: no Lua error escapes", function()
	local w, d, r = world(true)
	d.W.db.groupFinder = true
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w.lfg.removeError = true
	clicked(d, function() return d.W.GroupFinder.Delist() end)
	eq(d.W.GroupFinder.MyListing(), true)
	T.clean(w)
end)

test("gf i4: StillListed: offline but listed (setting on); not while online", function()
	local w, d, r = world(true)
	d.W.db.groupFinder = true
	local GF = d.W.GroupFinder
	d:lfgPost(NOTE, 1001, "Ashenvale")
	eq(GF.StillListed(), false)
	d.W.Driver.SetOnline(false)
	w:advance(3)
	eq(GF.StillListed(), true)
	clicked(d, function() return GF.Delist() end)
	eq(GF.StillListed(), false)
	T.clean(w)
end)

test("gf j1: Wuber never calls CreateListing or UpdateListing in a full session", function()
	local w, d, r = world(true)
	d.W.db.groupFinder = true
	d:lfgPost(NOTE, 1001, "Ashenvale")
	search(r)
	clicked(d, function() return d.W.GroupFinder.Delist() end)
	d:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	w:advance(600)
	eq(calls(w, "CreateListing"), 0)
	eq(calls(w, "UpdateListing"), 0)
	for _, v in ipairs(w.violations) do ok(not tostring(v):find("Listing called by addon", 1, true), v) end
	T.clean(w)
end)
