-- Wuber 2.4, part 5a: three-colour turning aura on map pins and flight map markers. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state

local LAYER_ORDER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local function vertexColour(tex)
	if type(tex.GetVertexColor) == "function" then
		local r, g, b, a = tex:GetVertexColor()
		if r ~= nil then return r, g, b, a end
	end
	local st = S and S[tex]
	if st then
		local c = st.vertexColor or st.color or st.vc
		if type(c) == "table" then return c[1], c[2], c[3], c[4] end
	end
end

local function drawLayer(tex)
	if type(tex.GetDrawLayer) == "function" then
		local layer = tex:GetDrawLayer()
		if layer then return layer end
	end
	local st = S and S[tex]
	return st and st.layer
end

local function rotationOf(tex)
	if type(tex.GetRotation) == "function" then
		local rot = tex:GetRotation()
		if rot ~= nil then return rot end
	end
	local st = S and S[tex]
	return st and st.rotation
end

local function sameColour(tex, want, what)
	local r, g, b, a = vertexColour(tex)
	ok(r ~= nil and g ~= nil and b ~= nil, what .. ": vertex colour readable")
	ok(math.abs(r - want[1]) < 0.01, what .. ": red matches")
	ok(math.abs(g - want[2]) < 0.01, what .. ": green matches")
	ok(math.abs(b - want[3]) < 0.01, what .. ": blue matches")
	if want[4] ~= nil and a ~= nil then
		ok(math.abs(a - want[4]) < 0.01, what .. ": alpha matches")
	end
end

