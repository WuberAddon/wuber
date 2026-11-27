
-- r33 g2 (AUD-97): Drive.Button paint() starts the minimap flash without the colour "gold", so the
-- minimap button pulses magenta (the rider's summon-portal colour) when a click becomes due for the driver
-- and the minimap's own refresh (throttled to once per 0.5 s) does not run right behind it.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.Driver.SetOnline(true)
	w:advance(3)
	return w, d, W
end
local function clickDue()
	return { marks = {}, color = "go", type = "macro", macrotext = "/x", title = "Summon Dan", sub = "in your group", doing = {}, says = {}, lines = 0 }
end

test("r33 g2 AUD-97: a click due for the driver flashes the minimap button gold, not the rider's magenta", function()
	local w, d, W = setup()
	local DR, mm = W.Drive, W.UI.state.minimap
	ok(mm, "the minimap button exists")
	-- control: a click is due and the engine's DRIVE events come at their usual pace: gold
	W.Fire("DRIVE") w:advance(0.1)
	DR.Plan = clickDue
	w:advance(1)
	W.Fire("DRIVE") w:advance(1)
	ok(mm.pulse.running and mm.pulseColour == "gold", "control: gold when the minimap refresh runs behind it (" .. tostring(mm.pulseColour) .. ")")
	-- the click goes (plan off), then another DRIVE, and a new click is due a moment after
	DR.Plan = function() return { marks = {}, color = "off", title = "Closed", sub = "", doing = {}, says = {}, lines = 0 } end
	W.Fire("DRIVE") w:advance(1)
	ok(not mm.pulse.running, "control: no click due, no flash")
	W.Fire("DRIVE") w:advance(0.1)
	DR.Plan = clickDue
	W.Fire("DRIVE")
	ok(mm.pulse.running, "the minimap button pulses")
	eq(mm.pulseColour, "gold", "the driver's click is due: the minimap button should pulse gold, but it pulses " .. tostring(mm.pulseColour) .. " (the rider's summon colour)")
	T.clean(w)
end)
