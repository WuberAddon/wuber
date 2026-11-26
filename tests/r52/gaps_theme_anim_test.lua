-- Final home: tests/theme/anim_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the motion tokens; Reduce motion read from the saved setting at every call;
--   T.Glide: 0 s ends at once, apply(0) first and apply(1) last, onDone once, a new glide replaces the old one
--   (its onDone never runs), GlideStop drops or finishes; nil input does nothing;
--   the guarded helpers take nil, FadeOut of a hidden frame calls onDone at once, Tap makes nothing;
--   pages: in combat with a secure page they swap at once; with Reduce motion the old page hides at once and the new
--   one fades in; PopPage without an old page hides; a second Push in the same clip ends the first move first;
--   a Push ends with the pages back in their own places.
-- Why it matters to a player: a page that never finishes sliding, a page left half-hidden, or a tween that touches a
--   secure button in combat leaves the Wuber window stuck, see-through or blocked by the game.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- a client, its theme and a clip frame with two pages in it (the second page is the old one)
local function stage()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w, 5)
	local env, Th = r.env, r.W.Theme
	local clip = env.CreateFrame("Frame", nil, env.UIParent)
	clip:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	clip:SetSize(300, 400)
	local function page()
		local p = env.CreateFrame("Frame", nil, clip)
		p:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
		p:SetSize(300, 400)
		return p
	end
	local new, old = page(), page()
	new:Hide()
	old:Show()
	return w, r, Th, clip, new, old
