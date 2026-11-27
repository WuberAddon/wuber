-- The map pin's ring (UI.Map.Pins) and Reduce motion: no ring while it is on, and switching it on stops a ring that plays.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local D = { key = "zed", name = "Zed", service = "Zed Rides", state = "open", price = 5000, dest = "Ratchet", team = 1, seats = 4 }

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Mod = r.W.Mod("UI.Map.Pins")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(1000, 600)
	local pin = Mod.NewPin(parent)
	pin.key, pin.nx, pin.ny = "zed", 0.5, 0.5
	return w, r, Mod, pin
end

test("pin ring: with Reduce motion on, a chosen open pin's ring does not play", function()
	local w, r, Mod, pin = setup()
	r.W.db.reduceMotion = true
	Mod.Paint(pin, D, true, 0, false)
	ok(not pin.pulseAnim:IsPlaying(), "the ring animation must not play")
	ok(not pin.pulse:IsShown(), "the ring is not shown")
	T.clean(w)
end)

test("pin ring: switching Reduce motion on stops a ring that is playing", function()
	local w, r, Mod, pin = setup()
	Mod.Paint(pin, D, true, 0, false)
	ok(pin.pulseAnim:IsPlaying(), "control: it plays first")
	r.W.db.reduceMotion = true
	r.W.Fire("SETTINGS", "reduceMotion")
	ok(not pin.pulseAnim:IsPlaying(), "the ring stops at once")
	ok(not pin.pulse:IsShown(), "and hides")
	T.clean(w)
end)

-- guard: with Reduce motion off the ring still plays, and another setting changing does not stop it
test("pin ring: guard, Reduce motion off keeps the ring playing", function()
	local w, r, Mod, pin = setup()
	Mod.Paint(pin, D, true, 0, false)
	ok(pin.pulseAnim:IsPlaying(), "plays")
	r.W.Fire("SETTINGS", "fx")
	ok(pin.pulseAnim:IsPlaying(), "an unrelated setting leaves it")
	T.clean(w)
end)

-- guard: an unchosen open pin never rings, Reduce motion or not
test("pin ring: guard, an unchosen pin has no ring", function()
	local w, r, Mod, pin = setup()
	Mod.Paint(pin, D, false, 0, false)
	ok(not pin.pulseAnim:IsPlaying(), "no ring")
	T.clean(w)
end)
