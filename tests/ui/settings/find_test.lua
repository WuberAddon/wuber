-- Tests of UI.Settings.Find (round 9, TEST-FINDINGS G1): the Settings search and the folded
-- Settings home. Loaded by tests/run.lua with its helper table T.
--   The contract; the folded home (a card per section with what it is set to, a tap opens just
--   that section, back to the home, back again closes); the search (label, tooltip and hidden
--   words, the section of each match, a match opens its section at the row and highlights it by
--   alpha, "No settings match" and Clear, Esc and the x clear it); the keyboard is never taken;
--   unfolded: the box above the list, the matches in the right pane; nothing outside the window;
--   (2.3.2, I30) why a match matched: the grey "matches: price" line, the word lit in its tooltip.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function R(f) return H.rect(f) end
local function inside(a, b, slack)
	slack = slack or 0.5
	return a.l >= b.l - slack and a.l + a.w <= b.l + b.w + slack and a.b >= b.b - slack and a.b + a.h <= b.b + b.h + slack
end
local function texts(c) return T.list(c:visibleTexts(), " | ") end
local function has(c, text) return #c:findText(text, false, true) > 0 end

-- a Warlock (Driving shows) or a Mage with Settings open, folded unless wide
local function open(opts)
	opts = opts or {}
	local w = T.newWorld()
	local c = opts.warlock and T.driver(w, T.BOB) or T.rider(w)
	T.settle(w)
	c.W.db.coach = true
	if opts.wide then c.wide = true c.W.db.fold = { v = 1, pages = {}, narrow = false } end
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(opts.where)
	w:advance(1)
	return w, c, c.W.UI.settings, c.W.Mod("UI.Settings.Find"), c.W.Mod("UI.Settings.Panel")
end

local function card(st, key)
	for _, b in ipairs(st.find.cards) do
		if b.key == key then return b end
	end
end

