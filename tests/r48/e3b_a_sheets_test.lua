-- Event 3b, group A: E3b-01 (the Report a bug and raincheck sheets dim the whole page, the header zone too, so no
-- page row is cut by the sheet's edge, and the header's buttons stay usable) and the sheet half of E3b-09 (the two
-- sheets rest on the phone's foot while the tab bar is away, the live ride page, and on the tab bar otherwise).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function near(a, b) return math.abs(a - b) <= 0.6 end

local function open()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, st)
	r.W.ride = { id = "e3ba", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = st,
		at = r.env.GetTime(), service = "Bea's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.RefreshNow()
	w:advance(2)
end

local function raincheck(r, w)
	local n = 0
	r.W.Raincheck.Mine = function()
		n = n + 1
		return { { id = "rc" .. n, state = "offered", driver = "Anita Lift", cover = 5000,
			expires = os.time({ year = 2026, month = 11, day = 19, hour = 12, min = 0, sec = 0 }) + 6 * 86400 } }
	end
	local f = r.W.UI.RaincheckOffer()
	w:advance(1)
	return f
end

-- every shown frame of the sheet that takes the mouse at the point (x, y)
local function catchers(f, x, y, out, seen)
	out, seen = out or {}, seen or {}
	if seen[f] then return out end
	seen[f] = true
	if f.IsShown and f:IsShown() then
		local rc = H.rect(f)
		if f.IsMouseEnabled and f:IsMouseEnabled() and rc.l <= x and x <= rc.l + rc.w and rc.b <= y and y <= rc.b + rc.h then
			out[#out + 1] = f
		end
		for _, c in ipairs({ f:GetChildren() }) do catchers(c, x, y, out, seen) end
	end
	return out
end

local function check(what, sh, ui, UI)
	local win = ui.win
	local wr, dr, cr = H.rect(win), H.rect(sh.dim), H.rect(sh.card)
	ok(H.visible(sh.card), what .. ": the sheet shows")
	-- E3b-01: the dim reaches the window's top, so no page row between the header and the sheet is left clear or cut
	ok(near(dr.b + dr.h, wr.b + wr.h), what .. (": the dim reaches the window's top (dim top %.1f, window top %.1f)"):format(dr.b + dr.h, wr.b + wr.h))
	-- E3b-01 / E1-07: the header's x still takes the click (nothing of the sheet catches the mouse over it)
	local xr = H.rect(ui.close)
	local hits = catchers(sh, xr.l + xr.w / 2, xr.b + xr.h / 2)
	eq(#hits, 0, what .. ": nothing of the sheet takes the mouse over the window's x")
	ok(H.visible(ui.close), what .. ": the window's x shows")
	-- E3b-09: the sheet rests on the phone's foot while the bar is away, on the tab bar otherwise
	if UI.TabsHidden() then
		ok(near(cr.b, wr.b), what .. (": the bar is away: the sheet rests on the foot (card bottom %.1f, window bottom %.1f)"):format(cr.b, wr.b))
	else
		local tb = H.rect(ui.tabbar)
		ok(near(cr.b, tb.b + tb.h), what .. (": the sheet rests on the tab bar (card bottom %.1f, bar top %.1f)"):format(cr.b, tb.b + tb.h))
	end
end

test("e3b-a: Report a bug dims the page to the window's top, keeps the header's x free and rests on the tab bar (Home)", function()
	local w, r, ui, UI = open()
	ok(not UI.TabsHidden(), "Home: the tab bar shows")
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	check("Home", UI.Bug.frame, ui, UI)
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("e3b-a: Report a bug on the live ride page rests on the phone's foot, not 56 above it", function()
	local w, r, ui, UI = open()
	ride(r, w, "summoning")
	eq(ui.screen, "found", "the ride page")
	ok(UI.TabsHidden(), "the tab bar is away")
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	check("ride page", UI.Bug.frame, ui, UI)
	-- the sheet is the whole height from under the header zone down to the foot
	local cr, wr = H.rect(UI.Bug.frame.card), H.rect(ui.win)
	local k = wr.h / ui.win:GetHeight() -- the rects are on the screen; the header zone is in the window's own units
	ok(near(cr.b + cr.h, wr.b + wr.h - UI.HEAD_H * k), ("the report's top sits at the header zone's foot (card top %.1f, window top %.1f, head %s)"):format(cr.b + cr.h, wr.b + wr.h, tostring(UI.HEAD_H)))
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("e3b-a: the raincheck sheet dims the page to the window's top and rests on the tab bar, or on the foot on the ride page", function()
	local w, r, ui, UI = open()
	local f = raincheck(r, w)
	ok(f and f.dim, "the offer is the sheet inside the window")
	check("Home", f, ui, UI)
	f:Close(true)
	w:advance(1)
	ride(r, w, "summoning")
	ok(UI.TabsHidden(), "the ride page: the tab bar is away")
	f = raincheck(r, w)
	ok(f and f.dim, "the offer on the ride page is the sheet inside the window")
	check("ride page", f, ui, UI)
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
