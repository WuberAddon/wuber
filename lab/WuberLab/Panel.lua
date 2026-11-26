-- Wuber Lab (developer only, never ship): the "Wuber Lab" panel (/lab), the mini "Now" strip and
-- the slash command. Plain dark violet, like Wuber.
--
--   Now strip (top): the plan's next step in large type, Done / Fail.
--   Tabs: Plan (the tester's test plan, default), the role's checklist sections, Tools, Log.
--   A- / A+ scale the panel (and the mini strip) for a 4K screen; Mini shows the always-on-top
--   Now strip on its own (movable, remembered).

local _, L = ...

local show, str, call = L.show, L.str, L.call

local W_, H_ = 440, 680
local ROWS = 13
local ROW_H = 24
local BODY_Y = -154
local BODY_H = H_ - 154 - 74
local FONT = "Fonts\\ARIALN.TTF"
local CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"

local C = {
	bg = { 0.055, 0.035, 0.085, 0.96 }, head = { 0.11, 0.06, 0.18, 1 }, line = { 0.533, 0.247, 0.855, 0.9 },
	text = { 1, 1, 1 }, muted = { 0.68, 0.62, 0.76 }, gold = { 0.976, 0.773, 0.243 }, violet = { 0.804, 0.49, 0.961 },
	pass = { 0.35, 0.85, 0.45 }, fail = { 0.95, 0.32, 0.32 }, none = { 0.32, 0.28, 0.38 },
	btn = { 0.18, 0.1, 0.28, 1 }, btnHi = { 0.3, 0.16, 0.46, 1 }, rowSel = { 0.24, 0.13, 0.36, 0.7 }, now = { 0.13, 0.07, 0.21, 1 },
	box = { 0.02, 0.01, 0.04, 1 },
}

local P = { tab = "Plan", selected = nil, planSel = nil, rows = {}, tabs = {}, logLines = {}, planRows = {}, expanded = {}, planOffset = 1 }
L.panel = P

local function rgb(c) return c[1], c[2], c[3], c[4] or 1 end

local function setFont(fs, size, flags)
	if not pcall(fs.SetFont, fs, FONT, size or 12, flags or "") then
		pcall(fs.SetFontObject, fs, GameFontHighlightSmall or GameFontNormal)
	end
end

local function text(parent, size, colour, justify, wrap)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	setFont(fs, size)
	fs:SetTextColor(rgb(colour or C.text))
	pcall(fs.SetJustifyH, fs, justify or "LEFT")
	pcall(fs.SetJustifyV, fs, "TOP")
	pcall(fs.SetWordWrap, fs, wrap and true or false)
	fs:SetText("")
	return fs
end

local function fill(frame, colour, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND")
	t:SetAllPoints(frame)
	t:SetColorTexture(rgb(colour))
	return t
end

local function safe(where, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then L.Bug(where, err) end
	end
end

local function button(parent, label, w, h, onClick, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h or 22)
	b.bg = fill(b, C.btn, "BACKGROUND")
	b.label = text(b, size or 12, C.text, "CENTER")
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetText(label)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(rgb(C.btnHi)) end)
	b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(rgb(self.colour or C.btn)) end)
	b:SetScript("OnClick", safe("button " .. tostring(label), function(self) onClick(self) end))
	function b.SetLabel(self, t) self.label:SetText(t) end
	function b.SetColour(self, c)
		self.colour = c
		self.bg:SetColorTexture(rgb(c or C.btn))
	end
	return b
end

-- A wrapped font string's height, measured (and estimated, in case the game hasn't laid it out).
local function heightOf(fs, txt, width, size)
	local h = tonumber(call(fs.GetStringHeight, fs)) or 0
	local perLine = math.max(1, math.floor(width / (size * 0.44)))
	local lines = math.max(1, math.ceil(#tostring(txt or "") / perLine))
	return math.max(h, lines * size * 1.25)
end

---------------------------------------------------------------------------
-- Scale and positions
---------------------------------------------------------------------------

local panel, mini

function L.Scale()
	local s = tonumber(L.db and L.db.scale) or 1
	if s ~= s then s = 1 end
	return math.max(0.6, math.min(2.5, s))
end

local function applyScale()
	local s = L.Scale()
	if panel then pcall(panel.SetScale, panel, s) end
	if mini then pcall(mini.SetScale, mini, s) end
end

function L.SetScale(s)
	if not L.db then return end
	L.db.scale = math.floor(math.max(0.6, math.min(2.5, tonumber(s) or 1)) * 10 + 0.5) / 10
	applyScale()
end

local function savePos(f, field)
	if not (f and L.db) then return end
	local point, _, rel, x, y = f:GetPoint(1)
	if type(point) == "string" and type(x) == "number" and type(y) == "number" then
		L.db[field] = { point = point, rel = type(rel) == "string" and rel or point, x = x, y = y }
	end
end

local function place(f, field, point, x, y)
	f:ClearAllPoints()
	local p = L.db and L.db[field]
	if type(p) == "table" and type(p.point) == "string" and type(p.x) == "number" and type(p.y) == "number" then
		local ok = pcall(f.SetPoint, f, p.point, UIParent, type(p.rel) == "string" and p.rel or p.point, p.x, p.y)
		if ok then return end
		f:ClearAllPoints()
	end
	f:SetPoint(point, UIParent, point, x, y)
end

local function movable(f, field)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not L.InCombat() then pcall(self.StartMoving, self) end end)
	f:SetScript("OnDragStop", function(self)
		pcall(self.StopMovingOrSizing, self)
		pcall(savePos, self, field)
	end)
end

local function edges(f, w, h)
	for _, e in ipairs({ { "TOPLEFT", w, 1 }, { "BOTTOMLEFT", w, 1 }, { "TOPLEFT", 1, h }, { "TOPRIGHT", 1, h } }) do
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(rgb(C.line))
		t:SetPoint(e[1], f, e[1], 0, 0)
		t:SetSize(e[2], e[3])
	end
end

---------------------------------------------------------------------------
-- The Now strip (in the panel and the mini frame)
---------------------------------------------------------------------------

local function nowInfo()
	local s = L.PlanNext and L.PlanNext()
	if not s then return nil, "Plan done. Log out of all four normally, then tell the person running the test \"done\"." end
	local sec = L.PLAN_SECTION[s.sec]
	return s, s.text, (sec and sec.title or "") .. (s.who and ("  ·  " .. s.who) or "") .. (s.check and "  ·  check" or "")
end

local function buildNow(parent, width, height, bigSize)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	fill(f, C.now, "BORDER")
	f.label = text(f, 11, C.gold, "LEFT")
	f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
	f.label:SetWidth(width - 110)
	f.big = text(f, bigSize, C.text, "LEFT", true)
	f.big:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -22)
	f.big:SetWidth(width - 110)
	pcall(f.big.SetMaxLines, f.big, 3)
	f.done = button(f, "Done", 86, 30, function()
		local s = nowInfo()
		if s then L.PlanMark(s.id, "pass") end
	end, 14)
	f.done:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	f.fail = button(f, "Fail", 86, 20, function()
		local s = nowInfo()
		if s then
			L.PlanMark(s.id, "fail")
			P.planSel = s.id
			if panel and panel:IsShown() then P.tab = "Plan" end
		end
	end, 11)
	f.fail:SetPoint("TOPRIGHT", f.done, "BOTTOMRIGHT", 0, -4)
	function f.Update()
		local s, line, label = nowInfo()
		f.label:SetText(s and ("NOW  ·  " .. label) or "NOW")
		f.big:SetText(line or "")
		if s then f.done:Show() f.fail:Show() else f.done:Hide() f.fail:Hide() end
	end
	return f
