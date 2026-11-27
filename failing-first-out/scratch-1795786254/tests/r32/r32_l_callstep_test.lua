local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local MIA, BEA, SPOT = "Mia Frost", "Bea Jones", "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Mia (Mage) sells summons; Bea is a Warlock WITHOUT Wuber in her crew. Dan then Eve asked and joined the group
-- (both away from Undercity). Dan then goes offline (or not, in the control).
local function run(danOnline)
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = { chars = { [key(MIA)] = {
		crew = { { name = BEA, role = "lock", app = false } }, captain = "", wizard = true, runner = true, summoners = { BEA } } } } } })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:group({ MIA, BEA })
	w:advance(2)
	local D = mia.W.Drive
	ok(D.SetOpen(true) ~= false, "open")
	w:advance(2)
	w:addBot("Dan Moss")
	w:botWhisper("Dan Moss", mia, "summon pls")
	w:advance(4)
	w:addBot("Eve Long")
	w:botWhisper("Eve Long", mia, "summon pls")
	w:advance(4)
	local c1, c2 = D.customers["dan moss"], D.customers["eve long"]
	ok(c1 and c2 and c1.state == "joined" and c2.state == "joined", "both joined: " .. tostring(c1 and c1.state) .. "/" .. tostring(c2 and c2.state))
	if not danOnline then
		w:player("Dan Moss").online = false
		w:advance(3)
	end
	return w, mia
end

test("r32 l: AUD-91: control: both riders online: the first (Dan) is the one Bea is asked to summon", function()
	local w, mia = run(true)
	local t = mia.W.Drive.Plan().title
	ok(t:find("Dan", 1, true), "control: reads '" .. tostring(t) .. "'")
	T.clean(w)
end)

test("r32 l: AUD-91: the first joined rider is offline: Bea (no Wuber) is asked to summon the online one instead", function()
	local w, mia = run(false)
	local t = mia.W.Drive.Plan().title
	ok(t:find("Eve", 1, true) and not t:find("Dan", 1, true), "Dan is offline, Eve is online and waiting, yet the runner's button reads '" .. tostring(t) .. "'")
	T.clean(w)
end)