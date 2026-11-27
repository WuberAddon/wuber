-- #100 (four bad hunt promises in tests/promises/universal.lua, not addon bugs): each promise below said "fail" for a game that is fine.
--   1. universal.button_does_something: "Close Wuber" zooms the window out over 0.18 s; the check looked after 0.2 s and saw nothing.
--   2. universal.reload_same: in combat the big button's words are out-of-combat only, so the words before and after a /reload differ.
--   3. universal.reload_same: the What's new card was still pending before the /reload and came up after it ("Not now").
--   4. universal.no_unclicked_send: messages a click queued in a boss fight are sent when it ends, over 60 s after the click.
-- Each fixed check must still catch the real fault it is for: a button that does nothing, a text that changes in a /reload, a
-- send with no click at all. tests/r54/u100_probe.lua runs one case of the bug hunt per process and prints "<status>|<line>".
local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."

local function lua() return (arg and arg[-1]) or "lua5.1" end
local function probe(case)
	local cmd = ("cd %s && \"%s\" tests/r54/u100_probe.lua %s 2>&1"):format(root, lua():gsub("\\", "/"), case)
	local p = io.popen(cmd)
	local out = p and p:read("*a") or ""
	if p then p:close() end
	local last = out:match("([^\r\n]*)%s*$") or ""
	local status, line = last:match("^(%S-)|(.*)$")
	return status, line, out
end

test("a button that closes the window with a zoom-out counts as doing something (#100)", function()
	local status, line, out = probe("close_window")
	ok(status == "pass", "universal.button_does_something passes for Close Wuber on trips (it said: " .. tostring(line or out:sub(-400)) .. ")")
end)

test("a button that does nothing still fails universal.button_does_something (#100)", function()
	local status, line, out = probe("dead_close_window")
	ok(status == "fail" and tostring(line):find("nothing happens", 1, true) ~= nil, "a dead Close Wuber is caught (it said: " .. tostring(status) .. " " .. tostring(line or out:sub(-400)) .. ")")
end)

test("universal.reload_same does not compare the big button's words read in combat (#100)", function()
	local status, line, out = probe("reload_in_combat")
	ok(status == "pass", "no difference reported for a /reload in combat (it said: " .. tostring(line or out:sub(-400)) .. ")")
end)

test("universal.reload_same does not blame a /reload for the What's new card coming up (#100)", function()
	local status, line, out = probe("reload_news_card")
	ok(status == "pass", "no difference reported for the pending card (it said: " .. tostring(line or out:sub(-400)) .. ")")
end)

test("universal.reload_same still finds a text that changes in a /reload out of combat (#100)", function()
	local status, line, out = probe("changed_reload")
	ok(status == "fail" and tostring(line):find("Where to?", 1, true) ~= nil, "the changed text is reported (it said: " .. tostring(status) .. " " .. tostring(line or out:sub(-400)) .. ")")
end)

test("universal.reload_same still finds a text away from the big button that goes in a /reload in combat (#100)", function()
	local status, line, out = probe("changed_reload_combat")
	ok(status == "fail" and tostring(line):find("Where to?", 1, true) ~= nil, "the lost text is reported in combat (it said: " .. tostring(status) .. " " .. tostring(line or out:sub(-400)) .. ")")
end)

test("universal.no_unclicked_send counts the click that queued a message sent after a long boss fight (#100)", function()
	local status, line, out = probe("boss_fight_send")
	ok(status == "pass", "no send without a click reported (it said: " .. tostring(line or out:sub(-400)) .. ")")
end)

test("universal.no_unclicked_send still fails a send with no click at all (#100)", function()
	local status, line, out = probe("dead_boss_fight_send")
	ok(status == "fail" and tostring(line):find("you had not clicked", 1, true) ~= nil, "a send with no click is caught (it said: " .. tostring(status) .. " " .. tostring(line or out:sub(-400)) .. ")")
end)
