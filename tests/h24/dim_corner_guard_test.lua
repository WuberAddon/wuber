-- guard: the dim of a small sheet (no opts.head) stays a plain square fill; only window-wide sheets round their corners
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("H24-06 guard: a sheet without opts.head keeps a square dim", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	local host = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	host:SetSize(200, 300)
	host:SetPoint("CENTER")
	local sh = r.W.Theme.Sheet(host, 120, "Guard")
	ok(sh.dim and sh.dim.fill, "the dim has a fill")
	eq(sh.dim.fill.parts, nil, "no nine-slice: a plain colour fill")
	T.clean(w)
end)
