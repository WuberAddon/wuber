-- Tests of the driver badge art (BRIEF18 01:25 (2)): on a rider's driver card the badge and crown drew as
-- plain white shapes. Every badge id has a real, coloured, face-on icon file; a card draws it (a still
-- icon: no spinning sheet to catch edge-on or still loading); nothing is left as a solid colour.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H, S = T.test, T.eq, T.ok, T.H, T.S

local MEDIA = T.dir .. "/../Wuber/Media"

local function tga(path)
	local t = T.readFile(path)
	if not t or #t < 18 then return nil end
	local wd, ht = t:byte(13) + t:byte(14) * 256, t:byte(15) + t:byte(16) * 256
	return { t = t, w = wd, h = ht, bpp = t:byte(17), kind = t:byte(3), idLen = t:byte(1), alphaBits = t:byte(18) % 16 }
end

-- how many opaque pixels, how many distinct colours (5 bits a channel) and how many near-white ones
local function look(g)
	local base = 18 + g.idLen
	local opaque, white, seen, kinds = 0, 0, {}, 0
	for i = 0, g.w * g.h - 1 do
		local b, gr, r, a = g.t:byte(base + i * 4 + 1, base + i * 4 + 4)
		if a > 128 then
			opaque = opaque + 1
			if r > 235 and gr > 235 and b > 235 then white = white + 1 end
			local k = math.floor(r / 8) * 1024 + math.floor(gr / 8) * 32 + math.floor(b / 8)
			if not seen[k] then seen[k] = true kinds = kinds + 1 end
		end
	end
	return opaque, kinds, white
end

local function ids(W)
	local out = {}
	for _, b in ipairs(W.BADGES) do out[#out + 1] = b.id end
	return out
end

test("fx.badge: every badge id has its icon file on disk (exact case), 64 x 64, 32-bit, coloured, not a solid shape", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local on = {}
	for _, f in ipairs(H.listFiles(MEDIA, "tga")) do on[f:match("([^/\\]+)$")] = true end
	ok(#ids(W) >= 6, "the badges: " .. #ids(W))
	for _, id in ipairs(ids(W)) do
		local name = "badge_" .. id .. ".tga"
		ok(on[name], name .. " is in Media with exactly this name")
		local g = tga(MEDIA .. "/" .. name)
		ok(g, name .. " reads")
		eq(g.w, 64, name .. " width") eq(g.h, 64, name .. " height")
		eq(g.bpp, 32, name .. " 32-bit") eq(g.kind, 2, name .. " uncompressed") eq(g.alphaBits, 8, name .. " alpha bits")
		eq(#g.t, 18 + g.idLen + 64 * 64 * 4, name .. " not truncated")
		local opaque, kinds, white = look(g)
		ok(opaque > 1200, name .. " has a body: " .. opaque)
		ok(kinds >= 12, name .. " is coloured, not flat: " .. kinds .. " colours")
		ok(white < opaque * 0.25, name .. " is not a white shape: " .. white .. " of " .. opaque)
		eq(W.Theme.BadgeTexture(id), "Interface\\AddOns\\Wuber\\Media\\badge_" .. id, "T.BadgeTexture " .. id)
	end
	eq(W.Theme.BadgeTexture("crown"), nil, "the crown is not a badge")
	eq(W.Theme.BadgeTexture(""), nil)
	T.clean(w)
end)

test("fx.badge: the spinning sheet has its own run of frames for every badge id", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local FX = r.W.FX
	local g = tga(MEDIA .. "/fx/badges.tga")
	ok(g, "fx/badges.tga")
	local seen = {}
	for _, id in ipairs(ids(r.W)) do
		local first = FX.BadgeFirst(id)
		ok(first, "FX.BadgeFirst " .. id)
		ok(not seen[first], id .. " has its own run")
		seen[first] = true
		ok(first + 10 <= (g.w / 64) * (g.h / 64), id .. "'s frames are inside the sheet")
		local f = FX.Badge(r.W.UIParent or UIParent, id, 20)
		ok(f, "FX.Badge " .. id)
	end
	T.clean(w)
end)

local function cardMark(badge, creator)
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w, T.ANITA, { netOnly = true })
	d.W.Char().badge = badge
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.UI.Toggle(true)
	w:advance(3)
	local card = r.W.UI.state.cards["anita lift"]
	return w, r, card
end

test("fx.badge: a driver card draws the badge as its real face-on icon, never a blank or solid texture (every badge)", function()
	for _, id in ipairs({ "bolt", "star", "flame", "moon", "crystal", "skull" }) do
		local w, r, card = cardMark(id)
		ok(card and card.mark, id .. ": the card has a badge")
		ok(H.visible(card.mark), id .. ": the badge shows")
		local texs = {}
		for _, o in ipairs(r.widgets) do
			if S[o].otype == "Texture" and S[o].parent == card.mark then texs[#texs + 1] = o end
		end
		eq(#texs, 1, id .. ": one texture")
		eq(S[texs[1]].texture, r.W.Theme.MEDIA .. "badge_" .. id, id .. ": its own icon")
		ok(not S[texs[1]].colorTexture and not S[texs[1]].color, id .. ": not set to a solid colour")
		ok(card.mark:GetWidth() >= 18 and card.mark:GetHeight() >= 18, id .. ": a readable size")
		T.clean(w)
	end
end)

test("fx.badge: the founder card keeps its crown and its badge side by side; with no effects module the badge is still the real icon", function()
	local w, r, card = cardMark("skull")
	-- (design 2) no crown after the name any more: the Founder badge says it, and the driver's badge is their picture
	ok(not (card.crown and H.visible(card.crown)), "no crown after the name")
	ok(card.royal and card.royal.chip and H.visible(card.royal.chip), "the Founder badge")
	ok(card.mark and H.visible(card.mark) and card.mark:GetParent() == card.avatar, "the badge, as the driver's picture")
	-- FX gone: a plain frame with the same icon, not a star on a disc
	local fx = r.W.FX
	r.W.FX = nil
	local f = r.W.Theme.DriverBadge(UIParent, "skull", 20)
	ok(f and f.plain and f.icon, "plain badge")
	eq(S[f.icon].texture, r.W.Theme.MEDIA .. "badge_skull", "the skull icon")
	local g = r.W.Theme.DriverBadge(UIParent, "skull", 20, true)
	eq(S[g.icon].texture, r.W.Theme.MEDIA .. "badge_skull", "still: the same")
	r.W.FX = fx
	local s = r.W.Theme.DriverBadge(UIParent, "skull", 20, true)
	eq(S[s.icon].texture, r.W.Theme.MEDIA .. "badge_skull", "still: no effect sheet even with FX")
	local m = r.W.Theme.DriverBadge(UIParent, "skull", 20)
	ok(m.wuberFX, "not still: the FX frame (it spins on pins and plates)")
	T.clean(w)
end)
