-- Design round 1, group G: the text rules. Wrapped labels have line spacing (about 0.3 x the drawn size), text
-- inside the phone has no shadow (T.WorldText puts it back for text over the game world), and the three labels
-- that used the game's serif font use Wuber's font file.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- the shipped fonts' real metrics, as the layout check measures: lines wrap and count as in the game
local TL = dofile("tools/preview/textlayout.lua")
local function withMetrics(fn)
	local old = H.textMetrics
	H.textMetrics = TL
	local good, err = pcall(fn)
	H.textMetrics = old
	if not good then error(err, 0) end
end

local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r, r.W.Theme
end

local function inter(fs, what)
	local path = fs:GetFont()
	ok(type(path) == "string" and path:find("Wuber\\Media\\fonts\\Inter-", 1, true), what .. " uses Wuber's font file, got " .. tostring(path))
end
local function shadowed(fs)
	local x, y = fs:GetShadowOffset()
	local _, _, _, a = fs:GetShadowColor()
	return (x ~= 0 or y ~= 0) and a > 0
end

test("d1 g: a T.Text label has no shadow; T.WorldText gives one and a refit keeps it", function()
	local w, r, Th = rider()
	local fs = Th.Text(r.env.UIParent, 13)
	fs:SetText("Summon to Undercity")
	ok(not shadowed(fs), "no shadow inside the phone")
	local world = Th.WorldText(Th.Text(r.env.UIParent, 13))
	ok(shadowed(world), "T.WorldText: a shadow")
	local x, y = world:GetShadowOffset()
	local _, _, _, a = world:GetShadowColor()
	eq(x, 1, "x") eq(y, -1, "y") eq(a, 0.45, "45% black")
	Th.SetFont(world, 11)
	ok(shadowed(world), "still there after T.SetFont")
	Th.SetFont(fs, 11)
	ok(not shadowed(fs), "still none after T.SetFont")
	T.clean(w)
end)

test("d1 g: line spacing is about 0.3 x the drawn size, set with the font", function()
	local w, r, Th = rider()
	eq(Th.Text(r.env.UIParent, 13):GetSpacing(), 4, "13 gets 4")
	eq(Th.Text(r.env.UIParent, 11):GetSpacing(), 3, "11 gets 3")
	eq(Th.Text(r.env.UIParent, 10):GetSpacing(), 3, "10 is drawn at 11: 3")
	eq(Th.Spacing(13), 4, "T.Spacing(13)") eq(Th.Spacing("small"), 4, "T.Spacing('small'): small is 12, 0.3 x 12 rounds to 4")
	local fs = Th.Text(r.env.UIParent, 17)
	eq(fs:GetSpacing(), 5, "17 gets 5")
	Th.SetFont(fs, 13)
	eq(fs:GetSpacing(), 4, "a refit at 13 gets 4")
	T.clean(w)
end)

test("d1 g: a two-line label of size 14 is two lines and its spacing tall; one line is as tall as before", function()
	withMetrics(function()
		local w, r, Th = rider()
		local one = Th.Text(r.env.UIParent, "body")
		one:SetText("Summon")
		eq(one:GetStringHeight(), 14, "one line: 14, no spacing added")
		local fs = Th.Text(r.env.UIParent, "body")
		fs:SetWordWrap(true)
		fs:SetWidth(140) -- (job 2885) was 120: the text is drawn about 4% wider now (measured game widths), 120 holds only a word or two per line
		fs:SetText("A summon to Undercity, please")
		eq(fs:GetNumLines(), 2, "control: two lines")
		eq(fs:GetStringHeight(), 2 * 14 + 4, "two lines of 14 and one gap of 4")
		T.clean(w)
	end)
end)

