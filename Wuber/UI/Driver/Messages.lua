-- Module: UI.Driver.Messages
-- Purpose: Messages editor with live preview, and the Blocked list. (2.3) Unfolded: the list left,
--   the editor in the side pane (D.FOLD.messages). (2.4) The editors of Greeting, Welcome, please pay and You're
--   next hold the switch that sends the message by itself (Drive.AutoLines: DR.LineOn, DR.SetLineOn, called at run
--   time).
-- API: UI.ADVERT_TIP, D.screens.messages, D.screens.blocked, D.FOLD.messages
-- Internals: (none)
-- Uses: UI.Driver.Screens
-- Later: UI.Driver.Console (D.SidePane, run time)
-- Events: (none)
-- Standalone: no
-- Test: tests/ui/driver/messages_test.lua
-- From: UI_Drive.lua 1121-1457 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Messages", { "UI.Driver.Screens" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local INNER, PAD, Pool, Screen = ScreensMod.INNER, ScreensMod.PAD, ScreensMod.Pool, ScreensMod.Screen
local dr, nameOf, para, plural = ScreensMod.dr, ScreensMod.nameOf, ScreensMod.para, ScreensMod.plural
local safeScript, setShown, st, toast = ScreensMod.safeScript, ScreensMod.setShown, ScreensMod.st, ScreensMod.toast
local T = W.Theme
local function wrapH(n, size) return n * T.DrawnSize(size) + (n - 1) * T.Spacing(size) end -- n wrapped lines, spacing between them
local Try = T.Try
local UI = W.UI

local DR = W.Drive
local D = W.Driver

local K = D.kit or {}

local S, N = W.Str, W.Num

---------------------------------------------------------------------------
-- Messages: the ten whispers, each editable with a live preview
---------------------------------------------------------------------------

local MESSAGES = {
	greet = { "Greeting", "when you start their summon" },
	price = { "Price", "when someone asks what it costs", list = "when someone asks" },
	offer = { "Offer", "to a buyer in public chat, with the invite", list = "to a buyer in public chat" },
	pay = { "Welcome, please pay", "when they land" },
	thanks = { "Thanks", "when they have paid" },
	tip = { "Thanks for the tip", "when they pay more than your price", list = "" },
	short = { "Paid too little", "when the trade is short", list = "" },
	busy = { "Already in a group", "when they can't be invited" },
	refuse = { "Blocked", "to a blocked player who asks" },
	-- 2.4: the big button's oops step (Drive.Careful's DR.Oops)
	oops = { "Oops, wrong invite", "when you undo a wrong invite" },
	advert = { "My advert line", "in public chat when you click Advertise" },
	-- 2.1 (SPEC4): stations, summoners without Wuber, raid summons
	where = { "Where to?", "when we don't know the place" },
	callsum = { "Ask a summoner", "chat, to a Warlock without Wuber" },
	raidsum = { "Raid: summon coming", "whisper to the raider" },
	raidclick = { "Raid: click the portal", "a raid chat line" },
	-- round 9 (Y1): only when you pick "Get Wuber" for a rider without the app (Drive.Book); BRIEF17 B2: the row's pill
	getapp = { "Get Wuber", "on your next big-button click after you tap Invite to Wuber on their row" },
	-- 2.4 (the decisions round): sent only by itself, with its switch on (Drive.AutoLines)
	next = { "You're next", "to the first rider waiting in your line" },
}
local MSG_ORDER = { "greet", "price", "offer", "next", "pay", "thanks", "tip", "short", "busy", "refuse", "oops", "advert", "where", "getapp", "callsum", "raidsum", "raidclick" }

