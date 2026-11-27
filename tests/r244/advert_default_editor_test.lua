-- 3045 answer 4: the advert editor opens with the line Wuber really posts ("Selling summons to <place>, <price>..."),
-- and saving without typing keeps that default (it is not swapped for the old "<service> - instant summons..." text).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function editor()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.SetAdvanced(true)
	T.openDrive(a)
	W.Driver.ShowScreen("messages", "advert")
	w:advance(1)
	return w, a, W, W.Driver.ui.subs.messages
end

test("advert editor 3045: opens with Wuber's default advert line, not the old starting text", function()
	local w, a, W, s = editor()
	local text = s.editor.field:Text()
	ok(text:find("^Selling summons to Undercity, "), "opens with the line Wuber posts: " .. text)
	ok(not text:find("instant summons", 1, true), "no old starting text: " .. text)
	eq("[Wuber] " .. text, W.Drive.AdvertText(), "what the driver sees is what gets posted")
	T.clean(w)
end)

-- guard: saving the unchanged editor never stores own words, so the posted line stays Wuber's default
test("advert editor 3045: Save without typing keeps the new default, and it still follows the place", function()
	local w, a, W, s = editor()
	a:clickOn(s.editor.save)
	w:advance(1)
	local own = W.Drive.db.templates and W.Drive.db.templates.advert
	ok(own == nil, "nothing own is saved: " .. tostring(own))
	ok(W.Drive.AdvertText():find("^%[Wuber%] Selling summons to Undercity, "), "the posted line is the new default: " .. W.Drive.AdvertText())
	T.clean(w)
end)

-- guard: words the driver typed are saved and posted as typed
test("advert editor 3045: own words are still saved as typed", function()
	local w, a, W, s = editor()
	local ok2 = W.Drive.SetTemplate("advert", "Rides to {dest} for {price}, whisper me for an invite")
	ok(ok2, "saved")
	eq(W.Drive.db.templates.advert, "Rides to {dest} for {price}, whisper me for an invite", "kept as typed")
	T.clean(w)
end)
