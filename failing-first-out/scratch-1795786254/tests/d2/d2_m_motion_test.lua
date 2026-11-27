-- Design round 2, group M: the motion core. The default of Reduce motion, T.ReduceMotion, the motion tokens,
-- and pages that slide (A.Push, A.PopPage, A.StopPage): travel by SetPoint inside a frame that clips, a black
-- cover whose alpha is set by hand, no Scale and no Translation animation, at once in combat with a secure button.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function theme()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(2)
	return w, c, c.W.Theme, c.env
end

-- a clip frame 300 wide with pages that fill it; every page counts the calls that move, show or hide it
local function stage(env, n)
	local clip = env.CreateFrame("Frame", nil, env.UIParent)
	clip:SetSize(300, 400)
	clip:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	local pages = {}
	for i = 1, n or 2 do
		local p = env.CreateFrame("Frame", nil, clip)
		p:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
		p:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
		if i > 1 then p:Hide() end
		p.calls = { SetPoint = 0, ClearAllPoints = 0, Show = 0, Hide = 0, SetAlpha = 0 }
		for name in pairs(p.calls) do
			local real = p[name]
			p[name] = function(self, ...)
				self.calls[name] = self.calls[name] + 1
				return real(self, ...)
			end
		end
		pages[i] = p
	end
	return clip, pages
end
local function xOf(f, i) return (select(4, f:GetPoint(i or 1))) end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function inPlace(f, what)
	eq(f:GetNumPoints(), 2, what .. ": its two points are back")
	local p1, rel1, rp1, x1, y1 = f:GetPoint(1)
	local p2, rel2, rp2, x2, y2 = f:GetPoint(2)
	eq(p1 .. rp1 .. p2 .. rp2, "TOPLEFTTOPLEFTBOTTOMRIGHTBOTTOMRIGHT", what .. ": the same points")
	ok(rel1 == f:GetParent() and rel2 == f:GetParent(), what .. ": on the same frame")
	ok(x1 == 0 and y1 == 0 and x2 == 0 and y2 == 0, what .. ": no offset left")
end

test("d2 m: Reduce motion is off by default, T.ReduceMotion follows W.db, and the motion tokens are one table", function()
	local w, c, Th = theme()
	eq(c.W.DEFAULTS.reduceMotion, false, "the default")
	eq(c.W.db.reduceMotion, false, "a new player has it off")
	eq(Th.ReduceMotion(), false, "off")
	c.W.db.reduceMotion = true
	eq(Th.ReduceMotion(), true, "on when the setting is on")
	c.W.db.reduceMotion = "yes"
	eq(Th.ReduceMotion(), false, "only a real true counts")
	c.W.db.reduceMotion = false
	eq(Th.ReduceMotion(), false, "off again: read at every call")
	local want = { page = 0.28, sheetUp = 0.32, sheetDown = 0.24, dim = 0.2, fade = 0.16, reduced = 0.12, pill = 0.45 }
	for k, v in pairs(want) do eq(Th.MOTION[k], v, "T.MOTION." .. k) end
	for k in pairs(Th.MOTION) do ok(want[k], "no other token: " .. tostring(k)) end
end)

