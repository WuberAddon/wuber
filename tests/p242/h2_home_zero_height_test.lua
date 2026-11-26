-- p242 group H, follow-up G1 (Google review of H24-14): the empty Home's room rule must never count the title or the
-- line as shorter than one line. A label whose font has not loaded yet reports a height of 0 (GetStringHeight), and
-- 0 is a number, so "or 17" never applied: the stack looked shorter than it draws, the round icon stayed and the
-- OpenMap line was let in, so the stack ran into the 12 above Ping drivers. Swept: the first refresh with both
-- heights 0 (no bounty, the OpenMap line wanting room), the same with your bounty's row up, and the refresh after the
-- font loads (the real heights again).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local STACK = { "disc", "title", "sub", "watch", "bountyGo", "why", "mapHint" }

local function setup(pin)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080, saved = { Wuber = { coach = true } } })
	w:advance(15)
	local W, UI = c.W, c.W.UI
	UI.Toggle(true)
	w:advance(3)
	W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Fold.Apply()
	w:advance(2)
	UI.Show("home")
	w:advance(2)
	if pin then
		UI.SetSearch(pin)
		w:advance(1)
		ok(UI.PinBounty(pin, 5000), "the bounty for " .. pin .. " is pinned")
		UI.SetSearch("")
		w:advance(1)
	end
	return w, c, W, UI
end

local function rect(f)
	local l, b, wd, ht = f:GetRect()
	return { b = b or 0, t = (b or 0) + (ht or 0) }
end

local function stackClear(c, label)
	local e = c.W.UI.state.screens.home.empty
	ok(H.visible(e.ping), label .. ": Ping drivers shows")
	local p = rect(e.ping)
	local seen = 0
	for _, k in ipairs(STACK) do
		local f = e[k]
		if f and f:IsVisible() then
			seen = seen + 1
			local r = rect(f)
			ok(r.b >= p.t + 12 - 0.5, ("%s: %s ends %.1f above Ping drivers (12 wanted)"):format(label, k, r.b - p.t))
		end
	end
	ok(seen >= 3, label .. ": the title, the line and Why? are there")
end

-- the title and the line report 0 (font not loaded) on one refresh; returns a function that brings the real heights back
local function zeroHeights(e)
	local t0, s0 = e.title.GetStringHeight, e.sub.GetStringHeight
	e.title.GetStringHeight = function() return 0 end
	e.sub.GetStringHeight = function() return 0 end
	return function()
		e.title.GetStringHeight, e.sub.GetStringHeight = t0, s0
	end
end

test("p242 H2: G1: a title and line reporting height 0 (font not loaded) still leave the stack above Ping drivers", function()
	local w, c, W, UI = setup(nil)
	local e = UI.state.screens.home.empty
	local back = zeroHeights(e)
	UI.Refresh(true)
	w:advance(0.1) -- (a refresh runs on the next frame)
	stackClear(c, "heights 0")
	eq(e.title:GetText(), "No drivers online", "the title reads the same")
	back()
	UI.Refresh(true)
	w:advance(1)
	stackClear(c, "font loaded")
	T.clean(w)
end)

-- the same with your bounty's row up (152 of the list's 238): the OpenMap line was let in on the short room too
test("p242 H2: G1: heights 0 with your bounty's row up: the stack still ends above Ping drivers", function()
	local w, c, W, UI = setup("Ironforge")
	local e = UI.state.screens.home.empty
	local back = zeroHeights(e)
	UI.Refresh(true)
	w:advance(0.1) -- (a refresh runs on the next frame)
	stackClear(c, "bounty, heights 0")
	back()
	UI.Refresh(true)
	w:advance(1)
	stackClear(c, "bounty, font loaded")
	T.clean(w)
end)
