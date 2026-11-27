-- Tests for lab/WuberLab/ApiFacts.lua:
--   1. Every `game` id in tests/fixtures/client/api/{chat,units,frames,world}.lua has a check in ApiFacts.lua, and the reverse.
--   2. Each check runs in the fake game beside the Lab without error and writes its fact.
--   3. No check calls a name on tools/forbidden.lua, sends anything, or runs in combat.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
local API_FACTS = LAB_DIR .. "/ApiFacts.lua"
if not H.exists(API_FACTS) then
	test("b4 api facts: ApiFacts.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local API_FILES = { "chat.lua", "units.lua", "frames.lua", "world.lua" }

local function ledgerIds()
	local ids, ordered = {}, {}
	for _, fname in ipairs(API_FILES) do
		local path = H.root .. "/tests/fixtures/client/api/" .. fname
		if H.exists(path) then
			local rows = dofile(path)
			for _, row in ipairs(rows) do
				if row.game and not ids[row.game] then
					ids[row.game] = true
					ordered[#ordered + 1] = row.game
				end
			end
		end
	end
	return ids, ordered
end

local function loadApiFacts(w)
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" } })
	settle(w)
	local L = c.ns.WuberLab
	local chunk = assert(loadfile(API_FACTS))
	setfenv(chunk, c.env)
	chunk("WuberLab", L)
	return c, L
end

test("b4 api facts: every ledger game id has a check in ApiFacts.lua and the reverse", function()
	local w = newWorld({ clubs = true })
	local _, L = loadApiFacts(w)
	local G = L.GameFacts
	ok(type(G) == "table" and type(G.API_CHECKS) == "table", "G.API_CHECKS exists")

	local wantIds, ordered = ledgerIds()
	local haveIds = {}
	for _, check in ipairs(G.API_CHECKS) do
		ok(type(check.id) == "string" and check.id ~= "", "check has non-empty id")
		ok(not haveIds[check.id], "no duplicate check id: " .. tostring(check.id))
		haveIds[check.id] = true
		ok(wantIds[check.id], "check id exists in API ledger: " .. tostring(check.id))
	end
	for _, id in ipairs(ordered) do
		ok(haveIds[id], "ledger game id has check in ApiFacts.lua: " .. tostring(id))
	end
	eq(#G.API_CHECKS, #ordered, "exact 1-to-1 count between ledger game ids and ApiFacts checks")

	local inIds = {}
	for _, row in ipairs(G.IDS) do inIds[row[1]] = true end
	for _, id in ipairs(ordered) do
		ok(inIds[id], "G.IDS has row for " .. tostring(id))
	end
	clean(w)
end)

test("b4 api facts: all checks run in the fake without error, write facts, send nothing, and touch nothing forbidden", function()
	local w = newWorld({ clubs = true })
	local c, L = loadApiFacts(w)
	local G = L.GameFacts

	local beforeWhispers = #(w.whispers or {})
	local beforeMacros = #(w.macros or {})
	local beforeInvites = #(w.invites or {})
	local beforeViolations = #(w.violations or {})
	local beforeBlocked = #(w.blocked or {})
	local beforeErrors = #(w.errors or {})
	local beforeSent = c.sent or 0

	local ran, count = G.RunApiFacts()
	eq(ran, true, "RunApiFacts succeeded")
	eq(count, #G.API_CHECKS, "ran every check")

	local facts = c.env.WuberLabDB and c.env.WuberLabDB.facts or {}
	for _, check in ipairs(G.API_CHECKS) do
		local list = facts[check.id]
		ok(type(list) == "table" and #list >= 1, "fact recorded for " .. check.id)
		local entry = list[#list]
		ok(type(entry.line) == "string" and entry.line ~= "", "non-empty fact line for " .. check.id)
		ok(not entry.line:find("^error:"), "no error in check " .. check.id .. ": " .. tostring(entry.line))
		ok(type(entry.a) == "table", "answers table recorded for " .. check.id)
	end

	eq(#(w.whispers or {}), beforeWhispers, "no whispers sent")
	eq(#(w.macros or {}), beforeMacros, "no macros run")
	eq(#(w.invites or {}), beforeInvites, "no invites sent")
	eq(#(w.violations or {}), beforeViolations, "no forbidden or taint violations")
	eq(#(w.blocked or {}), beforeBlocked, "no blocked actions")
	eq(#(w.errors or {}), beforeErrors, "no Lua errors")
	eq(c.sent or 0, beforeSent, "no addon messages sent")
	clean(w)
end)

test("b4 api facts: RunApiFacts refuses to run in combat and ApiFacts.lua names nothing forbidden or action-sending", function()
	local w = newWorld()
	local c, L = loadApiFacts(w)
	local G = L.GameFacts

	c.env.InCombatLockdown = function() return true end
	local ran, why = G.RunApiFacts()
	eq(ran, false, "refused in combat")
	eq(why, "in combat", "combat reason")

	local f = assert(io.open(API_FACTS, "rb"))
	local src = f:read("*a")
	f:close()

	for _, banned in ipairs({ "SendChatMessage", "SendAddonMessage", "InviteUnit", "ReloadUI", "CastSpell", "RunMacroText", "AcceptTrade" }) do
		ok(not src:find(banned, 1, true), "ApiFacts.lua does not contain " .. banned)
	end
	local forbidden = dofile(H.root .. "/tools/forbidden.lua")
	for _, item in ipairs(forbidden) do
		ok(not src:find(item.name, 1, true), "ApiFacts.lua does not name forbidden " .. item.name)
	end
	clean(w)
end)
