-- tests/fixtures/old_pills.lua: the code of two bugs the offline harness passed and the real client
-- showed, as git has it. Each entry is one hunk of the fix commit: `fixed` is today's
-- text (found exactly once in the file, else the test says this fixture is out of date) and `old` is
-- what the file said before the fix. tests/harness_draw.lua loads Wuber with the old text put back
-- (the client's opts.rewrite) and checks that the harness now draws the bug as the game did.
-- Made from: git show <commit> -- <file> (the hunks listed); regenerate the same way if a file moves.
return {
	{ commit = "0aa37c2", file = "UI/Window.lua", hunk = "@@ -183,9 +183,31 @@ (the paint functions)",
		why = "BRIEF20 B1: the top nav before its fix (one fill per tab, its style and alpha changed on every tab change)",
		fixed = [[
-- (design 2, C) the chosen tab has a violet glyph and a violet word, the others are grey; no pill. Only colours
-- change, never an alpha or a texture shown or hidden (in the game a texture keeps the alpha it had
-- when the tab changed while the window was shut), on every change and at open.
local function paintTab(b)
	local c = b.tabName == ui.tab and "accent" or ((b.hover or b.wuberPressed) and "white" or "offText")
	b.glyph:SetVertexColor(T.RGB(c))
	b.label:SetTextColor(T.RGB(c))
end

local function paintTabs()
	for _, tab in ipairs(ui.tabs) do paintTab(tab.button) end
end]],
		old = [[
]] },
	{ commit = "0aa37c2", file = "UI/Window.lua", hunk = "@@ -206,11 +228,9 @@ (the tab button and its layout; one block since design 2 moved the tabs to a bottom bar)",
		why = "BRIEF20 B1: the top nav before its fix (one fill per tab, its style and alpha changed on every tab change)",
		fixed = [[
local function tabButton(name)
	local b = CreateFrame("Button", nil, ui.tabbar)
	b:SetSize(WIN_W / 3, HEAD.bar)
	b:RegisterForClicks("LeftButtonUp")
	b.tabName = name
	b.glyph = T.Icon(b, TAB_GLYPH[name] or "circle", HEAD.glyph, "offText", "ARTWORK")
	b.glyph:SetPoint("TOP", b, "TOP", 0, -8)
	b.label = T.Text(b, "caption", "offText", "CENTER", "medium")
	b.label:SetPoint("BOTTOM", b, "BOTTOM", 0, 8)
	b.label:SetText(name)
	safeScript(b, "OnEnter", function(self) self.hover = true end)
	safeScript(b, "OnLeave", function(self) self.hover = nil end)
	-- the press look: the words and the glyph answer at once (T.Press plays the click)
	T.Press(b, { paint = function(self) paintTab(self) end })
	for _, ev in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
		b:HookScript(ev, function(self) pcall(paintTab, self) end)
	end
	safeScript(b, "OnClick", function(self)
		if ui.settingsOpen and UI.CloseSettings then W.Safe("settings", UI.CloseSettings, true) end
		W.Safe("tab", UI.SelectTab, self.tabName)
	end)
	T.Tip(b, name, TAB_TIPS[name] or ("Open the " .. name .. " tab."), "ANCHOR_TOP")
	setShown(b, tabShown(name))
	return b
end

-- each shown tab shares the folded width evenly, from the left: in the wide window the tabs
-- stay in the left pane
local function layoutTabs()
	local shown = {}
	for _, tab in ipairs(ui.tabs) do
		local show = tabShown(tab.name)
		setShown(tab.button, show)
		if show then shown[#shown + 1] = tab end
	end
	local w = WIN_W / math.max(1, #shown)
	for i, tab in ipairs(shown) do
		tab.button:ClearAllPoints()
		tab.button:SetPoint("BOTTOMLEFT", ui.tabbar, "BOTTOMLEFT", (i - 1) * w, 0)
		tab.button:SetWidth(w)
	end
	paintTabs()
end]],
		old = [[
local function tabButton(name)
	local b = T.Pill(ui.top, name, "ghost", 64, 30)
	b.tabName = name
	local width = T.TextWidth(b.label, name)
	if width <= 0 then width = #name * 8 end
	b:SetWidth(math.floor(width + 36))
	b.label.wuberRoom = math.floor(width + 36) - 30
	T.Fit(b.label)
	b:HookScript("OnClick", function(self)
		if ui.settingsOpen and UI.CloseSettings then W.Safe("settings", UI.CloseSettings, true) end
		W.Safe("tab", UI.SelectTab, self.tabName)
	end)
	T.Tip(b, name, TAB_TIPS[name] or ("Open the " .. name .. " tab."), "ANCHOR_BOTTOM")
	return b
end

local function layoutTabs()
	-- (round 9, S16) 48 and 2 apart (were 52 and 4): room for the fold button left of Settings
	local x = 48
	for _, tab in ipairs(ui.tabs) do
		tab.button:ClearAllPoints()
		tab.button:SetPoint("LEFT", ui.top, "LEFT", x, -2)
		x = x + (N(tab.button:GetWidth()) or 64) + 2
		local on = tab.name == ui.tab
		tab.button:SetStyle(on and "dark" or "ghost")

		if not on then tab.button.label:SetTextColor(T.RGB("muted")) end
	end
end]] },
	{ commit = "0aa37c2", file = "UI/Window.lua", hunk = "@@ -475,6 +495,7 @@",
		why = "BRIEF20 B1: the top nav before its fix (one fill per tab, its style and alpha changed on every tab change)",
		fixed = [[
	safeScript(win, "OnShow", function()
		-- (2.3.2 C1) the first-show text refresh used to be a HookScript, which this SetScript dropped
		pcall(onShowRefresh)
		pcall(syncTabs)
		pcall(paintTabs) -- the lit tab at open, whatever changed while shut
		ui.dirty = true
		UI.FlashMinimap(false)
		-- the Fold: this page's width at once (no tween while the window zooms in)]],
		old = [[
	safeScript(win, "OnShow", function()
		-- (2.3.2 C1) the first-show text refresh used to be a HookScript, which this SetScript dropped
		pcall(onShowRefresh)
		pcall(syncTabs)
		ui.dirty = true
		UI.FlashMinimap(false)
		-- the Fold: this page's width at once (no tween while the window zooms in)]] },
	{ commit = "28a70b8", file = "Theme/Widgets.lua", hunk = "@@ -537,7 +537,27 @@",
		why = "BRIEF20 B1: T.Segmented before its fix (the chosen part lit by flipping its fill between ghost, alpha 0, and an opaque style)",
		fixed = [[
end

-- T.Segmented(parent, choices, value, onChange(value), width, height): a pill split into
-- choices ({ { value =, label =, tip = } }); the chosen one is violet with ink words. s:SetValue(v), s:Paint().
-- the chosen part is lit by its own opaque pill (b.chosen), shown or hidden; the parts'
-- own fills stay hidden. In the game a fill kept its alpha when the choice changed while it was not
-- drawn (a clear part stayed clear, a lit one turned solid white). Looks: s.onStyle (a T.PILL_STYLES
-- name; "chosen" by default, which is no pill style but the look below) and s.litFor(b) (a colour for the lit pill)
-- and s.onText (its words' colour); the other parts have muted words, white under the mouse. (design 1) Whatever
-- the caller asks, words on a violet lit pill are ink.
local SEG_CHOSEN = { bg = "accent", hover = "accent", press = "accent", text = "ink" }
local function segPaint(s)
	local st = STYLES[s.onStyle] or SEG_CHOSEN
	for _, b in ipairs(s.buttons) do
		local on = b.value == s.value
		b.fill:SetShown(false)
		b.chosen:SetShown(on)
		local lit
		if on then
			lit = s.litFor and s.litFor(b)
			if not lit then lit = b.pressed and st.press or (b.hover and st.hover or st.bg) end
			-- a violet look (the old "violet" pill style has its own hover and press shades): the one violet
			if st.bg == "accent" then lit = "accent" end
			b.chosen:SetColor(lit)
		end
		b.label:SetTextColor(T.RGB(on and litText(lit, s.onText or st.text) or (b.hover and "white" or "muted")))
	end
end

-- T.Segmented(parent, choices, value, onChange, width, height, opts): opts.byLabel = true sizes the segments by
-- their labels (each one's text plus its pill padding, the spare width shared evenly) instead of equal widths,
-- so a long label is not cut beside short ones; opts.pad overrides the horizontal padding per side (default ph/2).
function T.Segmented(parent, choices, value, onChange, width, height, opts)
	height = height or 30
	local s = CreateFrame("Frame", nil, parent)]],
		old = [[
end

-- T.Segmented(parent, choices, value, onChange(value), width, height): a pill split into
-- choices ({ { value =, label =, tip = } }); the chosen one is gold. s:SetValue(v).
function T.Segmented(parent, choices, value, onChange, width, height)
	height = height or 30
	local s = CreateFrame("Frame", nil, parent)]] },
	{ commit = "28a70b8", file = "Theme/Widgets.lua", hunk = "@@ -560,14 +580,22 @@",
		why = "BRIEF20 B1: T.Segmented before its fix (the chosen part lit by flipping its fill between ghost, alpha 0, and an opaque style)",
		fixed = [[
			end
		end)
		if ch.tip then T.Tip(b, ch.label, ch.tip) end
		b.fill:SetShown(false)
		b.chosen = T.PillFill(b, "accent", height - 4, "BACKGROUND", 0)
		b.chosen:SetShown(false)
		for _, ev in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
			b:HookScript(ev, function() pcall(segPaint, s) end)
		end
		s.buttons[i] = b
	end
	s.onStyle = "chosen"
	function s.Paint(self) segPaint(self) end
	function s.SetValue(self, v)
		self.value = v
		for _, b in ipairs(self.buttons) do
			b:SetStyle(b.value == v and self.onStyle or "ghost")
		end
		segPaint(self)
	end
	s:SetValue(value)
	return s]],
		old = [[
			end
		end)
		if ch.tip then T.Tip(b, ch.label, ch.tip) end
		s.buttons[i] = b
	end
	function s.SetValue(self, v)
		self.value = v
		for _, b in ipairs(self.buttons) do
			b:SetStyle(b.value == v and "primary" or "ghost")
			if b.value ~= v then b.label:SetTextColor(T.RGB("muted")) end
		end
	end
	s:SetValue(value)
	return s]] },
	{ commit = "28a70b8", file = "UI/Driver/Build.lua", hunk = "@@ -556,29 +556,12 @@",
		why = "BRIEF20 B1: D.CalmSegmented before its fix (the calm look painted on the same fill)",
		fixed = [[

-- A segmented choice made calm (round 7): gold is for the big button; the chosen part is a
-- violet pill with ink words (item 2 of the design audit), the others muted (UI_Drive.lua's Earnings uses it too).
-- T.Segmented lights the chosen part with its own opaque pill (shown or hidden, never an
-- alpha change); this only sets its look: no gold glow (ghost), the lighter pill, white words.
function D.CalmSegmented(seg)
	seg.bg:SetColor("panel")
	seg.onStyle, seg.onText = "ghost", "ink"
	seg.litFor = function() return "glow" end
	seg:SetValue(seg.value)
	return seg
end]],
		old = [[

-- A segmented choice made calm (round 7): gold is for the big button; the chosen part is a
-- lighter pill with white words, the others muted (UI_Drive.lua's Earnings uses it too).
function D.CalmSegmented(seg)
	seg.bg:SetColor("panel")
	local function calm(b)
		if seg.value == b.value then
			b.fill:SetColor(b.hover and "raised" or "hover")
			b.label:SetTextColor(T.RGB("white"))
		else
			b.label:SetTextColor(T.RGB(b.hover and "white" or "muted"))
		end
	end
	local set = seg.SetValue
	function seg.SetValue(self, value)
		set(self, value)
		for _, b in ipairs(self.buttons) do
			b:SetStyle("ghost")
			calm(b)
		end
	end
	for _, b in ipairs(seg.buttons) do
		b:HookScript("OnEnter", calm)
		b:HookScript("OnLeave", calm)
		b:HookScript("OnMouseUp", calm)
	end
	seg:SetValue(seg.value)
	return seg
end]] },
	{ commit = "441fcf8", file = "UI/Driver/Earnings.lua", hunk = "@@ -448,12 +488,14 @@",
		why = "BRIEF19 F5: the Earnings period pills before their fix (no steady lit pills; s.update does not set the choice from the range)",
		fixed = [[
	}, "today", function(v) s.range = v s.update() end, 232, 26, { byLabel = true })
	s.seg:SetPoint("TOPLEFT", dash, "TOPLEFT", 12, -12)
	if D.CalmSegmented then D.CalmSegmented(s.seg) end
	steady(s.seg)
	s.who = T.Segmented(dash, {
		{ value = "me", label = "Me", tip = "Rides this character's window was paid for." },
		{ value = "crew", label = "Crew", tip = "Every ride your crew took, whoever was paid." },
	}, "me", function(v) s.scope = v s.update() end, 144, 30) -- (2.3.2, S4) 116 clipped "Crew" to "Cre..."
	s.who:SetPoint("TOPRIGHT", dash, "TOPRIGHT", -14, -54)
	if D.CalmSegmented then D.CalmSegmented(s.who) end
	steady(s.who)
	s.per = T.Text(dash, "hero", "gold", "LEFT", "bold")
	s.per:SetPoint("TOPLEFT", dash, "TOPLEFT", 14, -48)
	s.per:SetWidth(160)]],
		old = [[
	}, "today", function(v) s.range = v s.update() end, 196, 26)
	s.seg:SetPoint("TOPLEFT", dash, "TOPLEFT", 12, -12)
	if D.CalmSegmented then D.CalmSegmented(s.seg) end
	s.who = T.Segmented(dash, {
		{ value = "me", label = "Me", tip = "Rides this character's window was paid for." },
		{ value = "crew", label = "Crew", tip = "Every ride your crew took, whoever was paid." },
	}, "me", function(v) s.scope = v s.update() end, 144, 30) -- (2.3.2, S4) 116 clipped "Crew" to "Cre..."
	s.who:SetPoint("TOPRIGHT", dash, "TOPRIGHT", -14, -54)
	if D.CalmSegmented then D.CalmSegmented(s.who) end
	s.per = T.Text(dash, 40, "gold", "LEFT", "bold")
	s.per:SetPoint("TOPLEFT", dash, "TOPLEFT", 14, -48)
	s.per:SetWidth(160)]] },
	{ commit = "441fcf8", file = "UI/Driver/Earnings.lua", hunk = "@@ -524,11 +585,16 @@",
		why = "BRIEF19 F5: the Earnings period pills before their fix (no steady lit pills; s.update does not set the choice from the range)",
		fixed = [[
	s.update = function()
		s.side = s.side or eside
		local isAdv = adv()
		-- the totals' period is s.range; the lit pill follows it in every path (a tap, the
		-- photo tour setting it, a fold, a tab coming back)
		if not RANGES[s.range] then s.range = "today" end
		if s.seg.value ~= s.range then s.seg:SetValue(s.range) else s.seg:Paint() end
		local days = RANGES[s.range][1]
		local crewN = 0
		local crew = dr("Crew")
		if type(crew) == "table" then for _, m in ipairs(crew) do if not m.me then crewN = crewN + 1 end end end
		setShown(s.who, isAdv and crewN > 0)
		if s.who.value ~= s.scope then s.who:SetValue(s.scope) else s.who:Paint() end
		local scope = crewN > 0 and s.scope or "me"
		local tot = dr("LogTotals", since(s.range), scope)
		tot = type(tot) == "table" and tot or {}]],
		old = [[
	s.update = function()
		s.side = s.side or eside
		local isAdv = adv()
		local days = RANGES[s.range][1]
		local crewN = 0
		local crew = dr("Crew")
		if type(crew) == "table" then for _, m in ipairs(crew) do if not m.me then crewN = crewN + 1 end end end
		setShown(s.who, crewN > 0)
		local scope = crewN > 0 and s.scope or "me"
		local tot = dr("LogTotals", since(s.range), scope)
		tot = type(tot) == "table" and tot or {}]] },
	{ commit = "441fcf8", file = "UI/Driver/Console.lua", hunk = "design 2 N (b7767b0): the line A.SlideIn was before",
		why = "BRIEF19 F5: the game's bug needed an Alpha animation on the screen while its pill was set; design 2 N replaced the screen's A.SlideIn by a page push that moves by SetPoint, so the replay puts that one call back",
		fixed = [[
	if was == name and scr.frame:IsShown() then scr.frame:Show() else pageMove(scr.frame, under, true) end]],
		old = [[
	A.SlideIn(scr.frame, 40, 0.24)]] },
}
