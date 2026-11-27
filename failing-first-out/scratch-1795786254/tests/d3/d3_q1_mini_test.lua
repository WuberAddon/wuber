-- Design round 3, group Q1 (the fix wave): the floating mini console is as wide as the big button. Its foot's two
-- pills are as wide as their own labels need when two equal pills would cut one ("Warlocks pause" beside "Close"),
-- the shard words stand between them, and only when even that is wider than the button does the console grow,
-- evenly on both sides. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function mini(shards)
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.Button.docked = nil
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	local s = { shards = shards, can = true, paused = false }
	D.FuelInfo = function() return s.shards, "accent", "tip", 1 end
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return s.paused end
	D.CanPause = function() return s.can end
	local function draw(width)
		DR.button:SetWidth(width)
		local m0 = a.W.UI.drive.mini
		if m0 then m0.dirty = true end
		D.UpdateMini()
		return a.W.UI.drive.mini
	end
	return w, a, s, draw, DR
end

-- every word of the foot whole, at its own size, the gauge clear of both pills, all inside the console
local function whole(a, m, tag)
	local SIZE = a.W.Theme.SIZE
	for _, pill in ipairs({ m.pause, m.close }) do
		local word = tostring(pill.label:GetText())
		ok(not pill.label:IsTruncated() and H.truncation(pill.label) == nil, "not cut: " .. word .. ", " .. tag)
		eq(pill.label.wuberPx, SIZE.sub, "at the pill's own size: " .. word .. ", " .. tag)
		local room = pill:GetWidth() - pill:GetHeight()
		ok(a.W.Theme.MeasureText(word, "sub", "medium") <= room + 0.01, "the pill holds its label and its padding: " .. word .. ", " .. tag)
	end
	eq(m.fuel.num.wuberPx, SIZE.caption, "the shard words at their own size: " .. tag)
	ok(H.truncation(m.fuel.num) == nil, "the shard words whole: " .. tag)
	ok(m.fuel:GetLeft() - m.pause:GetRight() >= 8 and m.close:GetLeft() - m.fuel:GetRight() >= 8, "8 clear each side of the gauge: " .. tag)
	ok(m.pause:GetLeft() >= m:GetLeft() + 7.99 and m.close:GetRight() <= m:GetRight() - 7.99, "the pills inside the console: " .. tag)
end

test("d3 q1 mini: at the tour's float size the console is exactly as wide as the button, the foot's words whole", function()
	local w, a, s, draw, DR = mini(23)
	local WIDTH = 340 -- Drive.Cast WIDTH: the floating button in the game and in the tour's float shots
	local cases = {
		{ can = false, shards = 23, pause = "Warlocks pause", gauge = "23 shards" }, -- float_cantpause, float_combat
		{ can = true, shards = 12, pause = "Pause", gauge = "12 shards" },
		{ can = true, paused = true, shards = 12, pause = "Resume", gauge = "12 shards" },
	}
	for _, c in ipairs(cases) do
		s.can, s.shards, s.paused = c.can, c.shards, c.paused == true
		local m = draw(WIDTH)
		local tag = c.pause .. " / " .. c.gauge .. " / Close"
		ok(m and m:IsShown() and m.pause:IsShown(), "the console: " .. tag)
		eq(m.pause.label:GetText(), c.pause, "the left pill")
		eq(m.fuel.num.wuberText, c.gauge, "the shard words")
		eq(m.close.label:GetText(), "Close", "the right pill")
		ok(math.abs(m:GetWidth() - WIDTH) < 0.01, "as wide as the button, " .. tag .. ": " .. tostring(m:GetWidth()))
		ok(math.abs(m:GetLeft() - DR.button:GetLeft()) < 0.01 and math.abs(m:GetRight() - DR.button:GetRight()) < 0.01,
			"its sides on the button's sides, " .. tag .. ": " .. tostring(m:GetLeft()) .. " to " .. tostring(m:GetRight())
				.. ", button " .. tostring(DR.button:GetLeft()) .. " to " .. tostring(DR.button:GetRight()))
		whole(a, m, tag)
		if c.can then
			ok(math.abs(m.pause:GetWidth() - m.close:GetWidth()) <= 0.5, "both labels fit equal pills, so the pills stay equal: " .. tag)
		else
			ok(m.pause:GetWidth() > m.close:GetWidth(), "the long label has the wider pill: " .. tag)
		end
	end
	T.clean(w)
end)

test("d3 q1 mini: a console that must be wider than the button grows evenly on both sides, and comes back", function()
	local w, a, s, draw, DR = mini(23)
	s.can = false -- "Warlocks pause": too long for the 240 floor beside "23 shards" and "Close"
	local m = draw(240)
	local grown = m:GetWidth() - 240
	ok(grown > 0, "wider than a 240 button: " .. tostring(m:GetWidth()))
	whole(a, m, "Warlocks pause at 240")
	local bl, br = DR.button:GetLeft(), DR.button:GetRight()
	ok(math.abs((bl - m:GetLeft()) - (m:GetRight() - br)) < 0.01,
		"the same on each side: " .. tostring(bl - m:GetLeft()) .. " left, " .. tostring(m:GetRight() - br) .. " right")
	-- the narrowest width that holds the words: one unit less and it grows, at it and above it does not
	local need = m:GetWidth()
	m = draw(need)
	ok(math.abs(m:GetWidth() - need) < 0.01, "a button of " .. need .. " holds the words: " .. tostring(m:GetWidth()))
	ok(need < 340, "the real button (340) is wider than the words need: " .. need)
	-- a shorter word again: the console is back at the button's width and place
	s.can = true
	m = draw(240)
	ok(math.abs(m:GetWidth() - 240) < 0.01, "Pause at 240: the button's width again: " .. tostring(m:GetWidth()))
	ok(math.abs(m:GetLeft() - DR.button:GetLeft()) < 0.01, "and its left side on the button's")
	whole(a, m, "Pause at 240")
	T.clean(w)
end)
