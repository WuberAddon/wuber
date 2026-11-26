-- r49 group B (E1-07 + L25-SHEET-EDGE): with Report a bug or the raincheck sheet up, the dim covers the page whole (from the
-- window's top to the tab bar) and the header buttons (the fold button, the cog, the x) sit ABOVE it: drawn over the dim and
-- clickable, not dimmed. Promise swept over: window folded and unfolded, the sheet in its two homes (Bug, Raincheck), the cog shown or
-- hidden, and the sheet closed again (the buttons go back to where they were, so a game dialog over the window still covers them).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local Top = dofile(H.root .. "/tests/lib/topmost.lua")

local function setup(wide)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W, UI = c.W, c.W.UI
	UI.Toggle(true)
	w:advance(3)
	c.wide = wide
	W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
	UI.Fold.Apply()
	w:advance(2)
	return w, c, W, UI
end

local function headButtons(UI)
	local ui = UI.state
	local list = { { "x", ui.close }, { "cog", ui.gear } }
	if ui.phone and ui.phone.fold then list[#list + 1] = { "fold", ui.phone.fold } end
	return list
end

-- the window's own frames (strata HIGH, a bezel drawn over the header with no mouse) are not the question: the sheet's frames are
local function allAbove(w, c, UI, what)
	local n = 0
	local ignore = {}
	for _, f in ipairs(c.frames) do
		if f.GetFrameStrata and f:GetFrameStrata() == UI.state.win:GetFrameStrata() then ignore[f] = true end
	end
	for _, e in ipairs(headButtons(UI)) do
		local b = e[2]
		if b and b:IsShown() then
			n = n + 1
			local res = Top.checkButton(H, c, b, { ignore = ignore })
			ok(res.ok, what .. ": the " .. e[1] .. " is drawn over the dim and everything else: " .. tostring(res.reason))
		end
	end
	ok(n >= 2, what .. ": the x and one more header button showed (" .. n .. ")")
end

local function dimTopIsWindowTop(UI, sheet, what)
	local win = UI.state.win
	local wr, dr = H.rect(win), H.rect(sheet.dim)
	ok(math.abs((dr.b + dr.h) - (wr.b + wr.h)) < 1, what .. ": the dim reaches the window's top")
	local tb = H.rect(UI.state.tabbar)
	ok(math.abs(dr.b - (tb.b + tb.h)) < 1, what .. ": the dim ends on the tab bar")
end

for _, wide in ipairs({ false, true }) do
	local what = wide and "unfolded" or "folded"
	test("r49 b: Report a bug up, " .. what .. ": the dim is full height and the header buttons are above it", function()
		local w, c, W, UI = setup(wide)
		UI.Bug.Open()
		w:advance(1)
		ok(UI.Bug.Shown(), "the sheet is up")
		dimTopIsWindowTop(UI, UI.Bug.frame, what)
		allAbove(w, c, UI, what .. " with the bug sheet")
		eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
		T.clean(w)
	end)
end

test("r49 b: the raincheck sheet up: the dim is full height and the header buttons are above it", function()
	local w, c, W, UI = setup(false)
	W.Raincheck.Mine = function()
		return { { id = "rc1", state = "offered", driver = "Anita Lift", cover = 5000, expires = os.time() + 6 * 86400 } }
	end
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and H.visible(f), "the offer shows")
	dimTopIsWindowTop(UI, f, "raincheck")
	allAbove(w, c, UI, "with the raincheck sheet")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- the neighbouring path: with the sheet closed the header buttons are where the window made them (strata HIGH, the window's own),
-- so a game dialog over the window still covers them
-- guard: the header's own strata when no sheet is up, kept by the fix
test("r49 b: sheet closed (before and after): the header buttons stay in the window's strata", function()
	local w, c, W, UI = setup(false)
	local ui = UI.state
	local want = ui.win:GetFrameStrata()
	for _, e in ipairs(headButtons(UI)) do eq(e[2]:GetFrameStrata(), want, "before: the " .. e[1]) end
	UI.Bug.Open()
	w:advance(1)
	UI.Bug.Close()
	w:advance(2)
	ok(not UI.Bug.Shown(), "the sheet is shut")
	for _, e in ipairs(headButtons(UI)) do
		eq(e[2]:GetFrameStrata(), want, "after: the " .. e[1] .. " is back in the window's strata")
	end
	-- and a click on the x with no sheet still hides Wuber
	ui.close:Click()
	w:advance(1)
	ok(not ui.win:IsShown(), "the x closes the window")
	T.clean(w)
end)

-- the buttons stay clickable with the sheet up: the x hides Wuber, the sheet with it
-- guard: the x already closed Wuber with the sheet up (the dim's header strip took no mouse); it must still, now that the x is lifted over the dim
test("r49 b: the x pressed with the bug sheet up closes Wuber and the sheet", function()
	local w, c, W, UI = setup(false)
	UI.Bug.Open()
	w:advance(1)
	local ui = UI.state
	ui.close:Click()
	w:advance(2)
	ok(not ui.win:IsShown(), "the window is hidden")
	ok(not UI.Bug.Shown(), "the sheet is gone with it")
	-- the window comes back: the buttons are over the dim exactly while the sheet shows, in the window's strata otherwise
	UI.Toggle(true)
	w:advance(2)
	local up = ui.close:GetFrameStrata() ~= ui.win:GetFrameStrata()
	eq(up, UI.Bug.Shown(), "the x is lifted exactly while the sheet shows")
	UI.Bug.Close()
	w:advance(2)
	eq(ui.close:GetFrameStrata(), ui.win:GetFrameStrata(), "the sheet shut: the x is back in the window's strata")
	T.clean(w)
end)

-- the back chevron of a pushed page (Settings here) is a header button too: over the dim, and it still goes back
local function withSettings()
	local w, c, W, UI = setup(false)
	local ui = UI.state
	ui.gear:Click()
	w:advance(3)
	local st = W.Mod("UI.Settings.Rows").st
	return w, c, W, UI, st
end
local function ignoreHigh(c, UI)
	local ignore = {}
	for _, f in ipairs(c.frames) do
		if f.GetFrameStrata and f:GetFrameStrata() == UI.state.win:GetFrameStrata() then ignore[f] = true end
	end
	return ignore
end

test("r49 b: a pushed page (Settings) with the bug sheet up: its back chevron is above the dim and goes back", function()
	local w, c, W, UI, st = withSettings()
	ok(st.back and st.back:IsVisible(), "Settings is up with its back chevron")
	UI.Bug.Open()
	w:advance(1)
	ok(UI.Bug.Shown(), "the bug sheet is up")
	local res = Top.checkButton(H, c, st.back, { ignore = ignoreHigh(c, UI) })
	ok(res.ok, "the back chevron is drawn over the dim: " .. tostring(res.reason))
	st.back:Click()
	w:advance(3)
	ok(not (UI.SettingsShown and UI.SettingsShown()), "the chevron went back: Settings is shut")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- guard: with no sheet up the back chevron stays in the page's own strata and goes back as before
test("r49 b: a pushed page, sheet closed: the back chevron is in its page's strata and goes back", function()
	local w, c, W, UI, st = withSettings()
	eq(st.back:GetFrameStrata(), UI.state.win:GetFrameStrata(), "before: in the window's strata")
	UI.Bug.Open()
	w:advance(1)
	UI.Bug.Close()
	w:advance(2)
	eq(st.back:GetFrameStrata(), UI.state.win:GetFrameStrata(), "after the sheet: back where it was")
	st.back:Click()
	w:advance(3)
	ok(not (UI.SettingsShown and UI.SettingsShown()), "the chevron went back")
	T.clean(w)
end)

-- the words of the Report a bug sheet are never cut ("..."), whichever width the window has when they are laid out: open it
-- unfolded and fold the window under it (the fold button now stands over the dim), and the other way round; the boxes under
-- the words never start inside them
local function howWhole(c, f, what)
	local tr = H.truncation(f.how, true)
	ok(tr == nil, what .. ": the words end whole (" .. tostring(tr and (tr.lines .. " lines, room for " .. tostring(tr.max))) .. ")")
	local hr, lr = H.rect(f.how), H.rect(f.noteLbl)
	ok(lr.b + lr.h <= hr.b + 0.5, what .. ": the first label starts under the words")
end
for _, startWide in ipairs({ true, false }) do
	test("r49 b: the sheet's words stay whole when the window " .. (startWide and "folds" or "unfolds") .. " under it", function()
		local w, c, W, UI = setup(startWide)
		UI.Bug.Open()
		w:advance(1)
		local f = UI.Bug.frame
		howWhole(c, f, "first width")
		c.wide = not startWide
		W.db.fold = startWide and { v = 1, pages = {}, narrow = true } or nil
		UI.Fold.Apply()
		w:advance(3)
		ok(UI.Bug.Shown(), "the sheet is still up")
		howWhole(c, f, "after the fold change")
		eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
		T.clean(w)
	end)
end

-- the secure Request and Share overlays (UI.Secure) stand over their pills outside the window, with no art of their own. While a
-- modal sheet is up they lie under its dim and card: the player sees only the dimmed pill, and a click there goes to the sheet
-- (its dim or its own button), never to the overlay. That is the sheet's job (it is modal), so the layout rule treats them as page.
-- guard: the overlays were already under the sheet (they sit at FULLSCREEN_DIALOG level 120 to 200, the sheet's holder at 400)
test("r49 b: a secure overlay over its pill takes no click while the bug sheet is up", function()
	local w, c, W, UI = setup(false)
	local win = UI.state.win
	for _, name in ipairs({ "WuberRequestButton", "WuberShareButton" }) do
		local b = c.env[name] or (c.env._G and c.env._G[name])
		ok(b, name .. " exists")
		if b then
			b:ClearAllPoints()
			b:SetPoint("CENTER", win, "CENTER", 0, 0)
			b:SetSize(120, 30)
			b:SetFrameLevel(150)
			b:Show()
			UI.Bug.Open()
			w:advance(1)
			local r = H.rect(b)
			local hit = c:frameAt(r.l + r.w / 2, r.b + r.h / 2)
			ok(hit ~= b, name .. ": the click at its centre goes to " .. tostring(hit) .. ", not to the overlay")
			UI.Bug.Close()
			w:advance(2)
			b:Hide()
		end
	end
	T.clean(w)
end)
