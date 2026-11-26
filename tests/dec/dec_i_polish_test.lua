-- Decisions round, group I: the "off" grey passes the 4.5:1 bar, Wuber's own font on its two text fields (PST-03),
-- and every listed rider has a row on the Drive page (FAB-10). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function lum(c)
	local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end
local function contrast(a, b)
	local x, y = lum(a), lum(b)
	if x < y then x, y = y, x end
	return (x + 0.05) / (y + 0.05)
end

local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

test("dec i: the off grey reaches 4.5:1 on a card and on the window, and the violet button is untouched", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local C = a.W.Theme.C
	ok(contrast(C.off, C.card) >= 4.5, "off on card: " .. contrast(C.off, C.card))
	ok(contrast(C.off, C.black) >= 4.5, "off on black: " .. contrast(C.off, C.black))
	-- same hue family as before (6B6585): blue stays the largest channel, red the smallest
	ok(C.off[3] > C.off[1] and C.off[1] >= C.off[2], "still the violet-grey")
	eq(math.floor(C.accent[1] * 255 + 0.5), 0xA9, "accent unchanged")
end)

test("dec i: both Wuber text fields get a font object of their own (PST-03)", function()
	local w = T.newWorld()
	local a = T.rider(w, T.TESTCHAR)
	local W = a.W
	local T_ = W.Theme
	local seen = 0
	local box = CreateFrame and nil
	local eb = a.env.CreateFrame("EditBox", nil, a.env.UIParent)
	ok(T_.OwnFont(eb), "T.OwnFont gives a box its own font object")
	ok(eb.wuberOwnFont, "kept on the box")
	ok(not T_.OwnFont(eb), "the second call changes nothing")
	-- the two makers call it: Theme/Forms.lua (the form field) and UI/Rider/Cards.lua (the search box)
	for _, f in ipairs({ "Wuber/Theme/Forms.lua", "Wuber/UI/Rider/Cards.lua" }) do
		local h = io.open(f, "r")
		local src = h and h:read("*a") or ""
		if h then h:close() end
		ok(src:find('CreateFrame("EditBox"', 1, true) and src:find("T.OwnFont(", 1, true), f .. " makes an EditBox and calls T.OwnFont")
		seen = seen + 1
	end
	eq(seen, 2)
end)

local function rider(name)
	return { name = name, key = name:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
end

test("dec i: ten listed riders each have a row on the Drive page; no '+N more' (FAB-10)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 12 end
	local cs = {}
	for i = 1, 10 do cs[i] = rider("Rider" .. string.char(64 + i)) end
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return true end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local v = W.Driver.ui.console
	for _, i in ipairs({ 1, 8, 9, 10 }) do
		local r = v.rows[i]
		ok(r and r:IsShown(), "row " .. i .. " is shown")
		ok(r and r.c and r.c.name == cs[i].name, "row " .. i .. " is rider " .. i)
	end
	ok(not v.more:IsShown(), "no '+N more' line")
	for _, t in ipairs(a:visibleTexts()) do ok(not plain(t):find("^%+%d+ more"), "no more-line: " .. plain(t)) end
end)
