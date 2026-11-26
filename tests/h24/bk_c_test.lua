local T = ...
-- Group C, job 415: break-it guards for the 2.4.1 changes in Driver/Screens.lua, Earnings.lua, Sheets.lua.
local test, eq, ok = T.test, T.eq, T.ok

local function earnings()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = a.W
	T.openDrive(a)
	W.UI.ShowDrive("console") w:advance(1)
	W.Driver.ShowScreen("earnings") w:advance(2)
	return w, a, W, W.UI.drive.screens.earnings
end

local function clear(s, tag)
	ok(s.scroll:GetTop() <= s.title:GetBottom() + 0.01, tag .. ": the scroll area (" .. tostring(s.scroll:GetTop())
		.. ") starts under the title's foot (" .. tostring(s.title:GetBottom()) .. ")")
end

-- guard: break-it, Earnings.lua:895 (and :914) the scroll area put back at 50 when the strip appears or goes: the title would be clipped
test("h24 bk c: the Earnings scroll area stays under its title whichever way the strip below it changes", function()
	local w, a, W, s = earnings()
	for _, adv in ipairs({ false, true, false }) do
		W.SetAdvanced(adv)
		w:advance(2)
		clear(s, "advanced=" .. tostring(adv) .. " strip=" .. tostring(s.strip))
	end
	T.clean(w)
end)

-- guard: break-it, Screens.lua:173 the 'if big then return end' dropped: small words at the right would drag the big title back beside the chevron
test("h24 bk c: small words set on a big-title screen do not move its title", function()
	local w, a, W, s = earnings()
	local _, _, _, x0, y0 = s.title:GetPoint(1)
	s.right:SetText("3 things")
	local p, _, _, x1, y1 = s.title:GetPoint(1)
	eq(p, "TOPLEFT", "still hangs from its top left")
	eq(y1, y0, "the title did not move")
	eq(x1, x0, "the title did not move sideways")
	T.clean(w)
end)


local function shiftCard()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:addBot("Vex Shade", { spot = "Orgrimmar" })
	T.settle(w)
	local W = a.W
	T.openDrive(a)
	W.UI.ShowDrive("console") w:advance(1)
	w:group({ T.ANITA, "Vex Shade" }) w:advance(1)
	W.Driver.lastShift = { rides = 5, copper = 20000, tips = 0, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = { { key = W.myKey, name = T.ANITA, casts = 3, clicks = 0, share = 18000 },
		{ key = "vex shade", name = "Vex Shade", casts = 0, clicks = 2, share = 12000 } }, rule = "clicks", pct = 40 } }
	W.Driver.ShowSheet("shift") w:advance(1)
	return w, a, W, W.UI.drive.screens.shift
end

-- guard: break-it, Sheets.lua:768 the OnSizeChanged hook that narrows Nice when the pill widens: UI.Share widens the pill by itself in a fight, with no repaint of the card
test("h24 bk c: Nice gives way the moment the share pill widens, before the card repaints", function()
	local w, a, W, s = shiftCard()
	local p = s.split.post
	w:enterCombat(a)
	W.UI.Share.Sync()
	ok(p:GetWidth() > 156, "the pill widened to " .. tostring(p:GetWidth()))
	ok(p:GetRight() <= s.done:GetLeft() - 2, "pill right " .. tostring(p:GetRight()) .. " clears Nice left " .. tostring(s.done:GetLeft()))
	T.clean(w)
end)

-- guard: break-it, Sheets.lua:739-742 postPillWidth fixed at 156 / Sheets.lua:916 the fight width dropped: without UI.Share's own state the pill still holds its words
test("h24 bk c: without UI.Share the pill is wide enough for 'Share after combat' and clears Nice", function()
	local w, a, W, s = shiftCard()
	local p = s.split.post
	W.UI.Share.State = function() return nil end
	w:enterCombat(a)
	W.Driver.PaintSplit(s, s.frame)
	eq(p.label:GetText(), "Share after combat", "its words")
	local need = W.Theme.MeasureText("Share after combat", "body", "medium")
	ok(p:GetWidth() >= need + 40, "pill " .. tostring(p:GetWidth()) .. " holds " .. tostring(need) .. " plus its padding")
	ok(p:GetRight() <= s.done:GetLeft() - 2, "pill right " .. tostring(p:GetRight()) .. " clears Nice left " .. tostring(s.done:GetLeft()))
	T.clean(w)
end)
