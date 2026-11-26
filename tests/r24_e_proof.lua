-- (BRIEF24 F2) Proof for F1: through Wuber's own animation helpers (Theme.Anim: A.SlideIn on every Drive screen,
-- A.ZoomIn on the window), a texture's Region:SetAlpha is held while the Alpha animation plays, as the game
-- does (alpha probe, 20 Nov), and is taken once it has ended. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function r2(a) return math.floor((a or 1) * 100 + 0.5) / 100 end

local function setup()
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
	t:SetAlpha(0.6)
	w:advance(0.5)
	return w, c.W.Theme.Animate, f, t
end

local function check(how, play)
	local w, A, f, t = setup()
	local saved = H.ALPHA_HOLD
	H.ALPHA_HOLD = "anim" -- the client's rule, whatever WUBER_ALPHA_HOLD a run sets
	play(A, f)
	w:advance(0.05)
	ok(H.underAlphaAnim(t), how .. ": an Alpha animation plays over the texture")
	local before = (w.alphaKept or {})["?"] or 0
	t:SetAlpha(0.2)
	eq(r2(t:GetAlpha()), 0.6, how .. ": the texture's SetAlpha is held while it plays (drawn alpha unchanged)")
	eq(r2(H.alphaAsked(t)), 0.2, how .. ": the asked alpha is noted")
	eq(((w.alphaKept or {})["?"] or 0) - before, 1, how .. ": the held call is counted")
	w:advance(1)
	ok(not H.underAlphaAnim(t), how .. ": the animation has ended")
	eq(r2(t:GetAlpha()), 0.6, how .. ": the end of the animation does not repaint it")
	t:SetAlpha(0.2)
	eq(r2(t:GetAlpha()), 0.2, how .. ": after it ends SetAlpha is applied")
	-- "off" takes every change, as the fake did before BRIEF21 (the proof is the hold, not the animation)
	H.ALPHA_HOLD = "off"
	A.SlideIn(f, 40, 0.25)
	w:advance(0.05)
	t:SetAlpha(0.9)
	eq(r2(t:GetAlpha()), 0.9, how .. ": with the hold off the change is taken")
	H.ALPHA_HOLD = saved
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end

test("r24 proof: a texture's SetAlpha during A.SlideIn is held, and applied after it ends", function()
	check("SlideIn", function(A, f) A.SlideIn(f, 40, 0.25) end)
end)

test("r24 proof: a texture's SetAlpha during A.ZoomIn is held, and applied after it ends", function()
	check("ZoomIn", function(A, f) A.ZoomIn(f, 0, 0, 0.32) end)
end)
