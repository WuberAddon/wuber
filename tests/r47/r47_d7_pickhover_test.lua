local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 d7: AUD-200 the picked Step 1 choice loses its highlighted background when the mouse leaves it", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	local sc = d.W.Driver.ui.subs.wizard
	d:clickText("My friends help") w:advance(0.5)
	local b
	for _, c in ipairs(sc.choices) do if c.id == sc.choice then b = c end end
	ok(b, "control: a choice is picked")
	ok(b.bg.colour == "glow", "control: the picked choice has the violet background after the click, got " .. tostring(b.bg.colour))
	b:GetScript("OnEnter")(b) -- the mouse is on it
	b:GetScript("OnLeave")(b) -- and moves away
	eq(b.bg.colour, "glow", "the picked choice should keep its highlighted background after the mouse leaves; it went back to the plain card colour")
	-- Whoever clicks first (step 2, two or more ticked) is the same kind of card
	T.clean(w)
end)
