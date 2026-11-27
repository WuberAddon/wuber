-- Module: Net.GroupFinder
-- Purpose: the game's Group Finder as a second way to find drivers (decision draft, setting groupFinder, off by default):
--   the rider's search (one click, one answer) and the driver's own listing (shown, removed on his click). Never creates a listing.
-- API: W.GroupFinder (alias GF), GF.On, GF.Search, GF.Pending, GF.ListedZone, GF.ExtraCount, GF.MyListing, GF.Delist, GF.StillListed,
--   GF.SearchCategory, GF.DRAFT_WORDS, GF.CATEGORY
-- Internals: SEARCH_GIVE_UP, LISTED_KEEP, pending, pendingToken, listed, extra, lfg, readable, text, categoryOf, driverOnline,
--   handleResults, zoneOf, finish
-- Uses: Net.Base
-- Later: (none)
-- Events: listens LFG_LIST_SEARCH_RESULTS_RECEIVED, LFG_LIST_SEARCH_FAILED, LFG_LIST_ACTIVE_ENTRY_UPDATE; fires GROUPFINDER
-- Standalone: no
-- Test: tests/gf/gf_a_core_test.lua
-- From: new in Wuber 2.5 (docs/DESIGN-GROUP-FINDER.md)
--
-- What the game allows (see the design): C_LFGList.Search only from a real click, one at a time; the results carry the
-- leader, the note and the zone, and in dungeons, raids and restricted maps every field is secret (canaccessvalue).
-- A listing is made only by the driver with Blizzard's own Post button: Wuber never calls CreateListing or UpdateListing,
-- never touches applicants, invites, whispers or chats from here, and never hooks a Blizzard frame. Setting off: every
-- function returns at once and no C_LFGList call is made at all.
--
-- A search result marks a driver only when its leader is a driver Wuber already knows (W.drivers) AND the note mentions
-- Wuber. An unknown leader whose note mentions Wuber only adds to a count (ExtraCount): no name, no card.

local _, W = ...
local Mod = W.Module("Net.GroupFinder", { "Net.Base" })

local GF = {}
W.GroupFinder = GF
Mod.GF = GF

local SEARCH_GIVE_UP = 15 -- seconds: a search the game never answers stops being pending
local LISTED_KEEP = 600   -- seconds: a listed driver is forgotten after 10 minutes

