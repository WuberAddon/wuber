-- #234 The forbidden list learned the entries the API sweep of 26 Nov 2026 found in the client's own documentation
-- (SecureOnly / IsProtectedFunction): C_CombatLogSecure.*, C_PingSecure.*, GetForbiddenObjectTable,
-- C_TooltipComparison.CompareItem, ReloadUI. The fake client raises ADDON_ACTION_FORBIDDEN on each (one test per
-- entry kind, the whole family walked), and the protected widget methods are a RULE of the fake, not a ban:
-- a violation only on a protected frame in combat (tests/fixtures/protected-methods.lua).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function walk(env, path)
	local v = env
	for _, k in ipairs(path) do
		if type(v) ~= "table" then return nil end
		v = v[k]
	end
	return v
end

local function entry(name)
	for _, f in ipairs(H.FORBIDDEN) do if f.name == name then return f end end
end

test("#234 forbidden list: every new client-documented name is on the list with its evidence", function()
	for _, n in ipairs({ "GetForbiddenObjectTable", "C_TooltipComparison.CompareItem", "ReloadUI",
		"C_CombatLogSecure.GetCurrentEventInfo", "C_CombatLogSecure.AddEventFilter", "C_PingSecure.SendUnitPing", "C_PingSecure.SendPlayerSpellPing" }) do
		local f = entry(n)
		ok(f, n .. " is on tools/forbidden.lua")
		ok(f and f.why and #f.why > 20, n .. " says why")
	end
	local ping, clog = 0, 0
	for _, f in ipairs(H.FORBIDDEN) do
		if f.name:find("^C_PingSecure%.") then ping = ping + 1 end
		if f.name:find("^C_CombatLogSecure%.") then clog = clog + 1 end
	end
	ok(ping >= 20, "the ping family: " .. ping)
	ok(clog >= 12, "the combat log family: " .. clog)
end)

test("#234 forbidden list: the fake client raises ADDON_ACTION_FORBIDDEN on the whole C_CombatLogSecure and C_PingSecure families", function()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber" } })
	local seen = 0
	local f = c.env.CreateFrame("Frame")
	f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	f:SetScript("OnEvent", function() seen = seen + 1 end)
	local tried = 0
	for _, e in ipairs(H.FORBIDDEN) do
		if e.name:find("^C_PingSecure%.") or e.name:find("^C_CombatLogSecure%.") then
			local fn = walk(c.env, e.path)
			ok(type(fn) == "function", e.name .. " exists in the fake (so a call can raise)")
			local good, err = pcall(fn)
			ok(not good and tostring(err):find("ADDON_ACTION_FORBIDDEN", 1, true), e.name .. " raises: " .. tostring(err))
			tried = tried + 1
		end
	end
	ok(tried >= 32, "tried the families: " .. tried)
	eq(seen, tried, "ADDON_ACTION_FORBIDDEN fired for each")
	eq(#w.violations, tried, "each is a violation (a test that leaves one fails)")
	w.violations = {}
	T.clean(w)
end)

test("#234 forbidden list: GetForbiddenObjectTable and C_TooltipComparison.CompareItem raise", function()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber" } })
	for _, path in ipairs({ { "GetForbiddenObjectTable" }, { "C_TooltipComparison", "CompareItem" } }) do
		local fn = walk(c.env, path)
		ok(type(fn) == "function", table.concat(path, ".") .. " exists in the fake")
		local good, err = pcall(fn)
		ok(not good and tostring(err):find("ADDON_ACTION_FORBIDDEN", 1, true), table.concat(path, ".") .. " raises: " .. tostring(err))
	end
	eq(#w.violations, 2, "two violations")
	w.violations = {}
	T.clean(w)
end)

test("#234 forbidden list: ReloadUI is banned in the sources and blocked (recorded, not raised) in the fake", function()
	local f = entry("ReloadUI")
	ok(f, "ReloadUI is on tools/forbidden.lua")
	eq(f and f.fake, false, "check.lua bans the name; the fake keeps its own blocked-and-recorded answer")
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber" } })
	c.env.ReloadUI()
	w:advance(1)
	eq(#(c.reloadForbidden or {}), 1, "the call is recorded")
	eq(w:clientOf("Ana Smith"), c, "nothing reloaded")
	w.violations = {}
	T.clean(w)
end)

-- the rule of the fake, not a ban
local function secureButton(c)
	local b = c.env.CreateFrame("Button", "SecProbe234", c.env.UIParent, "SecureActionButtonTemplate")
	b:SetSize(40, 40) b:SetPoint("CENTER")
	return b
end

test("#234 protected methods: a violation on a protected frame in combat, none out of combat or on a plain frame", function()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber" } })
	local b = secureButton(c)
	local plain = c.env.CreateFrame("Frame", "PlainProbe234", c.env.UIParent)
	local calls = { function(f) f:SetFrameLevel(5) end, function(f) f:SetFrameStrata("HIGH") end, function(f) f:EnableKeyboard(false) end,
		function(f) f:SetToplevel(true) end, function(f) f:Raise() end, function(f) f:SetID(3) end }
	-- out of combat: free
	for _, fn in ipairs(calls) do fn(b) end
	eq(#w.violations, 0, "out of combat: free: " .. table.concat(w.violations, "; "))
	w:enterCombat(c)
	for _, fn in ipairs(calls) do fn(plain) end
	eq(#w.violations, 0, "a plain frame in combat: free: " .. table.concat(w.violations, "; "))
	for _, fn in ipairs(calls) do fn(b) end
	eq(#w.violations, #calls, "a protected frame in combat: one violation each: " .. table.concat(w.violations, "; "))
	ok(w.violations[1]:find("protected frame", 1, true), w.violations[1])
	w.violations = {}
	w:leaveCombat(c)
	T.clean(w)
end)

test("#234 protected methods: the cooldown family on a protected cooldown in combat is a violation", function()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber" } })
	-- a cooldown holding a secure button is protected as every frame that holds one is
	local cd = c.env.CreateFrame("Cooldown", nil, c.env.UIParent)
	c.env.CreateFrame("Button", "SecCd234", cd, "SecureActionButtonTemplate")
	ok(type(cd.SetCooldown) == "function", "the fake has a Cooldown")
	cd:SetCooldown(1, 5) cd:Clear()
	eq(#w.violations, 0, "out of combat: free")
	w:enterCombat(c)
	cd:SetCooldown(1, 5)
	cd:Clear()
	eq(#w.violations, 2, "in combat: SetCooldown and Clear: " .. table.concat(w.violations, "; "))
	w.violations = {}
	w:leaveCombat(c)
	T.clean(w)
end)
