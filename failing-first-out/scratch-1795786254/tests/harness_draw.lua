-- Tests of the harness drawing as the real client does. Loaded by tests/run.lua with its helper table T.
-- Two bugs passed offline and showed in game: BRIEF19 F5 (the Earnings period pills: Today lit while the totals
-- said 7 days) and BRIEF20 B1 (the top nav: Drive a solid white pill on every Ride screen). Both were a pill fill
-- whose SetVertexColor alpha the game did not take, set while an Alpha animation played (the window's A.ZoomIn,
-- a Drive screen's A.SlideIn). The harness holds such a change as the game does (tests/harness.lua,
-- Layered:SetVertexColor: only under an Alpha animation, as the in-game alpha probe showed; the
-- drawn-then-hidden hold is an opt-in, H.ALPHA_HOLD = "drawn": a texture's own SetAlpha is held by
-- the same rule, tests/r24_d_hold.lua): the old code of both fixes, put back from
-- tests/fixtures/old_pills.lua, must draw the bug here, and today's code must not.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local OLD = dofile(T.dir .. "/fixtures/old_pills.lua")

-- a client's rewrite (set in opts.prepare) that puts back the old code of these fix commits
local function oldCode(commits)
	local want = {}
	for _, c in ipairs(commits) do want[c] = true end
	local function lf(s) return (s:gsub("\r\n", "\n")) end -- (a checkout with CRLF line ends matches too)
	return function(addon, file, text)
		if addon ~= "Wuber" then return text end
		text = lf(text)
		for _, h in ipairs(OLD) do
			if h.file == file and want[h.commit] then
				local fixed = lf(h.fixed)
				local a, b = text:find(fixed, 1, true)
				if not a or text:find(fixed, b + 1, true) then
					error("tests/fixtures/old_pills.lua is out of date: " .. h.commit .. " " .. h.file .. " " .. h.hunk .. " is not in today's file exactly once")
				end
				text = text:sub(1, a - 1) .. lf(h.old) .. text:sub(b + 1)
			end
		end
		return text
	end
end

