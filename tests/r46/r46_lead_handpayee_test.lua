local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 46 lead (found by the independent read of the round's diff): HUNT-45 made a hand-marked ride's gold count
-- in the drive stats, and it also counted it for the runner when the mark was for another summoner who got the
-- gold (no Wuber there): that ride and its gold are the summoner's (the crew view), never the runner's own.
test("r46 lead: a ride marked paid by hand for another summoner adds no gold to my own drive stats", function()
	local w = T.newWorld()
	local ana = w:addClient(T.ANA, { spot = "Ratchet", class = "MAGE" })
	local W = ana.W
	local DR = W.Drive
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, caster = "bea jones", at = 0 }
	DR.SummonerHasApp = function(k) return k ~= "bea jones" end
	local before = DR.Stats().copper
	W.Fire("DRIVE_PAID", "Dan Miller", 5000, 0, "ana smith", true, "m", 5000)
	eq(DR.Stats().copper, before, "Bea got the gold: none of it in Ana's stats")
	local l = DR.Log()
	ok(l.team[#l.team]:find(",bea jones,bea jones$"), "Bea's ride on the crew view: " .. tostring(l.team[#l.team]))
	-- my own hand mark that carries an amount still counts (HUNT-45)
	DR.customers["eve long"] = { name = "Eve Long", key = "eve long", state = "arrived", price = 5000, at = 0 }
	W.Fire("DRIVE_PAID", "Eve Long", 5000, 0, "ana smith", true, "m", 5000)
	eq(DR.Stats().copper, before + 5000, "my own hand-marked ride with an amount counts")
	T.clean(w)
end)
