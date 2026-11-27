-- r51 group P (F006): two flight map price tags never lie over each other when a free side exists, also after Wuber's
-- window is dropped over a tag. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function addDriver(r, key, dest, price)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers[key] = { name = key, key = key, dest = dest, price = price, state = "open", team = 3, heard = r.env.GetTime() }
end

local function boxOf(f)
	local b = H.rect(f)
	return { l = b.l, r = b.l + b.w, b = b.b, t = b.b + b.h }
end
local function touch(a, b) return a.l + 0.5 < b.r and b.l + 0.5 < a.r and a.b + 0.5 < b.t and b.b + 0.5 < a.t end

local PLACES = { "Orgrimmar", "Crossroads", "Ratchet", "Camp Taurajo", "Splintertree Post", "Astranaar", "Thalanaar", "Feathermoon Stronghold" }
local PRICES = { 500, 15000, 2000, 12500, 700, 30000, 100, 99900 }

local function crowded(dropAt)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	for i, p in ipairs(PLACES) do addDriver(r, "drv" .. i, p, PRICES[i]) end
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = PLACES }))
	w:advance(1.2)
	local FP = r.W.Mod("UI.FlightPins")
	if dropAt then
		r.W.UI.Toggle(true)
		w:advance(0.6)
		local win = r.W.Mod("UI.Kit").ui.win or r.W.Mod("UI.Kit").ui.phone
		local pins = FP.Pins()
		local tag
		for _, p in ipairs(pins) do if p.tag and p.tag:IsShown() then tag = p.tag break end end
		if tag and win then
			local tr, before = H.rect(tag), H.rect(win)
			win:ClearAllPoints()
			win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", before.l, before.b + before.h / 2)
			local k = H.rect(win).l / before.l
			win:ClearAllPoints()
			win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", (tr.l + 2) / k, (tr.b + tr.h / 2) / k)
			w:advance(0.6)
		end
	end
	return FP
end

local function pairsTouching(FP)
	local shown = {}
	for _, p in ipairs(FP.Pins()) do if p.tag and p.tag:IsShown() then shown[#shown + 1] = p end end
	local bad = {}
	for i = 1, #shown do
		for j = i + 1, #shown do
			if touch(boxOf(shown[i].tag), boxOf(shown[j].tag)) then bad[#bad + 1] = shown[i].tag.text:GetText() .. " / " .. shown[j].tag.text:GetText() end
		end
	end
	return bad, #shown
end

-- guard: the crowded map without a window drop already placed every tag clear
test("r51 P F006: no two price tags overlap on a crowded flight map", function()
	local FP = crowded(false)
	local bad, n = pairsTouching(FP)
	ok(n >= 2, "several tags shown (" .. n .. ")")
	eq(#bad, 0, "tags touching: " .. table.concat(bad, ", "))
end)

test("r51 P F006: no two price tags overlap after Wuber's window is dropped over a tag", function()
	local FP = crowded(true)
	local bad, n = pairsTouching(FP)
	ok(n >= 1, "tags shown (" .. n .. ")")
	eq(#bad, 0, "tags touching: " .. table.concat(bad, ", "))
end)

-- guard: a lone pin's tag sits where it did, to the right of its flight point
test("r51 P F006 guard: a lone pin's tag sits on the right of its flight point", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "solo", "Orgrimmar", 5000)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(1.2)
	local pins = r.W.Mod("UI.FlightPins").Pins()
	eq(#pins, 1, "one pin")
	local tr = H.rect(pins[1].tag)
	local mk = H.rect(pins[1].marker)
	ok(tr.l >= mk.l + mk.w / 2, "tag starts right of the marker centre")
	eq(math.floor(tr.b + tr.h / 2 + 0.5), math.floor(mk.b + mk.h / 2 + 0.5), "tag is level with the flight point")
end)
