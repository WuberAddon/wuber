-- Group A proofs (job 415): the sheets (Report a bug, raincheck) and T.Sheet's dim. Temporary ids H24-06.. (the lead renumbers).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["H24-01"] = true, ["H24-02"] = true, ["H24-03"] = true, ["H24-04"] = true, ["H24-05"] = true, ["H24-08"] = true, ["H24-15"] = true, ["H24-06"] = true }
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

local function open()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, st)
	r.W.ride = { id = "h24a", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = st,
		at = r.env.GetTime(), service = "Bea's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.RefreshNow()
	w:advance(2)
end

-- the alpha of the window art (Wuber/Media/winbg.tga, 32-bit, bottom-left origin) at texel (x, y) counted from the top left
local function texelAlpha(x, y)
	local fh = assert(io.open("Wuber/Media/winbg.tga", "rb"))
	local d = fh:read("*a")
	fh:close()
	local idl = d:byte(1)
	local w = d:byte(13) + d:byte(14) * 256
	local h = d:byte(15) + d:byte(16) * 256
	local top = math.floor(d:byte(18) / 32) % 2 == 1
	local row = top and y or (h - 1 - y)
	return d:byte(18 + idl + (row * w + x) * 4 + 4)
end

local function near(a, b) return math.abs(a - b) <= 0.6 end

-- the corners of the window art that are clear (the window is rounded) while the dim's corner lies on them
local function bleed(ui, sh)
	local wr, dr = H.rect(ui.win), H.rect(sh.dim)
	local out = {}
	local pts = {
		{ "top left", dr.l, dr.b + dr.h, wr.l, wr.b + wr.h, 0, 0 },
		{ "top right", dr.l + dr.w, dr.b + dr.h, wr.l + wr.w, wr.b + wr.h, 503, 0 },
		{ "bottom left", dr.l, dr.b, wr.l, wr.b, 0, 839 },
		{ "bottom right", dr.l + dr.w, dr.b, wr.l + wr.w, wr.b, 503, 839 },
	}
	-- the dim's fill is what shows: round at the window art's own corner (T.CORNER.window) it lies inside the art
	local fill = sh.dim and sh.dim.fill
	if fill and fill.parts and (fill.px or 0) >= 7 then return out end
	for _, p in ipairs(pts) do
		if near(p[2], p[4]) and near(p[3], p[5]) and texelAlpha(p[6], p[7]) == 0 then out[#out + 1] = p[1] end
	end
	return out
end

proof("H24-06", "the dim of a sheet stays inside the window's rounded corners (Report a bug, top corners)", function()
	local w, r, ui, UI = open()
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	local b = bleed(ui, UI.Bug.frame)
	eq(#b, 0, "the dim's square corner lies on clear window art, so a dark corner shows outside the phone: " .. table.concat(b, ", "))
	T.clean(w)
end)

proof("H24-06", "the dim of a sheet stays inside the window's rounded corners (raincheck on the live ride page, all four corners)", function()
	local w, r, ui, UI = open()
	ride(r, w, "summoning")
	ok(UI.TabsHidden(), "the tab bar is away")
	r.W.Raincheck.Mine = function()
		return { { id = "h24a", state = "offered", driver = "Anita Lift", cover = 5000, expires = os.time() + 6 * 86400 } }
	end
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and f.dim, "the offer is the sheet inside the window")
	local b = bleed(ui, f)
	eq(#b, 0, "the dim's square corners lie on clear window art, so dark corners show outside the phone: " .. table.concat(b, ", "))
	T.clean(w)
end)
