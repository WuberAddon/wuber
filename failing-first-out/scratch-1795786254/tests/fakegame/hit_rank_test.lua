-- The fake game's hit test (Client:frameAt) ranks frames as the real client does (issue #36, job 2748b, Lab run 3).
-- The rule, proven from the Lab's GetMouseFoci samples (122 of 122 disagreeing rows, none against):
--   a frame inside a clipping ancestor competes with frames OUTSIDE that ancestor at the clipping ancestor's own strata and
--   level; at an equal level the frame outside the clipping ancestor wins; a child clipped out at the point takes no mouse.
-- Caveat (tests/README.md, What tests cannot prove): the tie at an equal level rests on one real case, the header strip.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function bare()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	return w, c, c.env
end
-- a mouse-taking frame at screen rect l, b, width, height
local function mk(env, parent, level, l, b, wd, ht, o)
	o = o or {}
	local f = env.CreateFrame(o.kind or "Frame", nil, parent or env.UIParent)
	if o.strata then f:SetFrameStrata(o.strata) end
	f:SetFrameLevel(level)
	f:SetSize(wd, ht)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", l, b)
	if o.mouse ~= false then f:EnableMouse(true) end
	if o.clips then f:SetClipsChildren(true) end
	return f
end

-- guard: infra (pins the tool: plain order, no clipping anywhere; the old and the new frameAt agree)
test("fakegame hit rank: without clipping a higher strata, then a higher level, then the newer frame wins", function()
	local w, c, env = bare()
	local low = mk(env, nil, 5, 100, 100, 200, 200)
	local high = mk(env, nil, 9, 100, 100, 200, 200)
	eq(c:frameAt(150, 150), high, "level 9 over level 5")
	local newer = mk(env, nil, 9, 100, 100, 200, 200)
	eq(c:frameAt(150, 150), newer, "equal level: the newer frame")
	local dialog = mk(env, nil, 1, 100, 100, 200, 200, { strata = "DIALOG" })
	eq(c:frameAt(150, 150), dialog, "a higher strata beats a higher level")
	eq(c:frameAt(900, 900), nil, "nothing there")
	local _ = low
end)

for _, order in ipairs({ "clipped first", "sibling first" }) do
	test("fakegame hit rank: a level-42 button in a clipping level-2 parent loses to an unclipped level-2 sibling over it (" .. order .. ")", function()
		local w, c, env = bare()
		local clipper, button, sibling
		local function makeClip()
			clipper = mk(env, nil, 2, 100, 100, 300, 300, { clips = true, mouse = false })
			button = mk(env, clipper, 42, 120, 120, 40, 40, { kind = "Button" })
		end
		if order == "clipped first" then makeClip() end
		sibling = mk(env, nil, 2, 100, 100, 300, 100)
		if order ~= "clipped first" then makeClip() end
		eq(c:frameAt(130, 130), sibling, "the equal level: the frame outside the clip wins, whichever was made first")
	end)
end

-- guard: infra (passes on the old frameAt too: what the old and the new agree on, so a later change cannot lose it)
test("fakegame hit rank: the clipped button still wins where nothing outside the clip covers it, and over a lower sibling", function()
	local w, c, env = bare()
	local clipper = mk(env, nil, 2, 100, 100, 300, 300, { clips = true, mouse = false })
	local button = mk(env, clipper, 42, 120, 220, 40, 40, { kind = "Button" })
	local under = mk(env, nil, 1, 100, 100, 300, 300)
	eq(c:frameAt(130, 230), button, "a level-1 sibling is under the level-2 clip: the button wins")
	local over = mk(env, nil, 3, 100, 100, 300, 100)
	eq(c:frameAt(130, 230), button, "a level-3 sibling that does not reach the button's point changes nothing")
	eq(c:frameAt(130, 130), over, "...and at a point it does cover, it wins (level 3 over the clip's level 2)")
	local _ = under
end)

