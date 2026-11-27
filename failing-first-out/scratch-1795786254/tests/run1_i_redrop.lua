-- Run 1 group i (item 8): a rider taken off the list, who left the group and asks again, is a rider
-- again: the big button offers his summon (not "Open - waiting for riders").
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, DAN = "Ana Smith", "Dan Miller"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function setup()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	return w, a, DR
end

local function summonNow(w, a, DR)
	local c = DR.NextSummon()
	ok(c, "a rider to summon: " .. tostring(DR.whyNoSummonText))
	local plan = DR.Plan()
	ok((plan.macrotext or ""):find("/cast", 1, true), "the button casts: " .. tostring(plan.title) .. " / " .. tostring(plan.macrotext))
	return c, plan
end

test("run1 i: taken off the list, left, asked again: the button offers the summon", function()
	local w, a, DR = setup()
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "Dan joined the group")
	summonNow(w, a, DR)
	-- summoned and arrived, then marked paid and taken off the list (step 9-11)
	w:move(DAN, "Undercity")
	w:advance(2)
	dan = DR.customers[key(DAN)]
	ok(dan, "still listed after arriving")
	DR.MarkPaid(dan)
	w:advance(1)
	dan = DR.customers[key(DAN)]
	if dan then DR.Do("DROP", dan.name) end
	w:advance(1)
	eq(DR.customers[key(DAN)], nil, "off the list")
	ok(DR.ignored[key(DAN)], "in the group, ignored")
	-- he leaves the group, goes away, and asks again (step 12)
	w:leave(DAN)
	w:advance(2)
	eq(DR.ignored[key(DAN)], nil, "out of the group: not ignored any more")
	w:move(DAN, "Ratchet")
	w:advance(1)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "Dan is a rider again, in the group")
	summonNow(w, a, DR)
	T.clean(w)
end)

test("run1 i: taken off the list, asked again while still in the group: a rider again", function()
	local w, a, DR = setup()
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "Dan joined the group")
	DR.Do("DROP", dan.name) -- (UI/Driver/Rows.lua "drop": Take off the list)
	w:advance(1)
	ok(DR.ignored[key(DAN)], "in the group, ignored")
	eq(DR.NextSummon(), nil, "nobody to summon")
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "asked again by whisper: a rider again")
	summonNow(w, a, DR)
	T.clean(w)
end)

-- (item 8, the likely real path) he never went away: summoned to the driver, he left the group standing
-- beside her and asked again. In the group he is already here: no summon to offer, and the debug note says so.
test("run1 i: asked again standing beside the driver: no summon, and why", function()
	local w, a, DR = setup()
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	summonNow(w, a, DR)
	w:move(DAN, "Undercity")
	w:advance(2)
	local dan = DR.customers[key(DAN)]
	DR.MarkPaid(dan)
	w:advance(1)
	dan = DR.customers[key(DAN)]
	if dan then DR.Do("DROP", dan.name) end
	w:advance(1)
	w:leave(DAN)
	w:advance(2)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "joined", "listed and in the group again")
	eq(DR.NextSummon(), nil, "nobody to summon: he is already here")
	eq(DR.whyNoSummon[key(DAN)], "already here", "the debug note says why")
	ok((DR.whyNoSummonText or ""):find("Dan Miller: already here", 1, true), "and the line: " .. tostring(DR.whyNoSummonText))
	ok(not (DR.Plan().macrotext or ""):find("/cast", 1, true), "no cast on the button")
	w:advance(2)
	c = DR.customers[key(DAN)]
	eq(c and c.state, "arrived", "counted as arrived (he walked)")
	T.clean(w)
end)
