-- Issue 102: the crew offer card keeps off the big summon button and its console. The card used to
-- steer clear of the action bars and chat only, so at its top-centre place it could sit on the
-- big button (default: centre, 200 up). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, ok, H = T.test, T.ok, T.H

-- { name, UIParent width, height (UI units), the physical window }
local SIZES = {
	{ "2662x2089 (UIParent 1372 x 1077)", 1372, 1077, 2662, 2089 },
	{ "2662x2089 at the default UI scale", 979, 768, 2662, 2089 },
	{ "1920x1080", 1365, 768, 1920, 1080 },
	{ "3840x2160", 1365, 768, 3840, 2160 },
	{ "3840x2160 at a small UI scale", 1920, 1080, 3840, 2160 },
	{ "3840x2160, big button at 2.2", 1365, 768, 3840, 2160, 2.2 },
}

local function setup(size)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	if size[6] then
		local b = W.db.drive and W.db.drive.button
		if b then b.scale, b.sizeSet = size[6], true end
	end
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = size[2], size[3]
	d.physW, d.physH = size[4], size[5]
	d.wide = true
	d:fire("DISPLAY_SIZE_CHANGED")
	W.Driver.SetOnline(true)
	w:advance(2)
	return w, d, W
end

local function shown(f)
	if not (f and f:IsVisible()) then return nil end
	return H.rect(f)
end

local function hits(a, c)
	return a.l < c.l + c.w and a.l + a.w > c.l and a.b < c.b + c.h and a.b + a.h > c.b
end

for _, size in ipairs(SIZES) do
	test("UI crew offer 102: " .. size[1] .. ": the card keeps off the big button and its console, on the screen", function()
		local w, d, W = setup(size)
		local sw, sh = size[2], size[3]
		if W.UI.IsShown() then W.UI.Toggle(false) end
		w:advance(1.5)
		local env = d.env
		ok(shown(env.WuberDriveButton) ~= nil, size[1] .. ": the big button shows")
		W.UI.CrewOffer("Vexember-Realm", "Vex's portals")
		w:advance(0.5)
		local card = shown(env.WuberCrewOffer)
		ok(card ~= nil, size[1] .. ": the crew offer shows")
		local btn, mini = shown(env.WuberDriveButton), shown(env.WuberDriveMini)
		if card and btn then
			ok(not hits(card, btn), ("%s: the card (%.0f,%.0f %.0fx%.0f) is over the big button (%.0f,%.0f %.0fx%.0f)")
				:format(size[1], card.l, card.b, card.w, card.h, btn.l, btn.b, btn.w, btn.h))
		end
		if card and mini then
			ok(not hits(card, mini), size[1] .. ": the card is over the console")
		end
		if card then
			ok(card.l >= -0.5 and card.b >= -0.5 and card.l + card.w <= sw + 0.5 and card.b + card.h <= sh + 0.5,
				size[1] .. ": the card stays on the screen")
		end
		T.clean(w)
	end)
end

-- the big button and its console show after the card did (the card was put where they were not yet)
for _, size in ipairs({ SIZES[4], SIZES[6] }) do
	test("UI crew offer 102: " .. size[1] .. ": the big button shows after the card: the card moves off it", function()
		local w, d, W = setup(size)
		local env = d.env
		if W.UI.IsShown() then W.UI.Toggle(false) end
		w:advance(1.5)
		local btn, mini = env.WuberDriveButton, env.WuberDriveMini
		ok(btn ~= nil and btn:IsVisible(), size[1] .. ": the big button shows")
		btn:Hide()
		if mini then mini:Hide() end
		W.UI.CrewOffer("Vexember-Realm", "Vex's portals")
		w:advance(0.5)
		btn:Show()
		if mini then mini:Show() end
		w:advance(1.5)
		local card, b, m = shown(env.WuberCrewOffer), shown(btn), shown(mini)
		ok(card ~= nil, size[1] .. ": the crew offer shows")
		if card and b then ok(not hits(card, b), size[1] .. ": the card is over the big button") end
		if card and m then ok(not hits(card, m), size[1] .. ": the card is over the console") end
		T.clean(w)
	end)
end

-- the mouse is over the card (about to click Yes or No) when the big button shows: the card stays put
-- until the mouse has left, then moves clear on the next look
test("UI crew offer 102: the card does not move from under the mouse", function()
	local w, d, W = setup(SIZES[4])
	local env = d.env
	if W.UI.IsShown() then W.UI.Toggle(false) end
	w:advance(1.5)
	local btn, mini = env.WuberDriveButton, env.WuberDriveMini
	btn:Hide()
	if mini then mini:Hide() end
	W.UI.CrewOffer("Vexember-Realm", "Vex's portals")
	w:advance(0.5)
	local before = shown(env.WuberCrewOffer)
	ok(before ~= nil, "the crew offer shows")
	d.mouseOver = env.WuberCrewOffer.yes
	btn:Show()
	if mini then mini:Show() end
	w:advance(1.5)
	local held = shown(env.WuberCrewOffer)
	ok(held and before and held.l == before.l and held.b == before.b, "the card stays where it is while the mouse is over it")
	d.mouseOver = nil
	w:advance(1)
	local after, b = shown(env.WuberCrewOffer), shown(btn)
	ok(after and b and not hits(after, b), "the card moves clear of the big button once the mouse has left")
	T.clean(w)
end)