-- (the decisions round, the author's yes of 21 Nov 2026 22:28) the three messages that can go by themselves
-- (Drive.AutoLines, DR.LINE_KINDS): each has its own switch in its editor, off until the driver turns it on.
-- { the switch's label, the line under it, the tooltip's text }
local AUTO_WORDS = {
	greet = { "Send the greeting by itself", "Wuber whispers it to your rider without your click, when you start their summon.",
		"Only to a rider who asked you and is in your group. Skipped when it cannot go, like in combat. Off: your click sends it." },
	pay = { "Send the pay reminder by itself", "Wuber whispers it to your rider without your click, 25 seconds after they land, once per ride.",
		"Only to a rider who asked you and is in your group. When it cannot go by itself, for example in combat, it waits for your click as before. Off: your click sends it." },
	next = { "Send You're next by itself", "Wuber whispers it without your click to a rider without the app who is first in your line and has waited 10 seconds, once per ride.",
		"Only to a rider who whispered you and waits for room. Skipped when it cannot go, such as in combat. Off: never sent." },
}

-- the made-up rider every preview is written for
-- (2.3.2, S5) what they paid depends on the message: the fare for Thanks, more for the tip, less only
-- for "Paid too little" (a tip is never previewed below the fare)
local function sample(kind)
	local price = (K.Price and K.Price()) or W.MIN_PRICE or 5000
	local paid = kind == "tip" and math.floor(price * 1.2) or (kind == "short" and math.floor(price * 0.6)) or price
	return { name = "Dan Rider", key = "dan rider", price = price, paid = paid, state = "arrived",
		reason = "you left without paying last time",
		summoner = type(W.Me) == "function" and S(W.Me()) or nil }
end

local function textOf(kind, draft)
	-- (HUNT-75) an emptied box previews the default wording, which is what Save goes back to
	if type(draft) == "string" and draft:gsub("%s", "") == "" then draft = S(DR.TEMPLATES and DR.TEMPLATES[kind]) end
	-- (2.3.2, S5) the list previews the saved words, as the editor does (no crew-payee variant of them)
	if draft == nil then draft = S(dr("Template", kind)) or S(DR.TEMPLATES and DR.TEMPLATES[kind]) end
	local t = dr("Text", kind, sample(kind), draft)
	return S(t) or ""
end

local function limitOf(kind) return kind == "advert" and (N(DR.ADVERT_MAX) or 200) or 190 end

local mside -- (2.3) the messages page's side pane, once it has unfolded (D.FOLD.messages)
local SIDE_W = 324 -- what fits in it at x PAD (18 px padding, as the rider's pages)

-- the rows: title and when only (the chosen one lit when unfolded); returns the list's height
local function layRows(s, wide)
	local y = 32
	for _, r in ipairs(s.rows) do
		local h = r.rowH or 40
		r:SetHeight(h)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", s.content, "TOPLEFT", PAD, -y)
		r.title:ClearAllPoints()
		r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -12)
		r.when:ClearAllPoints()
		r.when:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -13)
		r.bg:SetColor((wide and r.kind == s.kind) and "raised" or "card")
		y = y + h + 6
	end
	return y + 6
end

-- (BRIEF22 L2) the view's bottom edge never slices a text at the top of the page (the layout checker's
-- "clipped"): it ends just above the first text it would cut, so the rest waits whole below it. Positions are
-- from the content's top, so the scroll offset doesn't matter; shown, not visible: the page may be hidden yet. Returns how far the edge goes up (px).
local function sliceLift(content, view)
	local top = N(content:GetTop())
	if not top or view <= 0 then return 0 end
	local edge = view
	local function walk(f)
		for _, r in ipairs({ f:GetRegions() }) do
			local tx = r:GetObjectType() == "FontString" and r:IsShown() and r:GetText()
			local t, b = N(r:GetTop()), N(r:GetBottom())
			if type(tx) == "string" and tx:match("%S") and t and b and top - t < edge - 0.5 and top - b > edge + 0.5 then
				edge = top - t - 2
			end
		end
		for _, ch in ipairs({ f:GetChildren() }) do if ch:IsShown() then walk(ch) end end
	end
	for _ = 1, 4 do -- a lifted edge can land in a text above: again until it rests in a gap
		local was = edge
		walk(content)
		if edge == was then break end
	end
	return math.max(0, math.min(80, math.floor(view - edge + 0.5)))
end

