-- Module: UI.Settings.Find
-- Purpose: Settings search and the folded Settings home (round 9, G1): the search box, the matches
--   (each with its section) and the "No settings match" state, the home's section list with a
--   one-line summary of each, and the brief highlight of the row a match opens.
-- API: (none: Settings' own parts, on Mod)
-- Internals: Mod.match, Mod.summary, Mod.build, Mod.place, Mod.paint, Mod.summaries, Mod.flash, Mod.why, Mod.lit, L, ICONS, QUICK, card, quick
-- What a match is: every Settings row (UI.Settings.Rows' row() lists it in st.index: label, its
--   description and tooltip) plus its hidden search words (RowsMod.KEYWORDS[label]) and its
--   section's name; every typed word must be in one of them (label matches first, then top to
--   bottom). A row in a hidden part (Driving for a Mage) is never a match. The search box never
--   takes the keyboard by itself (no autofocus, no SetFocus): only the player's click does.
-- A question works too (Polestar 18): with two or more words typed, question and filler words ("how do I",
--   "turn off", "the", "?") are left out and the rest must match; one word is searched exactly as typed.
-- The home (design 2): three T.RowGroup cards in a scroll (f.groups: the section rows; f.quick, the three most
--   used switches, each the same setting as the switch on its page; this window, Help, Report a bug), then the
--   version line. A match's row is washed by the row itself (row:Wash: soft violet that fades away).
-- Why it matched (2.3.2, I30): a match whose name doesn't hold every typed word gets a grey line
--   under its section, "matches: price" (the words that aren't in its name, fitted, never cut with
--   "..."), and its tooltip lights those words in gold.
-- Uses: UI.Settings.Rows
-- Later: UI.Settings.Panel (SECTIONS, sectionRanges, search, openSection, openResult)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/settings/find_test.lua
-- From: new in Wuber 2.3.0 round 9 (TEST-FINDINGS G1)
--
local _, W = ...
local Mod = W.Module("UI.Settings.Find", { "UI.Settings.Rows" })
local RowsMod = W.Mod("UI.Settings.Rows")
local INNER = RowsMod.INNER
local N = RowsMod.N
local PAD = RowsMod.PAD
local S = RowsMod.S
local WIN_W = RowsMod.WIN_W
local call = RowsMod.call
local db = RowsMod.db
local safeScript = RowsMod.safeScript
local st = RowsMod.st
local T = W.Theme
local Try = T.Try
local UI = W.UI

-- the folded home: big title + hint, search box under them, section cards under that; the matches
local L = { fieldY = 102, fieldH = 32, listY = 144, cardH = 54, gap = 6, resH = 50, resGap = 6, most = 40, flash = 1.6,
	flashA = 0.18, groupGap = 12, paneH = 544, whyH = 14, whyPx = "caption" }
Mod.L = L
local ICONS = { riding = "ride", driving = "wheel", map = "pin", sound = "speaker", window = "phone_glyph", help = "question", bug = "bug" }

local function Panel() return W.Mod("UI.Settings.Panel") end

local function onOff(v) return v and "on" or "off" end

---------------------------------------------------------------------------
-- One line per section: what it is set to now
---------------------------------------------------------------------------

local function badgeName()
	local ch = type(W.Char) == "function" and call(W.Char)
	local id = type(ch) == "table" and S(ch.badge) or nil
	if not id or id == "" then -- (r54 B) a founder with no pick shows the crown (no badge saved at all counts too)
		local mine = W.myKey
		if type(W.IsCreator) == "function" and mine and W.IsCreator(mine) == true then return "Founder (automatic)" end
		return "none"
	end
	for _, b in ipairs(type(W.BADGES) == "table" and W.BADGES or {}) do
		if type(b) == "table" and b.id == id then return S(b.name) or id end
	end
	return id
end

