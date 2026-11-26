-- c2807 #10: wide Help has no contents list (no "1".."8" index rows) and its cards use the freed width; the wide Settings list stays.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function wideWorld()
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.wide = true
	c.W.db.fold = { v = 1, pages = {}, narrow = false }
	c.W.UI.Toggle(true)
	w:advance(3)
	return w, c
end

test("c2807 #10 wide Help shows no contents list and the cards use the freed width", function()
	local w, c = wideWorld()
	local UI = c.W.UI
	UI.OpenHelp("settings")
	w:advance(1)
	local help = UI.settings.help
	eq(help.nav, nil, "no contents list object")
	for _, t in ipairs(c:visibleTexts()) do
		local s = tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		ok(not s:find("^%d$"), "no index row on screen: " .. s)
	end
	eq(#help.cards, 8, "the eight cards still show")
	local clipW = help.clip:GetWidth()
	for i = 1, 8 do
		ok(help.cards[i]:GetWidth() > clipW - 40, "card " .. i .. " spans the pane, not a narrow column")
	end
	T.clean(w)
end)

test("c2807 #10 wide Settings keeps its list of pages", function()
	local w, c = wideWorld()
	local UI = c.W.UI
	UI.OpenSettings()
	w:advance(1)
	ok(UI.settings.nav and #UI.settings.nav.rows > 0, "the page list is still there")
	T.clean(w)
end)