-- (Design 2) Save is the page's one main button and Reset a link above it, both on the page (host), not in the
-- scrolling editor: they keep their place. ED_ROOM is what the editor's scroll leaves free under it.
local ED_ROOM = T.MAIN.foot + T.MAIN.h + 6 + 34 + 6

-- the list's view: up off a card's text it would slice (on), or down to the page's bottom (the folded editor)
local function fitView(s, on)
	local full = (N(s.frame:GetHeight()) or 0) - 56 -- the view from Screen: 50 under the top, 6 over the bottom
	local up = on and sliceLift(s.content, full) or 0
	local room = (not on and s.kind) and ED_ROOM or 0 -- (Design 2) the folded editor leaves room under it for Save
	if (s.lift or 0) == up and (s.room or 0) == room then return end
	s.lift, s.room = up, room
	s.scroll:ClearAllPoints()
	s.scroll:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, -50)
	s.scroll:SetPoint("BOTTOMRIGHT", s.frame, "BOTTOMRIGHT", 0, 6 + up + room)
	s.scroll:SetContentHeight(N(s.content:GetHeight()) or 1)
end

UI.ADVERT_TIP = "Typing your own adverts in Trade? Put Wuber in them: other Wuber players' addons hear it and add you, so riders find you."

-- the editor on c, its parts at x pad, iw wide (folded: 10 and 340; in the side pane: 10 and 324)
local function edFoot(e, on)
	if on then
		-- (the decisions round) the switch card can lie in the part of the editor that is scrolled out of sight under
		-- them: Save and Reset stay on top of it, so the click is theirs
		local top = (N(e.auto.toggle:GetFrameLevel()) or 0) + 10
		for _, b in ipairs({ e.save, e.reset }) do
			if (N(b:GetFrameLevel()) or 0) < top then b:SetFrameLevel(top) end
		end
		e.save:Show()
		e.reset:Show()
	else
		e.save:Hide()
		e.reset:Hide()
	end
end

