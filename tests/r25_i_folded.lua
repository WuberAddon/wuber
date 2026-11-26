-- Round 25 I: Settings > "Check my game" in the folded window. After Check, the result card comes
-- into view whole (its bottom inside the scroll area), and the row above Check is not cut at the top.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function run(screenW, scale)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = screenW or 1365, screenH = 768 })
	w:advance(15)
	if scale then r.env.UIParent:SetScale(scale) end
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
	return r, st
end

test("r25 I: Check my game's result card ends inside the scroll area (folded)", function()
	local r, st = run()
	local top = st.restTop + st.checkY
	local bottom = top + st.results:GetHeight()
	ok(st.results:IsShown(), "results shown")
	ok(bottom - st.scroll <= st.clip:GetHeight() + 0.5, "card's bottom is inside the clip")
	ok(top - st.scroll >= -0.5, "card's top is inside the clip")
	-- the row above Check (Report a bug) is wholly above the view or wholly in it: nothing cut at the top
	ok(st.scroll >= st.restTop + st.checkRowY - 6 - 0.5 or st.scroll <= st.restTop + st.checkRowY - 140, "no half row at the top")
end)
