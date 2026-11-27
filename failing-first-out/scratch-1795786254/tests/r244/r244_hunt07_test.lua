local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

-- Round 244, HUNT-07: on a small game window with the phone opened out, the floating big Drive button must never lie over a
-- clickable control of the phone (the Earnings screen's Me | Crew switch, the tab bar, the back arrows). Round 31 made it prefer the
-- screen corner that covers the least phone AREA; that corner can still cover the edge of the phone's tabs.

-- game window sizes (UIParent w, h, physical w, h) at the UI scales the maintainer plays at
local SIZES = {
	{ "1331x749 @2.2", { 1331, 749, 1331, 749 } },
	{ "1024x768 @2.2", { 1024, 768, 1024, 768 } },
	{ "1331x749 @0.71", { 1331, 749, 1331, 749 } },
	{ "1024x768 @0.71", { 1024, 768, 1024, 768 } },
	{ "square 2662x2089", { 1331, 1044.5, 2662, 2089 } },
}
local UISCALE = { 2.2, 2.2, 0.71, 0.71, 2.2 } -- the big button's size (db.scale), as the card names it
local SCREENS = { "earnings", "customers", "crew", "messages" }

local function sized(size, sc)
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
	W.db.scale = sc
	W.Drive.SetScale(sc)
	if W.UI.ApplyScale then W.UI.ApplyScale() end
	return w, d, W
end

local function rectK(env, f)
	if not (f and f:IsVisible()) then return nil end
	local k = f:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	return { l = f:GetLeft() * k, r = f:GetRight() * k, b = f:GetBottom() * k, t = f:GetTop() * k }
end
local function meets(a, c) return a and c and a.l < c.r and a.r > c.l and a.b < c.t and a.t > c.b end
local function fmt(r) return r and ("%.0f..%.0f x %.0f..%.0f"):format(r.l, r.r, r.b, r.t) or "hidden" end

-- every visible, mouse-taking Button / CheckButton under the phone's window
local function controls(env)
	local out = {}
	local function walk(f)
		local s = H.state[f]
		if not s then return end
		if (s.otype == "Button" or s.otype == "CheckButton") and f:IsVisible() and f:IsMouseEnabled() == true
			and (f:GetEffectiveAlpha() or 0) > 0.05 then
			local r = rectK(env, f)
			if r and r.r - r.l > 1 and r.t - r.b > 1 then out[#out + 1] = { f = f, r = r, name = s.name or tostring(f) } end
		end
		for _, c in ipairs(s.children or {}) do walk(c) end
	end
	walk(env.WuberFrame)
	return out
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

-- the controls' area under a box (l, b, w, h)
local function hitArea(ctl, px, py, bw, bh)
	local sum = 0
	for _, c in ipairs(ctl) do
		local w = math.min(px + bw, c.r.r) - math.max(px, c.r.l)
		local h = math.min(py + bh, c.r.t) - math.max(py, c.r.b)
		if w > 0 and h > 0 then sum = sum + w * h end
	end
	return sum
end

-- the least control area any place on the screen gives a box this size (the oracle: a grid at 6 units)
local function bestPossible(ctl, sw, sh, bw, bh)
	local best = math.huge
	for px = 0, math.max(0, sw - bw), 6 do
		for py = 0, math.max(0, sh - bh), 6 do
			local a = hitArea(ctl, px, py, bw, bh)
			if a < best then best = a end
		end
	end
	return best
end

local LOG = {}
local function checkOne(label, size, sc, screen)
	local w, d, W = sized(size, sc)
	local env = d.env
	openOn(w, W, screen)
	if not (W.UI.Fold.IsUnfolded() and W.Drive.Button.Floating()) then T.clean(w) return 0 end -- not the case under test
	if screen == "earnings" then
		local s = W.Mod("UI.Driver.Screens").st.screens.earnings
		if s and s.who then s.who:Show() end -- the switch shows only with crew mates
	end
	local b = rectK(env, env.WuberDriveButton)
	local ctl = controls(env)
	local own = {}
	for _, c in ipairs(ctl) do
		if c.f ~= env.WuberDriveButton and not (env.WuberDriveMini and c.f == env.WuberDriveMini) then own[#own + 1] = c end
	end
	local got = hitArea(own, b.l, b.b, b.r - b.l, b.t - b.b)
	local best = bestPossible(own, size[1], size[2], b.r - b.l, b.t - b.b)
	LOG[#LOG + 1] = ("%s %s: button %s covers %.0f of control area, best place anywhere %.0f"):format(label, screen, fmt(b), got, best)
	ok(got <= best + 0.5, label .. " " .. screen .. ": the big button (" .. fmt(b) .. ") covers " .. ("%.0f"):format(got)
		.. " of the phone's clickable control area; a place with " .. ("%.0f"):format(best) .. " exists")
	if best <= 0.5 then
		for _, c in ipairs(own) do
			ok(not meets(b, c.r), label .. " " .. screen .. ": the big button (" .. fmt(b) .. ") is not over " .. c.name .. " (" .. fmt(c.r) .. ")")
		end
	end
	local mini = env.WuberDriveMini and rectK(env, env.WuberDriveMini)
	if mini and env.WuberDriveMini:IsVisible() then
		for _, c in ipairs(own) do
			ok(not meets(mini, c.r), label .. " " .. screen .. ": the console is not over " .. c.name)
		end
	end
	T.clean(w)
	return #own
end

test("r244 hunt07: the floating big button never lies over a clickable control of the opened-out phone", function()
	local total = 0
	for i, sz in ipairs(SIZES) do
		for _, screen in ipairs(SCREENS) do
			total = total + checkOne(sz[1], sz[2], UISCALE[i], screen)
		end
	end
	ok(total > 0, "control: some phone controls were checked (" .. total .. ")")
	if os.getenv("HUNT07_LOG") then print(table.concat(LOG, "\n")) end
end)
