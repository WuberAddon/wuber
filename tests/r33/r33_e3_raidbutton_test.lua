local T = ...
do
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local MIA, BEA, SPOT = "Mia Frost", "Bea Jones", "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Mia (Mage runner, leader of an eight-player raid) sells summons; Bea (Warlock with Wuber) starts summoning Dan.
-- Mia then switches to raid summons and Bea's window closes before it says the summon ended.
local function run(switch)
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = { chars = { [key(MIA)] = {
		crew = { { name = BEA, role = "lock", app = true } }, captain = "", wizard = true, runner = true, summoners = { BEA } } } } } })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(BEA)] = {
		crew = { { name = MIA, role = "lock", app = true } }, captain = MIA, wizard = true } } } } })
	local names = { MIA, BEA, "Dan Moss" }
	w:addBot("Dan Moss", { spot = "Orgrimmar" })
	for i = 1, 5 do
		local n = "R" .. string.char(96 + i) .. " Raider"
		w:addBot(n, { spot = SPOT })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(MIA, true)
	w:advance(3)
	local D = mia.W.Drive
	ok(D.SetOpen(true) ~= false, "open")
	w:advance(3)
	w:botWhisper("Dan Moss", mia, "summon pls")
	w:advance(3)
	local c = D.customers["dan moss"]
	ok(c, "Dan is Mia's customer")
	local b = bea.env.WuberDriveButton
	ok(b and H.visible(b), "Bea's button is shown: " .. tostring(bea.W.Drive.Plan().title))
	bea:click(b)
	w:advance(2)
	eq(c.state, "summoning", "Dan is being summoned by Bea")
	if switch then
		ok(D.SetMode("raid") ~= false, "raid mode")
		w:advance(1)
		D.SetOpen(true)
		w:advance(1)
	end
	w:cancelRitual(BEA)
	w:logout(bea)                      -- Bea's window is gone: no END ever comes
	for _ = 1, 8 do w:advance(60) end  -- eight minutes
	return w, mia, c
end

test("r33 e3 AUD-98 raidbutton: control: still selling, Bea's window gone mid-summon: the sell side expires Dan's summoning state", function()
	local w, mia, c = run(false)
	ok(c.state ~= "summoning", "control: Dan is '" .. tostring(c.state) .. "' after 8 minutes")
	T.clean(w)
end)

test("r33 e3 AUD-98 raidbutton: raid summons running: a customer left in summoning by the sell mode does not lock the button on CLICK THE PORTAL", function()
	local w, mia, c = run(true)
	local D = mia.W.Drive
	local t = D.Plan().title
	ok(D.RaidOn(), "raid summons are on")
	ok(not t:find("CLICK THE PORTAL", 1, true), "the runner's raid button reads '" .. tostring(t) .. "' 8 minutes after Bea left, because Dan (state " .. tostring(c.state) .. ") is still a sell-mode customer")
	T.clean(w)
end)

end
do
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL or "Cal Brown"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- the setup of tests/drive/raid_test.lua: a Druid assist runs raid summons, Cal (Warlock, Wuber) summons
local function raid()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	return w, dru, cal
end

test("r33 e3 AUD-99 raidbutton: control, a raider far away is planned and targeted by the Warlock's big button", function()
	local w, dru, cal = raid()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	local assign = cal.W.Drive.RaidAssign()
	eq(#assign, 1, "one raider is planned")
	ok((cal.W.Drive.Plan().macrotext or ""):find("/target Raider Ra", 1, true), "the click targets Ra: " .. tostring(cal.W.Drive.Plan().macrotext))
	T.clean(w)
end)

test("r33 e3 AUD-99 raidbutton: a raider who has just arrived at the spot (before the 1 s tick drops his row) is not planned for a summon", function()
	local w, dru, cal = raid()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	w:move("Raider Ra", RAIDSPOT) -- he walked up / took the summon: standing at the spot now
	local rows = cal.W.Drive.RaidQueue() -- (what RaidAssign reads: row.here is worked out here)
	ok(rows[1] and rows[1].here == true, "setup: the queue knows Ra is here")
	local assign = cal.W.Drive.RaidAssign()
	local macro = cal.W.Drive.Plan().macrotext or ""
	ok(#assign == 0 and not macro:find("Raider Ra", 1, true),
		"Ra already stands at the summon spot yet the big button still plans a summon for him (" .. #assign .. " planned, macro: " .. macro:gsub("\n", " | ") .. ")")
	T.clean(w)
end)

end
