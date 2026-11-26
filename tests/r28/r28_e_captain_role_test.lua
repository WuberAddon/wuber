local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, PIA = "Ana Smith", "Pia Rose"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

local function captainRow(c)
	for _, m in ipairs(c.W.Drive.Crew()) do
		if m.key == key(ANA) then return m end
	end
end

test("r28 AUD-44: a crew member's Crew screen keeps the Warlock captain as a Warlock when she is away", function()
	local w = T.newWorld()
	-- Pia (Priest) is in Ana's crew; the CRW she saved lists the captain as a Warlock
	local pia = w:addClient(PIA, { spot = "Undercity", class = "PRIEST", saved = { Wuber = { chars = { [key(PIA)] = {
		captain = ANA, wizard = true, crew = { { name = ANA, role = "lock", app = true } } } } } } })
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", shards = 10, saved = { Wuber = { chars = { [key(ANA)] = {
		captain = "", wizard = true, crew = { { name = PIA, role = "helper", app = true } } } } } } })
	w:group({ ANA, PIA })
	T.settle(w)
	local row = captainRow(pia)
	ok(row, "control: the captain is listed")
	eq(row and row.role, "lock", "control: heard in the group, the captain is a Warlock (summons and clicks)")
	-- the captain leaves the group / goes away for a minute
	w:leave(ANA)
	w:advance(60)
	row = captainRow(pia)
	ok(row, "the captain is still in the crew list")
	eq(row and row.role, "lock", "the Crew screen should still show Ana as a Warlock (saved CRW says lock), but it shows her as '" .. tostring(row and row.role) .. "' with the helper icon and 'clicks the portal' tooltip")
	T.clean(w)
end)
