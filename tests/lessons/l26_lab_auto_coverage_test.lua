-- Lesson: every screen the layout check (tools/layout-check.lua) knows must have a row in the Lab's Auto check
-- (WuberLab: L.AutoScreens() = L.PHOTO_SCREENS + L.AUTO_SCREENS), or be named in L.AUTO_MANUAL with the reason it stays a
-- hand step. The layout check knows (1) the Lab photo tour's screens, (2) the extra screens tests/layout/extra_screens.lua
-- adds at tour time (X.install: f3_e, dec_q, d4_h, d4_c, sheet_states, f3_j, dec_n, dec_r, rem, d4_d _screens.lua), and
-- (3) the late-font scenes of tests/layout/run.lua (Run.SCENES). The two lists are kept in step by these tests; the table
-- is in lab/AUTO-COVERAGE.md. Skipped with one passing note when the Lab isn't there.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("lab auto coverage: Wuber Lab's AutoCheck.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

-- the layout check skips these two on purpose (tests/layout/run.lua GONE_SHOTS: Settings rows the 2.4 diet removed)
local GONE_SHOTS = { settings_summoner = true, settings_bug = true }

local function views(s)
	if s.only == "unfolded" then return "unfolded" end
	return s.unfold and "folded+unfolded" or "folded"
end

