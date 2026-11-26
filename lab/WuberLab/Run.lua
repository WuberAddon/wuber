-- Wuber Lab (developer only, never ship): the test run. Self-marking checks, one ordered run
-- across the tester's four windows, the results, and the login checks.
--
--   L.AddScene(def), L.AddCheck(def)   the check catalogue (Checks.lua, Pretend.lua; README "How
--                                      to add a check" documents every field)
--   L.RunStart(opts)                   "Start test run": every pending check, ordered to swap
--                                      windows as little as possible, about 10 minutes
--   L.RunStop(why), L.RunSkip(), L.RunLookedWrong(), L.RunPress()   the tester's buttons
--   L.RunOrder(ids, startRole)         the ordering (tested on its own)
--
-- Each check has a judge: on the judging window, begin(ctx), poll(ctx) twice a second and
-- test(ctx, event, ...) on the events it watches say "pass"/"fail" (with a short reason); nothing
-- within `timeout` seconds is a fail "didn't happen within N s". The tester never judges: a "look"
-- check is one screenshot (Snap) for the reviewer to look at, and "Looked wrong" is there for surprises.
--
-- Windows coordinate over the lab's own addon messages (prefix WLAB, like the plan's sync and the
-- test mode), only between Anita Lift, Farra Way, Hayley Cab and Wuber Rocks:
--   RUN~S~sid~by~sim~parts~part~id,id,...   the run's steps (in parts)
--   RUN~R~sid~index~id~r~took~who~why       a result (the judge's, or the tester's button)
--   RUN~I~sid~index                         where the run is (an answer to Q)
--   RUN~Q~sid                               "what is this run?" (a window that missed the start)
--   RUN~F~sid~index~from~text               a fact for the judge (another window saw something)
--   RUN~E~sid~why                           the run was stopped
--   RUN~V~wuber~lab~proto                   versions (a login check)
--   RUN~W~epoch                             "my lab last saw yours then" (the answer to a V; the
--                                           witness for "saved settings survived a restart")
--
-- Saved (WuberLabDB): run (the run going on, or the last one), results[id] (latest per check),
-- runs (a compact summary per run, newest last: "id|window|result|reason|epoch|took|judge|title"),
-- login[character] (the login checks: "id|result|reason|epoch|took").

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain

if type(L.KINDS) == "table" then L.KINDS.run = "test run (steps and self-marked results)" end

local R = { recent = {}, watched = {}, heardV = {}, answeredV = {}, facts = {}, login = {}, asked = {}, witnessTold = {} }
L.runState = R

L.RUN_ROLES = { driver = "Anita Lift", rider = "Wuber Rocks", crew1 = "Farra Way", crew2 = "Hayley Cab" }
L.RUN_ROLE_ORDER = { "driver", "rider", "crew1", "crew2" }
L.RUN_BUDGET = 660           -- seconds of checks one run aims for ("about 10 minutes")
L.RUN_TIMEOUT = 45           -- a check's default timeout
L.RUN_SECS = 15              -- a check's default estimate
L.RUN_REPLAY = 20            -- seconds of watched events replayed into a step that just began
L.RUN_KEEP = 8               -- run summaries kept

local VERDICT = { pass = true, fail = true, look = true, skip = true }

---------------------------------------------------------------------------
-- Roles and names
---------------------------------------------------------------------------

function L.RunName(role) return L.RUN_ROLES[role or ""] or tostring(role or "?") end
-- First names, but "Wuber Rocks" in full (plain "Wuber" reads as the addon)
function L.RunShort(role)
	local first = L.RunName(role):match("^(%S+)")
	return first == "Wuber" and L.RunName(role) or first
end

function L.RunRoleOf(name)
	local k = L.Key(name)
	for role, n in pairs(L.RUN_ROLES) do
		if L.Key(n) == k then return role end
	end
	return nil
end

function L.RunMyRole() return L.me and L.RunRoleOf(L.me) or nil end

---------------------------------------------------------------------------
-- The catalogue
---------------------------------------------------------------------------

L.RUN_CHECKS, L.RUN_BY_ID, L.RUN_SCENES, L.RUN_SCENE_BY_ID = {}, {}, {}, {}

