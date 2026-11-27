local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["H24-01"] = true, ["H24-02"] = true, ["H24-03"] = true, ["H24-04"] = true, ["H24-05"] = true, ["H24-08"] = true, ["H24-15"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_H24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local function overlap(a, b)
	return a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
end

-- Promise: the "Scroll for ..." cue never lies over a word of the page. The 2.4.1 big page title ("Trips" at display
-- size) makes the view shorter, and the first row of milestones is kept "even if the view is tiny", so on the
-- folded Trips tab at the top the cue sits over the names "5 Rides" and "10 Rides".
proof("H24-01", "the Trips scroll cue covers no milestone name at the top of the folded page", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	-- a rider with some history (the tour's: 11 rides, 2 places): the page is long enough for the cue to show
	W.Stats = function() return { rides = 11, places = 2, spent = 55000, saved = 6600, savedValue = 54000, favouriteCount = 1,
		favourite = "Mia", favouriteRides = 9, streakDays = 0, flightSaved = 0, flightRides = 0 } end
	W.UI.UpdateTrips() w:advance(1)
	tr.scroll, tr.scrollTarget = 0, 0
	M.trimCells()
	ok(tr.cue:IsShown(), "control: the cue shows at the top (more lies below)")
	local function scan()
		local cue = H.rect(tr.cue)
		local seen, hits = 0, {}
		for _, cell in ipairs(tr.cells) do
			if cell.m and cell:IsShown() and H.visible(cell.name) then
				seen = seen + 1
				if overlap(H.rect(cell.name), cue) then hits[#hits + 1] = tostring(cell.m.name) end
			end
		end
		return seen, hits
	end
	local _, hits0 = scan()
	eq(#hits0, 0, "at scroll 0 the cue covers milestone names: " .. table.concat(hits0, ", "))
	-- r50 H24-01: the first row hides under the cue at scroll 0; scrolled until it shows, names are drawn and uncovered
	tr.scroll, tr.scrollTarget = 100, 100
	tr.content:ClearAllPoints()
	tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, 100)
	M.trimCells()
	ok(tr.cue:IsShown(), "control: the cue still shows after scrolling")
	local seen, hits = scan()
	ok(seen > 0, "control: milestone names are drawn once the first row shows")
	eq(#hits, 0, "the cue covers milestone names: " .. table.concat(hits, ", "))
	T.clean(w)
end)

-- Promise (E3b-01): no page word is cut by the sheet's edge while the Report a bug sheet is up. 2.4.1 draws the
-- root pages' titles big on the page (E3b-05), just under the header zone, and the sheet's top edge is the header
-- zone's foot: "Settings" is half under the sheet card, only the tops of its letters show.
local function texts(f, out, seen)
	out, seen = out or {}, seen or {}
	if seen[f] then return out end
	seen[f] = true
	for _, r in ipairs({ f:GetRegions() }) do
		if r.GetText and r:GetText() == "Settings" and H.visible(r) then out[#out + 1] = r end
	end
	for _, c in ipairs({ f:GetChildren() }) do texts(c, out, seen) end
	return out
end

proof("H24-02", "the Report a bug sheet does not cut the big Settings title in two", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	UI.OpenSettings() w:advance(3)
	local big = texts(UI.state.win)
	ok(#big > 0, "control: the big Settings title is drawn")
	ok(UI.Bug.Open(), "the report opens") w:advance(2)
	local card = H.rect(UI.Bug.frame.card)
	local cardTop = card.b + card.h
	for _, t in ipairs(big) do
		local tr = H.rect(t)
		local top, bot = tr.b + tr.h, tr.b
		ok(not (top > cardTop + 0.5 and bot < cardTop - 0.5),
			("the title is cut by the sheet's top edge (title %.1f to %.1f, sheet top %.1f)"):format(bot, top, cardTop))
	end
	T.clean(w)
end)
