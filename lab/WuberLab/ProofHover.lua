-- Wuber Lab (developer only, never ship): ProofHover.lua - read-only in-game hover checks.
--
-- Proves in the real client what the fake game already checked:
--   1. a_proof_hover_raised    Settings > Drive row buttons (coach, drive.resetPos, drive.bellTest, drive.bellForget)
--                              keep their "raised" fill after the mouse enters and leaves (through the topmost frame).
--   2. a_proof_hover_owncolour A pill whose screen gave its label its own colour ("Hide this driver" in the driver
--                              card right-click menu, red) keeps that colour during and after hover.
--
-- Read-only: changes nothing, sends nothing, runs only out of combat, and puts every widget and setting back.
-- At load this file makes NO frame, event, or timer.
-- New file: needs a full game restart (a /reload does not find it).

local _, L = ...

local K = L.PhotoKit
local str, num = L.str, L.num
local fn = K and K.fn or function(t, k) return type(t) == "table" and type(t[k]) == "function" end

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	if type(SCREENS) ~= "table" then return s end
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end

local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end

local function runOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if not s then return "the tour has no screen " .. id end
		return s.run(W, view)
	end
end

local function result(name, status, detail)
	return { name = name, status = status, detail = detail }
end

local function callm(o, name, ...)
	if type(o) ~= "table" or not fn(o, name) then return nil end
	local r = { pcall(o[name], o, ...) }
	if not r[1] then return nil end
	return unpack(r, 2)
end

local function isTrue(o, name)
	local v = callm(o, name)
	local sec = rawget(_G, "issecretvalue")
	if type(sec) == "function" and sec(v) then return false end
	return v == true
end

local function inCombat()
	local icl = rawget(_G, "InCombatLockdown")
	return type(icl) == "function" and pcall(icl) and icl() == true
end

local function script(f, name)
	if type(f) ~= "table" or not fn(f, "GetScript") then return nil end
	local h = callm(f, "GetScript", name)
	return type(h) == "function" and h or nil
end

---------------------------------------------------------------------------
-- Topmost frame hit-testing (mirrors AutoSteps7.lua)
---------------------------------------------------------------------------

local STRATA = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local function rectOf(f, up)
	if type(f) ~= "table" then return nil end
	local l, r, t, b = num(callm(f, "GetLeft")), num(callm(f, "GetRight")), num(callm(f, "GetTop")), num(callm(f, "GetBottom"))
	if not (l and r and t and b) then return nil end
	local s = num(callm(f, "GetEffectiveScale")) or 1
	local us = (up and num(callm(up, "GetEffectiveScale"))) or 1
	if us <= 0 then us = 1 end
	local k = s / us
	return { l = l * k, r = r * k, t = t * k, b = b * k }
end

