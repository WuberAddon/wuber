-- Wuber Lab (developer only, never ship): GameFacts3.lua - "Send matrix" (job 2630, item 07). DRAFT, not in the Lab yet.
-- Joins WuberLab\ after GameFacts2.lua (add "GameFacts3.lua" to WuberLab.toc after it).
--
-- Style: a Game facts MOMENT check with a panel button (like "Accept without a click", GameFacts2.lua:712-720, and the
-- "Second account: test lines" of GameFacts.lua:1132-1246), plus a passive listener for the receiving window. Why this kind and
-- not an Auto check: every question here is about a chat send that the second account sees, and about the difference between a
-- send from a click and a send from a timer; the Auto check runs with one window and sends nothing.
--
-- NEEDS THE PLAYER'S OWN SECOND ACCOUNT in the same party, in a quiet place (it says one harmless line in Say and Yell and in
-- WuberNet). Batch it with the summon/trade session. Press "Game facts" once on BOTH windows first (starts the passive part, which
-- registers the prefix and listens), target the second account on the pressing window, out of combat, press "Send matrix".
-- Rules kept: no typing, no macro, no protected call, nothing in combat, every game call under pcall with type checks, never chat
-- text or another player's name written down (only shapes), the one second-account name never saved, nothing sent to anyone else:
-- Say, Yell and Emote are heard by whoever stands near; the line is "wuberlab send matrix".
--
-- WHAT IT DOES, each of WHISPER (the second account), PARTY, RAID, SAY, YELL, EMOTE, CHANNEL (WuberNet only), twice:
--   from the button's click (a hardware event), then 3 s later from a timer (no hardware event):
--     C_ChatInfo.SendChatMessage(line, type, nil, target)   and   C_ChatInfo.SendAddonMessage("WLABSM", "x", type, target)
--   and logs, per call: the return values and their COUNT, the error text if it raised, and every event that follows within 1 s
--   with ALL its arguments (ADDON_ACTION_BLOCKED, ADDON_ACTION_FORBIDDEN, CHAT_MSG_RESTRICTED, UI_ERROR_MESSAGE; chat strings
--   verbatim, names and chat text only as shapes), and whether the line's own echo event came back (CHAT_MSG_WHISPER_INFORM, _PARTY,
--   _RAID, _SAY, _YELL, _EMOTE or _TEXT_EMOTE, _CHANNEL, CHAT_MSG_ADDON).
-- Then, from timers: an addon message of 255, 256 (and 248, 249: prefix plus tab plus text = 255 / 256) bytes to PARTY; a burst of 12
--   addon messages to PARTY in one frame (each result code: the throttle); a whisper (addon message and chat line) to a name no
--   character has (the result code and the system line).
-- On both windows (passive): every CHAT_MSG_ADDON with the prefix WLABSM: the 9 values' types, the channel string, the sender's
--   spelling as shapes (length, space, hyphen, equals my own name), and the registration result codes of the prefix.
--
-- WHERE IT IS WRITTEN: WuberLabDB.facts["SENDM"] (one entry, the newest run; the pressing window) and WuberLabDB.facts["SENDM.heard"]
-- (both windows), each also as one line in the Lab log (kind "facts"), like every Game facts answer. The Lab report reads them through
-- G.Summary because the two ids are added to G.IDS below.
--
-- HOW IT BECOMES A FIXTURE: tools/rec/import-send-matrix.lua (import_send_matrix.lua in this folder) reads WuberLab.lua of both
-- accounts and writes tests/fixtures/rec/real-send-matrix.lua; proof_test.lua's last test then compares the fake with it.

local _, L = ...

local G = L.GameFacts
if type(G) ~= "table" or type(G.Put) ~= "function" then return end

local plain, secret = L.plain, L.IsSecret
local NOCALL = "no such call"
local PREFIX, LINE, NOBODY = "WLABSM", "wuberlab send matrix", "Wuberlabnobody"
local GAP, WATCH = 1.5, 1.0 -- seconds between two steps from the timer; seconds an event is waited for
local TYPES = { "WHISPER", "PARTY", "RAID", "SAY", "YELL", "EMOTE", "CHANNEL" }
local WATCHED = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "CHAT_MSG_RESTRICTED", "UI_ERROR_MESSAGE", "CHAT_MSG_SYSTEM",
	"CHAT_MSG_ADDON", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_CHANNEL" }
