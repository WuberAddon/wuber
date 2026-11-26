local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-102: opening (or reopening) with a flagged enemy player's nameplate already showing counts it.

local function setup()
	local w = H.NewWorld({})
	local ana = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	w:addBot("Ally Foe", { faction = "Alliance", spot = "Undercity" })
	w:advance(2)
	ana:showPlate("Ally Foe")
	w:advance(1)
	return w, ana
end

test("r31 j danger: open with an enemy plate already showing -> level 1", function()
	local w, ana = setup()
	eq((ana.W.Drive.DangerLevel()), 0, "closed: nothing")
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	eq((ana.W.Drive.DangerLevel()), 1, "plate in view at Open")
end)

test("r31 j danger: reopen after Close with the plate still showing -> level 1", function()
	local w, ana = setup()
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	ana.W.Drive.SetOpen(false)
	w:advance(2)
	eq((ana.W.Drive.DangerLevel()), 0, "closed: forgotten")
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	eq((ana.W.Drive.DangerLevel()), 1, "plate still in view at reopen")
end)