local function buildEditor(s, c, pad, iw, host)
	local e = CreateFrame("Frame", nil, c)
	e:SetAllPoints(c)
	e:Hide()
	e.pad, e.iw = pad, iw
	-- (HUNT-113) the explaining line wraps (the advert's takes two lines); everything below it sits in e.body,
	-- which s.edit moves down by the extra height (e.shift)
	e.when = para(e, "caption", "muted", iw - 8)
	e.when:SetPoint("TOPLEFT", e, "TOPLEFT", pad + 4, -4)
	e.shift = 0
	local bd = CreateFrame("Frame", nil, e)
	bd:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
	bd:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", 0, 0)
	e.body = bd
	e.field = T.Field(bd, iw, 112, { multi = true, max = 230, size = "sub",
		onChange = function() s.preview() end })
	e.field:SetPoint("TOPLEFT", bd, "TOPLEFT", pad, -24)
	T.Tip(e.field.edit, "Your message", "Type it as you'd say it. Tap a chip below to put in the rider's name, your price and so on.")
	e.meter = T.Text(bd, "caption", "muted", "RIGHT", "medium")
	e.meter:SetPoint("TOPRIGHT", bd, "TOPRIGHT", -pad - 4, -142)
	e.meter:SetWidth(120)
	e.chipHead = T.Text(bd, "caption", "glow", "LEFT", "bold")
	e.chipHead:SetPoint("TOPLEFT", bd, "TOPLEFT", pad + 4, -142)
	e.chipHead:SetText("Tap to add")
	e.chips = {}
	local x, y = pad, 160
	local places = DR.PLACEHOLDERS or { "name", "price", "dest", "service", "guild", "keyword", "paid", "due", "reason" }
	local TIPS = {
		name = "The rider's name", price = "Your price", dest = "Where you summon to", service = "The name riders see",
		guild = "Your guild's name", keyword = "The word riders whisper", paid = "What they paid", due = "What they still owe",
		reason = "Why they're blocked", payto = "Who they trade the gold to", places = "Every place your crew summons to",
		summoner = "The Warlock who summons them", caster = "Who casts this summon",
	}
	-- (round 9, S17) what a chip becomes, for the made-up rider Dan (with this window as the summoner)
	local function example(p)
		local c = sample(s.kind)
		c.summoner = type(W.Me) == "function" and S(W.Me()) or nil
		local t = S(dr("Text", s.kind or "greet", c, "{" .. p .. "}"))
		if not t or t == "" then return nil end
		return t
	end
	for _, p in ipairs(places) do
		local text = "{" .. p .. "}"
		local b = T.Pill(bd, text, "dark", 60, 24)
		-- (round 13, I6) each chip as wide as its word, with room to spare, and the word never held
		-- to a width (7 of 13 read '{pric...' in Google's shots): the label sits centred, unbounded
		b.label:ClearAllPoints()
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label.wuberRoom = nil
		T.Fit(b.label) -- back to its own size (it was fitted to the 60 px it was made with)
		local wd = math.ceil(T.TextWidth(b.label, text) * 1.12) + 24
		b:SetWidth(wd)
		b.fill:SetColor("raised")
		b:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
		if x + wd > pad + iw then
			x = pad
			y = y + 30
		end
		b:SetPoint("TOPLEFT", bd, "TOPLEFT", x, -y)
		x = x + wd + 6
		b.code = text
		safeScript(b, "OnClick", function(self)
			local eb = e.field.edit
			pcall(eb.SetFocus, eb)
			if not pcall(eb.Insert, eb, self.code) then e.field:SetText(e.field:Text() .. self.code) end
			e.field.hint:Hide()
			s.preview()
		end)
		T.Tip(b, text, function()
			local ex = example(p)
			return (TIPS[p] or p) .. (ex and (". For example: " .. ex) or "") .. ".\nTap to put it where the cursor is."
		end)
		e.chips[#e.chips + 1] = b
	end
	y = y + 36
	e.prevHead = T.Text(bd, "caption", "glow", "LEFT", "bold")
	e.prevHead:SetPoint("TOPLEFT", bd, "TOPLEFT", pad + 4, -y)
	e.prevHead:SetText("As the rider reads it")
	y = y + 18
	e.bubble = T.Card(bd, iw, 70, { colour = { 0.53, 0.25, 0.85, 0.32 }, radius = 16, shadow = false }) -- (BRIEF22 G1) its alpha from the start
	e.bubble:SetPoint("TOPLEFT", bd, "TOPLEFT", pad, -y)
	e.bubble:EnableMouse(true)
	T.Tip(e.bubble, "Preview", "Exactly what Wuber whispers, here for a made-up rider called Dan.")
	e.prev = para(e.bubble, "caption", "white", iw - 24, 5)
	e.prev:SetPoint("TOPLEFT", e.bubble, "TOPLEFT", 12, -10)
	e.prevY = y
	e.why = para(bd, "caption", "red", iw - 8, 2)
	e.tip = para(bd, "caption", "muted", iw - 8, 3)
	e.tip:SetText(UI.ADVERT_TIP)
	e.tip:Hide()
	-- (the decisions round) Greeting and Welcome, please pay: the switch that sends the message by itself, under the
	-- preview (s.preview places it and sets its words; hidden for every other message)
	local au = CreateFrame("Frame", nil, bd)
	au:SetSize(iw, 70)
	au.bg = T.Rounded(au, "card", 12, "BACKGROUND", 0)
	au.label = T.Text(au, "sub", "white", "LEFT", "bold")
	au.label:SetPoint("TOPLEFT", au, "TOPLEFT", 14, -11)
	au.label:SetWidth(iw - 86)
	au.note = para(au, "caption", "muted", iw - 86)
	au.note:SetPoint("TOPLEFT", au, "TOPLEFT", 14, -30)
	au.toggle = T.Toggle(au, false, function(on)
		if AUTO_WORDS[s.kind] then dr("SetLineOn", s.kind, on) end
	end)
	au.toggle:SetPoint("RIGHT", au, "RIGHT", -14, 0)
	local function autoTitle() return (AUTO_WORDS[s.kind] or AUTO_WORDS.greet)[1] end
	local function autoTip() return (AUTO_WORDS[s.kind] or AUTO_WORDS.greet)[3] end
	T.Tip(au.toggle, autoTitle, autoTip)
	au:EnableMouse(true)
	T.Tip(au, autoTitle, autoTip)
	au:Hide()
	e.auto = au
	e.reset = T.Pill(host, "Reset to default", "ghost", 150, 34)
	e.reset:SetPoint("BOTTOM", host, "BOTTOM", 0, T.MAIN.foot + T.MAIN.h + 6) -- centred over the main button
	e.reset:Hide()
	e.reset.label:SetTextColor(T.RGB("muted"))
	safeScript(e.reset, "OnClick", function()
		local ok, why = dr("SetTemplate", s.kind, nil)
		if ok then
			toast("Back to Wuber's own words", "info")
			e.field:SetText(S(dr("Template", s.kind)) or S(DR.TEMPLATES and DR.TEMPLATES[s.kind]) or "")
			s.preview()
		else
			toast(S(why) or "Couldn't reset it", "warn")
		end
	end)
	T.Tip(e.reset, "Reset to default", "Puts back Wuber's own wording for this message (your crew gets it too if you lead the crew).")
	e.save = T.MainButton(host, "Save")
	e.save:Hide()
	safeScript(e.save, "OnClick", function()
		local ok, why = dr("SetTemplate", s.kind, e.field:Text())
		if ok then
			-- (HUNT-30) only the crew's captain shares it; a member's window keeps its own words
			local member = type(DR.char) == "function" and (S((DR.char() or {}).captain) or "") ~= ""
			toast(member and "Saved" or "Saved · your crew uses it too", "found")
			s.list()
		else
			-- (AUD-167) kept, so the preview reserves its height above Reset and Save
			e.refused = { draft = e.field:Text(), text = "Not saved: " .. (S(why) or "refused") }
			s.preview()
			-- the refusal sits at the foot of the editor: bring it into view, above Reset and Save
			local sc = s.isWide() and mside.scroll or s.scroll
			pcall(sc.ScrollTo, sc, tonumber(sc.max) or 0, true)
		end
	end)
	T.Tip(e.save, "Save", "Uses this message from now on. If you lead the crew, every window of your crew uses it too.")
	return e
end

D.screens.messages = function(parent)
	local s = Screen(parent, "Messages")
	st.screens.messages = s
	local c = s.content
	s.rows = {}
	s.intro = para(c, "caption", "muted", INNER - 8, 2)
	s.intro:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -4)
	s.intro:SetText("Your whispers. Tap one to change it.")
	local y = 32
	for i, kind in ipairs(MSG_ORDER) do
		local m = MESSAGES[kind]
		local listWhen = m.list ~= nil and m.list or m[2]
		local r = CreateFrame("Button", nil, c)
		r:SetSize(INNER, 40)
		r:RegisterForClicks("LeftButtonUp")
		r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
		r.title = T.Text(r, "body", "white", "LEFT", "bold")
		r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -12)
		local tw = T.TextWidth(r.title, m[1])
		local titleW = listWhen == "" and (INNER - 28) or math.min(INNER - 126, math.ceil(tw * 1.05) + 4)
		r.title:SetWidth(titleW)
		T.Lines(r.title, 2)
		r.title:SetText(m[1])
		r.when = T.Text(r, "caption", "muted", "RIGHT", "regular")
		r.when:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -13)
		local whenW = math.max(100, INNER - 38 - titleW)
		r.when:SetWidth(whenW)
		T.Lines(r.when, 3)
		r.when:SetText(listWhen)
		setShown(r.when, listWhen ~= "")
		local th = wrapH(math.max(1, T.ParaLines(m[1], "body", "bold", titleW)), "body")
		local wh = 0
		if listWhen ~= "" then
			wh = wrapH(math.max(1, T.ParaLines(listWhen, "caption", "regular", whenW)), "caption")
		end
		local h = math.max(40, math.ceil(math.max(th, wh)) + 24)
		r.rowH = h
		r:SetHeight(h)
		r.kind = kind
		safeScript(r, "OnEnter", function(self) self.bg:SetColor("hover") end)
		safeScript(r, "OnLeave", function(self) self.bg:SetColor((s.kind == self.kind and s.isWide()) and "raised" or "card") end)
		T.Press(r, { fill = r.bg })
		safeScript(r, "OnClick", function(self) s.edit(self.kind) end)
		T.Tip(r, m[1], function()
			return "Sent " .. m[2] .. ". Click to change it.\n\n" .. textOf(kind)
		end)
		s.rows[i] = r
		y = y + h + 6
	end
	s.listH = y + 6
	s.foldEd = buildEditor(s, c, PAD, INNER, s.frame)
	s.editor = s.foldEd
	-- (2.3) unfolded: the list stays here, the editor is in the side pane (its own, 324 wide)
	function s.isWide() return mside ~= nil and D.Wide("messages") end
	function s.preview()
		local e = s.editor
		local draft = e.field:Text()
		local text = textOf(s.kind, draft)
		e.prev:SetText(text)
		local pad, iw = e.pad, e.iw
		local lines = math.max(1, math.min(6, T.ParaLines(text, "caption", "regular", iw - 24)))
		local prevH = math.max(e.prev.paraH or 0, wrapH(lines, "caption")) -- the preview's own lines, never a typed step
		e.bubble:SetHeight(22 + prevH)
		local lim = limitOf(s.kind)
		local len = #text
		e.meter:SetText(len .. " / " .. lim)
		e.meter:SetTextColor(T.RGB(len >= lim and "red" or (len >= lim - 20 and "red" or "muted")))
		local why = draft ~= "" and dr("TemplateSpam", draft) or nil
		local y = e.prevY + 22 + prevH + 10
		e.why:ClearAllPoints()
		e.why:SetPoint("TOPLEFT", e.body, "TOPLEFT", pad + 4, -y)
		if why then
			e.why:SetText("The spam check would refuse this (" .. tostring(why) .. "). Change the words.")
			e.why:Show()
			y = y + 36
		elseif e.refused and e.refused.draft == draft then
			e.why:SetText(e.refused.text)
			e.why:Show()
			y = y + 36
		else
			e.refused = nil
			e.why:Hide()
		end
		e.tip:ClearAllPoints()
		if s.kind == "advert" then
			e.tip:SetPoint("TOPLEFT", e.body, "TOPLEFT", pad + 4, -y)
			e.tip:Show()
			y = y + 44
		else
			e.tip:Hide()
		end
		-- (the decisions round) the switch of a message that can go by itself
		local words = AUTO_WORDS[s.kind]
		if words then
			local au = e.auto
			au.label:SetText(words[1])
			au.note:SetText(words[2])
			local h = 30 + (au.note.paraH or 28) + 12
			au:SetHeight(h)
			au:ClearAllPoints()
			au:SetPoint("TOPLEFT", e.body, "TOPLEFT", pad, -y)
			au.toggle:SetOn(dr("LineOn", s.kind) == true, true)
			au:Show()
			y = y + h + 8
		else
			e.auto:Hide()
		end
		e.save:SetActive(why == nil)
		local sc = s.isWide() and mside.scroll or s.scroll
		sc:SetContentHeight(y + 20 + (e.shift or 0))
		return text
	end
	-- keep: the field keeps what is typed (the page folded or unfolded under it)
	function s.edit(kind, keep)
		s.kind = kind
		local m = MESSAGES[kind]
		local wide = s.isWide()
		local e = s.editor
		e.when:SetText((wide and (m[1] .. " · sent ") or "Sent ") .. m[2] .. (kind == "advert" and ". Wuber adds [Wuber] in front." or "."))
		e.shift = math.max(0, (e.when.paraH or 0) - 18)
		e.body:ClearAllPoints()
		e.body:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -e.shift)
		e.body:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", 0, 0)
		if not keep then
			local cur = S(dr("Template", kind)) or S(DR.TEMPLATES and DR.TEMPLATES[kind]) or ""
			e.field:SetText(cur)
		end
		e.refused = nil
		e.why:Hide()
		e:Show()
		edFoot(e, true)
		if wide then
			s.title:SetText("Messages")
			s.intro:Show()
			for _, r in ipairs(s.rows) do
				r:Show()
				r.bg:SetColor(r.kind == kind and "raised" or "card")
			end
			s.scroll:SetContentHeight(s.listH)
			fitView(s, true)
			mside.scroll:ClearAllPoints()
			mside.scroll:SetPoint("TOPLEFT", mside.holder, "TOPLEFT", 8, -6)
			mside.scroll:SetPoint("BOTTOMRIGHT", mside.holder, "BOTTOMRIGHT", -8, 6 + ED_ROOM)
			mside.scroll:ScrollTo(0, true)
		else
			fitView(s, false)
			s.title:SetText(m[1])
			for _, r in ipairs(s.rows) do r:Hide() end
			s.intro:Hide()
			s.scroll:ScrollTo(0, true)
		end
		s.preview()
	end
	function s.list()
		-- unfolded, the list is always there: the editor shows the chosen one (the first at first)
		if s.isWide() then return s.edit(s.kind or MSG_ORDER[1]) end
		s.kind = nil
		s.title:SetText("Messages")
		s.editor:Hide()
		edFoot(s.editor, false)
		pcall(s.editor.field.edit.ClearFocus, s.editor.field.edit)
		s.intro:Show()
		for _, r in ipairs(s.rows) do
			r:Show()
		end
		s.scroll:SetContentHeight(s.listH)
		fitView(s, true)
	end
	-- (2.3) folded or unfolded: which editor, the screen's background and the rows' size follow
	-- (the side pane's editor is made the first time; a draft moves across)
	function s.place()
		local wide = s.isWide()
		if wide and not s.wideEd then s.wideEd = buildEditor(s, mside.content, PAD, SIDE_W, mside.holder) end
		local e = wide and s.wideEd or s.foldEd
		if s.editor ~= e then
			local old = s.editor
			if s.kind then e.field:SetText(old.field:Text()) end
			pcall(old.field.edit.ClearFocus, old.field.edit)
			old:Hide()
			edFoot(old, false)
			s.editor = e
		end
		s.placedWide = wide
		s.Wide(wide)
		s.listH = layRows(s, wide)
		if s.kind then s.edit(s.kind, true) else s.list() end
	end
	-- (BRIEF22 L2) a taller or shorter phone moves the edge: fit the list's view again
	safeScript(s.frame, "OnSizeChanged", function()
		if s.rows[1] and s.rows[1]:IsShown() then fitView(s, true) end
	end)
	s.onBack = function()
		-- (playtest) in Simple mode only the advert line is reachable: Back leaves the screen instead of showing the list
		if s.kind and not s.isWide() and (type(W.Advanced) ~= "function" or W.Advanced() == true) then
			s.list()
			return true
		end
		return false
	end
	s.enter = function(kind)
		-- the fold may have changed while this screen was away (its layout is only redone on screen)
		if s.placedWide ~= nil and s.placedWide ~= s.isWide() then s.place() end
		if S(kind) and MESSAGES[kind] then s.edit(kind) else s.list() end
	end
	s.update = function() end
	return s
end

-- (2.3, SPEC7 2.8) the messages page's side pane (made the first time it unfolds): the editor
-- moves into it; the list stays left
D.FOLD.messages = {
	build = function(holder)
		if mside or type(D.SidePane) ~= "function" then return end
		mside = D.SidePane(holder)
	end,
	layout = function(unfolded)
		D.wide.messages = unfolded == true
		local s = st.screens.messages
		-- leaving the screen (it slides out for 0.18 s): do not re-lay it out as the folded one
		if s and s.place and D.CurrentScreen() == "messages" then W.Safe("drive messages", s.place) end
	end,
}

---------------------------------------------------------------------------
-- Blocked: who, why, when; Unblock
---------------------------------------------------------------------------

D.screens.blocked = function(parent)
	local s = Screen(parent, "Blocked")
	st.screens.blocked = s
	local c = s.content
	s.intro = para(c, "caption", "muted", INNER - 8, 2)
	s.intro:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -4)
	s.intro:SetText("Players Wuber won't invite or summon. Your crew shares this list.")
	s.empty = CreateFrame("Frame", nil, c)
	s.empty:SetSize(INNER, 120)
	s.empty:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -48)
	s.empty.bg = T.Rounded(s.empty, "card", 14, "BACKGROUND", 0)
	local icon = T.Icon(s.empty, "lock", 26, "off", "OVERLAY")
	icon:SetPoint("TOP", s.empty, "TOP", 0, -18)
	local t1 = T.Text(s.empty, "body", "white", "CENTER", "bold")
	t1:SetPoint("TOP", icon, "BOTTOM", 0, -10)
	t1:SetText("Nobody blocked")
	local t2 = para(s.empty, "caption", "muted", INNER - 40, 2)
	t2:SetPoint("TOP", t1, "BOTTOM", 0, -6)
	t2:SetJustifyH("CENTER")
	s.emptyNote = t2 -- its words follow the "Block riders who leave without paying" switch (s.update)
	s.rows = Pool(c, function(p)
		local r = CreateFrame("Frame", nil, p)
		r:SetSize(INNER, 50)
		r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
		r.icon = T.Icon(r, "lock", 14, "red", "OVERLAY")
		r.icon:SetPoint("LEFT", r, "LEFT", 14, 0)
		r.name = T.Text(r, "body", "white", "LEFT", "bold")
		r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 38, -9)
		r.name:SetPoint("RIGHT", r, "RIGHT", -104, 0)
		r.why = para(r, "caption", "muted", INNER - 38 - 104) -- wraps: the row grows with the reason (s.update)
		r.why:SetPoint("TOPLEFT", r, "TOPLEFT", 38, -27)
		r.btn = T.Pill(r, "Unblock", "dark", 86, 28)
		r.btn:SetPoint("RIGHT", r, "RIGHT", -10, 0)
		r.btn.fill:SetColor("raised")
		r.btn:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
		safeScript(r.btn, "OnClick", function()
			if not r.entry then return end
			dr("Unblacklist", r.entry.name or nameOf(r.entry.key))
			toast(nameOf(r.entry.name or r.entry.key) .. " can ride with you again", "info")
			D.Refresh(true)
		end)
		T.Tip(r.btn, "Unblock", "They can ask you for summons again. Your crew is told too.")
		r:EnableMouse(true)
		T.Tip(r, function() return nameOf(r.entry and (r.entry.name or r.entry.key)) end, function() return "Blocked: " .. (S(r.entry and r.entry.reason) or "no reason given") end)
		return r
	end)
	s.update = function()
		local list = dr("BlockedList")
		list = type(list) == "table" and list or {}
		s.right:SetText(#list > 0 and plural(#list, "player") or "")
		local selfBlock = dr("Opt", "autoBlock")
		s.emptyNote:SetText("Shift-right-click a rider to block them. " .. (selfBlock == false
			and "Riders who leave without paying are not blocked by themselves: that switch is off in Settings."
			or "Riders who leave without paying are blocked by themselves."))
		s.empty:SetHeight(math.max(120, 92 + (s.emptyNote.paraH or 30))) -- the card grows with the note, nothing cut
		local y = 48
		for i, e in ipairs(list) do
			local r = s.rows.get(i)
			r.entry = e
			r.name:SetText(nameOf(S(e.name) or e.key))
			local when = S(e.at)
			if N(e.at) then
				local ok, d = pcall(date, "%d %b", N(e.at))
				when = ok and d or nil
			end
			r.why:SetText((S(e.reason) ~= "" and S(e.reason) or "blocked") .. (when and when ~= "" and (" · " .. when) or ""))
			local rowH = math.max(50, 27 + (r.why.paraH or 14) + 5)
			r:SetHeight(rowH)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			r:Show()
			y = y + rowH + 6
		end
		s.rows.hideFrom(#list)
		setShown(s.empty, #list == 0)
		s.scroll:SetContentHeight(math.max(y, 180) + 10)
	end
	return s
end
