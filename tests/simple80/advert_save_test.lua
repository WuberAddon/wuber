-- #80: in Simple mode the "My advert line" page is the only message page; Save leaves it like Back does.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function open(adv, unfold)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080, wide = unfold == true })
	a.wide = unfold == true
	w:advance(15)
	local W = a.W
	W.SetAdvanced(adv)
	T.openDrive(a)
	if unfold and not W.UI.Fold.IsUnfolded() then W.UI.Fold.Toggle() w:advance(3) end
	W.Driver.ShowScreen("messages", "advert")
	w:advance(1)
	return w, a, W, W.Driver.ui.subs.messages
end

local function anyRowShown(s)
	for _, r in ipairs(s.rows) do if r:IsShown() then return true end end
	return false
end

test("#80 Simple, folded: Save on the advert line leaves the screen and lists no other message", function()
	local w, a, W, s = open(false, false)
	s.editor.field:SetText("WTS summons to Ratchet")
	a:clickOn(s.editor.save)
	w:advance(1)
	eq(W.Driver.CurrentScreen(), "console", "back on the console")
	ok(not anyRowShown(s), "no message row is shown")
	T.clean(w)
end)

-- guard: Simple mode is always folded, so the unfolded side pane can never list the other messages
test("#80 guard: Simple on a wide screen stays folded: no side pane, no message rows", function()
	local w, a, W, s = open(false, true)
	ok(not W.UI.Fold.IsUnfolded(), "Simple does not unfold")
	ok(not s.isWide(), "the Messages page is not wide")
	ok(not anyRowShown(s), "no message row is shown beside the advert editor")
	T.clean(w)
end)

-- guard: Advanced keeps the list of messages after Save
test("#80 guard: Advanced, folded: Save shows the list of messages", function()
	local w, a, W, s = open(true, false)
	s.editor.field:SetText("WTS summons to Ratchet")
	a:clickOn(s.editor.save)
	w:advance(1)
	eq(W.Driver.CurrentScreen(), "messages", "still on Messages")
	ok(anyRowShown(s), "the list is shown")
	T.clean(w)
end)

-- guard: Advanced unfolded keeps the list beside the editor
test("#80 guard: Advanced, unfolded: the list stays beside the editor", function()
	local w, a, W, s = open(true, true)
	ok(anyRowShown(s), "the list is shown wide=" .. tostring(s.isWide()) .. " unf=" .. tostring(W.UI.Fold.IsUnfolded()) .. " dw=" .. tostring(W.Driver.wide.messages) .. " r1=" .. tostring(s.rows[1]:IsShown()) .. " kind=" .. tostring(s.kind))
	T.clean(w)
end)
