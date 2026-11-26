local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 33 b5 (HUNT-103): the alert banner and the "1 alert" box are clickable, so each says what a click does.
test("r33 b5: the alert banner and the alert box have tooltips that say what a click does", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	wub.W.Drive.BellAlert("Anita: Summon Dan")
	w:advance(1)
	local b, c = wub.env.WuberBell, wub.env.WuberBellCount
	ok(b and c, "control: both frames exist")
	ok(b.wuberTip and b.wuberTip.title and b.wuberTip.text, "the banner has a tip")
	ok(c.wuberTip and c.wuberTip.title and c.wuberTip.text, "the alert box has a tip")
	ok(b.wuberTip and b.wuberTip.text:lower():find("hide this banner") , "the banner tip says it hides the banner")
	ok(c.wuberTip and c.wuberTip.text:lower():find("clear the alert count"), "the box tip says it clears the count")
	T.clean(w)
end)
