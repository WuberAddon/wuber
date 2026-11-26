-- E1-15: verify the full 97-file hunt repro list is merged into tests/hunt/repro with all promises present.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function readAll(path)
	local f = assert(io.open(path, "rb"), "cannot open " .. path)
	local s = f:read("*a")
	f:close()
	return s
end

-- guard: the 97 repro files were already merged on the base; this keeps the list whole
test("e1-15: tests/hunt/repro has all 97 repro files and every one has its promise defined", function()
	local Hunt = dofile(T.dir .. "/hunt/lib.lua")
	Hunt.init({})
	local files = Hunt.listLua(T.dir .. "/hunt/repro")
	ok(#files >= 97, "expected at least 97 repro files in tests/hunt/repro, got " .. #files)
	local missing = {}
	for _, path in ipairs(files) do
		local txt = readAll(path)
		local pid = txt:match('promise%s*=%s*"([^"]+)"')
		ok(pid ~= nil, "repro file has no promise field: " .. path)
		if pid and not Hunt.promises[pid] then
			missing[#missing + 1] = pid .. " (" .. path .. ")"
		end
	end
	eq(#missing, 0, "repro files with missing promises: " .. table.concat(missing, ", "))
end)
