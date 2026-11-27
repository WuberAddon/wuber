-- tests/buttons/google_b4_rider_probes_test.lua: real-click probes for every control
-- returned by Lib.controls via Lib.screens/Lib.show on home, home_search, home_empty,
-- home_bounty, confirm, worldmap, done_paid, done_unpaid, raincheck, plus a coverage gate.
local T = ...
local test, ok, eq = T.test, T.ok, T.eq
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)
local PROBES = assert(loadfile(T.dir .. "/buttons/probes/rider.lua"))()

local TARGET_SCREENS = {
	"home", "home_search", "home_empty", "home_bounty",
	"confirm", "worldmap", "done_paid", "done_unpaid", "raincheck",
}

local function showScreen(sid)
	local ctx = Lib.newWorld()
	local target
	for _, s in ipairs(Lib.screens(ctx)) do
		if s.id == sid then target = s break end
	end
	ok(target ~= nil, "tour screen exists: " .. tostring(sid))
	local shown, why = Lib.show(ctx, target)
	ok(shown, "Lib.show(" .. tostring(sid) .. ") failed: " .. tostring(why))
	return ctx
end

local function matchesRow(ctl, row)
	if ctl.id ~= row.id then return false end
	if row.srcMatch and not tostring(ctl.src or ""):find(row.srcMatch) then return false end
	return true
end

local function findControl(ctx, row)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if matchesRow(ctl, row) then return ctl end
	end
	return nil
end

local function rowKey(row)
	return row.srcMatch and (row.id .. " [" .. row.srcMatch .. "]") or row.id
end

for _, row in ipairs(PROBES) do
	if not row.skip then
		test("b4 probe: " .. row.on .. " -> " .. rowKey(row), function()
			local ctx = showScreen(row.on)
			if row.setup then row.setup(ctx) end
			local ctl = findControl(ctx, row)
			ok(ctl ~= nil, rowKey(row) .. " found on " .. row.on)
			ok(not ctl.protected, rowKey(row) .. " must not be protected when clicked")
			local good, taker = Lib.judgeTaker(ctx, ctl)
			ok(good, rowKey(row) .. " on " .. row.on .. " is covered by " .. Lib.describe(taker))
			ctx.ctl = ctl
			ctx.c:clickOn(ctl.f)
			ctx.w:advance(0.6)
			row.check(ctx)
			eq(#ctx.w.errors, 0, "no Lua errors (" .. table.concat(ctx.w.errors, "; ") .. ")")
		end)
	end
end

test("b4 probe gate: every control on the 9 rider screens has a row and no row is stale", function()
	local byKey = {}
	for _, row in ipairs(PROBES) do
		ok(row.id and row.on, "every row has id and on")
		local k = rowKey(row)
		ok(byKey[k] == nil, "duplicate probe row for " .. k)
		if row.skip then
			ok(row.skip ~= "", "skip row needs a non-empty reason: " .. k)
		else
			ok(type(row.does) == "string" and row.does ~= "", "probe row needs does: " .. k)
			ok(type(row.check) == "function", "probe row needs check: " .. k)
		end
		byKey[k] = row
	end

	local matched = {}
	local missing = {}
	local ctx = Lib.newWorld()
	local byScreen = {}
	for _, s in ipairs(Lib.screens(ctx)) do byScreen[s.id] = s end

	for _, sid in ipairs(TARGET_SCREENS) do
		local s = byScreen[sid]
		ok(s ~= nil, "tour screen exists: " .. sid)
		local shown, why = Lib.show(ctx, s)
		ok(shown, "Lib.show(" .. sid .. ") failed: " .. tostring(why))
		for _, ctl in ipairs(Lib.controls(ctx)) do
			local foundRow
			for _, row in ipairs(PROBES) do
				if matchesRow(ctl, row) then
					foundRow = row
					matched[rowKey(row)] = true
				end
			end
			if not foundRow then
				missing[#missing + 1] = ctl.id .. " @ " .. tostring(ctl.src) .. " (on " .. sid .. ")"
			end
		end
	end
	eq(#ctx.w.errors, 0, "no Lua errors during Lib.show walk")

	local stale = {}
	for _, row in ipairs(PROBES) do
		local k = rowKey(row)
		if not matched[k] then
			stale[#stale + 1] = k .. " (expected on " .. row.on .. ")"
		end
	end
	table.sort(missing)
	table.sort(stale)
	ok(#missing == 0, #missing .. " control(s) with no probe row:\n  " .. table.concat(missing, "\n  "))
	ok(#stale == 0, #stale .. " stale probe row(s):\n  " .. table.concat(stale, "\n  "))
end)
