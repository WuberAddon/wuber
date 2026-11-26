-- p242 group H (H24-14): folded Home, empty state (no driver listed), with your bounty's row above it: the stack (the
-- round icon, the title, the line, the bell, "Pin a bounty", "Why?", the OpenMap line) never reaches "Ping drivers".
-- Cause (proven with and without the hunt's bounty step, J2-F122/F123): the bounty row takes 82 of the list's 238, so
-- the empty state has 152; only the OpenMap line checked the room, so the icon stayed and "Why?" sat inside Ping drivers.
-- Promise swept: no usual place, the usual place the same as the bounty's, another usual place (the bell stays: the
-- state scrolls), a searched zone, folded and unfolded; the words are never shortened (the title and line read the same).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- the layout checker's engine (tools/layout-check.lua) on each state: no problem in Home's own words
local E = assert(loadfile(H.root .. "/tests/layout/engine.lua"))(H)

local STACK = { "disc", "title", "sub", "watch", "bountyGo", "why", "mapHint" }

-- a rider on Home with nobody online; opts.usual: W.Usual's place; opts.pin: a bounty pinned for it; opts.search after
local function setup(opts)
	opts = opts or {}
	local untag = E.tag({ Wuber = H.ADDONS.Wuber })
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = opts.sw or 1920, screenH = opts.sh or 1080,
		saved = { Wuber = { coach = true } } }) -- (the first-open tips read: they are not the question)
	w:advance(15)
	local W, UI = c.W, c.W.UI
	if opts.usual then W.Usual = function() return { dest = opts.usual } end end
	UI.Toggle(true)
	w:advance(3)
	W.db.fold = (not opts.wide) and { v = 1, pages = {}, narrow = true } or nil
	UI.Fold.Apply()
	w:advance(2)
	UI.Show("home")
	w:advance(2)
	if opts.pin then
		UI.SetSearch(opts.pin)
		w:advance(1)
		ok(UI.PinBounty(opts.pin, 5000), "the bounty for " .. opts.pin .. " is pinned")
		UI.SetSearch("")
		w:advance(1)
	end
	if opts.search then
		UI.SetSearch(opts.search)
		w:advance(1)
	end
	UI.Refresh(true)
	w:advance(1)
	untag()
	return w, c, W, UI
end

local function rect(f)
	local l, b, wd, ht = f:GetRect()
	return { l = l or 0, b = b or 0, w = wd or 0, h = ht or 0, t = (b or 0) + (ht or 0) }
end

