-- Design round 2, group A: the list row. T.RowGroup is ONE card that holds rows; a row is 44 high with one line,
-- 56 with two and taller when its words wrap; a one-pixel divider between shown rows starts where the title starts.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local CLICK = 856

local function theme()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(2)
	return w, c.W.Theme, c.env, c
end
local function host(env)
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(400, 600)
	f:SetPoint("CENTER")
	return f
end
local function group(Th, env, width)
	local h = host(env)
	local g = Th.RowGroup(h, width or 328)
	g:SetPoint("TOPLEFT", h, "TOPLEFT", 16, -60)
	return g, h
end
local LONG = "Largest group Wuber may build for the riders who whisper you or post in a public channel you watch"

test("d2 a: T.RowGroup is one card with corner 14 in the card colour; a row is 44 with one line and 56 with two", function()
	local w, Th, env = theme()
	local g = group(Th, env)
	eq(g.bg.colour, "card", "the card colour")
	local one = g:Row({ title = "Riding" })
	local two = g:Row({ title = "Driving", sub = "Badge: none" })
	local h = g:Layout()
	eq(one:GetHeight(), 44, "one line: 44")
	eq(two:GetHeight(), 56, "two lines: 56")
	eq(h, 100, "the card is as high as its rows")
	eq(g.bg.parts.TL:GetWidth(), 14, "corner 14")
	eq(g:GetHeight(), 100, "and the frame has that height")
	eq(one:GetParent(), g, "rows live in the card: no card of their own")
	ok(one.bg == nil and two.bg == nil, "a row has no card fill of its own")
	T.clean(w)
end)

test("d2 a: a row grows when its words wrap: nothing is cut and nothing ends in dots", function()
	local w, Th, env = theme()
	local g = group(Th, env)
	local a = g:Row({ title = LONG, right = "switch" })
	local b = g:Row({ title = "Largest group", sub = LONG .. ". " .. LONG, right = "chevron" })
	g:Layout()
	ok(a:GetHeight() > 44, "a long title makes a one-line row taller than 44, got " .. a:GetHeight())
	ok(b:GetHeight() > 56, "a long second line makes the row taller than 56, got " .. b:GetHeight())
	eq(a.title:GetText(), LONG, "the title keeps every word")
	ok(not b.sub:GetText():find("%.%.%.$"), "no dots")
	ok(a.title:GetHeight() + 14 <= a:GetHeight(), "the wrapped title fits inside its row")
	ok(b.title:GetHeight() + b.sub:GetHeight() + 14 <= b:GetHeight(), "both wrapped lines fit inside the row")
	-- the words end before the control at the right
	ok(a.textX + a.title:GetWidth() <= 328 - 12 - 44, "the title ends before the switch")
	-- shorter words: back to 44
	a:SetTitle("Sound")
	eq(a:GetHeight(), 44, "44 again with short words")
	a:SetSub("Clicks and chimes")
	eq(a:GetHeight(), 56, "56 once it has a second line")
	T.clean(w)
end)

test("d2 a: one divider between shown rows, starting where the title starts; none after the last; hidden rows take no room", function()
	local w, Th, env = theme()
	local g = group(Th, env)
	local r1 = g:Row({ title = "Riding", icon = "ride", right = "chevron" })
	local r2 = g:Row({ title = "Driving", icon = "wheel", right = "chevron" })
	local r3 = g:Row({ title = "Map", icon = "pin", right = "chevron" })
	g:Layout()
	local function shown()
		local n = 0
		for _, r in ipairs(g.rows) do if r:IsShown() and r.divider:IsShown() then n = n + 1 end end
		return n
	end
	eq(shown(), 2, "three rows: two dividers")
	ok(not r3.divider:IsShown(), "none after the last row")
	eq(r1.divider:GetHeight(), 1, "one pixel")
	eq(r1.textX, 56, "with an icon the title starts at 56")
	ok(math.abs(r1.divider:GetLeft() - r1.title:GetLeft()) < 0.01, "the divider starts where the title starts")
	ok(math.abs(r1.divider:GetRight() - g:GetRight()) < 0.01, "and runs to the card's edge")
	eq(r1.disc:GetWidth(), 32, "a round 32 disc")
	local dr, dg, db, da = r1.disc:GetVertexColor()
	local v = Th.C.accent
	ok(math.abs(dr - v[1]) < 0.01 and math.abs(da - 0.18) < 0.01, "the disc is violet at 18%")
	r3:SetShown(false)
	eq(g:GetHeight(), 88, "a hidden row takes no room")
	eq(shown(), 1, "two rows shown: one divider")
	ok(not r2.divider:IsShown(), "the last SHOWN row has none")
	r1:SetShown(false)
	eq(g:GetHeight(), 44, "one row left")
	eq(shown(), 0, "and no divider")
	r1:SetShown(true)
	r3:SetShown(true)
	eq(g:GetHeight(), 132, "all three back")
	ok(r2:GetTop() < r1:GetTop() and r3:GetTop() < r2:GetTop(), "in the order they were made")
	local plain = Th.RowGroup(host(env), 328):Row({ title = "No icon" })
	eq(plain.textX, 16, "without an icon the title starts at 16")
	T.clean(w)
end)