local function hasScaleAnim(obj)
	local groups = {}
	if type(obj.GetAnimationGroups) == "function" then
		local list = { obj:GetAnimationGroups() }
		for i = 1, #list do
			if type(list[i]) == "table" then groups[#groups + 1] = list[i] end
		end
	end
	local st = S and S[obj]
	if st then
		for _, key in ipairs({ "animGroups", "animationGroups", "anims", "groups" }) do
			local t = st[key]
			if type(t) == "table" then
				for i = 1, #t do
					if type(t[i]) == "table" then groups[#groups + 1] = t[i] end
				end
			end
		end
	end
	if type(obj.wuberAnims) == "table" then
		for _, g in pairs(obj.wuberAnims) do
			if type(g) == "table" then groups[#groups + 1] = g end
		end
	end
	for i = 1, #groups do
		local ag = groups[i]
		local anims = {}
		if type(ag.GetAnimations) == "function" then
			local list = { ag:GetAnimations() }
			for j = 1, #list do
				if type(list[j]) == "table" then anims[#anims + 1] = list[j] end
			end
		end
		local agst = S and S[ag]
		if agst then
			for _, key in ipairs({ "animations", "anims" }) do
				local t = agst[key]
				if type(t) == "table" then
					for j = 1, #t do
						if type(t[j]) == "table" then anims[#anims + 1] = t[j] end
					end
				end
			end
		end
		for j = 1, #anims do
			local a = anims[j]
			local kind = type(a.GetObjectType) == "function" and a:GetObjectType() or (S and S[a] and (S[a].kind or S[a].type or S[a].objectType))
			if kind == "Scale" then return true end
		end
	end
	return false
end

local function hasFontString(frame)
	if type(frame.GetRegions) == "function" then
		local regs = { frame:GetRegions() }
		for i = 1, #regs do
			local reg = regs[i]
			local kind = type(reg) == "table" and (type(reg.GetObjectType) == "function" and reg:GetObjectType() or (S and S[reg] and S[reg].type))
			if kind == "FontString" then return true end
		end
	end
	local st = S and S[frame]
	if st and type(st.regions) == "table" then
		for i = 1, #st.regions do
			local reg = st.regions[i]
			local kind = type(reg) == "table" and (type(reg.GetObjectType) == "function" and reg:GetObjectType() or (S and S[reg] and S[reg].type))
			if kind == "FontString" then return true end
		end
	end
	if type(frame.GetChildren) == "function" then
		local kids = { frame:GetChildren() }
		for i = 1, #kids do
			if type(kids[i]) == "table" and hasFontString(kids[i]) then return true end
		end
	end
	return false
end

local function addDriver(r, key, opts)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers[key] = {
		name = opts.name or key,
		key = key,
		dest = opts.dest,
		price = opts.price or 5000,
		state = opts.state or "open",
		team = opts.team or 3,
		service = opts.service,
		heard = r.env.GetTime(),
	}
end

test("v24 aura: Mod.Aura builds three coloured arcs, a dark outline under them, and has mouse off", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)

	local Pins = r.W.Mod("UI.Map.Pins")
	ok(type(Pins.Aura) == "function", "Pins.Aura builder exported")
	ok(type(Pins.AURA) == "table", "Pins.AURA colour table exported")

	local host = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	host:SetSize(32, 32)
	local aura = Pins.Aura(host, 32)

	ok(aura and aura.frame and aura.outline and aura.arcs, "aura returns frame, outline and arcs")
	eq(aura.frame:GetParent(), host, "aura frame is a child of host")
	eq(aura.frame:GetWidth(), 56, "aura frame width matches outline")
	eq(aura.frame:GetHeight(), 56, "aura frame height matches outline")
	ok(not aura.frame:IsMouseEnabled(), "aura frame takes no mouse")

	eq(#aura.arcs, 3, "three arc textures")
	sameColour(aura.arcs[1], Pins.AURA.violet, "first arc violet")
	sameColour(aura.arcs[2], Pins.AURA.gold, "second arc gold")
	sameColour(aura.arcs[3], Pins.AURA.teal, "third arc teal")
	for i = 1, 3 do
		local tex = tostring(aura.arcs[i]:GetTextureFilePath() or "")
		ok(tex:find("Media\\arc", 1, true) ~= nil, "arc " .. i .. " uses Media\\arc")
	end

	sameColour(aura.outline, Pins.AURA.outline, "dark outline colour")
	local oTex = tostring(aura.outline:GetTextureFilePath() or "")
	ok(oTex:find("Media\\ring", 1, true) ~= nil, "outline uses Media\\ring")
	eq(aura.outline:GetWidth(), 56, "outline is 2 * (R + 3)")
	eq(aura.outline:GetHeight(), 56, "outline height is 2 * (R + 3)")

	local oLayer = drawLayer(aura.outline)
	local aLayer = drawLayer(aura.arcs[1])
	if oLayer and aLayer and LAYER_ORDER[oLayer] and LAYER_ORDER[aLayer] then
		ok(LAYER_ORDER[oLayer] < LAYER_ORDER[aLayer], "outline is drawn under the arcs")
	end

	aura:SetSize(40)
	eq(aura.frame:GetWidth(), 64, "SetSize resizes frame to outline")
	eq(aura.outline:GetWidth(), 64, "SetSize recomputes outline from new inner diameter")
	local v40 = 2 * (40 / 2 + 9) / 0.81
	ok(math.abs(aura.arcs[1]:GetWidth() - v40) < 0.01, "SetSize recomputes violet arc")
	ok(math.abs(aura.arcs[2]:GetWidth() - (v40 - 6)) < 0.01, "SetSize recomputes gold arc")
	ok(math.abs(aura.arcs[3]:GetWidth() - (v40 - 12)) < 0.01, "SetSize recomputes teal arc")
	T.clean(w)
end)

test("v24 aura: turns on fx full, shown still in three colours on light and off, follows SETTINGS fx", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)

	local Pins = r.W.Mod("UI.Map.Pins")
	local host = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	host:SetSize(32, 32)
	local aura = Pins.Aura(host, 32)

	r.W.db.fx = "full"
	aura:Start()
	ok(H.visible(aura.frame), "shown on full fx")
	ok(aura:Turning(), "turning on full fx")

	w:advance(0.2)
	local r0 = rotationOf(aura.arcs[1])
	w:advance(1)
	local r1 = rotationOf(aura.arcs[1])
	if r0 ~= nil and r1 ~= nil then
		ok(math.abs(r1 - r0) > 0.01, "arc rotation advances over time while turning")
	end

	r.W.db.fx = "light"
	r.W.Fire("SETTINGS", "fx")
	ok(H.visible(aura.frame), "stays shown when SETTINGS switches fx to light")
	ok(not aura:Turning(), "stops turning when SETTINGS switches fx to light")

	aura:Start()
	ok(H.visible(aura.frame), "shown on light fx after Start")
	ok(not aura:Turning(), "not turning on light fx")
	sameColour(aura.arcs[1], Pins.AURA.violet, "light fx arc 1 violet")
	sameColour(aura.arcs[2], Pins.AURA.gold, "light fx arc 2 gold")
	sameColour(aura.arcs[3], Pins.AURA.teal, "light fx arc 3 teal")
	local rLight0 = rotationOf(aura.arcs[1])
	w:advance(1)
	local rLight1 = rotationOf(aura.arcs[1])
	if rLight0 ~= nil and rLight1 ~= nil then
		eq(rLight1, rLight0, "arc stays still on light fx")
	end

	r.W.db.fx = "off"
	aura:Start()
	ok(H.visible(aura.frame), "shown on off fx")
	ok(not aura:Turning(), "not turning on off fx")
	sameColour(aura.arcs[1], Pins.AURA.violet, "off fx arc 1 violet")
	sameColour(aura.arcs[2], Pins.AURA.gold, "off fx arc 2 gold")
	sameColour(aura.arcs[3], Pins.AURA.teal, "off fx arc 3 teal")

	r.W.db.fx = "full"
	r.W.Fire("SETTINGS", "fx")
	ok(aura:Turning(), "resumes turning when SETTINGS switches fx back to full")

	aura:Stop()
	ok(not aura:Turning(), "Stop stops turning")
	aura:Hide()
	ok(not H.visible(aura.frame), "Hide hides aura frame")
	T.clean(w)
end)

test("v24 aura: open driver map pin wears shown aura; busy or closed does not; hiding stops it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)

	r.W.db.fx = "full"
	local Pins = r.W.Mod("UI.Map.Pins")
	local pin = Pins.NewPin(r.env.UIParent)
	ok(pin.auraRing, "pin builds an aura once")
	ok(not pin.auraRing.frame:IsShown(), "aura starts hidden on a fresh pin")

	local openD = { key = "anita lift", name = T.ANITA, dest = "Ratchet", price = 5000, state = "open", team = 3 }
	local busyD = { key = "anita lift", name = T.ANITA, dest = "Ratchet", price = 5000, state = "busy", team = 3 }
	local closedD = { key = "anita lift", name = T.ANITA, dest = "Ratchet", price = 5000, state = "closed", team = 3 }

	Pins.SetLevels(pin, 100)
	Pins.Paint(pin, openD, false, 0.8, false)
	pin:Show()
	local aura = pin.auraRing
	ok(H.visible(aura.frame), "open driver pin wears a shown aura")
	ok(aura:Turning(), "open driver pin aura turns on full fx")
	ok(aura.frame:GetFrameLevel() < pin.body:GetFrameLevel(), "aura sits under pin body and gold ring")

	Pins.Paint(pin, busyD, false, 0, false)
	eq(pin.auraRing, aura, "pin reuses the same aura")
	ok(not aura.frame:IsShown(), "busy driver pin hides aura")
	ok(not aura:Turning(), "busy driver pin stops aura")

	Pins.Paint(pin, closedD, false, 0, false)
	ok(not aura.frame:IsShown(), "closed driver pin hides aura")
	ok(not aura:Turning(), "closed driver pin stops aura")

	Pins.Paint(pin, openD, true, 0.8, false)
	ok(H.visible(aura.frame) and aura:Turning(), "re-painted open driver starts aura again")
	ok(H.visible(pin.halo), "chosen pin gold ring still shows")
	ok(H.visible(pin.tag), "chosen pin price tag still shows")
	ok(pin.pulsing, "chosen pin pulse still runs")

	pin:Hide()
	ok(not aura:Turning(), "hiding the pin stops the aura")
	ok(not aura.frame:IsShown(), "hiding the pin hides the aura")
	T.clean(w)
end)

test("v24 aura: no Scale animation on the aura or pin tag, no font string inside the aura frame", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)

	r.W.db.fx = "full"
	local Pins = r.W.Mod("UI.Map.Pins")
	local pin = Pins.NewPin(r.env.UIParent)
	local openD = { key = "anita lift", name = T.ANITA, dest = "Ratchet", price = 5000, state = "open", team = 3 }
	Pins.Paint(pin, openD, true, 0.8, false)
	pin:Show()

	local aura = pin.auraRing
	ok(not hasScaleAnim(pin), "no Scale animation on pin itself")
	ok(not hasScaleAnim(aura.frame), "no Scale animation on aura frame")
	ok(not hasScaleAnim(aura.outline), "no Scale animation on aura outline")
	for i = 1, 3 do
		ok(not hasScaleAnim(aura.arcs[i]), "no Scale animation on aura arc " .. i)
	end
	if aura.driver then
		ok(not hasScaleAnim(aura.driver), "no Scale animation on aura driver")
	end
	ok(not hasScaleAnim(pin.tag), "no Scale animation on pin tag")

	ok(not hasFontString(aura.frame), "aura frame holds no font string")
	eq(pin.tag:GetParent(), pin, "pin tag is a child of pin")
	ok(pin.tag:GetParent() ~= aura.frame, "pin tag is not a child of aura frame")
	ok(pin.tagText:GetParent() ~= aura.frame, "pin tag text is not a child of aura frame")
	T.clean(w)
end)

test("v24 aura: flight map marker of an open driver wears the aura with mouse off and TAXIMAP_CLOSED stops it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.db.fx = "full"
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000, state = "open" })

	local FlightMod = r.W.Mod("UI.FlightPins")
	local Pins = r.W.Mod("UI.Map.Pins")
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	w:openTaxiMap(r, nodes)
	w:advance(0.5)

	local pins = FlightMod.Pins()
	eq(#pins, 1, "one flight map pin shown")
	local m = pins[1].marker
	ok(m and H.visible(m), "flight map marker visible")
	eq(m:GetWidth(), 38, "flight map marker width matches 2 * (R + 3)")
	eq(m:GetHeight(), 38, "flight map marker height matches 2 * (R + 3)")
	ok(m.aura and H.visible(m.aura.frame), "flight map marker wears the shown aura")
	eq(m.aura.frame:GetWidth(), 38, "flight map marker aura matches marker size")
	eq(#m.aura.arcs, 3, "flight map marker aura has three arcs")
	sameColour(m.aura.arcs[1], Pins.AURA.violet, "flight marker arc 1 violet")
	sameColour(m.aura.arcs[2], Pins.AURA.gold, "flight marker arc 2 gold")
	sameColour(m.aura.arcs[3], Pins.AURA.teal, "flight marker arc 3 teal")
	eq(m.ring, nil, "flight map marker uses aura instead of plain ring")
	ok(m.aura:Turning(), "flight map marker aura turns on full fx")
	ok(not m:IsMouseEnabled(), "flight map marker keeps mouse off")
	ok(not m.aura.frame:IsMouseEnabled(), "flight map marker aura frame keeps mouse off")
	ok(pins[1].tag and H.visible(pins[1].tag), "flight map price tag still shown")
	local mr = H.rect(m)
	local tr = H.rect(pins[1].tag)
	ok(tr.l + tr.w <= mr.l or mr.l + mr.w <= tr.l or tr.b + tr.h <= mr.b or mr.b + mr.h <= tr.b, "price tag sits beside the whole aura ring")

	w:closeTaxiMap(r)
	w:advance(0.2)
	ok(not m.aura:Turning(), "TAXIMAP_CLOSED stops the flight map marker aura")
	ok(not H.visible(m.aura.frame), "TAXIMAP_CLOSED hides the flight map marker aura")
	ok(not H.visible(m), "TAXIMAP_CLOSED hides the flight map marker")

	r.W.db.fx = "light"
	w:openTaxiMap(r, nodes)
	w:advance(0.5)
	ok(H.visible(m.aura.frame), "reopened on light fx: aura still shown")
	ok(not m.aura:Turning(), "reopened on light fx: aura does not turn")
	w:closeTaxiMap(r)
	T.clean(w)
end)

local function angDiff(a, b)
	local twoPi = math.pi * 2
	local d = (a - b) % twoPi
	if d > math.pi then d = twoPi - d end
	return math.abs(d)
end

test("v24 aura: three bands, each colour shows", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)

	r.W.db.fx = "full"
	local Pins = r.W.Mod("UI.Map.Pins")
	local pin = Pins.NewPin(r.env.UIParent)
	local pinInner = pin:GetWidth()
	eq(pin.auraRing.frame:GetWidth(), 2 * (pinInner / 2 + 9 + 3), "NewPin builds aura around pin body")

	local inner = 14
	local host = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	host:SetSize(inner, inner)
	local aura = Pins.Aura(host, inner)

	local vw, gw, tw = aura.arcs[1]:GetWidth(), aura.arcs[2]:GetWidth(), aura.arcs[3]:GetWidth()
	local ow = aura.outline:GetWidth()
	ok(vw > gw and gw > tw, "three arcs have sizes violet > gold > teal")
	local oOuter = 1.00 * ow / 2
	local vOuter = 0.81 * vw / 2
	local gOuter = 0.81 * gw / 2
	local tOuter = 0.81 * tw / 2
	ok(oOuter > vOuter and vOuter > gOuter and gOuter > tOuter, "outline is the largest outer edge")
	ok(0.53 * tw / 2 >= inner / 2 - 1, "teal arc inner edge is not smaller than half inner minus 1")

	local s1, s2, s3 = rotationOf(aura.arcs[1]), rotationOf(aura.arcs[2]), rotationOf(aura.arcs[3])
	ok(s1 ~= nil and s2 ~= nil and s3 ~= nil, "start rotations readable")
	ok(angDiff(s1, 0) < 0.01, "violet starts at 0 deg")
	ok(angDiff(s2, math.rad(120)) < 0.01, "gold starts at 120 deg")
	ok(angDiff(s3, math.rad(240)) < 0.01, "teal starts at 240 deg")

	aura:Start()
	w:advance(2)
	local r1, r2, r3 = rotationOf(aura.arcs[1]), rotationOf(aura.arcs[2]), rotationOf(aura.arcs[3])
	ok(r1 ~= nil and r2 ~= nil and r3 ~= nil, "turning rotations readable")
	ok(angDiff(r1, s1) > 0.05, "violet rotation differs from start angle")
	ok(angDiff(r2, s2) > 0.05, "gold rotation differs from start angle")
	ok(angDiff(r3, s3) > 0.05, "teal rotation differs from start angle")
	ok(angDiff(r1, r2) > 0.05 and angDiff(r2, r3) > 0.05 and angDiff(r1, r3) > 0.05, "three arcs rotations differ from each other")
	T.clean(w)
end)
