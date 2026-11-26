-- r49 group F: the outdated hunt promises of the driver side and the universal layout promise (F005, F033, F037-F042,
-- F049, N1). The base (event 3b winner, E3b-11a/b/c) already carries the updated promises and the hunt's own allow table
-- (tests/hunt/lib/universal_util.lua); these tests keep them there, and guard the neighbouring paths the E3b tests leave
-- out: auto-remove ON for N1, and the radar-corner allowance staying on the Finding-your-driver screen only.
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

-- guard: the base already passes this (E3b-11a updated the promise to "My other characters"); it keeps F005 from coming back
test("r49-f: F005 the crew wizard offers Just me, My friends help and My other characters (promise and repro)", function()
	local Hunt = dofile("tests/hunt/lib.lua")
	local rc = Hunt.repro({
		addon = "Wuber",
		id = "wizard.warlock_three_choices--phone-drive_wizard--role-warlock",
		promise = "wizard.warlock_three_choices",
		seed = 2145741390,
		seen = "A Warlock opens the crew wizard and the choice My own other characters is missing.",
		situation = { phone = "drive_wizard", role = "warlock" },
		text = "The crew wizard asks a Warlock Who summons with you? and offers three choices: Just me, My friends help, and My other characters.",
	})
	eq(rc, 0, "wizard.warlock_three_choices repro passes on the base code")
	local p = loadPromise("tests/promises/driver2.lua", "wizard.warlock_three_choices")
	ok(p.text:find("My other characters", 1, true), "the promise names the choice the wizard shows")
	ok(not p.text:find("My own other characters", 1, true), "the promise no longer asks for the old words")
end)

-- guard: the base already passes these (E3b-11c put the radar-corner and splash entries in the hunt's allow table)
test("r49-f: F033, F037-F042 the layout promise passes where the hunt found the splash and the radar-corner boxes", function()
	local Hunt = dofile("tests/hunt/lib.lua")
	local cases = {
		{ id = "universal.layout--after-minimap.right_click_driv-eb477a", seed = 1584541964, after = "minimap.right_click_driver_console", situation = {} },
		{ id = "universal.layout--combat-before--net-none--saved-acct3_rider--after-net.api_requ-d79b66-1e4f33", seed = 962348266, after = "net.api_request_reaches_addon", situation = { combat = "before", net = "none", saved = "acct3_rider" } },
		{ id = "universal.layout--net-oldpeer--place-fm_known--saved-acct3_rider--after-net.old_-14f178-1e4f33", seed = 1473591042, after = "net.old_peer_listed", situation = { net = "oldpeer", place = "fm_known", saved = "acct3_rider" } },
		{ id = "universal.layout--combat-before--net-oldpeer--saved-old--after-net.old_peer_listed-1e4f33", seed = 783255870, after = "net.old_peer_listed", situation = { combat = "before", net = "oldpeer", saved = "old" } },
		{ id = "universal.layout--fold-narrow--net-oldpeer--phone-home--ride-requested-1bcce4", seed = 372132124, situation = { fold = "narrow", net = "oldpeer", phone = "home", ride = "requested" } },
		{ id = "universal.layout--combat-after--net-none--after-net.api_request_reaches-1bcce4", seed = 1130185928, after = "net.api_request_reaches_addon", situation = { combat = "after", net = "none" } },
		{ id = "universal.layout--fold-narrow--net-oldpeer--tipsOn-off--after-net.old_peer_listed-1bcce4", seed = 57339038, after = "net.old_peer_listed", situation = { fold = "narrow", net = "oldpeer", tipsOn = "off" } },
	}
	for _, c in ipairs(cases) do
		c.addon = "Wuber"
		c.promise = "universal.layout"
		c.seen = "A layout problem (boxes)"
		eq(Hunt.repro(c), 0, c.id .. " passes on the base code")
	end
end)

-- guard: the base already passes this; it pins the neighbouring path, a corner hit that is NOT the radar's stays reported
test("r49-f: the hunt's radar-corner allowance covers only the Finding-your-driver confirm screen and only the radar frame", function()
	local U = dofile("tests/hunt/lib/universal_util.lua")
	local radar = { kind = "boxes", key = "Window.lua:730(Widgets.lua) Button over Confirm.lua:698 Frame", what = "Window.lua:730(Widgets.lua) Button", detail = "half over Confirm.lua:698 Frame" }
	ok(U.allowed("confirm/folded", radar) ~= nil, "the header button over the radar's corner is the meant overlap on confirm")
	eq(U.allowed("home/folded", radar), nil, "the same hit on another screen is still a finding")
	eq(U.allowed("trips/folded", radar), nil, "the same hit on Trips is still a finding")
	eq(U.allowed("confirm/folded", { kind = "boxes", key = "Window.lua:730(Widgets.lua) Button over Trips.lua:99 Frame", what = "Window.lua:730(Widgets.lua) Button", detail = "half over Trips.lua:99 Frame" }), nil,
		"a header button over any other frame on confirm is still a finding")
	eq(U.allowed("confirm/folded", { kind = "windows", key = "Confirm.lua:698 Frame over WuberFrame", what = "Confirm.lua:698 Frame", detail = "over the window" }), nil,
		"another kind of hit on the radar frame is still a finding")
end)

-- guard: the neighbouring path of N1 (E3b-11b tests auto-remove OFF): with auto-remove ON the big button offers Remove (/uninvite)
test("r49-f: N1 nowayout.driver_can_remove_rider with Remove riders after the thanks ON offers Remove and fails if it does not", function()
	local p = loadPromise("tests/promises/nowayout.lua", "nowayout.driver_can_remove_rider")
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	local DR = d.W.Drive
	DR.opts().kickAfter = true
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
	local fakeCtx = {
		w = w, me = d, peers = { rider = r }, W = d.W,
		advance = function(_, s) w:advance(s) end,
		texts = function() return { "Riders" } end,
		note = function() end,
		fail = function(_, msg) failed = true error(msg, 0) end,
		na = function(_, msg) error("na: " .. tostring(msg), 0) end,
		cannot = function(_, msg) error("cannot: " .. tostring(msg), 0) end,
	}
	local origPlan = DR.Plan
	DR.Plan = function() return { title = "Open - waiting for riders", sub = "no Remove here" } end
	local okRun = pcall(p.check, fakeCtx)
	ok(not okRun and failed, "with auto-remove on, a button that offers no Remove fails the promise")
	DR.Plan = origPlan
	-- (the first run took the first rider off the list: the real Plan is judged with a second rider)
	local r2 = T.rider(w, "Bob Rider")
	w:botWhisper(r2.player.name, d, "summon pls")
	w:advance(2)
	w:invite(d, r2.player.name)
	if r2.env.AcceptGroup then r2.env.AcceptGroup() end
	w:advance(1)
	fakeCtx.peers.rider = r2
	failed = false
	local okReal, err = pcall(p.check, fakeCtx)
	ok(okReal and not failed, "with auto-remove on, the real Plan offers Remove (/uninvite): " .. tostring(err))
	T.clean(w)
end)
