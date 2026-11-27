local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."
-- (#192) Wuber/UI/Rider/WorldMap.lua: every local function it defines is used somewhere in the file.

test("WorldMap.lua: every local function is called or passed somewhere in the file (#192)", function()
	local f = assert(io.open(root .. "/Wuber/UI/Rider/WorldMap.lua", "rb"))
	local src = f:read("*a")
	f:close()
	-- comments and strings do not count as a use
	src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""'):gsub("'[^'\n]*'", "''")
	local unused = {}
	for name in src:gmatch("local%s+function%s+([%w_]+)") do
		local uses = 0
		for _ in src:gmatch("%f[%w_]" .. name .. "%f[^%w_]") do uses = uses + 1 end
		if uses < 2 then unused[#unused + 1] = name end
	end
	ok(#unused == 0, "unused local functions in WorldMap.lua: " .. table.concat(unused, ", "))
end)
