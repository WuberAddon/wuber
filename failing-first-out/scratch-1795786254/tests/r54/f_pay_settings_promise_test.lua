-- #88 (a bad hunt promise, not an addon bug): the promise pay.driver_sees_paid (tests/promises/payment.lua) took any
-- "paid" in the Settings lines ("Count a smaller payment as paid") for the driver's queue, so it never opened the
-- Drive tab, then searched the Settings text for the fare. With Settings open the promise must first look at the queue.
-- Runs the hunt's sweep on that one situation and one promise (tools/hunt/sweep.lua --one) and reads its verdict line.
local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."

local function lua() return (arg and arg[-1]) or "lua5.1" end
local function sweep(sit, promise)
	local cmd = ("cd %s && \"%s\" tools/hunt/sweep.lua --one \"%s\" --promise %s --verbose 2>&1"):format(root, lua():gsub("\\", "/"), sit, promise)
	local p = io.popen(cmd)
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end

test("pay.driver_sees_paid looks at the Drive queue when Settings is open (#88)", function()
	local out = sweep("phone=settings_map,ride=paid,role=crew,size=2662x2089@1.5", "pay.driver_sees_paid")
	ok(out:find("pay.driver_sees_paid", 1, true) ~= nil, "the sweep ran the promise")
	local verdict = out:match("\n(%a+)%s+pay%.driver_sees_paid") or out:match("^(%a+)%s+pay%.driver_sees_paid")
	ok(verdict == "pass", "the promise passes with Settings open (it said: " .. tostring(verdict) .. "): " .. out:sub(-700))
end)
