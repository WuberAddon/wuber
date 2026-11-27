-- Design round 3, group P: the last cuts. The raid page's "Nobody summons yet" line wraps and the page below follows it;
-- Help's paragraphs are as tall as their lines (T.DrawnSize, T.Spacing); a Demand row's detail line sits 4 under the place.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	return w, a, a.W, a.W.Driver, a.W.Theme
end

test("d3 p: 'Nobody summons yet' wraps onto two lines on the raid page and the Raiders heading starts below it", function()
	local w, a, W, D, Th = world()
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(1)
	if #a:findText("Just open the console") > 0 then a:clickText("Just open the console") w:advance(1) end
	D.ShowScreen("console")
	w:advance(1)
	W.Drive.SetMode("raid")
	w:advance(1)
	D.Role = function() return "helper" end -- a helper has no Pick line in the checklist, so the strip says it
	W.Drive.Readiness = function() return { { ok = false, text = "Something else to put right" } } end
	D.RefreshNow()
	local H = T.H
	local fs, heads = nil, {}
	for _, obj in ipairs(a.widgets) do
		local st = H.state[obj]
		if st and st.otype == "FontString" and type(st.text) == "string" and H.visible(obj) then
			if st.text:find("Nobody summons yet", 1, true) then fs = obj end
			if st.text:find("Raiders", 1, true) then heads[#heads + 1] = obj end
		end
	end
	if not fs then print("DBG " .. table.concat(a:visibleTexts(), " | "):sub(1, 1200)) end
	ok(fs, "the line shows")
	local need = Th.MeasureText(fs.wuberText, "caption", "medium")
	ok(fs.wuberWrapped or need <= fs.wuberRoom, "it fits its " .. fs.wuberRoom .. " (needs " .. need .. ") or wraps")
	fs:SetWidth(need - 20) -- the side pane's 316 is a little narrower than the line needs (327)
	ok(fs.wuberWrapped, "in a room " .. (need - 20) .. " wide it wraps, on its two allowed lines")
	D.RefreshNow() -- (the page lays out again with the room it has)
	eq(fs.wuberPx, Th.SIZE.caption, "at the caption size, which is the floor")
	local _, _, _, _, ny = fs:GetPoint(1)
	local qy
	for _, h in ipairs(heads) do
		local _, _, _, _, y = h:GetPoint(1)
		if y and y < ny and (not qy or y > qy) then qy = y end
	end
	ok(qy, "a Raiders heading under it")
	local twoLines = 2 * Th.DrawnSize("caption") + Th.Spacing("caption")
	ok(ny - qy >= twoLines, "the heading starts " .. (ny - qy) .. " under the line's top; two lines need " .. twoLines)
end)

test("d3 p: a Help paragraph is as tall as its lines: n x drawn size + (n - 1) x line gap + 2, one line never under 1.2 x its size", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	r.W.UI.OpenHelp()
	w:advance(1)
	local texts = r.W.UI.settings.help.texts
	ok(#texts >= 9, "paragraphs: " .. #texts)
	local Th = r.W.Theme
	local multi = 0
	for _, e in ipairs(texts) do
		local n = e.lines
		local want = n * Th.DrawnSize(e.px) + (n - 1) * Th.Spacing(e.px) + 2
		local floor = math.ceil(n * e.px * 1.2)
		eq(e.h, math.max(want, floor), "'" .. e.text:sub(1, 24) .. "' is " .. n .. " line(s)")
		eq(e.fs:GetHeight(), e.h, "its font string has that height")
		if n >= 2 then multi = multi + 1 end
	end
	ok(multi >= 1, "at least one paragraph wraps, so the line gap is covered")
end)

test("d3 p: a Demand row's detail line is 4 under the place's line, not a gap of about 10", function()
	local _, a, _, D, Th = world()
	local card = D.DemandCard(a.env.UIParent, 320)
	local t0 = os.time()
	a.W.Bounty.Demand = function() return { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = t0 - 120 } } end
	card:Update()
	local row = card.rows[1]
	local _, _, _, _, py = row.place:GetPoint(1)
	local _, _, _, _, sy = row.sub:GetPoint(1)
	local gap = (py - sy) - Th.DrawnSize("body") - Th.Spacing("body")
	ok(gap <= 4 + 4, "the second line starts " .. (py - sy) .. " under the first one's top: " .. gap .. " px of air beyond the line's own box")
	ok(-sy + Th.DrawnSize("caption") + 4 <= row:GetHeight(), "and the row is tall enough for it")
end)
