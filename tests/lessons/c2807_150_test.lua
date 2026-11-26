-- c2807 #150: the auto-invite warning names every public channel Wuber watches by default, and the longer text fits its popup.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

test("c2807 #150 the warning names every default watched channel", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	local list = DR.OPT_DEFAULTS.watchChannels
	local n = 0
	for ch in tostring(list):gmatch("[^,%s]+") do
		n = n + 1
		ok(DR.PUBLIC_WARNING:lower():find(ch:lower(), 1, true), "the warning does not name the watched channel '" .. ch .. "': " .. DR.PUBLIC_WARNING)
	end
	ok(n >= 5, "control: the defaults list " .. n .. " channels")
	ok(DR.PUBLIC_WARNING:find("^Wuber reads public chat channels %(Trade, LookingForGroup, Services, World, General%) and invites players who seem to want your place%. It can misread"), DR.PUBLIC_WARNING)
	ok(not DR.PUBLIC_WARNING:find("Trade chat", 1, true), "the old words are gone")
	T.clean(w)
end)

test("c2807 #150 the warning's text and its buttons fit inside the popup and the phone", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local env, DR = a.env, a.W.Drive
	a:slash("/wuber")
	w:advance(2)
	local phone = env.WuberFrame
	ok(phone and phone:IsShown(), "the phone is open")
	for _, scale in ipairs({ 0.71, 1, 1.5 }) do
		env.UIParent:SetScale(scale)
		local pop = env.CreateFrame("Frame", nil, env.UIParent)
		pop:SetSize(320, 120)
		pop.text = pop:CreateFontString(nil, "ARTWORK")
		pop.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
		pop.text:SetPoint("TOP", pop, "TOP", 0, -16)
		pop.text:SetText(DR.PUBLIC_WARNING)
		local b1 = env.CreateFrame("Button", nil, pop)
		b1:SetSize(100, 22)
		b1:SetPoint("BOTTOM", pop, "BOTTOM", 0, 16)
		eq(DR.PlacePublicWarning(pop), true, scale .. ": placed")
		local pr, r, br, tr = H.rect(phone), H.rect(pop), H.rect(b1), H.rect(pop.text)
		ok(tr.h > 0, scale .. ": control: the text has a height")
		ok(tr.l >= r.l - 0.01 and tr.l + tr.w <= r.l + r.w + 0.01, scale .. ": the text is inside the popup's width")
		ok(tr.b >= br.b + br.h - 0.01, scale .. ": the text ends above the button (" .. tr.b .. " vs " .. (br.b + br.h) .. ")")
		ok(tr.b + tr.h <= r.b + r.h + 0.01, scale .. ": the text is inside the popup's top")
		ok(r.b >= pr.b - 0.01 and r.b + r.h <= pr.b + pr.h + 0.01, scale .. ": the popup is inside the phone's height")
		DR.RestorePublicWarning(pop)
	end
	env.UIParent:SetScale(1)
	T.clean(w)
end)
