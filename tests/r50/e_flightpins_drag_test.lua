-- r50 E: any drag of the Wuber window re-checks the flight-map price tags at drag stop.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H


local function addDriver(r, key, opts)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key] = { name = opts.name or key, key = key, dest = opts.dest, price = opts.price or 5000, state = "open",
		team = 3, heard = r.env.GetTime() }
end

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

-- the map open with one tag, Wuber open; returns world, rider, the pins module, the window, the phone and the tag's first rect
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000 })
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	local tr = H.rect(Mod.Pins()[1].tag)
	r.W.UI.Toggle(true)
	w:advance(0.5)
	local win = r.W.UI.state.win
	return w, r, Mod, win, r.W.UI.state.phone or win, tr
end

-- drops the window with its left edge 2 px inside the tag's first place (screen px -> UIParent units by the window's own ratio)
local function dropOverTag(r, win, tr)
	local before = H.rect(win)
	win:ClearAllPoints()
	win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", before.l, before.b + before.h / 2)
	local k = H.rect(win).l / before.l
	win:ClearAllPoints()
	win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", (tr.l + 2) / k, (tr.b + tr.h / 2) / k)
end


local function tagUnderWindow(Mod, ph)
	local t = Mod.Pins()[1].tag
	return t and H.visible(t) and overlaps(H.rect(t), H.rect(ph))
end

local function dragVia(pick)
	local w, r, Mod, win, ph, tr = setup()
	local grip = pick(r.W.UI.state)
	assert(grip and grip:GetScript("OnDragStart"), "a drag handle")
	grip:GetScript("OnDragStart")(grip)
	dropOverTag(r, win, tr)
	grip:GetScript("OnDragStop")(grip)
	w:advance(0.1)
	local bad = tagUnderWindow(Mod, ph)
	T.clean(w)
	return bad
end

test("r50 E H24-04: a drag by the pill leaves no price tag under Wuber", function()
	ok(not dragVia(function(s) return s.phone.island end), "tag under the window after the pill drag")
end)

test("r50 E H24-04: a drag by the status bar leaves no price tag under Wuber", function()
	ok(not dragVia(function(s) return s.phone.status end), "tag under the window after the status bar drag")
end)

-- guard: the header drag was already hooked on the base
test("r50 E H24-04 guard: a drag by the header still re-checks the tags", function()
	local w, r, Mod, win, ph, tr = setup()
	local top = r.W.UI.state.top
	if not (top and top:GetScript("OnDragStart")) then T.clean(w) return end
	top:GetScript("OnDragStart")(top)
	dropOverTag(r, win, tr)
	top:GetScript("OnDragStop")(top)
	w:advance(0.1)
	ok(not tagUnderWindow(Mod, ph), "tag under the window after the header drag")
	T.clean(w)
end)

-- a nil in the list of drag handles must not end the hooks: a phone with no status bar still hooks its pill
test("r50 E H24-04 G13: with the status bar missing, a drag by the pill still re-checks the tags", function()
	local w, r, Mod, win, ph, tr = setup()
	local ui = r.W.UI.state
	local fakePhone = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local pill = r.env.CreateFrame("Button", nil, r.env.UIParent)
	fakePhone.island = pill
	ui.phone = fakePhone -- no .status
	r:fire("PLAYER_ENTERING_WORLD")
	w:advance(0.1)
	dropOverTag(r, win, tr)
	pill:GetScript("OnDragStop")(pill)
	w:advance(0.1)
	ok(not tagUnderWindow(Mod, win), "tag under the window after the pill drag")
	T.clean(w)
end)
