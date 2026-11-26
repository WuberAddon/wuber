-- Polestar lesson 19: being a polite sender is written down as numbers.
-- docs/POLITE-SENDING.md lists every limit on what Wuber sends to other players. This test reads the doc's
-- table and checks each row against the live value (NETK, RK, CX, W.ADVERT_GAP) and against the file it names,
-- so the doc and the code cannot drift apart. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the value a row's constant name has in the running addon
local function live(W, name)
	local owner, key = name:match("^(%a+)%.([%w_]+)$")
	if owner == "NETK" then return W.Mod("Net.Base").NETK[key] end
	if owner == "CX" then return W.Mod("Net.Community").CX[key] end
	if owner == "RK" then return W.Mod("Net.Raincheck").RK and W.Mod("Net.Raincheck").RK[key] end
	if owner == "W" then return W[key] end
end

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

test("polestar 19: every number in docs/POLITE-SENDING.md is the live limit", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local doc = readAll(T.dir .. "/../docs/POLITE-SENDING.md")
	ok(doc, "docs/POLITE-SENDING.md exists")
	if not doc then return end
	local rows, seen = 0, {}
	for line in doc:gmatch("[^\r\n]+") do
		local name, value, file = line:match("|%s*`([%w_%.]+)`%s*|%s*(%d+)%s*|%s*`([^`:]+)`%s*|")
		if name then
			rows = rows + 1
			eq(seen[name], nil, name .. " is listed once")
			seen[name] = true
			eq(live(W, name), tonumber(value), name .. " in the doc equals the live value")
			local src = readAll(T.dir .. "/../" .. file)
			ok(src, file .. " exists")
			if src then
				local short = name:match("%.([%w_]+)$")
				local pat = "%f[%w_]" .. short:gsub("%p", "%%%0") .. "%s*=%s*" .. value .. "%f[%D]"
				ok(src:find(pat), file .. " sets " .. short .. " = " .. value)
			end
		end
	end
	ok(rows >= 40, "the doc's table lists the limits (" .. rows .. " rows)")
	T.clean(w)
end)

-- guard: tools/failing-first.py reads AGENTS.md from the target tree, so it passes there; on plain main it fails (no link)
test("polestar 19: AGENTS.md links the polite-sending doc", function()
	local a = readAll(T.dir .. "/../AGENTS.md")
	ok(a and a:find("docs/POLITE%-SENDING%.md"), "AGENTS.md's table points to docs/POLITE-SENDING.md")
end)
