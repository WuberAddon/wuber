local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 33, group k4 (HUNT-61): two riders paying by trade a few seconds apart each get the coin burst.
-- The 5 second guard only stops the same payment bursting twice (SendStage and DRIVE_PAID).

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Ratchet" })
	local FX = d.W.FX
	local bursts = {}
	FX.Fullscreen = function(which) bursts[#bursts + 1] = which end
	return w, d, FX, bursts
end

test("r33 k4: a second rider paying within 5 seconds gets their own coin burst", function()
	local w, d, FX, bursts = setup()
	FX.OnDrivePaid("Ed", 100, 0, nil, true, "t")
	w:advance(2)
	FX.OnDrivePaid("Fay", 100, 0, nil, true, "t")
	eq(#bursts, 2, "two payments, two bursts")
	T.clean(w)
end)

test("r33 k4: the same payment still bursts once (stage hook then trade event)", function()
	local w, d, FX, bursts = setup()
	FX.OnPaid("ride-1", "Ed")
	w:advance(1)
	FX.OnDrivePaid("Ed-Realm", 100, 0, nil, true, "t")
	eq(#bursts, 1, "one payment, one burst")
	w:advance(1)
	FX.OnDrivePaid("Ed", 100, 0, nil, true, "t")
	eq(#bursts, 1, "same rider again within 5 s")
	T.clean(w)
end)
