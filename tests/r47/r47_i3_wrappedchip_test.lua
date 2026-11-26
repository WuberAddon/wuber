
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end
-- a rider whose clock says 3 November 2026; seed(W) fills October
local function setup(seed)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W, env = r.W, r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	W.db.rides = {}
	seed(W)
	W.RebuildTotals()
	W.UI.Toggle(true); w:advance(1); W.UI.SelectTab("Trips"); w:advance(1)
	return w, r, W, W.Mod("UI.Rider.Wrapped")
end
local function toSlide(w, M, n)
	ok(M.Open(2026, 10), "the story opens")
	w:advance(1)
	for _ = 2, n do M.Next(); w:advance(1) end
end

test("r47 i3: the Wrapped chip's clickable button covers its whole tag", function()
	local w, r, W, M = setup(function(W)
		for i = 1, 5 do W.db.rides[i] = { at = at(2026, 10, i), dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 } end
	end)
	local c = M.Chip(r.env.UIParent)
	c:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0); c:Show(); w:advance(1)
	local br, tr = H.rect(c), H.rect(c.tag)
	ok(math.abs((br.l + br.w) - (tr.l + tr.w)) < 0.5, "control: the tag and the button share their right edge")
	ok(tr.l >= br.l - 0.01, "the button is " .. c:GetWidth() .. " wide but its Wrapped tag is " .. c.tag:GetWidth() .. ": the star end of the chip sticks " .. string.format("%.1f", (br.l - tr.l)) .. " px out of the clickable button")
	T.clean(w)
end)
