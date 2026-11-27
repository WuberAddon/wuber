-- H24 group D: break-it guards for the E3b-07 lines of UI/FlightPins.lua (price tags stay clear of Wuber's window).
-- Loaded by tests/run.lua with its helper table T. A fake window (a plain frame put in place of ui.win) stands for a
-- window the module has not hooked yet; it is anchored to the flight point's marker, so no screen-unit sums are needed.
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

-- a rider on Thunder Bluff with one open driver to Orgrimmar; the flight map is not open yet
local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000 })
	return w, r, r.W.Mod("UI.FlightPins")
end

local function openMap(w, r)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
end

-- a plain frame in the place of Wuber's window (hidden, no points yet); with bezel it also gets a phone 10 units larger each side
local function fakeWindow(r, bezel)
	local ui = r.W.Mod("UI.Kit").ui
	local F = r.env.CreateFrame("Frame", "H24DFakeWindow", r.env.UIParent)
	F:SetSize(200, 300)
	F:Hide()
	ui.win, ui.phone, ui.top = F, nil, nil
	if bezel then
		local P = r.env.CreateFrame("Frame", "H24DFakePhone", F)
		P:SetPoint("TOPLEFT", F, "TOPLEFT", -10, 10)
		P:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", 10, -10)
		ui.phone = P
		return F, P
	end
	return F, F
end

-- the window's left edge dx units right of the flight point's centre (the tag's first place is the right side)
local function placeAt(F, marker, dx)
	F:ClearAllPoints()
	F:SetPoint("LEFT", marker, "CENTER", dx, 0)
end

local function clear(Mod, box, what)
	local t = Mod.Pins()[1].tag
	ok(t and H.visible(t), what .. ": the tag is still shown (a free side is left)")
	ok(not (t and overlaps(H.rect(t), H.rect(box))), what .. ": the tag is not under the window")
end

-- guard: break-it, Wuber/UI/FlightPins.lua windowRect: (ui.phone or ui.win) written as ui.win only (the bezel would not count)
test("h24 bk d: the phone's bezel counts as Wuber's window, not only the screen inside it", function()
	local w, r, Mod = rider()
	local F, P = fakeWindow(r, true)
	openMap(w, r)
	w:advance(0.3)
	local marker = Mod.Pins()[1].marker
	placeAt(F, marker, 60)
	F:Show()
	w:advance(1.2)
	clear(Mod, P, "bezel")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua Mod.Refresh: lastWinKey = winRectKey(winRect) dropped (the check would refresh every second)
test("h24 bk d: a window that stays put costs no refresh in the one-second check", function()
	local w, r, Mod = rider()
	openMap(w, r)
	w:advance(2.5)
	local n = 0
	local real = Mod.Refresh
	Mod.Refresh = function(...) n = n + 1 return real(...) end
	w:advance(5)
	Mod.Refresh = real
	eq(n, 0, "no refresh in 5 s while Wuber's window does not change")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua hookWin: the OnShow hook dropped (a window shown over a tag would wait for the one-second check)
test("h24 bk d: Wuber's window shown over a tag moves the tag at once", function()
	local w, r, Mod = rider()
	local F, P = fakeWindow(r)
	openMap(w, r)
	w:advance(0.3)
	placeAt(F, Mod.Pins()[1].marker, 20)
	F:Show()
	w:advance(0.01)
	clear(Mod, P, "shown")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua Mod.Refresh: hookWin() dropped (a window built after the map opened is hooked by the next refresh)
test("h24 bk d: a window that appears after the map opened is hooked by the next refresh", function()
	local w, r, Mod = rider()
	openMap(w, r)
	w:advance(0.3)
	local F, P = fakeWindow(r)
	r.W.Fire("PAGE")
	w:advance(0.01)
	placeAt(F, Mod.Pins()[1].marker, 20)
	F:Show()
	w:advance(0.01)
	clear(Mod, P, "late window, next refresh")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua watch(): hookWin() dropped (a window built after the map opened is hooked by the one-second check)
test("h24 bk d: a window that appears after the map opened is hooked by the one-second check", function()
	local w, r, Mod = rider()
	openMap(w, r)
	w:advance(1.3)
	local F, P = fakeWindow(r)
	w:advance(1.5)
	placeAt(F, Mod.Pins()[1].marker, 20)
	F:Show()
	w:advance(0.01)
	clear(Mod, P, "late window, one-second check")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua onWinResize / hookWin: the OnSizeChanged hook dropped; winResizePending never cleared; the 0.05 s delay made 2 s
test("h24 bk d: a window that grows over a tag moves it within a moment, each time it grows", function()
	local w, r, Mod = rider()
	local F, P = fakeWindow(r)
	openMap(w, r)
	w:advance(0.3)
	local marker = Mod.Pins()[1].marker
	local function grow(width)
		F:SetWidth(width)
		local f = F:GetScript("OnSizeChanged")
		ok(f ~= nil, "the window has a size script")
		if f then f(F, width, 300) end
	end
	F:SetHeight(300)
	F:ClearAllPoints()
	F:SetPoint("RIGHT", marker, "CENTER", -60, 0)
	F:SetWidth(40)
	F:Show()
	w:advance(1.2)
	grow(41)
	w:advance(0.2)
	-- the window now reaches from 60 units left of the point to 20 units right of it: a second size change
	F:ClearAllPoints()
	F:SetPoint("LEFT", marker, "CENTER", 20, 0)
	grow(200)
	w:advance(0.2)
	clear(Mod, P, "grown")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua W.Listen("FOLD", onWinChange) dropped
test("h24 bk d: Wuber folding or unfolding moves a tag the window now covers", function()
	local w, r, Mod = rider()
	local F, P = fakeWindow(r)
	openMap(w, r)
	w:advance(0.3)
	local marker = Mod.Pins()[1].marker
	F:ClearAllPoints()
	F:SetPoint("RIGHT", marker, "CENTER", -100, 0)
	F:Show()
	w:advance(0.2)
	placeAt(F, marker, 20)
	r.W.Fire("FOLD", true, "ride")
	w:advance(0.01)
	clear(Mod, P, "after FOLD")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua W.Listen("PAGE", onWinChange) dropped
test("h24 bk d: Wuber changing page moves a tag the window now covers", function()
	local w, r, Mod = rider()
	local F, P = fakeWindow(r)
	openMap(w, r)
	w:advance(0.3)
	local marker = Mod.Pins()[1].marker
	F:ClearAllPoints()
	F:SetPoint("RIGHT", marker, "CENTER", -100, 0)
	F:Show()
	w:advance(0.2)
	placeAt(F, marker, 20)
	r.W.Fire("PAGE")
	w:advance(0.01)
	clear(Mod, P, "after PAGE")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/FlightPins.lua hookWin: { ui.top, ui.phone } written as { ui.phone } (no OnDragStop hook on the header)
test("h24 bk d: dropping Wuber by its header over a price tag clears the tag at once", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000 })
	local Mod = r.W.Mod("UI.FlightPins")
	openMap(w, r)
	w:advance(0.5)
	local marker = Mod.Pins()[1].marker
	r.W.UI.Toggle(true)
	w:advance(0.5)
	local ui = r.W.UI.state
	local top = ui.top
	top:GetScript("OnDragStart")(top)
	ui.win:ClearAllPoints()
	ui.win:SetPoint("LEFT", marker, "CENTER", 40, 0)
	top:GetScript("OnDragStop")(top)
	w:advance(0.1)
	clear(Mod, ui.phone or ui.win, "dropped by the header")
	T.clean(w)
end)
