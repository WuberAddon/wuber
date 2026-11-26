local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Ratchet" })
	local FX = d.W.FX
	local bursts = {}
	FX.Fullscreen = function(which) bursts[#bursts + 1] = which end
	return w, d, FX, bursts
end

test("r47 d4: audit C17r-2: one tipped payment by 'Ana Smith' is one coin shower, not coins then a smaller burst", function()
	-- control: realm-tail spelling of the same rider is recognised as the same payer
	local w, d, FX, bursts = setup()
	FX.OnDrivePaid("Ana Smith", 100, 50, nil, true, "t")
	FX.OnPaid("ride-1", "Ana Smith-Realm")
	eq(#bursts, 1, "control: same payer (realm spelling), one burst")
	-- the bug: hyphenated sender address of the same rider
	local w2, d2, FX2, bursts2 = setup()
	FX2.OnDrivePaid("Ana Smith", 100, 50, nil, true, "t")
	FX2.OnPaid("ride-2", "Ana-Smith")
	eq(#bursts2, 1, "one payment by Ana Smith (address Ana-Smith) should be one shower, got " .. table.concat(bursts2, ","))
	T.clean(w)
	T.clean(w2)
end)
