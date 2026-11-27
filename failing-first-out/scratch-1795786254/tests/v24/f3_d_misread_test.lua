-- Wuber 2.4 fix round 3, group D (LRN-07): every row of tests/chatlines/misread.txt through the public-chat reader. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("v24 f3 d: every line in tests/chatlines/misread.txt gets its kept answer", function()
	local f = io.open("tests/chatlines/misread.txt", "r")
	ok(f ~= nil, "tests/chatlines/misread.txt opens (run from the repo root)")
	if not f then return end
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	local n = 0
	for row in f:lines() do
		row = row:gsub("\r$", "")
		if row ~= "" and row:sub(1, 1) ~= "#" then
			local expect, line = row:match("^(%a+)\t([^\t]+)")
			ok(expect == "ignore" or expect == "lead" or expect == "invite", "row has a known answer: " .. row)
			if expect and line then
				n = n + 1
				local verdict, why = DR.Careful(line, "public", "Dan Miller")
				eq(verdict, expect, "line: " .. line .. " (reason: " .. tostring(why) .. ")")
			end
		end
	end
	f:close()
	ok(n >= 10, "the file has its rows (" .. n .. ")")
	T.clean(w)
end)
