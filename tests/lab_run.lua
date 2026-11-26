-- Wuber Lab tests: the test run (WuberLab/Run.lua, Checks.lua, Prompt.lua), the pretend rider
-- (Pretend.lua) and the login checks. Loaded by tests/lab.lua with its helpers. Developer only.

local A = ...
local T = A.T
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean, requestVia = T.newWorld, T.settle, T.clean, T.requestVia
local HAVE_UI = T.HAVE_UI
local LAB_DIR, labOf, find, lines = A.LAB_DIR, A.labOf, A.find, A.lines
local simWorld, simSaved, bigClick, lkey, DRof, cust = A.simWorld, A.simSaved, A.bigClick, A.lkey, A.DRof, A.cust
local ANITA, FARRA, HAYLEY, ROCKS, SIM_SPOT = A.ANITA, A.FARRA, A.HAYLEY, A.ROCKS, A.SIM_SPOT

local function db(c) return c.env.WuberLabDB end
local function runOf(c) return db(c).run end
local function result(c, id)
	local run = runOf(c)
	return run and run.results[id]
end
local function step(c)
	local run = runOf(c)
	return run and not run.ended and run.steps[run.index] or nil
end
local function prompt(c) return labOf(c).runPrompt end

local function camera(c)
	local shots = {}
	c.env.Screenshot = function()
		shots[#shots + 1] = c:visibleTexts()
		-- like the game: it says the file is saved a moment later (the tour waits for that)
		c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end)
	end
	return shots
end

