-- Wuber Lab (developer only, never ship): the one "Next" prompt of a test run.
--
-- Shown on all four windows while a run goes on. The window whose turn it is reads, in large
-- type, who and the exact thing to click ("Anita: click the big button (it says Summon Wuber)");
-- the others read "Waiting for Anita..." with the same line underneath. It moves on by itself
-- when the judge says pass or fail. Buttons: the step's own (Snap for a look, Pretend I clicked,
-- Start photo tour), Looked wrong (the last step fails, with a screenshot), Skip, Stop.
-- Plain frames, no animation; strata DIALOG (Wuber's big button stays on top of it).

local _, L = ...

local str, call = L.str, L.call

local W_, H_ = 600, 150
local FONT = "Fonts\\ARIALN.TTF"
local C = {
	bg = { 0.055, 0.035, 0.085, 0.97 }, edge = { 0.533, 0.247, 0.855, 1 }, gold = { 0.976, 0.773, 0.243 }, text = { 1, 1, 1 },
	muted = { 0.72, 0.66, 0.8 }, pass = { 0.4, 0.88, 0.5 }, fail = { 1, 0.4, 0.4 }, look = { 0.55, 0.75, 1 },
	btn = { 0.18, 0.1, 0.28, 1 }, btnHi = { 0.3, 0.16, 0.46, 1 }, go = { 0.45, 0.2, 0.7, 1 },
}

local P = {}
L.runPrompt = P

local function rgb(c) return c[1], c[2], c[3], c[4] or 1 end

local function text(parent, size, colour, wrap)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	if not pcall(fs.SetFont, fs, FONT, size, "") then pcall(fs.SetFontObject, fs, GameFontNormal) end
	fs:SetTextColor(rgb(colour))
	pcall(fs.SetJustifyH, fs, "LEFT")
	pcall(fs.SetJustifyV, fs, "TOP")
	pcall(fs.SetWordWrap, fs, wrap and true or false)
	fs:SetText("")
	return fs
end

local function button(parent, label, w, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 24)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	b.bg:SetColorTexture(rgb(C.btn))
	b.label = text(b, 12, C.text)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	pcall(b.label.SetJustifyH, b.label, "CENTER")
	b.label:SetText(label)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(rgb(C.btnHi)) end)
	b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(rgb(self.colour or C.btn)) end)
	b:SetScript("OnClick", function(self)
		local ok, err = pcall(onClick, self)
		if not ok then L.Bug("prompt button " .. label, err) end
		if L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
	end)
	function b.Set(self, t, colour, width)
		self.label:SetText(t)
		self.colour = colour
		self.bg:SetColorTexture(rgb(colour or C.btn))
		if width then self:SetWidth(width) end
	end
	return b
end

