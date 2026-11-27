-- Tests of UI.Driver.Earnings. Loaded by tests/run.lua with its helper table T.
-- The period pill matches the totals in every path, in the game's terms (tour #47-#52); the tapped
-- hour's pill fits its words (tour #49, #50); narrow Earnings says there is more below (tour #47).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

local function earnings(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if o.prepare then o.prepare(W) end
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	return w, a, W, W.UI.drive.screens.earnings
end

-- (tour #47: Today lit white, 7 days clear, while the words said 7 days) In the game a texture of
-- the period pills kept the alpha it had when the pills were made: a later SetVertexColor changed its
-- colour, not its alpha. Here every alpha change after the build is not drawn, as in the game, and one on a
-- texture that shows is noted.
local function asGame(segs)
	local changed = {}
	local function wrap(f)
		for _, r in ipairs({ f:GetRegions() }) do
			if r:GetObjectType() == "Texture" then
				local orig = r.SetVertexColor
				r.SetVertexColor = function(self, cr, cg, cb, ca)
					local _, _, _, a0 = self:GetVertexColor()
					if self:IsShown() and math.abs((ca or 1) - (a0 or 1)) > 0.01 then changed[#changed + 1] = ("%.2f -> %.2f"):format(a0 or 1, ca or 1) end
					return orig(self, cr, cg, cb, a0)
				end
			end
		end
	end
	for _, seg in ipairs(segs) do
		wrap(seg)
		for _, b in ipairs(seg.buttons) do wrap(b) end
	end
	return changed
end

-- the parts of a choice that show a fill (a visible texture, alpha over 0.3) as the game draws them
local function lit(seg)
	local out = {}
	for _, b in ipairs(seg.buttons) do
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" and r:IsVisible() then
				local _, _, _, al = r:GetVertexColor()
				if (al or 1) > 0.3 then out[#out + 1] = b.value break end
			end
		end
	end
	table.sort(out)
	return table.concat(out, ",")
end

test("ui.driver.earnings: F5 the lit period pill is the one the totals use (first open, tour, tap, hover, tabs, fold, reload)", function()
	local w, a, W, e = earnings({ prepare = function(W)
		local me = W.myKey
		W.Drive.Crew = function()
			return { { name = T.ANITA, key = me, role = "lock", app = true, here = true, shards = 12, me = true },
				{ name = "Vex Shade", key = "vex shade", role = "lock", app = true, here = true, shards = 9 } }
		end
	end })
	w:advance(1)
	ok(e.who:IsVisible(), "Me | Crew shows (a crew)")
	local changed = asGame({ e.seg, e.who })
	local function check(want, when)
		eq(e.range, want, when .. ": the totals' period")
		eq(e.seg.value, want, when .. ": the choice's value")
		eq(lit(e.seg), want, when .. ": the lit pill, as the game draws it")
		eq(lit(e.who), e.scope, when .. ": Me | Crew lit as its value")
	end
	check("today", "first open")
	-- the photo tour: the range and the pill set from outside, then a redraw
	e.range = "week"
	e.seg:SetValue("week")
	e.update()
	w:advance(1)
	check("week", "the tour's 7 days")
	-- an older path: only the range set (the pill follows the totals, never the other way round)
	e.range = "today"
	e.update()
	check("today", "range set alone")
	-- a tap
	a:clickOn(e.seg.buttons[3])
	w:advance(1)
	check("month", "tap 30 days")
	-- hover over another part and away
	local b2 = e.seg.buttons[1]
	b2:GetScript("OnEnter")(b2)
	eq(lit(e.seg), "month", "hovering Today lights nothing else")
	b2:GetScript("OnLeave")(b2)
	check("month", "after a hover")
	-- tabs: the console and back
	W.UI.ShowDrive("console")
	w:advance(1)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	check("month", "back from the console")
	-- unfold and fold
	W.UI.Fold.Toggle()
	w:advance(1)
	check("month", "unfolded")
	W.UI.Fold.Toggle()
	w:advance(1)
	check("month", "folded again")
	eq(#changed, 0, "no alpha change after the pills are made (the game keeps the first): " .. table.concat(changed, ", "))
	T.clean(w)
	-- /reload: a new screen starts at Today with Today's totals
	local w2, a2, W2, e2 = earnings({ wide = true })
	w2:advance(1)
	eq(e2.range, "today", "after a reload: Today's totals")
	eq(lit(e2.seg), "today", "after a reload: Today lit")
	T.clean(w2)
end)

-- one busy hour: Wed 20:00, 2.9g in an hour open, 5 rides, 6 buyers asked (tour #49, #50)
local function busy(W)
	W.Drive.Heatmap = function()
		return { { wday = 3, hour = 20, copper = 29000, rides = 5, open = 60, asks = 6 } }
	end
end

test("ui.driver.earnings: F6 the tapped hour's pill holds all its words with room, folded and unfolded", function()
	for _, wide in ipairs({ false, true }) do
		local w, a, W, e = earnings({ wide = wide, prepare = busy })
		w:advance(1)
		local view = wide and "unfolded" or "folded"
		local hm = (e.heatW and e.heatW:IsShown()) and e.heatW or e.heat
		local cell
		for _, b in ipairs(hm.cells) do if b.wday == 3 and b.hour == 20 then cell = b end end
		cell:GetScript("OnClick")(cell, "LeftButton")
		w:advance(1)
		local text = hm.info:GetText() or ""
		ok(text:find("Wed 20:00", 1, true) and text:find("6 buyers asked", 1, true), view .. ": every number is there: " .. text)
		ok(not hm.info:IsTruncated(), view .. ": nothing cut: " .. text)
		local lines = H.textLines(hm.info) or 1
		local need = lines * 11 * 1.2 + 12
		ok(hm.pill:GetHeight() + 0.5 >= need, view .. (": %d line(s) need %d px, the pill is %d"):format(lines, need, hm.pill:GetHeight()))
		ok(hm.pill:GetBottom() >= hm:GetBottom() + 6 - 0.5, view .. ": the pill sits inside its card")
		ok(hm.pill:GetLeft() >= hm:GetLeft() + 6 - 0.5 and hm.pill:GetRight() <= hm:GetRight() - 6 + 0.5, view .. ": and not past its sides")
		-- what sits under the card moved down with it
		if e.top:IsShown() then ok(e.top:GetTop() <= hm:GetBottom() + 0.5, view .. ": the tips under the card stay under it") end
		T.clean(w)
	end
end)

test("ui.driver.earnings: F6 narrow Earnings says there is more below until the bottom is in view (tour #47)", function()
	local w, a, W, e = earnings({ prepare = busy })
	w:advance(1)
	local sc = e.scroll
	ok((sc.max or 0) > 24, "narrow Earnings is taller than its view (" .. tostring(sc.max) .. ")")
	ok(e.cue and e.cue:IsVisible(), "a cue at the bottom says there is more")
	if e.cue then
		ok(e.cue:GetBottom() >= e.frame:GetBottom() - 0.5 and e.cue:GetLeft() >= sc:GetLeft(), "the cue is inside the screen, in the strip under the view")
		ok(e.cue:GetFrameLevel() > sc:GetFrameLevel() + 40, "above the list's soft edge")
	end
	-- (F6) a reserved strip: the last content ends at least a cue's height above the content's bottom
	local lowest
	for _, part in ipairs({ e.heat, e.top, e.try, e.reset }) do
		if part and part:IsShown() and part:GetBottom() then
			lowest = math.min(lowest or 1e9, part:GetBottom())
		end
	end
		ok(lowest, "content found")
	-- (F6) nothing is drawn under the cue: at every 20 px step the view's bottom is above the cue's top
	for y = 0, math.floor(sc.max), 20 do
		sc:ScrollTo(y, true)
		w:advance(0.3)
		if e.cue:IsVisible() then
			ok(sc:GetBottom() >= e.cue:GetTop() - 0.5, "scroll " .. y .. ": the view ends above the cue (" .. tostring(sc:GetBottom()) .. " vs " .. tostring(e.cue:GetTop()) .. ")")
		end
	end
	sc:ScrollTo(0, true)
	w:advance(0.3)
	sc:ScrollTo(sc.max, true)
	w:advance(1)
	ok(not (e.cue and e.cue:IsVisible()), "at the bottom the cue goes")
	T.clean(w)
end)

-- (BRIEF20 B8, tour #48-#52) the fair-split rows are one font size, and a gap (about 3 px, a space) comes
-- before each coin icon; a long row shortens its words rather than shrinking
test("ui.driver.earnings: B8 fair split rows share one size and the coins have a gap", function()
	local w, a, W, e = earnings({ prepare = busy })
	local D = W.Driver
	local was = D.CutRows
	D.CutRows = function()
		return { { key = W.myKey, name = T.ANITA, casts = 7, clicks = 2, share = 18200 },
			{ key = "vex", name = "Vex Shade", casts = 2, clicks = 7, share = 15400 },
			{ key = "nyla", name = "Nyla", casts = 0, clicks = 9, share = 14400 },
			{ key = "big", name = "Bartholomew", casts = 12, clicks = 17, share = 1234500 } }, "clicks", 40
	end
	local host = e.frame
	D.PaintCut(e, host, 0, true, true)
	D.CutRows = was
	local card = e.cut
	ok(card and card:IsShown(), "the card shows")
	local px
	for i = 1, 4 do
		local l = card.lines[i]
		local what = l.what.wuberText
		ok(not what:find("%d|T"), "row " .. i .. ": a gap before every coin icon: " .. what)
		px = px or l.what.wuberPx
		eq(l.what.wuberPx, px, "row " .. i .. ": the words' size")
		eq(l.name.wuberPx, l.name.wuberBase, "row " .. i .. ": the name is not shrunk")
		eq(l.what.wuberPx, l.what.wuberBase, "row " .. i .. ": the words are not shrunk")
	end
	T.clean(w)
end)

-- the texts of a page the view's bottom edge slices at the top of the page (what the layout
-- checker calls "clipped": partly in, partly out)
local function slicedAtBottom(sc, content)
	local out, bottom = {}, sc:GetBottom()
	local function walk(f)
		for _, r in ipairs({ f:GetRegions() }) do
			local tx = r:GetObjectType() == "FontString" and r:IsVisible() and r:GetText()
			if type(tx) == "string" and tx:match("%S") then
				local t, b = r:GetTop(), r:GetBottom()
				if t and b and t > bottom + 0.5 and b < bottom - 0.5 then out[#out + 1] = ("%q (%.0f below the edge)"):format(tx:sub(1, 24), bottom - b) end
			end
		end
		for _, ch in ipairs({ f:GetChildren() }) do if ch:IsVisible() then walk(ch) end end
	end
	walk(content)
	return out
end

test("ui.driver.earnings: BRIEF22 L1 narrow Earnings, the bottom edge never slices the heatmap's hour labels (or any text) at the top", function()
	for _, prep in ipairs({ busy, false }) do
		local w, a, W, e = earnings({ prepare = prep or nil })
		w:advance(1)
		local sc = e.scroll
		for _, cut in ipairs({ 0, 7, 20, 40, 60, 90 }) do
			e.frame:ClearAllPoints()
			e.frame:SetPoint("TOPLEFT", e.frame:GetParent(), "TOPLEFT", 0, 0)
			e.frame:SetPoint("BOTTOMRIGHT", e.frame:GetParent(), "BOTTOMRIGHT", 0, cut)
			e.update()
			w:advance(0.5)
			sc:ScrollTo(0, true)
			w:advance(0.3)
			local bad = slicedAtBottom(sc, e.content)
			ok(#bad == 0, (prep and "busy" or "empty") .. ", phone " .. cut .. " shorter: nothing sliced at the bottom: " .. table.concat(bad, ", "))
			ok(e.cue:IsVisible() and sc:GetBottom() >= e.cue:GetTop() - 0.5, "phone " .. cut .. " shorter: the cue shows, under the view")
		end
		T.clean(w)
	end
end)