end

local function buildMini()
	if mini then return mini end
	mini = CreateFrame("Frame", "WuberLabMini", UIParent)
	mini:SetSize(W_, 92)
	pcall(mini.SetFrameStrata, mini, "FULLSCREEN_DIALOG")
	pcall(mini.SetToplevel, mini, true)
	movable(mini, "miniPos")
	fill(mini, C.bg, "BACKGROUND")
	edges(mini, W_, 92)
	mini.now = buildNow(mini, W_ - 2, 90, 15)
	mini.now:SetPoint("TOPLEFT", mini, "TOPLEFT", 1, -1)
	-- the strip passes drags on to the frame
	mini.now:EnableMouse(false)
	local open = button(mini, "Lab", 40, 18, function() L.Toggle(true) end, 10)
	open:SetPoint("BOTTOMRIGHT", mini, "BOTTOMRIGHT", -8, 6)
	local close = button(mini, "x", 18, 18, function() L.SetMini(false) end, 10)
	close:SetPoint("RIGHT", open, "LEFT", -4, 0)
	place(mini, "miniPos", "TOP", 0, -120)
	applyScale()
	mini:Hide()
	return mini
end

function L.SetMini(on)
	buildMini()
	if L.db then L.db.miniShown = on and true or false end
	if on then
		mini:Show()
		mini.now.Update()
	else
		mini:Hide()
	end
	L.Log("tool", "mini mode " .. (on and "on" or "off"))
	if P.miniBtn then P.miniBtn:SetColour(on and { 0.45, 0.2, 0.7, 1 } or nil) end
	return on
end

function L.MiniShown() return mini ~= nil and mini:IsShown() end

---------------------------------------------------------------------------
-- Building the panel
---------------------------------------------------------------------------

local function roleText()
	local c = L.Char()
	local over = c and c.roleOverride
	return "role: " .. L.Role() .. (over and " (set)" or "")
end

local Refresh

local function selectTab(name)
	P.tab = name
	Refresh()
end