-- the shown matches' labels
local function shown(st)
	local out = {}
	for _, b in ipairs(st.find.items) do
		if H.visible(b) and b.m then out[#out + 1] = b.m.label .. " (" .. b.m.section .. ")" end
	end
	return out
end
local function found(st, label)
	for _, b in ipairs(st.find.items) do
		if H.visible(b) and b.m and b.m.label == label then return b end
	end
end

test("ui.settings.find: contract (registered, deps, header, its parts)", function()
	local W, w = T.contract("UI.Settings.Find", "tests/ui/settings/find_test.lua", {
		["Mod.match"] = "function", ["Mod.summary"] = "function", ["Mod.build"] = "function", ["Mod.place"] = "function",
		["Mod.paint"] = "function", ["Mod.summaries"] = "function", ["Mod.flash"] = "function",
		["Mod.why"] = "function", ["Mod.lit"] = "function",
		["UI.OpenSettings"] = "function",
	})
	ok(type(W.Mod("UI.Settings.Rows").KEYWORDS) == "table", "the rows' search words")
	T.clean(w)
end)

test("ui.settings.find: folded home - search box and a card per section with its state; a tap opens just that section; back, back", function()
	local w, c, st, Find = open({ warlock = true })
	local UI = c.W.UI
	ok(not UI.Fold.IsUnfolded(), "folded")
	eq(st.view, "home", "the home")
	ok(H.visible(st.find.box) and H.visible(st.find.home), "the search box and the list")
	ok(not H.visible(st.clip), "no long scroll of every row")
	for _, label in ipairs({ "Riding", "Driving", "Map", "Sound and effects", "This window", "Help: how Wuber finds drivers" }) do
		ok(has(c, label), "card " .. label .. ": " .. texts(c))
	end
	-- each card: an icon and a line of what it is set to, and a tooltip
	for _, b in ipairs(st.find.cards) do
		ok(b.icon and b.desc:GetText() ~= "", "a summary for " .. b.key)
		ok(b.wuberTip, "a tooltip on " .. b.key)
	end
	ok(card(st, "sound").desc:GetText():find("Sound on", 1, true), "sound summary: " .. card(st, "sound").desc:GetText())
	c.W.db.sound = false
	UI.UpdateSettings()
	ok(card(st, "sound").desc:GetText():find("Sound off", 1, true), "it follows the setting")
	-- nothing cut off: every card inside the window, above its bottom
	local win = R(st.panel)
	-- (design 2) the home is three groups of rows and scrolls: each row is whole at the list's top or at its end
	local home = st.find.home
	local whole = {}
	for _, at in ipairs({ 0, home.max }) do
		home:ScrollTo(at, true)
		for _, b in ipairs(st.find.cards) do
			if H.visible(b) and inside(R(b), win) and inside(R(b), R(home), 1) then whole[b.key] = true end
		end
	end
	home:ScrollTo(0, true)
	for _, b in ipairs(st.find.cards) do
		if b:IsShown() then ok(whole[b.key], b.key .. " inside the window") end
	end
	-- a tap: just that section, its name as the title, the back arrow
	c:click(card(st, "map"))
	w:advance(1)
	eq(st.view, "section", "a section")
	eq(st.sec, "map", "Map")
	ok(H.visible(st.clip) and not H.visible(st.find.home), "its rows, not the home")
	eq(st.title:GetText(), "Map", "the title")
	ok(not H.visible(st.find.box), "no search box over a section")
	local rng
	for _, x in ipairs(c.W.Mod("UI.Settings.Panel").sectionRanges()) do
		if x.key == "map" then rng = x end
	end
	eq(st.scrollMin, rng.top, "from Map's top")
	ok(st.clip:GetHeight() <= rng.bottom - rng.top + 0.5, "only Map's rows")
	c:click(st.back)
	w:advance(1)
	eq(st.view, "home", "back: the home")
	eq(st.title:GetText(), "Settings", "the title again")
	ok(UI.SettingsShown(), "still open")
	c:click(st.back)
	w:advance(1)
	ok(not UI.SettingsShown(), "back on the home closes Settings")
	-- a Mage: no Driving card
	T.clean(w)
	local w2, m, st2 = open()
	ok(not H.visible(card(st2, "driving")), "no Driving card for a Mage")
	ok(H.visible(card(st2, "riding")), "Riding")
	T.clean(w2)
end)

test("ui.settings.find: search finds by label, tooltip and hidden word; matches name their section", function()
	local w, c, st, Find, Panel = open({ warlock = true })
	local box = st.find.box
	-- the keyboard is never taken: no autofocus, no focus at open
	eq(box.edit:IsAutoFocus(), false, "no autofocus")
	eq(box.edit:HasFocus(), false, "no focus when Settings opens")
	-- by label
	c:type(box.edit, "sounds", false)
	w:advance(0.5)
	eq(st.view, "results", "the matches")
	ok(found(st, "Sounds"), "Sounds by its label: " .. T.list(shown(st), ", "))
	eq(found(st, "Sounds").where:GetText(), "Sound and effects", "with its section")
	ok(H.visible(st.find.results) and not H.visible(st.find.home), "the matches replace the list")
	-- by a hidden word
	c:type(box.edit, "volume", false)
	w:advance(0.5)
	ok(found(st, "Sounds"), "volume finds Sounds: " .. T.list(shown(st), ", "))
	c:type(box.edit, "price", false)
	w:advance(0.5)
	ok(found(st, "My time is worth"), "price finds the time value: " .. T.list(shown(st), ", "))
	ok(not found(st, "Your message templates"), "the templates row left Settings: " .. T.list(shown(st), ", "))
	-- by the tooltip only ("shift-drag" is only in Lock the big button's tooltip)
	c:type(box.edit, "shift-drag", false)
	w:advance(0.5)
	ok(found(st, "Lock the big button"), "the tooltip's words: " .. T.list(shown(st), ", "))
	-- two words: both must be there
	local two = Find.match("big button key")
	ok(#two >= 1 and two[1].label == "Key for the big button", "two words: " .. (two[1] and two[1].label or "none"))
	-- labels first
	local inv = Find.match("invite")
	ok(#inv >= 2 and inv[1].label:lower():find("invite", 1, true), "a label match first: " .. (inv[1] and inv[1].label or "none"))
	-- the x clears it
	ok(H.visible(box.clear), "the x shows while there is text")
	c:click(box.clear)
	w:advance(0.5)
	eq(st.query, "", "cleared")
	eq(box:Text(), "", "the box empty")
	eq(st.view, "home", "back to the list")
	ok(not H.visible(box.clear), "no x on an empty box")
	T.clean(w)
end)

test("ui.settings.find: a match opens its section at the row, highlighted by alpha; no match; Esc clears", function()
	local w, c, st, Find = open({ warlock = true })
	local box = st.find.box
	c:type(box.edit, "alert character", false)
	w:advance(0.5)
	local b = found(st, "Alert character")
	ok(b, "found: " .. T.list(shown(st), ", "))
	c:click(b)
	w:advance(2)
	eq(st.view, "section", "its section")
	eq(st.sec, "driving", "Driving")
	eq(st.title:GetText(), "Driving", "the title")
	-- scrolled to it: the row is inside the visible scroll area
	local row = b.m and b.m.rec.frame
	ok(row and inside(R(row), R(st.clip), 1), "the row shows (scrolled to it)")
	ok(st.scroll > st.scrollMin + 100, "scrolled down the section: " .. st.scroll)
	-- the highlight: a violet wash on the row, fading by alpha (no scale anywhere)
	local fl = row.wuberFlash
	ok(fl, "the highlight")
	T.clean(w)
	local w2, c2, st2 = open({ warlock = true })
	c2:type(st2.find.box.edit, "sound", false)
	c2:click(found(st2, "Sounds"))
	w2:advance(0.2)
	local fl2 = st2.find.flashing
	ok(fl2 and fl2.tex.parts.M:IsShown(), "lit right after the tap")
	-- (BRIEF22 G1) drawn: the colour's alpha (kept) times the region's (the fade)
	local function drawn(t) return select(4, t:GetVertexColor()) * (t:GetAlpha() or 1) end
	local a1 = drawn(fl2.tex.parts.M)
	w2:advance(0.6)
	local a2 = drawn(fl2.tex.parts.M)
	ok(a2 < a1, "fading: " .. tostring(a1) .. " -> " .. tostring(a2))
	w2:advance(2)
	ok(not fl2.tex.parts.M:IsShown(), "gone after a moment")
	eq(fl2.frame:GetScale(), 1, "never scaled")
	-- back from a match: the matches again
	c2:click(st2.back)
	w2:advance(0.5)
	eq(st2.view, "results", "back to the matches")
	-- no match: the message and Clear
	c2:type(st2.find.box.edit, "zzqx", false)
	w2:advance(0.5)
	ok(has(c2, "No settings match") and H.visible(st2.find.none.clear), "the empty state: " .. texts(c2))
	ok(not H.visible(st2.find.results), "no list")
	c2:click(st2.find.none.clear)
	w2:advance(0.5)
	eq(st2.query, "", "Clear clears it")
	eq(st2.view, "home", "the home")
	-- Esc in the box clears it and lets go of the keyboard
	c2:type(st2.find.box.edit, "map", false)
	ok(st2.find.box.edit:HasFocus(), "focus only from the player's click")
	H.state[st2.find.box.edit].scripts.OnEscapePressed(st2.find.box.edit)
	w2:advance(0.5)
	eq(st2.query, "", "Esc clears it")
	eq(st2.find.box.edit:HasFocus(), false, "and lets go")
	T.clean(w2)
end)

test("ui.settings.find: a Mage's search never finds Driving rows; the Warlock's does", function()
	local w, c, st, Find = open()
	-- (decisions N) the Riding row "What Wuber sends" names the alert character too: what must not be found is a Driving row
	for _, m in ipairs(Find.match("alert character")) do ok(m.section ~= "Driving", "no Driving rows for a Mage: " .. tostring(m.label)) end
	ok(#Find.match("sound") > 0, "the rest is found")
	T.clean(w)
	local w2, d, st2, Find2 = open({ warlock = true })
	ok(#Find2.match("alert character") > 0, "Driving rows for a Warlock")
	T.clean(w2)
end)

test("ui.settings.find: unfolded - the box above a narrow list, matches in the right pane, a match picks its section", function()
	local w, c, st, Find = open({ warlock = true, wide = true })
	local UI = c.W.UI
	ok(UI.Fold.IsUnfolded(), "unfolded")
	local box = st.find.box
	ok(H.visible(box) and H.visible(st.nav), "the box and the list")
	local win = R(c.env.WuberFrame)
	local unit = win.w / c.env.WuberFrame:GetWidth()
	-- the box sits above the first section in the list, inside the list's column
	local first = st.nav.rows[1]
	ok(R(box).b >= R(first).b + R(first).h - 0.5, "the box above the list")
	ok(R(box).l + R(box).w <= R(st.clip).l + 0.5, "left of the rows")
	ok(not H.visible(st.find.home), "no home unfolded")
	c:type(box.edit, "wide", false)
	w:advance(0.5)
	ok(found(st, "Wide pages"), "found: " .. T.list(shown(st), ", "))
	local res = R(st.find.results)
	ok(res.l >= R(box).l + R(box).w, "the matches in the right pane")
	ok(inside(res, win, 1), "inside the window")
	ok(not H.visible(st.clip), "the matches instead of the rows")
	c:click(found(st, "Wide pages"))
	w:advance(1)
	eq(st.sec, "window", "This window picked")
	ok(H.visible(st.clip), "its rows")
	for _, b in ipairs(st.nav.rows) do
		if b.key == "window" then ok(H.visible(b.bar), "the list shows it chosen") end
	end
	-- a section from the list clears the search
	for _, b in ipairs(st.nav.rows) do
		if b.key == "map" then c:click(b) end
	end
	w:advance(1)
	eq(st.query, "", "the list clears the search")
	eq(st.sec, "map", "Map")
	-- folding keeps the section, with its back arrow to the home
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded")
	eq(st.title:GetText(), "Map", "the section folded")
	c:click(st.back)
	w:advance(1)
	eq(st.view, "home", "back: the home")
	ok(unit > 0, "the window's scale")
	T.clean(w)
end)

-- (2.3.2, I30: Google's shots 62 and 63) a match whose name doesn't hold the typed word says why it matched
test("ui.settings.find: I30 - a match says why it matched (grey 'matches: price'), its tooltip lights the word; nothing cut", function()
	local check = dofile(T.dir .. "/lib/listfade.lua")(H)
	for _, wide in ipairs({ false, true }) do
		local w, c, st, Find = open({ warlock = true, wide = wide })
		local box = st.find.box
		c:type(box.edit, "price", false)
		w:advance(0.5)
		local b = found(st, "My time is worth")
		ok(b, "found: " .. T.list(shown(st), ", "))
		ok(H.visible(b.why), "the why line shows")
		eq(b.why:GetText(), "matches: price", "the word it matched")
		-- under the section, inside its row
		local rb, rw, rs = R(b), R(b.why), R(b.where)
		ok(rw.b + rw.h <= rs.b + 0.5, "under the section")
		ok(inside(rw, rb, 0.5), "inside its row")
		-- the rows never overlap
		local prev
		for _, it in ipairs(st.find.items) do
			if H.visible(it) then
				if prev then ok(R(it).b + R(it).h <= R(prev).b + 0.5, "rows apart") end
				prev = it
			end
		end
		-- the tooltip lights the word
		local tip = b.wuberTip.text(b)
		ok(tip:find("Matches: ", 1, true) and tip:find(c.W.Theme.Code("glow") .. "price|r", 1, true), "the tooltip lights it: " .. tip)
		-- nothing cut short or by a hard edge (folded and unfolded)
		local bad = check(c, wide and "search unfolded" or "search folded")
		eq(#bad, 0, "cut text: " .. table.concat(bad, "; "))
		-- a name match says nothing more
		c:type(box.edit, "sounds", false)
		w:advance(0.5)
		ok(found(st, "Sounds") and not H.visible(found(st, "Sounds").why), "Sounds by its name: no why line")
		eq(found(st, "Sounds"):GetHeight(), Find.L.resH, "its row as before")
		-- two words, one in the name: only the other is the why
		c:type(box.edit, "sound volume", false)
		w:advance(0.5)
		local s2 = found(st, "Sounds")
		ok(s2 and H.visible(s2.why) and s2.why:GetText() == "matches: volume", "only the word not in its name: " .. (s2 and s2.why:GetText() or "none"))
		eq(#check(c, "two words"), 0, "nothing cut")
		T.clean(w)
	end
end)

test("ui.settings.find: I30 - the why line always fits (long words are left off, never cut by the game)", function()
	local w, c, st, Find = open()
	local room = c.W.Mod("UI.Settings.Rows").INNER - 48
	local M = c.W.Theme.MeasureText
	for _, words in ipairs({ { "price" }, { "a", "b" }, { string.rep("w", 40) }, { "invite", "group", "whisper", "trade", "money", "accept", "leave" } }) do
		local t = Find.why(words)
		ok(t and t:find("^matches: "), "a line: " .. tostring(t))
		ok(M(t, Find.L.whyPx, "regular") <= room, "fits: " .. t)
	end
	eq(Find.why({}), nil, "no words: no line")
	eq(Find.lit("Pings and Chimes", { "chime" }), "Pings and " .. c.W.Theme.Code("glow") .. "Chime|rs", "lit, the text's own letters kept")
	T.clean(w)
end)

test("ui.settings.find 2.3.2 S2: folded, a match is scrolled to at once, not after an ease", function()
	local w, c, st = open({ warlock = true })
	c:type(st.find.box.edit, "alert character", false)
	w:advance(0.5)
	local b = found(st, "Alert character")
	ok(b, "a match")
	c:click(b)
	eq(st.scroll, st.scrollTarget, "scroll snapped to its target")
	ok(st.scroll > st.scrollMin + 100, "below the section top: " .. tostring(st.scroll))
	T.clean(w)
end)
