-- p242 round 3 group F: the Here map (Home's map panel) never lies half under the window's header buttons.
-- Cause: HomeMap.lua DOCK put the docked map at y 32 of the side pane, but the fold, cog and x buttons run from y 12 to
-- y 44, so in the unfolded window they straddled the map's top edge (the layout rule "chrome": page content in the place of
-- a header button). Promise swept: Home on the Here view and on the World view, folded and unfolded, several screen sizes:
-- the layout engine finds no "chrome" problem, and a docked map begins at or below the lowest header button.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local E = assert(loadfile(H.root .. "/tests/layout/engine.lua"))(H)

local function scene(sw, sh, view, narrow)
	local untag = E.tag({ Wuber = H.ADDONS.Wuber })
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = sw, screenH = sh, saved = { Wuber = { coach = true } } })
	c.wide = true -- the harness says "no room" unless the test opts in (tests/ui/fold_test.lua)
	w:advance(15)
	local W, UI = c.W, c.W.UI
	W.db.mapView = view
	W.db.fold = narrow and { v = 1, pages = {}, narrow = true } or nil
	UI.Toggle(true) w:advance(3)
	UI.Fold.Apply() w:advance(2)
	UI.Show("home") w:advance(2)
	UI.Refresh(true) w:advance(1)
	untag()
	return w, c, E
end

local function chromeHits(c)
	local list = {}
	for _, h in ipairs(E.check(c)) do if h.kind == "chrome" then list[#list + 1] = h.what .. ": " .. tostring(h.detail) end end
	return list
end

test("p242 r3f: the Here map never lies half under a header button (sizes x view x folded/unfolded)", function()
	local docked = 0
	for _, sz in ipairs({ { 1920, 1080 }, { 2662, 2089 }, { 1365, 768 } }) do
		for _, view in ipairs({ "here", "world" }) do
			for _, narrow in ipairs({ false, true }) do
				local w, c = scene(sz[1], sz[2], view, narrow)
				local label = ("%dx%d %s %s"):format(sz[1], sz[2], view, narrow and "narrow" or "auto")
				local hits = chromeHits(c)
				eq(#hits, 0, label .. " chrome:\n  " .. table.concat(hits, "\n  "))
				local m = c.W.UI.state.screens.home.map
				if m.docked then
					docked = docked + 1
					local ch = E.chromeOf(c)
					local lowest = math.huge
					for _, b in ipairs(ch.buttons) do
						local l, bb, bw, bh = b:GetRect()						if H.visible(b) then lowest = math.min(lowest, bb) end
					end
					ok(m:GetTop() <= lowest + 0.5, label .. ": the docked map begins under the buttons (top " .. tostring(m:GetTop()) .. ", buttons' bottom " .. tostring(lowest) .. ")")
				end
				T.clean(w)
			end
		end
	end
	ok(docked > 0, "control: at least one size unfolds and docks the map")
end)

-- guard: unchanged neighbour, the folded (narrow) Home still has its map full-bleed at the window's top, buttons on it
test("p242 r3f guard: the folded Home map still starts at the top of its page", function()
	local w, c = scene(1920, 1080, "here", true)
	local s = c.W.UI.state.screens.home
	ok(not s.map.docked, "folded: not docked")
	eq(math.floor(s.frame:GetTop() - s.map:GetTop() + 0.5), 0, "the map starts at the page top")
	T.clean(w)
end)
