-- Wuber Lab tests: passive play (WuberLab/Passive.lua, developer only, never shipped). The lab
-- watches normal play: rides, trades, summon and portal clicks, crew syncs, logins and blocked
-- actions mark themselves; the photo tour starts by itself when idle in a city and stops on any
-- input or combat; and passive play never sends anything or acts for the player.
-- Loaded by run.lua like tests/lab.lua; skipped with one passing note when the lab isn't there.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean = T.newWorld, T.settle, T.clean
local HAVE_UI = T.HAVE_UI

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/Passive.lua") then
	test("lab passive: Wuber Lab's Passive.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function labOf(c) return c.ns.WuberLab end

-- WuberDB as text, keys sorted: the same text means the same saved file
local function serialize(v, out)
	local t = type(v)
	if t == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then
		out[#out + 1] = tostring(v)
	elseif t == "table" then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
			return type(a) < type(b)
		end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			out[#out + 1] = "["
			serialize(k, out)
			out[#out + 1] = "]="
			serialize(v[k], out)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "<" .. t .. ">"
	end
end
local function dbText(c)
	local out = {}
	serialize(c.env.WuberDB, out)
	return table.concat(out)
end

-- Everything a window sent into the world (addon messages of any prefix, whispers, chat lines, invites)
local function sentBy(w, name)
	local n = 0
	for _, e in ipairs(w.addonLog or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.whispers or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.chatPosts or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.invites or {}) do if e.from == name then n = n + 1 end end
	return n
end

-- The game's Screenshot(): counted; SCREENSHOT_SUCCEEDED a moment later, like the game
local function cameraOn(c)
	local shots = {}
	c.env.Screenshot = function()
		c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end)
		shots[#shots + 1] = c.env.GetTime()
	end
	return shots
end

-- Every API that sends something or acts for the player, wrapped: calls[name] = { n, fromPassive }
-- (fromPassive: calls with WuberLab/Passive.lua anywhere on the stack)
local ACTIONS = { "SendChatMessage", "SendAddonMessage", "CastSpellByName", "CastSpellByID", "TargetUnit", "AssistUnit",
	"InviteUnit", "AcceptTrade", "InitiateTrade", "AcceptGroup", "DeclineGroup", "ConfirmSummon", "CancelSummon", "LeaveParty",
	"RunMacroText", "SetTradeMoney", "PickupPlayerMoney", "DoEmote", "JumpOrAscendStart", "MoveForwardStart", "ToggleAutoRun",
	"InteractUnit", "UseAction", "UseItemByName", "SetRaidTarget", "PromoteToLeader", "ConvertToRaid" }
local TABLE_ACTIONS = { C_ChatInfo = { "SendAddonMessage", "SendAddonMessageLogged" }, C_PartyInfo = { "InviteUnit", "LeaveParty", "ConfirmLeaveParty", "ConvertToRaid" },
	C_SummonInfo = { "ConfirmSummon", "CancelSummon" }, C_TradeInfo = { "SetTradeMoney" }, C_BattleNet = { "SendWhisper" } }

local function spyActions(c)
	local calls = {}
	local function wrap(t, name, label)
		local orig = t[name]
		if type(orig) ~= "function" then return end
		calls[label] = { n = 0, fromPassive = 0 }
		t[name] = function(...)
			local rec = calls[label]
			rec.n = rec.n + 1
			if debug.traceback():find("Passive.lua", 1, true) then rec.fromPassive = rec.fromPassive + 1 end
			return orig(...)
		end
	end
	for _, n in ipairs(ACTIONS) do wrap(c.env, n, n) end
	for tn, names in pairs(TABLE_ACTIONS) do
		local t = rawget(c.env, tn)
		if type(t) == "table" then for _, n in ipairs(names) do wrap(t, n, tn .. "." .. n) end end
	end
	return calls
end

local function fromPassive(calls)
	local out = {}
	for name, rec in pairs(calls) do if rec.fromPassive > 0 then out[#out + 1] = name .. " x" .. rec.fromPassive end end
	table.sort(out)
	return out
end

-- this session's lines, as { kind, subject, r, why }
local function lines(c)
	local p = c.env.WuberLabDB.passive
	local s = p and p.sessions and p.sessions[#p.sessions]
	local out = {}
	for _, l in ipairs(s and s.lines or {}) do
		local kind, subject, r, why = l:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|")
		out[#out + 1] = { kind = kind, subject = subject, r = r, why = why }
	end
	return out
end

local function linesOf(c, kind)
	local out = {}
	for _, l in ipairs(lines(c)) do if l.kind == kind then out[#out + 1] = l end end
	return out
end

local function show(ls)
	local out = {}
	for _, l in ipairs(ls) do out[#out + 1] = l.kind .. " " .. l.r .. " " .. l.subject .. ": " .. l.why end
	return table.concat(out, " / ")
end

local function client(w, name, class, opts)
	opts = opts or {}
	local c = w:addClient(name, { spot = opts.spot or "Undercity", class = class or "MAGE", money = 100000, addons = opts.addons or { "Wuber", "WuberLab" },
		allowMissing = not HAVE_UI, screenW = 1920, screenH = 1080, saved = opts.saved })
	return c
end

-- passive play on, with short waits for the tests (put back by fresh()).
local DEFAULTS
local function fresh(L)
	DEFAULTS = DEFAULTS or {}
	for k, v in pairs(L.PASSIVE) do if DEFAULTS[k] == nil then DEFAULTS[k] = v end end
	for k, v in pairs(DEFAULTS) do L.PASSIVE[k] = v end
end

local function city(c, yes) c.env.IsResting = function() return yes ~= false end end

---------------------------------------------------------------------------

test("lab passive: off by default - nothing saved, no keyboard watcher; /lab passive on|off|status and the Tools button", function()
	local w = newWorld()
	local c = client(w, "Wuber Rocks")
	settle(w)
	local L = labOf(c)
	fresh(L)
	eq(L.PassiveOn(), false, "off by default")
	eq(c.env.WuberLabDB.passive, nil, "nothing saved while off")
	eq(rawget(c.env, "WuberLabPassiveKeys"), nil, "no keyboard watcher while off")
	c:slash("/lab passive status")
	ok(list(c.chatLines, " / "):find("passive play is off", 1, true), "status while off: " .. list(c.chatLines, " / "))
	c:slash("/lab passive on")
	eq(L.PassiveOn(), true, "on")
	eq(c.env.WuberLabDB.passive.on, true, "saved on")
	local keys = rawget(c.env, "WuberLabPassiveKeys")
	ok(keys and keys:IsShown(), "the keyboard watcher is shown")
	ok(type(c.env.WuberLabDB.passive.sessions[1]) == "table", "a session started")
	c:slash("/lab passive status")
	ok(list(c.chatLines, " / "):find("passive play is on", 1, true), "status while on: " .. list(c.chatLines, " / "))
	-- the Tools tab's button says so and turns it off
	c:slash("/lab")
	w:advance(1)
	local P = L.panel
	for _, t in ipairs(P.tabs) do if t.name == "Tools" then c:clickOn(t) end end
	w:advance(0.6)
	local b = P.toolButtons.passive
	ok(b and b:IsShown(), "the Passive play button is on the Tools tab")
	eq(b.label:GetText(), "Passive play: ON", "its label")
	ok(b:GetScript("OnEnter") ~= nil, "it has a tooltip")
	c:clickOn(b)
	eq(L.PassiveOn(), false, "the button turns it off")
	eq(b.label:GetText(), "Passive play: off", "its label after")
	ok(not keys:IsShown(), "the keyboard watcher hides when off")
	c:slash("/lab passive on")
	c:slash("/lab passive off")
	eq(L.PassiveOn(), false, "/lab passive off")
	clean(w)
end)

test("lab passive: rides mark themselves - done passes, failed fails, cancelled is skipped, a stuck stage fails", function()
	local w = newWorld()
	local c = client(w, "Wuber Rocks")
	settle(w)
	local L = labOf(c)
	fresh(L)
	L.PASSIVE.STUCK = 30
	L.PassiveSet(true)
	local function ride(id, states, extra)
		local r = { id = id, driver = "Anita Lift", driverKey = "anita lift", dest = "Ratchet", price = 5000 }
		for k, v in pairs(extra or {}) do r[k] = v end
		for _, s in ipairs(states) do
			r.state = s
			L.OnRide(r)
			w:advance(0.5)
		end
		return r
	end
	ride("r1", { "requesting", "accepted", "invited", "ingroup", "summoning", "portal", "arrived", "paying" }, { paidSoFar = 5000 })
	local r1 = { id = "r1", driver = "Anita Lift", dest = "Ratchet", price = 5000, paid = 5000, state = "done" }
	L.OnRide(r1)
	ride("r2", { "requesting", "accepted", "failed" }, { reason = "the summon didn't come" })
	ride("r3", { "requesting", "cancelled" })
	ride("r4", { "requesting", "declined" })
	-- a fake driver's ride is never judged
	local fake = { id = "rf", driver = "Cheap Labfake", driverKey = "cheap labfake", state = "requesting" }
	L.OnRide(fake)
	w:advance(1)
	local got = linesOf(c, "ride")
	eq(#got, 4, "four rides judged: " .. show(got))
	eq(got[1].r, "pass", "the done ride: " .. show(got))
	ok(got[1].why:find("paid", 1, true), "it says it was paid: " .. got[1].why)
	eq(got[2].r, "fail", "the failed ride")
	ok(got[2].why:find("summon didn't come", 1, true), "with Wuber's reason: " .. got[2].why)
	eq(got[3].r, "skip", "the cancelled ride")
	eq(got[4].r, "skip", "the declined ride")
	-- stuck: one stage too long (the ride is still Wuber's ride)
	local r5 = { id = "r5", driver = "Anita Lift", driverKey = "anita lift", dest = "Ratchet", price = 5000, state = "requesting" }
	c.W.ride = r5
	L.OnRide(r5)
	r5.state = "invited"
	L.OnRide(r5)
	w:advance(20)
	eq(#linesOf(c, "ride"), 4, "not stuck yet")
	w:advance(15)
	got = linesOf(c, "ride")
	eq(#got, 5, "the stuck ride judged: " .. show(got))
	eq(got[5].r, "fail", "stuck = fail")
	ok(got[5].why:find("stuck at invited", 1, true), got[5].why)
	-- the release checklist's evidence
	local rel = c.env.WuberLabDB.passive.release.ride
	ok(rel and rel.pass and rel.fail and rel.n == 5, "release.ride has the last pass and fail")
	c.W.ride = nil
	clean(w)
end)

test("lab passive: a trade with gold in from a customer passes only when Wuber marks them paid", function()
	local w = newWorld()
	local c = client(w, "Anita Lift", "WARLOCK")
	settle(w)
	local L, W = labOf(c), c.W
	fresh(L)
	L.PassiveSet(true)
	local DR = W.Drive
	local unitName = W.UnitName
	local partner = "Dan Rider"
	W.UnitName = function(u) if u == "npc" then return partner end return unitName(u) end
	DR.customers["dan rider"] = { name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0 }
	local function trade(copper, mark)
		DR.customers["dan rider"] = { name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0 }
		c:fire("TRADE_SHOW")
		w:advance(1)
		c.player.money = c.player.money + copper
		c:fire("TRADE_CLOSED")
		if mark then W.Fire("DRIVE_PAID", partner, copper, 0, "anita lift", true, "t", 5000) end
		w:advance(8)
	end
	trade(5000, true)
	trade(5000, false)
	trade(0, false)
	partner = "Joe Stranger"
	trade(300, false)
	local got = linesOf(c, "trade")
	eq(#got, 4, "four trades: " .. show(got))
	eq(got[1].r, "pass", "marked paid: " .. show(got))
	eq(got[2].r, "fail", "not marked: " .. show(got))
	ok(got[2].why:find("didn't mark them paid", 1, true), got[2].why)
	eq(got[3].r, "skip", "no gold moved")
	eq(got[4].r, "skip", "gold from a non-customer")
	W.UnitName = unitName
	DR.customers["dan rider"] = nil
	clean(w)
end)

test("lab passive: the rider's trade passes when the ride counts the gold, fails when it doesn't", function()
	local w = newWorld()
	local c = client(w, "Wuber Rocks")
	settle(w)
	local L, W = labOf(c), c.W
	fresh(L)
	L.PassiveSet(true)
	local unitName, rideActive, rideTrader = W.UnitName, W.RideActive, W.RideTrader
	W.UnitName = function(u) if u == "npc" then return "Anita Lift" end return unitName(u) end
	W.RideActive = function() return true end
	W.RideTrader = function(_, k) return k == "anita lift" end
	local r = { id = "r7", driver = "Anita Lift", driverKey = "anita lift", state = "summoning", price = 5000, paidSoFar = 0 }
	W.ride = r
	for _, counted in ipairs({ true, false }) do
		c:fire("TRADE_SHOW")
		w:advance(1)
		c.player.money = c.player.money - 5000
		if counted then r.paidSoFar = (r.paidSoFar or 0) + 5000 end
		c:fire("TRADE_CLOSED")
		w:advance(8)
	end
	local got = linesOf(c, "trade")
	eq(#got, 2, "two trades: " .. show(got))
	eq(got[1].r, "pass", "counted: " .. show(got))
	eq(got[2].r, "fail", "not counted: " .. show(got))
	W.UnitName, W.RideActive, W.RideTrader, W.ride = unitName, rideActive, rideTrader, nil
	clean(w)
end)

test("lab passive: a big-button Summon click passes when a cast starts, fails when none does", function()
	local w = newWorld()
	local c = client(w, "Anita Lift", "WARLOCK")
	settle(w)
	local L, W = labOf(c), c.W
	fresh(L)
	L.PassiveSet(true)
	w:advance(2) -- (the click hook goes on within a tick)
	local b = c.env.WuberDriveButton
	ok(b, "the big button exists")
	local plan, refresh = b.plan, W.Drive.Button.Refresh
	W.Drive.Button.Refresh = function() end -- (the plan stays as the test sets it)
	b.plan = { title = "Summon Dan", type = "macro", marks = { { kind = "cast", c = { name = "Dan Rider" } } } }
	c:runClick(b, "LeftButton", false)
	W.Drive.cast = { name = "Dan Rider", at = c.env.GetTime() }
	w:advance(2)
	W.Drive.cast = nil
	c:runClick(b, "LeftButton", false)
	w:advance(10)
	b.plan = { title = "Waiting for Eve", marks = {} }
	c:runClick(b, "LeftButton", false) -- (not a summon click: not judged)
	w:advance(10)
	local got = linesOf(c, "summon")
	eq(#got, 2, "two summon clicks judged: " .. show(got))
	eq(got[1].r, "pass", show(got))
	ok(got[1].why:find("Dan Rider", 1, true), got[1].why)
	eq(got[2].r, "fail", show(got))
	b.plan, W.Drive.Button.Refresh = plan, refresh
	clean(w)
end)

test("lab passive: a portal click on a crew mate's ritual passes when Wuber counts it", function()
	local w = newWorld()
	local c = client(w, "Farra Way", "WARLOCK")
	settle(w)
	local L, W = labOf(c), c.W
	fresh(L)
	L.PassiveSet(true)
	W.Fire("DRIVE_RITUAL", "Dan Rider", "c", { mine = false })
	c:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid-1", 23598)
	w:advance(1)
	W.Fire("DRIVE_RITUAL", "Dan Rider", "h", { helper = "farra way" })
	w:advance(1)
	c:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid-2", 23598)
	w:advance(12)
	W.Fire("DRIVE_RITUAL", "Dan Rider", "s", { mine = false })
	c:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid-3", 5143) -- (no ritual going on: not a portal click)
	w:advance(12)
	local got = linesOf(c, "portal")
	eq(#got, 2, "two portal clicks judged: " .. show(got))
	eq(got[1].r, "pass", show(got))
	eq(got[2].r, "fail", show(got))
	clean(w)
end)

test("lab passive: a crew window joining the group passes when its Wuber says hello", function()
	local w = newWorld()
	local c = client(w, "Anita Lift", "WARLOCK", { spot = "Ratchet" })
	w:addClient("Farra Way", { spot = "Ratchet", class = "WARLOCK", addons = { "Wuber" }, allowMissing = not HAVE_UI })
	w:addClient("Hayley Cab", { spot = "Ratchet", class = "WARLOCK", addons = {}, allowMissing = true }) -- (her Wuber is off)
	settle(w)
	local L, W = labOf(c), c.W
	fresh(L)
	L.PASSIVE.CREW_WAIT = 20
	L.PassiveSet(true)
	local DR = W.Drive
	local crewEntry, on, peers = DR.CrewEntry, DR.on, DR.peers
	DR.on = true
	DR.CrewEntry = function(k)
		if k == "farra way" or k == "hayley cab" then return { name = k, role = "lock", app = true } end
		return crewEntry and crewEntry(k)
	end
	DR.peers = {}
	w:group({ "Anita Lift", "Farra Way", "Hayley Cab" })
	w:advance(1)
	w:advance(25) -- (Farra's Wuber says hello by itself: the real crew sync)
	local got = linesOf(c, "crew")
	eq(#got, 2, "two crew windows judged: " .. show(got))
	table.sort(got, function(a, b) return a.subject < b.subject end)
	eq(got[1].r, "pass", show(got))
	eq(got[2].r, "fail", show(got))
	ok(got[2].why:find("no word from", 1, true), got[2].why)
	DR.CrewEntry, DR.on, DR.peers = crewEntry, on, peers
	clean(w)
end)

test("lab passive: login checks, blocked actions and errors are noted; a clean session passes 'blocked' at logout", function()
	local w = newWorld()
	local c = client(w, "Wuber Rocks", "MAGE", { saved = { WuberLab = { chars = {}, passive = { on = true } } } })
	local L = labOf(c)
	fresh(L)
	ok(L.PassiveOn(), "on from the saved setting")
	w:advance(125)
	local got = linesOf(c, "login")
	eq(#got, 1, "the login checks judged once: " .. show(lines(c)))
	ok(got[1] and (got[1].r == "pass" or got[1].r == "fail"), "a verdict: " .. show(got))
	c:fire("ADDON_ACTION_BLOCKED", "Wuber", "CastSpellByName()")
	c.W.Error("test", "something broke")
	w:advance(1)
	got = linesOf(c, "blocked")
	eq(#got, 1, "the blocked action: " .. show(lines(c)))
	eq(got[1].r, "fail", "a fail")
	ok(got[1].why:find("CastSpellByName", 1, true), got[1].why)
	local errs = linesOf(c, "error")
	ok(#errs >= 1 and errs[1].r == "fail" and errs[1].subject == "Wuber", "Wuber's error: " .. show(errs))
	c.W.lastError = nil
	clean(w)
	-- a clean session of 10 minutes or more: "blocked" passes at logout
	local w2 = newWorld()
	local c2 = client(w2, "Wuber Rocks", "MAGE", { saved = { WuberLab = { chars = {}, passive = { on = true } } } })
	local L2 = labOf(c2)
	w2:advance(L2.PASSIVE.BLOCK_FREE + 5)
	c2:fire("PLAYER_LOGOUT")
	got = linesOf(c2, "blocked")
	eq(#got, 1, "one line: " .. show(lines(c2)))
	eq(got[1] and got[1].r, "pass", "no blocked action")
	ok(c2.env.WuberLabDB.passive.release.blocked.pass, "the release checklist's evidence")
	clean(w2)
end)

-- BRIEF18 00:33: another addon's Lua error (DaylightUI's unit frames, during summoning) was logged as
-- "error fail Wuber" because the lab's own handler (WuberLab/Log.lua) is in its stack. The name comes
-- from the error's own file path (Interface\AddOns\<name>\...): another addon is "other addon: <name>"
-- and only looked at, Wuber's own is a fail, the lab's is the lab.
test("lab passive: another addon's Lua error is 'other addon: <name>' from its file path, never 'Wuber'", function()
	local w = newWorld()
	local c = client(w, "Wuber Rocks", "MAGE", { saved = { WuberLab = { chars = {}, passive = { on = true } } } })
	local L = labOf(c)
	fresh(L)
	ok(L.PassiveOn(), "on")
	local STACK = " @ [Interface/AddOns/WuberLab/Log.lua]:377: in function <Interface/..."
	L.Log("err", "[handler] ...nterface/AddOns/DaylightUI_UnitFrames/UnitFrames.lua:3422: bad argument #1 to 'fn' (Usage: local isLeader = UnitIsGroupLeader(unit [, partyCategory])) [C]: in function 'fn' [Interface/AddOns/DaylightUI_UnitFrames/Unit" .. STACK)
	L.Log("err", "[handler] (seen 10 times) ...nterface/AddOns/DaylightUI_UnitFrames/UnitFrames.lua:3243: bad argument #1 to 'UnitThreatSituation' (Usage: local result = UnitThreatSituation(unit [, mobGUID]))" .. STACK)
	L.Log("err", "[BugGrabber] Interface\\AddOns\\Bagnon\\core.lua:12: attempt to index a nil value")
	L.Log("err", "[handler] Interface/AddOns/Wuber/Drive/Queue.lua:10: attempt to index a nil value" .. STACK)
	L.Log("err", "[handler] Interface/AddOns/WuberLab/Photo.lua:5: attempt to call a nil value" .. STACK)
	L.Log("err", "[handler] [string \"x\"]:1: oops" .. STACK)
	w:advance(1)
	local errs = linesOf(c, "error")
	eq(#errs, 6, "one line each: " .. show(errs))
	local want = {
		{ "other addon: DaylightUI_UnitFrames", "look" }, { "other addon: DaylightUI_UnitFrames", "look" },
		{ "other addon: Bagnon", "look" }, { "Wuber", "fail" }, { "the lab", "look" }, { "another addon", "look" },
	}
	for i, x in ipairs(want) do
		eq(errs[i] and errs[i].subject, x[1], "line " .. i .. ": " .. show(errs))
		eq(errs[i] and errs[i].r, x[2], "line " .. i .. " verdict")
	end
	clean(w)
end)

-- the idle tour: a rider in a city, nothing touched
local function idleClient(w, opts)
	local c = client(w, "Wuber Rocks", "MAGE", opts)
	settle(w)
	local L = labOf(c)
	fresh(L)
	L.PASSIVE.IDLE, L.PASSIVE.COUNTDOWN = 10, 2
	city(c, true)
	return c, L
end

local function untilTour(w, L, max)
	for _ = 1, (max or 40) * 4 do
		if L.Touring() then return true end
		w:advance(0.25)
	end
	return L.Touring()
end

local function untilDone(w, L)
	for _ = 1, 600 do
		if not L.Touring() then return end
		w:advance(1)
	end
end

test("lab passive: idle in a city out of combat, the photo tour starts by itself - nothing sent, WuberDB put back, once per Wuber version", function()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" }) -- someone listening
	local c, L = idleClient(w)
	local shots = cameraOn(c)
	local calls = spyActions(c)
	L.PassiveSet(true)
	local before = dbText(c)
	w:advance(5)
	ok(not L.Touring(), "not before the idle time")
	local sent = sentBy(w, "Wuber Rocks")
	ok(untilTour(w, L), "the tour started by itself: " .. tostring(L.PassiveTourWhyNot()))
	ok(list(c.chatLines, " / "):find("photo tour starts in", 1, true), "a countdown first: " .. list(c.chatLines, " / "))
	untilDone(w, L)
	ok(#shots > 40, "screenshots taken: " .. #shots)
	eq(sentBy(w, "Wuber Rocks") - sent, 0, "nothing sent during the tour")
	eq(dbText(c), before, "WuberDB put back")
	w:advance(1)
	local got = linesOf(c, "tour")
	eq(#got, 1, "the tour judged: " .. show(lines(c)))
	eq(got[1] and got[1].r, "pass", show(got))
	local rec = c.env.WuberLabDB.passive.tours[c.W.VERSION]
	ok(rec and rec.done, "done for this Wuber version")
	ok(c.env.WuberLabDB.passive.release.tour.pass, "the release checklist's evidence")
	ok(L.PassiveSeen():find("the photo tour ok", 1, true), "/lab passive status says so: " .. L.PassiveSeen())
	ok(L.PassiveSeen():find("a trade not yet", 1, true), "and what it hasn't seen: " .. L.PassiveSeen())
	-- never again for this version, however idle
	local n = #shots
	w:advance(60)
	ok(not L.Touring(), "not again")
	eq(#shots, n, "no more shots")
	ok(tostring(L.PassiveTourWhyNot()):find("already done", 1, true), "why not: " .. tostring(L.PassiveTourWhyNot()))
	eq(list(fromPassive(calls)), "", "send or action APIs called from Passive.lua")
	clean(w)
end)

test("lab passive: the idle tour waits outside a city, in a group, in combat, and while off", function()
	local w = newWorld()
	local c, L = idleClient(w)
	cameraOn(c)
	w:advance(30)
	ok(not L.Touring(), "off: no tour")
	L.PassiveSet(true)
	city(c, false)
	w:advance(30)
	ok(not L.Touring(), "outside a city: no tour")
	eq(L.PassiveTourWhyNot(), "not in a city", "why")
	city(c, true)
	c.player.combat = true
	c:fire("PLAYER_REGEN_DISABLED")
	w:advance(30)
	ok(not L.Touring(), "in combat: no tour")
	ok(not c.env.WuberLabPassiveKeys:IsShown(), "the keyboard watcher hides in combat")
	c.player.combat = false
	c:fire("PLAYER_REGEN_ENABLED")
	ok(c.env.WuberLabPassiveKeys:IsShown(), "and comes back after")
	local inGroup = c.env.IsInGroup
	c.env.IsInGroup = function() return true end
	w:advance(30)
	ok(not L.Touring(), "in a group: no tour")
	eq(L.PassiveTourWhyNot(), "in a group", "why")
	c.env.IsInGroup = inGroup
	ok(untilTour(w, L), "then it starts: " .. tostring(L.PassiveTourWhyNot()))
	L.TourStop("test")
	clean(w)
	-- the driver's and the crew's windows never take it (one window shoots: the files are named by the second)
	local w2 = newWorld()
	local a = client(w2, "Anita Lift", "WARLOCK")
	settle(w2)
	local LA = labOf(a)
	fresh(LA)
	LA.PASSIVE.IDLE, LA.PASSIVE.COUNTDOWN = 10, 2
	city(a, true)
	cameraOn(a)
	LA.PassiveSet(true)
	w2:advance(40)
	ok(not LA.Touring(), "not on Anita's window")
	ok(tostring(LA.PassiveTourWhyNot()):find("rider's window", 1, true), "why: " .. tostring(LA.PassiveTourWhyNot()))
	clean(w2)
end)

-- each input stops the tour (and the countdown)
local INPUTS = {
	{ "a key", function(c) local k = c.env.WuberLabPassiveKeys k:GetScript("OnKeyDown")(k, "W") end },
	{ "the mouse moving", function(c) c.cursorX = (c.cursorX or 960) + 40 end },
	{ "a click", function(c) c:clickOn(c.env.WuberLabPhotoCatcher) end },
	{ "moving", function(c) c:fire("PLAYER_STARTED_MOVING") end },
	{ "chat", function(c) c:fire("CHAT_MSG_SAY", "hello", "Wuber Rocks") end },
	{ "a target", function(c) c:fire("PLAYER_TARGET_CHANGED") end },
	{ "a modifier key", function(c) c:fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1) end },
	{ "a cast", function(c) c:fire("UNIT_SPELLCAST_SENT", "player", "", "guid", 1459) end },
	{ "combat", function(c) c.player.combat = true c:fire("PLAYER_REGEN_DISABLED") end },
}

test("lab passive: the auto tour stops at once on any input - a key, the mouse, a click, moving, chat, a target, a cast - and on combat", function()
	for _, case in ipairs(INPUTS) do
		local w = newWorld()
		local c, L = idleClient(w)
		cameraOn(c)
		L.PassiveSet(true)
		local before = dbText(c)
		ok(untilTour(w, L), case[1] .. ": the tour started")
		w:advance(3)
		case[2](c)
		w:advance(0.5)
		ok(not L.Touring(), case[1] .. ": the tour stopped")
		eq(dbText(c), before, case[1] .. ": WuberDB put back")
		w:advance(1)
		local got = linesOf(c, "tour")
		eq(got[1] and got[1].r, "skip", case[1] .. ": a stopped tour is a skip, tried again later: " .. show(got))
		local rec = c.env.WuberLabDB.passive.tours[c.W.VERSION]
		ok(rec and not rec.done, case[1] .. ": not done yet")
		c.player.combat = false
		clean(w)
	end
end)

test("lab passive: input during the countdown calls the tour off", function()
	local w = newWorld()
	local c, L = idleClient(w)
	local shots = cameraOn(c)
	L.PassiveSet(true)
	for _ = 1, 80 do
		if L.passiveState.countdown then break end
		w:advance(0.25)
	end
	ok(L.passiveState.countdown, "the countdown is on")
	c:fire("PLAYER_STARTED_MOVING")
	ok(not L.passiveState.countdown, "called off")
	w:advance(3)
	ok(not L.Touring(), "no tour")
	eq(#shots, 0, "no shots")
	ok(list(c.chatLines, " / "):find("called off", 1, true), "said so: " .. list(c.chatLines, " / "))
	clean(w)
end)

test("lab passive: a real whisper during the auto tour stops it and still reaches Wuber", function()
	local w = newWorld()
	local c, L = idleClient(w)
	cameraOn(c)
	local heard = {}
	local f = c.W.frame
	local orig = f:GetScript("OnEvent")
	f:SetScript("OnEvent", function(self, event, ...)
		if event == "CHAT_MSG_WHISPER" or event == "PARTY_INVITE_REQUEST" then heard[#heard + 1] = event end
		return orig(self, event, ...)
	end)
	L.PassiveSet(true)
	ok(untilTour(w, L), "the tour started")
	w:advance(3)
	c:fire("CHAT_MSG_WHISPER", "hi, are you about?", "Bob Stone")
	ok(not L.Touring(), "the tour stopped")
	eq(list(heard), "CHAT_MSG_WHISPER", "Wuber heard the whisper")
	ok(tostring(L.lastTour and L.lastTour.reason):find("real player", 1, true), "why: " .. tostring(L.lastTour and L.lastTour.reason))
	f:SetScript("OnEvent", orig)
	-- a manual tour (/lab tour) still holds whispers back, as before
	local c2w = newWorld()
	local c2 = client(c2w, "Wuber Rocks")
	settle(c2w)
	cameraOn(c2)
	local L2 = labOf(c2)
	ok(L2.TourStart(), "a manual tour")
	c2w:advance(3)
	c2:fire("CHAT_MSG_WHISPER", "hi", "Bob Stone")
	ok(L2.Touring(), "a manual tour goes on")
	L2.TourStop("test")
	clean(c2w)
	clean(w)
end)

-- (review) the keyboard watcher's frame, changed as it is made (how: "error", "no", "missing")
local function brokenKeys(c, how)
	c.env.CreateFrame = (function(make)
		return function(...)
			local f = make(...)
			if select(2, ...) == "WuberLabPassiveKeys" then
				if how == "error" then f.SetPropagateKeyboardInput = function() error("protected") end
				elseif how == "no" then f.SetPropagateKeyboardInput = function() end
				elseif how == "missing" then f.SetPropagateKeyboardInput, f.GetPropagateKeyboardInput = false, false end -- (an old client: no such methods)
			end
			return f
		end
	end)(c.env.CreateFrame)
end

test("lab passive: a keyboard watcher that can't pass keys on is never shown and takes no keys; the events still stop the tour", function()
	for _, how in ipairs({ "error", "no", "missing" }) do
		local w = newWorld()
		local c, L = idleClient(w)
		cameraOn(c)
		brokenKeys(c, how)
		L.PassiveSet(true)
		local keys = rawget(c.env, "WuberLabPassiveKeys")
		ok(keys, how .. ": the watcher was made")
		eq(keys and keys:IsKeyboardEnabled(), false, how .. ": its keyboard is off again (it would swallow every key)")
		ok(keys and not keys:IsShown(), how .. ": never shown")
		c.player.combat = true
		c:fire("PLAYER_REGEN_DISABLED")
		c.player.combat = false
		c:fire("PLAYER_REGEN_ENABLED")
		ok(not keys:IsShown(), how .. ": not shown after a fight either")
		ok(untilTour(w, L), how .. ": the tour still starts: " .. tostring(L.PassiveTourWhyNot()))
		w:advance(3)
		c:fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
		w:advance(0.5)
		ok(not L.Touring(), how .. ": a modifier key (an event) stops it")
		eq(keys:IsKeyboardEnabled(), false, how .. ": the keyboard still off")
		ok(not keys:IsShown(), how .. ": still hidden")
		clean(w)
	end
end)

test("lab passive: the keyboard watcher is made, and its keyboard set, only out of combat", function()
	local w = newWorld()
	local c, L = idleClient(w)
	local calls = {}
	c.env.CreateFrame = (function(make)
		return function(...)
			local f = make(...)
			if select(2, ...) == "WuberLabPassiveKeys" then
				for _, m in ipairs({ "EnableKeyboard", "SetPropagateKeyboardInput" }) do
					local orig = f[m]
					f[m] = function(...)
						calls[#calls + 1] = m .. (c.player.combat and " in combat" or "")
						return orig(...)
					end
				end
			end
			return f
		end
	end)(c.env.CreateFrame)
	c.player.combat = true
	c:fire("PLAYER_REGEN_DISABLED")
	L.PassiveSet(true)
	eq(rawget(c.env, "WuberLabPassiveKeys"), nil, "turned on in combat: no watcher yet")
	w:advance(5)
	c.player.combat = false
	c:fire("PLAYER_REGEN_ENABLED")
	local keys = rawget(c.env, "WuberLabPassiveKeys")
	ok(keys and keys:IsShown(), "made and shown after the fight")
	eq(keys and keys:GetPropagateKeyboardInput(), true, "it passes keys on")
	c.player.combat = true
	c:fire("PLAYER_REGEN_DISABLED")
	ok(not keys:IsShown(), "hidden in the next fight")
	c.player.combat = false
	c:fire("PLAYER_REGEN_ENABLED")
	ok(keys:IsShown(), "back after it")
	eq(list(calls), "EnableKeyboard; SetPropagateKeyboardInput", "set once, out of combat")
	for _, v in ipairs(w.violations or {}) do ok(not tostring(v):find("Keyboard", 1, true), "no violation: " .. tostring(v)) end
	clean(w)
end)

test("lab passive: no auto tour where the game wants a click per shot; a refused shot ends a passive tour (no Snap button)", function()
	-- learned before: the tour waits, and says why
	local w = newWorld()
	local c, L = idleClient(w)
	cameraOn(c)
	L.PassiveSet(true)
	c.env.WuberLabDB.photoClick = true
	w:advance(40)
	ok(not L.Touring(), "no tour")
	eq(L.PassiveTourWhyNot(), "this client needs a click per shot", "why")
	clean(w)
	-- learned during the tour: the first refused shot ends it
	local w2 = newWorld()
	local c2, L2 = idleClient(w2)
	local shots = 0
	c2.env.Screenshot = function()
		shots = shots + 1
		c2:fire("ADDON_ACTION_BLOCKED", "WuberLab", "Screenshot()")
	end
	local before = dbText(c2)
	L2.PassiveSet(true)
	ok(untilTour(w2, L2), "the tour started: " .. tostring(L2.PassiveTourWhyNot()))
	for _ = 1, 60 do
		if shots > 0 then break end
		w2:advance(0.5)
	end
	ok(shots > 0, "a shot was tried")
	w2:advance(0.5)
	ok(not L2.Touring(), "the refused shot ended the tour")
	local snap = rawget(c2.env, "WuberLabPhotoSnap")
	ok(not (snap and snap:IsShown()), "no Snap button to click")
	eq(L2.lastTour and L2.lastTour.reason, "this client needs a click per shot", "why it ended")
	eq(dbText(c2), before, "WuberDB put back")
	w2:advance(1)
	local got = linesOf(c2, "tour")
	eq(got[1] and got[1].r, "skip", show(got))
	ok(got[1] and got[1].why:find("click per shot", 1, true), "says why: " .. show(got))
	w2:advance(60)
	ok(not L2.Touring(), "not tried again")
	eq(L2.PassiveTourWhyNot(), "this client needs a click per shot", "why not")
	clean(w2)
end)

test("lab passive: a real trade during the auto tour stops it first, then reaches Wuber; a manual tour holds it back", function()
	local w = newWorld()
	local c, L = idleClient(w)
	cameraOn(c)
	local heard = {}
	local f = c.W.frame
	local orig = f:GetScript("OnEvent")
	f:SetScript("OnEvent", function(self, event, ...)
		if event:find("^TRADE_") then heard[#heard + 1] = event .. (L.photo and " (during the tour)" or "") end
		return orig(self, event, ...)
	end)
	local before = dbText(c)
	L.PassiveSet(true)
	ok(untilTour(w, L), "the tour started")
	w:advance(3)
	c:fire("TRADE_SHOW")
	ok(not L.Touring(), "the tour stopped")
	eq(list(heard), "TRADE_SHOW", "Wuber heard the trade, after the tour had put its data back")
	eq(dbText(c), before, "WuberDB put back")
	c:fire("TRADE_CLOSED")
	f:SetScript("OnEvent", orig)
	clean(w)
	-- a manual tour (/lab tour): Wuber, holding demo data, doesn't hear the trade's events
	local w2 = newWorld()
	local c2 = client(w2, "Wuber Rocks")
	settle(w2)
	cameraOn(c2)
	local L2 = labOf(c2)
	local heard2 = {}
	local f2 = c2.W.frame
	local orig2 = f2:GetScript("OnEvent")
	f2:SetScript("OnEvent", function(self, event, ...)
		if event:find("^TRADE_") or event == "CANCEL_SUMMON" then heard2[#heard2 + 1] = event end
		return orig2(self, event, ...)
	end)
	ok(L2.TourStart(), "a manual tour")
	w2:advance(3)
	for _, ev in ipairs({ "TRADE_SHOW", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "CANCEL_SUMMON" }) do c2:fire(ev) end
	ok(L2.Touring(), "a manual tour goes on")
	eq(list(heard2), "", "Wuber heard none of it")
	L2.TourStop("test")
	f2:SetScript("OnEvent", orig2)
	clean(w2)
end)

test("lab passive: on or off, the same play sends the same messages and makes no action call - passive play never sends or acts", function()
	local function play(on)
		local w = newWorld()
		local a = client(w, "Anita Lift", "WARLOCK", { spot = "Ratchet" })
		local r = client(w, "Wuber Rocks", "MAGE", { spot = "Orgrimmar" })
		settle(w)
		local calls = { a = spyActions(a), r = spyActions(r) }
		for _, c in ipairs({ a, r }) do
			local L = labOf(c)
			fresh(L)
			L.PASSIVE.IDLE = 5
			city(c, false) -- (no tour here: its own test checks it sends nothing)
			if on then L.PassiveSet(true) end
		end
		local sent0 = { a = sentBy(w, "Anita Lift"), r = sentBy(w, "Wuber Rocks") }
		-- normal play: a ride's moments, trades, clicks, a blocked action, a roster change
		for _, c in ipairs({ a, r }) do
			c:fire("TRADE_SHOW")
			w:advance(1)
			c:fire("TRADE_CLOSED")
			c:fire("ADDON_ACTION_BLOCKED", "Wuber", "CastSpellByName()")
			c:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 23598)
			c:fire("PLAYER_STARTED_MOVING")
			c.W.Fire("DRIVE_RITUAL", "Dan Rider", "c", { mine = false })
			w:advance(2)
		end
		labOf(r).OnRide({ id = "x1", driver = "Anita Lift", state = "requesting" })
		w:advance(60)
		local out = { a = sentBy(w, "Anita Lift") - sent0.a, r = sentBy(w, "Wuber Rocks") - sent0.r, calls = {} }
		for who, cs in pairs(calls) do
			for name, rec in pairs(cs) do out.calls[#out.calls + 1] = who .. ":" .. name .. "=" .. rec.n .. (rec.fromPassive > 0 and ("!" .. rec.fromPassive) or "") end
		end
		table.sort(out.calls)
		out.n = #lines(a) + #lines(r)
		clean(w)
		return out
	end
	local off, on = play(false), play(true)
	ok(on.n > 0, "passive play judged things: " .. on.n)
	eq(on.a, off.a, "Anita sent the same number of messages")
	eq(on.r, off.r, "Wuber Rocks sent the same number of messages")
	eq(table.concat(on.calls, " "), table.concat(off.calls, " "), "the same send and action calls")
	ok(not table.concat(on.calls, " "):find("!", 1, true), "none from Passive.lua: " .. table.concat(on.calls, " "))
end)
