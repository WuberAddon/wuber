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

local function findScreen(ctx, id)
	for _, s in ipairs(Lib.screens(ctx)) do
		if s.id == id then return s end
	end
end

local function findControl(ctx, id)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if ctl.id == id then return ctl end
	end
end

local function sentCount(w)
	return #(w.addonLog or {}) + #(w.whispers or {}) + #(w.chatPosts or {}) + #(w.invites or {}) + #(w.macros or {})
end

for _, row in ipairs(PROBES) do
	if not row.skip then
		test("b4 probe: " .. row.id .. " (" .. row.on .. ")", function()
			local ctx = Lib.newWorld()
			local s = findScreen(ctx, row.on)
			ok(s ~= nil, "screen exists: " .. row.on)
			local shown, why = Lib.show(ctx, s)
			ok(shown, "screen shown: " .. row.on .. " (" .. tostring(why) .. ")")
			local ctl = findControl(ctx, row.id)
			ok(ctl ~= nil, "control found: " .. row.id .. " on " .. row.on)
			ok(not ctl.protected, "non-skip control must not be protected: " .. row.id)

			local good, taker = Lib.judgeTaker(ctx, ctl)
			ok(good, row.id .. " on " .. row.on .. ": click covered by " .. Lib.describe(taker))

			local err0 = #ctx.w.errors
			local sent0 = sentCount(ctx.w)
			local before = { sig = Lib.signature(ctx), ctl = ctl }
			ctx.c:clickOn(ctl.f)
			ctx.w:advance(1)
			before.afterSig = Lib.signature(ctx)

			local pass, msg = row.check(ctx, before)
			ok(pass == true, row.id .. " (" .. row.on .. "): " .. (msg or row.does))
			eq(#ctx.w.errors - err0, 0, row.id .. ": no Lua errors")
			eq(sentCount(ctx.w) - sent0, 0, row.id .. ": no network/chat sends")
		end)
	end
end

test("b4 probe gate: every control on the 13 driver screens has one probe row", function()
	local byId = {}
	local dupes = {}
	for _, row in ipairs(PROBES) do
		if byId[row.id] then
			dupes[#dupes + 1] = row.id
		end
		byId[row.id] = row
	end
	eq(#dupes, 0, "duplicate probe rows: " .. table.concat(dupes, ", "))

	local seen = {}
	local missing = {}
	for _, sid in ipairs(SCREENS) do
		local ctx = Lib.newWorld()
		local s = findScreen(ctx, sid)
		ok(s ~= nil, "screen exists: " .. sid)
		local shown, why = Lib.show(ctx, s)
		ok(shown, "screen shown: " .. sid .. " (" .. tostring(why) .. ")")
		for _, ctl in ipairs(Lib.controls(ctx)) do
			seen[ctl.id] = sid
			if not byId[ctl.id] then
				missing[#missing + 1] = ctl.id .. " (on " .. sid .. ")"
			end
		end
	end

	local stale = {}
	for _, row in ipairs(PROBES) do
		if not seen[row.id] then
			stale[#stale + 1] = row.id
		end
	end
	table.sort(missing)
	table.sort(stale)
	eq(#missing, 0, "controls missing probe row: " .. table.concat(missing, "; "))
	eq(#stale, 0, "stale probe rows: " .. table.concat(stale, "; "))
end)
