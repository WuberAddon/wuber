-- The harness holds a texture's own alpha (Region:SetAlpha) under an Alpha animation, as it holds
-- its SetVertexColor alpha: the in-game alpha probe of 20 Nov showed the game drops both while an Alpha animation
-- plays on the texture or a frame above it (A.SlideIn, A.ZoomIn, fades). Round 22's G1 moved several looks to
-- region alpha (card glow, hero glow and rim, rune ring, search wash fade, map routes), which the fake did not
-- hold before. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function r2(a) return math.floor((a or 1) * 100 + 0.5) / 100 end

-- a frame with a texture, drawn over a few frames, under the client's rule (H.ALPHA_HOLD = "anim")
local function setup(mode)
	local w = T.newWorld()
	local c = T.rider(w)
	w:advance(2)
	local env = c.env
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(100, 20)
	f:SetPoint("CENTER")
	local t = f:CreateTexture(nil, "ARTWORK")
	t:SetAllPoints(f)
	t:SetColorTexture(1, 1, 1, 1)
	t:SetVertexColor(1, 1, 1, 1)
	w:advance(0.5)
	local saved = H.ALPHA_HOLD
	H.ALPHA_HOLD = mode or "anim"
	local function done() H.ALPHA_HOLD = saved T.clean(w) end
	return w, env, f, t, done
end
local function fade(f, from, to, d)
	local ag = f:CreateAnimationGroup()
	local an = ag:CreateAnimation("Alpha")
	an:SetFromAlpha(from)
	an:SetToAlpha(to)
	an:SetDuration(d)
	return ag
end
local function kept(w) return (w.alphaKept or {})["?"] or 0 end

test("r24 hold: a texture's SetAlpha under an Alpha animation on its frame is held, as its vertex alpha is; after it, taken", function()
	local w, _, f, t, done = setup()
	t:SetAlpha(0.6)
	eq(r2(t:GetAlpha()), 0.6, "no animation: taken")
	local ag = fade(f, 0, 1, 0.3)
	ag:Play()
	w:advance(0.1)
	local n = kept(w)
	t:SetAlpha(0.2)
	eq(r2(t:GetAlpha()), 0.6, "under the fade: the drawn alpha is kept")
	eq(r2(H.alphaAsked(t)), 0.2, "the asked alpha is noted (H.alphaAsked)")
	eq(kept(w) - n, 1, "the held call is counted in world.alphaKept")
	t:SetAlpha(0.6)
	eq(kept(w) - n, 1, "asking for the alpha it already draws is not a change")
	w:advance(0.5)
	eq(r2(t:GetAlpha()), 0.6, "the fade ends: nothing repaints it")
	t:SetAlpha(0.2)
	eq(r2(t:GetAlpha()), 0.2, "after the fade: taken")
	eq(r2(t:GetEffectiveAlpha()), 0.2, "the effective alpha follows the drawn one")
	done()
end)

test("r24 hold: the hold covers an animation on the texture itself, a grandparent's, a hidden texture and a Line; frames and font strings take theirs", function()
	local w, env, f, t, done = setup()
	-- an animation on the texture itself
	local own = fade(t, 1, 1, 1)
	own:Play()
	w:advance(0.1)
	t:SetAlpha(0.3)
	eq(r2(t:GetAlpha()), 1, "its own Alpha animation: held")
	own:Stop()
	t:SetAlpha(0.3)
	eq(r2(t:GetAlpha()), 0.3, "stopped: taken")
	-- an animation two frames above, on a hidden texture and on a Line
	local outer = env.CreateFrame("Frame", nil, env.UIParent)
	outer:SetSize(200, 200)
	outer:SetPoint("CENTER")
	f:SetParent(outer)
	local line = f:CreateLine(nil, "ARTWORK")
	line:SetStartPoint("LEFT", f)
	line:SetEndPoint("RIGHT", f)
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText("Wuber")
	w:advance(0.3)
	local ag = fade(outer, 0, 1, 1)
	ag:Play()
	w:advance(0.1)
	t:SetAlpha(0.9)
	eq(r2(t:GetAlpha()), 0.3, "an Alpha animation on a grandparent: held")
	t:Hide()
	t:SetAlpha(0.9)
	eq(r2(t:GetAlpha()), 0.3, "a hidden texture under the animation: held")
	t:Show()
	line:SetAlpha(0.4)
	eq(r2(line:GetAlpha()), 1, "a Line (map routes): held")
	f:SetAlpha(0.5)
	eq(r2(f:GetAlpha()), 0.5, "a frame's own alpha: taken")
	label:SetAlpha(0.5)
	eq(r2(label:GetAlpha()), 0.5, "a font string's alpha: taken (the probe tested textures only)")
	ag:Stop()
	line:SetAlpha(0.4)
	eq(r2(line:GetAlpha()), 0.4, "the animation stopped: the Line takes it")
	done()
end)

