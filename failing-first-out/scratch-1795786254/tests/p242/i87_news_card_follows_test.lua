-- #87: the What's new card follows the Wuber window at once, and the flight map's price tags dodge the card where it
-- stands now. Promise: (a) after the window moves over a tag, half a second later no tag sits under any Wuber frame,
-- the card included; (b) right after the status bar is dragged, the card does not overlap the window.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function crosses(a, b)
	return a.l + 0.5 < b.l + b.w and b.l + 0.5 < a.l + a.w and a.b + 0.5 < b.b + b.h and b.b + 0.5 < a.b + a.h
end

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768, saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
	T.settle(w)
	local names = { "Orgrimmar", "Crossroads", "Ratchet" }
	r.W.drivers = r.W.drivers or {}
	for i, n in ipairs(names) do
		r.W.drivers["drv" .. i] = { name = "Drv" .. i, key = "drv" .. i, dest = n, price = 5000, state = "open", team = 3, heard = r.env.GetTime() }
	end
	-- the flight points are lifted to the top of the map, where the card stands, so a tag can lie under it
	local real = r.env.TaxiNodePosition
	r.env.TaxiNodePosition = function(i)
		local x, y = real(i)
		if not x then return x, y end
		return x, y * 0.01
	end
	w:advance(5)
	local News = r.W.Mod("UI.WhatsNew")
	local Pins = r.W.Mod("UI.FlightPins")
	local K = r.W.Mod("UI.Kit")
	r.W.UI.Toggle(true)
	w:advance(1)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = names }))
	w:advance(1.5)
	return w, r, News, Pins, K
end

local function moveWinTo(r, win, l, b)
	win:ClearAllPoints()
	win:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", l, b)
end

test("i87: after the window moves over a price tag, half a second later no tag is under the window or the card", function()
	local w, r, News, Pins, K = setup()
	local card, win = News.Card(), K.ui.win
	ok(card and H.visible(card), "control: the card shows")
	ok(win and H.visible(win), "control: Wuber shows")
	local tag
	for _, p in ipairs(Pins.Pins()) do if p.tag and H.visible(p.tag) then tag = p.tag break end end
	ok(tag, "control: a tag shows")
	if card and win and tag then
		local tr, wr = H.rect(tag), H.rect(win)
		moveWinTo(r, win, tr.l + 2 - 0, tr.b + tr.h / 2 - wr.h / 2)
		-- half a second later, and again after the card's own 1 s watch has run (it must not land on a tag)
		for _, t in ipairs({ 0.5, 1.5 }) do
			w:advance(t)
			for _, p in ipairs(Pins.Pins()) do
				if p.tag and H.visible(p.tag) then
					for _, f in ipairs({ win, card }) do
						ok(not crosses(H.rect(p.tag), H.rect(f)), "after " .. t .. " s a tag for " .. tostring(p.node) .. " is not under " .. tostring(f:GetName()))
					end
				end
			end
		end
	end
	T.clean(w)
end)

test("i87: right after the status bar is dragged, the card does not overlap the window", function()
	local w, r, News, Pins, K = setup()
	local card, win = News.Card(), K.ui.win
	local g = K.ui.phone and K.ui.phone.status
	ok(card and H.visible(card) and win and g, "control: card, window and status bar")
	if card and win and g then
		local cr, wr = H.rect(card), H.rect(win)
		-- the window lands on the card's spot
		moveWinTo(r, win, cr.l, cr.b)
		g:GetScript("OnDragStop")(g)
		w:advance(0.05)
		ok(not crosses(H.rect(card), H.rect(win)), "the card is clear of the window 0.05 s after the drag")
	end
	T.clean(w)
end)
