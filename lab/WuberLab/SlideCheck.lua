-- Wuber Lab (developer only, never ship): SlideCheck.lua - "does the game cut a child off at a clipping parent's edge when a
-- Translation ANIMATION moves it?" asked of the real game, with one press.
--
-- The question (2.4 work): Wuber's pages will slide in from the right inside the phone. A child is certainly cut off at a
-- SetClipsChildren(true) parent's edge when it is moved by SetPoint; it is NOT known for a Translation animation.
--
-- One press of the Lab bar's "Slide check" (/lab slide) builds, on the first press only, a small stage in the middle of the
-- screen: a dark box 360 x 200 that clips its children, and a bright page inside it. It then runs by itself:
--   move 1  the page starts a full width to the RIGHT and comes in by a Translation animation; half-way it holds 2 s
--           (the animation group is paused) and a screenshot is taken
--   move 2  the same by SetPoint on a per-frame OnUpdate (the reference that is certain to be cut off), hold, screenshot
--   move 3  the mirror: the page leaves to the LEFT by Translation, hold, screenshot
-- During each hold a caption says what to look for, and what the game can say by itself is written down (the group's
-- progress, GetLeft / GetRight / GetScaledRect of the page and of the box, DoesClipChildren), each call guarded.
-- Then ONE question with two buttons: "In move 1, was the bright page cut off at the box's edge?" [Cut off] [Stuck out],
-- and [Show again]. The answer is saved in WuberLabDB.facts.slide (the Game facts entry shape: t, build, line, a) and one
-- line goes to the Lab log (kind "facts"). Not in combat (it then only says so).
--
-- At load this file makes NO frame, NO event and NO timer (Wuber's own tests load the Lab on every branch and their
-- transcripts count them): everything is made on the first press. The stage hides itself in any screenshot that is not its
-- own (the photo tour's), as the Game facts panel does, and the check refuses to start during a tour.
-- Exports: L.SlideCheck (SC), L.SlideCheckSlash(rest).

local _, L = ...

local SC = {}
L.SlideCheck = SC

local secret = L.IsSecret
local BOX_W, BOX_H = 360, 200
local DUR, HOLD = 2, 2 -- seconds: one move; the hold half-way
local S = { runs = 0, mode = nil } -- state of this session

SC.BOX_W, SC.BOX_H, SC.DUR, SC.HOLD = BOX_W, BOX_H, DUR, HOLD
SC.QUESTION = "In move 1, was the bright page cut off at the box's edge?"

-- the three moves: how it moves, where the page starts (x from the box's left edge), what the caption says at the hold
SC.MOVES = {
	{ kind = "anim", startX = BOX_W, label = "Translation animation, coming in from the right",
		page = "MOVE 1 (Translation animation). If you can read this outside the dark box, the page was not cut off.",
		caption = "Move 1, half-way: the Translation animation is paused. Half of the bright page should be hidden: it must stop at the dark box's right edge." },
	{ kind = "tween", startX = BOX_W, label = "SetPoint on an OnUpdate, coming in from the right (the reference)",
		page = "MOVE 2 (SetPoint). This one is certain to be cut off at the box's edge.",
		caption = "Move 2, half-way (moved by SetPoint, the reference): half of the bright page should be hidden: it must stop at the dark box's right edge." },
	{ kind = "anim", startX = 0, label = "Translation animation, leaving to the left",
		page = "MOVE 3 (Translation animation, leaving to the left).",
		caption = "Move 3, half-way: the Translation animation is paused. Half of the bright page should be hidden: it must stop at the dark box's left edge." },
}

---------------------------------------------------------------------------
-- Guarded game calls (every call under pcall, every value tested with issecretvalue)
---------------------------------------------------------------------------

local function pk(...) return { n = select("#", ...), ... } end

local function ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = pk(pcall(fn, ...))
	if not r[1] then return nil end
	local out = { n = r.n - 1 }
	for i = 2, r.n do
		if secret and secret(r[i]) then return nil end
		out[i - 1] = r[i]
	end
	return out
end

-- a method of an object: its first result, or nil when missing, secret or failed
local function call(o, k, ...)
	local f = type(o) == "table" and o[k] or nil
	local r = ask(f, o, ...)
	return r and r[1]
end

local function r1(x) return type(x) == "number" and math.floor(x * 10 + 0.5) / 10 or nil end

local function edges(o)
	return { left = r1(call(o, "GetLeft")), right = r1(call(o, "GetRight")), top = r1(call(o, "GetTop")),
		bottom = r1(call(o, "GetBottom")), width = r1(call(o, "GetWidth")) }
end

local function scaled(o)
	local r = type(o) == "table" and ask(o.GetScaledRect, o) or nil
	if not r or type(r[1]) ~= "number" then return nil end
	return { left = r1(r[1]), bottom = r1(r[2]), width = r1(r[3]), height = r1(r[4]) }
end

local function buildText()
	local r = ask(rawget(_G, "GetBuildInfo"))
	if not r then return "?" end
	return tostring(r[1]) .. " (" .. tostring(r[2]) .. ")"
end

local function say(text)
	if L.Say then L.Say(text) else print(text) end
end

---------------------------------------------------------------------------
-- Saving: WuberLabDB.facts.slide (a list, at most 50), one log line (the Game facts entry shape)
---------------------------------------------------------------------------

function SC.Put(line, a)
	local d = L.db
	if type(d) ~= "table" then return nil end
	if type(d.facts) ~= "table" then d.facts = {} end
	local list = d.facts.slide
	if type(list) ~= "table" then list = {}; d.facts.slide = list end
	local e = { t = math.floor(L.Epoch and L.Epoch() or 0), build = buildText(), line = tostring(line):sub(1, 320), a = a or {} }
	list[#list + 1] = e
	while #list > 50 do table.remove(list, 1) end
	L.Log("facts", "slide: " .. e.line)
	return e
end

function SC.State() return S end -- for the offline test

function SC.Newest()
	local f = L.db and L.db.facts
	local list = type(f) == "table" and f.slide or nil
	if type(list) ~= "table" or #list == 0 then return nil, 0 end
	return list[#list], #list
end

---------------------------------------------------------------------------
-- The stage (made on the first press)
---------------------------------------------------------------------------

local function fillTex(f, r, g, b, al, layer)
	local t = f:CreateTexture(nil, layer or "BACKGROUND")
	t:SetAllPoints(f)
	t:SetColorTexture(r, g, b, al)
	return t
end

local function words(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	if not pcall(fs.SetFont, fs, "Fonts\\ARIALN.TTF", size, "") then pcall(fs.SetFontObject, fs, rawget(_G, "GameFontHighlightSmall")) end
	fs:SetTextColor(r, g, b)
	pcall(fs.SetJustifyH, fs, "LEFT")
	pcall(fs.SetJustifyV, fs, "TOP")
	pcall(fs.SetWordWrap, fs, true)
	return fs
end

local function tip(frame, text)
	frame:SetScript("OnEnter", function(self)
		local gt = rawget(_G, "GameTooltip")
		if gt then pcall(gt.SetOwner, gt, self, "ANCHOR_TOP"); pcall(gt.SetText, gt, text, 1, 1, 1, 1, true); pcall(gt.Show, gt) end
	end)
	frame:SetScript("OnLeave", function() local gt = rawget(_G, "GameTooltip"); if gt then pcall(gt.Hide, gt) end end)
end

local function button(parent, label, w, x, y, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 26)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fillTex(b, 0.18, 0.1, 0.28, 1)
	local lab = words(b, 12, 1, 1, 1)
	lab:SetPoint("CENTER", b, "CENTER", 0, 0)
	pcall(lab.SetJustifyH, lab, "CENTER")
	lab:SetText(label)
	b:SetScript("OnClick", function()
		local gt = rawget(_G, "GameTooltip")
		if gt then pcall(gt.Hide, gt) end
		local ok, err = pcall(onClick)
		if not ok then L.Bug("slide " .. label, err) end
	end)
	tip(b, text)
	return b
end

local PW, PH = 720, 470

local function place(x)
	S.page:ClearAllPoints()
	S.page:SetPoint("TOPLEFT", S.box, "TOPLEFT", x, 0)
end

local function build()
	local f = CreateFrame("Frame", "WuberLabSlideStage", UIParent)
	f:SetSize(PW, PH)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	fillTex(f, 0.16, 0.18, 0.32, 0.97) -- lighter than the box, so a page that sticks out is easy to see
	S.stage = f
	S.title = words(f, 14, 0.8, 0.49, 0.96)
	S.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	S.title:SetWidth(PW - 24)
	S.title:SetText("Slide check (developer only): hands off while it runs, then answer one question")
	-- the clipping box: dark, 360 x 200, in the middle of the stage, with a thin frame drawn outside it
	local box = CreateFrame("Frame", "WuberLabSlideBox", f)
	box:SetSize(BOX_W, BOX_H)
	box:SetPoint("TOP", f, "TOP", 0, -50)
	box:SetClipsChildren(true)
	fillTex(box, 0.03, 0.03, 0.06, 1)
	S.box = box
	local edge = CreateFrame("Frame", nil, f)
	edge:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
	edge:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1))
	fillTex(edge, 0.8, 0.49, 0.96, 1)
	-- the bright page
	local page = CreateFrame("Frame", "WuberLabSlidePage", box)
	page:SetSize(BOX_W, BOX_H)
	fillTex(page, 1, 0.85, 0.2, 1)
	S.pageText = words(page, 16, 0.05, 0.05, 0.05)
	S.pageText:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -14)
	S.pageText:SetWidth(BOX_W - 28)
	S.page = page
	place(BOX_W)
	local g = page:CreateAnimationGroup()
	local tr = g:CreateAnimation("Translation")
	tr:SetOffset(-BOX_W, 0)
	tr:SetDuration(DUR)
	pcall(tr.SetSmoothing, tr, "NONE")
	S.group, S.tr = g, tr
	-- the caption, the question and the buttons
	S.caption = words(f, 14, 1, 1, 1)
	S.caption:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -270)
	S.caption:SetWidth(PW - 80)
	S.caption:SetHeight(60)
	S.ask = words(f, 15, 1, 0.9, 0.4)
	S.ask:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -340)
	S.ask:SetWidth(PW - 80)
	S.ask:SetText(SC.QUESTION)
	S.cut = button(f, "Cut off", 130, 40, -380, "Move 1's bright page was hidden outside the dark box: a Translation animation IS clipped.", function() SC.Answer("cut") end)
	S.stuck = button(f, "Stuck out", 130, 190, -380, "Move 1's bright page showed outside the dark box: a Translation animation is NOT clipped.", function() SC.Answer("stuck") end)
	S.again = button(f, "Show again", 130, 340, -380, "Runs the three moves again.", function() SC.Start(true) end)
	S.close = button(f, "Close", 100, PW - 112, -PH + 40, "Stops the check and closes this stage. Nothing is saved.", function() SC.Stop("closed") end)
	-- out of every screenshot that is not its own (the photo tour's), as the Game facts panel is
	local function back() f:SetAlpha(1) end
	L.Hook("Screenshot", function() if S.mine then return end f:SetAlpha(0); L.After(1.5, back) end)
	L.On("SCREENSHOT_SUCCEEDED", function() if not S.mine then L.After(0.2, back) end end)
	L.On("SCREENSHOT_FAILED", function() if not S.mine then L.After(0.2, back) end end)
	return f
end

local function setMode(mode)
	S.mode = mode
	local asking = mode == "ask"
	for _, w in ipairs({ S.ask, S.cut, S.stuck, S.again }) do
		if asking then w:Show() else w:Hide() end
	end
	if asking then S.page:Hide() else S.page:Show() end
end

---------------------------------------------------------------------------
-- The run: three moves, each with a hold and a screenshot half-way
---------------------------------------------------------------------------

local function shoot(label)
	S.mine = true
	local ok, took, why
	if type(L.PhotoShoot) == "function" then
		ok, took, why = pcall(L.PhotoShoot, label)
	else
		local fn = rawget(_G, "Screenshot")
		if type(fn) ~= "function" then ok, took, why = true, false, "missing"
		else ok, took = pcall(fn); if not ok then why = "error" end end
	end
	S.mine = false
	if not ok then return false, "error" end
	if took then return true end
	return false, why or "error"
end

-- the numbers of the hold: what the game says about the group, the page and the box
local function snap(extra)
	local g = S.group
	local a = { page = edges(S.page), box = edges(S.box), pageScaled = scaled(S.page), boxScaled = scaled(S.box),
		clips = call(S.box, "DoesClipChildren") }
	a.groupProgress = r1(call(g, "GetProgress"))
	a.groupPaused = call(g, "IsPaused")
	a.groupPlaying = call(g, "IsPlaying")
	local p, b = a.page, a.box
	if p.left and p.right and b.left and b.right then
		-- by the layout numbers only: an animation's own offset may not show in GetLeft at all (that is one of the answers)
		a.layoutOutside = r1(math.max(0, p.right - b.right) + math.max(0, b.left - p.left))
	end
	for k, v in pairs(extra or {}) do a[k] = v end
	return a
end

local function finishRun(run)
	run.finished = true
	setMode("ask")
	S.caption:SetText("The three moves are done. Answer from what you saw (the three screenshots are in World of Warcraft\\_forever_\\Screenshots).")
	local m1 = run.moves[1] or {}
	L.Log("facts", ("slide: moves done (run %d); move 1 hold: layout outside %s, progress %s, paused %s"):format(run.id,
		tostring(m1.layoutOutside), tostring(m1.groupProgress), tostring(m1.groupPaused)))
end

local startStep

local function finished(run, i, why)
	if run.dead or run.done[i] then return end
	run.done[i] = true
	if why then run.moves[i] = run.moves[i] or {}; run.moves[i].ended = why end
	S.page:SetScript("OnUpdate", nil)
	if i >= #SC.MOVES then
		L.After(0.6, function() if not run.dead then finishRun(run) end end)
	else
		L.After(0.8, function() startStep(run, i + 1) end)
	end
end

-- the hold: numbers, caption, a screenshot 0.4 s in, then resume after HOLD s (longer when the game wants a click per shot)
local function hold(run, i, resume, extra)
	local mv = SC.MOVES[i]
	run.moves[i] = snap(extra)
	S.caption:SetText(mv.caption)
	local wait = HOLD
	L.After(0.4, function()
		if run.dead then return end
		local took, why = shoot("slide move " .. i)
		run.shots[i] = took and "taken" or tostring(why)
		if not took then
			S.caption:SetText(mv.caption .. " (No screenshot could be taken here: " .. tostring(why) .. ". Take one yourself now.)")
		end
	end)
	-- the screenshot's result is known only after 0.4 s: a refused one gets a longer look
	L.After(wait, function()
		if run.dead then return end
		if run.shots[i] ~= "taken" and not run.extended then
			run.extended = true
			L.After(4, function() if not run.dead then resume() end end)
		else
			resume()
		end
	end)
end

local function startAnim(run, i, mv)
	local g = S.group
	local held = false
	pcall(g.Stop, g)
	place(mv.startX)
	local function doHold(extra)
		if held or run.dead or run.step ~= i then return end
		held = true
		pcall(g.Pause, g)
		hold(run, i, function() if not run.dead then pcall(g.Play, g) end end, extra)
	end
	g:SetScript("OnUpdate", function()
		if not held and (call(g, "GetProgress") or 0) >= 0.5 then doHold() end
	end)
	g:SetScript("OnFinished", function()
		g:SetScript("OnUpdate", nil)
		if run.step == i then finished(run, i) end
	end)
	g:Play()
	-- a group that never reports half: hold anyway (and say so), then the watchdog ends a move that never finishes
	L.After(DUR / 2 + 1, function() doHold({ note = "progress never reached half by itself" }) end)
	L.After(DUR + HOLD + 8, function() if run.step == i then pcall(g.Stop, g); finished(run, i, "watchdog") end end)
end

local function startTween(run, i, mv)
	local t, held, resumed = 0, false, false
	place(mv.startX)
	S.page:SetScript("OnUpdate", function(_, el)
		if run.dead or run.step ~= i then S.page:SetScript("OnUpdate", nil); return end
		if held and not resumed then return end
		t = t + (type(el) == "number" and el or 0)
		local f = math.min(1, t / DUR)
		if f >= 0.5 and not held then
			held = true
			place(mv.startX - BOX_W * 0.5)
			hold(run, i, function() resumed = true end, { tweenProgress = 0.5 })
			return
		end
		place(mv.startX - BOX_W * f)
		if f >= 1 then finished(run, i) end
	end)
	L.After(DUR + HOLD + 8, function() if run.step == i then S.page:SetScript("OnUpdate", nil); finished(run, i, "watchdog") end end)
end

function startStep(run, i)
	if run.dead then return end
	if L.InCombat() then SC.Stop("a fight started"); return end
	local mv = SC.MOVES[i]
	run.step = i
	S.title:SetText("Slide check, move " .. i .. " of " .. #SC.MOVES .. ": " .. mv.label)
	S.pageText:SetText(mv.page)
	S.caption:SetText("Move " .. i .. " is running. Watch the dark box.")
	if mv.kind == "anim" then startAnim(run, i, mv) else startTween(run, i, mv) end
end

---------------------------------------------------------------------------
-- Press, answer, stop
---------------------------------------------------------------------------

function SC.Stop(why)
	local run = S.run
	if run then run.dead = true end
	S.run = nil
	if S.stage then
		pcall(S.group.Stop, S.group)
		S.group:SetScript("OnUpdate", nil)
		S.page:SetScript("OnUpdate", nil)
		S.stage:Hide()
	end
	S.mode = nil
	if why then say("Slide check: " .. why .. ".") end
end

function SC.Start(again)
	if L.InCombat() then say("Slide check: leave combat first. Nothing was started."); return false end
	if L.Touring and L.Touring() then say("Slide check: a photo tour is running. Nothing was started."); return false end
	if S.run and not S.run.dead and S.mode == "run" then say("Slide check: it is already running."); return false end
	if S.run then S.run.dead = true end
	if not S.stage then S.stage = build() end
	S.stage:SetAlpha(1)
	S.stage:Show()
	setMode("run")
	pcall(S.group.Stop, S.group)
	S.runs = S.runs + 1
	local run = { id = S.runs, moves = {}, shots = {}, done = {}, step = 0 }
	S.run = run
	S.title:SetText("Slide check (developer only): hands off while it runs, then answer one question")
	S.caption:SetText("Starting: three moves, about 20 seconds. Hands off.")
	L.After(0.6, function() startStep(run, 1) end)
	return true
end

function SC.Answer(kind)
	local run = S.run
	if not run or not run.finished then return end
	local word = kind == "cut" and "Cut off" or "Stuck out"
	local a = { answer = kind, runs = S.runs, moves = run.moves, shots = run.shots,
		meaning = kind == "cut" and "pages may slide by Translation" or "keep SetPoint" }
	local m1 = run.moves[1] or {}
	SC.Put(("move 1 (Translation, half-way): %s. Hold numbers: group progress %s, paused %s, page left %s right %s, box left %s right %s. Screenshots: %s/%s/%s."):format(
		word, tostring(m1.groupProgress), tostring(m1.groupPaused), tostring(m1.page and m1.page.left), tostring(m1.page and m1.page.right),
		tostring(m1.box and m1.box.left), tostring(m1.box and m1.box.right), tostring(run.shots[1]), tostring(run.shots[2]), tostring(run.shots[3])), a)
	say("Slide check: saved \"" .. word .. "\". " .. (kind == "cut" and "A Translation animation is clipped by its parent: pages may slide by Translation." or "A Translation animation is NOT clipped: keep SetPoint for the slide.") .. " Click Reload to save it to disk.")
	SC.Stop(nil)
end

-- /lab slide [stop | answers]: the Lab bar's "Slide check" button runs the plain "slide"
function L.SlideCheckSlash(rest)
	local a = tostring(rest or ""):lower()
	if a == "stop" then SC.Stop("stopped"); return end
	if a == "answers" or a == "answer" then
		local e, n = SC.Newest()
		say(e and ("Slide check: " .. e.line .. " (" .. n .. " entr" .. (n == 1 and "y" or "ies") .. ")") or "Slide check: not answered yet. Press the Slide check button.")
		return
	end
	if S.stage and S.stage:IsShown() and S.mode == "ask" then SC.Stop(nil); return end -- a second press closes the question
	SC.Start()
end
