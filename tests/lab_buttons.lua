local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean = T.newWorld, T.settle, T.clean
local HAVE_UI = T.HAVE_UI
local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("lab buttons: Wuber Lab not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR
local function labOf(c) return c.ns.WuberLab end
local function client(w, name, class)
	local c = w:addClient(name, { spot = "Undercity", class = class, money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	return c
end

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------
local function cameraOn(c)
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
end

local function sentBy(w, name)
	local n = 0
	for _, e in ipairs(w.addonLog or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.whispers or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.chatPosts or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.invites or {}) do if e.from == name then n = n + 1 end end
	return n
end

-- the Auto check on one or two of its screens, to its end; the rows of those screens
local function autoRun(c, w, words, step)
	local L = labOf(c)
	cameraOn(c)
	ok(L.AutoStart({ words = words }), "the Auto check started")
	for _ = 1, (step and 900 / step or 900) do
		if not L.AutoRunning() then break end
		w:advance(step or 1)
	end
	ok(not L.AutoRunning(), "the Auto check ended")
	return L.lastAuto
end

local function rows(auto, kindPattern)
	local out = {}
	for _, r in ipairs(auto.results or {}) do
		if r.kind:find(kindPattern) then out[#out + 1] = r end
	end
	return out
end

local function listRows(rs)
	local t = {}
	for _, r in ipairs(rs) do t[#t + 1] = r.status .. " " .. r.view .. " " .. r.kind .. ": " .. tostring(r.detail) end
	return table.concat(t, "\n")
end

local function fresh()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w, "Anita Lift", "WARLOCK")
	c:slash("/lab")
	w:advance(1)
	c.W.UI.Toggle(true)
	w:advance(2)
	return w, c
end

-- (the main branch has no hit inset on the header strip: the arrow is under it)
local function stripOf(c)
	local st = c.W.UI.state
	return st.top
end

test("lab buttons: the Auto check lists both passes after the tour's own screens, in the Auto check's order", function()
	local w, c = fresh()
	local L = labOf(c)
	local first = { back = nil, click = nil }
	for i, s in ipairs(L.AutoScreens()) do
		if s.id:find("^a_back_") and not first.back then first.back = i end
		if s.id:find("^a_click_") and not first.click then first.click = i end
	end
	ok(first.back and first.click, "both passes are Auto check screens")
	ok(first.back > #L.PHOTO_SCREENS and first.click > #L.PHOTO_SCREENS, "after the tour's own screens (Auto check first, hands off)")
	local n = 0
	for _, s in ipairs(L.AutoScreens()) do if s.id:find("^a_back_") or s.id:find("^a_click_") then n = n + 1 end end
	ok(n >= 11, "a screen per page and per list: " .. n)
	clean(w)
end)

test("lab buttons: the ranking is the client's rule (a frame in a clipping ancestor ranks at the ancestor's level; at an equal level the outside frame wins)", function()
	local w, c = fresh()
	local L = labOf(c)
	local B = L.AutoButtons
	local f = c.env.CreateFrame
	local up = c.env.UIParent
	local root = f("Frame", nil, up); root:SetSize(300, 300); root:SetPoint("CENTER")
	local strip = f("Frame", nil, root); strip:SetSize(300, 40); strip:SetPoint("TOP"); strip:SetFrameLevel(2); strip:EnableMouse(true)
	local body = f("Frame", nil, root); body:SetSize(300, 200); body:SetPoint("TOP", root, "TOP", 0, 0); body:SetFrameLevel(2); body:SetClipsChildren(true)
	local arrow = f("Button", nil, body); arrow:SetSize(32, 32); arrow:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -4); arrow:SetFrameLevel(42)
	-- plain level order would put the level-42 arrow on top; the client puts the clipped subtree at the body's level 2, the strip wins
	ok(B.above(strip, 1, arrow, 2), "the strip is over the arrow in a clipping body")
	ok(not B.above(arrow, 2, strip, 1), "and not the other way round")
	body:SetClipsChildren(false)
	ok(B.above(arrow, 2, strip, 1), "without the clip the arrow's own level 42 wins")
	-- a lower level outside still loses to the clipping body
	body:SetClipsChildren(true)
	strip:SetFrameLevel(1)
	ok(B.above(arrow, 2, strip, 1), "an outside frame of a lower level than the clipping body loses")
	strip:SetFrameLevel(3)
	ok(B.above(strip, 1, arrow, 2), "an outside frame above the clipping body's level wins")
	clean(w)
end)

local function backRows(auto)
	return rows(auto, "^verify back [RSDH]")
end

local function runBack(step, inset)
	local w, c = fresh()
	if inset then stripOf(c).GetHitRectInsets = function() return 120, 0, 0, 0 end -- the fix the author chose: a left hit inset on the strip
	elseif inset == false then stripOf(c).GetHitRectInsets = function() return 0, 0, 0, 0 end end -- main's Wuber: no inset (the fix on claude/back-arrow is switched off)
	return w, c, backRows(autoRun(c, w, { "a_back" }, step))
end

test("lab buttons: Back on every page FAILS on main's Wuber: the header strip covers the arrow, named in the row", function()
	local w, c, rs = runBack(nil, false)
	ok(#rs >= 12, "a row per page and view: " .. #rs .. "\n" .. listRows(rs))
	for _, r in ipairs(rs) do
		eq(r.status, "look", "every page's arrow is under the strip on main's Wuber: " .. r.kind .. ": " .. tostring(r.detail))
		ok(r.detail:find("is covered at its centre", 1, true), "the row says the arrow is covered: " .. r.detail)
		ok(r.detail:find("the top Wuber frame there, an unnamed Frame (no clip", 1, true) and r.detail:find("in WuberFrame", 1, true), "the row names the header strip, a child of WuberFrame: " .. r.detail)
		eq(r.steps, "BUTTONS-BACK", "the row carries the step id for labreport")
	end
	clean(w)
end)

for _, step in ipairs({ 1, 0.25 }) do
	test("lab buttons: Back on every page PASSES with the strip inset (step " .. step .. "): every click lands on the exact page before, Help included", function()
		local w, c, rs = runBack(step, true)
		ok(#rs >= 12, "rows: " .. #rs .. "\n" .. listRows(rs))
		local bad = {}
		for _, r in ipairs(rs) do if r.status ~= "pass" then bad[#bad + 1] = r end end
		eq(#bad, 0, "pages that still fail with the arrow free:\n" .. listRows(bad))
		local help = 0
		for _, r in ipairs(rs) do if r.kind:find("Help", 1, true) then help = help + 1 eq(r.status, "pass", "Help's arrow takes the click") end end
		ok(help >= 2, "Help folded and wide")
		clean(w)
	end)
end

test("lab buttons: a back arrow that goes to the WRONG page fails the row (guard: the arrow is free and on top, only where it lands is wrong)", function()
	local w, c = fresh()
	stripOf(c).GetHitRectInsets = function() return 120, 0, 0, 0 end
	local L = labOf(c)
	local B = L.AutoButtons
	local sc
	for _, s in ipairs(L.AUTO_SCREENS) do if s.id == "a_back_settings_ride" then sc = s end end
	eq(sc.run(c.W, "folded"), true, "Settings opened")
	w:advance(3)
	for _, a in ipairs(B.arrows(c.W)) do a:SetScript("OnClick", function() end) end -- a dead arrow: Settings stays
	B.flush()
	B.backPage(c.W, "Settings from Ride", { tab = "Ride", screen = "home", settings = false, help = false })
	w:advance(3)
	local row = B.flush()[1]
	eq(row.status, "look", "dead click: " .. tostring(row.detail))
	ok(row.detail:find("not the page before", 1, true) and row.detail:find("+settings", 1, true), row.detail)
	clean(w)
end)

test("lab buttons: Click every safe local button: each allow-listed button is on top, does what the list expects, and nothing is sent", function()
	local w, c = fresh()
	local before = { addon = #w.addonLog, whisper = #(w.whispers or {}), invite = #(w.invites or {}), chat = #(w.chatPosts or {}), macro = #(w.macros or {}), mine = sentBy(w, "Anita Lift") }
	local auto = autoRun(c, w, { "a_click" })
	local rs = rows(auto, "^verify click ")
	local want = 0
	for _, s in ipairs(labOf(c).AutoButtons.CLICK_LIST) do
		want = want + #s.labels
		for _, e in ipairs(s.labels) do ok(type(e.expect) == "function", e[1] .. " has an explicit expectation") end
	end
	eq(#rs, want, "a row per allow-listed button:\n" .. listRows(rs))
	local bad = {}
	for _, r in ipairs(rs) do if r.status ~= "pass" then bad[#bad + 1] = r end end
	eq(#bad, 0, "rows that did not pass:\n" .. listRows(bad))
	eq(#w.addonLog - before.addon, 0, "addon messages sent")
	eq(#(w.whispers or {}) - before.whisper, 0, "whispers sent")
	eq(#(w.invites or {}) - before.invite, 0, "invites sent")
	eq(#(w.chatPosts or {}) - before.chat, 0, "chat lines posted")
	eq(#(w.macros or {}) - before.macro, 0, "macros run")
	eq(sentBy(w, "Anita Lift") - before.mine, 0, "anything sent by the player")
	clean(w)
end)

test("lab buttons: the click pass presses only its allow list (every Button and CheckButton, also ones created after it starts)", function()
	local w, c = fresh()
	local L = labOf(c)
	local B = L.AutoButtons
	local allowed = {}
	for _, s in ipairs(B.CLICK_LIST) do for _, e in ipairs(s.labels) do allowed[e[1]] = true end end
	for _, bad in ipairs({ "Ping drivers", "Reset stats", "Report a bug", "Drive", "Add", "Run the setup again" }) do
		ok(not allowed[bad], bad .. " is not on the allow list")
	end
	-- every Button and CheckButton, the window's now and any created while the pass runs, notes its presses
	local seen, kinds = {}, {}
	local function note(k)
		if rawget(k, "labNoted") then return end
		k.labNoted = true
		local orig = k.Click
		k.Click = function(self, ...)
			local first
			for _, r in ipairs({ self:GetRegions() }) do if not first and r.GetText and r:GetText() then first = r:GetText() end end
			seen[#seen + 1] = first or "?"
			kinds[self:GetObjectType()] = (kinds[self:GetObjectType()] or 0) + 1
			return orig(self, ...)
		end
	end
	local function noteAll(f)
		for _, k in ipairs({ f:GetChildren() }) do
			local ty = k:GetObjectType()
			if ty == "Button" or ty == "CheckButton" then note(k) end
			noteAll(k)
		end
	end
	local created = 0
	local realCreate = c.env.CreateFrame
	c.env.CreateFrame = function(ty, ...)
		local f = realCreate(ty, ...)
		if ty == "Button" or ty == "CheckButton" then note(f) created = created + 1 end
		return f
	end
	local base = B.clickScreen
	B.clickScreen = function(W, sid, entries)
		noteAll(W.UI.state.win)
		return base(W, sid, entries)
	end
	local okRun, err = pcall(autoRun, c, w, { "a_click" })
	c.env.CreateFrame = realCreate
	B.clickScreen = base
	ok(okRun, tostring(err))
	ok(#seen >= 6, "the pass pressed its buttons: " .. #seen)
	for _, label in ipairs(seen) do
		ok(allowed[label], "pressed a button that is not on the allow list: " .. tostring(label))
	end
	clean(w)
end)

test("lab buttons: a button covered at its centre FAILS the click pass with the cover named (guard: the same button uncovered passes)", function()
	local w, c = fresh()
	local B = labOf(c).AutoButtons
	local W = c.W
	B.openHome = function() for _, x in ipairs(labOf(c).PHOTO_SCREENS) do if x.id == "home" then x.run(W, "folded") end end end
	B.openHome()
	w:advance(3)
	local trips = B.CLICK_LIST[1].labels[1]
	local good = B.clickScreen(W, "home", { trips })[1]
	eq(good.status, "pass", "uncovered: " .. tostring(good.detail))
	B.openHome()
	w:advance(3)
	local win = W.UI.state.win
	local cover = c.env.CreateFrame("Frame", nil, win)
	cover:SetFrameStrata("FULLSCREEN_DIALOG"); cover:SetFrameLevel(200); cover:EnableMouse(true)
	cover:SetAllPoints(win)
	local bad = B.clickScreen(W, "home", { trips })[1]
	eq(bad.status, "look", "covered: " .. tostring(bad.detail))
	ok(bad.detail:find("is covered at its centre", 1, true), bad.detail)
	cover:Hide()
	clean(w)
end)