test("d2 m: a push starts a full width to the right, is between half-way, and ends in place with the old page hidden and restored", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env)
	local done = 0
	eq(clip:DoesClipChildren(), false, "the clip frame does not clip before")
	eq(A.Push(p[2], p[1], { clip = clip, onDone = function() done = done + 1 end }), true, "it moves")
	eq(clip:DoesClipChildren(), true, "the clip frame clips")
	ok(p[2]:IsShown() and p[1]:IsShown(), "both pages show during the move")
	ok(near(xOf(p[2]), 300) and near(xOf(p[2], 2), 300), "the new page starts a full width right (both points)")
	ok(near(xOf(p[1]), 0), "the old page starts in its place")
	local cover = clip.wuberPageCover
	ok(cover and cover:IsShown(), "the cover shows")
	eq(cover:GetAlpha(), 0, "the cover starts clear")
	local peak, lastX = 0, 300
	local t = 0
	while t < 0.139 do
		w:advance(0.02)
		t = t + 0.02
		peak = math.max(peak, cover:GetAlpha())
		ok(xOf(p[2]) <= lastX + 0.001, "the page only ever moves left")
		lastX = xOf(p[2])
	end
	ok(xOf(p[2]) > 0 and xOf(p[2]) < 300, "half-way the new page is between: " .. xOf(p[2]))
	ok(xOf(p[2]) < 150, "ease out: more than half the way in half the time")
	ok(xOf(p[1]) < 0 and xOf(p[1]) > -90, "half-way the old page is between 0 and 30% left: " .. xOf(p[1]))
	ok(near(xOf(p[1]), -0.3 * (300 - xOf(p[2]))), "the old page moves 30% of what the new one moves")
	ok(cover:GetAlpha() > 0 and cover:GetAlpha() < 0.45, "the cover is part-way")
	eq(done, 0, "not done yet")
	while t < 0.25 do
		w:advance(0.02)
		t = t + 0.02
		peak = math.max(peak, cover:GetAlpha())
	end
	ok(peak <= 0.45 + 1e-9, "the cover never goes over 45%: " .. peak)
	ok(peak > 0.43, "the cover gets to about 45%: " .. peak)
	w:advance(0.1)
	eq(done, 1, "onDone once")
	ok(p[2]:IsShown(), "the new page shows")
	ok(not p[1]:IsShown(), "the old page is hidden")
	inPlace(p[2], "new page")
	inPlace(p[1], "old page")
	ok(not cover:IsShown(), "the cover is hidden")
	eq(cover:GetAlpha(), 0, "the cover is clear")
	eq(p[1].calls.SetAlpha + p[2].calls.SetAlpha, 0, "no page's alpha is touched by a push")
	w:advance(1)
	eq(done, 1, "onDone never again")
end)

test("d2 m: PopPage is the way back: the top page leaves to the right, the one under returns from 30% left as its cover clears", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env)
	A.Push(p[2], p[1], { clip = clip })
	w:advance(0.5)
	local done = 0
	eq(A.PopPage(p[2], p[1], { clip = clip, onDone = function() done = done + 1 end }), true, "it moves")
	local cover = clip.wuberPageCover
	ok(p[1]:IsShown() and p[2]:IsShown(), "both show")
	ok(near(xOf(p[1]), -90), "the page under starts 30% left")
	ok(near(xOf(p[2]), 0), "the top page starts in place")
	ok(near(cover:GetAlpha(), 0.45) and cover:IsShown(), "the cover starts at 45%")
	w:advance(0.14)
	ok(xOf(p[2]) > 0 and xOf(p[2]) < 300, "the top page is on its way right")
	ok(xOf(p[1]) > -90 and xOf(p[1]) < 0, "the page under is on its way back")
	ok(cover:GetAlpha() < 0.45 and cover:GetAlpha() > 0, "the cover clears")
	w:advance(0.3)
	eq(done, 1, "onDone once")
	ok(p[1]:IsShown() and not p[2]:IsShown(), "the page under shows, the top page is hidden")
	inPlace(p[1], "page under")
	inPlace(p[2], "top page")
	ok(not cover:IsShown() and cover:GetAlpha() == 0, "the cover is gone")
end)

test("d2 m: a call during a move makes the running move jump to its end first, and onDone runs once", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env, 3)
	local done1, done2 = 0, 0
	A.Push(p[2], p[1], { clip = clip, onDone = function() done1 = done1 + 1 end })
	w:advance(0.1)
	ok(xOf(p[2]) > 0, "in the middle of the first push")
	A.Push(p[3], p[2], { clip = clip, onDone = function() done2 = done2 + 1 end })
	eq(done1, 1, "the first push was ended: onDone once")
	ok(not p[1]:IsShown(), "its old page is hidden")
	inPlace(p[1], "first old page")
	ok(near(xOf(p[3]), 300) and near(xOf(p[2]), 0), "the second push starts from the first one's end")
	w:advance(0.1)
	A.StopPage(clip)
	eq(done2, 1, "StopPage ends the move: onDone once")
	ok(p[3]:IsShown() and not p[2]:IsShown(), "final state at once")
	inPlace(p[3], "third page")
	inPlace(p[2], "second page")
	ok(not clip.wuberPageCover:IsShown(), "no cover left")
	A.StopPage(clip)
	w:advance(1)
	eq(done1 .. "/" .. done2, "1/1", "nothing is called twice")
	-- a pop during a push
	A.Push(p[2], p[3], { clip = clip })
	w:advance(0.1)
	A.PopPage(p[2], p[3], { clip = clip })
	ok(near(xOf(p[2]), 0) and near(xOf(p[3]), -90), "the pop starts from the push's end")
	w:advance(0.5)
	ok(p[3]:IsShown() and not p[2]:IsShown(), "back on the page under")
	inPlace(p[2], "popped page")
	inPlace(p[3], "page under")
