-- Design round 4, group P1: two polish items from the merged pictures.
-- 1. the ride page's turning portal: nothing else of the hero shows under the dark header bar's lower edge.
-- 2. Wuber's tip card (WuberTip) has a one-pixel outline in the line token's colour, so it reads on any card2 background.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state

local function stateOf(founder)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.ride = { id = "d4p1", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity",
		price = 5000, state = "portal", at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	if founder then r.W.FounderSummon = function() return true end end
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

-- the owner chain's alpha: 0 when any frame up the chain is see-through
local function seen(f)
	while f do
		if f.GetAlpha and (f:GetAlpha() or 1) <= 0.01 then return false end
		f = f.GetParent and f:GetParent() or nil
	end
	return true
end

-- every drawn region under root: { rg, owner }
local function drawn(root, out)
	out = out or {}
	if root.IsShown and not root:IsShown() then return out end
	for _, rg in ipairs({ root:GetRegions() }) do
		if rg:IsShown() then out[#out + 1] = { rg = rg, owner = root } end
	end
	for _, c in ipairs({ root:GetChildren() }) do drawn(c, out) end
	return out
end

local function crossing(s)
	local bar = H.rect(s.bar)
	local edge = bar.b -- the bar's lower edge (rects are { l, b, w, h }, b = bottom)
	local bad = {}
	for _, e in ipairs(drawn(s.frame)) do
		local tile = e.rg.GetTextureFilePath and type(e.rg:GetTextureFilePath()) == "number" -- the map's own tiles lie behind the bar by design
		if e.rg ~= s.hero.art and e.rg:GetObjectType() ~= "FontString" and not tile and seen(e.owner) then
			local r = H.rect(e.rg)
			if r.w > 0 and r.h > 0 and r.b < edge - 0.5 and r.b + r.h > edge + 0.5 then
				bad[#bad + 1] = tostring(e.rg.GetTextureFilePath and e.rg:GetTextureFilePath()) .. " " .. string.format("%.0fx%.0f at %.0f,%.0f", r.w, r.h, r.l, r.b)
			end
		end
	end
	return bad
end

for _, founder in ipairs({ false, true }) do
	test("d4 p1: the ride page draws nothing but the map and the portal picture across the header bar's lower edge" .. (founder and " (founder)" or ""), function()
		local w, r, s = stateOf(founder)
		ok(s.hero.art:IsShown(), "control: the portal picture shows")
		eq(table.concat(crossing(s), "; "), "", "regions crossing the bar's lower edge")
		T.clean(w)
	end)
end

test("d4 p1: Wuber's tip card has a one-pixel outline in the line token's colour at full alpha, round its card2 fill", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local f = c.env.CreateFrame("Button", nil, c.env.UIParent)
	f:SetPoint("CENTER", c.env.UIParent, "CENTER", 0, 0)
	f:SetSize(120, 30)
	c.W.Theme.Tip(f, "A title", "One plain sentence.")
	S[f].scripts.OnEnter(f)
	local card = c.env.WuberTip
	ok(card and H.visible(card), "the tip shows")
	local line, raised = c.W.Theme.C.line, c.W.Theme.C.raised
	local function near(col, want) return col and math.abs(col[1] - want[1]) < 0.01 and math.abs(col[2] - want[2]) < 0.01 and math.abs(col[3] - want[3]) < 0.01 end
	local cr = H.rect(card)
	local edge, fill = 0, 0
	for _, rg in ipairs({ card:GetRegions() }) do
		if rg:IsShown() and rg.GetTextureFilePath and tostring(rg:GetTextureFilePath()):find("rounded", 1, true) then
			local col = S[rg].color or S[rg].vertex
			local r = H.rect(rg)
			if near(col, line) then
				eq(col[4] or 1, 1, "the outline is at full alpha")
				if r.l < cr.l - 0.4 or r.b < cr.b - 0.4 then edge = edge + 1 end -- reaches past the card by a pixel
			elseif near(col, raised) then
				fill = fill + 1
			end
		end
	end
	ok(edge >= 4, "line-coloured outline pieces reach one pixel past the card, got " .. edge)
	ok(fill >= 9, "the card2 fill is still there, got " .. fill)
	T.clean(w)
end)
