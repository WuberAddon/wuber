-- r49 D (F030-F032, F053): nothing of the flight map's price pins is drawn over or under Wuber's window.
-- The hunt's layout check named the 38 x 38 marker ring (a box) meeting WuberFrame; the tag already stepped aside.
-- Promise: with Wuber's window shown over the map, no shown marker and no shown tag meets it, at every place
-- the window can sit over the flight point; with Wuber closed the pin sits as before.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, heard = r.env.GetTime() }
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	return w, r, Mod
end

local function pinsClear(Mod, winRect, what)
	local seen = 0
	for _, p in ipairs(Mod.Pins()) do
		if p.marker and H.visible(p.marker) then
			seen = seen + 1
			ok(not overlaps(H.rect(p.marker), winRect), what .. ": the marker ring is not over Wuber's window")
		end
		if p.tag and H.visible(p.tag) then
			seen = seen + 1
			ok(not overlaps(H.rect(p.tag), winRect), what .. ": the price tag is not over Wuber's window")
		end
	end
	return seen
end

test("r49 d: marker rings and tags step aside from Wuber's window at every offset over the flight point", function()
	local w, r, Mod = setup()
	local pin = Mod.Pins()[1]
	ok(pin and pin.marker and H.visible(pin.marker), "the marker shows with Wuber closed")
	local mr = H.rect(pin.marker)
	local mcx, mcy = mr.l + mr.w / 2, mr.b + mr.h / 2
	r.W.UI.Toggle(true)
	w:advance(0.5)
	local win = r.W.UI.state.win
	local ph = r.W.UI.state.phone or win
	local swept = 0
	-- the window's left edge sweeps from well left of the point to well right of it, and its middle from below to above
	for _, dx in ipairs({ -400, -120, -40, -19, -5, 0, 5, 19, 40, 120, 400 }) do
		for _, dy in ipairs({ -300, -60, 0, 60, 300 }) do
			win:ClearAllPoints()
			win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", mcx + dx, mcy + dy)
			w:advance(1.1)
			swept = swept + 1
			pinsClear(Mod, H.rect(ph), "dx " .. dx .. " dy " .. dy)
		end
	end
	eq(swept, 55, "every window place was tried")
	T.clean(w)
end)

-- guard: the same move seen by the once-a-second check alone, at two step sizes, ends clear (the event path is covered above)
test("r49 d: after a window move the marker and tag are clear at 1 s and at 5 s steps", function()
	for _, step in ipairs({ 1, 5 }) do
		local w, r, Mod = setup()
		local mr = H.rect(Mod.Pins()[1].marker)
		r.W.UI.Toggle(true)
		w:advance(0.5)
		local win = r.W.UI.state.win
		local ph = r.W.UI.state.phone or win
		win:ClearAllPoints()
		win:SetPoint("CENTER", r.env.UIParent, "BOTTOMLEFT", mr.l + mr.w / 2 + 10, mr.b + mr.h / 2)
		for _ = 1, 5 do
			w:advance(step)
			pinsClear(Mod, H.rect(ph), "step " .. step)
		end
		T.clean(w)
	end
end)

-- Promise: no pin ring or tag meets ANY shown Wuber frame (the drive mini card, the drive button, the news card...),
-- not only the window; at 1 s and 5 s steps, when it appears, moves and goes.
test("r49 d: pins step aside from the drive mini card and every other shown Wuber frame, at 1 s and 5 s steps", function()
	for _, name in ipairs({ "WuberDriveMini", "WuberDriveButton", "WuberNewsCard", "WuberInFlight" }) do
		for _, step in ipairs({ 1, 5 }) do
			local w, r, Mod = setup()
			local mr = H.rect(Mod.Pins()[1].marker)
			local f = H.createFrame(r, "Frame", name, r.env.UIParent)
			f:SetSize(120, 60)
			f:SetPoint("CENTER", r.env.UIParent, "BOTTOMLEFT", mr.l + mr.w / 2 + 20, mr.b + mr.h / 2)
			f:Show()
			-- a frame that moves with no event of its own (the mini card follows the window a moment after a fold)
			-- is seen by the map watch within half a second
			w:advance(0.5)
			pinsClear(Mod, H.rect(f), name .. " half a second after it showed")
			for _ = 1, 4 do
				w:advance(step)
				ok(pinsClear(Mod, H.rect(f), name .. " step " .. step) >= 0, "swept")
			end
			-- moved off the point: the pin comes back
			f:ClearAllPoints()
			f:SetPoint("CENTER", r.env.UIParent, "BOTTOMLEFT", mr.l + mr.w / 2 + 500, mr.b + mr.h / 2 + 300)
			for _ = 1, 3 do w:advance(step) end
			local pin = Mod.Pins()[1]
			ok(pin.marker and H.visible(pin.marker), name .. " step " .. step .. ": the ring returns when the frame is gone from the point")
			ok(pin.tag and H.visible(pin.tag), name .. " step " .. step .. ": the tag returns too")
			f:Hide()
			w:advance(step)
			T.clean(w)
		end
	end
end)

-- guard: with Wuber closed the marker ring and the tag place as before (this also passes on the base)
test("r49 d: with Wuber closed the marker sits on the flight point and the tag shows beside it", function()
	local w, r, Mod = setup()
	local pin = Mod.Pins()[1]
	ok(pin.tag and H.visible(pin.tag), "the tag shows")
	ok(pin.marker and H.visible(pin.marker), "the marker shows")
	r.W.UI.Toggle(true)
	w:advance(0.5)
	r.W.UI.Toggle(false)
	w:advance(1.1)
	pin = Mod.Pins()[1]
	ok(pin.tag and H.visible(pin.tag), "the tag returns when Wuber closes")
	ok(pin.marker and H.visible(pin.marker), "the marker returns when Wuber closes")
	T.clean(w)
end)