end)

test("d2 m: with Reduce motion a page fades in in place over 0.12 s and no point ever changes", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env)
	c.W.db.reduceMotion = true
	local done = 0
	A.Push(p[2], p[1], { clip = clip, onDone = function() done = done + 1 end })
	ok(p[2]:IsShown() and not p[1]:IsShown(), "the pages swap at once")
	eq(p[2]:GetAlpha(), 0, "the new page starts clear")
	w:advance(0.06)
	ok(p[2]:GetAlpha() > 0 and p[2]:GetAlpha() < 1, "it fades: " .. p[2]:GetAlpha())
	eq(done, 0, "not done at 0.06 s")
	w:advance(0.1)
	eq(p[2]:GetAlpha(), 1, "full at the end")
	eq(done, 1, "onDone once")
	A.PopPage(p[2], p[1], { clip = clip, onDone = function() done = done + 1 end })
	ok(p[1]:IsShown() and not p[2]:IsShown(), "the way back swaps at once too")
	w:advance(0.3)
	eq(p[1]:GetAlpha(), 1, "full again")
	eq(done, 2, "onDone once more")
	for i = 1, 2 do
		eq(p[i].calls.SetPoint + p[i].calls.ClearAllPoints, 0, "page " .. i .. ": no point changed")
		inPlace(p[i], "page " .. i)
	end
	ok(not (clip.wuberPageCover and clip.wuberPageCover:IsShown()), "no cover")
end)

test("d2 m: in combat a page with a secure button swaps at once: no move, no fade, and a protected frame is not touched", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env, 3)
	-- page 3 holds a secure button, so it is protected itself; page 2 is plain
	local sec = env.CreateFrame("Button", nil, p[3], "SecureActionButtonTemplate")
	ok(p[3]:IsProtected(), "the page with a secure button is protected")
	local violations = #w.violations
	c.player.combat = true
	local done = 0
	-- plain pages, opts.secure: swap at once
	eq(A.Push(p[2], p[1], { clip = clip, secure = true, onDone = function() done = done + 1 end }), false, "no move")
	ok(p[2]:IsShown() and not p[1]:IsShown(), "swapped at once")
	eq(done, 1, "onDone at once")
	eq(p[1].calls.SetPoint + p[2].calls.SetPoint + p[1].calls.ClearAllPoints + p[2].calls.ClearAllPoints, 0, "no point changed")
	eq(p[1].calls.SetAlpha + p[2].calls.SetAlpha, 0, "no fade")
	-- a protected page: the helper notices by itself (no opts.secure) and leaves it alone
	A.Push(p[3], p[2], { clip = clip, onDone = function() done = done + 1 end })
	eq(done, 2, "onDone at once")
	ok(not p[2]:IsShown(), "the plain page is hidden")
	A.PopPage(p[3], p[2], { clip = clip, secure = true, onDone = function() done = done + 1 end })
	eq(done, 3, "onDone at once")
	ok(p[2]:IsShown(), "the plain page shows again")
	A.StopPage(clip)
	for name, n in pairs(p[3].calls) do eq(n, 0, "protected page: " .. name .. " never called") end
	eq(#w.violations, violations, "the game blocked nothing")
	w:advance(1)
	eq(done, 3, "nothing later")
	ok(not (clip.wuberPageCover and clip.wuberPageCover:IsShown()), "no cover in combat")
	-- with Reduce motion too: still at once
	c.W.db.reduceMotion = true
	A.PopPage(p[2], p[1], { clip = clip, secure = true })
	ok(p[1]:IsShown() and not p[2]:IsShown(), "at once")
	eq(p[1].calls.SetAlpha, 0, "no fade in combat")
	-- out of combat the same pages move again
	c.player.combat = false
	c.W.db.reduceMotion = false
	eq(A.Push(p[2], p[1], { clip = clip, secure = true }), true, "out of combat it moves")
	ok(near(xOf(p[2]), 300), "from a full width right")
end)

