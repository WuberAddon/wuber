local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
-- i6a (b) Lab Auto check 24 Nov: "Tell me when one opens" cut on the Home search page (the game drew "Tell me when one o...").
-- Promise: the words on the bell button are never cut in the game. Wuber's own fit asks the game (IsTruncated) and shrinks the
-- words; the bell's label is re-anchored narrower after the pill fitted it (Home.lua:842-845) and is not fitted again.
-- The fake draws text 6 per cent wider than the table (H.GAME_TEXT_MARGIN); the author's game drew this one wider still, so the
-- test lets the fake do the same and asks whether the label is cut.
local function bellWorld(margin)
	local old = H.GAME_TEXT_MARGIN
	if margin then H.GAME_TEXT_MARGIN = margin end
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local UI = c.W.UI
	local list = { { name = "Cal", key = "cal", short = "Cal", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Cal's Rides", heard = c.env.GetTime(), queue = 0 } }
	UI.Drivers = function() return list end
	UI.Driver = function(key) return list[1] and list[1].key == key and list[1] or nil end
	UI.Toggle(true)
	w:advance(3)
	UI.SetSearch("Undercity")
	w:advance(1)
	UI.Refresh(true)
	w:advance(2)
	local bell = UI.state.screens.home.bell
	return w, bell, old
end
local function restore(old) H.GAME_TEXT_MARGIN = old end

-- guard: at the fake's usual width the bell's words fit its room (what the Lab's sweep and the old tests see)
test("i6a guard: the bell's words are not cut at the fake's usual text width", function()
	local w, bell, old = bellWorld(nil)
	local shown, cut = H.visible(bell), H.truncation(bell.label)
	restore(old)
	ok(shown, "control: the bell shows with a driver listed for a searched place")
	eq(cut, nil, "words whole at the usual margin")
	T.clean(w)
end)

test("i6a: the bell's words are whole when the game draws them 20 per cent wider than the table", function()
	local w, bell, old = bellWorld(1.2)
	local shown = H.visible(bell)
	local cut = H.truncation(bell.label)
	restore(old)
	ok(shown, "control: the bell shows")
	ok(cut == nil, "the bell's words are cut: " .. (cut and ("needs " .. tostring(cut.need) .. " in " .. tostring(cut.room)) or ""))
	T.clean(w)
end)
