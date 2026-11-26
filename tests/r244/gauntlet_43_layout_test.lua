-- Issue #43 (found by the bug hunt): the Reset label of the Wide pages row is not cut short with "..." (settings window, big scale, after a position reset in combat).
-- Runs the hunt's own repro file in a fresh Lua (it exits 0 once fixed, 1 while the bug exists).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local LUA = os.getenv("WUBER_LUA") or "lua5.1"

test("gauntlet #43: the Reset label of the Wide pages row is not cut short with \"...\" (settings window, big scale, after a position reset in combat)", function()
	local p = io.popen("cd " .. T.dir .. "/.. && " .. LUA .. " tests/hunt/repro/universal.layout--combat-after--phone-settings_win--pos-corner--size-2662x2089_1-fb52d1-5045cc.lua 2>&1")
	local out = p:read("*a")
	local _, _, code = p:close()
	ok(code == 0 or code == nil, "the repro still fails: " .. tostring(out):sub(-300))
	ok(tostring(out):find("^PASS") or tostring(out):find("\nPASS"), "the repro did not report PASS: " .. tostring(out):sub(-300))
end)
