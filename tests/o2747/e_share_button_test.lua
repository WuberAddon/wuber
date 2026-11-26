-- o2747 group E (#16): WuberShareButton must lie fully inside Wuber's window and on the screen.
-- The secure share overlay docks over the shift card's "Post to party" pill (UI.Secure, UI.Driver.Sheets).
-- Promise: whenever WuberShareButton is shown, its rect is inside the window's rect and inside the screen,
-- for every row count of the split, phone and wide sizes, with and without advanced numbers.
-- It has no job (and so is not shown) when the pill is not visible: no group, or no cut to share.
local T = ...
local test, ok = T.test, T.ok

local function rectOf(env, f)
	local k = f:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	return { l = f:GetLeft() * k, r = f:GetRight() * k, b = f:GetBottom() * k, t = f:GetTop() * k }
end

local function shiftCard(wide, nrows, adv)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(wide == true) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local names = { T.ANITA }
	local rows = { { key = W.myKey, name = T.ANITA, casts = 3, clicks = 0, share = 18000 } }
	for i = 1, nrows - 1 do
		local n = ({ "Vexone", "Vextwo", "Vexthree", "Vexfour", "Vexfive", "Vexsix", "Vexseven", "Vexeight" })[i]
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
		rows[#rows + 1] = { key = n:lower(), name = n, casts = 0, clicks = i, share = 1000 * i }
	end
	w:group(names)
	w:advance(1)
	if W.Settings and W.Settings.Set then pcall(W.Settings.Set, "advanced", adv == true) end
	W.Driver.lastShift = { rides = 5, copper = 20000, tips = 100, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = rows, rule = "clicks", pct = 40 } }
	return w, a, W
end

-- guard: the settled card (every row count, phone and wide) already keeps the overlay inside the window on the base; this is the sweep the moving card below is judged against
test("o2747 #16: WuberShareButton lies inside the window and on the screen (1..8 split rows, phone and wide, plain and advanced)", function()
	local seen = 0
	for _, wide in ipairs({ false, true }) do
		for _, adv in ipairs({ false, true }) do
			for n = 1, 8 do
				local w, a, W = shiftCard(wide, n, adv)
				local env = a.env
				W.Driver.ShowSheet("shift")
				for _ = 1, 8 do w:advance(0.1) end
				W.UI.SyncSecure()
				local b = env.WuberShareButton
				local where = ("%s, %s, %d rows"):format(wide and "wide" or "phone", adv and "advanced" or "plain", n)
				if b:IsShown() then
					seen = seen + 1
					local br, wr = rectOf(env, b), rectOf(env, env.WuberFrame)
					local sw, sh = env.UIParent:GetWidth(), env.UIParent:GetHeight()
					ok(br.b >= -0.5 and br.l >= -0.5 and br.r <= sw + 0.5 and br.t <= sh + 0.5,
						("%s: overlay %.0f,%.0f-%.0f,%.0f is off the screen %.0fx%.0f"):format(where, br.l, br.b, br.r, br.t, sw, sh))
					ok(br.l >= wr.l - 0.5 and br.r <= wr.r + 0.5 and br.b >= wr.b - 0.5 and br.t <= wr.t + 0.5,
						("%s: overlay %.0f,%.0f-%.0f,%.0f is outside the window %.0f,%.0f-%.0f,%.0f"):format(where, br.l, br.b, br.r, br.t, wr.l, wr.b, wr.r, wr.t))
				end
			end
		end
	end
	ok(seen > 0, "control: the overlay was shown in at least one state")
end)

-- promise test, not a guard (fails on the base: the overlay rode the rising and dropping sheet below the window; the sheet drops 0.24 s on close, rises 0.32 s on open: the pill rides with it, under the window's edge)
test("o2747 #16: WuberShareButton stays inside the window while the shift card rises and drops (steps 0.02 s, 0.1 s, 1 s and 5 s, phone and wide)", function()
	local seen = 0
	for _, wide in ipairs({ false, true }) do
		for _, step in ipairs({ 0.02, 0.1, 1, 5 }) do
			local w, a, W = shiftCard(wide, 2, false)
			local env = a.env
			local where = ("%s, step %.2f"):format(wide and "wide" or "phone", step)
			local function look(phase)
				W.UI.SyncSecure()
				local b = env.WuberShareButton
				if not b:IsShown() then return end
				seen = seen + 1
				local br, wr = rectOf(env, b), rectOf(env, env.WuberFrame)
				ok(br.l >= wr.l - 0.5 and br.r <= wr.r + 0.5 and br.b >= wr.b - 0.5 and br.t <= wr.t + 0.5 and br.b >= -0.5,
					("%s, %s: overlay %.0f,%.0f-%.0f,%.0f is outside the window %.0f,%.0f-%.0f,%.0f"):format(where, phase, br.l, br.b, br.r, br.t, wr.l, wr.b, wr.r, wr.t))
			end
			W.Driver.ShowSheet("shift")
			for _ = 1, math.max(1, math.ceil(0.7 / step)) do w:advance(step) look("rising") end
			local sh = W.UI.drive.screens.shift
			ok(env.WuberShareButton:IsShown(), "control: the overlay is up over the settled card (" .. where .. ")")
			sh.frame:Close()
			look("closing at once")
			for _ = 1, math.max(1, math.ceil(0.5 / step)) do w:advance(step) look("dropping") end
		end
	end
	ok(seen > 0, "control: the overlay was seen")
end)

-- guard: on main the overlay already docks at once (it docks over the pill wherever the pill is), so this passes there; it pins that the new hook alone docks it after the rise (it fails with the OnUpdate hook removed). The docking itself: nothing but the sheet's own movement may dock the overlay once the card has risen; no SyncSecure call by the test)
test("o2747 #16: the overlay docks over the pill within 0.1 s of the rise ending, by itself, and goes within a frame when Nice closes the card", function()
	for _, step in ipairs({ 0.02, 0.05 }) do
		local w, a, W = shiftCard(false, 2, false)
		local env = a.env
		W.Driver.ShowSheet("shift")
		local s = W.UI.drive.screens.shift
		local b = env.WuberShareButton
		local t = 0
		while t < 0.32 + 0.1 - 1e-6 do w:advance(step) t = t + step end
		local where = "step " .. step
		ok(s.split.post:IsShown(), "control: the pill shows (" .. where .. ")")
		ok(b:IsShown(), where .. ": the overlay is docked within 0.1 s of the rise ending, without a SyncSecure call")
		local br, pr = rectOf(env, b), rectOf(env, s.split.post)
		ok(math.abs(br.l - pr.l) < 1 and math.abs(br.b - pr.b) < 1, where .. ": the overlay lies over the pill")
		local click = s.done:GetScript("OnClick")
		click(s.done)
		ok(not b:IsShown(), where .. ": the overlay is gone the moment Nice closes the card")
		w:advance(step)
		ok(not b:IsShown(), where .. ": and stays gone a frame later")
	end
end)
