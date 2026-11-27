-- tests/speed/idle_test.lua (job 2749, speed-idle): what Wuber does while nothing changes.
-- Closed window: no Wuber OnUpdate runs unless something is animating (the founder's own crown over the head is the one
-- that is: it is the shared FX driver). Open on Home, nothing clicked: the redraw each second makes (almost) no
-- SetPoint / SetText calls, because the cards, rows and chips are already as they should be.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local P = dofile(T.dir .. "/lib/screenprof.lua")(H)
local Scenes = dofile(T.dir .. "/speed/scenes.lua")

-- plays the scene up to (not including) the step with this id, returns world, client, session
local function upTo(id, opts)
	local w, c = Scenes.world(H, opts)
	local sess = P.session(c)
	for _, s in ipairs(Scenes.STEPS) do
		if s[1] == id then return w, c, sess end
		s[3](c, w)
		w:advance(s[4] or 1)
	end
	error("no step " .. id)
end

local function crownBook(c)
	for _, f in ipairs(c.widgets) do
		if type(f) == "table" and f.wuberFX and f.kind == "crown" and f:IsVisible() then return f end
	end
end

test("speed: idle on Home makes under 30 SetPoint and 20 SetText calls a second", function()
	local w, c, sess = upTo("idle_open", { name = "Plain Rider" }) -- not the founder: no crown over the head
	local m = sess:measure(function() end, { settle = 5 })
	sess:close()
	local sp, st = m.calls.setPoint or 0, m.calls.setText or 0
	-- 40 drivers on Home. Before: about 1,500 SetPoint and 850 SetText in 5 s (300 and 170 a second), the redraw each second
	-- laying out every card again. (The budget is for 5 s: 150 and 100.)
	ok(sp <= 150, "SetPoint calls in 5 s: " .. sp)
	ok(st <= 100, "SetText calls in 5 s: " .. st)
	T.clean(w)
end)

test("speed: with the window shut and nothing animating no Wuber OnUpdate runs", function()
	local w, c, sess = upTo("idle_closed", { name = "Plain Rider" })
	local m = sess:measure(function() end, { settle = 5 })
	sess:close()
	eq(m.idleUpdates, 0, "OnUpdate scripts running: " .. table.concat(m.idleSrc, " "))
	T.clean(w)
end)

test("speed: with the window shut the founder's own crown is the only OnUpdate, and it still turns", function()
	local w, c, sess = upTo("idle_closed")
	local m = sess:measure(function() end, { settle = 1 })
	eq(m.idleUpdates, 1, "OnUpdate scripts running: " .. table.concat(m.idleSrc, " "))
	ok(m.idleSrc[1]:find("FX/Effects.lua", 1, true), "it is the FX driver: " .. tostring(m.idleSrc[1]))
	local book = crownBook(c)
	ok(book, "the crown over the player's head is on screen")
	local m2 = sess:measure(function() end, { settle = 2 })
	sess:close()
	-- its glint and motes are placed again each step: the crown is alive, not frozen
	ok((m2.calls.setPoint or 0) >= 20, "the crown's motes still move: SetPoint calls in 2 s: " .. tostring(m2.calls.setPoint))
	T.clean(w)
end)

test("speed: effects off and the window shut: nothing ticks even for the founder", function()
	local w, c, sess = upTo("idle_closed")
	c.W.db.fx = "off"
	c.W.FX.Refresh()
	local m = sess:measure(function() end, { settle = 3 })
	sess:close()
	eq(m.idleUpdates, 0, "OnUpdate scripts running: " .. table.concat(m.idleSrc, " "))
	T.clean(w)
end)

-- guard: the redraw that now skips unchanged rows still shows a change
test("speed: a driver's new price and place still reach Home's card on the next redraw", function()
	local w, c, sess = upTo("idle_open", { name = "Plain Rider" })
	sess:close()
	local W = c.W
	local before = {}
	for k, card in pairs(W.UI.state.cards) do before[k] = card.titleText end
	local key
	for k in pairs(before) do key = key or k end
	ok(key, "Home has cards")
	local d = W.drivers[key]
	d.dest = "Gadgetzan"
	d.price = 123456
	W.UI.RefreshNow()
	w:advance(1)
	local card = W.UI.state.cards[key]
	ok(card, "the card is still there")
	ok((card.subText or ""):find("Gadgetzan", 1, true) or card.titleText:find("Gadgetzan", 1, true), "the card says the new place: " .. tostring(card.titleText) .. " / " .. tostring(card.subText))
	ok(tostring(card.price:GetText()):find("12", 1, true), "the card's price changed: " .. tostring(card.price:GetText()))
	T.clean(w)
end)

-- guard: the late font (Theme.Tokens WatchFont -> T.RefreshText) must still re-set every row's words: the idle row cache
-- (rowLayout) and the refresh's layout hold together must not leave a row title laid out with the fallback font ("tap Res...")
test("speed: when the font arrives late, no shown Wuber text stays laid out in the fallback font (list rows included)", function()
	local w = T.newWorld()
	w.fontReadyAt = (w.time or 0) + 25
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", money = 100000, screenW = 1920, screenH = 1080 })
	w:advance(3)
	c.W.UI.Toggle(true)
	w:advance(2)
	c.W.UI.OpenSettings()
	w:advance(2)
	w:advance(math.max(0, w.fontReadyAt - w.time) + 5)
	local stale = {}
	for _, f in ipairs(c.widgets) do
		local s = H.state[f]
		if s and s.otype == "FontString" and s.stale and H.visible(f) then stale[#stale + 1] = tostring(f:GetText()) end
	end
	eq(#stale, 0, "shown texts still in the fallback font: " .. table.concat(stale, " | "))
	T.clean(w)
end)

-- guard (review): a card whose Founder or rank chip wraps under the name keeps it anchored through the idle redraws
-- (the card's cardMarks clears the chip's points each redraw; the row cache must not skip placing it again)
test("speed: a driver card's rank chip under a long name stays anchored while Home is idle", function()
	local w, c = Scenes.world(H, { name = "Plain Rider" })
	local W = c.W
	local d = W.drivers["drvba lift1"] -- (Scenes.world's first driver)
	d.service = "Wolfgangbert's Extraordinarily Long Rides"
	d.rank = 7
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.RefreshNow()
	w:advance(0.2)
	local function unanchored()
		local n, list = 0, {}
		for _, f in ipairs(c.widgets) do
			local s = H.state[f]
			if s and s.kind == "frame" and H.visible(f) and #(s.points or {}) == 0 and s.parent and s.parent ~= c.env.UIParent and not s.allPoints then
				n = n + 1
				list[#list + 1] = tostring(s.lcSrc or s.name or s.otype)
			end
		end
		return n, list
	end
	local n0 = unanchored()
	w:advance(3)
	local n1, list = unanchored()
	eq(n1, n0, "shown frames with no anchor after 3 s idle: " .. table.concat(list, ", "))
	T.clean(w)
end)