local SUMMARY = {
	riding = function(d)
		local adv = type(W.Advanced) == "function" and W.Advanced() == true
		if not adv then
			return "Tips " .. onOff(RowsMod.tipsOn()) .. " · flight offers " .. onOff(d.birdTip ~= false and d.flightOffers ~= false)
		end
		return "Auto-accept " .. onOff(d.autoAccept ~= false) .. " · your time "
			.. math.floor((N(d.timeValue) or 100000) / 10000 + 0.5) .. "g an hour"
	end,
	driving = function(d) return "Badge: " .. badgeName() .. " · advert " .. onOff(d.advertOnline ~= false) end,
	map = function(d)
		return "Map pins " .. onOff(d.mapPins ~= false) .. " · minimap " .. onOff(not d.minimapHidden)
	end,
	sound = function(d)
		local fx = type(T.FxLevel) == "function" and S(T.FxLevel()) or "full"
		return "Sound " .. onOff(d.sound ~= false) .. " · effects " .. fx .. " · badges " .. onOff(d.plates ~= false)
	end,
	window = function(d)
		local win = UI.state and UI.state.win
		local s = N(d.scale) or (win and N(win:GetScale())) or 1
		local adv = type(W.Advanced) == "function" and W.Advanced() == true
		if not adv then return "Size " .. math.floor(s * 100 + 0.5) .. "%" end
		local narrow = type(d.fold) == "table" and d.fold.narrow == true
		return "Size " .. math.floor(s * 100 + 0.5) .. "% · wide pages " .. (narrow and "off" or "auto")
	end,
	help = function() return "Why you might see few drivers" end,
	bug = function() return "A report to copy. Nothing is sent." end,
}

-- the line under a section's name on the home (tests)
function Mod.summary(key)
	local fn = SUMMARY[key]
	if not fn then return "" end
	local ok, line = pcall(fn, db())
	return ok and S(line) or ""
end

---------------------------------------------------------------------------
-- Matching
---------------------------------------------------------------------------

-- where a row sits in the scroll content: y, page key, advLocked (nil: hidden for another reason, or not in the scroll)
local function rowInfo(rec)
	local f = rec.frame
	if not f then return nil end
	local g, pageFrame = f, nil
	while g and g ~= st.content do
		local parent = g:GetParent()
		if parent == st.content then
			pageFrame = g
			break
		end
		if not g:IsShown() then return nil end
		g = parent
	end
	if not pageFrame or not pageFrame.page then return nil end
	local page = pageFrame.page
	local advLocked = false
	if not pageFrame:IsShown() then
		if not pageFrame.adv then return nil end
		local pageShown = false
		for _, fr in ipairs(st.chain or {}) do
			if fr.page == page and not fr.adv and fr:IsShown() then
				pageShown = true
				break
			end
		end
		if not pageShown then return nil end
		advLocked = true
	end
	local par = f:GetParent()
	local _, _, _, _, oy = f:GetPoint(1)
	-- (design 2) a row sits in its group's card: the card's place in the page, then the row's place in the card
	if f.group and par == f.group then
		par = par:GetParent()
		oy = (N(oy) or 0) - (N(f.group.topY) or 0)
	end
	local base = (st.frameTop and st.frameTop[par]) or 0
	return (N(base) or 0) - (N(oy) or 0), page, advLocked
end

-- words a question is wrapped in ("how do I turn off the sound?"): left out when other words are typed too
local FILLER = {}
for w in ("how do does did i me my we can could would should will to where is are was what whats which "
	.. "turn off on stop the a an it of for in get make why find change set"):gmatch("%S+") do FILLER[w] = true end

