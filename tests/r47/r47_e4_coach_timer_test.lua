local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function waitForCoachTimer(w, r)
	local ui = r.W.UI.state
	for _ = 1, 400 do
		if ui.coaching and not ui.coach then return true end -- maybeCoach has run, the 0.6 s delay is pending
		w:advance(0.05)
	end
	return false
end

test("r47 e4: leaving and coming back to Home within 0.6 s starts the tips twice", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local calls = {}
	local real = r.W.UI.CoachStep
	r.W.UI.CoachStep = function(i, ...) calls[#calls + 1] = { i = i, t = r.env.GetTime() } return real(i, ...) end
	r.W.UI.Toggle(true)
	ok(waitForCoachTimer(w, r), "control: the first-open guide was queued after the splash")
	local t0 = r.env.GetTime()
	local Coach = r.W.Mod("UI.Coach")
	-- Settings opened (stops the guide for now) and closed again, 0.1 s apart, inside the 0.6 s delay
	Coach.stopCoachForNow()
	w:advance(0.1)
	r.W.UI.MaybeCoach()
	w:advance(1.5)
	ok(#calls >= 1, "control: the guide did show")
	eq(#calls, 1, "the first tip is started " .. #calls .. " times (at +" .. table.concat((function() local o = {} for _, c in ipairs(calls) do o[#o + 1] = string.format("%.2f", c.t - t0) end return o end)(), " s, +") .. " s): the stale first timer fires early and the second restarts the ring")
	T.clean(w)
end)
