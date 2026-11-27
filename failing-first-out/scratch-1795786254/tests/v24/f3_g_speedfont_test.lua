-- Wuber 2.4 fix round 3, group G: PST-05 (the flight estimate's speed) and PST-03 (an edit box's own font object).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function fontKey(...) return table.concat({ tostring((...)), tostring((select(2, ...))), tostring((select(3, ...))) }, "|") end

test("v24 f3g: an uncalibrated flight estimate flies at 30 yards a second (4,558 recorded flights say 29.8), take-off 3 s", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W = r.W
	eq(W.FLY.SPEED, 30, "the estimate's speed")
	eq(W.FLY.TAKEOFF, 3, "take-off unchanged")
	local L = W.TAXI.lens
	local yards, delay
	for i = 1, #L - 3, 4 do if L[i] == 11 and L[i + 1] == 13 then yards, delay = L[i + 2], L[i + 3] end end
	ok(yards, "a length for Undercity to Tarren Mill")
	eq(W.FlightTime("Undercity", "Tarren Mill"), math.floor(yards / 30 + delay + 3 + 0.5), "yards / 30 + stops + 3 s, no learned flights")
	T.clean(w)
end)

test("v24 f3g: Wuber's two text fields give their edit box a font of its own, so the chat box keeps its font", function()
	H.shareEditFont = true
	local okRun, err = pcall(function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
		w:advance(15)
		local env = r.env
		local chat = env.ChatFrame1EditBox
		local before = fontKey(chat:GetFont())
		-- T.Field (Theme.Forms)
		local host = env.CreateFrame("Frame", nil, env.UIParent)
		host:SetSize(300, 200)
		local fld = r.W.Theme.Field(host, 200, 32, { max = 16 })
		eq(fontKey(chat:GetFont()), before, "T.Field left the chat box's font alone")
		ok(fld.edit:GetFont(), "the field has a font")
		-- the Where to? search (Rider.Cards)
		r.W.UI.Toggle(true)
		w:advance(3)
		r.W.UI.Show("home")
		w:advance(1.5)
		local home = r.W.UI.state.screens.home
		ok(home and home.search and home.search.edit, "the search field exists")
		eq(fontKey(chat:GetFont()), before, "the search left the chat box's font alone")
		ok(home.search.edit:GetFont(), "the search has a font")
		-- later size changes (the text-size setting) stay on the field
		r.W.Theme.SetFont(home.search.edit, 20, "bold")
		eq(fontKey(chat:GetFont()), before, "a later T.SetFont stays off the chat box")
		T.clean(w)
	end)
	H.shareEditFont = nil
	if not okRun then error(err, 0) end
end)