-- A scene: checks that share state and run in their order, back to back.
--   { id, title, linked = true (default) | false (each check stands alone), prio (lower = sooner
--     into a run), after = scene id (runs after that one when both are in a run), only = true
--     (never in "Start test run": started by its own tool), intro (shown at its first step) }
function L.AddScene(def)
	if type(def) ~= "table" or type(def.id) ~= "string" then return nil end
	local s = L.RUN_SCENE_BY_ID[def.id]
	if not s then
		s = { checks = {} }
		L.RUN_SCENES[#L.RUN_SCENES + 1] = s
		L.RUN_SCENE_BY_ID[def.id] = s
	end
	for k, v in pairs(def) do s[k] = v end
	if s.linked == nil then s.linked = true end
	s.prio = tonumber(s.prio) or 5
	return s
end

local ROLE_OK = { driver = true, rider = true, crew1 = true, crew2 = true }

-- One check (see README "How to add a check"). Returns the check, or nil and why.
function L.AddCheck(def)
	if type(def) ~= "table" then return nil, "not a table" end
	local id = def.id
	if type(id) ~= "string" or not id:match("^[%w_]+$") then return nil, "bad id " .. show(id) end
	if L.RUN_BY_ID[id] then return nil, "duplicate id " .. id end
	if not def.login and not ROLE_OK[def.who or ""] then return nil, id .. ": who must be driver, rider, crew1 or crew2" end
	if def.judge ~= nil and not ROLE_OK[def.judge] then return nil, id .. ": bad judge " .. show(def.judge) end
	local c = {}
	for k, v in pairs(def) do c[k] = v end
	c.judge = c.judge or c.who
	if c.ask then c.judge = c.who end -- (a Yes/No step is judged where the tester answers)
	c.kind = c.kind or "auto"
	c.timeout = tonumber(c.timeout) or L.RUN_TIMEOUT
	c.secs = tonumber(c.secs) or L.RUN_SECS
	if type(c.watch) == "string" then c.watch = { c.watch } end
	c.watch = c.watch or {}
	for _, ev in ipairs(c.watch) do R.watch(ev) end
	if not c.login then
		local sceneId = c.scene or "loose"
		local s = L.RUN_SCENE_BY_ID[sceneId] or L.AddScene({ id = sceneId, title = sceneId, linked = sceneId ~= "loose" })
		c.scene = sceneId
		local pos = #s.checks + 1
		if c.after then
			for i, other in ipairs(s.checks) do
				if other.id == c.after then pos = i + 1 end
			end
		end
		table.insert(s.checks, pos, c)
	end
	L.RUN_CHECKS[#L.RUN_CHECKS + 1] = c
	L.RUN_BY_ID[id] = c
	return c
end

---------------------------------------------------------------------------
-- Saved state
---------------------------------------------------------------------------

local function db()
	local d = L.db
	if not d then return nil end
	if type(d.results) ~= "table" then d.results = {} end
	if type(d.runs) ~= "table" then d.runs = {} end
	if type(d.login) ~= "table" then d.login = {} end
	return d
end

function L.RunWuberVersion()
	local W = L.W()
	return W and str(W.VERSION) or "none"
end

-- Not passed yet with this Wuber version (a fail, a skip, never run, or an older Wuber).
function L.RunPending(id)
	local d = db()
	local rec = d and d.results[id]
	if type(rec) ~= "table" then return true end
	if rec.ver ~= L.RunWuberVersion() then return true end
	return not (rec.r == "pass" or rec.r == "look")
end

function L.RunResetResults()
	local d = db()
	if not d then return false end
	d.results = {}
	L.Log("run", "results reset: every check is pending again")
	if L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
	return true
end

function L.RunCurrent()
	local d = db()
	local run = d and d.run
	if type(run) ~= "table" or run.ended or not run.steps then return nil end
	return run
end

function L.RunActive() return L.RunCurrent() ~= nil end

---------------------------------------------------------------------------
-- Ordering: whole scenes (in their own order) and loose checks, the same window back to back
---------------------------------------------------------------------------

local function roleRank(role)
	for i, r in ipairs(L.RUN_ROLE_ORDER) do if r == role then return i end end
	return 9
end

-- The windows the tester acts in, in order (no-click steps don't make him swap).
local function actors(ids)
	local out = {}
	for _, id in ipairs(ids) do
		local c = L.RUN_BY_ID[id]
		if c and (c.click or c.button) then out[#out + 1] = c.who end
	end
	return out
end

function L.RunSwaps(ids)
	local n, last = 0, nil
	for _, role in ipairs(actors(ids)) do
		if last and role ~= last then n = n + 1 end
		last = role
	end
	return n
end

-- ids: the checks wanted (a list or set); opts: { budget, start = role, all = true (ignore the
-- budget) }. Returns the ordered ids, their estimated seconds, and the ids left for later.
function L.RunOrder(ids, opts)
	opts = opts or {}
	local want = {}
	for k, v in pairs(ids or {}) do
		if type(k) == "number" then want[v] = true elseif v then want[k] = true end
	end
	-- units: a linked scene with anything wanted runs whole; loose checks one by one
	local units = {}
	for si, s in ipairs(L.RUN_SCENES) do
		if s.linked then
			local any = false
			for _, c in ipairs(s.checks) do if want[c.id] then any = true end end
			if any then
				local list, secs, roles = {}, 0, {}
				for _, c in ipairs(s.checks) do
					list[#list + 1] = c.id
					secs = secs + c.secs
				end
				for _, r in ipairs(actors(list)) do roles[#roles + 1] = r end
				units[#units + 1] = { ids = list, secs = secs, first = roles[1] or s.checks[1].who, last = roles[#roles] or s.checks[#s.checks].who,
					prio = s.prio, order = si, scene = s.id, after = s.after, final = s.last }
			end
		else
			for ci, c in ipairs(s.checks) do
				if want[c.id] then
					units[#units + 1] = { ids = { c.id }, secs = c.secs, first = c.who, last = c.who, prio = s.prio, order = si + ci / 1000, scene = s.id,
						after = s.after }
				end
			end
		end
	end
	-- which units fit the budget: by priority (a scene is never cut; the first always goes)
	local budget = tonumber(opts.budget) or L.RUN_BUDGET
	local byPrio = {}
	for _, u in ipairs(units) do byPrio[#byPrio + 1] = u end
	table.sort(byPrio, function(a, b) if a.prio ~= b.prio then return a.prio < b.prio end return a.order < b.order end)
	local total, chosen, later = 0, {}, {}
	for _, u in ipairs(byPrio) do
		if u.final then
			chosen[u] = true -- (the last scene, the photo tour, always ends a run)
		elseif opts.all or total == 0 or total + u.secs <= budget then
			chosen[u] = true
			total = total + u.secs
		else
			for _, id in ipairs(u.ids) do later[#later + 1] = id end
		end
	end
	-- a scene that must follow another waits for it (when both are in)
	local sceneIn = {}
	for u in pairs(chosen) do sceneIn[u.scene] = u end
	-- greedy: the same window as where the tester is; then Anita, the rider, the crew; then the catalogue's order
	local out, placed, cur = {}, {}, opts.start or "driver"
	local left = 0
	for _ in pairs(chosen) do left = left + 1 end
	while left > 0 do
		local best
		for u in pairs(chosen) do
			if not placed[u] then
				local blocked = u.after and sceneIn[u.after] and not placed[sceneIn[u.after]]
				if u.final and left > 1 then blocked = true end
				if not blocked then
					local key = { u.first == cur and 0 or 1, roleRank(u.first), u.prio, u.order }
					if not best then
						best = { u = u, key = key }
					else
						for i = 1, 4 do
							if key[i] ~= best.key[i] then
								if key[i] < best.key[i] then best = { u = u, key = key } end
								break
							end
						end
					end
				end
			end
		end
		if not best then break end -- (a loop of "after"s: the rest is left out)
		placed[best.u] = true
		left = left - 1
		for _, id in ipairs(best.u.ids) do out[#out + 1] = id end
		cur = best.u.last or cur
	end
	return out, total, later
end

---------------------------------------------------------------------------
-- Sending to the other windows (the tester's four only)
---------------------------------------------------------------------------

local function unitKey(unit)
	local a, b = call(UnitName, unit)
	a, b = str(a), str(b)
	if not a then return nil end
	return L.Key(b and (a .. " " .. b) or a)
end

local function groupKeys()
	local out = {}
	for i = 1, 4 do local k = unitKey("party" .. i) if k then out[k] = true end end
	for i = 1, 40 do local k = unitKey("raid" .. i) if k then out[k] = true end end
	return out
end

local function inGroup()
	if type(IsInGroup) == "function" then return plain(call(IsInGroup)) == true end
	return false
end

-- The lab's share of the game's addon-message allowance (per prefix: about 10 at once, then one a
-- second): every WLAB message this window sends is counted (Hooks.lua counts the plan's and the
-- test mode's), and run messages wait in an outbox while fewer than RESERVE are left.
local BURST, RATE, RESERVE = 10, 1, 4
R.bucket = { tokens = BURST, at = 0 }
R.outbox = {}

local function refill()
	local b, t = R.bucket, L.Now()
	b.tokens = math.min(BURST, b.tokens + (t - b.at) * RATE)
	b.at = t
	return b.tokens
end

function L.RunSpent()
	if R.inRaw then return end
	refill()
	R.bucket.tokens = R.bucket.tokens - 1
end

local function raw(text, chan, target)
	local fn = type(C_ChatInfo) == "table" and C_ChatInfo.SendAddonMessage or rawget(_G, "SendAddonMessage")
	if type(fn) ~= "function" then return false end
	refill()
	R.bucket.tokens = R.bucket.tokens - 1
	R.inRaw = true
	local ok = pcall(fn, L.PLAN_PREFIX or "WLAB", text, chan, target)
	R.inRaw = false
	return ok
end

function R.pump()
	while R.outbox[1] and refill() >= RESERVE do
		local m = table.remove(R.outbox, 1)
		raw(m.text, m.chan, m.target)
	end
end

local function queue(text, chan, target)
	R.outbox[#R.outbox + 1] = { text = text, chan = chan, target = target }
	if #R.outbox > 60 then table.remove(R.outbox, 1) end
end

-- To the other three: the group in one message, a whisper to those out of it known to be online.
function R.send(text)
	if #text > 250 then text = text:sub(1, 250) end
	local grouped = inGroup() and groupKeys() or {}
	local viaGroup = false
	local peers = L.planPeers or {}
	local run = L.db and L.db.run
	local owner = type(run) == "table" and not run.ended and L.Key(run.by) or nil
	for _, name in pairs(L.RUN_ROLES) do
		local k = L.Key(name)
		if k ~= L.myKey then
			if grouped[k] then
				viaGroup = true
			else
				local p = peers[k]
				if (p and not p.offline) or R.heardFrom(k) or k == owner then queue(text, "WHISPER", name) end
			end
		end
	end
	if viaGroup then queue(text, (type(IsInRaid) == "function" and plain(call(IsInRaid)) == true) and "RAID" or "PARTY") end
	L.Log("run", "send " .. text:sub(1, 120))
	R.pump()
end

R.heard = {} -- [key] = GetTime(): a RUN message came from them
function R.heardFrom(k)
	local t = R.heard[k]
	return t ~= nil and L.Now() - t < 600
end

-- Online (or this window): the windows a run can count on.
function L.RunOnline(role)
	local name = L.RUN_ROLES[role]
	if not name then return false end
	local k = L.Key(name)
	if k == L.myKey then return true end
	local p = L.planPeers and L.planPeers[k]
	if p and not p.offline then return true end
	if R.heardFrom(k) then return true end
	return inGroup() and groupKeys()[k] == true
end

---------------------------------------------------------------------------
-- Events the checks watch (game events, lab signals, Wuber's own: "wuber:<name>")
---------------------------------------------------------------------------

local GAME = {}
function R.watch(name)
	if type(name) ~= "string" or R.watched[name] then return end
	R.watched[name] = true
	if name:match("^[A-Z][A-Z0-9_]+$") and not GAME[name] then
		GAME[name] = true
		L.On(name, function(...) R.event(name, ...) end)
	end
end

local function pack(...) return { n = select("#", ...), ... } end

function R.event(name, ...)
	if not R.watched[name] then return end
	local t = L.Now()
	local rec = R.recent
	rec[#rec + 1] = { t = t, name = name, args = pack(...) }
	if #rec > 80 then table.remove(rec, 1) end
	for _, ctx in ipairs(R.activeList()) do
		if ctx.watching[name] and not ctx.done then R.feed(ctx, name, ...) end
	end
end

L.signalFns[#L.signalFns + 1] = function(name, info) R.event(name, info) end
function L.RunFire(name, ...) R.event("wuber:" .. tostring(name), ...) end

---------------------------------------------------------------------------
-- Judging: one ctx per check this window judges (a step of the run, or a login check)
---------------------------------------------------------------------------

R.active = {} -- [ctx] = ctx

-- A copy, oldest first (a verdict starts the next step, which adds to R.active)
function R.activeList()
	local out = {}
	for ctx in pairs(R.active) do out[#out + 1] = ctx end
	table.sort(out, function(a, b) return (a.started or 0) < (b.started or 0) end)
	return out
end

-- Judge helpers (Checks.lua uses them): ctx.W, ctx.DR, ctx.UI, ctx.t, ctx.data, ctx.Tell(text)
local function newCtx(check, run, index)
	local W = L.W()
	local ctx = { check = check, run = run, index = index, started = L.Now(), data = {}, W = W,
		DR = W and W.Drive or nil, UI = W and W.UI or nil, watching = {}, sim = (run and run.sim) or L.sim }
	for _, ev in ipairs(check.watch) do ctx.watching[ev] = true end
	ctx.watching.fact = true
	ctx.Tell = function(text) R.tell(ctx, text) end
	ctx.Name = L.RunName
	ctx.Short = L.RunShort
	return ctx
end

-- A verdict: the step (or login check) is over.
function R.verdict(ctx, r, why)
	if ctx.done or not VERDICT[r] then return end
	ctx.done = true
	R.active[ctx] = nil
	local took = L.Now() - ctx.started
	why = tostring(why or (r == "pass" and "ok" or r)):gsub("[~|\r\n]", " "):sub(1, 140)
	if ctx.login then
		R.loginResult(ctx, r, why, took)
	else
		L.RunResult(ctx.check.id, r, why, { took = took, index = ctx.index, sid = ctx.run.sid, judge = L.me })
	end
end

local function call3(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, r, why = pcall(fn, ...)
	if not ok then
		L.Bug("check", r)
		return "fail", "the check itself broke: " .. tostring(r):sub(1, 100)
	end
	return r, why
end

-- A pass before the check's `hold` seconds waits (so the tester sees the state it judged).
local function held(ctx, r, why)
	local hold = tonumber(ctx.check.hold)
	if r == "pass" and hold and ctx.t < hold then
		ctx.data.held = ctx.data.held or { why = why }
		return true
	end
	return false
end

function R.feed(ctx, name, ...)
	if ctx.done then return end
	ctx.t = L.Now() - ctx.started
	local r, why = call3(ctx.check.test, ctx, name, ...)
	if r and not held(ctx, r, why) then R.verdict(ctx, r, why) end
end

function R.poll(ctx)
	if ctx.done then return end
	ctx.t = L.Now() - ctx.started
	local h = ctx.data.held
	if h then
		if ctx.t >= (tonumber(ctx.check.hold) or 0) then return R.verdict(ctx, "pass", h.why) end
		return
	end
	local r, why
	if ctx.check.poll then r, why = call3(ctx.check.poll, ctx) end
	if r and held(ctx, r, why) then return end
	if r then return R.verdict(ctx, r, why) end
	if ctx.t >= ctx.check.timeout then
		if ctx.check.onTimeout then
			local w, why2 = call3(ctx.check.onTimeout, ctx)
			if w then return R.verdict(ctx, w, why2) end
		end
		R.verdict(ctx, "fail", ctx.data.waitWhy or ("didn't happen within " .. math.floor(ctx.check.timeout + 0.5) .. " s"))
	end
end

-- Starts judging `check` here.
function R.judge(check, run, index, since)
	local ctx = newCtx(check, run, index)
	ctx.login = run == nil
	R.active[ctx] = ctx
	ctx.t = 0
	if check.kind == "skip" then
		R.verdict(ctx, "skip", check.say or "skipped")
		return ctx
	end
	if check.when then
		local ok, why = call3(check.when, ctx)
		if ok == false or ok == "skip" then
			R.verdict(ctx, "skip", why or "not for this setup")
			return ctx
		end
	end
	local r, why = call3(check.begin, ctx)
	if r and not held(ctx, r, why) then
		R.verdict(ctx, r, why)
		return ctx
	end
	-- what already happened since the step before began (a click can beat the message)
	local from = math.max(since or ctx.started, ctx.started - L.RUN_REPLAY)
	for _, e in ipairs(R.recent) do
		if ctx.done then break end
		if e.t >= from and ctx.watching[e.name] then R.feed(ctx, e.name, unpack(e.args, 1, e.args.n)) end
	end
	if not ctx.done then R.poll(ctx) end
	return ctx
end

-- Facts from other windows (check.also): text to the judging window.
function R.tell(ctx, text)
	text = tostring(text or ""):gsub("[~|\r\n]", " "):sub(1, 120)
	local run = ctx.run
	if not run then return end
	local c = ctx.check
	if c.judge == L.RunMyRole() then
		R.event("fact", L.me, text)
		return
	end
	if run.loc then return end
	R.send(("RUN~F~%s~%d~%s~%s"):format(run.sid, ctx.index or 0, tostring(L.me), text))
end

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------

local function newSid()
	local t = math.floor(L.Epoch())
	return ("%x"):format(t) .. tostring(math.random(10, 99))
end

-- The checks a run would take now: pending, not "only" scenes, every window they need online.
function L.RunWanted(opts)
	opts = opts or {}
	local ids, missing = {}, {}
	for _, c in ipairs(L.RUN_CHECKS) do
		local s = c.scene and L.RUN_SCENE_BY_ID[c.scene]
		local inScene = opts.scene and c.scene == opts.scene
		if not c.login and s and ((opts.scene and inScene) or (not opts.scene and not s.only)) then
			if opts.scene or opts.all or s.always or L.RunPending(c.id) then
				local ok = true
				for _, role in ipairs({ c.who, c.judge }) do
					if not (opts.online and opts.online(role) or L.RunOnline(role)) then
						ok = false
						missing[L.RunName(role)] = true
					end
				end
				if ok then ids[#ids + 1] = c.id end
			end
		end
	end
	return ids, missing
end

-- Starts a run on this window (the owner). opts: { scene = id (that scene alone), all = true
-- (passed checks too), sim = bool }. Returns true, or false and why.
function L.RunStart(opts)
	opts = opts or {}
	local d = db()
	if not d or not L.me then return false, "not ready yet" end
	local role = L.RunMyRole()
	if not role then return false, L.me .. " isn't one of the tester's four test characters" end
	if L.RunActive() then return false, "a test run is going: Stop it first" end
	if L.photo then return false, "the photo tour is running" end
	local ids, missing = L.RunWanted(opts)
	-- a linked scene runs whole: one of its checks on a window that isn't online drops the scene
	local dropped = {}
	for _, c in ipairs(L.RUN_CHECKS) do
		local s = c.scene and L.RUN_SCENE_BY_ID[c.scene]
		if s and s.linked and not (L.RunOnline(c.who) and L.RunOnline(c.judge)) then
			dropped[s.id] = true
			missing[L.RunName(L.RunOnline(c.who) and c.judge or c.who)] = true
		end
	end
	local keep = {}
	for _, id in ipairs(ids) do
		local c = L.RUN_BY_ID[id]
		if not dropped[c.scene] then keep[#keep + 1] = id end
	end
	local list, secs, later = L.RunOrder(keep, { start = role, all = opts.scene ~= nil })
	local real = 0
	for _, id in ipairs(list) do
		local s = L.RUN_SCENE_BY_ID[L.RUN_BY_ID[id].scene]
		if not (s and s.always) then real = real + 1 end
	end
	if real == 0 then
		local miss = {}
		for n in pairs(missing) do miss[#miss + 1] = n end
		table.sort(miss)
		return false, #miss > 0 and ("nothing to run without " .. table.concat(miss, ", ") .. " online") or "every check has passed (Reset results to run them again)"
	end
	local scene = opts.scene and L.RUN_SCENE_BY_ID[opts.scene]
	local run = { sid = newSid(), by = L.me, started = L.Epoch(), steps = list, index = 1, results = {}, secs = secs,
		sim = opts.sim == nil and L.sim or opts.sim, later = #later, loc = scene and scene.loc or nil, scene = opts.scene }
	d.run = run
	R.owner = true
	R.stepCtx = nil
	L.Log("run", ("start %s by %s: %d checks, about %d min, %d swaps%s%s"):format(run.sid, L.me, #list, math.ceil((secs or 0) / 60),
		L.RunSwaps(list), run.sim and ", test mode (no shards)" or "", #later > 0 and (", " .. #later .. " left for the next run") or ""))
	R.summary(run)
	if not run.loc then R.sendList(run) end
	R.startStep(run)
	return true
end

function R.sendList(run)
	local parts, cur = {}, ""
	for _, id in ipairs(run.steps) do
		if #cur + #id + 1 > 180 then
			parts[#parts + 1] = cur
			cur = ""
		end
		cur = cur == "" and id or (cur .. "," .. id)
	end
	if cur ~= "" then parts[#parts + 1] = cur end
	for i, p in ipairs(parts) do
		R.send(("RUN~S~%s~%s~%s~%d~%d~%s"):format(run.sid, tostring(run.by), run.sim and "1" or "0", #parts, i, p))
	end
end

-- The current step began (on every window): show it; judge it here if this window is its judge.
function R.startStep(run)
	local id = run.steps[run.index]
	if not id then return R.finish(run, "done") end
	local c = L.RUN_BY_ID[id]
	local now = L.Now()
	local since = R.stepAt
	R.stepAt = now
	R.stepId = id
	if R.stepCtx and not R.stepCtx.done then
		R.active[R.stepCtx] = nil
		R.stepCtx.done = true
	end
	R.stepCtx = nil
	if not c then
		L.Log("run", "step " .. run.index .. " unknown check " .. tostring(id) .. ": skipped")
		return L.RunResult(id, "skip", "this window's lab doesn't know it (an older lab?)", { index = run.index, sid = run.sid })
	end
	L.Log("run", ("step %d/%d %s on %s: %s"):format(run.index, #run.steps, id, L.RunName(c.who), tostring(c.click or c.say or "")))
	local me = L.RunMyRole()
	if c.judge == me then
		local ctx = R.judge(c, run, run.index, since)
		if not ctx.done then R.stepCtx = ctx end
		local early = R.facts[run.sid .. "#" .. run.index]
		R.facts[run.sid .. "#" .. run.index] = nil
		for _, f in ipairs(early or {}) do
			if not ctx.done then R.feed(ctx, "fact", f[1], f[2]) end
		end
	elseif c.also and me then
		for _, role in ipairs(c.also) do
			if role == me and c.observe then
				local ctx = newCtx(c, run, run.index)
				ctx.observer = true
				ctx.data.observe = true
				R.observers = R.observers or {}
				R.observers[#R.observers + 1] = ctx
				local ok, err = pcall(c.observe, ctx)
				if not ok then L.Bug("observe " .. id, err) end
			end
		end
	end
	if L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
end

-- A result for check `id` (from this window's judge, a button, or another window).
-- meta: { took, index, sid, judge, remote = true, hand = true }
function L.RunResult(id, r, why, meta)
	meta = meta or {}
	local d = db()
	local run = d and d.run
	if not run or not VERDICT[r] or (meta.sid and meta.sid ~= run.sid) then return false end
	local index = tonumber(meta.index) or run.index
	local rec = run.results[id]
	-- the first verdict counts; the tester's "looked wrong" may still turn a pass into a fail
	if rec and not (meta.hand and r == "fail") then return false end
	local c = L.RUN_BY_ID[id]
	rec = { r = r, why = why, at = L.Epoch(), took = meta.took, judge = meta.judge or L.me, who = c and L.RunName(c.who) or "?",
		hand = meta.hand or nil }
	run.results[id] = rec
	d.results[id] = { r = r, why = why, at = rec.at, w = rec.who, ver = L.RunWuberVersion(), sid = run.sid }
	L.Log("run", ("%s %s %s: %s%s"):format(id, r, rec.who, tostring(why), meta.took and (" (" .. ("%.1f"):format(meta.took) .. " s)") or ""))
	R.lastResult = { id = id, r = r, why = why, took = meta.took }
	if not meta.remote and not run.loc then
		R.send(("RUN~R~%s~%d~%s~%s~%s~%s~%s"):format(run.sid, index, id, r, meta.took and ("%.1f"):format(meta.took) or "",
			tostring(meta.judge or L.me), tostring(why or "")))
	end
	R.summary(run)
	if not run.ended and index >= run.index and run.steps[index] == id then
		run.index = index + 1
		R.startStep(run)
	elseif L.RunPromptUpdate then
		pcall(L.RunPromptUpdate)
	end
	return true
end

-- The run is over (on every window): the summary and the last word.
function R.finish(run, why)
	if run.ended then return end
	run.ended = L.Epoch()
	run.why = why
	if R.stepCtx then
		R.active[R.stepCtx] = nil
		R.stepCtx.done = true
	end
	R.stepCtx = nil
	R.observers = nil
	R.owner = nil
	R.summary(run)
	local n, f = 0, 0
	for _, rec in pairs(run.results) do
		n = n + 1
		if rec.r == "fail" then f = f + 1 end
	end
	L.Log("run", ("end %s (%s): %d of %d checked, %d failed"):format(run.sid, tostring(why), n, #run.steps, f))
	for _, fn in ipairs(L.runEndFns or {}) do
		local ok, err = pcall(fn, run, why)
		if not ok then L.Bug("run end", err) end
	end
	if L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
	if L.Say then L.Say("test run " .. (why == "done" and "done" or ("stopped (" .. tostring(why) .. ")")) .. ": log out or /reload, then tell the person running the test \"done\".") end
end
L.runEndFns = L.runEndFns or {}

function L.RunStop(why)
	local run = L.RunCurrent()
	if not run then return false end
	why = tostring(why or "stopped by the tester"):gsub("[~|]", " ")
	if not run.loc then R.send(("RUN~E~%s~%s"):format(run.sid, why)) end
	R.finish(run, why)
	return true
end

function L.RunSkip()
	local run = L.RunCurrent()
	if not run then return false end
	local id = run.steps[run.index]
	return L.RunResult(id, "skip", "skipped by the tester", { hand = true, index = run.index })
end

-- "Looked wrong": the last finished step (or the one going on) fails, with a screenshot.
function L.RunLookedWrong()
	local d = db()
	local run = d and d.run
	if not run or not run.steps then return false end
	local prev = run.steps[run.index - 1]
	local id, index = run.steps[run.index], run.index
	if prev and run.results[prev] or not id then id, index = prev, 0 end
	if not id then return false end
	local shot = ""
	if L.Snap and L.Snap() then shot = " (screenshot " .. tostring(L.photoShots) .. ")" end
	return L.RunResult(id, "fail", "Tester: it looked wrong" .. shot, { hand = true, index = index })
end

-- A Yes/No step (check.ask: the question, or function(ctx) -> the question or nil while the
-- lab is still watching): the tester's answer, on the step's window (its judge). check.answer(ctx, yes)
-- may give the verdict (nil: keep watching); without it Yes passes and No fails. A No takes a
-- screenshot, as "Looked wrong" does.
function L.RunAsk(ctx)
	local c = ctx and ctx.check
	if not (c and c.ask) or ctx.done then return nil end
	if type(c.ask) ~= "function" then return tostring(c.ask) end
	local ok, q = pcall(c.ask, ctx)
	return ok and str(q) or nil
end

function L.RunAnswer(yes)
	local run = L.RunCurrent()
	if not run then return false end
	local c = L.RUN_BY_ID[run.steps[run.index] or ""]
	local ctx = R.stepCtx
	if not (c and c.ask and ctx and ctx.check == c and not ctx.done) then return false end
	ctx.t = L.Now() - ctx.started
	ctx.data.answer = yes and "yes" or "no"
	local r, why
	if c.answer then
		r, why = call3(c.answer, ctx, yes == true)
	else
		r, why = yes and "pass" or "fail", yes and "Tester: yes" or "Tester: no"
	end
	if r == "fail" and not yes and L.Snap and L.Snap() then why = tostring(why) .. " (screenshot " .. tostring(L.photoShots) .. ")" end
	L.Log("run", c.id .. ": the tester answered " .. ctx.data.answer)
	if r then R.verdict(ctx, r, why) end
	if L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
	return true
end

-- The step's own button (Snap for a look, Pretend I clicked, Start photo tour): on its window.
-- (A Yes/No step's Yes is this button too.)
function L.RunPress()
	local run = L.RunCurrent()
	if not run then return false end
	local c = L.RUN_BY_ID[run.steps[run.index] or ""]
	if c and c.ask and not c.button then return L.RunAnswer(true) end
	if not (c and c.button and type(c.button.run) == "function") then return false end
	local ctx = R.stepCtx and R.stepCtx.check == c and R.stepCtx or newCtx(c, run, run.index)
	local ok, r, why = pcall(c.button.run, ctx)
	if not ok then
		L.Bug("button " .. c.id, r)
		return false
	end
	if VERDICT[r or ""] then L.RunResult(c.id, r, why, { index = run.index, took = L.Now() - (R.stepAt or L.Now()) }) end
	if L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
	return true
end

---------------------------------------------------------------------------
-- The compact summary (WuberLabDB.runs): one line per check
---------------------------------------------------------------------------

local function line(...)
	local parts = { ... }
	for i = 1, select("#", ...) do parts[i] = tostring(parts[i] == nil and "" or parts[i]):gsub("[|\r\n]", "/") end
	return table.concat(parts, "|")
end

function R.summary(run)
	local d = db()
	if not d then return end
	local s
	for _, x in ipairs(d.runs) do if x.sid == run.sid then s = x end end
	if not s then
		s = { sid = run.sid }
		d.runs[#d.runs + 1] = s
		while #d.runs > L.RUN_KEEP do table.remove(d.runs, 1) end
	end
	s.by, s.started, s.ended, s.why, s.sim = run.by, run.started, run.ended, run.why, run.sim and true or nil
	s.wuber, s.lab, s.scene, s.later = L.RunWuberVersion(), L.VERSION, run.scene, run.later
	local lines, counts = {}, { pass = 0, fail = 0, look = 0, skip = 0, todo = 0 }
	for _, id in ipairs(run.steps) do
		local c = L.RUN_BY_ID[id]
		local rec = run.results[id]
		local who = c and L.RunName(c.who) or "?"
		if rec then
			counts[rec.r] = (counts[rec.r] or 0) + 1
			lines[#lines + 1] = line(id, who, rec.r, rec.why, ("%.3f"):format(rec.at or 0), rec.took and ("%.1f"):format(rec.took) or "", rec.judge or "",
				c and c.title or "")
		else
			counts.todo = counts.todo + 1
			local what = c and (type(c.click) == "string" and c.click or type(c.say) == "string" and c.say) or "not reached"
			lines[#lines + 1] = line(id, who, "todo", what, "", "", "", c and c.title or "")
		end
	end
	s.lines = lines
	s.n = #run.steps
	for k, v in pairs(counts) do s[k] = v end
end

---------------------------------------------------------------------------
-- Login checks: everything that needs no click, a few seconds after login, on every window
---------------------------------------------------------------------------

function R.loginResult(ctx, r, why, took)
	local d = db()
	if not d or not L.me then return end
	local mine = d.login[L.me]
	if type(mine) ~= "table" or mine.session ~= R.loginSession then
		mine = { at = L.Epoch(), session = R.loginSession, wuber = L.RunWuberVersion(), lab = L.VERSION, lines = {} }
		d.login[L.me] = mine
	end
	mine.lines[#mine.lines + 1] = line(ctx.check.id, r, why, ("%.3f"):format(L.Epoch()), ("%.1f"):format(took or 0))
	L.Log("run", ("login %s %s: %s"):format(ctx.check.id, r, why))
	R.login[ctx.check.id] = { r = r, why = why }
end

-- Runs this window's login checks now (also /lab logincheck).
function L.RunLoginChecks()
	if not L.me then return 0 end
	R.loginSession = (R.loginSession or 0) + 1
	R.login = {}
	local d = db()
	if d then d.login[L.me] = nil end
	local me, n = L.RunMyRole(), 0
	for _, c in ipairs(L.RUN_CHECKS) do
		if c.login and (c.who == nil or c.who == "any" or c.who == me or (c.who == "cast" and me)) then
			n = n + 1
			R.judge(c, nil, nil, nil)
		end
	end
	L.Log("run", "login checks: " .. n .. " started")
	return n
end

function L.RunLoginResults() return R.login end

---------------------------------------------------------------------------
-- Versions (login check "versions match across windows")
---------------------------------------------------------------------------

function L.RunVersionText()
	local W = L.W()
	return ("%s~%s~%s"):format(L.RunWuberVersion(), L.VERSION, show(W and W.PROTO))
end

-- To the other windows (or one of them, by whisper: the answer to a window heard for the first time).
function L.RunSayVersion(to)
	if to then
		queue("RUN~V~" .. L.RunVersionText(), "WHISPER", to)
		R.pump()
	else
		R.send("RUN~V~" .. L.RunVersionText())
	end
	R.saidV = L.Now()
end

function L.RunHeardVersions() return R.heardV end

---------------------------------------------------------------------------
-- Hearing the other windows
---------------------------------------------------------------------------

local partsIn = {} -- [sid] = { parts = n, got = { [i] = text }, by, sim }

local function applyList(sid, info)
	local d = db()
	if not d then return end
	local ids = {}
	for i = 1, info.parts do
		for id in (info.got[i] or ""):gmatch("[^,]+") do ids[#ids + 1] = id end
	end
	local old = d.run
	if type(old) == "table" and old.sid == sid then return end
	if type(old) == "table" and not old.ended then R.finish(old, "replaced by a new run from " .. tostring(info.by)) end
	local run = { sid = sid, by = info.by, started = L.Epoch(), steps = ids, index = info.index or 1, results = {}, sim = info.sim }
	d.run = run
	R.owner = nil
	L.Log("run", ("joined run %s by %s: %d checks"):format(sid, tostring(info.by), #ids))
	if run.sim and not L.sim and L.SimSet then L.SimSet(true) end
	R.summary(run)
	R.startStep(run)
end

local function onRun(fields, sender, key)
	local kind, sid = fields[2], fields[3]
	local d = db()
	if not d or not sid then return end
	local run = d.run
	local mine = type(run) == "table" and run.sid == sid
	if kind == "V" then
		R.heardV[key] = { name = sender, wuber = fields[3], lab = fields[4], proto = fields[5], at = L.Now() }
		R.event("version", sender)
		-- a witness for "saved settings survived a restart": when this window last saw theirs
		if type(d.seenLab) ~= "table" then d.seenLab = {} end
		local seen = tonumber(d.seenLab[key])
		if seen and L.Now() - (R.witnessTold[key] or -999) > 30 then
			R.witnessTold[key] = L.Now()
			queue(("RUN~W~%.0f"):format(seen), "WHISPER", sender)
			R.pump()
		end
		d.seenLab[key] = L.Epoch()
		if not R.answeredV[key] and R.saidV then
			R.answeredV[key] = L.Now()
			L.RunSayVersion(sender)
		end
	elseif kind == "S" then
		local info = partsIn[sid] or { got = {} }
		partsIn[sid] = info
		info.by, info.sim, info.parts = fields[4], fields[5] == "1", tonumber(fields[6]) or 1
		info.got[tonumber(fields[7]) or 1] = fields[8] or ""
		for i = 1, info.parts do if not info.got[i] then return end end
		partsIn[sid] = nil
		applyList(sid, info)
	elseif kind == "R" then
		if not mine then
			if not R.asked[sid] or L.Now() - R.asked[sid] > 10 then
				R.asked[sid] = L.Now()
				R.send("RUN~Q~" .. sid)
			end
			return
		end
		local index, id, r = tonumber(fields[4]) or 0, fields[5], fields[6]
		local hand = index == 0
		if hand then index = run.index end
		-- a result for a step further on: we missed some; catch up
		if not hand and index > run.index and run.steps[index] == id then run.index = index end
		L.RunResult(id, r, fields[9], { took = tonumber(fields[7]), index = index, sid = sid, judge = fields[8], remote = true, hand = hand or nil })
	elseif kind == "W" then
		local at = tonumber(fields[3])
		if at and (not R.witness or at > R.witness.at) then R.witness = { name = sender, at = at } end
	elseif kind == "Q" then
		if mine and R.owner then
			R.sendList(run)
			R.send(("RUN~I~%s~%d"):format(sid, run.index))
		end
	elseif kind == "I" then
		if mine and not run.ended then
			local index = tonumber(fields[4]) or run.index
			if index > run.index then
				run.index = index
				R.startStep(run)
			end
		end
	elseif kind == "F" then
		local index = tonumber(fields[4]) or 0
		if mine and R.stepCtx and not R.stepCtx.done and index == run.index then
			R.feed(R.stepCtx, "fact", fields[5], fields[6])
		elseif mine and not run.ended and index >= run.index then
			-- (the teller is ahead of this window: kept for when the step begins here)
			R.facts[sid .. "#" .. index] = R.facts[sid .. "#" .. index] or {}
			table.insert(R.facts[sid .. "#" .. index], { fields[5], fields[6] })
		end
	elseif kind == "E" then
		if mine and not run.ended then R.finish(run, fields[4] or "stopped") end
	end
end

L.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender)
	if str(prefix) ~= (L.PLAN_PREFIX or "WLAB") then return end
	text, sender, chan = str(text), str(sender), plain(chan)
	if not text or not sender or text:sub(1, 4) ~= "RUN~" then return end
	if chan ~= "WHISPER" and chan ~= "PARTY" and chan ~= "RAID" then return end
	local W = L.W()
	local name = (W and type(W.CleanName) == "function" and str(call(W.CleanName, sender))) or sender
	local key = L.Key(name)
	if not key or key == L.myKey or not L.RunRoleOf(name) or not L.RunMyRole() then return end -- The tester's four only
	R.heard[key] = L.Now()
	local fields = {}
	for f in (text .. "~"):gmatch("(.-)~") do fields[#fields + 1] = f end
	local ok, err = pcall(onRun, fields, L.RUN_ROLES[L.RunRoleOf(name)] or name, key)
	if not ok then L.Bug("run message", err) end
end)

---------------------------------------------------------------------------
-- The clock: polls, timeouts, the owner's watchdog
---------------------------------------------------------------------------

function R.tick()
	R.pump()
	for _, ctx in ipairs(R.activeList()) do R.poll(ctx) end
	for i = #(R.observers or {}), 1, -1 do
		local o = R.observers[i]
		if o.check.observePoll and not o.done then
			o.t = L.Now() - o.started
			local ok, stop = pcall(o.check.observePoll, o)
			if not ok then L.Bug("observe", stop) end
			if not ok or stop or o.t > o.check.timeout then
				o.done = true
				table.remove(R.observers, i)
			end
		end
	end
	local run = L.RunCurrent()
	if run and R.owner and R.stepAt and not run.loc then
		local c = L.RUN_BY_ID[run.steps[run.index] or ""]
		if c and c.judge ~= L.RunMyRole() and L.Now() - R.stepAt > c.timeout + 20 then
			L.RunResult(c.id, "fail", "no answer from " .. L.RunName(c.judge) .. "'s window (logged in, with Wuber Lab on?)", { index = run.index })
		end
	end
end

L.OnLogin(function()
	L.Every(0.5, R.tick)
	-- a run that was going on before a /reload: carry on from the step it was at
	L.After(3, function()
		local run = L.RunCurrent()
		if run then
			R.owner = run.by == L.me
			if run.sim and not L.sim and L.SimSet then L.SimSet(true) end
			L.Log("run", "resumed run " .. run.sid .. " at step " .. run.index)
			R.startStep(run)
			if not run.loc then R.send("RUN~Q~" .. run.sid) end
		end
	end)
	L.After(8, function()
		L.RunSayVersion()
		L.RunLoginChecks()
	end)
	-- again for windows found since (the plan's hello finds them a moment after login)
	L.After(18, function()
		for _, role in ipairs(L.RUN_ROLE_ORDER) do
			local k = L.Key(L.RUN_ROLES[role])
			if k ~= L.myKey and not R.heardV[k] and L.RunOnline(role) then return L.RunSayVersion() end
		end
	end)
end)

-- Recorded: this window's own ritual casts (raid checks compare them across windows).
L.castLog = {}
L.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
	if plain(unit) ~= "player" then return end
	local W = L.W()
	local DR = W and W.Drive
	if num(spellID) ~= ((DR and DR.RITUAL_ID) or 698) then return end
	L.castLog[#L.castLog + 1] = { at = L.Now(), name = DR and type(DR.cast) == "table" and DR.cast.name or "?" }
end)
