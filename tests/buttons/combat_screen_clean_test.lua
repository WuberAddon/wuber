-- #232 The fake game looks at the whole screen after a fight (H.drawnTexts), not only at the one button.
-- 76b3b5a left "Paused during combat" drawn over Ride and Settings (fixed in #204); the old test read the
-- button's own alpha, so a label left on any other region would have passed. A sim run of the real scene found it.
-- Rule: a text that is drawn on the Drive tab only because of the fight (combat-only) must not be drawn on
-- another page while the fight goes on, nor after it ends.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	W.Driver.SetOnline(true)
	w:advance(2)
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Drive") w:advance(1.2)
	return w, d, W
end

-- the texts the fight itself puts on the Drive tab: drawn in the fight, not drawn there out of combat
local function combatOnly(before, now)
	local out = {}
	for t in pairs(now) do if not before[t] then out[#out + 1] = t end end
	table.sort(out)
	return out
end

local function leftOver(d, only, where)
	local left = {}
	local now = H.drawnTextSet(d)
	for _, t in ipairs(only) do if now[t] then left[#left + 1] = t end end
	ok(#left == 0, where .. ": combat-only text still drawn: " .. table.concat(left, " | "))
end

test("#232 H.drawnTexts: lists a shown text, drops a hidden, faded or off-screen one", function()
	local w, d, W = setup()
	local f = d.env.CreateFrame("Frame", "ScreenProbe232", d.env.UIParent)
	f:SetSize(100, 20) f:SetPoint("CENTER")
	local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER") fs:SetText("probe text 232")
	local function has() return #H.drawnTexts(d, { match = "probe text 232" }) == 1 end
	eq(has(), true, "shown: listed")
	f:SetAlpha(0) eq(has(), false, "frame alpha 0: not listed") f:SetAlpha(1)
	f:Hide() eq(has(), false, "hidden: not listed") f:Show()
	f:ClearAllPoints() f:SetPoint("TOPLEFT", d.env.UIParent, "TOPLEFT", -5000, 0)
	eq(has(), false, "off screen: not listed")
	T.clean(w)
end)

test("#232 screen after a fight: Drive tab, fight, Ride, Settings, fight ends: no combat-only text is drawn", function()
	local w, d, W = setup()
	local baseDrive = H.drawnTextSet(d)
	w:enterCombat(d) w:advance(0.5)
	ok(#H.drawnTexts(d, { match = "Paused during combat" }) > 0, "control: the paused label is drawn on the Drive tab in the fight")
	local only = combatOnly(baseDrive, H.drawnTextSet(d))
	ok(#only > 0, "control: the fight puts its own text on the Drive tab")
	W.UI.SelectTab("Ride") w:advance(1.5)
	leftOver(d, only, "Ride in the fight")
	W.UI.OpenSettings() w:advance(1.5)
	eq(#H.drawnTexts(d, { match = "Paused during combat" }), 0, "Settings in the fight: no paused label")
	eq(#H.drawnTexts(d, { match = "the button works again" }), 0, "Settings in the fight: no paused sub line")
	leftOver(d, only, "Settings in the fight")
	w:leaveCombat(d) w:advance(1.5)
	eq(#H.drawnTexts(d, { match = "Paused during combat" }), 0, "fight over: no paused label")
	leftOver(d, only, "Settings, fight over")
	W.UI.CloseSettings() w:advance(0.5)
	W.UI.SelectTab("Drive") w:advance(1.5)
	eq(#H.drawnTexts(d, { match = "Paused during combat" }), 0, "back on Drive after the fight: not paused")
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	T.clean(w)
end)

test("#232 screen after a fight: the window closed in the fight, then reopened after it: no combat-only text", function()
	local w, d, W = setup()
	local before = H.drawnTextSet(d)
	w:enterCombat(d) w:advance(0.5)
	local only = combatOnly(before, H.drawnTextSet(d))
	W.UI.Toggle(false) w:advance(1.5)
	eq(#H.drawnTexts(d, { match = "Paused during combat" }), 0, "window closed in the fight: no paused label")
	w:leaveCombat(d) w:advance(1.5)
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Ride") w:advance(1.5)
	leftOver(d, only, "Ride after the fight")
	T.clean(w)
end)
