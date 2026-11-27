local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
-- r54 E (Lab Auto check 24 Nov: "Raid summons" cut on 10 folded screens): the game draws regular/medium text 6 to 8 per cent wider than the
-- width table, so the mode bar's words need room for that. Promise: in every layout, each word's frame holds its table width plus 8 per cent.
local function bar(o)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", simple = o.simple })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if o.wide then a.wide = true W.db.coach = true W.UI.WindowWide(true) elseif W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console") w:advance(1)
	DR.SetMode("raid") w:advance(1)
	W.Driver.RefreshNow() w:advance(1)
	if o.fold then
		local ui = W.UI.state
		ui.phone.fold:Click() w:advance(1.5)
	end
	return w, a, W
end
local function holds(name, W)
	local seg = W.Driver.ui.console.modeBar
	ok(H.visible(seg), name .. ": the switch shows")
	for _, b in ipairs(seg.buttons) do
		local text = b.label:GetText()
		local table_ = W.Theme.MeasureText(text, W.Theme.SIZE.small, "medium")
		ok(b.label:GetWidth() >= table_ * 1.08, name .. ": '" .. text .. "' has room for the game's wider drawing: " .. b.label:GetWidth() .. " for " .. table_)
	end
end
local function foldedBesideFold(simple)
	local w, a, W = bar({ simple = simple, wide = true, fold = true })
	eq(W.UI.state.win:GetWidth(), 360, "folded")
	holds("folded + fold button", W)
	T.clean(w)
end
local function otherLayouts(simple)
	local w, a, W = bar({ simple = simple })
	holds("folded", W)
	T.clean(w)
	w, a, W = bar({ simple = simple, wide = true })
	if not simple then -- (Simple has no wide pages: the window stays folded)
		eq(W.UI.state.win:GetWidth(), 720, "unfolded")
		eq(W.Driver.ui.console.modeBar:GetWidth(), 328, "the unfolded switch is as wide as the pane")
	end
	holds("unfolded", W)
	T.clean(w)
end
-- guard: Simple has no fold button (no wide pages), so the switch is never beside all three buttons there
test("r54 E guard: the mode bar's words have 8 per cent spare in Simple (no fold button)", function() foldedBesideFold(true) end)
test("r54 E: the mode bar's words have 8 per cent spare, folded beside the fold button (Advanced)", function() foldedBesideFold(false) end)
-- guard: the other layouts already held the words with room; they still do (the unfolded switch stays as wide as the pane)
test("r54 E guard: the mode bar's words have 8 per cent spare folded without the fold button and unfolded (Simple)", function() otherLayouts(true) end)
-- guard: the same, Advanced
test("r54 E guard: the mode bar's words have 8 per cent spare folded without the fold button and unfolded (Advanced)", function() otherLayouts(false) end)
