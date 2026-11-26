local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- r50 F (H24-05): the "Scroll for more" cue shows only while a drawn word or button lies below the view at the top.
local function below(s)
	local view = H.rect(s.scroll)
	local n = 0
	local seen = {}
	local function walk(f)
		if seen[f] then return end
		seen[f] = true
		for _, g in ipairs({ f:GetRegions() }) do
			if g.GetText and H.visible(g) then
				local t = g:GetText()
				local r = H.rect(g)
				if type(t) == "string" and t ~= "" and r and r.w > 0 and r.h > 0 and r.b < view.b - 0.5 then n = n + 1 end
			end
		end
		if f:GetObjectType() == "Button" and H.visible(f) then
			local r = H.rect(f)
			if r and r.w > 0 and r.h > 0 and r.b < view.b - 0.5 then n = n + 1 end
		end
		for _, ch in ipairs({ f:GetChildren() }) do walk(ch) end
	end
	walk(s.content)
	return n
end

local function earn(scope, wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	local W = a.W
	W.db.coach = true
	W.db.fold = { v = 1, pages = {}, narrow = false }
	W.SetAdvanced(true)
	if not wide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console") w:advance(1)
	W.Driver.ShowScreen("earnings") w:advance(2)
	local s = W.UI.drive.screens.earnings
	s.scope = scope s.update() w:advance(1)
	s.scroll:ScrollTo(0, true) w:advance(0.6)
	return w, W, s
end

local function unfolded(scope)
	local w, W, s = earn(scope, true)
	ok(W.Driver.Wide("earnings"), "control: unfolded")
	ok(s.cue:IsShown() == (below(s) > 0), "cue " .. tostring(s.cue:IsShown()) .. " but " .. below(s) .. " items below")
	T.clean(w)
end
local function folded(scope)
	local w, W, s = earn(scope, false)
	ok(not W.Driver.Wide("earnings"), "control: folded")
	ok(below(s) > 0, "control: something lies below")
	ok(s.cue:IsShown(), "the cue shows")
	T.clean(w)
end
test("r50 f: unfolded Earnings (me): the cue shows only while something lies below the view", function() unfolded("me") end)
test("r50 f: unfolded Earnings (crew): the cue shows only while something lies below the view", function() unfolded("crew") end)
-- guard: the folded page is taller than its view with the reset link below; the cue is needed there and stays
test("r50 f: folded Earnings (me): the cue shows while something lies below the view", function() folded("me") end)
-- guard: same, crew view
test("r50 f: folded Earnings (crew): the cue shows while something lies below the view", function() folded("crew") end)
