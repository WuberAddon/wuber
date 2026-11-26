-- Round fga, group H (A4): defaults that are measured facts. Loaded by tests/run.lua with its helper table T.
-- Proposal: 10-summon-box (the measured-default parts), rows D19, D23 of the research.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function pair(opts)
	local w = T.newWorld(opts or { incomingSummon = true })
	local lock = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	w:addBot("Dan Moss", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Dan Moss" })
	w:advance(1)
	return w, lock
end

-- D19: this build has only the Settings API (source; InterfaceOptions_AddCategory is not in it).
test("fga h: a default client has the Settings API and no InterfaceOptions_AddCategory", function()
	local w, c = pair()
	ok(type(c.env.Settings) == "table", "Settings exists")
	eq(rawget(c.env, "InterfaceOptions_AddCategory"), nil, "the old API is absent")
	T.clean(w)
end)

test("fga h: Settings.RegisterCanvasLayoutCategory returns the category and its layout", function()
	local w, c = pair()
	local cat, layout = c.env.Settings.RegisterCanvasLayoutCategory(c.env.CreateFrame("Frame"), "X")
	ok(cat ~= nil and layout ~= nil, "two values")
	T.clean(w)
end)

test("fga h: Wuber registers its page in the default Options list", function()
	local w, c = pair()
	ok(c.settingsCats and c.settingsCats[1] and c.settingsCats[1].name == "Wuber", "the Wuber category is there with no test set-up")
	T.clean(w)
end)

-- guard: the old API stays one prepare call away (Panel.lua's fallback is still tested), and then Settings is gone
test("fga h: fakeOptionsList old gives only the old API", function()
	local w = T.newWorld()
	local c = T.rider(w, T.ANITA, { prepare = function(env, client) T.H.fakeOptionsList(env, client, "old") end })
	T.settle(w)
	eq(c.env.Settings, nil, "no Settings")
	eq(#(c.optionPanels or {}), 1, "the panel went to the old list")
end)

-- C_SummonInfo.ConfirmSummon: measured 32 of 32 allowed from code (event handler and timer), no click.
for _, step in ipairs({ 1, 5 }) do
	test("fga h: ConfirmSummon from a timer with no click is allowed (advance " .. step .. " s)", function()
		local w, c = pair()
		w:summon(w:player("Dan Moss"), T.ANITA)
		w:advance(step)
		ok(c.player.pendingSummon, "control: a summon is waiting")
		w.hardware = nil
		c.env.C_Timer.After(1, function() c.env.C_SummonInfo.ConfirmSummon() end)
		for _ = 1, math.ceil(3 / step) do w:advance(step) end
		eq(c.confirmedSummons, 1, "the summon was confirmed from the timer")
		eq(#w.violations, 0, "no hardware-click violation")
		T.clean(w)
	end)
end

-- guard: the strict rule (the base's only rule) is still available to a world that asks for it
test("fga h: confirmSummonNeedsClick brings the click rule back", function()
	local w, c = pair({ incomingSummon = true, confirmSummonNeedsClick = true })
	w:summon(w:player("Dan Moss"), T.ANITA)
	w:advance(1)
	c.env.C_SummonInfo.ConfirmSummon()
	eq(c.confirmedSummons, nil, "nothing confirmed")
	eq(#w.violations, 1, "one violation")
	w.violations = {}
end)

-- guard: the fake already allowed AcceptGroup from a timer (acceptGroupNeedsClick is the opt-in)
test("fga h: AcceptGroup from a timer with no click is allowed", function()
	local w = T.newWorld()
	local c = w:addClient(T.ANITA, { spot = "Undercity" })
	local bob = w:addClient("Bob Late", { spot = "Undercity" })
	w:advance(1)
	c.W.db.autoAccept = false
	w:invite(bob, T.ANITA)
	w:advance(1)
	c.env.C_Timer.After(1, function() c.env.AcceptGroup() end)
	w:advance(3)
	ok(c.player.group, "joined the group")
	eq(#w.violations, 0, "no violation")
	T.clean(w)
end)

-- D23: measured 6 to 9 channels in all with Wuber's at slot 6 or 7, joined by JoinTemporaryChannel
-- guard: the fake's five game channels plus Wuber's already fit the measured range (rec: real_login tests hold the arrival timing)
test("fga h: a default client has 6 to 9 channels and Wuber's is at slot 6 or 7", function()
	local w, c = pair()
	w:advance(10)
	local n = c.env.GetNumDisplayChannels()
	ok(n >= 6 and n <= 9, "6 to 9 channels with Wuber's, got " .. n)
	local idx = c.env.GetChannelName("WuberNet")
	ok(idx == 6 or idx == 7, "WuberNet at slot 6 or 7, got " .. tostring(idx))
end)
