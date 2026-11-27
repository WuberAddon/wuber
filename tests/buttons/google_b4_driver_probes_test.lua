-- tests/buttons/google_b4_driver_probes_test.lua: probes every control returned by Lib.controls
-- on the 13 driver screens and verifies 100% coverage with a gate test.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)
local PROBES = assert(loadfile(T.dir .. "/buttons/probes/driver.lua"))()

local SCREENS = {
	"console_open",
	"console_closed",
	"button_waiting",
	"row_marks",
	"note",
	"customers",
	"customers_queued",
	"crew",
	"raid",
	"demand",
	"pvp",
	"wizard_notlock",
	"wizard_summoner",
}

local function rowKey(row)
	return row.srcMatch and (row.id .. "|" .. row.srcMatch) or row.id
end

local function findScreen(ctx, id)
	for _, s in ipairs(Lib.screens(ctx)) do
		if s.id == id then return s end
	end
end

local function findControl(ctx, row)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if ctl.id == row.id and (not row.srcMatch or ctl.src:find(row.srcMatch)) then
			return ctl
		end
	end
end

local function matchesRow(ctl, row)
	return ctl.id == row.id and (not row.srcMatch or ctl.src:find(row.srcMatch))
end

local function sentCount(w)
	return #(w.addonLog or {}) + #(w.whispers or {}) + #(w.chatPosts or {}) + #(w.invites or {}) + #(w.macros or {})
end

for _, row in ipairs(PROBES) do
	if not row.skip then
		local label = row.srcMatch and (row.id .. " [" .. row.srcMatch .. "]") or row.id
		test("b4 probe: " .. label .. " (" .. row.on .. ")", function()
			local ctx = Lib.newWorld()
			local s = findScreen(ctx, row.on)
			ok(s ~= nil, "screen exists: " .. row.on)
			local shown, why = Lib.show(ctx, s)
			ok(shown, "screen shown: " .. row.on .. " (" .. tostring(why) .. ")")
			if row.setup then row.setup(ctx, findControl) end

			local ctl = findControl(ctx, row)
			ok(ctl ~= nil, "control found: " .. label .. " on " .. row.on)
			ok(not ctl.protected, "non-skip control must not be protected: " .. label)

			local good, taker = Lib.judgeTaker(ctx, ctl)
			ok(good, label .. " on " .. row.on .. ": click covered by " .. Lib.describe(taker))

			local err0 = #ctx.w.errors
			local sent0 = sentCount(ctx.w)
			local before = { sig = Lib.signature(ctx), ctl = ctl }
			ctx.c:clickOn(ctl.f)
			ctx.w:advance(1)

			local pass, msg = row.check(ctx, before)
			ok(pass == true, label .. " (" .. row.on .. "): " .. (msg or row.does))
			eq(#ctx.w.errors - err0, 0, label .. ": no Lua errors")
			eq(sentCount(ctx.w) - sent0, 0, label .. ": no network/chat sends")
		end)
	end
end

test("b4 probe gate: every control on the 13 driver screens has one probe row", function()
	local byKey = {}
	local dupes = {}
	for _, row in ipairs(PROBES) do
		local k = rowKey(row)
		if byKey[k] then
			dupes[#dupes + 1] = k
		end
		byKey[k] = row
	end
	eq(#dupes, 0, "duplicate probe rows: " .. table.concat(dupes, ", "))

	local matched = {}
	local missing = {}
	for _, sid in ipairs(SCREENS) do
		local ctx = Lib.newWorld()
		local s = findScreen(ctx, sid)
		ok(s ~= nil, "screen exists: " .. sid)
		local shown, why = Lib.show(ctx, s)
		ok(shown, "screen shown: " .. sid .. " (" .. tostring(why) .. ")")
		for _, ctl in ipairs(Lib.controls(ctx)) do
			local hit = nil
			for _, row in ipairs(PROBES) do
				if matchesRow(ctl, row) then
					hit = row
					matched[rowKey(row)] = sid
				end
			end
			if not hit then
				missing[#missing + 1] = ctl.id .. " [" .. ctl.src .. "] (on " .. sid .. ")"
			end
		end
	end

	local stale = {}
	for _, row in ipairs(PROBES) do
		if not matched[rowKey(row)] then
			stale[#stale + 1] = rowKey(row)
		end
	end
	table.sort(missing)
	table.sort(stale)
	eq(#missing, 0, "controls missing probe row: " .. table.concat(missing, "; "))
	eq(#stale, 0, "stale probe rows: " .. table.concat(stale, "; "))
end)
