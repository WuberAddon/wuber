-- Tests of Theme.Forms (round 9, S6: the one shared look for clipped lists, T.EdgeFade and T.Scroll's
-- soft edges). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- a client's theme and a 300 x 200 viewport on its UIParent
local function setup()
	local W, w = T.contract("Theme.Forms", "tests/theme/forms_test.lua", {
		["T.Line"] = "function", ["T.Field"] = "function", ["T.EdgeFade"] = "function", ["T.Scroll"] = "function",
		["T.Sheet"] = "function", ["T.ListButton"] = "function", ["T.ParaLines"] = "function", ["T.Para"] = "function",
		["T.Tag"] = "function", ["T.AlertCard"] = "function",
	})
	local env = w.clients[1].env
	local host = env.CreateFrame("Frame", nil, env.UIParent)
	host:SetSize(300, 200)
	host:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	return W, w, W.Theme, host, env
end

test("Theme.Forms: T.Scroll shows a bottom fade while there is more below, a top fade once scrolled (S6)", function()
	local W, w, Th, host = setup()
	local s = Th.Scroll(host)
	s:SetAllPoints(host)
	ok(s:DoesClipChildren(), "the scroll clips its rows")
	local fd = s.edgeFade
	ok(fd and fd.top and fd.bottom, "the scroll has T.EdgeFade's two fades")
	s:SetContentHeight(150)
	w:advance(0.5)
	ok(not fd:Shown("top") and not fd:Shown("bottom"), "everything fits: no fade")
	s:SetContentHeight(600)
	w:advance(0.5)
	ok(fd:Shown("bottom"), "more below: the bottom fade shows")
	ok(not fd:Shown("top"), "at the top: no top fade")
	s:ScrollTo(200, true)
	w:advance(0.5)
	ok(fd:Shown("top") and fd:Shown("bottom"), "in the middle: both fades")
	s:ScrollTo(400, true)
	w:advance(0.5)
	ok(fd:Shown("top"), "at the end: the top fade")
	ok(not fd:Shown("bottom"), "at the end: no bottom fade")
	-- the fades sit above the rows and take no clicks
	ok(fd.holder:GetFrameLevel() > s.content:GetFrameLevel() + 30, "the fades are drawn above the rows")
	ok(not fd.holder:IsMouseEnabled(), "the fades never take the mouse")
	eq(fd.bottom:GetHeight(), 24, "a 24 px fade")
	T.clean(w)
end)

test("Theme.Forms: T.EdgeFade on a hand-made clip follows its source, and measures content when it has none (S6)", function()
	local W, w, Th, host, env = setup()
	local off, max = 0, 0
	local fd = Th.EdgeFade(host, { source = function() return off, max end, colour = "card", size = 30 })
	ok(host:DoesClipChildren(), "EdgeFade turns clipping on")
	eq(host.edgeFade, fd, "view.edgeFade")
	fd:Update()
	ok(not fd:Shown("top") and not fd:Shown("bottom"), "nothing more: no fade")
	max = 120
	fd:Update()
	ok(fd:Shown("bottom") and not fd:Shown("top"), "more below")
	off = 120
	fd:Update()
	ok(fd:Shown("top") and not fd:Shown("bottom"), "scrolled to the end")
	eq(fd.top:GetHeight(), 30, "the size asked for")
	-- measured: a content frame taller than the view, pinned to its top
	local v2 = env.CreateFrame("Frame", nil, env.UIParent)
	v2:SetSize(200, 100)
	v2:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	local c = env.CreateFrame("Frame", nil, v2)
	c:SetPoint("TOPLEFT", v2, "TOPLEFT", 0, 0)
	c:SetSize(200, 300)
	local f2 = Th.EdgeFade(v2, { content = c })
	w:advance(0.5)
	ok(f2:Shown("bottom") and not f2:Shown("top"), "measured: rows below the view")
	eq(f2.bottom:GetHeight(), 24, "a small view gets a fade a quarter of its height at most (25 here)")
	T.clean(w)
end)

