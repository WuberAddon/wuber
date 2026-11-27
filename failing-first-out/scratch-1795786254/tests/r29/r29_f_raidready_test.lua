local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function sceneA(mode)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local names = { "Raider Ra", ANITA }
	w:addBot("Raider Ra", { spot = "Orgrimmar" })
	for i = 2, 6 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(ANITA, true) -- the raid leader made Anita an assistant
	w:advance(3)
	a.W.Drive.SetMode(mode)
	w:advance(1)
	return w, a, a.W.Drive
end

local function linesA(DR, pat)
	local out = {}
	for _, l in ipairs(DR.Readiness()) do
		if l.ok == false and l.text:find(pat) then out[#out + 1] = l.text end
	end
	return out
end

test("a raid assistant can run raid summons", function()
	local w, a, DR = sceneA("raid")
	ok(DR.InRaid(), "a raid")
	ok(not DR.IsLeader(), "Anita is not the leader")
	ok(DR.CanRunRaid(), "an assistant may run raid summons")
	T.clean(w)
end)

test("a raid assistant in Raid mode sees no leads-the-group red line and Ready() is true", function()
	local w, a, DR = sceneA("raid")
	ok(DR.Ready(), "Ready() is true for a raid assistant")
	local bad = linesA(DR, "leads the group")
	ok(#bad == 0, "Raid mode never invites riders, yet the 'Ready to summon?' card shows red: '" .. tostring(bad[1]) .. "' (Ready() = " .. tostring(DR.Ready()) .. ")")
	ok(DR.Ready(), "Ready() is true for a raid assistant")
	T.clean(w)
end)


local function sceneB(mode)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	w:advance(3)
	a.W.Drive.SetMode(mode)
	w:advance(1)
	return w, a, a.W.Drive
end

local function crewLine(DR)
	for _, l in ipairs(DR.Readiness()) do
		if l.ok == false and l.text:find("Crew not set up") then return l end
	end
end

test("selling mode still asks for the crew", function()
	local w, a, DR = sceneB("sell")
	ok(not DR.char().wizard, "the selling wizard has not been run")
	ok(crewLine(DR), "Sell mode asks for the crew")
	T.clean(w)
end)

test("Raid mode does not ask for a crew the Ready to summon card", function()
	local w, a, DR = sceneB("raid")
	eq(DR.Mode(), "raid")
	local l = crewLine(DR)
	ok(not l, "Raid mode picks Warlocks with the Warlocks pill, yet the card reads red: '" .. tostring(l and l.text) .. "' with a '" .. tostring(l and l.fix and l.fix[1]) .. "' button")
	local reds = {}
	for _, x in ipairs(DR.Readiness()) do if x.ok == false then reds[#reds + 1] = x.text end end
	eq(#reds, 1, "only the missing raid is red: " .. table.concat(reds, " / "))
	ok(reds[1] and reds[1]:find("raid"), "the one red line is about the raid")
	T.clean(w)
end)

test("selling mode still says who leads the group when another window leads", function()
	local w, a, DR = sceneA("sell")
	local bad = linesA(DR, "leads the group")
	ok(#bad == 1, "Sell mode keeps the red leads-the-group line")
	T.clean(w)
end)