-- every message this world carried that names a fake ("Labfake")
local function fakeLeaks(w, since)
	local out = {}
	for i = (since or 0) + 1, #w.addonLog do
		local e = w.addonLog[i]
		if tostring(e.target):lower():find("labfake", 1, true) or tostring(e.text):lower():find("labfake", 1, true) then
			out[#out + 1] = e.prefix .. " " .. tostring(e.chatType) .. ">" .. tostring(e.target) .. " " .. e.text
		end
	end
	for _, x in ipairs(w.whispers or {}) do if tostring(x.to):lower():find("labfake", 1, true) then out[#out + 1] = "whisper to " .. x.to end end
	for _, x in ipairs(w.invites or {}) do if tostring(x.to):lower():find("labfake", 1, true) then out[#out + 1] = "invite to " .. x.to end end
	for _, m in ipairs(w.macros or {}) do if tostring(m.text):lower():find("labfake", 1, true) then out[#out + 1] = "macro " .. m.text end end
	return out
end

-- WuberDB as text, keys sorted (the same text: the same saved file)
local function serialize(v, out)
	local t = type(v)
	if t == "string" then out[#out + 1] = string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
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

---------------------------------------------------------------------------
-- The catalogue and the order
---------------------------------------------------------------------------

test("lab run: every check is well formed; the order keeps scenes whole, swaps windows little, raid after the ride, the photo tour last", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local L = labOf(c)
	local roles = { driver = true, rider = true, crew1 = true, crew2 = true }
	local logins, normal = {}, {}
	for _, ch in ipairs(L.RUN_CHECKS) do
		ok(ch.id:match("^[%w_]+$"), "id " .. ch.id)
		ok(type(ch.timeout) == "number" and ch.timeout > 0, ch.id .. " timeout")
		if ch.login then
			logins[#logins + 1] = ch.id
			ok(ch.poll or ch.begin, ch.id .. ": a login check needs poll or begin")
		else
			normal[#normal + 1] = ch.id
			ok(roles[ch.who] and roles[ch.judge], ch.id .. " who/judge")
			ok(L.RUN_SCENE_BY_ID[ch.scene], ch.id .. " scene")
			ok(ch.click or ch.say or ch.kind == "skip", ch.id .. ": says what to click or what happens")
			ok(ch.kind == "skip" or ch.poll or ch.test or ch.begin or ch.button, ch.id .. ": has a judge")
			if ch.kind == "look" then ok(ch.button, ch.id .. ": a look check takes its screenshot with a button") end
		end
	end
	ok(#logins >= 10, "login checks: " .. #logins)
	for _, id in ipairs({ "login_channel", "login_community", "login_prefixes", "login_flights", "login_button", "login_settings",
		"login_versions", "login_selftest", "login_errors", "login_saved" }) do ok(L.RUN_BY_ID[id], "login check " .. id) end
	-- "look" checks kept to a minimum
	local looks = 0
	for _, ch in ipairs(L.RUN_CHECKS) do if ch.kind == "look" then looks = looks + 1 end end
	ok(looks <= 2, "look checks: " .. looks)
	-- a full run: every scene that isn't "only"
	-- (the 2.3 probes and the raincheck, Probes.lua, fill the next run: the classic run is checked without them)
	local ids = {}
	for _, id in ipairs(L.RunWanted({ all = true, online = function() return true end })) do
		local sc = L.RUN_BY_ID[id].scene
		if sc ~= "probes8" and sc ~= "rain8" and not sc:find("^fix9") then ids[#ids + 1] = id end
	end
	local order, secs, later = L.RunOrder(ids, { start = "driver" })
	eq(#later, 0, "everything fits: " .. list(later))
	ok(secs >= 480 and secs <= 720, "about ten minutes: " .. secs .. " s")
	local pos = {}
	for i, id in ipairs(order) do pos[id] = i end
	for _, s in ipairs(L.RUN_SCENES) do
		if not s.only and s.linked and s.id ~= "rain8" and not s.id:find("^fix9") then
			for i = 2, #s.checks do
				eq(pos[s.checks[i].id], pos[s.checks[i - 1].id] + 1, "scene " .. s.id .. " stays whole and in order at " .. s.checks[i].id)
			end
		end
	end
	ok(pos.raid_invite > pos.ride_rate, "raid summons after the ride")
	eq(order[#order], "photo_tour", "the photo tour ends the run")
	ok(pos.raid_cast and pos.raid_ask and pos.raid_window, "the raid-summon test with the window open is in")
	ok(L.RunSwaps(order) <= 34, "window swaps: " .. L.RunSwaps(order))
	ok(not pos.pr_book, "the pretend rider is its own tool, not in a run")
	-- a short budget: the raid scene first (it has priority), the ride for the next run; the tour still ends it
	local o2, s2, l2 = L.RunOrder(ids, { start = "driver", budget = 200 })
	ok(#l2 > 0, "some left for later")
	eq(o2[#o2], "photo_tour")
	ok(s2 > 0)
	-- loose checks: grouped by window (Anita's, then the rider's, then the crew's)
	L.AddScene({ id = "zloose", linked = false, only = true })
	L.AddCheck({ id = "zl_r1", scene = "zloose", who = "rider", click = "a", poll = function() end })
	L.AddCheck({ id = "zl_c1", scene = "zloose", who = "crew1", click = "b", poll = function() end })
	L.AddCheck({ id = "zl_d1", scene = "zloose", who = "driver", click = "c", poll = function() end })
	L.AddCheck({ id = "zl_r2", scene = "zloose", who = "rider", click = "d", poll = function() end })
	L.AddCheck({ id = "zl_d2", scene = "zloose", who = "driver", click = "e", poll = function() end })
	local o3 = L.RunOrder({ "zl_r1", "zl_c1", "zl_d1", "zl_r2", "zl_d2" }, { start = "driver" })
	eq(table.concat(o3, ","), "zl_d1,zl_d2,zl_r1,zl_r2,zl_c1", "one window at a time")
	eq(L.RunSwaps(o3), 2, "two swaps")
	local o4 = L.RunOrder({ "zl_r1", "zl_c1", "zl_d1", "zl_r2", "zl_d2" }, { start = "rider" })
	eq(o4[1], "zl_r1", "starts where the tester is")
	-- bad checks are refused, not raised
	local bad, why = L.AddCheck({ id = "zl_r1", scene = "zloose", who = "rider" })
	eq(bad, nil)
	ok(why:find("duplicate"), why)
	eq((L.AddCheck({ id = "x y", who = "rider" })), nil, "bad id")
	eq((L.AddCheck({ id = "zl_x", who = "nobody" })), nil, "bad who")
	clean(w)
end)

---------------------------------------------------------------------------
-- One window: judges, timeouts, Skip, Looked wrong, the summary
---------------------------------------------------------------------------

test("lab run: one window: checks mark themselves (pass, fail, timeout, replay), Skip, a look's Snap, Looked wrong, the saved summary", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local L = labOf(c)
	local shots = camera(c)
	settle(w)
	L.AddScene({ id = "zt", only = true, loc = true })
	L.AddCheck({ id = "zt_pass", scene = "zt", who = "driver", click = "do it", watch = { "zt_go" }, test = function() return "pass", "went" end })
	L.AddCheck({ id = "zt_early", scene = "zt", who = "driver", say = "it already happened", watch = { "zt_early" },
		test = function() return "pass", "seen before the step began" end })
	L.AddCheck({ id = "zt_time", scene = "zt", who = "driver", click = "never", timeout = 3, poll = function() end })
	L.AddCheck({ id = "zt_fail", scene = "zt", who = "driver", say = "breaks", poll = function() return "fail", "broken on purpose" end })
	L.AddCheck({ id = "zt_skip", scene = "zt", who = "driver", click = "skip me", timeout = 60, poll = function() end })
	L.AddCheck({ id = "zt_look", scene = "zt", who = "driver", kind = "look", click = "look, then Snap", timeout = 60,
		button = { label = "Snap", run = function() if L.Snap() then return "look", "screenshot " .. L.photoShots end end } })
	L.AddCheck({ id = "zt_last", scene = "zt", who = "driver", say = "fine", poll = function() return "pass", "fine" end })
	ok(L.RunStart({ scene = "zt" }), "started")
	local P = prompt(c)
	ok(P.frame and P.frame:IsShown(), "the prompt shows")
	eq(P.big:GetText(), "Anita: do it", "who and what to click")
	ok(P.head:GetText():find("step 1 of 7", 1, true), P.head:GetText())
	-- what happens before a step begins counts for it (replayed)
	L.Signal("zt_early")
	w:advance(0.6)
	eq(step(c), "zt_pass", "still the first step")
	L.Signal("zt_go")
	eq(result(c, "zt_pass").r, "pass")
	eq(result(c, "zt_early").r, "pass", "the early event counted")
	eq(step(c), "zt_time")
	w:advance(4)
	eq(result(c, "zt_time").r, "fail")
	eq(result(c, "zt_time").why, "didn't happen within 3 s")
	eq(result(c, "zt_fail").why, "broken on purpose")
	eq(step(c), "zt_skip")
	ok(P.last:GetText():find("FAIL", 1, true), "the last result on the prompt: " .. P.last:GetText())
	c:clickOn(P.skip)
	eq(result(c, "zt_skip").r, "skip")
	eq(step(c), "zt_look")
	ok(P.action:IsShown(), "the look's Snap button")
	eq(P.action.label:GetText(), "Snap")
	c:clickOn(P.action)
	eq(result(c, "zt_look").r, "look")
	eq(#shots, 1, "one screenshot")
	eq(result(c, "zt_last").r, "pass")
	w:advance(2) -- (the prompt steps aside for a screenshot, then comes back)
	local run = runOf(c)
	eq(run.why, "done", "the run is over")
	ok(P.big:GetText():find("Done: log out or /reload, then tell the person running the test", 1, true), P.big:GetText())
	ok(P.head:GetText():find("3 passed, 2 failed, 1 to look at, 1 skipped", 1, true), P.head:GetText())
	-- Looked wrong after the end: the last step fails, with a screenshot
	c:clickOn(P.wrong)
	eq(result(c, "zt_last").r, "fail", "Looked wrong")
	ok(result(c, "zt_last").why:find("^Tester: it looked wrong %(screenshot"), result(c, "zt_last").why)
	eq(#shots, 2)
	w:advance(2) -- (back after the screenshot)
	ok(P.frame:IsShown(), "the prompt is back after the screenshot")
	-- the saved summary: one line per check
	local s = db(c).runs[#db(c).runs]
	eq(s.sid, run.sid)
	eq(#s.lines, 7)
	ok(s.lines[1]:match("^zt_pass|Anita Lift|pass|went|%d+%.%d+|%d+%.%d|Anita Lift|$"), s.lines[1])
	ok(s.lines[3]:match("^zt_time|Anita Lift|fail|didn't happen within 3 s|"), s.lines[3])
	eq(s.pass, 2) eq(s.fail, 3) eq(s.look, 1) eq(s.skip, 1)
	eq(s.wuber, c.W.VERSION)
	-- results by check, for the next run
	eq(db(c).results.zt_pass.r, "pass")
	eq(L.RunPending("zt_pass"), false)
	eq(L.RunPending("zt_time"), true, "a fail runs again")
	ok(#find(c, "run", "zt_time fail Anita Lift: didn't happen within 3 s") == 1, list(find(c, "run"), "\n"))
	-- Close hides the finished prompt
	c:clickOn(P.stop)
	L.RunPromptUpdate()
	ok(not P.frame:IsShown(), "closed")
	-- a stopped run
	ok(L.RunStart({ scene = "zt" }))
	ok(L.RunStop("stopped by the tester"))
	eq(runOf(c).why, "stopped by the tester")
	ok(#find(c, "laberr") == 0, "no lab faults: " .. list(find(c, "laberr"), "\n"))
	clean(w)
end)

test("lab run: the README's worked example ('How to add a check') loads and judges itself", function()
	local f = io.open(LAB_DIR .. "/../README.md", "rb")
	if not f then return end -- (the installed lab copy has no README)
	local md = f:read("*a")
	f:close()
	local code = md:match("%*%*Worked example%*%*.-```lua\n(.-)```")
	ok(code, "the worked example's code block")
	local w = newWorld()
	local r = A.labRider(w)
	settle(w)
	local L = labOf(r)
	local who = "Anita Lift"
	local env = setmetatable({ L = L, C_SummonInfo = { GetSummonConfirmSummoner = function() return who end } }, { __index = _G })
	local chunk = assert(loadstring(code, "README worked example"))
	setfenv(chunk, env)
	chunk()
	ok(L.RUN_BY_ID.p23_summoner, "the check is in the catalogue")
	ok(L.RunStart({ scene = "probes23" }), "started")
	eq(step(r), "p23_summoner")
	eq(prompt(r).big:GetText(), "Wuber Rocks: accept nothing yet: wait for Anita's summon box")
	r:fire("CONFIRM_SUMMON")
	eq(result(r, "p23_summoner") and result(r, "p23_summoner").r, "pass")
	eq(result(r, "p23_summoner").why, "it says Anita Lift")
	-- and a wrong name fails, with the reason
	who = "Somebody Else"
	ok(L.RunStart({ scene = "probes23" }))
	r:fire("CONFIRM_SUMMON")
	eq(result(r, "p23_summoner").r, "fail")
	eq(result(r, "p23_summoner").why, "it returned Somebody Else")
	clean(w)
end)

---------------------------------------------------------------------------
-- Two windows: the run moves between them; a /reload resumes
---------------------------------------------------------------------------

local function zwChecks(L)
	L.AddScene({ id = "zw", only = true })
	L.AddCheck({ id = "zw1", scene = "zw", who = "rider", click = "press the thing", watch = { "zw_go" }, test = function() return "pass", "pressed" end })
	L.AddCheck({ id = "zw2", scene = "zw", who = "driver", say = "Anita's side sees it", poll = function() if L.zwFlag then return "pass", "seen" end end })
	L.AddCheck({ id = "zw3", scene = "zw", who = "rider", judge = "driver", click = "press it again", watch = { "fact" },
		also = { "rider" }, observe = function() end,
		observePoll = function(o) if L.zwPress then o.Tell("pressed again") return true end end,
		test = function(_, _, from, text) if text == "pressed again" then return "pass", "told by " .. tostring(from) end end })
end

test("lab run: two windows: the step's window says what to click, the other waits; a /reload resumes; only the tester's four, paced", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w)
	settle(w)
	w:advance(15)
	local La, Lr = labOf(an), labOf(r)
	zwChecks(La)
	zwChecks(Lr)
	ok(La.RunOnline("rider"), "Anita knows Wuber Rocks is online (the plan's hello)")
	local since = #w.addonLog
	ok(La.RunStart({ scene = "zw" }))
	w:advance(2)
	eq(step(r), "zw1", "Wuber Rocks has the run")
	eq(prompt(r).big:GetText(), "Wuber Rocks: press the thing", "the rider's window: what to click")
	eq(prompt(an).big:GetText(), "Waiting for Wuber Rocks...", "Anita's window waits")
	eq(prompt(an).sub:GetText(), "Wuber Rocks: press the thing")
	-- a stranger can't touch the run
	w:inject("Bob Stone", "RUN~E~" .. runOf(an).sid .. "~nope", "WHISPER", an, "WLAB")
	eq(runOf(an).ended, nil, "a stranger is ignored")
	Lr.Signal("zw_go")
	w:advance(2)
	eq(result(an, "zw1") and result(an, "zw1").r, "pass", "Anita heard the rider's result")
	eq(step(an), "zw2")
	La.zwFlag = true
	w:advance(2)
	eq(step(r), "zw3", "the rider is on step 3")
	-- the rider's window reloads mid-run: it carries on from step 3
	local r2 = w:reload(r)
	local Lr2 = labOf(r2)
	zwChecks(Lr2)
	w:advance(6)
	eq(step(r2), "zw3", "resumed after the reload")
	ok(prompt(r2).frame and prompt(r2).frame:IsShown(), "the prompt is back")
	Lr2.zwPress = true
	w:advance(3)
	eq(result(an, "zw3") and result(an, "zw3").why, "told by Wuber Rocks", "a fact from the other window decided it")
	eq(runOf(an).why, "done")
	eq(runOf(r2).why, "done", "both windows end the run")
	-- the messages: only to the tester's four, by whisper or group, none throttled
	local n = 0
	for i = since + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WLAB" and e.text:find("^RUN~") then
			n = n + 1
			ok(e.chatType == "WHISPER" or e.chatType == "PARTY" or e.chatType == "RAID", e.chatType)
			if e.chatType == "WHISPER" then ok(e.target == ANITA or e.target == ROCKS, tostring(e.target)) end
			eq(e.result, 0, "sent: " .. e.text)
		end
	end
	ok(n > 4 and n < 30, "run messages: " .. n)
	for _, c in ipairs({ an, r2 }) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

---------------------------------------------------------------------------
-- Login checks
---------------------------------------------------------------------------

test("lab run: login checks run by themselves on every window and land in the log (and versions are compared)", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w)
	w:advance(75)
	local function rows(c)
		local out = {}
		local d = db(c).login[c.player.name]
		for _, l in ipairs(d and d.lines or {}) do
			local id, res, why = l:match("^([^|]+)|([^|]+)|([^|]*)|%d+%.%d+|%d+%.%d$")
			ok(id, "line format: " .. l)
			out[id] = { r = res, why = why }
		end
		return out
	end
	local a, b = rows(an), rows(r)
	for _, id in ipairs({ "login_wuber", "login_old_addon", "login_prefixes", "login_channel", "login_settings", "login_errors", "login_flights", "login_button" }) do
		ok(a[id], "Anita: " .. id)
		eq(a[id].r, "pass", "Anita " .. id .. ": " .. tostring(a[id].why))
	end
	ok(a.login_versions and a.login_versions.r == "pass", "versions: " .. tostring(a.login_versions and a.login_versions.why))
	ok(a.login_versions.why:find("same versions as Wuber", 1, true), a.login_versions.why)
	ok(b.login_sound, "the rider's own check")
	ok(not a.login_sound, "not on Anita")
	ok(a.login_selftest, "self-test judged")
	ok(#find(an, "run", "login login_wuber pass") == 1, list(find(an, "run"), "\n"))
	-- a window with another version: a fail that says who and what
	w:inject(FARRA, "RUN~V~9.9.9~1.1.0~1", "WHISPER", an, "WLAB")
	labOf(an).RunLoginChecks()
	w:advance(5)
	local a2 = rows(an)
	eq(a2.login_versions and a2.login_versions.r, "fail")
	ok(a2.login_versions.why:find("Farra Way runs 9.9.9", 1, true), a2.login_versions.why)
	clean(w)
end)

local function loginRows(c)
	local out = {}
	local d = db(c).login[c.player.name]
	for _, l in ipairs(d and d.lines or {}) do
		local id, res, why = l:match("^([^|]+)|([^|]+)|([^|]*)|%d+%.%d+|%d+%.%d$")
		if id then out[id] = { r = res, why = why } end
	end
	return out
end


-- BRIEF18 00:33: another addon's Lua error (DaylightUI's unit frames) is not a fail of the login check
-- for Lua errors; its name is said. Wuber's own error still fails it.
test("lab: login errors: another addon's Lua error is named, not failed; Wuber's own fails", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local L = labOf(an)
	w:advance(2)
	L.Log("err", "[handler] ...nterface/AddOns/DaylightUI_UnitFrames/UnitFrames.lua:3422: bad argument #1 to 'fn' (Usage: local isLeader = UnitIsGroupLeader(unit [, partyCategory])) @ [Interface/AddOns/WuberLab/Log.lua]:377: in function <Interface/...")
	w:advance(75)
	local a = loginRows(an)
	eq(a.login_errors and a.login_errors.r, "pass", "another addon's error: " .. tostring(a.login_errors and a.login_errors.why))
	ok(a.login_errors.why:find("DaylightUI_UnitFrames", 1, true), a.login_errors.why)
	L.Log("err", "[handler] Interface/AddOns/Wuber/Drive/Queue.lua:10: attempt to index a nil value @ [Interface/AddOns/WuberLab/Log.lua]:377: in function <Interface/...")
	L.RunLoginChecks()
	w:advance(35)
	a = loginRows(an)
	eq(a.login_errors and a.login_errors.r, "fail", "Wuber's error: " .. tostring(a.login_errors and a.login_errors.why))
	ok(a.login_errors.why:find("Queue.lua", 1, true), a.login_errors.why)
	clean(w)
end)

-- A restart whose saved variables come back only for the addons named (the client's bug).
local function restartKeeping(w, c, keep)
	local p = c.player
	c:fire("PLAYER_LOGOUT")
	local saved = {}
	for _, addon in ipairs(keep) do saved[addon] = rawget(c.env, addon == "Wuber" and "WuberDB" or (addon .. "DB")) end
	w:closeClient(c, false)
	p.online = true
	return w:addClient(p.name, { saved = saved, addons = c.allAddons or c.addons, class = p.class, spot = "Undercity", allowMissing = true })
end

test("lab run: login check 'saved settings survived a restart': a marker at logout, checked at the next login; a lost WuberDB or WuberLabDB fails", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w)
	w:advance(35)
	local first = loginRows(an).login_saved
	ok(first, "judged at the first login")
	eq(first.r, "skip", "nothing saved yet: " .. first.why)
	ok(first.why:find("first start", 1, true), first.why)
	an.W.db.rides[#an.W.db.rides + 1] = { dest = "Ratchet", driver = "Real Driver", price = 5000, at = 1700000000, stars = 4 }
	-- a /reload: everything comes back
	local an2 = w:reload(an)
	w:advance(20)
	local m = db(an2).restart[ANITA]
	ok(m and m.token and m.wuber, "the marker was written at logout")
	eq(m.wuber.rides, 1)
	local back = loginRows(an2).login_saved
	eq(back and back.r, "pass", "came back: " .. tostring(back and back.why))
	ok(back.why:find("came back, and Wuber's settings (1 trips", 1, true), back.why)
	-- Wuber's saved variables are not loaded back
	local an3 = restartKeeping(w, an2, { "WuberLab" })
	w:advance(20)
	local lost = loginRows(an3).login_saved
	eq(lost and lost.r, "fail", "Wuber's lost: " .. tostring(lost and lost.why))
	ok(lost.why:find("^the game didn't load Wuber's saved settings back: trips 1 %-> 0"), lost.why)
	-- the lab's own are not loaded back: Wuber Rocks' lab remembers this window's, so it is a fail
	local an4 = restartKeeping(w, an3, { "Wuber" })
	w:advance(35)
	local labLost = loginRows(an4).login_saved
	ok(labLost, "judged")
	eq(labLost.r, "fail", labLost.why)
	ok(labLost.why:find("^WuberLabDB came back empty, yet the lab on Wuber Rocks saw this one at"), labLost.why)
	for _, c in ipairs({ an4, r }) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

---------------------------------------------------------------------------
-- The pretend rider
---------------------------------------------------------------------------

local function pretendDriver(w)
	local an = w:addClient(ANITA, { spot = SIM_SPOT, class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI,
		saved = simSaved(ANITA, { ANITA }, ANITA) })
	settle(w)
	an.W.db.rides[#an.W.db.rides + 1] = { dest = "Ratchet", driver = "Real Driver", price = 5000, at = 1700000000, stars = 4 }
	return an
end

test("lab pretend: one window steps through the driver's screens; nothing is sent; everything is put back", function()
	local w = newWorld()
	local listener = w:addClient("Dan Plain", { spot = "Orgrimmar", class = "MAGE", money = 100000, allowMissing = not HAVE_UI })
	local an = pretendDriver(w)
	local L = labOf(an)
	-- WuberDB just before the pretend ride begins and just after it ends
	local before, after
	local origBegin, origEnd = L.PretendBegin, L.PretendEnd
	L.PretendBegin = function(...)
		before = dbText(an)
		return origBegin(...)
	end
	L.PretendEnd = function(...)
		local left = origEnd(...)
		after = dbText(an)
		return left
	end
	local sent = #w.addonLog
	ok(L.PretendStart(), "started")
	eq(step(an), "pr_open", "first: open")
	ok(prompt(an).big:GetText():find("^Anita: Drive tab: choose Sell summons and press Open"), prompt(an).big:GetText())
	ok(DRof(an).SetOpen(true), "The tester presses Open")
	w:advance(1)
	eq(step(an), "pr_console")
	T.openDrive(an)
	w:advance(3)
	ok(({ pr_book = true, pr_row = true, pr_invited = true })[step(an) or ""], "each state stays up a moment for the tester to see: " .. tostring(step(an)))
	ok(cust(an, "Pretend Labfake"), "the pretend rider is queued")
	for _ = 1, 40 do
		if result(an, "pr_button") then break end
		w:advance(0.5)
	end
	for _, id in ipairs({ "pr_open", "pr_console", "pr_book", "pr_row", "pr_invited", "pr_button" }) do
		ok(result(an, id), id .. " judged (now at " .. tostring(step(an)) .. ")")
		eq(result(an, id).r, "pass", id .. ": " .. tostring(result(an, id).why))
	end
	ok(result(an, "pr_button").why:find("Invited Pretend", 1, true), result(an, "pr_button").why)
	for _, id in ipairs({ "pr_join", "pr_summon", "pr_trade" }) do
		eq(result(an, id).r, "skip", id)
		ok(result(an, id).why:find("^needs the rider account"), result(an, id).why)
	end
	for _ = 1, 40 do
		if result(an, "pr_clean") then break end
		w:advance(0.5)
	end
	for _, id in ipairs({ "pr_cancel", "pr_price", "pr_clean" }) do
		ok(result(an, id), id .. " judged")
		eq(result(an, id).r, "pass", id .. ": " .. tostring(result(an, id).why))
	end
	ok(result(an, "pr_price").why:find("Answer Asking", 1, true), result(an, "pr_price").why)
	eq(runOf(an).why, "done")
	eq(L.pretend, nil, "off")
	-- nothing was sent anywhere naming the fakes, and no run messages either (one window)
	local leaks = fakeLeaks(w, sent)
	eq(#leaks, 0, "sent: " .. list(leaks, "\n"))
	for i = sent + 1, #w.addonLog do ok(not w.addonLog[i].text:find("^RUN~"), "a pretend run sends no run messages") end
	eq(listener.W.drivers[lkey(ANITA)] ~= nil, true, "the listener still sees Anita (her normal beacon)")
	-- everything back as it was
	ok(before and after, "both taken")
	eq(after, before, "WuberDB byte-identical")
	eq(next(DRof(an).customers), nil, "no customers left")
	eq(#an.W.incoming, 0, "no requests left")
	eq(#L.PretendLeftovers(), 0, "no leftovers")
	ok(#find(an, "fake", "kept local: invite Pretend Labfake") >= 1, list(find(an, "fake"), "\n"))
	-- the big button holds no line for a fake (checked while the price question was up)
	ok(#find(an, "laberr") == 0, "no lab faults: " .. list(find(an, "laberr"), "\n"))
	clean(w)
end)

test("lab pretend: refused while a real rider is queued or elsewhere than Anita's window; a real rider asking stops it first", function()
	local w = simWorld()
	local an = pretendDriver(w)
	local L = labOf(an)
	local r = A.labRider(w, { spot = "Orgrimmar" })
	local dan = w:addClient("Dan Plain", { spot = "Orgrimmar", class = "MAGE", money = 100000, allowMissing = not HAVE_UI })
	settle(w)
	ok(DRof(an).SetOpen(true))
	w:advance(3)
	-- not on the rider's window
	local okR, whyR = labOf(r).PretendStart()
	eq(okR, false)
	ok(whyR:find("only in the driver's own window"), whyR)
	-- a real rider in the queue
	ok(requestVia(dan, lkey(ANITA)), "Dan books Anita for real")
	w:advance(6)
	ok(cust(an, "Dan Plain"), "Dan is queued")
	local okQ, whyQ = L.PretendStart()
	eq(okQ, false)
	ok(whyQ:find("Dan Plain is in the queue", 1, true), whyQ)
	dan.W.CancelRide()
	w:advance(4)
	DRof(an).Remove(cust(an, "Dan Plain"), "drop")
	w:advance(1)
	eq(next(DRof(an).customers), nil, "the queue is empty again")
	-- the pretend ride runs; a real rider asks in the middle of it
	T.openDrive(an)
	ok(L.PretendStart(), "started")
	w:advance(2)
	ok(cust(an, "Pretend Labfake"), "the pretend rider is queued")
	ok(requestVia(r, lkey(ANITA)), "Wuber Rocks books for real")
	w:advance(4)
	eq(L.pretend, nil, "the pretend ride stopped at once")
	ok(runOf(an).why:find("^pretend stopped: a real player asked: Wuber Rocks"), runOf(an).why)
	eq(cust(an, "Pretend Labfake"), nil, "the pretend rider is gone")
	ok(cust(an, ROCKS), "the real rider is served as normal")
	ok(#w:messages("A", ANITA, "WHISPER") >= 1, "the real rider got Anita's answer")
	eq(#fakeLeaks(w), 0, "nothing named a fake: " .. list(fakeLeaks(w), "\n"))
	ok(#find(an, "laberr") == 0, "no lab faults: " .. list(find(an, "laberr"), "\n"))
	clean(w)
end)

---------------------------------------------------------------------------
-- The whole run, four windows, test mode (no shards)
---------------------------------------------------------------------------

-- That window has the step (its run messages arrive a moment after Anita's)
local function reach(w, c, id)
	for _ = 1, 20 do
		if step(c) == id then return end
		w:advance(0.5)
	end
	eq(step(c), id, c.player.name .. "'s step")
end

-- Plays Tester: the current step's action, then waits for the run to move on.
local function play(w, cs, id, action, opts)
	opts = opts or {}
	local an = cs.an
	local function cur() return step(an) end
	for _ = 1, 40 do
		if cur() == id or (not action and result(an, id)) then break end
		w:advance(0.5)
	end
	ok(cur() == id or (not action and result(an, id)), "the run is at " .. id .. " (results so far: " .. (function()
		local out = {}
		for _, sid in ipairs(runOf(an).steps) do
			local rec = runOf(an).results[sid]
			if rec then out[#out + 1] = sid .. "=" .. rec.r .. (rec.r ~= "pass" and (" (" .. tostring(rec.why) .. ")") or "") end
		end
		return table.concat(out, ", ")
	end)() .. ")")
	if action then action() end
	for _ = 1, (opts.wait or 60) * 2 do
		if result(an, id) then break end
		w:advance(0.5)
	end
	local rec = result(an, id)
	ok(rec, id .. " judged")
	eq(rec.r, opts.want or "pass", id .. ": " .. tostring(rec.why))
	return rec
end

test("lab run: a whole test run on four windows in test mode marks itself: the ride, raid summons with the window open, the photo tour", function()
	local w = simWorld()
	local names = { ANITA, FARRA, HAYLEY }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = SIM_SPOT, class = "WARLOCK", shards = 0, addons = { "Wuber", "WuberLab" },
			allowMissing = not HAVE_UI, saved = simSaved(n, names, ANITA) })
	end
	local an, fa, ha = cs[1], cs[2], cs[3]
	local r = A.labRider(w, { spot = "Orgrimmar" })
	local g = w:group(names)
	settle(w)
	w:advance(20)
	local shots = camera(an)
	local La = labOf(an)
	La.SimSet(true)
	local runCs = { an = an }
	-- (the 2.3 probes, Probes.lua, have their own tests: passed here, so this is the classic run)
	local res = db(an).results or {}
	db(an).results = res
	for _, ch in ipairs(La.RUN_CHECKS) do
		if ch.scene == "probes8" or ch.scene == "rain8" or tostring(ch.scene):find("^fix9") then res[ch.id] = { r = "pass", ver = La.RunWuberVersion() } end
	end
	ok(La.RunStart(), "Start test run")
	w:advance(5)
	for _, c in ipairs({ fa, ha, r }) do
		eq(runOf(c) and runOf(c).sid, runOf(an).sid, c.player.name .. " joined the run (Anita: " .. list(find(an, "run"), "\n") .. "\n" .. c.player.name .. ": " .. list(find(c, "run"), "\n") .. ")")
		eq(labOf(c).sim, true, c.player.name .. ": test mode on with the run")
	end
	eq(runOf(an).steps[1], "ride_open", "the ride first")
	-- the ride
	play(w, runCs, "ride_open", function()
		eq(prompt(an).big:GetText(), "Anita: open Wuber (/wuber), Drive tab, choose Sell summons and press Open")
		eq(prompt(r).big:GetText(), "Waiting for Anita...")
		ok(prompt(an).sub:GetText():find("^First: Wuber Rocks in a zone next to Anita's"), "the scene's intro at its first step: " .. prompt(an).sub:GetText())
		ok(DRof(an).SetOpen(true))
	end)
	play(w, runCs, "ride_beacon")
	ok(not prompt(an).sub:GetText():find("First:", 1, true), "the intro only at the scene's first step")
	play(w, runCs, "ride_seen", function() r.W.UI.Toggle(true) end)
	play(w, runCs, "ride_confirm", function() r.W.UI.Show("confirm", lkey(ANITA)) end)
	play(w, runCs, "ride_request", function()
		w:advance(2.5)
		if #r:findText("^Request") > 0 then r:clickText("^Request", { pattern = true }) else r:clickOn(r.env.WuberRequestButton) end
	end)
	play(w, runCs, "ride_taken")
	play(w, runCs, "ride_invited")
	play(w, runCs, "ride_button")
	play(w, runCs, "ride_cast", function()
		ok(prompt(an).big:GetText():find("^Anita: click the big button %(it says Summon Wuber"), prompt(an).big:GetText())
		bigClick(an)
	end)
	play(w, runCs, "ride_arrive", function()
		w:advance(4)
		local card = r.env.WuberLabSimCard
		ok(card and card:IsShown(), "the pretend summon card")
		r:clickOn(card.accept)
	end)
	for _, id in ipairs({ "ride_portal1", "ride_portal2" }) do
		eq(result(an, id).r, "skip", id .. " (test mode: no portal clicks)")
	end
	play(w, runCs, "ride_landed")
	play(w, runCs, "ride_trade", function()
		w:move(ROCKS, SIM_SPOT) -- (test mode: the rider walks up to pay)
		w:advance(2)
		if not w:player(ROCKS).trade then ok(w:openTrade(r, an), "trade opened") end
		local price = r.W.ride.price
		w:typeTradeMoney(w:player(ROCKS), math.floor(price / 10000), math.floor(price % 10000 / 100), price % 100)
		w:tradeAccept(w:player(ROCKS))
	end)
	play(w, runCs, "ride_paid", function()
		w:advance(0.5)
		bigClick(an)
	end)
	play(w, runCs, "ride_done")
	play(w, runCs, "ride_left")
	play(w, runCs, "ride_rate", function() ok(r.W.Rate(5)) end)
	play(w, runCs, "ride_thanks", function()
		local b = an.env.WuberDriveButton
		if b and H.visible(b) then bigClick(an) end
	end)
	play(w, runCs, "ride_earnings", function() an:clickOn(prompt(an).action) end, { want = "look" })
	-- raid summons with the window open
	play(w, runCs, "raid_invite", function() w:invite(an, ROCKS) end)
	play(w, runCs, "raid_join", function() r.env.AcceptGroup() end)
	play(w, runCs, "raid_convert", function()
		local grp = w:player(ANITA).group
		grp.raid = true
		for _, c in ipairs({ an, fa, ha, r }) do c:fire("CHAT_MSG_SYSTEM", "Party converted to Raid") end
		w:rosterChanged(grp)
	end)
	play(w, runCs, "raid_start", function()
		ok(DRof(an).SetMode("raid"))
		w:advance(1)
		DRof(an).SetSummoners({ ANITA, FARRA, HAYLEY })
		w:advance(1)
		ok(DRof(an).SetOpen(true), "Start")
	end)
	play(w, runCs, "raid_window", function() T.openDrive(an) end)
	play(w, runCs, "raid_away", function()
		w:move(ROCKS, "Orgrimmar")
		r:fire("PLAYER_STARTED_MOVING")
	end)
	play(w, runCs, "raid_tap", function() ok(r.W.Drive.RaidAsk(), "Request a summon") end)
	play(w, runCs, "raid_nvm", function() w:groupSay(ROCKS, "nvm") end)
	play(w, runCs, "raid_ask", function() w:groupSay(ROCKS, "123") end)
	play(w, runCs, "raid_button")
	play(w, runCs, "raid_cast", function() bigClick(an) end)
	play(w, runCs, "raid_arrive", function()
		w:advance(4)
		local card = r.env.WuberLabSimCard
		ok(card and card:IsShown(), "the raider's pretend card")
		r:clickOn(card.accept)
	end)
	local one = play(w, runCs, "raid_one")
	ok(one.why:find("left Wuber Rocks alone", 1, true), one.why)
	play(w, runCs, "raid_stop", function() ok(DRof(an).SetOpen(false)) end)
	-- the photo tour, the tester's one click
	play(w, runCs, "photo_tour", function()
		ok(prompt(an).action:IsShown() and prompt(an).action.label:GetText() == "Start photo tour", "the tour's button")
		an:clickOn(prompt(an).action)
		for _ = 1, 200 do
			if not La.Touring() then break end
			w:advance(1)
		end
	end, { wait = 10 })
	ok(#shots >= 20, "the tour's screenshots: " .. #shots)
	w:advance(3)
	-- the end, on every window
	for _, c in ipairs({ an, fa, ha, r }) do
		eq(runOf(c).why, "done", c.player.name .. " ended the run")
		ok(prompt(c).big:GetText():find("^Done: log out or /reload"), c.player.name .. ": " .. prompt(c).big:GetText())
	end
	local s = db(an).runs[#db(an).runs]
	eq(s.fail, 0, "no fails: " .. list(s.lines, "\n"))
	eq(s.todo, 0)
	ok(s.pass >= 30, "passed: " .. s.pass)
	eq(s.look, 1)
	ok(s.sim, "test mode noted")
	-- every window's file has the same results
	for _, c in ipairs({ fa, ha, r }) do
		local s2 = db(c).runs[#db(c).runs]
		eq(s2.sid, s.sid)
		eq(s2.pass, s.pass, c.player.name .. " passes")
	end
	-- nothing throttled, nothing real cast or summoned
	eq(w.casts, 0, "no real cast")
	eq(#w.summons, 0, "nobody really summoned")
	for _, c in ipairs({ an, fa, ha, r }) do
		ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n"))
		ok(#find(c, "err") == 0, c.player.name .. " Lua errors: " .. list(find(c, "err"), "\n"))
	end
	-- (LAB_DUMP_RUN=<dir>: these four files are the sample tools/test/labreport.test.js reads)
	local dumpDir = os.getenv("LAB_DUMP_RUN")
	if dumpDir then
		A.dumpSaved(r, "ROCKS1", dumpDir)
		A.dumpSaved(an, "GLNWLS2K", dumpDir)
		A.dumpSaved(fa, "WOW1", dumpDir)
		A.dumpSaved(ha, "WOW2", dumpDir)
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- Wuber 2.3's in-game probes (WuberLab/Probes.lua, SPEC7 10): Yes/No steps, self-marking probes
---------------------------------------------------------------------------

-- copies of catalogue checks in a one-window scene of their own (a run of just these)
-- (who: put them all on that window)
local function onlyChecks(L, scene, ids, who)
	L.AddScene({ id = scene, only = true, loc = true })
	for _, id in ipairs(ids) do
		local def = {}
		for k, v in pairs(L.RUN_BY_ID[id]) do def[k] = v end
		def.id, def.scene, def.judge = scene .. "_" .. id, scene, nil
		if who then def.who = who end
		assert(L.AddCheck(def))
	end
end

---------------------------------------------------------------------------
-- The tester's test of 2.2.3 (18 Nov): portal clicks, the full fare, the late network channel
---------------------------------------------------------------------------

test("lab run: a portal click passes on any spell event of the helper's own, the game's channel, or Wuber's click count (here or told by Anita); never on its own ritual", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local fa = w:addClient(FARRA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w, { spot = "Orgrimmar" })
	settle(w)
	w:advance(15)
	local La, Lf = labOf(an), labOf(fa)
	ok(La.RunOnline("crew1"), "Anita knows Farra is online (the plan's hello)")
	-- Anita's window: Wuber counted Farra's click (HELP) and tells Farra's judge
	ok(DRof(an).SetOpen(true))
	w:advance(3)
	ok(requestVia(r, lkey(ANITA)), "Wuber Rocks books Anita")
	w:advance(6)
	ok(cust(an, ROCKS), "Wuber Rocks is in Anita's queue")
	for _, L in ipairs({ La, Lf, labOf(r) }) do -- (every window of the run must know the check)
		L.AddScene({ id = "zpb", only = true })
		local def = {}
		for k, v in pairs(L.RUN_BY_ID.ride_portal1) do def[k] = v end
		def.id, def.scene, def.judge = "zpb_ride_portal1", "zpb", nil
		assert(L.AddCheck(def))
	end
	ok(La.RunStart({ scene = "zpb" }), "started on Anita's window")
	w:advance(2)
	eq(step(fa), "zpb_ride_portal1", "Farra has the step")
	eq(result(an, "zpb_ride_portal1"), nil)
	DRof(an).Apply("HELP", lkey(FARRA), ROCKS) -- (Farra's Wuber said she clicked)
	w:advance(3)
	local rec = result(an, "zpb_ride_portal1")
	eq(rec and rec.r, "pass", "told by Anita's window")
	eq(rec.why, "Anita's Wuber counted Farra's click for Wuber Rocks")
	eq(result(fa, "zpb_ride_portal1").judge, FARRA, "Farra's window judged it")
	local id = "zpa_ride_portal1"
	onlyChecks(Lf, "zpa", { "ride_portal1" })
	-- each spell event of Farra's own counts (START, SUCCEEDED, CHANNEL_START); another unit's never
	for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START" }) do
		w:advance(21) -- (past the replay of the last one)
		ok(Lf.RunStart({ scene = "zpa" }), "started")
		eq(step(fa), id)
		eq(prompt(fa).big:GetText(), "Farra: right-click the summoning portal")
		fa:fire(ev, "party1", "Cast-Other", 7720)
		w:advance(1)
		eq(result(fa, id), nil, ev .. ": another unit's spell is not Farra's click")
		fa:fire(ev, "player", "Cast-Help", 7720)
		eq(result(fa, id) and result(fa, id).r, "pass", ev)
		ok(result(fa, id).why:find("^clicked the portal %("), result(fa, id).why)
	end
	ok(#find(fa, "run", "portal step " .. id .. ": UNIT_SPELLCAST_SUCCEEDED, spell 7720") == 1, "the spell events are logged: " .. list(find(fa, "run", "portal step"), "\n"))
	-- Farra's own ritual (Wuber's DR.cast) is not a click
	w:advance(21)
	ok(Lf.RunStart({ scene = "zpa" }))
	DRof(fa).cast = { name = ROCKS, at = 0 }
	fa:fire("UNIT_SPELLCAST_START", "player", "Cast-Own", 698)
	w:advance(1)
	eq(result(fa, id), nil, "her own ritual is not a portal click")
	DRof(fa).cast = nil
	-- the game says Farra channels (no event at all)
	local was = fa.env.UnitChannelInfo
	fa.env.UnitChannelInfo = function(unit) if unit == "player" then return "Ritual of Summoning" end end
	w:advance(1)
	eq(result(fa, id) and result(fa, id).r, "pass", "the game's channel")
	eq(result(fa, id).why, "clicked the portal (the game says it channels Ritual of Summoning)")
	fa.env.UnitChannelInfo = was
	-- nothing seen: the reason says so
	w:advance(21)
	ok(Lf.RunStart({ scene = "zpa" }))
	w:advance(46)
	eq(result(fa, id).r, "fail")
	eq(result(fa, id).why, "no spell, channel or Wuber click seen on this window")
	for _, c in ipairs({ an, fa }) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

test("lab run: 'Anita takes the fare' passes only on the full fare; less is part paid (a fail), more payments add up", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	settle(w)
	w:advance(10)
	local L = labOf(an)
	local id = "zq_ride_paid"
	onlyChecks(L, "zq", { "ride_paid" })
	local money = an.W.Money
	-- 55c for a 50s fare (the tester's test): waits for the rest, then fails as part paid
	ok(L.RunStart({ scene = "zq" }))
	an.W.Fire("DRIVE_PAID", ROCKS, 55, 0, lkey(ANITA), true, "t", 5000)
	w:advance(5)
	eq(result(an, id), nil, "not a pass")
	w:advance(60)
	eq(result(an, id) and result(an, id).r, "fail")
	eq(result(an, id).why, "part paid: " .. money(55) .. " of the " .. money(5000) .. " fare")
	-- the rest follows: the full fare passes; somebody else's money doesn't count
	w:advance(21)
	ok(L.RunStart({ scene = "zq" }))
	an.W.Fire("DRIVE_PAID", ROCKS, 2000, 0, lkey(ANITA), true, "t", 5000)
	an.W.Fire("DRIVE_PAID", "Dan Plain", 3000, 0, lkey(ANITA), true, "t", 5000)
	w:advance(1)
	eq(result(an, id), nil, "40s of 50s is not paid")
	an.W.Fire("DRIVE_PAID", ROCKS, 3000, 0, lkey(ANITA), true, "t", 5000)
	eq(result(an, id) and result(an, id).r, "pass")
	eq(result(an, id).why, "paid " .. money(5000) .. " by " .. ROCKS)
	ok(#find(an, "laberr") == 0, "no lab faults: " .. list(find(an, "laberr"), "\n"))
	clean(w)
end)

test("lab run: login self-test: a failed 'Network channel joined' runs the self-test again 60 s after login before it counts", function()
	local w = newWorld()
	local joined = false
	local function net(c) c.W.OnNetwork = function() return joined end end
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	net(an)
	w:advance(30)
	eq(loginRows(an).login_selftest, nil, "still waiting 30 s after login")
	ok(#find(an, "self", "[login] ") == 1, "the login self-test ran: " .. list(find(an, "self"), "\n"))
	ok(find(an, "self", "[login] ")[1]:find("Network channel joined", 1, true), "and the channel wasn't joined yet")
	joined = true
	w:advance(40)
	local row = loginRows(an).login_selftest
	ok(row, "judged")
	ok(#find(an, "self", "[login +60 s]") == 1, "run again 60 s after login: " .. list(find(an, "self"), "\n"))
	ok(not row.why:find("Network channel joined", 1, true), "the channel joined meanwhile: " .. row.why)
	ok(row.why:find("(again 60 s after login)", 1, true), row.why)
	-- never joined: a fail that says it was run again
	joined = false
	labOf(an).RunSelfTest("Run checks")
	labOf(an).RunLoginChecks()
	w:advance(2)
	row = loginRows(an).login_selftest
	eq(row and row.r, "fail")
	ok(row.why:find("Network channel joined", 1, true) and row.why:find("(again 60 s after login)", 1, true), row.why)
	clean(w)
end)

local PROBE_IDS = { "pb_fold", "pb_worldmap", "pb_flight", "pb_flycal", "pb_taxinode", "pb_bird", "pb_summoner", "pb_gold",
	"pb_violet", "pb_share_party", "pb_share_raid", "pb_share_combat", "rc_open", "rc_book", "rc_join", "rc_pay", "rc_close", "rc_ask",
	"rc_give", "rc_accept", "rc_reopen", "rc_rebook", "rc_end" }

if not H.exists(LAB_DIR .. "/Probes.lua") then
	test("lab probes: this Wuber Lab has no Probes.lua (2.3 probes) - skipped", function() end)
else

test("lab probes (2.3): every probe is in Start test run, after the ride; the raincheck is one scene; they fill the next run", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local L = labOf(c)
	for _, id in ipairs(PROBE_IDS) do ok(L.RUN_BY_ID[id], "probe " .. id) end
	eq(L.RUN_BY_ID.pb_pvp, nil, "no PvP probe (round 17, D1: the zone's PvP type is not read)")
	local P, Rn = L.RUN_SCENE_BY_ID.probes8, L.RUN_SCENE_BY_ID.rain8
	ok(P and P.linked == false and P.after == "ride" and not P.only, "probes8: loose, after the ride, in Start test run")
	ok(Rn and Rn.linked and Rn.after == "ride" and not Rn.only, "rain8: whole, after the ride")
	for _, ch in ipairs(L.RUN_CHECKS) do
		if ch.ask then eq(ch.judge, ch.who, ch.id .. ": a Yes/No is judged where the tester answers") end
	end
	local ids = {}
	for _, id in ipairs(L.RunWanted({ all = true, online = function() return true end })) do
		if not L.RUN_BY_ID[id].scene:find("^fix9") then ids[#ids + 1] = id end -- (the fix round has its own test)
	end
	local order = L.RunOrder(ids, { start = "driver", all = true })
	local pos = {}
	for i, id in ipairs(order) do pos[id] = i end
	for _, id in ipairs(PROBE_IDS) do ok(pos[id] and pos[id] > pos.ride_earnings, id .. " after the ride") end
	eq(order[#order], "photo_tour", "the photo tour still ends it")
	for i = 2, #Rn.checks do eq(pos[Rn.checks[i].id], pos[Rn.checks[i - 1].id] + 1, "the raincheck stays whole at " .. Rn.checks[i].id) end
	-- one run's budget: the ride and the raid first; what doesn't fit is a probe, for the next run
	local _, secs, later = L.RunOrder(ids, { start = "driver" })
	ok(secs <= L.RUN_BUDGET, "within the budget: " .. secs)
	ok(#later > 0, "some probes wait for the next run")
	for _, id in ipairs(later) do
		local sc = L.RUN_BY_ID[id].scene
		ok(sc == "probes8" or sc == "rain8", id .. " left for later is a probe")
	end
	-- once the ride and the raid have passed, the next run is the probes (and the tour)
	local probesOnly = {}
	for _, id in ipairs(ids) do
		local sc = L.RUN_BY_ID[id].scene
		if sc == "probes8" or sc == "rain8" or sc == "end" then probesOnly[#probesOnly + 1] = id end
	end
	local o2, s2 = L.RunOrder(probesOnly, { start = "driver" })
	ok(#o2 > 10 and s2 <= L.RUN_BUDGET, "a probes run: " .. #o2 .. " steps, " .. s2 .. " s")
	ok(L.RunSwaps(o2) <= 12, "window swaps: " .. L.RunSwaps(o2))
	clean(w)
end)

test("lab probes: a Yes/No step: the question waits for the lab's own evidence; Yes passes, No fails with a screenshot", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local L = labOf(c)
	local shots = camera(c)
	settle(w)
	L.AddScene({ id = "zy", only = true, loc = true })
	L.AddCheck({ id = "zy_ask", scene = "zy", who = "driver", judge = "rider", click = "look at it", timeout = 60,
		poll = function(ctx) if L.zyReady then ctx.data.auto = "seen" end end,
		ask = function(ctx) return ctx.data.auto and "Looks right?" or nil end })
	L.AddCheck({ id = "zy_no", scene = "zy", who = "driver", click = "look again", timeout = 60, ask = "Still right?",
		answer = function(_, yes) if yes then return "pass", "fine" end return "fail", "Tester: wrong" end })
	eq(L.RUN_BY_ID.zy_ask.judge, "driver", "judged where the tester answers")
	ok(L.RunStart({ scene = "zy" }), "started")
	local P = prompt(c)
	eq(step(c), "zy_ask")
	w:advance(1.5)
	ok(not P.action:IsShown() and not P.no:IsShown(), "no Yes/No before the lab saw it")
	L.zyReady = true
	w:advance(1.5)
	ok(P.action:IsShown() and P.no:IsShown(), "Yes and No")
	eq(P.action.label:GetText(), "Yes")
	ok(P.sub:GetText():find("Looks right?  (Yes / No)", 1, true), P.sub:GetText())
	c:clickOn(P.action)
	eq(result(c, "zy_ask") and result(c, "zy_ask").r, "pass")
	eq(result(c, "zy_ask").why, "Tester: yes")
	eq(step(c), "zy_no")
	w:advance(1.5)
	ok(P.no:IsShown(), "a fixed question: Yes/No at once")
	c:clickOn(P.no)
	eq(result(c, "zy_no") and result(c, "zy_no").r, "fail")
	ok(result(c, "zy_no").why:find("^Tester: wrong %(screenshot"), result(c, "zy_no").why)
	eq(#shots, 1, "one screenshot")
	w:advance(3)
	ok(not P.no:IsShown(), "no Yes/No once the run is over")
	ok(#find(c, "laberr") == 0, "no lab faults: " .. list(find(c, "laberr"), "\n"))
	clean(w)
end)

test("lab probes: at a flight master: TaxiNodePosition's continent positions; the bird card beside the map (or a skip without a driver)", function()
	local w = newWorld()
	local r = A.labRider(w, { spot = "Orgrimmar" })
	settle(w)
	local L = labOf(r)
	onlyChecks(L, "zf", { "pb_taxinode", "pb_bird" })
	onlyChecks(L, "zn", { "pb_taxinode" })
	onlyChecks(L, "zb", { "pb_bird" })
	ok(L.RunStart({ scene = "zf" }), "started")
	eq(prompt(r).big:GetText(), "Wuber Rocks: talk to a flight master (open the flight map)")
	local nodes = { { name = "Orgrimmar, Durotar", type = "CURRENT", cost = 0, x = 0.56, y = 0.42 },
		{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 300, x = 0.51, y = 0.55 },
		{ name = "Thunder Bluff, Mulgore", type = "REACHABLE", cost = 500, x = 0.45, y = 0.62 } }
	w:openTaxiMap(r, nodes)
	w:advance(1.5)
	local rec = result(r, "zf_pb_taxinode")
	eq(rec and rec.r, "pass", rec and rec.why)
	eq(rec.why, "3 of 3 nodes have continent positions (Orgrimmar, Durotar at 0.56, 0.42)")
	w:advance(4)
	rec = result(r, "zf_pb_bird")
	eq(rec and rec.r, "skip", rec and rec.why)
	eq(rec.why, "no card: no open driver beats flying from here")
	-- positions of 0, 0 (the game's "unknown") fail
	w:closeTaxiMap(r)
	ok(L.RunStart({ scene = "zn" }))
	for _, n in ipairs(nodes) do n.x, n.y = 0, 0 end
	w:openTaxiMap(r, nodes)
	w:advance(1.5)
	eq(result(r, "zn_pb_taxinode").r, "fail")
	eq(result(r, "zn_pb_taxinode").why, "only 0 of 3 nodes have a map position (0, 0 is unknown)")
	-- a card beside the map, a strata below: the tester's Yes passes it; over the map fails
	local B = r.W.Mod("UI.Bird")
	local map = r.env.TaxiFrame
	local card = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	card:SetSize(220, 64)
	card:SetPoint("TOPLEFT", map, "TOPRIGHT", 8, 0)
	card:SetFrameStrata("LOW")
	local real = B.Card
	B.Card = function() return card end
	ok(L.RunStart({ scene = "zb" }))
	w:advance(1.5)
	ok(prompt(r).no:IsShown(), "Yes/No once the card is seen")
	ok(prompt(r).sub:GetText():find("Card beside the map, and the whole map still clickable?", 1, true), prompt(r).sub:GetText())
	r:clickOn(prompt(r).action)
	eq(result(r, "zb_pb_bird").r, "pass")
	eq(result(r, "zb_pb_bird").why, "Tester: the map stays usable; beside TaxiFrame: right of the map, a strata below")
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", map, "TOPLEFT", 20, -20)
	ok(L.RunStart({ scene = "zb" }))
	w:advance(1.5)
	eq(result(r, "zb_pb_bird").r, "fail")
	eq(result(r, "zb_pb_bird").why, "the card overlaps the map")
	B.Card = real
	ok(#find(r, "laberr") == 0, "no lab faults: " .. list(find(r, "laberr"), "\n"))
	clean(w)
end)

test("lab probes: a timed flight against the estimate taken before it; the estimate's calibration after 3 flights", function()
	local w = newWorld()
	local r = A.labRider(w, { spot = "Undercity" })
	settle(w)
	local L, W = labOf(r), r.W
	onlyChecks(L, "zt8", { "pb_flight", "pb_flycal" })
	local est, src = W.FlightTime("Undercity", "Tarren Mill")
	ok(est and est > 0 and src == "est", "an estimate: " .. tostring(est) .. " " .. tostring(src))
	ok(L.RunStart({ scene = "zt8" }))
	eq(prompt(r).big:GetText(), "Wuber Rocks: fly Undercity to Tarren Mill (or Orgrimmar to the Crossroads) and land there")
	W.Fire("FLIGHT_TIME", "orgrimmar", "thunder bluff", 200)
	w:advance(1)
	eq(step(r), "zt8_pb_flight", "another route doesn't count")
	W.Fire("FLIGHT_TIME", "undercity", "tarren mill", math.floor(est * 1.1 + 0.5))
	local rec = result(r, "zt8_pb_flight")
	eq(rec and rec.r, "pass", rec and rec.why)
	ok(rec.why:find("^Undercity to Tarren Mill: flew %d+:%d%d, estimate about %d+:%d%d %(%+1[01]%%%)$"), rec.why)
	rec = result(r, "zt8_pb_flycal")
	eq(rec and rec.r, "skip")
	eq(rec.why, "0 of 3 own flights timed: fly 3 more")
	-- more than a quarter off: a fail; three flights: calibrated
	W.db.flyCal = { ratio = 1.08, n = 3, samples = { 1.05, 1.08, 1.1 } }
	w:advance(21) -- (out of the replay of the last flight)
	ok(L.RunStart({ scene = "zt8" }))
	W.Fire("FLIGHT_TIME", "undercity", "tarren mill", est * 2)
	rec = result(r, "zt8_pb_flight")
	eq(rec.r, "fail", rec.why)
	ok(rec.why:find("more than 25%% off$"), rec.why)
	eq(result(r, "zt8_pb_flycal").r, "pass")
	eq(result(r, "zt8_pb_flycal").why, "calibrated x1.08 from 3 flights")
	ok(#find(r, "laberr") == 0, "no lab faults: " .. list(find(r, "laberr"), "\n"))
	clean(w)
end)

test("lab probes: a character that knows no flight paths skips the flight and its calibration at once (no wait)", function()
	local w = newWorld()
	local r = A.labRider(w, { spot = "Undercity" })
	settle(w)
	local L = labOf(r)
	onlyChecks(L, "zt9", { "pb_flight", "pb_flycal" })
	ok(L.RunStart({ scene = "zt9" }))
	w:advance(1)
	eq(step(r), "zt9_pb_flight", "nothing known yet: the flight step waits for a flight")
	-- The tester talks to the flight master: the map has only the node he stands at
	w:openTaxiMap(r, { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.5, y = 0.4 } })
	w:advance(1.5)
	local rec = result(r, "zt9_pb_flight")
	eq(rec and rec.r, "skip", rec and rec.why)
	eq(rec.why, "no flight paths known on this character")
	rec = result(r, "zt9_pb_flycal")
	eq(rec and rec.r, "skip", rec and rec.why)
	eq(rec.why, "no flight paths known on this character")
	w:closeTaxiMap(r)
	-- the next run knows it from that map: skipped at once, no waiting
	w:advance(21)
	ok(L.RunStart({ scene = "zt9" }))
	w:advance(0.5)
	rec = result(r, "zt9_pb_flight")
	eq(rec and rec.r, "skip", rec and rec.why)
	eq(rec.why, "no flight paths known on this character")
	-- a path learned: the flight step waits for a real flight again
	w:advance(21)
	w:openTaxiMap(r, { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.5, y = 0.4 },
		{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 300, x = 0.55, y = 0.5 } })
	w:advance(0.5)
	w:closeTaxiMap(r)
	ok(L.RunStart({ scene = "zt9" }))
	w:advance(2)
	eq(step(r), "zt9_pb_flight", "a path known: waits for the flight")
	eq(result(r, "zt9_pb_flight"), nil)
	ok(#find(r, "laberr") == 0, "no lab faults: " .. list(find(r, "laberr"), "\n"))
	clean(w)
end)

test("lab: never touches what this client forbids addons (the combat log, community invites), in any lab file", function()
	-- (round 12: the client blocks them and shows a "blocked" popup)
	-- (round 15: every name on the one list, tools/forbidden.lua, as the harness loaded it)
	local FORBIDDEN = {}
	for _, f in ipairs(H.FORBIDDEN) do FORBIDDEN[#FORBIDDEN + 1] = f.name end
	ok(#FORBIDDEN >= 4, "the list is loaded")
	local toc = assert(io.open(LAB_DIR .. "/WuberLab.toc", "r"))
	local files = {}
	for line in toc:lines() do
		line = line:gsub("%s+$", "")
		if line:match("%.lua$") and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
	end
	toc:close()
	ok(#files >= 10, "lab files in the TOC: " .. #files)
	local bad = {}
	for _, f in ipairs(files) do
		local h = assert(io.open(LAB_DIR .. "/" .. f, "r"), f)
		local src = h:read("*a")
		h:close()
		for _, name in ipairs(FORBIDDEN) do
			if src:find(name, 1, true) then bad[#bad + 1] = f .. ": " .. name end
		end
	end
	ok(#bad == 0, "forbidden in this client: " .. list(bad, ", "))
end)

test("lab probes: the share macro (/p in a party, /ra in a raid, nothing in combat); the summon box seen in the ride", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w, { spot = "Orgrimmar" })
	settle(w)
	local L, W = labOf(r), r.W
	W.UI.Toggle(true)
	w:advance(3)
	local tab = W.UI.GetTab("Ride")
	local pill = W.Theme.Pill(tab, "Share", "dark", 140, 40)
	pill:SetPoint("BOTTOM", tab, "BOTTOM", 0, 20)
	pill:SetFrameLevel(tab:GetFrameLevel() + 50)
	W.UI.Share.Register(pill, function() return "Summoned to Orgrimmar by Anita with Wuber" end, { label = "Share" })
	onlyChecks(L, "zs", { "pb_share_party", "pb_share_raid", "pb_share_combat" })
	ok(L.RunStart({ scene = "zs" }))
	w:advance(1)
	eq(step(r), "zs_pb_share_party")
	w:group({ ANITA, ROCKS })
	w:advance(1.5)
	W.UI.RefreshNow()
	w:advance(1)
	r:click(r.env.WuberShareButton)
	w:advance(1)
	local rec = result(r, "zs_pb_share_party")
	eq(rec and rec.r, "pass", rec and rec.why)
	eq(rec.why, "/p posted to party chat: 'Summoned to Orgrimmar by Anita with Wuber'")
	-- a raid: /ra
	local grp = w:player(ANITA).group
	grp.raid = true
	w:rosterChanged(grp)
	w:advance(1.5)
	W.UI.RefreshNow()
	w:advance(1)
	r:click(r.env.WuberShareButton)
	w:advance(1)
	rec = result(r, "zs_pb_share_raid")
	eq(rec and rec.r, "pass", rec and rec.why)
	eq(rec.why, "/ra posted to raid chat: 'Summoned to Orgrimmar by Anita with Wuber'")
	-- a fight: the overlay stays off, nothing is posted
	w:enterCombat(r)
	w:advance(6)
	w:leaveCombat(r)
	w:advance(1.5)
	rec = result(r, "zs_pb_share_combat")
	eq(rec and rec.r, "pass", rec and rec.why)
	ok(rec.why:find("^%d s in combat: no share overlay, nothing posted$"), rec.why)
	-- the summon box (kept from the moment it came) names the summoner
	w:summon(an, ROCKS)
	w:advance(1)
	local seen = db(r).probe8 and db(r).probe8[ROCKS] and db(r).probe8[ROCKS].summon
	ok(seen and seen.name == ANITA, "the summon box was kept: " .. tostring(seen and seen.name))
	onlyChecks(L, "zm", { "pb_summoner", "pb_gold", "pb_violet" })
	ok(L.RunStart({ scene = "zm" }))
	w:advance(1)
	eq(result(r, "zm_pb_summoner").r, "pass")
	eq(result(r, "zm_pb_summoner").why, "it named Anita Lift")
	ok(result(r, "zm_pb_gold").r == "skip" or result(r, "zm_pb_gold").r == nil, "no founder's ride seen: " .. tostring(result(r, "zm_pb_gold") and result(r, "zm_pb_gold").why))
	for _, c in ipairs({ an, r }) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

test("lab probes: the Fold on Anita's window: a width tween both ways, never a scale; the tester's Yes passes it; a scale change fails", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI, wide = true })
	settle(w)
	local L, W = labOf(an), an.W
	W.db.coach = true -- (no first-open tips)
	W.UI.Fold.Register("settings", { build = function() end, layout = function() end })
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.OpenSettings()
	w:advance(2)
	ok(W.UI.Fold.IsUnfolded(), "Settings unfolds")
	onlyChecks(L, "zfo", { "pb_fold" })
	ok(L.RunStart({ scene = "zfo" }))
	local P = prompt(an)
	eq(P.big:GetText(), "Anita: open Wuber's Settings (it unfolds), press the fold button twice (fold, unfold), then answer")
	w:advance(1)
	ok(not P.no:IsShown(), "no Yes/No before the lab saw it fold and unfold")
	W.UI.Fold.Toggle()
	w:advance(1.5)
	W.UI.Fold.Toggle()
	w:advance(1.5)
	ok(P.no:IsShown(), "Yes/No once both tweens were seen")
	an:clickOn(P.action)
	local rec = result(an, "zfo_pb_fold")
	eq(rec and rec.r, "pass", rec and rec.why)
	ok(rec.why:find("^Tester: smooth; width %d+%-%d+ in %d+ steps, scale [%d%.]+ kept$"), rec.why)
	-- the window's scale changing while it runs fails at once
	ok(L.RunStart({ scene = "zfo" }))
	w:advance(0.5)
	an.env.WuberFrame:SetScale(1.37)
	w:advance(1)
	eq(result(an, "zfo_pb_fold") and result(an, "zfo_pb_fold").r, "fail")
	ok(result(an, "zfo_pb_fold").why:find("^the window's scale changed"), result(an, "zfo_pb_fold").why)
	ok(#find(an, "laberr") == 0, "no lab faults: " .. list(find(an, "laberr"), "\n"))
	clean(w)
end)

test("lab probes: the raincheck scene's judges hear Wuber's RAINCHECK events: ask, offer, kept, taken (or refused: a fail)", function()
	local w = newWorld()
	local r = A.labRider(w, { spot = "Orgrimmar" })
	settle(w)
	local L, W = labOf(r), r.W
	onlyChecks(L, "zr", { "rc_ask", "rc_give", "rc_accept", "rc_rebook" }, "rider")
	ok(L.RunStart({ scene = "zr" }))
	eq(prompt(r).big:GetText(), "Wuber Rocks: on the Done screen tap Ask for a raincheck")
	W.Fire("RAINCHECK", "ask", "zz-ride", "wuber rocks", "Wuber Rocks")
	eq(result(r, "zr_rc_ask") and result(r, "zr_rc_ask").why, "Anita's Wuber heard the ask")
	W.Fire("RAINCHECK", "offer", "Rc0000L1")
	eq(result(r, "zr_rc_give") and result(r, "zr_rc_give").why, "offered (Rc0000L1)")
	W.Fire("RAINCHECK", "active", "Rc0000L1")
	eq(result(r, "zr_rc_accept") and result(r, "zr_rc_accept").why, "kept (Rc0000L1)")
	W.Fire("RAINCHECK", "refused", "Rc0000L1")
	eq(result(r, "zr_rc_rebook") and result(r, "zr_rc_rebook").r, "fail")
	eq(result(r, "zr_rc_rebook").why, "Anita's Wuber refused the raincheck: the normal fare")
	ok(#find(r, "laberr") == 0, "no lab faults: " .. list(find(r, "laberr"), "\n"))
	clean(w)
end)

end -- (Probes.lua)

---------------------------------------------------------------------------
-- Wuber 2.3.0's fix round (WuberLab/Checks9.lua, REPORT9 "The tester, in game"): self-marking checks and
-- Yes/No looks, first in a run, in the order setup/rider, driver, settings; the photo tour last
---------------------------------------------------------------------------

local FIX9_IDS = { "f9_home_empty", "f9_own_driver", "f9_own_crew1", "f9_open", "f9_coins", "f9_whisper", "f9_getapp_pick",
	"f9_getapp_click", "f9_note", "f9_note_reach", "f9_gift", "f9_marks", "f9_clear", "f9_customers", "f9_raid_ready", "f9_text",
	"f9_fades", "f9_foldbtn", "f9_find_volume", "f9_find_price", "f9_find_pass", "f9_find_open", "f9_find_esc", "f9_pass_open",
	"f9_pass_default", "f9_pass_on", "f9_pass_rider", "f9_pass_off" }

if not H.exists(LAB_DIR .. "/Checks9.lua") then
	test("lab fix9: this Wuber Lab has no Checks9.lua (2.3.0 fix round) - skipped", function() end)
else

-- the current step's Yes or No (the prompt's buttons on that window)
local function answer(c, yes)
	local P = prompt(c)
	ok(P.action:IsShown() and P.no:IsShown(), c.player.name .. ": Yes and No show (" .. tostring(P.sub:GetText()) .. ")")
	c:clickOn(yes and P.action or P.no)
end
local function rec9(c, id) return result(c, id) end
local function verdict(c, id) local r = result(c, id) return r and r.r end

test("lab fix9: every fix-round check is in Start test run, first by priority, in order (home, book, driver, settings, passphrase); the photo tour last", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local L = labOf(c)
	local seen = {}
	for _, id in ipairs(FIX9_IDS) do
		local ch = L.RUN_BY_ID[id]
		ok(ch, "check " .. id)
		ok(not seen[id], "unique " .. id)
		seen[id] = true
		if ch and ch.ask then eq(ch.judge, ch.who, id .. ": a Yes/No is judged where the tester answers") end
	end
	local n = 0
	for _, ch in ipairs(L.RUN_CHECKS) do if tostring(ch.scene):find("^fix9") then n = n + 1 end end
	eq(n, #FIX9_IDS, "the fix round's checks")
	local S = L.RUN_SCENE_BY_ID
	ok(S.fix9home and not S.fix9home.linked and not S.fix9home.only, "fix9home: loose")
	ok(S.fix9book and S.fix9book.linked and S.fix9book.after == "fix9home", "fix9book: whole, after the home")
	ok(S.fix9drv and not S.fix9drv.linked and S.fix9drv.after == "fix9book", "fix9drv: loose, after the book")
	ok(S.fix9set and not S.fix9set.linked and S.fix9set.after == "fix9drv", "fix9set: loose, after the driver's pages")
	ok(S.fix9pass and S.fix9pass.linked and S.fix9pass.after == "fix9set", "fix9pass: whole, after the search")
	-- everything pending, all four online: the fix round fits one run; what's left is older
	local ids = L.RunWanted({ all = true, online = function() return true end })
	local order, secs, later = L.RunOrder(ids, { start = "driver" })
	ok(secs <= L.RUN_BUDGET, "within the budget: " .. secs)
	for _, id in ipairs(later) do ok(not L.RUN_BY_ID[id].scene:find("^fix9"), id .. " left for later is not a fix-round check") end
	local pos = {}
	for i, id in ipairs(order) do pos[id] = i end
	for _, id in ipairs(FIX9_IDS) do ok(pos[id], id .. " in the run") end
	eq(order[#order], "photo_tour", "the photo tour ends it")
	local B = S.fix9book.checks
	for i = 2, #B do eq(pos[B[i].id], pos[B[i - 1].id] + 1, "the book stays whole at " .. B[i].id) end
	local P = S.fix9pass.checks
	for i = 2, #P do eq(pos[P[i].id], pos[P[i - 1].id] + 1, "the passphrase stays whole at " .. P[i].id) end
	ok(pos.f9_home_empty < pos.f9_own_driver, "the empty Home before Anita opens")
	ok(pos.f9_coins < pos.f9_whisper and pos.f9_open < pos.f9_coins, "Confirm's coins once Anita is open, before the whisper")
	for _, id in ipairs({ "f9_customers", "f9_raid_ready", "f9_text", "f9_fades", "f9_foldbtn" }) do
		ok(pos[id] > pos.f9_clear, id .. " after the book")
		ok(pos[id] < pos.f9_find_volume, id .. " before the settings")
	end
	for _, id in ipairs({ "f9_find_volume", "f9_find_price", "f9_find_pass", "f9_find_open", "f9_find_esc" }) do
		ok(pos[id] < pos.f9_pass_open, id .. " before the passphrase")
	end
	-- the fix round alone (the rest passed): one run with the tour, few window swaps
	local only = {}
	for _, id in ipairs(ids) do
		local sc = L.RUN_BY_ID[id].scene
		if sc:find("^fix9") or sc == "end" then only[#only + 1] = id end
	end
	local o2, s2, l2 = L.RunOrder(only, { start = "driver" })
	eq(#l2, 0, "nothing left for later")
	eq(#o2, #FIX9_IDS + 1, "every fix-round check and the tour")
	ok(s2 >= 300 and s2 <= L.RUN_BUDGET, "about " .. math.floor(s2 / 60 + 0.5) .. " minutes: " .. s2 .. " s")
	ok(L.RunSwaps(o2) <= 14, "window swaps: " .. L.RunSwaps(o2))
	eq(o2[#o2], "photo_tour")
	clean(w)
end)

test("lab fix9: Get Wuber queued, then out on the next big-button click only; a note, Gifted, the row's marks and tooltip, off the list (and the fails)", function()
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", shards = 10, addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	w:addBot(ROCKS, { spot = "Orgrimmar", acceptsInvites = false })
	settle(w)
	w:advance(15)
	local L, DR = labOf(an), DRof(an)
	an.W.db.coach = true
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(ROCKS, an, "WTB summon")
	w:advance(3)
	local c = cust(an, ROCKS)
	ok(c, "Wuber Rocks asked by whisper")
	-- fails: a rider through the app; "Get Wuber" going out with no click
	c.wuberRide = "abcdef"
	onlyChecks(L, "zf", { "f9_whisper", "f9_getapp_pick" }, "driver")
	ok(L.RunStart({ scene = "zf" }))
	eq(verdict(an, "zf_f9_whisper"), "fail")
	eq(rec9(an, "zf_f9_whisper").why, "Wuber Rocks came through the app: cancel it and whisper by hand")
	eq(step(an), "zf_f9_getapp_pick")
	c.wuberRide = nil
	w:advance(1)
	eq(step(an), "zf_f9_getapp_pick", "waits for the pick")
	an:chatEvent("CHAT_MSG_WHISPER_INFORM", DR.Template("getapp"), ROCKS)
	w:advance(1)
	eq(verdict(an, "zf_f9_getapp_pick"), "fail")
	eq(rec9(an, "zf_f9_getapp_pick").why, "\"Get Wuber\" went out with no big-button click")
	w:advance(2)
	-- the pass path, in the scene's order
	onlyChecks(L, "zb", { "f9_own_driver", "f9_whisper", "f9_getapp_pick", "f9_getapp_click", "f9_note", "f9_gift", "f9_marks", "f9_clear" }, "driver")
	ok(L.RunStart({ scene = "zb" }))
	eq(step(an), "zb_f9_own_driver")
	eq(prompt(an).big:GetText(), "Anita: Drive tab > Crew: on Farra's card switch on \"my account\"")
	ok(DR.SetBookOwn(lkey(FARRA), true))
	w:advance(1)
	eq(verdict(an, "zb_f9_own_driver"), "pass")
	eq(verdict(an, "zb_f9_whisper"), "pass", rec9(an, "zb_f9_whisper") and rec9(an, "zb_f9_whisper").why)
	eq(step(an), "zb_f9_getapp_pick")
	ok(DR.AskGetApp(cust(an, ROCKS)), "picked")
	w:advance(1)
	eq(verdict(an, "zb_f9_getapp_pick"), "pass", rec9(an, "zb_f9_getapp_pick") and rec9(an, "zb_f9_getapp_pick").why)
	eq(step(an), "zb_f9_getapp_click")
	w:advance(5)
	eq(step(an), "zb_f9_getapp_click", "nothing goes out by itself")
	for _ = 1, 3 do
		if verdict(an, "zb_f9_getapp_click") then break end
		bigClick(an)
		w:advance(1.5)
	end
	local gr = rec9(an, "zb_f9_getapp_click")
	eq(gr and gr.r, "pass", gr and gr.why)
	ok(gr.why:find("^whispered on big%-button click %d") or gr.why:find("^sent with big%-button click %d"), gr.why)
	eq(step(an), "zb_f9_note")
	ok(DR.SetNote(ROCKS, "tips well, Orgrimmar"))
	w:advance(1)
	eq(rec9(an, "zb_f9_note").why, "note saved: 'tips well, Orgrimmar'")
	ok(DR.SetGifted(ROCKS))
	w:advance(1)
	ok(rec9(an, "zb_f9_gift").why:find("^stamped gifted "), rec9(an, "zb_f9_gift").why)
	eq(step(an), "zb_f9_marks")
	if HAVE_UI then
		T.openDrive(an)
		w:advance(2)
		local row = L.Fix9RowOf(cust(an, ROCKS))
		ok(row, "Wuber Rocks' row on screen")
		w:advance(1)
		eq(step(an), "zb_f9_marks", "waits for the tooltip")
		H.state[row].scripts.OnEnter(row)
		w:advance(1)
		local mr = rec9(an, "zb_f9_marks")
		eq(mr and mr.r, "pass", mr and mr.why)
		an.W.Driver.RowAction(cust(an, ROCKS), "drop")
		w:advance(1.5)
		eq(rec9(an, "zb_f9_clear") and rec9(an, "zb_f9_clear").why, "Wuber Rocks is off Anita's list")
	end
	ok(#find(an, "laberr") == 0, "no lab faults: " .. list(find(an, "laberr"), "\n"))
	clean(w)
end)

test("lab fix9: a note reaches the other own-account window (or says why not)", function()
	local w = newWorld()
	local names = { ANITA, FARRA }
	local cs = {}
	for i, n in ipairs(names) do
		local saved = simSaved(n, names, ANITA)
		-- Anita marks Farra; Farra hasn't marked Anita yet
		if n == ANITA then saved.Wuber.chars[lkey(n)].bookOwn = { [lkey(FARRA)] = true } end
		cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI, saved = saved })
	end
	w:group(names)
	w:advance(15)
	local an, fa = cs[1], cs[2]
	local Lf = labOf(fa)
	onlyChecks(Lf, "zn", { "f9_note_reach" }, "crew1")
	-- the fail: Farra hasn't marked Anita, the note never comes, and the fail says why
	ok(Lf.RunStart({ scene = "zn" }))
	eq(prompt(fa).big:GetText(), "Farra: nothing to click - the note reaches Farra's window by itself")
	w:advance(2)
	eq(step(fa), "zn_f9_note_reach", "no note yet")
	ok(an.W.Drive.SetNote(ROCKS, "pays in gold"))
	w:advance(92)
	local r1 = rec9(fa, "zn_f9_note_reach")
	eq(r1 and r1.r, "fail", r1 and r1.why)
	eq(r1.why, "Farra hasn't marked Anita \"My own account\"")
	-- Farra marks Anita (as in the run: both marks first, then the note): the next note arrives
	ok(fa.W.Drive.SetBookOwn(lkey(ANITA), true))
	w:advance(60)
	-- (round 12) the mark brings Anita's earlier note within seconds (Farra's hello on the mark)
	eq(fa.W.Drive.BookEntry(ROCKS) and fa.W.Drive.BookEntry(ROCKS).note, "pays in gold", "the earlier note came after the mark")
	ok(Lf.RunStart({ scene = "zn" }))
	ok(an.W.Drive.SetNote(ROCKS, "pays in gold, tips"))
	for _ = 1, 180 do
		if verdict(fa, "zn_f9_note_reach") then break end
		w:advance(0.5)
	end
	local r = rec9(fa, "zn_f9_note_reach")
	eq(r and r.r, "pass", r and r.why)
	ok(r.why:find("^Farra's book has Anita's note: 'pays in gold"), r.why)
	for _, c in ipairs(cs) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

test("lab fix9: Settings search (volume, price, passphrase), a match opens highlighted, Esc clears without closing; a Mage has no passphrase; Esc that closes fails", function()
	if not HAVE_UI then return end
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w, { spot = "Orgrimmar" })
	settle(w)
	local L = labOf(an)
	for _, c in ipairs({ an, r }) do
		c.W.db.coach = true
		c.W.UI.Toggle(true)
	end
	w:advance(3)
	onlyChecks(L, "zs", { "f9_find_volume", "f9_find_price", "f9_find_pass", "f9_find_open", "f9_find_esc" }, "driver")
	ok(L.RunStart({ scene = "zs" }))
	w:advance(1)
	eq(step(an), "zs_f9_find_volume")
	ok(rec9(an, "zs_f9_find_volume") == nil, "waits for Settings")
	an.W.UI.OpenSettings()
	w:advance(1)
	local st = an.W.UI.settings
	an:type(st.find.box.edit, "vol", false)
	w:advance(1)
	eq(step(an), "zs_f9_find_volume", "not the whole word yet")
	an:type(st.find.box.edit, "volume", false)
	w:advance(1)
	local v = rec9(an, "zs_f9_find_volume")
	eq(v and v.r, "pass", v and v.why)
	ok(v.why:find("Sounds", 1, true), v.why)
	an:type(st.find.box.edit, "price", false)
	w:advance(1)
	ok(rec9(an, "zs_f9_find_price").why:find("My time is worth", 1, true), rec9(an, "zs_f9_find_price").why)
	an:type(st.find.box.edit, "passphrase", false)
	w:advance(1)
	local pr = rec9(an, "zs_f9_find_pass")
	eq(pr and pr.r, "pass", pr and pr.why)
	ok(pr.why:find("Show ride passphrase", 1, true), pr.why)
	an:click(st.find.items[1])
	w:advance(0.6)
	local op = rec9(an, "zs_f9_find_open")
	eq(op and op.r, "pass", op and op.why)
	ok(op.why:find("highlighted", 1, true), op.why)
	an:click(st.back)
	w:advance(0.5)
	an:type(st.find.box.edit, "map", false)
	w:advance(1)
	eq(step(an), "zs_f9_find_esc")
	H.state[st.find.box.edit].scripts.OnEscapePressed(st.find.box.edit)
	w:advance(1.5)
	local e = rec9(an, "zs_f9_find_esc")
	eq(e and e.r, "pass", e and e.why)
	eq(e.why, "Esc cleared 'map', the window and Settings stayed open")
	-- an Esc that closes the window: a fail
	onlyChecks(L, "ze", { "f9_find_esc" }, "driver")
	ok(L.RunStart({ scene = "ze" }))
	an:type(st.find.box.edit, "map", false)
	w:advance(1)
	H.state[st.find.box.edit].scripts.OnEscapePressed(st.find.box.edit)
	an.env.WuberFrame:Hide()
	w:advance(1.5)
	eq(verdict(an, "ze_f9_find_esc"), "fail")
	eq(rec9(an, "ze_f9_find_esc").why, "Esc in the search box closed Wuber's window")
	-- a Mage's Settings have no Driving: "passphrase" finds no "Show ride passphrase"
	local Lr = labOf(r)
	onlyChecks(Lr, "zm", { "f9_find_pass" }, "rider")
	ok(Lr.RunStart({ scene = "zm" }))
	r.W.UI.OpenSettings()
	w:advance(1)
	r:type(r.W.UI.settings.find.box.edit, "passphrase", false)
	w:advance(1)
	eq(verdict(r, "zm_f9_find_pass"), "fail", tostring(rec9(r, "zm_f9_find_pass") and rec9(r, "zm_f9_find_pass").why) .. " / step "
		.. tostring(step(r)) .. " / " .. tostring(prompt(r).big:GetText()) .. " / " .. tostring(prompt(r).sub:GetText()) .. " / shown "
		.. tostring(r.W.UI.SettingsShown()) .. " / query " .. tostring(r.W.UI.settings.query) .. " / count " .. tostring(r.W.UI.settings.find and r.W.UI.settings.find.count))
	for _, c in ipairs({ an, r }) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

test("lab fix9: the passphrase off by default, on, heard by the rider's Wuber, off again; raid summons outside a raid; the Yes/No looks (Yes passes, No fails)", function()
	if not HAVE_UI then return end
	local w = newWorld()
	local an = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", shards = 10, addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = A.labRider(w, { spot = "Orgrimmar" })
	settle(w)
	w:advance(10)
	local La, Lr, DR = labOf(an), labOf(r), DRof(an)
	local shots = camera(an)
	for _, c in ipairs({ an, r }) do c.W.db.coach = true end
	-- the empty Home (nobody open), then Yes
	onlyChecks(Lr, "zh", { "f9_home_empty" }, "rider")
	ok(Lr.RunStart({ scene = "zh" }))
	w:advance(1)
	ok(not prompt(r).no:IsShown(), "no Yes/No before Home shows")
	r.W.UI.Toggle(true)
	w:advance(2)
	answer(r, true)
	local h = rec9(r, "zh_f9_home_empty")
	eq(h and h.r, "pass", h and h.why)
	ok(h.why:find("^Tester: right; 'No drivers online"), h.why)
	-- the passphrase
	onlyChecks(La, "zp", { "f9_pass_open", "f9_pass_default", "f9_pass_on", "f9_pass_off" }, "driver")
	ok(La.RunStart({ scene = "zp" }))
	ok(DR.SetOpen(true))
	w:advance(1.5)
	eq(verdict(an, "zp_f9_pass_open"), "pass")
	eq(rec9(an, "zp_f9_pass_default").why, "off (never set: the default)")
	eq(step(an), "zp_f9_pass_on")
	DR.SetOpt("showPass", true)
	an.W.Fire("SETTINGS", "drive.showPass")
	w:advance(1)
	eq(verdict(an, "zp_f9_pass_on"), "pass")
	onlyChecks(Lr, "zq", { "f9_pass_rider" }, "rider")
	ok(Lr.RunStart({ scene = "zq" }))
	for _ = 1, 120 do
		if verdict(r, "zq_f9_pass_rider") then break end
		w:advance(1)
	end
	eq(rec9(r, "zq_f9_pass_rider") and rec9(r, "zq_f9_pass_rider").why, "Anita's entry says riders see the passphrase")
	DR.SetOpt("showPass", false)
	w:advance(1)
	eq(rec9(an, "zp_f9_pass_off") and rec9(an, "zp_f9_pass_off").why, "off again: no passphrase")
	-- Confirm's coin icons (Yes)
	onlyChecks(Lr, "zc", { "f9_coins" }, "rider")
	ok(Lr.RunStart({ scene = "zc" }))
	r.W.UI.Show("confirm", lkey(ANITA))
	w:advance(1.5)
	answer(r, true)
	eq(verdict(r, "zc_f9_coins"), "pass")
	-- raid summons started outside a raid: in a group it waits (and fails at the limit); alone it passes
	ok(DR.SetOpen(false))
	w:advance(1)
	ok(DR.SetMode("raid"))
	T.openDrive(an)
	w:advance(1)
	w:group({ ANITA, ROCKS })
	w:advance(1)
	onlyChecks(La, "zr", { "f9_raid_ready" }, "driver")
	ok(La.RunStart({ scene = "zr" }))
	w:advance(151)
	eq(verdict(an, "zr_f9_raid_ready"), "fail")
	eq(rec9(an, "zr_f9_raid_ready").why, "Anita is in a group: leave it first")
	w:leave(ROCKS)
	w:advance(2)
	ok(La.RunStart({ scene = "zr" }))
	T.openDrive(an)
	w:advance(2)
	local rr = rec9(an, "zr_f9_raid_ready")
	eq(rr and rr.r, "pass", rr and rr.why)
	eq(rr.why, "'Ready to summon?' with 'Make or join a raid first.'")
	-- the Customers page (this window can't unfold: folded only), small text (Yes), fades (No: a fail
	-- with a screenshot), the header's fold button (Yes)
	ok(DR.SetMode("sell"))
	onlyChecks(La, "zl", { "f9_customers", "f9_text", "f9_fades", "f9_foldbtn" }, "driver")
	ok(La.RunStart({ scene = "zl" }))
	w:advance(1)
	ok(not prompt(an).no:IsShown(), "no Yes/No before the Customers page shows")
	an.W.Driver.ShowScreen("customers")
	w:advance(1.5)
	answer(an, true)
	local cu = rec9(an, "zl_f9_customers")
	eq(cu and cu.r, "pass", cu and cu.why)
	ok(cu.why:find("folded (this window can't unfold)", 1, true), cu.why)
	w:advance(1)
	answer(an, true)
	eq(verdict(an, "zl_f9_text"), "pass")
	w:advance(1)
	answer(an, false)
	eq(verdict(an, "zl_f9_fades"), "fail")
	ok(rec9(an, "zl_f9_fades").why:find("^Tester: no %(screenshot"), rec9(an, "zl_f9_fades").why)
	eq(#shots, 1, "one screenshot for the No")
	w:advance(1)
	answer(an, true)
	eq(verdict(an, "zl_f9_foldbtn"), "pass")
	for _, c in ipairs({ an, r }) do ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n")) end
	clean(w)
end)

end -- (Checks9.lua)

---------------------------------------------------------------------------
-- The lab's own files stay inside Lua 5.1's limits
---------------------------------------------------------------------------

test("lab run: the lab's files stay under 170 locals per function and file (tools/check.lua)", function()
	local here = (debug.getinfo(1, "S").source or ""):match("^@(.*)/[^/]*$") or "tests"
	local CHECK = assert(loadfile(here .. "/../tools/check.lua"))("--lib")
	local files = {}
	for l in io.lines(LAB_DIR .. "/WuberLab.toc") do if l:match("%.lua$") then files[#files + 1] = l end end
	ok(#files >= 13, "the lab's files: " .. #files)
	local function read(p)
		local f = io.open(LAB_DIR .. "/" .. p, "rb")
		if not f then return nil end
		local t = f:read("*a")
		f:close()
		return t
	end
	local any = setmetatable({}, { __index = function() return true end })
	local res = CHECK.check({ files = files, read = read, globals = { read = any, write = any }, owner = {}, legacy = any, allow = {} })
	local bad = {}
	for _, l in ipairs(res.fails) do if l:find("locals") or l:find("upvalues") or l:find("compile") or l:find("exist") then bad[#bad + 1] = l end end
	for _, l in ipairs(res.warns) do if l:find("locals") or l:find("upvalues") then bad[#bad + 1] = l end end
	eq(#bad, 0, list(bad, "\n"))
end)
