-- Round 24 B1: the Skip-the-bird card's layout. Open Wuber and "Don't show again" never overlap at
-- any label width or UI scale, the card stays on screen, and keeps clear of MinimapCluster (other
-- side of the map first, then below it).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup(screenW, scale)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = screenW or 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	local Mod = W.Mod("UI.Bird")
	if scale then r.env.UIParent:SetScale(scale) end
	w:openTaxiMap(r, { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 } })
	local t0 = r.env.GetTime()
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3, service = "Mia", heard = t0 }
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 540, "est" end
	return w, r, W, Mod
end

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

test("r24 B1: pill and label never overlap and sit inside the card, at several string widths", function()
	local w, r, W, Mod = setup()
	w:advance(0.5)
	local c = Mod.Card()
	ok(c, "card built")
	for _, sw in ipairs({ 40, 76, 100, 150, 220, 400 }) do
		c.never.label.GetStringWidth = function() return sw end
		local cw, ch = Mod.Layout(c)
		local lw = math.max(90, math.ceil(sw) + 2)
		-- anchors, computed: the pill (the "Book" pill, 76 wide) spans 34..110 from the left; the label starts at cw - 10 - lw
		local stacked = 34 + 76 + 10 + lw + 10 > 300
		if not stacked then ok(34 + 76 < cw - 10 - lw, "row: pill ends before label starts at " .. sw) end
		ok(cw >= 34 + 76 + 10 and cw >= lw + 20, "wide enough at " .. sw)
		if stacked then ok(ch >= 74 + 20, "stacked card is taller at " .. sw .. " (" .. ch .. ")") else ok(ch < 74 + 20, "row card is not stacked tall at " .. sw .. " (" .. ch .. ")") end
	end
	T.clean(w)
end)

test("r24 B1: placement stays on screen at several UI scales and never overlaps the map", function()
	for _, sc in ipairs({ 0.64, 1, 1.4 }) do
		local w, r, W, Mod = setup(1365, sc)
		w:advance(0.5)
		local c = Mod.Card()
		ok(c and H.visible(c), "shown at scale " .. sc)
		local cr, mr = H.rect(c), H.rect(r.env.TaxiFrame)
		ok(not overlaps(cr, mr), "not over the map at " .. sc)
		ok(cr.l >= -0.5 and cr.b >= -0.5, "on screen (left, bottom) at " .. sc)
		T.clean(w)
	end
end)

test("r24 B1: clear of the minimap cluster: other side of the map, then below", function()
	local w, r, W, Mod = setup()
	w:advance(0.5)
	local c, env = Mod.Card(), r.env
	local map = env.TaxiFrame
	map:ClearAllPoints()
	-- (rec) near the top: the real TaxiFrame is 638 high, so centred on this 768-high screen it leaves no
	-- room for the card below it (the case this test checks); the 384 x 512 fake one did
	map:SetPoint("TOP", env.UIParent, "TOP", 0, -10)
	local m = H.rect(map)
	local function mini(l, b, wd, ht)
		env.MinimapCluster:ClearAllPoints()
		env.MinimapCluster:SetSize(wd, ht)
		env.MinimapCluster:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", l, b)
		env.MinimapCluster:Show()
	end
	local function side()
		Mod.Place(c, map)
		local cr = H.rect(c)
		return cr.l >= m.l + m.w - 0.5 and "right" or (cr.l + cr.w <= m.l + 0.5 and "left" or (cr.b + cr.h <= m.b + 0.5 and "below" or "over"))
	end
	mini(0, 0, 1, 1) -- far corner: no clash
	local first = side()
	eq(first, "right", "right when clear")
	do
		mini(m.l + m.w + 2, m.b, 210, m.h) -- covers the right spot
		eq(side(), "left", "right blocked: left (map " .. m.l .. "," .. m.w .. "," .. m.b .. "," .. m.h .. ")")
		mini(0, m.b, m.l + m.w + 230, m.h) -- covers both sides
		local s = side()
		eq(s, "below", "both sides blocked: below")
	end
	T.clean(w)
end)

-- the boxes the layout checker uses: the pill's full width, the label's own box (not its string width),
-- also when the font loads after the first layout (a narrower stand-in measured first)
test("r24 B1: the label's box and the pill's box do not touch, whatever the first measure was", function()
	local w, r, W, Mod = setup()
	w:advance(0.5)
	local c = Mod.Card()
	for _, sw in ipairs({ 55, 60, 86, 140 }) do
		c.never.label.GetStringWidth = function() return sw end
		local cw = Mod.Layout(c)
		local p, l = H.rect(c.open), H.rect(c.never.label)
		local stacked = cw < 34 + 76 + 10 + 86 + 10
		ok(l.w >= 86 - 0.5, "label box is as wide as the real text at " .. sw)
		ok(stacked or p.l + p.w + 5 <= l.l, "pill ends before the label begins at " .. sw)
		ok(l.l >= 0 and l.l + l.w <= H.rect(c).l + H.rect(c).w + 0.5, "label inside the card at " .. sw)
	end
	T.clean(w)
end)
