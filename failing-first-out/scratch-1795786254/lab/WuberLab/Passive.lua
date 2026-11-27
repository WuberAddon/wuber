-- Wuber Lab (developer only, never ship): passive play. The lab watches normal play and judges
-- by itself what Wuber did - no run, no prompt, no clicks from the tester. Off by default:
-- "/lab passive on|off|status", or "Passive play" in the Tools tab. The guided run stays for releases.
--
-- While on, each of these is one line in the saved report (pass, fail, skip or look, with why):
--   ride      every real ride this window books (rider): done = pass; failed = fail; cancelled,
--             declined or timed out = skip (not Wuber's doing); 20 min in one stage = fail
--   customer  every real rider on this window's queue (driver, crew): arrived = pass, else skip
--   trade     every trade that moved gold, 6 s after it closed: gold in from a customer = Wuber
--             marked them paid (DRIVE_PAID); gold out to the ride's driver = the ride counts it
--   summon    every big-button click while it says "Summon...": a cast starts within 8 s
--   portal    every click on a crew mate's summoning portal (a channel starts on this window
--             during their ritual): Wuber counts it (HELP) within 10 s
--   crew      every crew window that joins the group: its Wuber says hello (the crew sync) in 45 s
--   login     the login checks (Checks.lua) once they are all in: any fail = fail
--   blocked   every blocked action (ADDON_ACTION_BLOCKED / _FORBIDDEN, Wuber's BLOCKED) = fail; a
--             session of 10 min or more without one = pass (at logout)
--   error     every Lua error: Wuber's = fail, anyone else's = look
--   tour      the photo tour (Photo.lua) by itself, once per Wuber version: after 2 min with no
--             input, in a city (IsResting, not in an instance), not in a group, out of combat, no
--             ride, not open as a driver; a 5 s countdown first. ANY input stops it: a key (a
--             keyboard watcher that passes every key on), the mouse moving or clicking, moving,
--             a cast, a target, chat, a vendor/NPC/mail/bank window, a whisper, invite, summon or
--             trade from a real player (those go on to Wuber: Photo.lua's L.PhotoRealEvent).
--
-- Never sends anything (no addon message, whisper or chat line: the lab's own WLAB traffic is
-- unchanged by it) and never acts for the player (no click, cast, target, invite, key or trade
-- call): it reads Wuber's state and the game's events. The only thing it does is the existing
-- photo tour (Screenshot(); its demo data is never sent and never saved, see Photo.lua).
-- In combat it pauses (nothing new is judged, the keyboard watcher hides, the tour stops); blocked
-- actions and errors are still noted then. While off, nothing is wired: no events, no frames,
-- no saved data.
--
-- Saved: WuberLabDB.passive = { on, sessions = { { char, started, ended, wuber, lab, taint,
--   lines = { "kind|subject|result|reason|epoch|took" }, pass, fail, skip, look, more, kinds } },
--   release = { [kind] = { n, pass = { at, why, wuber }, fail = { at, why, wuber } } } (what the
--   release checklist needs: trade, portal, summon, blocked, tour, ride...), tours = { [wuber
--   version] = { at, tries, shots, planned, reason, done } } }.

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain

if type(L.KINDS) == "table" then L.KINDS.passive = "passive play (self-checks of normal play, the idle photo tour)" end

-- Tunables (tests shorten them)
local C = {
	IDLE = 120,          -- seconds with no input before the photo tour may start
	COUNTDOWN = 5,       -- seconds of warning before it starts
	CURSOR = 6,          -- pixels the mouse may drift and still count as still
	TICK = 0.25,         -- how often the mouse is looked at (cases: every other tick)
	KEEP = 10,           -- sessions kept
	LINES = 300,         -- lines per session at most
	PER_KIND = 40,       -- lines per kind per session at most (the rest are counted)
	TRADE_WAIT = 6, CLICK_WAIT = 8, PORTAL_WAIT = 10, CREW_WAIT = 45,
	STUCK = 1200,        -- a ride stage longer than this is stuck
	LET_GO = 30,         -- a ride Wuber no longer holds (not ended) is skipped after this
	QUEUE_MAX = 7200,    -- a customer still listed after this is left unjudged
	LOGIN_WAIT = 110,    -- seconds after login until the login checks are all in
	TOUR_TRIES = 2,      -- auto tours started per session at most
	TOUR_GAP = 600,      -- seconds between two tries
	BLOCK_FREE = 600,    -- a session at least this long with no blocked action passes "blocked"
	RITUAL_FOR = 90,     -- a crew ritual counts as going on this long after its cast began
	-- the windows that take the tour by themselves: with the tester's four windows only Wuber Rocks (two
	-- windows shooting at once would overwrite each other's files: the game names them by the second);
	-- a character outside the cast ("other") too
	TOUR_ROLES = { rider = true, other = true },
}
L.PASSIVE = C

local PV = { open = {}, closed = {}, paid = {}, lastInput = 0, tries = 0, inGroup = {}, cx = nil, cy = nil, n = 0 }
L.passiveState = PV

local function W_() return L.W() end
local function now() return L.Now() end
local function fn(t, k) return type(t) == "table" and type(t[k]) == "function" end

---------------------------------------------------------------------------
-- Saved data (only ever made once passive play is turned on)
---------------------------------------------------------------------------

local function isOn()
	local d = L.db
	return type(d) == "table" and type(d.passive) == "table" and d.passive.on == true
end
L.PassiveOn = isOn

local function pdb()
	local d = L.db
	if type(d) ~= "table" then return nil end
	local p = d.passive
	if type(p) ~= "table" then
		p = { on = false }
		d.passive = p
	end
	if type(p.sessions) ~= "table" then p.sessions = {} end
	if type(p.release) ~= "table" then p.release = {} end
	if type(p.tours) ~= "table" then p.tours = {} end
	return p
end

local function cvar(name)
	local get = rawget(_G, "GetCVar")
	if type(get) ~= "function" and type(C_CVar) == "table" then get = C_CVar.GetCVar end
	return str(call(get, name))
end

-- This login's session (made when the first line comes, or passive play is turned on)
local function session(p)
	local s = PV.session
	if s then return s end
	s = { char = L.me or "?", started = L.Epoch(), wuber = L.RunWuberVersion(), lab = L.VERSION, taint = cvar("taintLog") or "?",
		lines = {}, kinds = {}, pass = 0, fail = 0, skip = 0, look = 0 }
	p.sessions[#p.sessions + 1] = s
	while #p.sessions > C.KEEP do table.remove(p.sessions, 1) end
	PV.session = s
	return s
end

local function money(c)
	local W = W_()
	return (W and fn(W, "Money") and str(call(W.Money, c))) or tostring(c)
end

local function key(name)
	local W = W_()
	if W and fn(W, "Key") then
		local k = str(call(W.Key, name))
		if k then return k end
	end
	return L.Key(name)
end

local function clean(v, max) return (tostring(v == nil and "-" or v):gsub("[|\r\n]", "/"):sub(1, max)) end

-- One verdict: a line in the session, the timeline, and the release checklist's evidence.
local function result(kind, subject, r, why, took)
	local p = pdb()
	if not p then return end
	local s = session(p)
	why, subject = clean(why or r, 160), clean(subject, 60)
	s[r] = (s[r] or 0) + 1
	s.kinds[kind] = (s.kinds[kind] or 0) + 1
	if s.kinds[kind] <= C.PER_KIND and #s.lines < C.LINES then
		s.lines[#s.lines + 1] = table.concat({ kind, subject, r, why, ("%.3f"):format(L.Epoch()), took and ("%.1f"):format(took) or "" }, "|")
	else
		s.more = (s.more or 0) + 1
	end
	if r == "fail" and kind == "blocked" then s.blocked = (s.blocked or 0) + 1 end
	L.Log("passive", ("%s %s %s: %s"):format(kind, r, subject, why))
	local rec = p.release[kind]
	if type(rec) ~= "table" then
		rec = { n = 0 }
		p.release[kind] = rec
	end
	rec.n = (rec.n or 0) + 1
	if r == "pass" or r == "fail" then rec[r] = { at = L.Epoch(), why = why, wuber = L.RunWuberVersion(), subject = subject, char = L.me } end
	if L.RefreshPanel then L.RefreshPanel() end
end
L.PassiveResult = result

---------------------------------------------------------------------------
-- Cases: something seen that Wuber has to finish, judged until a deadline
---------------------------------------------------------------------------

-- Judged only on normal play: not in combat, not during a tour, a test run, the pretend rider or
-- test mode (their demo and pretend data are never judged).
local function active()
	if not isOn() or L.InCombat() or L.photo then return false end
	if L.RunActive and L.RunActive() then return false end
	if L.pretend or L.sim then return false end
	return true
end
L.PassiveActive = active

local function open(id, kind, subject, wait, poll, late)
	local c = PV.open[id]
	if c then return c end
	c = { id = id, kind = kind, subject = subject, at = now(), deadline = now() + wait, poll = poll, late = late, data = {} }
	PV.open[id] = c
	return c
end

local function close(c, r, why)
	if PV.open[c.id] ~= c then return end
	PV.open[c.id] = nil
	PV.closed[c.id] = true
	result(c.kind, c.subject, r, why, now() - c.at)
end

local function judgeAll()
	local list = {}
	for _, c in pairs(PV.open) do list[#list + 1] = c end
	table.sort(list, function(a, b) return a.at < b.at end)
	local t = now()
	for _, c in ipairs(list) do
		if PV.open[c.id] == c then
			local ok, r, why = true, nil, nil
			if c.poll then ok, r, why = pcall(c.poll, c) end
			if not ok then
				L.Bug("passive " .. c.kind, r)
				close(c, "fail", "the self-check broke: " .. tostring(r):sub(1, 90))
			elseif r then
				close(c, r, why)
			elseif t >= c.deadline then
				local r2, why2
				if c.late then ok, r2, why2 = pcall(c.late, c) end
				if not ok then r2, why2 = "fail", "the self-check broke: " .. tostring(r2):sub(1, 90) end
				close(c, r2 or "fail", why2 or ("didn't happen within " .. math.floor(t - c.at + 0.5) .. " s"))
			end
		end
	end
end

-- (a pause - combat, a tour - moves every deadline on by its length)
local function shift(by)
	if not by or by <= 0 then return end
	for _, c in pairs(PV.open) do c.deadline = c.deadline + by end
end

---------------------------------------------------------------------------
-- Rides (the rider's window): Hooks.lua's ride_<state> signals
---------------------------------------------------------------------------

local RIDE_SKIP = { cancelled = "cancelled", declined = "the driver declined", timeout = "no answer from the driver" }

local function rideRank(state)
	local W = W_()
	local R = W and W.RIDE_RANK
	return type(R) == "table" and R[state or ""] or nil
end

local function paidText(r)
	local paid, price = num(r.paid) or num(r.paidSoFar), num(r.price)
	if paid and paid > 0 then
		return "done, paid " .. money(paid) .. ((price and paid < price) and (" of " .. money(price)) or "")
	end
	if r.payClicked then return "done (Pay clicked)" end
	return "done (no payment seen)"
end

local function ridePoll(c)
	local W = W_()
	local r = W and W.ride
	if (type(r) ~= "table" or str(r.id) ~= c.data.id) and now() - (c.data.since or c.at) > C.LET_GO then
		return "skip", "Wuber let the ride go at " .. tostring(c.data.state) .. " (a /reload?)"
	end
end

local function rideLate(c) return "fail", "stuck at " .. tostring(c.data.state) .. " for " .. math.floor(C.STUCK / 60) .. " min" end

local function rideSeen(r, state)
	local id = str(r.id)
	if not id then return end
	local cid = "ride:" .. id
	if PV.closed[cid] then return end
	local c = open(cid, "ride", (str(r.driver) or "?") .. " to " .. (str(r.dest) or "?"), C.STUCK, ridePoll, rideLate)
	if c.data.state ~= state then c.data.since = now() end
	c.data.id, c.data.state = id, state
	c.deadline = now() + C.STUCK
	if state == "done" then
		close(c, "pass", paidText(r))
	elseif state == "failed" then
		close(c, "fail", "the ride failed" .. (str(r.reason) and (": " .. r.reason) or ""))
	elseif RIDE_SKIP[state] then
		close(c, "skip", RIDE_SKIP[state] .. " (not Wuber's doing)")
	end
end

local function onSignal(name, info)
	if not active() or type(name) ~= "string" then return end
	local state = name:match("^ride_(%a+)$")
	if state and (rideRank(state) or RIDE_SKIP[state] or state == "failed") and type(info) == "table" and type(info.r) == "table" and not info.fake then
		rideSeen(info.r, state)
	end
end

---------------------------------------------------------------------------
-- Customers (driver and crew windows): Wuber's queue
---------------------------------------------------------------------------

local function DR_()
	local W = W_()
	return W and type(W.Drive) == "table" and W.Drive or nil
end

local function crewKey(k)
	local DR = DR_()
	return DR and fn(DR, "CrewEntry") and call(DR.CrewEntry, k) ~= nil
end

local function custRank(state)
	local DR = DR_()
	return DR and type(DR.RANK) == "table" and DR.RANK[state or ""] or 0
end

local function custNote(c, cust)
	local d = c.data
	if type(cust) == "table" then
		if custRank(cust.state) >= custRank(d.best) then d.best = str(cust.state) or d.best end
		d.paid = math.max(d.paid or 0, num(cust.paid) or 0)
	end
end

local function custVerdict(c, why)
	local d = c.data
	if custRank(d.best) >= custRank("arrived") then
		return "pass", "reached " .. tostring(d.best) .. ((d.paid or 0) > 0 and (", paid " .. money(d.paid)) or ", no fare taken")
	end
	return "skip", "left the list at " .. tostring(d.best) .. (why and (" (" .. tostring(why) .. ")") or "")
end

local function custPoll(c)
	local DR = DR_()
	local cust = DR and type(DR.customers) == "table" and DR.customers[c.data.key]
	if type(cust) ~= "table" then return custVerdict(c, "gone") end
	custNote(c, cust)
end

local function custLate(c) return "skip", "still listed after " .. math.floor(C.QUEUE_MAX / 60) .. " min (" .. tostring(c.data.best) .. ")" end

local function custOpen(k, cust)
	local cid = "cust:" .. k
	if PV.open[cid] then return PV.open[cid] end
	local c = open(cid, "customer", str(cust.name) or k, C.QUEUE_MAX, custPoll, custLate)
	c.data.key, c.data.best, c.data.paid = k, str(cust.state) or "?", 0
	PV.closed[cid] = nil
	return c
end

local function realCust(k, cust)
	return type(k) == "string" and type(cust) == "table" and not L.IsFakeKey(k) and not crewKey(k) and not cust.sim
end

local function scanCustomers()
	local DR = DR_()
	if not DR or type(DR.customers) ~= "table" then return end
	for k, cust in pairs(DR.customers) do
		if realCust(k, cust) then custNote(custOpen(k, cust), cust) end
	end
end

local function custRemoved(cust, why)
	if type(cust) ~= "table" then return end
	local k = str(cust.key) or (str(cust.name) and key(cust.name))
	if not k or not realCust(k, cust) then return end
	local c = PV.open["cust:" .. k] or custOpen(k, cust)
	custNote(c, cust)
	close(c, custVerdict(c, why))
end

---------------------------------------------------------------------------
-- Trades: 6 s after a trade that moved gold closed
---------------------------------------------------------------------------

local function purse() return num(call(GetMoney)) end

local function tradePoll(c)
	local t = c.data
	local m = purse()
	if not (m and t.money) then return end
	local delta = m - t.money
	if delta > 0 then
		for _, p in ipairs(PV.paid) do
			if p.at >= t.at and p.key == t.key then return "pass", "got " .. money(delta) .. " from " .. t.who .. "; Wuber marked them paid" end
		end
	elseif delta < 0 and t.ride then
		local W = W_()
		local r = W and W.ride
		if type(r) == "table" and str(r.id) == t.ride and (num(r.paidSoFar) or 0) - t.paidBefore >= -delta - 1 then
			return "pass", "paid " .. money(-delta) .. " to " .. t.who .. "; the ride counts it (" .. tostring(r.state) .. ")"
		end
	end
end

local function tradeLate(c)
	local t = c.data
	local m = purse()
	local delta = (m and t.money) and (m - t.money) or 0
	if delta == 0 then return "skip", "no gold changed hands with " .. t.who end
	if delta > 0 then
		if t.cust then return "fail", "got " .. money(delta) .. " from " .. t.who .. " (a customer); Wuber didn't mark them paid" end
		return "skip", "got " .. money(delta) .. " from " .. t.who .. ", not a customer here"
	end
	if t.ride then return "fail", "paid " .. money(-delta) .. " to " .. t.who .. "; Wuber's ride doesn't count it" end
	return "skip", "paid " .. money(-delta) .. " to " .. t.who .. ", not this ride's driver"
end

local function tradeShow()
	if not active() then return end
	local W = W_()
	local who = (W and fn(W, "UnitName") and str(call(W.UnitName, "npc"))) or str(call(UnitName, "npc")) or "?"
	local k = key(who)
	local t = { who = who, key = k, at = now(), money = purse(), paidBefore = 0 }
	local DR = DR_()
	t.cust = k and DR and type(DR.customers) == "table" and DR.customers[k] ~= nil or false
	local r = W and W.ride
	if type(r) == "table" and fn(W, "RideActive") and call(W.RideActive) == true and k then
		local trader = fn(W, "RideTrader") and call(W.RideTrader, r, k)
		if trader == nil then trader = str(r.driverKey) == k end
		if trader then
			t.ride = str(r.id)
			t.paidBefore = num(r.paidSoFar) or 0
		end
	end
	PV.trade = t
end

local function tradeClosed()
	local t = PV.trade
	if not t or t.closing then return end
	t.closing = true
	PV.trade = nil
	local c = open("trade:" .. ("%.2f"):format(t.at), "trade", t.who, C.TRADE_WAIT, nil, tradeLate)
	c.data = t
	c.poll = function(cc)
		-- (gold comes a moment after the close: judged as soon as Wuber has counted it, else at the end)
		return tradePoll(cc)
	end
end

---------------------------------------------------------------------------
-- The big button's summon click (driver), a portal click (crew helper)
---------------------------------------------------------------------------

local function summonPoll(c)
	local DR = DR_()
	local cast = DR and type(DR.cast) == "table" and DR.cast
	if cast and (num(cast.at) or 0) >= c.at - 1 then return "pass", "the ritual started" .. (str(cast.name) and (" on " .. cast.name) or "") end
	if PV.castAt and PV.castAt >= c.at then return "pass", "a cast started (" .. tostring(PV.castWhat) .. ")" end
	if PV.castFailAt and PV.castFailAt >= c.at then return "look", "the game refused the cast at once (shards, range or line of sight?)" end
end

local function summonLate(c) return "fail", "the click on '" .. tostring(c.subject) .. "' started no cast in " .. C.CLICK_WAIT .. " s" end

-- (after Wuber's own PreClick, which has just refreshed the plan: a "cast" mark = this click summons)
local function onBigClick(self, _, down)
	if down or not active() then return end
	local plan = type(self.plan) == "table" and self.plan or {}
	local who
	for _, m in ipairs(type(plan.marks) == "table" and plan.marks or {}) do
		if type(m) == "table" and m.kind == "cast" then who = type(m.c) == "table" and str(m.c.name) or "?" end
	end
	local title = str(plan.title) or ""
	if not who and title:lower():find("^summon") then who = title end
	if not who then return end
	open("summon:" .. ("%.2f"):format(now()), "summon", who, C.CLICK_WAIT, summonPoll, summonLate)
end

local hooked = false
local function hookBig()
	if hooked or L.InCombat() then return hooked end
	local b = rawget(_G, "WuberDriveButton")
	if type(b) ~= "table" or not fn(b, "HookScript") then return false end
	hooked = pcall(b.HookScript, b, "PreClick", function(self, button, down)
		local ok, err = pcall(onBigClick, self, button, down)
		if not ok then L.Bug("passive click", err) end
	end)
	return hooked
end

-- the queue entry whose helpers include this window (Checks.lua's helper)
local function helped()
	local J = L.J
	return J and fn(J, "helpedBy") and J.helpedBy(L.myKey) or nil
end

local function portalPoll(c)
	local h = helped()
	if h then return "pass", "Wuber counted the click for " .. tostring(h.name) end
	if PV.helpAt and PV.helpAt >= c.at then return "pass", "Wuber counted the click (HELP)" end
end

local function portalLate(c) return "fail", "this window clicked " .. tostring(c.subject) .. "'s portal (a channel started); Wuber didn't count it" end

local function onChannel(unit, _, spellID)
	if plain(unit) ~= "player" or not active() then return end
	local DR = DR_()
	if DR and type(DR.cast) == "table" then return end -- (this window's own ritual)
	local rt = PV.ritual
	if not rt or now() - rt.at > C.RITUAL_FOR then return end
	open("portal:" .. ("%.2f"):format(now()), "portal", rt.rider, C.PORTAL_WAIT, portalPoll, portalLate).data.spell = num(spellID)
end

---------------------------------------------------------------------------
-- Wuber's own events (Hooks.lua passes every W.Fire to L.RunFire)
---------------------------------------------------------------------------

local function onFire(name, a, b, c3)
	if not active() then return end
	if name == "DRIVE_PAID" then
		PV.paid[#PV.paid + 1] = { at = now(), key = key(a), copper = num(b) }
		while #PV.paid > 20 do table.remove(PV.paid, 1) end
	elseif name == "DRIVE_REMOVED" then
		custRemoved(a, b)
	elseif name == "DRIVE_RITUAL" then
		local data = type(c3) == "table" and c3 or {}
		if b == "c" and not data.mine then
			PV.ritual = { rider = str(a) or "?", at = now() }
		elseif (b == "s" or b == "f") and PV.ritual and PV.ritual.rider == str(a) then
			PV.ritual = nil
		elseif b == "h" and (data.helper == L.myKey or (str(data.helper) and key(data.helper) == L.myKey)) then
			PV.helpAt = now()
		end
	end
end

---------------------------------------------------------------------------
-- Crew sync: a crew window that joins the group says hello
---------------------------------------------------------------------------

local function groupKeys()
	local out = {}
	local W = W_()
	local function add(u)
		local n = (W and fn(W, "UnitName") and str(call(W.UnitName, u))) or nil
		if not n then
			local a, b = call(UnitName, u)
			a, b = str(a), str(b)
			n = a and (b and (a .. " " .. b) or a) or nil
		end
		local k = n and key(n)
		if k and k ~= L.myKey then out[k] = n end
	end
	for i = 1, 4 do add("party" .. i) end
	if plain(call(IsInRaid)) == true then for i = 1, 40 do add("raid" .. i) end end
	return out
end

local function crewPoll(c)
	local DR = DR_()
	local peer = DR and type(DR.peers) == "table" and DR.peers[c.data.key]
	if type(peer) == "table" and (num(peer.at) or 0) >= c.at - 5 then
		return "pass", "heard " .. tostring(c.subject) .. "'s Wuber (" .. tostring(peer.version or "?") .. ")"
	end
	if not PV.inGroup[c.data.key] then return "skip", "left the group first" end
end

local function crewLate(c) return "fail", "no word from " .. tostring(c.subject) .. "'s Wuber in " .. C.CREW_WAIT .. " s (crew sync)" end

local function onRoster()
	local keys = groupKeys()
	local was = PV.inGroup
	PV.inGroup = keys
	if not active() then return end
	local DR = DR_()
	if not (DR and DR.on) then return end
	for k, n in pairs(keys) do
		local m = fn(DR, "CrewEntry") and call(DR.CrewEntry, k)
		if not was[k] and type(m) == "table" and m.app ~= false then
			local c = open("crew:" .. k .. ":" .. ("%.0f"):format(now()), "crew", n, C.CREW_WAIT, crewPoll, crewLate)
			c.data.key = k
		end
	end
end

---------------------------------------------------------------------------
-- Login checks, blocked actions and errors
---------------------------------------------------------------------------

local function judgeLogin()
	if not isOn() or PV.loginDone then return end
	PV.loginDone = true
	local res = L.RunLoginResults and L.RunLoginResults() or {}
	local n, bad = 0, {}
	for id, rec in pairs(res) do
		n = n + 1
		if type(rec) == "table" and rec.r == "fail" then bad[#bad + 1] = id .. ": " .. tostring(rec.why) end
	end
	table.sort(bad)
	if n == 0 then return result("login", L.me, "skip", "no login checks ran here") end
	if #bad > 0 then return result("login", L.me, "fail", #bad .. " of " .. n .. " failed: " .. table.concat(bad, "; ")) end
	result("login", L.me, "pass", "all " .. n .. " login checks passed or skipped")
end

local LOG_KINDS = { block = true, werr = true, err = true, laberr = true }

-- An error's subject and verdict: Wuber's own fails; the lab's and other addons' are only looked at.
local function errorSubject(text)
	local name = L.ErrorAddon(text)
	if name == "Wuber" then return "Wuber", "fail" end
	if name == "WuberLab" then return "the lab", "look" end
	if name then return "other addon: " .. name, "look" end
	-- no path at all: a mention of Wuber (not the lab) still counts as Wuber's
	local own = (text:match("^(.-) @ ") or text):gsub("WuberLab", "")
	if own:find("Wuber", 1, true) then return "Wuber", "fail" end
	return "another addon", "look"
end

local function onLogLine(kind, text)
	if not isOn() or not LOG_KINDS[kind] then return end
	text = tostring(text or "")
	if kind == "block" then
		result("blocked", text:match("addon=(%S+)") or "Wuber", "fail", text)
	elseif kind == "werr" then
		result("error", "Wuber", "fail", text)
	elseif kind == "err" then
		local subject, r = errorSubject(text)
		result("error", subject, r, text)
	else
		result("error", "the lab", "look", text)
	end
end

---------------------------------------------------------------------------
-- Input: anything the tester does (and anything a real player asks of this window)
---------------------------------------------------------------------------

local function input(why)
	PV.lastInput = now()
	if PV.countdown then
		PV.countdown = nil
		L.Log("passive", "photo tour countdown stopped: " .. tostring(why))
		if L.Say then L.Say("passive play: photo tour called off (" .. tostring(why) .. ")") end
	end
	if PV.tourMine and L.Touring and L.Touring() then L.TourStop("input: " .. tostring(why)) end
end
L.PassiveInput = input

-- events that mean the player did something (or a real player wants this window)
local INPUT = {
	PLAYER_STARTED_MOVING = "moving", MODIFIER_STATE_CHANGED = "a key", PLAYER_TARGET_CHANGED = "a target",
	GLOBAL_MOUSE_DOWN = "a click", WORLD_MAP_OPEN = "the map", TAXIMAP_OPENED = "a flight master",
	CINEMATIC_START = "a cinematic", LOADING_SCREEN_ENABLED = "a loading screen", PLAYER_CONTROL_LOST = "lost control",
	MERCHANT_SHOW = "a vendor", GOSSIP_SHOW = "an NPC", MAIL_SHOW = "the mailbox", BANKFRAME_OPENED = "the bank",
	AUCTION_HOUSE_SHOW = "the auction house", LOOT_OPENED = "loot", QUEST_DETAIL = "a quest",
	PLAYER_INTERACTION_MANAGER_FRAME_SHOW = "an NPC window", CHAT_MSG_WHISPER_INFORM = "a whisper sent",
	CHAT_MSG_BN_WHISPER_INFORM = "a whisper sent", CHAT_MSG_WHISPER = "a whisper", CHAT_MSG_BN_WHISPER = "a whisper",
	PARTY_INVITE_REQUEST = "an invite", CONFIRM_SUMMON = "a summon", TRADE_SHOW = "a trade",
	PLAYER_REGEN_DISABLED = "combat",
}
-- chat lines that are the player's own when the author is this character
local OWN_CHAT = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE" }

-- (Photo.lua, while a passive tour runs) Wuber's event frame got one of the events the tour
-- holds back: a whisper, an addon whisper, an invite or a summon from a real player stops the
-- tour, and Photo.lua passes the event on to Wuber.
-- (review) A real trade (any of its events) or a summon being cancelled too: Wuber hears it only
-- after the tour has put its own data back.
local REAL = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true, PARTY_INVITE_REQUEST = true, CONFIRM_SUMMON = true,
	CANCEL_SUMMON = true, TRADE_SHOW = true, TRADE_UPDATE = true, TRADE_ACCEPT_UPDATE = true, TRADE_MONEY_CHANGED = true,
	TRADE_PLAYER_ITEM_CHANGED = true, TRADE_TARGET_ITEM_CHANGED = true, TRADE_CLOSED = true, TRADE_REQUEST_CANCEL = true,
	PLAYER_TRADE_MONEY = true }
local function realEvent(event, ...)
	if not (PV.tourMine and L.Touring and L.Touring()) then return false end
	local real = REAL[event]
	if event == "CHAT_MSG_ADDON" then real = plain((select(3, ...))) == "WHISPER" end
	if not real then return false end
	L.TourStop("a real player: " .. tostring(event))
	return true
end

-- The keyboard watcher: a frame that hears every key and passes it on (never holds one back).
-- Made only out of combat (EnableKeyboard and SetPropagateKeyboardInput are called once, at its
-- making, never in combat: propagation is protected in combat on some clients); shown only out of
-- combat; hidden in combat and while passive play is off.
-- (review) A keyboard frame that does NOT pass keys on would swallow every key the player presses.
-- So after asking for propagation the watcher checks GetPropagateKeyboardInput() is true; if the
-- call failed, the getter is missing or says no, its keyboard is turned off again and it is never
-- shown (keys.deaf): passive play then hears keys only through the events (a modifier, moving, a
-- click, chat, a cast, ...).
local keys
local function keyWatcher(showIt)
	if not keys then
		if not showIt or L.InCombat() then return nil end
		local f = CreateFrame("Frame", "WuberLabPassiveKeys", UIParent)
		f:SetSize(1, 1)
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		f:Hide()
		local okKb = pcall(f.EnableKeyboard, f, true)
		local okProp = okKb and pcall(f.SetPropagateKeyboardInput, f, true)
		local passes = false
		if okProp and type(f.GetPropagateKeyboardInput) == "function" then
			local okGet, v = pcall(f.GetPropagateKeyboardInput, f)
			passes = okGet and plain(v) == true
		end
		if passes then
			f:SetScript("OnKeyDown", function(_, k) input("a key (" .. tostring(k) .. ")") end)
		else
			pcall(f.EnableKeyboard, f, false)
			f.deaf = true
			L.Log("passive", "the keyboard watcher can't pass keys on in this client: it stays off (keys are heard through events only)")
		end
		keys = f
		PV.keys = f
	end
	if showIt and not keys.deaf and not L.InCombat() then keys:Show() else keys:Hide() end
	return keys
end

---------------------------------------------------------------------------
-- The photo tour, by itself when idle in a city
---------------------------------------------------------------------------

local function tourWhyNot(t)
	if not (keys and (keys:IsShown() or keys.deaf)) then return "the keyboard watcher isn't on" end
	if L.photoClick or (L.db and L.db.photoClick) then return L.PHOTO_CLICK_ONLY or "this client needs a click per shot" end
	if L.photo or (L.Touring and L.Touring()) then return "a tour is running" end
	if L.RunActive and L.RunActive() then return "a test run is going" end
	if L.pretend then return "the pretend rider is on" end
	if L.TrailOn and L.TrailOn() then return "the usage trail is on (/lab trail off)" end
	if not C.TOUR_ROLES[L.Role and L.Role() or "other"] then return "not on this window (" .. tostring(L.Role and L.Role()) .. "): the rider's window takes it" end
	local p = pdb()
	local rec = p and p.tours[L.RunWuberVersion()]
	if type(rec) == "table" and rec.done then return "already done for Wuber " .. L.RunWuberVersion() end
	if PV.tries >= C.TOUR_TRIES then return "tried " .. PV.tries .. " times this session" end
	if PV.lastTry and t - PV.lastTry < C.TOUR_GAP then return "tried a moment ago" end
	if plain(call(rawget(_G, "IsResting"))) ~= true then return "not in a city" end
	if plain(call(rawget(_G, "IsInInstance"))) == true then return "in an instance" end
	if plain(call(rawget(_G, "IsInGroup"))) == true then return "in a group" end
	if plain(call(rawget(_G, "UnitOnTaxi"), "player")) == true then return "on a flight" end
	if plain(call(rawget(_G, "UnitIsDeadOrGhost"), "player")) == true then return "dead" end
	if L.TourCan then
		local ok, why = L.TourCan()
		if not ok then return why end
	end
	return nil
end
L.PassiveTourWhyNot = function() return tourWhyNot(now()) end

local function tourStart(t)
	local p = pdb()
	if not p then return end
	local ver = L.RunWuberVersion()
	L.PhotoRealEvent = realEvent
	local ok = L.TourStart and L.TourStart({ passive = true })
	PV.tries = PV.tries + 1
	PV.lastTry = t
	local rec = type(p.tours[ver]) == "table" and p.tours[ver] or {}
	rec.at, rec.tries = L.Epoch(), (rec.tries or 0) + 1
	p.tours[ver] = rec
	if not ok then
		L.PhotoRealEvent = nil
		return result("tour", "Wuber " .. ver, "fail", "the tour didn't start")
	end
	PV.tourMine = { at = t, ver = ver }
	L.Log("passive", "photo tour started by itself (idle " .. math.floor(t - PV.lastInput) .. " s in a city)")
end

local function tourEnded(t)
	local mine = PV.tourMine
	PV.tourMine = nil
	L.PhotoRealEvent = nil
	shift(t - mine.at)
	local lt = L.lastTour or {}
	local shots, planned = lt.shots or 0, lt.planned or 0
	local p = pdb()
	local rec = p and type(p.tours[mine.ver]) == "table" and p.tours[mine.ver] or {}
	rec.shots, rec.planned, rec.reason = shots, planned, lt.reason
	rec.done = shots > 0 and lt.reason == nil
	if p then p.tours[mine.ver] = rec end
	PV.lastInput = math.max(PV.lastInput, t)
	if rec.done then
		local missed = #(lt.missed or {}) + #(lt.skipped or {})
		return result("tour", "Wuber " .. mine.ver, "pass", shots .. " of " .. planned .. " screenshots" .. (missed > 0 and (", " .. missed .. " screens skipped or missed") or ""))
	end
	if shots == 0 and not lt.reason then return result("tour", "Wuber " .. mine.ver, "fail", "no screenshots") end
	if L.PHOTO_CLICK_ONLY and lt.reason == L.PHOTO_CLICK_ONLY then
		return result("tour", "Wuber " .. mine.ver, "skip", L.PHOTO_CLICK_ONLY .. " (after " .. shots .. " of " .. planned .. " shots): passive play won't try it again; take it by hand with /lab tour")
	end
	result("tour", "Wuber " .. mine.ver, "skip", "stopped (" .. tostring(lt.reason) .. ") after " .. shots .. " of " .. planned .. " shots; it tries again when idle")
end

local function idleTour(t)
	if PV.countdown then
		if t < PV.countdown then return end
		PV.countdown = nil
		local why = tourWhyNot(t)
		if why then return L.Log("passive", "photo tour not started: " .. why) end
		return tourStart(t)
	end
	if t - PV.lastInput < C.IDLE then return end
	if tourWhyNot(t) then return end
	PV.countdown = t + C.COUNTDOWN
	L.Log("passive", "idle in a city: photo tour in " .. C.COUNTDOWN .. " s")
	if L.Say then L.Say("passive play: idle in a city - the photo tour starts in " .. C.COUNTDOWN .. " s (any key, click or move stops it)") end
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------

local function cursor()
	local gc = rawget(_G, "GetCursorPosition")
	if type(gc) ~= "function" then return end
	local ok, x, y = pcall(gc)
	x, y = ok and num(x), ok and num(y)
	if not (x and y) then return end
	if PV.cx and math.abs(x - PV.cx) + math.abs(y - PV.cy) > C.CURSOR then input("the mouse") end
	PV.cx, PV.cy = x, y
end

local function tick()
	if not isOn() then return end
	cursor()
	local t = now()
	if PV.tourMine and not (L.Touring and L.Touring()) then tourEnded(t) end
	if L.InCombat() or L.photo then return end
	PV.n = PV.n + 1
	if PV.n % 2 == 0 and active() then
		if not hooked then hookBig() end
		scanCustomers()
		judgeAll()
	end
	idleTour(t)
end
L.PassiveTick = tick

---------------------------------------------------------------------------
-- On and off
---------------------------------------------------------------------------

local wired = false
local function wire()
	if wired then return end
	wired = true
	L.signalFns[#L.signalFns + 1] = function(name, info) if isOn() then onSignal(name, info) end end
	local baseFire = L.RunFire
	L.RunFire = function(name, ...)
		if baseFire then baseFire(name, ...) end
		if isOn() then
			local ok, err = pcall(onFire, tostring(name), ...)
			if not ok then L.Bug("passive fire", err) end
		end
	end
	L.listeners[#L.listeners + 1] = function(kind, text)
		local ok, err = pcall(onLogLine, kind, text)
		if not ok then L.Bug("passive log", err) end
	end
	for ev, why in pairs(INPUT) do L.On(ev, function() if isOn() then input(why) end end) end
	for _, ev in ipairs(OWN_CHAT) do
		L.On(ev, function(_, author)
			if isOn() and L.myKey and key(str(author) or "") == L.myKey then input("chat") end
		end)
	end
	L.On("UNIT_SPELLCAST_SENT", function(unit)
		if isOn() and plain(unit) == "player" then
			input("a cast")
			PV.castAt, PV.castWhat = now(), "the game says a spell went out"
		end
	end)
	L.On("UNIT_SPELLCAST_START", function(unit)
		if isOn() and plain(unit) == "player" then PV.castAt, PV.castWhat = now(), "the game says a cast began" end
	end)
	L.On("UNIT_SPELLCAST_FAILED", function(unit) if isOn() and plain(unit) == "player" then PV.castFailAt = now() end end)
	L.On("UNIT_SPELLCAST_CHANNEL_START", function(...) if isOn() then onChannel(...) end end)
	L.On("TRADE_SHOW", function() if isOn() then tradeShow() end end)
	L.On("TRADE_CLOSED", function() if isOn() then tradeClosed() end end)
	L.On("TRADE_REQUEST_CANCEL", function() if isOn() then tradeClosed() end end)
	L.On("GROUP_ROSTER_UPDATE", function() if isOn() then onRoster() end end)
	L.On("PLAYER_REGEN_DISABLED", function()
		if not isOn() then return end
		PV.pausedAt = now()
		PV.countdown = nil
		keyWatcher(false)
	end)
	L.On("PLAYER_REGEN_ENABLED", function()
		if not isOn() then return end
		if PV.pausedAt then shift(now() - PV.pausedAt) end
		PV.pausedAt = nil
		PV.lastInput = now()
		keyWatcher(true)
	end)
	L.On("PLAYER_LOGOUT", function()
		if not isOn() then return end
		local p = pdb()
		local s = p and session(p)
		if not s then return end
		s.ended = L.Epoch()
		local mins = (s.ended - (s.started or s.ended)) / 60
		if (s.blocked or 0) == 0 and mins * 60 >= C.BLOCK_FREE then
			result("blocked", "the session", "pass", ("no blocked action in %d min"):format(math.floor(mins)))
		end
	end)
end

local ticker
local function start()
	wire()
	local p = pdb()
	if p then session(p) end
	PV.lastInput = now()
	PV.inGroup = groupKeys()
	keyWatcher(true)
	if L.FocusStart then L.FocusStart() end
	if not ticker then ticker = L.Every(C.TICK, tick) end
	if not PV.loginDone and not PV.loginTimer then
		PV.loginTimer = true
		L.After(math.max(1, C.LOGIN_WAIT - (now() - (PV.loginAt or now()))), judgeLogin)
	end
end

local function stop(why)
	PV.countdown = nil
	keyWatcher(false)
	if L.FocusStop then L.FocusStop(why) end
	if PV.tourMine and L.Touring and L.Touring() then L.TourStop(why or "passive play off") end
	if ticker and fn(ticker, "Cancel") then pcall(ticker.Cancel, ticker) end
	ticker = nil
	PV.open = {}
	if PV.session then PV.session.ended = L.Epoch() end
	PV.session = nil
end

function L.PassiveSet(on)
	local p = pdb()
	if not p then return false end
	on = on and true or false
	local was = p.on == true
	p.on = on
	if on then start() elseif was then stop("passive play off") end
	L.Log("passive", "passive play " .. (on and "on" or "off"))
	if L.RefreshPanel then L.RefreshPanel() end
	return on
end

function L.PassiveStatus()
	if not isOn() then return "passive play is off (/lab passive on: the lab checks rides, trades, portal clicks, crew syncs and logins by itself, and takes the photo tour when idle in a city)" end
	local s = PV.session or {}
	local t = now()
	local why = tourWhyNot(t)
	local p = pdb()
	local rec = p and p.tours[L.RunWuberVersion()]
	return ("passive play is on. This session: %d passed, %d failed, %d skipped, %d to look at; %d being watched. Idle %d s. Photo tour: %s."):format(
		s.pass or 0, s.fail or 0, s.skip or 0, s.look or 0, (function() local n = 0 for _ in pairs(PV.open) do n = n + 1 end return n end)(),
		math.floor(t - PV.lastInput),
		(type(rec) == "table" and rec.done) and ("done for Wuber " .. L.RunWuberVersion())
			or (why and ("waits (" .. why .. ")") or ("after " .. C.IDLE .. " s idle")))
end

-- What passive play has proved so far for the release checklist (any Wuber version, newest first)
local SEEN = { { "blocked", "a session with no blocked action" }, { "trade", "a trade" }, { "summon", "a summon click" },
	{ "portal", "a portal click" }, { "ride", "a ride" }, { "customer", "a rider arrived" }, { "tour", "the photo tour" } }
function L.PassiveSeen()
	local p = isOn() and pdb() or (type(L.db) == "table" and type(L.db.passive) == "table" and L.db.passive) or nil
	local rel = p and type(p.release) == "table" and p.release or {}
	local out = {}
	for _, s in ipairs(SEEN) do
		local rec = type(rel[s[1]]) == "table" and rel[s[1]] or {}
		local pass, fail = rec.pass, rec.fail
		local word = "not yet"
		if type(fail) == "table" and (type(pass) ~= "table" or (fail.at or 0) >= (pass.at or 0)) then
			word = "FAILED"
		elseif type(pass) == "table" then
			word = "ok"
		end
		out[#out + 1] = s[2] .. " " .. word
	end
	return "release checklist so far: " .. table.concat(out, ", ")
end

function L.PassiveSlash(rest)
	local a = (str(rest) or ""):lower()
	if a == "on" then
		L.PassiveSet(true)
		L.Say("passive play on: play as usual; the lab checks what Wuber does and saves it (log out or /reload, then tell the person running the test \"done\")")
	elseif a == "off" then
		L.PassiveSet(false)
		L.Say("passive play off")
	else
		L.Say(L.PassiveStatus())
		L.Say(L.PassiveSeen())
	end
end

L.OnLogin(function()
	PV.loginAt = now()
	if isOn() then start() end
end)
