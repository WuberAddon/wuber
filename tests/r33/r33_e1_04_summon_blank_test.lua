local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- E1-04: when CONFIRM_SUMMON fires during an active Wuber ride and GetSummonConfirmSummoner
-- gives nothing, the ride page shows "<summoner> is summoning you to <place>" (summoner =
-- ride's summoner, else driver), clears when summon ends/cancels/accepted, and with no Wuber
-- ride Wuber stays out of the game's StaticPopup / CONFIRM_SUMMON frame.

local function hasText(r, needle)
	for _, s in ipairs(r:visibleTexts()) do
		if s:find(needle, 1, true) then return true end
	end
	return false
end

test("e1-04: blank GetSummonConfirmSummoner during active ride shows summoner/driver sentence, clears on cancel/accept, and leaves popup alone with no ride", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Orgrimmar" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	T.goOnline(d)

	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(0.5)

	r.env.C_SummonInfo.GetSummonConfirmSummoner = function() return nil end
	r.env.GetSummonConfirmSummoner = function() return nil end

	r.W.ride.summoner = "Farra Way"
	r:fire("CONFIRM_SUMMON")
	r.W.UI.Toggle(true)
	w:advance(0.5)
	r.W.UI.RefreshNow()
	ok(hasText(r, "Farra is summoning you to Orgrimmar"), "uses ride summoner: " .. table.concat(r:visibleTexts(), " | "))

	-- fallback to driver when ride has no separate summoner
	r.W.ride.summoner = nil
	r.W.UI.RefreshNow()
	ok(hasText(r, "Anita is summoning you to Orgrimmar"), "falls back to driver: " .. table.concat(r:visibleTexts(), " | "))

	-- clears on CANCEL_SUMMON
	r:fire("CANCEL_SUMMON")
	w:advance(0.2)
	r.W.UI.RefreshNow()
	ok(not hasText(r, "is summoning you to"), "sentence clears on CANCEL_SUMMON")

	-- re-show on blank CONFIRM_SUMMON, then clear on AcceptSummon
	r:fire("CONFIRM_SUMMON")
	r.W.UI.RefreshNow()
	ok(hasText(r, "Anita is summoning you to Orgrimmar"), "sentence shows again on blank CONFIRM_SUMMON")
	r.env.C_SummonInfo.ConfirmSummon = function() end
	r.env.ConfirmSummon = r.env.C_SummonInfo.ConfirmSummon
	r.W.AcceptSummon()
	r.W.UI.RefreshNow()
	ok(not hasText(r, "is summoning you to"), "sentence clears when summon is accepted")

	-- with no Wuber ride, Wuber does nothing and never touches StaticPopup
	r.W.ClearRide()
	local popup = { text = "" }
	local hid = false
	r.env.StaticPopup_FindVisible = function(which)
		if which == "CONFIRM_SUMMON" then return popup end
		return nil
	end
	r.env.StaticPopup_Hide = function(which)
		if which == "CONFIRM_SUMMON" then hid = true end
	end
	r:fire("CONFIRM_SUMMON")
	w:advance(0.2)
	eq(r.W.ride, nil, "no ride created")
	eq(popup.text, "", "StaticPopup text untouched")
	eq(hid, false, "StaticPopup not hidden")

	T.clean(w)
end)
