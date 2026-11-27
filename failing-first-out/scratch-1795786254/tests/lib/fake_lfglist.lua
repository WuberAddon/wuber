-- tests/lib/fake_lfglist.lua: the fake game's Group Finder (C_LFGList) for the Group Finder feature
-- (docs/DESIGN-GROUP-FINDER.md). Loaded once by tests/harness.lua (H.fakeLfg); H.fakeLfg.api runs for every client
-- while its game API is built. Nothing here fires an event or changes anything unless a test (or the addon) calls
-- it, so a test that never turns the feature on behaves as before.
--
-- World state: w.lfg = { listings = { [playerName] = { id, name, note, activityID, zone } }, searches = { one row per
--   Search the addon made }, calls = { the name of every C_LFGList function called, in order }, available = nil | { activity
--   ids } (nil: both fake activities), failNext = true (the next search answers LFG_LIST_SEARCH_FAILED),
--   silent = true (searches are never answered), removeError = true (RemoveListing raises),
--   secretFields = { leaderName = true, comment = true, numMembers = true, activityIDs = true, name = true, areaName = true } (only these
--   fields are secret: a mixed case), secretIds = true (every result id is secret), retailShape = true (GetSearchResults answers
--   count, ids), callLog = { { name, hw } per call: hw is true when it ran inside the client's hardware click } }.
-- Activities: 1001 (category 10, "dungeon") and 2001 (category 20, "raid").
-- In the client: C_LFGList.{HasActiveEntryInfo, GetActiveEntryInfo, RemoveListing, Search (a hardware click only: refused
--   and recorded as a violation otherwise; answered after 1 s), GetSearchResults, GetSearchResultInfo,
--   GetSearchResultPlayerInfo, GetActivityInfoTable, GetAvailableActivities}, canaccessvalue.
--   CreateListing and UpdateListing exist only so a test can prove the addon never calls them (a violation).
-- Client helpers: client:lfgPost(note, activityID, zone) (the player's own click on Blizzard's Post button),
--   client:lfgLockdown(on) (every search field becomes the secret sentinel), client:lfgForeignSearch() (a search made by
--   Blizzard's own window: results arrive without the addon asking).

return function(H, World, Client)
	local F = {}
	local SECRET = H.SECRET
	for _, e in ipairs({ "LFG_LIST_ACTIVE_ENTRY_UPDATE", "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_FAILED" }) do
		H.KNOWN_EVENTS[e] = true
	end
	local ACTIVITIES = {
		[1001] = { categoryID = 10, fullName = "Fake Dungeon" },
		[2001] = { categoryID = 20, fullName = "Fake Raid" },
	}

	local function state(w)
		if not w.lfg then w.lfg = { listings = {}, searches = {}, calls = {}, seq = 0 } end
		return w.lfg
	end
	F.state = state

	local function matching(w, category)
		local out = {}
		for _, l in pairs(state(w).listings) do
			local act = ACTIVITIES[l.activityID]
			if category == nil or (act and act.categoryID == category) then out[#out + 1] = l end
		end
		table.sort(out, function(a, b) return a.id < b.id end)
		return out
	end

	local function byId(w, id)
		for _, l in pairs(state(w).listings) do
			if l.id == id then return l end
		end
	end

	local function answer(client, category)
		local ids = {}
		for i, l in ipairs(matching(client.world, category)) do ids[i] = l.id end
		client.lfgResults = ids
		client:fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	end

	function F.api(env, client, p, w, needClick)
		local L = state(w)
		local function call(name, f)
			return function(...)
				L.calls[#L.calls + 1] = name
				L.callLog = L.callLog or {}
				L.callLog[#L.callLog + 1] = { name = name, hw = w.hardware == client }
				return f(...)
			end
		end
		local function forbiddenCall(name)
			return function()
				L.calls[#L.calls + 1] = name
				w.violations[#w.violations + 1] = p.name .. ": " .. name .. " called by addon"
			end
		end
		env.canaccessvalue = function(v) return v ~= SECRET end
		env.C_LFGList = {
			HasActiveEntryInfo = call("HasActiveEntryInfo", function() return L.listings[p.name] ~= nil end),
			GetActiveEntryInfo = call("GetActiveEntryInfo", function()
				local l = L.listings[p.name]
				if not l then return nil end
				return { activityIDs = { l.activityID } }
			end),
			RemoveListing = call("RemoveListing", function()
				if L.removeError then error("C_LFGList.RemoveListing: the game refused", 2) end
				if L.listings[p.name] then
					L.listings[p.name] = nil
					client:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
				end
			end),
			Search = call("Search", function(categoryID)
				if needClick("C_LFGList.Search") then return end
				L.searches[#L.searches + 1] = { name = p.name, category = categoryID, at = w.time }
				if L.silent then return end
				w:after(1, function()
					if L.failNext then
						L.failNext = nil
						client:fire("LFG_LIST_SEARCH_FAILED")
					else
						answer(client, categoryID)
					end
				end, client, "LFGSearch")
			end),
			GetSearchResults = call("GetSearchResults", function()
				local out = {}
				for i, id in ipairs(client.lfgResults or {}) do out[i] = L.secretIds and SECRET or id end
				if L.retailShape then return #out, out end
				return out
			end),
			GetSearchResultInfo = call("GetSearchResultInfo", function(id)
				local l = byId(w, id)
				if not l then return nil end
				if client.lfgLocked then
					return { searchResultID = SECRET, leaderName = SECRET, comment = SECRET, activityIDs = SECRET, numMembers = SECRET }
				end
				local sf = L.secretFields or {}
				local function f(k, v) if sf[k] then return SECRET end return v end
				return { searchResultID = f("searchResultID", l.id), leaderName = f("leaderName", l.name), comment = f("comment", l.note),
					activityIDs = f("activityIDs", { l.activityID }), numMembers = f("numMembers", 1) }
			end),
			GetSearchResultPlayerInfo = call("GetSearchResultPlayerInfo", function(id, i)
				local l = byId(w, id)
				if not l or i ~= 1 then return nil end
				if client.lfgLocked then return { name = SECRET, areaName = SECRET, isLeader = SECRET } end
				local sf = L.secretFields or {}
				return { name = sf.name and SECRET or l.name, areaName = sf.areaName and SECRET or l.zone, isLeader = true }
			end),
			GetActivityInfoTable = call("GetActivityInfoTable", function(id)
				local a = ACTIVITIES[id]
				return a and { categoryID = a.categoryID, fullName = a.fullName } or nil
			end),
			GetAvailableActivities = call("GetAvailableActivities", function()
				local out = {}
				for i, id in ipairs(L.available or { 1001, 2001 }) do out[i] = id end
				return out
			end),
			CreateListing = forbiddenCall("CreateListing"),
			UpdateListing = forbiddenCall("UpdateListing"),
		}
	end

	-- the player's own click on Blizzard's Post button (not a call of the addon)
	function Client:lfgPost(note, activityID, zone)
		local L = state(self.world)
		L.seq = L.seq + 1
		L.listings[self.player.name] = { id = L.seq, name = self.player.name, note = note or "", activityID = activityID or 1001, zone = zone or "" }
		self:fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	end

	function Client:lfgLockdown(on) self.lfgLocked = on ~= false end

	-- a search made by Blizzard's own window: the results arrive, the addon did not ask
	function Client:lfgForeignSearch()
		answer(self, nil)
	end

	return F
end