local function buildTabs()
	for _, t in ipairs(P.tabs) do t:Hide() end
	local names = { "Plan" }
	for _, n in ipairs(L.Sections()) do names[#names + 1] = n end
	names[#names + 1] = "Tools"
	names[#names + 1] = "Log"
	local x = 10
	local w = math.floor((W_ - 20 - (#names - 1) * 4) / #names)
	for i, name in ipairs(names) do
		local t = P.tabs[i]
		if not t then
			t = button(panel, name, w, 22, function(self) selectTab(self.name) end)
			P.tabs[i] = t
		end
		t.name = name
		t:SetSize(w, 22)
		t:SetLabel(name)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -126)
		t:Show()
		x = x + w + 4
	end
	local known = false
	for _, n in ipairs(names) do if n == P.tab then known = true end end
	if not known then P.tab = "Plan" end
end

local function buildRows(body)
	P.progress = text(body, 12, C.violet, "LEFT")
	P.progress:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	P.progress:SetWidth(W_ - 20)
	P.hint = text(body, 12, C.text, "LEFT")
	P.hint:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -18)
	P.hint:SetWidth(W_ - 20)
	for i = 1, ROWS do
		local r = CreateFrame("Button", nil, body)
		r:SetSize(W_ - 20, ROW_H - 2)
		r:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -44 - (i - 1) * ROW_H)
		r.sel = fill(r, C.rowSel, "BACKGROUND")
		r.sel:Hide()
		r.dot = r:CreateTexture(nil, "ARTWORK")
		r.dot:SetSize(10, 10)
		r.dot:SetPoint("LEFT", r, "LEFT", 4, 0)
		r.dot:SetColorTexture(rgb(C.none))
		r.label = text(r, 12, C.text, "LEFT")
		r.label:SetPoint("LEFT", r, "LEFT", 20, 0)
		r.label:SetWidth(W_ - 210)
		r.took = text(r, 11, C.muted, "RIGHT")
		r.took:SetPoint("RIGHT", r, "RIGHT", -84, 0)
		r.took:SetWidth(46)
		r.pass = button(r, "Pass", 38, 18, function(self)
			local p = self:GetParent()
			if not p.step then return end
			local on = (L.Result(p.step.id) or {}).r == "pass"
			if on then L.MarkStep(p.step.id, nil) else L.MarkStep(p.step.id, "pass") end
		end)
		r.pass:SetPoint("RIGHT", r, "RIGHT", -42, 0)
		r.fail = button(r, "Fail", 38, 18, function(self)
			local p = self:GetParent()
			if p.step then
				local on = (L.Result(p.step.id) or {}).r == "fail"
				if on then L.MarkStep(p.step.id, nil) else L.MarkStep(p.step.id, "fail") end
				P.selected = p.step.id
				Refresh()
			end
		end)
		r.fail:SetPoint("RIGHT", r, "RIGHT", 0, 0)
		r:RegisterForClicks("LeftButtonUp")
		r:SetScript("OnClick", safe("row", function(self)
			if not self.step then return end
			P.selected = self.step.id
			Refresh()
		end))
		r:SetScript("OnEnter", safe("row tip", function(self)
			if not (self.step and GameTooltip and type(GameTooltip.SetOwner) == "function") then return end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:AddLine(self.step.text, 1, 1, 1)
			GameTooltip:AddLine(self.step.hint or "", C.muted[1], C.muted[2], C.muted[3], true)
			GameTooltip:AddLine(self.step.manual and "Mark it Pass or Fail by hand." or "Ticks itself when seen; Pass/Fail by hand too.",
				C.violet[1], C.violet[2], C.violet[3], true)
			GameTooltip:Show()
		end))
		r:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end end)
		P.rows[i] = r
	end
end

-- The Plan tab: collapsible sections, steps with a big tick box, wrapped text, who tag.
local PLAN_ROWS = 24
local function buildPlan(body)
	local f = CreateFrame("Frame", nil, body)
	f:SetAllPoints(body)
	pcall(f.EnableMouseWheel, f, true)
	f:SetScript("OnMouseWheel", safe("plan wheel", function(_, delta)
		P.planOffset = math.max(1, (P.planOffset or 1) - (tonumber(delta) or 0))
		Refresh()
	end))
	P.plan = f
	for i = 1, PLAN_ROWS do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(W_ - 20, 24)
		r.sel = fill(r, C.rowSel, "BACKGROUND")
		r.sel:Hide()
		r.head = fill(r, C.head, "BACKGROUND")
		r.head:Hide()
		r.tick = CreateFrame("Button", nil, r)
		r.tick:SetSize(24, 24)
		r.tick:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -3)
		r.tick.bg = fill(r.tick, C.box, "BACKGROUND")
		r.tick.fill = r.tick:CreateTexture(nil, "BORDER")
		r.tick.fill:SetPoint("TOPLEFT", r.tick, "TOPLEFT", 2, -2)
		r.tick.fill:SetPoint("BOTTOMRIGHT", r.tick, "BOTTOMRIGHT", -2, 2)
		r.tick.fill:SetColorTexture(rgb(C.none))
		r.tick.mark = r.tick:CreateTexture(nil, "ARTWORK")
		r.tick.mark:SetAllPoints(r.tick)
		pcall(r.tick.mark.SetTexture, r.tick.mark, CHECK_TEX)
		r.tick.x = text(r.tick, 16, C.text, "CENTER")
		r.tick.x:SetPoint("CENTER", r.tick, "CENTER", 0, 0)
		r.tick:RegisterForClicks("LeftButtonUp")
		r.tick:SetScript("OnClick", safe("plan tick", function(self)
			local s = self:GetParent().pstep
			if not s then return end
			local rec = L.PlanRec(s.id)
			if rec and (rec.r == "pass" or rec.r == "auto") then L.PlanMark(s.id, nil) else L.PlanMark(s.id, "pass") end
		end))
		r.text = text(r, 13, C.text, "LEFT", true)
		r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -4)
		r.who = text(r, 10, C.violet, "LEFT")
		r.fail = button(r, "Fail", 40, 18, function(self)
			local s = self:GetParent().pstep
			if not s then return end
			local rec = L.PlanRec(s.id)
			if rec and rec.r == "fail" then L.PlanMark(s.id, nil) else L.PlanMark(s.id, "fail") end
			P.planSel = s.id
			Refresh()
		end, 10)
		r.fail:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -4)
		r:RegisterForClicks("LeftButtonUp")
		r:SetScript("OnClick", safe("plan row", function(self)
			if self.psec then
				local sec = self.psec
				P.expanded[sec.id] = not P.expanded[sec.id]
				P.userToggled = true
			elseif self.pstep then
				P.planSel = self.pstep.id
			end
			Refresh()
		end))
		pcall(r.EnableMouseWheel, r, true)
		r:SetScript("OnMouseWheel", safe("plan row wheel", function(_, delta)
			P.planOffset = math.max(1, (P.planOffset or 1) - (tonumber(delta) or 0))
			Refresh()
		end))
		P.planRows[i] = r
	end
	P.more = text(f, 11, C.muted, "RIGHT")
	P.more:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f:Hide()
end

local function runSay(ok, why)
	if not ok and why then L.Say("test run: " .. tostring(why)) end
	return ok
end