-- the typed words; with more than one word, the question's filler and "?" are dropped (never all of them,
-- and a one-word search is exactly as typed)
local function searchWords(query)
	local words = {}
	for w in tostring(query or ""):lower():gmatch("%S+") do words[#words + 1] = w end
	if #words < 2 then return words end
	local keep = {}
	for _, w in ipairs(words) do
		local bare = w:gsub("^[%?!%.,:;]+", ""):gsub("[%?!%.,:;]+$", "")
		if bare ~= "" and not FILLER[bare] then keep[#keep + 1] = bare end
	end
	if #keep == 0 then return words end
	return keep
end
Mod.searchWords = searchWords

-- the matches for what was typed: { rec, key, label, section, y, adv } (label matches first)
function Mod.match(query)
	local words = searchWords(query)
	if #words == 0 then return {} end
	local P = Panel()
	local names = {}
	for _, s in ipairs(P.SECTIONS) do names[s[1]] = s[2] end
	local kw = RowsMod.KEYWORDS or {}
	local first, rest = {}, {}
	for i, rec in ipairs(st.index or {}) do
		local y, key, advLocked = rowInfo(rec)
		if key then
			local label = S(rec.label) or ""
			local hay = (label .. " " .. (S(rec.desc) or "") .. " " .. (S(rec.tip) or "") .. " " .. (S(kw[label]) or "") .. " "
				.. (names[key] or "")):lower()
			local all, inLabel = true, true
			for _, w in ipairs(words) do
				if not hay:find(w, 1, true) then all = false break end
				if not label:lower():find(w, 1, true) then inLabel = false end
			end
			if all then
				local m = { rec = rec, key = key, label = label, section = names[key] or key, y = y, i = i, adv = advLocked }
				-- (I30) the typed words its name doesn't hold: why it matched
				local why, seen = {}, {}
				for _, w in ipairs(words) do
					if not seen[w] and not label:lower():find(w, 1, true) then why[#why + 1] = w end
					seen[w] = true
				end
				m.why = why
				if inLabel then first[#first + 1] = m else rest[#rest + 1] = m end
			end
		end
	end
	local function byY(a, b)
		if a.y ~= b.y then return a.y < b.y end
		return a.i < b.i
	end
	table.sort(first, byY)
	table.sort(rest, byY)
	for _, m in ipairs(rest) do first[#first + 1] = m end
	return first
end

---------------------------------------------------------------------------
-- Building (once, from the panel's build)
---------------------------------------------------------------------------

local function hoverable(b, colour)
	b:SetScript("OnEnter", function(self) self.bg:SetColor("hover") end)
	b:SetScript("OnLeave", function(self) self.bg:SetColor(colour) end)
	T.Press(b, { fill = b.bg })
end

local function chevron(b)
	local c = T.Icon(b, "chevron", 12, "muted", "ARTWORK")
	c:SetPoint("RIGHT", b, "RIGHT", -14, 0)
	return c
end

-- (design 2) the home is groups of rows (T.RowGroup): Advanced mode, the sections, the most used switches,
-- and This window, Help and Report a bug. A section row: icon, name, what it is set to; a tap opens it.
local QUICK = { { "autoAccept", "ride", true }, { "mapPins", "pin" }, { "sound", "speaker" } }
Mod.QUICK = QUICK

local function card(group, key, label, tip)
	local b = group:Row({ title = label, icon = ICONS[key] or "gear", right = "chevron", tip = { title = label, body = tip },
		onClick = function(self)
			if self.key == "help" then UI.OpenHelp("settings")
			elseif self.key == "bug" then Panel().openBug()
			else Panel().openSection(self.key) end
		end })
	b.key, b.label, b.desc, b.chev = key, b.title, b.sub, b.chevron
	return b
end

-- one of the most used switches on the home: the SAME setting as the switch on its page (its title, its tooltip,
-- its get and its put), so both places stay in step
local function quick(group, key, icon)
	local t = st.controls and st.controls[key]
	local src = t and t.row
	if not (src and type(t.get) == "function" and type(t.put) == "function") then return nil end
	local r
	r = group:Row({ title = src.titleText, icon = icon, right = "switch", on = t.get() and true or false,
		tip = { title = src.titleText, body = src.wuberTip and src.wuberTip.text },
		onChange = function(on)
			t.put(on, t)
			if t.on ~= on then t:SetOn(on) end
			if type(UI.UpdateSettings) == "function" then UI.UpdateSettings() end
		end })
	r.key, r.source = key, t
	return r
end

-- a match: the setting's name and its section; a tap opens the section at it
local function item(f, i)
	local b = f.items[i]
	if b then return b end
	b = CreateFrame("Button", nil, f.results.content)
	b:SetSize(INNER, L.resH)
	b:RegisterForClicks("LeftButtonUp")
	b.bg = T.Rounded(b, "card", 12, "BACKGROUND", 0)
	b.label = T.Text(b, "body", "white", "LEFT", "bold")
	b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 14, -9)
	b.label:SetWidth(INNER - 48)
	Try(b.label, "SetWordWrap", false)
	b.where = T.Text(b, "caption", "muted", "LEFT", "medium")
	b.where:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -4)
	b.where:SetWidth(INNER - 48)
	-- (I30) why it matched: the typed words that aren't in its name
	b.why = T.Text(b, L.whyPx, "muted", "LEFT", "regular")
	b.why:SetPoint("TOPLEFT", b.where, "BOTTOMLEFT", 0, -3)
	b.why:SetWidth(INNER - 48)
	b.why:Hide()
	b.chev = chevron(b)
	hoverable(b, "card")
	T.Tip(b, function(self) return self.m and self.m.label end, function(self)
		local m = self.m
		if not m then return nil end
		local why = m.why or {}
		local where = m.adv and (m.section .. ", Advanced") or m.section
		local text = "In " .. where .. ". " .. Mod.lit(S(m.rec.tip) or "", why)
		if #why > 0 then text = text .. "\n\nMatches: " .. Mod.lit(table.concat(why, " "), why) end
		return text
	end)
	safeScript(b, "OnClick", function(self)
		if not self.m then return end
		Panel().openResult(self.m)
	end)
	f.items[i] = b
	return b
end

-- the placeholder: the longest of these that fits the box on one line (never cut, never wrapped)
local HINTS = { "Ask or search: how do I mute sounds?", "Ask or search settings", "Search settings" }
Mod.HINTS = HINTS

local function fitHint(box)
	local hint = box and box.hint
	if not hint then return end
	local w = N(box:GetWidth()) or INNER
	local room = w - 66 - 4 -- the typing room (32 left, 34 right) and a little spare
	local pick = HINTS[#HINTS]
	for _, text in ipairs(HINTS) do
		hint:SetText(text)
		if T.TextWidth(hint, text) <= room then pick = text break end
	end
	hint:SetText(pick)
	box.hintText = pick
end
Mod.fitHint = fitHint

local function searchBox(p, f)
	local box = T.Field(p, INNER, L.fieldH, { placeholder = "Search settings", size = "sub", max = 40,
		get = function() return st.query or "" end,
		onChange = function(text) Panel().search(text) end })
	-- the magnifier left, the x right; the typing room between them
	local eb = box.edit
	eb:SetAutoFocus(false)
	eb:ClearAllPoints()
	eb:SetPoint("TOPLEFT", box, "TOPLEFT", 32, 0)
	eb:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -34, 0)
	fitHint(box)
	box.icon = T.Icon(box.inner, "search", 14, "muted", "ARTWORK")
	box.icon:SetPoint("LEFT", box, "LEFT", 12, 0)
	box.clear = T.RoundButton(box, "close", 22, "raised")
	box.clear:SetPoint("RIGHT", box, "RIGHT", -5, 0)
	box.clear:SetFrameLevel((N(box:GetFrameLevel()) or 0) + 5)
	safeScript(box.clear, "OnClick", function() Panel().search("") end)
	T.Tip(box.clear, "Clear", "Clears the search.")
	box.clear:Hide()
	-- Esc clears it (and lets go of the keyboard)
	safeScript(eb, "OnEscapePressed", function(self)
		box.focused = nil
		pcall(self.ClearFocus, self)
		Panel().search("")
		box:Sync()
	end)
	box:EnableMouse(true)
	T.Tip(box, "Search settings", "Click and type a word (sound, invite, map, price) to find a setting. Esc or the x clears it.")
	T.Tip(eb, "Search settings", "Click and type a word (sound, invite, map, price) to find a setting. Esc or the x clears it.")
	f.box = box
	-- (#203) the game leaves the keyboard in a box until Esc, whatever the player presses next, and then no key reaches the game
	-- (movement, bars, the big button's key). Let go when Settings shows or hides, on a tab switch, and on a press anywhere
	-- outside the box (its pill, its x, the box itself keep it: that is the player typing)
	local function release()
		if eb:HasFocus() then pcall(eb.ClearFocus, eb) box.focused = nil pcall(box.Sync, box) end
	end
	local function inBox(fr)
		local n = 0
		while type(fr) == "table" and n < 12 do
			if fr == box or fr == eb then return true end
			local okp, par = pcall(fr.GetParent, fr)
			if not okp then return false end
			fr, n = par, n + 1
		end
		return false
	end
	local function pressedInside()
		local foci
		if type(GetMouseFoci) == "function" then
			local okf, list = pcall(GetMouseFoci)
			if okf and type(list) == "table" then foci = list end
		elseif type(GetMouseFocus) == "function" then
			local okf, one = pcall(GetMouseFocus)
			if okf and one then foci = { one } end
		end
		for _, fr in ipairs(foci or {}) do
			if inBox(fr) then return true end
		end
		return false
	end
	p:HookScript("OnShow", release)
	p:HookScript("OnHide", release)
	if type(hooksecurefunc) == "function" and type(W.UI) == "table" and type(W.UI.SelectTab) == "function" then
		pcall(hooksecurefunc, W.UI, "SelectTab", release)
	end
	local watch = CreateFrame("Frame", nil, p)
	pcall(watch.RegisterEvent, watch, "GLOBAL_MOUSE_DOWN")
	watch:SetScript("OnEvent", function()
		if eb:HasFocus() and not pressedInside() then release() end
	end)
	f.releaseKeys = release
end

function Mod.build(p)
	local f = { items = {}, cards = {} }
	st.find = f
	searchBox(p, f)
	-- the home: a card per section, Help last, the version under them
	-- (design 2) three groups of rows; the home scrolls when they are taller than the phone
	local home = T.Scroll(p, { lift = 12 }) -- its soft edges and bar stay under Help when Help opens over Settings
	home:SetSize(WIN_W, L.paneH - L.listY)
	home:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -L.listY)
	f.home = home
	local inner = home.content
	f.groups = { T.RowGroup(inner, INNER), T.RowGroup(inner, INNER), T.RowGroup(inner, INNER), T.RowGroup(inner, INNER) }
	f.quick = {}
	f.advQuick = quick(f.groups[1], "advanced", "gear")
	if f.advQuick then f.quick[#f.quick + 1] = f.advQuick end
	for _, sec in ipairs(Panel().SECTIONS) do
		f.cards[#f.cards + 1] = card(f.groups[sec[1] == "window" and 4 or 2], sec[1], sec[2], sec[3])
	end
	for _, q in ipairs(QUICK) do
		local r = quick(f.groups[3], q[1], q[2])
		if r then
			r.adv = q[3] and true or false
			f.quick[#f.quick + 1] = r
		end
	end
	f.help = card(f.groups[4], "help", "Help: how Wuber finds drivers", "Why you might see few or no drivers, and what helps.")
	f.cards[#f.cards + 1] = f.help
	-- (BRIEF20 B9) the bug report is a row on the home too, not only a row deep in "This window"
	f.bug = card(f.groups[4], "bug", "Report a bug", "Opens a short report to copy: your Wuber version, game build, window and the last errors. Other players' names become \"player 1\", \"player 2\" and nothing is sent.")
	f.cards[#f.cards + 1] = f.bug
	f.ver = T.Text(inner, "caption", "muted", "CENTER", "regular")
	f.ver:SetWidth(INNER)
	f.ver:SetText("Wuber " .. tostring(W.VERSION or "") .. " · /wuber opens this app")
	-- the matches (a scroll with the shared soft edges) and the empty state
	f.results = T.Scroll(p, {})
	f.none = CreateFrame("Frame", nil, p)
	f.none.head = T.Text(f.none, "body", "white", "CENTER", "bold")
	f.none.head:SetPoint("TOP", f.none, "TOP", 0, -36)
	f.none.head:SetWidth(INNER)
	f.none.head:SetText("No settings match")
	f.none.sub = T.Text(f.none, "caption", "muted", "CENTER", "regular")
	f.none.sub:SetPoint("TOP", f.none.head, "BOTTOM", 0, -6)
	f.none.sub:SetWidth(INNER)
	f.none.sub:SetText("Try another word, like sound, invite or map.")
	f.none.clear = T.Pill(f.none, "Clear", "dark", 96, 30)
	f.none.clear:SetPoint("TOP", f.none.sub, "BOTTOM", 0, -14)
	f.none.clear.fill:SetColor("raised")
	f.none.clear:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(f.none.clear, "OnClick", function() Panel().search("") end)
	T.Tip(f.none.clear, "Clear", "Clears the search and shows every section again.")
	-- the highlight's fade (alpha only, never a scale)
	f.ticker = CreateFrame("Frame", nil, p)
	f.ticker:Hide()
	safeScript(f.ticker, "OnUpdate", function(self, elapsed)
		local fl = f.flashing
		if not fl or fl.row then self:Hide() return end
		fl.t = fl.t - (N(elapsed) or 0)
		if fl.t <= 0 then
			fl.tex:SetShown(false)
			f.flashing = nil
			self:Hide()
			return
		end
		fl.tex:SetAlpha(fl.t / L.flash) -- (BRIEF22 G1) the wash keeps its colour's alpha; the region fades
	end)
	Mod.paint("")
	return f
end

---------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------

local function showIf(fr, on)
	if on then fr:Show() else fr:Hide() end
end

-- the home's lines, from the saved values
function Mod.summaries()
	local f = st.find
	if not f then return end
	for _, b in ipairs(f.cards) do b.desc:SetText(Mod.summary(b.key)) end
	-- the home's switches show what their pages' switches show
	for _, r in ipairs(f.quick or {}) do
		local on = r.source.get() and true or false
		if r.switch.on ~= on then r.switch:SetOn(on) end
	end
end

-- what shows for the view ("home" | "results" | "section"), folded or unfolded. geo: the
-- panel's unfolded geometry (navW, clipX, clipTop, clipBottom, paneH).
function Mod.place(view, wide, geo)
	local f = st.find
	if not f then return end
	local p = st.panel
	local box = f.box
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -L.fieldY)
	box:SetWidth(wide and (geo.navW - PAD) or INNER)
	fitHint(box)
	showIf(box, wide or view ~= "section")
	showIf(box.clear, (st.query or "") ~= "")
	-- the home's cards: the sections that show (Driving only for drivers), then Help
	local onHome = not wide and view == "home"
	showIf(f.home, onHome)
	if onHome then
		local adv = type(W.Advanced) == "function" and W.Advanced() == true
		local shown = {}
		for _, r in ipairs(Panel().sectionRanges()) do shown[r.key] = true end
		for _, b in ipairs(f.cards) do
			b:SetShown(b.key == "help" or b.key == "bug" or shown[b.key] == true)
		end
		for _, r in ipairs(f.quick or {}) do
			if r.adv then r:SetShown(adv) end
		end
		Mod.summaries()
		local y = 0
		for _, g in ipairs(f.groups) do
			local h = g:Layout()
			showIf(g, h > 0)
			if h > 0 then
				g:ClearAllPoints()
				g:SetPoint("TOPLEFT", f.home.content, "TOPLEFT", PAD, -y)
				y = y + h + L.groupGap
			end
		end
		f.ver:ClearAllPoints()
		f.ver:SetPoint("TOP", f.home.content, "TOPLEFT", WIN_W / 2, -(y + 2))
		f.home:SetHeight((geo.paneH or L.paneH) - L.listY - (N(geo.clipBottom) or 0))
		f.home:SetContentHeight(y + 2 + 16 + 8)
	end
	-- the matches: under the box folded, in the right pane unfolded
	local res, none = f.results, f.none
	local x, top = 0, L.listY
	if wide then x, top = geo.clipX, geo.clipTop end
	local h = (geo.paneH or L.paneH) - top - geo.clipBottom
	for _, fr in ipairs({ res, none }) do
		fr:ClearAllPoints()
		fr:SetPoint("TOPLEFT", p, "TOPLEFT", x, -top)
		fr:SetSize(WIN_W, h)
		fr:SetFrameLevel((N(p:GetFrameLevel()) or 0) + 12)
	end
	local searching = view == "results"
	showIf(res, searching and (f.count or 0) > 0)
	showIf(none, searching and (f.count or 0) == 0)
	if searching then res:SetContentHeight(f.contentH or 1) end
end

-- (I30) the grey "matches: price" line for a match's words (nil: its name holds them all). Fitted
-- to the row: words that don't fit are left off (never "..." from the game).
function Mod.why(words)
	if type(words) ~= "table" or #words == 0 then return nil end
	local room = INNER - 48
	local function fits(t) return (N(T.MeasureText(t, L.whyPx, "regular")) or 0) <= room end
	local list = {}
	for i = 1, #words do list[i] = words[i] end
	local text = "matches: " .. table.concat(list, " ")
	while not fits(text) and #list > 1 do
		list[#list] = nil
		text = "matches: " .. table.concat(list, " ")
	end
	-- one very long word: as much of it as fits
	while not fits(text) and #text > 10 do text = text:sub(1, -2) end
	return text
end

-- (I30) text with the typed words lit in gold (any case; the text's own letters kept)
function Mod.lit(text, words)
	text = tostring(text or "")
	if type(words) ~= "table" or #words == 0 or text == "" then return text end
	local low, out, i = text:lower(), {}, 1
	local gold = T.Code("glow")
	while i <= #text do
		local hit
		for _, w in ipairs(words) do
			if #w > 0 and low:sub(i, i + #w - 1) == w and (not hit or #w > hit) then hit = #w end
		end
		if hit then
			out[#out + 1] = gold .. text:sub(i, i + hit - 1) .. "|r"
			i = i + hit
		else
			out[#out + 1] = text:sub(i, i)
			i = i + 1
		end
	end
	return table.concat(out)
end

-- fills the matches for what was typed
function Mod.paint(query)
	local f = st.find
	if not f then return end
	local list = Mod.match(query)
	local n = math.min(#list, L.most)
	local y = 4
	for i = 1, n do
		local m = list[i]
		local b = item(f, i)
		b.m = m
		b.label:SetText(m.label)
		b.where:SetText(m.adv and (m.section .. " · Advanced") or m.section)
		local why = Mod.why(m.why)
		b.why:SetText(why or "")
		showIf(b.why, why ~= nil)
		local h = L.resH + (why and L.whyH or 0)
		b:SetHeight(h)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f.results.content, "TOPLEFT", PAD, -y)
		b:Show()
		y = y + h + L.resGap
	end
	for i = n + 1, #f.items do
		f.items[i].m = nil
		f.items[i]:Hide()
	end
	f.count = n
	f.list = list
	f.contentH = y + 4
	f.results:ScrollTo(0, true)
	f.results:SetContentHeight(f.contentH)
end

-- a brief highlight on the row a match opened (a violet wash that fades out)
function Mod.flash(frame)
	local f = st.find
	if not (f and frame) then return end
	-- (design 2) a row of a group washes itself: soft violet (18%), held a moment, then it fades away
	if type(frame.Wash) == "function" then
		if f.flashing and f.flashing.frame ~= frame then
			if f.flashing.frame.Unwash then f.flashing.frame:Unwash() else f.flashing.tex:SetShown(false) end
		end
		frame:Wash()
		frame.wuberFlash = frame.wash.fill
		f.flashing = { tex = frame.wash.fill, frame = frame, row = true }
		return
	end
	frame.wuberFlash = frame.wuberFlash or T.Rounded(frame, { T.RGB("accent", L.flashA) }, 12, "BACKGROUND", 1)
	if f.flashing and f.flashing.tex ~= frame.wuberFlash then
		if f.flashing.row then f.flashing.frame:Unwash() else f.flashing.tex:SetShown(false) end
	end
	frame.wuberFlash:SetAlpha(1)
	frame.wuberFlash:SetShown(true)
	f.flashing = { tex = frame.wuberFlash, t = L.flash, frame = frame }
	f.ticker:Show()
end
