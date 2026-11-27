-- tests/h24 group F: Settings panel and Find (2.4.1 hardening night). Proof tests wrapped in proof().
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["H24-01"] = true, ["H24-02"] = true, ["H24-03"] = true, ["H24-04"] = true, ["H24-05"] = true, ["H24-08"] = true, ["H24-15"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_H24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local function openSettings(adv)
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.W.SetAdvanced(adv)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings()
	w:advance(2)
	return w, c, c.W.UI.settings, c.W.Mod("UI.Settings.Panel")
end

-- the words a player may type for the Flight offers row: its old name (Flight master tip), the Skip the bird card it
-- controls (the card's own name) and the plain word. Each must find the row, folded, Simple and Advanced.
for _, q in ipairs({ "skip the bird", "flight master tip", "flight offers", "bird" }) do
	local fn = function()
		for _, adv in ipairs({ false, true }) do
			local w, _, st, P = openSettings(adv)
			P.search(q)
			w:advance(1)
			ok((st.find.count or 0) >= 1, "Find finds a row for '" .. q .. "' (advanced " .. tostring(adv) .. ")")
			T.clean(w)
		end
	end
	if q == "skip the bird" then
		proof("H24-03", "Find: typing the Skip the bird card's own name finds the Flight offers row", fn)
	else
		-- guard: neighbouring paths, the other names for the same row already find it
		test("h24 f find old name finds Flight offers: " .. q, fn)
	end
end
