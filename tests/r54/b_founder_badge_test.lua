local T = ...
local test, eq, ok = T.test, T.eq, T.ok
-- r54 B (the author 24 Nov 15:03): a founder sees the crown by default; the picker shows what is shown and every tile can be picked.
local function open(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end
local function tiles(st)
	local f, none, byId = nil, nil, {}
	for _, b in ipairs(st.badges) do
		if b.founder then f = b elseif b.id == "" then none = b else byId[b.id] = b end
	end
	return f, none, byId
end
local function card(r, d)
	local CM = r.W.Mod("UI.Rider.Cards")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local c = CM.buildCard(parent)
	CM.fillCard(c, d)
	return c
end
local function drv(r, extra)
	local d = { name = "Farra Way", key = "farra way", dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Farra's Rides", heard = r.env.GetTime(), summoner = "Farra Way", creator = true }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d
end

test("r54 b: a founder with no pick shows the crown as the picked tile, named under the row", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.Char().badge = ""
	local st = open(d, w, "driving")
	local f, none = tiles(st)
	ok(f and f.chosen, "the crown tile has the chosen ring")
	ok(none == nil, "a founder has no None tile (it would show the crown anyway)")
	eq(st.badgeName:GetText(), "Founder (automatic)", "the label names the crown")
	T.clean(w)
end)

test("r54 b: a founder can pick Star (label says Star, crown tile off), and the crown tile picks the crown again", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.Char().badge = ""
	local st = open(d, w, "driving")
	local f, _, byId = tiles(st)
	d:click(byId.star)
	eq(d.W.Char().badge, "star", "star saved")
	eq(st.badgeName:GetText(), "Star", "label says Star")
	ok(not f.chosen and byId.star.chosen, "only Star is ringed")
	d:click(f)
	eq(d.W.Char().badge, "", "the crown tile clears the pick: automatic")
	ok(f.chosen and not byId.star.chosen, "the crown is ringed")
	eq(st.badgeName:GetText(), "Founder (automatic)", "label says so")
	T.clean(w)
end)

test("r54 b: a founder's card shows the crown (not a letter) with no pick, and the pick when there is one", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local c = card(r, drv(r))
	ok(c.crownMark and c.crownMark:IsShown(), "the crown is on the card")
	ok(not c.avatar.initial:IsShown(), "no letter beside it")
	c = card(r, drv(r, { badge = "star" }))
	ok(c.mark and c.mark:IsShown(), "the picked badge shows")
	ok(not (c.crownMark and c.crownMark:IsShown()), "no crown over a pick")
	T.clean(w)
end)

-- guard: a driver who is not a founder never gets the crown on the card; None shows the letter
test("r54 b guard: a non-founder never gets the crown; None is a tile and shows the letter", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local c = card(r, drv(r, { name = "Bob Test", key = "bob test", creator = false }))
	ok(not (c.crownMark and c.crownMark:IsShown()), "no crown")
	ok(c.avatar.initial:IsShown(), "the letter")
	T.clean(w)
	local w2 = T.newWorld()
	local d2 = T.driver(w2, T.BOB)
	T.settle(w2)
	local st = open(d2, w2, "driving")
	local f, none = tiles(st)
	ok(f == nil and none, "None is there, no crown tile")
	d2:click(none)
	eq(d2.W.Char().badge, "", "None saved")
	T.clean(w2)
end)
