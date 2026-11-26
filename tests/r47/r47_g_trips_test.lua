local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- C31r-1: a Trips chip that was half width stays half width (with shrunk text) when its words grow longer.
test("r47 g: the Spent chip stays half width with shrunk text after its words grow", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	local spent = 0
	W.Stats = function()
		return { rides = 5, places = 3, spent = spent, saved = 600, savedValue = 0, favouriteCount = 0,
			streakDays = 0, flightSaved = 0, flightRides = 0 }
	end
	local function show(copper)
		spent = copper
		W.UI.UpdateTrips() w:advance(1)
		local ch = tr.chips[3]
		return ch:IsShown(), ch:GetWidth(), ch.text.wuberPx, ch.text:GetText()
	end
	local LONG = 123450 -- 12g 34s 50c
	local s0, w0, px0, t0 = show(LONG)           -- control: the long words, chip built fresh
	ok(s0, "control: the Spent chip shows")
	local _, wHalf, _, tHalf = show(5000)        -- short words: half width
	local _, w1, px1, t1 = show(LONG)            -- the same long words again
	ok(wHalf < w0, "control: the short words get a half width chip (" .. wHalf .. " vs " .. w0 .. ")")
	eq(t1, t0, "same words")
	eq(w1, w0, "the chip for '" .. tostring(t1) .. "' is " .. tostring(w1) .. " wide with the text drawn at " .. tostring(px1)
		.. " px, but built fresh it is " .. tostring(w0) .. " wide at " .. tostring(px0) .. " px")
	T.clean(w)
end)


-- C31r-2: milestone cells are only checked against the whole view, not against the bottom band the
-- "Scroll for your trips / more" pill sits in, so a cell's name can sit under the pill.
test("r47 g: a milestone name is drawn under the visible scroll pill on the folded Trips tab", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	W.UI.UpdateTrips()
	local COLS, CELL_H = 4, 96
	local clipH = tr.clip:GetHeight()
	if not clipH or clipH < 2 then clipH = 544 end
	local KM = W.Mod("UI.Kit")
	local INNER, PAD = KM.INNER, KM.PAD
	local CELL_W = INNER / 4
	local hits, shownPill, control, first = 0, 0, 0, nil
	tr.scrollMax = math.max(0, tr.height - clipH)
	for y = 0, tr.scrollMax, 1 do
		tr.scroll, tr.scrollTarget = y, y
		M.trimCells()
		if tr.cue:IsShown() then
			shownPill = shownPill + 1
			local lo, hi = y + clipH - 30, y + clipH - 8
			for _, cell in ipairs(tr.cells) do
				if cell.m and cell:IsShown() then
					local row = math.floor((cell.index - 1) / COLS)
					local top = tr.gridTop + row * CELL_H
					local nameTop, nameBot = top + 60, top + 76 -- the name sits 60 px under the cell's top
					local cx0 = PAD + ((cell.index - 1) % COLS) * CELL_W
					local mid, half = (INNER + 2 * PAD) / 2, tr.cue:GetWidth() / 2
					if nameTop < hi and nameBot > lo and cx0 < mid + half and cx0 + CELL_W > mid - half then
						hits = hits + 1
						first = first or ("scroll " .. y .. ", milestone " .. tostring(cell.m.name))
					end
				end
			end
			if y == 0 then control = control + 1 end
		end
	end
	ok(shownPill > 0, "control: the pill shows while more lies below")
	eq(hits, 0, "a milestone name is drawn under the visible 'Scroll for...' pill (first at " .. tostring(first) .. "; " .. hits .. " scroll positions x cells)")
	T.clean(w)
end)