local function build()
	if P.frame then return P.frame end
	local f = CreateFrame("Frame", "WuberLabRunPrompt", UIParent)
	P.frame = f
	f:SetSize(W_, H_)
	pcall(f.SetFrameStrata, f, "DIALOG")
	pcall(f.SetClampedToScreen, f, true)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetColorTexture(rgb(C.bg))
	local edge = f:CreateTexture(nil, "BORDER")
	edge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	edge:SetHeight(2)
	edge:SetColorTexture(rgb(C.edge))
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not L.InCombat() then pcall(self.StartMoving, self) end end)
	f:SetScript("OnDragStop", function(self)
		pcall(self.StopMovingOrSizing, self)
		local point, _, rel, x, y = self:GetPoint(1)
		if L.db and type(point) == "string" and type(x) == "number" and type(y) == "number" then
			L.db.runPromptPos = { point = point, rel = type(rel) == "string" and rel or point, x = x, y = y }
		end
	end)
	P.head = text(f, 12, C.gold)
	P.head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
	P.head:SetWidth(W_ - 24)
	P.big = text(f, 19, C.text, true)
	P.big:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -26)
	P.big:SetWidth(W_ - 24)
	pcall(P.big.SetMaxLines, P.big, 2)
	P.sub = text(f, 12, C.muted, true)
	P.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -72)
	P.sub:SetWidth(W_ - 24)
	pcall(P.sub.SetMaxLines, P.sub, 2)
	P.last = text(f, 12, C.pass)
	P.last:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 38)
	P.last:SetWidth(W_ - 24)
	P.action = button(f, "", 170, function() L.RunPress() end)
	P.action:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
	P.no = button(f, "No", 64, function() L.RunAnswer(false) end) -- (a Yes/No step: Yes is the action button)
	P.no:SetPoint("LEFT", P.action, "RIGHT", 6, 0)
	P.no:Hide()
	P.stop = button(f, "Stop", 64, function()
		if L.RunActive() then L.RunStop("stopped by the tester") else P.closed = true end
	end)
	P.stop:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
	P.skip = button(f, "Skip", 64, function() L.RunSkip() end)
	P.skip:SetPoint("RIGHT", P.stop, "LEFT", -6, 0)
	P.wrong = button(f, "Looked wrong", 110, function() L.RunLookedWrong() end)
	P.wrong:SetPoint("RIGHT", P.skip, "LEFT", -6, 0)
	f:ClearAllPoints()
	local p = L.db and L.db.runPromptPos
	if not (type(p) == "table" and pcall(f.SetPoint, f, p.point, UIParent, p.rel, p.x, p.y)) then
		f:SetPoint("TOP", UIParent, "TOP", 0, -36)
	end
	pcall(f.SetScale, f, L.Scale and L.Scale() or 1)
	f:Hide()
	return f
end

-- "{button}" in a click line: the big button's own words on its window, else what it should say.
local function fill(line, c, here)
	if type(line) ~= "string" then return nil end
	if line:find("{button}", 1, true) then
		local b = rawget(_G, "WuberDriveButton")
		local live = here and type(b) == "table" and type(b.plan) == "table" and str(b.plan.title) or nil
		local words = (live or c.buttonText or "?"):gsub("%%", "%%%%")
		line = line:gsub("{button}", words)
	end
	return line
end

local function textOf(c, run, here)
	local ctx = { sim = run.sim, W = L.W(), here = here }
	local click = c.click
	if type(click) == "function" then
		local ok, v = pcall(click, ctx)
		click = ok and v or nil
	end
	local say = c.say
	if type(say) == "function" then
		local ok, v = pcall(say, ctx)
		say = ok and v or nil
	end
	return fill(click, c, here), fill(say, c, here)
end

-- The scene's intro ("Put Wuber Rocks in another zone first"), at its first step in the run.
local function sceneIntro(run, c)
	local s = L.RUN_SCENE_BY_ID[c.scene or ""]
	if not (s and s.intro) then return nil end
	local prev = L.RUN_BY_ID[run.steps[run.index - 1] or ""]
	if prev and prev.scene == c.scene then return nil end
	local intro = s.intro
	if type(intro) == "function" then
		local ok, v = pcall(intro, { sim = run.sim })
		intro = ok and v or nil
	end
	return type(intro) == "string" and ("First: " .. intro) or nil
end

local function remaining(run)
	local secs = 0
	for i = run.index, #run.steps do
		local c = L.RUN_BY_ID[run.steps[i]]
		secs = secs + (c and c.secs or 0)
	end
	return math.max(1, math.ceil(secs / 60))
end

local function counts(run)
	local n = { pass = 0, fail = 0, look = 0, skip = 0 }
	for _, rec in pairs(run.results or {}) do n[rec.r] = (n[rec.r] or 0) + 1 end
	return n
end

local function lastLine(run)
	local st = L.runState
	local r = st and st.lastResult
	if not r or not run.results[r.id] then return "", C.muted end
	local word = ({ pass = "OK", fail = "FAIL", look = "LOOK", skip = "SKIP" })[r.r] or r.r
	local c = L.RUN_BY_ID[r.id]
	local name = c and c.title or r.id
	return ("Last: %s  %s: %s%s"):format(word, name, tostring(r.why or ""), r.took and (" (" .. ("%.1f"):format(r.took) .. " s)") or ""),
		r.r == "fail" and C.fail or (r.r == "pass" and C.pass or C.look)
