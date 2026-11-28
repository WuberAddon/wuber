-- Tests for lab/WuberLab/ApiFacts3.lua:
--   1. Every `evidence = "guess"` row in tests/fixtures/client/api/{units,world}.lua has a check in ApiFacts3.lua.
--   2. Each check runs in the fake game beside the Lab without error, writes its fact, and sends nothing.
--   3. Combat guard blocks RunApiFacts3() when InCombatLockdown() is true.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
local API_FACTS3 = LAB_DIR .. "/ApiFacts3.lua"
if not H.exists(API_FACTS3) then
	test("b5 api facts 3: ApiFacts3.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function guessRows()
	local byName, ordered = {}, {}
	for _, fname in ipairs({ "units.lua", "world.lua" }) do
		local path = H.root .. "/tests/fixtures/client/api/" .. fname
		if H.exists(path) then
			for _, row in ipairs(dofile(path)) do
				if row.evidence == "guess" and row.name then
					local key = fname .. "::" .. row.name
					if not byName[key] then
						byName[key] = true
						ordered[#ordered + 1] = { file = fname, name = row.name }
					end
				end
			end
		end
	end
	return byName, ordered
end

local function loadApiFacts3(w)
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" } })
	settle(w)
	local L = c.ns.WuberLab
	local chunk = assert(loadfile(API_FACTS3))
	setfenv(chunk, c.env)
	chunk("WuberLab", L)
	return c, L
end

test("b5 api facts 3: covers all 53 guess rows in units.lua and world.lua", function()
	local w = newWorld({ clubs = true })
	local _, L = loadApiFacts3(w)
	local G = L.GameFacts
	ok(type(G) == "table" and type(G.API_CHECKS3) == "table", "G.API_CHECKS3 exists")

	local want, ordered = guessRows()
	local have = {}
	for _, check in ipairs(G.API_CHECKS3) do
		local key = tostring(check.source) .. "::" .. tostring(check.name)
		ok(not have[key], "no duplicate check for " .. key)
		have[key] = true
		ok(want[key], "check matches a guess row: " .. key)
	end
	for _, row in ipairs(ordered) do
		local key = row.file .. "::" .. row.name
		ok(have[key], "guess row has check in ApiFacts3.lua: " .. key)
	end
	eq(#G.API_CHECKS3, #ordered, "exact 1-to-1 count (53 guess rows)")
	clean(w)
end)

test("b5 api facts 3: all checks run in fake game, write facts, send nothing, and list non-read-only rows", function()
	local w = newWorld({ clubs = true })
	local c, L = loadApiFacts3(w)
	local G = L.GameFacts

	local beforeWhispers = #(w.whispers or {})
	local beforeMacros = #(w.macros or {})
	local beforeInvites = #(w.invites or {})
	local beforeErrors = #(w.errors or {})
	local beforeSent = c.sent or 0

	local ran, count = G.RunApiFacts3()
	eq(ran, true, "RunApiFacts3 succeeded")
	eq(count, #G.API_CHECKS3, "ran every check")

	local facts = c.env.WuberLabDB and c.env.WuberLabDB.facts or {}
	local notReadOnly = {}
	for _, check in ipairs(G.API_CHECKS3) do
		local list = facts[check.id]
		ok(type(list) == "table" and #list >= 1, "fact recorded for " .. check.id)
		local entry = list[#list]
		ok(type(entry.line) == "string" and entry.line ~= "", "non-empty fact line for " .. check.id)
		ok(not entry.line:find("^error:"), "no error in check " .. check.id .. ": " .. tostring(entry.line))
		ok(type(entry.a) == "table", "answers table recorded for " .. check.id)
		if check.readOnly == false then
			notReadOnly[#notReadOnly + 1] = check.source .. ":" .. check.name
		end
	end
	print("not checkable read-only (" .. #notReadOnly .. "): " .. table.concat(notReadOnly, ", "))

	eq(#(w.whispers or {}), beforeWhispers, "no whispers sent")
	eq(#(w.macros or {}), beforeMacros, "no macros touched")
	eq(#(w.invites or {}), beforeInvites, "no invites sent")
	eq(#(w.errors or {}), beforeErrors, "no Lua errors")
	eq(c.sent or 0, beforeSent, "no addon messages sent")
	clean(w)
end)

test("b5 api facts 3: combat guard blocks RunApiFacts3", function()
	local w = newWorld({ clubs = true })
	local c, L = loadApiFacts3(w)
	c.env.InCombatLockdown = function() return true end
	local ran, why = L.GameFacts.RunApiFacts3()
	eq(ran, false, "blocked in combat")
	eq(why, "in combat", "combat reason")
	clean(w)
end)
