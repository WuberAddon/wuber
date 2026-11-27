-- Tests of tools/taint.lua (round 15, agent E): reading the game's taint.log for what was blocked and
-- which names are not on tools/forbidden.lua yet. Fixture: tests/fixtures/taint (a Logs folder and the
-- AddOns folder next to it, as in the game). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local TAINT = assert(loadfile(T.dir .. "/../tools/taint.lua"))("--lib")
local FIX = T.dir .. "/fixtures/taint"

local function readSource(addon, file, n)
	local lines = TAINT.readLines(FIX .. "/Interface/AddOns/" .. addon .. "/" .. file)
	return lines and lines[n] or nil
end

test("tools/taint.lua: reads taint.log's blocked actions, the addon lines on their stack, and the names not on the list", function()
	local lines = assert(TAINT.readLines(FIX .. "/Logs/taint.log"), "the fixture log")
	local entries, notes = TAINT.parse(lines)
	eq(#entries, 6, "blocked actions")
	eq(notes, 1, "an 'Execution tainted' line is only a note")
	eq(entries[1].addon, "ProbeAddon")
	eq(entries[1].file .. ":" .. entries[1].line, "Log.lua:3", "the first line inside the addon")
	eq(#entries[1].frames, 2, "and the one under it (the wrapper hides the name)")
	eq(entries[2].addon, "Wuber")
	eq(entries[2].fn, nil, "UNKNOWN: the function is not named")
	eq(#entries[2].frames, 2, "a note's stack line never joins the blocked action after it")
	eq(entries[4].fn, "C_Club.SendCharacterInvitation")
	local list = assert(loadfile(T.dir .. "/../tools/forbidden.lua"))()
	local out = table.concat(TAINT.report(entries, notes, list, readSource), "\n")
	ok(out:find("6 blocked actions at 5 places; 1 taint note", 1, true), out)
	ok(out:find("Wuber/Drive/Danger.lua:4 x2", 1, true), "the same place counted once: " .. out)
	ok(out:find("listed  COMBAT_LOG_EVENT_UNFILTERED (event)", 1, true), out)
	ok(out:find("listed  C_Club.SendCharacterInvitation (api)", 1, true), out)
	ok(out:find("NEW     PLAYER_FAKE_BLOCKED_EVENT (event)", 1, true), out)
	ok(out:find("NEW     SetPassThroughButtons (method)", 1, true), out)
	ok(out:find("NEW     CastSpellByName (api)", 1, true), out)
	ok(not out:find(" L.On (", 1, true) and not out:find(" DR.Open (", 1, true) and not out:find(" W.Print (", 1, true)
		and not out:find(" RegisterEvent (", 1, true) and not out:find(" CreateFrame (", 1, true),
		"the addon's own tables are no candidates: " .. out)
	ok(out:find("1 place with no name to read", 1, true), "a file that is gone: " .. out)
	ok(out:find('{ name = "PLAYER_FAKE_BLOCKED_EVENT", kind = "event", why = "taint.log: blocked at ProbeAddon/Log.lua:3" },', 1, true),
		"a ready line for tools/forbidden.lua: " .. out)
	ok(out:find('{ name = "CastSpellByName", kind = "api", path = { "CastSpellByName" },', 1, true), out)
	-- each suggested line is valid Lua that the harness would take
	local sugg = {}
	for l in out:gmatch("\t(%b{}),") do sugg[#sugg + 1] = l end
	eq(#sugg, 3, "three suggestions")
	local more = assert(loadstring("return { " .. table.concat(sugg, ", ") .. " }"))()
	eq(more[3].kind, "api")
	eq(more[3].path[1], "CastSpellByName")
	-- nothing blocked
	local none = table.concat(TAINT.report({}, 0, list, readSource), "\n")
	ok(none:find("Nothing was blocked.", 1, true), none)
end)

test("tools/taint.lua: candidates on a line of Lua (events, API calls, methods; never the addon's own tables or comments)", function()
	local function names(src)
		local out = {}
		for _, c in ipairs(TAINT.candidates(src)) do out[#out + 1] = c.name .. "/" .. c.kind end
		return table.concat(out, " ")
	end
	eq(names('f:RegisterEvent("UNIT_AURA") C_Club.SendCharacterInvitation(1, n)'), "UNIT_AURA/event C_Club.SendCharacterInvitation/api")
	eq(names('local f = CreateFrame("Frame") f:SetScript("OnEvent", fn) f:RegisterAllEvents()'), "RegisterAllEvents/method")
	eq(names('W.On("PLAYER_LOGIN", fn) UIMod.show() self:Hide() local x = pcall(fn) -- CastSpellByName()'), "PLAYER_LOGIN/event")
	eq(names(nil), "")
end)
