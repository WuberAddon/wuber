local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

-- Round 31, group B: the floating big Drive button and its console on a small game window at size 2.2.
-- HUNT-92: no clear place beside the opened-out phone: the console was drawn over the middle of the phone.
-- HUNT-94: a raid-sized list on a 1920x1080 screen: the console's last line hung off the bottom.
-- HUNT-07: the button floated over the Earnings screen's Me | Crew switch, so a tap on Crew pressed it.

local SQUARE = { 1331, 1044.5, 2662, 2089 } -- 2662x2089 at UI scale 0.7353
local WIDE = { 1365, 768, 1920, 1080 }     -- 1920x1080 at UI scale 1

local function rectK(env, f)
	if not (f and f:IsVisible()) then return nil end
	local k = f:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	return { l = f:GetLeft() * k, r = f:GetRight() * k, b = f:GetBottom() * k, t = f:GetTop() * k }
end
local function meets(a, c) return a and c and a.l < c.r and a.r > c.l and a.b < c.t and a.t > c.b end
local function fmt(r) return r and ("%.0f..%.0f x %.0f..%.0f"):format(r.l, r.r, r.b, r.t) or "hidden" end

local function sizedDriver(size)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = size[1], size[2]
	d.physW, d.physH = size[3], size[4]
	d.wide = true
	d:fire("DISPLAY_SIZE_CHANGED")
	W.db.scale = 2.2
	W.Drive.SetScale(2.2)
	if W.UI.ApplyScale then W.UI.ApplyScale() end
	return w, d, W
end

-- the handset round the window (bezel, status bar, home strip), in UIParent units
local function phoneBox(env, W)
	local win = env.WuberFrame
	local k = win:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local P = W.UI.PHONE
	return { l = (win:GetLeft() - P.bezel) * k, r = (win:GetRight() + P.bezel) * k,
		b = (win:GetBottom() - P.bezel - P.home) * k, t = (win:GetTop() + P.bezel + P.status) * k }
end

local function openOn(w, W, screen)
	W.Driver.SetOnline(true)
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(0.5)
	W.Driver.ShowScreen(screen)
	w:advance(3)
end

test("r31 b console: no clear place beside the opened-out phone, the console never covers the phone", function()
	for _, screen in ipairs({ "customers", "earnings" }) do
		local w, d, W = sizedDriver(SQUARE)
		local env = d.env
		openOn(w, W, screen)
		ok(W.UI.Fold.IsUnfolded(), screen .. ": control: the page opens out")
		ok(W.Drive.Button.Floating(), screen .. ": control: the button floats")
		local ph = phoneBox(env, W)
		local mini = rectK(env, env.WuberDriveMini)
		ok(not meets(mini, ph), screen .. ": the console (" .. fmt(mini) .. ") is not over the phone (" .. fmt(ph) .. ")")
		T.clean(w)
	end
end)

local NAMES = { "Alder Oak", "Birch Bark", "Cedar Pine", "Dune Sand", "Elm Root", "Fern Leaf", "Gorse Bush", "Hazel Nut", "Ivy Vine" }

local function withRiders(w, d, W)
	W.Driver.SetOnline(true)
	for _, n in ipairs(NAMES) do w:addBot(n, { spot = "Undercity", acceptsInvites = false }) end
	w:advance(5)
	for _, n in ipairs(NAMES) do
		w:botWhisper(n, d, "summon pls")
		w:advance(0.5)
	end
	w:advance(4)
	local list = W.Drive.Sorted()
	return type(list) == "table" and #list or 0
end

local function shownRows(m)
	local n = 0
	for _, r in ipairs(m.rows or {}) do if r:IsShown() then n = n + 1 end end
	return n
end