test("fakegame hit rank: a level-10 unclipped sibling beats the level-42 button inside a level-2 clip", function()
	local w, c, env = bare()
	local clipper = mk(env, nil, 2, 100, 100, 300, 300, { clips = true, mouse = false })
	mk(env, clipper, 42, 120, 120, 40, 40, { kind = "Button" })
	local sibling = mk(env, nil, 10, 100, 100, 300, 300)
	eq(c:frameAt(130, 130), sibling, "10 > the clip's level 2, however high the button's own level")
end)

test("fakegame hit rank: a child clipped out at the point takes no mouse; the frame beneath gets it", function()
	local w, c, env = bare()
	local under = mk(env, nil, 1, 0, 0, 1000, 1000)
	local clipper = mk(env, nil, 2, 100, 100, 100, 100, { clips = true, mouse = false })
	local child = mk(env, clipper, 3, 150, 150, 200, 200) -- sticks out to 350, 350
	eq(c:frameAt(160, 160), child, "inside the clip rect: the child")
	eq(c:frameAt(300, 300), under, "outside the clip rect: the child is cut off, the frame beneath takes it")
	local grand = mk(env, child, 4, 150, 150, 200, 200)
	eq(c:frameAt(300, 300), under, "a grandchild is cut off too")
	eq(c:frameAt(160, 160), grand, "...and inside the clip it ranks as before")
end)

test("fakegame hit rank: nested clips compete at the OUTER clipping ancestor's level", function()
	local w, c, env = bare()
	local outer = mk(env, nil, 2, 100, 100, 400, 400, { clips = true, mouse = false })
	local inner = mk(env, outer, 5, 100, 100, 400, 400, { clips = true, mouse = false })
	local button = mk(env, inner, 99, 120, 120, 40, 40, { kind = "Button" })
	local out3 = mk(env, nil, 3, 100, 100, 400, 400)
	eq(c:frameAt(130, 130), out3, "an outside level-3 frame beats the button: it ranks as the outer clip (level 2), not the inner (5)")
	local inside6 = mk(env, outer, 6, 100, 100, 400, 400)
	eq(c:frameAt(130, 130), out3, "a frame inside the outer clip at level 6 competes with the outside frame at 2, and loses to 3")
	out3:SetFrameLevel(1)
	eq(c:frameAt(130, 130), inside6, "outside frame lowered to 1: inside the outer clip, level 6 beats the inner clip's level 5 (the button's stand-in)")
	local _ = button
end)

-- The real evidence (tests/fixtures/rec/focus-run3-back.lua, two GetMouseFoci rows of the Lab's run 3): the game's focus was the strip.
test("fakegame hit rank: the Lab's run 3 rows, the strip and not the back arrow, at both real mouse points", function()
	local R = dofile(T.dir .. "/fixtures/rec/focus-run3-back.lua")
	local w, c, env = bare()
	local function geom(f, r)
		f:SetSize(r.w, r.h)
		f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", r.l, r.b)
	end
	local root = env.CreateFrame("Frame", nil, env.UIParent)
	root:SetFrameStrata(R.root.strata) root:SetFrameLevel(R.root.level) geom(root, R.root)
	local body = env.CreateFrame("Frame", nil, root)
	body:SetFrameLevel(R.body.level) geom(body, R.body) body:SetClipsChildren(R.body.clips)
	local strip = env.CreateFrame("Frame", nil, root)
	strip:SetFrameLevel(R.strip.level) geom(strip, R.strip) strip:EnableMouse(true)
	local arrow = env.CreateFrame("Button", nil, body)
	arrow:SetFrameLevel(R.arrow.level) geom(arrow, R.arrow)
	eq(arrow:GetFrameStrata(), "HIGH", "the arrow's strata is the rows' HIGH")
	eq(strip:GetFrameStrata(), "HIGH", "the strip's strata is the rows' HIGH")
	local want = R[R.focus]
	for _, m in ipairs(R.mouse) do
		local hit = c:frameAt(m.x, m.y)
		ok(hit == strip, ("at %.1f,%.1f the game's focus was the strip; frameAt gave %s"):format(m.x, m.y,
			hit == arrow and "the back arrow (plain level order)" or tostring(hit)))
	end
	eq(want.name, "strip", "the fixture's focus is the strip")
end)