test("d1 g: the fake game's wrapped label is lines x size + (lines - 1) x spacing tall, and a fixed height holds that many lines", function()
	local L = TL.layout("Inter-Regular.ttf", 10, "aa bb cc dd", { width = 20, spacing = 3 })
	eq(#L.lines, 4, "control: four lines")
	eq(L.height, 4 * 10 + 3 * 3, "height")
	eq(L.lineH, 13, "the step")
	eq(TL.layout("Inter-Regular.ttf", 10, "aa", { spacing = 3 }).height, 10, "one line: no spacing")
	local two = TL.layout("Inter-Regular.ttf", 10, "aa bb cc dd", { width = 20, spacing = 3, height = 23 })
	eq(#two.lines, 2, "23 high holds two lines (10 + 3 + 10)")
	eq(#TL.layout("Inter-Regular.ttf", 10, "aa bb cc dd", { width = 20, spacing = 3, height = 22 }).lines, 1, "22 high holds one")
end)

test("d1 g: T.Para's height counts the line spacing, and holds its text", function()
	local words = "Wuber only says what to type. The trade needs your own steps, and the driver sees the same words."
	local w, r, Th = rider()
	local p = Th.Para(r.env.UIParent, 11, "muted", 150)
	local one = p:SetPara("Short")
	eq(p.paraLines, 1, "control: one line")
	eq(one, math.ceil(11 * 1.32 + 1) + 2, "one line: the height it always had")
	local h = p:SetPara(words)
	local n = p.paraLines
	ok(n >= 3, "control: three lines or more (" .. n .. ")")
	eq(p:GetSpacing(), 3, "the paragraph has line spacing")
	eq(h, one + (n - 1) * (11 + 3), "each further line adds its size and the spacing")
	T.clean(w)
	withMetrics(function()
		local w2, r2, Th2 = rider()
		local q = Th2.Para(r2.env.UIParent, 13, "muted", 180)
		local hq = q:SetPara(words)
		ok(q:GetNumLines() >= 3, "control: wrapped in the fake game")
		ok(hq >= q:GetStringHeight(), "the box (" .. hq .. ") holds the text (" .. q:GetStringHeight() .. ")")
		T.clean(w2)
	end)
end)

test("d1 g: the sea arrow's label uses Wuber's font, with no shadow", function()
	local w, r = rider()
	local M = r.W.Mod("UI.Rider.SeaRoute")
	local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	f:SetSize(300, 200)
	local legs = { { cont = 1, to = 1, kind = "flight", pts = { 10, 10, 40, 30 } }, { cont = 1, to = 0, kind = "zeppelin", pts = { 80, 60, 300, 70 } } }
	local o = M.Draw(f, M.Arrow(M.Split(legs, 1), { x = 200 }))
	eq(o.label:GetText(), "continues by zeppelin", "control: the label")
	inter(o.label, "the sea arrow's label")
	ok(not shadowed(o.label), "inside the phone: no shadow")
	T.clean(w)
end)

test("d1 g: the alert banner and its counter use Wuber's font, with the world shadow; the banner grows by the text's step", function()
	local w = T.newWorld()
	local c = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	c.env.UIParent:SetSize(1024, 768)
	c.W.Drive.BellAlert("Anita: Summon Dan")
	w:advance(1)
	local b = c.env.WuberBell
	ok(b and b:IsShown(), "control: the banner is up")
	eq(b:GetHeight(), 120, "a short alert keeps the 120 high banner")
	for _, k in ipairs({ "text", "sub", "hint" }) do
		inter(b[k], "the banner's " .. k)
		ok(shadowed(b[k]), "the banner's " .. k .. " keeps a shadow (over the game world)")
	end
	local _, size = b.text:GetFont()
	eq(size, 28, "the alert is display, 28")
	local hr, hg, hb = b.hint:GetTextColor()
	eq(hr, 0.5, "the hint is still grey") eq(hg, 0.5, "g") eq(hb, 0.5, "b")
	local n = c.env.WuberBellCount
	if n then inter(n.text, "the counter") end
	w:advance(3)
	c.W.Drive.BellAlert("Anita: Three invites in a row went unanswered. If those players never saw one, invite by hand (/invite Name): they still become riders.")
	w:advance(1)
	local grew = b:GetHeight() - 120
	ok(grew > 0 and grew % (28 + b.text:GetSpacing()) == 0, "the banner grows by whole steps of 28 + spacing, grew " .. grew)
	T.clean(w)
end)

test("d1 g: the big button's words use Wuber's font and keep the world shadow", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local b = d.env.WuberDriveButton
	ok(b and b.title and b.sub, "control: the button and its words")
	inter(b.title, "the title") inter(b.sub, "the subtitle")
	ok(shadowed(b.title) and shadowed(b.sub), "both keep a shadow")
	T.clean(w)
end)
