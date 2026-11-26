-- Run 1, group o: Lab tour polish. The Shift complete sheet must not cut the console's Open / Pause / Advertise pills in half
-- (WoWScrnShot_112226_164040); the Greeting confirm (Invite public chat buyers) must have an opaque backdrop (164054).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

test("run1 o: the Shift complete sheet's top never lands inside the Open / Pause / Advertise pills", function()
	for _, tips in ipairs({ 0, 3000 }) do
		local w = T.newWorld()
		local a = T.driver(w, T.ANITA, { spot = "Undercity" })
		w:advance(15)
		local W = a.W
		local D = W.Driver
		T.openDrive(a)
		D.lastShift = { rides = 9, copper = 48000, tips = tips, open = 7200, crewRides = 2, crewCopper = 10000, at = 1 }
		ok(D.ShowSheet("shift"), "opens")
		w:advance(1)
		local s = W.UI.drive.screens.shift
		-- the fake phone's pills sit above the sheet: slide the row down until the sheet's top is in the middle of it
		local open = D.ui.console.open
		local top0, r0 = H.rect(s.frame.card), H.rect(open)
		local sc = top0.h / s.frame.sheetH
		local pt, rel, rp, x, y = open:GetPoint(1)
		open:ClearAllPoints()
		open:SetPoint(pt, rel, rp, x, y + ((top0.b + top0.h) - (r0.b + r0.h / 2)) / sc)
		s.update()
		w:advance(1)
		local card = H.rect(s.frame.card)
		if not card then error("no rect: sheet open=" .. tostring(s.frame.open) .. " shown=" .. tostring(s.frame:IsShown()) .. " host rect=" .. tostring(H.rect(D.ui.root)) .. " pill=" .. tostring(H.rect(D.ui.console.open))) end
		local cut = nil
		for _, name in ipairs({ "open", "pause", "advert" }) do
			local p = D.ui.console[name]
			local r = p and p:IsShown() and H.rect(p)
			if r and r.h > 0 and card.b + card.h > r.b + 0.01 and card.b + card.h < r.b + r.h - 0.01 then cut = name end
		end
		if os.getenv("R1O") then local p = H.rect(D.ui.console.open) print("card top", card.b + card.h, "open", p and p.b, p and p.b + p.h, "root", H.rect(D.ui.root).b, H.rect(D.ui.root).h) end
		eq(cut, nil, "tips " .. tips .. ": the sheet's top (" .. (card.b + card.h) .. ") cuts the " .. tostring(cut) .. " pill")
		s.frame:Close(true)
		T.clean(w)
	end
end)

test("run1 o: the Invite public chat buyers confirm has an opaque backdrop, put away with the popup", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	local env = a.env
	local pop = env.CreateFrame("Frame", nil, env.UIParent)
	pop:SetSize(320, 120)
	pop.text = pop:CreateFontString(nil, "ARTWORK")
	pop.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
	pop.text:SetText(DR.PUBLIC_WARNING)
	pop:SetAlpha(0.6)
	env.WuberFrame:Show()
	eq(DR.PlacePublicWarning(pop), true, "placed")
	ok(pop.wuberBack, "an opaque backdrop is on the popup")
	ok(pop.wuberBack:IsShown(), "it is shown")
	eq(pop:GetAlpha(), 1, "the popup itself is not see-through")
	ok(DR.RestorePublicWarning(pop), "restored")
	ok(not pop.wuberBack:IsShown(), "the backdrop is hidden with it")
	eq(pop:GetAlpha(), 0.6, "the alpha is put back")
	T.clean(w)
end)
