-- r52 C: audit #3 (FlightPins ipairs nil hole) and #5 (Wizard step 2 fixed 56 px row step).
-- Promise 3: a marker is placed against the first map area that exists: the route map, else the map art (InsetBg).
-- Promise 5: Wizard step 2 rows never overlap each other or the "Add by name" box, whatever the row height.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function pinSetup()
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

test("r52 c: with no route map, the marker sits in the map art (InsetBg), not the outer frame", function()
	local w, r, Mod = pinSetup()
	local env = r.env
	local tf = env.TaxiFrame
	ok(tf, "control: TaxiFrame exists")
	-- no TaxiButtons shown (skinned map), no TaxiRouteMap: the node-position fallback decides
	for i = 1, 60 do
		local b = rawget(env, "TaxiButton" .. i)
		if b then b:Hide() end
	end
	env.TaxiRouteMap = nil
	local bg = tf.InsetBg or env.CreateFrame("Frame", "TaxiFrameInsetBgC", tf)
	tf.InsetBg = bg
	bg:ClearAllPoints()
	-- a small corner of the frame, so a point placed against the whole frame cannot land inside it by chance
	bg:SetPoint("TOPLEFT", tf, "TOPLEFT", 10, -30)
	bg:SetSize(120, 100)
	bg:Show()
	Mod.Refresh()
	w:advance(1.1)
	local pin = Mod.Pins()[1]
	ok(pin and pin.marker and H.visible(pin.marker), "the marker shows")
	local m, a = H.rect(pin.marker), H.rect(bg)
	local cx, cy = m.l + m.w / 2, m.b + m.h / 2
	ok(cx >= a.l - 1 and cx <= a.l + a.w + 1 and cy >= a.b - 1 and cy <= a.b + a.h + 1,
		string.format("the marker centre (%.0f, %.0f) is inside the map art (%.0f..%.0f, %.0f..%.0f)", cx, cy, a.l, a.l + a.w, a.b, a.b + a.h))
	T.clean(w)
end)

test("r52 c: the wizard's step 2 rows never overlap, even when a row grows tall", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Wanda Lock", { spot = "Ratchet", class = "WARLOCK" })
	w:addBot("Wim Mage", { spot = "Ratchet", class = "MAGE" })
	w:group({ T.ANITA, "Wanda Lock", "Wim Mage" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	local ui = d.W.Driver.ui.subs.wizard
	-- a tall row: three wrapped lines (as a long status gives), applied on every paint
	for _, row in ipairs(ui.people.list) do
		local set = row.SetHeight
		row.SetHeight = function(self, h) return set(self, math.max(h, 90)) end
	end
	d.W.Driver.Refresh(true) w:advance(1)
	ok(#d:findText("Pick your crew") > 0, "control: still on step 2")
	local rows = {}
	for _, row in ipairs(ui.people.list) do
		if H.visible(row) then rows[#rows + 1] = row end
	end
	ok(#rows >= 2, "control: at least two person rows show (" .. #rows .. ")")
	for i = 2, #rows do
		local up, lo = H.rect(rows[i - 1]), H.rect(rows[i])
		ok(lo.b + lo.h <= up.b + 0.5, "row " .. i .. " starts below row " .. (i - 1) .. " (it was drawn over it)")
	end
	local last = H.rect(rows[#rows])
	ok(ui.adder and H.visible(ui.adder), "control: the Add by name box shows")
	local ad = H.rect(ui.adder)
	ok(ad.b + ad.h <= last.b + 0.5, "the Add by name box starts below the last row")
	T.clean(w)
end)
