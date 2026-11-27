local T = ...
local test = T.test
test("r2D DS24-03: closing the raincheck offer while the bug report is still open keeps the header buttons lifted over the report's dim", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	c.W.Raincheck.Mine = function() return { { id = "rcX", state = "offered", driver = "Anita Lift", cover = 5000, expires = c.env.time() + 6 * 86400 } } end
	local UI = c.W.UI
	UI.Toggle(true) w:advance(3)
	local btn = c.W.Mod("UI.Kit").ui.close
	assert(btn, "control: close button exists")
	assert(UI.Bug.Open(), "control: bug report opens") w:advance(1)
	assert(UI.Bug.Shown(), "control: bug report is up")
	assert(btn:GetFrameStrata() == "FULLSCREEN_DIALOG", "control: close button lifted by the report: " .. btn:GetFrameStrata())
	local f = UI.RaincheckOffer() w:advance(1)
	assert(f and f.open, "control: the raincheck offer opens")
	assert(UI.Bug.Shown(), "control: the bug report is still up with the offer")
	f:Close() w:advance(1)
	assert(UI.Bug.Shown(), "control: the bug report is still up after the offer closed")
	assert(btn:GetFrameStrata() == "FULLSCREEN_DIALOG",
		"the report is still up but the close button dropped to " .. btn:GetFrameStrata() .. " under its dim")
	T.clean(w)
end)

-- guard: the offer alone lifts the header and puts it back
test("r2D guard: offer alone lifts, then returns to its normal strata", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	c.W.Raincheck.Mine = function() return { { id = "rcX", state = "offered", driver = "Anita Lift", cover = 5000, expires = c.env.time() + 6 * 86400 } } end
	local UI = c.W.UI
	UI.Toggle(true) w:advance(3)
	local btn = c.W.Mod("UI.Kit").ui.close
	local was = btn:GetFrameStrata()
	local f = UI.RaincheckOffer() w:advance(1)
	assert(btn:GetFrameStrata() == "FULLSCREEN_DIALOG", "lifted: " .. btn:GetFrameStrata())
	f:Close() w:advance(1)
	assert(btn:GetFrameStrata() == was, "back to " .. was .. ", is " .. btn:GetFrameStrata())
	T.clean(w)
end)
-- guard: the report alone, and report closed first then the offer
test("r2D guard: report alone, and report closed before the offer", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	c.W.Raincheck.Mine = function() return { { id = "rcX", state = "offered", driver = "Anita Lift", cover = 5000, expires = c.env.time() + 6 * 86400 } } end
	local UI = c.W.UI
	UI.Toggle(true) w:advance(3)
	local btn = c.W.Mod("UI.Kit").ui.close
	local was = btn:GetFrameStrata()
	assert(UI.Bug.Open()) w:advance(1)
	assert(btn:GetFrameStrata() == "FULLSCREEN_DIALOG", "report lifts")
	local f = UI.RaincheckOffer() w:advance(1)
	UI.Bug.Close() w:advance(1)
	assert(not UI.Bug.Shown(), "report closed")
	assert(btn:GetFrameStrata() == "FULLSCREEN_DIALOG", "offer still holds the lift: " .. btn:GetFrameStrata())
	f:Close() w:advance(1)
	assert(btn:GetFrameStrata() == was, "all closed, back to " .. was .. ", is " .. btn:GetFrameStrata())
	T.clean(w)
end)
