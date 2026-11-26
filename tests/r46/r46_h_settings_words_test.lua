-- Round 46 h: HUNT-29 / HUNT-41 / HUNT-72, the Settings words and the Reset button.
-- Share notes tooltip says the notes stay on this account; the Advert reminder tooltip says the button turns
-- violet; Settings > Window "Reset" puts the page width choice back to Auto too, so its toast is true.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function openSettings()
	local w = T.newWorld()
	local r = T.driver(w, "Anita Lift", {})
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.OpenSettings()
	w:advance(1)
	return w, r, r.W.UI.settings.controls
end

-- the words of a control's tooltip (T.Tip keeps them on the frame; the row may hold them)
local function tipOf(r, w, ctl)
	local f, t = ctl, nil
	while f and not t do
		t = f.wuberTip
		f = (not t) and f.GetParent and f:GetParent() or nil
	end
	ok(t, "the control has a tooltip")
	return tostring(t.title) .. "\n" .. tostring(t.text)
end

test("r46 h: Share notes has left Settings; the typed command still turns it off and on", function()
	local w, r, c = openSettings()
	eq(c["drive.shareNotes"], nil, "no row in Settings any more")
	r:slash("/wuber drive sharenotes off")
	eq(r.W.Drive.opts().shareNotes, false, "off, saved")
	ok(r:said("Sharing notes with your own accounts: off%."), "and it says so")
	r:slash("/wuber drive sharenotes on")
	eq(r.W.Drive.opts().shareNotes, true, "on again")
	T.clean(w)
end)

test("r46 h: Advert reminder tooltip says the button turns violet", function()
	local w, r, c = openSettings()
	local tip = tipOf(r, w, c["drive.adEvery"])
	ok(tip:find("The Advertise button turns violet and rings after this many minutes (15 at least). It never posts by itself.", 1, true), "new words: " .. tip)
	ok(not tip:find("gold", 1, true), "no gold")
	T.clean(w)
end)

test("r46 h: Reset puts Always narrow back to Auto", function()
	local w, r, c = openSettings()
	c.foldWide.buttons[2]:Click()
	w:advance(0.5)
	eq(r.W.db.fold.narrow, true, "Always narrow is chosen")
	c.foldReset:Click()
	w:advance(0.5)
	eq(r.W.db.fold.narrow, false, "Reset: the width choice is Auto again")
	eq(r.W.UI.WindowWide(), true, "the pages may open wide again")
	T.clean(w)
end)
