local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."
-- 2.4.4 words page, group A (the maintainer's answered words): buyers become riders, the switch asks once, a toast, the raid leader.

local function src(p)
	local f = assert(io.open(root .. "/" .. p, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end
local function has(p, s) return src(p):find(s, 1, true) ~= nil end

test("words244 A1/A2: the public chat switch says riders, and its tooltip says it asks you once when you switch it on", function()
	local s = "Wuber/UI/Settings/Rows.lua"
	ok(has(s, '"drive.autoPublic", "Invite public chat riders"'), "label")
	ok(not has(s, '"drive.autoPublic", "Invite public chat buyers"'), "old label still there")
	ok(has(s, "On: invites riders in the public chat channels you read (see Chat channels) who name your place. Wuber can misread chat, so it asks you once when you switch this on. Off: click a name to invite."), "tooltip")
end)

test("words244 A3: /wuber market line says riders", function()
	ok(has("Wuber/Drive/Commands.lua", "Inviting riders in the public chat channels you read who name your place"), "Commands")
end)

test("words244 A4: the chat-post tip says riders find you", function()
	ok(has("Wuber/UI/Driver/Build.lua", "always starting [Wuber], so riders find you and get the addon."), "Build")
end)

test("words244 A5/A6: Earnings day and total views say riders asked", function()
	local s = src("Wuber/UI/Driver/Earnings.lua")
	ok(not s:find('"buyer", "buyers") .. " asked"', 1, true), "old plural still there")
	local _, n = s:gsub('"rider", "riders"%) %.%. " asked"', "")
	ok(n == 2, "riders asked in day and total views: " .. n)
end)

test("words244 A7: /wuber stats says riders seen", function()
	ok(has("Wuber/Drive/Log.lua", "%d riders seen (%d for %s)."), "stats")
	ok(not has("Wuber/Drive/Log.lua", "%d buyers seen"), "old")
end)

test("words244 A8: Do nothing tip says toast", function()
	ok(has("Wuber/UI/Settings/Rows.lua", "the rider stays unblocked and you only get a toast."), "tip")
end)

test("words244 A9: raid alert says the crew captain left", function()
	ok(has("Wuber/Drive/Raid.lua", "Raid summons stopped: the crew captain left the group."), "alert")
end)
