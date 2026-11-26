-- Group Finder (group C): fixes from a reviewer's second look. Design: docs/DESIGN-GROUP-FINDER.md.
-- Secret values in mixed cases, the results call inside pcall, the rider's own listing, Delist only on clicks, nothing sent
-- and nothing hooked by the Group Finder parts, Home's frames built lazily, the category cached, no literal player text.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local NOTE = "Wuber summons to Ashenvale"
local SEARCH = "Search the Group Finder"

local function world(on)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	if on then r.W.db.groupFinder = true end
	return w, d, r
end

local function search(r)
	r.world.hardware = r
	local a, b = r.W.GroupFinder.Search()
	r.world.hardware = nil
	r.world:advance(1.5)
	return a, b
end

local function calls(w, name)
	local n = 0
	for _, c in ipairs(w.lfg and w.lfg.calls or {}) do
		if name == nil or c == name then n = n + 1 end
	end
	return n
end

local function key(r, name) return r.W.Key(name) end

-- ---- 1. secret values, mixed cases
test("gf c1.1: a secret leader name with a readable note: nothing listed and not counted as extra, no error", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w.lfg.secretFields = { leaderName = true }
	eq(search(r), true)
	eq(r.W.GroupFinder.ListedZone(key(r, T.ANITA)), nil)
	eq(r.W.GroupFinder.ExtraCount(), 0, "a secret leader is not an extra listing")
	T.clean(w)
end)

test("gf c1.2: a secret note with a readable leader: nothing listed, nothing counted", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w.lfg.secretFields = { comment = true }
	search(r)
	eq(r.W.GroupFinder.ListedZone(key(r, T.ANITA)), nil)
	eq(r.W.GroupFinder.ExtraCount(), 0)
	T.clean(w)
end)

test("gf c1.3: secret member names and zones, or secret result ids, or everything secret: nothing listed", function()
	for _, mode in ipairs({ "playerInfo", "ids", "all" }) do
		local w, d, r = world(true)
		d:lfgPost(NOTE, 1001, "Ashenvale")
		if mode == "playerInfo" then w.lfg.secretFields = { name = true, areaName = true }
		elseif mode == "ids" then w.lfg.secretIds = true
		else d:lfgLockdown(true); r:lfgLockdown(true) end
		search(r)
		eq(r.W.GroupFinder.ListedZone(key(r, T.ANITA)), nil, mode)
		eq(r.W.GroupFinder.ExtraCount(), 0, mode)
		T.clean(w)
	end
end)

test("gf c1.4: readable asks the game (canaccessvalue) about a value before it compares it, even a missing one", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	local orig, sawNil = r.env.canaccessvalue, false
	r.env.canaccessvalue = function(v)
		if v == nil then sawNil = true end
		return orig(v)
	end
	w.lfg.listings[T.ANITA].note = nil -- the game sent no note at all
	search(r)
	r.env.canaccessvalue = orig
	ok(sawNil, "canaccessvalue was asked about the missing value first")
	T.clean(w)
end)

-- ---- 2. GetSearchResults inside pcall, both shapes
test("gf c2.1: both shapes of GetSearchResults list the driver", function()
	for _, shape in ipairs({ "table", "retail" }) do
		local w, d, r = world(true)
		d:lfgPost(NOTE, 1001, "Ashenvale")
		w.lfg.retailShape = shape == "retail"
		eq(search(r), true)
		eq(r.W.GroupFinder.ListedZone(key(r, T.ANITA)), "Ashenvale", shape)
		T.clean(w)
	end
end)

test("gf c2.2: GetSearchResults raising an error: no error escapes, the search is not pending, a new search is possible", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	local api = r.env.C_LFGList
	local orig = api.GetSearchResults
	api.GetSearchResults = function() error("secret results", 2) end
	eq(search(r), true)
	eq(r.W.GroupFinder.Pending(), false, "pending cleared")
	api.GetSearchResults = orig
	eq(search(r), true, "a new search starts")
	eq(r.W.GroupFinder.ListedZone(key(r, T.ANITA)), "Ashenvale")
	T.clean(w)
end)

-- ---- 3. own listing, realm suffix
test("gf c3.1: the rider's own listing with a Wuber note is neither listed nor counted", function()
	local w, d, r = world(true)
	r:lfgPost(NOTE, 1001, "Ashenvale")
	search(r)
	eq(r.W.GroupFinder.ListedZone(key(r, T.TESTCHAR)), nil, "not listed")
	eq(r.W.GroupFinder.ExtraCount(), 0, "not counted")
	T.clean(w)
end)

