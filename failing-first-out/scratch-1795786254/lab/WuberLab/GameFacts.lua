-- Wuber Lab (developer only, never ship): GameFacts.lua - "does the real game do X?", answered by the game itself.
--
-- Answers the open questions of the 2.4 work (LAB-CHECKS-WANTED L1..L16, B-16, B-18) with no typing:
--   PASSIVE   start by themselves at login or on their event, cheap, stop by themselves:
--             L7 spellbook after login, L6 summoner name, L1 summon state (in a group, out of combat),
--             L3 chat lock (reading), L5 channel, L12 names and GUID shapes, L13 blocked actions and input style,
--             L15 chat font again once Wuber's window has been shown
--   INSTANT   one press of the Lab bar's "Game facts" (/lab facts), and by themselves when an Auto check ends:
--             L10 send result codes, L15 chat font, L16 realm facts, blank or cut labels, and a summary of the rest
--   MOMENT    the panel that "Game facts" opens: one button per check that needs the player at the right moment
--             (L4, L3 send, L8, L14 twice, "Can I remove?", "Flight map facts")
-- Not built: L2, L9, L11. L17, L18, L19, the Mailbox check and more of L13 and L16 are in GameFacts2.lua (job 134b).
--
-- Every answer is saved in WuberLabDB.facts[id] = a list (at most 50 entries) of { t, build, line, a = answers }
-- and one short line goes to the Lab log (kind "facts"). Never chat text, never another player's name: only shapes
-- (length, has a space, has a realm tail), prefixes, booleans and numbers. Every game call is guarded (a missing call
-- is recorded as "no such call"), runs under pcall, and every value is tested with issecretvalue first ("secret").
-- Nothing protected is called in combat. Exports: L.GameFacts (G), L.GameFactsInstant(why), L.GameFactsSlash(rest).
-- Panel.lua's /lab facts calls the slash; AutoCheck.lua calls the instant part at the end of a run.

local _, L = ...

local G = {}
L.GameFacts = G

local secret, str, num, plain = L.IsSecret, L.str, L.num, L.plain
local NOCALL, CAP, PREFIX = "no such call", 50, "WuberLabT"
local S = { enteredAt = nil, lastCast = nil, whispers = 0 } -- this session's state

