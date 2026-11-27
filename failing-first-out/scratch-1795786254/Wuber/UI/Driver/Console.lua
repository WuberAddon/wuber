-- Module: UI.Driver.Console
-- Purpose: Screens, sheets and the big button's dock (D.ShowScreen, D.ShowSheet, D.Slot, D.SyncDock),
--   refresh, D.Build, the Drive tab, wiring.
-- API: D.ShowScreen, D.CurrentScreen, D.ShowSheet, D.SheetOpen, D.PageOver, D.Slot, D.SyncDock, D.Refresh,
--   D.RefreshNow, D.Build, D.Toggle, D.SideChip, D.PaintSideChip, D.LaySideChips, D.SidePane,
--   D.DrawConsoleSide, D.WideLayout, D.FOLD.console (r18: unfolded, the riders stay on the left under the
--   buttons; the side pane has the crew, today's takings and the best hours; r46: a grey "Your summons: about 45 sec"
--   line under the takings figure from DR.SummonAvg, once 3 summons are counted, with its own tip; 2.4 p2: the
--   careful record line from DR.AutoRecordText right under it, with its own tip)
-- (design 2, N) D.ShowScreen pushes a page in from the right over the console or the page before it (A.Push) and
--   "console" pops it (A.PopPage), inside the Drive tab's body; D.pageMoving is true while one travels (D.Slot then
--   gives no slot) and the dock and the overlays are laid when it ends; in combat the swap is at once.
-- Internals: (none)
-- Uses: UI.Driver.State, UI.Driver.Build, UI.Driver.Draw
-- Later: UI.Driver.Earnings (D.BuildHeatmap, D.PaintHeatmap, D.TopWindow), UI.Driver.Demand (List, D.DemandCard), run time
-- Events: listens Listen (loop: DRIVE, DRIVE_CREW, DRIVE_LOG, DRIVE_PAID, DRIVE_RANK, SETTINGS, PROVIDER,
--   COMMUNITY, ADVERT, REQUESTS), On GROUP_ROSTER_UPDATE, On PLAYER_REGEN_DISABLED, On
--   PLAYER_REGEN_ENABLED, login; fires PAGE (2.3: D.ShowScreen, D.ShowSheet open/close); owns the built tab `ui` (was UI.Driver.State's line 52) and
--   sets D.ui with it
-- Standalone: no
-- Test: tests/ui/driver/console_test.lua
-- From: Driver.lua 2455-2724 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Console", { "UI.Driver.State", "UI.Driver.Build", "UI.Driver.Draw" })
local StateMod = W.Mod("UI.Driver.State")
local BuildMod = W.Mod("UI.Driver.Build")
local DrawMod = W.Mod("UI.Driver.Draw")
local N, S, call, inCombat = StateMod.N, StateMod.S, StateMod.call, StateMod.inCombat
local now, safeScript, setShown = StateMod.now, StateMod.safeScript, StateMod.setShown
local buildConsole, buildProvider, buildWelcome, paintWelcome = BuildMod.buildConsole, BuildMod.buildProvider, BuildMod.buildWelcome, BuildMod.paintWelcome
local drawConsole, drawProvider, slotWords = DrawMod.drawConsole, DrawMod.drawProvider, DrawMod.slotWords
local T = W.Theme
local A = T.Animate
local Try = T.Try

local DR = W.Drive

local D = W.Driver

local ui -- the built tab (D.ui for tests)
local refreshNow -- (below)

-- (2.3) the Drive tab's page may have changed: UI.Fold works it out
local function pageChanged() W.Fire("PAGE") end

---------------------------------------------------------------------------
-- Screens (UI_Drive.lua's), the sheets, and the big button's dock
---------------------------------------------------------------------------

-- (design 2, N) the console, the welcome or the provider page: whichever shows under the pushed pages
local function baseView()
	for _, f in ipairs({ ui.console, ui.welcome, ui.provider }) do
		if f and f:IsShown() then return f end
	end
	return ui[ui.mode or "console"] -- hidden by the push before: the one the page's mode shows
end

-- (design 2, N) A pushed page comes in from the right over 'under' (push) or leaves that way while 'under' comes
-- back (pop), cut off by the Drive tab's body (360 wide in the wide window too). While it travels D.Slot gives no
-- slot; only one of the two is on screen during the move, opts.single: no frame level is touched (the big button never sits where its slot is not) and the Advertise overlays stay away (the window's
-- animUntil); both are laid again when the move ends. In combat nothing travels (opts.secure): a swap at once.
local function pageMove(page, under, push)
	local U = W.UI
	local wst = U and U.state
	if not (ui.root:IsVisible() and wst) then
		A.StopPage(ui.parent)
		if push then page:Show() else page:Hide() end
		return
	end
	local opts = { clip = ui.parent, width = N(Try(ui.parent, "GetWidth")) or 360, secure = true, single = true, onDone = function()
		D.pageMoving = nil
		if wst.animUntil and wst.animUntil > now() then wst.animUntil = now() end
		D.SyncDock()
		if type(U.SyncSecure) == "function" then call(U.SyncSecure) end
	end }
	D.pageMoving = true
	local until_ = now() + T.MOTION.page + 0.02
	if (N(wst.animUntil) or 0) < until_ then wst.animUntil = until_ end
	local moves
	if push then moves = A.Push(page, under, opts) else moves = A.PopPage(page, under, opts) end
	if not moves then
		D.pageMoving = nil
		wst.animUntil = now()
	end
end

-- Shows a screen over the console ("console" goes back to it). Returns true when it shows.
function D.ShowScreen(name, arg)
	if not ui then return false end
	name = S(name) or "console"
	if name == "messages" and type(W.db) == "table" then W.db.msgSeen = true end -- the footer glow stops
	if name == "sheet" or name == "menu" then return D.ShowSheet(name, arg) end
	if name == "console" then
		local old = D.sub and ui.subs[D.sub]
		D.sub = nil
		-- (design 2, N) the back route: the page leaves to the right and the console comes back from the left
		if old then pageMove(old.frame, baseView(), false) end
		D.Refresh()
		D.SyncDock()
		-- (round 32, HUNT-110) the Advertise overlay lies over its pill again at once, not at the next tick
		if W.UI and type(W.UI.SyncSecure) == "function" then call(W.UI.SyncSecure) end
		pageChanged()
		return true
	end
	local maker = D.screens[name]
	if type(maker) ~= "function" then return false end
	local scr = ui.subs[name]
	if not scr then
		local ok, s = pcall(maker, ui.root)
		if not ok or type(s) ~= "table" or not s.frame then
			W.Error("drive screen " .. name, ok and "no frame" or s)
			return false
		end
		scr = s
		scr.frame:SetFrameLevel(ui.root:GetFrameLevel() + 20)
		ui.subs[name] = scr
	end
	-- (design 2, N) the page comes in from the right over what is there: the page before it, else the console
	A.StopPage(ui.parent)
	local under = D.sub and D.sub ~= name and ui.subs[D.sub] and ui.subs[D.sub].frame or nil
	if not (under and under:IsShown()) then under = baseView() end
	for n, s in pairs(ui.subs) do
		if n ~= name and s.frame ~= under and s.frame:IsShown() then s.frame:Hide() end
	end
	local was = D.sub
	D.sub = name
	if scr.enter then call(scr.enter, arg) end
	if scr.update then call(scr.update) end
	if was == name and scr.frame:IsShown() then scr.frame:Show() else pageMove(scr.frame, under, true) end
	D.SyncDock()
	-- (round 47, AUD-213) the Advertise overlay leaves its pill at once, not at the next tick (UI.SyncSecure does nothing in combat)
	if W.UI and type(W.UI.SyncSecure) == "function" then call(W.UI.SyncSecure) end
	pageChanged()
	return true
end

function D.CurrentScreen() return D.sub or "console" end

-- the bottom sheets (the price/place sheet "sheet", the row menu "menu"), UI_Drive.lua's
function D.ShowSheet(name, arg)
	if not ui then return false end
	local maker = D.screens[name]
	if type(maker) ~= "function" then return false end
	local sh = ui.sheets[name]
	if not sh then
		local ok, s = pcall(maker, ui.root)
		if not ok or type(s) ~= "table" or not s.frame then
			W.Error("drive sheet " .. name, ok and "no frame" or s)
			return false
		end
		sh = s
		ui.sheets[name] = sh
		-- (2.3) a sheet's page is nil (folded): closing it gives the page back
		local before = sh.frame.onClose
		sh.frame.onClose = function(self)
			if type(before) == "function" then pcall(before, self) end
			-- (round 47, AUD-213) the overlays dock back at once (UI.SyncSecure does nothing in combat)
			if W.UI and type(W.UI.SyncSecure) == "function" then call(W.UI.SyncSecure) end
			pageChanged()
		end
	end
	for n, s in pairs(ui.sheets) do
		if n ~= name and s.frame.open then s.frame:Close(true) end
	end
	if sh.enter then call(sh.enter, arg) end
	-- (round 9, C2) open, then draw: a sheet's share pill (UI.Share) only has a line while its
	-- sheet is open, so drawing first hid "Post to party" and stretched Nice under it until the
	-- next tick; then the secure overlays dock at once (no 1 s wait for the share button)
	sh.frame:Open()
	if sh.update then call(sh.update) end
	D.SyncDock() -- the button leaves its slot while the sheet is over it
	if W.UI and type(W.UI.SyncSecure) == "function" then call(W.UI.SyncSecure) end
	pageChanged()
	return true
end

-- (fix round j) true while Settings, a sheet or a page other than `name` (nil: the console and the raid page
-- on it) is open over that page: its list's "more below" cue and soft edges must not be drawn then, whatever
-- frame level the page above has.
function D.PageOver(name)
	if D.sub and D.sub ~= name then return true end
	if D.SheetOpen() then return true end
	local U = W.UI
	return U and type(U.SettingsShown) == "function" and U.SettingsShown() and true or false
end

function D.SheetOpen()
	if not ui then return false end
	for _, s in pairs(ui.sheets) do
		if s.frame.open then return true end
	end
	return false
end

-- The big button's slot while the console is really on screen, else nil.
function D.Slot()
	if not ui or not ui.console or not ui.console:IsVisible() then return nil end
	local U = W.UI
	local st = U and U.state
	if not st or not st.win or not st.win:IsShown() then return nil end
	if st.tab ~= "Drive" or st.settingsOpen or st.moving or st.closing or st.splashing then return nil end
	if D.sub or D.pageMoving then return nil end -- (design 2, N) nor while a page is on its way
	-- an open price / place sheet lies over the slot: the secure button must not sit above it
	if D.SheetOpen() then return nil end
	return ui.console.slot
end

-- The button's placing tells the slot at once whether its own words should show under it
-- (docked, the button's words are the ones on the card).
local function hookPlace()
	local B = DR.Button
	if type(B) ~= "table" or B.wuberSlotHook then return end
	local before = B.onPlace
	B.onPlace = function(docked, ...)
		if type(before) == "function" then pcall(before, docked, ...) end
		if ui and ui.console then W.Safe("drive slot", slotWords, ui.console, docked == true) end
	end
	B.wuberSlotHook = true
end

-- Docks the big button over the slot, or lets it float (out of combat only; a fight freezes it).
function D.SyncDock(force)
	hookPlace()
	if inCombat() then
		-- (#204) a fight freezes the button where it was docked: when its slot is gone (or moved) the paused look is
		-- taken off (alpha only), and put back when the slot is back where it was
		local B = DR.Button
		if type(B) == "table" and type(B.CombatView) == "function" then
			local slot = D.Slot()
			local back = false
			if slot then
				local l, b = N(Try(slot, "GetLeft")), N(Try(slot, "GetBottom"))
				local w, h = N(Try(slot, "GetWidth")), N(Try(slot, "GetHeight"))
				local s = N(Try(slot, "GetEffectiveScale"))
				back = l and b and w and h and s and ("%.1f:%.1f:%.1f:%.1f:%.3f"):format(l, b, w, h, s) == D.dockSig or false
			end
			call(B.CombatView, back)
		end
		return
	end
	-- (r54 C) a drag of the window changes nothing here: D.Slot answers nil while it moves, which used to let the
	-- big button float (and its mini console open) on every tick of the drag; the drop's UI.SyncSecure docks it again
	local st = W.UI and W.UI.state
	if st and st.moving then return end
	local B = DR.Button
	if type(B) ~= "table" or type(B.Dock) ~= "function" then return end
	local slot = D.Slot()
	local sig = "float"
	if slot then
		local l, b = N(Try(slot, "GetLeft")), N(Try(slot, "GetBottom"))
		local w, h = N(Try(slot, "GetWidth")), N(Try(slot, "GetHeight"))
		local s = N(Try(slot, "GetEffectiveScale"))
		if not (l and b and w and h and s) then
			slot, sig = nil, "float"
		else
			sig = ("%.1f:%.1f:%.1f:%.1f:%.3f"):format(l, b, w, h, s)
		end
	end
	if sig == D.dockSig and not force then return end
	D.dockSig = sig
	call(B.Dock, slot)
end

---------------------------------------------------------------------------
-- (2.3) The unfolded console: the left keeps the folded console (its slot and the
-- secure GO / ADVERT pills never move); r18: the riders are listed once, on the left right under the buttons,
-- and the side pane has the crew panel (one chip per member: role, name, shards, this shift's casts and
-- clicks), today's takings and the best hours (Earnings' heatmap). "Wanted nearby" is a card on the left
-- under the riders. Nothing secure is ever in the side pane.
---------------------------------------------------------------------------

-- the side pane's content: 324 wide at x 18 of the pane (the scroll is inset 8 each side, the
-- content 10 more), the rider's pages' 18 px padding
-- (round 9, S10) crew cards are the side pane's full width, one to a row
local SIDE_PAD, SIDE_W, CHIP_W = 10, 324, 324

-- a crew panel chip, 324 x 40: role glyph, name, shards (or "no Wuber"), casts and clicks
function D.SideChip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(CHIP_W, 40)
	b:RegisterForClicks("LeftButtonUp")
	b.bg = T.Rounded(b, "card", 12, "BACKGROUND", 0)
	b.glyph = T.Icon(b, "summon", 14, "glow", "ARTWORK")
	b.glyph:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -7)
	b.name = T.Text(b, "sub", "white", "LEFT", "bold")
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 30, -6)
	b.name:SetWidth(CHIP_W - 30 - 110)
	b.count = T.Text(b, "caption", "gold", "RIGHT", "bold")
	b.count:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -7)
	b.count:SetWidth(100)
	b.cut = T.Text(b, "caption", "muted", "LEFT", "regular")
	b.cut:SetPoint("TOPLEFT", b, "TOPLEFT", 30, -23)
	b.cut:SetWidth(CHIP_W - 40)
	b.star = T.Icon(b, "star", 10, "glow", "OVERLAY")
	b.star:SetPoint("CENTER", b.glyph, "BOTTOMRIGHT", 1, 1)
	safeScript(b, "OnEnter", function(self) self.bg:SetColor("hover") end)
	safeScript(b, "OnLeave", function(self) self.bg:SetColor("card") end)
	T.Press(b, { fill = b.bg })
	safeScript(b, "OnClick", function() D.ShowScreen("crew") end)
	T.Tip(b, function(self) return S(self.m and self.m.name) or "Crew" end, function(self)
		local m = self.m or {}
		local t = m.role == "lock" and "Summons and clicks." or "Clicks the portal."
		if m.role == "lock" and m.app == false then t = t .. " No Wuber: nobody sees their Soul Shards." end
		if self.turn then t = t .. " Casts the next summon." end
		if m.silent then t = t .. " Not heard from for a while." end
		return t .. "\nThis shift: " .. (self.cutWords or "no clicks yet") .. ".\nClick: your crew."
	end)
	return b