end

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: contract (registered, deps = Theme.Tokens, header, public names); the motion tokens", function()
	local W, w, r, Mod = T.contract("Theme.Anim", "tests/theme/anim_test.lua", {
		["T.Animate"] = "table", ["T.HasText"] = "function", ["T.Tween"] = "function", ["T.MOTION"] = "table",
		["T.ReduceMotion"] = "function", ["T.Glide"] = "function", ["T.GlideStop"] = "function",
		["T.Animate.Stop"] = "function", ["T.Animate.FadeIn"] = "function", ["T.Animate.FadeOut"] = "function",
		["T.Animate.Move"] = "function", ["T.Animate.SlideUp"] = "function", ["T.Animate.SlideIn"] = "function",
		["T.Animate.SlideOut"] = "function", ["T.Animate.Pop"] = "function", ["T.Animate.ZoomIn"] = "function",
		["T.Animate.ZoomOut"] = "function", ["T.Animate.Tap"] = "function", ["T.Animate.Pulse"] = "function",
		["T.Animate.Spin"] = "function", ["T.Animate.Stagger"] = "function", ["T.Animate.Push"] = "function",
		["T.Animate.PopPage"] = "function", ["T.Animate.StopPage"] = "function",
	})
	ok(Mod, "W.Mod(\"Theme.Anim\")")
	local M = W.Theme.MOTION
	eq(M.page, 0.28, "page") eq(M.sheetUp, 0.32, "sheetUp") eq(M.sheetDown, 0.24, "sheetDown") eq(M.dim, 0.2, "dim")
	eq(M.fade, 0.16, "fade") eq(M.reduced, 0.12, "reduced") eq(M.pill, 0.45, "pill")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: Reduce motion is read from the saved setting at every call (true only for true)", function()
	local w, r, Th = stage()
	local W = r.W
	W.db.reduceMotion = true
	eq(Th.ReduceMotion(), true, "on")
	W.db.reduceMotion = "yes"
	eq(Th.ReduceMotion(), false, "only true is on")
	W.db.reduceMotion = nil
	eq(Th.ReduceMotion(), false, "off")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: T.Glide runs apply 0 -> 1 and onDone once; 0 s ends at once; nil input does nothing", function()
	local w, r, Th = stage()
	local ks, done = {}, 0
	local obj = {}
	Th.Glide(obj, 0.3, function(o, k) ks[#ks + 1] = k end, function(o) done = done + 1 end, "NONE")
	eq(ks[1], 0, "apply(0) first")
	w:advance(1)
	eq(ks[#ks], 1, "apply(1) last") -- Anim.lua glideEnd
	eq(done, 1, "onDone once")
	w:advance(1)
	eq(done, 1, "and never again")
	local now = {}
	Th.Glide({}, 0, function(o, k) now[#now + 1] = k end, function() now.done = true end)
	eq(now[1], 1, "0 s: apply(1) at once")
	eq(now.done, true, "0 s: onDone at once")
	Th.Glide(nil, 1, function() error("never") end)
	Th.Glide({}, 1, "not a function")
	w:advance(1.5)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: a new glide on the same object replaces the old (its onDone never runs); GlideStop drops or finishes", function()
	local w, r, Th = stage()
	local obj, log = {}, {}
	Th.Glide(obj, 1, function() end, function() log[#log + 1] = "first" end)
	w:advance(0.2)
	Th.Glide(obj, 0.3, function() end, function() log[#log + 1] = "second" end)
	w:advance(2)
	eq(table.concat(log, ","), "second", "only the newer glide finished")
	local last
	Th.Glide(obj, 5, function(_, k) last = k end, function() log[#log + 1] = "dropped" end)
	Th.GlideStop(obj)
	w:advance(6)
	eq(table.concat(log, ","), "second", "a dropped glide never finishes")
	Th.Glide(obj, 5, function(_, k) last = k end, function() log[#log + 1] = "finished" end)
	Th.GlideStop(obj, true)
	eq(last, 1, "finish = true applies 1")
	eq(table.concat(log, ","), "second,finished", "and calls onDone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: the helpers take nil; FadeOut of a hidden frame calls onDone at once; Tap makes nothing", function()
	local w, r, Th, clip, new, old = stage()
	local A = Th.Animate
	eq(A.FadeIn(nil), nil, "FadeIn(nil)")
	eq(A.FadeOut(nil), nil, "FadeOut(nil)")
	eq(A.Pop(nil), nil, "Pop(nil)")
	eq(A.ZoomIn(nil), nil, "ZoomIn(nil)")
	A.Stop(nil)
	A.Stop(new) -- (no animation yet: nothing to stop)
	eq(A.Tap(new), nil, "Tap makes no animation")
	eq(new.wuberAnims, nil, "no animation group was made")
	local got
	eq(A.FadeOut(new, 0.2, function(f) got = f end), nil, "nothing to fade")
	eq(got, new, "onDone at once with the frame")
	ok(not new:IsShown(), "still hidden")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: in combat a Push with a secure page swaps at once (no move) and says done", function()
	local w, r, Th, clip, new, old = stage()
	local calls = {}
	w:enterCombat(r)
	local moved = Th.Animate.Push(new, old, { secure = true, onDone = function(a, b) calls[#calls + 1] = { a, b } end })
	eq(moved, false, "no move in combat")
	ok(new:IsShown(), "the new page is shown at once")
	ok(not old:IsShown(), "the old page is hidden at once")
	eq(#calls, 1, "onDone once")
	eq(calls[1][1], new, "with the page that stays") eq(calls[1][2], old, "and the one that left")
	w:leaveCombat(r)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: with Reduce motion a Push hides the old page at once and fades the new one in over T.MOTION.reduced", function()
	local w, r, Th, clip, new, old = stage()
	r.W.db.reduceMotion = true
	local done = 0
	local moved = Th.Animate.Push(new, old, { onDone = function(a) if a == new then done = done + 1 end end })
	eq(moved, true, "it fades")
	ok(not old:IsShown(), "the old page went at once")
	ok(new:IsShown(), "the new page is shown")
	eq(new:GetAlpha(), 0, "from see-through")
	w:advance(0.5)
	eq(new:GetAlpha(), 1, "to whole")
	eq(done, 1, "onDone once")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: PopPage with no old page hides the page and says done (nil, page)", function()
	local w, r, Th, clip, new, old = stage()
	local a, b, n = "x", nil, 0
	eq(Th.Animate.PopPage(old, nil, { onDone = function(x, y) a, b, n = x, y, n + 1 end }), false, "no move")
	ok(not old:IsShown(), "hidden")
	eq(n, 1, "onDone once") eq(a, nil, "nothing stays") eq(b, old, "the page left")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: a Push ends with the old page hidden and both pages back in their own places", function()
	local w, r, Th, clip, new, old = stage()
	local _, _, _, x0, y0 = new:GetPoint(1)
	local done = 0
	eq(Th.Animate.Push(new, old, { onDone = function() done = done + 1 end }), true, "it moves")
	ok(new:IsShown(), "the new page is on its way")
	w:advance(1)
	eq(done, 1, "onDone once")
	ok(not old:IsShown(), "the old page is hidden at the end")
	local _, _, _, x1, y1 = new:GetPoint(1)
	eq(x1, x0, "the new page is in its place (x)") eq(y1, y0, "(y)")
	local _, _, _, ox, oy = old:GetPoint(1)
	eq(ox, x0, "the old page is back in its place under it (x)") eq(oy, y0, "(y)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("theme.anim: a second Push in the same clip ends the first move first; StopPage ends a move at once", function()
	local w, r, Th, clip, new, old = stage()
	local log = {}
	Th.Animate.Push(new, old, { onDone = function() log[#log + 1] = "first" end })
	Th.Animate.PopPage(new, old, { onDone = function() log[#log + 1] = "back" end })
	eq(table.concat(log, ","), "first", "the first move ended before the second began") -- Anim.lua pageEndFor
	Th.Animate.StopPage(clip)
	eq(table.concat(log, ","), "first,back", "StopPage ended the second at once")
	ok(old:IsShown(), "the old page is back")
	ok(not new:IsShown(), "the page that left is hidden")
	w:advance(1)
	eq(#log, 2, "nothing finished twice")
	T.clean(w)
end)
