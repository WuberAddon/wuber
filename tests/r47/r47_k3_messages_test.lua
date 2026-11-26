local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function console(wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	DR.customers = {}
	DR.IsOpen = function() return true end
	if wide then a.wide = true W.db.coach = true W.UI.WindowWide(true)
	else W.UI.WindowWide(false) end
	T.openDrive(a)
	if W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	return w, a, W, DR
end

-- (2.4, the word rule) a list card shows its title and when only; the words it sends are in its tooltip
-- (after "Click to change it.") and in the editor
local function cardWords(a, r)
	local gt = a.env.GameTooltip
	H.state[r].scripts.OnEnter(r)
	local all = table.concat(H.state[gt].tipLines or {}, "\n")
	H.state[r].scripts.OnLeave(r)
	return (all:match("Click to change it%.%s*(.*)$") or ""):gsub("^%s+", "")
end
test("r47 k3: the Ask a summoner message previews with the summoner's name", function()
	local w, a, W = console(false)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	local greet
	for _, r in ipairs(s.rows) do if r.kind == "greet" then greet = r end end
	ok(greet and cardWords(a, greet) ~= "", "control: the Greeting card's tooltip has the words")
	local row
	for _, r in ipairs(s.rows) do if r.kind == "callsum" then row = r end end
	local t = cardWords(a, row)
	ok(t ~= "", "control: the Ask a summoner card's tooltip has the words")
	ok(not t:find("^%s*:"), "the Ask a summoner row reads '" .. t .. "': the Warlock's name is missing before the colon")
	W.Driver.ShowScreen("messages")
	s.edit("callsum")
	local p = s.editor.prev:GetText() or ""
	ok(not p:find("^%s*:"), "the live preview bubble reads '" .. p .. "': no name before the colon")
	T.clean(w)
end)
test("r47 k3: leaving the unfolded Messages screen does not flip it to the folded editor while it slides out", function()
	local w, a, W = console(true)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	ok(W.UI.Fold.IsUnfolded(), "control: unfolded")
	ok(#s.rows > 0 and s.rows[1]:IsShown(), "control: the list rows show while unfolded")
	W.Driver.ShowScreen("console")
	w:advance(0.05)
	local shown = 0
	for _, r in ipairs(s.rows) do if r:IsShown() then shown = shown + 1 end end
	ok(shown > 0 and not s.foldEd:IsShown(), "while the screen slides out the list rows are hidden (" .. shown .. " shown) and the folded editor appears (" .. tostring(s.foldEd:IsShown()) .. ")")
	T.clean(w)
end)
local function layoutOf(W, s)
	local wideEd = s.wideEd and s.wideEd.frame and s.wideEd.frame:IsShown()
	return { unfolded = W.UI.Fold.IsUnfolded(), isWide = s.isWide(), editor = s.editor, foldEd = s.foldEd, wideEd = s.wideEd }
end
test("r47 k3: unfolded Messages, Back, fold the window, open Messages again: the folded layout", function()
	local w, a, W = console(true)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	ok(s.isWide() and s.editor == s.wideEd, "control: unfolded Messages uses the side-pane editor")
	W.Driver.ShowScreen("console")
	w:advance(1)
	W.UI.WindowWide(false)
	w:advance(1)
	ok(not W.UI.Fold.IsUnfolded(), "control: the window is folded now")
	W.Driver.ShowScreen("messages")
	w:advance(1)
	ok(not s.isWide(), "Messages reads folded")
	ok(s.editor == s.foldEd, "the folded editor is the one in use, not the side pane's")
	ok(s.intro:IsShown() and s.rows[1]:IsShown(), "the list and its rows show")
	ok(not s.foldEd:IsShown(), "the folded editor is hidden while the list shows")
	ok(not (s.wideEd and s.wideEd:IsShown()), "no side-pane editor shows")
	W.Driver.ShowScreen("console") w:advance(1)
	W.UI.WindowWide(true) w:advance(1)
	W.Driver.ShowScreen("messages") w:advance(1)
	ok(s.isWide() and s.editor == s.wideEd, "control: unfolding again goes wide")
	T.clean(w)
end)
test("r47 k3: folded Messages, Back, unfold the window on the console, open Messages: the unfolded layout", function()
	local w, a, W = console(false)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	ok(not s.isWide() and s.editor == s.foldEd, "control: folded")
	W.Driver.ShowScreen("console")
	w:advance(1)
	a.wide = true W.db.coach = true W.UI.WindowWide(true)
	w:advance(1)
	ok(W.UI.Fold.IsUnfolded(), "control: unfolded on the console")
	W.Driver.ShowScreen("messages")
	w:advance(1)
	ok(s.isWide(), "Messages reads unfolded")
	ok(s.editor == s.wideEd and s.wideEd ~= nil, "the side-pane editor is in use")
	ok(s.placedWide == true, "the screen was laid out as the unfolded one")
	T.clean(w)
end)