-- The probed category id (filled from the in-game probe, step 1 of the design's proof list). nil until then.
GF.CATEGORY = nil

-- Every player-facing word of this feature. ALL OF THESE ARE DRAFTS: none is approved wording (needs the maintainer).
GF.DRAFT_WORDS = {
	settingName = "Group Finder (preview)",                                        -- draft
	settingHint = "Find and be found through the game's Group Finder",             -- draft
	note = "Wuber summons to %s",                                                  -- draft: the short note the driver types by hand (%s = destination); must contain "Wuber" (handleResults)
	listed = "You are listed in the Group Finder",                                 -- draft: the driver's status line
	notListed = "You are not listed in the Group Finder",                          -- draft: the driver's status line
	listButton = "List me in the Group Finder",                                    -- draft
	removeButton = "Remove my listing",                                            -- draft
	searchButton = "Search the Group Finder",                                      -- draft
	card = "In the Group Finder, %s",                                              -- draft: the driver card line (%s = zone)
	extra = "%d more listings mention Wuber: open the Group Finder",               -- draft: the count line
	stillListed = "You are offline but still listed in the Group Finder",          -- draft: the reminder
	steps = "Open the Group Finder, go to List yourself, choose the Custom category, pick a Playstyle, click the Note box and type the note below by hand, then List me.", -- draft: the sheet's steps
	busy = "Searching...",                                                         -- draft: why the search button waits
	nocategory = "No Group Finder category found",                                 -- draft: why the search button is off
	nolfg = "The Group Finder is not available",                                   -- draft: why the search button is off
	here = "here",                                                                 -- draft: the note's destination when the driver has none
}

local pending, pendingToken = false, 0
local listed = {}  -- listed[driverKey] = { zone, at }
local extra, extraAt = 0, 0

local function now() return type(GetTime) == "function" and GetTime() or 0 end
local function lfg() return type(C_LFGList) == "table" and C_LFGList or nil end

-- A search field the game lets us read, or nil. canaccessvalue is asked before any comparison. No canaccessvalue in this client: every value is readable.
local function readable(v)
	-- ask the game FIRST: in the real client a secret value may raise an error on any comparison, even == nil
	if type(canaccessvalue) == "function" and not canaccessvalue(v) then return nil end
	if v == nil then return nil end
	return v
end
local function text(v)
	v = readable(v)
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

function GF.On()
	return type(W.db) == "table" and W.db.groupFinder == true
end

local function fireChange()
	W.Fire("GROUPFINDER")
end

-- the category of one activity id, or nil
local function categoryOf(api, activity)
	activity = readable(activity)
	if type(activity) ~= "number" or type(api.GetActivityInfoTable) ~= "function" then return nil end
	local ok, info = pcall(api.GetActivityInfoTable, activity)
	if not ok or type(info) ~= "table" then return nil end
	local cat = readable(info.categoryID)
	return type(cat) == "number" and cat or nil
end

-- The category a search uses: the driver's own active entry first, then the probed CATEGORY, then Blizzard's own default
-- (the first category among the available activities). nil: none known (the search button stays off).
local catCache, catNoneUntil = nil, 0 -- the resolved category (kept until something changes it); a "none" answer is kept 5 seconds
local catSeenConst = nil -- GF.CATEGORY as it was when the cached answer was made
local function dropCategory() catCache, catNoneUntil = nil, 0 end

local resolveCategory
function GF.SearchCategory()
	if not GF.On() then return nil end
	if catSeenConst ~= GF.CATEGORY then dropCategory() end -- the probed constant was set after the last answer
	if catCache then return catCache end
	if now() < catNoneUntil then return nil end
	catSeenConst = GF.CATEGORY
	local cat = resolveCategory()
	if cat then catCache = cat else catNoneUntil = now() + 5 end
	return cat
end

resolveCategory = function()
	local api = lfg()
	if not api then return nil end
	if type(api.HasActiveEntryInfo) == "function" and type(api.GetActiveEntryInfo) == "function" then
		local ok, has = pcall(api.HasActiveEntryInfo)
		if ok and has == true then
			local ok2, entry = pcall(api.GetActiveEntryInfo)
			local ids = ok2 and type(entry) == "table" and readable(entry.activityIDs) or nil
			if type(ids) == "table" then
				local cat = categoryOf(api, ids[1])
				if cat then return cat end
			end
		end
	end
	if type(GF.CATEGORY) == "number" then return GF.CATEGORY end
	if type(api.GetAvailableActivities) == "function" then
		local ok, acts = pcall(api.GetAvailableActivities)
		if ok and type(acts) == "table" then
			for i = 1, #acts do
				local cat = categoryOf(api, acts[i])
				if cat then return cat end
			end
		end
	end
	return nil
end

-- The rider's search. ONLY from a button's OnClick (the game refuses it from an event or a timer).
-- Returns true, or false and why: "off", "nolfg", "busy", "nocategory".
function GF.Search()
	if not GF.On() then return false, "off" end
	local api = lfg()
	if not api or type(api.Search) ~= "function" then return false, "nolfg" end
	if pending then return false, "busy" end
	local cat = GF.SearchCategory()
	if not cat then return false, "nocategory" end
	dropCategory() -- asked again each search: the driver's own entry may have changed
	pending = true
	pendingToken = pendingToken + 1
	local token = pendingToken
	if type(C_Timer) == "table" and C_Timer.After then
		C_Timer.After(SEARCH_GIVE_UP, function()
			if pending and token == pendingToken then
				pending = false
				fireChange()
			end
		end)
	end
	local ok = pcall(api.Search, cat)
	if not ok then
		pending = false
		return false, "nolfg"
	end
	fireChange()
	return true
end

-- true while Wuber's own search waits for its answer (read only: the rider's button shows it)
function GF.Pending()
	return GF.On() and pending
end

