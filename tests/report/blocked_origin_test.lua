-- Blocked origin: the game names a blocked action "UNKNOWN()" and the event arrives with no Wuber frame in the
-- stack, so Wuber keeps breadcrumbs (W.Crumb) just before it does something the game may refuse, and the bug
-- report says which Wuber file:line asked. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the real Lua traceback, taken when this file loads (before any test can swap debug.traceback), as the game's
-- debugstack; the last stack seen is kept so a failure can show it
local traceback, lastStack = debug.traceback, nil
local function realStack()
	lastStack = traceback("", 2)
	return lastStack
end

-- the stack of a Wuber call that is no longer on the stack when the block event arrives
local function stackAt(file, line)
	return "[string \"=[C]\"]: in function 'x'\n" ..
		"Interface\\AddOns\\Wuber\\Core\\Runtime.lua:99: in function 'Crumb'\n" ..
		"Interface\\AddOns\\Wuber\\" .. file .. ":" .. line .. ": in function 'go'\n" ..
		"Interface\\AddOns\\Other\\Thing.lua:9: in main chunk"
end
local EVENT_STACK = "[string \"=[C]\"]: in function 'x'\nInterface\\AddOns\\Wuber\\Core\\Runtime.lua:480: in function <Interface\\AddOns\\Wuber\\Core\\Runtime.lua:470>"

local function client()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	r.env.geterrorhandler = function() return function() end end
	return w, r
end

test("blocked origin: an UNKNOWN() block right after a Wuber call names that call's file:line in the report", function()
	local w, r = client()
	r.env.debugstack = function() return stackAt("Drive/Invite.lua", 212) end
	r.W.Crumb("invite")
	r.env.debugstack = function() return EVENT_STACK end -- the event itself carries no Wuber frame
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "UNKNOWN()")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("UNKNOWN() from Drive/Invite.lua:212", 1, true), "the block names the Wuber line: " .. text)
	ok(text:find("invite from Drive/Invite.lua:212", 1, true), "the breadcrumb list shows the call")
	-- the frame is "Interface\AddOns\Other\Thing.lua:9"; the word "Other" alone is also in #78's "Other addons:" line
	ok(not text:find("Thing.lua", 1, true) and not text:find("AddOns\\Other", 1, true), "no other addon's frame")
end)

-- guard: unknown stays honest when no recent crumb
test("blocked origin: with no recent breadcrumb the report says unknown", function()
	local w, r = client()
	r.env.debugstack = function() return stackAt("Drive/Invite.lua", 212) end
	r.W.Crumb("invite")
	w:advance(10) -- long ago: not the call that was blocked
	r.env.debugstack = function() return EVENT_STACK end
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "UNKNOWN()")
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("UNKNOWN() from unknown", 1, true), "honest: " .. text)
	ok(not text:find("UNKNOWN() from Drive", 1, true), "an old call is not blamed")
	local w2, r2 = client()
	r2.env.debugstack = function() return EVENT_STACK end
	r2:fire("ADDON_ACTION_BLOCKED", "Wuber", "UNKNOWN()")
	ok(r2.W.UI.Bug.Report("x"):find("UNKNOWN() from unknown", 1, true), "no breadcrumb at all")
end)

