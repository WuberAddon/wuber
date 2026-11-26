local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function info(fare, wait)
	return { dest = "Undercity", flySecs = 1500, flyAbout = true, flightCost = 1000, fare = fare, wait = wait, waitKnown = true,
		timeSaved = math.max(0, 1500 - wait) }
end

test("r47 o6: a knob tween still running drags the knob back after the dial is set while hidden", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local B = r.W.Mod("UI.Rider.Booking")
		local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(400, 300)
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	local d = B.Dial(parent, 324, 88)
	d:SetPoint("TOP", parent, "TOP", 0, 0)
	d:SetSize(324, 88)
	local A, Bi, C = info(500, 900), info(80000, 30), info(80000, 30)
	d:Set(A) -- first driver: knob placed straight away
	w:advance(1)
	local pA = d.p
	d:Set(Bi) -- a refresh moves the knob: it eases toward the new place
	-- (no frame has run yet: the tween is in flight)
	local pB = d.target
	ok(math.abs(pA - pB) > 0.3, "setup: the two drivers put the knob far apart (" .. pA .. " to " .. pB .. ")")
	-- the rider backs out and opens another driver while the card is hidden
	parent:Hide()
	local C2 = info(500, 900) -- the new driver is about as good as the first
	d:Set(C2)
	local want = d.target
	w:advance(1)
	parent:Show()
	w:advance(0.1)
	-- control: a dial set while nothing was in flight keeps its knob
	local d2 = B.Dial(parent, 324, 88)
	d2:SetPoint("TOP", parent, "TOP", 0, -100)
	d2:SetSize(324, 88)
	d2:Set(A)
	parent:Hide() d2:Set(C2) w:advance(1) parent:Show() w:advance(0.1)
	ok(math.abs(d2.p - d2.target) < 0.01, "control: with no tween running the knob sits at " .. d2.target .. " (is " .. d2.p .. ")")
	ok(math.abs(d.p - want) < 0.01, "the new driver's dial should put the gold knob at " .. string.format("%.2f", want)
		.. " (summon wins) but the old tween drags it back to " .. string.format("%.2f", d.p) .. " (the last driver's verdict)")
	T.clean(w)
end)
