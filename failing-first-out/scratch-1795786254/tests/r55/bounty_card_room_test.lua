local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local E = assert(loadfile(H.root .. "/tests/layout/engine.lua"))(H)

local function setup(place, opts)
	opts = opts or {}
	local untag = E.tag({ Wuber = H.ADDONS.Wuber })
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080, saved = { Wuber = { coach = true } } })
	w:advance(15)
	local W, UI = c.W, c.W.UI
	if opts.gf then
		W.db.groupFinder = true
		if opts.tall then
			W.GroupFinder.Pending = function() return true end
			W.GroupFinder.ExtraCount = function() return 999 end
		end
	end
	UI.Toggle(true)
	w:advance(3)
	W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Fold.Apply()
	w:advance(2)
	UI.Show("home")
	w:advance(2)
	UI.SetSearch(place)
	w:advance(1)
	UI.Refresh(true)
	w:advance(1)
	untag()
	return w, c, W, UI
end

local function rect(f)
	local l, b, wd, ht = f:GetRect()
	return { l = l or 0, b = b or 0, w = wd or 0, h = ht or 0, t = (b or 0) + (ht or 0) }
end

local PLACE = "Feathermoon Stronghold" -- the longest place name: no driver goes there, so Home offers the bounty card

local function inter(a, b)
	local w = math.min(a.l + a.w, b.l + b.w) - math.max(a.l, b.l)
	local h = math.min(a.t, b.t) - math.max(a.b, b.b)
	return w > 0.5 and h > 0.5
end

-- the parts of the bounty card that show, with their names
local function parts(UI)
	local bb = UI.state.screens.home.empty.bounty
	local out = {}
	for i, p in ipairs(bb.picks) do out[#out + 1] = { "pick " .. i, p } end
	out[#out + 1] = { "note", bb.note }
	if H.visible(bb.pin) then out[#out + 1] = { "pin", bb.pin } end
	if bb.custom:IsShown() then out[#out + 1] = { "custom box", bb.custom } end
	return out
end

local function noOverlap(UI, label)
	local ps = parts(UI)
	for i = 1, #ps do
		for j = i + 1, #ps do
			ok(not inter(rect(ps[i][2]), rect(ps[j][2])), label .. ": " .. ps[i][1] .. " and " .. ps[j][1] .. " do not overlap")
		end
	end
end

-- every part is whole inside the page when the list is scrolled to where that part is
local function reachable(UI, label)
	local s = UI.state.screens.home
	local clip = rect(s.clip)
	local sm = tonumber(UI.state.scrollMax) or 0
	for _, p in ipairs(parts(UI)) do
		local r = rect(p[2])
		ok(r.b >= clip.b - sm - 0.5, label .. ": " .. p[1] .. " ends " .. ("%.1f"):format(clip.b - sm - r.b) .. " below the end of the scroll")
		ok(r.t <= clip.t + 0.5, label .. ": " .. p[1] .. " starts inside the page")
	end
	-- the note reads in full: its drawn height is what its box holds
	local bb = s.empty.bounty
	ok(rect(bb.note).h + 0.5 >= (bb.note:GetStringHeight() or 0), label .. ": the note box holds its whole text")
end

test("bounty card room: Group Finder card up, a long unserved place: Pin covers neither the amounts nor the note", function()
	local w, c, W, UI = setup(PLACE, { gf = true })
	local s = UI.state.screens.home
	ok(H.visible(s.gfSearch), "the Group Finder row shows")
	ok(H.visible(s.empty.bounty), "the bounty card shows")
	eq(s.empty.bounty.note:GetText(), UI.BOUNTY_NOTE, "the note keeps its words")
	noOverlap(UI, "gf")
	reachable(UI, "gf")
	T.clean(w)
end)

test("bounty card room: the tallest Group Finder card: nothing of the bounty card overlaps", function()
	local w, c, W, UI = setup(PLACE, { gf = true, tall = true })
	noOverlap(UI, "gf tall")
	reachable(UI, "gf tall")
	T.clean(w)
end)

test("bounty card room: an amount of your own (Custom): the box, the note and Pin stand apart and the page scrolls to Pin", function()
	local w, c, W, UI = setup(PLACE, { gf = true, tall = true })
	local bb = UI.state.screens.home.empty.bounty
	bb.picks[4]:GetScript("OnClick")(bb.picks[4])
	w:advance(1)
	UI.Refresh(true)
	w:advance(1)
	ok(bb.custom:IsShown(), "the amount box shows")
	noOverlap(UI, "custom")
	reachable(UI, "custom")
	T.clean(w)
end)

-- guard: no Group Finder card: the bounty card already stood clear and the page did not scroll
test("bounty card room: guard: setting off: nothing overlaps and the page does not scroll", function()
	local w, c, W, UI = setup(PLACE, {})
	ok(H.visible(UI.state.screens.home.empty.bounty), "the bounty card shows")
	noOverlap(UI, "plain")
	reachable(UI, "plain")
	eq(tonumber(UI.state.scrollMax) or 0, 0, "no scroll")
	T.clean(w)
end)

-- guard: your own bounty up for the place: Pin is gone, the amounts and the note stay apart
test("bounty card room: guard: your bounty is up: no Pin, amounts and note apart", function()
	local w, c, W, UI = setup(PLACE, { gf = true })
	ok(UI.PinBounty(PLACE, 5000), "the bounty is pinned")
	w:advance(1)
	UI.Refresh(true)
	w:advance(1)
	local bb = UI.state.screens.home.empty.bounty
	ok(not H.visible(bb.pin), "Pin is hidden while the bounty is up")
	noOverlap(UI, "pinned")
	T.clean(w)
end)
