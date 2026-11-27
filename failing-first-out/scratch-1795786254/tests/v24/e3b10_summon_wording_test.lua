-- E3b-10: tests/promises/v24_summon.lua and release/CHANGELOG-2.4.0.md quote the softened summon guard wording.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, ok, eq = T.test, T.ok, T.eq

local function read(rel)
	local dir = T.dir or "tests"
	local path = rel == "v24_summon" and (dir .. "/promises/v24_summon.lua") or (dir .. "/../release/CHANGELOG-2.4.0.md")
	return T.readFile(path)
end

test("v24_summon e3b-10: v24_summon.lua and CHANGELOG-2.4.0.md use the softened summon guard wording", function()
	local oldSentence = "never casts on a rider who already has a summon waiting"
	local newSentence = "does not cast on a rider it has seen get a summon"

	local changelog = read("changelog")
	ok(changelog ~= nil, "release/CHANGELOG-2.4.0.md is readable")
	ok(changelog:find(newSentence, 1, true) ~= nil, "CHANGELOG-2.4.0.md has the softened wording")
	ok(changelog:find(oldSentence, 1, true) == nil, "CHANGELOG-2.4.0.md does not have the old wording")

	local promises = read("v24_summon")
	ok(promises ~= nil, "tests/promises/v24_summon.lua is readable")
	ok(promises:find(oldSentence, 1, true) == nil, "v24_summon.lua does not pin the old 'never casts' wording")

	local count, pos = 0, 1
	while true do
		local found = promises:find(newSentence, pos, true)
		if not found then break end
		count = count + 1
		pos = found + #newSentence
	end
	eq(count, 3, "v24_summon.lua quotes the softened wording in all 3 places (header, guard.no_cast_on_waiting, guard.survives_reload)")
end)
