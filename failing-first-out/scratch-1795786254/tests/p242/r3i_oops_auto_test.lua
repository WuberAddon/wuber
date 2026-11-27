-- prep-242 r3 group I (BUGS-NEXT R50-03): once a wording is marked a wrong invite (Oops), no row stays an automatic
-- invite for words Careful now calls a lead, and a later line with those words never invites by itself.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function openDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", shards = 10 })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().kickAfter = false
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR
end

-- the hunt's always-promise queue.careful_auto: every row marked as an automatic invite asked in words Careful
-- (as it stands now) calls a clear request
local function autoRowsNotClear(DR)
	local bad = {}
	for _, c in pairs(DR.customers) do
		if type(c) == "table" and c.auto and c.auto ~= "" and type(c.autoMsg) == "string" then
			local v, why = DR.Careful(c.autoMsg, c.auto == "public" and "public" or "whisper")
			if v ~= "invite" then bad[#bad + 1] = tostring(c.name) .. " (" .. tostring(c.state) .. ") '" .. c.autoMsg .. "' => " .. tostring(v) .. " (" .. tostring(why) .. ")" end
		end
	end
	return table.concat(bad, "; ")
end

-- sweep: the oopsed rider invited (not joined) and joined, at two advance step sizes
local function sweep(case)
	local w, a, DR = openDriver()
	w:addBot("Kay Pine", { spot = "Ratchet", acceptsInvites = case.joins })
	w:addBot("Lou Reed", { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)
	w:botWhisper("Kay Pine", a, "summ pls")
	for _ = 1, 4 / math.min(case.step, 4) do w:advance(math.min(case.step, 4)) end
	local kay = DR.customers[key("Kay Pine")]
	eq(kay and kay.state, case.state, "control: Kay was invited by herself")
	eq(kay and kay.auto, "whisper", "control: Kay is an automatic invite")
	eq(autoRowsNotClear(DR), "", "control: before the Oops every automatic row is a clear request")
	eq(DR.Oops(kay), true, "Oops works")
	w:advance(case.step)
	eq(DR.Careful("summ pls", "whisper"), "lead", "the words are now a lead")
	eq(autoRowsNotClear(DR), "", "after the Oops no row is still an automatic invite for words Careful calls a lead")
	eq(DR.CanOops(kay), false, "a second Oops is refused")
	eq(DR.Oops(kay), false, "a second Oops does nothing")
	-- a later line with the marked words, from someone new, never invites by itself
	local before = #w.invites
	w:botWhisper("Lou Reed", a, "summ pls")
	w:advance(case.step)
	w:advance(case.step)
	local lou = DR.customers[key("Lou Reed")]
	eq(lou and lou.state, "lead", "Lou's 'summ pls' waits as a lead to click")
	ok(not (lou and lou.auto), "Lou is no automatic invite")
	for i = before + 1, #w.invites do
		ok(key(w.invites[i].to) ~= key("Lou Reed"), "Lou was not invited")
	end
	T.clean(w)
end
test("r3i R50-03: Oops on an invited rider (1 s steps): no automatic row for marked words, and they never invite again", function()
	sweep({ joins = false, state = "invited", step = 1 })
end)
test("r3i R50-03: Oops on an invited rider (5 s steps): no automatic row for marked words, and they never invite again", function()
	sweep({ joins = false, state = "invited", step = 5 })
end)
test("r3i R50-03: Oops on a joined rider (1 s steps): no automatic row for marked words, and they never invite again", function()
	sweep({ joins = true, state = "joined", step = 1 })
end)
test("r3i R50-03: Oops on a joined rider (5 s steps): no automatic row for marked words, and they never invite again", function()
	sweep({ joins = true, state = "joined", step = 5 })
end)

-- guard: unmarked buyer lines still invite by themselves after an Oops on other words
test("r3i R50-03 guard: after an Oops on 'summ pls', an unmarked clear request still auto-invites", function()
	local w, a, DR = openDriver()
	w:addBot("Kay Pine", { spot = "Ratchet", acceptsInvites = false })
	w:addBot("Max Dale", { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)
	w:botWhisper("Kay Pine", a, "summ pls")
	w:advance(4)
	local kay = DR.customers[key("Kay Pine")]
	eq(DR.Oops(kay), true, "Oops works")
	w:advance(1)
	w:botWhisper("Max Dale", a, "summ to org pls")
	w:advance(4)
	local max = DR.customers[key("Max Dale")]
	eq(max and max.state, "invited", "Max was invited by himself")
	eq(max and max.auto, "whisper", "Max is an automatic invite")
	eq(DR.CanOops(max), true, "Oops is offered for Max")
	T.clean(w)
end)

-- guard: the oopsed rider still gets the sorry step owed on the big button (Drive.Plan reads c.oops)
test("r3i R50-03 guard: the oopsed rider is still owed the sorry and uninvite", function()
	local w, a, DR = openDriver()
	w:addBot("Kay Pine", { spot = "Ratchet", acceptsInvites = true })
	w:advance(1)
	w:botWhisper("Kay Pine", a, "summ pls")
	w:advance(4)
	local kay = DR.customers[key("Kay Pine")]
	eq(kay and kay.state, "joined", "control: Kay joined")
	eq(DR.Oops(kay), true, "Oops works")
	w:advance(1)
	eq(DR.customers[key("Kay Pine")] and DR.customers[key("Kay Pine")].oops, true, "the Oops is still owed")
	T.clean(w)
end)