test("blocked origin: breadcrumbs keep the last five, newest last", function()
	local w, r = client()
	for i = 1, 8 do
		r.env.debugstack = function() return stackAt("Drive/F" .. i .. ".lua", i) end
		r.W.Crumb("call" .. i)
		w:advance(1)
	end
	eq(#r.W.crumbs, 5, "capped at five")
	eq(r.W.crumbs[1].tag, "call4")
	eq(r.W.crumbs[5].where, "Drive/F8.lua:8")
end)

test("blocked origin: W.Try leaves a breadcrumb for the call it runs", function()
	local w, r = client()
	r.env.debugstack = function() return stackAt("Drive/Invite.lua", 77) end
	r.W.Try("invite", function() end)
	local c = r.W.crumbs[#r.W.crumbs]
	ok(c and c.tag == "invite" and c.where == "Drive/Invite.lua:77", "a Try is a breadcrumb")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
end)

-- the real call sites: the fake game runs the real Secure.lua and Button.lua; debugstack is the real Lua traceback
-- (the files load under their Wuber/... names), so the file:line is the one the code really has
test("blocked origin: a click on the secure Request button leaves a crumb with its Secure.lua line", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	r.env.debugstack = realStack
	T.openConfirm(r, d.W.myKey)
	w:advance(1)
	r:click(r.env.WuberRequestButton)
	local found
	for _, c in ipairs(r.W.crumbs) do
		if c.tag == "click WuberRequestButton" then found = c end
	end
	ok(found, "a crumb for the click")
	ok(found and found.where and found.where:find("^UI/Secure%.lua:%d+$"), "its Wuber file:line: " .. tostring(found and found.where) .. "\nlast stack:\n" .. tostring(lastStack))
end)

test("blocked origin: changing the driver button's secure attribute leaves a crumb with its Button.lua line, an unchanged plan none", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	d.env.debugstack = realStack
	local DR = W.Drive
	local real = DR.Plan
	DR.Plan = function() local p = real() p.type, p.macrotext = "macro", "/wave" return p end
	DR.Button.Refresh()
	eq(d.env.WuberDriveButton:GetAttribute("macrotext"), "/wave", "the attribute really changed")
	local c = W.crumbs[#W.crumbs]
	ok(c and c.tag == "secure attribute" and c.where and c.where:find("^Drive/Button%.lua:%d+$"), "a crumb: " .. tostring(c and c.where) .. "\nlast stack:\n" .. tostring(lastStack))
	local n = #W.crumbs
	DR.Button.Refresh()
	eq(#W.crumbs, n, "the same plan again changes nothing: no crumb")
	eq(c.n, 1, "and no count")
end)

test("blocked origin: the report lists the crumbs and tags a guessed origin; with none it says none recorded", function()
	local w, r = client()
	r.env.debugstack = function() return stackAt("Drive/Invite.lua", 212) end
	r.W.Crumb("invite")
	r.env.debugstack = function() return EVENT_STACK end
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "UNKNOWN()")
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("Wuber calls the game may refuse (last 5):", 1, true), "the section: " .. text)
	ok(text:find("(the last Wuber call before it)", 1, true), "the guess is tagged")
	local w2, r2 = client()
	r2.env.debugstack = function() return EVENT_STACK end
	r2:fire("ADDON_ACTION_BLOCKED", "Wuber", "UNKNOWN()")
	local t2 = r2.W.UI.Bug.Report("x")
	ok(t2:find("Wuber calls the game may refuse (last 5):", 1, true) and t2:find("none recorded", 1, true), "none recorded: " .. t2)
	ok(not t2:find("the last Wuber call before it", 1, true), "no guess without a crumb")
end)

-- every shape a stack line takes: the suite's relative chunk names, absolute, the live client's own, nested folders
local SHAPES = {
	{ "relative (the suite)", "stack traceback:\n\tWuber/Core/Runtime.lua:493: in function 'Crumb'\n\tWuber/UI/Secure.lua:279: in function <Wuber/UI/Secure.lua:278>", "UI/Secure.lua:279" },
	{ "relative, no tab", "Wuber/Drive/Button.lua:651: in function 'apply'", "Drive/Button.lua:651" },
	{ "absolute with /", "x\n\tF:/work/Wuber-tree/Wuber/Drive/Invite.lua:12: in function 'go'", "Drive/Invite.lua:12" },
	{ "game, backslashes", "Interface\\AddOns\\Wuber\\Drive\\Invite.lua:212: in function 'go'", "Drive/Invite.lua:212" },
	{ "game, forward slashes", "Interface/AddOns/Wuber/Net/Beacons.lua:30: in function 'x'", "Net/Beacons.lua:30" },
	{ "[string] form", "[string \"@Wuber/UI/Secure.lua\"]:279: in function 'x'", "UI/Secure.lua:279" },
	{ "nested Wuber folders", "x\n\tF:\\copy\\Wuber\\Wuber\\Drive\\Invite.lua:12: in function 'go'", "Drive/Invite.lua:12" },
	{ "another addon is not Wuber's", "Interface\\AddOns\\MyWuber\\Thing.lua:9: in main chunk", nil },
}
test("blocked origin: the Wuber file:line is found in every shape of a stack line", function()
	local w, r = client()
	for _, s in ipairs(SHAPES) do
		r.W.crumbs = {}
		r.env.debugstack = function() return s[2] end
		r.W.Crumb("t")
		eq(r.W.crumbs[1].where, s[3], s[1])
	end
end)
