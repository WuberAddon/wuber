-- (T243 round 2) the Lab's Auto checks KEYS-SETTINGS (lab/WuberLab/AutoKeys.lua) and BACK-REAL (AutoSteps7.lua) after the first run in the game:
--  1. the check read a secret boolean (IsEventRegistered) with ==: a Lua error in the game ("attempt to compare a secret boolean value");
--     now every game value goes through plain()/issecretvalue, and a frame that hides its answer gives a skip, never a false look;
--  2. the Drive tab's cog opens the "driving" page (the Key for the big button row): a visible Wuber frame that takes keys there while no key
--     is being set is a look at once, with the frame named (the fake game does not turn keys on by itself: the broken copy does it, as the client does);
--  3. Drive > Your crew's back arrow check ran into the Settings chain before it (which clicked the crew page's arrow away): it reaches the arrow.
-- Wuber Lab is never shipped.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoKeys.lua") then
	test("lab keys drive: AutoKeys.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

local function world(rewrite)
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	c.env.IsInGuild = function() return true end
	c.env.C_AddOns = { GetNumAddOns = function() return 2 end, GetAddOnInfo = function(i) return ({ "Wuber", "WuberLab" })[i] end,
		IsAddOnLoaded = function() return true end }
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	c.env.GetCurrentKeyBoardFocus = function()
		for _, f in ipairs(c.frames) do
			local okT, ot = pcall(f.GetObjectType, f)
			if okT and ot == "EditBox" and f:HasFocus() and f:IsVisible() then return f end
		end
		return nil
	end
	c.W.UI.Toggle(true)
	w:advance(2)
	return w, c
end

local function autoRun(words, rewrite, before)
	local w, c = world(rewrite)
	local L = c.ns.WuberLab
	if before then before(c) end
	local started, why = L.AutoStart({ words = words })
	ok(started, "the Auto check started: " .. tostring(why))
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	return L.lastAuto or {}, c, w
end

local function rows(last, step)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		if r.steps and ("," .. (type(r.steps) == "table" and table.concat(r.steps, ",") or r.steps) .. ","):find("," .. step .. ",", 1, true) then
			out[#out + 1] = r.status .. " " .. tostring(r.detail)
		end
	end
	return out
end

-- the broken Wuber: the client turns keys on for a frame when an OnKeyDown script is set on it (the cap over the key row)
local function keyCapBroken()
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find("UI/Settings/Rows.lua", 1, true) then return text end
		-- (after every line that sets the cover up, so a fixed Rows.lua is broken the same way: keys on, propagate off, no OnShow reset)
		local find = 'safeScript(clear, "OnClick", function()'
		local s, e = text:find(find, 1, true)
		if not s then error("the broken copy's text is not in Rows.lua") end
		hit = true
		return text:sub(1, s - 1) .. 'cap:EnableKeyboard(true) cap:SetPropagateKeyboardInput(false) cap:SetScript("OnShow", nil)\n\t' .. text:sub(s)
	end
	return rewrite, function() return hit end
end

test("lab keys drive: a frame that hides whether it listens (secret answer) gives a skip, not a Lua error or a false look", function()
	local last, c, w
	last, c, w = autoRun({ "a_keys_settings" }, nil, function(cl)
		cl.env.issecretvalue = function(v) return v == SECRET end
		local mt = getmetatable(cl.frames[1])
		local was = mt.__index
		mt.__index = function(t, k)
			if k == "IsEventRegistered" then return function(self, ev) if ev == "GLOBAL_MOUSE_DOWN" then return SECRET end return was(self, ev) end end
			return was(t, k)
		end
		cl.restoreReg = function() mt.__index = was end
	end)
	c.restoreReg()
	local r = rows(last, "KEYS-SETTINGS")
	eq(#r, 2, "one row per origin: " .. table.concat(r, " | "))
	for _, line in ipairs(r) do
		ok(not line:find("^look"), "no false look: " .. line)
		ok(not line:find("broke", 1, true), "the check did not break: " .. line)
	end
	clean(w)
end)

test("lab keys drive: a visible Wuber frame taking keys on the Drive cog's page is a look, with the frame named", function()
	local rewrite, hit = keyCapBroken()
	local last, c, w = autoRun({ "a_keys_settings" }, rewrite)
	ok(hit(), "the broken copy was made")
	local r = rows(last, "KEYS-SETTINGS")
	eq(#r, 2, "one row per origin: " .. table.concat(r, " | "))
	local driveRow, rideRow
	for _, line in ipairs(r) do
		if line:find("driving", 1, true) then driveRow = line else rideRow = line end
	end
	ok(driveRow and driveRow:find("^look") and driveRow:find("takes keys", 1, true), "the Drive page is flagged: " .. table.concat(r, " | "))
	ok(driveRow and driveRow:find("unnamed Frame inside", 1, true), "the frame is named: " .. tostring(driveRow))
	eq((last.steps or {})["KEYS-SETTINGS"], "look", "the step looks")
	clean(w)
end)

-- guard: the base's fake game has no client keyboard rule, so the Drive page shows no key-taking frame there; it is the Lab check's pass case
test("lab keys drive: the current Wuber's Drive cog page holds no keys (pass from Ride and from Drive)", function()
	local last, c, w = autoRun({ "a_keys_settings" })
	local r = rows(last, "KEYS-SETTINGS")
	eq(#r, 2, "one row per origin: " .. table.concat(r, " | "))
	for _, line in ipairs(r) do ok(line:find("^pass"), "passes: " .. line) end
	clean(w)
end)

test("lab keys drive: BACK-REAL reaches Drive > Your crew's back arrow right after the Settings from the Drive cog", function()
	local w, c = world()
	local L, W = c.ns.WuberLab, c.W
	local function scr(id) for _, s in ipairs(L.AUTO_SCREENS) do if s.id == id then return s end end end
	local drive, crew, last = scr("a_backreal_drive"), scr("a_backreal_crew"), scr("a_backreal_last")
	ok(drive and crew and last, "the three screens are there")
	eq(drive.run(W), true, "the Drive cog's page opens")
	drive.verify(W) -- starts the chain that clicks the arrow until Settings is shut
	eq(crew.run(W), true, "Your crew opens while that chain has a read to come")
	w:advance(1)
	crew.verify(W) -- its own chain
	w:advance(3)
	local out = last.verify(W)
	local crewRow
	for _, r in ipairs(out) do if tostring(r.name):find("Your crew", 1, true) then crewRow = r end end
	ok(crewRow, "a row for Your crew")
	eq(crewRow and crewRow.status, "pass", "Your crew passes: " .. tostring(crewRow and crewRow.detail))
	clean(w)
end)