-- the zone text of one result's leader (his own line among the members), or nil
local function zoneOf(api, id, key, members)
	if type(api.GetSearchResultPlayerInfo) ~= "function" then return nil end
	local zone
	for i = 1, math.min(5, members) do
		local ok, info = pcall(api.GetSearchResultPlayerInfo, id, i)
		if not ok or type(info) ~= "table" then break end
		local name, area = text(info.name), text(info.areaName)
		if name and area and W.Key(name) == key then return area end
		if i == 1 then zone = area end
	end
	return zone
end

local function handleResults()
	local api = lfg()
	if not api or type(api.GetSearchResults) ~= "function" or type(api.GetSearchResultInfo) ~= "function" then return end
	local okR, a, b = pcall(api.GetSearchResults)
	if not okR then return end
	local ids = type(a) == "table" and a or b
	local fresh, count, at = {}, 0, now()
	local me = W.Key(W.UnitName("player"))
	if type(ids) == "table" then
		for i = 1, #ids do
			local ok, err = pcall(function()
				local info = api.GetSearchResultInfo(ids[i])
				if type(info) ~= "table" then return end
				local note, leader = text(info.comment), text(info.leaderName)
				if not note or not note:lower():find("wuber", 1, true) then return end
				if not leader then return end -- a secret or missing leader name: nothing to name, nothing to count
				local key = W.Key(leader)
				if key == me then return end
				if W.drivers[key] then
					local members = readable(info.numMembers)
					local zone = zoneOf(api, ids[i], key, type(members) == "number" and members or 1)
					if zone then fresh[key] = { zone = zone, at = at } end
				else
					count = count + 1
				end
			end)
			if not ok then W.Error("GroupFinder", err) end
		end
	end
	listed, extra, extraAt = fresh, count, at
end

W.On("LFG_LIST_SEARCH_RESULTS_RECEIVED", function()
	if not GF.On() or not pending then return end -- a search of Blizzard's window or another addon is not ours
	pending = false
	dropCategory()
	local okH, err = pcall(handleResults)
	if not okH then W.Error("GroupFinder", err) end
	fireChange()
end)

W.On("LFG_LIST_SEARCH_FAILED", function()
	if not GF.On() or not pending then return end
	pending = false
	fireChange()
end)

W.On("LFG_LIST_ACTIVE_ENTRY_UPDATE", function()
	if not GF.On() then return end
	dropCategory()
	fireChange()
end)

W.Listen("SETTINGS", function(key)
	if key == "groupFinder" then dropCategory() end
end)

-- the zone a known driver is listed in (from the last search, at most 10 minutes old), or nil
function GF.ListedZone(key)
	if not GF.On() then return nil end
	local e = key and listed[key]
	if not e then return nil end
	if now() - e.at > LISTED_KEEP then
		listed[key] = nil
		return nil
	end
	return e.zone
end

-- how many listings of the last search mention Wuber with a leader Wuber does not know
function GF.ExtraCount()
	if not GF.On() or now() - extraAt > LISTED_KEEP then return 0 end
	return extra
end

-- the driver's own listing (read from the game each time: the event only says it changed)
function GF.MyListing()
	if not GF.On() then return false end
	local api = lfg()
	if not api or type(api.HasActiveEntryInfo) ~= "function" then return false end
	local ok, has = pcall(api.HasActiveEntryInfo)
	return ok and has == true
end

-- Remove the driver's listing. ONLY from his own click. Returns true when the call went through.
function GF.Delist()
	if not GF.On() or not GF.MyListing() then return false end
	local ok = pcall(C_LFGList.RemoveListing)
	fireChange()
	return ok
end

local function driverOnline()
	local DR = W.Drive
	if type(DR) == "table" and type(DR.IsOpen) == "function" then
		local ok, open = pcall(DR.IsOpen)
		if ok and open == true then return true end
	end
	local ok, c = pcall(W.Char)
	return ok and type(c) == "table" and c.drive == true
end

-- offline but still listed: the reminder shows
function GF.StillListed()
	if not GF.On() or driverOnline() then return false end
	return GF.MyListing()
end
