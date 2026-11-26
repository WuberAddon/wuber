-- tests/buttons/google_b4_rider_probes_test.lua: real-click probes for every control
-- returned by Lib.controls on home, home_search, home_empty, home_bounty, confirm,
-- worldmap, done_paid, done_unpaid, raincheck, plus a coverage gate.
local T = ...
local test, ok, eq = T.test, T.ok, T.eq
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)
local PROBES = assert(loadfile(T.dir .. "/buttons/probes/rider.lua"))()

local TARGET_SCREENS = {
	"home", "home_search", "home_empty", "home_bounty",
	"confirm", "worldmap", "done_paid", "done_unpaid", "raincheck",
}

local function demoDrivers(now)
	local t0 = now or 100
	return {
		["nia quill"] = {
			name = "Nia Quill", key = "nia quill", dest = "Undercity", price = 5000,
			state = "open", team = 3, service = "Nia's Portals", heard = t0, ver = "2.3.0", badge = "skull",
		},
		["mia runner"] = {
			name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000,
			state = "open", team = 3, service = "Mia's Rides", heard = t0, ver = "2.3.0", badge = "bolt",
		},
		["bob stone"] = {
			name = "Bob Stone", key = "bob stone", dest = "Ratchet", price = 6000,
			state = "open", team = 1, service = "Bob's Rides", heard = t0, badge = "star",
		},
		["ivy moss"] = {
			name = "Ivy Moss", key = "ivy moss", dest = "Booty Bay", price = 7500,
			state = "busy", team = 2, service = "Ivy's Express", heard = t0, queue = 2, badge = "flame",
		},
	}
end

local function showScreen(sid)
	local ctx = Lib.newWorld()
	local c, w, W = ctx.c, ctx.w, ctx.W
	if sid == "worldmap" then
		W.db.pos = { "TOPLEFT", "TOPLEFT", 500, -80 }
	end
	W.UI.Toggle(true)
	if W.UI.EndSplash then pcall(W.UI.EndSplash) end
	if W.UI.EndCoach then pcall(W.UI.EndCoach) end
	local now = W.Now and W.Now() or 100
	if sid == "home" or sid == "home_search" or sid == "worldmap" or sid == "confirm" then
		W.drivers = demoDrivers(now)
	elseif sid == "home_empty" or sid == "home_bounty" then
		W.drivers = {}
	end
	if sid == "home_bounty" then
		local t = os.time()
		W.Bounty.Mine = function()
			return { place = "Gadgetzan", copper = 5000, at = t - 120, left = 1680 }
		end
	end
	if sid == "home_search" then
		W.UI.SetSearch("Undercity")
	end
	if sid == "confirm" then
		W.UI.Show("confirm", "mia runner")
	elseif sid == "done_paid" then
		W.drivers = demoDrivers(now)
		W.InGroup = function() return true end
		W.ride = {
			id = "rc_done_paid", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity",
			price = 5000, state = "done", at = now, payee = "Mia Runner", payto = "Mia",
			service = "Mia's Rides", paid = 6000, saved = 600, stars = 5, rated = true,
		}
		W.UI.Show("done")
	elseif sid == "done_unpaid" then
		W.drivers = demoDrivers(now)
		W.ride = {
			id = "rc_done_unpaid", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity",
			price = 5000, state = "done", at = now, payee = "Mia Runner", payto = "Mia",
			service = "Mia's Rides", unpaid = true,
		}
		W.UI.Show("done")
	elseif sid == "raincheck" then
		W.drivers = demoDrivers(now)
		local t = os.time()
		W.Raincheck.Mine = function()
			return {
				{ id = "rc_offer_1", state = "offered", driver = "Mia Runner", service = "Mia's Rides", cover = 5000, expires = t + 7 * 86400 },
			}
		end
		W.UI.Show("home")
		if W.UI.RefreshNow then W.UI.RefreshNow() end
		W.UI.RaincheckOffer()
	else
		if sid ~= "confirm" then W.UI.Show("home") end
	end
	if sid == "worldmap" then
		if W.UI.Fold then
			W.UI.Fold.Fits = function() return true end
			if not W.UI.Fold.IsUnfolded() then W.UI.Fold.Toggle() end
		end
		w:advance(0.5)
		local WM = W.Mod("UI.Rider.WorldMap")
		if WM and WM.Show then WM.Show("world") end
	end
	w:advance(1)
	if W.UI.RefreshNow then W.UI.RefreshNow() end
	return ctx
end

local function findControl(ctx, id)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if ctl.id == id then return ctl end
	end
	return nil
end

local function snapshotBefore(ctx)
	local favCount = 0
	for _, v in pairs(ctx.W.db.favs or {}) do
		if v then favCount = favCount + 1 end
	end
	return {
		sig = Lib.signature(ctx),
		shown = ctx.W.UI.IsShown(),
		favCount = favCount,
		favMia = ctx.W.db.favs["mia runner"] == true,
	}
end

for _, row in ipairs(PROBES) do
	if not row.skip then
		test("b4 probe: " .. row.on .. " -> " .. row.id, function()
			local ctx = showScreen(row.on)
			local ctl = findControl(ctx, row.id)
			ok(ctl ~= nil, row.id .. " found on " .. row.on)
			ok(not ctl.protected, row.id .. " must not be protected when clicked")
			local good, taker = Lib.judgeTaker(ctx, ctl)
			ok(good, row.id .. " on " .. row.on .. " is covered by " .. Lib.describe(taker))
			local before = snapshotBefore(ctx)
			ctx.ctl = ctl
			ctx.c:clickOn(ctl.f)
			ctx.w:advance(0.6)
			ctx.sig = Lib.signature(ctx)
			row.check(ctx, before)
			eq(#ctx.w.errors, 0, "no Lua errors (" .. table.concat(ctx.w.errors, "; ") .. ")")
		end)
	end
end

test("b4 probe gate: every control on the 9 rider screens has a row and no row is stale", function()
	local byId = {}
	for _, row in ipairs(PROBES) do
		ok(row.id and row.on, "every row has id and on")
		ok(byId[row.id] == nil, "duplicate probe row for " .. tostring(row.id))
		if row.skip then
			ok(row.skip ~= "", "skip row needs a non-empty reason: " .. tostring(row.id))
		else
			ok(type(row.does) == "string" and row.does ~= "", "probe row needs does: " .. tostring(row.id))
			ok(type(row.check) == "function", "probe row needs check: " .. tostring(row.id))
		end
		byId[row.id] = row
	end

	local seen = {}
	local missing = {}
	for _, sid in ipairs(TARGET_SCREENS) do
		local ctx = showScreen(sid)
		for _, ctl in ipairs(Lib.controls(ctx)) do
			seen[ctl.id] = seen[ctl.id] or sid
			if not byId[ctl.id] then
				missing[#missing + 1] = ctl.id .. " (on " .. sid .. ")"
			end
		end
		eq(#ctx.w.errors, 0, "no Lua errors building " .. sid)
	end

	local stale = {}
	for _, row in ipairs(PROBES) do
		if not seen[row.id] then
			stale[#stale + 1] = row.id .. " (expected on " .. row.on .. ")"
		end
	end
	table.sort(missing)
	table.sort(stale)
	ok(#missing == 0, #missing .. " control(s) with no probe row:\n  " .. table.concat(missing, "\n  "))
	ok(#stale == 0, #stale .. " stale probe row(s):\n  " .. table.concat(stale, "\n  "))
end)
