local T = ...
local test = T.test
-- guard: none (fails on base d632c1e7)
test("DS24-01: with the page cut above the cue, the Trips viewport is measured as the cut clip, not 30 taller", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W, env = r.W, r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	local oct = os.time({ year = 2026, month = 10, day = 10, hour = 12, min = 0, sec = 0 })
	W.db.rides = {}
	for i = 1, 6 do
		W.db.rides[i] = { at = oct + i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	tr.scroll, tr.scrollTarget = 0, 0
	tr.wrapTop = 420
	M.trimCells()
	assert(tr.cueClipped, "control: the page is cut above the cue")
	-- the real client: frame methods are not raw keys on the frame (they come from the metatable)
	local clip = tr.clip
	local real = {}
	for _, k in ipairs({ "GetHeight" }) do real[k] = clip[k]; rawset(clip, k, nil) end
	if rawget(clip, "GetHeight") == nil and clip.GetHeight == nil then
		setmetatable(clip, { __index = function(_, k) return real[k] end })
	end
	assert(rawget(clip, "GetHeight") == nil, "control: GetHeight is not a raw key")
	tr.clipH = nil
	M.fit()
	local h = clip:GetHeight()
	assert(h and h > 1, "control: clip has a height " .. tostring(h))
	assert(math.abs(tr.clipH - h) < 0.5, "viewport measured " .. tostring(tr.clipH) .. " but the clip is " .. tostring(h))
	-- the promise: the last row can always be scrolled fully into view (cut or not)
	assert(tr.scrollMax >= (tr.height or 0) - h - 0.5, "scroll range " .. tostring(tr.scrollMax) .. " short of " .. ((tr.height or 0) - h))
	T.clean(w)
end)

-- guard: uncut page (no Wrapped card in the cue band) keeps scroll range = page height less the view
test("DS24-01 guard: an uncut Trips page scrolls by page height less the clip", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.db.rides = {}
	for i = 1, 12 do W.db.rides[i] = { at = os.time({ year = 2026, month = 11, day = 17, hour = 12, min = 0, sec = 0 }) - i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 } end
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	tr.wrapTop = nil
	M.trimCells()
	tr.cueClipped = nil
	M.fit()
	local want = math.max(0, (tr.height or 0) - tr.clipH)
	assert(math.abs(tr.scrollMax - want) < 0.5, "scrollMax " .. tostring(tr.scrollMax) .. " want " .. want)
	T.clean(w)
end)