local TOOL_BUTTONS = {
	{ "run", "Start test run", function()
		if L.RunActive() then L.RunStop("stopped by the tester") else runSay(L.RunStart()) end
	end },
	{ "pretend", "Pretend rider (this window)", function() runSay(L.PretendStart()) end },
	{ "fakes", "Fake drivers: off", function() if L.fakesOn then L.FakesOff() else L.FakesOn() end end },
	{ "sim", "Pretend to summon (no shards): off", function() L.SimToggle() end },
	{ "simclick", "Pretend I clicked", function() L.SimHelperClick() end },
	{ "fx", "Play every effect", function() L.PlayAllFX() end },
	{ "fresh", "Fresh rider", function() L.FreshRider() end },
	{ "restore", "Restore rider", function() L.RestoreRider() end },
	{ "mark", "Mark (text below)", function()
		local t = P.note and P.note:GetText() or ""
		L.Mark(t)
		if P.note then P.note:SetText("") P.note:ClearFocus() end
	end },
	{ "checks", "Run checks", function() L.RunChecks() end },
	{ "role", "Role: auto", function()
		local c = L.Char()
		if not c then return end
		local order = { false, "rider", "driver", "team" }
		local cur = c.roleOverride or false
		local nextRole = false
		for i, r in ipairs(order) do if r == cur then nextRole = order[i % #order + 1] end end
		L.SetRole(nextRole or nil)
	end },
	{ "reset", "Reset checklist", function()
		L.Confirm("Wuber Lab: clear every tick, Pass/Fail and note on this character's checklist?", function() L.ResetChecks() end)
	end },
	{ "planreset", "Reset plan (all four)", function()
		L.Confirm("Wuber Lab: clear every tick and note of the test plan on all four characters?", function() L.PlanReset() end)
	end },
	{ "mini", "Mini Now strip", function() L.SetMini(not L.MiniShown()) end },
	{ "snap", "Snap (screenshot)", function() L.Snap() end },
	{ "tour", "Photo tour (every screen)", function() if L.Touring() then L.TourStop() else L.TourFull() end end },	{ "login", "Login checks again", function() L.RunLoginChecks() end },
	{ "results", "Reset test run results", function()
		L.Confirm("Wuber Lab: forget every test run result, so every check runs again?", function() L.RunResetResults() end)
	end },
	{ "trail", "Usage trail: off", function() if L.TrailSet then L.TrailSet(not L.TrailOn()) end end,
		tip = "Usage trail: logs every Wuber window, tab, screen, click, hover and setting with the clock time, so the report "
			.. "can show where you struggled (Struggles). Play as usual; no screen recording needed. Same as /lab trail on|off." },
	{ "huh", "Huh (mark + screenshot)", function()
		local t = P.note and P.note:GetText() or ""
		if L.Huh then L.Huh(t) end
		if P.note then P.note:SetText("") P.note:ClearFocus() end
	end,
		tip = "Huh: notes that you got stuck here (with the text below, if any, and the last 30 s of the trail) and takes a "
			.. "screenshot. Bind a key for it: Esc > Options > Keybindings > WuberLab. Same as /lab huh <words>." },
	{ "passive", "Passive play: off", function() L.PassiveSet(not L.PassiveOn()) end,
		tip = "Passive play: the lab checks real rides, trades, portal clicks, crew syncs and logins by itself, logs anything blocked, "
			.. "and takes the photo tour when you are idle in a city. It never sends anything and never clicks for you. Same as /lab passive on|off." },
}

local function buildTools(body)
	local f = CreateFrame("Frame", nil, body)
	f:SetAllPoints(body)
	P.tools = f
	P.toolButtons = {}
	local bw = math.floor((W_ - 20 - 8) / 2)
	for i, def in ipairs(TOOL_BUTTONS) do
		local b = button(f, def[2], bw, 22, def[3])
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * (bw + 8), -row * 26)
		P.toolButtons[def[1]] = b
		if def.tip then
			b:SetScript("OnEnter", function(self)
				self.bg:SetColorTexture(rgb(C.btnHi))
				if GameTooltip then
					pcall(GameTooltip.SetOwner, GameTooltip, self, "ANCHOR_TOP")
					pcall(GameTooltip.SetText, GameTooltip, def.tip, 1, 1, 1, 1, true)
					pcall(GameTooltip.Show, GameTooltip)
				end
			end)
			b:SetScript("OnLeave", function(self)
				self.bg:SetColorTexture(rgb(self.colour or C.btn))
				if GameTooltip then pcall(GameTooltip.Hide, GameTooltip) end
			end)
		end
	end
	local top = -math.ceil(#TOOL_BUTTONS / 2) * 26 - 6
	local head = text(f, 12, C.gold, "LEFT")
	head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, top)
	head:SetText("Fake drivers (local only - never sent to anyone)")
	P.fakeRows = {}
	for i, fk in ipairs(L.FAKES) do
		local y = top - 18 - (i - 1) * 22
		local t = text(f, 11, C.text, "LEFT")
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 4)
		t:SetWidth(W_ - 20 - 60)
		local money = (L.W() and type(L.W().Money) == "function" and call(L.W().Money, fk.price)) or tostring(fk.price)
		t:SetText(fk.name .. " · " .. money .. " · " .. fk.does)
		local b = button(f, "Book", 52, 20, function() L.BookFake(fk.id) end)
		b:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, y)
		P.fakeRows[i] = { text = t, book = b }
	end
	local foot = text(f, 11, C.muted, "LEFT", true)
	foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
	foot:SetWidth(W_ - 20)
	foot:SetText("Logs: WuberLabDB, written on /reload or logout. Report: tools\\labreport.cmd")
	f:Hide()
end

local function buildLog(body)
	local f = CreateFrame("Frame", nil, body)
	f:SetAllPoints(body)
	P.log = f
	for i = 1, 24 do
		local t = text(f, 10, C.text, "LEFT")
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i - 1) * 18)
		t:SetWidth(W_ - 20)
		P.logLines[i] = t
	end
	f:Hide()
end

