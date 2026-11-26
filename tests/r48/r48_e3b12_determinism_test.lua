-- E3b-12: determinism & isolation tests for the two full-suite transcript diffs:
-- 1) Wuber/UI/Rider/Home.lua LayoutCards cardPool order must not depend on Lua pairs() hash order.
-- 2) tests/hunt/lib.lua must not leak H.textMetrics on Hunt.init() and must apply/restore it on every Hunt.build().
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, rider, settle, clean = T.newWorld, T.rider, T.settle, T.clean

test("e3b-12: Home.LayoutCards pools gone driver cards deterministically regardless of pairs() hash history", function()
	local function poolOrder(perturb)
		local w = newWorld()
		local r = rider(w, "Wuber Rocks")
		settle(w)
		r.W.UI.Toggle(true)
		w:advance(1)
		local UI = r.W.UI
		local home = UI.state.screens.home
		r.W.drivers = {
			["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Undercity", price = 5000, state = "open", team = 3, creator = true },
			["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3 },
			["bob stone"] = { name = "Bob Stone", key = "bob stone", dest = "Ratchet", price = 6000, state = "open", team = 1 },
			["ivy moss"] = { name = "Ivy Moss", key = "ivy moss", dest = "Booty Bay", price = 7500, state = "busy", team = 2 },
		}
		local list = UI.Drivers()
		if perturb then
			for i = 1, 20 do UI.state.cards["dummy_" .. i] = nil end
			-- Insert in reverse order after forcing a hash rehash
			local rev = {}
			for i = #list, 1, -1 do rev[#rev + 1] = list[i] end
			UI.LayoutCards(home, rev)
		end
		UI.LayoutCards(home, list)
		local cardKey = {}
		for k, c in pairs(UI.state.cards) do cardKey[c] = k end
		local base = #UI.state.cardPool
		UI.LayoutCards(home, {})
		local order = {}
		for i = base + 1, #UI.state.cardPool do
			order[#order + 1] = cardKey[UI.state.cardPool[i]]
		end
		clean(w)
		return table.concat(order, ",")
	end

	local a = poolOrder(false)
	local b = poolOrder(true)
	eq(a, "anita lift,bob stone,ivy moss,mia runner", "sorted cardPool order")
	eq(b, a, "cardPool order must be identical even when ui.cards hash history differs")
end)

-- guard: Hunt.init and runPromise live in the test tree (tests/hunt/lib.lua), so the addon base cannot fail this; it keeps the isolation
test("e3b-12: Hunt.init does not leak H.textMetrics and Hunt.runPromise applies/restores it on every run", function()
	local oldTM = H.textMetrics
	H.textMetrics = nil
	local Hunt = dofile(T.dir .. "/hunt/lib.lua")
	Hunt.init({})
	eq(H.textMetrics, nil, "Hunt.init must not leak H.textMetrics")

	for runIdx = 1, 2 do
		H.textMetrics = nil
		local res = Hunt.runPromise("nowayout.rider_not_stuck_after_cancelled_trade", { role = "rider", ride = "arrived" }, 1, { always = false })
		eq(res.status, "pass", "run " .. runIdx .. ": " .. tostring(res.seen or res.detail or res.status))
		eq(H.textMetrics, nil, "run " .. runIdx .. ": Hunt.runPromise must restore H.textMetrics")
	end
	H.textMetrics = oldTM
end)