test("d2 a: the control at the right: a grey chevron, T.Toggle, a grey value, a gold price, one small button", function()
	local w, Th, env = theme()
	local g = group(Th, env)
	local flips, clicks = {}, 0
	local chev = g:Row({ title = "Riding", right = "chevron" })
	local sw = g:Row({ title = "Sound", right = "switch", on = true, onChange = function(on) flips[#flips + 1] = on end })
	local val = g:Row({ title = "Window size", right = "value", value = "100%", chevron = true })
	local price = g:Row({ title = "Stormwind", right = "price", value = "12g" })
	local btn = g:Row({ title = "Window position", right = "button", value = "Reset", onClick = function() clicks = clicks + 1 end,
		tip = { title = "Window position", body = "Puts the window back in the middle." } })
	g:Layout()
	local function near(fs, name)
		local r, gg, b
		if fs.GetTextColor then r, gg, b = fs:GetTextColor() else r, gg, b = fs:GetVertexColor() end
		local c = Th.C[name]
		return math.abs(r - c[1]) < 0.01 and math.abs(gg - c[2]) < 0.01 and math.abs(b - c[3]) < 0.01
	end
	ok(chev.chevron and near(chev.chevron, "offText"), "a grey chevron")
	ok(sw.switch and sw.switch.on == true and sw.switch:GetWidth() == 44 and sw.switch:GetHeight() == 24, "the switch is T.Toggle, 44 x 24")
	sw.switch:Click()
	eq(flips[1], false, "the switch tells onChange")
	ok(near(val.value, "muted") and val.chevron ~= nil, "a grey value with a chevron")
	eq(val.value:GetText(), "100%", "the value's words")
	ok(near(price.value, "gold"), "a price is gold")
	ok(btn.button and btn.button.label:GetText() == "Reset", "one small button with its words")
	btn.button:Click()
	eq(clicks, 1, "the button runs onClick")
	eq(btn.button.wuberTip.text, "Puts the window back in the middle.", "the control carries the row's tooltip")
	eq(btn.wuberTip.text, "Puts the window back in the middle.", "and so does the row")
	val:SetValue("120%")
	eq(val.value:GetText(), "120%", "SetValue changes the words")
	-- the controls stay inside the card, 12 from its edge
	for name, r in pairs({ sw = sw.switch, btn = btn.button }) do
		ok(math.abs(g:GetRight() - r:GetRight() - 12) < 0.01, name .. ": 12 from the card's right edge")
	end
	T.clean(w)
end)

test("d2 a: a row that clicks is pressed like every control: the pressed fill and one click sound on mouse down", function()
	local w, Th, env, c = theme()
	local g = group(Th, env)
	local n = 0
	local row = g:Row({ title = "Riding", sub = "Auto-accept on", icon = "ride", right = "chevron", onClick = function() n = n + 1 end })
	local still = g:Row({ title = "Version", right = "value", value = "2.4" })
	g:Layout()
	ok(type(row.wuberPress) == "table", "T.Press is on the row")
	ok(still.wuberPress == nil, "a row with no onClick is not pressable")
	local before = #c.sounds
	row:GetScript("OnMouseDown")(row, "LeftButton")
	ok(row.wuberPressed, "pressed on mouse down")
	local heard = 0
	for i = before + 1, #c.sounds do if c.sounds[i] == CLICK then heard = heard + 1 end end
	eq(heard, 1, "one click sound, on mouse down")
	row:GetScript("OnMouseUp")(row, "LeftButton")
	row:Click()
	eq(n, 1, "onClick ran once")
	for i = before + 1, #c.sounds do if c.sounds[i] == CLICK then heard = heard + 1 end end
	eq(heard, 2, "the click handler adds no second sound")
	T.clean(w)
end)

test("d2 a: T.RowHeading is a quiet grey heading 8 above its card; a row can hold a control below its words", function()
	local w, Th, env = theme()
	local h0 = host(env)
	local g = Th.RowGroup(h0, 328)
	g:SetPoint("TOPLEFT", h0, "TOPLEFT", 16, -60)
	local below = env.CreateFrame("Frame", nil, h0)
	below:SetSize(200, 30)
	local r = g:Row({ title = "Wide pages", sub = "Some pages open out to two panes.", below = below })
	g:Layout()
	eq(r:GetHeight(), 56 - 6 + 30 + 12, "the row grows by what is below its words")
	eq(below:GetParent(), r, "and holds it")
	ok(below:GetBottom() >= r:GetBottom(), "inside the row")
	local head = Th.RowHeading(h0, "Most used", g)
	eq(head:GetText(), "Most used", "its words as given")
	eq(head.gap, 8, "gap 8")
	ok(math.abs(head:GetBottom() - g:GetTop() - 8) < 0.01, "8 above the card")
	local r1, g1, b1 = head:GetTextColor()
	local m = Th.C.muted
	ok(math.abs(r1 - m[1]) < 0.01 and math.abs(g1 - m[2]) < 0.01 and math.abs(b1 - m[3]) < 0.01, "grey")
	-- a search match: a wash that is soft violet and goes away
	r:Wash()
	ok(r.wash:IsShown(), "the wash shows")
	local _, part = next(r.wash.fill.parts)
	local _, _, _, a = part:GetVertexColor()
	ok(a < 0.3, "soft: under 30% violet, got " .. tostring(a))
	w:advance(3)
	ok(not r.wash:IsShown(), "and it has faded away after 3 s")
	T.clean(w)
end)
