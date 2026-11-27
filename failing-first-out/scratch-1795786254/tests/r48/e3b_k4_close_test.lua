-- E3b-11 F016 (carried from the other side of Event 3b): the bug hunt's danger.closed_no_warning promise knows the 2.4
-- question. Closing the shop with riders still listed asks "N riders are still with you. Close anyway?"; the promise
-- answers Yes (crew.lua closeAnswering), then checks the closed shop. A Close that skips the question while riders are
-- listed is still a fault there (closeAnswering fails it).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local Hunt
-- guard: the hunt promise and the 2.4 Close anyway question already pass on the addon base; the fix was in the promise (tests/promises), not the addon
test("e3b-k4: danger.closed_no_warning answers 'Close anyway?' and passes on the 2.4 code", function()
	if not Hunt then
		Hunt = dofile(T.dir .. "/hunt/lib.lua")
		Hunt.init({})
	end
	local p = Hunt.promises["danger.closed_no_warning"]
	ok(p, "no promise danger.closed_no_warning")
	local okc, res = pcall(Hunt.runPromise, p, { enemies = "near", phone = "drive", ride = "paid", role = "warlock" }, 1, { always = false })
	assert(okc, res)
	eq(res.status, "pass", tostring(res.seen or res.detail or res.status))
end)