-- the buttons whose fill the game draws lit (a visible texture, its drawn alpha over 0.3), by key
-- (design 2) today's tabs are not pills: the open one has a violet glyph, the others grey; a button with a
-- glyph counts as lit when its glyph is that violet (T.RGB("accent")), whatever else it draws
local function lit(buttons, key, accent)
	local out = {}
	for _, b in ipairs(buttons) do
		if b.glyph then
			local r, g, bl = b.glyph:GetVertexColor()
			local ar, ag, ab = accent[1], accent[2], accent[3]
			if math.abs(r - ar) < 0.01 and math.abs(g - ag) < 0.01 and math.abs(bl - ab) < 0.01 then out[#out + 1] = tostring(b[key]) end
		else
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" and r:IsVisible() then
				local _, _, _, al = r:GetVertexColor()
				if (al or 1) > 0.3 then out[#out + 1] = tostring(b[key]) break end
			end
		end
		end
	end
	return table.concat(out, ",")
end
local function tabButtons(W)
	local out = {}
	for _, t in ipairs(W.UI.state.tabs or {}) do out[#out + 1] = t.button end
	return out
end

local function tabLit(W) return lit(tabButtons(W), "tabName", { W.Theme.RGB("accent") }) end

local function alphaOf(t) local _, _, _, a = t:GetVertexColor() return math.floor(a * 100 + 0.5) / 100 end
local function askedOf(t) local _, _, _, a = H.vertexAsked(t) return math.floor(a * 100 + 0.5) / 100 end

---------------------------------------------------------------------------
-- The rule, on plain frames
---------------------------------------------------------------------------

test("harness draw: the client's rule (alpha probe, 20 Nov): drawn-then-hidden and hidden textures take an alpha change; under an Alpha animation it is held", function()
	local w = T.newWorld()
	local c = T.rider(w)
	w:advance(2)
	local env = c.env
	local savedHold = H.ALPHA_HOLD
	H.ALPHA_HOLD = "anim" -- the client's rule, whatever WUBER_ALPHA_HOLD a run sets
	local function kept() return (w.alphaKept or {})["?"] or 0 end
	local t
	local function step(heldWant, alphaWant, what, r, g, b, a)
		local n = kept()
		t:SetVertexColor(r, g, b, a)
		eq(kept() - n, heldWant, what .. ": " .. (heldWant == 1 and "held" or "taken"))
		eq(alphaOf(t), alphaWant, what .. ": the alpha drawn")
	end
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(100, 20)
	f:SetPoint("CENTER")
	t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(f)
	step(0, 1, "first colour", 1, 0, 0, 1)
	w:advance(0.5)
	-- probe A (control): drawn, changed while shown
	step(0, 0.15, "A: drawn, changed while shown", 1, 0, 0, 0.15)
	step(0, 1, "A: and back", 1, 0, 0, 1)
	-- probe B: drawn, its frame hidden, changed, shown again
	f:Hide()
	w:advance(0.3)
	step(0, 0.15, "B: drawn, frame hidden", 1, 0, 0, 0.15)
	f:Show()
	step(0, 1, "B: shown again, same frame", 1, 0, 0, 1)
	w:advance(0.3)
	-- probe D: drawn, the texture itself hidden, changed, shown again
	t:Hide()
	w:advance(0.3)
	step(0, 0.15, "D: drawn, the texture hidden", 1, 0, 0, 0.15)
	t:Show()
	w:advance(0.3)
	eq(alphaOf(t), 0.15, "D: shown again: drawn faint")
	-- probe C: an Alpha animation running on the frame (1 to 1, looping): held, the colour still taken
	local ag = f:CreateAnimationGroup()
	local an = ag:CreateAnimation("Alpha")
	an:SetFromAlpha(1)
	an:SetToAlpha(1)
	an:SetDuration(2)
	ag:Play()
	w:advance(0.1)
	step(1, 0.15, "C: under an Alpha animation", 0, 1, 0, 1)
	local r, g = t:GetVertexColor()
	eq(("%.1f %.1f"):format(r, g), "0.0 1.0", "C: the colour is taken")
	eq(askedOf(t), 1, "C: the alpha asked for is noted (H.vertexAsked)")
	-- also on a hidden texture under the animation
	t:Hide()
	step(1, 0.15, "C: a hidden texture under the animation", 0, 1, 0, 1)
	t:Show()
	-- the probe: the texture's own alpha (Region:SetAlpha) is dropped too under the animation
	local n = kept()
	t:SetAlpha(0.3)
	eq(t:GetAlpha(), 1, "C: a texture's SetAlpha under an Alpha animation: held")
	eq(H.alphaAsked(t), 0.3, "C: the asked region alpha is noted (H.alphaAsked)")
	eq(kept() - n, 1, "C: the held SetAlpha is counted")
	ag:Stop()
	step(0, 1, "the animation stopped: taken", 0, 1, 0, 1)
	t:SetAlpha(0.3)
	eq(t:GetAlpha(), 0.3, "the animation stopped: SetAlpha taken")
	t:SetAlpha(1)
	-- a frame's own alpha: SetAlpha while hidden takes
	f:Hide()
	f:SetAlpha(0.4)
	eq(f:GetAlpha(), 0.4, "SetAlpha on a hidden frame takes")
	T.clean(w)
	H.ALPHA_HOLD = savedHold
end)

test("harness draw: opt-in 'drawn' rule (H.ALPHA_HOLD = \"drawn\", not the client's): a drawn texture keeps its alpha while hidden or shown this frame", function()
	-- BRIEF21's guess, kept as an option: the in-game probe of 20 Nov showed the client takes these changes
	local before = H.ALPHA_HOLD
	H.ALPHA_HOLD = "drawn"
	local done, err = pcall(function()
		local w = T.newWorld()
		local c = T.rider(w)
		w:advance(2)
		local env = c.env
		-- calls held by the harness, counted in world.alphaKept by the line that made them ('?' outside an addon)
		local function kept() return (w.alphaKept or {})["?"] or 0 end
		local t
		-- one SetVertexColor: held (1) or taken (0), and the alpha drawn after it
		local function set(r, g, b, a)
			local n = kept()
			t:SetVertexColor(r, g, b, a)
			return kept() - n, alphaOf(t)
		end
		local function step(heldWant, alphaWant, what, r, g, b, a)
			local h, al = set(r, g, b, a)
			eq(h, heldWant, what .. ": " .. (heldWant == 1 and "held" or "taken"))
			eq(al, alphaWant, what .. ": the alpha drawn")
		end
		-- made in a hidden frame, never drawn: every change takes (a screen built before it shows)
		local f = env.CreateFrame("Frame", nil, env.UIParent)
		f:SetSize(100, 20)
		f:SetPoint("CENTER")
		f:Hide()
		t = f:CreateTexture(nil, "BACKGROUND")
		t:SetAllPoints(f)
		step(0, 1, "never drawn, first colour", 1, 1, 1, 1)
		step(0, 0, "never drawn", 1, 1, 1, 0)
		-- shown and drawn: a change takes at once
		f:Show()
		w:advance(0.1)
		step(0, 0.5, "drawn", 1, 1, 1, 0.5)
		-- hidden: the colour changes, the alpha stays as drawn
		f:Hide()
		step(1, 0.5, "hidden", 0.2, 0.3, 0.4, 1)
		local r, g, b = t:GetVertexColor()
		eq(("%.1f %.1f %.1f"):format(r, g, b), "0.2 0.3 0.4", "hidden: the colour is taken")
		eq(askedOf(t), 1, "the alpha asked for is noted (H.vertexAsked)")
		-- shown again: still not in the frame the game has drawn
		f:Show()
		step(1, 0.5, "shown this frame", 0.2, 0.3, 0.4, 1)
		w:advance(0.1)
		eq(alphaOf(t), 0.5, "nothing repaints it by itself")
		step(0, 1, "drawn again", 0.2, 0.3, 0.4, 1)
		-- the texture hidden by itself
		t:Hide()
		step(1, 1, "the texture hidden", 1, 1, 1, 0)
		t:Show()
		w:advance(0.1)
		step(0, 0, "shown and drawn", 1, 1, 1, 0)
		-- moved under a hidden parent
		local hidden = env.CreateFrame("Frame", nil, env.UIParent)
		hidden:Hide()
		f:SetParent(hidden)
		step(1, 0, "under a hidden parent", 1, 1, 1, 1)
		f:SetParent(env.UIParent)
		w:advance(0.1)
		step(0, 1, "back under a shown parent and drawn", 1, 1, 1, 1)
		-- an Alpha animation playing on the frame (A.SlideIn, A.FadeIn): not taken until it has finished
		local ag = f:CreateAnimationGroup()
		local an = ag:CreateAnimation("Alpha")
		an:SetFromAlpha(0)
		an:SetToAlpha(1)
		an:SetDuration(0.3)
		ag:Play()
		step(1, 1, "fading in", 1, 1, 1, 0.25)
		w:advance(0.5)
		step(0, 0.25, "after the fade", 1, 1, 1, 0.25)
		-- the region's own alpha is not this: SetAlpha while hidden takes (the game's fades set it before Show)
		f:Hide()
		f:SetAlpha(0.4)
		eq(f:GetAlpha(), 0.4, "SetAlpha on a hidden frame takes")
		ok(kept() >= 1, "held calls are counted in world.alphaKept")
		T.clean(w)
	end)
	H.ALPHA_HOLD = before
	if not done then error(err, 0) end
end)

test("harness draw: a texture that was never drawn takes its changes, however often it was shown and hidden in between", function()
	local w = T.newWorld()
	local c = T.rider(w)
	w:advance(2)
	local env = c.env
	-- made hidden (its frame hidden): hidden and shown again within one frame, never drawn
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(100, 20)
	f:SetPoint("CENTER")
	f:Hide()
	local t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(f)
	t:SetVertexColor(1, 1, 1, 1)
	t:Hide()
	w:advance(0.5)
	t:Show()
	t:Hide()
	t:SetVertexColor(1, 1, 1, 0)
	eq(alphaOf(t), 0, "made hidden, hidden again, never drawn: taken")
	f:Show()
	t:Show()
	t:Hide()
	w:advance(0.5)
	t:SetVertexColor(1, 1, 1, 0.5)
	eq(alphaOf(t), 0.5, "shown and hidden in one frame: never drawn, taken")
	-- made in a shown frame, hidden in the same frame: never drawn
	local u = f:CreateTexture(nil, "BACKGROUND")
	u:SetVertexColor(1, 1, 1, 1)
	u:Hide()
	w:advance(0.5)
	u:SetVertexColor(1, 1, 1, 0)
	eq(alphaOf(u), 0, "hidden in the frame it was made: never drawn, taken")
	ok(next(w.alphaKept or {}) == nil, "nothing held")
	T.clean(w)
end)

test("harness draw: an Alpha animation holds the alpha of a visible texture the game has drawn and that was never hidden", function()
	local w = T.newWorld()
	local c = T.rider(w)
	w:advance(2)
	local env = c.env
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(100, 20)
	f:SetPoint("CENTER")
	local t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(f)
	t:SetVertexColor(1, 1, 1, 1)
	w:advance(0.5)
	ok(H.drawnNow(t), "visible over frames: drawn")
	t:SetVertexColor(1, 1, 1, 0.8)
	eq(alphaOf(t), 0.8, "drawn, no animation: taken")
	-- the fade on a frame above it (the screen slides in again)
	local ag = f:CreateAnimationGroup()
	local an = ag:CreateAnimation("Alpha")
	an:SetFromAlpha(0)
	an:SetToAlpha(1)
	an:SetDuration(0.3)
	ag:Play()
	w:advance(0.1)
	t:SetVertexColor(1, 1, 1, 0.2)
	eq(alphaOf(t), 0.8, "fading in: held")
	eq(askedOf(t), 0.2, "asked: 0.2")
	w:advance(0.5)
	eq(alphaOf(t), 0.8, "the fade ends: nothing repaints it")
	t:SetVertexColor(1, 1, 1, 0.2)
	eq(alphaOf(t), 0.2, "after the fade: taken")
	ok(((w.alphaKept or {})["?"] or 0) >= 1, "the held call is counted")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- the old top nav draws Drive lit on the Ride tab, as the game did (tour #1-17, #89)
---------------------------------------------------------------------------

local function topNav(old, how)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity",
		prepare = old and function(_, c) c.rewrite = oldCode({ "0aa37c2" }) end or nil })
	w:advance(15)
	local W = a.W
	W.db.coach = true
	T.openDrive(a)
	local UI = W.UI
	eq(UI.state.tab, "Drive", "on the Drive tab")
	eq(tabLit(W), "Drive", "Drive lit while open")
	UI.Toggle(false)
	w:advance(2)
	if how == "tour" then
		-- WuberLab's rider(): the window opened, then the Ride tab picked, in one frame
		UI.Toggle(true)
		UI.SelectTab("Ride")
	else
		-- the tab picked while the window is shut, then opened
		UI.SelectTab("Ride")
		UI.Toggle(true)
	end
	w:advance(3)
	eq(UI.state.tab, "Ride", "on the Ride tab")
	local got = tabLit(W)
	-- a click on Trips while open: the game drew that right with the old code too (tour #18-23)
	for _, tab in ipairs(UI.state.tabs) do if tab.name == "Trips" then a:clickOn(tab.button) end end
	w:advance(1)
	local trips = tabLit(W)
	T.clean(w)
	return got, trips
end

test("harness draw: B1 the old top nav draws Drive lit on the Ride tab, as the game did; today's lights Ride", function()
	for _, how in ipairs({ "tour", "shut" }) do
		local got, trips = topNav(true, how)
		if how == "tour" then
			-- the window's open animation (A.ZoomIn, an Alpha animation) holds the pills' alpha set in that frame
			eq(got, "Drive", "old code (tour): the game drew Drive lit, Ride clear")
		else
			-- picked while shut, no animation playing: the client takes the change (alpha probe, 20 Nov)
			eq(got, "Ride", "old code (shut): drawn right, as the client takes an alpha change on a hidden frame")
		end
		eq(trips, "Trips", "old code (" .. how .. "): a tab clicked while open was drawn right")
		got, trips = topNav(false, how)
		eq(got, "Ride", "today's code (" .. how .. "): Ride lit")
		eq(trips, "Trips", "today's code (" .. how .. "): Trips lit after a click")
	end
end)

---------------------------------------------------------------------------
-- the old Earnings pills draw Today lit while the totals say 7 days, as the game did (tour #47-#52)
---------------------------------------------------------------------------

local function earnings(old, seenBefore)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity",
		prepare = old and function(_, c) c.rewrite = oldCode({ "28a70b8", "441fcf8" }) end or nil })
	w:advance(15)
	local W = a.W
	W.db.coach = true
	T.openDrive(a)
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	if seenBefore then
		W.UI.ShowDrive("earnings")
		w:advance(1)
	end
	W.UI.ShowDrive("console")
	w:advance(1)
	local got = {}
	for shot = 1, 2 do
		-- WuberLab's earningsBase: the screen shown, then the range and the pill set, then a redraw, in one frame
		W.UI.ShowDrive("earnings")
		local e = W.UI.drive.screens.earnings
		e.range = "week"
		e.seg:SetValue("week")
		e.update()
		w:advance(2)
		eq(e.seg.value, "week", "the choice's value is 7 days")
		got[shot] = lit(e.seg.buttons, "value")
		W.UI.ShowDrive("console")
		w:advance(1)
	end
	T.clean(w)
	return got
end

test("harness draw: F5 the old Earnings pills draw Today lit under 7-day totals, as the game did; today's light 7 days", function()
	for _, seen in ipairs({ false, true }) do
		local when = seen and "Earnings seen before" or "first time"
		local old = earnings(true, seen)
		eq(old[1], "today", "old code, " .. when .. ": the game drew Today lit")
		eq(old[2], "today", "old code, " .. when .. ": and again on the next shot")
		local now = earnings(false, seen)
		eq(now[1], "week", "today's code, " .. when .. ": 7 days lit")
		eq(now[2], "week", "today's code, " .. when .. ": and on the next shot")
	end
end)

---------------------------------------------------------------------------
-- The photo tour itself (WuberLab), old and today's code: the pattern the game showed
---------------------------------------------------------------------------

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")

test("harness draw: the photo tour on the old code draws what the game drew (Drive lit on Ride, Trips and Drive right, Today lit on Earnings)", function()
	if not H.exists(LAB_DIR .. "/Photo.lua") then
		print("      skipped: WuberLab's Photo.lua not found at " .. LAB_DIR .. " (set WUBER_LAB_DIR)")
		return
	end
	local function tour(old)
		local w = T.newWorld()
		local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
			screenW = 1920, screenH = 1080, rewrite = old and oldCode({ "0aa37c2", "28a70b8", "441fcf8" }) or nil })
		T.settle(w)
		local W, L = c.W, c.ns.WuberLab
		local shots = {}
		c.env.Screenshot = function()
			c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end)
			local e = W.UI.drive and W.UI.drive.screens and W.UI.drive.screens.earnings
			shots[#shots + 1] = W.UI.state.tab .. ":" .. tabLit(W)
				.. ((e and e.seg:IsVisible()) and (" " .. lit(e.seg.buttons, "value")) or "")
		end
		-- as the player left it: the window shut on the Drive tab
		W.db.coach = true
		W.UI.Toggle(true)
		w:advance(2)
		W.UI.SelectTab("Drive")
		w:advance(1)
		W.UI.Toggle(false)
		w:advance(2)
		ok(L.TourStart({ only = { "home", "trips", "console_open", "earnings" } }), "the tour started")
		for _ = 1, 300 do
			if not L.Touring() then break end
			w:advance(1)
		end
		T.clean(w)
		return table.concat(shots, " | ")
	end
	-- the lab is loaded from LAB_DIR for these two tours only; H.ADDONS is put back whatever happens
	local before = H.ADDONS.WuberLab
	H.ADDONS.WuberLab = LAB_DIR
	local done, err = pcall(function()
		eq(tour(true), "Ride:Drive | Ride:Drive | Trips:Trips | Trips:Trips | Drive:Drive | Drive:Drive | Drive:Drive today | Drive:Drive today",
			"the old code, shot by shot (home, trips, console, earnings; folded, unfolded)")
		eq(tour(false), "Ride:Ride | Ride:Ride | Trips:Trips | Trips:Trips | Drive:Drive | Drive:Drive | Drive:Drive week | Drive:Drive week",
			"today's code, shot by shot")
	end)
	H.ADDONS.WuberLab = before
	if not done then error(err, 0) end
end)

