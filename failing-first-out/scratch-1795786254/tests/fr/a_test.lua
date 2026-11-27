local T = ...
-- Fix round 2.4, group a: ING-01 (a label the game has not placed answers GetLeft with NO value) and HUNT-129
-- (the Share pill is as wide as its words in a fight). Loaded by tests/run.lua with its helper table T.
local test, eq, ok = T.test, T.eq, T.ok

test("fr a: ING-01 the big Drive button paints fully when GetLeft/GetRight give no value", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local DR = d.W.Drive
	local b = d.env.WuberDriveButton
	ok(b and b.title and b.sub, "control: the button and its words")
	-- the real game: a bare return, no nil
	b.title.GetLeft = function() end
	b.title.GetRight = function() end
	b.sub:SetText("stale")
	local good, err = pcall(DR.Button.Refresh)
	ok(good, "no error: " .. tostring(err))
	ok(b.sub:GetText() ~= "stale", "the line under the title was painted")
	T.clean(w)
end)

test("fr a: ING-01 a pill and a card row survive a getter that gives no value", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local Th = r.W.Theme
	local p = Th.Pill(UIParent or r.env.UIParent, "Go", "dark", 100, 30)
	p.GetWidth = function() end
	p.GetHeight = function() end
	local good, err = pcall(p.SetLabel, p, "Another")
	ok(good, "SetLabel: " .. tostring(err))
	T.clean(w)
end)

test("fr a: HUNT-129 the Share pill is as wide as 'Share after combat' in a fight", function()
	local w = T.newWorld()
	local r = T.rider(w)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	W.UI.Toggle(true)
	w:advance(3)
	local pill = W.Theme.Pill(W.UI.GetTab("Ride"), "Tell the guild", "dark", 124, 30)
	W.UI.Share.Register(pill, function() return "a line" end, { label = "Tell the guild" })
	w:group({ "Wuber TestCharacter", "Sly Fox" })
	w:advance(1.5)
	W.UI.RefreshNow()
	eq(pill:GetWidth(), 124, "plain width")
	w:enterCombat(r)
	w:advance(1.2)
	eq(pill.label:GetText(), "Share after combat", "its words")
	local need = W.Theme.MeasureText("Share after combat", "sub", "medium")
	ok(pill:GetWidth() - 30 >= need, "room " .. tostring(pill:GetWidth() - 30) .. " for words " .. tostring(need))
	w:leaveCombat(r)
	w:advance(1.5)
	eq(pill:GetWidth(), 124, "back to plain width")
	T.clean(w)
end)
