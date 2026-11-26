-- A driver's own advert line and own messages may start with WTS (their sales line in trade chat); WTB, gold and links stay refused.
local T = ...
local test, eq, ok, clean = T.test, T.eq, T.ok, T.clean

test("wts own: the advert editor keeps 'WTS summons to Ratchet'", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	a.W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = a.W.UI.drive.screens.messages
	s.edit("advert")
	w:advance(0.5)
	local e = s.editor
	local DR = a.W.Drive
	local txt = "WTS summons to Ratchet"
	e.field:SetText(txt)
	s.preview()
	ok(not e.why:IsShown(), "no spam warning under the editor: " .. tostring(e.why:GetText()))
	local okSave, why = DR.SetTemplate("advert", txt)
	ok(okSave, "Save keeps it, got: " .. tostring(why))
	local line, bad = a.W.AdvertOwnText(txt)
	ok(line, "the advert line is built, got: " .. tostring(bad))
	clean(w)
end)

test("wts own: other texts around WTS stay as they were", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	ok((DR.SetTemplate("advert", "WTS summons to Ratchet")), "WTS summons to Ratchet saves")
	ok(not (DR.SetTemplate("advert", "WTB summons to Ratchet")), "WTB is still refused")
	ok(not (DR.SetTemplate("advert", "WTS summons 100 gold")), "gold is still refused")
	ok(not (DR.SetTemplate("advert", "WTS summons www.example.com")), "a link is still refused")
	ok(not (DR.SetTemplate("advert", "WTS summons for 5000 usd")), "digits and money words still refused")
	ok(a.W.SpamReason("WTS") ~= nil, "a service name may still not be WTS")
	ok(a.W.SentenceSpam("WTS summons to Ratchet") ~= nil, "lines Wuber builds from other text still refuse WTS")
	eq(a.W.SentenceSpam("WTS summons to Ratchet", true), nil, "the driver's own line passes")
	ok(a.W.SentenceSpam("Selling summons to Ratchet", true) ~= nil, "typed Selling is as before (refused)")
	clean(w)
end)

test("wts own: other Wubers still read a WTS line as a seller", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local DR = r.W.Drive
	ok(not DR.Wanted("WTS summons to Ratchet"), "Wanted: a WTS line is not a buyer")
	eq(DR.PublicWant("WTS summons to Ratchet"), nil, "PublicWant: a WTS line is not a buyer")
	clean(w)
end)
