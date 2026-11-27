-- Issue #41 (found by the bug hunt): the cost text of a flight-map price tag is never drawn off the screen (confirm page, window in the corner).
-- Runs the hunt's own repro file in a fresh Lua (it exits 0 once fixed, 1 while the bug exists).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local LUA = os.getenv("WUBER_LUA") or "lua5.1"

test("gauntlet #41: the cost text of a flight-map price tag is never drawn off the screen (confirm page, window in the corner)", function()
	local p = io.popen("cd " .. T.dir .. "/.. && " .. LUA .. " tests/hunt/repro/universal.layout--net-many--phone-confirm--place-fm_known--pos-corner-d74f93.lua 2>&1")
	local out = p:read("*a")
	local _, _, code = p:close()
	ok(code == 0 or code == nil, "the repro still fails: " .. tostring(out):sub(-300))
	ok(tostring(out):find("^PASS") or tostring(out):find("\nPASS"), "the repro did not report PASS: " .. tostring(out):sub(-300))
end)
