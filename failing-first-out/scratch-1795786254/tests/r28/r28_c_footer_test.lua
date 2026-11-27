-- Round 28 group C: REV-r27-1. Settings > Check my game, folded: the footer line stays whole after the results show.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the shipped fonts' real metrics, as the layout check measures (a line may wrap where the fake game's default does not)
local TL = dofile("tools/preview/textlayout.lua")

for _, sz in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 2662, 2089 } }) do
	test("r28 REV-r27-1: after Check my game the footer line is whole inside the folded view (" .. sz[1] .. "x" .. sz[2] .. ")", function()
		local H = T.H
		local old = H.textMetrics
		TL.PX = sz[2] / 768
		TL.SNAP, TL.SIZE_SNAP = "round", "round"
		H.textMetrics = TL
		local good, err = pcall(function()
		local w = T.newWorld()
		local r = w:addClient(T.TESTCHAR, { spot = "Undercity", class = "WARLOCK", screenW = sz[1], screenH = sz[2] })
		w:advance(15)
		local UI = r.W.UI
		UI.OpenSettings()
		local st = UI.settings
		local P = r.W.Mod("UI.Settings.Panel")
		P.search("Check my game")
		local m
		for _, x in ipairs(st.find.list) do if x.label == "Check my game" then m = x end end
		ok(m, "found the row")
		P.openResult(m)
		st.controls.check:GetScript("OnClick")(st.controls.check, "LeftButton", false)
		for _ = 1, 30 do w:advance(0.1) end
		ok(st.results:IsShown(), "results shown")
		local aboutBottom, clipBottom = st.about:GetBottom(), st.clip:GetBottom()
		ok(aboutBottom and clipBottom, "geometry known")
		ok(aboutBottom >= clipBottom - 0.5, "footer bottom " .. tostring(aboutBottom) .. " is inside the view bottom " .. tostring(clipBottom))
		end)
		H.textMetrics = old
		if not good then error(err, 0) end
	end)
end
