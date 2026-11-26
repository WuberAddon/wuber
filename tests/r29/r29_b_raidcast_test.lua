local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
do

local DRU, ANA, SPOT = "Dru Oak", "Ana Smith", "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- a raid of eight: Dru (druid, runs raid summons), Ana (Warlock with Wuber, in Dru's crew), two
-- clickers in range, four raiders waiting in Orgrimmar. Ana summons Ra; the two clickers hold the portal.
local function run(helpSeenOn)
	local w = T.newWorld()
	local dru = w:addClient(DRU, { spot = SPOT, class = "DRUID", saved = { Wuber = { chars = { [key(DRU)] = {
		crew = { { name = ANA, role = "lock", app = true } }, captain = "", wizard = true, runner = true, summoners = { ANA } } } } } })
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = DRU, role = "lock", app = true } }, captain = DRU, wizard = true } } } } })
	local names = { "Rex Lead", DRU, ANA, "Cid Click" }
	w:addBot("Rex Lead", { spot = SPOT, class = "WARRIOR" })
	w:addBot("Cid Click", { spot = SPOT })
	for i = 1, 4 do
		local n = "R" .. string.char(96 + i) .. " Raider"
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	w:advance(5)
	-- the account did a crew summon on this build earlier: a crew HELP was heard then
	if helpSeenOn then ana.W.Drive.opts().helpSeen = ana.W.Build() end
	local D = dru.W.Drive
	ok(D.SetMode("raid") ~= false, "raid mode")
	ok(D.SetOpen(true) ~= false, "start")
	w:advance(5)
	w:groupSay("Ra Raider", "123")
	w:advance(3)
	eq(#D.RaidQueue(), 1, "Ra is queued")
	local b = ana.env.WuberDriveButton
	ok(b and H.visible(b), "Ana's big button is shown")
	ana:click(b)
	w:advance(3)                          -- the cast is done, the channel has run a while
	ok(w:clickPortal(dru), "Dru clicks the portal")
	ok(w:clickPortal("Cid Click"), "Cid clicks the portal")
	w:advance(2.5)
	local ends = {}
	for _, e in ipairs(w.addonLog) do
		local f = e.text:match("^END~[^~]*~Ra Raider~(%d)")
		if f then ends[#ends + 1] = f end
	end
	local row = D.raidRows[key("Ra Raider")]
	return w, ends, row
end

test("a raid summon with no earlier crew HELP on this account is reported done", function()
	local w, ends, row = run(false)
	eq(ends[1], "1", "control: END says the summon went")
	ok(row == nil or row.state == "waiting" or row.state == "summoning" or row.state == "done" or row.state == "arrived",
		"control: Ra is not back in the queue, state " .. tostring(row and row.state))
	T.clean(w)
end)

test("a raid summon held open by two clickers is reported done even after an earlier crew HELP on this build", function()
	local w, ends, row = run(true)
	ok(ends[1] == "1", "two raiders clicked the portal and Ra was summoned, but Ana's window sent END ok=" .. tostring(ends[1])
		.. " and put Ra back in the queue as '" .. tostring(row and row.state) .. "' (summoned again, no 'Summoned tonight' count)")
	T.clean(w)
end)

end
do

local DRU, ANA, BEA, SPOT = "Dru Oak", "Ana Smith", "Bea Jones", "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Dru (druid) runs raid summons; the summoners in order are Bea (a Warlock WITHOUT Wuber) then Ana (Warlock with Wuber).
-- One raider (Ra) waits. bea is online or not.
local function run(beaOnline)
	local w = T.newWorld()
	local dru = w:addClient(DRU, { spot = SPOT, class = "DRUID", saved = { Wuber = { chars = { [key(DRU)] = {
		crew = { { name = ANA, role = "lock", app = true }, { name = BEA, role = "lock", app = false } },
		captain = "", wizard = true, runner = true, summoners = { BEA, ANA } } } } } })
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = DRU, role = "lock", app = true } }, captain = DRU, wizard = true } } } } })
	local names = { "Rex Lead", DRU, ANA, BEA, "Cid Click" }
	w:addBot("Rex Lead", { spot = SPOT, class = "WARRIOR" })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:addBot("Cid Click", { spot = SPOT })
	for i = 1, 3 do
		local n = "R" .. string.char(96 + i) .. " Raider"
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	w:advance(5)
	local D = dru.W.Drive
	ok(D.SetMode("raid") ~= false, "raid mode")
	ok(D.SetOpen(true) ~= false, "start")
	w:advance(5)
	w:groupSay("Ra Raider", "123")
	w:advance(3)
	eq(#D.RaidQueue(), 1, "Ra is queued")
	if not beaOnline then
		w:player(BEA).online = false
		w:advance(6)
	end
	return w, dru, ana
end

test("the first summoner online takes the raider and the runner is told to ask her", function()
	local w, dru, ana = run(true)
	local t = dru.W.Drive.Plan().title
	ok(t:find("Bea", 1, true), "control: the runner's button asks Bea, it reads '" .. tostring(t) .. "'")
	T.clean(w)
end)

test("an offline first summoner is skipped: the online Warlock behind her gets the only raider", function()
	local w, dru, ana = run(false)
	local ta, td = ana.W.Drive.Plan().title, dru.W.Drive.Plan().title
	ok(ta == "Summon Ra", "Bea is offline, yet the next summoner Ana's big button reads '" .. tostring(ta)
		.. "' (and the runner's reads '" .. tostring(td) .. "') instead of 'Summon Ra': nobody summons Ra")
	T.clean(w)
end)

end