-- Nothing of the passive part exists at load (Wuber's own tests load the Lab on every branch and count its frames, events
-- and timers): onP / listenP only COLLECT the wiring, G.StartPassive() makes it. It runs at login when the saved
-- WuberLabDB.factsOn is set, and from the first press of "Game facts".
local PASSIVE = {}
local function onP(event, fn) PASSIVE[#PASSIVE + 1] = { event = event, fn = fn } end
local function listenP(fn) PASSIVE[#PASSIVE + 1] = { listen = fn } end

-- the ids, in the order of the summary: { id, title, kind, what is said while there is no answer }
G.IDS = {
	{ "L7", "Spellbook after login", "passive", "not seen yet (a Warlock, in the 12 seconds after login)" },
	{ "L6", "Summoner name", "passive", "no summon seen yet" },
	{ "L1", "Summon state", "passive", "no change seen yet (needs a group)" },
	{ "L1.table", "C_IncomingSummon", "passive", "not in a group yet" },
	{ "L3.read", "Chat lock (reading)", "passive", "no loading screen or boss seen yet" },
	{ "L5", "Wuber channel", "passive", "not read yet (20 seconds after login)" },
	{ "L5.notice", "Channel notices", "passive", "no notice yet" },
	{ "L12.self", "Player name shapes", "passive", "not read yet (5 seconds after login)" },
	{ "L12.whisper", "Whisper name and GUID", "passive", "no whisper yet" },
	{ "L13.style", "Input style", "passive", "not read yet" },
	{ "L13.blocked", "Blocked actions", "passive", "none seen this session" },
	{ "L15.wuber", "Chat font after Wuber's window", "passive", "Wuber's window not shown yet" },
	{ "L10", "Send result codes", "instant" },
	{ "L15", "Chat font", "instant" },
	{ "L16", "Realm facts", "instant" },
	{ "LBL", "Blank or cut labels", "instant" },
	{ "L4", "Right after loading", "moment" },
	{ "L3.send", "Chat lock send", "moment" },
	{ "L8", "Mounted click", "moment" },
	{ "L14.wuber", "Map opened by Wuber", "moment" },
	{ "L14.safe", "Map opened the safe way", "moment" },
	{ "B18", "Can I remove?", "moment" },
	{ "B16", "Flight map facts", "moment" },
	{ "LINE", "Test lines sent", "moment" },
	{ "LINE.reply", "Reply whisper shape", "moment" },
}

---------------------------------------------------------------------------
-- Guarded game calls
---------------------------------------------------------------------------

local function pack(...) return { n = select("#", ...), ... } end

-- ask(fn, ...): the results ({ n = count, [1..n] }), or nil plus "no such call" / "error" / "secret".
local function ask(fn, ...)
	if type(fn) ~= "function" then return nil, NOCALL end
	local r = pack(pcall(fn, ...))
	if not r[1] then return nil, "error" end
	local out = { n = r.n - 1 }
	for i = 2, r.n do
		if secret(r[i]) then return nil, "secret" end
		out[i - 1] = r[i]
	end
	return out
end
G.ask = ask

-- val(fn, ...): the first result (a boolean, number or string), or "nil", "no such call", "error", "secret".
local function val(fn, ...)
	local r, e = ask(fn, ...)
	if not r then return e end
	if r[1] == nil then return "nil" end
	return r[1]
end

-- a method of an object (frame, region): its first result, or nil when missing, secret or failed
local function m(o, k, ...)
	local f = type(o) == "table" and o[k] or nil
	if type(f) ~= "function" then return nil end
	local r = ask(f, o, ...)
	return r and r[1]
end

local function gfn(name) return rawget(_G, name) end
local function tfn(tname, name)
	local t = rawget(_G, tname)
	return type(t) == "table" and t[name] or nil
end

local function shortc(s, n) s = tostring(s or ""); return s:sub(1, n or 60) end

local function nameShape(s)
	if type(s) ~= "string" then return tostring(s) end
	return { len = #s, space = s:find(" ", 1, true) ~= nil, realmTail = s:find("-", 1, true) ~= nil }
end

local function round1(x) return math.floor(x * 10 + 0.5) / 10 end
local function since(t) return t and round1(L.Now() - t) or nil end

local function buildText()
	local r = ask(gfn("GetBuildInfo"))
	if not r then return "?" end
	return tostring(r[1]) .. " (" .. tostring(r[2]) .. ")"
end

local function inInstance()
	local r, e = ask(gfn("IsInInstance"))
	if not r then return e end
	return r[1] == true, type(r[2]) == "string" and r[2] or nil
end

local function ticker(delay, fn) return L.Every(delay, fn) end
local function stop(t) if t and type(t.Cancel) == "function" then pcall(t.Cancel, t) end end

---------------------------------------------------------------------------
-- Saving: WuberLabDB.facts[id] (a list, at most 50), one log line
---------------------------------------------------------------------------

local function store()
	local d = L.db
	if type(d) ~= "table" then return nil end
	if type(d.facts) ~= "table" then d.facts = {} end
	return d.facts
end

-- G.Put(id, line, answers, replace, quiet): adds an entry (or replaces the list); returns the entry so a
-- watcher can fill it in later. quiet: no log line (another part of the lab already logged it).
function G.Put(id, line, a, replace, quiet)
	local f = store()
	if not f then return nil end
	local list = f[id]
	if type(list) ~= "table" or replace then
		list = {}
		f[id] = list
	end
	local e = { t = math.floor(L.Epoch and L.Epoch() or 0), build = buildText(), line = shortc(line, 320), a = a or {} }
	list[#list + 1] = e
	while #list > CAP do table.remove(list, 1) end
	if not quiet then L.Log("facts", id .. ": " .. e.line) end
	return e
end

function G.Newest(id)
	local f = L.db and L.db.facts
	local list = type(f) == "table" and f[id] or nil
	if type(list) ~= "table" or #list == 0 then return nil, 0 end
	return list[#list], #list
end

-- the answers of every check, as short lines (the summary of the Game facts press)
function G.Summary()
	local out = {}
	for _, row in ipairs(G.IDS) do
		local e, n = G.Newest(row[1])
		local text
		if e then text = tostring(e.line) .. (n > 1 and (" [" .. n .. " entries]") or "")
		elseif row[1] == "L7" and S.midSession then text = "answers at your next login or Reload"
		elseif row[3] == "passive" then text = row[4] or "not seen yet"
		else text = "not run yet" end
		out[#out + 1] = row[1] .. " " .. row[2] .. ": " .. text
	end
	return out
end

---------------------------------------------------------------------------
-- Blocked actions: Hooks.lua already logs ADDON_ACTION_BLOCKED / _FORBIDDEN (kind "block"); this listens to its line
---------------------------------------------------------------------------

local watchers = {} -- the map and remove checks: { entry =, untilT = } ; blocked actions are copied into them

local function blockedLine(kind, text)
	if kind ~= "block" or type(text) ~= "string" then return end
	local ev, addon, func = text:match("^(ADDON_ACTION_%u+) addon=(%S+) func=(%S+)")
	if not ev then return end
	local item = { event = ev, addon = shortc(addon, 40), func = shortc(func, 60), combat = text:find("combat=true", 1, true) ~= nil }
	local e = S.blocked
	if not e then
		e = G.Put("L13.blocked", "blocked actions this session: 0", { count = 0, list = {} }, false, true)
		S.blocked = e
	end
	if e then
		e.a.count = (e.a.count or 0) + 1
		if #e.a.list < 20 then e.a.list[#e.a.list + 1] = item end
		e.line = "blocked actions this session: " .. e.a.count .. " (last: " .. item.event:gsub("ADDON_ACTION_", "") .. " " .. item.addon .. " " .. item.func .. ")"
	end
	local now = L.Now()
	for _, w in ipairs(watchers) do
		if w.entry and w.untilT and now <= w.untilT then
			w.entry.a.blockedCount = (w.entry.a.blockedCount or 0) + 1
			if #w.entry.a.blocked < 20 then w.entry.a.blocked[#w.entry.a.blocked + 1] = item end
		end
	end
end
listenP(function(kind, text) pcall(blockedLine, kind, text) end)

---------------------------------------------------------------------------
-- PASSIVE
---------------------------------------------------------------------------

-- L7: the Warlock summoning spell after login, each second for 12 s (the id is the one Wuber asks for)
local function ritualId()
	local W = L.W()
	local d = W and type(W.Drive) == "table" and W.Drive or nil
	local id = d and num(d.RITUAL_ID)
	return id or 698, id and "Wuber" or "default"
end

local function spellbook()
	local class = ask(gfn("UnitClass"), "player")
	local token = class and class[2]
	if token ~= "WARLOCK" then
		G.Put("L7", "not a Warlock: not asked", { skipped = true, class = type(token) == "string" and token or "?" })
		return
	end
	local id, src = ritualId()
	local t0 = L.Now()
	local first, noCall, secs = {}, {}, 0
	local names = { "IsPlayerSpell", "IsSpellKnown", "C_Spell.GetSpellInfo" }
	local function look()
		local at = math.floor(L.Now() - t0 + 0.5)
		local got = {
			IsPlayerSpell = val(gfn("IsPlayerSpell"), id),
			IsSpellKnown = val(gfn("IsSpellKnown"), id),
			["C_Spell.GetSpellInfo"] = val(tfn("C_Spell", "GetSpellInfo"), id),
		}
		for _, n in ipairs(names) do
			local v = got[n]
			if v == NOCALL then noCall[n] = true
			elseif first[n] == nil and (v == true or (n == "C_Spell.GetSpellInfo" and type(v) == "table")) then first[n] = at end
		end
		return at
	end
	look()
	local tk
	tk = ticker(1, function()
		secs = secs + 1
		look()
		if secs >= 12 then
			stop(tk)
			local a, parts = { id = id, idFrom = src, firstYes = {}, noCall = {} }, {}
			for _, n in ipairs(names) do
				a.firstYes[n] = noCall[n] and NOCALL or (first[n] or "never")
				parts[#parts + 1] = n .. " " .. (noCall[n] and NOCALL or (first[n] and ("yes at " .. first[n] .. " s") or "never in 12 s"))
			end
			G.Put("L7", "ritual " .. id .. ": " .. table.concat(parts, "; "), a)
		end
	end)
end

-- L6: at every CONFIRM_SUMMON, ask the summoner's name every 100 ms for 5 s
onP("CONFIRM_SUMMON", function()
	if S.sum then S.sum.dead = true end
	local run = { t0 = L.Now() }
	S.sum = run
	local function finish(result, a)
		if run.dead then return end
		run.dead = true
		stop(run.tk)
		a = a or {}
		a.result = result
		local ms = a.ms and (a.ms .. " ms") or ""
		G.Put("L6", "summoner name: " .. result .. (ms ~= "" and (" after " .. ms) or ""), a)
	end
	local function look()
		if run.dead then return end
		local ms = math.floor((L.Now() - run.t0) * 1000 + 0.5)
		local fns = { { "C_SummonInfo", tfn("C_SummonInfo", "GetSummonConfirmSummoner") }, { "global", gfn("GetSummonConfirmSummoner") } }
		local any = false
		for _, f in ipairs(fns) do
			if f[2] then
				any = true
				local r, e = ask(f[2])
				if e == "secret" then return finish("secret", { ms = ms, via = f[1] }) end
				if r and type(r[1]) == "string" and r[1] ~= "" then
					return finish("name", { ms = ms, via = f[1], name = nameShape(r[1]) })
				end
			end
		end
		if not any then return finish(NOCALL) end
		if ms >= 5000 then finish("never", { ms = ms }) end
	end
	look()
	if not run.dead then run.tk = ticker(0.1, look) end
end)

-- L1: C_IncomingSummon, every 5 s while in a group and out of combat; only changes are saved
local function groupUnits()
	local list = { "player" }
	local raid = val(gfn("IsInRaid")) == true
	if raid then
		for i = 1, 40 do list[#list + 1] = "raid" .. i end
	else
		for i = 1, 4 do list[#list + 1] = "party" .. i end
	end
	return list
end

local function summonTick()
	if L.InCombat() then return end
	local tb = rawget(_G, "C_IncomingSummon")
	if type(tb) ~= "table" then
		if not S.l1none then
			S.l1none = true
			G.Put("L1", "C_IncomingSummon: " .. NOCALL, { noCall = true })
			G.Put("L1.table", "C_IncomingSummon: " .. NOCALL, { noCall = true }, true)
		end
		stop(S.l1tk)
		S.l1tk = nil
		return
	end
	if not S.l1keys then
		local keys = {}
		for k in pairs(tb) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		S.l1keys = keys
		G.Put("L1.table", "C_IncomingSummon has " .. #keys .. " entries: " .. table.concat(keys, ", "), { keys = keys }, true)
	end
	local inst = inInstance()
	for _, u in ipairs(groupUnits()) do
		if val(gfn("UnitExists"), u) == true then
			local st = val(tb.IncomingSummonStatus, u)
			local has = tb.HasIncomingSummon and val(tb.HasIncomingSummon, u) or nil
			local sig = tostring(st) .. "/" .. tostring(has)
			local old = S.l1last and S.l1last[u]
			if not S.l1last then S.l1last = {} end
			S.l1last[u] = sig
			local quiet = (st == 0 or st == "nil" or st == false) and (has == nil or has == false or has == "nil")
			if (old == nil and not quiet) or (old ~= nil and old ~= sig) then
				G.Put("L1", "unit " .. u .. ": status " .. tostring(st) .. (has ~= nil and (", has " .. tostring(has)) or "") ..
					(old and (" (was " .. old .. ")") or "") .. ", " .. (S.lastCast and (since(S.lastCast) .. " s after your last cast") or "no cast yet") ..
					", " .. (inst == true and "in an instance" or "not in an instance"),
					{ unit = u, status = st, has = has, was = old, sinceCast = since(S.lastCast), instance = inst })
			end
		end
	end
end

local function groupChanged()
	local inGroup = val(gfn("IsInGroup")) == true
	if inGroup and not S.l1tk then
		S.l1tk = ticker(5, summonTick)
		summonTick()
	elseif not inGroup and S.l1tk then
		stop(S.l1tk)
		S.l1tk = nil
		S.l1last = nil
	end
end
onP("GROUP_ROSTER_UPDATE", groupChanged)

-- the player's own casts. Through the Lab's own event frame (L.On), never a frame of this file's: a frame made at load
-- would move every later frame's number in the behaviour transcript of Wuber's lab tests, on every branch.
for _, ev in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
	local event = ev
	onP(event, function(unit, a2, a3, a4)
		if plain(unit) ~= "player" then return end
		if event == "UNIT_SPELLCAST_SUCCEEDED" then S.lastCast = L.Now() end
		local spell = event == "UNIT_SPELLCAST_SENT" and num(a4) or num(a3)
		if S.castHook then pcall(S.castHook, event, spell) end
	end)
end

-- L3 (reading): the chat lock at a boss, at every loading screen
local function lockdown()
	return val(tfn("C_ChatInfo", "InChatMessagingLockdown"))
end
local function netNow()
	local W = L.W()
	local n = W and type(W.net) == "table" and W.net or nil
	if not n then return nil end
	return { sent = num(n.sent), failed = num(n.failed), dropped = num(n.dropped) }
end
local function chatLockRead(event)
	local inst, kind = inInstance()
	local a = { event = event, lockdown = lockdown(), instance = inst, instType = kind, net = netNow() }
	local e = G.Put("L3.read", event .. ": chat lockdown " .. tostring(a.lockdown) .. ", " .. (inst == true and ("in an instance (" .. tostring(kind) .. ")") or "not in an instance"), a)
	-- Wuber's own sends cannot be read without a second wrapper on the send (Hooks.lua only post-hooks it, which has no
	-- result): the counts of what Wuber sent or failed to send in the next 6 s stand in for the result code
	if e and a.net then
		L.After(6, function()
			local n2 = netNow()
			if not n2 then return end
			e.a.after = { sent = (n2.sent or 0) - (a.net.sent or 0), failed = (n2.failed or 0) - (a.net.failed or 0), dropped = (n2.dropped or 0) - (a.net.dropped or 0) }
			e.line = e.line .. "; Wuber sent " .. e.a.after.sent .. ", failed " .. e.a.after.failed .. " in 6 s"
		end)
	end
end
onP("ENCOUNTER_START", function() chatLockRead("ENCOUNTER_START") end)
onP("ENCOUNTER_END", function() chatLockRead("ENCOUNTER_END") end)
onP("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
	S.enteredAt = L.Now()
	chatLockRead("PLAYER_ENTERING_WORLD")
	-- (job 144) "Right after loading" by itself: the first loading screen of a session that is not the login or a Reload
	-- (a summon, a zone, a boat) sends the ten test messages to yourself at once, so nobody has to press a button within
	-- a second of it. Once a session; the panel's button still does it by hand.
	if isLogin == false and isReload == false and not S.l4Auto then
		S.l4Auto = true
		L.After(0.2, function() pcall(G.L4) end)
	end
end)

-- L5: the Wuber channel: slot, how many channels, owner; and every notice word for it
local function channelName()
	local W = L.W()
	return (W and str(W.CHANNEL)) or "WuberNet"
end

local function channelFacts()
	local name = channelName()
	local r, e = ask(gfn("GetChannelName"), name)
	local a = { channels = L.ChannelCount() }
	if not r then
		a.slot = e
	else
		a.slot = num(r[1]) or r[1]
	end
	local slot = type(a.slot) == "number" and a.slot > 0 and a.slot or nil
	if slot then
		local roster = gfn("GetChannelRosterInfo")
		if type(roster) ~= "function" then
			a.owner = NOCALL
		else
			local me = ask(gfn("UnitName"), "player")
			me = me and me[1]
			local rows, ownerIsMe, ownerSeen = 0, false, false
			for i = 1, 200 do
				local row, err = ask(roster, slot, i)
				if not row then a.owner = err; break end
				if type(row[1]) ~= "string" then break end
				rows = rows + 1
				if row[2] == true then
					ownerSeen = true
					if me and row[1]:match("^([^%-]+)") == me then ownerIsMe = true end
				end
			end
			a.members = rows
			if not a.owner then a.owner = ownerSeen and (ownerIsMe and "this character" or "someone else") or "none shown" end
		end
	end
	G.Put("L5", "channel " .. name .. ": slot " .. tostring(a.slot) .. " of " .. tostring(a.channels) .. " channels; owner " .. tostring(a.owner), a)
end

local function notice(kind)
	return function(text, _, _, chan, _, _, _, idx, base)
		local want = channelName():lower()
		local c, b = str(chan), str(base)
		local match = (b and b:lower() == want) or (c and c:lower():find(want, 1, true))
		if not match then return end
		local w = str(text)
		w = (w and #w <= 40 and w:match("^[%w_]+$")) and w or "other"
		local e = S.notice
		if not e then
			e = G.Put("L5.notice", "channel notices: 0", { words = {} })
			S.notice = e
		end
		if e then
			local key = kind .. ":" .. w
			e.a.words[key] = (e.a.words[key] or 0) + 1
			local parts = {}
			for k, v in pairs(e.a.words) do parts[#parts + 1] = k .. " x" .. v end
			table.sort(parts)
			e.line = "channel notices: " .. table.concat(parts, ", ")
		end
	end
end
onP("CHAT_MSG_CHANNEL_NOTICE", notice("NOTICE"))
onP("CHAT_MSG_CHANNEL_NOTICE_USER", notice("NOTICE_USER"))

-- L12: names and the GUID, as shapes
local function guidShape(g)
	if type(g) ~= "string" then return tostring(g) end
	return { prefix = g:match("^(%a+)%-") or "?", len = #g }
end

local function selfNames()
	local a = {}
	local un = ask(gfn("UnitName"), "player")
	if un then a.UnitName = { name = nameShape(un[1]), realmGiven = type(un[2]) == "string" and un[2] ~= "" } else a.UnitName = select(2, ask(gfn("UnitName"), "player")) end
	local uf = ask(gfn("UnitFullName"), "player")
	if uf then a.UnitFullName = { name = nameShape(uf[1]), realmGiven = type(uf[2]) == "string" and uf[2] ~= "" } else a.UnitFullName = select(2, ask(gfn("UnitFullName"), "player")) end
	local gu = ask(gfn("GetUnitName"), "player", true)
	if gu then a.GetUnitName = nameShape(gu[1]) else a.GetUnitName = select(2, ask(gfn("GetUnitName"), "player", true)) end
	local gg = ask(gfn("UnitGUID"), "player")
	if gg then a.UnitGUID = guidShape(gg[1]) else a.UnitGUID = select(2, ask(gfn("UnitGUID"), "player")) end
	local function s(v) return type(v) == "table" and ("len " .. tostring(v.len) .. (v.realmTail and " +realm" or "") .. (v.space and " space" or "")) or tostring(v) end
	G.Put("L12.self", "UnitName " .. s(a.UnitName and a.UnitName.name or a.UnitName) .. "; UnitFullName " .. s(a.UnitFullName and a.UnitFullName.name or a.UnitFullName) ..
		"; GetUnitName(,true) " .. s(a.GetUnitName) .. "; GUID " .. (type(a.UnitGUID) == "table" and a.UnitGUID.prefix or tostring(a.UnitGUID)), a)
end

local UNITS = { "player", "target", "mouseover", "focus", "party1", "party2", "party3", "party4" }
onP("CHAT_MSG_WHISPER", function(text, sender, _, _, _, _, _, _, _, _, _, guid)
	if S.whispers >= 3 then return end
	S.whispers = S.whispers + 1
	local a = { n = S.whispers }
	if secret(sender) then a.sender = "secret"
	elseif type(sender) == "string" then a.sender = nameShape(sender) else a.sender = tostring(type(sender)) end
	if secret(guid) then a.guid = "secret"
	elseif type(guid) == "string" then a.guid = guidShape(guid) else a.guid = tostring(type(guid)) end
	a.textSecret = secret(text) or nil
	if type(sender) == "string" and not secret(sender) and type(guid) == "string" and not secret(guid) then
		local base = sender:match("^([^%-]+)")
		a.unitFound, a.guidEqual = false, nil
		for _, u in ipairs(UNITS) do
			local nm = ask(gfn("UnitName"), u)
			if nm and nm[1] == base then
				local g = ask(gfn("UnitGUID"), u)
				a.unitFound = true
				a.guidEqual = g ~= nil and g[1] == guid
				break
			end
		end
	end
	local sh = type(a.sender) == "table" and ("len " .. a.sender.len .. (a.sender.realmTail and " +realm" or "") .. (a.sender.space and " space" or "")) or tostring(a.sender)
	G.Put("L12.whisper", "whisper " .. a.n .. ": sender " .. sh .. "; GUID " .. (type(a.guid) == "table" and a.guid.prefix or tostring(a.guid)) ..
		"; " .. (a.unitFound and ("same as the unit's GUID: " .. tostring(a.guidEqual)) or "no unit of that sender to compare"), a)
end)

-- L13: the input style at login (blocked actions: above)
local function inputStyle()
	local a = {}
	a.GetCurrentStyle = val(tfn("C_InputInterfaceStyle", "GetCurrentStyle"))
	local cv = tfn("C_CVar", "GetCVar") or gfn("GetCVar")
	a.cvar = val(cv, "InputDeviceInterfaceStyle")
	local en = rawget(_G, "Enum")
	local t = type(en) == "table" and en.InputDeviceInterfaceType or nil
	if type(t) == "table" then
		a.enum = {}
		for k, v in pairs(t) do if type(k) == "string" and type(v) == "number" then a.enum[k] = v end end
	else
		a.enum = NOCALL
	end
	G.Put("L13.style", "input style " .. tostring(a.GetCurrentStyle) .. ", CVar " .. tostring(a.cvar), a)
end

-- L15 (after Wuber's window): the chat box font again, once per session, when Wuber's window is first shown
local function chatFont()
	local cb = gfn("ChatFrame1EditBox")
	if type(cb) ~= "table" then return nil, NOCALL end
	local r, e = ask(cb.GetFont, cb)
	if not r then return nil, e end
	return { file = r[1], size = r[2], flags = r[3] }
end
G.chatFont = chatFont

local function wuberShown()
	local f = rawget(_G, "WuberFrame")
	return type(f) == "table" and m(f, "IsShown") == true
end

local function watchWuberWindow()
	if S.wuberSeen or not wuberShown() then return end
	S.wuberSeen = true
	local f, e = chatFont()
	local before = S.fontBefore
	local same = f and before and f.file == before.file and f.size == before.size and f.flags == before.flags
	G.Put("L15.wuber", "chat box font after Wuber's window was shown: " .. (f and (tostring(f.file) .. " " .. tostring(f.size)) or tostring(e)) ..
		(before and (same and " (the same)" or " (CHANGED)") or " (no earlier reading)"), { font = f or e, before = before, same = same })
end

---------------------------------------------------------------------------
-- Login: start the passive checks
---------------------------------------------------------------------------

-- G.StartPassive(pressed): wires every passive event and starts the login checks; safe to call twice (the second call does
-- nothing). pressed: switched on in the middle of a session, so the checks that wait for a login run at once (L12.self,
-- L13.style, the group, L5 with its 20 s counted from now) and L7, which needs the login, answers at the next login.
function G.StartPassive(pressed)
	if S.started then return false end
	S.started = true
	for _, p in ipairs(PASSIVE) do
		if p.listen then L.listeners[#L.listeners + 1] = p.listen else L.On(p.event, p.fn) end
	end
	local ci = rawget(_G, "C_ChatInfo")
	local reg = type(ci) == "table" and ci.RegisterAddonMessagePrefix or gfn("RegisterAddonMessagePrefix")
	ask(reg, PREFIX)
	S.loginAt = L.Now()
	S.fontBefore = (chatFont())
	if pressed then
		S.midSession = true
		inputStyle()
		groupChanged()
		selfNames()
	else
		spellbook()
		inputStyle()
		L.After(3, groupChanged)
		L.After(5, selfNames)
	end
	L.After(20, channelFacts)
	ticker(10, function() pcall(watchWuberWindow) end)
	return true
end

-- the first press: the flag is saved, so every later login starts the passive checks by itself
function G.Press()
	local d = L.db
	local first = type(d) == "table" and d.factsOn ~= true
	if first then d.factsOn = true end
	local started = G.StartPassive(true)
	if first or started then S.announce = true end
	return started
end

-- at login: only when the saved flag is set. (Registering this function adds an entry to a list, nothing else.)
L.OnLogin(function()
	if type(L.db) == "table" and L.db.factsOn == true then G.StartPassive(false) end
end)

---------------------------------------------------------------------------
-- INSTANT: the press of "Game facts", and the end of an Auto check
---------------------------------------------------------------------------

local function say(text)
	if L.Say then L.Say(text) else print(text) end
end

local function enumName(code)
	local en = rawget(_G, "Enum")
	local t = type(en) == "table" and en.SendAddonMessageResult or nil
	if type(t) ~= "table" then return nil end
	for k, v in pairs(t) do if v == code then return k end end
	return nil
end

-- L10: every entry of Enum.SendAddonMessageResult
local function sendResults()
	local en = rawget(_G, "Enum")
	local t = type(en) == "table" and en.SendAddonMessageResult or nil
	if type(t) ~= "table" then
		G.Put("L10", "Enum.SendAddonMessageResult: " .. NOCALL, { noCall = true }, true)
		return
	end
	local list, codes, parts = {}, {}, {}
	for k, v in pairs(t) do if type(k) == "string" and type(v) == "number" then list[#list + 1] = { k, v } end end
	table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
	for _, p in ipairs(list) do codes[p[1]] = p[2]; parts[#parts + 1] = p[2] .. "=" .. p[1] end
	G.Put("L10", #list .. " send result codes: " .. table.concat(parts, " "), { codes = codes }, true)
end

-- L15: the chat box font, and whether a bare EditBox shares its font object
local function chatFontNow()
	local f, e = chatFont()
	local a = { chat = f or e }
	local eb = S.eb
	if not eb then
		local ok, fr = pcall(gfn("CreateFrame"), "EditBox", nil, rawget(_G, "UIParent"))
		if ok and type(fr) == "table" then
			eb = fr
			pcall(eb.Hide, eb)
			pcall(eb.SetAutoFocus, eb, false)
			S.eb = eb
		end
	end
	local cb = gfn("ChatFrame1EditBox")
	if eb and type(cb) == "table" then
		local o1, o2 = ask(cb.GetFontObject, cb), ask(eb.GetFontObject, eb)
		if o1 and o2 and o1[1] ~= nil and o2[1] ~= nil then a.sameObject = (o1[1] == o2[1])
		else a.sameObject = "no font object to compare" end
		local own = ask(eb.GetFont, eb)
		a.bareBoxFont = own and { file = own[1], size = own[2], flags = own[3] } or "none"
	else
		a.sameObject = NOCALL
	end
	a.wuberShown = wuberShown()
	if a.wuberShown then
		local f2 = chatFont()
		a.afterWuber = f2 and { file = f2.file, size = f2.size, flags = f2.flags, same = f ~= nil and f2.file == f.file and f2.size == f.size } or "unreadable"
	else
		a.afterWuber = S.wuberSeen and "shown earlier: see L15.wuber" or "Wuber's window not shown"
	end
	G.Put("L15", "chat box font " .. (f and (tostring(f.file) .. " " .. tostring(f.size) .. " " .. tostring(f.flags)) or tostring(e)) ..
		"; bare EditBox shares the font object: " .. tostring(a.sameObject), a, true)
end

-- L16: realm facts
local function realmFacts()
	local a = {
		GetRealmName = val(gfn("GetRealmName")),
		GetNormalizedRealmName = val(gfn("GetNormalizedRealmName")),
		GetRealmID = val(gfn("GetRealmID")),
		GetCurrentRegion = val(gfn("GetCurrentRegion")),
		IsHardcoreActive = val(tfn("C_GameRules", "IsHardcoreActive")),
		IsWarModeActive = val(tfn("C_PvP", "IsWarModeActive")),
	}
	G.Put("L16", "realm " .. tostring(a.GetRealmName) .. " (" .. tostring(a.GetNormalizedRealmName) .. ", id " .. tostring(a.GetRealmID) .. "), region " ..
		tostring(a.GetCurrentRegion) .. ", hardcore " .. tostring(a.IsHardcoreActive) .. ", war mode " .. tostring(a.IsWarModeActive), a, true)
end

-- blank labels: every SHOWN Wuber frame's font strings with text that draw nothing, and every one the game says is cut
local function labelRoots()
	local out, seen = {}, {}
	local function add(f)
		if type(f) == "table" and not seen[f] and m(f, "IsShown") == true then seen[f] = true; out[#out + 1] = f end
	end
	add(rawget(_G, "WuberFrame"))
	for _, holder in ipairs({ rawget(_G, "UIParent") or false, rawget(_G, "Minimap") or false }) do
		if type(holder) == "table" and type(holder.GetChildren) == "function" then
			local kids = { pcall(holder.GetChildren, holder) }
			for i = 2, #kids do
				local nm = type(kids[i]) == "table" and str(m(kids[i], "GetName"))
				if nm and nm:find("^Wuber") and not nm:find("^WuberLab") and not nm:find("^WuberRec") and not nm:find("^WuberTest") then add(kids[i]) end
			end
		end
	end
	return out
end

local function frameLabel(f)
	local parts = {}
	local o = f
	for _ = 1, 4 do
		if type(o) ~= "table" then break end
		local nm = str(m(o, "GetName"))
		parts[#parts + 1] = nm or "?"
		if nm then break end
		o = m(o, "GetParent")
	end
	return shortc(table.concat(parts, "<"), 60)
end

local function scanLabels()
	local res = { blank = {}, cut = {}, texts = 0 }
	local seen, visited = {}, 0
	local function walk(f, depth)
		if type(f) ~= "table" or seen[f] or depth > 14 or visited > 4000 then return end
		seen[f] = true
		visited = visited + 1
		if m(f, "IsForbidden") == true or m(f, "IsShown") ~= true then return end
		local regs = { pcall(f.GetRegions, f) }
		for i = 2, #regs do
			local r = regs[i]
			if type(r) == "table" and m(r, "GetObjectType") == "FontString" and m(r, "IsShown") == true then
				local text = str(m(r, "GetText"))
				if text and text:find("%S") then
					res.texts = res.texts + 1
					local w, h, lines, hh = num(m(r, "GetStringWidth")), num(m(r, "GetStringHeight")), num(m(r, "GetNumLines")), num(m(r, "GetHeight"))
					local blank = (w ~= nil and w <= 0) or (h ~= nil and h <= 0) or (lines ~= nil and lines == 0) or (hh ~= nil and hh <= 0)
					local item = { f = frameLabel(f), t = shortc(text, 20) }
					if blank and #res.blank < 40 then res.blank[#res.blank + 1] = item end
					if m(r, "IsTruncated") == true and #res.cut < 40 then res.cut[#res.cut + 1] = item end
				end
			end
		end
		local kids = { pcall(f.GetChildren, f) }
		for i = 2, #kids do walk(kids[i], depth + 1) end
	end
	for _, f in ipairs(labelRoots()) do walk(f, 1) end
	return res
end
G.scanLabels = scanLabels

local function labels(done)
	local first = scanLabels()
	L.After(0.05, function()
		local later = scanLabels()
		local known = {}
		for _, it in ipairs(first.cut) do known[it.f .. "|" .. it.t] = true end
		local onlyLater = {}
		for _, it in ipairs(later.cut) do if not known[it.f .. "|" .. it.t] then onlyLater[#onlyLater + 1] = it end end
		G.Put("LBL", first.texts .. " texts on shown Wuber frames: " .. #first.blank .. " blank, " .. #first.cut .. " cut now, " .. #later.cut ..
			" cut a frame later (" .. #onlyLater .. " only later)", { texts = first.texts, blank = first.blank, cutNow = first.cut, cutLater = later.cut, cutOnlyLater = onlyLater,
			blankLater = #later.blank })
		if done then done() end
	end)
end

function G.Instant(why)
	if why == "auto" then
		if not (type(L.db) == "table" and L.db.factsOn == true) then return end -- an Auto check run alone does nothing here
	else
		G.Press()
	end
	pcall(sendResults)
	pcall(chatFontNow)
	pcall(realmFacts)
	local function report()
		if why == "auto" then return end
		if S.announce then
			S.announce = nil
			say("Passive checks are on from now on (saved).")
		end
		say("Game facts (what is known so far):")
		for _, l in ipairs(G.Summary()) do say(l) end
	end
	local ok = pcall(labels, report)
	if not ok then report() end
end
L.GameFactsInstant = G.Instant

---------------------------------------------------------------------------
-- NEEDS THE MOMENT
---------------------------------------------------------------------------

local function sender()
	return tfn("C_ChatInfo", "SendAddonMessage") or gfn("SendAddonMessage")
end

local function fullSelf()
	local r = ask(gfn("UnitFullName"), "player")
	local name, realm = r and r[1], r and r[2]
	if type(name) ~= "string" then return nil end
	if type(realm) ~= "string" or realm == "" then
		local rn = ask(gfn("GetNormalizedRealmName"))
		realm = rn and rn[1]
	end
	if type(realm) == "string" and realm ~= "" then return name .. "-" .. realm end
	return name
end

local function codeOf(r, e)
	if not r then return e end
	local v = r[1]
	if type(v) == "number" then return v end
	return tostring(v)
end

-- L4: ten addon messages to yourself, back to back
function G.L4()
	local send = sender()
	local full = fullSelf()
	if type(send) ~= "function" then G.Put("L4", "SendAddonMessage: " .. NOCALL, { noCall = true }); return end
	if not full then G.Put("L4", "own name unknown: nothing sent", {}); return end
	local codes, tally = {}, {}
	for i = 1, 10 do
		local r, e = ask(send, PREFIX, "L4 " .. i, "WHISPER", full)
		codes[i] = codeOf(r, e)
		local k = tostring(codes[i])
		tally[k] = (tally[k] or 0) + 1
	end
	local keys, parts = {}, {}
	for k in pairs(tally) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. (enumName(tonumber(k)) and ("(" .. enumName(tonumber(k)) .. ")") or "") .. " x" .. tally[k] end
	local sinceEnter = since(S.enteredAt)
	G.Put("L4", "10 whispers to yourself " .. (sinceEnter and (sinceEnter .. " s after the last loading screen") or "(no loading screen seen this session)") ..
		": " .. table.concat(parts, ", "), { codes = codes, tally = tally, sinceEnter = sinceEnter })
end

-- L3: one addon message to the party and its result code
function G.L3Send()
	local send = sender()
	if type(send) ~= "function" then G.Put("L3.send", "SendAddonMessage: " .. NOCALL, { noCall = true }); return end
	local r, e = ask(send, PREFIX, "L3", "PARTY")
	local code = codeOf(r, e)
	local inst, kind = inInstance()
	local a = { code = code, codeName = type(code) == "number" and enumName(code) or nil, lockdown = lockdown(), instance = inst, instType = kind,
		inGroup = val(gfn("IsInGroup")), combat = L.InCombat() }
	G.Put("L3.send", "party message: code " .. tostring(code) .. (a.codeName and (" (" .. a.codeName .. ")") or "") .. ", chat lockdown " .. tostring(a.lockdown) ..
		", " .. (inst == true and "in an instance" or "not in an instance") .. ", " .. (a.combat and "in combat" or "out of combat"), a)
end

-- L8: mounted click: watches casts and the dismount for 60 s (the big button is not hooked: a secure button)
function G.Mounted()
	if S.mount and not S.mount.done then say("Mounted click: already watching (60 seconds)"); return end
	local t0 = L.Now()
	local a = { mountedAtArm = val(gfn("IsMounted")), events = {} }
	local run = { done = false, mounted = a.mountedAtArm == true }
	S.mount = run
	local id = ritualId()
	local function words()
		local parts = {}
		for _, ev in ipairs(a.events) do parts[#parts + 1] = ev.what .. " at " .. ev.at .. " s" .. (ev.ritual and " (the ritual)" or "") end
		return "mounted at the start: " .. tostring(a.mountedAtArm) .. "; " .. (#parts > 0 and table.concat(parts, "; ") or "nothing seen yet")
	end
	run.e = G.Put("L8", "watching for 60 s: mounted " .. tostring(a.mountedAtArm), a)
	local function add(what, spell)
		if #a.events >= 14 then return end
		a.events[#a.events + 1] = { at = since(t0), what = what, ritual = (spell and spell == id) or nil }
		if run.e then run.e.line = shortc(words(), 320) end
	end
	local names = { UNIT_SPELLCAST_SENT = "cast sent", UNIT_SPELLCAST_START = "cast start", UNIT_SPELLCAST_CHANNEL_START = "channel start",
		UNIT_SPELLCAST_SUCCEEDED = "cast succeeded", UNIT_SPELLCAST_FAILED = "cast failed", UNIT_SPELLCAST_INTERRUPTED = "interrupted" }
	S.castHook = function(event, spell) if not run.done then add(names[event] or event, spell) end end
	run.tk = ticker(0.2, function()
		local now = val(gfn("IsMounted")) == true
		if run.mounted and not now then add("dismounted"); run.mounted = false
		elseif not run.mounted and now then add("mounted again"); run.mounted = true end
	end)
	L.After(60, function()
		run.done = true
		stop(run.tk)
		S.castHook = nil
		if run.e then run.e.line = shortc("(done) " .. words(), 320) end
		L.Log("facts", "L8: " .. (run.e and run.e.line or ""))
	end)
	say("Mounted click: watching for 60 seconds. Click Wuber's big button twice, a few seconds apart.")
end

-- L14: the world map opened by Wuber's way (ShowUIPanel) or the safe way (C_Map.OpenWorldMap); blocked actions for 3 minutes
function G.Map(how)
	local id = how == "wuber" and "L14.wuber" or "L14.safe"
	if L.InCombat() then say("Map check: leave combat first (the map is never opened in a fight)"); return end
	local map = rawget(_G, "WorldMapFrame")
	if type(map) ~= "table" then G.Put(id, "WorldMapFrame: " .. NOCALL, { noCall = true }); return end
	if m(map, "IsShown") == true then say("Map check: close the world map first, then press again"); return end
	local a = { how = how, blocked = {}, blockedCount = 0 }
	local via
	if how == "wuber" then
		local sp = gfn("ShowUIPanel")
		if type(sp) == "function" then
			pcall(sp, map)
			via = "ShowUIPanel"
			if m(map, "IsShown") ~= true then pcall(map.Show, map); via = "ShowUIPanel, then Show" end
		else
			pcall(map.Show, map)
			via = "Show"
		end
	else
		local f = tfn("C_Map", "OpenWorldMap")
		a.globalOpenWorldMap = type(gfn("OpenWorldMap")) == "function"
		if type(f) ~= "function" then
			a.result = NOCALL
			G.Put(id, "C_Map.OpenWorldMap: " .. NOCALL, a)
			return
		end
		local mid = val(tfn("C_Map", "GetBestMapForUnit"), "player")
		pcall(f, type(mid) == "number" and mid or nil)
		via = "C_Map.OpenWorldMap"
	end
	a.via = via
	a.opened = m(map, "IsShown") == true
	local e = G.Put(id, "opened via " .. via .. ": " .. (a.opened and "map is open" or "map did NOT open") .. "; watching 3 minutes for blocked actions", a)
	local w = { entry = e, untilT = L.Now() + 180 }
	watchers[#watchers + 1] = w
	L.After(1, function()
		if L.InCombat() then a.closed = "not closed (in combat)"; return end
		local hp = gfn("HideUIPanel")
		if type(hp) == "function" then pcall(hp, map) else pcall(map.Hide, map) end
		a.closed = m(map, "IsShown") ~= true
	end)
	L.After(181, function()
		for i = #watchers, 1, -1 do if watchers[i] == w then table.remove(watchers, i) end end
		if e then
			e.line = shortc("opened via " .. via .. ": " .. (a.opened and "map open" or "map did NOT open") .. "; blocked actions in 3 minutes: " .. a.blockedCount, 320)
			L.Log("facts", id .. ": " .. e.line)
		end
	end)
end

-- B-18 "Can I remove?": removes the TARGETED party member once, out of combat, and says removed or blocked
function G.Remove()
	if L.InCombat() then say("Can I remove? Leave combat first"); return end
	if val(gfn("UnitExists"), "target") ~= true or val(gfn("UnitIsPlayer"), "target") ~= true or val(gfn("UnitInParty"), "target") ~= true
		or val(gfn("UnitIsUnit"), "target", "player") == true then
		say("Can I remove? Target a player in your own party first (not yourself). Nothing was done.")
		return
	end
	local leader = val(gfn("UnitIsGroupLeader"), "player")
	if leader ~= true then
		say("Can I remove? You are not the party leader, so nothing was done.")
		G.Put("B18", "not the party leader: nothing was done", { leader = leader, called = "no" })
		return
	end
	local fn, via = tfn("C_PartyInfo", "UninviteUnit"), "C_PartyInfo.UninviteUnit"
	if type(fn) ~= "function" then fn, via = gfn("UninviteUnit"), "UninviteUnit" end
	if type(fn) ~= "function" then
		G.Put("B18", "UninviteUnit: " .. NOCALL, { noCall = true, leader = true })
		return
	end
	local nm = ask(gfn("GetUnitName"), "target", true)
	nm = nm and nm[1]
	if type(nm) ~= "string" then say("Can I remove? The target's name is hidden. Nothing was done."); return end
	local a = { leader = true, via = via, before = val(gfn("GetNumGroupMembers")), blocked = {}, blockedCount = 0 }
	local e = G.Put("B18", "called " .. via .. " once; waiting 2 seconds", a)
	local w = { entry = e, untilT = L.Now() + 3 }
	watchers[#watchers + 1] = w
	a.pcall = pcall(fn, nm)
	L.After(2, function()
		for i = #watchers, 1, -1 do if watchers[i] == w then table.remove(watchers, i) end end
		a.after = val(gfn("GetNumGroupMembers"))
		local verdict
		if a.blockedCount > 0 then verdict = "blocked"
		elseif type(a.before) == "number" and type(a.after) == "number" and a.after < a.before then verdict = "removed"
		else verdict = "no change (not blocked, not removed)" end
		a.verdict = verdict
		e.line = shortc(via .. ": " .. verdict .. "; group " .. tostring(a.before) .. " -> " .. tostring(a.after) .. "; blocked actions " .. a.blockedCount, 320)
		L.Log("facts", "B18: " .. e.line)
		say("Can I remove? " .. verdict)
	end)
end

-- B-16 "Flight map facts": the game's own flight buttons, their places, and the map's inner area
local function rect(o)
	if type(o) ~= "table" then return nil end
	local l, b, w, h = num(m(o, "GetLeft")), num(m(o, "GetBottom")), num(m(o, "GetWidth")), num(m(o, "GetHeight"))
	if not (l and b and w and h) then return nil end
	return { l = round1(l), b = round1(b), w = round1(w), h = round1(h) }
end

local function flightRead()
	local tf, fm = rawget(_G, "TaxiFrame"), rawget(_G, "FlightMapFrame")
	local route = rawget(_G, "TaxiRouteMap")
	local function state(o) if type(o) ~= "table" then return "absent" end return m(o, "IsShown") == true and "shown" or "hidden" end
	local a = { TaxiFrame = state(tf), TaxiRouteMap = state(route), FlightMapFrame = state(fm), buttons = 0, shown = 0, samples = {} }
	local area = (type(route) == "table" and route) or (type(tf) == "table" and tf) or (type(fm) == "table" and fm) or nil
	a.area = rect(area)
	a.frame = rect(type(tf) == "table" and tf or fm)
	for i = 1, 120 do
		local b = rawget(_G, "TaxiButton" .. i)
		if type(b) == "table" then
			a.buttons = a.buttons + 1
			if m(b, "IsShown") == true then
				a.shown = a.shown + 1
				if #a.samples < 5 then
					local c = ask(b.GetCenter, b)
					local sm = { i = i, w = num(m(b, "GetWidth")), h = num(m(b, "GetHeight")) }
					if c and num(c[1]) and num(c[2]) then
						sm.x, sm.y = round1(c[1]), round1(c[2])
						if a.area then
							sm.fx = math.floor((c[1] - a.area.l) / math.max(a.area.w, 1) * 1000 + 0.5) / 1000
							sm.fy = math.floor((c[2] - a.area.b) / math.max(a.area.h, 1) * 1000 + 0.5) / 1000
						end
					end
					a.samples[#a.samples + 1] = sm
				end
			end
		end
	end
	G.Put("B16", "TaxiFrame " .. a.TaxiFrame .. ", FlightMapFrame " .. a.FlightMapFrame .. "; " .. a.buttons .. " TaxiButtons (" .. a.shown ..
		" shown); inner area " .. (a.area and (a.area.w .. " x " .. a.area.h) or "unknown"), a)
end

function G.Flight()
	local tf, fm = rawget(_G, "TaxiFrame"), rawget(_G, "FlightMapFrame")
	if m(tf, "IsShown") == true or m(fm, "IsShown") == true then
		flightRead()
	else
		S.flightArm = L.Now() + 180
		say("Flight map facts: no flight map is open. Talk to a flight master within 3 minutes: it reads by itself.")
	end
end
onP("TAXIMAP_OPENED", function()
	-- (job 144) the first flight map of a session is read by itself (no button to press first); after that only within
	-- 3 minutes of a press
	local armed = S.flightArm and L.Now() <= S.flightArm
	if not armed and S.flightSeen then return end
	S.flightArm = nil
	S.flightSeen = true
	L.After(0.5, function() pcall(flightRead) end)
end)

---------------------------------------------------------------------------
-- The panel: one button per check that needs the moment (made when first opened)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Second account: test lines. One chat line (or one leave) from the button's own click, never from a timer.
-- Saved: WuberLabDB.facts["LINE"] = which button, the channel kind, "sent" or the error text (never a name or the line).
---------------------------------------------------------------------------

-- the last quoted "summon ..." part of a whisper this character received (memory only, never saved, nothing else kept).
-- Its one handler is registered when the panel is first opened (G.Open), not at load and not by the passive checks.
local function toldHandler(text, sender)
	text = plain(text)
	if type(text) ~= "string" then return end
	local q = text:match('[Ww][Hh][Ii][Ss][Pp][Ee][Rr]%s+[Mm][Ee]%s+"([Ss][Uu][Mm][Mm][Oo][Nn][^"]*)"')
	if not q then return end
	local nm = plain(sender)
	local sh = { hidden = true }
	if type(nm) == "string" then sh = { len = #nm, space = nm:find(" ", 1, true) ~= nil, hyphen = nm:find("-", 1, true) ~= nil } end
	S.told = { line = shortc(q, 100), at = L.Now(), sender = sh }
end

local function chatSender()
	local f = tfn("C_ChatInfo", "SendChatMessage")
	if type(f) == "function" then return f, "C_ChatInfo.SendChatMessage" end
	f = gfn("SendChatMessage")
	if type(f) == "function" then return f, "SendChatMessage" end
	return nil
end

-- the targeted friendly player as a whisper takes it ("First-Surname"), or nil plus the reason
local function whisperTarget()
	if val(gfn("UnitExists"), "target") ~= true then return nil, "target the driver first" end
	if val(gfn("UnitIsPlayer"), "target") ~= true then return nil, "your target is not a player" end
	if val(gfn("UnitIsUnit"), "target", "player") == true then return nil, "your target is yourself" end
	local fr = val(gfn("UnitIsFriend"), "player", "target")
	if fr ~= true and fr ~= NOCALL then return nil, "your target is not a friendly player" end
	local r = ask(gfn("UnitName"), "target")
	local first, sur = r and r[1], r and r[2]
	if type(first) ~= "string" or first == "" or first == "Unknown" then return nil, "the target's name is hidden" end
	local full = first
	if type(sur) == "string" and sur ~= "" then
		local c = rawget(_G, "Constants")
		local sc = type(c) == "table" and type(c.CharacterNameSeparatorConsts) == "table" and c.CharacterNameSeparatorConsts or nil
		local sep = sc and type(sc.CHARACTERNAME_SURNAME_SEPARATOR) == "string" and sc.CHARACTERNAME_SURNAME_SEPARATOR ~= "" and sc.CHARACTERNAME_SURNAME_SEPARATOR or " "
		full = first .. sep .. sur
	end
	return (full:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "-"))
end

local function placeName()
	local z = val(gfn("GetRealZoneText"))
	if type(z) == "string" and z ~= "" then return z end
	return nil
end

local function tradeChannel()
	local r = ask(gfn("GetChannelList"))
	if r then
		for i = 1, r.n, 3 do
			local id, name = r[i], r[i + 1]
			if type(id) == "number" and type(name) == "string" and name:lower():sub(1, 5) == "trade" then return id end
		end
	end
	for i = 1, 20 do
		local c = ask(gfn("GetChannelName"), i)
		if c and type(c[2]) == "string" and c[2]:lower():sub(1, 5) == "trade" and type(c[1]) == "number" and c[1] > 0 then return c[1] end
	end
	return nil
end

-- send one line: kind "SAY" / "WHISPER" / "CHANNEL"; target = whisper name or channel number. Returns the result word.
local function sendLine(button, kind, text, target)
	local fn, via = chatSender()
	local result
	if not fn then
		result = NOCALL
	else
		local ok, err = pcall(fn, text, kind, nil, target)
		if ok then result = "sent"
		else
			result = tostring(err)
			if type(target) == "string" and target ~= "" then result = result:gsub(target:gsub("%p", "%%%0"), "?") end
			result = shortc(result, 120)
		end
	end
	local a = { button = button, kind = kind, result = result, via = via }
	if result == "sent" then
		a.sinceLast = since(S.lastLine)
		S.lastLine = L.Now()
	end
	G.Put("LINE", button .. ": " .. kind .. " " .. result, a)
	say("Test line (" .. button .. "): " .. kind .. " " .. result)
	return result
end

local function lineGuard(button)
	if L.InCombat() then say(button .. ": leave combat first. Nothing was sent."); return false end
	return true
end

local function whisperLine(button, text)
	return function()
		if not lineGuard(button) then return end
		local who, why = whisperTarget()
		if not who then say(button .. ": " .. why .. ". Nothing was sent."); return end
		sendLine(button, "WHISPER", text, who)
	end
end

local function sayLine(button, make)
	return function()
		if not lineGuard(button) then return end
		local place = placeName()
		local text = make(place)
		if not text then say(button .. ": the zone name is unknown. Nothing was sent."); return end
		sendLine(button, "SAY", text)
	end
end

local function withPlace(prefix, suffix)
	return function(place) return place and (prefix .. place .. (suffix or "")) or nil end
end

function G.TellBack()
	local button = "Whisper back what I was told"
	if not lineGuard(button) then return end
	local told = S.told
	if not told then say(button .. ": no whisper holding Whisper me \"summon ...\" was received yet. Nothing was sent."); return end
	local who, why = whisperTarget()
	if not who then say(button .. ": " .. why .. ". Nothing was sent."); return end
	local before = S.lastLine
	local result = sendLine(button, "WHISPER", told.line, who)
	local a = { sender = told.sender, secondsSinceLastTestLine = before and round1(L.Now() - before) or "none yet",
		secondsSinceTold = round1(L.Now() - told.at), result = result }
	G.Put("LINE.reply", "the whisper told to us came from a name of " .. tostring(told.sender.len) .. " characters, space " ..
		tostring(told.sender.space) .. ", hyphen " .. tostring(told.sender.hyphen) .. "; " .. tostring(a.secondsSinceLastTestLine) .. " s after the last test line", a, false, true)
end

function G.TradeLine()
	local button = "Trade: WTB summon to <place>"
	if not lineGuard(button) then return end
	local place = placeName()
	if not place then say(button .. ": the zone name is unknown. Nothing was sent."); return end
	local ch = tradeChannel()
	if not ch then say(button .. ": no Trade channel (you are not in a city). Nothing was sent."); return end
	sendLine(button, "CHANNEL", "WTB summon to " .. place, ch)
end

function G.LeaveGroup()
	local button = "Leave the group"
	if not lineGuard(button) then return end
	if val(gfn("IsInGroup")) == false then say(button .. ": you are not in a group. Nothing was done."); return end
	local fn, via = tfn("C_PartyInfo", "LeaveParty"), "C_PartyInfo.LeaveParty"
	if type(fn) ~= "function" then fn, via = gfn("LeaveParty"), "LeaveParty" end
	local result
	if type(fn) ~= "function" then result = NOCALL
	else
		local ok, err = pcall(fn)
		result = ok and "called" or shortc(tostring(err), 120)
	end
	G.Put("LINE", button .. ": party " .. result, { button = button, kind = "party", result = result, via = via })
	say("Test line (" .. button .. "): " .. result)
end

-- the second section of the panel: { label, instruction, handler }
local PLACE_NOTE = "<place> is this character's own city or zone."
local LINES = {
	{ "Whisper: summon pls", "Whispers \"summon pls\" to the player you have targeted (the driver).", whisperLine("Whisper: summon pls", "summon pls") },
	{ "Whisper: LF sleeping bag summons", "Whispers \"LF sleeping bag summons\" to your target.", whisperLine("Whisper: LF sleeping bag summons", "LF sleeping bag summons") },
	{ "Whisper: whisper me invite ...", "Whispers \"whisper me invite for summon to <place>\" to your target. " .. PLACE_NOTE,
		function()
			local button = "Whisper: whisper me invite ..."
			if not lineGuard(button) then return end
			local place = placeName()
			if not place then say(button .. ": the zone name is unknown. Nothing was sent."); return end
			whisperLine(button, "whisper me invite for summon to " .. place)()
		end },
	{ "Whisper back what I was told", "Whispers your target exactly the quoted part of the last whisper you received that said Whisper me \"summon ...\". Also saves what that sender's name looked like.", G.TellBack },
	{ "Say: WTB summon to <place>", "Says \"WTB summon to <place>\" in Say. " .. PLACE_NOTE, sayLine("Say: WTB summon to <place>", withPlace("WTB summon to ")) },
	{ "Say: LF sleeping bag summons", "Says \"LF sleeping bag summons\" in Say.", sayLine("Say: LF sleeping bag summons", function() return "LF sleeping bag summons" end) },
	{ "Say: WTS summons to <place> 1g", "Says \"WTS summons to <place> 1g\" in Say. " .. PLACE_NOTE, sayLine("Say: WTS summons to <place> 1g", withPlace("WTS summons to ", " 1g")) },
	{ "Say: Port <place>", "Says \"Port <place>\" in Say. " .. PLACE_NOTE, sayLine("Say: Port <place>", withPlace("Port ")) },
	{ "Trade: WTB summon to <place>", "Real players in Trade see this line. Sends \"WTB summon to <place>\" to the Trade channel (cities only). " .. PLACE_NOTE, G.TradeLine },
	{ "Leave the group", "Leaves your group (out of combat), so the second account can leave between tries. Sends no chat.", G.LeaveGroup },
}
G.LINES = LINES
local LINE_HEAD = "Second account: test lines (target the driver first)"

local PANEL = {
	{ "Right after loading", "Press within a second of a loading screen ending (log in, /reload or a zone). Sends 10 addon messages to yourself back to back and saves each result.", G.L4 },
	{ "Chat lock send", "Press inside a dungeon or in a boss fight (and once in town). Sends one addon message to your own party and saves the result.", G.L3Send },
	{ "Mounted click", "Mount up, press this, then click Wuber's big button twice, a few seconds apart. Watches 60 seconds. Sends nothing.", G.Mounted },
	{ "Map opened by Wuber", "Out of combat, map closed. Opens the world map the way Wuber's show-driver-on-the-map does, closes it after 1 second, and watches 3 minutes for blocked actions. Then pull one mob and press M.", function() G.Map("wuber") end },
	{ "Map opened the safe way", "The same, opened with C_Map.OpenWorldMap. Press it after a /reload, then do the same fight test.", function() G.Map("safe") end },
	{ "Can I remove?", "Target a player in YOUR party (you must lead it), out of combat. One press tries to remove that one player from your party and says removed or blocked.", G.Remove },
	{ "Flight map facts", "Press with a flight map open (it reads the game's own flight buttons and the map's inner area). Press first and it waits 3 minutes for the next flight map.", G.Flight },
	{ "Show the answers", "Prints what every check knows so far, and what still waits for an event.", function() G.Instant("press") end },
}
G.PANEL = PANEL
local PW, ROW_H, LINE_H = 500, 52, 50

local function fillTex(f, r, g, b, al)
	local t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(f)
	t:SetColorTexture(r, g, b, al)
	return t
end

local function words(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	if not pcall(fs.SetFont, fs, "Fonts\\ARIALN.TTF", size, "") then pcall(fs.SetFontObject, fs, rawget(_G, "GameFontHighlightSmall")) end
	fs:SetTextColor(r, g, b)
	pcall(fs.SetJustifyH, fs, "LEFT")
	pcall(fs.SetJustifyV, fs, "TOP")
	pcall(fs.SetWordWrap, fs, true)
	return fs
end

local function tip(frame, text)
	frame:SetScript("OnEnter", function(self)
		local gt = rawget(_G, "GameTooltip")
		if gt then pcall(gt.SetOwner, gt, self, "ANCHOR_TOP"); pcall(gt.SetText, gt, text, 1, 1, 1, 1, true); pcall(gt.Show, gt) end
	end)
	frame:SetScript("OnLeave", function() local gt = rawget(_G, "GameTooltip"); if gt then pcall(gt.Hide, gt) end end)
end

local function build()
	local f = CreateFrame("Frame", "WuberLabFactsPanel", UIParent)
	-- two columns: the checks on the left, the second account's test lines on the right (one column would be about 1000 high)
	f:SetSize(PW * 2, math.max(40 + #PANEL * ROW_H + 30, 66 + #LINES * LINE_H + 34))
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	fillTex(f, 0.043, 0.043, 0.086, 0.96)
	local bar = rawget(_G, "WuberLabBarFrame")
	if bar then f:SetPoint("TOP", bar, "BOTTOM", 0, -6) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	local title = words(f, 14, 0.8, 0.49, 0.96)
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	title:SetText("Game facts (developer only): checks that need your moment")
	for i, row in ipairs(PANEL) do
		local y = -36 - (i - 1) * ROW_H
		local b = CreateFrame("Button", nil, f)
		b:SetSize(160, 24)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
		fillTex(b, 0.18, 0.1, 0.28, 1)
		local lab = words(b, 12, 1, 1, 1)
		lab:SetPoint("CENTER", b, "CENTER", 0, 0)
		pcall(lab.SetJustifyH, lab, "CENTER")
		lab:SetText(row[1])
		b:SetScript("OnClick", function()
			local gt = rawget(_G, "GameTooltip")
			if gt then pcall(gt.Hide, gt) end
			local ok, err = pcall(row[3])
			if not ok then L.Bug("facts " .. row[1], err) end
		end)
		tip(b, row[2])
		local t = words(f, 11, 0.85, 0.8, 0.92)
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 182, y + 2)
		t:SetWidth(PW - 196)
		t:SetText(row[2])
	end
	local head = words(f, 12, 0.8, 0.49, 0.96)
	head:SetPoint("TOPLEFT", f, "TOPLEFT", PW + 12, -38)
	head:SetWidth(PW - 24)
	head:SetText(LINE_HEAD)
	for i, row in ipairs(LINES) do
		local y = -66 - (i - 1) * LINE_H
		local b = CreateFrame("Button", nil, f)
		b:SetSize(210, 24)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", PW + 12, y)
		fillTex(b, 0.18, 0.1, 0.28, 1)
		local lab = words(b, 12, 1, 1, 1)
		lab:SetPoint("CENTER", b, "CENTER", 0, 0)
		pcall(lab.SetJustifyH, lab, "CENTER")
		lab:SetText(row[1])
		b:SetScript("OnClick", function()
			local gt = rawget(_G, "GameTooltip")
			if gt then pcall(gt.Hide, gt) end
			local ok, err = pcall(row[3])
			if not ok then L.Bug("facts " .. row[1], err) end
		end)
		tip(b, row[2])
		local t = words(f, 11, 0.85, 0.8, 0.92)
		t:SetPoint("TOPLEFT", f, "TOPLEFT", PW + 232, y + 2)
		t:SetWidth(PW - 246)
		t:SetText(row[2])
	end
	local close = CreateFrame("Button", nil, f)
	close:SetSize(80, 22)
	close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
	fillTex(close, 0.18, 0.1, 0.28, 1)
	local cl = words(close, 12, 1, 1, 1)
	cl:SetPoint("CENTER", close, "CENTER", 0, 0)
	pcall(cl.SetJustifyH, cl, "CENTER")
	cl:SetText("Close")
	close:SetScript("OnClick", function() f:Hide() end)
	tip(close, "Closes this panel.")
	-- out of every screenshot, as the bar and its steps note are
	L.On("CHAT_MSG_WHISPER", toldHandler) -- for "Whisper back what I was told"
	local function back() f:SetAlpha(1) end
	L.Hook("Screenshot", function() f:SetAlpha(0); L.After(1.5, back) end)
	L.On("SCREENSHOT_SUCCEEDED", function() L.After(0.2, back) end)
	L.On("SCREENSHOT_FAILED", function() L.After(0.2, back) end)
	return f
end

function G.Open(toggle)
	if not S.panel then
		S.panel = build()
		S.panel:Show()
	elseif toggle and S.panel:IsShown() then
		S.panel:Hide()
	else
		S.panel:Show()
	end
	return S.panel
end

-- /lab facts [panel | answers]: the Lab bar's "Game facts" button runs the plain "facts"
function L.GameFactsSlash(rest)
	local a = tostring(rest or ""):lower()
	G.Press() -- the first press (any form) switches the passive checks on for good
	if a == "panel" then G.Open(false)
	elseif a == "answers" or a == "instant" then G.Instant("press")
	else
		G.Instant("press")
		G.Open(true)
	end
end
