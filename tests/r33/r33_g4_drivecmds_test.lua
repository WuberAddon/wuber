local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

test("r33 g4 AUD-3: /wuber drive add in raid mode with raid summons running does not claim a sale queue entry", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local names = { ANITA }
	for i = 1, 6 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(ANITA, true)
	w:advance(3)
	local DR = a.W.Drive
	a:slash("/wuber drive raid")
	a:slash("/wuber drive on")
	w:advance(1)
	ok(DR.RaidOn(), "control: raid summons are running")
	local before = 0
	for _ in pairs(DR.customers) do before = before + 1 end
	a:slash("/wuber drive add Raider Ra")
	local after = 0
	for _ in pairs(DR.customers) do after = after + 1 end
	ok(after == before, "no paying-customer entry is added (" .. before .. " -> " .. after .. ")")
	ok(DR.raidRows and next(DR.raidRows) ~= nil and a:said("is on the list"), "the raid summon row is added and the line is true")
	T.clean(w)
end)

local function scene(assist)
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
	if assist then w:setAssist(ANITA, true) end
	w:advance(3)
	return w, a, a.W.Drive
end

test("r33 g4 AUD-5: /wuber drive status in raid mode does not say Driving open (selling)", function()
	local w, a, DR = scene(true)
	a:slash("/wuber drive raid")
	a:slash("/wuber drive on")
	w:advance(1)
	ok(DR.RaidOn() and not DR.Selling(), "control: raid summons run and selling is closed")
	a:slash("/wuber drive status")
	ok(a:said("Raid summons running"), "control: status says raid summons are running")
	ok(not a:said("Driving open"), "status also says 'Driving open: <price> to <place>.' though nothing is on sale, only free raid summons")
	T.clean(w)
end)


test("r33 g4 AUD-7: /wuber drive bell test says something when it cannot send a test", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	local DR = d.W.Drive
	local okk, why = DR.BellTest()
	ok(okk == false and why, "control: with no alert character the engine refuses: " .. tostring(why))
	local n0 = #d.chatLines
	d:slash("/wuber drive bell test")
	local new = {}
	for i = n0 + 1, #d.chatLines do new[#new + 1] = d.chatLines[i] end
	ok(#new > 0, "'/wuber drive bell test' with no alert character prints nothing at all (engine said: " .. tostring(why) .. ")")
	T.clean(w)
end)