-- every shown part of the stack ends at least 12 above Ping drivers, and the list scrolls far enough to show it all
local function stackClear(c, label)
	local UI = c.W.UI
	local s = UI.state.screens.home
	local e = s.empty
	ok(H.visible(e), label .. ": the empty state shows")
	ok(H.visible(e.ping), label .. ": Ping drivers shows")
	local p = rect(e.ping)
	local clip = rect(s.clip)
	local maxS = tonumber(UI.state.scrollMax) or 0
	local seen = 0
	for _, k in ipairs(STACK) do
		local f = e[k]
		if f and f:IsVisible() then
			seen = seen + 1
			local r = rect(f)
			ok(r.b >= p.t + 12 - 0.5, ("%s: %s ends %.1f above Ping drivers (12 wanted)"):format(label, k, r.b - p.t))
			ok(r.t <= clip.t + 0.5, ("%s: %s starts inside the list (%.1f over its top)"):format(label, k, r.t - clip.t))
		end
	end
	-- the layout checker: nothing of Home's overlaps, lies under a box or is cut
	local bad = {}
	for _, p2 in ipairs(E.check(c) or {}) do
		local key = tostring(p2.key or "") .. " " .. tostring(p2.what or "") .. " " .. tostring(p2.detail or "")
		-- (the sheet lies over the map by design: allowed in tests/layout/allow.lua)
		if key:find("Home.lua", 1, true) and not key:find("HomeMap.lua:%d+ canvas") then bad[#bad + 1] = tostring(p2.kind) .. ": " .. key end
	end
	eq(#bad, 0, label .. ": layout problems in Home: " .. table.concat(bad, " | "))
	ok(seen >= 3, label .. ": the title, the line and Why? are there (" .. seen .. ")")
	-- Ping drivers itself is reachable: in the list's view now, or once the list is scrolled to its end
	ok(p.b >= clip.b - maxS - 0.5, ("%s: Ping drivers is reachable (%.1f below the view, scroll %.1f)"):format(label, clip.b - p.b, maxS))
	return s, e
end

test("p242 H: H24-14: folded Home, nobody online, your bounty's row up: the stack ends above Ping drivers (J2-F122/F123)", function()
	local w, c, W, UI = setup({ pin = "Ironforge" })
	local s, e = stackClear(c, "bounty up")
	ok(H.visible(s.bountyChip), "the bounty row shows")
	eq(e.title:GetText(), "No drivers online", "the title reads the same")
	ok(not e.disc:IsVisible(), "the round icon gave way for the words")
	T.clean(w)
end)

test("p242 H: H24-14: the same at a smaller screen and a large UI scale", function()
	local w, c = setup({ pin = "Ironforge", sw = 1365, sh = 768 })
	stackClear(c, "1365x768")
	T.clean(w)
end)

test("p242 H: H24-14: unfolded Home with your bounty's row up: the stack ends above Ping drivers", function()
	local w, c = setup({ pin = "Ironforge", wide = true })
	stackClear(c, "unfolded")
	T.clean(w)
end)

test("p242 H: H24-14: your usual place is the bounty's place: no second bell (the bounty already watches it), the stack fits", function()
	local w, c, W, UI = setup({ pin = "Ironforge", usual = "Ironforge" })
	local s, e = stackClear(c, "usual = bounty")
	ok(not e.watch:IsVisible(), "no Tell me bell for the place the bounty already watches")
	eq(UI.state.scrollMax or 0, 0, "nothing to scroll")
	T.clean(w)
end)

test("p242 H: H24-14: your usual place is another place: its bell stays and the empty state scrolls, Ping drivers at its end", function()
	local w, c, W, UI = setup({ pin = "Ironforge", usual = "Thunder Bluff" })
	local s, e = stackClear(c, "usual elsewhere")
	ok(e.watch:IsVisible(), "the Tell me bell for Thunder Bluff shows")
	eq(e.watch.place, "Thunder Bluff", "the bell watches the usual place")
	ok((UI.state.scrollMax or 0) > 0, "the list scrolls to show it all")
	T.clean(w)
end)

test("p242 H: H24-14: a searched place with your bounty up elsewhere: the stack ends above Ping drivers", function()
	local w, c, W, UI = setup({ pin = "Ironforge", search = "Durotar" })
	stackClear(c, "search Durotar")
	T.clean(w)
end)

-- the same empty state reached without the bounty step, as before: nothing scrolls, the words the same
-- guard: the cause needs the bounty row; without it the stack already fitted on the base (J2-F122/F123 pass without the step)
test("p242 H: H24-14 guard: nobody online and no bounty: the stack ends above Ping drivers and nothing scrolls", function()
	local w, c, W, UI = setup({})
	local s, e = stackClear(c, "no bounty")
	eq(e.title:GetText(), "No drivers online", "the title reads the same")
	eq(UI.state.scrollMax or 0, 0, "nothing to scroll")
	T.clean(w)
end)

-- the bounty taken down (the hunt's last step): back to the whole list's room
-- guard: taking the bounty down gives the empty state its 238 back, so the base already fitted here
test("p242 H: H24-14 guard: after the bounty is taken down the stack ends above Ping drivers and nothing scrolls", function()
	local w, c, W, UI = setup({ pin = "Ironforge", usual = "Thunder Bluff" })
	UI.CancelBounty()
	w:advance(1)
	local s, e = stackClear(c, "taken down")
	ok(not H.visible(s.bountyChip), "the bounty row is gone")
	eq(UI.state.scrollMax or 0, 0, "nothing to scroll")
	T.clean(w)
end)