local function build()
	if panel then return panel end
	panel = CreateFrame("Frame", "WuberLabPanel", UIParent)
	P.frame = panel
	panel:SetSize(W_, H_)
	pcall(panel.SetFrameStrata, panel, "HIGH")
	movable(panel, "pos")
	fill(panel, C.bg, "BACKGROUND")
	edges(panel, W_, H_)
	local head = CreateFrame("Frame", nil, panel)
	head:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	head:SetSize(W_, 34)
	fill(head, C.head, "BORDER")
	local title = text(head, 16, C.gold, "LEFT")
	title:SetPoint("LEFT", head, "LEFT", 10, 0)
	title:SetText("Wuber Lab")
	P.who = text(head, 11, C.muted, "LEFT")
	P.who:SetPoint("LEFT", head, "LEFT", 96, 0)
	P.who:SetWidth(170)
	local close = button(head, "x", 24, 22, function() panel:Hide() end)
	close:SetPoint("RIGHT", head, "RIGHT", -6, 0)
	P.miniBtn = button(head, "Mini", 40, 22, function() L.SetMini(not L.MiniShown()) end, 11)
	P.miniBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
	local bigger = button(head, "A+", 30, 22, function() L.SetScale(L.Scale() + 0.1) end, 11)
	bigger:SetPoint("RIGHT", P.miniBtn, "LEFT", -4, 0)
	local smaller = button(head, "A-", 30, 22, function() L.SetScale(L.Scale() - 0.1) end, 11)
	smaller:SetPoint("RIGHT", bigger, "LEFT", -4, 0)
	P.now = buildNow(panel, W_ - 20, 84, 16)
	P.now:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -38)
	local body = CreateFrame("Frame", nil, panel)
	body:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, BODY_Y)
	body:SetSize(W_ - 20, BODY_H)
	P.body = body
	P.list = CreateFrame("Frame", nil, body)
	P.list:SetAllPoints(body)
	buildRows(P.list)
	buildPlan(body)
	buildTools(body)
	buildLog(body)
	-- the note (checklist / plan) or mark text (Tools, Log) box
	local noteLabel = text(panel, 11, C.muted, "LEFT")
	noteLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 40)
	noteLabel:SetWidth(W_ - 20)
	P.noteLabel = noteLabel
	local eb = CreateFrame("EditBox", "WuberLabNote", panel)
	eb:SetSize(W_ - 20 - 66, 22)
	eb:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 12)
	pcall(eb.SetFont, eb, FONT, 12, "")
	eb:SetAutoFocus(false)
	pcall(eb.SetMaxLetters, eb, 150)
	pcall(eb.SetTextInsets, eb, 4, 4, 0, 0)
	fill(eb, C.box, "BACKGROUND")
	local function save(self)
		if P.tab == "Tools" or P.tab == "Log" then
			L.Mark(self:GetText())
			self:SetText("")
		elseif P.tab == "Plan" then
			if P.planSel then L.PlanNote(P.planSel, self:GetText()) end
		elseif P.selected then
			L.SetNote(P.selected, self:GetText())
		end
		self:ClearFocus()
	end
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnEnterPressed", safe("note enter", save))
	P.note = eb
	P.save = button(panel, "Save", 58, 22, function() save(eb) end)
	P.save:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 12)
	panel:SetScript("OnHide", function() pcall(eb.ClearFocus, eb) end)
	local acc = 0
	panel:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + (elapsed or 0)
		if acc < 0.5 then return end
		acc = 0
		if P.dirty then
			P.dirty = false
			pcall(Refresh)
		end
	end)
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WuberLabPanel") end
	place(panel, "pos", "RIGHT", -40, 40)
	applyScale()
	panel:Hide()
	buildTabs()
	return panel
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function stepColour(rec)
	if not rec or not rec.r then return C.none end
	if rec.r == "fail" then return C.fail end
	if rec.r == "pass" then return C.pass end
	return C.violet
end

local function fmtTook(rec)
	if not (rec and rec.r) then return "" end
	if rec.took then return ("+%.1fs"):format(rec.took) end
	return rec.r == "auto" and "seen" or ""
end

local KIND_RED = { err = true, werr = true, block = true, laberr = true }