test("gf c3.2: a leader written Name-Realm for a known driver still matches", function()
	local w, d, r = world(true)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w.lfg.listings[T.ANITA].name = T.ANITA .. "-Somerealm"
	search(r)
	eq(r.W.GroupFinder.ListedZone(key(r, T.ANITA)), "Ashenvale")
	eq(r.W.GroupFinder.ExtraCount(), 0)
	T.clean(w)
end)

-- ---- 4. Delist only on clicks
local function removeCalls(w, onlyOutside)
	local n = 0
	for _, c in ipairs(w.lfg.callLog or {}) do
		if c.name == "RemoveListing" and (not onlyOutside or not c.hw) then n = n + 1 end
	end
	return n
end

local function driverWorld()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.db.groupFinder = true
	T.goOnline(d)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true)
	w:advance(2.5)
	d:clickText("Drive")
	w:advance(1.5)
	return w, d
end

test("gf c4.1: offline but listed: ten minutes of timers, entry updates and the setting toggled never call RemoveListing", function()
	local w, d = driverWorld()
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w:advance(3)
	d.W.Driver.SetOnline(false)
	w:advance(3)
	for _ = 1, 20 do
		w:advance(30)
		d:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	end
	d.W.db.groupFinder = false
	d.W.Fire("SETTINGS", "groupFinder")
	w:advance(5)
	d.W.db.groupFinder = true
	d.W.Fire("SETTINGS", "groupFinder")
	w:advance(5)
	eq(calls(w, "RemoveListing"), 0, "RemoveListing calls")
	ok(w.lfg.listings[T.ANITA], "the listing is still there")
	T.clean(w)
end)

test("gf c4.2: every RemoveListing call happens inside a hardware click (the Remove button, the Open pill)", function()
	local w, d = driverWorld()
	local WD = d.W.GroupFinder.DRAFT_WORDS
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w:advance(3)
	d:clickText(WD.removeButton)
	w:advance(2)
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w:advance(3)
	d:clickOn(d.W.Driver.ui.console.open)
	w:advance(2)
	ok(removeCalls(w) >= 2, "both clicks removed a listing")
	eq(removeCalls(w, true), 0, "RemoveListing calls outside a click")
	T.clean(w)
end)

