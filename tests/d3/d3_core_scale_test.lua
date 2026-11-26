-- Design round 3, the lead's core: seven text sizes and no others (T.SIZE, T.SCALE, T.Snap). A number that still
-- reaches the theme is drawn and measured at a scale size; a label T.Fit shrinks steps down the scale.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local SEVEN = { hero = 40, display = 28, title = 22, heading = 17, body = 14, sub = 12, caption = 11 }
local ON = { [11] = true, [12] = true, [14] = true, [17] = true, [22] = true, [28] = true, [40] = true }

local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r, r.W.Theme
end
local function sizeOf(fs)
	local _, size = fs:GetFont()
	return size
end

test("d3 core: T.SIZE holds the seven sizes; small and price are older names for sub and title", function()
	local _, _, Th = rider()
	for name, px in pairs(SEVEN) do eq(Th.SIZE[name], px, name) end
	eq(Th.SIZE.small, Th.SIZE.sub, "small is sub")
	eq(Th.SIZE.price, Th.SIZE.title, "price is title")
	local n = 0
	for _ in pairs(Th.SIZE) do n = n + 1 end
	eq(n, 9, "seven names and two older ones, nothing else")
	eq(#Th.SCALE, 7, "seven sizes on the scale")
	for name in pairs(Th.SIZE) do ok(Th.WEIGHT[name], name .. " has a weight") end
end)

test("d3 core: any number is snapped to one of the seven, in order, with 11 as the floor", function()
	local _, _, Th = rider()
	local last = 0
	for px = 1, 80 do
		local got = Th.Snap(px)
		ok(ON[got], px .. " snaps onto the scale, got " .. tostring(got))
		ok(got >= last, px .. " never snaps under a smaller number's size")
		last = got
		eq(Th.DrawnSize(px), got, "DrawnSize(" .. px .. ")")
	end
	local want = { [8] = 11, [10] = 11, [11] = 11, [12] = 12, [13] = 14, [15] = 14, [16] = 17, [19] = 17, [20] = 22, [23] = 22,
		[24] = 28, [34] = 28, [35] = 40, [46] = 40, [54] = 40 }
	for px, to in pairs(want) do eq(Th.Snap(px), to, "Snap(" .. px .. ")") end
	eq(Th.Snap(nil), 14, "no number: body")
	eq(Th.Snap(12.5), 14, "a fraction goes up to the next size")
end)

test("d3 core: a label is drawn at a scale size whatever it asks for, and measured at the same size", function()
	local _, r, Th = rider()
	for _, ask in ipairs({ 8, 9, 10, 13, 15, 16, 18, 20, 24, 26, 30, 46, 54, "body", "small", "price", "caption", "hero" }) do
		local fs = Th.Text(r.env.UIParent, ask, nil, nil, "medium")
		fs:SetText("Summon to Undercity")
		ok(ON[sizeOf(fs)], tostring(ask) .. " is drawn on the scale, got " .. tostring(sizeOf(fs)))
		eq(fs.wuberPx, sizeOf(fs), tostring(ask) .. ": remembered as drawn")
		eq(Th.MeasureText("Summon to Undercity", ask, "medium"), Th.MeasureText("Summon to Undercity", sizeOf(fs), "medium"), tostring(ask) .. ": measured as drawn")
	end
	eq(Th.Spacing(13), Th.Spacing("body"), "line spacing follows the drawn size")
end)

test("d3 core: a label T.Fit shrinks goes down the scale (14, 12, 11), never to a size between", function()
	local _, r, Th = rider()
	local text = "Summon to Undercity for a fair price"
	local full = Th.MeasureText(text, "body", "medium")
	local seen = {}
	for room = math.floor(full * 1.2), math.floor(full * 0.6), -3 do
		local fs = Th.Text(r.env.UIParent, "body", nil, nil, "medium")
		fs:SetWidth(room)
		fs:SetText(text)
		local px = sizeOf(fs)
		ok(ON[px], "room " .. room .. ": drawn on the scale, got " .. tostring(px))
		ok(px >= 11, "room " .. room .. ": never under 11")
		seen[px] = true
	end
	ok(seen[14], "with room it stays body")
	ok(seen[12], "a little short of room: sub")
	ok(seen[11], "shorter still: caption")
	local cap = Th.Text(r.env.UIParent, "caption", nil, nil, "medium")
	cap:SetWidth(20)
	cap:SetText(text)
	eq(sizeOf(cap), 11, "a caption has nowhere smaller to go")
end)