local function drawList()
	local d, n, f = L.Progress()
	P.progress:SetText(("Checklist %d/%d done%s%s"):format(d, n, f > 0 and (" · " .. f .. " failed") or "",
		(L.fakesOn and " · FAKE DRIVERS ON" or "") .. (L.sim and " · TEST MODE" or "")))
	local nextStep = L.NextStep(P.tab)
	P.hint:SetText(nextStep and ("Next: " .. (nextStep.hint or nextStep.text)) or "Next: all done here.")
	local list = {}
	for _, s in ipairs(L.Steps()) do if s.sec == P.tab then list[#list + 1] = s end end
	for i, r in ipairs(P.rows) do
		local s = list[i]
		r.step = s
		if s then
			local rec = L.Result(s.id)
			r.dot:SetColorTexture(rgb(stepColour(rec)))
			r.label:SetText(s.text .. (rec and rec.note and " *" or ""))
			r.label:SetTextColor(rgb((rec and rec.r) and C.text or C.muted))
			r.took:SetText(fmtTook(rec))
			r.pass:SetColour(rec and rec.r == "pass" and { 0.15, 0.45, 0.22, 1 } or nil)
			r.fail:SetColour(rec and rec.r == "fail" and { 0.55, 0.12, 0.12, 1 } or nil)
			if P.selected == s.id then r.sel:Show() else r.sel:Hide() end
			r:Show()
		else
			r:Hide()
		end
	end
end

-- The plan as a list of items: { kind = "head"|"intro"|"sub"|"step", sec, step, text }
local function planItems()
	local nextStep = L.PlanNext and L.PlanNext()
	local nextSec = nextStep and nextStep.sec or nil
	if nextSec ~= P.autoSec then
		-- the next step moved on: its section opens, the rest close, and it scrolls into view
		P.autoSec = nextSec
		if not P.userToggled or not P.expanded[nextSec or ""] then
			P.expanded = {}
			if nextSec then P.expanded[nextSec] = true end
		end
		P.userToggled = false
		P.scrollTo = nextSec
	end
	local items = {}
	for _, sec in ipairs(L.PLAN or {}) do
		items[#items + 1] = { kind = "head", sec = sec }
		if P.scrollTo == sec.id then
			P.planOffset = #items
			P.scrollTo = nil
		end
		if P.expanded[sec.id] then
			if sec.intro then items[#items + 1] = { kind = "intro", sec = sec, text = sec.intro } end
			local sub
			for _, s in ipairs(sec.steps) do
				if s.sub and s.sub ~= sub then items[#items + 1] = { kind = "sub", sec = sec, text = s.sub } end
				sub = s.sub
				if s.check and not sub then
					-- (checks follow the numbered steps)
				end
				items[#items + 1] = { kind = "step", sec = sec, step = s }
			end
		end
	end
	return items
end

local function drawPlan()
	local items = planItems()
	if P.planOffset > #items then P.planOffset = math.max(1, #items) end
	local y, used = 0, 0
	local textW = W_ - 20 - 34 - 48
	for i, r in ipairs(P.planRows) do
		local it = items[P.planOffset + i - 1]
		r.psec, r.pstep = nil, nil
		if not it or y >= BODY_H - 20 then
			r:Hide()
		else
			used = used + 1
			r.head:Hide()
			r.sel:Hide()
			r.tick:Hide()
			r.fail:Hide()
			r.who:SetText("")
			r.text:ClearAllPoints()
			local h
			if it.kind == "head" then
				local d, n = L.PlanProgress(it.sec.id)
				r.psec = it.sec
				r.head:Show()
				setFont(r.text, 14)
				r.text:SetTextColor(rgb(d == n and C.pass or C.gold))
				r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -6)
				r.text:SetWidth(W_ - 32)
				r.text:SetText((P.expanded[it.sec.id] and "[-]  " or "[+]  ") .. it.sec.title .. "   " .. d .. "/" .. n)
				h = 28
			elseif it.kind == "intro" or it.kind == "sub" then
				setFont(r.text, it.kind == "sub" and 12 or 12)
				r.text:SetTextColor(rgb(it.kind == "sub" and C.violet or C.muted))
				r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -3)
				r.text:SetWidth(W_ - 32)
				r.text:SetText(it.text)
				h = heightOf(r.text, it.text, W_ - 32, 12) + 6
			else
				local s = it.step
				local rec = L.PlanRec(s.id)
				r.pstep = s
				r.tick:Show()
				r.fail:Show()
				r.tick.fill:SetColorTexture(rgb(stepColour(rec)))
				if rec and (rec.r == "pass" or rec.r == "auto") then r.tick.mark:Show() else r.tick.mark:Hide() end
				r.tick.x:SetText(rec and rec.r == "fail" and "X" or "")
				r.fail:SetColour(rec and rec.r == "fail" and { 0.55, 0.12, 0.12, 1 } or nil)
				setFont(r.text, 13)
				r.text:SetTextColor(rgb((rec and rec.r) and C.muted or C.text))
				r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -4)
				r.text:SetWidth(textW)
				local body = (s.check and "Check: " or "") .. s.text
				r.text:SetText(body)
				local th = heightOf(r.text, body, textW, 13)
				local tag = {}
				if s.who then tag[#tag + 1] = s.who end
				if rec and rec.r == "auto" then tag[#tag + 1] = "auto" .. (rec.by and (" (" .. rec.by .. ")") or "") end
				if rec and rec.r and rec.who then tag[#tag + 1] = "by " .. rec.who end
				if rec and rec.note then tag[#tag + 1] = "note: " .. rec.note end
				if not rec and (s.sig or s.all or s.probe) then tag[#tag + 1] = "ticks itself" end
				r.who:ClearAllPoints()
				r.who:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -(th + 6))
				r.who:SetWidth(textW)
				r.who:SetText(table.concat(tag, "  ·  "))
				h = math.max(32, th + 22)
				if P.planSel == s.id then r.sel:Show() end
			end
			r:SetHeight(h)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", P.plan, "TOPLEFT", 0, -y)
			r:Show()
			y = y + h + 2
		end
	end
	local rest = #items - (P.planOffset - 1) - used
	P.more:SetText(rest > 0 and ("scroll for " .. rest .. " more") or "")
end

local function drawLog()
	local lines = L.Tail(#P.logLines)
	for i, fs in ipairs(P.logLines) do
		local l = lines[i]
		if l then
			local at, _, kind, rest = l:match("^([%d%.]+)|([^|]*)|([^|]*)|(.*)$")
			local clock = ""
			local t = tonumber(at)
			if t and type(date) == "function" then clock = (call(date, "%H:%M:%S", math.floor(t)) or "") end
			fs:SetText(("%s %s %s"):format(clock, kind or "?", (rest or l):sub(1, 76)))
			fs:SetTextColor(rgb(KIND_RED[kind or ""] and C.fail or (kind == "mark" and C.gold or C.text)))
		else
			fs:SetText("")
		end
	end
end

local function drawNow()
	if P.now then P.now.Update() end
	if mini and mini:IsShown() then mini.now.Update() end
end

Refresh = function()
	drawNow()
	if not panel then return end
	P.who:SetText(tostring(L.me or "?") .. " · " .. roleText())
	for _, t in ipairs(P.tabs) do t:SetColour(t.name == P.tab and { 0.45, 0.2, 0.7, 1 } or nil) end
	local isPlan, isTools, isLog = P.tab == "Plan", P.tab == "Tools", P.tab == "Log"
	local isList = not (isPlan or isTools or isLog)
	if isList then P.list:Show() else P.list:Hide() end
	if isPlan then P.plan:Show() else P.plan:Hide() end
	if isTools then P.tools:Show() else P.tools:Hide() end
	if isLog then P.log:Show() else P.log:Hide() end
	if isList then
		drawList()
		local s = P.selected and L.STEP_BY_ID[P.selected]
		P.noteLabel:SetText(s and ("Note for: " .. s.text) or "Click a step to add a note (Enter saves)")
		P.save:SetLabel("Save")
	elseif isPlan then
		drawPlan()
		local s = P.planSel and L.PLAN_STEP[P.planSel]
		P.noteLabel:SetText(s and ("Note for: " .. s.text:sub(1, 60)) or "Click a plan step to add a note (Enter saves)")
		P.save:SetLabel("Save")
	else
		P.noteLabel:SetText("Mark text (Enter or Mark adds a bookmark line)")
		P.save:SetLabel("Mark")
	end
	if isTools then
		local tb = P.toolButtons
		tb.fakes:SetLabel(L.fakesOn and "Fake drivers: ON (clear)" or "Fake drivers: off")
		tb.fakes:SetColour(L.fakesOn and { 0.5, 0.3, 0.05, 1 } or nil)
		tb.sim:SetLabel(L.sim and "Pretend to summon: ON" or "Pretend to summon (no shards): off")
		tb.sim:SetColour(L.sim and { 0.6, 0.12, 0.12, 1 } or nil)
		local c = L.Char()
		tb.role:SetLabel("Role: " .. ((c and c.roleOverride) or ("auto (" .. L.Role() .. ")")))
		tb.restore:SetColour((L.db and L.db.riderBackup) and { 0.15, 0.45, 0.22, 1 } or nil)
		tb.tour:SetLabel(L.Touring() and "Photo tour: running (stop)" or "Photo tour (every screen)")
		tb.run:SetLabel(L.RunActive() and "Test run: going (stop)" or "Start test run")
		tb.run:SetColour(L.RunActive() and { 0.45, 0.2, 0.7, 1 } or nil)
		tb.pretend:SetColour(L.pretend and { 0.5, 0.3, 0.05, 1 } or nil)
		if tb.trail and L.TrailOn then
			tb.trail:SetLabel(L.TrailOn() and "Usage trail: ON" or "Usage trail: off")
			tb.trail:SetColour(L.TrailOn() and { 0.15, 0.45, 0.22, 1 } or nil)
		end
		if tb.passive and L.PassiveOn then
			tb.passive:SetLabel(L.PassiveOn() and "Passive play: ON" or "Passive play: off")
			tb.passive:SetColour(L.PassiveOn() and { 0.15, 0.45, 0.22, 1 } or nil)
		end
	end
	if isLog then drawLog() end
end
L.RefreshPanel = function() pcall(Refresh) end

local function dirty()
	if panel and panel:IsShown() then P.dirty = true end
	if mini and mini:IsShown() then pcall(mini.now.Update) end
	if P.now and panel and panel:IsShown() then pcall(P.now.Update) end
end
L.changed = dirty
L.planChanged = dirty

L.listeners[#L.listeners + 1] = function()
	if panel and P.tab == "Log" and panel:IsShown() then P.dirty = true end
end

-- When the selection changes, the note box shows that step's note.
local origRefresh = Refresh
Refresh = function()
	origRefresh()
	if not P.note then return end
	local sel = P.tab == "Plan" and ("plan:" .. tostring(P.planSel)) or ("check:" .. tostring(P.selected))
	if sel ~= P.lastSelected then
		P.lastSelected = sel
		local rec
		if P.tab == "Plan" and P.planSel then rec = L.PlanRec(P.planSel) elseif P.selected then rec = L.Result(P.selected) end
		P.note:SetText(rec and rec.note or "")
	end
end

function L.SetRole(role)
	local c = L.Char()
	if not c then return false end
	if role ~= "rider" and role ~= "driver" and role ~= "team" then role = nil end
	c.roleOverride = role
	L.Log("check", "role " .. (role or "auto") .. " -> " .. L.Role())
	L.SaveStepList()
	if panel then
		buildTabs()
		P.dirty = true
		pcall(Refresh)
	end
	return true
end

function L.Toggle(showIt)
	build()
	if showIt == nil then showIt = not panel:IsShown() end
	if showIt then
		if not panel:IsShown() then P.tab = "Plan" end -- the plan first, every time it opens
		panel:Show()
		pcall(Refresh)
	else
		panel:Hide()
	end
	return showIt
end

---------------------------------------------------------------------------
-- /lab
---------------------------------------------------------------------------

local HELP = "/lab - panel; /lab auto [stop|shots|steps|ride|drive|settings|<screen ids>] (Auto check: the game looks over Wuber's screens itself; a screenshot only of a screen that needs a look or is new; shots photographs every screen); /lab mini; /lab done; /lab mark <text>; /lab role rider|driver|team|auto; /lab fakes on|off; /lab sim on|off; /lab simclick; "
	.. "/lab book <cheap|mid|busy|spam|dear>; /lab fx; /lab fresh; /lab restore; /lab check; /lab reset; /lab resetplan; /lab scale <0.6-2.5>; "
	.. "/lab snap; /lab tour [click|stop] (every screen); /lab tour ride|drive|float|settings|earnings|<shot ids or starts, e.g. home pay float_> (a partial tour: ride = rider screens, drive = driver screens, float = floating button, settings = Settings and Help, earnings = Earnings; add click if needed); /lab run [all|stop]; /lab skip; /lab wrong; /lab pretend [stop]; /lab logincheck; /lab results reset; /lab passive on|off|status; /lab trail on|off|status; /lab huh [words]; /lab f1 allow|require; /lab alphaprobe"

function L.Slash(msg)
	msg = (str(msg) or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "show" or cmd == "toggle" then
		L.Toggle()
	elseif cmd == "mini" then
		L.SetMini(not L.MiniShown())
	elseif cmd == "done" then
		local s = L.PlanNext()
		if s then L.PlanMark(s.id, "pass") end
	elseif cmd == "scale" then
		L.SetScale(tonumber(rest) or 1)
	elseif cmd == "mark" then
		L.Mark(rest)
		L.Say("marked: " .. (rest ~= "" and rest or "mark"))
	elseif cmd == "role" then
		L.SetRole(rest:lower())
		L.Say("role: " .. L.Role())
	elseif cmd == "fakes" or cmd == "fake" then
		if rest:lower() == "off" or (rest == "" and L.fakesOn) then L.FakesOff() else L.FakesOn() end
		L.Say("fake drivers " .. (L.fakesOn and "on" or "off"))
	elseif cmd == "sim" then
		if rest:lower() == "off" or (rest == "" and L.sim) then L.SimSet(false) else L.SimSet(true) end
		L.Say("pretend to summon " .. (L.sim and "on - nobody is really summoned" or "off"))
	elseif cmd == "simclick" then
		L.SimHelperClick()
	elseif cmd == "book" then
		L.BookFake(rest:lower())
	elseif cmd == "fx" then
		L.PlayAllFX()
	elseif cmd == "fresh" then
		L.FreshRider()
	elseif cmd == "restore" then
		L.RestoreRider()
	elseif cmd == "check" or cmd == "checks" then
		L.RunChecks()
	elseif cmd == "reset" then
		L.Confirm("Wuber Lab: clear every tick, Pass/Fail and note on this character's checklist?", function() L.ResetChecks() end)
	elseif cmd == "nettest" then
		L.NetTest()
	elseif cmd == "snap" or cmd == "shot" then
		L.Snap()
	elseif cmd == "auto" or cmd == "autocheck" then
		-- (job 105c) /lab auto [stop | steps | ride | drive | settings | <screen ids or their starts>]
		local a = rest:lower()
		if not L.AutoStart then
			L.Say("Auto check isn't loaded: AutoCheck.lua is a new file, so close the game fully and start it again")
		elseif a == "stop" or a == "off" then
			if not L.AutoStop() then L.Say("no Auto check is running") end
		elseif L.AutoRunning() then
			L.Say("Auto check is running (/lab auto stop, or click anywhere)")
		elseif L.Touring() then
			L.Say("the photo tour is running (/lab tour stop)")
		else
			-- (job 2880) "shots" = a screenshot of every screen (the old way); without it only new screens and looks get one
			local words, shots, full = {}, false, false
			for w in a:gmatch("[^%s,]+") do
				if w == "shots" then shots = true elseif w == "all" or w == "full" then full = true else words[#words + 1] = w end
			end
			L.AutoStart({ words = words, shots = shots, full = full })
		end
	elseif cmd == "tour" or cmd == "photos" then
		local a = rest:lower()
		if a == "stop" or a == "off" then
			if not L.TourStop("/lab tour stop") then L.Say("no photo tour is running") end
		elseif L.Touring() then
			L.Say("the photo tour is running (/lab tour stop)")
		else
			local words, click = {}, false
			for w in a:gmatch("[^%s,]+") do
				if w == "click" then click = true else words[#words + 1] = w end
			end
			if #words == 0 then
				L.TourFull({ click = click })
			else
				local ids, label, unknown = L.TourResolve(words)
				if #unknown > 0 then
					L.Say("photo tour: no screen or group called " .. table.concat(unknown, ", ") .. " (groups: ride, drive, float, settings, earnings, video, openmap; or shot ids such as bird / id starts)")
				elseif #ids == 0 then
					L.Say("photo tour: nothing to shoot")
				else
					L.TourStart({ click = click, only = ids, subset = label })
				end
			end
		end
	elseif cmd == "run" or cmd == "test" then
		local a = rest:lower()
		if a == "stop" then
			if not L.RunStop("stopped by the tester") then L.Say("no test run is going") end
		elseif L.RunActive() then
			L.Say("a test run is going (/lab run stop)")
			L.RunPromptUpdate()
		else
			-- "/lab run <scene>" runs that scene alone (e.g. "/lab run emblem"); "all" includes passed checks
			local scene = a ~= "" and a ~= "all" and L.RUN_SCENE_BY_ID and L.RUN_SCENE_BY_ID[a] and a or nil
			runSay(L.RunStart(scene and { scene = scene } or { all = a == "all" }))
		end
	elseif cmd == "skip" then
		L.RunSkip()
	elseif cmd == "wrong" then
		L.RunLookedWrong()
	elseif cmd == "pretend" then
		if rest:lower() == "stop" then
			if L.pretend then L.PretendAbort("stopped by the tester") else L.Say("no pretend ride is going") end
		else
			runSay(L.PretendStart())
		end
	elseif cmd == "logincheck" or cmd == "login" then
		L.Say("login checks again: " .. L.RunLoginChecks() .. " started (see the log)")
	elseif cmd == "results" and rest:lower() == "reset" then
		L.Confirm("Wuber Lab: forget every test run result, so every check runs again?", function() L.RunResetResults() end)
	elseif cmd == "passive" then
		if L.PassiveSlash then L.PassiveSlash(rest) end
	elseif cmd == "trail" then
		if L.TrailSlash then L.TrailSlash(rest) end
	elseif cmd == "huh" then
		if L.Huh then L.Huh(rest) end
	elseif cmd == "f1" then
		if L.F1Slash then L.F1Slash(rest) end
	elseif cmd == "alphaprobe" then
		if L.AlphaProbe then L.AlphaProbe(rest) end
	elseif cmd == "facts" then
		-- (job 129) /lab facts [panel | answers]: Game facts (GameFacts.lua); the Lab bar's "Game facts" button
		if not L.GameFactsSlash then
			L.Say("Game facts isn't loaded: GameFacts.lua is a new file, so close the game fully and start it again")
		else
			L.GameFactsSlash(rest)
		end
	elseif cmd == "slide" then
		-- (job 135) /lab slide [stop | answers]: Slide check (SlideCheck.lua); the Lab bar's "Slide check" button
		if not L.SlideCheckSlash then
			L.Say("Slide check isn't loaded: SlideCheck.lua is a new file, so close the game fully and start it again")
		else
			L.SlideCheckSlash(rest)
		end
	elseif cmd == "portal" then
		-- (job 136) /lab portal: Wuber's Ride page shows the portal for 12 seconds, then goes back (the Lab bar's "Portal turn")
		if not L.PortalTurn then
			L.Say("Portal turn isn't loaded: close the game fully and start it again")
		else
			L.PortalTurn()
		end
	elseif cmd == "resetplan" then
		L.Confirm("Wuber Lab: clear every tick and note of the test plan on all four characters?", function() L.PlanReset() end)
	else
		L.Say(HELP)
	end
	L.RefreshPanel()
end

SLASH_WUBERLAB1 = "/lab"
SLASH_WUBERLAB2 = "/wuberlab"
if type(SlashCmdList) == "table" then
	SlashCmdList.WUBERLAB = function(msg)
		local ok, err = pcall(L.Slash, msg)
		if not ok then L.Bug("/lab", err) end
	end
end

L.OnLogin(function()
	if L.db and L.db.miniShown then L.SetMini(true) end
	L.After(2, function() L.Say("test mode on (developer only). /lab opens the test plan. Role: " .. L.Role()) end)
end)
