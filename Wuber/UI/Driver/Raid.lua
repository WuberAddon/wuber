-- Module: UI.Driver.Raid
-- Purpose: Raid-summon console parts: summoners, not-here rows, raid queue drawing (folded: a
--   "+N more below" / "Not here (N) below" cue at the list's edge).
-- API: D.RaidSummoners, D.ClassColour, D.DrawRaidSide, D.FOLD.raid
-- Internals: drawRaid, hideRaid, drawRaidWide, raidQueue, notHere, buildRaidSide, cueParts, updateCue
-- Uses: UI.Driver.State, UI.Driver.Draw
-- Later: (none)
-- Events: (none)
-- Standalone: no
-- Test: tests/ui/driver/raid_test.lua
-- From: Driver.lua 1980-2265 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Raid", { "UI.Driver.State", "UI.Driver.Draw" })
local StateMod = W.Mod("UI.Driver.State")
local DrawMod = W.Mod("UI.Driver.Draw")
local Crew, IsOpen, List, MAX_ROWS = StateMod.Crew, StateMod.IsOpen, StateMod.List, StateMod.MAX_ROWS
local N, PAD, QROW_GAP, QROW_H = StateMod.N, StateMod.PAD, StateMod.QROW_GAP, StateMod.QROW_H
local S, SLOT_W, call, dr = StateMod.S, StateMod.SLOT_W, StateMod.call, StateMod.dr
local plural, safeScript, setShown, short = StateMod.plural, StateMod.safeScript, StateMod.setShown, StateMod.short
local toast = StateMod.toast
local layChips = DrawMod.layChips
local T = W.Theme
local Try = T.Try

local DR = W.Drive

local D = W.Driver

---------------------------------------------------------------------------
-- Raid summons: summoners, the raiders' queue, "Not here (N)", summoned tonight
---------------------------------------------------------------------------

-- "dan rider" -> "Dan Rider"
local function nameOf(key)
	local n = S(dr("WhoIs", key))
	if n then return n end
	return ((S(key) or "?"):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

-- the chosen summoners, in cast order, with what is known of each (shards, Wuber or not)
function D.RaidSummoners()
	local info = {}
	for _, x in ipairs(List("RaidWarlocks")) do
		if type(x) == "table" and S(x.key) then info[x.key] = x end
	end
	for _, m in ipairs(Crew()) do
		if type(m) == "table" and S(m.key) and not info[m.key] then info[m.key] = m end
	end
	local out = {}
	for _, k in ipairs(List("Summoners")) do
		k = S(k)
		if k then
			local x = info[k] or {}
			local mine = k == W.myKey
			out[#out + 1] = { key = k, name = S(x.name) or (mine and W.Me and W.Me()) or nameOf(k), role = "lock", raid = true,
				shards = mine and dr("Shards") or x.shards, app = mine or x.app ~= false, silent = x.silent }
		end
	end
	return out
end

-- a raid member from DR.NotHere(): a name, or { name, class, zone }
local function notHereView(e)
	if type(e) == "string" then return { name = e } end
	if type(e) == "table" and S(e.name) then return { name = S(e.name), class = S(e.class), zone = S(e.zone) or S(e.place) } end
	return nil
end

local function classColour(class)
	local cc = type(RAID_CLASS_COLORS) == "table" and class and RAID_CLASS_COLORS[class]
	if type(cc) == "table" and N(cc.r) then return { cc.r, cc.g, cc.b, 1 } end
	return "white"
end
D.ClassColour = classColour

-- (AUD-173) the + is dimmed until the driver has pressed Start; its tooltip stays.
local function dimAdd(r)
	r.add:SetAlpha(call(DR.RaidOn) and 1 or 0.4)
end

local function notHereRow(parent, w)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(w or SLOT_W, 32)
	r.bg = T.Rounded(r, "card", 10, "BACKGROUND", 0)
	r.name = T.Text(r, "sub", "white", "LEFT", "bold")
	r.name:SetPoint("LEFT", r, "LEFT", 12, 0)
	r.name:SetWidth(150)
	r.zone = T.Text(r, "caption", "muted", "RIGHT", "regular")
	r.zone:SetPoint("RIGHT", r, "RIGHT", -44, 0)
	r.zone:SetWidth(140)
	r.add = CreateFrame("Button", nil, r)
	r.add:SetSize(26, 26)
	r.add:SetPoint("RIGHT", r, "RIGHT", -6, 0)
	r.add:RegisterForClicks("LeftButtonUp")
	r.add.bg = T.Circle(r.add, 24, "accent", "BACKGROUND")
	r.add.bg:SetPoint("CENTER", r.add, "CENTER")
	r.add.plus = T.Text(r.add, "heading", "ink", "CENTER", "bold")
	r.add.plus:SetPoint("CENTER", r.add, "CENTER", 0, 1)
	r.add.plus:SetText("+")
	safeScript(r.add, "OnEnter", function(self) self.bg:SetVertexColor(T.RGB("glow")) end)
	safeScript(r.add, "OnLeave", function(self) self.bg:SetVertexColor(T.RGB("accent")) end)
	T.Press(r.add, { fill = r.add.bg })
	safeScript(r.add, "OnClick", function()
		local name = r.who
		if not name then return end
		if not call(DR.RaidOn) then return end -- (AUD-173) dimmed until Start: nobody is queued, so no toast says so
		local okAdd, why = call(DR.RaidAdd, name)
		if okAdd == false then
			toast(S(why) or ("Couldn't add " .. short(name)), "warn")
		else
			toast(short(name) .. " is in the queue", "info")
		end
		D.Refresh(true)
	end)
	T.Tip(r.add, function() return "Queue " .. short(r.who) end,
		"Adds them to the summon queue by hand. Only for someone who asked (in voice, say): nobody is queued who didn't ask.")
	r:EnableMouse(true)
	T.Tip(r, function() return S(r.who) or "Raid member" end, function()
		return "In your raid but not where your summoners stand" .. (r.where and (" (in " .. r.where .. ")") or "") .. ". Tap + to queue them."
	end)
	return r
end

local function raidPart(v)
	if v.raid then return v.raid end
	local c = v.scroll.content
	local R = { chips = {}, nh = {} }
	R.sumHead = T.Text(c, "body", "white", "LEFT", "bold")
	R.sumHead:SetText("Summoners")
	R.edit = T.Pill(c, "Change", "dark", 84, 24)
	R.edit.fill:SetColor("raised")
	R.edit:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(R.edit, "OnClick", function() D.ShowSheet("raidpick") end)
	T.Tip(R.edit, "Change summoners", "Tick the Warlocks in your raid who summon, and set who casts first.")
	R.none = T.Text(c, "caption", "red", "LEFT", "medium")
	R.none:SetWidth(SLOT_W - 8)
	R.none:SetText("Nobody summons yet: tap Warlocks to pick who summons")
	T.Lines(R.none, 2) -- (design 3, P) wraps onto a second line when Inter's size needs it; the page below follows
	R.qHead = T.Text(c, "body", "white", "LEFT", "bold")
	R.qHead:SetText("Raiders")
	R.qCount = T.Text(c, "caption", "muted", "LEFT", "regular")
	R.qCount:SetPoint("LEFT", R.qHead, "RIGHT", 8, 0)
	R.qCount:SetWidth(200)
	R.empty = CreateFrame("Frame", nil, c)
	R.empty:SetSize(SLOT_W, 56)
	R.empty.bg = T.Rounded(R.empty, "card", 14, "BACKGROUND", 0)
	R.empty.icon = T.Icon(R.empty, "summon", 22, "glow", "OVERLAY")
	R.empty.icon:SetPoint("LEFT", R.empty, "LEFT", 18, 0)
	R.empty.text = T.Text(R.empty, "body", "white", "LEFT", "medium")
	R.empty.text:SetPoint("TOPLEFT", R.empty, "TOPLEFT", 54, -11)
	R.empty.text:SetPoint("RIGHT", R.empty, "RIGHT", -12, 0)
	R.empty.sub = T.Text(R.empty, "caption", "muted", "LEFT", "regular")
	R.empty.sub:SetPoint("TOPLEFT", R.empty.text, "BOTTOMLEFT", 0, -3)
	R.empty.sub:SetPoint("RIGHT", R.empty, "RIGHT", -12, 0)
	T.Lines(R.empty.sub, 2)
	-- "Not here (N)": tap to open the list
	R.nhHead = CreateFrame("Button", nil, c)
	R.nhHead:SetSize(SLOT_W, 28)
	R.nhHead:RegisterForClicks("LeftButtonUp")
	R.nhHead.fill = T.PillFill(R.nhHead, "card", 28, "BACKGROUND", 0)
	R.nhHead.chev = T.Icon(R.nhHead, "back", 10, "muted", "OVERLAY")
	R.nhHead.chev:SetPoint("LEFT", R.nhHead, "LEFT", 12, 0)
	R.nhHead.label = T.Text(R.nhHead, "sub", "white", "LEFT", "bold")
	R.nhHead.label:SetPoint("LEFT", R.nhHead, "LEFT", 30, 0)
	R.nhHead.label:SetWidth(SLOT_W - 40)
	safeScript(R.nhHead, "OnEnter", function(self) self.fill:SetColor("hover") end)
	safeScript(R.nhHead, "OnLeave", function(self) self.fill:SetColor("card") end)
	T.Press(R.nhHead, { fill = R.nhHead.fill })
	safeScript(R.nhHead, "OnClick", function()
		R.open = not R.open
		D.Refresh(true)
	end)
	T.Tip(R.nhHead, "Not here", "Raid members who aren't where your summoners stand. Open the list to queue someone by hand (only if they asked).")
	R.nhMore = T.Text(c, "caption", "muted", "CENTER", "medium")
	R.nhMore:SetWidth(SLOT_W)
	R.tonight = T.Text(c, "caption", "muted", "CENTER", "medium")
	R.tonight:SetWidth(SLOT_W)
	v.raid = R
	return R
end

local RAID_NH_MAX = 12

-- (round 17, S6) folded: a cue at the list's bottom edge while raiders, or "Not here", are below it
-- ("+2 more below", "Not here (3) below"); a tap scrolls to them. ROOM: what the cue leaves free
-- under the row it brings into view.
local CUE = { W = 230, H = 24, ROOM = 40, EVERY = 0.2, GAP = 34 } -- GAP: the pill's own strip (its height, its lift, a margin)

-- (round 19) a row faded out under the cue takes no clicks and shows no tooltip
local function rowMouse(row, on)
	if not row or not row.EnableMouse then return end
	row:EnableMouse(on)
	for _, k in ipairs({ "more", "getapp" }) do
		local ch = row[k]
		if ch and ch.EnableMouse then ch:EnableMouse(on) end
	end
end

local function updateCue(v, R)
	local b, items = R.cue, R.cueItems
	if not b then return end
	if not items or not R.cueHolder:IsShown() then
		b:Hide()
		if R.nhHead and R.nhHead.SetAlpha then
			R.nhHead:SetAlpha(1)
			if R.nhHead.EnableMouse then R.nhHead:EnableMouse(true) end
		end
		for i = 1, math.max(MAX_ROWS, #v.rows) do
			local row = v.rows[i]
			if row and row.SetAlpha then row:SetAlpha(1) end
			rowMouse(row, true)
		end
		return
	end
	local viewH = N(Try(v.scroll, "GetHeight")) or 0
	local edge = (N(v.scroll.offset) or 0) + viewH + 1
	-- a row the pill would touch is not drawn (alpha 0) and counted as below, so the pill
	-- never sits on a row, sliced or whole
	-- (HUNT-145) the "Not here" header counts like a row: one under the pill's strip is below, not half hidden
	local cueMode = items.nh and items.nh > edge - CUE.GAP
	for _, bottom in ipairs(items.rows) do
		if bottom > edge then cueMode = true end
	end
	-- (prep-242 r3 C) the "Nobody waiting" / "stopped" card is words, not a row that can fade: while its lines reach
	-- into the pill's strip, no pill (it would sit on the card's second line); the page still scrolls by wheel or drag
	if items.card and items.card > edge - CUE.GAP then cueMode = false end
	local reserve = cueMode and CUE.GAP or 0
	local below, first = 0, nil
	for i, bottom in ipairs(items.rows) do
		local hide = bottom > edge - reserve
		if hide then
			below = below + 1
			first = first or bottom
		end
		local row = v.rows[i]
		if row and row.SetAlpha then
			local gone = hide and cueMode
			row:SetAlpha(gone and 0 or 1)
			rowMouse(row, not gone)
		end
	end
	-- (HUNT-145) the header under the pill's strip is not drawn (and takes no click) while the pill is up
	local nhGone = cueMode and items.nh and items.nh > edge - reserve and true or false
	if R.nhHead and R.nhHead.SetAlpha then
		R.nhHead:SetAlpha(nhGone and 0 or 1)
		if R.nhHead.EnableMouse then R.nhHead:EnableMouse(not nhGone) end
	end
	local text, to
	if items.card and items.card > edge - CUE.GAP then
		-- no pill over the card (see above)
	elseif below > 0 then
		text, to = "+" .. below .. " more below", first
		if items.nh then text = text .. " · " .. items.nhText end
	elseif items.nh and items.nh > edge - reserve then
		text, to = items.nhText .. " below", items.nh
	end
	if not text or viewH <= 0 or D.PageOver(nil) then
		b:Hide()
		return
	end
	b.to = to - viewH + CUE.ROOM
	if b.text ~= text then
		b.text = text
		b:SetLabel(text)
	end
	-- (HUNT-115) above the rows but under Settings and the sheets (the window's level + 40) that cover this page
	Try(R.cueHolder, "SetFrameLevel", (N(Try(v.scroll, "GetFrameLevel")) or 1) + 25)
	Try(b, "SetFrameLevel", (N(Try(R.cueHolder, "GetFrameLevel")) or 26) + 1)
	b:Show()
end

local function cueParts(v, R)
	if R.cue then return end
	local holder = CreateFrame("Frame", nil, v.scroll)
	holder:SetAllPoints(v.scroll)
	local b = T.Pill(holder, "", "dark", CUE.W, CUE.H)
	b:SetPoint("BOTTOM", holder, "BOTTOM", 0, 6)
	b.fill:SetColor("raised")
	b:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	b:Hide()
	safeScript(b, "OnClick", function(self)
		if self.to then v.scroll:ScrollTo(self.to) end
	end)
	Try(b, "EnableMouseWheel", true)
	safeScript(b, "OnMouseWheel", function(_, delta)
		v.scroll:ScrollTo((N(v.scroll.target) or 0) - (N(delta) or 0) * 60)
	end)
	T.Tip(b, "More below", "The raid page goes on below. Tap to scroll down, or use the mouse wheel.")
	holder.wait = 0
	holder:SetScript("OnUpdate", function(self, elapsed)
		self.wait = self.wait - (N(elapsed) or 0)
		if self.wait > 0 then return end
		self.wait = CUE.EVERY
		pcall(updateCue, v, R)
	end)
	R.cueHolder, R.cue = holder, b
end

-- the raiders who asked
local function raidQueue()
	local q = {}
	for _, row in ipairs(List("RaidQueue")) do
		if type(row) == "table" and S(row.name) then q[#q + 1] = row end
	end
	return q
end

-- "Not here (N)": raid members away from the summoners (only the runner may queue them)
local function notHere()
	local nh = {}
	for _, e in ipairs(List("NotHere")) do
		local x = notHereView(e)
		if x then nh[#nh + 1] = x end
	end
	return nh
end

-- (unfolded) the left keeps the slot, Start/Stop, Pause and Summoners; (round 9, S10)
-- the raiders are listed once, in the side pane, with "Not here" and the summoners ("Summoned
-- tonight" is the status line's number)
local function drawRaidWide(v, y, t, R)
	for _, f in ipairs({ R.sumHead, R.edit, R.none, R.nhHead, R.nhMore, R.qHead, R.qCount, R.empty, R.tonight }) do f:Hide() end
	for _, b in ipairs(R.chips) do b:Hide() end
	for _, r in ipairs(R.nh) do r:Hide() end
	if R.cueHolder then R.cueHolder:Hide() end
	for i = 1, math.max(MAX_ROWS, #v.rows) do
		local r = v.rows[i]
		if r then
			r:SetAlpha(1)
			rowMouse(r, true)
			r:Hide()
			r.c = nil
		end
	end
	v.more:Hide()
	if D.DrawRaidSide then call(D.DrawRaidSide, v, t) end
	return y
end

-- (round 9, S7) "Not here" with nobody listed: everyone is here only when there is a raid
local function nobodyAway()
	-- a raid console that is open, or has raiders waiting, is a raid (a demo has no real group)
	if dr("InRaid") == false and not IsOpen() and #raidQueue() == 0 then return "Join a raid to see who isn't here" end
	if dr("InRaid") == false then return "Nobody to wait for" end
	return "Everyone in your raid is here"
end

local function drawRaid(v, y, t)
	local c = v.scroll.content
	local R = raidPart(v)
	if D.Wide("raid") then return drawRaidWide(v, y, t, R) end
	local runner = D.Role() == "driver"
	-- the summoner strip
	R.sumHead:ClearAllPoints()
	R.sumHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	R.sumHead:Show()
	R.edit:Hide() -- (round 9, S10) one picker: the Summoners pill beside Start
	R.edit:ClearAllPoints()
	R.edit:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -(y - 3))
	y = y + 26
	local sums = D.RaidSummoners()
	local _, turn = dr("MayCast")
	if turn == nil and sums[1] then turn = sums[1].key end
	if #sums == 0 and D.Role() == "driver" and v.ready and v.ready:IsShown() then
		-- (round 9) the checklist above already says "Pick who summons": no strip saying it again
		for _, b in ipairs(R.chips) do b:Hide() end
		R.none:Hide()
		R.sumHead:Hide()
		y = y - 26
	elseif #sums == 0 then
		for _, b in ipairs(R.chips) do b:Hide() end
		R.none:ClearAllPoints()
		R.none:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		R.none:Show()
		y = y + 24 + (R.none.wuberWrapped and T.Spacing("caption") or 0)
	else
		R.none:Hide()
		y = layChips(R.chips, c, sums, y, turn)
	end
	y = y + 6
	-- the raiders who asked
	local q = raidQueue()
	R.qHead:ClearAllPoints()
	R.qHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	R.qHead:Show()
	R.qCount:Show()
	R.qCount:SetText(#q == 0 and "" or (plural(#q, "waiting", "waiting")))
	y = y + 24
	local n = math.min(#q, MAX_ROWS)
	local cueRows = {}
	for i = 1, math.max(MAX_ROWS, #v.rows) do
		local r = v.rows[i]
		if i <= n then
			D.PaintRaidRow(r, q[i], t)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			cueRows[#cueRows + 1] = y + QROW_H
			y = y + QROW_H + QROW_GAP
		else
			r:Hide()
			r.c = nil
		end
	end
	if #q > n then
		v.more:ClearAllPoints()
		v.more:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		v.more:SetText("+" .. (#q - n) .. " more")
		v.more:Show()
		y = y + 20
	else
		v.more:Hide()
	end
	if #q == 0 then
		R.empty:ClearAllPoints()
		R.empty:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		R.empty.icon:SetVertexColor(T.RGB(IsOpen() and "glow" or "off"))
		if not IsOpen() then
			R.empty.text:SetText("Raid summons are stopped")
			R.empty.sub:SetText(runner and "Press Start, then raiders type 123 in raid chat" or "Your raid leader starts them")
		else
			R.empty.text:SetText("Nobody waiting")
			R.empty.sub:SetText("Raiders type 123 in raid chat, or tap Request a summon")
		end
		local h = 56 + (R.empty.sub.wuberWrapped and (T.DrawnSize("caption") + T.Spacing("caption")) or 0)
		R.empty:SetHeight(h)
		R.empty:Show()
		y = y + h + 10
	else
		R.empty:Hide()
		y = y + 4
	end
	-- "Not here (N)": the runner may queue someone by hand
	local nh = runner and notHere() or {}
	setShown(R.nhHead, runner)
	local shown = 0
	cueParts(v, R)
	R.cueItems = { rows = cueRows, card = (#q == 0) and (y - 10) or nil }
	if runner then
		R.nhHead:ClearAllPoints()
		R.nhHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		R.nhHead.label:SetText("Not here (" .. #nh .. ")")
		-- (round 30) no cue to an empty "Not here (0)": it would sit on the message above it
		if #nh > 0 then R.cueItems.nh, R.cueItems.nhText = y + 28, "Not here (" .. #nh .. ")" end
		Try(R.nhHead.chev, "SetRotation", R.open and (math.pi / 2) or math.pi)
		y = y + 34
		if R.open then
			shown = math.min(#nh, RAID_NH_MAX)
			for i = 1, shown do
				local r = R.nh[i]
				if not r then
					r = notHereRow(c)
					R.nh[i] = r
				end
				local e = nh[i]
				r.who, r.where = e.name, e.zone
				dimAdd(r)
				r.name:SetText(short(e.name))
				r.name:SetTextColor(T.RGB(classColour(e.class)))
				r.zone:SetText(e.zone or "")
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
				r:Show()
				y = y + 36
			end
			if #nh == 0 then
				R.nhMore:SetText(nobodyAway())
			elseif #nh > shown then
				R.nhMore:SetText("+" .. (#nh - shown) .. " more")
			else
				R.nhMore:SetText("")
			end
			R.nhMore:ClearAllPoints()
			R.nhMore:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			R.nhMore:Show()
			if R.nhMore.wuberText ~= "" then y = y + 18 end
		end
	end
	if not (runner and R.open) then R.nhMore:Hide() end
	for i = shown + 1, #R.nh do R.nh[i]:Hide() end
	R.tonight:ClearAllPoints()
	R.tonight:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 4))
	R.tonight:SetText("Summoned tonight: " .. D.RaidTonight())
	R.tonight:Show()
	R.cueHolder:Show()
	updateCue(v, R)
	return y + 28
end

local function hideRaid(v)
	local R = v.raid
	if not R then return end
	for _, f in ipairs({ R.sumHead, R.edit, R.none, R.qHead, R.qCount, R.empty, R.nhHead, R.nhMore, R.tonight }) do f:Hide() end
	for _, b in ipairs(R.chips) do b:Hide() end
	for _, r in ipairs(R.nh) do r:Hide() end
	if R.cueHolder then R.cueHolder:Hide() end
	for i = 1, math.max(MAX_ROWS, #v.rows) do
		if v.rows[i] then
			v.rows[i]:SetAlpha(1)
			rowMouse(v.rows[i], true)
		end
	end
end

---------------------------------------------------------------------------
-- (2.3) The raid page's side pane: every raider who asked, "Not here (N)" with a +
-- per member (the whole list, it scrolls), and the summoner strip (shards, "no Wuber")
---------------------------------------------------------------------------

local side -- the side pane's parts (made by the page's build)
local SIDE_W = 324 -- what fits in the side pane at x PAD (18 px padding, as the rider's pages)

local function buildRaidSide(holder)
	if side or type(D.SidePane) ~= "function" then return end
	local p = D.SidePane(holder)
	local c = p.content
	p.qHead = T.Text(c, "body", "white", "LEFT", "bold")
	p.qCount = T.Text(c, "caption", "muted", "LEFT", "regular")
	p.qCount:SetPoint("LEFT", p.qHead, "RIGHT", 8, 0)
	p.qCount:SetWidth(200)
	p.empty = T.Text(c, "sub", "muted", "LEFT", "regular")
	p.empty:SetWidth(SIDE_W - 8)
	p.nhHead = T.Text(c, "body", "white", "LEFT", "bold")
	p.nhNone = T.Text(c, "caption", "muted", "LEFT", "regular")
	p.nhNone:SetWidth(SIDE_W - 8)
	p.nh = {}
	p.sumHead = T.Text(c, "body", "white", "LEFT", "bold")
	p.sumHead:SetText("Summoners")
	p.edit = T.Pill(c, "Change", "dark", 84, 24)
	p.edit.fill:SetColor("raised")
	p.edit:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(p.edit, "OnClick", function() D.ShowSheet("raidpick") end)
	T.Tip(p.edit, "Change summoners", "Tick the Warlocks in your raid who summon, and set who casts first.")
	p.none = T.Text(c, "caption", "red", "LEFT", "medium")
	p.none:SetWidth(SIDE_W - 8)
	p.none:SetText("Nobody summons yet: tap Warlocks to pick who summons")
	T.Lines(p.none, 2)
	side = p
end

function D.DrawRaidSide(v, t)
	local p = side
	if not p then return end
	local c = p.content
	local runner = D.Role() == "driver"
	local y = 4
	-- every raider who asked
	local q = raidQueue()
	p.qHead:ClearAllPoints()
	p.qHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	p.qHead:SetText("Raiders (" .. #q .. ")")
	p.qCount:SetText(#q > 0 and "click: summon next" or "")
	y = y + 26
	for i = 1, math.max(#q, #p.rows) do
		local r = p.rows[i]
		if i <= #q then
			if not r then
				r = D.Row(c, SIDE_W)
				r:SetHeight(QROW_H)
				p.rows[i] = r
			end
			D.PaintRaidRow(r, q[i], t)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			y = y + QROW_H + QROW_GAP
		elseif r then
			r:Hide()
			r.c = nil
		end
	end
	setShown(p.empty, #q == 0)
	if #q == 0 then
		p.empty:ClearAllPoints()
		p.empty:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		p.empty:SetText(IsOpen() and "Nobody waiting: raiders type 123 in raid chat" or "Raid summons are stopped")
		y = y + 24
	end
	y = y + 8
	-- "Not here (N)": the whole list, with + (the runner only)
	local nh = runner and notHere() or {}
	setShown(p.nhHead, runner)
	setShown(p.nhNone, runner and #nh == 0)
	if runner then
		p.nhHead:ClearAllPoints()
		p.nhHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		p.nhHead:SetText("Not here (" .. #nh .. ")")
		y = y + 24
		if #nh == 0 then
			p.nhNone:ClearAllPoints()
			p.nhNone:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
			p.nhNone:SetText(nobodyAway())
			y = y + 22
		end
	end
	for i = 1, math.max(#nh, #p.nh) do
		local r = p.nh[i]
		if i <= #nh then
			if not r then
				r = notHereRow(c, SIDE_W)
				p.nh[i] = r
			end
			local e = nh[i]
			r.who, r.where = e.name, e.zone
			dimAdd(r)
			r.name:SetText(short(e.name))
			r.name:SetTextColor(T.RGB(classColour(e.class)))
			r.zone:SetText(e.zone or "")
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			r:Show()
			y = y + 36
		elseif r then
			r:Hide()
		end
	end
	y = y + 8
	-- the summoners
	p.sumHead:ClearAllPoints()
	p.sumHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	p.edit:Hide() -- (round 9, S10) one picker: the Summoners pill beside Start
	p.edit:ClearAllPoints()
	p.edit:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -(y - 3))
	y = y + 28
	local sums = D.RaidSummoners()
	local _, turn = dr("MayCast")
	if turn == nil and sums[1] then turn = sums[1].key end
	setShown(p.none, #sums == 0)
	if #sums == 0 then
		for _, b in ipairs(p.chips) do b:Hide() end
		p.none:ClearAllPoints()
		p.none:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		y = y + 24 + (p.none.wuberWrapped and T.Spacing("caption") or 0)
	elseif D.LaySideChips then
		y = D.LaySideChips(p.chips, c, sums, y, turn) + 6
	end
	p.scroll:SetContentHeight(y + 6)
end

D.FOLD.raid = {
	build = buildRaidSide,
	layout = function(unfolded)
		D.wide.raid = unfolded == true
		D.Refresh(true)
		if D.RefreshNow then D.RefreshNow() end
	end,
}

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.drawRaid = drawRaid
Mod.hideRaid = hideRaid