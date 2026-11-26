-- Wuber Lab (developer only, never ship): GameFacts2.lua - six more checks for "Game facts" (job 134b, 22 Nov 2026).
--
-- LAB-CHECKS-WANTED L13, L16, L17, L18, L19 and the Mailbox check, with no typing. This file only adds to GameFacts.lua
-- (L.GameFacts): rows in its list of ids and in its panel, and a little more work in its press. Like GameFacts.lua it
-- makes no frame, registers no event and starts no timer at load (Wuber's own tests load the Lab on every branch):
-- its events are wired when the passive checks start (the saved WuberLabDB.factsOn, or the first press of Game facts).
--   INSTANT   every press of "Game facts" and the end of an Auto check (once Game facts is on):
--             (L16.char and L18 also run by themselves 6 s after the passive checks start, so at every login)
--             L16.char  realm facts of THIS character (realm, region, Hardcore, War Mode, the realm part of UnitFullName,
--                       the ruleset Wuber worked out and the one it remembered); also 6 s after every login and when the
--                       player's flags change, saved only when the line differs, so one login per ruleset is enough
--             L13.style the input (gamepad) style again, saved only when it changed (blocked actions: GameFacts.lua)
--             L18       the taint log's state, and whether a "run after" hook (hooksecurefunc) on PlaySound ran
--             L19       the whisper check: asks C_ChatInfo.RequestCanLocalWhisperTarget about yourself, your target, one logged-out
--                       friend and one logged-out guild member (the ones with a GUID), and the remembered player; the answer is the
--                       event CAN_LOCAL_WHISPER_TARGET_RESPONSE (status, ms, or "no answer in 3 s"); saved every time (the ms differ)
--   PASSIVE   L19       the last other player targeted or grouped with is kept in memory (not saved); asked again every 30 s for at most
--                       30 minutes; the first change of its answer is saved ("remembered player went 0 -> 2") and the asking stops
--   PASSIVE   MAIL      each time a mailbox opens: every mail's sender, money, subject and days left, written to the Lab
--                       log (GetInboxNumItems / GetInboxHeaderInfo, read only: nothing is taken, opened or deleted) and
--                       whether any value is a secret value (issecretvalue may not exist: said so)
--   MOMENT    panel buttons "Accept without a click" (L17), "Hooks and the taint log" (L18), "Mailbox check" (MAIL), "Whisper check" (L19)
-- L17 acts for the player once per press: armed for 60 s, it calls AcceptGroup inside PARTY_INVITE_REQUEST or
-- C_SummonInfo.ConfirmSummon inside CONFIRM_SUMMON (no click), whichever comes first, never in combat, and writes
-- "joined" / "accepted" or the blocked action the game reports. A try that did nothing (and was not blocked) is
-- repeated once from a timer. A summon box already up at the press is tried from a timer 1 s later.

local _, L = ...

local G = L.GameFacts
if type(G) ~= "table" or type(G.Put) ~= "function" or type(G.ask) ~= "function" then return end

local secret, ask, plain = L.IsSecret, G.ask, L.plain
local NOCALL = "no such call"
local S = { wired = false, hookRuns = 0, ownRuns = 0 }
G.More = S -- (for the offline test)

local function gfn(name) return rawget(_G, name) end
local function tfn(tname, name)
	local t = rawget(_G, tname)
	return type(t) == "table" and t[name] or nil
end
local function val(fn, ...)
	local r, e = ask(fn, ...)
	if not r then return e end
	if r[1] == nil then return "nil" end
	return r[1]
end
local function say(text) if L.Say then L.Say(text) else print(text) end end
local function short(s, n) return tostring(s or ""):sub(1, n or 120) end
local function factsOn() return type(L.db) == "table" and L.db.factsOn == true end
local function cvar(name) return val(tfn("C_CVar", "GetCVar") or gfn("GetCVar"), name) end

-- saved only when the line is not the newest one already (a login on the same character adds nothing)
local function putIfNew(id, line, a)
	local e = G.Newest(id)
	if e and e.line == short(line, 320) then return nil end
	return G.Put(id, line, a)
end

for _, row in ipairs({
	{ "L16.char", "Realm facts of this character", "instant" },
	{ "L18", "Hooks and the taint log", "instant" },
	{ "L17.invite", "Invite accepted without a click", "moment" },
	{ "L17.summon", "Summon accepted without a click", "moment" },
	{ "MAIL", "Mailbox check", "passive", "no mailbox opened yet" },
	{ "L19", "Whisper check", "instant", "not asked yet (press Game facts, or the Whisper check button)" },
}) do G.IDS[#G.IDS + 1] = row end

---------------------------------------------------------------------------
-- L16.char: realm facts of this character, and what Wuber made of them
---------------------------------------------------------------------------

local function realmChar(why)
	local a = {
		why = why,
		GetRealmName = val(gfn("GetRealmName")),
		GetNormalizedRealmName = val(gfn("GetNormalizedRealmName")),
		GetRealmID = val(gfn("GetRealmID")),
		GetCurrentRegion = val(gfn("GetCurrentRegion")),
		IsHardcoreActive = val(tfn("C_GameRules", "IsHardcoreActive")),
		IsWarModeActive = val(tfn("C_PvP", "IsWarModeActive")),
		IsWarModeDesired = val(tfn("C_PvP", "IsWarModeDesired")),
	}
	-- UnitFullName: the realm part only (the name is personal: its length)
	local r, e = ask(gfn("UnitFullName"), "player")
	if r then
		a.fullNameLen = type(r[1]) == "string" and #r[1] or tostring(r[1])
		a.fullNameRealm = r[2] == nil and "nil" or r[2]
	else
		a.fullNameRealm = e
	end
	-- Wuber: the ruleset it works out now, and the one it remembered for this character
	local W = L.W and L.W() or nil
	a.wuberRuleset, a.wuberRemembered = "no Wuber", "no Wuber"
	if type(W) == "table" then
		a.wuberRuleset = type(W.Ruleset) == "function" and val(W.Ruleset) or NOCALL
		local ok, m = pcall(function()
			local c = W.db and W.db.chars and W.myKey and W.db.chars[W.myKey]
			return type(c) == "table" and c.ruleset or nil
		end)
		a.wuberRemembered = (ok and not secret(m) and m ~= nil) and tostring(m) or "nothing"
	end
	local line = "realm " .. tostring(a.GetRealmName) .. " (" .. tostring(a.GetNormalizedRealmName) .. ", id " .. tostring(a.GetRealmID) ..
		"), region " .. tostring(a.GetCurrentRegion) .. ", hardcore " .. tostring(a.IsHardcoreActive) .. ", war mode " ..
		tostring(a.IsWarModeActive) .. " (wanted " .. tostring(a.IsWarModeDesired) .. "), realm in the full name " .. tostring(a.fullNameRealm) ..
		"; Wuber says " .. tostring(a.wuberRuleset) .. ", remembered " .. tostring(a.wuberRemembered)
	return putIfNew("L16.char", line, a)
end
G.RealmChar = realmChar

---------------------------------------------------------------------------
-- L13.style again (GameFacts.lua reads it at login only): saved when it changed
---------------------------------------------------------------------------

local function styleAgain()
	local a = { GetCurrentStyle = val(tfn("C_InputInterfaceStyle", "GetCurrentStyle")), cvar = cvar("InputDeviceInterfaceStyle"),
		gamePadEnable = cvar("GamePadEnable") }
	local en = rawget(_G, "Enum")
	local t = type(en) == "table" and en.InputDeviceInterfaceType or nil
	if type(t) == "table" then
		a.enum = {}
		for k, v in pairs(t) do if type(k) == "string" and type(v) == "number" then a.enum[k] = v end end
	else
		a.enum = NOCALL
	end
	-- (the same words as GameFacts.lua's line, so an unchanged style adds no entry)
	return putIfNew("L13.style", "input style " .. tostring(a.GetCurrentStyle) .. ", CVar " .. tostring(a.cvar), a)
end

---------------------------------------------------------------------------
-- L18: does a "run after" hook still run, with the taint log off and on?
---------------------------------------------------------------------------

local function taintState()
	local v = cvar("taintLog")
	if v == NOCALL or v == "error" or v == "secret" or v == "nil" then return nil, tostring(v) end
	return tostring(v) ~= "0", tostring(v)
end

-- reads once, in the taint log's present state. Returns the entry's answers.
local function hooksNow(why)
	local on, raw = taintState()
	local a = { why = why, taintLog = raw }
	local hsf, play = gfn("hooksecurefunc"), gfn("PlaySound")
	if type(hsf) ~= "function" or type(play) ~= "function" then
		a.hookRan = NOCALL
		putIfNew("L18", "taint log " .. raw .. "; hook ran: " .. NOCALL, a)
		return a
	end
	if not S.hooked then
		-- one hook for the session, counting only. (Made at the first press, never at load.)
		S.hooked = pcall(hsf, "PlaySound", function() S.hookRuns = S.hookRuns + 1 end)
	end
	a.hooked = S.hooked == true
	-- how often the hook ran for the game's own sounds since the last reading (a hook called from the game's code)
	a.gameSounds = S.hookRuns - S.ownRuns
	local before = S.hookRuns
	local kit = rawget(_G, "SOUNDKIT")
	local id = (type(kit) == "table" and type(kit.IG_MAINMENU_OPTION_CHECKBOX_ON) == "number" and kit.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856
	a.played = (pcall(play, id))
	a.hookRan = S.hookRuns > before
	S.ownRuns = S.ownRuns + (S.hookRuns - before)
	local line = "taint log " .. raw .. (on == nil and "" or (on and " (on)" or " (off)")) .. "; hook ran: " .. (a.hookRan and "yes" or "no") ..
		"; the game's own sounds the hook heard before this: " .. a.gameSounds
	putIfNew("L18", line, a)
	-- which states have been read on this game build so far (saved, so the report can say "both")
	local d = L.db
	if type(d) == "table" and on ~= nil then
		if type(d.l18) ~= "table" then d.l18 = {} end
		d.l18[on and "on" or "off"] = a.hookRan and "yes" or "no"
	end
	return a
end
G.HooksNow = hooksNow

local function setTaint(want)
	local set = tfn("C_CVar", "SetCVar") or gfn("SetCVar")
	if type(set) ~= "function" then return false end
	return (pcall(set, "taintLog", want and "1" or "0"))
end

-- The panel button: reads now; if the other state has no answer yet it switches the taint log, reloads (this click is the
-- player's own), reads again after the reload and puts the taint log back (that counts from the next Reload).
function G.Hooks()
	if L.InCombat() then say("Hooks and the taint log: leave combat first"); return end
	local a = hooksNow("press")
	local on = taintState()
	say("Hooks and the taint log: taint log " .. tostring(a.taintLog) .. ", hook ran: " .. tostring(a.hookRan == true and "yes" or a.hookRan == false and "no" or a.hookRan))
	local d = L.db
	if on == nil or type(d) ~= "table" or type(d.l18) ~= "table" then return end
	local other = on and "off" or "on"
	if d.l18[other] ~= nil then
		say("Hooks and the taint log: done. Both answers are saved (log off: hook ran " .. tostring(d.l18.off) .. "; log on: hook ran " .. tostring(d.l18.on) .. ").")
		return
	end
	local reload = gfn("ReloadUI")
	if type(reload) ~= "function" or not setTaint(not on) then
		say("Hooks and the taint log: could not switch the taint log here. Click Taint on the Lab bar, Reload, then this button again.")
		return
	end
	d.l18.pending = { back = on and "1" or "0" }
	say("Hooks and the taint log: reloading once with the taint log " .. other .. " ...")
	pcall(reload)
end

L.OnLogin(function()
	local d = L.db
	local p = type(d) == "table" and type(d.l18) == "table" and d.l18.pending or nil
	if type(p) ~= "table" then return end
	d.l18.pending = nil
	L.After(4, function()
		local a = hooksNow("after the reload")
		setTaint(p.back == "1")
		say("Hooks and the taint log: done. Log off: hook ran " .. tostring(d.l18.off) .. "; log on: hook ran " .. tostring(d.l18.on) ..
			". The taint log is set back to " .. (p.back == "1" and "ON" or "off") .. " (it counts from your next Reload).")
		L.Log("facts", "L18: both states read; taint log put back to " .. tostring(p.back) .. "; last hook ran " .. tostring(a.hookRan))
	end)
end)

---------------------------------------------------------------------------
-- Blocked actions while a try of L17 is watched (Hooks.lua logs them as kind "block")
---------------------------------------------------------------------------

local function blockedLine(kind, text)
	local w = S.watch
	if kind ~= "block" or type(text) ~= "string" or not w then return end
	local ev, addon, func = text:match("^(ADDON_ACTION_%u+) addon=(%S+) func=(%S+)")
	if not ev then return end
	if #w.blocked < 6 then w.blocked[#w.blocked + 1] = { event = ev, addon = short(addon, 40), func = short(func, 60) } end
end

local function blockedWords(list)
	local b = list[1]
	return b.event .. " " .. b.func .. " (blamed: " .. b.addon .. ")" .. (#list > 1 and (" and " .. (#list - 1) .. " more") or "")
end

local function popup(which)
	local r = ask(gfn("StaticPopup_FindVisible"), which)
	return r and r[1] or nil
end

---------------------------------------------------------------------------
-- L17: accept a party invite and a summon with no click
---------------------------------------------------------------------------

local ARM_SECS = 60
local function armed(kind) return S.arm ~= nil and S.arm[kind] == true and L.Now() <= S.arm.untilT end

local tryInvite, trySummon

-- how: "event" (inside the game's event) or "timer" (the one repeat, 1.5 s later, from a timer)
tryInvite = function(how)
	if not armed("invite") then return end
	if L.InCombat() then
		G.Put("L17.invite", "in combat: nothing was done (the invite box is yours)", { how = how, combat = true })
		say("Accept without a click: in combat, so the invite was left to you")
		return
	end
	local fn = gfn("AcceptGroup")
	if type(fn) ~= "function" then
		S.arm.invite = false
		G.Put("L17.invite", "AcceptGroup: " .. NOCALL, { how = how, noCall = true })
		return
	end
	S.arm.invite = false
	S.arm.summon = false -- one press acts once: this press was the invite's
	local a = { how = how, via = "AcceptGroup", blocked = {}, inGroupBefore = val(gfn("IsInGroup")), boxBefore = popup("PARTY_INVITE") ~= nil }
	local e = G.Put("L17.invite", "called AcceptGroup from the " .. how .. " (no click); waiting", a)
	S.watch = a
	local ok, err = pcall(fn)
	a.pcall = ok
	if not ok then a.err = secret(err) and "secret" or short(err, 120) end
	L.After(1.5, function()
		if S.watch == a then S.watch = nil end
		a.inGroupAfter = val(gfn("IsInGroup"))
		local verdict
		if #a.blocked > 0 then verdict = "blocked: " .. blockedWords(a.blocked)
		elseif not ok then verdict = "error: " .. tostring(a.err)
		elseif a.inGroupAfter == true and a.inGroupBefore ~= true then verdict = "joined"
		elseif a.inGroupAfter == true then verdict = "in a group before and after (cannot tell)"
		else verdict = "no change (not blocked, not joined)" end
		a.verdict = verdict
		if verdict == "joined" then
			-- close the game's invite box with its accepted mark set, so closing it does not decline
			local box = popup("PARTY_INVITE")
			if box then
				pcall(function() box.inviteAccepted = 1 end)
				a.boxClosed = (pcall(gfn("StaticPopup_Hide") or error, "PARTY_INVITE"))
			end
		end
		if e then e.line = short("AcceptGroup from the " .. how .. ", no click: " .. verdict, 320) end
		L.Log("facts", "L17.invite: " .. (e and e.line or verdict))
		say("Accept without a click (invite, from the " .. how .. "): " .. verdict)
		if verdict ~= "joined" and how == "event" and #a.blocked == 0 and S.arm and popup("PARTY_INVITE") then
			S.arm.invite = true
			S.arm.untilT = math.max(S.arm.untilT, L.Now() + 1)
			tryInvite("timer, again")
		end
	end)
end

local function summonLeft() return val(tfn("C_SummonInfo", "GetSummonConfirmTimeLeft") or gfn("GetSummonConfirmTimeLeft")) end

trySummon = function(how)
	if not armed("summon") then return end
	if L.InCombat() then
		G.Put("L17.summon", "in combat: nothing was done (the summon box is yours)", { how = how, combat = true })
		say("Accept without a click: in combat, so the summon was left to you")
		return
	end
	local fn, via = tfn("C_SummonInfo", "ConfirmSummon"), "C_SummonInfo.ConfirmSummon"
	if type(fn) ~= "function" then fn, via = gfn("ConfirmSummon"), "ConfirmSummon" end
	if type(fn) ~= "function" then
		S.arm.summon = false
		G.Put("L17.summon", "ConfirmSummon: " .. NOCALL, { how = how, noCall = true })
		return
	end
	S.arm.summon = false
	S.arm.invite = false -- one press acts once: this press was the summon's
	local a = { how = how, via = via, blocked = {}, leftBefore = summonLeft(), boxBefore = popup("CONFIRM_SUMMON") ~= nil,
		zoneBefore = val(gfn("GetRealZoneText")), instance = val(gfn("IsInInstance")) }
	local e = G.Put("L17.summon", "called " .. via .. " from the " .. how .. " (no click); waiting", a)
	S.watch = a
	local ok, err = pcall(fn)
	a.pcall = ok
	if not ok then a.err = secret(err) and "secret" or short(err, 120) end
	L.After(1.5, function()
		if S.watch == a then S.watch = nil end
		a.leftAfter = summonLeft()
		a.boxAfter = popup("CONFIRM_SUMMON") ~= nil
		a.zoneChanged = val(gfn("GetRealZoneText")) ~= a.zoneBefore
		local gone = (type(a.leftAfter) == "number" and a.leftAfter <= 0) or (type(a.leftAfter) ~= "number" and not a.boxAfter)
		local verdict
		if #a.blocked > 0 then verdict = "blocked: " .. blockedWords(a.blocked)
		elseif not ok then verdict = "error: " .. tostring(a.err)
		elseif gone or a.zoneChanged then verdict = "accepted"
		else verdict = "no change (not blocked, the summon is still waiting)" end
		a.verdict = verdict
		if e then e.line = short(via .. " from the " .. how .. ", no click: " .. verdict, 320) end
		L.Log("facts", "L17.summon: " .. (e and e.line or verdict))
		say("Accept without a click (summon, from the " .. how .. "): " .. verdict)
		if verdict ~= "accepted" and how == "event" and #a.blocked == 0 and S.arm and type(a.leftAfter) == "number" and a.leftAfter > 0 then
			S.arm.summon = true
			S.arm.untilT = math.max(S.arm.untilT, L.Now() + 1)
			trySummon("timer, again")
		end
	end)
end

---------------------------------------------------------------------------
-- MAIL: what an addon can read at an open mailbox (read only)
---------------------------------------------------------------------------

local function nameShape(s)
	if type(s) ~= "string" then return tostring(s) end
	return { len = #s, space = s:find(" ", 1, true) ~= nil, realmTail = s:find("-", 1, true) ~= nil }
end

local function mailOpen()
	if S.mailOpen then return true end
	local f = rawget(_G, "MailFrame")
	if type(f) == "table" and type(f.IsShown) == "function" then
		local ok, shown = pcall(f.IsShown, f)
		return ok and shown == true
	end
	return false
end

local function mailRead(why)
	local numFn, hdrFn = gfn("GetInboxNumItems"), gfn("GetInboxHeaderInfo")
	local a = { why = why, issecretvalue = type(gfn("issecretvalue")) == "function" and "exists" or NOCALL, secrets = 0, mails = {} }
	if type(numFn) ~= "function" or type(hdrFn) ~= "function" then
		a.noCall = true
		G.Put("MAIL", "GetInboxNumItems / GetInboxHeaderInfo: " .. NOCALL, a)
		return a
	end
	local ok, n, total = pcall(numFn)
	if not ok then G.Put("MAIL", "GetInboxNumItems failed", a); return a end
	if secret(n) then
		a.secrets = 1
		G.Put("MAIL", "the number of mails is a secret value", a)
		return a
	end
	n = tonumber(n) or 0
	a.count = n
	a.total = secret(total) and "secret" or tonumber(total)
	local withMoney, withCod = 0, 0
	-- one value as the log shows it; a secret value is never touched
	local function show(v)
		if secret(v) then a.secrets = a.secrets + 1; return "secret", true end
		if v == nil then return "nil" end
		return v
	end
	for i = 1, math.min(n, 50) do
		local r = { pcall(hdrFn, i) }
		if not r[1] then
			a.mails[i] = { failed = true }
			L.Log("facts", "MAIL " .. i .. ": GetInboxHeaderInfo failed")
		else
			-- (after pcall's true) 1 packageIcon, 2 stationeryIcon, 3 sender, 4 subject, 5 money, 6 CODAmount, 7 daysLeft,
			-- 8 itemCount, 9 wasRead, 10 wasReturned, 11 textCreated, 12 canReply, 13 isGM
			local sender, sSec = show(r[4])
			local subject, subSec = show(r[5])
			local money, mSec = show(r[6])
			local cod = show(r[7])
			local days, dSec = show(r[8])
			local items = show(r[9])
			local wasRead, returned, canReply, gm = show(r[10]), show(r[11]), show(r[13]), show(r[14])
			if type(days) == "number" then days = math.floor(days * 100 + 0.5) / 100 end
			if type(money) == "number" and money > 0 then withMoney = withMoney + 1 end
			if type(cod) == "number" and cod > 0 then withCod = withCod + 1 end
			a.mails[i] = { sender = sSec and "secret" or nameShape(sender), senderType = type(sender), money = money, cod = cod,
				subjectLen = (not subSec and type(subject) == "string") and #subject or tostring(subject), daysLeft = days, items = items,
				read = wasRead, returned = returned, canReply = canReply, gm = gm,
				secret = (sSec or subSec or mSec or dSec) and true or nil }
			L.Log("facts", ("MAIL %d: sender %s; money %s; subject %s; days left %s; COD %s; items %s; read %s; returned %s"):format(
				i, short(sender, 60), tostring(money), short(subject, 80), tostring(days), tostring(cod), tostring(items), tostring(wasRead), tostring(returned)))
		end
	end
	local line = "mailbox: " .. n .. " mail" .. (n == 1 and "" or "s") .. " (" .. tostring(a.total) .. " on the server), money in " .. withMoney ..
		", pay-on-delivery " .. withCod .. "; secret values: " .. (a.secrets == 0 and "none" or tostring(a.secrets)) ..
		"; issecretvalue " .. a.issecretvalue .. "; nothing was taken"
	G.Put("MAIL", line, a)
	say("Mailbox check: " .. n .. " mail" .. (n == 1 and "" or "s") .. " written down, secret values: " .. (a.secrets == 0 and "none" or tostring(a.secrets)) .. ". Nothing was taken.")
	return a
end
G.MailRead = mailRead

-- a mailbox opened: read once, at the first inbox update (the list is empty until then) or 1.5 s later
local function mailShown()
	S.mailOpen = true
	local visit = {}
	S.mailVisit = visit
	L.After(1.5, function()
		if S.mailVisit == visit and S.mailOpen and not visit.read then visit.read = true; mailRead("opened") end
	end)
end
local function mailUpdate()
	local visit = S.mailVisit
	if not S.mailOpen or not visit or visit.read then return end
	local n = val(gfn("GetInboxNumItems"))
	if type(n) == "number" and n == 0 then return end -- (still empty: the timer reads it)
	visit.read = true
	mailRead("opened")
end

---------------------------------------------------------------------------
-- L19: can this player be whispered? (C_ChatInfo.RequestCanLocalWhisperTarget, answer: CAN_LOCAL_WHISPER_TARGET_RESPONSE)
---------------------------------------------------------------------------

local WHISPER_SECS, REMEMBER_EVERY, REMEMBER_MAX = 3, 30, 1800
-- plain words for a status (Wuber's own idea of them: 0 can, 1 can (guild), 2 offline, 3 wrong faction)
local STATUS_WORDS = { [0] = "can be whispered", [1] = "can be whispered (guild)", [2] = "offline", [3] = "wrong faction" }
S.pend, S.seen = {}, {}

local function wcall() return tfn("C_ChatInfo", "RequestCanLocalWhisperTarget") end
local function ms(t0) return math.floor((L.Now() - t0) * 1000 + 0.5) end

-- one request: cb(result) once, result = { status, ms } / { none } / { secret } / { err } / { nocall }
local function settle(p, res)
	if p.done then return end
	p.done = true
	for i, q in ipairs(S.pend) do if q == p then table.remove(S.pend, i) break end end
	L.Safe("L19", p.cb, res)
end
local function request(guid, cb)
	local fn = wcall()
	if type(fn) ~= "function" then cb({ nocall = true }) return end
	local p = { guid = guid, t0 = L.Now(), cb = cb }
	S.pend[#S.pend + 1] = p
	if not pcall(fn, guid) then settle(p, { err = true }) return end
	L.After(WHISPER_SECS, function() settle(p, { none = true }) end)
end

local function onWhisperAnswer(guid, status)
	if secret(guid) or secret(status) then
		local p = S.pend[1]
		if p then settle(p, { secret = true }) end
		return
	end
	local list = {}
	for _, p in ipairs(S.pend) do if p.guid == guid then list[#list + 1] = p end end
	for _, p in ipairs(list) do settle(p, { status = tonumber(status) or tostring(status), ms = ms(p.t0) }) end
end

local function ownGuid()
	local r = ask(gfn("UnitGUID"), "player")
	return r and type(r[1]) == "string" and r[1] or nil
end

-- another PLAYER on this unit: its GUID, else nil
local function playerGuid(unit)
	if val(gfn("UnitIsPlayer"), unit) ~= true then return nil end
	local r = ask(gfn("UnitGUID"), unit)
	local g = r and r[1]
	if type(g) ~= "string" or g == ownGuid() then return nil end
	return g
end

-- the first friend (then the first guild member) that is logged out and has a GUID: its GUID, else nil
local function offlineFriend()
	local n = val(tfn("C_FriendList", "GetNumFriends"))
	if type(n) ~= "number" then return nil end
	for i = 1, math.min(n, 100) do
		local r = ask(tfn("C_FriendList", "GetFriendInfoByIndex"), i)
		local info = r and r[1]
		if type(info) == "table" and not secret(info.guid) and not secret(info.connected) and type(info.guid) == "string" and info.connected == false then
			return info.guid
		end
	end
end
local function offlineGuild()
	local n = val(gfn("GetNumGuildMembers"))
	if type(n) ~= "number" then return nil end
	for i = 1, math.min(n, 300) do
		local r = ask(gfn("GetGuildRosterInfo"), i)
		if r and r[9] == false and type(r[17]) == "string" then return r[17] end
	end
end

-- the last other player targeted or grouped with: kept in memory only, asked again every 30 s for up to 30 minutes, until its
-- answer changes (one saved line, then it stops)
local function noteRemembered(rem, status)
	if S.rem ~= rem or rem.done or type(status) ~= "number" then return end
	if rem.last == nil then rem.last = status return end
	if status == rem.last then return end
	rem.done = true
	G.Put("L19", "remembered player went " .. rem.last .. " -> " .. status, { remembered = { from = rem.last, to = status } })
end
local function rememberTick(rem)
	if S.rem ~= rem or rem.done then return end
	if L.Now() - rem.since > REMEMBER_MAX then rem.done = true return end
	request(rem.guid, function(res) noteRemembered(rem, res.status) end)
	L.After(REMEMBER_EVERY, function() rememberTick(rem) end)
end
local function remember(guid)
	if not guid or (S.rem and S.rem.guid == guid) then return end
	local rem = { guid = guid, since = L.Now(), done = false }
	S.rem = rem
	rememberTick(rem)
end

local function wireWhisper()
	if S.wiredW then return end
	S.wiredW = true
	L.On("CAN_LOCAL_WHISPER_TARGET_RESPONSE", onWhisperAnswer)
end
-- (the passive part: StartPassive, never at load)
local function wireRemember()
	if S.wiredR then return end
	S.wiredR = true
	wireWhisper()
	L.On("PLAYER_TARGET_CHANGED", function() remember(playerGuid("target")) end)
	L.On("GROUP_ROSTER_UPDATE", function()
		for i = 1, 4 do
			local g = playerGuid("party" .. i)
			if g and not S.seen[g] then
				if (S.nSeen or 0) >= 40 then S.seen, S.nSeen = {}, 0 end
				S.seen[g] = true
				S.nSeen = (S.nSeen or 0) + 1
				remember(g)
			end
		end
	end)
end

local WORDS = { -- the chat line's names (no "offline" in a name: that word only comes from an answer of 2)
	me = "me", target = "target", friend = "friend who is logged out", guild = "guild member who is logged out", rem = "remembered player" }
local SAVED = { me = "me", target = "target", friend = "offline friend", guild = "offline guild member", rem = "remembered player" }
local ORDER = { "me", "target", "friend", "guild", "rem" }

local function enumFacts()
	local en = rawget(_G, "Enum")
	local t = type(en) == "table" and en.ChatWhisperTargetStatus or nil
	if type(t) ~= "table" then return nil end
	local names, parts = {}, {}
	for k, v in pairs(t) do if type(k) == "string" and type(v) == "number" then names[k] = v; parts[#parts + 1] = { k, v } end end
	table.sort(parts, function(x, y) return x[2] < y[2] end)
	for i, p in ipairs(parts) do parts[i] = p[1] .. "=" .. p[2] end
	return names, table.concat(parts, ", ")
end

local running
-- report(chatLine) is called once when the answers are in
local function whisperCheck(why, report)
	if running then return end
	local fn = wcall()
	wireWhisper()
	local a = { why = why, call = type(fn) == "function" and "yes" or NOCALL, answers = {} }
	if type(fn) ~= "function" then
		G.Put("L19", "C_ChatInfo.RequestCanLocalWhisperTarget: " .. NOCALL, a)
		if report then report("Whisper check: the game has no RequestCanLocalWhisperTarget call here.") end
		return a
	end
	local names, enumText = enumFacts()
	a.enum = names or "no table"
	L.Log("facts", "L19: Enum.ChatWhisperTargetStatus " .. (enumText or "no such table"))
	local guids = { me = ownGuid(), target = playerGuid("target"), friend = offlineFriend(), guild = offlineGuild(), rem = S.rem and S.rem.guid or nil }
	local run = { n = 0, got = 0, res = {} }
	running = run
	local function finish()
		if running ~= run then return end
		running = nil
		local saved, chat = { "call yes" .. (names and "" or " (no Enum.ChatWhisperTargetStatus)") }, {}
		for _, k in ipairs(ORDER) do
			local r = run.res[k]
			if not guids[k] and not r then
				saved[#saved + 1] = (k == "me" and "me no id" or "no " .. SAVED[k])
				chat[#chat + 1] = (k == "me" and "me: no id" or "no " .. WORDS[k])
			elseif r.status then
				saved[#saved + 1] = SAVED[k] .. " " .. r.status .. " in " .. r.ms .. " ms"
				chat[#chat + 1] = WORDS[k] .. ": " .. (STATUS_WORDS[r.status] or ("status " .. r.status)) .. " (" .. r.status .. ", " .. r.ms .. " ms)"
			else
				local why2 = r.none and ("no answer in " .. WHISPER_SECS .. " s") or r.secret and "secret value" or "call failed"
				saved[#saved + 1] = SAVED[k] .. " " .. why2
				chat[#chat + 1] = WORDS[k] .. ": " .. why2
			end
			a.answers[SAVED[k]] = r and (r.status or (r.none and "none") or (r.secret and "secret") or "error") or "not asked"
			if k == "rem" and r and r.status and S.rem then noteRemembered(S.rem, r.status) end
		end
		G.Put("L19", table.concat(saved, "; "), a)
		if report then report("Whisper check: " .. table.concat(chat, "; ") .. ".") end
	end
	for _, k in ipairs(ORDER) do
		if guids[k] then
			run.n = run.n + 1
			request(guids[k], function(res)
				run.res[k] = res
				run.got = run.got + 1
				if run.got >= run.n then finish() end
			end)
		end
	end
	if run.n == 0 then finish() end
	return a
end
G.WhisperNow = whisperCheck
function G.WhisperCheck() whisperCheck("button", say) end

---------------------------------------------------------------------------
-- Wiring (never at load), the press, the panel
---------------------------------------------------------------------------

local function wire()
	if S.wired then return end
	S.wired = true
	L.listeners[#L.listeners + 1] = blockedLine
	L.On("PARTY_INVITE_REQUEST", function() tryInvite("event") end)
	L.On("CONFIRM_SUMMON", function() trySummon("event") end)
	L.On("MAIL_SHOW", mailShown)
	L.On("MAIL_INBOX_UPDATE", mailUpdate)
	L.On("MAIL_CLOSED", function() S.mailOpen = false; S.mailVisit = nil end)
	L.On("PLAYER_FLAGS_CHANGED", function(unit) if plain(unit) == "player" then realmChar("flags") end end)
end
G.WireMore = wire

-- with the passive checks of GameFacts.lua (the saved flag at login, or the first press)
local startPassive = G.StartPassive
function G.StartPassive(pressed)
	local started = startPassive(pressed)
	wire()
	wireRemember()
	-- by themselves a few seconds after every start: this character's realm facts and one hook reading
	if started then
		L.After(6, function()
			realmChar(pressed and "switched on" or "login")
			hooksNow(pressed and "switched on" or "login")
		end)
	end
	return started
end

-- with every press of "Game facts", and the end of an Auto check once Game facts is on
local instant = G.Instant
function G.Instant(why)
	if why ~= "auto" or factsOn() then
		pcall(realmChar, why == "auto" and "auto" or "press")
		pcall(styleAgain)
		pcall(hooksNow, why == "auto" and "auto" or "press")
		pcall(whisperCheck, why == "auto" and "auto" or "press")
	end
	return instant(why)
end
L.GameFactsInstant = G.Instant

function G.AcceptNoClick()
	wire()
	S.arm = { invite = true, summon = true, untilT = L.Now() + ARM_SECS }
	local arm = S.arm
	L.Log("facts", "L17: armed for " .. ARM_SECS .. " s (invite and summon)")
	say("Accept without a click: armed for " .. ARM_SECS .. " seconds. The next party invite or summon, whichever comes first, is accepted for you once with no click (never in combat). Click again for the other.")
	-- a summon that is already waiting: the event has passed, so this is the timer's try
	local left = summonLeft()
	if type(left) == "number" and left > 0 then L.After(1, function() if S.arm == arm then trySummon("timer") end end) end
	L.After(ARM_SECS + 0.5, function()
		if S.arm ~= arm then return end
		local nothing = arm.invite and arm.summon
		if nothing then say("Accept without a click: 60 seconds are over, nothing arrived. Click it again when you are ready.") end
		L.Log("facts", "L17: the 60 s are over; " .. (nothing and "no invite and no summon arrived" or "one try was made"))
		S.arm = nil
	end)
end

function G.Mailbox()
	wire()
	if mailOpen() then mailRead("button"); return end
	say("Mailbox check: no mailbox is open. Open one: it is read by itself the moment it opens (nothing is taken).")
end

-- the panel's rows, before its last one ("Show the answers")
local ROWS = {
	{ "Accept without a click", "Second account, out of combat. Armed for 60 seconds: the next party invite or summon, whichever comes first, is accepted for you once with no click. It says joined, accepted or blocked. Click again for the other.", G.AcceptNoClick },
	{ "Hooks and the taint log", "Plays one soft sound and says whether a run-after hook heard it. If only one taint log state is known, it switches the log, reloads once by itself and puts the log back.", G.Hooks },
	{ "Whisper check", "Asks the game whether you, your target, a logged-out friend, a logged-out guild member and the last other player you targeted or grouped with can be whispered (C_ChatInfo.RequestCanLocalWhisperTarget). Prints the answers and how fast they came; \"offline\" means that player is logged out. Sends no whisper.", G.WhisperCheck },
	{ "Mailbox check", "With a mailbox open: writes each mail's sender, money, subject and days left into the Lab log. Takes nothing. A mailbox you open later is read by itself.", G.Mailbox },
}
if type(G.PANEL) == "table" then
	for _, row in ipairs(ROWS) do table.insert(G.PANEL, #G.PANEL, row) end
end
