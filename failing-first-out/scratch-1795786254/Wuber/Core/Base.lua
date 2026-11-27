-- Module: Core.Base
-- Purpose: identity and constants (W.VERSION, PREFIX, CHANNEL, CREATOR), rulesets and seed drivers (the
--   W.SEEDS block tools/build-seeds.js rewrites), secret-value guards (W.Plain/Str/Num), saved-settings
--   defaults and W.InitDB / W.Char.
-- API: W.ADDON, Wuber, W.VERSION, W.PREFIX, W.CHANNEL, W.PROTO, W.CREATOR, W.IsCreator, W.MIN_PRICE,
--   W.FOUNDER_RULESET, W.RulesetOf, W.Ruleset, W.OnFounderRuleset, W.SEEDS, W.SEED_FOUNDERS, W.SeedList,
--   W.IsSeed, W.PIONEERS, W.PioneerKind, W.IsPioneer, W.PioneerNames, W.Plain, W.Str, W.Num, W.DEFAULTS,
--   W.CHAR_DEFAULTS, W.InitDB, W.Char, W.Advanced, W.SetAdvanced
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens (none); fires SETTINGS (advanced, from W.SetAdvanced)
-- Standalone: no
-- Test: tests/core/base_test.lua
-- From: Core.lua 1-274 (Wuber 2.2.1)
--
-- Rule for new code: read the game before logout, never at PLAYER_LOGOUT (the game answers wrongly then: no gold, no
-- map, not resting). Saved data can also load empty while the file is intact: keep only preferences in it and work
-- the rest out from the live game (W.Ruleset does; an empty WuberDB is today taken for a new install).
--
-- Wuber: a "call a summon" network for WoW Forever.
-- Core: the namespace every file shares, saved settings, events, timers, and the small
-- helpers for values the 1.60.1 client may keep secret. Nothing here draws or talks.

local ADDON, W = ...
local Mod = W.Module("Core.Base", {})
W.ADDON = ADDON
Wuber = W -- the one global (also read by tests and by /dump)

-- Internal builds say "a.b.c-dev" (PLAN-2.3.2 release rule): the update notice's strict a.b.c
-- parse ignores it, every version gate (W.VerAtLeast) reads it as a.b.c. Only the CurseForge build
-- says the plain number.
W.VERSION = "2.4.3-dev"
W.PREFIX = "WUBER"      -- addon message prefix (registered at login)
W.CHANNEL = "WuberNet"  -- the hidden chat channel the network runs on
W.PROTO = 1             -- protocol version carried in every message
-- The founder's characters (keys as W.Key): crowned, brightest glow. Checked locally against
-- the names the game reports, so nobody can claim it over the network. Another player's name
-- only counts on the founders' ruleset (review 2.2 #12: anywhere else those names may be
-- anyone's); the player's own character always does.
W.CREATOR = { ["anita lift"] = true, ["farra way"] = true, ["hayley cab"] = true, ["wuber rocks"] = true }
function W.IsCreator(nameOrKey)
	local k = W.Key and W.Key(nameOrKey)
	if k == nil or W.CREATOR[k] ~= true then return false end
	local me = W.myKey
	if not me and W.UnitName and W.Key then me = W.Key(W.UnitName("player")) end
	if k == me then return true end
	return type(W.OnFounderRuleset) == "function" and W.OnFounderRuleset() == true