end

function D.PaintSideChip(b, m, turn)
	b.m, b.turn = m, turn ~= nil and m.key == turn
	b.glyph:SetTexture(T.MEDIA .. (m.role == "lock" and "summon" or "ride"))
	local silent = m.silent == true
	b.glyph:SetVertexColor(T.RGB(silent and "off" or (m.role == "lock" and "glow" or "white")))
	b.name:SetText(m.key == W.myKey and "You" or W.Short(S(m.name) or "?"))
	b.name:SetTextColor(T.RGB(silent and "off" or "white"))
	local words, colour = D.ChipCount(m) -- (round 9) the folded chips' words
	b.count:SetText(words)
	b.count:SetTextColor(T.RGB(colour))
	local casts, clicks
	if D.CutFor then casts, clicks = D.CutFor(m.key) end
	b.cutWords = D.CutWords and D.CutWords(casts, clicks) or nil
	b.cut:SetText(b.cutWords or "")
	setShown(b.star, b.turn)
end

-- lays chips one to a row (the pane's full width) from y; returns the y under them
function D.LaySideChips(pool, parent, list, y, turn)
	for i, m in ipairs(list) do
		local b = pool[i]
		if not b then
			b = D.SideChip(parent)
			pool[i] = b
		end
		D.PaintSideChip(b, m, turn)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDE_PAD, -(y + (i - 1) * 46))
		b:Show()
	end
	for i = #list + 1, #pool do pool[i]:Hide() end
	return y + #list * 46
