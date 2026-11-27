local T = ...
local test, eq = T.test, T.eq

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Ratchet" })
	local FX = d.W.FX
	local bursts = {}
	FX.Fullscreen = function(which) bursts[#bursts + 1] = which end
	return w, FX, bursts
end

test("r47 i5: a bare first name then the same name with a realm tail is one payer, one burst", function()
	local w, FX, bursts = setup()
	FX.OnPaid("ride-1", "Ed")
	FX.OnDrivePaid("Ed-Realm", 100, 0, nil, true, "t")
	eq(#bursts, 1, "Ed then Ed-Realm")
	T.clean(w)
end)

test("r47 i5: a different rider with the same first name still bursts", function()
	local w, FX, bursts = setup()
	FX.OnPaid("ride-1", "Ana Smith")
	FX.OnDrivePaid("Ana Jones", 100, 0, nil, true, "t")
	eq(#bursts, 2, "Ana Smith then Ana Jones")
	T.clean(w)
end)