test("r31 b console: a long list on a 1920x1080 screen at size 2.2: the whole console is on the screen, fewer rows", function()
	local w, d, W = sizedDriver(WIDE)
	local env = d.env
	local n = withRiders(w, d, W)
	ok(n >= 5, "control: a long list (" .. n .. " riders)")
	ok(W.Drive.Button.Floating() and not W.Drive.Button.Solo(), "control: the button floats with its console")
	local b, m = rectK(env, env.WuberDriveButton), rectK(env, env.WuberDriveMini)
	ok(b and b.t <= WIDE[2] + 0.5 and b.b >= -0.5, "the button is on the screen (" .. fmt(b) .. ")")
	ok(m and m.b >= -0.5 and m.t <= WIDE[2] + 0.5, "the console is on the screen (" .. fmt(m) .. ")")
	local mini = env.WuberDriveMini
	local rows = shownRows(mini)
	ok(rows >= 1, "it still shows riders (" .. rows .. ")")
	ok(mini.more:IsShown(), "the more line shows")
	eq(mini.more:GetText(), "+" .. (n - rows) .. " more in Wuber's Drive tab", "it counts the riders left out")
	T.clean(w)
	-- a taller screen: all four rows
	w, d, W = sizedDriver({ 1365, 1365, 1920, 1920 })
	env = d.env
	n = withRiders(w, d, W)
	mini = env.WuberDriveMini
	ok(mini and mini:IsVisible(), "tall screen: the console shows")
	eq(shownRows(mini), 4, "tall screen: four rows")
	eq(mini.more:GetText(), "+" .. (n - 4) .. " more in Wuber's Drive tab", "tall screen: the rest in the Drive tab")
	T.clean(w)
end)

test("r31 b console: little room beside the opened-out phone: a shorter console there before the button goes alone", function()
	local w, d, W = sizedDriver({ 1365, 1200, 1920, 1688 })
	W.db.scale = 1.15
	W.Drive.SetScale(1.5)
	if W.UI.ApplyScale then W.UI.ApplyScale() end
	W.db.pos = { "TOPLEFT", "TOPLEFT", 40, -40 }
	local env = d.env
	local n = withRiders(w, d, W)
	openOn(w, W, "customers")
	ok(n >= 5, "control: a long list (" .. n .. " riders)")
	ok(W.UI.Fold.IsUnfolded(), "control: the page opens out")
	local ph = phoneBox(env, W)
	ok(not W.Drive.Button.Solo(), "the button keeps its console")
	local b, m = rectK(env, env.WuberDriveButton), rectK(env, env.WuberDriveMini)
	ok(b and not meets(b, ph), "the button (" .. fmt(b) .. ") is off the phone (" .. fmt(ph) .. ")")
	ok(m and not meets(m, ph), "its console (" .. fmt(m) .. ") is off the phone")
	ok(m and m.b >= -0.5, "and on the screen")
	local mini = env.WuberDriveMini
	local rows = shownRows(mini)
	ok(rows >= 1 and rows < 4, "fewer rows (" .. rows .. ")")
	eq(mini.more:GetText(), "+" .. (n - rows) .. " more in Wuber's Drive tab", "it counts the riders left out")
	-- the window shut: four rows again
	W.UI.Toggle(false)
	w:advance(3)
	eq(shownRows(mini), 4, "window shut: four rows")
	T.clean(w)
end)

-- (HUNT-07) the Earnings screen's Me | Crew switch, wherever the floating button was left
local POSITIONS = { false, { "CENTER", "CENTER", 0, 0 }, { "CENTER", "CENTER", 0, 150 }, { "TOPLEFT", "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 } }

test("r31 b console: on Earnings the floating button never covers the Me | Crew switch", function()
	for i, pos in ipairs(POSITIONS) do
		local w, d, W = sizedDriver(SQUARE)
		local env = d.env
		if pos then
			W.db.drive = W.db.drive or {}
			W.db.drive.button = W.db.drive.button or {}
			W.db.drive.button.pos = pos
		end
		openOn(w, W, "earnings")
		local s = W.Mod("UI.Driver.Screens").st.screens.earnings
		ok(s and s.who, "control: the Me | Crew switch")
		-- the switch shows only with crew mates; its place is what counts here
		s.who:Show()
		local tag = "place " .. i .. ": "
		local b = rectK(env, env.WuberDriveButton)
		-- (round 244) where the button alone sits is no longer fixed to a screen corner: it goes where it covers no clickable control
		-- of the phone (tests/r244/r244_hunt07_test.lua); what this test keeps is that it is not over the Me | Crew switch
		ok(not (env.WuberDriveMini and env.WuberDriveMini:IsVisible()), tag .. "its console waits")
		for j, sb in ipairs(s.who.buttons or {}) do
			local r = rectK(env, sb)
			ok(r, tag .. "control: the switch's button " .. j)
			ok(not meets(b, r), tag .. "the button (" .. fmt(b) .. ") is not over " .. (j == 1 and "Me" or "Crew") .. " (" .. fmt(r) .. ")")
		end
		T.clean(w)
	end
end)
