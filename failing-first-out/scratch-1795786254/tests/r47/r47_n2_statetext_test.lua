local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
-- (round 47, AUD-168 follow-up) the state text and the sub line stay inside their card when they take two lines
local function mkcard(r, extra)
	local CM = r.W.Mod("UI.Rider.Cards")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local c = CM.buildCard(parent)
	local d = { name = "Farra Way", key = "farra way", dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Farra's Rides", heard = r.env.GetTime() }
	for k, v in pairs(extra or {}) do d[k] = v end
	c.view = d
	CM.fillCard(c, d)
	return c, d, parent
end
local function inside(c, fs, scale)
	local C, R = H.rect(c), H.rect(fs)
	-- the fake game measures one line: a font string that wraps to n lines is n lines tall
	local h = math.min((fs.wuberLines or 1) * (fs:GetStringHeight() or 0) * scale, math.max(R.h, (fs.wuberLines or 1) * (fs:GetStringHeight() or 0) * scale))
	-- the drawn lines are centred in the font string's box (SetJustifyV MIDDLE)
	local mid = R.b + R.h / 2
	return mid - h / 2 - C.b, C.b + C.h - (mid + h / 2)
end
for _, scale in ipairs({ 1, 1.5, 2.2 }) do
	test("r47 n2: AUD-168 a two-line state text and sub line stay inside the card at scale " .. scale, function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 2662, screenH = 2089 })
		w:advance(15)
		local c, _, parent = mkcard(r, { state = "busy", queue = 99, seats = 0, dest = "Feathermoon Stronghold", summoner = "Bartholomewx" })
		parent:SetSize(324, 64)
		parent:SetScale(scale)
		parent:ClearAllPoints()
		parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
		w:advance(0.5)
		-- (design 2) the state words are plain words of the row's second line; the row is as tall as its lines
		ok(c.sub:GetText():find("Busy · 99 waiting · Group full", 1, true), "control: busy and full, in the second line: " .. tostring(c.sub:GetText()))
		ok((c.sub.paraLines or 1) >= 2, "control: the second line wraps")
		ok(c.sub:GetBottom() >= c:GetBottom() - 0.01, string.format("the second line hangs %.1f below the row", c:GetBottom() - c.sub:GetBottom()))
		ok(c.title:GetTop() <= c:GetTop() + 0.01, "the name pokes above the row")
		local lo = inside(c, c.sub, scale)
		ok(lo >= -0.01, string.format("the sub line hangs %.1f px below the card", -lo))
		T.clean(w)
	end)
end
