local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."

-- #295: at the 2662x2089 window and Wuber size 2.2 the "Inviting" heading of Settings > Driving must not lie
-- under the next card. layout-check --known lists every overlap it finds, allowed or not.
local function sweep(config, screen)
	local p = io.popen('cd "' .. root .. '" && lua5.1 tools/layout-check.lua --known --config ' .. config .. " --screen " .. screen .. " 2>&1")
	local out = p:read("*a")
	p:close()
	return out
end

test("settings_driving at 2662x2089 Wuber 2.2: the Inviting heading is clear of the next card", function()
	local out = sweep("2662x2089@2.2", "settings_driving")
	ok(out:find("layout-check: 1 runs", 1, true), "the sweep ran: " .. out:sub(-300))
	for line in out:gmatch("[^\r\n]+") do
		ok(not line:find("Inviting", 1, true), "the Inviting heading still overlaps: " .. line:sub(1, 200))
	end
end)

-- guard: the same page at the plain size was clean already and must stay so
test("settings_driving at Wuber 1.0: no overlap of the Inviting heading", function()
	local out = sweep("1920x1080@1.0", "settings_driving")
	ok(out:find("layout-check: 1 runs", 1, true), "the sweep ran: " .. out:sub(-300))
	ok(not out:find("Inviting", 1, true), "overlap at 1.0")
end)