local ECHO = { CHAT_MSG_WHISPER_INFORM = "WHISPER", CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY", CHAT_MSG_RAID = "RAID",
	CHAT_MSG_RAID_LEADER = "RAID", CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL", CHAT_MSG_EMOTE = "EMOTE", CHAT_MSG_TEXT_EMOTE = "EMOTE",
	CHAT_MSG_CHANNEL = "CHANNEL" }
local VERBATIM = { ADDON_ACTION_BLOCKED = true, ADDON_ACTION_FORBIDDEN = true, UI_ERROR_MESSAGE = true, CHAT_MSG_RESTRICTED = true }

local S = { wired = false, run = nil, cur = nil, heard = {}, token = 0 }
G.SendMatrixState = S -- (for the offline test of the Lab)

local function gfn(name) return rawget(_G, name) end
local function tfn(tname, name)
	local t = rawget(_G, tname)
	return type(t) == "table" and t[name] or nil
end
local function say(text) if L.Say then L.Say(text) else print(text) end end
local function short(s, n) return tostring(s or ""):sub(1, n or 60) end
local function round(x) return math.floor(x * 100 + 0.5) / 100 end
local function pack(...) return { n = select("#", ...), ... } end

-- call(fn, ...): the results as { n = count, [1..n] }, or nil plus "no such call" / "error: text"
local function call(fn, ...)
	if type(fn) ~= "function" then return nil, NOCALL end
	local r = pack(pcall(fn, ...))
	if not r[1] then
		local okS, s = pcall(tostring, r[2])
		return nil, "error: " .. short(okS and s or "?", 100)
	end
	local out = { n = r.n - 1 }
	for i = 2, r.n do out[i - 1] = r[i] end
	return out
end

-- first(fn, ...): the first result (boolean, number, short string) or "no such call" / "error: ..." / "secret" / "nil"
local function first(fn, ...)
	local r, why = call(fn, ...)
	if not r then return why end
	local v = r[1]
	if secret(v) then return "secret" end
	if v == nil then return "nil" end
	if type(v) == "boolean" or type(v) == "number" then return v end
	return short(v, 40)
end

-- a value as it can be written down: its type and, for a string, only its shape; a secret is only said so
local function shape(v)
	if secret(v) then return "secret" end
	local t = type(v)
	if t == "number" or t == "boolean" then return t .. ":" .. tostring(v) end
	if t == "string" then
		return ("string(len %d%s%s)"):format(#v, v:find(" ", 1, true) and ",space" or "", v:find("-", 1, true) and ",hyphen" or "")
	end
	return t
end

-- an event argument: words of the game's own messages verbatim (the second account's name taken out), everything else a shape
local function word(v, ev)
	if VERBATIM[ev] and not secret(v) and type(v) == "string" then
		local s = v:gsub(NOBODY, "?")
		if S.target then s = s:gsub(S.target:gsub("%p", "%%%0"), "?") end
		return short(s, 90)
	end
	return shape(v)
end

local function me()
	local r = call(gfn("UnitName"), "player")
	local n = r and r[1]
	if secret(n) or type(n) ~= "string" then return nil end
	return n
end

-- the receiving side: what one CHAT_MSG_ADDON of ours looked like, on this window
local function flush(token)
	if token ~= S.token or #S.heard == 0 then return end
	local first1 = S.heard[1]
	G.Put("SENDM.heard", ("heard %d WLABSM messages; first: channel %s, sender %s, %s values"):format(#S.heard, tostring(first1.chan),
		tostring(first1.sender and first1.sender.shape), tostring(first1.n)), { heard = S.heard, prefixRegistered = S.reg }, true)
end

