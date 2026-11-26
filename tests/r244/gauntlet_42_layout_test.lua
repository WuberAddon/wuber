-- Issue #42 (found by the bug hunt): the news card is never over the Wuber window when the Settings page opens wide.
-- Runs the hunt's own repro file in a fresh Lua (it exits 0 once fixed, 1 while the bug exists).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local LUA = os.getenv("WUBER_LUA") or "lua5.1"

test("gauntlet #42: the news card is never over the Wuber window when the Settings page opens wide", function()
	local p = io.popen("cd " .. T.dir .. "/.. && " .. LUA .. " tests/hunt/repro/universal.layout--coach-not_done--phone-settings--pos-corner--saved-old-70e28b.lua 2>&1")
	local out = p:read("*a")
	local _, _, code = p:close()
	ok(code == 0 or code == nil, "the repro still fails: " .. tostring(out):sub(-300))
	ok(tostring(out):find("^PASS") or tostring(out):find("\nPASS"), "the repro did not report PASS: " .. tostring(out):sub(-300))
end)
