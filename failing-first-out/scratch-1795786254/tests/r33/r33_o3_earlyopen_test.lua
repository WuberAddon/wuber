local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 33 (HUNT-52): opening Wuber in the first seconds after login, while the network join is still pending,
-- must not say "Can't reach the Wuber network"; once the join delay is over and it truly is not joined, it says so.

local LINE = "Can't reach the Wuber network"

local function has(r)
	for _, s in ipairs(r:visibleTexts()) do
		if s:find(LINE, 1, true) then return true end
	end
	return false
end

test("r33 o3: Home opened just after login does not say it cannot reach the network", function()
	local w = T.newWorld({ joinFails = true })
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	r:slash("/wuber")
	w:advance(2)
	ok(not has(r), "no alarm in the first seconds")
	w:advance(30)
	r.W.UI.Refresh(true)
	ok(has(r), "after the join delay, with the join still failing, it says so as before")
	T.clean(w)
end)