test("Theme.Forms: lift sets how far above the list its fades sit (round 9 previews: under screens opened over it)", function()
	local W, w, Th, host = setup()
	local s = Th.Scroll(host)
	s:SetAllPoints(host)
	s:SetContentHeight(600)
	local low = Th.Scroll(host, { lift = 12 })
	low:SetAllPoints(host)
	low:SetContentHeight(600)
	w:advance(0.5)
	eq(s.edgeFade.holder:GetFrameLevel(), s:GetFrameLevel() + 40, "by default 40 above")
	eq(low.edgeFade.holder:GetFrameLevel(), low:GetFrameLevel() + 12, "lift 12: 12 above")
	ok(low.edgeFade:Shown("bottom"), "and it still fades")
	-- a hand-made clip takes it too
	local clip = Th.EdgeFade(host, { source = function() return 0, 50 end, lift = 5 })
	w:advance(0.5)
	eq(clip.holder:GetFrameLevel(), host:GetFrameLevel() + 5, "T.EdgeFade with lift 5")
	T.clean(w)
end)

-- the user types: focus, keys (OnTextChanged with user = true), as the client does
local function typeIn(field, text)
	local eb = field.edit
	eb:ClearFocus() -- (the fake box starts focused: it is made with autofocus on)
	eb:SetFocus()
	eb:SetText(text)
	local fn = eb:GetScript("OnTextChanged")
	if fn then fn(eb, true) end
end

test("Theme.Forms: a box with no get keeps what was typed when it loses focus (B1: notes, messages, price, search)", function()
	local W, w, Th, host = setup()
	local changed
	local note = Th.Field(host, 280, 92, { multi = true, max = 200, placeholder = "Anything", onChange = function(t) changed = t end })
	typeIn(note, "Pays in silver")
	ok(note.focused, "typing: the box has focus")
	eq(changed, "Pays in silver", "onChange saw the keys")
	note.edit:ClearFocus()
	ok(not note.focused, "focus lost")
	eq(note:Text(), "Pays in silver", "the typed text is still there after focus is lost")
	ok(not note.hint:IsShown(), "no placeholder over the text")
	note:Sync()
	eq(note:Text(), "Pays in silver", "a later Sync keeps it too (it has nothing to show instead)")
	-- Escape leaves the box and keeps the words (nothing to go back to)
	typeIn(note, "Likes Org")
	note.edit:GetScript("OnEscapePressed")(note.edit)
	eq(note:Text(), "Likes Org", "Escape keeps the typed text")
	-- a single-line box (price, place search) and Enter
	local entered
	local price = Th.Field(host, 140, 32, { justify = "RIGHT", max = 16, onEnter = function(t) entered = t end })
	typeIn(price, "1g 50s")
	price.edit:GetScript("OnEnterPressed")(price.edit)
	eq(entered, "1g 50s", "Enter hands over the typed text")
	eq(price:Text(), "1g 50s", "and the box keeps it after Enter clears the focus")
	-- emptied by the user: the placeholder comes back
	typeIn(note, "")
	note.edit:ClearFocus()
	eq(note:Text(), "", "emptied")
	ok(note.hint:IsShown(), "the placeholder shows again")
	T.clean(w)
end)

