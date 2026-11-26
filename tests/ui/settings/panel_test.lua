-- Tests of UI.Settings.Panel (round 9: S11 and the section order of G1). Loaded by tests/run.lua
-- with its helper table T.
--   The contract; the driver's message templates sit at the top of Driving (no "Rider messages"
--   row above Riding); unfolded, the section list is a narrow column, the rows sit right of it and
--   Help is a link, never styled as the chosen section; the most used rows top their sections;
--   (2.3.2, I31) unfolded Help's contents light the part being read, as you scroll or click.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function R(f) return H.rect(f) end

local function open(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end

local function range(c, key)
	for _, x in ipairs(c.W.Mod("UI.Settings.Panel").sectionRanges()) do
		if x.key == key then return x end
	end
end

-- a row's top in the scroll content
local function rowTop(st, frame)
	local _, _, _, _, oy = frame:GetPoint(1)
	local par = frame:GetParent()
	-- (design 2) a row sits in its group's card: the card's place in the page, then the row's place in the card
	if frame.group and par == frame.group then
		par = par:GetParent()
		oy = oy - frame.group.topY
	end
	-- (the Settings diet) a page is a frame of always-shown rows and an Advanced frame: each has its own top in the chain
	local base = st.frameTop and st.frameTop[par] or 0
	return base - oy
end

test("ui.settings.panel: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("UI.Settings.Panel", "tests/ui/settings/panel_test.lua", {
		["UI.OpenSettings"] = "function", ["UI.CloseSettings"] = "function", ["UI.LayoutSettings"] = "function",
		["UI.UpdateSettings"] = "function", ["UI.BuildSettings"] = "function", ["UI.SettingsShown"] = "function",
		["UI.OpenHelp"] = "function", ["UI.CloseHelp"] = "function", ["UI.HelpShown"] = "function",
		["Mod.sectionRanges"] = "function", ["Mod.search"] = "function", ["Mod.openSection"] = "function",
		["Mod.openResult"] = "function", ["Mod.back"] = "function", ["Mod.SECTIONS"] = "table",
	})
	T.clean(w)
end)

