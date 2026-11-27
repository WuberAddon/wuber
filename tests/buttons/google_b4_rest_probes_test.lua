-- Tests: every control returned by Lib.controls on earnings, earnings_heatmap,
-- earnings_tips, earnings_empty, shift, trips, wrapped, wrapped_summary, help,
-- help_bug, plus window header/tab controls on home, has a probe or skip row
-- in tests/buttons/probes/rest.lua and passes its real-click check.
local T = ...
local test, ok, eq = T.test, T.ok, T.eq
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)
local PROBES = assert(loadfile(T.dir .. "/buttons/probes/rest.lua"))()

local TARGET_SCREENS = {
	"earnings", "earnings_heatmap", "earnings_tips", "earnings_empty",
	"shift", "trips", "wrapped", "wrapped_summary", "help", "help_bug",
}

local function findScreen(ctx, id)
	for _, s in ipairs(Lib.screens(ctx)) do
		if s.id == id then return s end
	end
end

local function findControl(ctx, id, srcMatch)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if ctl.id == id and (not srcMatch or ctl.src:find(srcMatch)) then
			return ctl
		end
	end
end

local function rowKey(id, srcMatch)
	return id .. "::" .. (srcMatch or "")
end

for _, row in ipairs(PROBES) do
	if not row.skip then
		local label = row.srcMatch and (row.id .. " [" .. row.srcMatch .. "]") or row.id
		test("b4 probe: " .. row.on .. " - " .. label .. " (" .. row.does .. ")", function()
			local ctx = Lib.newWorld()
			local s = findScreen(ctx, row.on)
			ok(s ~= nil, "screen exists: " .. row.on)
			local shown, why = Lib.show(ctx, s)
			ok(shown, "screen shown: " .. row.on .. " (" .. tostring(why) .. ")")
			local ctl = findControl(ctx, row.id, row.srcMatch)
			ok(ctl ~= nil, "control found: " .. label .. " on " .. row.on)
			local before = row.before and row.before(ctx, ctl, Lib) or {}
			ctx.c:clickOn(ctl.f)
			ctx.w:advance(0.5)
			row.check(ctx, before, ctl)
			eq(#ctx.w.errors, ctx.errors0, "no Lua errors (" .. table.concat(ctx.w.errors, "; ") .. ")")
		end)
	end
end

test("b4 probe gate: every control on target screens and home header has a probe or skip row", function()
	local ctx = Lib.newWorld()
	local byId = {}
	local byKey = {}
	for _, row in ipairs(PROBES) do
		byId[row.id] = byId[row.id] or {}
		byId[row.id][#byId[row.id] + 1] = row
		byKey[rowKey(row.id, row.srcMatch)] = row
	end

	local missing = {}
	local seenKeys = {}

	-- 1. Window header, tab bar, and phone chrome on home
	local home = findScreen(ctx, "home")
	ok(home ~= nil and Lib.show(ctx, home), "home screen shown")
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if Lib.isChrome(ctl.id) then
			local matched = false
			for _, row in ipairs(byId[ctl.id] or {}) do
				if row.on == "home" and (not row.srcMatch or ctl.src:find(row.srcMatch)) then
					matched = true
					seenKeys[rowKey(row.id, row.srcMatch)] = true
				end
			end
			if not matched then
				missing[#missing + 1] = "home: " .. ctl.id .. " (" .. ctl.src .. ")"
			end
		end
	end

	-- 2. Non-chrome controls on the 10 target screens
	for _, sid in ipairs(TARGET_SCREENS) do
		local s = findScreen(ctx, sid)
		ok(s ~= nil, "target screen exists: " .. sid)
		local shown = Lib.show(ctx, s)
		if shown then
			for _, ctl in ipairs(Lib.controls(ctx)) do
				if not Lib.isChrome(ctl.id) then
					local matched = false
					for _, row in ipairs(byId[ctl.id] or {}) do
						if not row.srcMatch or ctl.src:find(row.srcMatch) then
							matched = true
							seenKeys[rowKey(row.id, row.srcMatch)] = true
						end
					end
					if not matched then
						missing[#missing + 1] = sid .. ": " .. ctl.id .. " (" .. ctl.src .. ")"
					end
				end
			end
		end
	end

	-- 3. Stale check: every probe row must match a control on its declared screen
	local stale = {}
	for _, row in ipairs(PROBES) do
		local k = rowKey(row.id, row.srcMatch)
		if not seenKeys[k] then
			stale[#stale + 1] = row.on .. ": " .. row.id
		end
	end

	table.sort(missing)
	table.sort(stale)
	ok(#missing == 0, #missing .. " control(s) with no probe row: " .. table.concat(missing, "; "))
	ok(#stale == 0, #stale .. " stale probe row(s): " .. table.concat(stale, "; "))
	eq(#ctx.w.errors, ctx.errors0, "no Lua errors during gate walk")
end)