end

local sides = {} -- page -> the side pane's parts (made by the page's build)

local function sidePane(holder)
	local p = { holder = holder, rows = {}, chips = {}, fchips = {} }
	-- (round 9, S10) every driver page's two panes: a thin line down the side pane's left edge, so
	-- the left pane (its footer included) is a bounded column
	p.divider = T.Line(holder, "line", 0.8)
	p.divider:SetWidth(1)
	p.divider:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -6)
	p.divider:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 6)
	p.scroll = T.Scroll(holder)
	p.scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 8, -6)
	p.scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -8, 6)
	p.w = SIDE_W -- what fits in it at x SIDE_PAD
	p.content = p.scroll.content
	return p
end
D.SidePane = sidePane

local function buildConsoleSide(holder)
	if sides.console then return end
	local p = sidePane(holder)
	local c = p.content
	p.crewHead = T.Text(c, "body", "white", "LEFT", "bold")
	p.crewHead:SetText("Crew")
	p.shards = T.Text(c, "caption", "muted", "LEFT", "medium")
	p.shards:SetPoint("LEFT", p.crewHead, "RIGHT", 8, 0)
	p.shards:SetWidth(220)
	-- (r18) today's takings: the Earnings page's own "Today" numbers (D.Today), one card
	p.today = T.Card(c, SIDE_W, 64, { colour = "card", radius = 18, shadow = false })
	p.today.head = T.Text(p.today, "sub", "muted", "LEFT", "medium")
	p.today.head:SetPoint("TOPLEFT", p.today, "TOPLEFT", 14, -12)
	p.today.head:SetWidth(SIDE_W - 28)
	p.today.head:SetText("Today's takings")
	p.today.gold = T.Text(p.today, "title", "gold", "LEFT", "bold")
	p.today.gold:SetPoint("TOPLEFT", p.today, "TOPLEFT", 14, -30)
	p.today.gold:SetWidth(SIDE_W - 28)
	p.today:EnableMouse(true)
	T.Tip(p.today, "Today's takings", "What this character was paid since midnight. Earnings has the rest.")
	-- (r46, FEAT-01) the average summon: one grey line under the gold figure (shown from the third counted ride), its own tip
	p.today.avgHit = CreateFrame("Frame", nil, p.today)
	p.today.avgHit:SetSize(SIDE_W - 28, 16)
	p.today.avgHit:SetPoint("TOPLEFT", p.today, "TOPLEFT", 14, -56)
	p.today.avgHit:EnableMouse(true)
	p.today.avg = T.Text(p.today.avgHit, "caption", "muted", "LEFT", "medium")
	p.today.avg:SetPoint("LEFT", p.today.avgHit, "LEFT", 0, 0)
	p.today.avg:SetWidth(SIDE_W - 28)
	p.today.avgHit:Hide()
	-- (2.4, p2) the careful record: one grey line under the summons line, hidden while DR.AutoRecordText() is nil
	p.today.recordHit = CreateFrame("Frame", nil, p.today)
	p.today.recordHit:SetSize(SIDE_W - 28, 16)
	p.today.recordHit:SetPoint("TOPLEFT", p.today, "TOPLEFT", 14, -56)
	p.today.recordHit:EnableMouse(true)
	T.Tip(p.today.recordHit, "Auto-invites", "Invites Wuber sent by itself after a clear request, and how many of them you marked as wrong.")
	p.today.record = T.Text(p.today.recordHit, "caption", "muted", "LEFT", "medium")
	p.today.record:SetPoint("LEFT", p.today.recordHit, "LEFT", 0, 0)
	p.today.record:SetWidth(SIDE_W - 28)
	p.today.recordHit:Hide()
	-- (2.4) the driver's own rank: title, verified summons and progress to the next title
	p.rank = T.Card(c, SIDE_W, 54, { colour = "card", radius = 18, shadow = false })
	p.rank.text = T.Text(p.rank, "sub", "white", "LEFT", "medium")
	p.rank.text:SetPoint("TOPLEFT", p.rank, "TOPLEFT", 14, -12)
	p.rank.text:SetWidth(SIDE_W - 28)
	p.rank.bar = T.Bar(p.rank, SIDE_W - 28, 6, "accent")
	p.rank.bar:SetPoint("TOPLEFT", p.rank.text, "BOTTOMLEFT", 0, -8)
	p.rank:EnableMouse(true)
	T.Tip(p.rank, "Your title", function(self)
		local body = "Verified summons count once a rider who asked through Wuber arrives by your summon: once per rider a day, never your crew."
		if self.nextAt then return body .. " The next title comes at " .. self.nextAt .. "." end
		return body
	end)
	p.rank:Hide()
	-- the best hours: the Earnings heatmap (D.BuildHeatmap, made on first use: Earnings loads later) and its top window
	p.top = T.Text(c, "caption", "muted", "LEFT", "medium")
	p.top:SetWidth(SIDE_W - 8)
	sides.console = p
