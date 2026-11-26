-- Wuber 2.2 (round six, SPEC5.md) tests: agent B's part (action). Loaded by run.lua with the
-- same helpers as round five. Test names start "r6 action:". Each one fails on the 2.1 code
-- and passes on 2.2 (SPEC5 "regress").

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean

local ANA, BEA = "Ana Smith", "Bea Jones"
local PAT = "Pat Priest"
local SPOT = "Undercity"

test("r6 action: the file loads", function()
	ok(H ~= nil, "the harness")
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function plan(c) return c.W.Drive.Plan() end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

local function saved(me, names, extra, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

local function member(me, captain, names, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } }
end

local function read(rel) return T.readFile(T.dir .. "/" .. rel) end

-- A Warlock driving alone at Undercity with one rider (a bot) who has landed and owes 50s.
local function landed()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Dan Miller", { spot = SPOT })
	w:group({ ANA, "Dan Miller" })
	w:advance(1)
	local DR = DRof(ana)
	DR.SetOpt("autoTrade", false)
	DR.SetOpen(true)
	local c = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1 }
	DR.customers["dan miller"] = c
	return w, ana, DR, c
end

---------------------------------------------------------------------------
-- complete (#3): the driver's side credits gold only on a completed trade
---------------------------------------------------------------------------

test("r6 action: complete - a trade both sides accepted that then failed (bags full) credits nothing", function()
	local w, ana, DR, c = landed()
	ana.env.ERR_TRADE_TARGET_BAG_FULL = "That player's bags are full."
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, ana.player), "trade open")
	w:typeTradeMoney(dan, 0, 50, 0)
	ok(DR.trade and DR.trade.money == 5000, "50s read")
	-- both accept, then the game refuses it: no "Trade complete", a failure line, the window shuts
	ana:fire("TRADE_ACCEPT_UPDATE", 1, 1)
	ana:fire("UI_ERROR_MESSAGE", 0, "That player's bags are full.")
	w:tradeCancel(dan)
	w:advance(3)
	eq(c.paid, 0, "not paid: the trade never went through")
	clean(w)
end)

test("r6 action: complete - the purse stands in for an unread amount only right after a completed trade", function()
	local w, ana, DR, c = landed()
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, ana.player), "trade open")
	-- both accepted, the amount never read, then the trade fails (a failure line, no completion);
	-- a vendor sale a moment later must not be taken for the fare
	ana:fire("TRADE_ACCEPT_UPDATE", 1, 1)
	ana:fire("UI_ERROR_MESSAGE", 0, ana.env.ERR_TRADE_CANCELLED or "Trade cancelled.")
	ana.env.ERR_TRADE_CANCELLED = ana.env.ERR_TRADE_CANCELLED or "Trade cancelled."
	ana:fire("UI_ERROR_MESSAGE", 0, ana.env.ERR_TRADE_CANCELLED)
	w:tradeCancel(dan)
	ana.player.money = ana.player.money + 5000 -- sold something to a vendor
	ana:fire("PLAYER_MONEY")
	w:advance(3)
	eq(c.paid, 0, "a vendor sale is not the fare")
	-- a real, completed trade still counts (with the amount read)
	ok(w:openTrade(dan, ana.player), "trade again")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan)
	w:tradeAccept(ana.player)
	w:advance(2)
	eq(c.paid, 5000, "paid by the completed trade")
	eq(c.state, "paid")
	clean(w)
end)

test("r6 action: complete - the game's 'Trade complete' line counts with either argument order", function()
	local w, ana, DR, c = landed()
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, ana.player), "trade open")
	w:typeTradeMoney(dan, 0, 50, 0)
	-- an older client: UI_INFO_MESSAGE(message), while the trade window is still up
	ana:fire("UI_INFO_MESSAGE", "Trade complete.")
	w:advance(1)
	eq(c.paid, 5000, "counted from the line alone")
	w:tradeCancel(dan)
	clean(w)
end)