test("r24 hold: WUBER_ALPHA_HOLD modes for SetAlpha: 'off' takes every change, 'drawn' also holds a drawn texture while it is hidden", function()
	local w, _, f, t, done = setup("off")
	local ag = fade(f, 0, 1, 1)
	ag:Play()
	w:advance(0.1)
	t:SetAlpha(0.2)
	eq(r2(t:GetAlpha()), 0.2, "off: taken under the animation")
	eq(kept(w), 0, "off: nothing held")
	ag:Stop()
	H.ALPHA_HOLD = "drawn"
	w:advance(0.3)
	f:Hide()
	w:advance(0.3)
	t:SetAlpha(0.7)
	eq(r2(t:GetAlpha()), 0.2, "drawn: a drawn texture whose frame is hidden keeps its alpha")
	f:Show()
	w:advance(0.3)
	t:SetAlpha(0.7)
	eq(r2(t:GetAlpha()), 0.7, "drawn: shown and drawn again: taken")
	H.ALPHA_HOLD = "anim"
	f:Hide()
	w:advance(0.3)
	t:SetAlpha(0.1)
	eq(r2(t:GetAlpha()), 0.1, "anim (the client's rule): a hidden frame's texture takes it")
	done()
end)

test("r24 hold: a held SetAlpha is written to the alpha report with its call; SetToFinalAlpha's end alpha clears the asked one", function()
	local w, _, f, t, done = setup()
	-- tests/out is made by a full run's transcript; made here too, so this test also passes run alone
	local path = T.dir .. "/out/r24_d_hold_report.txt"
	local probe = io.open(path, "w")
	if probe then probe:close()
	elseif package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. (T.dir .. "/out"):gsub("/", "\\") .. '" 2>nul')
	else os.execute('mkdir -p "' .. T.dir .. '/out"') end
	os.remove(path)
	local savedPath, savedSeen = H.ALPHA_REPORT, H.alphaReported
	H.ALPHA_REPORT, H.alphaReported = path, {}
	local ag = fade(f, 0, 1, 0.3)
	ag:Play()
	w:advance(0.1)
	t:SetAlpha(0.5)
	t:SetVertexColor(1, 1, 1, 0.5)
	H.ALPHA_REPORT, H.alphaReported = savedPath, savedSeen
	local fh = io.open(path, "r")
	local text = fh and fh:read("*a") or ""
	if fh then fh:close() end
	os.remove(path)
	ok(text:find("(SetAlpha)", 1, true), "the report names a held SetAlpha: " .. text)
	ok(text:find("(SetVertexColor)", 1, true), "and a held SetVertexColor: " .. text)
	w:advance(0.5)
	-- an animation on the texture that ends at its final alpha sets what is drawn and asked
	local own = fade(t, 1, 0.25, 0.2)
	own:SetToFinalAlpha(true)
	own:Play()
	w:advance(0.1)
	t:SetAlpha(0.9)
	eq(r2(H.alphaAsked(t)), 0.9, "asked under its own fade")
	w:advance(0.5)
	eq(r2(t:GetAlpha()), 0.25, "the fade's final alpha is drawn")
	eq(r2(H.alphaAsked(t)), 0.25, "and is the asked one too")
	done()
end)