end
W.MIN_PRICE = 5000      -- 50s: the lowest fare on the network (drivers' time is worth it).
                        -- Riders never see a driver beaconing less; drivers can't set less.

---------------------------------------------------------------------------
-- Rulesets and seed drivers
---------------------------------------------------------------------------
-- Forever runs separate worlds per region and ruleset (EU / US; Normal = PvE, PvP, RP,
-- Hardcore): whispers don't cross them. The founders play on EU Normal, so only clients on
-- W.FOUNDER_RULESET ever whisper them (seed pings, driver announces) or crown them; anywhere
-- else their names may belong to other people.
W.FOUNDER_RULESET = "EU-PvE"
-- Server ids of the EU-PvE characters, as the middle part of a player GUID "Player-<id>-<hex>". Build 71037 names
-- no realm at all (GetRealmName "", UnitFullName no realm: the in-game realm census, recorded fact realm.name.empty71037), so W.Ruleset
-- falls back on this, only then. Evidence: the founders' own characters' GUIDs in the author's saved data show 6939
-- (Farra Way, Hayley Cab), 6941 (Wuber Rocks), 6947 (Anita Lift); chat on the same ruleset (channels never cross
-- rulesets) also shows 6841, 6855, 6937, 6945, 6949.
W.FOUNDER_SERVERS = { [6841] = true, [6855] = true, [6937] = true, [6939] = true, [6941] = true, [6945] = true,
	[6947] = true, [6949] = true }

-- "CAMWOW EU5 Realm 5 PvE" -> "EU-PvE"; "... US2 Realm 1 PvP" -> "US-PvP"; also RP, RPPvP
-- and HC (Hardcore). The internal realm numbers are ignored. nil when the name carries no
-- region or no ruleset.
local RULE_WORDS = { pve = "PvE", normal = "PvE", pvp = "PvP", rp = "RP", rppvp = "RPPvP", ["rp-pvp"] = "RPPvP",
	hardcore = "HC", hc = "HC" }
function W.RulesetOf(realm)
	if type(realm) ~= "string" or realm == "" then return nil end
	local low = realm:lower()
	local region, rule
	for token in low:gmatch("[%w%-]+") do
		local t = token:gsub("%-$", "")
		if not region then
			local r = t:match("^(eu)%d*$") or t:match("^(us)%d*$")
			if r then region = r:upper() end
		end
		if RULE_WORDS[t] then rule = RULE_WORDS[t] end
	end
	if not (region and rule) and not low:find("%s") then
		-- a normalised name ("CAMWOWEU5Realm5PvE")
		region = region or ((low:find("eu%d") and "EU") or (low:find("us%d") and "US") or nil)
		for _, w in ipairs({ "rppvp", "hardcore", "normal", "pve", "pvp", "rp", "hc" }) do
			if low:sub(-#w) == w then
				rule = rule or RULE_WORDS[w]
				break
			end
		end
	end
	if region and rule then return region .. "-" .. rule end
	return nil
end

-- A ruleset W.RulesetOf can give (an edited saved value of another shape counts for nothing).
local RULESETS = { ["EU-PvE"] = true, ["EU-PvP"] = true, ["EU-RP"] = true, ["EU-RPPvP"] = true, ["EU-HC"] = true,
	["US-PvE"] = true, ["US-PvP"] = true, ["US-RP"] = true, ["US-RPPvP"] = true, ["US-HC"] = true }

-- This client's ruleset ("EU-PvE"), or nil when the realm name doesn't say. A ruleset the game
-- names is remembered for this character (W.db.chars[W.myKey].ruleset); only while the game
-- names no realm at all (build 71037 gives nil) is that memory used. A named realm always wins.
function W.Ruleset()
	local r, n
	if type(GetRealmName) == "function" then
		local ok, v = pcall(GetRealmName)
		r = ok and W.Str(v) or nil
	end
	local rs = W.RulesetOf(r)
	if not rs and type(GetNormalizedRealmName) == "function" then
		local ok, v = pcall(GetNormalizedRealmName)
		n = ok and W.Str(v) or nil
		rs = W.RulesetOf(n)
	end
	if not rs and type(UnitFullName) == "function" then
		-- build 71037 gives GetRealmName "" ; the realm part of the player's full name may still name it.
		-- Only a name that reads as a real realm (region and ruleset in it) counts; nothing is assumed.
		local ok, _, v = pcall(UnitFullName, "player")
		local u = ok and W.Str(v) or nil
		rs = W.RulesetOf(u)
	end
	local db, me = W.db, W.myKey
	local chars = type(db) == "table" and type(db.chars) == "table" and type(me) == "string" and me ~= "?" and me ~= ""
		and db.chars or nil
	if rs then
		if chars and RULESETS[rs] then
			local c = chars[me]
			if type(c) ~= "table" then
				c = {}
				chars[me] = c
			end
			if c.ruleset ~= rs then c.ruleset = rs end
		end
		return rs
	end
	if (r and r ~= "") or (n and n ~= "") or not chars then return nil end -- named: the name decides
	local c = chars[me]
	local m = type(c) == "table" and c.ruleset or nil
	if type(m) == "string" and RULESETS[m] then return m end
	-- nothing named, nothing remembered: the player's GUID still names its server
	local unitGuid = rawget(_G, "UnitGUID")
	if type(unitGuid) == "function" then
		local ok, g = pcall(unitGuid, "player")
		g = ok and W.Str(g) or nil
		local id = g and g:match("^Player%-(%d+)%-%x+$")
		if id and W.FOUNDER_SERVERS[tonumber(id)] then
			if type(c) ~= "table" then
				c = {}
				chars[me] = c
			end
			c.ruleset = W.FOUNDER_RULESET
			return W.FOUNDER_RULESET
		end
	end
	return nil
end

-- Whether this client may whisper the founders (it plays on their ruleset).
function W.OnFounderRuleset()
	return W.Ruleset() == W.FOUNDER_RULESET
end

-- Seed drivers per ruleset: asked by whisper at login like the founders (and with the same
-- 30-min back-off when they are offline), so a brand-new rider with no contacts still finds
-- someone to ask; the gossip mesh does the rest. The founders are added to their own ruleset
-- below. To add a driver by hand: put "First Surname" in the list of his ruleset (keep the
-- markers: tools/build-seeds.js rewrites what is between them from the author's saved variables,
-- with every driver seen in the last 14 days who didn't opt out in Settings).
-- BEGIN SEEDS (tools/build-seeds.js)
W.SEEDS = {
	["EU-PvE"] = {},
	["EU-PvP"] = {},
	["EU-RP"] = {},
	["EU-HC"] = {},
	["US-PvE"] = {},
	["US-PvP"] = {},
	["US-RP"] = {},
	["US-HC"] = {},
}
-- END SEEDS
W.SEED_FOUNDERS = { "Anita Lift", "Farra Way", "Hayley Cab", "Wuber Rocks" } -- = W.CREATOR, as names
do
	local list = W.SEEDS[W.FOUNDER_RULESET] or {}
	W.SEEDS[W.FOUNDER_RULESET] = list
	for i = #W.SEED_FOUNDERS, 1, -1 do table.insert(list, 1, W.SEED_FOUNDERS[i]) end
end

-- The seed names for a ruleset (default: ours), founders first; {} when unknown.
function W.SeedList(ruleset)
	if ruleset == nil then ruleset = W.Ruleset() end
	local list = ruleset and W.SEEDS[ruleset]
	return type(list) == "table" and list or {}
end

-- Whether this key is a seed driver of our ruleset (founders included there).
function W.IsSeed(nameOrKey)
	local k = W.Key and W.Key(nameOrKey)
	if not k then return false end
	for _, n in ipairs(W.SeedList()) do
		if W.Key(n) == k then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Pioneers: Wuber's first riders and drivers (cosmetic badges and the credits)
---------------------------------------------------------------------------
-- Shipped by hand, per ruleset like W.SEEDS: { ["EU-PvE"] = { "Name-Realm" or "First Surname", ... } }.
-- Unforgeable: a badge comes ONLY from these lists, never from a network field, saved data or
-- another player's claim. A name only counts on this client's ruleset's list (anywhere else it
-- may be someone else's), the player's own character too; only when the realm names no ruleset
-- (W.Ruleset() nil) does the player's own character count on any list. Empty lists:
-- nothing shows anywhere. The founders' look (W.IsCreator) is separate and wins where both apply.
W.PIONEERS = { riders = {}, drivers = {} }

-- whether key k is on list (a { ruleset = names } table): this ruleset's names; any ruleset's
-- only for my own character on a realm that names no ruleset (rs nil)
local function pioneerOn(list, k, rs, own)
	if type(list) ~= "table" then return false end
	for ruleset, names in pairs(list) do
		if type(names) == "table" and (ruleset == rs or (own and rs == nil)) then
			for _, n in ipairs(names) do
				if W.Key(n) == k then return true end
			end
		end
	end
	return false
end

-- whether a { ruleset = names } list holds any name at all (the empty, shipped lists are a fast no)
local function pioneerAny(list)
	if type(list) ~= "table" then return false end
	for _, names in pairs(list) do
		if type(names) == "table" and names[1] ~= nil then return true end
	end
	return false
end

-- "driver", "rider" or nil (driver wins when a name is on both lists).
function W.PioneerKind(nameOrKey)
	local P = W.PIONEERS
	if type(P) ~= "table" then return nil end
	local hasD, hasR = pioneerAny(P.drivers), pioneerAny(P.riders)
	if not (hasD or hasR) then return nil end
	local k = W.Key and W.Key(nameOrKey)
	if not k then return nil end
	local me = W.myKey
	if not me and W.UnitName then me = W.Key(W.UnitName("player")) end
	local own = k == me
	local rs = W.Ruleset()
	if not own and rs == nil then return nil end
	if hasD and pioneerOn(P.drivers, k, rs, own) then return "driver" end
	if hasR and pioneerOn(P.riders, k, rs, own) then return "rider" end
	return nil
end

-- Whether the name is a Pioneer (kind "rider" or "driver": of that kind; a Pioneer Driver also
-- counts as a rider Pioneer only when his name is on the riders' list too).
function W.IsPioneer(nameOrKey, kind)
	if kind == nil then return W.PioneerKind(nameOrKey) ~= nil end
	local P = W.PIONEERS
	if type(P) ~= "table" or (kind ~= "rider" and kind ~= "driver") then return false end
	local list = kind == "driver" and P.drivers or P.riders
	if not pioneerAny(list) then return false end
	local k = W.Key and W.Key(nameOrKey)
	if not k then return false end
	local me = W.myKey
	if not me and W.UnitName then me = W.Key(W.UnitName("player")) end
	local rs = W.Ruleset()
	if k ~= me and rs == nil then return false end
	return pioneerOn(list, k, rs, k == me)
end

-- The credits: this ruleset's Pioneers as short names, sorted, each once; a name on both lists
-- is a driver. { riders = {}, drivers = {} } when the lists are empty.
function W.PioneerNames()
	local out = { riders = {}, drivers = {} }
	local P = W.PIONEERS
	local rs = W.Ruleset()
	if type(P) ~= "table" or rs == nil then return out end
	local seen, keys = {}, {}
	for _, kind in ipairs({ "drivers", "riders" }) do
		local names = type(P[kind]) == "table" and P[kind][rs]
		if type(names) == "table" then
			for _, n in ipairs(names) do
				local k = W.Key(n)
				if k and not keys[k] then
					keys[k] = true
					local s = W.Short(n)
					local sk = kind .. "|" .. s:lower()
					if not seen[sk] then
						seen[sk] = true
						local t = out[kind]
						t[#t + 1] = s
					end
				end
			end
		end
	end
	table.sort(out.riders, function(a, b) return a:lower() < b:lower() end)
	table.sort(out.drivers, function(a, b) return a:lower() < b:lower() end)
	return out
end

---------------------------------------------------------------------------
-- Values the client may keep secret
---------------------------------------------------------------------------
-- Asked before anything else is done with a value: even comparing a secret is an error.

local function secret(v)
	if not issecretvalue then return false end
	local ok, is = pcall(issecretvalue, v)
	return not ok or is == true
end

function W.Plain(v)
	if secret(v) then return nil end
	return v
end

function W.Str(v)
	v = W.Plain(v)
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

function W.Num(v)
	v = W.Plain(v)
	if type(v) == "number" and v == v then return v end
	return nil
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------

W.DEFAULTS = {
	-- buyer
	minimapAngle = 215,
	minimapHidden = false,
	pos = nil,              -- the window's place: { point, relPoint, x, y }
	scale = nil,            -- nil: fits the screen (W.AutoScale)
	sound = true,
	mapPins = true,         -- drivers on the world map
	lastDest = nil,         -- the destination picked last time
	rides = {},             -- the rider's trip history, newest last, at most 100 (W.AddTrip)
	chars = {},             -- per character (W.Char()): driver settings
	-- round two (every change fires "SETTINGS" with the key)
	fx = "full",            -- effects: "full", "light" or "off"
	plates = true,          -- crowns and badges over heads (nameplates)
	timeValue = 100000,     -- "My time is worth": copper per hour (10g/h; slider 1g..100g)
	favs = {},              -- favourite drivers: favs[driverKey] = true (W.ToggleFav)
	watch = {},             -- "tell me when a driver to X comes online": watch[destKey] = true
	hidden = {},            -- hidden drivers: hidden[driverKey] = true (W.HideDriver)
	milestones = {},        -- earned milestones: milestones[id] = time() (W.CheckMilestones)
	toastAt = {},           -- toast rate limits: toastAt[what] = time() of the last one
	coach = false,          -- true once the first-open coach marks were seen or skipped
	autoAccept = true,      -- accept the booked driver's group invite for you (W.Try "accept")
	autoLeave = true,       -- leave the driver's group 3 s after a paid ride
	blockedBuild = {},      -- what the game refused, per client build: [build][cap] = true (W.Try)
	totals = nil,           -- lifetime trip totals (W.AddTrip; built from rides on first load)
	-- adverts in public chat (driver)
	advertOnline = true,    -- GO ONLINE also posts one advert line (W.AdvertPlan), by the same click
	advertAt = nil,         -- time() of our last advert (at most one per W.ADVERT_GAP)
	directory = {},         -- founder clients: drivers confirmed directly, [key] = { name, lastSeen, dest, ruleset }
	ruleset = nil,          -- the ruleset at the last login (tools/build-seeds.js reads it)
	openMapHint = false,    -- true once Home showed the "Get OpenMap" hint (shown once, never with OpenMap)
	tipsOn = true,          -- login tips (UI.Tips): one tip card on the first open after a login
	tipsSeen = {},          -- the login tips already shown: tipsSeen[id] = true
	reduceMotion = false,   -- "Reduce motion": pages and sheets fade in place, nothing travels (T.ReduceMotion)
	advanced = nil,         -- Simple or Advanced (W.Advanced): W.InitDB makes it false the first time; never filled from here
	groupFinder = false,    -- the Group Finder preview (draft, Net.GroupFinder): off by default; on, Wuber may search and delist from clicks
	simpleNote = nil,       -- true while a player whose saved data is older than Simple mode has not been told yet
}

-- Driver mode settings belong to one character (logging in on another Warlock must not
-- put it online by itself).
W.CHAR_DEFAULTS = {
	drive = false,          -- online as a driver
	price = 5000,           -- copper
	service = "",           -- the name riders see; "" = the character's name
	team = 1,               -- Warlocks summoning together (1..3); riders bring 3 - team helpers
	badge = "",             -- the driver's badge (an id from W.BADGES), beaconed; "" none
	starter = true,         -- "List me in Wuber's starter list": false is sent as D's last field "0"
	-- 2.0: the built-in driver engine (W.Drive, Drive_*.lua). team above is no
	-- longer read (the beacon's team is counted from the crew in the group).
	paused = false,         -- no new invites; rides under way carry on
	dest = "",              -- where I summon to, typed by hand ("" = where I stand)
	destWords = "",         -- more names riders use for it ("Also called")
	caster = "",            -- the main caster's name ("" = whoever clicks)
	crew = {},              -- { { name = "Farra Way", role = "lock"|"helper", app = true|false } }
	captain = "",           -- "" = I am the captain (or solo); else the captain's name
	wizard = false,         -- the crew wizard was finished once
	alertWindow = false,    -- true: first crew hello accepted only from own driver (Drive.Bell)
	queue = nil,            -- { at = time(), list = {...} }: the queue saved on PLAYER_LOGOUT
	ruleset = nil,          -- the ruleset the game last named for this character (W.Ruleset; used only with no realm name)
	rank = nil,             -- { n = verified summons, seen = { [riderKey] = day } }: made by Drive.Rank on first use
}

local function fill(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			if type(v) == "table" then
				local copy = {}
				for kk, vv in pairs(v) do copy[kk] = vv end
				db[k] = copy
			else
				db[k] = v
			end
		end
	end
end

local FX_LEVELS = { full = true, light = true, off = true }

function W.InitDB()
	if type(WuberDB) ~= "table" then WuberDB = {} end
	local db = WuberDB
	local had = next(db) ~= nil -- saved data from before this load
	fill(db, W.DEFAULTS)
	for _, k in ipairs({ "chars", "rides", "favs", "watch", "hidden", "milestones", "toastAt", "blockedBuild", "directory", "tipsSeen" }) do
		if type(db[k]) ~= "table" then db[k] = {} end
	end
	if type(db.advertOnline) ~= "boolean" then db.advertOnline = true end
	if not FX_LEVELS[db.fx] then db.fx = "full" end
	if type(db.plates) ~= "boolean" then db.plates = true end
	if type(db.coach) ~= "boolean" then db.coach = false end
	if type(db.tipsOn) ~= "boolean" then db.tipsOn = true end
	if type(db.autoAccept) ~= "boolean" then db.autoAccept = true end
	if type(db.autoLeave) ~= "boolean" then db.autoLeave = true end
	-- Simple or Advanced: everyone starts in Simple with this version. A player whose saved data is from
	-- before is told once (db.simpleNote: the UI shows the line and clears it). No other value changes.
	if type(db.advanced) ~= "boolean" then
		db.advanced = false
		if had then db.simpleNote = true end
	end
	local tv = tonumber(db.timeValue)
	if not tv or tv ~= tv then tv = 100000 end
	db.timeValue = math.max(10000, math.min(1000000, math.floor(tv + 0.5)))
	W.db = db
	-- first load with this version: lifetime totals from the saved trips, and the
	-- milestones those trips already earned, marked without any celebration
	if not db.progressReady then
		db.progressReady = true
		if type(db.totals) ~= "table" then W.RebuildTotals() end
		if W.CheckMilestones then W.CheckMilestones(true) end
	elseif type(db.totals) ~= "table" then
		W.RebuildTotals()
	elseif not db.totals.paidOnly and #db.rides < 100 then
		-- totals from an older version counted unpaid rides; every trip is still saved (fewer than 100), so count again
		if db.totalsOld == nil then db.totalsOld = db.totals end -- kept so the owner can restore the old counts in one line
		W.RebuildTotals()
	end
	return db
end

-- Simple or Advanced (2.4). Simple shows what one ride or one summon needs on a normal day; Advanced also
-- shows the tuning, statistics, crews, raids and extra facts. One saved switch (db.advanced). Switching it
-- changes no other saved value, ends no ride and closes no driver: the UI only asks W.Advanced() when it
-- draws a power-user control, and draws again on SETTINGS "advanced".
function W.Advanced()
	local db = W.db
	return type(db) == "table" and db.advanced == true
end

function W.SetAdvanced(on)
	local db = W.db or W.InitDB()
	on = on and true or false
	if db.advanced == on then return end
	db.advanced = on
	if W.Fire then W.Fire("SETTINGS", "advanced") end
end

-- This character's driver settings (W.CHAR_DEFAULTS), created on first use.
function W.Char()
	local db = W.db or W.InitDB()
	local key = W.myKey
	if (not key or key == "?") and W.UnitName then
		-- the name was unknown at login: ask again, so the saved entry is found
		local me = W.UnitName("player")
		key = me and W.Key(me) or nil
		if key then W.myName, W.myKey = me, key end
	end
	if not key or key == "?" then
		-- still unknown: settings for now, but no "?" entry is saved
		local tmp = {}
		fill(tmp, W.CHAR_DEFAULTS)
		return tmp
	end
	local c = db.chars[key]
	if type(c) ~= "table" then
		c = {}
		db.chars[key] = c
	end
	fill(c, W.CHAR_DEFAULTS)
	return c
end