---------------------------------------------------------------------------
-- guild (#25): one DR.Guild, no double brackets
---------------------------------------------------------------------------

test("r6 action: guild - one DR.Guild in the addon; {guild} and <{guild}> both read <Moo>, never <<Moo>>", function()
	local defs = {}
	for _, f in ipairs({ "Drive_Core", "Drive_Places", "Drive_Team", "Drive_Queue", "Drive_Chat", "Drive_Trade", "Drive_Service",
		"Drive_Log", "Drive_Button", "Drive_Net", "Drive_Bell", "Drive_Commands", "Driver", "UI_Drive", "Commands", "Core", "Net" }) do
		local paths = H.F.paths(f) -- the old file, or the modules its code moved to (tests/lib/files.lua)
		ok(#paths > 0, f .. "'s files in the TOC")
		for _, path in ipairs(paths) do
			local src = T.readFile(path) or ""
			local file = path:sub(#H.ADDONS.Wuber + 2)
			for _ in src:gmatch("\nfunction DR%.Guild%s*%(") do defs[#defs + 1] = file end
			for _ in src:gmatch("\nDR%.Guild%s*=") do defs[#defs + 1] = file end
		end
	end
	eq(#defs, 1, "DR.Guild defined in: " .. table.concat(defs, ", "))
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	ana.player.guild = "Moo"
	local DR = DRof(ana)
	eq(DR.Guild(), "<Moo>", "in brackets, as 2.0")
	local dest = DR.Text("advert", nil, "{dest}")
	eq(DR.Text("advert", nil, "<{guild}> summons to {dest}"), "<Moo> summons to " .. dest, "brackets written: once")
	eq(DR.Text("advert", nil, "{guild} summons to {dest}"), "<Moo> summons to " .. dest)
	ana.player.guild = nil
	eq(DR.Text("advert", nil, "<{guild}>summons"), "summons", "no guild: nothing, no empty brackets")
	clean(w)
end)

---------------------------------------------------------------------------
-- helperpause (#17): a helper can't pause by /wuber drive pause
---------------------------------------------------------------------------

test("r6 action: helperpause - a helper's /wuber drive pause and resume change nothing and say why", function()
	local w = T.newWorld()
	local names = { ANA, PAT }
	local roles = { [PAT] = "helper" }
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = saved(ANA, names, nil, roles) } })
	local pat = w:addClient(PAT, { spot = SPOT, class = "PRIEST", saved = { Wuber = member(PAT, ANA, names, roles) } })
	w:group(names)
	w:advance(2)
	DRof(ana).SetOpen(true)
	w:advance(2)
	eq(DRof(pat).Role(), "helper")
	local before = #pat.chatLines
	pat:slash("/wuber drive pause")
	w:advance(1)
	eq(pat.W.Char().paused == true, false, "the helper's window is not paused")
	eq(ana.W.Char().paused == true, false, "nor the Warlock's")
	local said = table.concat(pat.chatLines, "\n", before + 1)
	ok(said:find("can pause or resume", 1, true), said)
	ana.W.Char().paused = true
	pat.W.Char().paused = true -- (as the crew's PAU left it)
	pat:slash("/wuber drive resume")
	eq(pat.W.Char().paused, true, "a helper can't resume either")
	ana.W.Char().paused = false
	pat.W.Char().paused = false
	-- the Warlock still can
	ana:slash("/wuber drive pause")
	eq(ana.W.Char().paused, true, "the Warlock pauses")
	ana:slash("/wuber drive resume")
	eq(ana.W.Char().paused, false)
	clean(w)
end)

---------------------------------------------------------------------------
-- logsize (#27): smaller log caps, hourly maps 120 days
---------------------------------------------------------------------------

test("r6 action: logsize - asks and team lines capped at 2500, rides at 10000, hourly maps keep 120 days", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	local l = DR.Log()
	local now = ana.env.time()
	for i = 1, 3000 do
		l.asks[i] = (now - 3000 + i) .. ",match,Dan,m,Undercity,wtb summon"
		l.team[i] = (now - 3000 + i) .. ",5000,Dan,Undercity,bea jones,bea jones"
	end
	for i = 1, 10050 do l.rides[i] = (now - 20000 + i) .. ",5000,Dan,Undercity,t,5000" end
	local old = ana.env.date("%Y%m%d%H", now - 130 * 86400)
	local recent = ana.env.date("%Y%m%d%H", now - 100 * 86400)
	l.open[old], l.open[recent] = 30, 40
	l.seen[old] = 60
	ok(type(DR.LogPrune) == "function", "DR.LogPrune")
	DR.LogPrune()
	eq(#l.asks, 2500, "asks")
	eq(#l.team, 2500, "team")
	eq(#l.rides, 10000, "rides")
	ok(l.asks[2500]:find("^" .. now .. ","), "the newest kept: " .. l.asks[2500])
	ok(l.asks[1]:find("^" .. (now - 2499) .. ","), "the oldest went: " .. l.asks[1])
	eq(l.open[old], nil, "130 days ago: gone")
	eq(l.seen[old], nil)
	eq(l.open[recent], 40, "100 days ago: kept")
	-- a new line keeps the cap
	DR.LogAsk("match", "Eve Long", "wtb summon uc", true)
	eq(#l.asks, 2500)
	ok(l.asks[2500]:find("Eve Long", 1, true), "the new line is last")
	eq(DR.LOG_MAX_DAYS, 120)
	clean(w)
end)

---------------------------------------------------------------------------
-- promote (#29): "Give lead to X" on the big button; PromoteToLeader only from that click
---------------------------------------------------------------------------

test("r6 action: promote - a helper who leads gets 'Give lead to Ana'; only its click promotes", function()
	local w = T.newWorld()
	local names = { PAT, ANA } -- Pat (a Priest helper) leads
	local roles = { [PAT] = "helper" }
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = saved(ANA, { ANA, PAT }, nil, roles) } })
	local pat = w:addClient(PAT, { spot = SPOT, class = "PRIEST", saved = { Wuber = member(PAT, ANA, { ANA, PAT }, roles) } })
	w:group(names)
	w:advance(2)
	DRof(ana).SetOpen(true)
	-- who calls PromoteToLeader, and inside a hardware click or not
	local calls = {}
	for _, c in ipairs({ ana, pat }) do
		local real = c.env.PromoteToLeader
		local function spy(...)
			calls[#calls + 1] = { by = c.player.name, hw = w.hardware == c }
			return real(...)
		end
		c.env.PromoteToLeader = spy
		if c.env.C_PartyInfo then c.env.C_PartyInfo.PromoteToLeader = spy end
	end
	w:advance(30)
	eq(#calls, 0, "no timer hands the lead over")
	eq(w:player(PAT).group.leader, PAT)
	local p = plan(pat)
	eq(p.title, "Give lead to Ana")
	ok(p.sub:find("group leader", 1, true), p.sub)
	press(pat)
	w:advance(1)
	eq(#calls, 1, "one promote")
	eq(calls[1] and calls[1].hw, true, "inside the click")
	eq(w:player(PAT).group.leader, ANA, "Ana leads now")
	ok(plan(pat).title ~= "Give lead to Ana", "done: " .. plan(pat).title)
	clean(w)
end)

---------------------------------------------------------------------------
-- DR.SimHooks (WuberLab's test mode): the cast step keeps /target, the lab replaces the cast
---------------------------------------------------------------------------

test("r6 action: SimHooks - castLine replaces /cast, cast leaves it out and is called after the click; /target stays", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:group({ ANA, "Dan Miller" })
	w:advance(1)
	local DR = DRof(ana)
	DR.SetOpen(true)
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "joined", price = 5000, paid = 0, at = 0, greeted = true }
	DR.MayCast = function() return true, ana.W.myKey end
	DR.Button.Refresh()
	local real = plan(ana).macrotext or ""
	ok(real:find("/cast Ritual of Summoning", 1, true), "no hook: the real cast: " .. real)
	DR.SimHooks = { castLine = function(line, name) return "/stopmacro" end }
	local p = plan(ana)
	ok(p.macrotext:find("/target [@party1]", 1, true), p.macrotext)
	ok(p.macrotext:find("/stopmacro", 1, true) and not p.macrotext:find("/cast", 1, true), "castLine: " .. p.macrotext)
	local got = {}
	DR.SimHooks = { cast = function(name) got[#got + 1] = name end }
	p = plan(ana)
	eq(p.macrotext, "/target [@party1]", "cast hook: no cast line")
	eq(p.title, "Summon Dan")
	press(ana)
	w:advance(0.5)
	eq(got[1], "Dan Miller", "the hook after the click")
	ok(not ana.player.casting and not w.ritual, "nothing really cast")
	DR.SimHooks = nil
	clean(w)
end)

---------------------------------------------------------------------------
-- repeat (#19): DR.RideCount(name) for the "3rd ride with you" badge
---------------------------------------------------------------------------

test("r6 action: repeat - DR.RideCount counts a rider's earlier rides (two payments of one ride = one), not the one going on", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	ok(type(DR.RideCount) == "function", "DR.RideCount")
	local l = DR.Log()
	local now = ana.env.time()
	l.rides[#l.rides + 1] = (now - 3 * 86400) .. ",5000,Dan Miller,Undercity,t,5000"
	l.team[#l.team + 1] = (now - 2 * 86400) .. ",5000,Dan Miller,Undercity,bea jones,bea jones"
	l.rides[#l.rides + 1] = (now - 86400) .. ",3000,Dan Miller,Undercity,t,5000"
	l.rides[#l.rides + 1] = (now - 86400 + 300) .. ",2000,Dan Miller,Undercity,t,5000" -- the rest of that fare
	l.rides[#l.rides + 1] = (now - 3600) .. ",5000,Eve Long,Undercity,t,5000"
	ana.W.Fire("DRIVE_LOG")
	eq(DR.RideCount("Dan Miller"), 3)
	eq(DR.RideCount("dan-miller"), 3, "by key")
	eq(DR.RideCount("Eve Long"), 1)
	eq(DR.RideCount("Nobody Here"), 0)
	-- Dan is in the queue now and has just paid this ride: it is not an earlier one
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:group({ ANA, "Dan Miller" })
	w:advance(1)
	DR.SetOpen(true)
	local c = DR.customers["dan miller"] or DR.Create("Dan Miller", "joined", "manual")
	ok(c and c.since, "first seen noted")
	w:advance(60)
	DR.LogRide(5000, "Dan Miller", "t", 5000)
	ok(DR.customers["dan miller"] == c, "still in the queue: " .. tostring(DR.customers["dan miller"]))
	eq(DR.RideCount("Dan Miller"), 3, "the ride going on is not counted")
	clean(w)
end)

---------------------------------------------------------------------------
-- shift (#20): DR.ShiftSummary() when the driver closes
---------------------------------------------------------------------------

test("r6 action: shift - DR.ShiftSummary sums the shift that just ended: rides, gold, tips, best hour, time open", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	ok(type(DR.ShiftSummary) == "function", "DR.ShiftSummary")
	DR.LogRide(5000, "Old Rider", "t", 5000) -- before the shift
	w:advance(10)
	ok(DR.SetOpen(true), "open")
	local start = ana.env.time()
	w:advance(600)
	DR.LogRide(6000, "Dan Miller", "t", 5000) -- 10s tip
	w:advance(600)
	DR.LogRide(5000, "Eve Long", "m", 5000)
	DR.LogTeamRide(5000, "Fay Moon", "bea jones", "bea jones")
	w:advance(600)
	DR.SetOpen(false)
	local s = DR.ShiftSummary()
	ok(s, "a summary")
	eq(s.rides, 2)
	eq(s.copper, 11000)
	eq(s.tips, 1000)
	eq(s.crewRides, 1)
	eq(s.crewCopper, 5000)
	ok(math.abs(s.open - 1800) <= 2, "open about 30 min: " .. tostring(s.open))
	eq(s.start, start)
	ok(s.bestHour ~= nil and s.bestHour >= 0 and s.bestHour <= 23, "best hour " .. tostring(s.bestHour))
	ok(s.bestCopper >= 6000, "best hour's gold")
	-- later the summary still says that shift (closed: the clock stopped)
	w:advance(3600)
	eq(DR.ShiftSummary().open, s.open, "closed: time open stays")
	clean(w)
end)

---------------------------------------------------------------------------
-- heatmap (#28): DR.Heatmap(days), a 7 x 24 grid for the in-game Earnings heatmap
---------------------------------------------------------------------------

test("r6 action: heatmap - DR.Heatmap(days) is a 7x24 grid of gold, rides, open minutes and gold per open hour", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	ok(type(DR.Heatmap) == "function", "DR.Heatmap")
	local l = DR.Log()
	local at = ana.env.time() - 2 * 86400
	local wd, h = tonumber(ana.env.date("%w", at)), tonumber(ana.env.date("%H", at))
	l.rides[#l.rides + 1] = at .. ",10000,Dan Miller,Undercity,t,10000"
	l.rides[#l.rides + 1] = (at + 60) .. ",5000,Eve Long,Undercity,t,5000"
	l.open[ana.env.date("%Y%m%d%H", at)] = 30
	l.asks[#l.asks + 1] = at .. ",match,Gus Hill,m,Undercity,wtb summon"
	local g = DR.Heatmap(7)
	for d = 0, 6 do
		ok(type(g[d]) == "table", "weekday " .. d)
		for hr = 0, 23 do ok(type(g[d][hr]) == "table", "cell " .. d .. "/" .. hr) end
	end
	local cell = g[wd][h]
	eq(cell.copper, 15000)
	eq(cell.rides, 2)
	eq(cell.open, 30)
	eq(cell.asks, 1)
	eq(cell.perHour, 30000, "15000 in half an hour")
	eq(g.max, 30000)
	eq(g[(wd + 1) % 7][h].perHour, nil, "nothing open there")
	eq(DR.Heatmap(1).copper, 0, "today only: nothing")
	eq(DR.Heatmap(500).days, 120, "never more than the log keeps")
	clean(w)
end)

---------------------------------------------------------------------------
-- rrmentions (#4): README and install.ps1 never name the old addon
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 2.1 on the real client: the macro budget with raid lines; /p and /ra only from clicks
---------------------------------------------------------------------------

test("r6 action: 2.1 sanity - a 40-man raid with long names: every macro fits, group lines only from a click", function()
	local w = T.newWorld()
	local names, long = {}, {}
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	names[1] = ANA
	for i = 1, 39 do
		local n = ("Maximilianus%s Wolfeschlegel%s"):format(string.char(96 + (i % 26) + 1), string.char(96 + (i % 7) + 1))
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
		long[#long + 1] = n
	end
	w:group(names)
	w:advance(1)
	local DR = DRof(ana)
	ok(DR.SetTemplate("raidsum", "Summon coming from {caster} - accept it when it pops! It is free, from your raid, and the portal is up at the entrance now: please accept quickly."), "long whisper")
	ok(DR.SetTemplate("raidclick", "Summoning {name} - everyone at the entrance please right-click the portal so the summon goes through, thanks!"), "long line")
	local rows = {}
	for i = 1, 5 do rows[i] = { name = long[i], key = key(long[i]), asked = 0, state = "queued", tries = 0 } end
	DR.Mode = function() return "raid" end
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return false end
	DR.RaidQueue = function() return rows end
	DR.Summoners = function() return { ana.W.myKey } end
	DR.Changed()
	DR.Button.Refresh()
	for round = 1, 5 do
		local p = plan(ana)
		ok(#(p.macrotext or "") <= 255, "round " .. round .. ": " .. #(p.macrotext or ""))
		for line in ((p.macrotext or "") .. "\n"):gmatch("(.-)\n") do ok(#line <= 255, "line fits: " .. line) end
		if p.type == "macro" then press(ana) end
		w:advance(1)
		rows[round].state = "waiting"
		DR.cast = nil
	end
	ok(#(w.groupPosts or {}) >= 1, "raid lines went")
	for _, post in ipairs(w.groupPosts or {}) do eq(post.how, "macro", "a group line by the button's macro: " .. post.text) end
	clean(w)
end)