---------------------------------------------------------------------------
-- FontString:IsTruncated, as the client answers it (the layout checker relies on it)
---------------------------------------------------------------------------

test("harness draw: IsTruncated is true when the client draws '...' (too wide unwrapped; more lines than the limit or the height)", function()
	local w = T.newWorld()
	local c = T.rider(w)
	w:advance(2)
	local env = c.env
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(200, 100)
	f:SetPoint("CENTER")
	local fs = f:CreateFontString(nil, "ARTWORK")
	fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
	fs:SetPoint("TOPLEFT", f, "TOPLEFT")
	-- 6 px a letter here (the harness's rough measure without the addon's font)
	fs:SetWidth(60)
	fs:SetWordWrap(false)
	fs:SetText("short")
	eq(fs:IsTruncated(), false, "fits on one line")
	fs:SetText("a much longer line")
	eq(fs:IsTruncated(), true, "wider than its width, no wrap: cut")
	eq(fs:GetText(), "a much longer line", "GetText keeps the whole text (the client only draws '...')")
	-- wrapping: the words go on more lines, no limit: nothing cut
	fs:SetWordWrap(true)
	eq(fs:IsTruncated(), false, "wraps onto more lines with no limit")
	fs:SetMaxLines(1)
	eq(fs:IsTruncated(), true, "more lines than SetMaxLines allows: cut")
	fs:SetMaxLines(0)
	fs:SetHeight(15)
	eq(fs:IsTruncated(), true, "more lines than its height holds: cut")
	fs:SetHeight(60)
	eq(fs:IsTruncated(), false, "room for the lines: not cut")
	-- one word wider than the width: cut even when it may wrap
	fs:SetText("abcdefghijklmnop")
	eq(fs:IsTruncated(), true, "a word wider than the width is cut")
	T.clean(w)
end)
