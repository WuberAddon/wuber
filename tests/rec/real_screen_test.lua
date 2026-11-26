-- Flight recorder, lane B1: the real game window measured from screenshots (SHOT-FACTS.md of the recorder's
-- scratch, 21 Nov 2026): Config.wtf GxWindowedResolution 2662x2089 at uiScale 1, and Wuber's phone (376 x 657
-- units) measured 1.97 real px per unit, so UIParent is about 1350 x 1060 units (an estimate from Wuber's own
-- size, not read from the game). The fake's default screen stays 1920 x 1080; this asks whether Wuber's windows
-- stay on a screen of the real shape.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local E = assert(loadfile(T.dir .. "/layout/engine.lua"))(H)

local SW, SH = 1350, 1060

local function onScreen(r, what)
	ok(r, what .. " has a place")
	local slop = 0.5
	ok(r.l >= -slop and r.b >= -slop and r.l + r.w <= SW + slop and r.b + r.h <= SH + slop,
		("%s on the %d x %d screen: l %.0f b %.0f r %.0f t %.0f"):format(what, SW, SH, r.l, r.b, r.l + r.w, r.b + r.h))
end

local function check(saved, label)
	local untag = E.tag({ Wuber = H.ADDONS.Wuber })
	local okRun, err = pcall(function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { screenW = SW, screenH = SH, saved = saved })
		T.settle(w)
		eq(r.env.GetScreenWidth(), SW, "the screen's width")
		r.W.UI.Toggle(true)
		w:advance(2)
		local win = r.W.Mod("UI.Kit").ui.win
		ok(win and H.visible(win), label .. ": the phone is open")
		onScreen(H.rect(win), label .. ": the phone")
		local n = 0
		for _, f in ipairs(r:secureButtons()) do
			if H.visible(f) then
				n = n + 1
				onScreen(H.rect(f), label .. ": secure button " .. tostring(f:GetName()))
			end
		end
		local off = {}
		for _, p in ipairs(E.check(r, label)) do
			if p.kind == "offscreen" then off[#off + 1] = p.what .. " " .. p.detail end
		end
		eq(#off, 0, label .. ": nothing of Wuber's off the screen (" .. table.concat(off, "; ") .. ")")
		T.clean(w)
		return n
	end)
	untag()
	if not okRun then error(err, 0) end
end

test("rec: real: a 1350 x 1060 screen (the real window's shape): the phone and its secure buttons stay on it", function()
	if not T.HAVE_UI then return end
	check(nil, "default place")
end)

-- the author's saved place in the real Wuber.lua: BOTTOMRIGHT -48, 44 at scale 1 (SHOT-FACTS: the phone's
-- right edge 60 px from the screen's edge in shot 112126_000951, as that place says)
test("rec: real: a 1350 x 1060 screen: the real saved place (BOTTOMRIGHT -48, 44) keeps the phone on it", function()
	if not T.HAVE_UI then return end
	check({ Wuber = { pos = { "BOTTOMRIGHT", "BOTTOMRIGHT", -48, 44 } } }, "saved place")
end)
