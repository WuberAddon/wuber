-- E3b-11c: hunt layout allow-list guards for F033 (splash) and F037-F042/F049 (finding-screen radar corner),
-- while keeping real regressions (HUNT-116, E3b-01, non-splash Phone chrome) unallowed. Loaded by tests/run.lua.
local T = ...
local test, ok, eq = T.test, T.ok, T.eq

-- guard: the allow list is a test-tree tool that this test loads from the target, so the addon base cannot fail it; it keeps real regressions unallowed
test("e3b-11c: hunt allow-list covers splash (F033) and finding radar corner (F037-F042, F049) without masking regressions", function()
	local U = dofile("tests/hunt/lib/universal_util.lua")

	-- F033: splash covers the window on purpose
	ok(U.allowed("phone/folded", {
		kind = "chrome",
		key = "Phone.lua:52 Frame",
		what = 'Phone.lua:52 Frame "Summons, on demand"',
		detail = "in the place of the header (32 x 32)",
	}) ~= nil, "F033 splash chrome is allowed")

	-- F037-F042, F049: finding-screen radar corner (Fold.Page() == "confirm" in hunt)
	ok(U.allowed("confirm/folded", {
		kind = "boxes",
		key = "Confirm.lua:648(Widgets.lua) Frame over Confirm.lua:698 Frame",
		what = 'Confirm.lua:648(Widgets.lua) Frame "Silver rider"',
		detail = "half over Confirm.lua:698 Frame",
	}) ~= nil, "finding tier chip over radar corner is allowed")

	ok(U.allowed("confirm/folded", {
		kind = "boxes",
		key = "Window.lua:730(Widgets.lua) Button over Confirm.lua:698 Frame",
		what = "Window.lua:730(Widgets.lua) Button",
		detail = "half over Confirm.lua:698 Frame",
	}) ~= nil, "finding window header button over radar corner is allowed")

	ok(U.allowed("confirm/folded", {
		kind = "boxes",
		key = "Phone.lua:175 Button over Confirm.lua:698 Frame",
		what = "Phone.lua:175 Button",
		detail = "half over Confirm.lua:698 Frame",
	}) ~= nil, "finding fold button over radar corner is allowed")

	ok(U.allowed("confirm/folded", {
		kind = "chrome",
		key = "Confirm.lua:698 Frame",
		what = "Confirm.lua:698 Frame",
		detail = "in the place of the header (32 x 32)",
	}) ~= nil, "finding radar chrome is allowed")

	-- Real regressions must still fail
	eq(U.allowed("confirm/folded", {
		kind = "boxes",
		key = "Confirm.lua:192(Tokens.lua) Frame over Confirm.lua:698 Frame",
		what = 'Confirm.lua:192(Tokens.lua) Frame "Summon to Ratchet"',
		detail = "half over Confirm.lua:698 Frame",
	}), nil, "HUNT-116 portal pin under sheet must not be allowed")

	eq(U.allowed("phone/folded", {
		kind = "boxes",
		key = "Bug.lua:426(Forms.lua) fill over Ride.lua:663(Widgets.lua) Button",
		what = "Bug.lua:426(Forms.lua) fill",
		detail = "half over Ride.lua:663(Widgets.lua) Button",
	}), nil, "E3b-01 Bug sheet over Ride button must not be allowed")

	eq(U.allowed("phone/folded", {
		kind = "chrome",
		key = "Phone.lua:263 Frame",
		what = "Phone.lua:263 Frame",
		detail = "in the place of the header (32 x 32)",
	}), nil, "non-splash Phone chrome must not be allowed")
end)