local function hear(...)
	local a = pack(...)
	local name = me()
	local sender = a[4]
	local rec = { n = a.n, chan = (not secret(a[3]) and type(a[3]) == "string") and short(a[3], 20) or shape(a[3]), at = round(L.Now()) }
	rec.types = {}
	for i = 1, a.n do rec.types[i] = secret(a[i]) and "secret" or type(a[i]) end
	rec.sender = { shape = shape(sender) }
	if not secret(sender) and type(sender) == "string" then
		rec.sender.equalsMyName = name ~= nil and sender == name
		rec.sender.startsWithMyName = name ~= nil and sender:sub(1, #name) == name
		rec.sender.hasHyphen = sender:find("-", 1, true) ~= nil
		rec.sender.hasSpace = sender:find(" ", 1, true) ~= nil
	end
	rec.target = shape(a[5])
	rec.localID = shape(a[7])
	if #S.heard < 60 then S.heard[#S.heard + 1] = rec end
	S.token = S.token + 1
	local token = S.token
	L.After(6, function() flush(token) end)
end

-- the latest started step of this kind and chat type (an echo belongs to it), or the current one
local function latest(run, kind, chat)
	for i = #run.steps, 1, -1 do
		local s = run.steps[i]
		if s.kind == kind and s.chat == chat then return s end
	end
	return nil
end

local function onSeen(ev, ...)
	local n = select("#", ...)
	if ev == "CHAT_MSG_ADDON" then
		local prefix = ...
		if not secret(prefix) and prefix == PREFIX then pcall(hear, ...) end
	end
	local run = S.run
	if not run then return end
	local e = { ev = ev, n = n, dt = round(L.Now() - run.t0) }
	local step
	if ECHO[ev] then
		local text = ...
		if secret(text) or text ~= LINE then return end -- somebody else's line
		e.ourLine = true
		step = latest(run, "chat", ECHO[ev])
	elseif ev == "CHAT_MSG_ADDON" then
		local prefix, _, channel = ...
		if secret(prefix) or prefix ~= PREFIX then return end
		e.channel = secret(channel) and "secret" or short(channel, 20)
		step = (not secret(channel)) and latest(run, "addon", channel) or nil
	elseif ev == "CHAT_MSG_SYSTEM" then
		local text = ...
		if secret(text) or type(text) ~= "string" or not text:find(NOBODY, 1, true) then return end
		e[1] = word(text, "UI_ERROR_MESSAGE")
		step = S.cur
	else
		for i = 1, math.min(n, 6) do e[i] = word((select(i, ...)), ev) end
		step = S.cur
	end
	e.step = step and step.i or nil
	run.events[#run.events + 1] = e
	if step then
		step.events = step.events or {}
		step.events[#step.events + 1] = e
	end
end

local function wire()
	if S.wired then return end
	S.wired = true
	for _, ev in ipairs(WATCHED) do L.On(ev, function(...) onSeen(ev, ...) end) end
	local reg = tfn("C_ChatInfo", "RegisterAddonMessagePrefix") or gfn("RegisterAddonMessagePrefix")
	local r, why = call(reg, PREFIX)
	S.reg = r and { n = r.n, first = first(function() return unpack(r, 1, r.n) end) } or why
	if r then
		local r2 = call(reg, PREFIX) -- again: the answer for a prefix that is already registered
		S.regAgain = r2 and first(function() return unpack(r2, 1, r2.n) end) or "none"
	end
end

-- the second account as a whisper takes it, or nil plus why (the same rules as GameFacts.lua whisperTarget)
local function targetName()
	if first(gfn("UnitExists"), "target") ~= true then return nil, "target your second account first" end
	if first(gfn("UnitIsPlayer"), "target") ~= true then return nil, "your target is not a player" end
	if first(gfn("UnitIsUnit"), "target", "player") == true then return nil, "your target is yourself" end
	local r = call(gfn("UnitName"), "target")
	local f, sur = r and r[1], r and r[2]
	if secret(f) or type(f) ~= "string" or f == "" or f == "Unknown" then return nil, "the target's name is hidden" end
	local full = f
	if not secret(sur) and type(sur) == "string" and sur ~= "" then
		local c = rawget(_G, "Constants")
		local sc = type(c) == "table" and type(c.CharacterNameSeparatorConsts) == "table" and c.CharacterNameSeparatorConsts or nil
		local sep = sc and type(sc.CHARACTERNAME_SURNAME_SEPARATOR) == "string" and sc.CHARACTERNAME_SURNAME_SEPARATOR ~= "" and sc.CHARACTERNAME_SURNAME_SEPARATOR or " "
		full = f .. sep .. sur
	end
	return (full:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "-"))
end

local function targetFor(step)
	if step.target then return step.target end
	if step.chat == "WHISPER" then return S.target end
	if step.chat == "CHANNEL" then return S.chan end
	return nil
end

-- one call. kind "chat": C_ChatInfo.SendChatMessage(line, type, nil, target); kind "addon": C_ChatInfo.SendAddonMessage(prefix, text, type, target)
local function runStep(run, step)
	run.steps[#run.steps + 1] = step
	step.i = #run.steps
	step.at = round(L.Now() - run.t0)
	S.cur = step
	local fn, via
	if step.kind == "chat" then
		fn, via = tfn("C_ChatInfo", "SendChatMessage"), "C_ChatInfo.SendChatMessage"
		if type(fn) ~= "function" then fn, via = gfn("SendChatMessage"), "SendChatMessage" end
	else
		fn, via = tfn("C_ChatInfo", "SendAddonMessage"), "C_ChatInfo.SendAddonMessage"
		if type(fn) ~= "function" then fn, via = gfn("SendAddonMessage"), "SendAddonMessage" end
	end
	step.via = via
	local target = targetFor(step)
	if (step.chat == "CHANNEL" and target == nil) or (step.chat == "WHISPER" and target == nil) then
		step.skipped = "no target (" .. step.chat .. ")"
		return
	end
	local r, why
	if step.kind == "chat" then
		r, why = call(fn, LINE, step.chat, nil, target)
	else
		r, why = call(fn, PREFIX, step.text or "x", step.chat, target)
	end
	step.err = why
	if r then
		step.n = r.n
		step.ret = {}
		for i = 1, math.min(r.n, 3) do
			local v = r[i]
			if type(v) == "number" or type(v) == "boolean" then step.ret[i] = v else step.ret[i] = shape(v) end
		end
	end
end

-- the first value a step got back (a false or a 0 is a value), else why it got none
local function retOf(step)
	if step.ret and step.ret[1] ~= nil then return step.ret[1] end
	return step.err or "nothing returned"
end

local function matrixSteps(trigger)
	local out = {}
	for _, t in ipairs(TYPES) do
		out[#out + 1] = { kind = "chat", chat = t, trigger = trigger }
		out[#out + 1] = { kind = "addon", chat = t, trigger = trigger }
	end
	return out
end

local function finish(run)
	if S.run ~= run then return end
	S.run, S.cur = nil, nil
	local blocked, echoes, raised = 0, 0, 0
	for _, e in ipairs(run.events) do
		if e.ev == "ADDON_ACTION_BLOCKED" or e.ev == "ADDON_ACTION_FORBIDDEN" then blocked = blocked + 1 end
		if e.ourLine then echoes = echoes + 1 end
	end
	for _, s in ipairs(run.steps) do
		if s.label == "offline" and run.offline then
			for _, e in ipairs(s.events or {}) do
				if e.ev == "CHAT_MSG_SYSTEM" and not run.offline.system then run.offline.system = e[1] end
			end
		end
	end
	local out = { steps = {}, burst = run.burst, sizes = run.sizes, offline = run.offline, pre = run.pre, aborted = run.aborted }
	for _, s in ipairs(run.steps) do
		if s.err then raised = raised + 1 end
		s.echo = false
		for _, e in ipairs(s.events or {}) do if e.ourLine or (e.ev == "CHAT_MSG_ADDON" and s.kind == "addon") then s.echo = true end end
		out.steps[#out.steps + 1] = s
	end
	out.heard = S.heard
	local line = ("%d calls, %d raised, %d blocked-events, %d line echoes, restricted=%s, lockdown=%s%s"):format(#run.steps, raised, blocked, echoes,
		tostring(run.pre.restricted), tostring(run.pre.lockdown), run.aborted and (", aborted: " .. run.aborted) or "")
	G.Put("SENDM", line, out, true)
	say("Send matrix: done. " .. line)
end

-- the steps from the timer, one every GAP seconds
local function sequence(run, list, i, after)
	if S.run ~= run then return end
	if i > #list then L.After(WATCH + 0.3, after) return end
	if L.InCombat() then run.aborted = "combat" L.After(0.1, function() finish(run) end) return end
	local step = list[i]
	if step.burst then
		run.steps[#run.steps + 1] = step
		step.i = #run.steps
		S.cur = step
		local fn = tfn("C_ChatInfo", "SendAddonMessage") or gfn("SendAddonMessage")
		run.burst = {}
		for k = 1, 12 do
			local r, why = call(fn, PREFIX, "b" .. k, "PARTY")
			run.burst[k] = r and (type(r[1]) == "number" and r[1] or shape(r[1])) or why
		end
		step.results = run.burst
	else
		runStep(run, step)
		if step.label == "size" then run.sizes[step.len] = retOf(step) end
		if step.label == "offline" then
			run.offline = run.offline or {}
			if step.kind == "addon" then run.offline.addonRet = retOf(step)
			else run.offline.chatN, run.offline.chatRet = step.n, retOf(step) end
		end
	end
	L.After(GAP, function() sequence(run, list, i + 1, after) end)
end

function G.SendMatrixPress()
	local button = "Send matrix"
	if S.run then say(button .. ": a run is under way (about 45 seconds)."); return end
	if L.InCombat() then say(button .. ": leave combat first. Nothing was sent."); return end
	if first(gfn("IsInGroup")) ~= true then say(button .. ": you are not in a group with your second account. Nothing was sent."); return end
	wire()
	local who, why = targetName()
	if not who then say(button .. ": " .. why .. ". Nothing was sent."); return end
	S.target = who
	local ci = call(gfn("GetChannelName"), "WuberNet")
	S.chan = ci and type(ci[1]) == "number" and ci[1] > 0 and ci[1] or nil
	local en = rawget(_G, "Enum")
	local rt = type(en) == "table" and type(en.AddOnRestrictionType) == "table" and en.AddOnRestrictionType.Chat or nil
	local run = { t0 = L.Now(), steps = {}, events = {}, sizes = {}, pre = {
		restricted = first(tfn("C_ChatInfo", "AreOutgoingAddonChatMessagesRestricted")),
		lockdown = first(tfn("C_ChatInfo", "InChatMessagingLockdown")),
		chatRestrictionActive = (function()
			if rt == nil then return "no such enum" end
			return first(tfn("C_RestrictedActions", "IsAddOnRestrictionActive"), rt)
		end)(),
		inRaid = first(gfn("IsInRaid")), inInstance = first(gfn("IsInInstance")), channel = S.chan ~= nil,
		prefixFirst = S.reg, prefixAgain = S.regAgain,
	} }
	S.run = run
	L.Log("facts", "SENDM: started (click batch now, timer batch in 3 s)")
	-- 1. from the click (a hardware event): every call in this frame
	for _, step in ipairs(matrixSteps("click")) do pcall(runStep, run, step) end
	-- 2. from a timer: the same matrix, then sizes, the offline whisper, the burst
	local list = matrixSteps("timer")
	for _, n in ipairs({ 255, 256, 248, 249 }) do
		list[#list + 1] = { kind = "addon", chat = "PARTY", trigger = "timer", label = "size", len = n, text = string.rep("x", n) }
	end
	list[#list + 1] = { kind = "addon", chat = "WHISPER", trigger = "timer", label = "offline", target = NOBODY }
	list[#list + 1] = { kind = "chat", chat = "WHISPER", trigger = "timer", label = "offline", target = NOBODY }
	list[#list + 1] = { kind = "addon", chat = "PARTY", trigger = "timer", label = "burst", burst = true }
	L.After(3, function() sequence(run, list, 1, function() finish(run) end) end)
end

-- the second window: with the passive checks of GameFacts.lua (the saved flag at login, or the first press of Game facts)
local startPassive = G.StartPassive
if type(startPassive) == "function" then
	function G.StartPassive(pressed)
		local started = startPassive(pressed)
		wire()
		return started
	end
end

for _, row in ipairs({
	{ "SENDM", "Send matrix", "moment", "not pressed yet (second account in the party)" },
	{ "SENDM.heard", "Send matrix: what this window heard", "passive", "no WLABSM message heard yet" },
}) do G.IDS[#G.IDS + 1] = row end

-- (job 2609b) the Lab bar's More menu has the Send matrix button (it calls G.SendMatrixPress); it is not in the Game facts panel.
