-- Design round 4, group A: the Ride screen's portal is ONE still picture (Media/portal_still.tga) that the game turns in
-- place: one full turn every 8 s, anticlockwise; Reduce motion stops it; a founder's summon is the same picture in gold.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local TWO_PI = 2 * math.pi
local STILL = "portal_still"

local function stateOf(opts)
	opts = opts or {}
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	if opts.setup then opts.setup(r) end
	w:advance(15)
	r.W.ride = { id = "d4a", driver = opts.driver or "Mia Runner", driverKey = (opts.driver or "mia runner"):lower(), dest = "Undercity",
		price = 5000, state = "portal", at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

local function turned(tex) return (tex:GetRotation() or 0) % TWO_PI end
local function near(a, b) return math.abs(((a - b + math.pi) % TWO_PI) - math.pi) < 0.05 end

test("d4 a: the Ride screen's portal is the still file, not the flipbook", function()
	local w, r, s = stateOf()
	local hero = s.hero
	ok(hero.art and tostring(hero.art:GetTextureFilePath()):find(STILL, 1, true), "the portal picture is " .. STILL .. ", got " .. tostring(hero.art and hero.art:GetTextureFilePath()))
	ok(hero.art:IsShown(), "the still is shown")
	ok(hero.book == nil and hero.bookGold == nil, "no flipbook on the ride screen's portal")
	eq(hero.art:GetBlendMode(), "BLEND", "the normal blend (the black is transparent in the file)")
	T.clean(w)
end)

test("d4 a: the portal turns anticlockwise, one turn in 8 s, never jumping back", function()
	local w, r, s = stateOf()
	local art = s.hero.art
	w:advance(0.1)
	local t0 = r.env.GetTime()
	local a0 = turned(art)
	-- the game draws a positive SetRotation anticlockwise: the angle only grows
	local prev, jump = a0, false
	local function at(dt)
		w:advance(dt)
		return turned(art)
	end
	local a2 = at(2)
	ok(near(a2 - a0, TWO_PI / 4), "after 2 s: a quarter turn, got " .. (a2 - a0))
	local a4 = at(2)
	ok(near(a4 - a0, TWO_PI / 2), "after 4 s: a half turn, got " .. (a4 - a0))
	local a8 = at(4)
	ok(near(a8, a0), "after 8 s: back at the start")
	-- walk across the full-turn mark in small steps: each step turns forward by about the same, never back
	for i = 1, 40 do
		local before = turned(art)
		w:advance(0.25)
		local d = (turned(art) - before) % TWO_PI
		ok(d > 0.1 and d < 0.3, "step " .. i .. ": turns forward about 0.2 rad, got " .. d)
		if d <= 0.1 or d >= 0.3 then jump = true break end
	end
	ok(not jump, "no jump at the full turn")
	T.clean(w)
end)

test("d4 a: Reduce motion stops the turn (upright) and it turns again when the switch goes off", function()
	local w, r, s = stateOf()
	local art = s.hero.art
	w:advance(1.5)
	ok(math.abs(art:GetRotation()) > 0.01, "control: it turns")
	r.W.db.reduceMotion = true
	w:advance(0.5)
	eq(art:GetRotation(), 0, "upright with Reduce motion on")
	w:advance(3)
	eq(art:GetRotation(), 0, "and it stays upright")
	r.W.db.reduceMotion = false
	w:advance(0.5)
	w:advance(1)
	ok(math.abs(art:GetRotation()) > 0.01, "turning again when the switch is off")
	T.clean(w)
end)

test("d4 a: effects off stops the turn the same way", function()
	local w, r, s = stateOf()
	local art = s.hero.art
	w:advance(1.5)
	r.W.db.fx = "off"
	w:advance(0.5)
	eq(art:GetRotation(), 0, "upright with effects off")
	w:advance(2)
	eq(art:GetRotation(), 0, "and it stays upright")
	T.clean(w)
end)

test("d4 a: a founder's summon is the same still, desaturated and gold", function()
	local w, r, s = stateOf()
	local art = s.hero.art
	local R, G, B = r.W.Theme.RGB("white")
	local v = art.GetVertexColor and { art:GetVertexColor() } or {}
	ok(math.abs((v[1] or 0) - R) < 0.01 and math.abs((v[3] or 0) - B) < 0.01, "violet ride: the picture's own colours")
	ok(not art:IsDesaturated(), "violet ride: not desaturated")
	T.clean(w)
	local w2, r2, s2 = stateOf({ setup = function(rr) rr.W.FounderSummon = function() return true end end })
	local a2 = s2.hero.art
	ok(tostring(a2:GetTextureFilePath()):find(STILL, 1, true), "founder: the same file")
	ok(a2:IsDesaturated(), "founder: desaturated")
	local gr, gg, gb = r2.W.Theme.RGB("gold")
	local c = { a2:GetVertexColor() }
	ok(math.abs(c[1] - gr) < 0.01 and math.abs(c[2] - gg) < 0.01 and math.abs(c[3] - gb) < 0.01, "founder: the gold token as vertex colour")
	T.clean(w2)
end)

local function slurp(path)
	local h = io.open(path, "rb")
	if not h then return nil end
	local s = h:read("*a")
	h:close()
	return s
end

test("d4 a: portal_still.tga is 512 x 512, 32-bit, and its corners are clear", function()
	local d = slurp(T.dir .. "/../Wuber/Media/" .. STILL .. ".tga")
	ok(d, "the file exists")
	if not d then return end
	local function u16(i) return d:byte(i) + d:byte(i + 1) * 256 end
	eq(d:byte(3), 2, "uncompressed true colour")
	local w, h, bpp = u16(13), u16(15), d:byte(17)
	eq(w, 512, "512 wide")
	eq(h, 512, "512 high")
	eq(bpp, 32, "32 bits")
	eq(#d, 18 + 512 * 512 * 4, "the file size")
	local function alpha(x, y) return d:byte(18 + (y * 512 + x) * 4 + 4) end
	for _, p in ipairs({ { 0, 0 }, { 511, 0 }, { 0, 511 }, { 511, 511 } }) do
		eq(alpha(p[1], p[2]), 0, "corner " .. p[1] .. "," .. p[2] .. " is fully transparent")
	end
	ok(alpha(256, 256) > 200, "the middle is opaque")
end)
