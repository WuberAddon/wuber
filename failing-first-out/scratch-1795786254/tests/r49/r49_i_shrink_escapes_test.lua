-- Round 49, group I: tests/hunt/lib/shrink.lua wrote its layout patterns as "%\\(" (a backslash before a bracket in a
-- string). Lua 5.1 reads that as "%(", but strict Lua refuses an unknown escape, so the file did not load there.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, readFile, dir = T.test, T.eq, T.ok, T.readFile, T.dir

local PATH = dir .. "/hunt/lib/shrink.lua"

-- A backslash may only start a known escape in a Lua string: a b f n r t v \\ " ' newline, a digit, or x/z in newer Lua.
-- The one bug: a backslash before ( or ) (the pattern "%\(").
-- guard: shrink.lua lines 283-284 held "%\(" and "%\)" and this test failed on that file by hand on 23 Nov; failing-first --base-tools swaps only tools/ and tests/lib/, not tests/hunt/lib/, so it cannot prove it
test("r49 i: shrink.lua has no backslash-bracket escape in a string (strict Lua would refuse the file)", function()
	local text = readFile(PATH)
	ok(text and #text > 1000, "shrink.lua is read")
	local bad = {}
	local n = 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if line:find("\\[()]") then bad[#bad + 1] = n .. ": " .. line end
	end
	eq(#bad, 0, "lines with a backslash before a bracket:\n" .. table.concat(bad, "\n"))
end)

-- guard: the layout line is still reduced to kind and region (the fix only spells the same pattern without the backslash)
test("r49 i: Hunt.looseLine still reduces a layout line to kind and region", function()
	local Hunt = { copy = function(x) return x end, ser = tostring, oneLine = function(s) return s end }
	local chunk = assert(loadfile(PATH))()
	chunk(Hunt)
	local line = Hunt.looseLine("universal.layout", "A layout problem (cut off): Wuber/UI/Foo.lua:12. more text")
	eq(line, "layout\1cut off\1Foo.lua:12", "kind and file:line of the first region")
	local plain = Hunt.looseLine("universal.layout", "A layout problem (overlap): Bar.lua:9 and so on")
	eq(plain, "layout\1overlap\1Bar.lua:9")
	eq(Hunt.looseLine("rider.other", "x"), nil, "other promises are not loosened")
end)
