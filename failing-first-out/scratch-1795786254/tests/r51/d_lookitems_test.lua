-- r51 group D: Lab run 1 Auto check, four "need a look" rows in Settings (RUN1-8a).
-- Each test drives the path the Lab probe drives (the Lab's AutoSteps.lua) and checks the words.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function open(adv, section)
	local w = T.newWorld()
	local d = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
	w:advance(2)
	d.W.SetAdvanced(adv)
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings(section)
	w:advance(2)
	return w, d, d.W.UI.settings.controls
end

-- everything the player is told: toasts and the undo toast
local function listen(W)
	local said = {}
	local t, u = W.UI.Toast, W.UI.UndoToast
	W.UI.Toast = function(x, ...) said[#said + 1] = tostring(x) return t(x, ...) end
	W.UI.UndoToast = function(x, ...) said[#said + 1] = tostring(x) return u(x, ...) end
	return said, function() W.UI.Toast, W.UI.UndoToast = t, u end
end
local function has(said, s) for _, x in ipairs(said) do if x:find(s, 1, true) then return true end end end

for _, adv in ipairs({ false, true }) do
	-- guard: run1 a_size, Wuber shows it in Simple and Advanced; the Lab probe AutoSteps.lua:201 reads the card by its own scan of the folded home and finds none (not proven why: the home is read before the section cards are drawn, or in a state this fake does not reach)
	test("r51 d: a_size AUD-172 the Settings home card says Size N% (" .. (adv and "Advanced" or "Simple") .. ")", function()
		local w, d = open(adv)
		local real = math.floor(d.W.UI.state.win:GetScale() * 100 + 0.5)
		local got = d:findText("Size %d+%%")
		ok(#got > 0, "the Size card line shows: " .. T.list(d:visibleTexts()):sub(1, 300))
		eq(tonumber(got[1]:GetText():match("Size (%d+)%%")), real, "the card says the window's real size")
		T.clean(w)
	end)
end

-- guard: run1 a_wide_reset, Wuber says "1 setting reset." with Undo (decisions N), not the old line, once Always narrow was saved; the Lab probe AutoSteps.lua:217 still waits for the old toast "Every page is back to Auto", which only shows when nothing was changed
test("r51 d: a_wide_reset HUNT-72 Always narrow then Reset: back to Auto, told '1 setting reset.' with Undo", function()
	local w, d, c = open(true, "window")
	local said, undo = listen(d.W)
	c.foldWide.buttons[2]:Click()
	w:advance(0.5)
	eq(d.W.db.fold.narrow, true, "Always narrow saved")
	c.foldReset:Click()
	w:advance(0.5)
	eq(d.W.db.fold.narrow, false, "the choice is Auto again")
	eq(c.foldWide.value, "auto", "the pill shows Auto")
	ok(has(said, "1 setting reset."), "told: " .. table.concat(said, " | "))
	ok(not has(said, "Every page is back to Auto"), "the old line is not the answer when something changed")
	undo()
	T.clean(w)
end)

-- guard: run1 a_wide_reset, with nothing to forget Reset still says "Every page is back to Auto" (the neighbouring path)
test("r51 d: a_wide_reset Reset with nothing saved says Every page is back to Auto", function()
	local w, d, c = open(true, "window")
	local said, undo = listen(d.W)
	c.foldReset:Click()
	w:advance(0.5)
	ok(has(said, "Every page is back to Auto"), "told: " .. table.concat(said, " | "))
	undo()
	T.clean(w)
end)

-- guard: run1 a_pos_reset, Wuber forgets the place and says "1 setting reset." with Undo (decisions N), as r33 m4 pins; the Lab probe AutoSteps.lua:788 saves a place first, so the old line never shows
test("r51 d: a_pos_reset HUNT-59 Window position Reset forgets the place and says so", function()
	local w, d, c = open(false, "window")
	local said, undo = listen(d.W)
	d.W.db.pos = { "TOPLEFT", "TOPLEFT", 40, -40 }
	c.resetPos:Click()
	w:advance(1)
	eq(d.W.db.pos, nil, "the saved place is forgotten")
	ok(has(said, "setting reset."), "told: " .. table.concat(said, " | "))
	undo()
	T.clean(w)
end)

-- guard: run1 a_pos_reset, with no saved place or size the old line shows
test("r51 d: a_pos_reset with nothing saved says Window back in its usual place", function()
	local w, d, c = open(false, "window")
	local said, undo = listen(d.W)
	d.W.db.pos, d.W.db.scale = nil, nil
	c.resetPos:Click()
	w:advance(1)
	ok(has(said, "Window back in its usual place"), "told: " .. table.concat(said, " | "))
	undo()
	T.clean(w)
end)

-- guard: run1 a_tip_words, the tooltip carries the corrected words of r46 (HUNT-43), which no longer hold "Advert channels"; the Lab probe AutoSteps.lua:313 still looks for the old words
test("r51 d: a_tip_words HUNT-43 the go-online advert tooltip says what it does", function()
	local w, d, c = open(true, "driving")
	local f, t = c.advertOnline, nil
	while f and not t do t = f.wuberTip f = (not t) and f.GetParent and f:GetParent() or nil end
	ok(t, "the row has a tooltip")
	local all = tostring(t.title) .. "\n" .. tostring(t.text)
	ok(all:find("Opening also posts one advert line in public chat. At most once every 15 minutes. Never in combat, never without your click. Change the words in Messages.", 1, true), "the words: " .. all)
	ok(not all:find("Advert channels", 1, true), "the old promise of channels is gone")
	T.clean(w)
end)
