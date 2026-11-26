-- Tests of Drive.Plan (round 13, agent B: Google's in-game screenshot findings). Loaded by
-- tests/run.lua with its helper table T. The big button's words and the rider's queue row follow
-- one state: while the button says "Summoning Dan" or "CLICK THE PORTAL", Dan's row says he is being
-- summoned (shots 26-29 showed "ready to summon": the photo tour fakes the button's plan, I13), and
-- the button's words for a rider who landed are neutral (the tour's "she pays in a trade", I28).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

local function land(w) w:advance(8) end

-- The rider types the fare into the trade and accepts (the addon never puts gold in).
local function pays(w, name, copper)
	local p = w:player(name)
	ok(p.trade, name .. " has no trade open")
	w:typeTradeMoney(p, math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
	w:tradeAccept(p)
	w:advance(0.3)
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": the big button")
	return c:click(b)
end

-- the row words (UI.Driver.Rows' D.Describe) for the rider in that window
local function rowWords(c, name)
	local x = c.W.Drive.customers[key(name)]
	return x and c.W.Driver.Describe(x) or nil
end

test("drive.plan: I13 the queue row follows the big button (Summon / Summoning / CLICK THE PORTAL); I28 landed words are neutral", function()
	local w = H.NewWorld({ restricted = true })
	local names = { ANA, BEA, CAL }
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(ANA, names, ANA) } })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(BEA, names, ANA) } })
	local cal = w:addClient(CAL, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(CAL, names, ANA) } })
	w:group(names)
	w:advance(1)
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Miller")
	w:botWhisper("Dan Miller", ana, "summon pls")
	w:advance(3.5)
	eq(ana.W.Drive.Plan().title, "Summon Dan", "the button: Summon Dan")
	eq(rowWords(ana, "Dan Miller"), "ready to summon", "the row: ready to summon")
	press(ana)
	w:advance(1.5)
	eq(ana.W.Drive.Plan().title, "Summoning Dan", "the caster's button: Summoning Dan")
	eq(rowWords(ana, "Dan Miller"), "summoning (you)", "the caster's row says so too")
	eq(bea.W.Drive.Plan().title, "CLICK THE PORTAL", "the helper's button")
	ok((rowWords(bea, "Dan Miller") or ""):find("^summoning %("), "the helper's row: " .. tostring(rowWords(bea, "Dan Miller")))
	w:clickPortal(bea)
	w:clickPortal(cal)
	w:advance(1.5)
	land(w)
	-- the caster's window has the trade open ("Dan is trading"); a crew window waits for the fare
	local pa, pb = ana.W.Drive.Plan(), bea.W.Drive.Plan()
	eq(pa.title, "Dan is trading", "the caster: the trade is open")
	eq(pb.title, "Waiting for Dan's 50s", "a crew window: waiting for the fare")
	for _, p in ipairs({ pa, pb }) do
		local words = " " .. p.title .. " " .. tostring(p.sub) .. " "
		for _, g in ipairs({ " she ", " he ", " her ", " his ", " him " }) do ok(not words:lower():find(g, 1, true), "neutral words: " .. words) end
		ok(not words:lower():find("click", 1, true), "no click pays: " .. words)
	end
	T.clean(w)
end)

-- (BRIEF20 B5, shot 87) raid summons: a raider who has the summon window is listed on the console
-- ("has the summon window"), so the button must not say "nobody waiting" while they are there.
test("drive.plan BRIEF20 B5: raid summons never say nobody waiting while a raider has the summon window", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	local real = { Mode = DR.Mode, IsOpen = DR.IsOpen, IsPaused = DR.IsPaused, RaidQueue = DR.RaidQueue, Shards = DR.Shards }
	DR.Mode = function() return "raid" end
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return false end
	DR.Shards = function() return 10 end
	local rows = {}
	DR.RaidQueue = function() return rows end
	eq(DR.Plan().title, "Raid summons - nobody waiting", "an empty queue: nobody waiting")
	rows[1] = { key = "dan miller", name = "Dan Miller", state = "waiting", order = 1, tries = 1, fails = 0, endAt = d.W.Now() }
	local p = DR.Plan()
	ok(not p.title:find("nobody waiting", 1, true), "Dan has the summon window: " .. p.title)
	eq(p.title, "Summon sent to Dan", "the button says whose summon is out")
	eq(p.sub, "waiting for them to accept it", "and what it waits for")
	eq(d.W.Driver.DescribeRaid(rows[1]), "has the summon window", "the row says the same")
	for k, v in pairs(real) do DR[k] = v end
	T.clean(w)
end)

-- (BRIEF20 B5, shot 79: the tour faked "No Soul Shards" beside a gauge it set to 12) in Wuber the
-- button's "No Soul Shards" and the console's shard gauge read the same count: 0 on both.
test("drive.plan BRIEF20 B5: No Soul Shards on the button, 0 on the shard gauge", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR, D = d.W.Drive, d.W.Driver
	local real = { Shards = DR.Shards, NextSummon = DR.NextSummon, MayCast = DR.MayCast, IsOpen = DR.IsOpen }
	DR.IsOpen = function() return true end
	DR.Shards = function() return 0 end
	DR.MayCast = function() return true end
	DR.NextSummon = function() return { name = "Dan Miller", key = "dan miller", state = "joined" } end
	local p = DR.Plan()
	eq(p.title, "No Soul Shards on this Warlock", "the button")
	local n = D.FuelInfo()
	eq(n, 0, "the gauge counts the same shards")
	for k, v in pairs(real) do DR[k] = v end
	T.clean(w)
end)
