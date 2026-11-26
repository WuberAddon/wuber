-- Wuber Lab (developer only, never ship): AutoSteps4.lua, the Auto check screen "a_anim" (job 2630, item 12). DRAFT.
--
-- What it settles in the REAL game (nothing here is known from source; the notes' rows 27 to 33 are engine questions):
--   E1  the alpha of a frame half-way through a 0.4 s Alpha animation (GetAlpha and GetEffectiveAlpha, 40 readings), with and without
--       SetToFinalAlpha, at the finish and 0.3 s later; the progress calls (group and animation GetProgress, GetSmoothProgress, IsPlaying)
--   E2  whether a Translation moves what GetLeft / GetCenter / GetPoint say, while it plays, at the finish, 0.3 s after
--   E3  a group played on a frame that is HIDDEN (hidden parent): IsPlaying at once and after 0.15 s, does OnFinished ever come, when
--   E4  a group whose frame is hidden half-way through and shown again: the events (OnPlay / OnPause / OnStop / OnFinished) with times,
--       IsPlaying while hidden, after showing, and when OnFinished comes
--   E5  does OnUpdate run on a frame hidden through its parent, on a frame hidden itself, on a shown frame (counts in 1 s), GetOnUpdateMode
--   E6  the spread of OnUpdate elapsed values over 2 s (n, min, max, mean, distinct values) and GetFramerate()
--   E7  C_Timer.After(0): how many OnUpdate calls come between the call and the callback (ten tries), and After(0.05) the same
--   E8  type() of what C_Timer.NewTicker, NewTimer and After return, and of the argument their callbacks get; whether Cancel / IsCancelled exist
--   E9  which names the Scale animation has (SetScaleFrom / SetScaleTo / SetFromScale / SetToScale / SetScale) and the animation-group methods
--       the notes call missing in the fake (GetAnimationSpeedMultiplier, IsReverse, RemoveAnimations, ...) as type() only
--
-- Which kind of check, and why: an AUTO CHECK screen (like a_keybinding in AutoSteps3.lua): it runs by itself in the Auto check, needs no
-- step from the player, and has a ready(W) state machine for things that take seconds. It builds its own throwaway frames (children of two
-- holders it makes itself, one shown, one hidden; never Wuber's), plays only its own animation groups, sends nothing, sets no cvar, hooks
-- nothing, makes no protected call (so combat changes nothing but the Auto check stops itself in combat anyway), and takes every frame and
-- every group down again at the end (scripts cleared, groups stopped, holders hidden).
--
-- How the answer is kept: every measurement is plain data in ONE Game facts entry, id "ANIM", WuberLabDB.facts.ANIM[n].a (G.Put in GameFacts.lua),
-- and each screen result is an "info" line (stored by the Auto check because it is not a pass) with the short words; "skip" when a call is missing.
-- The importer (../13-facts-census/import_facts.lua --id ANIM) writes tests/fixtures/rec/anim-<build>.lua = { build, a = <the entry> }, which
-- proof_test.lua (fgp 12b to 12d) compares the fake against. Needs the Lab to load this file after AutoSteps3.lua (WuberLab.toc).
-- No step id: it replaces no hand step by itself (the in-game checks it makes unnecessary are in README.md part f).

local _, L = ...

local K = L.PhotoKit
local str, num, plain = L.str, L.num, L.plain

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end
local function fn(t, k) return type(t) == "table" and type(t[k]) == "function" end
local function result(name, status, detail, step)
	return { name = name, status = status, detail = detail, steps = step and { step } or nil }
end

-- o:k(...) -> its first result, plain; nil when missing, failed or secret
local function m(o, k, ...)
	if not fn(o, k) then return nil end
	local ok, a = pcall(o[k], o, ...)
	if not ok then return nil end
	return plain(a)
end
local function r2(x) x = num(x) return x and math.floor(x * 100 + 0.5) / 100 or nil end
local function r3(x) x = num(x) return x and math.floor(x * 1000 + 0.5) / 1000 or nil end
local function now() return L.Now() end

local MAX_SECS = 9 -- everything is over by then, ready() says so anyway

---------------------------------------------------------------------------
-- The experiments (each one books itself in D.open and closes itself)
---------------------------------------------------------------------------

local function holder(shown)
	local h = CreateFrame("Frame", nil, UIParent)
	h:SetSize(1, 1)
	h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	h:SetFrameStrata("BACKGROUND")
	if shown then h:Show() else h:Hide() end
	return h
end

local function events(g, r, t0)
	for _, name in ipairs({ "OnPlay", "OnPause", "OnStop", "OnFinished", "OnLoop" }) do
		pcall(g.SetScript, g, name, function() r.ev[#r.ev + 1] = { r2(now() - t0()), name } end)
	end
end

-- E1: Alpha 1 -> 0 over 0.4 s, read on every OnUpdate
local function alphaRun(D, name, final)
	local r = { name = name, final = final, dur = 0.4, from = 1, to = 0, s = {}, ev = {} }
	D.a.alpha[#D.a.alpha + 1] = r
	D.open = D.open + 1
	local f = CreateFrame("Frame", nil, D.vis)
	D.frames[#D.frames + 1] = f
	f:SetSize(20, 20)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 300)
	f:SetAlpha(1)
	f:Show()
	local g = f:CreateAnimationGroup()
	D.groups[#D.groups + 1] = g
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0)
	a:SetDuration(0.4)
	if final then pcall(g.SetToFinalAlpha, g, true) end
	local t0
	events(g, r, function() return t0 or now() end)
	local function reading() return { a = r2(m(f, "GetAlpha")), ea = r2(m(f, "GetEffectiveAlpha")) } end
	f:SetScript("OnUpdate", function()
		if not t0 or #r.s >= 40 then return end
		local row = reading()
		row.t = r2(now() - t0)
		row.gp, row.ap, row.asp, row.pl = r2(m(g, "GetProgress")), r2(m(a, "GetProgress")), r2(m(a, "GetSmoothProgress")), m(g, "IsPlaying")
		r.s[#r.s + 1] = row
	end)
	pcall(g.SetScript, g, "OnFinished", function()
		r.ev[#r.ev + 1] = { r2(now() - t0), "OnFinished" }
		r.atFinish = reading()
		L.After(0.3, function()
			r.after = reading()
			r.after.pl = m(g, "IsPlaying")
			D.close()
		end)
	end)
	t0 = now()
	r.base = reading()
	g:Play()
	r.playing = m(g, "IsPlaying")
end

-- E2: a Translation of 100 to the right over 0.4 s: does what the frame says about its place move?
local function transRun(D)
	local r = { dur = 0.4, dx = 100, s = {}, ev = {} }
	D.a.trans = r
	D.open = D.open + 1
	local f = CreateFrame("Frame", nil, D.vis)
	D.frames[#D.frames + 1] = f
	f:SetSize(20, 20)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 200)
	f:Show()
	local g = f:CreateAnimationGroup()
	D.groups[#D.groups + 1] = g
	local a = g:CreateAnimation("Translation")
	a:SetOffset(100, 0)
	a:SetDuration(0.4)
	local t0
	events(g, r, function() return t0 or now() end)
	local function reading()
		local cx
		local okc, c1 = pcall(f.GetCenter, f)
		if okc then cx = plain(c1) end
		local okp, _, _, _, p4, p5 = pcall(f.GetPoint, f, 1)
		return { l = r2(m(f, "GetLeft")), cx = r2(cx), px = okp and r2(p4) or nil, py = okp and r2(p5) or nil }
	end
	f:SetScript("OnUpdate", function()
		if not t0 or #r.s >= 40 then return end
		local row = reading()
		row.t = r2(now() - t0)
		r.s[#r.s + 1] = row
	end)
	pcall(g.SetScript, g, "OnFinished", function()
		r.ev[#r.ev + 1] = { r2(now() - t0), "OnFinished" }
		r.atFinish = reading()
		L.After(0.3, function()
			r.after = reading()
			D.close()
		end)
	end)
	r.base = reading()
	t0 = now()
	g:Play()
end

-- E3: a group played on a frame whose PARENT is hidden
local function hiddenRun(D)
	local r = { dur = 0.3, ev = {} }
	D.a.hiddenPlay = r
	D.open = D.open + 1
	local f = CreateFrame("Frame", nil, D.hid)
	D.frames[#D.frames + 1] = f
	f:SetSize(20, 20)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 400, 300)
	r.visible = m(f, "IsVisible")
	local g = f:CreateAnimationGroup()
	D.groups[#D.groups + 1] = g
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0)
	a:SetDuration(0.3)
	local t0 = now()
	events(g, r, function() return t0 end)
	g:Play()
	r.playingAtOnce = m(g, "IsPlaying")
	L.After(0.15, function() r.playing150 = m(g, "IsPlaying") r.progress150 = r2(m(g, "GetProgress")) end)
	L.After(1.0, function()
		r.playing1000 = m(g, "IsPlaying")
		r.done = m(g, "IsDone")
		for _, e in ipairs(r.ev) do if e[2] == "OnFinished" then r.finishedAt = e[1] end end
		D.close()
	end)
end

-- E4: a group whose frame is hidden half-way through (0.2 s of 0.8 s) and shown again at 0.6 s
local function midHideRun(D)
	local r = { dur = 0.8, hideAt = 0.2, showAt = 0.6, ev = {} }
	D.a.midHide = r
	D.open = D.open + 1
	local f = CreateFrame("Frame", nil, D.vis)
	D.frames[#D.frames + 1] = f
	f:SetSize(20, 20)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 300)
	f:Show()
	local g = f:CreateAnimationGroup()
	D.groups[#D.groups + 1] = g
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0)
	a:SetDuration(0.8)
	local t0 = now()
	events(g, r, function() return t0 end)
	g:Play()
	L.After(0.2, function() f:Hide() end)
	L.After(0.4, function() r.playingHidden = m(g, "IsPlaying") r.progressHidden = r2(m(g, "GetProgress")) end)
	L.After(0.6, function() f:Show() end)
	L.After(0.65, function() r.playingShown = m(g, "IsPlaying") r.progressShown = r2(m(g, "GetProgress")) end)
	L.After(1.6, function()
		r.playingEnd = m(g, "IsPlaying")
		for _, e in ipairs(r.ev) do if e[2] == "OnFinished" then r.finishedAt = e[1] end end
		D.close()
	end)
end

-- E5: OnUpdate on a frame hidden through its parent, hidden itself, shown (counts over 1 s)
local function updateRun(D)
	local r = {}
	D.a.onUpdate = r
	D.open = D.open + 1
	local function counter(parent, hideSelf)
		local f = CreateFrame("Frame", nil, parent)
		D.frames[#D.frames + 1] = f
		f:SetSize(1, 1)
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
		if hideSelf then f:Hide() else f:Show() end
		local box = { n = 0, f = f }
		f:SetScript("OnUpdate", function() box.n = box.n + 1 end)
		return box
	end
	local viaParent, selfHidden, visible = counter(D.hid, false), counter(D.vis, true), counter(D.vis, false)
	r.mode = str(m(visible.f, "GetOnUpdateMode"))
	r.modeHidden = str(m(viaParent.f, "GetOnUpdateMode"))
	L.After(1.0, function()
		r.hiddenParent, r.hiddenSelf, r.shown = viaParent.n, selfHidden.n, visible.n
		D.close()
	end)
end

-- E6: the OnUpdate elapsed values over 2 s; E7: C_Timer.After(0) against OnUpdate
local function spreadRun(D)
	local r = { n = 0 }
	D.a.spread = r
	D.open = D.open + 1
	local f = CreateFrame("Frame", nil, D.vis)
	D.frames[#D.frames + 1] = f
	f:SetSize(1, 1)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	f:Show()
	local seen, values, sum, mn, mx, distinct = 0, {}, 0, nil, nil, 0
	local t0 = now()
	local frames = 0
	local t7 = { hist = { [0] = 0, [1] = 0, [2] = 0, more = 0 }, tries = 0, hist05 = { [0] = 0, [1] = 0, [2] = 0, more = 0 }, tries05 = 0 }
	D.a.timer0 = t7
	local waiting, waiting05 = false, false
	local function bump(h, d) if d <= 2 then h[d] = h[d] + 1 else h.more = h.more + 1 end end
	f:SetScript("OnUpdate", function(_, elapsed)
		frames = frames + 1
		elapsed = num(elapsed)
		if elapsed and now() - t0 <= 2 then
			r.n = r.n + 1
			sum = sum + elapsed
			mn = (not mn or elapsed < mn) and elapsed or mn
			mx = (not mx or elapsed > mx) and elapsed or mx
			local k = r3(elapsed)
			if not values[k] then values[k] = true distinct = distinct + 1 end
		end
		if t7.tries < 10 and not waiting then
			waiting = true
			t7.tries = t7.tries + 1
			local at = frames
			pcall(C_Timer.After, 0, function() bump(t7.hist, frames - at) waiting = false end)
		end
		if t7.tries05 < 10 and not waiting05 then
			waiting05 = true
			t7.tries05 = t7.tries05 + 1
			local at = frames
			pcall(C_Timer.After, 0.05, function() bump(t7.hist05, frames - at) waiting05 = false end)
		end
	end)
	L.After(2.2, function()
		r.min, r.max, r.mean, r.distinct = r3(mn), r3(mx), r.n > 0 and r3(sum / r.n) or nil, distinct
		r.fps = r2(plain(L.call(rawget(_G, "GetFramerate"))))
		D.close()
	end)
end

-- E8, E9: types only
local function typesRun(D)
	local ct = rawget(_G, "C_Timer")
	local r = { ct = type(ct) }
	D.a.types = r
	if type(ct) == "table" then
		local got = {}
		local okT, tk = pcall(ct.NewTicker, 0.05, function(self) got.tickerArg = type(self) end, 2)
		r.ticker = okT and type(tk) or "error"
		r.tickerCancel, r.tickerIsCancelled = fn(tk, "Cancel"), fn(tk, "IsCancelled")
		local okM, tm = pcall(ct.NewTimer, 0.05, function(self) got.timerArg = type(self) end)
		r.timer = okM and type(tm) or "error"
		r.timerCancel, r.timerIsCancelled = fn(tm, "Cancel"), fn(tm, "IsCancelled")
		local okA, af = pcall(ct.After, 0.05, function(...) got.afterArgs = select("#", ...) end)
		r.after = okA and type(af) or "error"
		D.open = D.open + 1
		L.After(0.4, function()
			r.tickerArg, r.timerArg, r.afterArgs = got.tickerArg, got.timerArg, got.afterArgs
			D.close()
		end)
	end
	local f = CreateFrame("Frame", nil, D.vis)
	D.frames[#D.frames + 1] = f
	local g = f:CreateAnimationGroup()
	D.groups[#D.groups + 1] = g
	local sc = g:CreateAnimation("Scale")
	local names = {}
	for _, n in ipairs({ "SetScaleFrom", "SetScaleTo", "SetFromScale", "SetToScale", "SetScale", "SetOrigin", "GetScale" }) do names[n] = type(sc[n]) end
	r.scaleNames = names
	local gm = {}
	for _, n in ipairs({ "GetAnimationSpeedMultiplier", "SetAnimationSpeedMultiplier", "IsReverse", "RemoveAnimations", "SetPlaying", "GetLoopState",
		"IsPendingFinish", "GetProgress", "Finish", "SetToFinalAlpha", "IsSetToFinalAlpha", "SetIgnoreFramerateThrottle" }) do gm[n] = type(g[n]) end
	r.groupMethods = gm
	local am = {}
	for _, n in ipairs({ "GetProgress", "GetSmoothProgress", "GetElapsed", "IsDone", "IsPlaying", "IsStopped", "SetSmoothProgress", "GetSmoothing" }) do am[n] = type(sc[n]) end
	r.animMethods = am
end

local function takeDown(D)
	for _, g in ipairs(D.groups) do pcall(g.SetScript, g, "OnFinished", nil) pcall(g.Stop, g) end
	for _, f in ipairs(D.frames) do pcall(f.SetScript, f, "OnUpdate", nil) pcall(f.Hide, f) end
	if D.vis then pcall(D.vis.Hide, D.vis) end
	if D.hid then pcall(D.hid.Hide, D.hid) end
	D.groups, D.frames = {}, {}
end

local function start(D)
	D.a = { alpha = {} }
	D.open, D.groups, D.frames = 0, {}, {}
	D.close = function()
		D.open = D.open - 1
		if D.open <= 0 and not D.done then D.done, D.fin = true, now() end
	end
	D.t0 = now()
	D.vis, D.hid = holder(true), holder(false)
	D.open = 1 -- (held until every experiment is booked)
	for _, run in ipairs({
		function() alphaRun(D, "plain", false) end,
		function() alphaRun(D, "final", true) end,
		function() transRun(D) end, function() hiddenRun(D) end, function() midHideRun(D) end, function() updateRun(D) end,
		function() spreadRun(D) end, function() typesRun(D) end,
	}) do
		local ok, err = pcall(run)
		if not ok then D.errs = D.errs or {} D.errs[#D.errs + 1] = tostring(err):sub(1, 160) end
	end
	D.close()
	-- a hard stop whatever happens
	L.After(MAX_SECS, function() if not D.done then D.done, D.timeout = true, true end end)
end

---------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------

-- classes the fake's test compares: where a reading sits between the start and the end value
local function band(v, from, to)
	v = num(v)
	if not v then return "none" end
	local lo, hi = math.min(from, to), math.max(from, to)
	if v <= lo + 0.02 then return v == from and "from" or "to" end
	if v >= hi - 0.02 then return v == to and "to" or "from" end
	return "between"
end

screen({ id = "a_anim", side = "rider", maxWait = 14,
	title = "Animations in the real game: alpha half-way, translation, hidden frames, OnUpdate steps, C_Timer (throwaway frames; measured, nothing judged)",
	run = function() return true end,
	ready = function(W)
		local D = data()
		D.anim = D.anim or { phase = 0 }
		local d = D.anim
		if d.phase == 0 then
			d.phase = 1
			local ok, err = pcall(start, d)
			if not ok then d.startErr = tostring(err):sub(1, 200) d.done = true end
			return false
		end
		return d.done == true
	end,
	verify = function(W)
		local d = (data().anim) or {}
		local out = {}
		if d.startErr then return { result("anim", "look", "the check itself broke: " .. d.startErr) } end
		if not d.a then return "skip", "the animation check did not start" end
		takeDown(d)
		local a = d.a
		a.build = (function() local okB, v, b = pcall(rawget(_G, "GetBuildInfo") or function() end) return okB and (tostring(plain(v)) .. " (" .. tostring(plain(b)) .. ")") or "?" end)()
		a.timeout = d.timeout or nil
		a.errs = d.errs
		-- the words, one line per experiment
		for _, r in ipairs(a.alpha) do
			local mid
			for _, row in ipairs(r.s) do if row.t and row.t >= 0.18 and not mid then mid = row end end
			r.mid = mid
			if mid then
				r.midBand = { a = band(mid.a, r.from, r.to), ea = band(mid.ea, r.from, r.to) }
			end
			out[#out + 1] = result("alpha " .. r.name, "info", ("Alpha 1 to 0 over 0.4 s%s: at %.2f s GetAlpha %s (%s), GetEffectiveAlpha %s (%s); at the finish %s / %s; 0.3 s later %s / %s; %d readings"):format(
				r.final and " with SetToFinalAlpha" or "", mid and mid.t or -1, tostring(mid and mid.a), r.midBand and r.midBand.a or "-", tostring(mid and mid.ea),
				r.midBand and r.midBand.ea or "-", tostring(r.atFinish and r.atFinish.a), tostring(r.atFinish and r.atFinish.ea),
				tostring(r.after and r.after.a), tostring(r.after and r.after.ea), #r.s))
		end
		local t = a.trans
		if t then
			local lo, hi
			for _, row in ipairs(t.s) do
				if row.l then lo = (not lo or row.l < lo) and row.l or lo hi = (not hi or row.l > hi) and row.l or hi end
			end
			t.moves = (lo and hi and hi - lo > 1) or false
			t.leftBase, t.leftAfter = t.base and t.base.l, t.after and t.after.l
			out[#out + 1] = result("translation", "info", ("Translation of 100 over 0.4 s: GetLeft base %s, while playing %s to %s (%s), 0.3 s after the finish %s"):format(
				tostring(t.leftBase), tostring(lo), tostring(hi), t.moves and "it MOVES" or "it does not move", tostring(t.leftAfter)))
		end
		local h = a.hiddenPlay
		if h then
			out[#out + 1] = result("hidden frame", "info", ("group played on a hidden frame (IsVisible %s): IsPlaying at once %s, at 0.15 s %s, at 1 s %s; OnFinished at %s; IsDone %s"):format(
				tostring(h.visible), tostring(h.playingAtOnce), tostring(h.playing150), tostring(h.playing1000), tostring(h.finishedAt), tostring(h.done)))
		end
		local mh = a.midHide
		if mh then
			local evs = {}
			for _, e in ipairs(mh.ev) do evs[#evs + 1] = e[2] .. "@" .. tostring(e[1]) end
			out[#out + 1] = result("hidden mid-play", "info", ("hidden at 0.2 s, shown at 0.6 s of 0.8 s: IsPlaying while hidden %s (progress %s), after showing %s (progress %s), at 1.6 s %s; events %s"):format(
				tostring(mh.playingHidden), tostring(mh.progressHidden), tostring(mh.playingShown), tostring(mh.progressShown), tostring(mh.playingEnd), table.concat(evs, " ")))
		end
		local u = a.onUpdate
		if u then
			out[#out + 1] = result("OnUpdate hidden", "info", ("OnUpdate calls in 1 s: shown frame %s, hidden through its parent %s, hidden itself %s; GetOnUpdateMode %s"):format(
				tostring(u.shown), tostring(u.hiddenParent), tostring(u.hiddenSelf), tostring(u.mode)))
		end
		local sp = a.spread
		if sp then
			out[#out + 1] = result("OnUpdate steps", "info", ("elapsed over 2 s: %d calls, min %s, max %s, mean %s, %d different values; GetFramerate %s"):format(
				sp.n or 0, tostring(sp.min), tostring(sp.max), tostring(sp.mean), sp.distinct or 0, tostring(sp.fps)))
		end
		local t7 = a.timer0
		if t7 then
			local function h(x) return ("0:%d 1:%d 2:%d more:%d"):format(x[0], x[1], x[2], x.more) end
			out[#out + 1] = result("C_Timer.After", "info", ("OnUpdate calls between the call and the callback, After(0) over %d tries: %s; After(0.05) over %d: %s"):format(
				t7.tries, h(t7.hist), t7.tries05, h(t7.hist05)))
		end
		local ty = a.types
		if ty then
			out[#out + 1] = result("C_Timer types", "info", ("NewTicker -> %s (Cancel %s, IsCancelled %s), NewTimer -> %s, After -> %s; callback args: ticker %s timer %s after %s"):format(
				tostring(ty.ticker), tostring(ty.tickerCancel), tostring(ty.tickerIsCancelled), tostring(ty.timer), tostring(ty.after),
				tostring(ty.tickerArg), tostring(ty.timerArg), tostring(ty.afterArgs)))
			local sn = ty.scaleNames or {}
			out[#out + 1] = result("Scale names", "info", ("Scale animation: SetScaleFrom %s SetScaleTo %s SetFromScale %s SetToScale %s SetScale %s"):format(
				tostring(sn.SetScaleFrom), tostring(sn.SetScaleTo), tostring(sn.SetFromScale), tostring(sn.SetToScale), tostring(sn.SetScale)))
		end
		local G = L.GameFacts
		if type(G) == "table" and type(G.Put) == "function" then
			G.Put("ANIM", ("animation facts: alpha mid %s, translation %s, hidden frame playing %s, OnUpdate hidden %s"):format(
				tostring(a.alpha[1] and a.alpha[1].midBand and a.alpha[1].midBand.ea), tostring(t and t.moves), tostring(h and h.playing150), tostring(u and u.hiddenParent)), a)
		else
			out[#out + 1] = result("saved", "skip", "no Game facts store (GameFacts.lua not loaded): the numbers are in the lines above only")
		end
		if #out == 0 then return "skip", "nothing was measured" end
		return out
	end })