-- (the Settings diet) "Your message templates" left Settings (the Drive tab's Messages is the one place); what stays true: no
-- Rider messages row above Riding, and no second messages row.
test("ui.settings.panel: S11 - no Rider messages row above Riding, and no messages row in Settings (the Drive tab's Messages is the place)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w)
	eq(#d:findText("Rider messages", true, true), 0, "no Rider messages row")
	eq(#d:findText("Messages to riders", true, true), 0, "one messages row only")
	eq(#d:findText("Your message templates", true, true), 0, "the templates row is gone")
	ok(st.controls["drive.messages"] == nil, "no Edit button for it")
	T.clean(w)
end)

-- the author struggled to find auto-invite: the three switches drivers look for lead Driving, and Search still finds them
test("ui.settings.panel: BRIEF22 T3 Driving opens with its always rows (whisper invite, advert); the public chat invite is an Advanced row; Search finds them", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local names = { "Invite riders who whisper me", "Invite public chat riders", "Post an advert when I go online" }
	local rows = {}
	for _, r in ipairs(st.rows) do if r.label then rows[r.label:GetText()] = r end end
	-- the always-shown rows come first; every row of the Advanced frame is below all of them
	local lastAlways = -1
	for _, r in ipairs(st.rows) do
		local frame = r.group and r.group:GetParent() or r:GetParent()
		if frame == st.drive then lastAlways = math.max(lastAlways, rowTop(st, r)) end
	end
	for _, r in ipairs(st.rows) do
		local frame = r.group and r.group:GetParent() or r:GetParent()
		if frame == st.driveAdv then
			ok(rowTop(st, r) > lastAlways, "below the always rows: " .. tostring(r.label and r.label:GetText()))
		end
	end
	ok((rows["Invite public chat riders"].group:GetParent()) == st.driveAdv, "the public chat invite is an Advanced row")
	for _, n in ipairs(names) do
		ok(rows[n], n .. ": still a row")
		ok(rows[n].wuberTip, n .. ": has a tooltip")
		local hit = false
		for _, e in ipairs(st.index) do if e.label == n then hit = true end end
		ok(hit, n .. ": in the search index")
	end
	-- (the Settings diet) "Most used" is no longer drawn
	eq(#d:findText("Most used", true, true), 0, "no Most used heading")
	eq(#d:findText("Driving: most used", true, true), 0, "not the page's name again")
	local found = d.W.Mod("UI.Settings.Find").match("auto invite")
	local labels = {}
	for _, m in ipairs(found or {}) do labels[(m.label or (m.entry and m.entry.label) or "")] = true end
	ok(labels["Invite riders who whisper me"] and labels["Invite public chat riders"], "Search 'auto invite' finds both")
	T.clean(w)
end)

-- a founder sees the Founder badge in Your badge, automatic, never stored or clickable
test("ui.settings.panel: BRIEF22 T2 a founder sees 'Founder (automatic)' in Your badge; others do not; it is not clickable", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.Char().badge = "star"
	local st = open(d, w, "driving")
	local f
	for _, b in ipairs(st.badges) do if b.founder then f = b end end
	ok(f, "the founder tile is there")
	ok(f.wuberTip and tostring(f.wuberTip.title or f.wuberTip[1] or ""):find("Founder (automatic)", 1, true), "tooltip title says Founder (automatic)")
	eq(st.badgeName:GetText(), "Star", "(r54 B) a founder with Star picked: the label names Star")
	ok(not f.chosen, "a founder with Star picked: the crown tile is not ringed")
	d:click(f) -- (r54 B) the crown tile is a choice: it clears the pick
	eq(d.W.Char().badge, "", "clicking it picks the automatic crown")
	d.W.UI.UpdateSettings()
	local chosen = 0
	for _, b in ipairs(st.badges) do if b.chosen then chosen = chosen + 1 end end
	eq(chosen, 1, "only one tile has the chosen ring")
	ok(f.chosen, "the crown tile has it")
	T.clean(w)
	local w2 = T.newWorld()
	local d2 = T.driver(w2, T.BOB)
	T.settle(w2)
	local st2 = open(d2, w2, "driving")
	for _, b in ipairs(st2.badges) do ok(not b.founder, "a non-founder never gets the tile") end
	T.clean(w2)
end)

test("ui.settings.panel: G1 - the most used rows first: Riding starts with Tips, Sound and effects with Sounds", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local st = open(r, w)
	local firstRiding, firstSound
	local rid, snd = range(r, "riding"), range(r, "sound")
	for _, row in ipairs(st.rows) do
		local y = (row.group and row.group:GetParent() or row:GetParent()) ~= st.drive and rowTop(st, row) or -1 -- (Driving is hidden for a Mage)
		if y >= rid.top and y < rid.bottom and (not firstRiding or y < rowTop(st, firstRiding)) then firstRiding = row end
		if y >= snd.top and y < snd.bottom and (not firstSound or y < rowTop(st, firstSound)) then firstSound = row end
	end
	eq(firstRiding.label:GetText(), "Tips", "Riding's first row (the always-shown rows come before the Advanced ones)")
	eq(firstSound.label:GetText(), "Sounds", "Sound and effects' first row")
	T.clean(w)
end)

test("ui.settings.panel: round 9 - every text box shows its whole default text (Request words: nothing cut short)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local Th = d.W.Theme
	ok(#st.fields >= 4, "the Driving text boxes")
	local seen = 0
	for _, f in ipairs(st.fields) do
		local text = f:Text()
		if text ~= "" then
			seen = seen + 1
			local room = R(f.edit).w / (R(d.env.WuberFrame).w / d.env.WuberFrame:GetWidth())
			local need = Th.MeasureText(text, 11, "medium")
			ok(need <= room, "fits: \"" .. text .. "\" needs " .. need .. ", has " .. room)
		end
	end
	ok(seen >= 2, "boxes with a default text: " .. seen)
	T.clean(w)
end)

test("ui.settings.panel: S11 unfolded - a narrow section list, the rows right of it, Help a link (not chosen)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.wide = true
	d.W.db.fold = { v = 1, pages = {}, narrow = false }
	local st = open(d, w)
	ok(d.W.UI.Fold.IsUnfolded(), "unfolded")
	local win = R(d.env.WuberFrame)
	local nav = R(st.nav.rows[1])
	ok(nav.w <= win.w * 0.35, "the list is narrow: " .. nav.w .. " of " .. win.w)
	local clip = R(st.clip)
	ok(clip.l >= nav.l + nav.w, "the rows right of the list")
	ok(clip.l + clip.w <= win.l + win.w + 0.5, "inside the window")
	-- Help: no accent bar, the plain colour (only the chosen section has the bar)
	ok(not H.visible(st.nav.help.bar), "Help has no selection bar")
	local bars = 0
	for _, b in ipairs(st.nav.rows) do
		if H.visible(b) and H.visible(b.bar) then bars = bars + 1 end
	end
	eq(bars, 1, "one section chosen")
	-- every slider's knob above its gold fill and the rows above the side pane, unfolded too (A's S8 knob
	-- has its own level: the rows' scroll must not change level when the page unfolds)
	local sliders = { st.controls.timeValue, st.controls.scale }
	for _, sl in ipairs(st.sliders) do sliders[#sliders + 1] = sl end
	for _, sl in ipairs(sliders) do
		ok(sl.top:GetFrameLevel() > sl.fill:GetFrameLevel(), "a knob above its fill: " .. sl.top:GetFrameLevel() .. " / " .. sl.fill:GetFrameLevel())
	end
	ok(st.clip:GetFrameLevel() > d.W.UI.Fold.Pane():GetFrameLevel(), "the rows above the side pane")
	d.W.UI.Fold.Toggle()
	w:advance(1)
	for _, sl in ipairs(sliders) do ok(sl.top:GetFrameLevel() > sl.fill:GetFrameLevel(), "folded: a knob above its fill") end
	d.W.UI.Fold.Toggle()
	w:advance(1)
	-- Help still opens from the list
	d:click(st.nav.help)
	w:advance(1)
	ok(d.W.UI.HelpShown(), "Help opens")
	d.W.UI.CloseHelp(true)
	w:advance(1)
	T.clean(w)
end)

-- (round 13, I2) the badge picker: a reviewer caught the spinning badges edge-on (thin sticks, squashed
-- ovals: Skull looked like the rest). The badges you can pick stand still, face-on; only the one
-- you chose turns, and one you hover turns while the mouse is on it.
test("ui.settings.panel r13 I2: the badge picker's badges stand still face-on; only the chosen (or hovered) one turns", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	W.db.fx = nil -- full effects: the badges would all turn
	local st = open(d, w, "driving")
	w:advance(1)
	local picks = {}
	for _, b in ipairs(st.badges or {}) do if b.preview and not b.preview.plain then picks[#picks + 1] = b end end
	ok(#picks >= 4, "the picker's badges (" .. #picks .. ")")
	local chosen = picks[2]
	W.Char().badge = chosen.id
	W.UI.UpdateSettings()
	w:advance(0.5)
	local before = {}
	for i, b in ipairs(picks) do before[i] = b.preview.pos end
	w:advance(1.3)
	for i, b in ipairs(picks) do
		local p = b.preview
		if b == chosen then
			ok(p.pos ~= before[i], "the chosen badge (" .. b.id .. ") turns")
		else
			eq(p.pos, p.restFrame or 0, b.id .. ": still, on its face-on frame")
			eq(before[i], p.pos, b.id .. ": did not move")
		end
	end
	-- hover one: it turns while the mouse is on it, then rests face-on again
	local other = picks[3]
	local S = H.state
	S[other].scripts.OnEnter(other)
	local p0 = other.preview.pos
	w:advance(0.8)
	ok(other.preview.pos ~= p0, "the hovered badge turns")
	S[other].scripts.OnLeave(other)
	w:advance(0.5)
	eq(other.preview.pos, other.preview.restFrame or 0, "back face-on when the mouse leaves")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- (BRIEF20 B9, updated for E3b-06) the bug report is where a player looks: a card on Settings home,
-- a link in the unfolded list, and at the end of unfolded Help (which has no contents list)
test("ui.settings.panel: B9 - Report a bug is a visible card on the home, a link unfolded, and at Help's end", function()
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	local UI = c.W.UI
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	local st = open(c, w)
	local bug
	for _, b in ipairs(st.find.cards) do if b.key == "bug" then bug = b end end
	ok(bug and H.visible(bug), "a Report a bug card on the home")
	-- (design 2) the home is three groups of rows and scrolls: the bug row is its last, seen at the list's end
	st.find.home:ScrollTo(st.find.home.max, true)
	local win = R(c.env.WuberFrame)
	local r = R(bug)
	ok(r.b >= win.b + 20, "inside the window: card bottom " .. r.b .. ", window bottom " .. win.b)
	local v = R(st.find.ver)
	ok(v.b + v.h <= r.b + 1, "the version line under it")
	local opened = 0
	local B = UI.Bug
	local was = B.Open
	B.Open = function() opened = opened + 1 end
	c:click(bug)
	B.Open = was
	eq(opened, 1, "the card opens the bug window")
	-- unfolded: a link under Help in the list
	UI.CloseSettings()
	w:advance(1)
	c.wide = true
	c.W.db.fold = { v = 1, pages = {}, narrow = false }
	st = open(c, w)
	ok(st.nav.bug and H.visible(st.nav.bug), "a Report a bug link in the unfolded list")
	local rb, rh = R(st.nav.bug), R(st.nav.help)
	ok(rb.b + rb.h <= rh.b + 1, "under Help")
	UI.CloseSettings()
	w:advance(1)
	-- Help unfolded: no contents list; scrolling to the end shows "Something not working?" and Report a bug
	UI.OpenHelp("settings")
	w:advance(1)
	local help = UI.settings.help
	eq(help.nav, nil, "no contents list in wide Help")
	UI.ScrollHelp(-40)
	w:advance(2)
	ok(H.visible(help.bug), "the Report a bug pill shows at the page end")
	T.clean(w)
end)

-- (E3b-06) wide Help has no contents list; it reads as the folded page does, with Report a bug at the end
test("ui.settings.panel: E3b-06 - wide Help has no contents list, reads like folded Help (whole pane wide), Something not working leads to Report a bug", function()
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	local UI = c.W.UI
	-- measure folded Help first
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Toggle(true)
	w:advance(3)
	UI.OpenHelp("settings")
	w:advance(1)
	local help = UI.settings.help
	local foldedW = R(help.clip).w
	UI.CloseHelp(true)
	UI.Toggle(false)
	w:advance(1)
	-- now wide Help
	c.wide = true
	c.W.db.fold = { v = 1, pages = {}, narrow = false }
	UI.Toggle(true)
	w:advance(3)
	UI.OpenHelp("settings")
	w:advance(1)
	ok(help.wide, "Help is in wide mode")
	eq(help.nav, nil, "wide Help has no contents list")
	local win, clip = R(c.env.WuberFrame), R(help.clip)
	-- (H24-07: Help unfolded takes the whole unfolded pane, twice the folded page; this line used to pin the empty right half)
	eq(math.floor(clip.w + 0.5), math.floor(foldedW * 2 + 0.5), "wide Help clip is the whole unfolded pane, twice the folded width")
	ok(clip.l >= win.l - 0.5 and clip.l + clip.w <= win.l + win.w + 0.5, "wide Help clip is inside the window")
	eq(#help.cards, #UI.HELP, "all Help cards are shown")
	-- scroll to the end: "Something not working?" leads to Report a bug
	UI.ScrollHelp(-40)
	w:advance(2)
	ok(H.visible(help.bugRow) and H.visible(help.bug), "Something not working? and Report a bug show at the end")
	local opened = 0
	local B = UI.Bug
	local was = B.Open
	B.Open = function() opened = opened + 1 end
	c:click(help.bug)
	B.Open = was
	eq(opened, 1, "Report a bug opens the bug window")
	T.clean(w)
end)
