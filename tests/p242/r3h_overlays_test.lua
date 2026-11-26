-- prep-242 round 3, group H: two placement faults of Wuber's top-level secure frames (the hunt's universal.layout).
-- (1) The secure share overlay (WuberShareButton, UI.Secure) docked over the shift card's "Post to party" pill
--     while the card's sheet was still rising and stayed there (off the screen's foot) until the next 1 s refresh.
--     Promise: once the pill holds still the overlay lies exactly over it, at any step size, folded and unfolded.
-- (2) The floating big button (WuberDriveButton, Drive.Button) that has no clear place beside the opened-out phone
--     goes above the window, but the report sheet (WuberBug, a FULLSCREEN_DIALOG layer of the window at 400) lay
--     over its foot. Promise: a floating button that lies over the window lies over every layer of it.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

local function rectOf(env, f)
	local k = f:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	return { l = f:GetLeft() * k, r = f:GetRight() * k, b = f:GetBottom() * k, t = f:GetTop() * k }
end

local function near(a, b) return math.abs(a - b) < 0.6 end

local function shiftCard(wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(wide == true) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	w:addBot("Vex Shade", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Vex Shade" })
	w:advance(1)
	W.Driver.lastShift = { rides = 5, copper = 20000, tips = 0, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = {
			{ key = W.myKey, name = T.ANITA, casts = 3, clicks = 0, share = 18000 },
			{ key = "vex shade", name = "Vex Shade", casts = 0, clicks = 2, share = 12000 },
		}, rule = "clicks", pct = 40 } }
	return w, a, W
end

-- guard: none (fails on base 44d6e2c6: the overlay stays where the rising sheet first put the pill)
test("r3h: the share overlay lies over the shift card's Post to party pill once the card has risen (steps 0.05/0.1/1 s, folded and unfolded)", function()
	for _, wide in ipairs({ false, true }) do
		for _, step in ipairs({ 0.05, 0.1, 1 }) do
			local w, a, W = shiftCard(wide)
			local env = a.env
			ok(W.Driver.ShowSheet("shift"), "the card opens")
			-- the first look while the sheet is rising (the refresh does this in the game)
			w:advance(0.02)
			W.UI.SyncSecure()
			local t = 0
			while t < 0.7 - 1e-6 do w:advance(step) t = t + step end
			local s = W.UI.drive.screens.shift
			local p = s.split and s.split.post
			local b = env.WuberShareButton
			local where = (wide and "unfolded" or "folded") .. ", step " .. step
			ok(p and p:IsVisible(), "control: the pill shows in a group (" .. where .. ")")
			ok(b:IsShown(), "control: the overlay is up (" .. where .. ")")
			local pr, br = rectOf(env, p), rectOf(env, b)
			ok(near(pr.l, br.l) and near(pr.b, br.b) and near(pr.r, br.r) and near(pr.t, br.t),
				("%s: overlay %.0f,%.0f-%.0f,%.0f is not over its pill %.0f,%.0f-%.0f,%.0f"):format(where, br.l, br.b, br.r, br.t, pr.l, pr.b, pr.r, pr.t))
			ok(br.b >= -1, where .. ": the overlay is on the screen (bottom " .. br.b .. ")")
			T.clean(w)
		end
	end
end)

-- The same overlay reached the other way: a card opened at once in combat, then combat ends. Secure frames are not
-- moved in combat, so it docks over the pill only after.
-- guard: the neighbouring path (the card opened in combat) docked right on the base too
test("r3h guard: in combat the share overlay stays hidden; after combat it docks over the pill", function()
	local w, a, W = shiftCard(false)
	local env = a.env
	w:enterCombat(a)
	w:advance(1)
	ok(W.Driver.ShowSheet("shift"), "the card opens in combat")
	w:advance(1)
	ok(not env.WuberShareButton:IsShown(), "hidden in combat")
	w:leaveCombat(a)
	w:advance(1.2)
	local p = W.UI.drive.screens.shift.split.post
	local b = env.WuberShareButton
	ok(b:IsShown(), "up after combat")
	local pr, br = rectOf(env, p), rectOf(env, b)
	ok(near(pr.l, br.l) and near(pr.b, br.b), "over its pill after combat")
	T.clean(w)
end)

local SQUARE = { 1331, 1044, 2662, 2089 }

local function squareDriver()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = SQUARE[1], SQUARE[2]
	d.physW, d.physH = SQUARE[3], SQUARE[4]
	d.wide = true
	d:fire("DISPLAY_SIZE_CHANGED")
	return w, d, W
end

local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function z(f) return (RANK[f:GetFrameStrata()] or 0) * 100000 + (f:GetFrameLevel() or 0) end

-- every shown frame of the window that the button's box meets and that lies above the button
local function above(env, root, b)
	local br = rectOf(env, b)
	local out = {}
	local function walk(f)
		if not f:IsVisible() then return end
		local fr = rectOf(env, f)
		if fr.l < br.r - 1 and fr.r > br.l + 1 and fr.b < br.t - 1 and fr.t > br.b + 1 and z(f) > z(b) then
			out[#out + 1] = tostring(f) .. " " .. f:GetFrameStrata() .. " " .. f:GetFrameLevel()
		end
		for _, c in ipairs({ f:GetChildren() }) do walk(c) end
	end
	walk(root)
	return out
end

-- guard: none (fails on base 44d6e2c6: WuberBug at FULLSCREEN_DIALOG 400 over the button at 101)
test("r3h: the floating big button over the opened-out phone lies over the report sheet too (window at each corner)", function()
	for _, pos in ipairs({ { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 20 }, { "TOPLEFT", "TOPLEFT", 20, -20 }, { "BOTTOMLEFT", "BOTTOMLEFT", 20, 20 } }) do
		local w, d, W = squareDriver()
		local DR, env = W.Drive, d.env
		local b = env.WuberDriveButton
		DR.Button.KeepClosed(true)
		W.Driver.SetOnline(false)
		DR.SetScale(1.5)
		W.db.scale, W.db.scaleV = 1.5, 2 -- Wuber's size 1.5 (the layout check's square window at 1.5)
		W.db.pos = pos
		W.UI.Toggle(true)
		w:advance(2)
		if W.UI.WindowWide then W.UI.WindowWide(true) end
		w:advance(2)
		W.UI.Bug.Open()
		w:advance(2)
		ok(W.UI.Bug.Shown(), "control: the report shows")
		ok(b:IsShown() and DR.Button.Floating(), "control: the button floats")
		local wr, br = rectOf(env, env.WuberFrame), rectOf(env, b)
		local meets = br.l < wr.r and br.r > wr.l and br.b < wr.t and br.t > wr.b
		if meets then
			local hi = above(env, env.WuberFrame, b)
			eq(#hi, 0, pos[1] .. ": layers of the window over the button:\n  " .. table.concat(hi, "\n  "))
		end
		T.clean(w)
	end
end)

-- guard: the docked button (in the Drive tab's slot) stays under a sheet over the page: the report covers it whole
test("r3h guard: the docked big button keeps its level under the window's sheets", function()
	local w, d, W = squareDriver()
	local env = d.env
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	local b = env.WuberDriveButton
	if W.Drive.Button.Docked() then
		ok(b:GetFrameLevel() < 400, "docked level " .. b:GetFrameLevel() .. " stays under the sheet holders")
	end
	T.clean(w)
end)
