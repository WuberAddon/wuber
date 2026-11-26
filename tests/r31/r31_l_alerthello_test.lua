local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("audit C48b-1: a non-driver alt on the account whispers the alert character at login", function()
	local w = H.NewWorld({})
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	-- the account's saved variables already name the alert character (set from the real crew window)
	local alt = w:addClient("Mia Mage", { spot = "Orgrimmar", class = "MAGE",
		saved = { Wuber = { drive = { bell = { name = "Wuber Rocks" } } } } })
	w:advance(10)
	eq(alt.W.Drive.Active(), false, "control: the Mage alt is not driving or in a crew")
	eq(alt.W.db.drive.bell.name, "Wuber Rocks", "control: the account-wide alert name is set")
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.from == "Mia Mage" and (e.text or ""):match("^BH~") then n = n + 1 end
	end
	eq(n, 0, "the Mage alt (no crew, not driving) sent " .. n .. " crew hello(s) to the alert character at login; the alert character now trusts it as 'the crew': team=" .. table.concat(wub.W.db.drive.bell.team, ","))
	T.clean(w)
end)

test("r31 L: a Warlock driver with an alert character still sends the crew hello", function()
	local w = H.NewWorld({})
	w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	local lock = w:addClient("Ana Lock", { spot = "Orgrimmar", class = "WARLOCK", shards = 10,
		saved = { Wuber = { drive = { bell = { name = "Wuber Rocks" } } } } })
	w:advance(10)
	eq(lock.W.Drive.Active(), true, "control: the Warlock is a driver")
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.from == "Ana Lock" and (e.text or ""):match("^BH~") then n = n + 1 end
	end
	ok(n > 0, "the driver sent no crew hello to the alert character")
	T.clean(w)
end)
