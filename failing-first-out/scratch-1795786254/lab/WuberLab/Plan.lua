-- Wuber Lab (developer only, never ship): the test plan's state, its auto-ticks and probes, and
-- the sync between the tester's four characters.
--
-- State: WuberLabDB.plan[key] = { r = "auto"|"pass"|"fail"|nil, at = epoch, who = name, by, note }
--   key: a step id ("s3_r5"), or "<step id>@<character key>" for one character's probe result
--   (r = "ok"|"no"), or "_reset" (at = when the plan was reset: anything older is gone).
-- Last write wins, by `at`. Every change is a "plan" line in the timeline.
--
-- Sync: addon messages with prefix "WLAB", ONLY to and from Anita Lift, Farra Way, Hayley Cab and
-- Wuber Rocks (anyone else is ignored): PARTY when grouped with them, else WHISPER to the ones
-- known to be online. Never chat. Messages (fields joined by "~"):
--   H                        hello: "send me what you have"
--   U~key~at~r~who~by~note   one entry
--   B~key,at,r,who,by~...    several entries without notes (a dump)
--   R~at                     the plan was reset

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain

L.PLAN_PREFIX = "WLAB"
local CAST_NAMES = { ["anita lift"] = "Anita Lift", ["farra way"] = "Farra Way", ["hayley cab"] = "Hayley Cab", ["wuber rocks"] = "Wuber Rocks" }
L.CAST_NAMES = CAST_NAMES
L.PLAN_NAMES = CAST_NAMES
local SEND_GAP = 1.5        -- seconds between two sync messages (Wuber's own messages come first)
local DONE = { auto = true, pass = true, fail = true }

L.PLAN_STEP = {}
L.PLAN_SECTION = {}
do
	for si, sec in ipairs(L.PLAN or {}) do
		L.PLAN_SECTION[sec.id] = sec
		sec.index = si
		for i, s in ipairs(sec.steps) do
			s.sec, s.index = sec.id, i
			L.PLAN_STEP[s.id] = s
		end
	end
end

local function db()
	if not L.db then return nil end
	if type(L.db.plan) ~= "table" then L.db.plan = {} end
	return L.db.plan
end

local function resetAt()
	local p = db()
	local r = p and p._reset
	return type(r) == "table" and num(r.at) or 0
end

-- The entry for a key, or nil (also nil when older than the last reset).
function L.PlanRec(key)
	local p = db()
	local rec = p and p[key]
	if type(rec) ~= "table" or (num(rec.at) or 0) <= resetAt() then return nil end
	return rec
end

function L.PlanDone(id)
	local rec = L.PlanRec(id)
	return rec ~= nil and DONE[rec.r] == true
end

-- Every step in order: { step, section }
function L.PlanSteps()
	local out = {}
	for _, sec in ipairs(L.PLAN or {}) do
		for _, s in ipairs(sec.steps) do out[#out + 1] = s end
	end
	return out
end

function L.PlanNext()
	for _, s in ipairs(L.PlanSteps()) do
		if not L.PlanDone(s.id) then return s end
	end
	return nil
end

function L.PlanProgress(secId)
	local d, n = 0, 0
	for _, sec in ipairs(L.PLAN or {}) do
		if not secId or sec.id == secId then
			for _, s in ipairs(sec.steps) do
				n = n + 1
				if L.PlanDone(s.id) then d = d + 1 end
			end
		end
	end
	return d, n
end

L.planChanged = function() end -- the panel sets it

local function logRec(key, rec, src)
	L.Log("plan", ("%s;%s;by=%s;who=%s;src=%s%s"):format(key, rec.r or "cleared", tostring(rec.by or "-"), tostring(rec.who or "?"), src,
		rec.note and (";note=" .. rec.note) or ""))
end

local queueUpdate -- below (sync)
local evaluate    -- below (probes)

-- Stores an entry if it is newer than what we have. Returns whether it changed.
local function store(key, rec, src)
	local p = db()
	if not p or type(key) ~= "string" or key == "" or type(rec) ~= "table" then return false end
	local at = num(rec.at) or 0
	if key == "_reset" then
		if at <= resetAt() then return false end
		p._reset = { at = at, who = rec.who }
		for k, v in pairs(p) do
			if k ~= "_reset" and type(v) == "table" and (num(v.at) or 0) <= at then p[k] = nil end
		end
		L.Log("plan", ("reset;who=%s;src=%s"):format(tostring(rec.who or "?"), src))
		pcall(L.planChanged)
		return true
	end
	if at <= resetAt() then return false end
	local old = p[key]
	if type(old) == "table" and (num(old.at) or 0) >= at then return false end
	local r = rec.r
	if r ~= nil and not (DONE[r] or r == "ok" or r == "no") then r = nil end
	local new = { r = r, at = at, who = str(rec.who), by = str(rec.by), note = str(rec.note) }
	p[key] = new
	logRec(key, new, src)
	pcall(L.planChanged, key)
	if key:find("@", 1, true) and evaluate then evaluate(key:match("^([^@]+)@")) end
	return true
end
L.PlanStore = store

-- A local change: fields over the old entry, stamped now, shared with the others.
local function set(key, fields)
	local old = L.PlanRec(key) or {}
	local rec = { r = old.r, note = old.note, by = old.by }
	for k, v in pairs(fields) do rec[k] = v end
	if fields.r == false then rec.r = nil end
	rec.at = math.max(L.Epoch(), (num(old.at) or 0) + 0.001)
	rec.who = L.me or "?"
	if store(key, rec, "local") then
		if queueUpdate then queueUpdate(key) end
		return true
	end
	return false
end

-- Ticked by a detector: only when not done yet.
function L.PlanTick(id, by)
	if not L.PLAN_STEP[id] or L.PlanDone(id) then return false end
	return set(id, { r = "auto", by = by or "auto" })
end

-- By hand: "pass", "fail" or nil (clear).
function L.PlanMark(id, r)
	if not L.PLAN_STEP[id] then return false end
	if r ~= "pass" and r ~= "fail" then r = false end
	return set(id, { r = r, by = "hand" })
end

function L.PlanNote(id, text)
	if not L.PLAN_STEP[id] then return false end
	text = tostring(text or ""):gsub("[\r\n|~]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 150 then text = text:sub(1, 150) end
	return set(id, { note = text ~= "" and text or false })
end

function L.PlanReset()
	local p = db()
	if not p then return false end
	local at = L.Epoch()
	for _, rec in pairs(p) do
		if type(rec) == "table" and (num(rec.at) or 0) >= at then at = num(rec.at) + 0.001 end
	end
	store("_reset", { at = at, who = L.me }, "local")
	if queueUpdate then queueUpdate("_reset") end
	L.planSeen = {}
	return true
end

-- The plan's steps, kept with the state so the report can show them all.
function L.SavePlanSteps()
	if not L.db then return end
	local out = {}
	for _, sec in ipairs(L.PLAN or {}) do
		for _, s in ipairs(sec.steps) do
			out[#out + 1] = { id = s.id, sec = sec.title, text = s.text, who = s.who, check = s.check or nil, auto = (s.sig or s.all or s.probe) and true or nil }
		end
	end
	L.db.planSteps = out
end

---------------------------------------------------------------------------
-- Auto-ticks: the same signals as the checklist
---------------------------------------------------------------------------

L.planSeen = {} -- [stepId][signal] = true (steps needing several signals), this session

function L.PlanSignal(name, info)
	for _, s in ipairs(L.PlanSteps()) do
		local hit = false
		for _, sg in ipairs(s.sig or {}) do if sg == name then hit = true end end
		local inAll = false
		for _, sg in ipairs(s.all or {}) do if sg == name then inAll = true end end
		if hit or inAll then
			local ok = true
			if type(info) == "table" and info.fake == true and not s.fake then ok = false end
			if s.minCount and (tonumber(info) or 0) < s.minCount then ok = false end
			if ok and hit then L.PlanTick(s.id, name) end
			if ok and inAll then
				local seen = L.planSeen[s.id] or {}
				L.planSeen[s.id] = seen
				seen[name] = true
				local all = true
				for _, sg in ipairs(s.all) do if not seen[sg] then all = false end end
				if all then L.PlanTick(s.id, table.concat(s.all, "+")) end
			end
		end
	end
end
L.signalFns[#L.signalFns + 1] = function(name, info) L.PlanSignal(name, info) end

---------------------------------------------------------------------------
-- Probes: checks run on each character; a step ticks when every named character said ok
---------------------------------------------------------------------------

local function loaded(name) return (L.AddonInfo(name)) == true end

L.PROBES = {
	-- Wuber 1.1's new files are there: only a full restart loads them
	fresh = function()
		local W = L.W()
		return W ~= nil and type(W.FX) == "table" and type(W.Map) == "table"
	end,
	addons = function()
		return loaded("Wuber") and loaded(L.ADDON) and loaded("RitualRides") and not loaded("WuberTest") and not loaded("Wuber Test")
	end,
	sound = function()
		local get = (type(C_CVar) == "table" and C_CVar.GetCVar) or GetCVar
		local v = plain(call(get, "Sound_EnableSoundWhenGameIsInBG"))
		if v == nil then return nil end
		return tostring(v) == "1"
	end,
	f1 = function()
		-- F1 is the author's multibox swap key on purpose: allowed unless "/lab f1 require" was chosen
		if not (L.db and L.db.requireF1Free) then return true, "allowed" end
		if type(GetBindingAction) ~= "function" then return nil end
		local ok, action = pcall(GetBindingAction, "F1")
		if not ok then return nil end
		action = plain(action)
		if action == nil then return true end
		return action == ""
	end,
	logout = function() return true end,
}

-- Re-checks one step from the probe results (any character's): ticks it when all are ok.
evaluate = function(id)
	local s = L.PLAN_STEP[id]
	if not s or not s.perChar or L.PlanDone(id) then return end
	local first
	for _, key in ipairs(s.perChar) do
		local rec = L.PlanRec(id .. "@" .. key)
		if not rec or rec.r ~= "ok" then return end
		if not first or key < first then first = key end
	end
	-- one window ticks it (the first of them by name), so four don't race to write it
	if first ~= L.myKey then return end
	L.PlanTick(id, "probe")
end
L.PlanEvaluate = evaluate

-- /lab f1 allow|require: whether the login check wants F1 unbound (default: F1 may stay bound)
function L.F1Slash(arg)
	arg = (tostring(arg or "")):lower()
	if arg == "require" then L.db.requireF1Free = true elseif arg == "allow" then L.db.requireF1Free = nil end
	L.Say("F1 " .. (L.db.requireF1Free and "must be unbound (login check and plan step)" or "may stay bound (the swap key)"))
end

-- Runs this character's probes (skip: names not to run now, e.g. "logout" at login).
function L.RunPlanProbes(only)
	local me = L.myKey
	if not me then return end
	for _, s in ipairs(L.PlanSteps()) do
		if s.probe and s.perChar and (not only or only == s.probe) and (only or s.probe ~= "logout") then
			local mine = false
			for _, k in ipairs(s.perChar) do if k == me then mine = true end end
			local fn = L.PROBES[s.probe]
			if mine and fn then
				local ok, res = pcall(fn)
				if ok and res ~= nil then
					local key = s.id .. "@" .. me
					local old = L.PlanRec(key)
					local r = res and "ok" or "no"
					if not old or old.r ~= r then set(key, { r = r, by = "probe:" .. s.probe }) end
					L.Log("probe", ("plan %s (%s) on %s: %s"):format(s.id, s.probe, tostring(L.me), r))
				end
			end
			evaluate(s.id)
		end
	end
end

---------------------------------------------------------------------------
-- Sync between the four characters
---------------------------------------------------------------------------

-- Outgoing work per destination ("GROUP", or a teammate's key for a whisper): a hello and the
-- set of entry keys that changed since they last heard. One message per SEND_GAP, round robin;
-- changed entries are packed into as few messages as fit (B), a note goes alone (U).
local pending = {}        -- [dest] = { hello = true, keys = { [key] = true } }
local order = {}          -- destinations, for the round robin
local peers = {}          -- [key] = { at = GetTime() last heard } or { offline = GetTime() }
local dumpedTo = {}       -- [dest] = GetTime() of the last full dump
local whisperedAt = {}    -- [key] = GetTime() of our last whisper (to hide "No player named")
L.planPeers = peers

local function isCast(key) return key ~= nil and CAST_NAMES[key] ~= nil end

local function clean(v, max)
	v = tostring(v == nil and "" or v):gsub("[~|\r\n]", " ")
	if max and #v > max then v = v:sub(1, max) end
	return v
end

local function unitKey(unit)
	local a, b = L.call(UnitName, unit)
	a, b = L.str(a), L.str(b)
	if not a then return nil end
	return L.Key(b and (a .. " " .. b) or a)
end

local function groupHas(key)
	for i = 1, 4 do
		if unitKey("party" .. i) == key then return true end
	end
	for i = 1, 40 do
		if unitKey("raid" .. i) == key then return true end
	end
	return false
end

local function inRaid()
	return type(IsInRaid) == "function" and plain(call(IsInRaid)) == true
end

local function inGroup()
	if type(IsInGroup) == "function" then return plain(call(IsInGroup)) == true end
	return (num(call(GetNumGroupMembers)) or 0) > 0
end

local function work(dest)
	local w = pending[dest]
	if not w then
		w = { keys = {} }
		pending[dest] = w
		order[#order + 1] = dest
	end
	return w
end

-- Where a change goes: the group for teammates in it, a whisper for the others heard from.
local function destinations()
	local out, viaGroup = {}, false
	local grouped = inGroup()
	for key in pairs(CAST_NAMES) do
		if key ~= L.myKey then
			local p = peers[key]
			if grouped and groupHas(key) then
				viaGroup = true
			elseif p and not p.offline then
				out[#out + 1] = key
			end
		end
	end
	if viaGroup then table.insert(out, 1, "GROUP") end
	return out
end

queueUpdate = function(key)
	for _, d in ipairs(destinations()) do work(d).keys[key] = true end
end

local function dump(dest)
	local t = L.Now()
	if dumpedTo[dest] and t - dumpedTo[dest] < 30 then return end
	dumpedTo[dest] = t
	local p = db()
	if not p then return end
	local w = work(dest)
	for key in pairs(p) do
		if key == "_reset" or L.PlanRec(key) then w.keys[key] = true end
	end
end

local function destOf(key)
	if inGroup() and groupHas(key) then return "GROUP" end
	return key
end

local function entryText(key)
	local rec = L.PlanRec(key)
	if not rec then return nil end
	return ("%s,%.3f,%s,%s,%s"):format((clean(key, 40):gsub(",", " ")), num(rec.at) or 0, clean(rec.r),
		(clean(rec.who, 24):gsub(",", " ")), (clean(rec.by, 30):gsub(",", " ")))
end

-- The next message for a destination, taking its keys off the list.
local function nextMessage(w)
	if w.hello then
		w.hello = nil
		return "H"
	end
	local p = db()
	if not p then return nil end
	if w.keys._reset then
		w.keys._reset = nil
		local r = p._reset
		if type(r) == "table" then return ("R~%.3f"):format(num(r.at) or 0) end
	end
	-- sorted, so the same keys always go out in the same order (pairs order depends on insert history)
	local sorted = {}
	for key in pairs(w.keys) do sorted[#sorted + 1] = key end
	table.sort(sorted)
	-- a note goes alone
	for _, key in ipairs(sorted) do
		local rec = L.PlanRec(key)
		if rec and rec.note then
			w.keys[key] = nil
			return ("U~%s~%.3f~%s~%s~%s~%s"):format(clean(key, 40), num(rec.at) or 0, clean(rec.r), clean(rec.who, 24), clean(rec.by, 30),
				clean(rec.note, 150))
		end
	end
	local batch = "B"
	local taken = {}
	for _, key in ipairs(sorted) do
		local item = entryText(key)
		if not item then
			taken[#taken + 1] = key
		elseif #batch + 1 + #item <= 240 then
			batch = batch .. "~" .. item
			taken[#taken + 1] = key
		end
	end
	for _, k in ipairs(taken) do w.keys[k] = nil end
	if batch == "B" then return nil end
	return batch
end

local function send(dest, text)
	local CI = C_ChatInfo
	local fn = type(CI) == "table" and CI.SendAddonMessage or nil
	if type(fn) ~= "function" then return true end
	local chan, target = "WHISPER", nil
	if dest == "GROUP" then
		if not inGroup() then return true end
		chan = inRaid() and "RAID" or "PARTY"
	else
		if not isCast(dest) then return true end -- never anyone else
		target = CAST_NAMES[dest]
		whisperedAt[dest] = L.Now()
	end
	local ok, res = pcall(fn, L.PLAN_PREFIX, text, chan, target)
	res = plain(res)
	if ok and type(res) == "number" and (res == 3 or res == 8) then return false end -- throttled: later
	return true
end

local turn = 0
local function flush()
	local W = L.W()
	-- Wuber's own messages first
	if W and type(W.QueueLength) == "function" and (num(call(W.QueueLength)) or 0) > 0 then return end
	for _ = 1, #order do
		turn = turn % #order + 1
		local dest = order[turn]
		local w = pending[dest]
		if w and (w.hello or next(w.keys) ~= nil) then
			local hello = w.hello
			local text = nextMessage(w)
			if text then
				if not send(dest, text) then
					if hello then w.hello = true end -- throttled: the keys are sent again next time
					if text:sub(1, 1) ~= "H" then dumpedTo[dest] = nil end
				end
				return
			end
		end
	end
end

function L.PlanQueueLength()
	local n = 0
	for _, w in pairs(pending) do
		if w.hello then n = n + 1 end
		for _ in pairs(w.keys) do n = n + 1 end
	end
	return n
end

local function hello()
	for key in pairs(CAST_NAMES) do
		if key ~= L.myKey then
			local p = peers[key]
			if not (p and p.offline and L.Now() - p.offline < 300) then work(destOf(key)).hello = true end
		end
	end
end
L.PlanHello = hello

local function heard(key)
	local p = peers[key]
	local first = not p or p.offline ~= nil
	peers[key] = { at = L.Now() }
	return first
end

local function decodeB(fields)
	for i = 2, #fields do
		local key, at, r, who, by = fields[i]:match("^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)$")
		if key and key ~= "" then store(key, { at = tonumber(at), r = r ~= "" and r or nil, who = who, by = by }, "sync") end
	end
end

L.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender)
	if str(prefix) ~= L.PLAN_PREFIX then return end
	text, chan = str(text), str(chan)
	local key = L.Key(str(sender))
	if not text or not isCast(key) or key == L.myKey then return end -- only the tester's four
	if chan ~= "WHISPER" and chan ~= "PARTY" and chan ~= "RAID" then return end
	local fields = {}
	for f in (text .. "~"):gmatch("(.-)~") do fields[#fields + 1] = f end
	local kind = fields[1]
	if kind ~= "H" and kind ~= "U" and kind ~= "B" and kind ~= "R" then return end
	local first = heard(key)
	if kind == "U" then
		store(fields[2] or "", { at = tonumber(fields[3]), r = fields[4] ~= "" and fields[4] or nil, who = fields[5], by = fields[6],
			note = fields[7] ~= "" and fields[7] or nil }, "sync")
	elseif kind == "B" then
		decodeB(fields)
	elseif kind == "R" then
		store("_reset", { at = tonumber(fields[2]), who = CAST_NAMES[key] }, "sync")
	end
	-- a hello, or a teammate we hadn't heard from: they get everything we have
	if kind == "H" or first then dump(destOf(key)) end
end)

-- "No player named 'Anita Lift' is currently playing." after our whisper: they're offline;
-- the line is kept out of chat (only for our own whispers of the last 5 s).
local function notFound(text)
	text = str(text)
	if not text then return nil end
	local fmt = type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
	local pat = "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
	local name = text:match(pat)
	local key = name and L.Key(name)
	if key and isCast(key) and whisperedAt[key] and L.Now() - whisperedAt[key] < 5 then return key end
	return nil
end
L.PlanNotFound = notFound

L.On("CHAT_MSG_SYSTEM", function(text)
	local key = notFound(text)
	if key then
		peers[key] = { offline = L.Now() }
		pending[key] = nil
		for i = #order, 1, -1 do if order[i] == key then table.remove(order, i) end end
	end
end)

if type(ChatFrame_AddMessageEventFilter) == "function" then
	pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", function(_, _, text, ...)
		local ok, key = pcall(notFound, text)
		if ok and key then return true end
		return false, text, ...
	end)
end

-- Teammates who join our group are online: say hello through the group.
local lastGroup = {}
L.On("GROUP_ROSTER_UPDATE", function()
	local now, joined = {}, false
	for key in pairs(CAST_NAMES) do
		if key ~= L.myKey and groupHas(key) then
			now[key] = true
			if not lastGroup[key] then
				joined = true
				peers[key] = { at = L.Now() }
			end
		end
	end
	lastGroup = now
	if joined then work("GROUP").hello = true end
end)

if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, L.PLAN_PREFIX)
end

L.OnLogin(function()
	db()
	L.SavePlanSteps()
	L.After(6, hello)
	L.After(10, function() L.RunPlanProbes() end)
	L.Every(SEND_GAP, flush)
end)

L.On("PLAYER_LOGOUT", function()
	-- kept locally; the others hear it at the next login
	pcall(L.RunPlanProbes, "logout")
end)
