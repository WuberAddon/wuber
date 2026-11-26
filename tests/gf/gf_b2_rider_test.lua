-- Group Finder (group B2): the rider's side on Home: the search button, the card line, the count line.
-- Design: docs/DESIGN-GROUP-FINDER.md. The rider's REAL click (client:clickText), never a code click.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local NOTE = "Wuber summons to Ashenvale"
local W_SEARCH = "Search the Group Finder"

local function world(on)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	if on then r.W.db.groupFinder = true end
	return w, d, r
end

local function openHome(w, r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
end

local function calls(w, name)
	local n = 0
	for _, c in ipairs(w.lfg and w.lfg.calls or {}) do
		if name == nil or c == name then n = n + 1 end
	end
	return n
end

local function has(r, needle)
	for _, t in ipairs(r:visibleTexts()) do
		if t:find(needle, 1, true) then return t end
	end
	return nil
end

local function cardCount(r)
	local n = 0
	for _ in pairs(r.W.UI.state.cards) do n = n + 1 end
	return n
end

local function row(r) return r.W.UI.state.screens.home.gfSearch end

test("gf b2-1: setting off (default): no button, no card line, no count line, no C_LFGList call on Home", function()
	local w, d, r = world(false)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	openHome(w, r)
	r:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	r.W.Fire("GROUPFINDER")
	w:advance(5)
	eq(has(r, "Group Finder"), nil, "no Group Finder words")
	ok(cardCount(r) >= 1, "the driver's card shows as before")
	eq(calls(w), 0, "C_LFGList calls")
	T.clean(w)
end)

test("gf b2-2: setting on: the button shows; a real click finds the driver and his card says where he is listed", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	openHome(w, r)
	ok(has(r, W_SEARCH), "the search button shows (" .. table.concat(r:visibleTexts(), " | ") .. ")")
	eq(has(r, "In the Group Finder"), nil, "no card line before a search")
	eq(has(r, "more listings"), nil, "no count line before a search")
	eq(#w.lfg.searches, 0)
	r:clickText(W_SEARCH)
	w:advance(1.5)
	eq(#w.lfg.searches, 1)
	ok(has(r, "In the Group Finder, Ashenvale"), "the card line (" .. table.concat(r:visibleTexts(), " | ") .. ")")
	eq(has(r, "more listings"), nil, "no count line")
	T.clean(w)
end)

test("gf b2-3: an unknown leader with a Wuber note: the count line says 1, no extra card, no name", function()
	local w, d, r = world(true)
	local bob = T.rider(w, T.BOB)
	T.settle(w)
	bob:lfgPost("wuber portals, whisper me", 1001, "Duskwood")
	openHome(w, r)
	local before = cardCount(r)
	r:clickText(W_SEARCH)
	w:advance(1.5)
	ok(has(r, "1 more listings mention Wuber: open the Group Finder"), "the count line (" .. table.concat(r:visibleTexts(), " | ") .. ")")
	eq(cardCount(r), before, "no extra card")
	eq(has(r, "Duskwood"), nil, "no zone of the stranger")
	eq(has(r, T.BOB), nil, "no name of the stranger")
	eq(has(r, "In the Group Finder"), nil)
	T.clean(w)
end)

test("gf b2-4: the button is disabled while the search is pending, enabled again after the answer", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	openHome(w, r)
	local b = row(r)
	ok(b, "Home holds the search row")
	eq(b.disabled == true, false, "enabled before")
	r:clickText(W_SEARCH)
	w:advance(0.3)
	eq(b.disabled, true, "disabled while pending")
	ok(has(r, "Searching..."), "says why")
	r:clickText(W_SEARCH)
	eq(#w.lfg.searches, 1, "a click while pending searches nothing more")
	w:advance(1.5)
	eq(b.disabled == true, false, "enabled after the answer")
	eq(has(r, "Searching..."), nil)
	T.clean(w)
end)

test("gf b2-5: a search the game never answers frees the button after 15 s", function()
	local w, d, r = world(true)
	w.lfg.silent = true
	openHome(w, r)
	r:clickText(W_SEARCH)
	w:advance(1)
	eq(row(r).disabled, true)
	w:advance(16)
	eq(row(r).disabled == true, false)
	T.clean(w)
end)

test("gf b2-6: no category: the button is disabled with its reason and a click makes no Search call", function()
	local w, d, r = world(true)
	w.lfg.available = {}
	openHome(w, r)
	eq(row(r).disabled, true)
	ok(has(r, "No Group Finder category found"), "the reason (" .. table.concat(r:visibleTexts(), " | ") .. ")")
	r:clickText(W_SEARCH)
	w:advance(2)
	eq(calls(w, "Search"), 0)
	eq(#w.lfg.searches, 0)
	T.clean(w)
end)

test("gf b2-7: a search made by Blizzard's own window changes nothing on the screen", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	openHome(w, r)
	w:advance(5)
	local before = table.concat(r:visibleTexts(), "|")
	r:lfgForeignSearch()
	w:advance(3)
	eq(table.concat(r:visibleTexts(), "|"), before)
	T.clean(w)
end)

test("gf b2-8: lockdown (every field secret): nothing shown, no error", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	openHome(w, r)
	r:lfgLockdown(true)
	r:clickText(W_SEARCH)
	w:advance(1.5)
	eq(has(r, "In the Group Finder"), nil)
	eq(has(r, "more listings"), nil)
	ok(has(r, W_SEARCH), "the button is still there")
	T.clean(w)
end)

test("gf b2-9: switching the setting off takes the button and the lines away; on again brings the button", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	openHome(w, r)
	r:clickText(W_SEARCH)
	w:advance(1.5)
	ok(has(r, "In the Group Finder, Ashenvale"))
	r.W.db.groupFinder = false
	r.W.Fire("SETTINGS", "groupFinder")
	w:advance(1)
	eq(has(r, "Group Finder"), nil)
	r.W.db.groupFinder = true
	r.W.Fire("SETTINGS", "groupFinder")
	w:advance(1)
	ok(has(r, W_SEARCH), "the button is back")
	T.clean(w)
end)
