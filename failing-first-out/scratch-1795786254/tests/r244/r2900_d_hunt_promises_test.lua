local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local root = T.dir .. "/.."

-- Job 2900 group D: the hunt promises that were wrong, not the addon. Each repro is the hunt's own failing file (copied from the
-- hunt-r3 and hunt-big worktrees into tests/hunt/repro_r2900/); it exits 0 and prints PASS when the promise now holds.
local function lua() return (arg and arg[-1]) or "lua5.1" end
local DIR = "tests/hunt/repro_r2900/"

local function runRepro(name)
	local cmd = ('"%s" "%s%s" 2>&1'):format(lua():gsub("\\", "/"), DIR, name)
	local p = io.popen("cd " .. root .. " && " .. cmd)
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end

-- the repro files of one promise (the folder is listed by the shell: the files are named <promise id>--<situation>.lua)
local function reproFiles(id)
	local p = io.popen("cd " .. root .. " && ls " .. DIR)
	local list, out = p and p:read("*a") or "", {}
	if p then p:close() end
	for name in list:gmatch("[^\r\n]+") do
		if name:sub(1, #id + 2) == id .. "--" or name == id .. ".lua" then out[#out + 1] = name end
	end
	return out
end

local function holds(id)
	local files = reproFiles(id)
	ok(#files > 0, "repro files for " .. id)
	for _, f in ipairs(files) do
		local out = runRepro(f)
		ok(out:find("^PASS " .. id:gsub("%.", "%%."), 1) or out:find("PASS " .. id, 1, true), f .. ": " .. out)
	end
end

-- guard: infra, failed before because the promise did not scroll Trips to the Milestones the scroll cue hides
test("r2900 d: simple.rider_leaves_out_and_back: a rider in Simple loses the Milestones and Advanced brings them back (folded Trips: the player scrolls to them)", function()
	holds("simple.rider_leaves_out_and_back")
end)

-- guard: infra, failed before because the first reading was taken before the button had settled
test("r2900 d: simple.switch_in_combat: switching modes in combat leaves the big summon button where it was", function()
	holds("simple.switch_in_combat")
end)

-- guard: infra, failed before because the promise counted a ride\'s savedAt stamp and a timed-out ride the reload drops
test("r2900 d: simple.switch_changes_nothing: switching Simple/Advanced changes no saved setting (a ride\'s savedAt clock and a timed-out ride dropped by /reload are not the switch)", function()
	holds("simple.switch_changes_nothing")
end)

-- guard: infra, failed before because the promise expected the Ride tab even for a driver in a ride (Drive tab)
test("r2900 d: help.back_returns: Back on the help page returns to the tab the situation opened", function()
	holds("help.back_returns")
end)

-- guard: infra, failed before because the promise pressed Escape once with the login tip sheet holding the window\'s Escape slot
test("r2900 d: phone.escape_closes_keeps_ride: Escape closes Wuber and the ride carries on (a card over the page takes the first Escape alone)", function()
	holds("phone.escape_closes_keeps_ride")
end)

-- guard: infra, failed before because the promise expected an invite while another rider was already being invited
test("r2900 d: careful.unsure_waits_as_lead: a click on a lead invites it, or queues it while another rider is being served", function()
	holds("careful.unsure_waits_as_lead")
end)

-- guard: infra, failed before because the promise clicked the hint\'s x while it was scrolled out of the list
test("r2900 d: home.openmap_hint_gone_for_good: closing the Get OpenMap hint hides it for good (the player scrolls the hint into view first)", function()
	holds("home.openmap_hint_gone_for_good")
end)