test("Theme.Forms: an onCommit box with no get commits what changed and keeps it; a box with get still shows get() (B1)", function()
	local W, w, Th, host = setup()
	local commits = {}
	local custom = Th.Field(host, 120, 30, { max = 12, onCommit = function(t) commits[#commits + 1] = t end })
	typeIn(custom, "60s")
	custom.edit:ClearFocus()
	eq(commits[1], "60s", "committed on focus lost")
	eq(custom:Text(), "60s", "the box keeps what was committed")
	custom.edit:SetFocus()
	custom.edit:ClearFocus()
	eq(#commits, 1, "focus in and out with no change: no second commit")
	typeIn(custom, "")
	custom.edit:ClearFocus()
	eq(commits[2], "", "clearing the box is a change too")
	-- managed: the box shows the saved value after focus is lost (what was put, or what was refused)
	local saved = "summon"
	local kw = Th.Field(host, 200, 30, { get = function() return saved end, onCommit = function(t) if t ~= "bad" then saved = t end end })
	eq(kw:Text(), "summon", "shows get()")
	typeIn(kw, "taxi")
	kw.edit:ClearFocus()
	eq(kw:Text(), "taxi", "committed and shown")
	typeIn(kw, "bad")
	kw.edit:ClearFocus()
	eq(kw:Text(), "taxi", "refused: back to the saved value")
	typeIn(kw, "ride")
	kw.edit:GetScript("OnEscapePressed")(kw.edit)
	eq(kw:Text(), "taxi", "Escape: back to the saved value")
	T.clean(w)
end)

test("Theme.Forms: the Note sheet keeps a note typed, then blurred by the Save click, and saves it (B1)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local dan = { name = "Dan Rider", key = "dan rider", state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	DR.Sorted = function() return { dan } end
	DR.customers = { [dan.key] = dan }
	DR.IsOpen = function() return true end
	if W.UI and W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	local D = W.Driver
	D.RefreshNow()
	w:advance(1)
	D.OpenMenu(dan)
	w:advance(1)
	a:click(D.ui.sheets.menu.items.custnote.note)
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(sh and sh.frame.open, "the Note sheet")
	typeIn(sh.field, "Tips well, always Org")
	sh.field.edit:ClearFocus() -- the click on Save takes the focus first
	eq(sh.field:Text(), "Tips well, always Org", "the note is still in the box")
	a:click(sh.save)
	w:advance(1)
	eq(DR.BookEntry("Dan Rider") and DR.BookEntry("Dan Rider").note, "Tips well, always Org", "saved in the book")
	T.clean(w)
end)

-- the author asked for a visible scroll bar on pages that scroll: a thin track and thumb on the
-- right edge, shown only while the list can scroll, following the scroll, never taking the mouse.
test("Theme.Forms BRIEF22 S1: a clipped list shows a thin scroll bar only while it can scroll, and it follows the scroll", function()
	local W, w, Th, host, env = setup()
	local H = T.H
	local s = Th.Scroll(host)
	s:SetAllPoints(host)
	local fd = s.edgeFade
	ok(fd.track and fd.thumb, "the list has a scroll bar (track and thumb)")
	s:SetContentHeight(150)
	w:advance(0.5)
	ok(not fd:BarShown() and not fd.track:IsShown(), "everything fits: no scroll bar")
	s:SetContentHeight(800)
	w:advance(0.5)
	ok(fd:BarShown() and fd.track:IsShown(), "more than fits: the scroll bar shows")
	local vr, tr, kr = H.rect(s), H.rect(fd.track), H.rect(fd.thumb)
	ok(kr.w <= 4 and tr.w <= 4, "a thin bar (" .. kr.w .. " px)")
	ok(kr.l >= vr.l + vr.w - 8 and kr.l + kr.w <= vr.l + vr.w, "on the right edge, inside the list")
	-- 200 of 800 in view: the thumb is a quarter of the track, at its top
	ok(math.abs(kr.h - tr.h / 4) <= 1, ("the thumb is the part in view (%d of %d)"):format(kr.h, tr.h))
	ok(math.abs((kr.b + kr.h) - (tr.b + tr.h)) <= 1, "at the top: the thumb at the top of the track")
	s:ScrollTo(300, true)
	w:advance(0.05)
	kr = H.rect(fd.thumb)
	local mid = (tr.b + tr.h) - (kr.b + kr.h)
	ok(mid > 1 and kr.b > tr.b + 1, "half way: the thumb is in the middle (" .. mid .. " px down)")
	s:ScrollTo(600, true)
	w:advance(0.05)
	kr = H.rect(fd.thumb)
	ok(math.abs(kr.b - tr.b) <= 1, "at the end: the thumb at the bottom of the track")
	-- it never takes the mouse, never scales, and the wheel still scrolls the list
	ok(not fd.holder:IsMouseEnabled(), "the bar takes no clicks")
	eq(fd.holder:GetScale(), 1, "never scaled")
	s:SetContentHeight(150)
	w:advance(0.5)
	ok(not fd:BarShown(), "fits again: the bar hides")
	-- a list can do without one
	local other = env.CreateFrame("Frame", nil, host)
	other:SetAllPoints(host)
	local plain = Th.EdgeFade(other, { bar = false, source = function() return 0, 300 end })
	plain:Update()
	ok(not plain.thumb and not plain:BarShown(), "bar = false: no scroll bar")
	T.clean(w)
end)
