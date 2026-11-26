-- Module: Drive.Team
-- Purpose: Crew windows on the WUBERT prefix (was Drive_Team.lua).
-- API: W.Drive, DR.TPREFIX, DR.TPROTO, DR.comm, DR.offers, DR.pendingOffers, DR.FlushComm,
--   DR.CommBacklog, DR.Send, DR.Whisper, DR.Do, DR.Hello, DR.SyncStates, DR.StationsWire,
--   DR.SendConfig, DR.SendService, DR.SendBlocklist, DR.SendCrew, DR.CrewList, DR.SyncAnswerer,
--   DR.SyncOut, DR.SyncNow, DR.OfferCrew, DR.AnswerOffer, DR.RemoveCrew, DR.LeaveCrew, DR.OnTeamAddon,
--   DR.OfferTick, DR.StartTeam, DR.SendState, DR.SendBulk, DR.KeepOwnConfig, DR.RestoreOwnConfig (a crew member's
--   own price, typed place, largest group, kick and whisper mode: kept aside in W.Char().crewOwn while the captain's
--   CFG rules, put back once on every way out of the crew)
-- Internals: (none)
-- Uses: (none)
-- Later: Drive.AutoReply (DR.ReplyHeard for RPL: an asker a crew window whispered), Drive.Danger (DR.DangerWire for HI field 11, DR.DangerHeard), Drive.Raincheck (DR.RaincheckSync
--   when a window joins), Drive.Raid (DR.RaidSync: the raid rows to a window that joins or reloads, and back to
--   an order keeper that reloads)
-- Events: listens On CHAT_MSG_ADDON, login; fires DRIVE_CREW, DRIVE_OFFER, DRIVE_RAID, DRIVE_REMOVED,
--   DRIVE_STATIONS
-- Standalone: no
-- Test: tests/drive/team_test.lua
-- From: Drive_Team.lua 1-672 (Wuber 2.2.1)
--
-- Drive_Team: the crew's windows talk on the addon prefix WUBERT (Ritual Rides' Comm.lua).
--
-- Group facts (PARTY / RAID): `KIND~1~field~...`. A fact is something one window saw ("I
-- began the summon for Dan", "Dan paid 5g"); every window runs the same reducer over the same
-- facts (DR.Apply, Drive_Queue.lua), so all show the same queue.
--   HI  version, shards (-1), leader 0/1, needSync 0/1, ritual cooldown s, role L/H, class
--   CFG open, price, maxGroup, kick, whisperMode, dest    PAU 0/1
--   SVC service, keywords, caster|-     TPL kind, text
--   ASK ADD DROP GR THX HELP CAST name   END name, ok   PAID name, copper, m
--   ST name, state, caster, paid, cashier, flags, station, price, rideId (2.3.0)
--   BLK key, reason, date   UBL key
--   IOU op i|a|u|v, id, riderKey, cover, expires, rideId (2.3.0, the raincheck book)
--   HI also: place, map, mode, danger "level:seconds:zone" (2.3.0)
--   CRW name:L,name:H,name:P,...  (the captain's crew list; P = an "Add anyway" helper
--       without Wuber: never a rider, never trusted, never asked)
-- Whispers: TO service (crew offer), TY, TN, TL (left / removed); BH, BE belong to Drive_Bell.
--
-- Who is believed: who is speaking is always the event's sender, resolved against the group
-- roster (never a name in the payload). Group facts count only from a sender in my group AND
-- in my crew; CFG/PAU/SVC/TPL only from the group leader or the captain; HI from any group
-- member (to learn they run Wuber). Own token bucket: burst 8, +1/s, retry on 3; an answer of 11
-- (the game's chat lock, a boss fight) holds both lanes for 2 s and tries again, as Net.Transport does.
-- Two lanes: everything goes out before the bulk of a sync (the blocklist and the messages,
-- BULK_MAX at most, the oldest dropped first), so a rider's PAID, CAST, END or ST never waits
-- behind (or is dropped for) a sync. Nothing but bulk is ever dropped.

local _, W = ...
local Mod = W.Module("Drive.Team", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, str = W.Plain, W.Str

DR.TPREFIX = "WUBERT"
DR.TPROTO = 1
DR.comm = DR.comm or { sent = 0, failed = 0, heard = 0 }
DR.offers = DR.offers or {}          -- captain side: [key] = { name, at, state }
DR.pendingOffers = DR.pendingOffers or {} -- member side: [key] = { name, service, at }

local outbox = {} -- facts, config and whispers: in order, never dropped
local bulk = {}   -- a sync's blocklist and messages: after the outbox, capped
local tokens, lastFill = 8, 0
local MAX_BYTES = 250
local BULK_MAX = 50
-- The game's chat lock (a raid or boss fight) refuses every addon message with 11: "later", never a failure.
-- Both lanes are held (nothing counted, nothing dropped, the budget stays) and tried again, as in Net.Transport.
local CHAT_LOCKED = 11
local holdUntil = 0

local function groupChannel()
	if DR.InRaid and DR.InRaid() then return "RAID" end
	if W.InGroup() then return "PARTY" end
	return nil
end

-- true when dealt with (sent or not sendable), false to try again later
local function transmit(item)
	local ch, target = item.ch, item.target
	if ch ~= "WHISPER" then
		ch = groupChannel()
		if not ch then return true end
	end
	local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
	if type(send) ~= "function" then return true end
	local ok, result = W.Try("comm", send, DR.TPREFIX, item.text, ch, target)
	if not ok then
		DR.comm.failed = DR.comm.failed + 1
		return true
	end
	result = plain(result)
	DR.comm.last = result
	if result == CHAT_LOCKED then
		holdUntil = GetTime() + 2
		return false
	end
	if result == 3 then return false end
	if result == nil or result == 0 or result == true then
		DR.comm.sent = DR.comm.sent + 1
	else
		DR.comm.failed = DR.comm.failed + 1
	end
	return true
end

function DR.FlushComm()
	local now = GetTime()
	if now - lastFill >= 1 then
		tokens = math.min(8, tokens + math.floor(now - lastFill))
		lastFill = now
	end
	if now < holdUntil then return end -- (the chat lock: asked again by the next tick)
	while tokens > 0 and (#outbox > 0 or #bulk > 0) do
		local lane = #outbox > 0 and outbox or bulk
		if not transmit(lane[1]) then
			if GetTime() < holdUntil then return end -- (locked: the budget stays)
			tokens = 0
			return
		end
		table.remove(lane, 1)
		tokens = tokens - 1
	end
end

-- (tests) how many items wait in each lane
function DR.CommBacklog() return #outbox, #bulk end

local function pack(kind, ...)
	local n = select("#", ...)
	local parts = { kind, tostring(DR.TPROTO) }
	for i = 1, n do
		local v = select(i, ...)
		parts[#parts + 1] = W.Clean(v == nil and "" or tostring(v), MAX_BYTES)
	end
	while #parts > 2 and parts[#parts] == "" do parts[#parts] = nil end
	local text = table.concat(parts, "~")
	if #text > MAX_BYTES then
		-- cut, never through a UTF-8 letter (W.Clean would turn the ~ separators into spaces)
		local cut = MAX_BYTES
		while cut > 0 do
			local b = text:byte(cut + 1)
			if not b or b < 128 or b >= 192 then break end
			cut = cut - 1
		end
		text = text:sub(1, cut)
	end
	return text
end

-- Kinds whose newer message makes a queued older one stale: it is replaced in place.
local LATEST = { HI = true, CFG = true, SVC = true, PAU = true, CRW = true }

local function queue(item)
	local kind = item.ch ~= "WHISPER" and item.text:match("^([^~]*)") or nil
	if kind and LATEST[kind] then
		for i, old in ipairs(outbox) do
			if old.ch ~= "WHISPER" and old.text:match("^([^~]*)") == kind then
				outbox[i] = item
				DR.FlushComm()
				return
			end
		end
	elseif kind == "ST" then
		local who = item.text:match("^ST~%d+~([^~]*)")
		for i, old in ipairs(outbox) do
			if old.ch ~= "WHISPER" and old.text:match("^ST~%d+~([^~]*)") == who then
				outbox[i] = item
				DR.FlushComm()
				return
			end
		end
	end
	outbox[#outbox + 1] = item
	DR.FlushComm()
end

-- Bulk (a sync): the same text queued once; over BULK_MAX the oldest bulk item goes (never a BLK or TPL).
local function queueBulk(item)
	for _, old in ipairs(bulk) do
		if old.text == item.text then return end
	end
	if #bulk >= BULK_MAX then
		-- (r52 #6) the blocklist (BLK) and the messages (TPL) are never the ones dropped: the oldest of the
		-- rest (IOUs, raids, states: the next sync sends them again) goes; a lane of nothing else drops
		-- the newcomer, unless that is a BLK or TPL (then the oldest BLK or TPL goes; the lane never passes BULK_MAX)
		local function keep(it) local k = it.text:sub(1, 4) return k == "BLK~" or k == "TPL~" end
		local at
		for i, it in ipairs(bulk) do
			if not keep(it) then at = i break end
		end
		if at then table.remove(bulk, at)
		elseif keep(item) then table.remove(bulk, 1) -- a lane of only BLK/TPL: the oldest of those goes, 50 is a cap
		else return end
	end
	bulk[#bulk + 1] = item
	DR.FlushComm()
end

-- A group fact to the crew windows (nothing out of a group).
function DR.Send(kind, ...)
	if not DR.on or not groupChannel() then return end
	queue({ text = pack(kind, ...) })
end

local function sendBulk(kind, ...)
	if not DR.on or not groupChannel() then return end
	queueBulk({ text = pack(kind, ...) })
end

-- A group fact on the low-priority bulk lane (a sync, e.g. the raincheck book to a window that joins).
function DR.SendBulk(kind, ...) sendBulk(kind, ...) end

-- One WUBERT addon whisper (crew offers, the alert character).
function DR.Whisper(target, kind, ...)
	if DR.Lock and DR.Lock() == "rr" then return end
	target = str(target)
	if not target then return end
	queue({ text = pack(kind, ...), ch = "WHISPER", target = target })
end

-- A fact of my own: applied here, then told to the others (as text, so this window reads
-- exactly what the others read).
local function field(v)
	if v == nil then return nil end
	return W.Clean(tostring(v), MAX_BYTES)
end

function DR.Do(kind, a, b, c, d, e, f, g)
	a, b, c, d, e, f, g = field(a), field(b), field(c), field(d), field(e), field(f), field(g)
	if DR.Apply then DR.Apply(kind, W.myKey, a, b, c, d, e, f, g) end
	DR.Send(kind, a, b, c, d, e, f, g)
end

---------------------------------------------------------------------------
-- Who is here
---------------------------------------------------------------------------

function DR.Hello(needSync)
	DR.lastHi = GetTime()
	local lock = DR.IsWarlock and DR.IsWarlock()
	local cd = (lock and DR.RitualCooldown) and DR.RitualCooldown() or 0
	DR.lastCd = cd > 0
	local shards = lock and DR.Shards and DR.Shards() or nil
	-- 2.1: where I stand (stations) and "R" (the runner) / "r" (a summoner) while raid summons run
	local place, map
	if DR.PlaceOf then place, map = DR.PlaceOf("player") end
	local mode = ""
	-- (review 2.2 #9: paused raid summons don't advertise themselves)
	if DR.RaidOn and DR.RaidOn() and not (DR.IsPaused and DR.IsPaused()) then mode = DR.char().captain == "" and "R" or "r" end
	-- 2.3.0 (SPEC7 5.6): field 11, my PvP danger "level:seconds:zone" (only when there is some)
	DR.Send("HI", W.VERSION, shards or -1, DR.IsLeader() and 1 or 0, needSync and 1 or 0, math.ceil(cd),
		lock and "L" or "H", (DR.Class and DR.Class()) or "", place or "", map or "", mode,
		DR.DangerWire and DR.DangerWire() or "")
end

-- Where every rider in the group stands.
function DR.SyncStates()
	for _, c in pairs(DR.customers) do
		if DR.Rank(c.state) >= DR.Rank("joined") then
			local flags = (c.greeted and "g" or "") .. (c.thanked and "t" or "") .. (c.reminded and "r" or "") .. ((c.tries or 0) > 0 and "s" or "")
			DR.SendState(c, flags)
		end
	end
end

-- One rider's ST. 2.3.0 (SPEC7 5.7, 5.8): field 9 the Wuber ride id; flag v = the fare a raincheck
-- lowered (any amount, even under the minimum); flag n = a 2.3.0 app rider (paid before arriving:
-- still summoned, see DR.Apply's PAID). Field 9 and flag n only for a 2.3.0 rider (or a raincheck):
-- for older riders the ST is the 2.2 one, byte for byte.
function DR.SendState(c, flags)
	flags = flags or ((c.greeted and "g" or "") .. (c.thanked and "t" or "") .. (c.reminded and "r" or "") .. ((c.tries or 0) > 0 and "s" or ""))
	if c.voucher then flags = flags .. "v" end
	local new = W.VerAtLeast and W.VerAtLeast(c.wuberVer, "2.3.0")
	if new then flags = flags .. "n" end
	if new or c.voucher then
		DR.Send("ST", c.name, c.state, c.caster or "", c.paid or 0, c.cashier or "", flags, c.station or "", c.price or "",
			c.wuberRide or c.rideId or "")
	else
		-- a rider before 2.3.0: the 2.2 ST, exactly (no passphrase, no raincheck for them)
		DR.Send("ST", c.name, c.state, c.caster or "", c.paid or 0, c.cashier or "", flags, c.station or "", c.price or "")
	end
end

-- The stations switched on and off: "Undercity:1,Orgrimmar:0" (the runner's list).
function DR.StationsWire()
	local parts = {}
	local seen = {}
	for _, st in ipairs(DR.Stations and DR.Stations() or {}) do
		local name = st.place:gsub("[,:~]", "")
		seen[W.NormPlace(name)] = true
		parts[#parts + 1] = name .. ":" .. (st.open and "1" or "0")
	end
	local ch = DR.char()
	for place, on in pairs(ch.captain == "" and ch.stations or DR.crewStations or {}) do
		local name = tostring(place):gsub("[,:~]", "")
		if on == false and not seen[W.NormPlace(name)] and #parts < 8 then parts[#parts + 1] = name .. ":0" end
	end
	return table.concat(parts, ",")
end

-- CFG: open (selling), price, maxGroup, kick, whisperMode, dest; 2.1: stations, mode, raid running;
-- round 9: field 12 "1" = riders see the ride passphrase (DR.PassWire; "" when off, so the CFG is as before)
function DR.SendConfig()
	local ch, o = DR.char(), DR.opts()
	-- a helper who leads after the captain left answers with the crew's copy (DR.Selling/Mode/RaidOn follow the CFG)
	local selling = DR.Selling()
	local raid = DR.Mode() == "raid"
	DR.Send("CFG", selling and 1 or 0, ch.price, DR.MaxGroup(), o.kickAfter and 1 or 0, o.whisperMode, ch.dest or "",
		DR.StationsWire(), raid and "raid" or "sell", DR.RaidOn() and 1 or 0,
		o.raidsum == false and 0 or 1, o.raidclick == false and 0 or 1, DR.PassWire and DR.PassWire() or "")
end

-- SVC: service, keywords, caster or -; 2.1: the summoners in cast order (full names)
function DR.SendService()
	local ch, o = DR.char(), DR.opts()
	local caster = ch.caster or ""
	local chosen = DR.Summoners and DR.Summoners() or {}
	if caster == "" then
		if chosen[1] then caster = DR.NameOf(chosen[1]) or "-"
		else caster = DR.IsWarlock() and (W.myName or "-") or "-" end
	end
	local names = {}
	for _, k in ipairs(chosen) do names[#names + 1] = (DR.NameOf(k) or k):gsub(",", "") end
	DR.Send("SVC", ch.service or "", table.concat(o.keywords or {}, " "), caster, table.concat(names, ","))
end

-- The whole blocked list, as bulk (after every fact, never ahead of one): 40 names per batch, one BLK
-- each (an older window reads each as before); the next batch goes once the bulk lane has drained (checked
-- every 2 s, for at most 3 minutes), so the lane never overflows and drops a name. A newer call (a second
-- window asking for the sync) takes over from an older run, so two runs never fill the lane together.
local blockRun = 0
local function sendBlockBatch(keys, from, waited, run)
	if not DR.on or run ~= blockRun then return end
	local backlog = 0
	if from > 1 and DR.CommBacklog then local _, nb = DR.CommBacklog() backlog = nb or 0 end
	if backlog > 0 and (waited or 0) < 90 then
		W.After(2, function() sendBlockBatch(keys, from, (waited or 0) + 1, run) end)
		return
	end
	local last = math.min(#keys, from + 39)
	for i = from, last do
		local e = DR.BlockEntry and DR.BlockEntry(keys[i])
		if e then sendBulk("BLK", keys[i], e.reason or "", e.at or "") end
	end
	if last < #keys then W.After(2, function() sendBlockBatch(keys, last + 1, 0, run) end) end
end

function DR.SendBlocklist()
	local keys = {}
	for k in pairs((DR.db or {}).blocklist or {}) do keys[#keys + 1] = k end
	table.sort(keys)
	blockRun = blockRun + 1
	sendBlockBatch(keys, 1, 0, blockRun)
end

-- The captain's crew list: the captain first, then up to 8 name:role pairs. Plain helpers ("Add
-- anyway", no Wuber) go as P, so no member window takes them for riders.
function DR.SendCrew()
	if not DR.IsCaptain() then return end
	local list = DR.CrewList()
	DR.Send("CRW", list)
	return list
end

function DR.CrewList()
	local pairsOut = { W.Clean((W.myName or W.Me()):gsub("[,:]", ""), 48) .. ":" .. ((DR.IsWarlock and DR.IsWarlock()) and "L" or "H") }
	for _, m in ipairs(DR.char().crew) do
		if #pairsOut < 9 then
			-- P: a helper without Wuber; S: a summoner without Wuber (2.1)
			local role = (m.app == false and (m.role == "lock" and "S" or "P")) or (m.role == "lock" and "L") or "H"
			pairsOut[#pairsOut + 1] = W.Clean(tostring(m.name):gsub("[,:]", ""), 48) .. ":" .. role
		end
	end
	return table.concat(pairsOut, ",")
end

-- Which window answers a crew window's "I need a sync": the captain when it is in my group,
-- else the leader. One answer, not two floods.
function DR.SyncAnswerer()
	if DR.IsCaptain() then return true end
	local cap = DR.CaptainKey()
	if cap and DR.units[cap] then return false end
	return DR.IsLeader()
end

-- Everything a window that just arrived (or reloaded) needs. Several windows arriving at
-- once get one sync.
local syncDue = false
function DR.SyncOut()
	if syncDue then return end
	syncDue = true
	W.After(0.5, function()
		syncDue = false
		DR.SyncNow()
	end)
end

function DR.SyncNow()
	DR.SendConfig()
	DR.SendService()
	-- (SPEC5 roles, review #17: a reloading captain who doesn't lead never sends its stale pause
	-- over the leading Warlock's)
	local leaderKey = DR.LeaderOf and DR.LeaderOf()
	local lockLeads = leaderKey and leaderKey ~= W.myKey and DR.peers[leaderKey] and DR.peers[leaderKey].role == "L"
	if DR.IsLeader() or not lockLeads then DR.Send("PAU", DR.IsPaused and DR.IsPaused() and 1 or 0) end
	if DR.IsCaptain() and #DR.char().crew > 0 then DR.SendCrew() end
	DR.SendBlocklist()
	local d = DR.db
	local order = DR.TEMPLATE_ORDER or { "advert", "greet", "price", "offer", "pay", "thanks", "tip", "short", "busy", "refuse" }
	for _, kind in ipairs(order) do
		local text = d and d.templates[kind]
		if type(text) == "string" and text ~= "" then sendBulk("TPL", kind, text) end
	end
	DR.SyncStates()
	if DR.RaincheckSync then DR.RaincheckSync() end
	-- (AU24-04) the raid queue, from the window that keeps its order
	if DR.RaidSync then DR.RaidSync() end
end

-- (AUD-76) the last window heard running raid summons (HI "R"): a raider's own window forgets its
-- mirrored queue when that runner's CFG says raid summons stopped (a pause keeps the queue)
local raidRunner = nil

local function heardHello(key, name, p)
	local was = DR.apps[key]
	local map = W.Int(p[11])
	DR.apps[key] = { name = name, version = p[3] or "?", role = p[8], class = p[9], at = GetTime(),
		place = (p[10] and p[10] ~= "") and W.Clean(p[10], 32) or nil, map = (map and map > 0) and map or nil,
		mode = (p[12] == "R" or p[12] == "r") and p[12] or nil, shards = W.Int(p[4]) }
	if (was and was.mode) ~= DR.apps[key].mode then W.Fire("DRIVE_RAID") end
	if DR.apps[key].mode == "R" then raidRunner = key end
	if not DR.TrustKey(key) then return end
	local known = DR.peers[key] ~= nil
	local wantsSync = p[6] == "1"
	local shards = W.Int(p[4])
	if p[4] == "-1" then shards = -1 end
	local cd = W.Int(p[7]) or 0
	local oldPeer = DR.peers[key]
	DR.peers[key] = {
		name = name, version = p[3] or "?", shards = shards or -1, leader = p[5] == "1", at = GetTime(),
		cdUntil = GetTime() + math.min(cd, 7200), role = (p[8] == "L" or p[8] == "H") and p[8] or nil,
		class = p[9], place = DR.apps[key].place, map = DR.apps[key].map,
	}
	if DR.DangerHeard then DR.DangerHeard(key, p[13]) end
	if oldPeer and (oldPeer.place ~= DR.peers[key].place or oldPeer.map ~= DR.peers[key].map) then
		W.Fire("DRIVE_STATIONS")
	end
	local m = DR.CrewEntry(key)
	local roleWas = m and m.role
	if m and p[8] == "L" and m.role ~= "lock" then m.role = "lock" end
	if m and p[8] == "H" and m.role ~= "helper" then m.role = "helper" end
	-- (SPEC5 roles, review #17: a member's role learned late - an offer taken out of the group -
	-- reaches the other windows at once)
	if m and m.role ~= roleWas and DR.IsCaptain() then DR.SendCrew() end
	-- a crew member is never a customer
	local c = DR.customers[key]
	if c then
		DR.customers[key] = nil
		W.Fire("DRIVE_REMOVED", c, "crew")
	end
	if (not known or wantsSync) and GetTime() - (DR.lastHi or -100) >= 2 then DR.Hello() end
	if not known and p[3] and p[3] ~= W.VERSION and not DR.versionHint then
		DR.versionHint = true
		W.Print(W.Short(name) .. " runs Wuber " .. p[3] .. ", this window " .. W.VERSION .. " - update the older one.")
	end
	if wantsSync then
		if DR.SyncAnswerer() then
			DR.SyncOut()
		elseif p[5] == "1" then
			DR.SyncStates()
		end
		-- (AU24-05) the raid queue's order keeper reloaded: the rows this window holds go back to it
		if DR.RaidSync then DR.RaidSync(key) end
	end
	W.Fire("DRIVE_CREW")
	DR.Changed()
end

---------------------------------------------------------------------------
-- Crew offers (consent per member)
---------------------------------------------------------------------------

local OFFER_TTL = 300 -- a TY counts only for an offer made in the last 5 minutes
local OFFER_SHOWN = 60 -- one offer card per sender per minute
local NOAPP_AFTER = 20

local function isContact(k)
	if type(W.Contacts) ~= "function" then return false end
	local ok, list = pcall(W.Contacts)
	if not ok or type(list) ~= "table" then return false end
	for _, e in ipairs(list) do
		if type(e) == "table" and e.key == k then return true end
	end
	return false
end

-- The captain asks one player to join the crew (one name per tap). `kind` "raid": a raid
-- summoner pick (SPEC4 3.1; the card reads "Summon for X's raid?"), who then summons; one already
-- in my crew gets no card and summons at once (returns true, "crew").
-- Can this be a character's name? One word of letters only, or "First Surname" (two such words, one space),
-- 2 to 12 letters each (accented Latin letters count as one), then an optional -Realm of letters. Nothing is sent for anything else.
local function letters(s)
	if s:find("[^%a\128-\255]") then return nil end
	local n = 0
	for i = 1, #s do
		local b = s:byte(i)
		if b < 128 or b >= 192 then n = n + 1 end
	end
	return n
end

function DR.ValidName(name, loose)
	name = tostring(name or "")
	-- (strict) the text as typed: no space at either end, no double space (W.Clean would quietly tidy them away)
	if not loose and (name:find("^%s") or name:find("%s$") or name:find("%s%s")) then return false end
	name = W.Clean(name, 48)
	if loose then
		-- what the game's own fakes and old saved names may hold: words of letters, a space between
		for word in (name .. " "):gmatch("(%S*) ") do
			local n = letters((word:gsub("%-", "")))
			if not n or n < 2 or n > 24 then return false end
		end
		return name ~= ""
	end
	local who, realm = name:match("^([^%-]+)%-([^%-]+)$")
	if not who then who = name end
	-- WoW Forever names are "First Surname": one word, or two words with one plain space between them
	local first, second = who:match("^(%S+) (%S+)$")
	for _, word in ipairs(first and { first, second } or { who }) do
		local n = letters(word)
		if not n or n < 2 or n > 12 then return false end
	end
	if realm then
		local r = letters((realm:gsub("'", ""))) -- a realm name may hold an apostrophe
		if not r or r < 2 or r > 24 then return false end
	end
	return true
end

function DR.OfferCrew(name, kind)
	name = W.Clean(name, 48)
	local k = W.Key(name)
	if not k or k == W.myKey then return false, "name" end
	if not DR.ValidName(name, true) then return false, "badname" end
	if not DR.IsCaptain() then return false, "member" end
	-- a raid pick of a Warlock already in my crew: his window drops a card from its own captain
	-- (heardWhisper TO), so he joins the summoners at once
	local m = kind == "raid" and DR.CrewEntry(k)
	if m and DR.AddSummoner then
		DR.offers[k] = nil
		return DR.AddSummoner(m.name or name) ~= false, "crew"
	end
	local ch = DR.char()
	local service = (ch.service ~= "" and ch.service) or W.myName or ""
	if kind == "raid" then service = "raid" end
	DR.offers[k] = { name = name, at = GetTime(), state = "waiting", kind = kind == "raid" and "raid" or nil }
	DR.Whisper(name, "TO", service)
	W.Fire("DRIVE_CREW")
	DR.Changed()
	return true
end

-- Forget what the old captain's crew said (open, mode, run, stations, summoners).
local function forgetCrewState()
	DR.crewOpen, DR.crewMode, DR.crewRaidRun, DR.crewStations, DR.crewSummoners = nil, nil, nil, nil, nil
end

-- A crew member's own settings, which the captain's CFG overwrites (Drive.Queue applyConfig): kept aside, in the
-- character's saved settings so a reload inside a crew does not lose them, when the first CFG of a crew arrives.
-- "Largest group automatic" is 0 (or nothing) and comes back as that.
function DR.KeepOwnConfig()
	local ch = DR.char()
	if ch.captain == "" or type(ch.crewOwn) == "table" then return false end
	local opts = DR.opts()
	ch.crewOwn = { price = ch.price, dest = ch.dest, maxGroup = opts.maxGroup, kickAfter = opts.kickAfter,
		whisperMode = opts.whisperMode, service = ch.service, paused = ch.paused == true, caster = ch.caster }
	if type(opts.keywords) == "table" then
		ch.crewOwn.keywords = {}
		for i, w in ipairs(opts.keywords) do ch.crewOwn.keywords[i] = w end
	end
	return true
end

-- Every way out of a crew (left, removed, the crew ended, another crew joined) puts them back, once.
function DR.RestoreOwnConfig()
	local ch = DR.char()
	local own = ch.crewOwn
	ch.crewOwn = nil
	if type(own) ~= "table" then return false end
	local opts = DR.opts()
	local price = tonumber(own.price)
	if price and price == price then ch.price = math.max(W.MIN_PRICE or 5000, math.min(99999999, math.floor(price))) end
	ch.dest = type(own.dest) == "string" and W.Clean(own.dest, 32) or ""
	-- (a value that was not set comes back as not set: the setting's default)
	local mg = tonumber(own.maxGroup)
	if own.maxGroup == nil then opts.maxGroup = nil
	else opts.maxGroup = (mg and mg == mg and mg >= 3) and math.min(40, math.floor(mg)) or 0 end
	if type(own.kickAfter) == "boolean" then opts.kickAfter = own.kickAfter else opts.kickAfter = nil end
	local mode = own.whisperMode
	if mode == "auto" or mode == "macro" or mode == "box" or mode == "off" then opts.whisperMode = mode else opts.whisperMode = nil end
	-- (AU24-31) what the captain's SVC and PAU overwrote: service name, invite words, pause, who casts
	if type(own.service) == "string" then ch.service = own.service end
	if type(own.keywords) == "table" then
		local kw = {}
		for i, w in ipairs(own.keywords) do kw[i] = w end
		opts.keywords = kw
	end
	if own.paused ~= nil then ch.paused = own.paused == true end
	if type(own.caster) == "string" then ch.caster = own.caster end
	W.Fire("SETTINGS", "drive")
	return true
end

-- The invited side answers the card: Yes joins this captain's crew.
function DR.AnswerOffer(fromName, yes)
	local k = W.Key(fromName)
	if not k then return false end
	local p = DR.pendingOffers[k]
	local name = (p and p.name) or fromName
	DR.pendingOffers[k] = nil
	-- (SPEC5 roles: TY says what this window is, L or H, so a Warlock invited out of the group
	-- is a Warlock in the crew list at once)
	if yes then DR.Whisper(name, "TY", (DR.IsWarlock and DR.IsWarlock()) and "L" or "H") else DR.Whisper(name, "TN") end
	if yes then
		local ch = DR.char()
		-- leaving an earlier crew: the old captain (or, if I was a captain, my crew) is told with TL
		-- (the same message LeaveCrew sends; an old window treats it as that member leaving)
		if ch.captain ~= "" then
			if W.Key(ch.captain) ~= k then
				DR.Whisper(ch.captain, "TL")
				DR.peers[W.Key(ch.captain) or "?"] = nil
				DR.RestoreOwnConfig() -- (the new captain's CFG keeps my own values aside afresh)
			end
		else
			for _, m in ipairs(ch.crew) do
				if W.Key(m.name) ~= k and m.app ~= false then DR.Whisper(m.name, "TL") end
			end
		end
		for _, m in ipairs(ch.crew) do
			if W.Key(m.name) ~= k then DR.peers[W.Key(m.name) or "?"] = nil end
		end
		ch.crew = {}
		ch.captain = W.Clean(name, 48)
		ch.wizard = true
		DR.KeepOwnConfig() -- (before any CFG, SVC or PAU of the new captain can overwrite my own)
		forgetCrewState()
		-- the captain's crew list replaces mine once its CRW comes
		for i = #ch.crew, 1, -1 do
			if W.Key(ch.crew[i].name) == k then table.remove(ch.crew, i) end
		end
		DR.on = DR.on or (DR.Lock and DR.Lock() ~= "rr")
		if W.InGroup() then DR.Hello(true) end
	end
	W.Fire("DRIVE_CREW")
	DR.Changed()
	return true
end

-- The captain takes a member off the crew (they are told).
function DR.RemoveCrew(name)
	local k = W.Key(name)
	if not k then return false end
	local m = DR.CrewEntry(k)
	local who = m and m.name or name
	if DR.IsCaptain() then
		DR.DropCrewMember(k)
		DR.offers[k] = nil
		if not m or m.app ~= false then DR.Whisper(who, "TL") end
		DR.SendCrew()
		return true
	end
	-- a member edits only its own copy
	return DR.DropCrewMember(k)
end

-- Leave the crew I am in (a member), or break up mine (a captain).
function DR.LeaveCrew()
	local ch = DR.char()
	if ch.captain ~= "" then
		DR.Whisper(ch.captain, "TL")
		DR.peers[W.Key(ch.captain) or "?"] = nil
		ch.captain = ""
		DR.RestoreOwnConfig()
	else
		for _, m in ipairs(ch.crew) do
			if m.app ~= false then DR.Whisper(m.name, "TL") end
		end
	end
	for _, m in ipairs(ch.crew) do DR.peers[W.Key(m.name) or "?"] = nil end
	ch.crew = {}
	forgetCrewState()
	for k in pairs(DR.offers) do DR.offers[k] = nil end
	W.Fire("DRIVE_CREW")
	DR.Changed()
	return true
end

-- The captain's CRW: my crew is the list (without me).
local function applyCrew(list)
	local ch = DR.char()
	local crew = {}
	local seen = {}
	for pair in tostring(list or ""):gmatch("[^,]+") do
		local name, role = pair:match("^%s*(.-)%s*:%s*([LHPS])%s*$")
		local k = name and W.Key(name)
		if k and k ~= W.myKey and not seen[k] and #crew < 8 then
			seen[k] = true
			crew[#crew + 1] = { name = W.Clean(name, 48), role = (role == "L" or role == "S") and "lock" or "helper",
				app = role ~= "P" and role ~= "S" }
		end
	end
	ch.crew = crew
	-- a Warlock the captain removed who stays in the party is no longer a crew peer (her shards, her line)
	local capKey = ch.captain ~= "" and W.Key(ch.captain) or nil
	for k in pairs(DR.peers) do
		if not seen[k] and k ~= capKey then DR.peers[k] = nil end
	end
	for _, m in ipairs(crew) do
		local k = W.Key(m.name)
		local c = k and DR.customers[k]
		if c then
			DR.customers[k] = nil
			W.Fire("DRIVE_REMOVED", c, "crew")
		end
	end
	W.Fire("DRIVE_CREW")
	DR.Changed()
end

local function heardWhisper(kind, key, sender, p)
	-- round 9: the customer book (BKH, BKQ, BKR: Drive.Book checks it is my own crew)
	if DR.BookHeard and DR.BookHeard(kind, key, sender, p) then return end
	local now = GetTime()
	if kind == "TO" then
		if W.IsHidden and W.IsHidden(key) then return end
		if DR.db and DR.db.blocklist[key] then return end
		DR.offerShownAt = DR.offerShownAt or {}
		local shownAt = DR.offerShownAt[key]
		if shownAt and now - shownAt < OFFER_SHOWN then return end
		if DR.CaptainKey() == key and not DR.IsCaptain() then return end -- already in that crew
		DR.offerShownAt[key] = now
		local service = W.Clean(p[3] or "", 32)
		DR.pendingOffers[key] = { name = sender, service = service, at = now }
		W.Fire("DRIVE_OFFER", sender, service)
		return
	end
	if kind == "TY" or kind == "TN" then
		local o = DR.offers[key]
		if not o or now - o.at > OFFER_TTL or not DR.IsCaptain() then return end
		if kind == "TN" then
			o.state = "no"
		else
			local app = DR.apps[key]
			local class = (app and app.class) or (DR.UnitClassKey and DR.UnitClassKey(key))
			local role = (class == "WARLOCK" or (app and app.role == "L") or p[3] == "L") and "lock" or "helper"
			if not DR.SetCrewMember(o.name or sender, role, true) then
				-- the crew is full (8 beside the captain): she is not in the list, so tell her
				o.state = "no"
				DR.Whisper(sender, "TL")
				W.Fire("DRIVE_CREW")
				DR.Changed()
				return
			end
			o.state = "yes"
			-- a raid pick summons; so does a Warlock who joins a runner that is no Warlock
			if role == "lock" and DR.AddSummoner and (o.kind == "raid" or (DR.Role() == "driver" and not DR.IsWarlock())) then
				DR.AddSummoner(o.name or sender)
			end
			local list = DR.CrewList()
			DR.Send("CRW", list)
			for _, m in ipairs(DR.char().crew) do
				if m.app ~= false and not (DR.units[W.Key(m.name) or "?"]) then DR.Whisper(m.name, "CRW", list) end
			end
		end
		W.Fire("DRIVE_CREW")
		DR.Changed()
		return
	end
	if kind == "TL" then
		local ch = DR.char()
		if ch.captain ~= "" and W.Key(ch.captain) == key then
			-- my captain removed me
			ch.captain, ch.crew = "", {}
			DR.RestoreOwnConfig()
			forgetCrewState()
			DR.peers = DR.peers or {}
			for k in pairs(DR.peers) do DR.peers[k] = nil end
			W.Print("you are no longer in " .. W.Short(sender) .. "'s crew.")
		elseif DR.IsCaptain() and DR.CrewEntry(key) then
			DR.DropCrewMember(key)
			DR.offers[key] = nil
			DR.SendCrew()
		end
		W.Fire("DRIVE_CREW")
		DR.Changed()
		return
	end
	if kind == "CRW" then
		local ch = DR.char()
		if ch.captain ~= "" and W.Key(ch.captain) == key then applyCrew(p[3]) end
		return
	end
end

---------------------------------------------------------------------------
-- Hearing
---------------------------------------------------------------------------

local GROUP_KINDS = { CFG = true, PAU = true, SVC = true, TPL = true, ASK = true, ADD = true, DROP = true, GR = true,
	THX = true, HELP = true, CAST = true, ["END"] = true, PAID = true, ST = true, BLK = true, UBL = true,
	-- 2.1 raid summons: queue add, drop, move to top, channel started
	RA = true, RD = true, RT = true, CH = true,
	-- 2.3.0 raincheck book facts (SPEC7 5.8)
	IOU = true,
	-- (#72) a crew window whispered an asker (Drive.AutoReply): the one hour holds on every own window
	RPL = true }
local LEAD_KINDS = { CFG = true, PAU = true, SVC = true, TPL = true }

local function onAddon(prefix, text, ch, sender)
	prefix, text, ch, sender = plain(prefix), plain(text), plain(ch), plain(sender)
	if prefix ~= DR.TPREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
	if DR.Lock and DR.Lock() == "rr" then return end
	if #text > 255 then return end
	local p = W.Split(text)
	local kind = p[1]
	local v = W.Int(p[2])
	if not kind or not v or v > DR.TPROTO then return end
	for i = 3, #p do p[i] = W.Clean(p[i], MAX_BYTES) end
	if ch == "WHISPER" then
		local key = W.Key(sender)
		if not key or key == W.myKey then return end
		DR.comm.heard = DR.comm.heard + 1
		heardWhisper(kind, key, sender, p)
		return
	end
	if ch ~= "PARTY" and ch ~= "RAID" then return end
	if not DR.on then return end
	local key = DR.ResolveKey and DR.ResolveKey(sender) or W.Key(sender)
	if not key or key == W.myKey then return end
	if not DR.units[key] then
		if DR.SyncRoster then DR.SyncRoster() end
		if not DR.units[key] then return end -- not in my group
	end
	DR.comm.heard = DR.comm.heard + 1
	local name = W.UnitName(DR.units[key]) or sender
	if kind == "HI" then
		-- round 11: "a newer Wuber is out" (Net.Update), under the game's own sender key (not ResolveKey's match)
		if W.HeardVersion then W.Safe("version", W.HeardVersion, W.Key(sender), p[3]) end
		heardHello(key, name, p)
		return
	end
	if kind == "CRW" then
		local chr = DR.char()
		if chr.captain ~= "" and W.Key(chr.captain) == key then applyCrew(p[3]) end
		return
	end
	if kind == "RQ" or kind == "RN" then
		-- a raider's own "Request a summon" (or cancel): only ever about the sender
		if DR.RaidHeard then DR.RaidHeard(kind, key, name) end
		return
	end
	if not GROUP_KINDS[kind] then return end
	if not DR.TrustKey(key) then
		-- a raider's own window follows the raid queue of the raid's runner (display only)
		if DR.RaidMirror then DR.RaidMirror(kind, key, p[3], p[4], p[5]) end
		if kind == "CFG" and key == raidRunner and not (p[10] == "raid" and p[11] == "1") then
			raidRunner = nil
			if DR.raidRows and next(DR.raidRows) ~= nil and not (DR.RaidOn and DR.RaidOn()) then
				for rk in pairs(DR.raidRows) do DR.raidRows[rk] = nil end
				W.Fire("DRIVE_RAID")
				DR.Changed()
			end
		end
		return
	end
	if LEAD_KINDS[kind] and not (DR.IsLeaderKey(key) or DR.CaptainKey() == key) then
		-- a pause from a crew Warlock counts too (any window's Pause stops the invites, as in
		-- Ritual Rides); a helper can't pause, and nobody else changes price or messages
		local m = DR.CrewEntry(key)
		if not (kind == "PAU" and m and m.role == "lock" and m.app ~= false) then return end
	end
	if kind == "RPL" then
		if DR.ReplyHeard then DR.ReplyHeard(p[3]) end
		return
	end
	-- round 9: the captain's passphrase setting (CFG field 12) for this window (Drive.Net)
	if kind == "CFG" and DR.PassHeard then DR.PassHeard(key, p[14]) end
	if DR.Apply then DR.Apply(kind, key, p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13]) end
end

W.On("CHAT_MSG_ADDON", onAddon)

-- The game says nobody of that name is playing: a crew offer still waiting for that name is dropped.
W.On("CHAT_MSG_SYSTEM", function(text)
	local who = type(W.NotFoundName) == "function" and W.NotFoundName(text)
	local k = who and W.Key(who)
	local o = k and DR.offers[k]
	if not o or o.state ~= "waiting" then return end
	DR.offers[k] = nil
	W.Print("Nobody called " .. W.Short(o.name or who) .. " is online, so that crew offer is gone.")
	W.Fire("DRIVE_CREW")
	DR.Changed()
end)
DR.OnTeamAddon = onAddon -- tests

-- "No answer in 20 s and not a Wuber contact": the wizard offers "Add anyway".
function DR.OfferTick()
	local now = GetTime()
	for k, o in pairs(DR.offers) do
		if o.state == "waiting" and now - o.at > NOAPP_AFTER and not isContact(k) and not DR.apps[k] then
			o.state = "noapp"
			W.Fire("DRIVE_CREW")
			DR.Changed()
		elseif o.state == "waiting" and now - o.at > OFFER_TTL then
			-- a Yes would now be ignored (see OFFER_TTL): stop saying "Waiting for X to tap Yes"
			DR.offers[k] = nil
			W.Fire("DRIVE_CREW")
			DR.Changed()
		elseif now - o.at > OFFER_TTL * 4 and o.state ~= "waiting" then
			DR.offers[k] = nil
		end
	end
end

local registered = false
function DR.StartTeam()
	if registered then return end
	registered = true
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, DR.TPREFIX)
	end
end

-- The prefix is registered at login for every character (the alert character and helpers
-- hear offers and alerts too), unless an old Ritual Rides drives.
W.OnLogin(function()
	if DR.Lock and DR.Lock() == "rr" then return end
	DR.StartTeam()
	-- characters the engine doesn't run on still answer offers on a slow tick
	if not DR.on then
		W.Every(1, function()
			DR.FlushComm()
			DR.OfferTick()
		end)
	end
end)
