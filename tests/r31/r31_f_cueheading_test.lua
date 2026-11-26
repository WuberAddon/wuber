local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-90: on the folded Trips screen the "Scroll for your trips" pill never covers the "Milestones" or
-- "Your trips" heading: a heading its band would touch is hidden whole (as a trip row is), the pill stays.

test("r31 f cue heading: no visible heading under the visible pill, the pill stays, headings come back", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Trips")
	w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	W.UI.UpdateTrips()
	-- the real view's height varies with the window and its scale: try several
	local clashes, mHidden, hHidden, mBack, hBack, pill0 = 0, 0, 0, 0, 0, 0
	for _, clipH in ipairs({ 340, 380, 420, 460, 500, 544 }) do
		-- a real clip cut 30 above the foot (tr.cueClipped) reports its true, 30-shorter height (DS24-01)
		tr.clip.GetHeight = function() return clipH - (tr.cueClipped and 30 or 0) end
		tr.scrollMax = math.max(0, tr.height - clipH)
		for y = 0, tr.scrollMax, 2 do
			tr.scroll, tr.scrollTarget = y, y
			M.trimCells()
			local lo, hi = y + clipH - 30, y + clipH - 8
			local mb = { tr.gridTop - 32, tr.gridTop - 6 }
			local hb = { tr.histTop, tr.histTop + 26 }
			local mm = mb[1] < hi and mb[2] > lo
			local hm = hb[1] < hi and hb[2] > lo
			if tr.scrollMax - y > 1 then
				ok(tr.cue:IsShown(), "the pill shows whenever there is more below (h=" .. clipH .. " y=" .. y .. ")")
				if y == 0 then pill0 = pill0 + 1 end
			end
			if tr.cue:IsShown() then
				if tr.mHead:IsShown() and mm then clashes = clashes + 1 end
				if tr.hHead:IsShown() and hm then clashes = clashes + 1 end
			end
			if not tr.mHead:IsShown() then mHidden = mHidden + 1 elseif not mm then mBack = mBack + 1 end
			if not tr.hHead:IsShown() then hHidden = hHidden + 1 elseif not hm then hBack = hBack + 1 end
		end
	end
	eq(clashes, 0, "no visible heading under the visible pill")
	ok(pill0 > 0, "the pill shows at scroll 0")
	ok(mHidden > 0 and hHidden > 0, "control: each heading is hidden somewhere while the pill would touch it")
	ok(mBack > 0 and hBack > 0, "each heading is visible again when scrolled clear of the band")
end)
