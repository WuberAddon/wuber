-- Module: Drive.Queue
-- Purpose: Riders and their states (was Drive_Queue.lua).
-- API: W.Drive, DR.customers, DR.units, DR.ignored, DR.helpers, DR.session, DR.requestFilters, DR.RANK,
--   DR.Rank, DR.LEAD_TTL, DR.QUEUE_TTL, DR.WAIT_TTL, DR.CAST_TTL, DR.AWAY_AFTER, DR.ResolveKey,
--   DR.Find, DR.CleanName, DR.Create, DR.SetState, DR.Remove, DR.Sorted, DR.Count, DR.Due,
--   DR.NeverRider, DR.WuberLine, DR.Classify, DR.Wanted, DR.ResetRide, DR.Lead, DR.Request, DR.Invite,
--   DR.ClickInvites (r30: whisper invites off, a queued rider's row click invites when the timer would),
--   DR.SetPriority, DR.MarkPaid, DR.NotRider, DR.Market, DR.PublicLine, DR.Busy, DR.LeaderOf,
--   DR.CanInvite, DR.LeadTarget, DR.HandLead, DR.LeadFix, DR.PumpInvites, DR.owing, DR.OWING_GRACE, DR.recentLeft, DR.LEFT_KEEP (riders who left in the last 120 s: a late PAID still counts),
--   DR.DecidesNonPayer, DR.OwingTick, DR.SyncRoster, DR.LockPrice, DR.Apply, DR.QueueTick,
--   DR.PLACE_SETTLE, DR.MOVED_TTL, DR.moved, DR.ServedPlaces, DR.PlaceOK, DR.PlaceStale, DR.PlaceSweep,
--   DR.Travelling (BRIEF18: a request's place; riders for a place the driver left), DR.AskedFor,
--   DR.AskOK (BRIEF18 00:53: a request naming a place we don't serve is a lead, never invited)
-- Internals: (none)
-- Uses: Drive.Careful, Drive.AutoReply
-- Later: Drive.Raincheck (DR.RaincheckFact: DR.Apply hands it the IOU facts), Drive.Service
--   (DR.SendConfig, DR.Summoners: a Warlock who left a typed place), Drive.Chat (DR.PlacesText),
--   Drive.Book (DR.ServeHold: a held rider's request is a lead, never queued by itself)
-- Events: listens On CHAT_MSG_WHISPER, On CHAT_MSG_CHANNEL, On CHAT_MSG_SAY, On CHAT_MSG_YELL, On
--   CHAT_MSG_SYSTEM, On GROUP_ROSTER_UPDATE, On GROUP_JOINED, On GROUP_LEFT, On PARTY_LEADER_CHANGED,
--   On PARTY_INVITE_REQUEST; fires DRIVE_MODE, DRIVE_PAID, DRIVE_RAID, DRIVE_REMOVED, DRIVE_STATE,
--   DRIVE_STATIONS, SETTINGS, DRIVE_RITUAL (2.3.0: name, phase c|h|s|f|t, data, from the CAST, HELP
--   (field 2: a helper without Wuber), END and GR facts)
-- Standalone: no
-- Test: tests/drive/queue_test.lua
-- From: Drive_Queue.lua 1-1123 (Wuber 2.2.1)
--
-- Drive_Queue: the riders and what happens to them (Ritual Rides' Queue.lua).
--
--   lead       wrote something that is not a clear request (listed, never invited unasked)
--   queued     asked for a summon; waits for a free place in the group
--   invited    the invite is out
--   joined     in the group, not here yet: ready to be summoned
--   summoning  a crew Warlock is casting the ritual for them
--   waiting    the ritual is done: they have the summon window (Wuber stage "portal")
--   arrived    stands next to us; pays now
--   paid       the price is in (2.3.0: a 2.3.0 app rider who paid by trade before arriving keeps
--              their state, c.prepaid, and is still summoned; paid once here)
--   done       thanked (and, with "kick", about to be removed)
--
-- The group says who joined, who left and who stands here; the other steps come from facts
-- (DR.Apply) that each crew window tells the others.

local _, W = ...
local Mod = W.Module("Drive.Queue", { "Drive.Careful", "Drive.AutoReply" })
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, str = W.Plain, W.Str

DR.customers = DR.customers or {}
DR.units = DR.units or {}
DR.ignored = DR.ignored or {}
DR.helpers = DR.helpers or {}
DR.session = DR.session or { rides = 0, copper = 0 }
DR.requestFilters = DR.requestFilters or {} -- fn(name, source, msg) -> true to refuse

local RANK = { lead = 1, queued = 2, invited = 3, joined = 4, summoning = 5, waiting = 6, arrived = 7, paid = 8, done = 9 }
DR.RANK = RANK
function DR.Rank(state) return RANK[state] or 0 end

local order = 0

DR.LEAD_TTL = 180
DR.QUEUE_TTL = 900
DR.WAIT_TTL = 130
DR.CAST_TTL = 330
DR.AWAY_AFTER = 240
local MAX_LEADS = 6

local function o() return DR.opts() end
-- selling summons now (raid mode has no riders, invites or whispers of this kind)
local function open() return DR.Selling and DR.Selling() or false end
local function myKey() return W.myKey end

---------------------------------------------------------------------------
-- Finding and making riders
---------------------------------------------------------------------------

-- The key of a player as some event spelled the name: exact, or the one group member or
-- rider whose name it starts (or is started by).
function DR.ResolveKey(name)
	local k = W.Key(name)
	if not k then return nil end
	if k == myKey() or DR.customers[k] or DR.units[k] then return k end
	local found, many = nil, false
	local function scan(t)
		for key in pairs(t) do
			if key ~= found and (key:sub(1, #k + 1) == k .. " " or k:sub(1, #key + 1) == key .. " ") then
				if found then many = true end
				found = key
			end
		end
	end
	scan(DR.units)
	scan(DR.customers)
	if found and not many then return found end
	return k
end

function DR.Find(name)
	local k = DR.ResolveKey(name)
	return k and DR.customers[k] or nil, k
end

-- A player's name as invites and whispers take it: "First Surname" (a "-Realm" after both
-- parts is dropped: on Forever the realm is a server node, and the name alone reaches them).
function DR.CleanName(name)
	name = str(name)
	if not name then return nil end
	local person = name:match("^(%S+ %S+)%-.+$")
	if person then return person end
	-- a one-part name (or "First-Surname") with a realm tail (W.IsRealmTail: SPEC5 realms,
	-- "Dan-CAMWOWEU4Realm7PvE" too): the realm goes; "Jean-Luc Picard" stays whole
	local base, tail = name:match("^(.-)%-([^%-]+)$")
	if base and base ~= "" and W.IsRealmTail(tail) then return base end
	return name
end

-- (v2.4, the sender's GUID, chat event argument 12) kept in memory beside the name on a rider or lead record
-- (c.guid; never saved, shown or sent), so the same person under another spelling of the name ("Dan",
-- "Dan Smith", a realm tail) is found by GUID first and by the name key after. A secret or missing GUID
-- is ignored: then only the name key matches, as before.
local hearing -- the GUID of the chat line being handled, if it carried a real one
local hearingKey -- and the name key of that line's sender: only a record made for the sender takes the GUID

local function realGuid(v)
	v = str(v)
	return v and v:find("^Player%-") and v or nil
end

function DR.KeyOfGuid(guid)
	if not guid then return nil end
	for k, c in pairs(DR.customers) do
		if c.guid == guid then return k end
	end
	return nil
end

-- The key (and the name to use on) of the sender of the line being handled. When the GUID finds a record made under
-- another spelling, the record keeps its key AND its name: the rest of this file makes a record's key from its name
-- (create), so the two must stay one spelling. The group roster refreshes the name later (DR.SyncRoster).
local function heardKey(sender)
	local k = hearing and DR.KeyOfGuid(hearing)
	if k then return k, DR.customers[k].name or sender end
	return W.Key(sender), sender
end

local function create(name, state, source)
	name = DR.CleanName(name)
	local k = W.Key(name)
	if not k then return nil end
	order = order + 1
	local c = {
		key = k, name = name, state = state, source = source, order = order, at = GetTime(),
		paid = 0, price = DR.char().price, tries = 0,
		guid = (hearing and k == hearingKey) and hearing or nil, -- the sender's own record only, never one made for somebody else meanwhile
	}
	DR.customers[k] = c
	W.Fire("DRIVE_STATE", c, nil)
	DR.Changed()
	return c
end
DR.Create = create

function DR.SetState(c, state)
	if not c or c.state == state then return end
	local was = c.state
	c.state = state
	c.at = GetTime()
	-- the driver at work: summoning, waiting, landing or finishing a ride is the driver's doing (AU24-01)
	if state == "summoning" or state == "waiting" or state == "arrived" or state == "paid" or state == "done" then
		DR.driverActAt = c.at
	end
	W.Fire("DRIVE_STATE", c, was)
	DR.Changed()
end

local TOLD = { timeout = true, expired = true, declined = true, missing = true, left = true }

-- (H24-13) riders who just left the group: [key] = { c, at }, kept DR.LEFT_KEEP seconds so a late PAID counts
DR.recentLeft = DR.recentLeft or {}
DR.LEFT_KEEP = 120
-- (H24-12) END and HELP of a summon are still counted this long after it ended (or, for END, after its CAST)
local LATE_END, LATE_HELP = 120, 20

function DR.Remove(c, why)
	if not c then return end
	if DR.customers[c.key] == c then
		DR.customers[c.key] = nil
		if why == "left" then
			-- (H24-13) a PAID can come after the rider left: remember them a while so it still shows
			local now = GetTime()
			for k, e in pairs(DR.recentLeft) do
				if now - e.at > DR.LEFT_KEEP then DR.recentLeft[k] = nil end
			end
			DR.recentLeft[c.key] = { c = c, at = now }
		end
		-- a rider the leader listed in the crew windows (ASK) and never got: off theirs too
		if TOLD[why or ""] and (c.state == "queued" or c.state == "invited") and DR.IsLeader() and W.InGroup() then
			DR.Send("DROP", c.name)
		end
		W.Fire("DRIVE_REMOVED", c, why or "drop")
	end
	DR.Changed()
end

-- Riders in the order they came.
function DR.Sorted()
	local list = {}
	for _, c in pairs(DR.customers) do list[#list + 1] = c end
	table.sort(list, function(a, b) return a.order < b.order end)
	return list
end

function DR.Count(state)
	local n = 0
	for _, c in pairs(DR.customers) do
		if c.state == state then n = n + 1 end
	end
	return n
end

function DR.Due(c) return math.max(0, (c and c.price or 0) - (c and c.paid or 0)) end

-- Never a rider: crew, the alert character, a group member marked "Not a rider".
function DR.NeverRider(k)
	return k == nil or k == myKey() or DR.IsCrewKey(k) or DR.IsBellKey(k) or DR.helpers[k] == true
end

---------------------------------------------------------------------------
-- Reading whispers
---------------------------------------------------------------------------

local PRICE_WORDS = { "how much", "price", "cost", "fee", "charge" }

-- The line a Wuber rider's Request click whispers: "WTB summon to Ratchet for 50s".
function DR.WuberLine(msg)
	if type(msg) ~= "string" then return false end
	return msg:lower():find("^%s*wtb%s+summons?%s+to%s+.-%s+for%s+%d") ~= nil
end

-- "request", "price", "cancel" or "other".
function DR.Classify(msg)
	if type(msg) ~= "string" then return "other" end
	if DR.WuberLine(msg) then return "request" end
	local lower = msg:lower()
	if lower:find("cancel%a*%s+my%s+summ") or lower:find("have%s+to%s+cancel") then return "cancel" end
	-- whole words only: "feel", "feet", "costume", "recharge" are not price questions (AU24-09)
	for _, p in ipairs(PRICE_WORDS) do
		if lower:find("%f[%a]" .. p .. "s?%f[%A]") or (p == "charge" and lower:find("%f[%a]charged%f[%A]")) then return "price" end
	end
	if #msg > 80 then return "other" end
	local words = {}
	for w in lower:gmatch("[%a%d]+") do words[w] = true end
	for _, kw in ipairs(o().keywords or DR.KEYWORDS) do
		if words[tostring(kw):lower()] then return "request" end
	end
	if DR.Summonish then
		for w in pairs(words) do
			if DR.Summonish(w) then return "request" end
		end
	end
	return "other"
end

local TOPIC = { summon = true, summons = true, summ = true, summoner = true, summoning = true, warlock = true, lock = true }
local WANT = {
	lf = true, lfs = true, wtb = true, need = true, looking = true, any = true, anyone = true,
	buying = true, paying = true, pls = true, plz = true, please = true, can = true,
}
local SELL = { wts = true, selling = true, sell = true, lfm = true, guild = true, recruiting = true }

-- Does a public chat line look like somebody who wants to buy a summon? (RR 1.0's test)
function DR.Wanted(msg)
	if type(msg) ~= "string" or #msg > 120 then return false end
	local topic, want = false, false
	for w in msg:lower():gmatch("%a+") do
		if SELL[w] then return false end
		if TOPIC[w] then topic = true end
		if WANT[w] then want = true end
	end
	return topic and want
end

-- a ride's own fields (BRIEF17 C6: also 2.1-2.3's); after "|" its Wuber ride, kept on a lead put back (Drive.Net ends it)
local RIDE_KEYS = "caster cashier castAt endAt arrivedAt paidAt joinedAt invitedAt greeted thanked reminded short shortTold walked priority gone busy "
	.. "busyTold farSeen hereSince wantsPrice kicks kickedAt boxed tradeTries tradeAt offer offerTold cameWith helperOf awayAt rideId prepaid payeeBlind askWhere whereTold "
	.. "elsewhere elsewhereTold dest forPlace askFor askedFor placeOffAt station priceTold doneAt helps called calledAt auto autoMsg | wuberRide wuberBuyer wuberPrice wuberLabel wuberVer voucher cover fullFare"
local function resetRide(c)
	c.paid, c.price, c.tries = 0, DR.char().price, 0
	for k in RIDE_KEYS:gmatch("%S+") do if k == "|" and c.state == "lead" and c.wuberRide then break end c[k] = nil end
end
DR.ResetRide = resetRide

-- The same place for a summon: the same name, or a town and the zone it stands in (a step outside).
local function samePlace(a, b)
	if W.SamePlace(a, b) then return true end
	local pa, pb = W.ExactPlace(a), W.ExactPlace(b)
	-- (the zone a place stands in counts by its name, so Orgrimmar and Durotar, or Auberdine and
	-- Darkshore, match though those zones are no listed places)
	local za, zb = pa and W.NormPlace(pa.zone) or "", pb and W.NormPlace(pb.zone) or ""
	if (za ~= "" and za == W.NormPlace(b)) or (zb ~= "" and zb == W.NormPlace(a)) then return true end
	if not (pa and pb) then return false end
	return (pb.kind == "zone" and pa.zone == pb.name) or (pa.kind == "zone" and pb.zone == pa.name)
end

-- Whether a place is one of these (DR.ServedPlaces' list).
local function inPlaces(place, list)
	for _, p in ipairs(list or {}) do
		if samePlace(place, p) then return true end
	end
	return false
end

-- Where we take riders now, for reading a request: DR.ServedPlaces, else the place DR.Dest names
-- when it is a real one; nil while neither is known.
local function servedNow()
	local list = DR.ServedPlaces()
	if list then return list end
	local d = str(DR.Dest and DR.Dest())
	if d and W.ExactPlace(d) then return { d } end
	return nil
end

local function multi() return DR.MultiStation and DR.MultiStation() or false end

-- (BRIEF18 00:53) What a request's words ask for, against where we take riders now: "match" (a
-- place we serve), "elsewhere" (only places we don't: "do you do UC summ?" while serving
-- Orgrimmar), "unclear" (ours and another, no "to" to tell which), "noplace" (none named, or we
-- don't know where we are yet); and the place: the one asked for (elsewhere, unclear: the other one).
local function askedFor(msg)
	local list = DR.AskedPlaces and DR.AskedPlaces(msg) or {}
	if #list == 0 then return "noplace", nil end
	local to = {}
	for _, p in ipairs(list) do if p.to then to[#to + 1] = p end end
	if #to > 0 then list = to end
	local now = servedNow()
	if not now then return "noplace", list[1].name end
	local hit, miss
	for _, p in ipairs(list) do
		if inPlaces(p.name, now) then hit = hit or p.name else miss = miss or p.name end
	end
	if hit and miss then return "unclear", miss end
	if miss then return "elsewhere", miss end
	return "match", hit
end
DR.AskedFor = askedFor

-- (BRIEF18 00:53) The invite's own guard: a rider who asked for a place is invited only while we
-- serve it (and not while we can't tell).
local function askOK(c)
	if not c.askFor or multi() then return true end
	local now = servedNow()
	return now ~= nil and inPlaces(c.askFor, now)
end
DR.AskOK = askOK

-- A player who did not clearly ask: listed, so one click can invite or answer them.
function DR.Lead(name, msg, source)
	local k = W.Key(name)
	if not k or DR.db.blocklist[k] or DR.NeverRider(k) then return nil end
	local c = DR.customers[k]
	if c then
		c.msg = msg
		DR.Changed()
		return c
	end
	local leads = {}
	for _, other in pairs(DR.customers) do
		if other.state == "lead" and not other.cameWith then leads[#leads + 1] = other end
	end
	if #leads >= MAX_LEADS then
		table.sort(leads, function(a, b) return a.order < b.order end)
		DR.Remove(leads[1], "expired")
	end
	c = create(name, "lead", source)
	c.msg, c.heardBy = msg, myKey()
	return c
end

-- A player asked for a summon.
function DR.Request(name, source, msg)
	if not DR.db then return nil end
	for _, f in ipairs(DR.requestFilters) do
		local ok, refuse = pcall(f, name, source, msg)
		if ok and refuse then return nil end
	end
	local k = W.Key(name)
	if not k or DR.db.blocklist[k] or DR.NeverRider(k) then return nil end
	DR.ignored[k] = nil
	local c = DR.customers[k]
	if c then
		if c.state ~= "lead" and c.state ~= "done" then return c end -- already being served
	end
	-- "Don't serve again until" (Drive.Book, the driver's own): listed so the driver can decide by hand, never
	-- queued for an invite by a whisper, the app or public chat
	if source ~= "manual" and DR.ServeHold and DR.ServeHold(k) then
		if c then
			c.msg = msg or c.msg
			resetRide(c)
			DR.SetState(c, "lead")
		else
			DR.Lead(name, msg, source)
		end
		DR.Changed()
		return nil
	end
	-- (BRIEF18 00:53, the author: "do you do UC summ?" while serving Orgrimmar was invited) words naming
	-- only a place we don't serve, or ours and another without saying which, are no request for us:
	-- a lead the driver decides on, never invited by itself. Several stations: DR.Route decides.
	-- A name the driver adds (or a lead clicked) is the driver's choice: kept, and said.
	local want, place = askedFor(msg)
	local named = (want == "elsewhere" or want == "unclear") and not multi()
	if named and source ~= "manual" and source ~= "relay" then
		local l = DR.Lead(name, msg, source)
		if l then
			l.askedFor, l.heardBy = place, l.heardBy or myKey()
			DR.Changed()
		end
		return nil
	end
	-- a lead who asked for another place and now names none ("summon pls"): still that place
	if c and c.state == "lead" and c.askedFor and want == "noplace" and source ~= "manual" and source ~= "relay"
		and not inPlaces(c.askedFor, servedNow()) then
		c.msg = msg or c.msg
		DR.Changed()
		return nil
	end
	if c then
		c.name, c.source = DR.CleanName(name) or c.name, source
		resetRide(c)
		DR.SetState(c, "queued")
	else
		c = create(name, "queued", source)
	end
	c.msg = msg or c.msg
	DR.moved[k] = nil -- (BRIEF18) asked again: for the place we serve now
	if not multi() and not named then c.askFor = place end
	if named and source == "manual" then
		c.askedFor = place
		local now = servedNow()
		DR.Alert(W.Short(c.name) .. " asked for " .. place .. (now and (", not " .. now[1]) or "")
			.. ": on your list because you added them.", "info")
	end
	-- several stations (SPEC4 2.2): the rider goes where they asked to go
	if DR.Route then
		local how = DR.Route(c, msg)
		-- (BRIEF18 a) the request remembers its place: the station (several), else where we summon to now
		local served = DR.ServedPlaces()
		local multi = DR.MultiStation and DR.MultiStation()
		-- (c.dest, from Route, is the place the words named: often where the rider stands, "I'm in
		-- Ironforge", so it never refuses a request by itself)
		c.forPlace = (multi and c.station) or (served and served[1]) or nil
		if how == "elsewhere" and source ~= "manual" then
			-- no station of ours summons there: told where we do, not queued
			c.state, c.elsewhere, c.elsewhereTold, c.heardBy = "lead", true, nil, myKey()
			W.Fire("DRIVE_STATE", c, "queued")
			DR.Changed()
			return nil
		elseif how == "elsewhere" then
			-- (r27 AUD-03) a lead the driver clicked: the driver's choice, to an open station
			c.station, c.elsewhere = c.station or c.forPlace, nil
			c.forPlace = c.station
		end
	end
	if DR.units[k] then
		c.joinedAt = GetTime()
		DR.SetState(c, "joined")
		DR.Send("ADD", name, c.station)
	elseif not DR.IsLeader() then
		if source ~= "relay" then DR.Send("ASK", name, "", c.station, c.price) end -- only the leader invites
	else
		-- the leader lists the rider in every crew window (the queues stay identical)
		DR.Send("ASK", name, "queued", c.station, c.price)
	end
	DR.PumpInvites()
	return c
end

function DR.SetPriority(c)
	if not c then return end
	for _, other in pairs(DR.customers) do other.priority = nil end
	c.priority = true
	if c.state == "waiting" then DR.SetState(c, "joined") end
	DR.Changed()
end

function DR.MarkPaid(c)
	if c then DR.Do("PAID", c.name, 0, "m") end
end

-- "Not a rider": a helper in the group (the rider's friend who clicks).
function DR.NotRider(c)
	if not c then return end
	DR.helpers[c.key] = true
	DR.Do("DROP", c.name)
end

local function onWhisper(text, sender)
	if not DR.on or DR.Role() ~= "driver" or not open() then return end
	text, sender = str(text), str(sender)
	if not text or not sender then return end
	local key
	key, sender = heardKey(sender)
	if not key or DR.NeverRider(key) then return end
	if DR.db.blocklist[key] then
		if DR.Classify(text) == "request" and DR.BlockedAskToast then DR.BlockedAskToast(sender) end
		if DR.Refuse then DR.Refuse(sender, text) end
		return
	end
	local c = DR.customers[key]
	if c and hearing and not c.guid then c.guid = hearing end
	if c and c.state ~= "lead" and c.state ~= "done" then
		c.msg = text
		-- the answer to "Where to?": the rider goes to that station
		if c.askWhere and DR.Route and DR.DestIn and DR.DestIn(text) then
			local was = c.station
			DR.Route(c, text)
			if c.station ~= was then
				-- (r32 AUD-14) the answer is where they asked to go now: the request remembers that place
				if DR.MultiStation and DR.MultiStation() and c.station then c.forPlace = c.station end
				DR.Send("ASK", c.name, "", c.station or "", c.price)
			end
		end
		DR.Changed()
		return
	end
	local kind = DR.Classify(text)
	if kind == "request" then
		-- (20 Nov hotfix, the author) a whisper naming another place ("do you do UC summ?" while you serve
		-- Orgrimmar) is not a request for you: it waits as a lead for you to decide; nobody is invited
		-- (BRIEF18 00:53) one naming a place we don't serve becomes a lead in DR.Request
		if DR.WuberLine(text) then
			DR.Request(sender, "whisper", text)
			return
		end
		local verdict = DR.Careful and DR.Careful(text, "whisper", sender) or "lead"
		if verdict == "invite" then
			local made = DR.Request(sender, "whisper", text)
			if made and (made.state == "queued" or made.state == "invited") then
				made.auto, made.autoMsg = "whisper", text
				-- (HUNT-123) counted only when the timer will invite them (switch on); off, they only wait for a click
				if o().autoInvite and DR.CountAuto then DR.CountAuto(made) end -- (Drive.Log: the careful record)
			end
			return
		end
		local l = DR.Lead(sender, text, "whisper")
		if l and l.state == "lead" and not multi() then
			local want, place = askedFor(text)
			if (want == "elsewhere" or want == "unclear") and place then
				l.askedFor, l.heardBy = place, l.heardBy or myKey()
				DR.Changed()
			end
		end
		return
	end
	if kind == "cancel" then return end
	-- (r27 AUD-02) the answer to "Where would you like to go?": just a place we serve ("Orgrimmar")
	if kind == "other" and c and c.state == "lead" and c.elsewhere and not text:find("[Wuber]", 1, true)
		and DR.DestIn and inPlaces(DR.DestIn(text), servedNow()) then
		DR.Request(sender, "whisper", text)
		return
	end
	if c and c.state == "done" then
		c.msg = text
		return
	end
	c = DR.Lead(sender, text, "whisper")
	if c and kind == "price" then
		c.wantsPrice, c.priceTold, c.heardBy = true, nil, myKey()
	end
end
W.On("CHAT_MSG_WHISPER", function(text, sender, _, _, _, _, _, _, _, _, _, guid)
	hearing = realGuid(guid)
	hearingKey = hearing and W.Key(str(sender)) or nil
	local ok, err = pcall(onWhisper, text, sender)
	hearing, hearingKey = nil, nil
	if not ok then error(err, 0) end
end)

-- A channel where buyers are invited from (opts.watchChannels).
local function market(channel)
	channel = tostring(channel or ""):lower():gsub("%s+", "")
	if channel == "" then return false end
	local watch = tostring(o().watchChannels or "")
	for entry in watch:lower():gmatch("[^,]+") do
		entry = entry:gsub("%s+", "")
		if entry ~= "" and channel:find(entry, 1, true) then return true end
	end
	return channel:find("lfg", 1, true) ~= nil and watch:lower():find("lookingforgroup", 1, true) ~= nil
end
DR.Market = market

local function publicLine(text, sender, inMarket)
	if not DR.on or DR.Role() ~= "driver" then return end
	text, sender = str(text), str(sender)
	if not text or not sender then return end
	local key
	key, sender = heardKey(sender)
	if not key or DR.NeverRider(key) then return end
	if W.drivers and W.drivers[key] then return end -- another Wuber driver
	-- (SPEC5 public, review #18: buyers are read only while selling with "watch public chat" on;
	-- a closed driver's chat costs nothing here. Net still reads "[Wuber]" adverts for discovery.)
	local opts = o()
	if not (open() and opts.watchPublic) then return end
	if DR.HasGameLink and DR.HasGameLink(text) then return end -- (LRN-06) a linked item or spell is no request
	local verdict, why, want = "ignore", nil, nil
	if DR.Careful then verdict, why, want = DR.Careful(text, "public", sender) end
	-- the demand log still hears a buyer for a place we don't serve (logged, never listed); a seller's
	-- line or a bare place name ("Port Orgrimmar") is no demand
	if want and DR.LogAsk and (verdict ~= "ignore" or why == "another place") then DR.LogAsk(want, sender, text, inMarket) end
	if verdict == "ignore" then return end
	if DR.db.blocklist[key] then return end
	local c = DR.customers[key]
	if c and c.state ~= "lead" and c.state ~= "done" then return end
	if verdict == "invite" and inMarket and opts.autoPublic then
		c = DR.Request(sender, "public", text)
		if c and (c.state == "queued" or c.state == "invited") then
			c.offer = true
			c.auto, c.autoMsg = "public", text
			if o().autoInvite and DR.CountAuto then DR.CountAuto(c) end
		end
		return
	end
	if not c then DR.Lead(sender, text, "public") end
	if DR.TryReply then DR.TryReply(sender, text, verdict) end
end
DR.PublicLine = publicLine

-- a public line, with its GUID (argument 12) known while it is handled
local function heardPublic(guid, text, sender, inMarket)
	hearing = realGuid(guid)
	hearingKey = hearing and W.Key(str(sender)) or nil
	local ok, err = pcall(publicLine, text, sender, inMarket)
	hearing, hearingKey = nil, nil
	if not ok then error(err, 0) end
end

W.On("CHAT_MSG_CHANNEL", function(text, sender, _, channelName, _, _, _, _, baseName, _, _, guid)
	heardPublic(guid, text, sender, market(str(baseName) or str(channelName)))
end)
W.On("CHAT_MSG_SAY", function(text, sender, _, _, _, _, _, _, _, _, _, guid) heardPublic(guid, text, sender, false) end)
W.On("CHAT_MSG_YELL", function(text, sender, _, _, _, _, _, _, _, _, _, guid) heardPublic(guid, text, sender, false) end)

---------------------------------------------------------------------------
-- Invites (the leader's window)
---------------------------------------------------------------------------

local inviteLog = {}

-- A ride in progress: invited, in the group, being summoned, or landed and not yet paid.
function DR.Busy()
	for _, c in pairs(DR.customers) do
		local s = c.state
		if s == "invited" or s == "joined" or s == "summoning" or s == "waiting" or (s == "arrived" and not c.walked) then
			return true
		end
	end
	return false
end

-- The group's leader: key and name (nil when I lead, or am not in a group).
function DR.LeaderOf()
	if not W.InGroup() or DR.IsLeader() then return nil end
	for k, unit in pairs(DR.units) do
		if DR.IsLeaderKey(k) then return k, W.UnitName(unit) or k end
	end
	return nil
end

-- Whether a window of this crew can invite riders: alone or leading as a Warlock, or the
-- leader is a crew Warlock running Wuber (it invites the riders we ASK about). A helper or a
-- stranger leading the group invites nobody: the beacon then says paused.
function DR.CanInvite()
	if not W.InGroup() or DR.IsLeader() then return DR.Role() == "driver" end
	local k = DR.LeaderOf()
	if not k or not DR.TrustKey(k) then return false end
	local peer = DR.peers[k]
	-- a non-Warlock runner is the captain (setting it up makes it so) and invites its own riders
	return peer ~= nil and (peer.role == "L" or (peer.role == "H" and k == DR.CaptainKey()))
end

-- A helper's window that leads the group hands the lead to a crew Warlock (the captain
-- first), so somebody can invite. Returns the name it went to, or nil.
function DR.LeadTarget()
	if DR.Role() ~= "helper" or not W.InGroup() or not DR.IsLeader() then return nil end
	-- (review 2.2 #6: only while selling - raid summons invite nobody, and the raid's lead stays put)
	if DR.Selling and not DR.Selling() then return nil end
	local pick, pickKey
	local cap = DR.CaptainKey()
	for k, unit in pairs(DR.units) do
		local peer = DR.peers[k]
		if DR.TrustKey(k) and peer and peer.role == "L" then
			if k == cap then return unit, W.UnitName(unit) or peer.name end
			if not pickKey or k < pickKey then pick, pickKey = unit, k end
		end
	end
	if not pick then return nil end
	return pick, W.UnitName(pick) or pickKey
end

function DR.HandLead(force)
	if not DR.on then return nil end
	if not force and not DR.IsOpen() then return nil end
	local now = GetTime()
	if not force and now - (DR.handLeadAt or -100) < 5 then return nil end
	local unit, name = DR.LeadTarget()
	if not unit then return nil end
	DR.handLeadAt = now
	-- C_PartyInfo.PromoteToLeader(name) on Forever 1.60.1 (not a protected call); the name as
	-- invites take it
	local promote = (C_PartyInfo and C_PartyInfo.PromoteToLeader) or rawget(_G, "PromoteToLeader")
	if not name or not W.Try("promote", promote, DR.CleanName(name) or name) then return nil end
	return name
end

-- The lead handover as a step for a click (SPEC5 promote: PromoteToLeader only from a hardware
-- click, the Readiness pill or the big button): nil, or { unit, name, short, title, run }.
function DR.LeadFix()
	local unit, name = DR.LeadTarget()
	if not unit or not name then return nil end
	local short = W.Short(name)
	return { unit = unit, name = name, short = short, title = "Give lead to " .. short,
		run = function() return DR.HandLead(true) end }
end

local function raidQuestion()
	local q = rawget(_G, "CONVERT_TO_RAID")
	if type(q) == "string" and q ~= "" then return q end
	return "Convert to raid"
end

-- The invite itself (DR.PumpInvites, and DR.Invite's row click): marks them invited, tells the crew.
local function inviteOne(pick, now, converts)
	local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or rawget(_G, "InviteUnit")
	if not W.Try("invite", invite, pick.name) then return end
	DR.lastInviteAt = now
	inviteLog[#inviteLog + 1] = now
	if DR.customers[pick.key] ~= pick or pick.state ~= "queued" then return end
	pick.invitedAt = now
	DR.SetState(pick, "invited")
	DR.Send("ASK", pick.name, "invited", pick.station, pick.price)
	if converts and not DR.raidHint then
		DR.raidHint = true
		DR.Alert("The game asks \"" .. raidQuestion() .. "\" - say yes so " .. W.Short(pick.name) .. " can join.", "info")
	end
end

-- (r30) Room for an invite now, the timer's and a click's alike: false, or true and converts (to a raid).
local function inviteRoom(opts, now, sweep)
	if (DR.IsPaused and DR.IsPaused()) or (opts.oneAtATime and DR.Busy()) then return false end
	if (DR.inviteHold and now < DR.inviteHold) or now - (DR.lastInviteAt or -100) < 1.5 then return false end
	-- (BRIEF18) a hearth or teleport on its way: nobody is invited to the place we leave
	if DR.Travelling() then return false end
	if sweep then DR.PlaceSweep() end
	while inviteLog[1] and now - inviteLog[1] > 60 do table.remove(inviteLog, 1) end
	local cap = opts.inviteCap or 8
	if DR.MultiStation and DR.MultiStation() then cap = math.max(cap, 12) end -- SPEC4 2.3
	if #inviteLog >= cap then return false end
	local size, pending = DR.GroupSize(), DR.Count("invited")
	if size + pending >= DR.MaxGroup() then return false end
	if not DR.InRaid() and size + pending >= 5 then return pending == 0, true end
	return true, false
end

-- (r30 HUNT-12) Whisper invites off: a queued rider's row click invites them when the timer would (switch on).
function DR.ClickInvites(c)
	if type(c) ~= "table" or c.state ~= "queued" or o().autoInvite or not DR.on then return false end
	if not (DR.Role() == "driver" and open() and DR.IsLeader() and not W.IsBlocked("invite")) then return false end
	return DR.PlaceOK(c) and askOK(c) and inviteRoom(o(), GetTime()) and true or false
end

-- Invite a lead now, or a queued rider (DR.ClickInvites), from the driver's click (never a timer).
function DR.Invite(c)
	if not c then return nil end
	if not DR.ClickInvites(c) then
		-- (HUNT-122) one tap on a lead invites too: it is queued, then invited when the click may invite
		local made = DR.Request(c.name, "manual", c.msg)
		if not (made and DR.ClickInvites(made)) then return made end
		c = made
	end
	inviteOne(c, GetTime(), select(2, inviteRoom(o(), GetTime())))
	return c
end

function DR.PumpInvites()
	local opts, now = o(), GetTime()
	if not DR.on or DR.Role() ~= "driver" then return end
	if not (open() and opts.autoInvite) or W.IsBlocked("invite") or not DR.IsLeader() then return end
	local room, converts = inviteRoom(opts, now, true)
	if not room then return end
	local pick
	for _, c in ipairs(DR.Sorted()) do
		-- (BRIEF18 c) never a rider for a place we left; (00:53) nor one who asked for a place we don't serve
		if c.state == "queued" and DR.PlaceOK(c) and askOK(c) and not (c.source ~= "manual" and DR.ServeHold and DR.ServeHold(c.key)) then
			pick = c
			break
		end
	end
	if not pick then return end
	inviteOne(pick, now, converts)
end

local function toPattern(fmt)
	if type(fmt) ~= "string" or fmt == "" then return nil end
	local p = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	p = p:gsub("%%%d+%%%$s", "(.+)"):gsub("%%s", "(.+)")
	return "^" .. p .. "$"
end

local SYSTEM = {
	{ global = "ERR_DECLINE_GROUP_S", what = "declined" },
	{ global = "ERR_ALREADY_IN_GROUP_S", what = "grouped" },
	{ global = "ERR_BAD_PLAYER_NAME_S", what = "missing" },
	{ global = "ERR_IGNORING_YOU_S", what = "declined" },
}
local systemPatterns

W.On("CHAT_MSG_SYSTEM", function(text)
	if not DR.on or not open() then return end
	text = str(text)
	if not text then return end
	if text == rawget(_G, "ERR_GROUP_FULL") then
		DR.inviteHold = GetTime() + 15
		return
	end
	if not systemPatterns then
		systemPatterns = {}
		for _, s in ipairs(SYSTEM) do
			local p = toPattern(rawget(_G, s.global))
			if p then systemPatterns[#systemPatterns + 1] = { pattern = p, what = s.what } end
		end
	end
	for _, s in ipairs(systemPatterns) do
		local who = text:match(s.pattern)
		if who then
			local c = DR.Find(who)
			DR.inviteMisses = 0
			if c and (c.state == "invited" or c.state == "queued") then
				if s.what == "grouped" then
					c.busy, c.busyTold, c.heardBy = true, nil, myKey()
					local wasInvited = c.state == "invited"
					DR.SetState(c, "lead")
					-- the crew's other windows hear it, or they keep him invited and Busy for the invite timeout
					if wasInvited and W.InGroup() then DR.Send("DROP", c.name) end
				else
					DR.Remove(c, s.what)
				end
			end
			return
		end
	end
end)

---------------------------------------------------------------------------
-- The group
---------------------------------------------------------------------------

-- Who decides that a rider who left owed the fare: one window only (the others learn it from
-- its BLK). The caster's; with the caster gone, the leader's when it is crew, else the captain.
DR.owing = DR.owing or {} -- [key] = { c, at }: left owing, decided after DR.OWING_GRACE
DR.OWING_GRACE = 10

local function crewHere()
	for k in pairs(DR.units) do
		if DR.TrustKey(k) and DR.peers[k] then return true end
	end
	return false
end

function DR.DecidesNonPayer(c)
	local caster = c and c.caster
	if caster == myKey() then return true end
	if caster and DR.units[caster] and DR.peers[caster] then return false end
	if DR.IsLeader() then return true end
	for k in pairs(DR.units) do
		if DR.IsLeaderKey(k) and DR.TrustKey(k) and DR.peers[k] then return false end
	end
	return DR.IsCaptain()
end

-- (AUD-20) set by DR.SyncRoster: this window left its group itself (it is out of a group now and more than
-- one other member was there), so the riders it no longer sees are still there, not walk-outs. With one
-- other member it is that member who left (a rider walking out of a two-person party).
local selfLeft = false

local function left(c)
	if c.state == "done" then
		DR.Remove(c, "done")
	elseif c.state == "paid" then
		c.gone = true -- the thanks can still go out
	else
		-- (AUD-20) this window left the group itself: the rider is still there, not a walk-out
		if c.state == "arrived" and (c.tries or 0) > 0 and not c.walked and not selfLeft and DR.DecidesNonPayer(c) then
			-- with crew windows about, a PAID may still be on its way: decided in a moment; a solo driver waits 2 s for the trade timers
			DR.owing[c.key] = { c = c, at = GetTime(), grace = crewHere() and DR.OWING_GRACE or 2 }
		end
		DR.Remove(c, "left")
		DR.OwingTick(GetTime())
	end
end

-- Riders who left owing: blocked (or reported) once the grace is over and they still owe.
function DR.OwingTick(now)
	for k, e in pairs(DR.owing) do
		if now - e.at >= (e.grace or 0) then
			DR.owing[k] = nil
			if DR.Due(e.c) > 0 and DR.NonPayer then DR.NonPayer(e.c) end
		end
	end
end

-- The rider a hand-invited stranger most likely came with (someone waiting for a summon).
local function waitingRider()
	local best
	for _, c in pairs(DR.customers) do
		if (c.state == "joined" or c.state == "summoning" or c.state == "waiting") and not c.cameWith then
			if not best or c.order > best.order then best = c end
		end
	end
	return best
end

-- (AUD-28) a group member whose name reads "Unknown" for a moment (loading screen, party to raid) is
-- missing from DR.Roster: while the roster is short, nobody is dropped, and the roster is looked at
-- again in a few seconds (a name coming back fires no roster event of its own). For RECHECK_FOR seconds
-- at most: a name that stays unreadable must not hold the list for good (then: as before AUD-28).
local RECHECK_SECS, RECHECK_FOR = 3, 15
local recheckDue = false
local shortSince -- GetTime() when the roster was first seen short (nil: it is whole)
local function recheckRoster()
	recheckDue = false
	if DR.on then DR.SyncRoster() DR.Changed() end
end

function DR.SyncRoster()
	if not DR.db then return end
	local now = GetTime()
	local units = {}
	local roster = DR.Roster()
	local isOpen = open()
	local short = W.InGroup() and #roster < DR.GroupSize() - 1
	if not short then
		shortSince = nil
	elseif not shortSince then
		shortSince = now
	elseif now - shortSince > RECHECK_FOR then
		short = false
	end
	if short and not recheckDue then
		recheckDue = true
		W.After(RECHECK_SECS, recheckRoster)
	end
	-- the group member is the record's person when the GUID says so, whatever the spelling of the name
	local claimed = {}
	for _, m in ipairs(roster) do claimed[m.key] = true end
	for _, m in ipairs(roster) do
		local unitGuid = rawget(_G, "UnitGUID")
		local ok, g = false, nil
		if type(unitGuid) == "function" then ok, g = pcall(unitGuid, m.unit) end
		m.guid = ok and realGuid(g) or nil
		if m.guid then
			local own = DR.customers[m.key]
			if own then
				own.guid = own.guid or m.guid
			else
				local k = DR.KeyOfGuid(m.guid)
				if k and not claimed[k] then claimed[k], m.key = true, k end
			end
		end
	end
	for _, m in ipairs(roster) do units[m.key] = m.unit end
	local fresh = {}
	for _, m in ipairs(roster) do
		if not DR.NeverRider(m.key) then
			local c = DR.customers[m.key]
			if c then
				c.name, c.gone = m.name, nil
				if RANK[c.state] < RANK.joined and not c.cameWith then
					if c.state == "invited" then DR.inviteMisses = 0 end
					-- (SPEC5 farelock, review #6: the fare stays the one locked when they asked)
					c.joinedAt = now
					if c.wuberPrice then c.price = c.wuberPrice end
					-- (BRIEF18 00:53) a lead who asked for another place, invited by hand: the driver's choice, said
					if c.state == "lead" and c.askedFor then
						DR.Alert(W.Short(c.name) .. " joined, but asked for " .. c.askedFor .. ".", "info")
					end
					DR.SetState(c, "joined")
				end
			elseif DR.moved[m.key] and DR.moved[m.key].invited and now - (DR.moved[m.key].at or now) < DR.MOVED_TTL then
				-- (BRIEF18 b) the invite for a place we left, accepted late: not a rider (owed the sorry whisper)
				DR.ignored[m.key] = true
			elseif isOpen and not DR.ignored[m.key] and DR.Role() == "driver" then
				fresh[#fresh + 1] = m
			end
		end
	end
	local hadOthers = 0
	for _ in pairs(DR.units) do hadOthers = hadOthers + 1 end
	selfLeft = hadOthers >= 2 and not W.InGroup()
	DR.units = units
	-- invited by hand: a rider all the same, unless they came along while a rider waits for
	-- a summon (a friend who clicks): then a "came with" row the driver can mark "Helper".
	-- Only the leader knows whom it invited, so only the leader decides; the other crew
	-- windows are told (DROP: not billed there either).
	local leads = DR.IsLeader()
	for _, m in ipairs(fresh) do
		local with = leads and waitingRider() or nil
		if with and not DR.units[with.key] then with = nil end
		if with then
			local c = create(m.name, "lead", "group")
			c.guid = m.guid
			c.cameWith, c.helperOf, c.heardBy, c.msg = with.name, with.name, myKey(), nil
			DR.Send("DROP", m.name)
		else
			local c = create(m.name, "joined", "group")
			c.guid = m.guid
			c.joinedAt = now
		end
	end
	if short then return end -- (AUD-28) a name reads Unknown: who left is decided on the next look
	for key in pairs(DR.peers) do
		if not units[key] then DR.peers[key] = nil end
	end
	for key in pairs(DR.apps) do
		if not units[key] then DR.apps[key] = nil end
	end
	for key in pairs(DR.ignored) do
		if not units[key] then DR.ignored[key] = nil end
	end
	for key in pairs(DR.helpers) do
		if not units[key] then DR.helpers[key] = nil end
	end
	for key, c in pairs(DR.customers) do
		if not units[key] and not c.gone then
			if RANK[c.state] >= RANK.joined then
				left(c)
			elseif c.cameWith then
				DR.Remove(c, "left")
			end
		end
	end
end

W.On("GROUP_ROSTER_UPDATE", function()
	if not DR.on then return end
	DR.SyncRoster()
	DR.PumpInvites()
	DR.Changed()
end)

W.On("GROUP_JOINED", function()
	if not DR.on then return end
	DR.SyncRoster()
	if DR.Active() then DR.Hello(true) end
end)

W.On("GROUP_LEFT", function()
	if not DR.on then return end
	DR.SyncRoster()
	DR.Changed()
end)

W.On("PARTY_LEADER_CHANGED", function() if DR.on then DR.Changed() end end)

-- A crew member's group invite is accepted for you.
W.On("PARTY_INVITE_REQUEST", function(sender)
	if not DR.on or not DR.Active() or not o().autoAccept then return end
	sender = str(sender)
	local k = sender and W.Key(sender)
	if not k or k == myKey() or not DR.TrustKey(k) then return end
	local accept = rawget(_G, "AcceptGroup")
	if type(accept) ~= "function" then return end
	if not W.Try("accept", accept) then return end
	local function close()
		local find = rawget(_G, "StaticPopup_FindVisible")
		local dialog = type(find) == "function" and find("PARTY_INVITE")
		if not dialog then return end
		dialog.inviteAccepted = 1
		local hide = rawget(_G, "StaticPopup_Hide")
		if type(hide) == "function" then hide("PARTY_INVITE") end
	end
	close()
	W.After(0.2, close)
end)

---------------------------------------------------------------------------
-- Facts
---------------------------------------------------------------------------

local function blank(v)
	if v == "" then return nil end
	return v
end

local function applyConfig(mine, a, b, c3, d, e, f, g, h, i, j, k)
	if mine then return end
	local ch, opts = DR.char(), o()
	local on = a == "1"
	if DR.Role() == "driver" and ch.captain == "" and not DR.IsWarlock() then
		-- a runner of my own (any class) never mirrors another window's open
	elseif DR.Role() == "driver" then
		if ch.drive ~= on then
			ch.drive = on
			W.Fire("SETTINGS", "drive")
		end
	else
		DR.crewOpen = on
	end
	-- 2.1: the runner's stations (on/off), mode and raid summons
	if g ~= nil or h ~= nil then
		local stations = {}
		for pair in tostring(g or ""):gmatch("[^,]+") do
			local place, flag = pair:match("^%s*(.-)%s*:%s*([01])%s*$")
			if place and place ~= "" and flag == "0" then stations[W.Clean(place, 32)] = false end
		end
		DR.crewStations = stations
		W.Fire("DRIVE_STATIONS")
		local mode = h == "raid" and "raid" or "sell"
		local run = i == "1"
		-- the runner's raid message toggles (B's raidsum whisper, raidclick line)
		if j == "0" or j == "1" then opts.raidsum = j == "1" end
		if k == "0" or k == "1" then opts.raidclick = k == "1" end
		if DR.crewMode ~= mode or DR.crewRaidRun ~= run then
			DR.crewMode, DR.crewRaidRun = mode, run
			-- (AUD-76) the runner stopped raid summons: its queue went with it, so a restart lists only the new run
			if not (mode == "raid" and run) then
				for rk in pairs(DR.raidRows or {}) do DR.raidRows[rk] = nil end
			end
			W.Fire("DRIVE_MODE", mode)
			W.Fire("DRIVE_RAID")
			W.Fire("SETTINGS", "drive")
		end
	end
	-- (FAB-03) a crew member's own values are kept aside before the captain's replace them (Drive.Team puts them back)
	if ch.captain ~= "" and DR.KeepOwnConfig then DR.KeepOwnConfig() end
	local price = W.Int(b)
	if price then ch.price = math.max(W.MIN_PRICE or 5000, math.min(99999999, price)) end
	local mg = W.Int(c3)
	if mg then opts.maxGroup = math.max(3, math.min(40, mg)) end
	opts.kickAfter = d == "1"
	if e == "auto" or e == "macro" or e == "box" or e == "off" then opts.whisperMode = e end
	ch.dest = W.Clean(f or "", 32)
	DR.SyncRoster()
	DR.Changed()
end

local function applyService(mine, a, b, c3, d)
	if mine then return end
	-- 2.1: the runner's summoners in cast order
	local list = {}
	for n in tostring(d or ""):gmatch("[^,]+") do
		n = W.Clean(n, 48)
		if W.Key(n) and #list < 8 then list[#list + 1] = n end
	end
	DR.crewSummoners = list
	local ch, opts = DR.char(), o()
	if a then
		local name, why = W.CleanService(a, W.myName)
		if not why then ch.service = name end
	end
	if b then
		local list = {}
		for w in b:lower():gmatch("[%a%d]+") do if #list < 20 then list[#list + 1] = w end end
		if #list > 0 then opts.keywords = list end
	end
	if c3 then
		-- "-" = whoever clicks; else the main caster's name ("" never travels)
		if c3 == "-" or W.Key(c3) ~= W.myKey then ch.caster = (c3 == "-") and "-" or W.Clean(c3, 48)
		else ch.caster = W.myName or "" end
	end
	DR.Changed()
end

local TEMPLATE_KINDS = { advert = true, greet = true, price = true, offer = true, pay = true, thanks = true,
	tip = true, short = true, busy = true, refuse = true,
	where = true, callsum = true, raidsum = true, raidclick = true, getapp = true } -- 2.1; getapp: round 9

local function applyPaid(c, key, from, mine, a, b, c3, now)
	local copper = math.max(0, math.min(99999999, W.Int(b) or 0))
	local byHand = c3 == "m"
	if not c and key and DR.owing[key] then c = DR.owing[key].c end
	-- (H24-13) a rider who left the group a moment ago: the PAID still counts for them
	local gone = key and DR.recentLeft[key]
	if not c and gone and GetTime() - gone.at <= DR.LEFT_KEEP then c = gone.c end
	if not byHand then DR.session.copper = DR.session.copper + copper end
	local before = c and (c.paid or 0) or 0
	local price = c and (c.price or 0) or 0
	if c then c.paid = before + copper end
	local tip = 0
	if c and not byHand then tip = math.max(0, c.paid - price) - math.max(0, before - price) end
	W.Fire("DRIVE_PAID", c and c.name or a, copper, tip, from, mine, byHand and "m" or "t", price)
	if not c then DR.Changed() return end -- a gift from somebody not on the list
	if DR.customers[c.key] ~= c then
		-- a rider who left a moment ago (DR.owing): the fare counts, they are not blocked
		if c.paid >= price or byHand or o().acceptUnder then
			DR.session.rides = DR.session.rides + 1
			DR.owing[c.key] = nil
			DR.recentLeft[c.key] = nil -- counted: a second PAID is no second ride
		end
		DR.Changed()
		return
	end
	c.cashier, c.paidAt = from, now
	if c.paid >= price or byHand or o().acceptUnder then
		c.short = nil
		if RANK[c.state] < RANK.paid then
			-- 2.3.0 (SPEC7 5.8): a 2.3.0 app rider in the group who paid by trade before arriving is
			-- still summoned; "paid" once here (QueueTick), so a ride that fails first can earn a raincheck
			if not byHand and RANK[c.state] >= RANK.joined and RANK[c.state] < RANK.arrived
				and W.VerAtLeast and W.VerAtLeast(c.wuberVer, "2.3.0") then
				c.prepaid = true
			else
				DR.session.rides = DR.session.rides + 1
				DR.SetState(c, "paid")
			end
		end
	else
		c.short, c.shortTold = true, nil
	end
	DR.Changed()
end

-- A crew window's locked fare for a rider (ASK / ST, SPEC5 farelock): every window bills
-- the same fare, whatever the price is now.
local function lockPrice(c, price)
	price = W.Int(price)
	if not c or not price or price < (W.MIN_PRICE or 5000) then return end
	price = math.min(99999999, price)
	if c.price ~= price then
		c.price = price
		DR.Changed()
	end
end
DR.LockPrice = lockPrice

local function applyState(c, key, mine, a, b, c3, d, e, f, price, ride)
	if mine or not key or not DR.units[key] or DR.NeverRider(key) then return end
	-- 2.3.0: another ride id for a listed rider (they booked again): the old row's ride is over
	if c and ride and ride:match("^%a%a%a%a%a%a$") and (c.wuberRide or c.rideId) and (c.wuberRide or c.rideId) ~= ride then
		DR.Remove(c, "rebook")
		c = nil
	end
	if not c then c = create(W.UnitName(DR.units[key]) or a, "joined", "group") end
	if not c then return end
	lockPrice(c, price)
	-- 2.3.0 (SPEC7 5.7, 5.8): the ride id (field 9) and a fare a raincheck lowered (flag v: any amount)
	if ride and not c.wuberRide and ride:match("^%a%a%a%a%a%a$") then c.rideId = ride end
	if price and (f or ""):find("v", 1, true) then c.price = math.max(0, math.min(99999999, price)) end
	if RANK[b or ""] and RANK[b] > RANK[c.state] then
		DR.SetState(c, b)
		-- a window that came back after the rider landed: they landed by now (the trade 3 s and
		-- the pay reminder 25 s after it, as when this window sees them arrive itself)
		if c.state == "arrived" then c.arrivedAt = c.arrivedAt or GetTime() end
	end
	c.caster = c.caster or (c3 and W.Key(c3)) or nil
	c.paid = math.max(c.paid or 0, math.min(99999999, W.Int(d) or 0))
	c.cashier = c.cashier or (e and W.Key(e)) or nil
	local flags = f or ""
	if flags:find("g", 1, true) then c.greeted = true end
	if flags:find("t", 1, true) then c.thanked = true end
	if flags:find("r", 1, true) then c.reminded = true end
	-- 2.3.0: flag n = a 2.3.0 app rider (the window that took the request knows from R field 6)
	if flags:find("n", 1, true) and not c.wuberVer then c.wuberVer = "2.3.0" end
	if flags:find("s", 1, true) then
		if (c.tries or 0) == 0 then c.tries = 1 end
		c.walked = nil
	end
	DR.Changed()
end

-- A summoner key a crew window names for a cast (CAST b / END c3): a crew Warlock, else nil.
local function namedCaster(v)
	local k = v and W.Key(v)
	if not k then return nil end
	if k == myKey() then return DR.IsWarlock() and k or nil end
	local m = DR.CrewEntry(k)
	return (m and m.role == "lock") and k or nil
end

-- DRIVE_RITUAL (2.3.0, SPEC7 5.10): a step of a rider's summon, in every crew window, from the
-- facts: t greeted, c casting, h a helper clicked (data.helper, data.tapped), s summoned, f failed
local function ritual(c, phase, data)
	data.key, data.rider, data.caster, data.ride = c.key, c.name, c.caster, c.wuberRide or c.rideId
	W.Fire("DRIVE_RITUAL", c.name, phase, data)
end

-- kind and fields as in Drive_Team.lua; `from` is the key of the crew window that saw it.
function DR.Apply(kind, from, a, b, c3, d, e, f, g, h, i, j, k)
	if not DR.db then return end
	local now = GetTime()
	a, b, c3, d, e, f, g = blank(a), blank(b), blank(c3), blank(d), blank(e), blank(f), blank(g)
	local mine = from == myKey()
	if DR.RaidApply and DR.RaidApply(kind, from, mine, a, b, c3, now) then return end

	if kind == "CFG" then
		applyConfig(mine, a, b, c3, d, e, f, g, h, i, j, k)
		return
	elseif kind == "PAU" then
		if not mine then
			local was = DR.char().paused == true
			DR.char().paused = a == "1"
			-- a crew mate's Resume does what a local one does (SPEC5 resume, review #17): the
			-- away guard's marks go, the queue is invited, the screens hear it
			if was and not DR.char().paused then
				DR.driverActAt = GetTime() -- a crew Resume restarts the away clock too (as DR.SetPaused does)
				for _, c in pairs(DR.customers) do c.awayAt = nil end
				if DR.PumpInvites then DR.PumpInvites() end
			end
			if was ~= DR.char().paused then W.Fire("SETTINGS", "paused") end
			DR.Changed()
		end
		return
	elseif kind == "SVC" then
		applyService(mine, a, b, c3, d)
		return
	elseif kind == "TPL" then
		if mine then return end
		if a and (TEMPLATE_KINDS[a] or (type(DR.TEMPLATES) == "table" and DR.TEMPLATES[a] ~= nil)) and b then
			-- the advert line may be longer than a whisper (DR.ADVERT_MAX); the default text clears the entry
			local t = W.Clean(b, a == "advert" and DR.ADVERT_MAX or DR.TEXT_MAX)
			local spam = DR.TemplateSpam or W.SentenceSpam
			local okS, why = pcall(spam, t)
			if okS and not why then
				if t == (DR.TEMPLATES or {})[a] then DR.db.templates[a] = nil else DR.db.templates[a] = t end
			end
		end
		return
	elseif kind == "ASK" then
		if mine or not a or not open() then return end
		-- (SPEC5 farelock: ASK's fourth field is the fare the hearing window locked)
		local fare = W.Int(d)
		-- the station a crew window routed the rider to (ASK's third field)
		local function station(c)
			if c and c3 and c.station ~= c3 then
				c.station = c3
				c.askWhere = nil
				DR.Changed()
			end
		end
		if DR.IsLeader() then
			local known = DR.Find(a)
			if known and known.state ~= "lead" and known.state ~= "done" then
				station(known)
				lockPrice(known, fare)
			elseif DR.Role() == "driver" then
				DR.relayStation = c3 -- routed by the window that heard them
				local made = DR.Request(a, "relay")
				DR.relayStation = nil
				if type(made) == "table" then lockPrice(made, fare) end
			end
		elseif DR.IsLeaderKey(from) or (b == nil and DR.Find(a)) then
			if b == nil then
				station(DR.Find(a))
				return
			end
			-- the leader's list: queued (or invited) in this window too
			local k = W.Key(a)
			if not k or DR.NeverRider(k) or DR.db.blocklist[k] or DR.units[k] then return end
			local c = DR.customers[k]
			if not c then
				c = create(a, "queued", "relay")
				if not c then return end
			elseif c.state == "lead" or c.state == "done" then
				resetRide(c)
				DR.SetState(c, "queued")
			end
			if b == "invited" and c.state == "queued" then
				c.invitedAt = now
				DR.SetState(c, "invited")
			end
			station(c)
			lockPrice(c, fare)
		end
		return
	end

	if not a then return end
	local c, key = DR.Find(a)

	-- a crew window serves a group member this window does not list: listed again
	if not c and (kind == "ADD" or kind == "CAST") and key and DR.units[key] and not DR.NeverRider(key) then
		DR.ignored[key] = nil
		c = create(W.UnitName(DR.units[key]) or a, "joined", "group")
		if c then c.joinedAt = now end
	end
	if kind == "ADD" then
		if c and key and DR.units[key] and (c.state == "done" or (c.state == "lead" and c.cameWith)) then
			resetRide(c)
			c.joinedAt = now
			DR.SetState(c, "joined")
		end
		if c and b then c.station = b end
		return
	end

	if kind == "BLK" then
		if not mine and DR.Blacklist then DR.Blacklist(a, b or "", true, c3) end
		return
	elseif kind == "UBL" then
		if not mine and DR.Unblacklist then DR.Unblacklist(a, true) end
		return
	elseif kind == "DROP" then
		if key and DR.units[key] then DR.ignored[key] = true end
		if c then DR.Remove(c, "drop") end
		return
	elseif kind == "ST" then
		applyState(c, key, mine, a, b, c3, d, e, f, W.Int(h), blank(i))
		if g and not mine then
			c = DR.Find(a)
			if c then c.station = g end
		end
		return
	elseif kind == "PAID" then
		applyPaid(c, key, from, mine, a, b, c3, now)
		return
	elseif kind == "IOU" then
		-- 2.3.0 (SPEC7 5.8): the raincheck book's facts (Drive.Raincheck)
		if DR.RaincheckFact then DR.RaincheckFact(from, mine, a, b, c3, d, e, f) end
		return
	end

	if not c then return end

	if kind == "CAST" then
		-- b: the summoner without Wuber whose cast a crew window saw (SPEC4 1.1)
		c.caster, c.castAt, c.endSeen = namedCaster(b) or from, now, nil
		c.tries = (c.tries or 0) + 1
		c.priority, c.helps, c.awayAt, c.called, c.calledAt = nil, nil, nil, nil, nil
		if RANK[c.state] < RANK.arrived then DR.SetState(c, "summoning") end
		ritual(c, "c", { mine = mine })
		-- the portal call only at the station the summon is cast at (several stations)
		local here = not (c.station and DR.MultiStation and DR.MultiStation() and DR.MyStation)
			or W.SamePlace(DR.MyStation() or "", c.station)
		if (not mine or c.caster ~= myKey()) and open() and here and c.caster ~= myKey() then
			DR.Alert("Click the summoning portal - " .. W.Short(c.name) .. " is on the way!", "portal")
		end
	elseif kind == "END" then
		-- (H24-12) a late END (the rider's state already moved on) is still counted, once per cast
		local live = c.state == "summoning"
		local late = not live and c.castAt and not c.endSeen and now - c.castAt <= LATE_END
		if live or late then
			c.endSeen = now
			if late then
				if b == "1" then c.endAt = c.endAt or now end
			elseif b == "1" then
				c.endAt = now
				DR.SetState(c, "waiting")
			else
				DR.SetState(c, "joined")
			end
			ritual(c, b == "1" and "s" or "f", { mine = mine })
		end
	elseif kind == "HELP" then
		-- b (2.3.0, SPEC7 5.5): a helper without Wuber the caster's (or the network driver's)
		-- window saw hold the portal; believed only during that rider's summon, for a group member
		local hk = from
		-- (H24-12) still this summon for a few seconds after its END, so a late HELP counts in every window
		local inSummon = c.state == "summoning" or (c.castAt ~= nil and c.endSeen ~= nil and now - c.endSeen <= LATE_HELP)
		if b then
			hk = W.Key(b)
			if not (hk and inSummon and (from == c.caster or DR.IsLeaderKey(from)) and DR.units[hk]
				and hk ~= c.key and hk ~= c.caster) then return end
		end
		local fresh = not (c.helps and c.helps[hk])
		c.helps = c.helps or {}
		c.helps[hk] = true
		if not b then
			DR.helpSeen = true
			o().helpSeen = W.Build()
		end
		if fresh and inSummon and hk ~= c.caster then
			local n = 0
			for k in pairs(c.helps) do if k ~= c.caster then n = n + 1 end end
			ritual(c, "h", { mine = mine, helper = hk, helperName = b or (DR.units[hk] and W.UnitName(DR.units[hk])) or nil, tapped = n })
		end
	elseif kind == "GR" then
		c.greeted = true
		ritual(c, "t", { mine = mine })
	elseif kind == "THX" then
		c.thanked = true
		if c.state == "paid" then
			c.doneAt = now
			DR.SetState(c, "done")
		end
	end
	DR.Changed()
end

---------------------------------------------------------------------------
-- The place a rider asked for (BRIEF18, 20 Nov 00:50: the author hearthed from Undercity to Orgrimmar
-- while open; two riders for Undercity stayed queued and were invited, to be summoned to Orgrimmar)
---------------------------------------------------------------------------

DR.PLACE_SETTLE = 3 -- seconds a new place must hold before riders for the old one go (a zone line, a loading screen)
DR.MOVED_TTL = 300  -- how long a rider dropped for a place we left is no rider when they join (their invite was out)
-- [key] = { name, key, from, to, movedTo, at, told }: riders dropped for a place we left; told = false: the
-- sorry whisper is owed (Drive.Chat's DR.Pending, kind "moved"; only the big button's click sends it)
DR.moved = DR.moved or {}

-- Hearthstone, Astral Recall and the Mage teleports: casting one, this window is about to leave.
local TRAVEL = { [8690] = true, [556] = true, [3561] = true, [3562] = true, [3563] = true, [3565] = true, [3566] = true,
	[3567] = true }

-- Whether this window is casting a hearth or a teleport (UnitCastingInfo; a secret value counts as no).
function DR.Travelling()
	if type(UnitCastingInfo) ~= "function" then return false end
	local ok, name, _, _, _, _, _, _, a8, a9 = pcall(UnitCastingInfo, "player")
	if not ok then return false end
	local id = W.Num(a9) or W.Num(a8)
	if id and TRAVEL[id] then return true end
	name = str(name)
	name = name and name:lower()
	return name ~= nil and (name == "hearthstone" or name == "astral recall" or name:find("^teleport:") ~= nil)
end

-- Where this window takes riders now: { place names }, or nil while it is not known (a loading
-- screen). Several stations: the open ones; else the place set by hand, else the station.
function DR.ServedPlaces()
	local list = DR.Stations and DR.Stations() or {}
	if DR.MultiStation and DR.MultiStation() then
		local out = {}
		for _, st in ipairs(list) do if st.open and str(st.place) then out[#out + 1] = st.place end end
		return #out > 0 and out or nil
	end
	-- (no station yet - a crew Warlock's HI on its way - is "not known", never "somewhere else")
	local first
	for _, st in ipairs(list) do if st.open then first = st break end end
	local d = str(DR.char().dest) or (first and str(first.place))
	if not d or d == "Unknown" then return nil end
	return { d }
end

-- Whether a rider's request is for a place this window serves (a rider without one: yes).
-- served: DR.ServedPlaces() (nil: not known, yes); want: the place to test (else the rider's).
function DR.PlaceOK(c, served, want)
	if type(c) ~= "table" then return true end
	want = want or (DR.MultiStation and DR.MultiStation() and c.station) or c.forPlace
	if not want then return true end
	served = served or DR.ServedPlaces()
	if not served then return true end
	for _, p in ipairs(served) do
		if samePlace(want, p) then return true end
	end
	return false
end

-- A rider for a place we left who was neither summoned nor paid (those are never dropped).
function DR.PlaceStale(c, served)
	if type(c) ~= "table" or not c.forPlace then return false end
	local s = c.state
	-- (a joined rider whose summon failed, tries >= 1, was not summoned either)
	if not (s == "queued" or s == "invited" or s == "joined") then return false end
	if (c.paid or 0) > 0 or c.prepaid or c.voucher or c.cameWith then return false end
	return not DR.PlaceOK(c, served)
end

-- (BRIEF18, lead review #1) A Warlock who typed a place (Settings, /wuber drive dest) and stood there,
-- then left it (a hearth, a flight): they summon where they stand now, not to the typed place, and
-- the console says so. Not with several stations or another chosen summoner (the place is theirs).
local follow = { at = nil }
local function followMe()
	local ch = DR.char()
	local d = str(ch.dest)
	if not d or d == "" or not DR.IsWarlock() or multi() then
		follow.at = nil
		return false
	end
	local here = DR.PlaceOf("player")
	if not here then return false end -- a loading screen
	if samePlace(here, d) then
		follow.at = d
		return false
	end
	if follow.at ~= d then return false end
	follow.at = nil
	for _, k in ipairs(DR.Summoners and DR.Summoners() or {}) do
		if k ~= myKey() then return false end
	end
	ch.dest = ""
	DR.Alert("You left " .. d .. ": you summon to " .. here .. " now, where you stand.", "info")
	if DR.SendConfig then DR.SendConfig() end
	W.Fire("SETTINGS", "dest")
	DR.Changed()
	return true
end

-- (BRIEF18 b) Riders for a place we left go, once the new place has held DR.PLACE_SETTLE seconds
-- (force: at once - Close/Open, a place set by hand). Only the window that invites decides (the
-- others hear DROP). A rider we told something (an invite, a whisper) is owed the sorry whisper;
-- one in the group stays there, ignored. Returns how many went.
function DR.PlaceSweep(force)
	if not DR.db or not DR.on or DR.Role() ~= "driver" then return 0 end
	if W.InGroup() and not DR.IsLeader() then return 0 end
	if DR.Mode and DR.Mode() == "raid" then return 0 end
	followMe()
	local served = DR.ServedPlaces()
	if not served then return 0 end
	local t, n = GetTime(), 0
	local several = multi()
	for _, c in ipairs(DR.Sorted()) do
		local s = c.state
		-- (BRIEF18) a request made while the place was not known: for the place we serve now
		if not c.forPlace and (s == "queued" or s == "invited" or s == "joined") then
			c.forPlace = (several and c.station) or served[1]
		end
		if s == "queued" and not askOK(c) then
			-- (00:53) asked for a place we don't serve (read before we knew ours): a lead, not invited
			c.state, c.askedFor, c.askFor, c.heardBy = "lead", c.askFor, nil, c.heardBy or myKey()
			W.Fire("DRIVE_STATE", c, "queued")
			if W.InGroup() then DR.Send("DROP", c.name) end
			DR.Changed()
		elseif DR.PlaceStale(c, served) then
			c.placeOffAt = c.placeOffAt or t
			if force or t - c.placeOffAt >= DR.PLACE_SETTLE then
				local told = c.state ~= "queued" or c.greeted or c.priceTold or c.offerTold or c.whereTold or c.busyTold
				local speaks = c.heardBy == nil or c.heardBy == myKey()
				local from = (DR.MultiStation and DR.MultiStation() and c.station) or c.forPlace
				-- several stations: "Undercity and Orgrimmar", not one picked at random
				local to = several and DR.PlacesText and DR.PlacesText() or served[1]
				DR.moved[c.key] = { name = c.name, key = c.key, from = from, to = served[1], movedTo = to, at = t,
					told = not (told and speaks), invited = c.state == "invited" }
				if DR.units[c.key] then DR.ignored[c.key] = true end
				if W.InGroup() then DR.Send("DROP", c.name) end
				DR.Remove(c, "moved")
				n = n + 1
			end
		else
			c.placeOffAt = nil
		end
	end
	for k, m in pairs(DR.moved) do
		if t - (m.at or t) > DR.MOVED_TTL then DR.moved[k] = nil end
	end
	return n
end

---------------------------------------------------------------------------
-- Once a second: the riders' clocks (DR.Tick in Drive_Service calls this)
---------------------------------------------------------------------------

-- (d4 g) A rider still waiting (joined, never summoned by us, nothing paid, no trade) who was seen away
-- and now stands here: arrived another way. Starts the hold clock (c.hereSince). Only the window that
-- leads decides. One who was already beside us when listed (a test summon, a friend) is left be: that
-- row says "is here (no ride)" as before.
DR.WALK_HOLD = 4
function DR.ArrivedAnotherWay(c, now)
	if c.state ~= "joined" or not c.farSeen or (c.tries or 0) > 0 or c.caster or c.prepaid or c.voucher or c.cameWith then return false end
	if (c.paid or 0) > 0 or c.tradeAt or c.boxed or c.priority then return false end
	if DR.Role() ~= "driver" or (W.InGroup() and not DR.IsLeader()) then return false end
	c.hereSince = c.hereSince or now
	return true
end

function DR.QueueTick(now)
	local opts = o()
	DR.PlaceSweep()
	for key, c in pairs(DR.customers) do
		local unit = DR.units[key]
		local state, age = c.state, now - (c.at or now)
		if state == "lead" then
			if c.cameWith then
				if not unit then DR.Remove(c, "left") end
			elseif age > DR.LEAD_TTL then
				DR.Remove(c, "expired")
			end
		elseif state == "queued" then
			if age > DR.QUEUE_TTL then DR.Remove(c, "expired") end
		elseif state == "invited" then
			if now - (c.invitedAt or c.at) > (opts.inviteTimeout or 90) then
				DR.Remove(c, "timeout")
				DR.inviteMisses = (DR.inviteMisses or 0) + 1
				if DR.inviteMisses == 3 then
					DR.Alert("Three invites in a row went unanswered. If those players never saw one, invite by hand (/invite Name): they still become riders.", "info")
				end
			end
		elseif state == "joined" or state == "summoning" or state == "waiting" then
			local hereNow = unit and (DR.ArrivedAt and DR.ArrivedAt(c, unit) or (not DR.ArrivedAt and DR.Here(unit)))
			if unit and not hereNow then c.farSeen, c.hereSince = true, nil end
			if hereNow and DR.ArrivedAnotherWay(c, now) then
				-- (d4 g) came by foot or another summon: held for DR.WALK_HOLD, then the row goes as a hand removal does
				if now - c.hereSince >= DR.WALK_HOLD then DR.Do("DROP", c.name) end
			elseif hereNow then
				c.hereSince = nil
				if (c.tries or 0) == 0 then c.walked = true end
				c.arrivedAt = now
				DR.SetState(c, "arrived")
				if c.prepaid and c.state == "arrived" then
					-- 2.3.0 (SPEC7 5.8): paid by trade before arriving: paid now
					c.prepaid = nil
					DR.session.rides = DR.session.rides + 1
					DR.SetState(c, "paid")
				end
			elseif state == "summoning" and (now - (c.castAt or c.at or now) > DR.CAST_TTL
				or (DR.ClaimGone and DR.ClaimGone(c.caster, now))) then
				DR.SetState(c, "joined") -- (review 2.2 #4: also when the caster left or went silent)
			elseif state == "waiting" and now - (c.endAt or c.at or now) > DR.WAIT_TTL then
				DR.SetState(c, "joined")
			elseif state == "joined" and opts.awayGuard and not c.awayAt and age > DR.AWAY_AFTER
				and now - (DR.driverActAt or 0) > DR.AWAY_AFTER and (not unit or DR.Online(unit))
				and DR.IsLeader() and DR.Role() == "driver" and not (DR.IsPaused and DR.IsPaused()) then
				-- a rider waits 4 minutes and nobody summons: the driver is away
				c.awayAt = now
				if DR.SetPaused then DR.SetPaused(true) end
				DR.Alert("Paused: " .. W.Short(c.name) .. " waited 4 minutes for a summon. Resume when you're back.", "away")
			end
		elseif state == "paid" then
			if c.gone and (c.thanked or age > 120) then DR.Remove(c, "done") end
		elseif state == "done" then
			if not unit then DR.Remove(c, "done") end
		end
	end
end

