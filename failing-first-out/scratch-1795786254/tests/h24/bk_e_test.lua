local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function trips(n, narrow, wrap)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W, env = r.W, r.env
	if wrap then
		local realDate = env.date
		env.date = function(fmt, t)
			if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
			return realDate(fmt, t)
		end
	end
	local oct = os.time({ year = 2026, month = 10, day = 10, hour = 12, min = 0, sec = 0 })
	W.db.rides = {}
	for i = 1, n do
		W.db.rides[i] = { at = oct + i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.db.fold = { v = 1, pages = {}, narrow = narrow }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	return w, W, W.Mod("UI.Rider.Trips")
end

local function rel(tr, f)
	local c = tr.content:GetTop()
	return c - f:GetTop(), c - f:GetBottom()
end

-- guard: break-it, Wuber/UI/Rider/Trips.lua:237-310 (E3b-05 stack: title -4, hero -48, level -184, rule -298, chips 310;
-- breaks: hero back to -16 (B8), level to -152 (B16), rule to -266 (B15), chips to 278 (B7))
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 e bk: the Trips page stacks title, time saved, level card, rule and chips without overlap", function()
	local w, W, M = trips(11, true, false)
	local tr = M.view()
	local tT, tB = rel(tr, tr.title)
	local hT, hB = rel(tr, tr.hero)
	local lT, lB = rel(tr, tr.level)
	local rT, rB = rel(tr, tr.rule)
	local cT = rel(tr, tr.chips[1])
	ok(tr.chips[1]:IsShown(), "the first chip shows")
	ok(tB <= hT + 0.5, "title clear of time saved: " .. tB .. " / " .. hT)
	ok(hB <= lT + 0.5, "time saved clear of the level card: " .. hB .. " / " .. lT)
	ok(lB <= rT + 0.5, "level card clear of the rule: " .. lB .. " / " .. rT)
	ok(rB <= cT + 0.5, "rule clear of the first chip: " .. rB .. " / " .. cT)
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Rider/Trips.lua:307 (the Wrapped chip's y -10 changed to -18: it no longer stands on the title's line)
test("h24 e bk: the Wrapped chip stands on the title's line and clear of time saved", function()
	local w, W, M = trips(11, true, false)
	local tr = M.view()
	ok(tr.wrapChip:IsShown(), "the Wrapped chip shows")
	local tT, tB = rel(tr, tr.title)
	local cT, cB = rel(tr, tr.wrapChip)
	local hT = rel(tr, tr.hero)
	ok(math.abs((cT + cB) / 2 - (tT + tB) / 2) <= 5, "chip centre on the title's centre: " .. (cT + cB) / 2 .. " / " .. (tT + tB) / 2)
	ok(cB <= hT + 0.5, "chip clear of time saved")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Rider/Trips.lua:237 (the title built on the body instead of the scrolling page: it would stay while the page scrolls)
test("h24 e bk: the Trips title is part of the scrolling page", function()
	local w, W, M = trips(11, true, false)
	local tr = M.view()
	ok(tr.title:GetParent() == tr.content, "the title is a child of the scrolling page (clipped with it)")
	local t0 = tr.title:GetTop()
	tr.scroll, tr.scrollTarget = 50, 50
	tr.content:ClearAllPoints()
	tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, 50)
	ok(math.abs((tr.title:GetTop() - t0) - 50) < 0.5, "the title moved up with the page")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Rider/Trips.lua:791-796 (clipForCue forced false (B3), or the clip never re-anchored (B4): the page
-- would run under the cue pill when the Wrapped card reaches the cue's band)
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 e bk: with the cue up and the Wrapped card in its band, the page is cut 30 above the foot, and runs to the foot again after", function()
	local w, W, M = trips(6, true, true)
	local tr = M.view()
	tr.scroll, tr.scrollTarget = 0, 0
	tr.wrapTop = 420 -- a card low on the page (two rows of chips above it): its foot reaches the cue's band
	M.trimCells()
	ok(tr.cue:IsShown(), "the cue shows while content lies below")
	local foot = tr.body:GetBottom()
	ok(math.abs(tr.clip:GetBottom() - (foot + 30)) < 0.5, "page cut above the cue's band: " .. tr.clip:GetBottom() .. " vs " .. foot)
	ok(tr.clip:GetBottom() >= tr.cue:GetTop() - 0.5, "the page ends above the cue pill")
	tr.wrapTop = 100
	M.trimCells()
	ok(math.abs(tr.clip:GetBottom() - foot) < 0.5, "card out of the band: the page runs to the foot again")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Rider/Trips.lua:~761 (viewH: the body-height path dropped; the clip's own height used instead)
test("h24 e bk: the Trips view height follows the body when the clip itself reports no height of its own", function()
	local w, W, M = trips(11, true, false)
	local tr = M.view()
	tr.clipH = nil
	tr.clip.GetHeight = function() return 0 end -- the clip reports no height of its own
	tr.body.GetHeight = function() return 400 end
	M.fit()
	eq(tr.clipH, 400 - (W.UI.HEAD_ROW or 44), "view height from the body")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Rider/Trips.lua:~321 (the clip's OnUpdate: the body-height fallback dropped, so a changed body is not noticed)
test("h24 e bk: the Trips page refits when the body's height changes", function()
	local w, W, M = trips(11, true, false)
	local tr = M.view()
	tr.clipH = tr.clip:GetHeight() -- what the last pass measured
	tr.clip.GetHeight = function() return 0 end -- the clip reports no height of its own
	tr.body.GetHeight = function() return 400 end
	local onUpdate = tr.clip:GetScript("OnUpdate")
	ok(type(onUpdate) == "function", "the clip has its OnUpdate")
	onUpdate(tr.clip, 0.05)
	eq(tr.clipH, 400 - (W.UI.HEAD_ROW or 44), "refitted to the new body height")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Rider/Home.lua:1315-1327 (the gone-loop: ui.cards[key] = nil dropped, so a gone driver keeps its card
-- and the same card is handed to a new driver as well)
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 e bk: Home keeps one live card per driver, never lost or doubled, whatever lists were shown before", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(1)
	local UI = r.W.UI
	local home = UI.state.screens.home
	local function drv(name, dest, team)
		return { name = name, key = string.lower(name), dest = dest, price = 5000, state = "open", team = team }
	end
	local all = { drv("Anita Lift", "Undercity", 3), drv("Mia Runner", "Undercity", 3), drv("Bob Stone", "Ratchet", 1), drv("Ivy Moss", "Booty Bay", 2) }
	local function show(idx)
		local ds = {}
		for _, i in ipairs(idx) do ds[#ds + 1] = all[i] end
		r.W.drivers = {}
		for _, d in ipairs(ds) do r.W.drivers[d.key] = d end
		local list = UI.Drivers()
		UI.LayoutCards(home, list)
		local seen, n = {}, 0
		for key, c in pairs(UI.state.cards) do
			ok(not seen[c], "a card is held by two drivers: " .. key)
			seen[c] = key
			eq(c.key or key, key, "the card knows its driver")
			n = n + 1
		end
		eq(n, #list, "one card per driver in the list")
		for _, c in ipairs(UI.state.cardPool) do ok(not seen[c], "a pooled card is also in use") end
		for _, d in ipairs(list) do ok(UI.state.cards[d.key] and not UI.state.cards[d.key].off, "the card of " .. d.key .. " is live") end
	end
	show({ 1, 2, 3, 4 })
	show({ 2 })
	show({ 3, 4, 1 })
	show({})
	show({ 4, 2, 1, 3 })
	show({ 1 })
	T.clean(w)
end)
