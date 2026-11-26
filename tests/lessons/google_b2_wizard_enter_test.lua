-- Regression test for Big Batch 2 W1: Enter in the crew wizard's "Add by name" field.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function has(c, text) return #c:findText(text, false, true) > 0 end

local function openStep2(opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	if opts.target then
		w:addBot(opts.target, { spot = "Ratchet", class = "MAGE" })
	end
	T.settle(w)
	T.openDrive(d)
	local W = d.W
	W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	return w, d, W, W.Driver.ui.subs.wizard, W.Drive
end

test("lessons b2: Enter in the crew wizard's Add by name box adds the name", function()
	local w, d, W, wz, DR = openStep2({ target = "Wanda" })
	local edit = wz.adder.field.edit
	d:type(edit, "Wanda", false)
	edit:GetScript("OnEnterPressed")(edit)
	w:advance(0.5)
	eq(wz.adder.field:Text(), "", "the field empties after Enter")
	ok(DR.offers[W.Key("Wanda")] ~= nil, "Enter sends the same crew offer as the Add pill")
	ok(wz.sent == true, "wizard marks the offer as sent")
	T.clean(w)
end)

test("lessons b2: Enter in Add by name refuses an empty field and an invalid name", function()
	local w, d, W, wz, DR = openStep2()
	local edit = wz.adder.field.edit
	edit:GetScript("OnEnterPressed")(edit)
	w:advance(0.3)
	ok(has(d, "Type a name first"), "empty: asks for a name on Enter")
	eq(next(DR.offers), nil, "empty: no offer was sent")

	d:type(edit, "x", false)
	edit:GetScript("OnEnterPressed")(edit)
	w:advance(0.3)
	ok(has(d, "That isn't a player's name. Type the name as the game shows it (each part 2 to 12 letters), with -Realm for another realm."),
		"one letter: warns on Enter")
	eq(next(DR.offers), nil, "invalid name: no offer was sent")
	T.clean(w)
end)