-- WuberDB as text, keys sorted: the same text means the same saved file
local function serialize(v, out)
	local ty = type(v)
	if ty == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif ty == "number" or ty == "boolean" or ty == "nil" then
		out[#out + 1] = tostring(v)
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
-- everything this window sent into the world so far (addon messages, whispers, chat lines, invites)
local function sentBy(w, name)
	local n = 0
	for _, e in ipairs(w.addonLog or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.whispers or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.chatPosts or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.invites or {}) do if e.from == name then n = n + 1 end end
	return n
end

local function client(w, name)
	local c = w:addClient(name or "Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	return c
end

-- what the layout check knows, worked out once: { ids = { id, ... } in the layout check's order, row = { id -> its screen }, extras = { id, ... } }
local KNOWN
local function layoutKnown()
	if KNOWN then return KNOWN end
	local keep = { H.textMetrics, H.TEXT_PIXELS, H.ALPHA_HOLD }
	local root = H.root
	local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
	local Run = assert(loadfile(root .. "/tests/layout/run.lua"))(H, E, root)
	local ids, seen = {}, {}
	local function add(id)
		if not seen[id] and not GONE_SHOTS[id] then seen[id] = true ids[#ids + 1] = id end
	end
	for _, s in ipairs(Run.shotList()) do add(s.id) end -- the tour's screens and Run.SCENES
	-- the extra screens, installed on a tour client as the layout check does at tour time
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w)
	local L, W = c.ns.WuberLab, c.W
	local X = assert(loadfile(root .. "/tests/layout/extra_screens.lua"))()
	local okI, added = pcall(X.install, L, W)
	local extras = {}
	if okI and type(added) == "table" then
		for _, id in ipairs(added) do
			if not GONE_SHOTS[id] then
				add(id)
				extras[#extras + 1] = id
			end
		end
	end
	local row = {}
	for _, s in ipairs(L.PHOTO_SCREENS) do row[s.id] = s end
	local scenes = {}
	for _, s in ipairs(Run.SCENES or {}) do scenes[s.id] = true end
	H.textMetrics, H.TEXT_PIXELS, H.ALPHA_HOLD = keep[1], keep[2], keep[3] -- (the layout run turns the flat measure on: not for the next test)
	KNOWN = { ids = ids, row = row, extras = extras, scenes = scenes, installed = okI, err = not okI and tostring(added) or nil }
	return KNOWN
end

-- the Lab's Auto check list on a plain client: { id -> screen }, in order
local function autoRows()
	local w = newWorld()
	local c = client(w)
	local L = c.ns.WuberLab
	local rows, order = {}, {}
	for _, s in ipairs(L.AutoScreens()) do
		rows[s.id] = s
		order[#order + 1] = s.id
	end
	return rows, order, L.AUTO_MANUAL or {}
end

local function reasonOf(manual, id)
	local r = manual[id]
	return type(r) == "string" and r:gsub("%s", "") ~= "" and r or nil
end

---------------------------------------------------------------------------

test("lab auto coverage: every screen the layout check knows has an Auto check row, or a reason in L.AUTO_MANUAL", function()
	local K = layoutKnown()
	ok(K.installed, "tests/layout/extra_screens.lua X.install ran: " .. tostring(K.err))
	eq(#K.extras >= 70, true, "the layout check's extra screens: " .. #K.extras)
	local rows, _, manual = autoRows()
	local missing = {}
	for _, id in ipairs(K.ids) do
		if not rows[id] and not reasonOf(manual, id) then missing[#missing + 1] = id end
	end
	eq(#missing, 0, #missing .. " layout-check screens have no Auto check row and no L.AUTO_MANUAL reason: " .. list(missing, ", "))
	-- the manual list holds only layout screens that really have no row, each with a reason
	local bad = {}
	local known = {}
	for _, id in ipairs(K.ids) do known[id] = true end
	for id, why in pairs(manual) do
		if not known[id] then bad[#bad + 1] = id .. " (not a layout-check screen)"
		elseif rows[id] then bad[#bad + 1] = id .. " (has a row: take it off L.AUTO_MANUAL)"
		elseif not reasonOf(manual, id) then bad[#bad + 1] = id .. " (no reason)" end
	end
	table.sort(bad)
	eq(#bad, 0, "L.AUTO_MANUAL: " .. list(bad, ", "))
	-- only the late-font scenes can stay by hand: a screen of the tour or an extra one runs in the real game
	for id in pairs(manual) do ok(K.scenes[id], id .. " is in L.AUTO_MANUAL but is not a Run.SCENES scene") end
end)

test("lab auto coverage: each ported row has the layout screen's side, title and views, in the layout check's order, pay_part last", function()
	local K = layoutKnown()
	local rows, order = autoRows()
	local bad = {}
	for _, id in ipairs(K.extras) do
		local lay, row = K.row[id], rows[id]
		if not row then bad[#bad + 1] = id .. ": no Auto check row"
		elseif not lay then bad[#bad + 1] = id .. ": the layout check has no screen of that id on the tour client"
		else
			if views(row) ~= views(lay) then bad[#bad + 1] = id .. ": views " .. views(row) .. ", layout check " .. views(lay) end
			if row.side ~= lay.side then bad[#bad + 1] = id .. ": side " .. tostring(row.side) .. ", layout check " .. tostring(lay.side) end
			if row.title ~= lay.title then bad[#bad + 1] = id .. ": title differs" end
			if row.auto ~= true then bad[#bad + 1] = id .. ": not marked auto (s.auto = true)" end
			if type(row.run) ~= "function" then bad[#bad + 1] = id .. ": no run" end
		end
	end
	eq(#bad, 0, #bad .. " ported rows differ: " .. list(bad, " | "))
	-- the order: the layout check's install order, with pay_part (it leaves a ride under way) moved to the end
	local want = {}
	for _, id in ipairs(K.extras) do if id ~= "pay_part" then want[#want + 1] = id end end
	want[#want + 1] = "pay_part"
	local isExtra, got = {}, {}
	for _, id in ipairs(K.extras) do isExtra[id] = true end
	for _, id in ipairs(order) do if isExtra[id] then got[#got + 1] = id end end
	eq(list(got, ","), list(want, ","), "the ported rows' order")
end)

-- a real Auto check over the ported rows, in the fake game, at one window size
test("lab auto coverage: a real Auto check over the ported rows ends, shoots every one in its views, with no Lua error and no error string", function()
	local K = layoutKnown()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w)
	local L, W = c.ns.WuberLab, c.W
	local rows = {}
	for _, s in ipairs(L.AutoScreens()) do rows[s.id] = s end
	local ids = {}
	for _, id in ipairs(K.extras) do if rows[id] then ids[#ids + 1] = id end end
	ok(#ids > 0, "no ported rows to run")
	if #ids == 0 then return end
	-- a Warlock in a guild (the New title card's Tell the guild pill shows only then), and the game's Screenshot() as lab_photo does
	c.env.IsInGuild = function() return true end
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	-- every ported row's need must say yes here: a typo'd module name must not leave a row out for good
	local notMet = {}
	for _, id in ipairs(ids) do
		local s = rows[id]
		if type(s.need) == "function" then
			local okN, r = pcall(s.need, W)
			if not okN or r ~= true then notMet[#notMet + 1] = id .. ": " .. tostring(r) end
		end
	end
	eq(#notMet, 0, #notMet .. " ported rows whose need is not met in the fake game: " .. list(notMet, " | "))
	W.UI.Toggle(true)
	w:advance(2)
	local before, sent, drivers, ride, db = dbText(c), sentBy(w, "Anita Lift"), W.drivers, W.ride, W.db
	local sendTo, invite, toast, drivePlan = W.SendTo, W.Invite, W.UI.Toast, W.Drive.Plan
	local started, why = L.AutoStart({ words = ids })
	ok(started, "the Auto check started: " .. tostring(why))
	if not started then return end
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	local last = L.lastAuto
	ok(type(last) == "table", "the Auto check saved its result")
	if type(last) ~= "table" then return end
	eq(last.reason, nil, "the Auto check ended by itself (not stopped)")
	local shot = {}
	for _, s in ipairs(last.shots or {}) do shot[s.id .. "|" .. s.view] = true end
	local skipped, problems = {}, {}
	for _, r in ipairs(last.results or {}) do
		local d = tostring(r.detail or "")
		if r.kind == "screen" and r.status == "skip" then skipped[r.id .. "|" .. r.view] = d end
		if d:find("^error") or d:find("the check itself broke", 1, true) then problems[#problems + 1] = r.id .. " " .. r.view .. " " .. r.kind .. ": " .. d:sub(1, 160) end
	end
	local want = {}
	for _, id in ipairs(ids) do want[id] = true end
	for _, id in ipairs(ids) do
		local s, lay = rows[id], K.row[id]
		for _, view in ipairs({ "folded", "unfolded" }) do
			local planned = (view == "folded" and s.only ~= "unfolded") or (view == "unfolded" and (s.unfold or s.only == "unfolded"))
			local key = id .. "|" .. view
			if planned and not shot[key] then
				-- a row may skip only for a reason it declares (s.declares: a list of the words that reason says)
				local d = skipped[key]
				if not d then
					local okN, needWhy = false, nil
					if type(s.need) == "function" then okN, needWhy = pcall(s.need, W) end
					d = okN and type(needWhy) == "string" and needWhy or nil
				end
				local declared = false
				for _, words in ipairs(type(s.declares) == "table" and s.declares or {}) do
					if d and words ~= "" and d:find(words, 1, true) then declared = true end
				end
				if not declared then
					problems[#problems + 1] = id .. " " .. view .. ": no shot" .. (d and (" (skipped: " .. d:sub(1, 160) .. ")") or " and no skip")
				end
			end
		end
	end
	for _, s in ipairs(last.shots or {}) do
		if not want[s.id] then problems[#problems + 1] = s.id .. " " .. s.view .. ": shot but not asked for (a word matched more than the ported ids)" end
	end
	eq(#problems, 0, #problems .. " problems: " .. list(problems, " | "))
	-- nothing sent, nothing saved, every stub put back
	eq(sentBy(w, "Anita Lift") - sent, 0, "messages, whispers, chat lines or invites sent during the Auto check")
	eq(dbText(c), before, "WuberDB after the Auto check")
	ok(W.drivers == drivers and W.ride == ride and W.db == db, "W.drivers, W.ride and W.db are the same tables as before")
	ok(W.SendTo == sendTo and W.Invite == invite and W.UI.Toast == toast and W.Drive.Plan == drivePlan, "the stubbed functions are back")
	clean(w)
end)
