-- Module: UI.Settings.Rows
-- Purpose: Settings building blocks and option logic: rows, toggles, buttons, "Check my game", driving
--   options. (design 2) A page is groups of rows (T.RowGroup): row() adds a row to the group of the row before it,
--   section() starts a new group under a quiet heading that does not say the page's name again.
-- API: UI.settings
-- Internals: INNER, KEYWORDS, N, PAD, S, TOP_H, WIN_W, btn, index, buildDriving, keyRow, optToggle, tipsOn, setTips, buildDriving2, buildDriving3, buildRiding8,
--   buildWindow8, sync8, buttonRow, call, db, dopts, hiddenCount, inCombat, isWarlock, row, runCheck,
--   safeScript, section, headingText, groupAt, grow, set, st, toggleRow, friendlyPlatesOn, turnOnPlates, newerVersion, aboutText,
--   syncUpdates (round 11); (decisions N) resetDone ("3 settings reset." with Undo for 10 s), SENDING and sendingRow (the
--   one quiet row that states what Wuber sends, and how much; its numbers are the code's: see SENDING);
--   (quick wins) NOTES (the two lines' words), noteUnder (a quiet line of what Wuber won't do under
--   a switch, inside the switch's own row; st.notes.autoInvite / st.notes.autoReply)
-- Uses: (none: Core via W)
-- Later: UI.Tips (IsOn, SetOn: the Tips switch)
-- Events: listens Listen NEWER_VERSION, On PLAYER_REGEN_DISABLED; fires SETTINGS
-- Standalone: no
-- Test: tests/ui/settings/rows_test.lua
-- From: UI_Settings.lua 1-582 (Wuber 2.2.1)
--
-- Wuber: Settings (the cog in the top bar). Every option is a toggle, slider or choice with
-- a one-line label and a tooltip saying exactly what it does: Riding, Driving (Warlocks
-- only), Map, Effects, Sound, and a footer with the window, "Check my game" and the
-- version. Writes W.db / W.Char() and fires "SETTINGS" with the key it changed.

local _, W = ...
local Mod = W.Module("UI.Settings.Rows", {})
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

local WIN_W, TOP_H, PAD = 360, 56, 16 -- (design 2) the screen's side margin is 16
local INNER = WIN_W - PAD * 2

local function S(v) return W.Str(v) end
local function N(v) return W.Num(v) end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		W.Error("settings", a)
		return nil
	end
	return a, b, c
end

local function safeScript(frame, script, fn)
	frame:SetScript(script, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then W.Error(script, err) end
	end)
end

local function inCombat() return type(W.InCombat) == "function" and call(W.InCombat) == true end

local function db() return W.db or (W.InitDB and W.InitDB()) or {} end

local function set(key, value)
	db()[key] = value
	W.Fire("SETTINGS", key)
end

local st = { rows = {}, scroll = 0, scrollTarget = 0, index = {}, query = "", view = "home" }
UI.settings = st -- the controls, for tests: st.controls[key]

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

-- (quick wins) what Wuber won't do, one quiet line under each of two switches in Driving (the author's picks of 22 Nov;
-- the words live in this one table)
local NOTES = {
	inviteNote = "Wuber won't invite on an unclear whisper or for a place you don't summon to: those wait in your list. It never invites a blocked player.",
	replyNote = "Wuber won't whisper the same person twice in an hour, and never in combat, in a raid, in an instance or during a ride.",
}

-- Search (round 9, G1): every row is listed in st.index as it is made (UI.Settings.Find matches
-- its label, description and tooltip); KEYWORDS[label] adds hidden words a player might type.
-- A row added later (another agent's setting) is searchable with no more work; its words go here.
local KEYWORDS = {
	["My time is worth"] = "value gold hour price fare cost money worth",
	["Auto-accept my driver's invite"] = "invite group party join accept",
	["Leave the group after the ride"] = "group party leave quit",
	["Flight offers"] = "flight master tip flying flight path bird skip gryphon wyvern taxi",
	["Hidden drivers"] = "hide hidden block ignore unhide show",
	["Your badge"] = "icon crown emblem badge look",
	["Post an advert when I go online"] = "advert advertise chat trade services online",
	["List me in Wuber's starter list"] = "new riders starter list find",
	["Invite riders who whisper me"] = "auto invite group party whisper app requests",
	["Invite public chat riders"] = "auto invite trade lfg lookingforgroup public chat riders buyers",
	["Group size"] = "largest group one rider at a time raid group size party",
	["Chat channels"] = "channels to watch advert channels advertise chat channels trade lfg lookingforgroup services general",
	["Request words"] = "keywords whisper words",
	["How whispers leave"] = "whisper send button chat",
	["Riders who leave without paying"] = "block blocked tell why unpaid leavers leave paying",
	["Key for the big button"] = "keybind hotkey binding key",
	["Big button size"] = "scale size bigger smaller fit window",
	["Lock the big button"] = "lock big button position move reset middle centre center place",
	["Big button on screen"] = "show big button keep closed always waiting only in wuber",
	["Alert character"] = "bell alert alt multibox account test forget crew",
	["This is my alert window"] = "bell alert alt multibox account window crew own driver",
	["Show ride passphrase"] = "password code word secret phrase", -- round 9 (D)
	["Drivers on the world map"] = "pins map world openmap addon",
	["Badges over heads"] = "crowns badges pioneer emblems nameplates plates crown badge heads names",
	["Turn on friendly nameplates"] = "nameplates plates names",
	["Minimap button"] = "minimap icon button",
	["Effects"] = "animations portals sparkles motion calm graphics fx",
	["Reduce motion"] = "animations slide sliding still calm fade accessibility", -- design 2
	["Sounds"] = "sound volume audio noise chime ping alert mute quiet",
	["Advanced mode"] = "simple advanced extra tools all settings",
	["Window size"] = "scale size bigger smaller zoom position move reset middle centre center",
	["Wide pages"] = "fold unfold wide narrow two pane reset per page",
	["What Wuber sends"] = "privacy limits limit hidden messages message whispers sending sent spam rate how many often chat addon", -- decisions N
	["Tips"] = "login tips hints help tip advice learn how tutorial coach replay",
	["Check my game"] = "test diagnose problems broken",
}

-- lists something in the search (rows do it themselves)
local function index(frame, label, desc, tip)
	st.index[#st.index + 1] = { frame = frame, label = label, desc = desc, tip = type(tip) == "string" and tip or nil }
end

-- (design 2) Settings pages are groups of rows (T.RowGroup): one card per group, a divider between its rows, the
-- control at the right. section() ends the group; the next row starts a new one. Rows that follow each other
-- (the next one's y is where the last one ended) share a card.
local PAGE_NAMES = { ["Riding"] = true, ["Map"] = true, ["This window"] = true }

-- the heading's words: the page's name is not said again ("Driving: most used" -> "Most used"); a heading
-- that is only the page's name is not drawn
local function headingText(title)
	title = tostring(title or "")
	local rest = title:match("^Driving: (.+)$")
	if rest then return rest:sub(1, 1):upper() .. rest:sub(2) end
	if PAGE_NAMES[title] then return nil end
	return title
end

local function section(parent, y, title)
	parent.wuberRows = nil
	if y > 10 then y = y + 12 end
	local words = headingText(title)
	if not words then return y end
	local h = T.RowHeading(parent, words)
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, -y)
	st.headings = st.headings or {}
	st.headings[#st.headings + 1] = h
	return y + 15 + h.gap
end

-- the card a row at y joins: the one the last row of this parent ended at y, else a new one
local function groupAt(parent, y)
	local g = parent.wuberRows
	if not g or g.nextY ~= y then
		g = T.RowGroup(parent, INNER)
		g:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
		g.topY, g.nextY = y, y
		parent.wuberRows = g
		st.groups = st.groups or {}
		st.groups[#st.groups + 1] = g
	end
	return g
end

-- A row: its name and a line under it on the left (both wrap: never cut, never "..."), the control on the right.
-- height: "slider" (desc is the grey caption at the right, r.below the room for the slider) or a number over 50
-- (room under the words for the caller's own control, which it anchors to r.below or r's bottom left, 16 and 12 in).
-- more: further T.RowGroup row options (right, value, on, onChange, onClick, buttonW).
-- Returns the row (r.label = its title, r.desc = its second line or caption; setting their text lays the row
-- out again) and the y under it. The whole row shows the tooltip.
local function row(parent, y, label, desc, tip, height, textW, more)
	local g = groupAt(parent, y)
	local o = { title = label, sub = desc, tip = { title = label, body = tip } }
	if type(more) == "table" then for k, v in pairs(more) do o[k] = v end end
	local room
	local slider = height == "slider"
	if slider then
		-- (design 3) a caption too long to stand beside its name (it left "Group / size" two words on two lines) goes under the
		-- name as the row's second line instead, whole; a short one stays at the right
		local need = math.ceil((N(T.MeasureText(label, "body", "bold")) or 0) * 1.04) + math.ceil(N(T.MeasureText(desc or "", "body", "medium")) or 0) + 2
		local fits = need + T.ROW.gap + T.ROW.pad * 2 + 4 <= INNER
		if fits then
			o.sub, o.right, o.value = nil, "value", desc or ""
		else
			o.sub = desc or ""
		end
		room = 24
	elseif tonumber(height) and height > 50 then
		room = height - 54
	end
	if room then
		o.below = CreateFrame("Frame", nil, parent)
		o.below:SetSize(INNER - 28, room)
	end
	local r = g:Row(o)
	r.label, r.desc = r.title, r.value or r.sub
	g:Layout()
	local h = N(r:GetHeight()) or 44
	g.nextY = y + h
	st.rows[#st.rows + 1] = r
	index(r, label, desc, tip)
	return r, y + h
end

-- more room under a row's words (the badge picker's second line of badges): returns what was added
local function grow(r, extra)
	if not (r and r.below and r.group) then return 0 end
	r.below:SetHeight((N(r.below:GetHeight()) or 0) + extra)
	r.group:Layout()
	r.group.nextY = r.group.nextY + extra
	return extra
end

-- (quick wins) a quiet line of plain text under a switch's own words, inside the switch's row (the same card, no divider
-- between, no control). It wraps and the row grows; ctl is the switch (st.controls[...]), y the y under its row.
-- Returns the new y and the text. The row's label, sub line and tooltip are not touched.
local function noteUnder(ctl, y, text)
	local r = ctl and ctl.row
	if not (r and r.group and not r.below) then return y end
	local f = CreateFrame("Frame", nil, r)
	f:SetSize(INNER - 28, 14)
	f.text = T.Para(f, "caption", "muted", INNER - 28, "regular")
	f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f:SetHeight(f.text:SetPara(text))
	local before = N(r:GetHeight()) or 0
	r.below = f
	r.group:Layout()
	local extra = (N(r:GetHeight()) or before) - before
	r.group.nextY = r.group.nextY + extra
	return y + extra, f
end

local function toggleRow(parent, y, key, label, desc, tip, get, put)
	local r
	r, y = row(parent, y, label, desc, tip, nil, nil, { right = "switch", on = get(), onChange = function(on, self) put(on, self) end })
	local t = r.switch
	t.get, t.put, t.row = get, put, r
	st.controls[key] = t
	return y, r
end

local function fitExtraRows(g)
	for _, e in ipairs(g.wuberExtraRows or {}) do
		local r = e.r
		if r and r.switch then
			local sw = N(r.switch:GetWidth()) or 44
			local room = math.max(100, INNER - 16 - sw - 8 - e.w - 20)
			if r.title then r.title:SetWidth(room) end
			if r.sub then r.sub:SetWidth(room) end
		end
	end
end

local function attachSwitchButton(r, key, text, width, tipTitle, tipBody, onClick)
	-- (#261) the pill is as wide as it was unless its words, as the game draws them (about 7% over the font table), need more: its label
	-- stands 8 in from each end (a capsule's curve is under the words only past that), not 13, so the row beside it keeps its room
	local PAD = 8
	width = math.max(width, math.ceil(T.MeasureText(text, "sub", "medium") * 1.07) + PAD * 2 + 2)
	local b = T.Pill(r, text, "dark", width, 26)
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", b, "LEFT", PAD, 0)
	b.label:SetPoint("RIGHT", b, "RIGHT", -PAD, 0)
	b.label.wuberRoom = width - PAD * 2
	b.label:SetText(text or "")
	b:SetPoint("RIGHT", r.switch, "LEFT", -8, 0)
	b.fill:SetColor("raised")
	b:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(b, "OnClick", function() onClick(b) end)
	T.Tip(b, tipTitle, tipBody)
	if key then st.controls[key] = b end
	local g = r.group
	if g then
		if not g.wuberExtraRows then
			g.wuberExtraRows = {}
			local orig = g.Layout
			g.Layout = function(self, ...)
				local h = orig(self, ...)
				fitExtraRows(self)
				return h
			end
		end
		g.wuberExtraRows[#g.wuberExtraRows + 1] = { r = r, w = width }
		fitExtraRows(g)
	end
	return b
end

-- one small button at the row's right (fitted to its words unless a width is given)
local function buttonRow(parent, y, key, label, desc, tip, text, onClick, width)
	local r
	r, y = row(parent, y, label, desc, tip, nil, nil, { right = "button", value = text, buttonW = width, onClick = function(_, b) onClick(b) end })
	local b = r.button
	st.controls[key] = b
	return y, b, r
end

-- (decisions N) After a reset: "3 settings reset." with an Undo button for 10 s (UI.UndoToast). n: how many saved
-- values the reset changed; undo puts exactly those back. Nothing changed: the reset's old line (same), unless an
-- Undo is still up (a second click on Reset must not take it away).
local function resetDone(n, undo, same)
	if n > 0 and type(UI.UndoToast) == "function" then
		return UI.UndoToast(n == 1 and "1 setting reset." or (n .. " settings reset."), undo)
	end
	if not (type(UI.UndoPending) == "function" and UI.UndoPending()) then UI.Toast(same, "info") end
end

-- (decisions N) What Wuber sends, in one place a player can read. Every number is the code's:
--   12 at once, 2 a second: the two hidden outboxes together. Net (Net.Base: NETK.BURST = 4 at once, NETK.RATE = 1 a
--     second; Net.Transport sends to the hidden channels and by hidden whisper to a driver or rider) and the crew's
--     (Drive.Team: 8 at once, 1 a second; to the party or raid, and by hidden whisper to the crew and, through
--     Drive.Bell, the alert character).
--   once an hour for each person; never in combat, a raid, an instance or during a ride: Drive.AutoReply
--     (DR.REPLY_EVERY = 3600, DR.CanReply), the only chat line sent without a click until the Messages switches.
-- (the 20 rewrites, W-13) the row shows the short line; the whole of what is sent is its tooltip
local SENDING = { title = "What Wuber sends",
	text = "Hidden messages: at most 12 at once, then 2 a second. One whisper back to a public request, once an hour for each person, never in combat. Every other line waits for your click, unless you switched it on in Messages.",
	tip = "Hidden messages go only to Wuber's own hidden channels, to your group and to your driver, your riders, your crew and your alert character: at most 12 at once, then at most 2 a second. The only chat lines Wuber sends by itself are one whisper back to a public request (at most once an hour for each person; never in combat, in a raid, in an instance or during a ride) and the lines you switch on in Messages; every other line waits for your own click or key press." }
local function sendingRow(parent, y)
	local r
	r, y = row(parent, y, SENDING.title, SENDING.text, SENDING.tip)
	st.sendingRow = r
	return y
end

---------------------------------------------------------------------------
-- What each option does
---------------------------------------------------------------------------

local function isWarlock()
	if type(W.IsWarlock) == "function" then return call(W.IsWarlock) == true end
	return false
end

local function hiddenCount()
	local n = 0
	local h = db().hidden
	if type(h) == "table" then for _ in pairs(h) do n = n + 1 end end
	return n
end

local function friendlyPlatesOn()
	local cc = rawget(_G, "C_CVar")
	local g1 = type(cc) == "table" and type(cc.GetCVar) == "function" and cc.GetCVar or nil
	local g2 = rawget(_G, "GetCVar")
	local raw
	if g1 then
		local ok, r = pcall(g1, "nameplateShowFriends")
		if ok and r ~= nil then raw = r end
	end
	if raw == nil and type(g2) == "function" then
		local ok, r = pcall(g2, "nameplateShowFriends")
		if ok and r ~= nil then raw = r end
	end
	if raw ~= nil then
		local s = S(raw)
		if s == "1" then return true end
		if s == "0" then return false end
		local n = N(raw)
		if n ~= nil then return n == 1 end
		local p = type(W.Plain) == "function" and W.Plain(raw) or raw
		return p == true
	end
	local gb = (type(cc) == "table" and type(cc.GetCVarBool) == "function" and cc.GetCVarBool)
		or rawget(_G, "GetCVarBool")
	if type(gb) == "function" then
		local ok, r = pcall(gb, "nameplateShowFriends")
		if ok then
			local p = type(W.Plain) == "function" and W.Plain(r) or r
			return p == true
		end
	end
	return false
end

local function turnOnPlates()
	if inCombat() then
		UI.Toast("Leave combat first", "warn")
		return
	end
	local plates = W.Plates
	if type(plates) == "table" and type(plates.TurnOnFriendlyPlates) == "function" then
		local ok, res, why = pcall(plates.TurnOnFriendlyPlates)
		if ok and res == true then
			-- W.Plates already toasted the longer line with the Shift+V hint; a second toast would replace it
		elseif ok and res ~= false then
			UI.Toast("Friendly nameplates are on", "found")
		elseif S(why) or not ok then
			UI.Toast(S(why) or "Couldn't turn them on. Try the game's Interface options.", "warn")
		end
		-- else: W.Plates already toasted its own failure line, which carries the Shift+V hint
	else
		UI.Toast("Turn on friendly nameplates in the game's Interface options", "info")
	end
	if type(UI.UpdateSettings) == "function" then UI.UpdateSettings() end
end

-- (prep-242 r3 G) a Check my game line is shown whole: it wraps, and its row grows to the lines it takes
local function fitLine(l)
	local h = N(l.text:GetStringHeight())
	if not h or h <= 0 then
		-- (prep-242 r3 G2) a font not loaded yet reports 0: that is unknown, so count the lines the words need (at most 3)
		local fs = l.text
		local room = N(fs.wuberRoom) or (INNER - 52)
		local wide = T.MeasureText(tostring(fs.wuberText or ""), fs.wuberBase or "caption", fs.wuberWeight)
		local n = math.max(1, math.min(3, math.ceil((N(wide) or 0) / math.max(1, room))))
		h = n * T.DrawnSize("caption") + (n - 1) * T.Spacing("caption")
	end
	local rowH = math.max(20, math.ceil(h) + 6)
	l:SetHeight(rowH)
	return rowH + 2
end

-- "Check my game": retries refused actions, then W.SelfTest() -> { { name, ok, detail } }
local function runCheck()
	if type(W.RetryBlocked) == "function" then call(W.RetryBlocked) end
	local res = st.results
	local list = type(W.SelfTest) == "function" and call(W.SelfTest) or nil
	res.lines = res.lines or {}
	for _, l in ipairs(res.lines) do l:Hide() end
	local y = 44
	local pass, fail = 0, 0
	if type(list) ~= "table" then
		res.head:SetText("The check isn't available in this version")
		res.head:SetTextColor(T.RGB("red"))
		res:SetHeight(60)
	else
		for i, item in ipairs(list) do
			if type(item) == "table" then
				local ok = item.ok == true
				if ok then pass = pass + 1 else fail = fail + 1 end
				local l = res.lines[i]
				if not l then
					l = CreateFrame("Frame", nil, res)
					l:SetSize(INNER - 28, 20)
					l.icon = T.Icon(l, "check", 14, "glow", "ARTWORK")
					l.icon:SetPoint("LEFT", l, "LEFT", 0, 0)
					l.text = T.Text(l, "caption", "white", "LEFT", "medium")
					T.Lines(l.text, 3) -- (prep-242 r3 G) a long line wraps, never cut
					l.text:SetPoint("LEFT", l, "LEFT", 22, 0)
					l.text:SetWidth(INNER - 52)
					l:EnableMouse(true)
					T.Tip(l, function(self) return self.name end, function(self)
						if self.ok then return "Works in your game." end
						return "Not working: " .. (self.detail or "unknown") .. ". Wuber carries on without it."
					end)
					res.lines[i] = l
				end
				l.name, l.ok, l.detail = S(item.name) or "?", ok, S(item.detail)
				l:ClearAllPoints()
				l:SetPoint("TOPLEFT", res, "TOPLEFT", 14, -y)
				l.icon:SetTexture(T.MEDIA .. (ok and "check" or "close"))
				l.icon:SetVertexColor(T.RGB(ok and "glow" or "red"))
				l.text:SetText(l.name .. ((not ok and l.detail) and ("  ·  " .. l.detail) or ""))
				l.text:SetTextColor(T.RGB(ok and "white" or "red"))
				l:Show()
				y = y + fitLine(l)
			end
		end
		-- the driver's readiness (Warlocks and crew members) and the crew's message counters
		local DRm = W.Drive
		local extra = {}
		local role = type(DRm) == "table" and call(DRm.Role) or nil
		if type(DRm) == "table" and (isWarlock() or role == "helper" or role == "driver") then
			local rl = call(DRm.Readiness)
			if type(rl) == "table" then
				for _, l in ipairs(rl) do
					if type(l) == "table" and S(l.text) then extra[#extra + 1] = { name = l.text, ok = l.ok ~= false, driver = true } end
				end
			end
			local cm = type(DRm.comm) == "table" and DRm.comm or nil
			if cm then
				extra[#extra + 1] = { name = ("Crew messages: %d sent, %d refused, %d heard"):format(N(cm.sent) or 0, N(cm.failed) or 0, N(cm.heard) or 0),
					ok = (N(cm.failed) or 0) == 0 }
			end
		end
		for _, item in ipairs(extra) do
			local i = #res.lines + 1
			for k, l in ipairs(res.lines) do if not l:IsShown() then i = k break end end
			local l = res.lines[i]
			if not l then
				l = CreateFrame("Frame", nil, res)
				l:SetSize(INNER - 28, 20)
				l.icon = T.Icon(l, "check", 14, "glow", "ARTWORK")
				l.icon:SetPoint("LEFT", l, "LEFT", 0, 0)
				l.text = T.Text(l, "caption", "white", "LEFT", "medium")
				T.Lines(l.text, 3) -- (prep-242 r3 G) a long line wraps, never cut
				l.text:SetPoint("LEFT", l, "LEFT", 22, 0)
				l.text:SetWidth(INNER - 52)
				l:EnableMouse(true)
				T.Tip(l, function(self) return self.name end, function(self) return self.ok and "Fine." or "Needs a look: see your Drive tab." end)
				res.lines[i] = l
			end
			l.name, l.ok = item.name, item.ok
			l:ClearAllPoints()
			l:SetPoint("TOPLEFT", res, "TOPLEFT", 14, -y)
			l.icon:SetTexture(T.MEDIA .. (item.ok and "check" or "close"))
			l.icon:SetVertexColor(T.RGB(item.ok and "glow" or "red"))
			l.text:SetText(item.name)
			l.text:SetTextColor(T.RGB(item.ok and "white" or "red"))
			l:Show()
			y = y + fitLine(l)
		end
		-- (HUNT-108) the crossed lines under the game checks: driver lines and the crew messages line
		local badDrv, badOther = 0, 0
		for _, item in ipairs(extra) do
			if not item.ok then if item.driver then badDrv = badDrv + 1 else badOther = badOther + 1 end end
		end
		if fail == 0 and badDrv + badOther > 0 then
			local n = badDrv + badOther
			if badOther == 0 then
				res.head:SetText("All " .. pass .. " game checks passed. " .. n .. (n == 1 and " driver line needs" or " driver lines need") .. " a look: see your Drive tab.")
			else
				res.head:SetText("All " .. pass .. " game checks passed. " .. n .. (n == 1 and " line below needs" or " lines below need") .. " a look.")
			end
			res.head:SetTextColor(T.RGB("red"))
		elseif fail == 0 then
			res.head:SetText("All " .. pass .. " checks passed. Your game runs Wuber fully.")
			res.head:SetTextColor(T.RGB("glow"))
		else
			res.head:SetText(pass .. " passed, " .. fail .. " not working (Wuber works around them)")
			res.head:SetTextColor(T.RGB("red"))
		end
		res:SetHeight(y + 12)
	end
	res:Show()
	A.FadeIn(res, 0.25)
	UI.LayoutSettings()
	-- the results come into view whole: scrolled down just far enough that the card's
	-- bottom clears the scroll area (folded it is only a phone's height), never past its own top
	if st.clip and st.clip.GetHeight and st.scrollMax then
		local base = st.restTop or 0
		local rowTop = base + (st.checkRowY or st.checkY or 0) -- the Check row's top: the view starts there when it all fits
		-- (design 1, M) the row's real place: wrapped text above it grew the page, so what the build counted can be short
		local shift = 0
		local crow = st.controls.check and st.controls.check.GetParent and st.controls.check:GetParent()
		local okt, ct = pcall(st.content.GetTop, st.content)
		local okr, rt = pcall(crow and crow.GetTop or function() end, crow)
		ct, rt = okt and N(ct), okr and N(rt)
		if ct and rt then shift = (ct - rt) - rowTop end
		rowTop = rowTop + shift
		-- (REV-r27-1) the footer line under the card (8 + 8 below it) comes into view whole too
		-- (the Settings diet) in Advanced, the Wide pages frame sits between the card and the footer: its place is the frame's own
		local footTop = st.frameTop and st.winFoot and st.frameTop[st.winFoot]
		local bottom
		if footTop then
			bottom = shift + footTop + 8 + (st.about and N(st.about:GetStringHeight()) or 13) + 4
		else
			bottom = shift + base + (st.checkY or 0) + (N(res:GetHeight()) or 60) + 16 + (st.about and N(st.about:GetStringHeight()) or 13) + 4
		end
		local room = N(st.clip:GetHeight()) or 0
		-- all of it fits: start at the Check row; else the card's bottom is what shows. The 4 after the footer line is only
		-- margin: it is not asked of the view, so a page that is 4 short of fitting still shows the Check row whole
		local want = (bottom - rowTop <= room) and (rowTop - 4) or (bottom - 4 - room)
		st.scrollTarget = math.max(st.scrollMin or 0, math.min(st.scrollMax, want))
		if st.scrollTarget ~= st.scroll then
			st.scroll = st.scrollTarget
			st.content:ClearAllPoints()
			st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
		end
	end
end

---------------------------------------------------------------------------
-- Driving (2.0): the engine's options (W.Drive), one row each
---------------------------------------------------------------------------

local function DR() return W.Drive or {} end
local function dopts()
	local o = call(DR().opts)
	return type(o) == "table" and o or {}
end

-- (round 9) this window is a crew member: its passphrase follows the captain's
local function crewWindow()
	local DRv = W.Drive
	if type(DRv) ~= "table" or type(DRv.IsCaptain) ~= "function" then return false end
	local ok, cap = pcall(DRv.IsCaptain)
	return ok and cap == false
end

-- the passphrase as it is in force here (the captain's on a crew window)
local function passOn()
	if type(W.PassphraseOn) == "function" then
		local ok, v = pcall(W.PassphraseOn)
		if ok then return v == true end
	end
	return dopts().showPass == true
end

local function setOpt(key, v)
	local d = DR()
	if type(d.SetOpt) == "function" then call(d.SetOpt, key, v) else dopts()[key] = v end
	W.Fire("SETTINGS", "drive." .. key)
end
local function btn()
	local db = W.db and W.db.drive
	local b = type(db) == "table" and db.button
	return type(b) == "table" and b or {}
end
local function btnChanged()
	local B = DR().Button
	if type(B) == "table" and type(B.Refresh) == "function" then call(B.Refresh) end
	W.Fire("SETTINGS", "drive.button")
end

-- a label with a text field under it (commit on Enter / focus lost)
local function fieldRow(parent, y, key, label, desc, tip, get, put, opts2)
	local r
	r, y = row(parent, y, label, desc, tip, 88)
	-- round 9: the box is 12 wider and its text 5 nearer each end, so a default list ("summon summons summ
	-- sum inv invite ride taxi") shows whole, never cut short (the pill's round ends still clear it)
	local f = T.Field(r, INNER - 16, 30, {
		max = opts2 and opts2.max or 120, placeholder = opts2 and opts2.placeholder or "", size = "caption",
		get = get, onCommit = function(text) put(text) end,
	})
	f:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 8, 12)
	f.edit:ClearAllPoints()
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 10, 0)
	f.edit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 0)
	T.Tip(f.edit, label, tip)
	f.get = get
	st.controls[key] = f
	st.fields[#st.fields + 1] = f
	return y, f, r
end

local function sliderRow(parent, y, key, label, desc, tip, sopts, action)
	local r
	r, y = row(parent, y, label, desc, tip, "slider")
	local bw = action and (action.width or 60) or 0
	local slW = action and (INNER - 28 - bw - 10) or (INNER - 28)
	if action then y = y + grow(r, 4) end
	local sl = T.Slider(r, slW, sopts)
	sl.holder:SetPoint("LEFT", r.below, "LEFT", 0, 0)
	T.Tip(sl, label, tip)
	sl.get = sopts.get
	sl.onChange = sl.onChange or sopts.onChange
	st.controls[key] = sl
	st.sliders[#st.sliders + 1] = sl
	if action then
		local b = T.Pill(r, action.label, "dark", bw, 26)
		b:SetPoint("RIGHT", r.below, "RIGHT", 0, 0)
		b.fill:SetColor("raised")
		b:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
		safeScript(b, "OnClick", function() action.onClick(b) end)
		T.Tip(b, action.label, action.tip)
		if action.key then st.controls[action.key] = b end
		r.actionBtn = b
	end
	return y, sl, r
end

local function optToggle(parent, y, key, label, desc, tip)
	return toggleRow(parent, y, "drive." .. key, label, desc, tip,
		function() return dopts()[key] == true end, function(on) setOpt(key, on) end)
end

local function listText(v)
	if type(v) == "table" then return table.concat(v, " ") end
	return S(v) or ""
end

-- "press a key" capture for the big button
local function keyRow(parent, y)
	local r
	local tip = "Press this key to click the big button, also with Wuber closed. Click Set, then press the key. Clear removes it."
	-- (design 2) its two buttons sit under the words (a row has one control at its right)
	r, y = row(parent, y, "Key for the big button", "None set", tip, 82)
	local set = T.Pill(r, "Set", "dark", 84, 28) -- wide enough for "Press..."
	set:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 16, 12)
	local clear = T.Pill(r, "Clear", "dark", 66, 28)
	clear:SetPoint("LEFT", set, "RIGHT", 8, 0)
	local cap = CreateFrame("Frame", nil, r)
	cap:SetAllPoints(r)
	cap:EnableKeyboard(false)
	-- Clear, hiding Settings and the start of a fight all end a capture the player walked away from
	local function cancelCapture()
		if not st.capturing then return end
		st.capturing = nil
		Try(cap, "EnableKeyboard", false)
		set:SetLabel("Set")
	end
	st.cancelCapture = cancelCapture
	-- (#203) a press anywhere but on Set ends a capture the player walked away from: the keyboard goes back to the game
	pcall(cap.RegisterEvent, cap, "GLOBAL_MOUSE_DOWN")
	safeScript(cap, "OnEvent", function()
		if not st.capturing then return end
		local foci
		if type(GetMouseFoci) == "function" then
			local okf, list = pcall(GetMouseFoci)
			if okf and type(list) == "table" then foci = list end
		elseif type(GetMouseFocus) == "function" then
			local okf, one = pcall(GetMouseFocus)
			if okf and one then foci = { one } end
		end
		for _, fr in ipairs(foci or {}) do
			if fr == set then return end
		end
		cancelCapture()
	end)
	safeScript(cap, "OnHide", cancelCapture)
	safeScript(set, "OnClick", function()
		if inCombat() then UI.Toast("After the fight", "warn") return end
		st.capturing = true
		set:SetLabel("Press...")
		Try(cap, "EnableKeyboard", true)
		Try(cap, "SetPropagateKeyboardInput", false)
	end)
	safeScript(cap, "OnKeyDown", function(_, key)
		key = S(key)
		if not st.capturing or not key then return end
		if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
		st.capturing = nil
		Try(cap, "EnableKeyboard", false)
		set:SetLabel("Set")
		if key == "ESCAPE" then return end
		local mods = ""
		if call(IsAltKeyDown) == true then mods = mods .. "ALT-" end
		if call(IsControlKeyDown) == true then mods = mods .. "CTRL-" end
		if call(IsShiftKeyDown) == true then mods = mods .. "SHIFT-" end
		local d = DR()
		if type(d.SetKey) == "function" then call(d.SetKey, mods .. key) else btn().key = mods .. key end
		UI.Toast("The big button is on " .. mods .. key, "info")
		UI.UpdateSettings()
	end)
	-- the client turns keyboard input ON for a frame once OnKeyDown is set (and propagate is off), so the cover would eat every
	-- key: switch it off AFTER the script is set, and again whenever the row shows (only a capture takes keys)
	Try(cap, "EnableKeyboard", false)
	safeScript(cap, "OnShow", function() if not st.capturing then Try(cap, "EnableKeyboard", false) end end)
	safeScript(clear, "OnClick", function()
		cancelCapture()
		local d = DR()
		if type(d.SetKey) == "function" then call(d.SetKey, nil) else btn().key = nil end
		UI.UpdateSettings()
	end)
	T.Tip(set, "Set a key", "Click, then press the key you want (Shift, Ctrl or Alt with it is fine). Esc cancels.")
	T.Tip(clear, "Clear", "No key for the big button.")
	st.keyRow = r
	st.controls["drive.key"] = set
	return y
end

local function buildDriving(drive, dy)
	dy = section(drive, dy, "Driving: inviting")
	-- (2.3.2) off by default; turning it on asks first (DR.SetAutoPublic's warning),
	-- so the switch stays off until Yes, and Cancel leaves it off
	dy = toggleRow(drive, dy, "drive.autoPublic", "Invite public chat riders", "Public chat channels you read, not whispers.",
		"On: invites riders in the public chat channels you read (see Chat channels) who name your place. Wuber can misread chat, so it asks you once when you switch this on. Off: click a name to invite.",
		function() return dopts().autoPublic == true end,
		function(on, t)
			local d = DR()
			if not on or type(d.SetAutoPublic) ~= "function" then return setOpt("autoPublic", on) end
			-- the click's own slide to "on" is still running: SetOn(false) alone left the
			-- knob ticked and the track grey once the slide ended. Settle on the real value now, when
			-- the answer comes, and when the popup goes away without one (Escape, another popup).
			local function settle()
				local tg = st.controls["drive.autoPublic"] or t
				if not tg then return end
				local real = dopts().autoPublic == true
				T.Tween(tg, 0, 0, function() end) -- from == to ends a running slide
				tg:SetOn(real)
				UI.UpdateSettings()
			end
			local function watch(n)
				W.After(0.25, function()
					local find = rawget(_G, "StaticPopup_FindVisible")
					if n < 400 and type(find) == "function" and find(d.PUBLIC_POPUP) then return watch(n + 1) end
					settle()
				end)
			end
			if dopts().autoPublic ~= true then settle() end
			local res = call(d.SetAutoPublic, true, settle)
			if res == "asked" then watch(0) end
			-- (review #6) no popup to ask with: say so, as /wuber drive market does
			if res == nil then UI.Toast("Invite public chat riders: off (the warning can't be shown right now).", "warn") end
		end)
	dy = toggleRow(drive, dy, "starter", "List me in Wuber's starter list", "So new riders can find you.",
		"New Wuber users start with a short list of drivers to ask. On: you can be on it (only your name; riders still see you "
		.. "only when you answer them yourself). Off: you are never put on it.",
		function()
			local ch = type(W.Char) == "function" and call(W.Char)
			return not (type(ch) == "table" and ch.starter == false)
		end, function(on)
			local ch = type(W.Char) == "function" and call(W.Char)
			if type(ch) ~= "table" then return end
			ch.starter = on and true or false
			W.Fire("SETTINGS", "starter")
			if type(W.SendBeacon) == "function" then call(W.SendBeacon) end
		end)
	-- (Group Finder, B1) off by default; its words are drafts kept in W.GroupFinder.DRAFT_WORDS
	if type(W.GroupFinder) == "table" and type(W.GroupFinder.DRAFT_WORDS) == "table" then
		local gw = W.GroupFinder.DRAFT_WORDS
		dy = toggleRow(drive, dy, "groupFinder", gw.settingName, gw.settingHint, gw.settingHint,
			function() return db().groupFinder == true end, function(on) set("groupFinder", on and true or false) end)
	end
	dy = sliderRow(drive, dy, "drive.maxGroup", "Group size", "auto: 5, or 10 with a crew of 3+",
		"One rider at a time; the next after the last pays. Size includes your crew. Over 5, the game asks once for a raid.",
		{ min = 1, max = 40, step = 1, value = 2, live = false, labelW = 90,
			get = function()
				local o = dopts()
				if o.oneAtATime == true then return 1 end
				local v = N(o.maxGroup) or 0
				if v < 3 then return 2 end
				return math.min(40, math.floor(v))
			end,
			format = function(v)
				v = math.floor((N(v) or 2) + 0.5)
				if v <= 1 then return "One at a time" end
				if v == 2 then return "Auto" end
				return v .. " people"
			end,
			onChange = function(v)
				v = math.floor((N(v) or 2) + 0.5)
				if v <= 1 then
					setOpt("oneAtATime", true)
				elseif v == 2 then
					setOpt("oneAtATime", false)
					setOpt("maxGroup", 0)
				else
					setOpt("oneAtATime", false)
					setOpt("maxGroup", v)
				end
			end })
	dy = optToggle(drive, dy, "autoReply", "Whisper back to public requests", "Advanced: one whisper, then they whisper you.",
		"Whispers once to a clear public request for your place. Once an hour per person; never in combat, a raid, an instance or a ride.")
	st.notes = st.notes or {}
	dy, st.notes.autoReply = noteUnder(st.controls["drive.autoReply"], dy, NOTES.replyNote) -- (quick wins)
	local cr
	local watchTip = "The public channels Wuber reads for buyers. Usually: services, trade, lookingforgroup, world, general."
	local adTip = "Where your adverts go, in turn: the one posted to longest ago first. Usually services, trade, lookingforgroup."
	cr, dy = row(drive, dy, "Chat channels", "", watchTip .. " " .. adTip, 164)
	local lbl1 = T.Text(cr, "caption", "muted", "LEFT", "medium")
	lbl1:SetWidth(INNER - 32)
	lbl1:SetText("Read these")
	lbl1:SetPoint("BOTTOMLEFT", cr, "BOTTOMLEFT", 16, 102)
	local wfGet = function() return listText(dopts().watchChannels) end
	local wf = T.Field(cr, INNER - 16, 30, {
		max = 120, placeholder = "", size = "caption",
		get = wfGet, onCommit = function(t) setOpt("watchChannels", t) end,
	})
	wf:SetPoint("BOTTOMLEFT", cr, "BOTTOMLEFT", 8, 68)
	wf.edit:ClearAllPoints()
	wf.edit:SetPoint("TOPLEFT", wf, "TOPLEFT", 10, 0)
	wf.edit:SetPoint("BOTTOMRIGHT", wf, "BOTTOMRIGHT", -10, 0)
	T.Tip(wf.edit, "Read these", watchTip)
	wf.get = wfGet
	st.controls["drive.watchChannels"] = wf
	st.fields[#st.fields + 1] = wf
	local lbl2 = T.Text(cr, "caption", "muted", "LEFT", "medium")
	lbl2:SetWidth(INNER - 32)
	lbl2:SetText("Advertise in these")
	lbl2:SetPoint("BOTTOMLEFT", cr, "BOTTOMLEFT", 16, 46)
	local afGet = function() return listText(dopts().adChannels) end
	local af = T.Field(cr, INNER - 16, 30, {
		max = 120, placeholder = "", size = "caption",
		get = afGet, onCommit = function(t) setOpt("adChannels", t) end,
	})
	af:SetPoint("BOTTOMLEFT", cr, "BOTTOMLEFT", 8, 12)
	af.edit:ClearAllPoints()
	af.edit:SetPoint("TOPLEFT", af, "TOPLEFT", 10, 0)
	af.edit:SetPoint("BOTTOMRIGHT", af, "BOTTOMRIGHT", -10, 0)
	T.Tip(af.edit, "Advertise in these", adTip)
	af.get = afGet
	st.controls["drive.adChannels"] = af
	st.fields[#st.fields + 1] = af
	dy = fieldRow(drive, dy, "drive.keywords", "Request words", "A whisper with one of these is a request.",
		"Words that make a whisper a request, separated by spaces: summon summons summ sum inv invite ride taxi.",
		function() return listText(dopts().keywords) end, function(t) setOpt("keywords", t) end)

	dy = section(drive, dy + 4, "Driving: whispers and trades")
	local wr
	wr, dy = row(drive, dy, "How whispers leave", "Button: your click sends them.",
		"Button: each whisper goes out when you click the big button (the safe way). Chat box: Wuber types it, you press Enter. Off: riders are told nothing.", 84)
	local seg = T.Segmented(wr, {
		{ value = "auto", label = "Button", tip = "Your big-button click sends each whisper (falls back to the chat box if your whispers do not go through)." },
		{ value = "box", label = "Chat box", tip = "Wuber puts each whisper in the chat box; Enter sends it." },
		{ value = "off", label = "Off", tip = "No whispers at all." },
	}, "auto", function(v) setOpt("whisperMode", v) end, INNER - 28, 30)
	seg:SetPoint("BOTTOMLEFT", wr, "BOTTOMLEFT", 16, 12)
	st.controls["drive.whisperMode"] = seg
	dy = optToggle(drive, dy, "acceptUnder", "Count a smaller payment as paid", "Off: they're asked for the rest.",
		"Off: the big button never accepts less than your price; the rider is asked for the rest. On: any payment counts.")
	-- a crew window follows its captain's setting here, like "Show ride passphrase": a click there changes nothing
	dy = toggleRow(drive, dy, "drive.kickAfter", "Remove riders after the thanks", "Shared with your crew.",
		"After the thank-you whisper the rider is removed from your group, freeing the seat. Your crew does the same.",
		function() return dopts().kickAfter == true end, function(on, t)
			if crewWindow() then
				if t then t:SetOn(dopts().kickAfter == true, true) end
				return
			end
			setOpt("kickAfter", on)
		end)
	local lr
	local blkTip = "A rider who was summoned, landed and left the group owing gold is blocked by themselves (Undo for 10 seconds)."
	local tellTip = "A blocked player who asks again gets one whisper saying why (at most once every ten minutes)."
	local lo = dopts()
	local lv0 = lo.autoBlock ~= true and "off" or (lo.tellBlocked == true and "tell" or "quiet")
	lr, dy = row(drive, dy, "Riders who leave without paying", "You get a toast with Undo.", blkTip .. " " .. tellTip, 84)
	local lseg = T.Segmented(lr, {
		{ value = "tell", label = "Block and tell them", tip = blkTip .. " " .. tellTip },
		{ value = "quiet", label = "Block quietly", tip = blkTip },
		{ value = "off", label = "Do nothing", tip = "Nothing happens: the rider stays unblocked and you only get a toast." },
	}, lv0, function(v)
		if v == "tell" then
			setOpt("autoBlock", true)
			setOpt("tellBlocked", true)
		elseif v == "quiet" then
			setOpt("autoBlock", true)
			setOpt("tellBlocked", false)
		else
			setOpt("autoBlock", false)
		end
	end, INNER - 12, 30, { byLabel = true, pad = 6 })
	lseg:SetPoint("BOTTOMLEFT", lr, "BOTTOMLEFT", 6, 12)
	st.controls["drive.leavers"] = lseg

	dy = section(drive, dy + 4, "Driving: summoning")
	dy = sliderRow(drive, dy, "drive.lowShards", "Warn me at this many shards", "0: never",
		"A warning when your Soul Shards drop to this many, and each one lower.",
		{ min = 0, max = 10, step = 1, value = 3, get = function() return N(dopts().lowShards) or 3 end,
			format = function(v) return v == 0 and "never" or (math.floor(v) .. (math.floor(v) == 1 and " shard" or " shards")) end,
			onChange = function(v) setOpt("lowShards", v) end })
	dy = fieldRow(drive, dy, "drive.ritual", "Summoning spell name", "Advanced: only if the button won't cast.",
		"The summoning spell's name as your game shows it, if the button can't find it (another language). Empty: found by itself.",
		function() return S(dopts().ritual) or "" end, function(t) setOpt("ritual", t) end, { placeholder = "Found by itself" })

	dy = section(drive, dy + 4, "Driving: adverts")
	dy = sliderRow(drive, dy, "drive.adEvery", "Advert reminder", "0: never",
		"The Advertise button turns violet and rings after this many minutes (15 at least). It never posts by itself.",
		{ min = 0, max = 60, step = 5, value = 15, labelW = 100, get = function() return N(dopts().adEvery) or 15 end,
			format = function(v) return v == 0 and "never" or ("every " .. math.floor(math.max(15, v)) .. " min") end,
			onChange = function(v) if v > 0 and v < 15 then v = 15 end setOpt("adEvery", v) end })
	return dy
end

-- the big button and the alert character
local function buildDriving2(drive, dy)
	dy = section(drive, dy + 4, "Driving: the big button")
	dy = sliderRow(drive, dy, "drive.scale", "Big button size", "Fit: sized for your window",
		"Makes the floating big button bigger or smaller. Fit window sizes it for small screens.",
		{ min = 0.5, max = 3, step = 0.1, value = 1, live = false,
			get = function() return N(call(DR().Scale)) or 1 end,
			format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
			onChange = function(v)
				local d = DR()
				if type(d.SetScale) == "function" then call(d.SetScale, v) else btn().scale, btn().sizeSet = v, true end
				btnChanged()
			end },
		{ key = "drive.fit", label = "Fit", width = 52,
			tip = "Sizes the big button for your game window by itself (good for small screens).",
			onClick = function()
				local d = DR()
				if type(d.SetScale) == "function" then call(d.SetScale, nil) else btn().sizeSet = false end
				btnChanged()
				UI.UpdateSettings()
			end })
	local lockRow
	dy, lockRow = toggleRow(drive, dy, "drive.locked", "Lock the big button", "No moving it by accident.",
		"Locked: shift-drag doesn't move the floating big button.",
		function() return btn().locked == true end, function(on) btn().locked = on btnChanged() end)
	attachSwitchButton(lockRow, "drive.resetPos", "Reset place", 90, "Reset place",
		"Puts the floating big button back where it starts.", function()
			if inCombat() then UI.Toast("After the fight", "warn") return end
			local was = btn().pos -- (decisions N) kept only in the Undo
			call(DR().ResetPosition)
			resetDone(was ~= nil and 1 or 0, function()
				btn().pos = was
				local B = DR().Button
				if type(B) == "table" then call(B.Place) end
				btnChanged()
			end, "The big button is back in place")
		end)
	local orow
	local showTip = "Shows the floating big button (with the mini list under it) while the Wuber window is closed."
	local keepTip = "Keeps the big button on screen while you're closed and whether or not anyone is in your list."
	local b0 = btn()
	local os0 = b0.shown == false and "wuber" or (b0.keepClosed == true and "always" or "waiting")
	orow, dy = row(drive, dy, "Big button on screen", "", showTip .. " " .. keepTip, 84)
	local oseg = T.Segmented(orow, {
		{ value = "always", label = "Always", tip = showTip .. " " .. keepTip },
		{ value = "waiting", label = "When riders wait", tip = showTip },
		{ value = "wuber", label = "Only in Wuber", tip = "Hidden when Wuber is closed." },
	}, os0, function(v)
		local b = btn()
		if v == "always" then
			b.shown = true
			b.keepClosed = true
		elseif v == "waiting" then
			b.shown = true
			b.keepClosed = false
		else
			b.shown = false
		end
		btnChanged()
	end, INNER - 16, 30, { byLabel = true })
	oseg:SetPoint("BOTTOMLEFT", orow, "BOTTOMLEFT", 8, 12)
	st.controls["drive.onScreen"] = oseg

	dy = section(drive, dy + 4, "Driving: more")
	local bellY = dy
	local bellField, bellRow
	dy, bellField, bellRow = fieldRow(drive, dy, "drive.bell", "Alert character", "A character on another account.",
		"A character you have logged in on another account: it flashes, beeps and shows a banner when one of your windows needs a click. Empty: off.",
		function()
			local db = W.db and W.db.drive
			return type(db) == "table" and type(db.bell) == "table" and S(db.bell.name) or ""
		end, function(t)
			local d = DR()
			if type(d.BellSet) == "function" then
				local ok, why = call(d.BellSet, t)
				if ok == false and why then UI.Toast(tostring(why), "warn") end
			end
			UI.UpdateSettings()
		end, { placeholder = "Name-Realm (empty: off)", max = 40 })
	st.bellY = bellY
	dy = dy + grow(bellRow, 36)
	bellField:ClearAllPoints()
	bellField:SetPoint("BOTTOMLEFT", bellRow, "BOTTOMLEFT", 8, 48)
	local bellTest = T.Pill(bellRow, "Test", "dark", 64, 28)
	bellTest:SetPoint("BOTTOMLEFT", bellRow, "BOTTOMLEFT", 16, 12)
	bellTest.fill:SetColor("raised")
	bellTest:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(bellTest, "OnClick", function()
		local ok, why = call(DR().BellTest)
		if ok and why == "here" then return end -- this is the alert character: the banner is the answer
		UI.Toast(ok and "Test sent" or (S(why) or "No alert character set"), ok and "info" or "warn")
	end)
	T.Tip(bellTest, "Test", "Sends one test alert to your alert character: it should flash, beep and show a banner.")
	st.controls["drive.bellTest"] = bellTest
	local bellForget = T.Pill(bellRow, "Forget", "dark", 74, 28)
	bellForget:SetPoint("LEFT", bellTest, "RIGHT", 8, 0)
	bellForget.fill:SetColor("raised")
	bellForget:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(bellForget, "OnClick", function()
		call(DR().BellForget)
		UI.Toast("Forgotten", "info")
	end)
	T.Tip(bellForget, "Forget", "On your alert character: forget which drivers it listens to (it learns again from the next hello).")
	st.controls["drive.bellForget"] = bellForget
	dy = toggleRow(drive, dy, "drive.alertWindow", "This is my alert window", "",
		"On: this window takes the first crew hello only from your own driver, so nobody else can make your alert ring. Turn it on in the window you keep for alerts.",
		function()
			local d = DR()
			if type(d.AlertWindow) == "function" then return call(d.AlertWindow) == true end
			local c = W.Char and W.Char()
			return type(c) == "table" and c.alertWindow == true
		end, function(on)
			local d = DR()
			if type(d.SetAlertWindow) == "function" then
				call(d.SetAlertWindow, on and true or false)
			else
				local c = W.Char and W.Char()
				if type(c) == "table" then c.alertWindow = on and true or false end
				W.Fire("SETTINGS", "alertWindow")
			end
		end)
	return dy
end

---------------------------------------------------------------------------
-- Round 8: the new rows. Riding: the flight master tip (5.11). This window: wide pages
-- and their reset (the Fold, section 2; UI.WindowWide / UI.Fold.Reset are UI.Fold's). Driving:
-- the fair split (5.5) and what riders want (5.3).
---------------------------------------------------------------------------

-- Round 25 (T2): "Login tips". UI.Tips (later module) owns the switch; without it the saved flag is set directly.
local function tipsOn()
	local m = W.Mod("UI.Tips")
	if type(m) == "table" and type(m.IsOn) == "function" then return m.IsOn() and true or false end
	return db().tipsOn ~= false
end

local function setTips(on)
	local m = W.Mod("UI.Tips")
	if type(m) == "table" and type(m.SetOn) == "function" then
		call(m.SetOn, on and true or false)
	else
		db().tipsOn = on and true or false
	end
end

local function buildRiding8(c, y)
	local tipsRow
	y, tipsRow = toggleRow(c, y, "tips", "Tips", "A short tip inside Wuber the next time you open it.",
		"On: a small tip card shows when you open Wuber after login, each tip once. Off: none. Type /wuber tips for one now.",
		tipsOn, setTips)
	attachSwitchButton(tipsRow, "coach", "Replay", 64, "Replay",
		"Shows the first-open tips again, from the first: how to find a driver, how paying works and where to sell summons.",
		function() if UI.ReplayCoach then UI.ReplayCoach() end end)
	return toggleRow(c, y, "flightOffers", "Flight offers", "A summon that beats flying: beside the flight map, on it, and while you fly.",
		"Shows a faster summon at a flight master's map, and once mid-flight. Never in combat or during a ride. Off: no cards.",
		function()
			local d = db()
			return d.birdTip ~= false and d.flightOffers ~= false
		end, function(on)
			on = on and true or false
			if on then db().midFlight = nil end
			set("birdTip", on)
			set("flightOffers", on)
		end)
end

local function foldDB()
	local d = db()
	return type(d.fold) == "table" and d.fold or {}
end

local function buildWindow8(rest, y)
	local wr
	wr, y = row(rest, y, "Wide pages", "Some pages open out to two panes.",
		"Auto: pages that need room (the drivers, booking, trips, settings and the Drive screens) open wide when your game "
		.. "window has room. Always narrow: Wuber stays phone-sized. The button at the top of the window opens or closes a page too.", 84)
	local resetW = 64
	local seg = T.Segmented(wr, {
		{ value = "auto", label = "Auto", tip = "Open wide where it helps, when there is room." },
		{ value = "narrow", label = "Always narrow", tip = "Always phone-sized." },
	}, foldDB().narrow and "narrow" or "auto", function(v)
		if type(UI.WindowWide) == "function" then
			call(UI.WindowWide, v == "auto")
		else
			local d = db()
			if type(d.fold) ~= "table" then d.fold = { v = 1, pages = {} } end
			d.fold.narrow = v == "narrow"
		end
		W.Fire("SETTINGS", "fold")
	end, INNER - 28 - resetW - 8, 30, { byLabel = true }) -- (#266) segments sized by their words: "Always narrow" is the longer one
	seg:SetPoint("BOTTOMLEFT", wr, "BOTTOMLEFT", 16, 12)
	st.controls.foldWide = seg
	local resetBtn = T.Pill(wr, "Reset", "dark", resetW, 30)
	resetBtn:SetPoint("LEFT", seg, "RIGHT", 8, 0)
	resetBtn.fill:SetColor("raised")
	resetBtn:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(resetBtn, "OnClick", function()
		local F = UI.Fold
		-- (decisions N) what the reset forgets (each page's choice, Always narrow), kept only in the Undo
		local f0, n, pages = foldDB(), 0, {}
		local narrow = f0.narrow == true
		for k, v in pairs(type(f0.pages) == "table" and f0.pages or {}) do pages[k] = v n = n + 1 end
		if narrow then n = n + 1 end
		if type(F) == "table" and type(F.Reset) == "function" then call(F.Reset) end
		if st.controls.foldWide and st.controls.foldWide.SetValue then st.controls.foldWide:SetValue("auto", true) end
		resetDone(n, function()
			local f = foldDB()
			f.pages, f.narrow = pages, narrow
			if type(F) == "table" then call(F.Apply) end
			if st.controls.foldWide and st.controls.foldWide.SetValue then st.controls.foldWide:SetValue(narrow and "narrow" or "auto", true) end
			W.Fire("SETTINGS", "fold")
		end, "Every page is back to Auto")
	end)
	T.Tip(resetBtn, "Reset", "Each page remembers whether you opened or closed it with the button at the top. This forgets them all: every page goes back to Auto.")
	st.controls.foldReset = resetBtn
	return y
end

local function buildDriving3(drive, dy)
	-- (round 13, I26) riders and notes
	dy = section(drive, dy + 4, "Driving: riders and notes")
	-- round 9 (the author): the ride passphrase is off unless the driver turns it on
	dy = toggleRow(drive, dy, "drive.showPass", "Show ride passphrase", "Two words you and the rider both see.",
		"On: you and a Wuber rider see the same two words, so you know it's the right person. Your crew follows the captain.",
		-- a crew window shows (and follows) its captain's setting; a click there changes nothing
		function() return passOn() end, function(on, t)
			if crewWindow() then
				-- back to the captain's value, retargeting the knob's slide the click started
				if t then t:SetOn(passOn(), true) end
				return
			end
			setOpt("showPass", on)
		end)
	local cmd = T.Text(drive, "caption", "muted", "LEFT", "regular")
	cmd:SetPoint("TOPLEFT", drive, "TOPLEFT", PAD + 4, -(dy + 10))
	cmd:SetWidth(INNER - 8)
	cmd:SetText("Typed commands: /wuber drive help")
	return dy + 32
end

local function newerVersion()
	return type(W.NewerVersion) == "function" and S(call(W.NewerVersion)) or nil
end

-- the footer under the window's section (UI.Settings.Panel's st.about)
local function aboutText()
	local v = newerVersion()
	if v then return "Wuber " .. tostring(W.VERSION or "") .. " · Wuber " .. v .. " is out: see above.\n/wuber opens this app." end
	return "Wuber " .. tostring(W.VERSION or "") .. " · summons on demand · no website, no server.\n/wuber opens this app."
end

local function syncUpdates()
	if st.about then st.about:SetText(aboutText()) end
end

local function sync8()
	local c = st.controls or {}
	for _, key in ipairs({ "flightOffers", "tips", "drive.showPass" }) do
		local t = c[key]
		if t and t.get then
			local on = t.get() and true or false
			if t.on ~= on then t:SetOn(on) end
		end
	end
	-- (round 9) a crew window's "Show ride passphrase" is greyed and says it follows the captain
	local member = crewWindow()
	for key, plain in pairs({ ["drive.showPass"] = "Two words you and the rider both see.", ["drive.kickAfter"] = "Shared with your crew." }) do
		local sp = c[key]
		if sp then
			sp:SetAlpha(member and 0.4 or 1)
			if sp.row and sp.row.desc then
				sp.row.desc:SetText(member and "Follows your captain's setting." or plain)
			end
		end
	end
	local fw = c.foldWide
	if fw then
		local v = foldDB().narrow and "narrow" or "auto"
		if fw.value ~= v then fw:SetValue(v) end
	end
	syncUpdates()
end

-- (round 11) a newer version trusted while Settings is open: its lines say so at once
W.Listen("NEWER_VERSION", function() syncUpdates() end)

-- a fight starting ends a key capture (the keyboard is not ours to hold in combat)
W.On("PLAYER_REGEN_DISABLED", function() if st.cancelCapture then st.cancelCapture() end end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.INNER = INNER
Mod.aboutText = aboutText
Mod.NOTES = NOTES
Mod.noteUnder = noteUnder
Mod.KEYWORDS = KEYWORDS
Mod.index = index
Mod.N = N
Mod.PAD = PAD
Mod.S = S
Mod.TOP_H = TOP_H
Mod.WIN_W = WIN_W
Mod.btn = btn
Mod.buildDriving = buildDriving
Mod.keyRow = keyRow
Mod.optToggle = optToggle
Mod.buildDriving2 = buildDriving2
Mod.buildDriving3 = buildDriving3
Mod.buildRiding8 = buildRiding8
Mod.buildWindow8 = buildWindow8
Mod.sync8 = sync8
Mod.buttonRow = buttonRow
Mod.call = call
Mod.db = db
Mod.dopts = dopts
Mod.hiddenCount = hiddenCount
Mod.inCombat = inCombat
Mod.isWarlock = isWarlock
Mod.row = row
Mod.grow = grow
Mod.headingText = headingText
Mod.runCheck = runCheck
Mod.resetDone, Mod.SENDING, Mod.sendingRow = resetDone, SENDING, sendingRow
Mod.safeScript = safeScript
Mod.section = section
Mod.set = set
Mod.st = st
Mod.tipsOn = tipsOn
Mod.toggleRow = toggleRow
Mod.friendlyPlatesOn = friendlyPlatesOn
Mod.turnOnPlates = turnOnPlates
