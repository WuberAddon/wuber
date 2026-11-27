-- Wuber 2.4, part 5bc: aura colour contrast and "Wuber only" map veil. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function linear(c)
	return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(col)
	return 0.2126 * linear(col[1]) + 0.7152 * linear(col[2]) + 0.0722 * linear(col[3])
end

local function contrastRatio(a, b)
	local la, lb = luminance(a), luminance(b)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end

local function findPin(child, key)
	for _, f in ipairs({ child:GetChildren() }) do
		if f.key == key and H.visible(f) then return f end
	end
end

local function tipOf(c, f)
	local gt = c.env.GameTooltip
	H.state[gt].tipLines = {}
	local fn = H.state[f].scripts and H.state[f].scripts.OnEnter
	ok(fn, "frame has an OnEnter tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(H.state[gt].tipLines or {}) do
		out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l)
	end
	local leave = H.state[f].scripts and H.state[f].scripts.OnLeave
	if leave then leave(f) end
	return table.concat(out, "\n")
end

local function copyTable(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copyTable(v) end
	return out
end

test("v24 veil: the aura's colours show on a light and on a dark map", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)

	local AURA = r.W.Mod("UI.Map.Pins").AURA
	local parchment = { 0.85, 0.76, 0.60 }
	local sea = { 0.07, 0.13, 0.22 }
	local arcs = { AURA.violet, AURA.gold, AURA.teal }

	local outlineVsParchment = contrastRatio(AURA.outline, parchment)
	ok(outlineVsParchment >= 3, "outline vs parchment reaches 3:1 (" .. string.format("%.2f", outlineVsParchment) .. ")")

	local lightHits = 0
	for i = 1, #arcs do
		if contrastRatio(arcs[i], AURA.outline) >= 3 then lightHits = lightHits + 1 end
	end
	ok(lightHits >= 2, "at least two arcs reach 3:1 against the outline (" .. lightHits .. ")")

	local darkHits = 0
	for i = 1, #arcs do
		if contrastRatio(arcs[i], sea) >= 3 then darkHits = darkHits + 1 end
	end
	ok(darkHits >= 2, "at least two arcs reach 3:1 against the dark sea (" .. darkHits .. ")")

	T.clean(w)
end)

test("v24 veil: clicking 'Wuber only' shows the veil below the pin with mouse off, saves mapOnly and toggles off", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)

	local fired = {}
	r.W.Listen("SETTINGS", function(what) fired[#fired + 1] = what end)

	ok(r.W.Map.ShowDriver("bob stone"), "ShowDriver opens the map on Bob")
	w:advance(0.1)

	local child = r.env.WorldMapFrame.ScrollContainer.Child
	local pin = findPin(child, "bob stone")
	ok(pin, "open driver's pin is showing on the world map")

	local pill = r.W.Map.OnlyPill()
	ok(pill and H.visible(pill), "Wuber only pill is shown")
	local tip = tipOf(r, pill)
	ok(tip:find("Wuber only", 1, true), "tooltip title says Wuber only")
	ok(tip:find("Dims the rest of the map so Wuber's pins stand out.", 1, true), "tooltip text matches")

	local veilBefore = r.W.Map.Veil()
	ok(not (veilBefore and H.visible(veilBefore)), "veil is not shown before toggling on")
	local offR, offG, offB = pill.parts[1]:GetVertexColor()

	r:clickOn(r.W.Map.OnlyPill())
	eq(r.W.db.mapOnly, true, "W.db.mapOnly is saved true")
	eq(fired[#fired], "mapOnly", "SETTINGS fired with mapOnly")

	local veil = r.W.Map.Veil()
	ok(veil and H.visible(veil), "clicking the pill shows the veil")
	eq(veil:GetParent(), child, "veil is parented to the map canvas")
	ok(not veil:IsMouseEnabled(), "veil has mouse off")
	ok(veil:GetFrameLevel() < pin:GetFrameLevel(), "veil frame level is below the pin's")

	local regs = { veil:GetRegions() }
	eq(#regs, 1, "veil holds one region")
	eq(regs[1]:GetObjectType(), "Texture", "veil region is a texture")

	local onR, onG, onB = pill.parts[1]:GetVertexColor()
	ok(onR ~= offR or onG ~= offG or onB ~= offB, "pill changes to active look")

	r:clickOn(r.W.Map.OnlyPill())
	eq(r.W.db.mapOnly, nil, "clicking again saves nil")
	eq(fired[#fired], "mapOnly", "SETTINGS fired with mapOnly on toggle off")
	ok(not H.visible(veil), "clicking again hides the veil")

	local backR, backG, backB = pill.parts[1]:GetVertexColor()
	eq(backR, offR, "pill red returns to inactive look")
	eq(backG, offG, "pill green returns to inactive look")
	eq(backB, offB, "pill blue returns to inactive look")

	T.clean(w)
end)

test("v24 veil: saved mapOnly applies on fresh map open and reload, hides on close and with SetShown(false)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)

	ok(r.W.Map.ShowDriver("anita lift"), "open world map")
	w:advance(0.1)
	r:clickOn(r.W.Map.OnlyPill())
	eq(r.W.db.mapOnly, true, "mapOnly saved true before reload")
	local saved = { Wuber = copyTable(r.env.WuberDB) }
	T.clean(w)

	local w2 = T.newWorld()
	local r2 = T.rider(w2, T.TESTCHAR, { saved = saved })
	T.settle(w2)

	eq(r2.W.db.mapOnly, true, "mapOnly survives reload")
	eq(r2.W.Map.Veil(), nil, "veil is not shown before opening the map")

	r2.env.WorldMapFrame:SetMapID(1413)
	r2.env.WorldMapFrame:Show()
	w2:advance(0.1)

	local veil = r2.W.Map.Veil()
	local pill = r2.W.Map.OnlyPill()
	ok(veil and H.visible(veil), "fresh open of the map after reload shows the veil")
	ok(pill and H.visible(pill), "fresh open of the map shows the pill")

	r2.env.WorldMapFrame:Hide()
	w2:advance(0.1)
	ok(not H.visible(veil), "closing the map hides the veil")
	ok(not H.visible(pill), "closing the map hides the pill")

	r2.env.WorldMapFrame:Show()
	w2:advance(0.1)
	ok(H.visible(veil), "reopening the map shows the veil again")

	r2.W.Map.SetShown(false)
	ok(not H.visible(veil), "SetShown(false) hides the veil")
	ok(not H.visible(pill), "SetShown(false) hides the pill")
	eq(r2.W.db.mapOnly, true, "SetShown(false) keeps mapOnly saved")

	r2.W.Map.SetShown(true)
	ok(H.visible(veil), "SetShown(true) shows the veil again")
	ok(H.visible(pill), "SetShown(true) shows the pill again")

	T.clean(w2)
end)
