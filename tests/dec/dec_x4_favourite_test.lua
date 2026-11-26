-- Decisions X4: on Confirm the word "Favourite" under the heart keeps the driver card's 12 px margin (it ended about
-- 1 px from the card's edge), and still stands clear of the service and driver lines. Loaded by tests/run.lua with T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function riderWorld(narrow)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.FlightCost = function() return 2300, 1 end
	r.W.TravelSaved = function() return 540 end
	r.W.db.tipPct = 10
	r.W.db.fold = { v = 1, pages = {}, narrow = narrow }
	return w, r
end

for _, narrow in ipairs({ true, false }) do
	test("dec x4: the Favourite word is 12 px inside the driver card and clear of the text (" .. (narrow and "folded" or "unfolded") .. ")", function()
		local w, r = riderWorld(narrow)
		r.W.UI.Toggle(true)
		w:advance(3)
		r.W.UI.Show("confirm", "mia runner")
		w:advance(3)
		local card = r.W.UI.state.screens.confirm.card
		local word, row = H.rect(card.heart.word), H.rect(card.row)
		local sv, dr, hw = H.rect(card.service), H.rect(card.driver), H.rect(card.heart)
		local gap = (row.l + row.w) - (word.l + word.w)
		ok(gap >= 12 - 0.5, "the word ends " .. gap .. " px from the card's right edge")
		ok(sv.l + sv.w <= word.l + 1 and dr.l + dr.w <= word.l + 1, "text ends " .. (sv.l + sv.w) .. ", " .. (dr.l + dr.w) .. " before the word at " .. word.l)
		ok(word.l >= hw.l - 40, "the word is by the heart")
		T.clean(w)
	end)
end
