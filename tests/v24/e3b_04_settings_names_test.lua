local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- E3b-04: lines that send the player to Settings rows name "Tips" and "Flight offers" (Riding page).

test("e3b-04: /wuber tips off, tip card off line, Don't show again tooltip, and Tips.Why name Tips", function()
	local w = T.newWorld()
	local c = T.rider(w, T.BOB, { saved = { Wuber = { coach = true } } })
	local W = c.W
	w:advance(5)
	local Tips = W.Mod("UI.Tips")
	Tips.ShowNow()
	w:advance(5)
	local card = Tips.Card()
	ok(card and H.visible(card), "tip card shown")
	local st = H.state[card.never]
	ok(st and st.scripts and st.scripts.OnEnter, "Don't show again has OnEnter")
	st.scripts.OnEnter(card.never)
	ok(#c:findText("Turn login tips off. Settings > Riding > Tips turns them back on.", nil, true) > 0,
		"Don't show again tooltip names Tips")
	if st.scripts.OnLeave then st.scripts.OnLeave(card.never) end
	card.never:Click()
	eq(card.text:GetText(), "Tips are off. Turn Login tips back on in Settings > Riding, or type /wuber tips.", "OFF_LINE on card")
	w:advance(9)
	eq(Tips.Why(), "Login tip: off in Settings (Riding, Tips).", "Tips.Why off line")
	local lines = {}
	local origPrint = W.Print
	W.Print = function(...)
		lines[#lines + 1] = tostring((...))
		if origPrint then return origPrint(...) end
	end
	W.SlashCommand("tips off")
	W.Print = origPrint
	local printed = lines[#lines] or ""
	ok(printed:find("Tips are off. Turn Login tips back on in Settings > Riding, or type /wuber tips.", 1, true) ~= nil,
		"/wuber tips off line: " .. tostring(printed))
	T.clean(w)
end)

test("e3b-04: Bird.Why names Flight offers when birdTip is off", function()
	local w = T.newWorld()
	local c = T.rider(w, T.BOB)
	local W = c.W
	w:advance(5)
	W.db.birdTip = false
	local Bird = W.Mod("UI.Bird")
	eq(Bird.Why(), "Skip the bird: off. Turn Flight offers on in Settings, Riding.", "Bird.Why off line")
	T.clean(w)
end)
