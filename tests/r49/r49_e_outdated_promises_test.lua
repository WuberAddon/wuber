-- r49 group E: the outdated hunt promises of the rider side (F002/F019, F004, F008, F009/F010, F011, F020, F024, F026, F029).
-- Each promise now says what 2.4 does (the judge ruled the old words outdated, not the game wrong). On this base the bugs are
-- already gone and the repro files in tools/hunt/known-gauntlet exit 0, so every test here passes on the base: a guard
-- that (1) the promise still states the 2.4 behaviour (words pinned, so nobody puts the old claim back) and (2) its own
-- check still passes in the situation the hunt found it in, with the same seed.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function loadPromise(file, id)
	local list = {}
	local Hunt = { promise = function(p) list[#list + 1] = p end }
	assert(loadfile(file))()(Hunt)
	for _, p in ipairs(list) do
		if p.id == id then return p end
	end
	error("promise not found: " .. tostring(id) .. " in " .. tostring(file))
end

-- id, file, [words the promise text must carry], [words it must not carry], repro runs { id, seed, situation }
local CASES = {
	{ "F002/F019 Why? link", "tests/promises/shell2.lua", "help.why_cant_i_see_anyone", { "Why%?", "How Wuber finds drivers" }, { "Why can't I see anyone" },
		{ { "help.why_cant_i_see_anyone--net-none--phone-home", 1778807212, { net = "none", phone = "home" } } } },
	{ "F019 empty help under the tip", "tests/promises/shell2.lua", "help.empty_help_not_hidden_by_tip", { "Why%?", "Ping drivers" }, { "Why can't I see anyone" },
		{ { "help.empty_help_not_hidden_by_tip--net-none--phone-home", 599103982, { net = "none", phone = "home" } } } },
	{ "F004 bounty chip minutes", "tests/promises/rider2.lua", "wish.chip_counts_down", { "minutes are left", "goes down" }, {},
		{ { "wish.chip_counts_down", 1941706229, {} } } },
	{ "F008 bird card stays until closed", "tests/promises/bird.lua", "bird.goes_by_itself", { "until you close it", "no timer" }, { "about ten seconds" },
		{ { "bird.goes_by_itself", 1273152262, {} } } },
	{ "F009/F010 bird card numbers and names", "tests/promises/bird.lua", "bird.says_the_numbers", { "first line", "second line", "price" }, { "what flying costs" },
		{ { "bird.says_the_numbers-4d1629", 1778789080, {} }, { "bird.says_the_numbers--net-many-237e50", 1272636674, { net = "many" } } } },
	{ "F011 no bird card on a short flight", "tests/promises/bird.lua", "bird.short_flight_no_card", { "driver's summon wait", "at least a minute" }, { "two%-minute" },
		{ { "bird.short_flight_no_card", 1240102758, {} } } },
	{ "F020 Tell me button", "tests/promises/home.lua", "home.bell_tells_me", { "Tell me" }, { "the bell" },
		{ { "home.bell_tells_me", 940514896, {} } } },
	{ "F024 unpaid end says no level progress", "tests/promises/payment.lua", "pay.unpaid_end", { "Not paid, so no level progress" }, { "does not count toward" },
		{ { "pay.unpaid_end--ride-arrived", 889628646, { ride = "arrived" } } } },
	{ "F026 first tip, HR-1", "tests/promises/tips.lua", "tips.first_open", { "HR%-1", "directly on Drive" }, {},
		{ { "tips.first_open--phone-drive_direct--session-reload", 1400721139, { phone = "drive_direct", session = "reload" } } } },
	{ "F029 Wrapped driver slide", "tests/promises/rider2.lua", "wrapped.driver_slide_when_you_drove", { "Behind the portal slide" }, { "Behind the Portal slide" },
		{ { "wrapped.driver_slide_when_you_drove--day-next_month", 1454237270, { day = "next_month" } } } },
}

for _, c in ipairs(CASES) do
	local name, file, pid, must, mustNot, runs = c[1], c[2], c[3], c[4], c[5], c[6]
	-- guard: the promise was brought up to date in the Event 3b round; this pins its 2.4 wording
	test("r49_e: " .. name .. ": the promise says what 2.4 does", function()
		local p = loadPromise(file, pid)
		for _, w in ipairs(must) do ok(p.text:find(w), pid .. " text must carry " .. w .. ": " .. p.text) end
		for _, w in ipairs(mustNot) do ok(not p.text:find(w), pid .. " text still carries the old words " .. w .. ": " .. p.text) end
	end)
	-- guard: the hunt's own repro passes on this code (the bug is gone, the old promise was what was wrong)
	test("r49_e: " .. name .. ": the hunt repro passes in the situation it was found in", function()
		for _, r in ipairs(runs) do
			local Hunt = dofile("tests/hunt/lib.lua")
			local rc = Hunt.repro({ addon = "Wuber", id = r[1], promise = pid, seed = r[2], seen = name, situation = r[3], text = loadPromise(file, pid).text })
			eq(rc, 0, name .. " repro " .. r[1])
		end
	end)
end

-- the neighbouring path: the same promise id run again with another seed still passes (not a one-seed pass)
-- guard: the promise must not depend on the seed the hunt found it with
test("r49_e: F008 and F011 bird promises pass with a second seed", function()
	local Hunt = dofile("tests/hunt/lib.lua")
	for _, r in ipairs({ { "bird.goes_by_itself", 7 }, { "bird.short_flight_no_card", 11 } }) do
		local file = "tests/promises/bird.lua"
		local rc = Hunt.repro({ addon = "Wuber", id = r[1] .. "-s2", promise = r[1], seed = r[2], seen = r[1], situation = {}, text = loadPromise(file, r[1]).text })
		eq(rc, 0, r[1] .. " with seed " .. r[2])
	end
end)
