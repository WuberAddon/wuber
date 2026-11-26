-- Job 2894 (feature D): lab/WuberLab/CallLog.lua notes, for the curated names only, each call of Wuber's own code: inside a click handler,
-- in combat, and whether a blocked event followed in the same frame. No arguments, no names. Driven here with stack texts (the fake game
-- has no real debugstack).
-- guard: CallLog.lua is a new file, so on the base commit this test file skips ("file not found"); the tests below fail on any CallLog that does not log as described.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local path = (os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")) .. "/CallLog.lua"
if not H.exists(path) then test("lab calllog: file not found (skipped)", function() end) return end
local function load()
	local L = { On = function() end }
	assert(loadfile(path))("WuberLab", L)
	return L.CallLog
end
local CLICK = "Interface\\AddOns\\Wuber\\UI\\Rider\\Cards.lua:10: in function <Interface\\AddOns\\Wuber\\UI\\Rider\\Cards.lua:8> (OnClick)"
local PLAIN = "Interface\\AddOns\\Wuber\\Core\\Base.lua:99: in function 'tick'"
test("lab calllog: the 30 names are exactly the guard's curated list", function()
	local S = dofile(H.root .. "/tests/surface/apisurface.lua")
	local C = load()
	local want = 0
	for name in pairs(S.curated) do want = want + 1 ok((function() for _, n in ipairs(C.NAMES) do if n == name then return true end end end)(), name .. " is logged") end
	eq(#C.NAMES, want, "no extra name")
end)
test("lab calllog: a call of Wuber's code inside a click handler, in combat, is noted", function()
	local C = load()
	local r = C.Note("InviteUnit", CLICK, true)
	ok(r and r.click == true and r.combat == true, "click and combat")
	local r2 = C.Note("InviteUnit", PLAIN, false)
	ok(r2 and r2.click == false and r2.combat == false, "not a click, not combat")
end)
test("lab calllog: another addon's call (WuberLab, a Blizzard frame) is never noted", function()
	local C = load()
	eq(C.Note("Logout", "Interface\\AddOns\\WuberLab\\Run.lua:5: in function x", false), nil)
	eq(C.Note("Logout", "Interface\\FrameXML\\Foo.lua:5", false), nil)
	eq(C.count, 0)
end)
test("lab calllog: a blocked event in the same frame marks the note; a later frame does not", function()
	local C = load()
	C.Note("Logout", PLAIN, false)
	ok(C.Blocked("ADDON_ACTION_BLOCKED", "Logout"), "same frame")
	eq(C.list[1].blocked, true) eq(C.list[1].kind, "BLOCKED")
	C.Note("Quit", PLAIN, false)
	C.frame = C.frame + 1
	eq(C.Blocked("ADDON_ACTION_BLOCKED", "Quit"), nil, "next frame: not the same")
	eq(C.list[2].blocked, false)
end)
test("lab calllog: a note holds no arguments and no names (only fn, click, combat, frame, blocked, kind)", function()
	local C = load()
	local r = C.Note("SendChatMessage", CLICK, false)
	local allowed = { fn = true, click = true, combat = true, frame = true, blocked = true, kind = true }
	for k in pairs(r) do ok(allowed[k], "field " .. k) end
end)
