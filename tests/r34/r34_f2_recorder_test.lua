local T = ...
local test, ok = T.test, T.ok

-- The recorder conformance and replay tests share one kept story (CF.scenes). They must stay out of the
-- behaviour transcript (T.testOutside), or the record of whichever builds the story first would differ.
local function src(name)
	local f = assert(io.open(T.dir .. "/rec/" .. name, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end

test("r34 f2: the recorder conformance and replay tests are not written into the behaviour transcript", function()
	for _, name in ipairs({ "conform_test.lua", "replay_test.lua" }) do
		local s = src(name)
		ok(s:find("T.testOutside or T.test", 1, true), name .. " takes its test function from T.testOutside")
		local rest = s:gsub("T%.testOutside or T%.test", "")
		ok(not rest:find("T%.test%f[%W]"), name .. " has no plain T.test")
	end
end)
