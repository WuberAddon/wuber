local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function reportOf(c)
	local lines = {}
	local pr = c.W.Print
	c.W.Print = function(t, ...) lines[#lines + 1] = tostring(t) return pr(t, ...) end
	c.W.Drive.LogReport()
	c.W.Print = pr
	return table.concat(lines, "\n")
end

test("r33 n5 AUD-82: the drive log says 0, never free, for no takings", function()
	local w = T.newWorld()
	local bob = w:addClient("Bob Smith", { spot = "Undercity", class = "WARLOCK" })
	w:advance(10)
	ok(bob.W.Drive.SetOpen(true), "open")
	w:advance(1800)
	local out = reportOf(bob)
	ok(out:find("0 rides"), "report printed: " .. out)
	ok(not out:find("free"), "no 'free' for zero takings: " .. out)
	ok(out:find("0c in 0.5 open hours = 0c per open hour"), "zero written as 0c: " .. out)
	bob.W.Drive.LogRide(50000, "Dan Miller", "t", 50000)
	local with = reportOf(bob)
	ok(with:find("5g") and not with:find("free"), "with a ride gold shows: " .. with)
	T.clean(w)
end)

test("r33 n5 HUNT-85: the stats raid count and the console Summoned tonight use the same hours", function()
	local w = T.newWorld()
	local ana = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	w:advance(10)
	local DR, D = ana.W.Drive, ana.W.Driver
	DR.LogRaid("Cal Brown")
	w:advance(7 * 3600)
	eq(D.RaidTonight(), 0, "console: 7 hours ago is not tonight")
	eq(DR.RaidCount(), D.RaidTonight(), "the two counts agree at 7 hours")
	DR.LogRaid("Dee Jones")
	w:advance(5 * 3600)
	eq(DR.RaidCount(), D.RaidTonight(), "the two counts agree at 5 hours")
	eq(DR.RaidCount(), 1, "only the raider inside six hours")
	T.clean(w)
end)