end

-- the side pane while the console is unfolded (drawn with the console, once a second or sooner):
-- (r18) the crew, today's takings and the best hours; the riders are on the left, once
function D.DrawConsoleSide(v)
	local p = sides.console
	if not p then return end
	local c = p.content
	local y = 4
	local helper = D.Role() == "helper"
	-- (round 13, I9; r18) what riders want: a card at the top of the side pane, once there is demand
	-- (D.DemandCard, UI.Driver.Demand's, made on first use)
	local DemandMod = W.Mod("UI.Driver.Demand")
	local want = type(DemandMod) == "table" and type(DemandMod.List) == "function" and DemandMod.List() or {}
	if #want > 0 and type(D.DemandCard) == "function" then
		if not p.wanted then
			p.wanted = D.DemandCard(c, SIDE_W)
			v.wanted = p.wanted
		end
		local h = p.wanted:Update()
		if h > 0 then
			p.wanted:ClearAllPoints()
			p.wanted:SetPoint("TOPLEFT", c, "TOPLEFT", SIDE_PAD, -y)
			p.wanted:Show()
			y = y + h + 10
		end
	elseif p.wanted then
		p.wanted:Hide()
	end
	-- the crew panel: me first, then everyone here (alone: my own chip, my shards and casts)
	local crew = {}
	for _, m in ipairs(StateMod.Crew()) do
		if type(m) == "table" and m.here ~= false and not m.me and m.key ~= W.myKey then crew[#crew + 1] = m end
	end
	local show = not helper or #crew > 0
	setShown(p.crewHead, show)
	setShown(p.shards, show)
	if show then
		table.insert(crew, 1, { name = W.Me and W.Me() or "Me", key = W.myKey, role = StateMod.IsWarlock() and "lock" or "helper",
			shards = StateMod.dr("Shards"), app = true })
		p.crewHead:ClearAllPoints()
		p.crewHead:SetPoint("TOPLEFT", c, "TOPLEFT", SIDE_PAD + 4, -y)
		-- (round 13, I10) the team's total: the chips' own counts added up (UI.Driver.State)
		local total = D.CrewShards and D.CrewShards(crew) or nil
		p.shards:SetText(total and ("· " .. StateMod.plural(total, "shard")) or "")
		y = y + 24
		local _, turn = StateMod.dr("MayCast")
		y = D.LaySideChips(p.chips, c, crew, y, turn) + 10
	else
		for _, b in ipairs(p.chips) do b:Hide() end
	end
	-- today's takings and the best hours: a driver's (a helper is not paid)
	setShown(p.today, not helper)
	if p.rank and helper then p.rank:Hide() end
	if p.heat then setShown(p.heat, not helper) end
	setShown(p.top, not helper)
	if not helper then
		local rides, copper = D.Today()
		local c0 = math.max(0, math.floor((N(copper) or 0) + 0.5))
		p.today.gold:SetText(c0 > 0 and W.Money(c0) or "0g") -- in letters, gold; nothing taken is "0g", never "free"
		p.today.head:SetText("Today's takings · " .. StateMod.plural(N(rides) or 0, "ride"))
		-- (r46, FEAT-01) "Your summons: about 45 sec": DR.SummonAvg, worded as the Fly or summon card words a summon
		-- (seconds under a minute, else UI.Duration); nothing before the third counted ride, and the card keeps 64
		local total, cast, n = nil, nil, nil
		if type(DR.SummonAvg) == "function" then total, cast, n = DR.SummonAvg() end
		total, cast, n = N(total), N(cast), N(n)
		local cardH = 64
		if total and cast and n then
			local function words(sec)
				return "about " .. (sec < 60 and (math.floor(sec + 0.5) .. " sec") or W.UI.Duration(sec))
			end
			p.today.avg:SetText("Your summons: " .. words(total))
			T.Tip(p.today.avgHit, "Your summons", "Request to arrival, averaged over your last " .. math.floor(n)
				.. " counted summons. Counted: no queue, arrived, paid by trade. Cast to arrival: "
				.. words(cast) .. ".")
			p.today.avgHit:Show()
			cardH = 80
		else
			p.today.avgHit:Hide()
		end
		local rec = type(DR.AutoRecordText) == "function" and S(DR.AutoRecordText()) or nil
		if rec then
			local lineW = SIDE_W - 28
			local lines = 1
			if type(T.MeasureText) == "function" then
				local tw = N(T.MeasureText(rec, "caption", "medium")) or 0
				if tw > lineW then lines = math.ceil(tw / lineW) end
			end
			local rh = math.max(16, lines * 14 + 2)
			p.today.recordHit:SetHeight(rh)
			p.today.recordHit:ClearAllPoints()
			p.today.recordHit:SetPoint("TOPLEFT", p.today, "TOPLEFT", 14, -(cardH - 8))
			p.today.record:SetText(rec)
			p.today.recordHit:Show()
			cardH = cardH + rh
		else
			p.today.recordHit:Hide()
		end
		p.today:SetHeight(cardH)
		p.today:ClearAllPoints()
		p.today:SetPoint("TOPLEFT", c, "TOPLEFT", SIDE_PAD, -y)
		y = y + cardH + 10
		local info = type(DR.RankInfo) == "function" and DR.RankInfo() or nil
		if p.rank and type(info) == "table" and info.title then
			local n = math.max(0, math.floor(N(info.n) or 0))
			local countWords = n == 1 and "1 summon" or (n .. " summons")
			local nxt = info.rung and type(W.RANKS) == "table" and W.RANKS[info.rung + 1] or nil
			local line = info.title .. " · " .. countWords
			if nxt and info.nextAt then
				line = line .. " · " .. (N(info.toNext) or 0) .. " to " .. nxt.title
			end
			local lineW = SIDE_W - 28
			local lines = 1
			if type(T.MeasureText) == "function" then
				local tw = N(T.MeasureText(line, "sub", "medium")) or 0
				if tw > lineW then lines = math.ceil(tw / lineW) end
			end
			local textH = math.max(16, lines * 15)
			local rankH = 12 + textH + 8 + 6 + 12
			p.rank.text:SetText(line)
			local curAt = info.rung and type(W.RANKS) == "table" and W.RANKS[info.rung] and N(W.RANKS[info.rung].at) or 0
			local nextAt = N(info.nextAt)
			local frac = (nextAt and nextAt > curAt) and ((n - curAt) / (nextAt - curAt)) or 1
			p.rank.bar:SetValue(frac)
			p.rank.nextAt = nextAt
			p.rank:SetHeight(rankH)
			p.rank:ClearAllPoints()
			p.rank:SetPoint("TOPLEFT", c, "TOPLEFT", SIDE_PAD, -y)
			p.rank:Show()
			y = y + rankH + 10
		elseif p.rank then
			p.rank:Hide()
		end
		if not p.heat and type(D.BuildHeatmap) == "function" then
			p.heat = D.BuildHeatmap(c, SIDE_W)
		end
		if p.heat and type(D.PaintHeatmap) == "function" then
			D.PaintHeatmap(p.heat, 7, "me")
			p.heat:ClearAllPoints()
			p.heat:SetPoint("TOPLEFT", c, "TOPLEFT", SIDE_PAD, -y)
			y = y + (N(p.heat:GetHeight()) or 196) + 8
			local hours = StateMod.dr("Hours", 7, "me")
			local th = type(D.TopWindow) == "function" and D.TopWindow(hours) or nil
			p.top:SetText(th and ("Top window: %02d:00–%02d:00"):format(th, (th + 3) % 24) or "Open a few hours to find your best ones")
			p.top:ClearAllPoints()
			p.top:SetPoint("TOPLEFT", c, "TOPLEFT", SIDE_PAD + 4, -y)
			y = y + 20
		end
	end
	p.scroll:SetContentHeight(y + 6)
end

-- a page's layout: remember the state and redraw now (makes nothing after its build)
local function wideLayout(page)
	return function(unfolded)
		D.wide[page] = unfolded == true
		if ui then
			ui.dirty = true
			W.Safe("drive refresh", refreshNow)
		end
	end
end
D.WideLayout = wideLayout

D.FOLD.console = { build = buildConsoleSide, layout = wideLayout("console") }

-- the pages register with UI.Fold once, at login (or when the Drive tab is first built)
local function registerFold()
	local F = W.UI and W.UI.Fold
	if D.foldRegistered or type(F) ~= "table" or type(F.Register) ~= "function" then return end
	D.foldRegistered = true
	-- (design 2, C) the window's buttons are over the side pane's top right while it is wide: each driver page's
	-- side content is built in a frame that starts under them (UI.HEAD_ROW), down to the pane's bottom
	local head = N(W.UI.HEAD_ROW) or 44
	local function under(spec)
		local inner = {}
		return {
			build = function(holder)
				local f = CreateFrame("Frame", nil, holder)
				f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -head)
				f:SetSize(N(holder:GetWidth()) or 360, (N(holder:GetHeight()) or 544) - head)
				inner[holder] = f
				if spec.build then spec.build(f) end
			end,
			layout = function(unfolded, holder)
				if spec.layout then spec.layout(unfolded, inner[holder] or holder) end
			end,
		}
	end
	for _, page in ipairs({ "console", "raid", "earnings", "messages", "customers" }) do
		local spec = D.FOLD[page]
		if type(spec) == "table" then call(F.Register, page, under(spec)) end
	end
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

refreshNow = function()
	if not ui or not ui.root:IsVisible() then return end
	ui.dirty = false
	ui.at = now()
	local mode = D.Mode()
	ui.mode = mode
	if not D.pageMoving then
		local sub = D.sub and ui.subs[D.sub]
		local baseShown = not (sub and sub.frame and sub.frame:IsShown())
		setShown(ui.console, baseShown and mode == "console")
		setShown(ui.welcome, baseShown and mode == "welcome")
		setShown(ui.provider, baseShown and mode == "provider")
	end
	if mode == "welcome" then paintWelcome(ui.welcome) end
	if mode == "console" then
		drawConsole(ui.console)
	elseif mode == "provider" then
		drawProvider(ui.provider)
	end
	if D.sub then
		local scr = ui.subs[D.sub]
		if scr and scr.update then call(scr.update) end
	end
	for _, sh in pairs(ui.sheets) do
		if sh.frame.open and sh.update then call(sh.update) end
	end
	D.SyncDock()
end

-- Something changed: redraws within a quarter of a second (now when `soon`).
function D.Refresh(soon)
	if not ui then return end
	ui.dirty = true
	if soon then ui.at = 0 end
end

function D.RefreshNow() W.Safe("drive refresh", refreshNow) end

local function onUpdate()
	if not ui then return end
	local t = now()
	if (ui.dirty and t - (ui.at or 0) >= 0.25) or t - (ui.at or 0) >= 1 then
		W.Safe("drive refresh", refreshNow)
	end
end

function D.Build(parent)
	if ui and ui.parent == parent then return ui.root end
	local root = CreateFrame("Frame", nil, parent)
	root:SetAllPoints(parent)
	ui = { parent = parent, root = root, subs = {}, sheets = {}, dirty = true, at = 0 }
	D.ui = ui
	ui.console = buildConsole(root)
	ui.welcome = buildWelcome(root)
	ui.provider = buildProvider(root)
	-- compat names for older tests and tools
	ui.drive, ui.go = ui.console, ui.console.open
	safeScript(root, "OnShow", function()
		ui.dirty = true
		refreshNow()
	end)
	safeScript(root, "OnHide", function()
		for _, sh in pairs(ui.sheets) do if sh.frame.open then sh.frame:Close(true) end end
		D.SyncDock()
	end)
	safeScript(root, "OnUpdate", onUpdate)
	W.Safe("drive fold", registerFold)
	W.Safe("drive build", refreshNow)
	return root
end

---------------------------------------------------------------------------
-- The tab, and a window of its own (only if the Wuber window offers no tabs)
---------------------------------------------------------------------------

local tabbed = false

local function AddTab()
	if tabbed then return true end
	if not (W.UI and type(W.UI.AddTab) == "function") then return false end
	local ok = W.Safe("drive tab", W.UI.AddTab, "Drive", function(parent)
		local okb, root = W.Safe("drive build", D.Build, parent)
		return okb and root or nil
	end)
	tabbed = ok and true or false
	return tabbed
end

function D.Toggle()
	if tabbed and W.UI and type(W.UI.Show) == "function" then
		W.UI.Show("drive")
		return
	end
	local f = D.window
	if not f then
		f = CreateFrame("Frame", "WuberDriveFrame", UIParent)
		f:SetSize(360, 600)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetClampedToScreen(true)
		f:SetScript("OnDragStart", function(self) self:StartMoving() end)
		f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
		f.bg = T.Rounded(f, "black", 16, "BACKGROUND", 0)
		local close = T.RoundButton(f, "close", 28, "card")
		close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
		close:SetScript("OnClick", function() f:Hide() end)
		T.Tip(close, "Close", "Hide the driver window.")
		local title = T.Text(f, "heading", "white", "LEFT", "bold")
		title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
		title:SetText("Wuber Drive")
		local body = CreateFrame("Frame", nil, f)
		body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -56)
		body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
		D.Build(body)
		if type(UISpecialFrames) == "table" and not W.GamepadUI() then table.insert(UISpecialFrames, "WuberDriveFrame") end -- (PST-01 B)
		f:Hide()
		D.window = f
	end
	if f:IsShown() then f:Hide() else f:Show() end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

AddTab()

-- (2.3: BOUNTY, DRIVE_CUT, DRIVE_DANGER and RAINCHECK need no listener here: the console and its
-- open screen redraw once a second anyway, and the behaviour transcript keeps its wiring)
for _, ev in ipairs({ "DRIVE", "DRIVE_CREW", "DRIVE_LOG", "DRIVE_PAID", "DRIVE_RANK", "SETTINGS", "PROVIDER", "COMMUNITY", "ADVERT", "REQUESTS" }) do
	W.Listen(ev, function() D.Refresh() end)
end
W.On("GROUP_ROSTER_UPDATE", function() D.Refresh() end)
W.On("PLAYER_REGEN_DISABLED", function() D.Refresh(true) end)
W.On("PLAYER_REGEN_ENABLED", function()
	D.Refresh(true)
	W.After(0.2, function() D.SyncDock(true) end)
end)

W.OnLogin(function()
	AddTab()
	W.Safe("drive fold", registerFold)
	-- the dock follows the window even when the tab isn't redrawn (moved, opened, closed)
	W.Every(1, function() D.SyncDock() end)
end)
