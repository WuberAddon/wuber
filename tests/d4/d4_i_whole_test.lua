-- Design round 4, group I (quick win 7): hovering a one-line label that is cut shows its whole text. Loaded by
-- tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local LONG = "Aaaaaaaaaaaaaaa-Bbbbbbbbbbbbbbbbbbb of the Very Long Realm Name"

local function setup()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local f = a.env.CreateFrame("Button", nil, a.env.UIParent)
	f:SetSize(120, 30)
	f:SetPoint("CENTER")
	f:Show()
	f.wuberWorld = w
	return w, a, W, f
end

local function label(W, f, text, width)
	local fs = W.Theme.Text(f, "body", "white", "LEFT", "bold")
	fs:SetPoint("LEFT", f, "LEFT", 4, 0)
	fs:SetWidth(width or 100)
	fs:SetText(text)
	f.wuberWorld:advance(1) -- the hover is set a moment after the label is laid out
	return fs
end

local function lines(a)
	local gt = a.env.GameTooltip
	local out = {}
	for i = 1, 6 do
		local fs = a.env["GameTooltipTextLeft" .. i]
		if fs and fs:IsShown() and fs:GetText() then out[#out + 1] = fs:GetText() end
	end
	return out, gt
end

local function hover(f) local h = H.scriptsOf and H.scriptsOf(f) or nil f:GetScript("OnEnter")(f) end

test("d4 i whole: a cut one-line label shows its whole text when its parent control is hovered", function()
	local w, a, W, f = setup()
	f:EnableMouse(true)
	local fs = label(W, f, LONG)
	ok(fs:IsTruncated(), "setup: the label is cut")
	f:GetScript("OnEnter")(f)
	local got = lines(a)
	eq(got[1], LONG, "the whole text is the first line")
	eq(#got, 1, "and the only one when the control has no tip")
	f:GetScript("OnLeave")(f)
	T.clean(w)
end)

test("d4 i whole: a label that fits shows nothing new", function()
	local w, a, W, f = setup()
	f:EnableMouse(true)
	label(W, f, "Anita", 100)
	local on = f:GetScript("OnEnter")
	if on then on(f) end
	eq(#lines(a), 0, "no tip")
	T.clean(w)
end)

test("d4 i whole: an owner with its own tip shows the whole text first, then its words", function()
	local w, a, W, f = setup()
	f:EnableMouse(true)
	local fs = label(W, f, LONG)
	W.Theme.Tip(f, "Open the profile", "Shows who this is.") -- set after the helper: the order must not matter
	f:GetScript("OnEnter")(f)
	local got = lines(a)
	eq(got[1], LONG, "whole text first")
	eq(got[2], "Open the profile", "then the tip's title")
	eq(got[3], "Shows who this is.", "then its words")
	f:GetScript("OnLeave")(f)
	local fresh = a.env.CreateFrame("Button", nil, a.env.UIParent)
	fresh:SetSize(120, 30) fresh:SetPoint("CENTER") fresh:EnableMouse(true)
	fresh.wuberWorld = w
	W.Theme.Tip(fresh, "Own words", "Only these.")
	label(W, fresh, "Short", 100)
	fresh:GetScript("OnEnter")(fresh)
	eq(#lines(a), 2, "a label that fits leaves the tip as it was")
	T.clean(w)
end)

test("d4 i whole: a parent that takes no mouse gets a hover-only frame that never takes the click", function()
	local w, a, W, f = setup()
	f:EnableMouse(false)
	local fs = label(W, f, LONG)
	local over
	for _, c in ipairs({ f:GetChildren() }) do if c.wuberWholeMouse then over = c end end
	ok(over, "a thin frame lies over the label")
	ok(over:GetScript("OnEnter") or over.wuberWholes, "it has the hover")
	ok(not over:IsMouseEnabled() or over.wuberWholeMouse, "click disabled where the client allows it")
	over:GetScript("OnEnter")(over)
	eq(lines(a)[1], LONG, "hovering it shows the whole text")
	T.clean(w)
end)

test("d4 i whole: the click still reaches the control", function()
	local w, a, W, f = setup()
	f:EnableMouse(true)
	label(W, f, LONG)
	local n = 0
	f:SetScript("OnClick", function() n = n + 1 end)
	f:GetScript("OnEnter")(f)
	f:GetScript("OnClick")(f)
	eq(n, 1, "OnClick is the control's own")
	eq(#f.wuberWholes, 1, "the hover rides on the control (HookScript), its click script is untouched")
	T.clean(w)
end)

test("d4 i whole: a driver row with a long name shows it whole on hover", function()
	local w, a, W = setup()
	local D = W.Driver
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 300) parent:SetPoint("CENTER") parent:Show()
	local r = D.Row(parent, 260)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	D.PaintRow(r, { name = "Averyveryveryverylongridername-Realmofmanyletters", state = "joined", source = "whisper", at = 1000 }, 1000)
	w:advance(1)
	ok(r.name:IsTruncated() or W.Theme.CutOneLine(r.name), "setup: the name is cut")
	local owner = r.name.wuberWhole
	ok(owner, "the name has its hover")
	owner:GetScript("OnEnter")(owner)
	local got = lines(a)
	local seen = false
	for _, l in ipairs(got) do if l == r.name:GetText() then seen = true end end
	ok(seen, "the tip carries the name whole")
	T.clean(w)
end)

test("d4 i whole: a pill with a long label (the Home pills) shows it whole, with its own tip kept below", function()
	local w, a, W = setup()
	local Th = W.Theme
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(300, 100) parent:SetPoint("CENTER") parent:Show()
	local b = Th.Pill(parent, "Stranglethorn Vale and its many many camps", "dark", 96, 30)
	b:SetPoint("CENTER")
	w:advance(1)
	Th.Tip(b, "Pledge", "Nothing is paid now.")
	ok(b.label:IsTruncated(), "setup: the label is cut")
	b:GetScript("OnEnter")(b)
	local got = lines(a)
	eq(got[1], b.label:GetText(), "the pill's words whole, first")
	eq(got[2], "Pledge", "its own tip after")
	T.clean(w)
end)

test("d4 i whole: a label that fits in the same pill keeps only its own tip", function()
	local w, a, W = setup()
	local Th = W.Theme
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(300, 100) parent:SetPoint("CENTER") parent:Show()
	local b = Th.Pill(parent, "1g", "dark", 96, 30)
	b:SetPoint("CENTER")
	w:advance(1)
	Th.Tip(b, "Pledge 1g", "Nothing is paid now.")
	b:GetScript("OnEnter")(b)
	eq(lines(a)[1], "Pledge 1g", "just the tip")
	T.clean(w)
end)
