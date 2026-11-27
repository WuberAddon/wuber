local T = ...
local test, ok, H = T.test, T.ok, T.H

-- R52-01: the What's new card keeps clear of the Wuber window. After the window is moved (here onto the card's spot),
-- the card must step aside within about 0.3 s, so a flight-map price tag never sits under it for a second.
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768, saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
	T.settle(w)
	w:advance(15)
	local Mod = r.W.Mod("UI.WhatsNew")
	r.W.UI.Toggle(true)
	w:advance(1)
	return w, r, Mod
end

local function overlap(a, b)
	return a.l + 0.5 < b.l + b.w and b.l + 0.5 < a.l + a.w and a.b + 0.5 < b.b + b.h and b.b + 0.5 < a.b + a.h
end

local function moved(step)
	local w, r, Mod = setup()
	local card = Mod.Card()
	
	ok(H.visible(card), "control: the news card shows")
	local win = r.W.UI.state.win
	local c = H.rect(card)
	win:ClearAllPoints()
	win:SetPoint("CENTER", r.env.UIParent, "BOTTOMLEFT", c.l + c.w / 2, c.b + c.h / 2)
	local t = 0
	while t < 0.3 - 1e-9 do w:advance(step) t = t + step end
	if t < 0.3 then w:advance(0.3 - t) end
	ok(H.visible(card), "the card is still up")
	ok(not overlap(H.rect(card), H.rect(win)), "the card is clear of the moved window 0.3 s after it moved (step " .. step .. " s)")
	T.clean(w)
end

test("r52 R52-01: the news card clears a moved Wuber window within 0.3 s (0.1 s steps)", function() moved(0.1) end)
-- guard: one big step runs every timer due inside it in order, so the old 1 s watch already passes here
test("r52 R52-01: the news card clears a moved Wuber window within 0.3 s (one 1.5 s step)", function()
	local w, r, Mod = setup()
	local card = Mod.Card()
	
	local win = r.W.UI.state.win
	local c = H.rect(card)
	win:ClearAllPoints()
	win:SetPoint("CENTER", r.env.UIParent, "BOTTOMLEFT", c.l + c.w / 2, c.b + c.h / 2)
	w:advance(1.5)
	ok(not overlap(H.rect(card), H.rect(win)), "the card is clear of the moved window after one 1.5 s step")
	T.clean(w)
end)