end

function L.RunPromptUpdate()
	if L.photo or L.Now() < (L.labHiddenUntil or 0) then return end -- (out of the screenshots)
	local d = L.db
	local run = d and d.run
	local me = L.RunMyRole()
	if not me or type(run) ~= "table" or not run.steps or (run.ended and (P.closed or L.Epoch() - run.ended > 3600)) then
		if P.frame then P.frame:Hide() end
		return
	end
	local f = build()
	if not run.ended then P.closed = nil end
	pcall(f.SetScale, f, L.Scale and L.Scale() or 1)
	local last, lastColour = lastLine(run)
	P.last:SetText(last)
	P.last:SetTextColor(rgb(lastColour))
	if run.ended then
		local n = counts(run)
		P.head:SetText(("TEST RUN %s  \194\183  %d passed, %d failed, %d to look at, %d skipped"):format(run.why == "done" and "done" or "stopped",
			n.pass, n.fail, n.look, n.skip))
		P.big:SetText("Done: log out or /reload, then tell the person running the test \"done\".")
		P.sub:SetText(run.why ~= "done" and ("(" .. tostring(run.why) .. ")") or "The results are in WuberLabDB: the game writes them at logout or /reload.")
		P.action:Hide()
		P.no:Hide()
		P.skip:Hide()
		P.stop:Set("Close")
		P.wrong:Show()
		f:Show()
		return
	end
	local id = run.steps[run.index]
	local c = L.RUN_BY_ID[id or ""]
	if not c then
		P.head:SetText("TEST RUN")
		P.big:SetText("Waiting...")
		P.sub:SetText("")
		f:Show()
		return
	end
	local here = c.who == me
	local click, say = textOf(c, run, here)
	local who = L.RunShort(c.who)
	local st = L.runState
	local left = st and st.stepAt and math.max(0, math.floor(c.timeout - (L.Now() - st.stepAt) + 0.5)) or nil
	P.head:SetText(("TEST RUN  \194\183  step %d of %d  \194\183  about %d min left%s"):format(run.index, #run.steps, remaining(run),
		run.sim and "  \194\183  test mode (no shards)" or ""))
	local line
	if click then
		line = who .. ": " .. click
	elseif c.kind == "skip" then
		line = who .. ": skipped - " .. tostring(say or "")
	else
		line = who .. ": nothing to click - " .. tostring(say or "wait")
	end
	local intro = sceneIntro(run, c)
	local ask = here and c.ask and L.RunAsk and L.RunAsk(st and st.stepCtx) or nil
	if here then
		P.big:SetText(line)
		P.big:SetTextColor(rgb(C.text))
		local tail = c.kind == "look" and "a reviewer looks at the screenshot" or (left and ("checks itself  \194\183  " .. left .. " s left") or "checks itself")
		if ask then tail = ask .. "  (Yes / No)" end
		P.sub:SetText((intro and (intro .. "\n") or "") .. ((click and say) and (say .. "  \194\183  " .. tail) or tail))
	else
		P.big:SetText("Waiting for " .. who .. "...")
		P.big:SetTextColor(rgb(C.muted))
		P.sub:SetText((intro and (intro .. "\n") or "") .. line)
	end
	local btn = c.button
	if here and type(btn) == "table" and (btn.show == nil or btn.show(run)) then
		P.action:Set(btn.label or "Do it", C.go)
		P.action:Show()
	elseif ask then
		P.action:Set("Yes", C.go)
		P.action:Show()
	else
		P.action:Hide()
	end
	if ask and not btn then P.no:Show() else P.no:Hide() end
	P.skip:Show()
	P.stop:Set("Stop")
	f:Show()
end

L.runEndFns = L.runEndFns or {}

L.OnLogin(function()
	L.Every(1, function()
		if L.RunActive() or (P.frame and P.frame:IsShown()) then L.RunPromptUpdate() end
	end)
end)