test("d2 m: opts.place and opts.width are used, and no Scale, Translation or any other animation is ever made", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env)
	local seen = {}
	local function place(frame, dx) seen[#seen + 1] = { frame, dx } end
	A.Push(p[2], p[1], { clip = clip, width = 200, place = place })
	ok(seen[1][1] == p[2] and near(seen[1][2], 200), "the page is placed opts.width to the right first")
	w:advance(0.5)
	local last = {}
	for _, s in ipairs(seen) do last[s[1]] = s[2] end
	eq(last[p[2]], 0, "the page ends at 0")
	eq(last[p[1]], 0, "the old page is put back at 0")
	local low = 0
	for _, s in ipairs(seen) do if s[1] == p[1] then low = math.min(low, s[2]) end end
	ok(near(low, -60), "the old page went 30% of the width left: " .. low)
	eq(p[1].calls.SetPoint + p[2].calls.SetPoint, 0, "with opts.place the helper sets no point itself")
	A.PopPage(p[2], p[1], { clip = clip })
	w:advance(0.5)
	c.W.db.reduceMotion = true
	A.Push(p[2], p[1], { clip = clip })
	w:advance(0.5)
	local kinds = {}
	for _, f in ipairs({ clip, p[1], p[2], clip.wuberPageCover, clip.wuberPageCover.tex }) do
		for _, g in ipairs({ f:GetAnimationGroups() }) do
			kinds[#kinds + 1] = "group"
			for _, a in ipairs({ g:GetAnimations() }) do kinds[#kinds + 1] = a:GetObjectType() end
		end
	end
	eq(table.concat(kinds, " "), "", "no animation group on the clip frame, the pages or the cover")
	eq(c.W.lastError, nil, "no error")
end)

test("d2 m: opts.single: one page on screen; the other is hidden at the start and never moves; a fill of the clip frame; no level is set", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env)
	local sets = 0
	for _, f in ipairs({ clip, p[1], p[2] }) do
		local real = f.SetFrameLevel
		f.SetFrameLevel = function(self, ...) sets = sets + 1 return real(self, ...) end
	end
	local done = 0
	eq(A.Push(p[2], p[1], { clip = clip, single = true, onDone = function() done = done + 1 end }), true, "it moves")
	ok(p[2]:IsShown() and not p[1]:IsShown(), "the old page is hidden when the move starts")
	ok(near(xOf(p[2]), 300), "the new page starts a full width right")
	local b = clip.wuberPageBacking
	ok(b and b:IsShown() and b:GetParent() == clip and b:GetObjectType() == "Texture", "the fill is a texture of the clip frame")
	ok(not (clip.wuberPageCover and clip.wuberPageCover:IsShown()), "no cover")
	w:advance(0.08)
	ok(xOf(p[2]) > 0 and xOf(p[2]) < 300, "on its way: " .. xOf(p[2]))
	eq(p[1].calls.SetPoint, 0, "the page that left never moves")
	w:advance(0.4)
	eq(done, 1, "onDone once")
	inPlace(p[2], "new page")
	ok(not b:IsShown(), "the fill is gone")
	p[1].calls.SetPoint, p[2].calls.SetPoint = 0, 0
	eq(A.PopPage(p[2], p[1], { clip = clip, single = true, onDone = function() done = done + 1 end }), true, "the pop moves")
	ok(p[1]:IsShown() and not p[2]:IsShown(), "the top page is hidden when the pop starts")
	ok(near(xOf(p[1]), -90), "the page that comes back starts 30% left")
	ok(b:IsShown(), "over the fill")
	w:advance(0.08)
	ok(xOf(p[1]) < 0 and xOf(p[1]) > -90, "on its way back: " .. xOf(p[1]))
	w:advance(0.4)
	eq(done, 2, "onDone once more")
	inPlace(p[1], "page that came back")
	ok(not b:IsShown() and not p[2]:IsShown(), "the fill and the top page are gone")
	eq(sets, 0, "no frame level was set")
end)

test("d2 lead: with Reduce motion the older slide helpers (SlideUp, SlideIn, Move, SlideOut) fade in place: their offsets are 0", function()
	local w, c, Th, env = theme()
	local A = Th.Animate
	local clip, p = stage(env)
	local ag = A.SlideUp(p[1], 24)
	local x, y = ag.t0:GetOffset()
	eq(y, -24, "with motion the frame starts 24 lower")
	c.W.db.reduceMotion = true
	for _, how in ipairs({ { "SlideUp", 24 }, { "SlideIn", 40 }, { "Move", 30, 30 } }) do
		local g = A[how[1]](p[1], how[2], how[3])
		local x0, y0 = g.t0:GetOffset()
		local x1, y1 = g.t1:GetOffset()
		ok(x0 == 0 and y0 == 0 and x1 == 0 and y1 == 0, how[1] .. " does not travel")
	end
	local out = A.SlideOut(p[1], -40)
	local ox, oy = out.t:GetOffset()
	ok(ox == 0 and oy == 0, "SlideOut does not travel")
	T.clean(w)
end)
