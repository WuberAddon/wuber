-- r34 k2 (HUNT-84): with the full 100-trip list, the visits before the oldest kept month are gone, so that
-- month can call no place new; a later month still compares with the earlier kept trips.
local T = ...
local test, eq = T.test, T.eq
local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end

test("r34 k2: the oldest month of a full trip list lists no new places (history is cut); later months and short lists still do", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("Core.Wrapped")
	local function build(n)
		local t = {}
		for i = 1, n - 1 do t[#t + 1] = { at = at(2026, 10, 1) + i * 60, dest = "Undercity", price = 1000 } end
		t[#t + 1] = { at = at(2026, 11, 3), dest = "Gadgetzan", price = 1000 }
		return t
	end
	W.db.rides = build(100)
	local m = Mod.Month(2026, 10)
	eq(m.rides, 99, "99 October rides")
	eq(#m.newPlaces, 0, "cannot know Undercity is new in the oldest kept month when only the last 100 trips are kept")
	m = Mod.Month(2026, 11)
	eq(m.rides, 1, "one November ride")
	eq(#m.newPlaces, 1, "November has earlier kept trips to compare with: Gadgetzan is new")
	W.db.rides = build(5)
	m = Mod.Month(2026, 10)
	eq(#m.newPlaces, 1, "with the whole history kept, Undercity is new in October")
	m = Mod.Month(2026, 11)
	eq(#m.newPlaces, 1, "and Gadgetzan in November")
	T.clean(w)
end)
