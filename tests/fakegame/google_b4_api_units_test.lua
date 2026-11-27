-- Conformance test for tests/fixtures/client/api/units.lua (Batch 4 Part 5, lane e2).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local LEDGER_PATH = "tests/fixtures/client/api/units.lua"
local VALID_EVIDENCE = {
	["one-real-case"] = true,
	docs = true,
	borrowed = true,
	guess = true,
}

local function resolveEnv(env, name)
	local ns, fn = name:match("^([^.]+)%.(.+)$")
	if ns then
		local t = env[ns]
		return type(t) == "table" and t[fn] or nil
	end
	return env[name]
end

test("b4 api units: ledger rows are well formed, honest, and have no duplicates", function()
	local rows = assert(loadfile(LEDGER_PATH))()
	eq(type(rows), "table", "units ledger returns a table")
	ok(#rows >= 35, "expected at least 35 units API rows, got " .. #rows)

	local seen = {}
	for i, r in ipairs(rows) do
		local ctx = "row " .. i .. " (" .. tostring(r.name) .. ")"
		eq(type(r.name), "string", ctx .. ": name is string")
		ok(r.name ~= "", ctx .. ": name non-empty")
		ok(not seen[r.name], ctx .. ": duplicate name")
		seen[r.name] = true

		eq(type(r.calls), "number", ctx .. ": calls is number")
		ok(r.calls >= 1, ctx .. ": calls >= 1")
		eq(type(r.first), "string", ctx .. ": first is string")
		ok(r.first:match("^Wuber/.+:%d+$") ~= nil, ctx .. ": first has path:line")
		eq(type(r.fake), "string", ctx .. ": fake is string")
		ok(r.fake ~= "", ctx .. ": fake non-empty")

		ok(VALID_EVIDENCE[r.evidence], ctx .. ": valid evidence word (never measured)")
		eq(type(r.source), "string", ctx .. ": source is string")
		ok(r.source ~= "", ctx .. ": source non-empty")

		if r.evidence == "one-real-case" then
			ok(r.build ~= nil and tostring(r.build) ~= "", ctx .. ": one-real-case has build")
		else
			local hasCheck = (type(r.game) == "string" and r.game ~= "") or (type(r.offline) == "string" and r.offline ~= "")
			ok(hasCheck, ctx .. ": guess/docs/borrowed row has game or offline")
		end
	end
end)

test("b4 api units: every row matches logged-in fake game presence and return shape", function()
	local rows = assert(loadfile(LEDGER_PATH))()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", level = 60, addons = {}, allowMissing = true })
	local env = c.env

	local shapes = {
		AcceptGroup = function(fn) eq(fn(), nil, "AcceptGroup returns nil") end,
		["C_PartyInfo.InviteUnit"] = function(fn) eq(type(fn), "function", "C_PartyInfo.InviteUnit is function") end,
		["C_PartyInfo.LeaveParty"] = function(fn) eq(fn(), nil, "C_PartyInfo.LeaveParty returns nil") end,
		["C_PartyInfo.PromoteToLeader"] = function(fn) eq(fn("player"), nil, "C_PartyInfo.PromoteToLeader returns nil") end,
		["C_Spell.GetSpellCooldown"] = function(fn)
			local t = fn(698)
			eq(type(t), "table", "C_Spell.GetSpellCooldown returns table")
			eq(type(t.startTime), "number", "cooldown startTime is number")
			eq(type(t.duration), "number", "cooldown duration is number")
			eq(type(t.isEnabled), "boolean", "cooldown isEnabled is boolean")
			eq(fn(999999), nil, "unknown spell cooldown returns nil")
		end,
		["C_Spell.GetSpellInfo"] = function(fn)
			local t = fn(698)
			eq(type(t), "table", "C_Spell.GetSpellInfo(698) returns table")
			eq(type(t.name), "string", "spellInfo.name is string")
			eq(t.spellID, 698, "spellInfo.spellID is 698")
		end,
		["C_Spell.GetSpellName"] = function(fn)
			eq(type(fn(698)), "string", "C_Spell.GetSpellName(698) returns string")
			eq(fn(999999), nil, "unknown spell name returns nil")
		end,
		CheckInteractDistance = function(fn) eq(type(fn("player")), "boolean", "CheckInteractDistance returns boolean") end,
		GetNormalizedRealmName = function(fn) eq(type(fn()), "string", "GetNormalizedRealmName returns string") end,
		GetNumGroupMembers = function(fn) eq(type(fn()), "number", "GetNumGroupMembers returns number") end,
		GetNumSubgroupMembers = function(fn) eq(type(fn()), "number", "GetNumSubgroupMembers returns number") end,
		GetRaidRosterInfo = function(fn) eq(fn(1), nil, "GetRaidRosterInfo(1) returns nil solo") end,
		GetRealmName = function(fn) eq(type(fn()), "string", "GetRealmName returns string") end,
		InCombatLockdown = function(fn) eq(type(fn()), "boolean", "InCombatLockdown returns boolean") end,
		InviteUnit = function(fn) eq(type(fn), "function", "InviteUnit is function") end,
		IsInGroup = function(fn) eq(type(fn()), "boolean", "IsInGroup returns boolean") end,
		IsInRaid = function(fn) eq(type(fn()), "boolean", "IsInRaid returns boolean") end,
		IsPlayerSpell = function(fn) eq(type(fn(686)), "boolean", "IsPlayerSpell returns boolean") end,
		IsSpellKnown = function(fn) eq(type(fn(686)), "boolean", "IsSpellKnown returns boolean") end,
		LeaveParty = function(fn) eq(fn(), nil, "LeaveParty returns nil") end,
		PromoteToLeader = function(fn) eq(fn("player"), nil, "PromoteToLeader returns nil") end,
		UnitAffectingCombat = function(fn) eq(type(fn("player")), "boolean", "UnitAffectingCombat returns boolean") end,
		UnitCanAttack = function(fn) eq(type(fn("player", "target")), "boolean", "UnitCanAttack returns boolean") end,
		UnitCastingInfo = function(fn) eq(fn("player"), nil, "UnitCastingInfo returns nil when idle") end,
		UnitChannelInfo = function(fn) eq(fn("player"), nil, "UnitChannelInfo returns nil when idle") end,
		UnitClass = function(fn)
			local loc, tok, id = fn("player")
			eq(type(loc), "string", "UnitClass localizedName is string")
			eq(type(tok), "string", "UnitClass token is string")
			eq(type(id), "number", "UnitClass id is number")
		end,
		UnitExists = function(fn)
			eq(fn("player"), true, "UnitExists('player') is true")
			eq(fn("target"), false, "UnitExists('target') is false")
		end,
		UnitFactionGroup = function(fn)
			local en, loc = fn("player")
			eq(type(en), "string", "UnitFactionGroup english is string")
			eq(type(loc), "string", "UnitFactionGroup localized is string")
		end,
		UnitFullName = function(fn)
			local first, sur = fn("player")
			eq(first, "Anita", "UnitFullName first")
			eq(sur, "Lift", "UnitFullName surname")
		end,
		UnitGUID = function(fn)
			local g = fn("player")
			eq(type(g), "string", "UnitGUID returns string")
			ok(g:find("^Player%-1%-") ~= nil, "UnitGUID starts with Player-1-")
		end,
		UnitIsConnected = function(fn) eq(type(fn("player")), "boolean", "UnitIsConnected returns boolean") end,
		UnitIsEnemy = function(fn) eq(type(fn("player", "target")), "boolean", "UnitIsEnemy returns boolean") end,
		UnitIsGroupLeader = function(fn) eq(type(fn("player")), "boolean", "UnitIsGroupLeader returns boolean") end,
		UnitIsPlayer = function(fn) eq(type(fn("player")), "boolean", "UnitIsPlayer returns boolean") end,
		UnitIsUnit = function(fn) eq(fn("player", "player"), true, "UnitIsUnit('player','player') is true") end,
		UnitIsVisible = function(fn) eq(type(fn("player")), "boolean", "UnitIsVisible returns boolean") end,
		UnitLevel = function(fn) eq(fn("player"), 60, "UnitLevel returns integer level") end,
		UnitName = function(fn)
			local first, sur = fn("player")
			eq(first, "Anita", "UnitName first")
			eq(sur, "Lift", "UnitName surname")
		end,
		UnitOnTaxi = function(fn) eq(type(fn("player")), "boolean", "UnitOnTaxi returns boolean") end,
	}

	for _, r in ipairs(rows) do
		local val = resolveEnv(env, r.name)
		if r.fake:find("^not modelled: returns nil") then
			eq(val, nil, r.name .. " is absent (nil) in c.env")
		else
			eq(type(val), "function", r.name .. " exists as function in c.env")
			local check = shapes[r.name]
			ok(type(check) == "function", r.name .. " has a shape check")
			check(val)
		end
	end

	T.clean(w)
end)
