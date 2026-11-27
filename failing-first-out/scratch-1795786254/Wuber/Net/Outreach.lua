-- Module: Net.Outreach
-- Purpose: Adverts in public chat ([Wuber] lines, W.AdvertPlan, W.HeardChatLine); no community
--   invites (forbidden in this client since round 12: CX.tickInvites is a no-op).
-- API: W.ADVERT_TAG, W.ADVERT_GAP, W.ADVERT_CHANNELS, W.net.advertsHeard, W.net.advertsPosted,
--   W.AdvertText, W.ChannelBase, W.AdvertChannel, W.AdvertWait, W.AdvertWords,
--   W.AdvertOwnText, W.AdvertPlan, W.AdvertPosted, W.HeardChatLine, W.NetStatus,
--   W.NetStatusLines, CX.tickInvites, NETK.{ADVERT_MAX}
-- Internals: (none)
-- Uses: Net.Base, Net.Community, Net.Favourites, Net.Discovery
-- Later: (none)
-- Events: listens On CHAT_MSG_CHANNEL, On CHAT_MSG_SAY, On CHAT_MSG_YELL; fires ADVERT
-- Standalone: no
-- Test: tests/net/outreach_test.lua
-- From: Net.lua 3852-4225 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Adverts in public chat
---------------------------------------------------------------------------
-- A driver may post ONE public line when he goes online (Settings "Post an advert when I go
-- online") or with the Drive tab's Advertise pill - only by his own click on a secure macro
-- button (UI.lua), never in combat, at most once per 15 min:
--   "[Wuber] Selling summons to Undercity, 50s. Pay after you land. /w me or use my Wuber addon (on curse), you can also set it up and become a driver"
-- In: a line with the tag "[Wuber]" (any case) in a public channel, /say or /yell makes its
-- sender a name to ask (an unconfirmed name, or a known driver asked again soon): we whisper
-- a Q within the usual caps and list him only when he answers with his own D. The line
-- itself is never shown. Lines without the tag (other summoners, mage portals) are ignored:
-- only Wuber drivers appear in Wuber. Chat channels are faction-bound already.
-- A line with the word "wuber" in any form but no tag ("Wuber", "wuber's", "wuberaddon") is only a
-- MENTION: its sender (never a name inside the text) gets ONE hidden addon-whisper Q, so a driver
-- on another Forever layer who answers with his own D is listed (addon whispers cross layers). A
-- mention never counts as an advert (no unconfirmed name, no ADVERT event, no invite), is kept in
-- session memory only and is held back by NETK.MENTION_* (one Q per name per hour, 12 an hour, one
-- per 10 s, 5 waiting, none in the first minute, in combat, in a raid, in an instance or on a ride).

local _, W = ...
local Mod = W.Module("Net.Outreach", { "Net.Base", "Net.Community", "Net.Favourites", "Net.Discovery" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local FavouritesMod = W.Mod("Net.Favourites")
local DiscoveryMod = W.Mod("Net.Discovery")
local BeaconsMod = W.Mod("Net.Beacons")
local NETK, address, call, fb, isOurChannel = BaseMod.NETK, BaseMod.address, BaseMod.call, BaseMod.fb, BaseMod.isOurChannel
local localInt, myKey, now, seenList = BaseMod.localInt, BaseMod.myKey, BaseMod.now, BaseMod.seenList
local CX, comm = CommunityMod.CX, CommunityMod.comm
local db = FavouritesMod.db
local goodName, round, sendMentionQ = DiscoveryMod.goodName, DiscoveryMod.round, DiscoveryMod.sendMentionQ
local amFounder = W.AmFounder
local plain, str, num = W.Plain, W.Str, W.Num

do
W.ADVERT_TAG = "[Wuber]"
W.ADVERT_GAP = 900
NETK.ADVERT_MAX = 200
local ADVERT_CHANNELS = { "services", "trade", "lookingforgroup", "general" }
W.ADVERT_CHANNELS = ADVERT_CHANNELS
W.net.advertsHeard = 0  -- tagged lines heard this session
W.net.advertsPosted = 0

local DEFAULT_TAIL = ". Pay after you land. /w me or use my Wuber addon (on curse), you can also set it up and become a driver"
local DEFAULT_TAIL_PATTERN = DEFAULT_TAIL:gsub("%p", "%%%0")

-- The advert line for a dest and price (copper): at most 200 bytes, no links or codes.
function W.AdvertText(dest, price)
	local d = W.CleanDest(dest)
	local p = W.ExactPlace and W.ExactPlace(d)
	if p then d = p.name end
	price = math.max(W.MIN_PRICE, localInt(price) or W.MIN_PRICE)
	local head
	if d ~= "" and d ~= "Unknown" then
		head = "Selling summons to " .. d .. ", " .. W.Money(price)
	else
		head = "Selling summons, " .. W.Money(price)
	end
	return W.Clean(W.ADVERT_TAG .. " " .. head .. DEFAULT_TAIL, NETK.ADVERT_MAX)
end

-- "2. Trade - City" / "Trade - City" / "Trade" -> "trade"; "Trade (Services) - City" -> "services".
local function channelBase(name)
	local n = str(name)
	if not n then return nil end
	n = n:lower():gsub("^%d+%.%s*", "")
	if n:find("^trade %(services%)") then return "services" end
	return n:match("^(%a+)")
end
W.ChannelBase = channelBase

local function pack(...) return { n = select("#", ...), ... } end

-- Where an advert goes: Services when joined and in a capital, else Trade, else
-- LookingForGroup, else General (by name, through GetChannelList / GetChannelName, guarded).
-- Returns index, name, base; nil when none is joined.
function W.AdvertChannel()
	local found = {}
	local function note(id, name, disabled)
		id = num(id)
		if not id or id <= 0 or plain(disabled) == true then return end
		local base = channelBase(name)
		if base and not found[base] then found[base] = { index = id, name = str(name) or base } end
	end
	local listed = false
	if type(GetChannelList) == "function" then
		local res = pack(pcall(GetChannelList))
		if res[1] then
			listed = true
			for i = 2, res.n, 3 do note(res[i], res[i + 1], res[i + 2]) end
		end
	end
	-- GetChannelName has no disabled flag: ask it only when the list is missing or failed
	if not listed and next(found) == nil and type(GetChannelName) == "function" then
		for i = 1, 10 do
			local ok, id, name = pcall(GetChannelName, i)
			if ok then note(id, name) end
		end
	end
	local capital = false
	if found.services then
		local okd, _, place = pcall(W.DestHere)
		capital = okd and type(place) == "table" and place.kind == "city"
	end
	for _, base in ipairs(ADVERT_CHANNELS) do
		local c = found[base]
		if c and (base ~= "services" or capital) then return c.index, c.name, base end
	end
	return nil
end

-- Seconds until the next advert may go (0: now).
function W.AdvertWait()
	local t = num(call(time))
	local at = num(db().advertAt)
	local left = 0
	if at and t then
		if at > t + 60 then db().advertAt = t at = t end -- the clock went back a lot: start again
		left = W.ADVERT_GAP - (t - at)
	end
	local s = W.net.advertNow
	if s then left = math.max(left, W.ADVERT_GAP - (now() - s)) end
	return math.max(0, math.floor(left + 0.5))
end

-- The driver's own advert line (2.0, the driver engine's "My advert line"): the tag always
-- first, no links or codes, at most 200 bytes. Returns the line, or nil and why ("text":
-- nothing left; "spam" and W.SpamReason's reason). A short word like "a" or "I" is fine in a
-- sentence: only W.SpamReason's "letters" rule is not applied to whole lines.
-- An advert line without what Wuber filled in (for the spam check): the player's guild name,
-- the service name and money amounts ("1000g", "5g 25s", "80s") taken out.
local function escapePattern(x) return (x:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
function W.AdvertWords(text)
	local t = tostring(text or "")
	local cut = {}
	if type(GetGuildInfo) == "function" then
		local ok, g = pcall(GetGuildInfo, "player")
		cut[#cut + 1] = ok and str(g) or nil
	end
	local DRv = W.Drive
	if type(DRv) == "table" and type(DRv.ServiceName) == "function" then
		local ok, sname = pcall(DRv.ServiceName)
		cut[#cut + 1] = ok and str(sname) or nil
	end
	for _, c in ipairs(cut) do
		if #c >= 2 then
			-- any case: "<Gold Diggers>" and "gold diggers" both go
			local pat = escapePattern(c):gsub("%a", function(ch) return "[" .. ch:lower() .. ch:upper() .. "]" end)
			t = t:gsub(pat, " ")
		end
	end
	t = t:gsub("%f[%w]%d+%s*[gsc]%f[%W]", " ")
	return t
end

function W.AdvertOwnText(text)
	local t = W.Clean(plain(text) or "", 400)
	local low = t:lower()
	local tag = W.ADVERT_TAG:lower()
	while low:sub(1, #tag) == tag do
		t = t:sub(#tag + 1):gsub("^%s+", "")
		low = t:lower()
	end
	if t == "" then return nil, "text" end
	-- (playtest) Wuber's own default line says "Selling summons ... Pay after you land": the word filter is for the
	-- driver's own words, so the fixed words of the default pass, and only its place and fare are checked
	local dest, fare = t:match("^Selling summons to (.-), ([%w ]+)" .. DEFAULT_TAIL_PATTERN .. "$")
	if not dest then fare = t:match("^Selling summons, ([%w ]+)" .. DEFAULT_TAIL_PATTERN .. "$") end
	if fare and not (W.SentenceSpam and W.SentenceSpam((dest or "") .. " " .. fare)) then
		return W.Clean(W.ADVERT_TAG .. " " .. t, NETK.ADVERT_MAX + #W.ADVERT_TAG + 1)
	end
	-- (the spam check reads the driver's own words, not what Wuber
	-- filled in: the guild's name, the service name and the fare never trip it)
	local why = W.SentenceSpam and W.SentenceSpam(W.AdvertWords(t), true)
	if why and why ~= "letters" then return nil, "spam", why end
	-- the editor's limit counts the driver's own words; the tag and its space go in front on top of it
	return W.Clean(W.ADVERT_TAG .. " " .. t, NETK.ADVERT_MAX + #W.ADVERT_TAG + 1)
end

-- A joined channel by its number: index, name, base; nil when that number is not joined.
local function channelByIndex(index)
	index = localInt(index)
	if not index or index <= 0 or type(GetChannelName) ~= "function" then return nil end
	local ok, id, name = pcall(GetChannelName, index)
	id = ok and num(id) or nil
	if not id or id <= 0 then return nil end
	name = str(name)
	if not name or isOurChannel(name) then return nil end
	return id, name, channelBase(name) or name
end

-- What a click would post now: { macro = "/2 [Wuber] ...", text, channel, index, base }, or
-- nil and why: "combat", "wait" (and the seconds left), "channel" (none joined), "text",
-- "spam" (and W.SpamReason's reason). opts (2.0, optional): text = the driver's own line
-- (W.AdvertOwnText: tag added, spam-checked); channel = a channel number to post in (the
-- engine picks the joined advert channel posted to longest ago); a number that is not
-- joined falls back to W.AdvertChannel().
function W.AdvertPlan(dest, price, opts)
	if W.InCombat() then return nil, "combat" end
	local own = W.DriverBeacon()
	if own and own.only then return nil, "test" end -- the test addon's test mode: never in public
	local wait = W.AdvertWait()
	if wait > 0 then return nil, "wait", wait end
	opts = type(opts) == "table" and opts or {}
	local idx, cname, base
	if opts.channel ~= nil then idx, cname, base = channelByIndex(opts.channel) end
	if not idx then idx, cname, base = W.AdvertChannel() end
	if not idx then return nil, "channel" end
	local text
	if opts.text ~= nil and opts.text ~= "" then
		local why, reason
		text, why, reason = W.AdvertOwnText(opts.text)
		if not text then return nil, why, reason end
	else
		text = W.AdvertText(dest, price)
	end
	if text == "" or text:find("[|\r\n]") then return nil, "text" end
	return { macro = "/" .. idx .. " " .. text, text = text, channel = cname, index = idx, base = base }
end

-- The secure button posted plan's line: starts the 15 min wait. Fires "ADVERT" ("posted",
-- channel, text).
function W.AdvertPosted(plan)
	if type(plan) ~= "table" then return false end
	db().advertAt = num(call(time))
	W.net.advertNow = now()
	W.net.advertsPosted = W.net.advertsPosted + 1
	W.Debug("advert", "posted in " .. tostring(plan.channel) .. ": " .. tostring(plan.text))
	W.Fire("ADVERT", "posted", plan.channel, plan.text)
	return true
end

-- The mention path (see the header): session memory only, nothing saved.
local mentionAt, mentionSent, mentionPending, mentionDue = {}, {}, 0, 0

-- Multibox (#244): the player's own windows (crew, captain, own accounts) together send ONE Q per name per hour.
-- (1) An own character is never pinged. (2) The hour is also kept in the saved variables, so a /reload or relog of a
-- window does not open a second Q. (3) Among the own windows this one has heard of (a hello or a beacon, on this version
-- or newer), the lowest number made from the name's and the window's keys has the turn, so only one of them asks (no
-- new message). A window that hears no other own window asks by itself.
local function ownKey(key)
	local DR = W.Drive
	if type(DR) ~= "table" then return false end
	if type(DR.IsCrewKey) == "function" and DR.IsCrewKey(key) then return true end
	if type(DR.BookOwn) == "function" and DR.BookOwn(key) then return true end
	return false
end

local function mentionScore(askerKey, windowKey)
	local s = askerKey .. "|" .. windowKey
	local h = 7
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return h
end

local function mentionTurn(key)
	local DR = W.Drive
	if type(DR) ~= "table" or type(DR.char) ~= "function" then return true end
	local ch = DR.char()
	if type(ch) ~= "table" then return true end
	local names = {}
	if type(ch.captain) == "string" and ch.captain ~= "" then names[#names + 1] = ch.captain end
	for _, m in ipairs(type(ch.crew) == "table" and ch.crew or {}) do
		if type(m) == "table" and m.name and m.app ~= false then names[#names + 1] = m.name end
	end
	local me = myKey()
	local mine = str(W.VERSION) and W.VERSION:match("^%d+%.%d+%.%d+")
	local best, bestScore = me, mentionScore(key, me)
	local function seen(k)
		local app = type(DR.apps) == "table" and k and DR.apps[k] or nil
		local d = k and W.drivers and W.drivers[k] or nil
		local ver = (app and app.version) or (type(d) == "table" and d.ver) or nil
		local v = ver and tostring(ver):match("^%d+%.%d+%.%d+")
		local cmp = v and mine and W.CompareVersions and W.CompareVersions(v, mine)
		return cmp == 0 or cmp == 1
	end
	-- a crew member leaves it to a captain whose beacon it sees but who has not said hello (not grouped: the captain cannot see the members)
	if type(ch.captain) == "string" and ch.captain ~= "" then
		local ck = W.Key(ch.captain)
		local heldByHello = type(DR.apps) == "table" and ck and DR.apps[ck] ~= nil
		if ck and ck ~= me and not heldByHello and seen(ck) then return false end
	end
	for _, n in ipairs(names) do
		local k = W.Key(n)
		local app = type(DR.apps) == "table" and k and DR.apps[k] or nil
		local d = k and W.drivers and W.drivers[k] or nil
		local ver = (app and app.version) or (type(d) == "table" and d.ver) or nil
		local v = ver and tostring(ver):match("^%d+%.%d+%.%d+")
		local cmp = v and mine and W.CompareVersions and W.CompareVersions(v, mine)
		if k and k ~= me and (cmp == 0 or cmp == 1) then
			local sc = mentionScore(key, k)
			if sc < bestScore or (sc == bestScore and k < best) then best, bestScore = k, sc end
		end
	end
	return best == me
end

local function mentionStamps(create)
	if type(W.db) ~= "table" then return nil end
	if type(W.db.mentioned) ~= "table" then
		if not create then return nil end
		W.db.mentioned = {}
	end
	return W.db.mentioned
end

local function wall() return num(type(time) == "function" and time() or 0) or 0 end

local function mentionedRecently(key)
	local s = mentionStamps(false)
	local at = s and num(s[key])
	return at ~= nil and math.abs(wall() - at) < NETK.MENTION_GAP
end

local function mentionStamp(key)
	local s = mentionStamps(true)
	if not s then return end
	local w, n = wall(), 0
	for k, v in pairs(s) do
		if math.abs(w - (num(v) or 0)) >= NETK.MENTION_GAP then s[k] = nil else n = n + 1 end
	end
	if n < 200 then s[key] = w end
end

-- Everything that must hold for a mention Q, at queue time and again at send time.
local function mentionBlocked(key, t)
	if W.net.cantSend or W.InCombat() or W.InInstance() then return true end
	if type(IsInRaid) == "function" and plain(IsInRaid()) == true then return true end
	if W.RideActive and W.RideActive() then return true end
	if W.IsHidden(key) or W.drivers[key] or ownKey(key) then return true end
	if mentionedRecently(key) then return true end
	local off = fb.offlineUntil[key]
	if off and t < off then return true end
	return false
end

local function mentionHeard(sender, chanName, chanBase)
	if isOurChannel(chanName) or isOurChannel(chanBase) then return end
	local name = goodName(W.CleanName(address(sender)))
	local key = name and W.Key(name)
	if not key or key == myKey() or key == "?" then return end
	if W.CREATOR[key] and not W.OnFounderRuleset() then return end
	local t = now()
	if not round.loginAt or t - round.loginAt < NETK.MENTION_QUIET then return end
	if mentionAt[key] and t - mentionAt[key] < NETK.MENTION_GAP then return end
	if not mentionTurn(key) then return end
	if mentionPending >= NETK.MENTION_QUEUE or mentionBlocked(key, t) then return end
	for i = #mentionSent, 1, -1 do
		if t - mentionSent[i] >= 3600 then table.remove(mentionSent, i) end
	end
	if #mentionSent + mentionPending >= NETK.MENTION_CAP then return end
	mentionAt[key] = t
	mentionPending = mentionPending + 1
	mentionDue = math.max(t + 3 + math.random() * 12, mentionDue + NETK.MENTION_STEP)
	W.After(mentionDue - t, function()
		mentionPending = mentionPending - 1
		local t2 = now()
		for i = #mentionSent, 1, -1 do
			if t2 - mentionSent[i] >= 3600 then table.remove(mentionSent, i) end
		end
		if #mentionSent >= NETK.MENTION_CAP or mentionBlocked(key, t2) then return end
		if sendMentionQ(key, name) then
			mentionSent[#mentionSent + 1] = t2
			mentionStamp(key)
		end
	end)
end

-- A public chat line (CHAT_MSG_CHANNEL, _SAY, _YELL). Returns the sender's key when it
-- carried the tag and was taken.
local function heardChatLine(text, sender, chanName, chanBase)
	text = str(text)
	if not text then return nil end
	local low = text:lower()
	if not low:find("[wuber]", 1, true) then
		if low:find("wuber", 1, true) then mentionHeard(sender, chanName, chanBase) end
		return nil
	end
	if isOurChannel(chanName) or isOurChannel(chanBase) then return nil end
	local name = goodName(W.CleanName(address(sender)))
	local key = name and W.Key(name)
	if not key or key == myKey() or key == "?" then return nil end
	if W.CREATOR[key] and not W.OnFounderRuleset() then return nil end
	local t = now()
	W.net.advertsHeard = W.net.advertsHeard + 1
	local where = str(chanBase) or str(chanName) or "chat"
	local prev = fb.advertHeard[key]
	fb.advertHeard[key] = { name = name, at = t, channel = where, confirmed = prev and prev.confirmed or nil }
	if not prev or t - prev.at >= 60 then W.Fire("ADVERT", "heard", name, where, text) end
	if W.drivers[key] or W.IsHidden(key) then return key end
	local rej = fb.rejected[key]
	if rej and t - rej < NETK.GOSSIP_FRESH then return key end
	fb.offlineUntil[key] = nil -- he is on now, whatever "No player named" said before
	if not W.CREATOR[key] and not W.IsKeptKnown(key) and not fb.unconfirmed[key] then
		local n = 0
		for _ in pairs(fb.unconfirmed) do n = n + 1 end
		if n < (amFounder() and NETK.UNCONFIRMED_FOUNDER or NETK.UNCONFIRMED_MAX) then
			fb.unconfirmed[key] = { key = key, name = name, at = t, from = "chat", tries = 0 }
		end
	end
	if not round.confirmAt then round.confirmAt = t + 1 + math.random() end
	return key
end
W.HeardChatLine = heardChatLine

W.On("CHAT_MSG_CHANNEL", function(text, sender, _, chanName, _, _, _, _, chanBase)
	heardChatLine(text, sender, chanName, chanBase)
end)
W.On("CHAT_MSG_SAY", function(text, sender) heardChatLine(text, sender, nil, "say") end)
W.On("CHAT_MSG_YELL", function(text, sender) heardChatLine(text, sender, nil, "yell") end)
end -- adverts

-- The network as /wuber status tells it: "Network: channel joined, 3 drivers by whisper."
function W.NetStatus()
	local idx = W.ChannelIndex()
	local n = W.net.byWhisper or 0
	local by = n == 1 and "1 driver by whisper" or (n .. " drivers by whisper")
	if idx then
		if n > 0 then return "Network: channel joined, " .. by .. "." end
		return "Network: joined (channel " .. idx .. ")."
	end
	if n > 0 then return "Network: channel not joined, " .. by .. "." end
	return "Network: not joined. Requests still work by whisper."
end

-- For /wuber status, as many lines as before (old subcommands print nothing new): the
-- network line, then "Drivers online: 2 (Anita Lift: CAMWOW EU4 Realm 7, by whisper; ...)."
-- with each driver's internal realm and how we hear them (at most 6 named).
function W.NetStatusLines()
	local net = W.NetStatus()
	if W.net.cantSend then net = net .. " This account can't send addon messages: listening only." end
	local list, parts = W.DriversSorted(), {}
	for i, d in ipairs(list) do
		if i > 6 then
			parts[#parts + 1] = "..."
			break
		end
		parts[#parts + 1] = tostring(d.name) .. ": " .. (d.realm or "realm unknown") .. ", "
			.. (d.via == "WHISPER" and "by whisper" or (d.viaComm and "in the community" or "on the channel"))
	end
	local drivers = "Drivers online: " .. #list .. (#parts > 0 and (" (" .. table.concat(parts, "; ") .. ")") or "") .. "."
	local adverts = W.net.advertsHeard or 0
	drivers = drivers .. " [Wuber] adverts heard: " .. adverts .. "."
	-- the community and the ruleset on the network line (old subcommands print no more lines than before)
	return { net .. " " .. W.CommunityStatus() .. " Ruleset: " .. (W.Ruleset() or "unknown") .. ".", drivers }
end

---------------------------------------------------------------------------
-- The founder's community invites: gone (round 12)
---------------------------------------------------------------------------
-- This client forbids C_Club.SendCharacterInvitation to addons (the "only available to the
-- Blizzard UI" popup), so Wuber sends no community invites at all; the founder's team invites
-- from Guild & Communities (J) by hand. Saved W.db.community.invited/times are left as they are.
-- CX.tickInvites stays (Net.Inbox calls it every second): it does nothing.
function CX.tickInvites() return false end
