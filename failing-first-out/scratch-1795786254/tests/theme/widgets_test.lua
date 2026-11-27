-- Tests of Theme.Widgets (round 9, S8: the slider's fill sits under its knob). Loaded by
-- tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- the frame level and layer a region is drawn at: its frame's level first, then its layer
local LAYER = { BACKGROUND = 0, BORDER = 1, ARTWORK = 2, OVERLAY = 3, HIGHLIGHT = 4 }
local function depth(region)
	local s = H.state[region]
	local owner = region:GetParent()
	return owner:GetFrameLevel() * 100 + (LAYER[s.layer or "ARTWORK"] or 2) * 10 + (s.sublevel or 0)
end

test("Theme.Widgets S8: the slider's gold fill is drawn under its white knob ('My time is worth')", function()
	local W, w = T.contract("Theme.Widgets", "tests/theme/widgets_test.lua", {
		["T.Pill"] = "function", ["T.Chip"] = "function", ["T.Tip"] = "function", ["T.Toggle"] = "function",
		["T.Slider"] = "function", ["T.Segmented"] = "function", ["T.Bar"] = "function", ["T.PILL_STYLES"] = "table",
	})
	local env = w.clients[1].env
	local Th = W.Theme
	local holder = env.CreateFrame("Frame", nil, env.UIParent)
	holder:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	holder:SetSize(300, 40)
	local s = Th.Slider(holder, 260, { min = 0, max = 100, step = 1 })
	s.holder:SetPoint("CENTER", holder, "CENTER", 0, 0)
	s:Set(30)
	w:advance(0.2)
	-- every texture of the fill (a 3-piece pill) is under every texture of the knob
	local fills = {}
	for _, r in ipairs({ s.fill:GetRegions() }) do fills[#fills + 1] = r end
	ok(#fills > 0, "the fill has textures")
	local top = -1
	for _, r in ipairs(fills) do top = math.max(top, depth(r)) end
	ok(depth(s.knob) > top, ("the knob (%d) is drawn above the fill (%d)"):format(depth(s.knob), top))
	ok(s.halo.nothing == true, "the knob has no halo any more (design round 1: glows off)")
	-- the fill still ends under the knob's centre
	local kr, fr = H.rect(s.knob), H.rect(s.fill)
	ok(math.abs((fr.l + fr.w) - (kr.l + kr.w / 2)) < 1, "the fill ends under the knob's centre")
	-- and the knob still takes no mouse of its own (the slider is what you drag)
	ok(not s.top:IsMouseEnabled(), "the knob's frame takes no clicks")
	T.clean(w)
end)

-- (round 13, I5) a reviewer's shots 37, 56, 57: a tooltip let the page under it show through, its text
-- mixing with what was behind ('Gifted on 17 Nov.' ran into 'Crew · 12 shards'). (design 4) A Wuber tip is
-- Wuber's own card (the frame WuberTip): solid and on the tooltip layer every time, and the game's own
-- tooltip is left exactly as the game (or another addon) had it. More in tests/d4/d4_d_tip_test.lua.
test("Theme.Widgets r13 I5: a Wuber tooltip is solid and on the tooltip layer, every time, and the game's tooltip keeps its look", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, W = c.env, c.W
	local gt = env.GameTooltip
	local f = env.CreateFrame("Button", nil, env.UIParent)
	f:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	f:SetSize(80, 30)
	W.Theme.Tip(f, "A title", "One plain sentence.")
	local S = H.state
	for round = 1, 2 do
		-- something else left the game's tooltip low and see-through: it stays so
		gt:SetFrameStrata("MEDIUM")
		gt:SetAlpha(0.6)
		gt.NineSlice:SetCenterColor(0.09, 0.09, 0.19, 0.8)
		S[f].scripts.OnEnter(f)
		local card = env.WuberTip
		ok(card and H.visible(card), round .. ": the tip card shows")
		eq(card:GetFrameStrata(), "TOOLTIP", round .. ": on the tooltip layer")
		w:advance(0.5)
		eq(card:GetAlpha(), 1, round .. ": not faded")
		local _, _, _, fa = W.Theme.RGB("raised")
		eq(fa, 1, round .. ": a solid background colour")
		eq(gt:GetFrameStrata(), "MEDIUM", round .. ": the game's tooltip keeps its layer")
		eq(gt:GetAlpha(), 0.6, round .. ": and its alpha")
		local _, _, _, a = gt.NineSlice:GetCenterColor()
		eq(a, 0.8, round .. ": and its background")
		eq(gt.wuberSolid, nil, round .. ": nothing of Wuber's is put on it")
		S[f].scripts.OnLeave(f)
		ok(not H.visible(card), round .. ": hidden again")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- (round 13 review) tooltips Wuber builds by hand (not through T.Tip) are the same solid card
test("Theme.Widgets r13 I5: hand-built tooltips (minimap button, big button) are solid and on the tooltip layer", function()
	local w = T.newWorld()
	local c = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(5)
	local env, W = c.env, c.W
	local gt = env.GameTooltip
	local S = H.state
	local targets = { { "the minimap button", env.WuberMinimapButton }, { "the big button", env.WuberDriveButton } }
	ok(targets[1][2] and targets[2][2], "both buttons exist")
	for _, t in ipairs(targets) do
		local name, b = t[1], t[2]
		if b then
			gt:SetFrameStrata("MEDIUM")
			gt.NineSlice:SetCenterColor(0.09, 0.09, 0.19, 0.8)
			S[b].scripts.OnEnter(b)
			local card = env.WuberTip
			ok(card and H.visible(card), name .. ": its tip card shows")
			eq(card and card:GetFrameStrata(), "TOOLTIP", name .. ": on the tooltip layer")
			eq(W.Theme.TipOwner(), b, name .. ": it is this button's")
			local _, _, _, a = gt.NineSlice:GetCenterColor()
			eq(a, 0.8, name .. ": the game's tooltip keeps its look")
			eq(gt:GetFrameStrata(), "MEDIUM", name .. ": and its layer")
			S[b].scripts.OnLeave(b)
			ok(card and not H.visible(card), name .. ": hidden on leave")
		end
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- the author's crew row tooltip hung off the right edge of the screen. (design 4) A Wuber tip stands
-- beside its owner on a side where it lies wholly on the screen; the anchor asked for is a preference.
test("Theme.Widgets BRIEF18: tooltips stay on the screen (the side flips near an edge)", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, W = c.env, c.W
	local ui = env.UIParent
	local S = H.state
	local sw = ui:GetWidth()
	local function owner(point, x)
		local f = env.CreateFrame("Button", nil, ui)
		f:SetPoint(point, ui, point, x, 0)
		f:SetSize(120, 30)
		return f
	end
	local function hover(f)
		S[f].scripts.OnEnter(f)
		local card = env.WuberTip
		local side = card.side
		ok(card:GetLeft() >= -0.5 and card:GetRight() <= sw + 0.5, ("on the screen (%.0f to %.0f of %.0f)"):format(card:GetLeft(), card:GetRight(), sw))
		ok(card:GetRight() <= f:GetLeft() + 0.5 or card:GetLeft() >= f:GetRight() - 0.5 or card:GetBottom() >= f:GetTop() - 0.5 or card:GetTop() <= f:GetBottom() + 0.5, "not on its owner")
		S[f].scripts.OnLeave(f)
		return side
	end
	local right = owner("RIGHT", -4)
	W.Theme.Tip(right, "A crew row", "Somebody with a long enough line of words to make a wide tooltip.")
	eq(hover(right), "left", "at the right edge: opens to the left")
	local rightTop = owner("RIGHT", -4)
	W.Theme.Tip(rightTop, "A title", "Words.", "ANCHOR_TOPLEFT")
	eq(hover(rightTop), "above", "at the right edge, a TOPLEFT tip is above, kept on the screen")
	local left = owner("LEFT", 4)
	W.Theme.Tip(left, "A title", "Words.", "ANCHOR_LEFT")
	eq(hover(left), "right", "at the left edge: opens to the right")
	local mid = owner("CENTER", 0)
	W.Theme.Tip(mid, "A title", "Words.")
	eq(hover(mid), "right", "with room: as asked")
	S[right].scripts.OnEnter(right)
	ok(env.WuberTip:IsClampedToScreen(), "clamped to the screen")
	S[right].scripts.OnLeave(right)
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- the mouse wheel over a slider (Largest group, Casters' part) changed it while the author was
-- scrolling the Settings page. The rule: a slider takes the wheel only after it was clicked, until the
-- mouse leaves it; until then the wheel goes to the page under it. wheelAt sends a wheel turn the way
-- the game does: to the topmost shown frame under the point that takes the wheel.
local function wheelAt(c, region, delta)
	local r = H.rect(region)
	local x, y = r.l + r.w / 2, r.b + r.h / 2
	local best, bestKey
	for i, f in ipairs(c.frames) do
		local s = H.state[f]
		if s.kind == "frame" and s.wheel and H.visible(f) and not s.isUIParent then
			local fr = H.rect(f)
			if fr and x >= fr.l and x <= fr.l + fr.w and y >= fr.b and y <= fr.b + fr.h then
				local k = H.STRATA_RANK(f:GetFrameStrata()) * 1e8 + f:GetFrameLevel() * 1e4 + i
				if not bestKey or k > bestKey then best, bestKey = f, k end
			end
		end
	end
	if best and H.state[best].scripts.OnMouseWheel then H.state[best].scripts.OnMouseWheel(best, delta) end
	return best
end

test("Theme.Widgets BRIEF22 S1: the wheel passes over a slider to the page until the slider is clicked", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local page = env.CreateFrame("Frame", nil, env.UIParent)
	page:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	page:SetSize(320, 200)
	page:EnableMouseWheel(true)
	local scrolled = 0
	page:SetScript("OnMouseWheel", function(_, d) scrolled = scrolled + d end)
	local s = Th.Slider(page, 280, { min = 0, max = 40, step = 1, value = 10 })
	s.holder:SetPoint("CENTER", page, "CENTER", 0, 0)
	w:advance(0.2)
	ok(not s:IsMouseWheelEnabled(), "a slider not clicked takes no wheel")
	eq(wheelAt(c, s, -1), page, "the wheel over it goes to the page")
	eq(scrolled, -1, "the page scrolled")
	eq(s.value, 10, "the slider kept its value")
	-- a click on it: now the wheel steps it
	c:click(s)
	ok(s:IsMouseWheelEnabled(), "clicked: the slider takes the wheel")
	eq(wheelAt(c, s, 1), s, "the wheel goes to the slider")
	eq(s.value, 11, "one step up")
	eq(scrolled, -1, "the page stayed")
	-- the mouse leaves it: back to the page
	H.state[s].scripts.OnLeave(s)
	ok(not s:IsMouseWheelEnabled(), "left: the slider takes no wheel again")
	eq(wheelAt(c, s, -1), page, "the page again")
	eq(s.value, 11, "the slider kept its value")
	eq(scrolled, -2, "the page scrolled")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("Theme.Widgets BRIEF22 S1: in Settings the wheel over Group size and Warn me at this many shards scrolls the page; the page has a scroll bar", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local st = d.W.UI.settings
	local checked = 0
	for _, key in ipairs({ "drive.maxGroup", "drive.lowShards" }) do
		local sl = st.controls[key]
		ok(sl, key .. ": the slider exists")
		if sl and H.visible(sl) then
			checked = checked + 1
			-- scroll the page (on its empty space) until the slider is under the mouse, as the author does
			local function inView()
				local a, b = H.rect(sl), H.rect(st.clip)
				local y = a.b + a.h / 2
				return y > b.b + 10 and y < b.b + b.h - 10
			end
			for _, sec in ipairs(d.W.Mod("UI.Settings.Panel").sectionRanges()) do
				d.W.Mod("UI.Settings.Panel").openSection(sec.key)
				w:advance(1)
				for _ = 1, 60 do
					if inView() then break end
					local before = st.scrollTarget
					local a, b = H.rect(sl), H.rect(st.clip)
					H.state[st.clip].scripts.OnMouseWheel(st.clip, (a.b + a.h / 2 < b.b + b.h / 2) and -1 or 1)
					w:advance(1)
					if st.scrollTarget == before then break end
				end
				if inView() then break end
			end
			ok(inView(), key .. ": the slider is in view")
			local v = sl.value
			local before = st.scrollTarget
			local delta = (st.scrollTarget < (st.scrollMax or 0)) and -1 or 1
			eq(wheelAt(d, sl, delta), st.clip, key .. ": the wheel goes to the page")
			ok(st.scrollTarget ~= before, key .. ": the page scrolled")
			eq(sl.value, v, key .. ": the slider kept its value")
			w:advance(1)
			eq(sl.value, v, key .. ": still the same once settled")
		end
	end
	eq(checked, 2, "both sliders checked")
	ok(st.clip.edgeFade.BarShown and st.clip.edgeFade:BarShown(), "the page is longer than the window: a scroll bar shows")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