-- ---- 5. nothing sent, nothing hooked by the Group Finder parts
local function counts(w)
	local sent = 0
	for _, c in ipairs(w.clients or {}) do sent = sent + (c.sent or 0) end
	return { whispers = #w.whispers, invites = #w.invites, addon = #w.addonLog, sent = sent, violations = #w.violations }
end

local sessionBody
-- a whole session; on: the setting. Returns the send counts, the hooks made, and whether clicks found their buttons
local function session(on)
	local mtRef = {}
	local okS, a, b, c = pcall(function() return sessionBody(on, mtRef) end)
	if mtRef.mt then mtRef.mt.__index = mtRef.orig end
	if not okS then error(a, 0) end
	return a, b, c
end
sessionBody = function(on, mtRef)
	local hooks = { secure = 0, script = 0, foreign = {} }
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	d.W.db.groupFinder = on
	r.W.db.groupFinder = on
	for _, c in ipairs({ d, r }) do
		local orig = c.env.hooksecurefunc
		c.env.hooksecurefunc = function(a, ...)
			hooks.secure = hooks.secure + 1
			hooks.foreign[#hooks.foreign + 1] = "hooksecurefunc " .. tostring(type(a) == "string" and a or (type(a) == "table" and a.GetName and a:GetName()) or a)
			return orig(a, ...)
		end
	end
	local probe = r.env.CreateFrame("Frame")
	local mt = getmetatable(probe)
	local origIndex = mt.__index
	mtRef.mt, mtRef.orig = mt, origIndex
	mt.__index = function(t, k)
		local v
		if type(origIndex) == "function" then v = origIndex(t, k) else v = origIndex[k] end
		if k == "HookScript" and type(v) == "function" then
			return function(self, ...)
				hooks.script = hooks.script + 1
				local nm = type(self.GetName) == "function" and self:GetName() or nil
				if nm and not tostring(nm):find("^Wuber") then hooks.foreign[#hooks.foreign + 1] = "HookScript " .. tostring(nm) end
				return v(self, ...)
			end
		end
		return v
	end
	T.goOnline(d)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true)
	r.W.UI.Toggle(true)
	w:advance(3)
	d:clickText("Drive")
	w:advance(1.5)
	local WD = d.W.GroupFinder.DRAFT_WORDS
	d:lfgPost(NOTE, 1001, "Ashenvale")
	w:advance(3)
	if on then
		r:clickText(SEARCH)
		w:advance(2)
		d:clickText(WD.removeButton)
		w:advance(2)
		d:lfgPost(NOTE, 1001, "Ashenvale")
		w:advance(3)
	end
	d:clickOn(d.W.Driver.ui.console.open)
	w:advance(5)
	mt.__index = origIndex
	return w, counts(w), hooks
end

test("gf c5.1: a whole Group Finder session sends no whisper, invite, chat line or addon message of its own, and hooks nothing more", function()
	local wOff, off, hOff = session(false)
	T.clean(wOff)
	local wOn, on, hOn = session(true)
	eq(on.whispers, off.whispers, "whispers")
	eq(on.invites, off.invites, "invites")
	eq(on.violations, off.violations, "chat-line violations")
	eq(on.addon, off.addon, "addon messages")
	eq(on.sent, off.sent, "addon messages sent")
	eq(hOn.secure, hOff.secure, "hooksecurefunc calls")
	eq(table.concat(hOn.foreign, ","), table.concat(hOff.foreign, ","), "hooks on frames or functions that are not Wuber's own")
	eq(calls(wOn, "CreateListing") + calls(wOn, "UpdateListing"), 0)
	T.clean(wOn)
end)

-- ---- 6. Home builds its Group Finder frames lazily
local function home(w, r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	return r.W.UI.state.screens.home
end

test("gf c6.1: setting off: Home has no Group Finder frames at all", function()
	local w, d, r = world(false)
	local s = home(w, r)
	r.W.UI.Refresh(true)
	w:advance(2)
	eq(s.gfRows, nil, "gfRows")
	eq(s.gfSearch, nil, "gfSearch")
	eq(s.gfExtra, nil, "gfExtra")
	T.clean(w)
end)

test("gf c6.2: setting turned on: the frames appear and the search button shows; turned off again: it hides", function()
	local w, d, r = world(false)
	local s = home(w, r)
	r.W.db.groupFinder = true
	r.W.Fire("SETTINGS", "groupFinder")
	w:advance(2)
	ok(s.gfRows and s.gfSearch and s.gfExtra, "the frames are built")
	local seen = false
	for _, t in ipairs(r:visibleTexts()) do if t == SEARCH then seen = true end end
	ok(seen, "the search button shows")
	r.W.db.groupFinder = false
	r.W.Fire("SETTINGS", "groupFinder")
	w:advance(2)
	seen = false
	for _, t in ipairs(r:visibleTexts()) do if t == SEARCH then seen = true end end
	ok(not seen, "the search button is gone again")
	T.clean(w)
end)

-- ---- 7. the category is cached
test("gf c7.1: twenty layouts of Home ask the game for the available activities at most once", function()
	local w, d, r = world(true)
	home(w, r)
	local before = calls(w, "GetAvailableActivities")
	for _ = 1, 20 do
		r.W.UI.Refresh(true)
		w:advance(0.5)
	end
	ok(calls(w, "GetAvailableActivities") - before <= 1, "GetAvailableActivities calls: " .. (calls(w, "GetAvailableActivities") - before))
	T.clean(w)
end)

test("gf c7.2: the cached category is dropped when the entry changes, the setting toggles and after a search", function()
	local w, d, r = world(true)
	local GF = r.W.GroupFinder
	eq(GF.SearchCategory(), 10)
	local n = calls(w, "GetAvailableActivities")
	GF.SearchCategory()
	eq(calls(w, "GetAvailableActivities"), n, "cached")
	r:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	GF.SearchCategory()
	eq(calls(w, "GetAvailableActivities"), n + 1, "asked again after the entry changed")
	r.W.Fire("SETTINGS", "groupFinder")
	GF.SearchCategory()
	eq(calls(w, "GetAvailableActivities"), n + 2, "asked again after the setting changed")
	search(r)
	GF.SearchCategory()
	ok(calls(w, "GetAvailableActivities") >= n + 3, "asked again after a search")
	T.clean(w)
end)

-- ---- 8. no literal player text outside DRAFT_WORDS
test("gf c8.1: the List me sheet's note with no known destination uses a DRAFT_WORDS word, not a literal", function()
	local w, d = driverWorld()
	local WD = d.W.GroupFinder.DRAFT_WORDS
	ok(WD.here, "DRAFT_WORDS.here exists")
	d.W.Drive.SetDest(nil)
	w:advance(1.5)
	d:clickText(WD.listButton)
	w:advance(1.5)
	local sh = d.W.Driver.ui.sheets.gflist
	ok(sh and sh.note and sh.note.edit, "the sheet opens")
	local dest = sh.note.edit:GetText():match("^Wuber summons to (.*), request in Wuber$")
	ok(dest and dest ~= "", "a destination word stands in the note")
	T.clean(w)
end)
