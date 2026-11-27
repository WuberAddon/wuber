-- Event 3b-11b: verify the updated Q3 outdated promises (F015-F018, F025, F026, N1) pass on 2.4 code
-- where the old promises failed on 0f5177e1, and still fail if the 2.4 behaviour breaks.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function loadPromise(file, id)
	local list = {}
	local Hunt = { promise = function(p) list[#list + 1] = p end }
	local fn = assert(loadfile(file))()
	fn(Hunt)
	for _, p in ipairs(list) do
		if p.id == id then return p end
	end
	error("promise not found: " .. tostring(id) .. " in " .. tostring(file))
end

-- guard: the row menu was already right on the base; the old promise was outdated, not the addon
test("e3b_11b: F025 queue.row_menu repro passes on 2.4 and checks row tap invites + Options menu", function()
	local Hunt = dofile("tests/hunt/lib.lua")
	local rc = Hunt.repro({
		addon = "Wuber",
		id = "queue.row_menu--opt_autoIn-off--role-warlock",
		promise = "queue.row_menu",
		seed = 308455638,
		seen = "You tap a waiting rider's row and the menu has no Mark as paid.",
		situation = { opt_autoInvite = "off", role = "warlock" },
		text = "With whisper invites off, tapping a queued rider's row invites them (HUNT-12), and tapping Options opens a menu offering Mark as paid, Not a rider, Take off the list and Block; Take off the list works.",
	})
	eq(rc, 0, "queue.row_menu repro passes on 2.4")
end)

-- guard: the first-open tips were already right on the base (HR-1); the old promise was outdated, not the addon
test("e3b_11b: F026 tips.first_open (drive_direct) repro passes on 2.4 and fails if HR-1 breaks", function()
	local Hunt = dofile("tests/hunt/lib.lua")
	local rc = Hunt.repro({
		addon = "Wuber",
		id = "tips.first_open--phone-drive_direct--session-reload",
		promise = "tips.first_open",
		seed = 1400721139,
		seen = "You log in and /reload, open Wuber for the first time (it opens on the Drive tab) and no tip card shows.",
		situation = { phone = "drive_direct", session = "reload" },
		text = "The first time you open Wuber after logging in, you see one tip card, whatever tab the phone opens on — except when opened directly on Drive (/wuber drive or minimap Drive click), where it stays on Drive and shows the tip at the next open (HR-1).",
	})
	eq(rc, 0, "tips.first_open drive_direct repro passes on 2.4")

	-- negative check: if HR-1 breaks (tab flips away from Drive), the updated promise fails
	local p = loadPromise("tests/promises/tips.lua", "tips.first_open")
	local failed = false
	local fakeCtx = {
		sit = { phone = "drive_direct" },
		facts = {},
		me = { player = { combat = false } },
		W = {
			db = { coach = true, tipsOn = true },
			UI = { IsShown = function() return true end },
		},
		mod = function(_, name)
			if name == "UI.Tips" then
				return { Card = function() return nil end, Next = function() return "t1" end }
			elseif name == "UI.Kit" then
				return { ui = { tab = "Ride", screen = "home" }, rideActive = function() return false end }
			end
		end,
		advance = function() end,
		texts = function() return {} end,
		fail = function(_, msg) failed = true; error(msg, 0) end,
		na = function(_, msg) error("na: " .. tostring(msg), 0) end,
		cannot = function(_, msg) error("cannot: " .. tostring(msg), 0) end,
	}
	pcall(p.check, fakeCtx)
	ok(failed, "tips.first_open fails if drive_direct flips off Drive")
end)

-- guard: the FAB-02 Close anyway question is addon code already on the base; the repros were outdated, not the addon
test("e3b_11b: F015-F018 FAB-02 Close anyway? repros pass on 2.4", function()
	local Hunt = dofile("tests/hunt/lib.lua")
	local cases = {
		{
			id = "driver.open_button--ride-requested--role-warlock",
			promise = "driver.open_button",
			seed = 1097666281,
			seen = "You tap Close on the Drive tab and Wuber still thinks you are open.",
			situation = { ride = "requested", role = "warlock" },
		},
		{
			id = "earnings.shift_card--phone-drive--ride-paid--role-warlock",
			promise = "earnings.shift_card",
			seed = 263908752,
			seen = "You close after a shift with 1 paid ride(s) and no Shift complete card shows.",
			situation = { phone = "drive", ride = "paid", role = "warlock" },
		},
		{
			id = "cut.shift_card_split--phone-drive--ride-paid--role-warlock--saved-acct4_main",
			promise = "cut.shift_card_split",
			seed = 2015138183,
			seen = "You close a shift that took 50s and the shift log holds free.",
			situation = { phone = "drive", ride = "paid", role = "warlock", saved = "acct4_main" },
		},
	}
	for _, c in ipairs(cases) do
		c.addon = "Wuber"
		eq(Hunt.repro(c), 0, c.promise .. " passes on 2.4")
	end
end)

-- guard: the driver can already remove a rider with kickAfter off on the base; the old promise was outdated, not the addon
test("e3b_11b: N1 nowayout.driver_can_remove_rider passes with kickAfter off and fails if Plan text breaks", function()
	local p = loadPromise("tests/promises/nowayout.lua", "nowayout.driver_can_remove_rider")
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	local DR = d.W.Drive
	DR.opts().kickAfter = false
	d.W.Driver.SetOnline(true)
	w:advance(1)
	w:botWhisper(r.player.name, d, "summon pls")
	w:advance(2)
	w:invite(d, r.player.name)
	if r.env.AcceptGroup then r.env.AcceptGroup() end
	w:advance(1)

	d.W.UI.Toggle(true)
	d.W.UI.ShowDrive("console")
	w:advance(1)
	local failed = false
	local origPlan = DR.Plan
	DR.Plan = function() return { title = "Open - waiting for riders", sub = "wrong" } end
	local fakeCtx = {
		w = w,
		me = d,
		peers = { rider = r },
		W = d.W,
		advance = function(_, s) w:advance(s) end,
		texts = function() return { "Riders" } end,
		note = function() end,
		fail = function(_, msg) failed = true; error(msg, 0) end,
		na = function(_, msg) error("na: " .. tostring(msg), 0) end,
		cannot = function(_, msg) error("cannot: " .. tostring(msg), 0) end,
	}
	local okRun, errRun = pcall(p.check, fakeCtx)
	ok(not okRun and failed, "nowayout.driver_can_remove_rider fails when kickAfter=false Plan text breaks: " .. tostring(errRun))

	DR.Plan = origPlan
	-- now restore and run with real Plan(): should pass
	local r2 = T.rider(w, "Bob Rider")
	w:botWhisper(r2.player.name, d, "summon pls")
	w:advance(2)
	w:invite(d, r2.player.name)
	if r2.env.AcceptGroup then r2.env.AcceptGroup() end
	w:advance(1)
	fakeCtx.peers.rider = r2
	failed = false
	p.check(fakeCtx)
	ok(not failed, "nowayout.driver_can_remove_rider passes with kickAfter=false and real Plan()")
	T.clean(w)
end)
