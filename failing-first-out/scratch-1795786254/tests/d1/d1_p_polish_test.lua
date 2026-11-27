-- Design round 1, group P: three polish points. Money beside a time is gold letters (a colour code round the
-- amount, the words unchanged); the Help cards' text starts at the card's margin and every card holds its
-- text; a glyph on a solid violet disc is ink.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local GOLD = "|cff" .. "%x%x%x%x%x%x"
local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function riderWorld(fly, cost)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.FlightCost = function() if cost then return cost, 1 end return nil end
	r.W.TravelSaved = function() return fly end
	r.W.db.tipPct = 10
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	return w, r
end
local function show(w, r, screen, key)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show(screen, key)
	w:advance(1.5)
	return r.W.UI.state.screens[screen]
end

test("d1 p: the Confirm pill puts the amount in gold: same words with the codes taken out", function()
	local w, r = riderWorld(100, 2300)
	local s = show(w, r, "confirm", "mia runner")
	local line = s.dial.line.wuberText
	ok(line:find("Net " .. GOLD .. "32s|r vs flying", 1), "net amount in gold: " .. line)
		-- r50 AU24-18: a worked-out flight time says about
	eq(plain(line), "Summon is about 1 min faster · Net 32s vs flying", "the words")
	local w2, r2 = riderWorld(600, nil)
	local s2 = show(w2, r2, "confirm", "mia runner")
	local l2 = s2.dial.line.wuberText
	ok(l2:find("worth about " .. GOLD .. "[^|]+|r of your time"), "worth in gold: " .. l2)
end)

test("d1 p: the booking sides carry their amounts in gold", function()
	local w, r = riderWorld(100, 2300)
	local s = show(w, r, "confirm", "mia runner")
	local d = s.dial
	ok(d.summonText.wuberText:find("^30 sec · costing " .. GOLD .. "55s|r"), "summon side: " .. d.summonText.wuberText)
	ok(d.flyText.wuberText:find("· costing " .. GOLD .. "23s|r$"), "fly side: " .. d.flyText.wuberText)
	eq(plain(d.summonText.wuberText), "30 sec · costing 55s", "the words")
end)

test("d1 p: UI.FlightLine writes gold amounts only when its coins flag is set", function()
	local w, r = riderWorld(100, 2300)
	r.W.FlightCost = function() return 2300, 1 end
	local UI = r.W.UI
	local a = UI.FlightLine("Undercity", false, 5000)
	local b = UI.FlightLine("Undercity", false, 5000, true)
	if a then
		ok(not a:find("|c"), "no code without the flag: " .. a)
		ok(b:find("costs " .. GOLD .. "23s|r") and b:find("really costs " .. GOLD .. "%d+s|r"), "gold with it: " .. tostring(b))
		eq(plain(b), a, "same words")
	end
end)

test("d1 p: Help's text starts at the card margin, takes the room to the right margin and no card is shorter than its text", function()
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenHelp("settings")
	w:advance(1)
	local help = c.W.UI.settings.help
	local n = 0
	for _, t in ipairs(help.texts) do
		local par = t.fs:GetParent()
		for i, card in ipairs(help.cards) do
			if par == card then
				n = n + 1
				local _, _, _, x, y = t.fs:GetPoint(1)
				eq(x, 14, "text at the margin")
				ok(card:GetWidth() - 14 - t.fs:GetWidth() <= 14.01, "room up to the right margin: " .. t.fs:GetWidth())
				ok(-y + t.h <= card:GetHeight() + 0.01, "card " .. i .. " holds its text")
			end
		end
	end
	ok(n >= 8, "the cards' paragraphs were checked: " .. n)
	local last = help.cards[#help.cards]
	local _, _, _, _, ly = last:GetPoint(1)
	ok(help.height >= -ly + last:GetHeight(), "the page's height follows")
end)

test("d1 p: the Confirm driver avatar's glyph is ink on the violet disc", function()
	local w, r = riderWorld(100, 2300)
	local s = show(w, r, "confirm", "mia runner")
	local g
	for _, v in pairs(s) do
		if type(v) == "table" and v.glyph and v.avatar then g = v.glyph end
	end
	ok(g, "found the glyph")
	local ink = r.W.Theme.C.ink
	local cr, cg, cb = g:GetVertexColor()
	ok(math.abs(cr - ink[1]) < 0.01 and math.abs(cg - ink[2]) < 0.01 and math.abs(cb - ink[3]) < 0.01, "ink, not white: " .. cr .. "," .. cg .. "," .. cb)
end)
