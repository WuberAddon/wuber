
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

test("r47 g3: a month of free summons must not show 'free taken' on Behind the Portal", function()
	local w, r, W, M = setup(function(W)
		W.db.drive = W.db.drive or {}
		W.db.drive.log = { rides = { at(2026, 10, 5, 20) .. ",5000,Dan,Undercity,t,5000" } }
	end)
	-- control: paid ride reads '50s taken'
	local rc = W.Mod("Core.Wrapped").Month(2026, 10)
	local s = M.Slides(rc)
	local five
	for _, e in ipairs(s) do if e.kicker == "Behind the portal" then five = e end end
	ok(five and five.lines[1]:find("50s taken"), "control: a paid month reads '50s taken', reads '" .. tostring(five and five.lines[1]) .. "'")
	-- the bug: only free / rain-check summons (0 copper)
	W.db.drive.log = { rides = { at(2026, 10, 5, 20) .. ",0,Dan,Undercity,m,0", at(2026, 10, 6, 20) .. ",0,Eve,Undercity,m,0" } }
	toSlide(w, M, 5)
	local f = r:findText("Behind the portal")
	ok(#f > 0, "setup: the Behind the Portal slide is shown")
	local bad = r:findText("free taken")
	for _, e in ipairs(M.Slides(W.Mod("Core.Wrapped").Month(2026, 10))) do for _, l in ipairs(e.lines) do ok(not l:find("taken"), "no taken line: " .. l) end end
	ok(#bad == 0, "the Behind the Portal slide reads 'free taken' for 2 rides given (the driver took nothing)")
	T.clean(w)
end)
