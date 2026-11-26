-- Design round 1, group E: the driver screens use gold only for money; violet marks what is chosen or in progress,
-- grey is for facts, red is for warnings. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function rgbOf(d, token)
	local TH = d.W.Theme or d.W.T or d.W.UI.T
	return { TH.RGB(token) }
end
local function near(a, b) return math.abs(a[1] - b[1]) < 0.02 and math.abs(a[2] - b[2]) < 0.02 and math.abs(a[3] - b[3]) < 0.02 end
local function textIs(d, fs, token) local r, g, b = fs:GetTextColor() return near({ r, g, b }, rgbOf(d, token)) end

test("d1 e: a chosen set-up wizard option is a violet fill with ink words", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	local sc = d.W.Driver.ui.subs.wizard
	d:clickText("My friends help") w:advance(0.5)
	local on, off
	for _, c in ipairs(sc.choices) do if c.id == sc.choice then on = c else off = off or c end end
	ok(on and off, "control: one choice is picked, another is not")
	eq(on.bg.colour, "glow", "the picked option's fill is the violet token")
	ok(textIs(d, on.label, "ink"), "its title is ink")
	ok(textIs(d, on.sub2, "ink"), "its words are ink")
	ok(textIs(d, off.label, "white"), "an unpicked title stays white")
	eq(off.bg.colour, "card", "an unpicked option stays a card")
	on:GetScript("OnEnter")(on)
	on:GetScript("OnLeave")(on)
	eq(on.bg.colour, "glow", "hover on and off keeps the violet fill")
	T.clean(w)
end)

test("d1 e: Where I stand (the chosen summon-to part) is violet with ink words", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowSheet("sheet") w:advance(1)
	local fs = d:findText("Where I stand")[1]
	ok(fs, "the set-up sheet shows Where I stand")
	ok(textIs(d, fs, "ink"), "the chosen part's words are ink")
	local seg = d.W.Driver.ui.sheets.sheet and d.W.Driver.ui.sheets.sheet.where
	ok(seg, "control: the sheet keeps its summon-to control")
	for _, b in ipairs(seg.buttons) do
		if b.value == seg.value then eq(b.chosen.colour, "glow", "the chosen part's fill is the violet token") end
	end
	T.clean(w)
end)

test("d1 e: the queue's states and a returning rider's chip are not gold or amber", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	local D = d.W.Driver
	ok(D.STATE.summoning ~= "gold" and D.STATE.waiting ~= "gold", "summoning and waiting are violet (progress), not gold")
	ok(D.STATE.arrived ~= "amber", "arrived is not amber")
	local UI = d.W.Theme or d.W.T or d.W.UI.T
	local parent = d.env.CreateFrame("Frame", nil, d.env.UIParent)
	local r = { again = UI.Chip(parent, "", "white") }
	D.RideCount = function() return 2 end
	D.PaintAgain(r, { name = "Mia Tester" })
	ok(r.again.colour ~= "gold" and r.again.colour ~= "amber", "the '3rd ride with you' chip is not amber or gold, got " .. tostring(r.again.colour))
	eq(r.again.colour, "muted", "it is a grey fact")
	T.clean(w)
end)

test("d1 e: today's take stays gold (money)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	w:advance(1)
	local st = d.W.Driver.ui.console.status
	local gold = st and st.gold
	ok(gold, "control: the console's status line has its money text")
	ok(textIs(d, gold, "gold"), "the money line is gold")
	T.clean(w)
end)
