-- Lab job 242: the Auto check's new screens (lab/WuberLab/AutoSteps7.lua) and the saved-data check (PR-76).
-- Each check is shown two ways in the fake game: on the current Wuber every step passes; on a Wuber copy with the fix undone
-- (the client's opts.rewrite changes the source it loads, tests/harness_draw.lua does the same) the step says look.
-- Skipped with one passing note when the Lab isn't there. Wuber Lab is never shipped.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoSteps7.lua") then
	test("lab auto7: AutoSteps7.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local SCREENS = { "a_settings_asks", "a_driver_hits", "a_pill_hit", "a_rider_checks" }
local STEPS = { "PR-79", "PR-78", "PR-50", "PR-62", "PR-97", "PR-45", "PR-116", "PR-115", "PR-48" }

local function serialize(v, out)
	local ty = type(v)
	if ty == "string" then out[#out + 1] = string.format("%q", v)
	elseif ty == "number" or ty == "boolean" or ty == "nil" then out[#out + 1] = tostring(v)
	elseif ty == "table" then
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
		out[#out + 1] = "<" .. ty .. ">"
	end
end
local function dbText(c)
	local out = {}
	serialize(c.env.WuberDB, out)
	return table.concat(out)
end
local function sentBy(w, name)
	local n = 0
	for _, e in ipairs(w.addonLog or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.whispers or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.chatPosts or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.invites or {}) do if e.from == name then n = n + 1 end end
	return n
end

-- a Wuber with one fix undone: the exact text must be in the file (a changed file fails the test loudly, not silently)
local function undo(file, find, repl)
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find(file, 1, true) then return text end
		text = text:gsub("\r\n", "\n") -- a CRLF checkout must still find the text
		local s, e = text:find(find, 1, true)
		if not s then error("the broken copy's text is not in " .. file .. ": " .. find) end
		hit = true
		return text:sub(1, s - 1) .. repl .. text:sub(e + 1)
	end
	return rewrite, function() return hit end
end

local function client(w, rewrite)
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	return c
end

-- an Auto check over the named screens: the saved result, and the client
local function autoRun(words, rewrite)
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w, rewrite)
	local L, W = c.ns.WuberLab, c.W
	c.env.IsInGuild = function() return true end
	-- the game's list of addons (the fake game has none): Wuber and the Lab are loaded, a third is switched off
	local ADDONS = { "Wuber", "WuberLab", "SomeOtherAddon" }
	c.env.C_AddOns = { GetNumAddOns = function() return #ADDONS end, GetAddOnInfo = function(i) return ADDONS[i] end,
		IsAddOnLoaded = function(n) return n ~= "SomeOtherAddon" end }
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	W.UI.Toggle(true)
	w:advance(2)
	local before, sent = dbText(c), sentBy(w, "Anita Lift")
	local started, why = L.AutoStart({ words = words })
	ok(started, "the Auto check started: " .. tostring(why))
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	return L.lastAuto or {}, c, w, { before = before, sent = sent }
end

local function rows(last, step)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		if r.steps and (","  .. r.steps .. ","):find("," .. step .. ",", 1, true) then out[#out + 1] = r.status .. " " .. r.kind .. ": " .. tostring(r.detail) end
	end
	return table.concat(out, " | ")
end
local function problems(last)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		local d = tostring(r.detail or "")
		if d:find("^error") or d:find("the check itself broke", 1, true) then out[#out + 1] = r.id .. " " .. r.kind .. ": " .. d:sub(1, 200) end
	end
	return table.concat(out, " | ")
end

---------------------------------------------------------------------------

test("lab auto7: on the current Wuber every step of the new screens passes, nothing is sent and WuberDB is put back", function()
	local last, c, w, was = autoRun(SCREENS)
	eq(last.reason, nil, "the Auto check ended by itself")
	eq(problems(last), "", "no check broke")
	if os.getenv("LAB7_SHOW") then
		for _, step in ipairs(STEPS) do print(step, rows(last, step)) end
		print("minutes", last.minutes, "done", last.done)
	end
	for _, step in ipairs(STEPS) do
		eq((last.steps or {})[step], "pass", step .. " passes: " .. rows(last, step))
	end
	eq(sentBy(w, "Anita Lift") - was.sent, 0, "messages, whispers, chat lines or invites sent")
	eq(dbText(c), was.before, "WuberDB after the Auto check")
	eq(#w.errors, 0, "Lua errors: " .. table.concat(w.errors, "; "))
	clean(w)
end)

-- the fix undone: the step says look
local BREAKS = {
	{ "a_driver_hits", "PR-97", "UI/Driver/Sheets.lua", "-- (job 2767) Enter confirms like the Block button\n\t\tonEnter = function()", "-- (job 2767) Enter confirms like the Block button\n\t\tonEnterGone = function()", "Enter in the block-reason box" },
	{ "a_settings_asks", "PR-79", "UI/Settings/Find.lua", "if #words < 2 then return words end", "do return words end", "question" },
	{ "a_settings_asks", "PR-78", "UI/Bug.lua", 'add("Other addons: " .. #others .. " loaded")', 'add("Other addons: unknown")', "other-addons" },
	{ "a_settings_asks", "PR-78", "UI/Bug.lua", 'add("Character: " .. characterLine())', 'add("Character: unknown")', "class and level" },
	{ "a_settings_asks", "PR-78", "UI/Bug.lua", "add(\"Changed settings:\")\n\tfor _, s in ipairs(settingsLines()) do add(s) end", 'add("Changed settings:")\n\tadd("  none")', "the changed setting" },
	{ "a_settings_asks", "PR-50", "FX/Emblem.lua", "E.Sweep()\n\t\tsyncSettings()\n\t\tsay(a == \"on\"", "E.Sweep()\n\t\tsay(a == \"on\"", "OFF" },
	{ "a_settings_asks", "PR-62", "UI/Window.lua", "top:SetHitRectInsets(inset, 0, 0, 0)", "top:SetHitRectInsets(0, 0, 0, 0)", "top Wuber frame" },
	{ "a_driver_hits", "PR-62", "UI/Window.lua", "top:SetHitRectInsets(inset, 0, 0, 0)", "top:SetHitRectInsets(0, 0, 0, 0)", "top Wuber frame" },
	{ "a_rider_checks", "PR-115", "UI/Moments.lua", "\t\tUI.SelectTab(\"Trips\")\n\t\t-- the tap asked for Trips", "\t\t-- the tap asked for Trips", "tab" },
	{ "a_rider_checks", "PR-116", "UI/Rider/Trips.lua", 'if type(t) == "table" and not t.unpaid then', 'if type(t) == "table" then', "trips" },
	{ "a_rider_checks", "PR-116", "Core/Stats.lua", "if trip.unpaid then return end", "", "rides" },
	{ "a_rider_checks", "PR-48", "UI/Map/Pins.lua", 'tag:SetPoint("TOP", pin, "BOTTOM", 0, -(12 + 3))', 'tag:SetPoint("TOP", pin, "BOTTOM", 0, -3)', "aura frame" },
	{ "a_pill_hit", "PR-45", "UI/Phone.lua", "if state then isl:EnableMouse(pillClickShows(rv)) end", "if state then isl:EnableMouse(true) end", "takes the mouse" },
}
for i, b in ipairs(BREAKS) do
	local screenId, step, file, find, repl, words = b[1], b[2], b[3], b[4], b[5], b[6]
	test(("lab auto7: %s says look on a Wuber with the fix undone (%s, %d)"):format(step, file, i), function()
		local rewrite, hit = undo(file, find, repl)
		local last, c, w = autoRun({ screenId }, rewrite)
		ok(hit(), "the broken copy was made (" .. file .. " was loaded)")
		eq(problems(last), "", "no check broke")
		eq((last.steps or {})[step], "look", step .. " looks on the broken copy: " .. rows(last, step))
		ok(rows(last, step):find(words, 1, true) ~= nil, step .. " says what is wrong (wanted '" .. words .. "'): " .. rows(last, step))
		clean(w)
	end)
end

---------------------------------------------------------------------------
-- PR-76: saved data survived a restart
---------------------------------------------------------------------------

local function labOf(c) return c.ns.WuberLab end

test("lab auto7: PR-76 the sum is kept at logout and a plain reload says pass", function()
	local w = newWorld()
	local r = client(w)
	w:advance(5)
	r.W.db.coach = not r.W.db.coach
	local r2 = w:reload(r)
	w:advance(5)
	local L2 = labOf(r2)
	local s = L2.db.savedSurvived
	ok(type(s) == "table", "the next load recorded a result")
	eq(s and s.status, "pass", "a restart with nothing changed: " .. tostring(s and s.detail))
	eq(L2.db.savedSum, nil, "the kept sum is used once")
	clean(w)
end)

test("lab auto7: PR-76 a changed key between logout and the next login says look and names the key", function()
	local w = newWorld()
	local r = client(w)
	w:advance(5)
	local saved = w:logout(r)
	ok(saved.WuberLab and saved.WuberLab.savedSum, "a sum was kept at PLAYER_LOGOUT")
	saved.Wuber.timeValue = (tonumber(saved.Wuber.timeValue) or 100000) + 1234
	saved.Wuber.labChangedKey = { deep = 1 }
	local r2 = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, saved = saved })
	settle(w)
	w:advance(5)
	local s = labOf(r2).db.savedSurvived
	eq(s and s.status, "look", "the changed data is a look: " .. tostring(s and s.detail))
	ok(s and s.detail:find("labChangedKey", 1, true) and s.detail:find("timeValue", 1, true), "it names the keys that differ: " .. tostring(s and s.detail))
	clean(w)
end)

test("lab auto7: PR-76 the result is in the last Auto check's steps and results, and again after the next Auto check", function()
	local w = newWorld()
	local r = client(w)
	w:advance(5)
	local L = labOf(r)
	L.db.autoCheck = { steps = {}, results = {}, counts = { pass = 0, look = 0, skip = 0, info = 0 } }
	L.SavedPut("pass", "saved data came back the same")
	eq(L.db.autoCheck.steps["PR-76"], "pass", "the step is in the saved Auto check")
	local row
	for _, x in ipairs(L.db.autoCheck.results) do if x.steps == "PR-76" then row = x end end
	ok(row and row.status == "pass" and row.kind == "saved data survived a restart", "a result row carries PR-76")
	-- an Auto check replaces autoCheck at its end: the result is put in again
	clean(w)
	-- a whole Auto check: the result kept from the load is written into the new autoCheck at its end
	local w2 = newWorld()
	w2:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c2 = client(w2)
	local L2 = labOf(c2)
	L2.db.savedSurvived = { status = "look", detail = "differs in: coach" }
	c2.env.Screenshot = function() c2.env.C_Timer.After(0.2, function() c2:fire("SCREENSHOT_SUCCEEDED") end) end
	c2.W.UI.Toggle(true)
	w2:advance(2)
	ok(L2.AutoStart({ words = { "a_pill_hit" } }), "the Auto check started")
	for _ = 1, 3000 do
		if not L2.AutoRunning() then break end
		w2:advance(1)
	end
	eq(L2.lastAuto and L2.lastAuto.steps and L2.lastAuto.steps["PR-76"], "look", "the saved-data result is in the new Auto check's steps")
	clean(w2)
end)

test("lab auto7: PR-76 no kept sum, or another Wuber version, is not judged", function()
	local w = newWorld()
	local r = client(w)
	w:advance(2)
	local L = labOf(r)
	local st, why = L.SavedCompare(nil, r.env.WuberDB, "2.4.2")
	eq(st, nil, "no sum: no verdict")
	ok(why:find("no checksum", 1, true), why)
	local sum = L.SavedSum(r.env.WuberDB)
	st = L.SavedCompare({ sum = sum, wuber = "2.4.1" }, r.env.WuberDB, "2.4.2")
	eq(st, nil, "another version: no verdict")
	st = L.SavedCompare({ sum = sum, wuber = "2.4.2" }, r.env.WuberDB, "2.4.2")
	eq(st, "pass", "the same data and version")
	r.env.WuberDB.zzz = 1
	st = L.SavedCompare({ sum = sum, wuber = "2.4.2" }, r.env.WuberDB, "2.4.2")
	eq(st, "look", "one new key")
	clean(w)
end)
