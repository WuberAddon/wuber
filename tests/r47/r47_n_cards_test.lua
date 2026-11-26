local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
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

test("r47 n: AUD-164 the card menu stays on screen after Wuber is closed with Escape", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	r.W.UI.Toggle(true) w:advance(3)
	ok(H.visible(r.W.UI.win or r.env.WuberWindow or r.env.UIParent), "control: the phone is open")
	local c = mkcard(r)
	c:GetScript("OnClick")(c, "RightButton")
	w:advance(0.6)
	local fs = r:findText("Hide this driver")[1]
	ok(fs and H.visible(fs), "control: the card menu is open")
	r:pressEscape() w:advance(1)
	ok(not (r.W.UI.win and H.visible(r.W.UI.win)), "control: Escape closed Wuber")
	r:fire("PLAYER_STARTED_MOVING")
	ok(not H.visible(fs), "Wuber is closed but the Favourite / Hide this driver menu still floats on screen")
	T.clean(w)
end)

test("r47 n: AUD-168 a busy driver's state text is drawn over the end of a long subtitle", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local c, d, parent = mkcard(r, { state = "busy", queue = 3, dest = "Thunder Bluff", summoner = "Wuberwarlockxx" })
	parent:SetSize(324, 64)
	parent:ClearAllPoints()
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	w:advance(0.5)
	-- (design 2) the state words are plain words of the row's second line, after the place and the Warlock: one text,
	-- so nothing can be drawn over its end; it wraps, and the row grows with it
	eq(c.stateText, "Busy · 3 waiting", "control: the state words")
	local sub = c.sub:GetText()
	ok(sub:find("Summoned by Wuberwarlockxx", 1, true), "control: the subtitle is the long one: " .. tostring(sub))
	ok(sub:find("Summoned by Wuberwarlockxx · Busy · 3 waiting", 1, true), "the state words follow the subtitle in the same line: " .. tostring(sub))
	eq(c.full, nil, "no second text beside the heart")
	ok(c.sub:GetBottom() >= c:GetBottom() - 0.01 and c:GetHeight() >= c.title:GetHeight() + c.sub:GetHeight(), "the row is as tall as its words")
	-- the price and the heart stand on the name's line or beside the words: never on the second line's words
	local P, Sb = H.rect(c.price), H.rect(c.sub)
	ok(P.b >= Sb.b + Sb.h - 0.01 or P.l >= Sb.l + Sb.w - 0.01, "the price is clear of the second line")
	T.clean(w)
end)

test("r47 n: AUD-164 the card menu goes when Home hides and the window stays open", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	r.W.UI.Toggle(true) w:advance(3)
	local c = mkcard(r)
	c:GetScript("OnClick")(c, "RightButton")
	w:advance(0.6)
	local fs = r:findText("Hide this driver")[1]
	ok(fs and H.visible(fs), "control: the card menu is open")
	local p = c:GetParent()
	p:Hide() -- the card's own screen goes; the window is not touched
	ok(not H.visible(fs), "Home is hidden but the Favourite / Hide this driver menu still floats on screen")
	T.clean(w)
end)