local function gather(W)
	local up = rawget(_G, "UIParent")
	local list, par, index = {}, {}, {}
	local seen = {}
	local function add(f, p)
		if type(f) ~= "table" or seen[f] then return end
		seen[f] = true
		index[f] = #list + 1
		list[#list + 1] = f
		par[f] = p
		local kids = { callm(f, "GetChildren") }
		for _, k in ipairs(kids) do add(k, f) end
	end
	local roots = { up }
	if type(W) == "table" and type(W.UI) == "table" then
		local st = W.UI.state
		if type(st) == "table" and type(st.win) == "table" then roots[#roots + 1] = st.win end
	end
	for _, r in ipairs(roots) do add(r, nil) end
	local function owned(f)
		local n, cur = 0, f
		while cur and n < 60 do
			if cur == up then return true end
			cur = par[cur]
			n = n + 1
		end
		return true
	end
	return { up = up, list = list, par = par, index = index, owned = owned }
end

local function chainOf(w, f)
	local c, n = {}, 0
	while f and n < 60 do c[#c + 1] = f; f = w.par[f]; n = n + 1 end
	return c
end

local function clips(f) return callm(f, "DoesClipChildren") == true end

local function standIn(w, chain, stop)
	local who
	for i = 1, #chain do
		local g = chain[i]
		if g == stop then break end
		if i > 1 and clips(g) then who = g end
	end
	return who or chain[1], who ~= nil
end

local function hitKey(f)
	local s = STRATA[str(callm(f, "GetFrameStrata")) or "MEDIUM"] or 3
	return s * 1e5 + (num(callm(f, "GetFrameLevel")) or 0)
end

local function above(w, a, b)
	local ca, cb = chainOf(w, a), chainOf(w, b)
	local inB = {}
	for _, g in ipairs(cb) do inB[g] = true end
	local lca
	for _, g in ipairs(ca) do if inB[g] then lca = g break end end
	local ra, clipA = standIn(w, ca, lca)
	local rb, clipB = standIn(w, cb, lca)
	if ra ~= rb then
		local ka, kb = hitKey(ra), hitKey(rb)
		if ka ~= kb then return ka > kb end
		if clipA ~= clipB then return clipB end
	end
	local ka, kb = hitKey(a), hitKey(b)
	if ka ~= kb then return ka > kb end
	return (w.index[a] or 0) > (w.index[b] or 0)
end

local function cutOff(w, f, x, y)
	local p, n = w.par[f], 0
	while p and n < 60 do
		if clips(p) then
			local r = rectOf(p, w.up)
			if not r or x < r.l or x > r.r or y < r.b or y > r.t then return true end
		end
		p, n = w.par[p], n + 1
	end
	return false
end

local function framesAt(w, x, y)
	local cands = {}
	for _, f in ipairs(w.list) do
		local fname = str(callm(f, "GetName"))
		if (not fname or not fname:find("^WuberLab")) and isTrue(f, "IsMouseEnabled") and isTrue(f, "IsVisible") and w.owned(f) then
			local r = rectOf(f, w.up)
			if r then
				local il, ir, it, ib = callm(f, "GetHitRectInsets")
				il, ir, it, ib = num(il) or 0, num(ir) or 0, num(it) or 0, num(ib) or 0
				local l, rr, t, b = r.l + il, r.r - ir, r.t - it, r.b + ib
				if x >= l and x <= rr and y >= b and y <= t and not cutOff(w, f, x, y) then cands[#cands + 1] = f end
			end
		end
	end
	local out = {}
	while #cands > 0 do
		local best = 1
		for k = 2, #cands do if above(w, cands[k], cands[best]) then best = k end end
		out[#out + 1] = cands[best]
		table.remove(cands, best)
	end
	return out
end

local function within(w, f, anc)
	local n = 0
	while f and n < 60 do if f == anc then return true end f = w.par[f]; n = n + 1 end
	return false
end

local function topmostAt(W, target)
	local w = gather(W)
	local r = rectOf(target, w.up)
	if not r then return nil, "no rect" end
	local hits = framesAt(w, (r.l + r.r) / 2, (r.b + r.t) / 2)
	local top = hits[1]
	if not top then return nil, "no mouse-enabled frame at centre" end
	if not within(w, top, target) then
		local tname = str(callm(top, "GetName")) or str(callm(top, "GetObjectType")) or "?"
		return nil, "covered by " .. tname
	end
	return top
end

---------------------------------------------------------------------------
-- Colour reading helpers
---------------------------------------------------------------------------

local function fillRgb(fill)
	if type(fill) ~= "table" then return nil end
	local tex = fill
	if type(fill.parts) == "table" then
		local _, part = next(fill.parts)
		tex = part or fill.rect
	end
	if type(tex) ~= "table" or type(tex.GetVertexColor) ~= "function" then return nil end
	local r, g, b, a = callm(tex, "GetVertexColor")
	r, g, b, a = num(r), num(g), num(b), num(a)
	if not r then return nil end
	return { r, g or r, b or r, a or 1 }
end

local function labelRgb(b)
	if type(b) ~= "table" or type(b.label) ~= "table" then return nil end
	local r, g, bl, a = callm(b.label, "GetTextColor")
	r, g, bl, a = num(r), num(g), num(bl), num(a)
	if not r then return nil end
	return { r, g or r, bl or r, a or 1 }
end

local function rgbClose(a, b, tol)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	tol = tol or 0.02
	for i = 1, 3 do
		if math.abs((a[i] or 0) - (b[i] or 0)) > tol then return false end
	end
	return true
end

local function rgbStr(c)
	if type(c) ~= "table" then return "nil" end
	return ("(%.2f,%.2f,%.2f)"):format(c[1] or 0, c[2] or 0, c[3] or 0)
end

local function scrollControlIntoView(st, b)
	if type(st) ~= "table" or not st.clip or not st.content then return end
	local clipR = rectOf(st.clip, nil)
	local bR = rectOf(b, nil)
	if not (clipR and bR) then return end
	if bR.b >= clipR.b + 4 and bR.t <= clipR.t - 4 then return end
	local cur = num(st.scroll) or 0
	local delta = (clipR.t - 60) - bR.t
	local nextScroll = math.max(num(st.scrollMin) or 0, math.min(num(st.scrollMax) or 0, cur + delta))
	st.scroll = nextScroll
	st.scrollTarget = nextScroll
	st.content:ClearAllPoints()
	st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, nextScroll)
end

---------------------------------------------------------------------------
-- 1. Settings > Drive buttons keep their raised fill after hover/leave
---------------------------------------------------------------------------

local SETTINGS_KEYS = { "drive.resetPos", "drive.bellTest", "drive.bellForget" }

screen({
	id = "a_proof_hover_raised",
	side = "settings",
	title = "Proof hover: Settings > Drive row buttons keep raised fill after mouse leaves",
	need = function(W)
		return type(W.UI) == "table" and type(W.UI.OpenSettings) == "function" and type(W.UI.CloseSettings) == "function"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		W.UI.Toggle(true)
		W.UI.OpenSettings("drive")
		return true
	end,
	hide = function()
		local W = L.W()
		if type(W) == "table" and type(W.UI) == "table" and type(W.UI.CloseSettings) == "function" then
			pcall(W.UI.CloseSettings)
		end
	end,
	verify = function(W)
		if inCombat() then return { result("settings buttons raised fill", "skip", "in combat") } end
		local st = type(W.UI) == "table" and W.UI.settings
		local ctl = type(st) == "table" and st.controls
		if type(ctl) ~= "table" then return { result("settings buttons raised fill", "look", "W.UI.settings.controls missing") } end

		local savedScroll = st.scroll
		local out = {}
		local raisedRgb = W.T and type(W.T.RGB) == "function" and { W.T.RGB("raised") } or nil

		for _, key in ipairs(SETTINGS_KEYS) do
			local b = ctl[key]
			if type(b) ~= "table" or type(b.fill) ~= "table" then
				out[#out + 1] = result(key .. " raised fill", "look", "button or fill not found")
			else
				scrollControlIntoView(st, b)
				local top, why = topmostAt(W, b)
				if not top then
					out[#out + 1] = result(key .. " raised fill", "look", "topmost frame check failed: " .. tostring(why))
				else
					local enter = script(top, "OnEnter")
					local leave = script(top, "OnLeave")
					if not enter or not leave then
						out[#out + 1] = result(key .. " raised fill", "look", "topmost frame missing OnEnter/OnLeave")
					else
						local beforeName = b.fill.colour
						local beforeRgb = fillRgb(b.fill)
						pcall(enter, top)
						local duringName = b.fill.colour
						local duringRgb = fillRgb(b.fill)
						pcall(leave, top)
						local afterName = b.fill.colour
						local afterRgb = fillRgb(b.fill)

						local okName = (afterName == "raised")
						local okRgb = (not raisedRgb) or rgbClose(afterRgb, raisedRgb)
						local changedDuring = (duringName ~= beforeName) or (beforeRgb and duringRgb and not rgbClose(beforeRgb, duringRgb))
						if okName and okRgb and changedDuring then
							out[#out + 1] = result(key .. " raised fill", "pass",
								("before=%s%s during=%s%s after=%s%s"):format(tostring(beforeName), rgbStr(beforeRgb), tostring(duringName), rgbStr(duringRgb), tostring(afterName), rgbStr(afterRgb)))
						else
							out[#out + 1] = result(key .. " raised fill", "look",
								("before=%s%s during=%s%s after=%s%s"):format(tostring(beforeName), rgbStr(beforeRgb), tostring(duringName), rgbStr(duringRgb), tostring(afterName), rgbStr(afterRgb)))
						end
					end
				end
			end
		end

		if st.clip and st.content and type(savedScroll) == "number" then
			st.scroll = savedScroll
			st.scrollTarget = savedScroll
			st.content:ClearAllPoints()
			st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, savedScroll)
		end
		return out
	end,
})

---------------------------------------------------------------------------
-- 2. "Hide this driver" pill keeps its red ownColour during and after hover
---------------------------------------------------------------------------

local savedAdvanced = nil

local function findVisibleHidePill(W)
	local up = rawget(_G, "UIParent")
	local seen = {}
	local found
	local function scan(f)
		if found or type(f) ~= "table" or seen[f] then return end
		seen[f] = true
		if isTrue(f, "IsVisible") and type(f.label) == "table" and fn(f.label, "GetText") then
			if str(callm(f.label, "GetText")) == "Hide this driver" then
				found = f
				return
			end
		end
		local kids = { callm(f, "GetChildren") }
		for _, k in ipairs(kids) do scan(k) end
	end
	scan(up)
	return found
end

local function findVisibleDriverCard(W)
	local st = type(W.UI) == "table" and W.UI.state
	local cards = type(st) == "table" and st.cards
	if type(cards) == "table" then
		for _, c in pairs(cards) do
			if type(c) == "table" and isTrue(c, "IsVisible") and c.key then return c end
		end
	end
	return nil
end

screen({
	id = "a_proof_hover_owncolour",
	side = "rider",
	only = "unfolded",
	title = "Proof hover: Hide this driver pill keeps its red ownColour during and after hover",
	need = function(W)
		return tourScreen("home") ~= nil and type(W.db) == "table"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		savedAdvanced = W.db.advanced
		W.db.advanced = true
		return runOf("home")(W)
	end,
	hide = function()
		local W = L.W()
		if type(W) == "table" and type(W.db) == "table" and savedAdvanced ~= nil then
			W.db.advanced = savedAdvanced
			savedAdvanced = nil
		elseif type(W) == "table" and type(W.db) == "table" then
			W.db.advanced = nil
		end
		local hp = findVisibleHidePill(W)
		if hp and type(hp.GetParent) == "function" then
			local host = callm(hp, "GetParent")
			local menu = host and type(host.GetParent) == "function" and callm(host, "GetParent")
			if menu and fn(menu, "Hide") then pcall(menu.Hide, menu) end
		end
		local b = tourScreen("home")
		if b and type(b.hide) == "function" then pcall(b.hide) end
	end,
	verify = function(W)
		if inCombat() then return { result("Hide this driver ownColour", "skip", "in combat") } end
		local card = findVisibleDriverCard(W)
		if not card then return { result("Hide this driver ownColour", "look", "no visible driver card on Home") } end

		local cardTop, cardWhy = topmostAt(W, card)
		if not cardTop then return { result("Hide this driver ownColour", "look", "driver card not topmost: " .. tostring(cardWhy)) } end
		local onClick = script(cardTop, "OnClick")
		if not onClick then return { result("Hide this driver ownColour", "look", "driver card topmost has no OnClick") } end

		pcall(onClick, cardTop, "RightButton")
		local hidePill = findVisibleHidePill(W)
		if not hidePill then return { result("Hide this driver ownColour", "look", "Hide this driver pill did not open") } end

		local redRgb = W.T and type(W.T.RGB) == "function" and { W.T.RGB("red") } or { 1, 0.36, 0.48, 1 }
		local pillTop, pillWhy = topmostAt(W, hidePill)
		local out
		if not pillTop then
			out = { result("Hide this driver ownColour", "look", "Hide this driver pill not topmost: " .. tostring(pillWhy)) }
		else
			local enter = script(pillTop, "OnEnter")
			local leave = script(pillTop, "OnLeave")
			if not enter or not leave then
				out = { result("Hide this driver ownColour", "look", "Hide this driver pill missing OnEnter/OnLeave") }
			else
				local beforeRgb = labelRgb(hidePill)
				pcall(enter, pillTop)
				local duringRgb = labelRgb(hidePill)
				pcall(leave, pillTop)
				local afterRgb = labelRgb(hidePill)

				local okBefore = rgbClose(beforeRgb, redRgb)
				local okDuring = rgbClose(duringRgb, redRgb)
				local okAfter = rgbClose(afterRgb, redRgb)
				if okBefore and okDuring and okAfter then
					out = { result("Hide this driver ownColour", "pass",
						("before=%s during=%s after=%s"):format(rgbStr(beforeRgb), rgbStr(duringRgb), rgbStr(afterRgb))) }
				else
					out = { result("Hide this driver ownColour", "look",
						("expected red%s; before=%s during=%s after=%s"):format(rgbStr(redRgb), rgbStr(beforeRgb), rgbStr(duringRgb), rgbStr(afterRgb))) }
				end
			end
		end

		local host = fn(hidePill, "GetParent") and callm(hidePill, "GetParent")
		local menu = host and fn(host, "GetParent") and callm(host, "GetParent")
		if menu and fn(menu, "Hide") then pcall(menu.Hide, menu) end
		if type(W.db) == "table" then
			W.db.advanced = savedAdvanced
			savedAdvanced = nil
		end
		return out
	end,
})
