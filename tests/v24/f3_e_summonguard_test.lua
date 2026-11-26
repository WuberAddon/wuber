-- Wuber 2.4 fix round 3, group E, part 2: the double-summon guard. Before the big button casts on a rider, the game
-- is asked whether that rider has a summon waiting (another Warlock's, or an earlier one of ours): then the
-- button holds no cast (nothing harmful to click), says so, and the next rider is summoned instead. No Soul Shard
-- is wasted on a second summon. Sources (ideas only): the addon-learning notes FAKE-GAME-HINTS 40, LESSONS-FOR-24 section 1
-- (two Warlocks summoning the same person). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local SPOT = "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local TITLE = "Dan has a summon waiting"
local SUB = "no second summon while it is up: it would waste a Soul Shard"

-- a Warlock driver with two helpers; Dan (no Wuber) and Wes (another Warlock, no Wuber, far away) in the group
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld({ incomingSummon = opts.api ~= false })
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Bo Second", { spot = SPOT })
	w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
	-- (opts.wes = false: Wes stays out of the group to leave a place for a second rider; the fake game's
	-- World:summon does not ask who is grouped)
	w:group(opts.wes == false and { ANITA, "Bob Helper", "Bo Second" } or { ANITA, "Bob Helper", "Bo Second", "Wes Other" })
	w:advance(1)
	local DR = lock.W.Drive
	DR.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar", acceptsSummon = false })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	local c = DR.Find("Dan Moss")
	ok(c and c.state == "joined", "Dan is in the group, ready to summon: " .. tostring(c and c.state))
	local b = lock.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is shown")
	eq(DR.Plan().title, "Summon Dan", "control: the button offers Dan's summon")
	return w, lock, DR, c, b
end

local function casts(b) return tostring(b:GetAttribute("macrotext") or ""):find("/cast", 1, true) ~= nil end

test("v24 f3 e summon guard: no cast on a rider who already has another Warlock's summon waiting", function()
	local w, lock, DR, c, b = setup()
	w:summon(w:player("Wes Other"), "Dan Moss")
	w:advance(2)
	local plan = DR.Plan()
	eq(plan.summon, nil, "the plan holds no summon")
	eq(plan.title, TITLE, "the button says why")
	eq(plan.sub, SUB, "and what it saves")
	eq(plan.color, "wait", "amber: waiting")
	ok(not casts(b), "the secure button holds no /cast: " .. tostring(b:GetAttribute("macrotext")))
	local shards = w:player(ANITA).shards
	lock:click(b)
	w:advance(3)
	eq(w.casts, 0, "the click cast nothing")
	eq(w:player(ANITA).shards, shards, "no Soul Shard is gone")
	eq(c.state, "joined", "Dan is still ready to summon")
	-- he declines Wes's summon: now ours goes
	w:answerSummon("Dan Moss", false)
	w:advance(2)
	eq(DR.Plan().title, "Summon Dan", "the box is gone: the button offers the summon again")
	lock:click(b)
	w:advance(1)
	eq(w.casts, 1, "and the click casts it")
	T.clean(w)
end)

test("v24 f3 e summon guard: the look right before the click catches a summon that came this second", function()
	local w, lock, DR, c, b = setup()
	ok(casts(b), "control: the button holds the cast")
	w:summon(w:player("Wes Other"), "Dan Moss") -- no tick since: the button still holds its cast
	lock:click(b)
	w:advance(3)
	eq(w.casts, 0, "the click cast nothing (PreClick looked first)")
	eq(DR.Plan().title, TITLE, "and the button says why")
	T.clean(w)
end)

test("v24 f3 e summon guard: the next rider is summoned instead", function()
	local w, lock, DR, c, b = setup({ wes = false })
	w:addBot("Eve Night", { spot = "Orgrimmar", acceptsSummon = false })
	w:botWhisper("Eve Night", lock, "summon pls")
	w:advance(3)
	eq((DR.NextSummon() or {}).name, "Dan Moss", "control: Dan is first")
	w:summon(w:player("Wes Other"), "Dan Moss")
	w:advance(2)
	eq((DR.NextSummon() or {}).name, "Eve Night", "Dan has a summon waiting: Eve is next")
	eq(DR.Plan().title, "Summon Eve", "the button offers Eve")
	-- a click on Dan's row ("summon this one next") does not get round it either
	lock.W.Driver.RowAction(c, "next")
	w:advance(1)
	eq(DR.Plan().title, "Summon Eve", "still Eve")
	T.clean(w)
end)

test("v24 f3 e summon guard: a rider with Wuber is guarded too, and so is the call to a Warlock without Wuber", function()
	local w, lock, DR, c, b = setup()
	c.source, c.wuberRide = "wuber", "abcdef"
	w:summon(w:player("Wes Other"), "Dan Moss")
	w:advance(2)
	eq(DR.Plan().title, TITLE, "the game's answer holds the cast for any rider")
	eq((lock.W.Driver.Describe(c)), "ready to summon", "(their row is Wuber's own, as before)")
	eq(DR.SummonPending(c), true, "DR.SummonPending: what the plan's call step asks before it asks a Warlock in chat")
	T.clean(w)
end)

test("v24 f3 e summon guard: a secret or missing answer, or a box the game says is up for over 200 s, holds nothing", function()
	local w, lock, DR, c, b = setup()
	lock:secret("IncomingSummon")
	w:summon(w:player("Wes Other"), "Dan Moss")
	w:advance(2)
	eq(DR.Plan().title, "Summon Dan", "secret: the button is as it is today")
	lock:unsecret()
	w:advance(2)
	-- (lead) a "waiting" that is already there at the first readable look was not seen to appear: it holds nothing
	eq(DR.Plan().title, "Summon Dan", "readable again, the box already up: not seen to appear, so as today")
	w:setIncomingSummon(false)
	w:advance(2)
	eq(DR.Plan().title, "Summon Dan", "the call is gone: as today")
	-- a game that says "pending" for everybody from the first look on never holds a cast
	w:setIncomingSummon(true)
	local says = 1
	lock.env.C_IncomingSummon.IncomingSummonStatus = function() return says end
	w:advance(3)
	eq(DR.Plan().title, "Summon Dan", "pending from the first look on: never believed")
	-- a summon seen to appear whose "pending" then never ends: believed for 200 s (a box lasts 2 to 3 minutes), then not
	says = 0
	w:advance(3)
	says = 1
	w:advance(3)
	eq(DR.Plan().title, TITLE, "seen to appear: held")
	w:advance(205)
	ok(DR.Plan().title ~= TITLE, "after 200 s the answer is not believed any more: " .. tostring(DR.Plan().title))
	eq(#w.violations, 0, "no secret value was used: " .. tostring(w.violations[1]))
	T.clean(w)
end)

-- raid summons: Dru (druid) runs them, Ana (Warlock with Wuber) is her summoner, Ra waits in Orgrimmar
test("v24 f3 e summon guard: raid summons hold the cast too, and keep the raider with their summoner", function()
	local DRU, ANA = "Dru Oak", "Ana Smith"
	local w = T.newWorld({ incomingSummon = true })
	local dru = w:addClient(DRU, { spot = SPOT, class = "DRUID", saved = { Wuber = { chars = { [key(DRU)] = {
		crew = { { name = ANA, role = "lock", app = true } }, captain = "", wizard = true, runner = true, summoners = { ANA } } } } } })
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = DRU, role = "lock", app = true } }, captain = DRU, wizard = true } } } } })
	w:addBot("Rex Lead", { spot = SPOT, class = "WARRIOR" })
	w:addBot("Cid Click", { spot = SPOT })
	w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
	w:addBot("Ra Raider", { spot = "Orgrimmar", acceptsSummon = false })
	w:group({ "Rex Lead", DRU, ANA, "Cid Click", "Wes Other", "Ra Raider" })
	w:setAssist(DRU, true)
	w:advance(5)
	local D = dru.W.Drive
	ok(D.SetMode("raid") ~= false, "raid mode")
	ok(D.SetOpen(true) ~= false, "start")
	w:advance(5)
	w:groupSay("Ra Raider", "123")
	w:advance(3)
	eq(#D.RaidQueue(), 1, "Ra is queued")
	local A = ana.W.Drive
	eq(A.Plan().title, "Summon Ra", "control: Ana's button offers Ra")
	w:summon(w:player("Wes Other"), "Ra Raider")
	w:advance(2)
	local plan = A.Plan()
	eq(plan.summon, nil, "Ana's plan holds no summon")
	eq(plan.title, "Ra has a summon waiting", "her button says why")
	eq(plan.sub, SUB, "and what it saves")
	local assign = A.RaidAssign()
	eq(assign[1] and assign[1].row and assign[1].row.name, "Ra Raider", "Ra stays Ana's (every window keeps the same assignment)")
	local b = ana.env.WuberDriveButton
	ana:click(b)
	w:advance(3)
	eq(w.casts, 0, "her click cast nothing")
	T.clean(w)
end)
