-- (#237) the Lab Auto check's own mistakes after 2.4.3 run 3 (lab/WuberLab, dev only; Wuber is unchanged). The Lab is never shipped.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoKeys.lua") then
	test("autocheck 237: lab not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function world()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	c.env.IsInGuild = function() return true end
	c.env.C_AddOns = { GetNumAddOns = function() return 2 end, GetAddOnInfo = function(i) return ({ "Wuber", "WuberLab" })[i] end,
		IsAddOnLoaded = function() return true end }
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	c.env.GetCurrentKeyBoardFocus = function()
		for _, f in ipairs(c.frames) do
			local okT, ot = pcall(f.GetObjectType, f)
			if okT and ot == "EditBox" and f:HasFocus() and f:IsVisible() then return f end
		end
		return nil
	end
	c.W.UI.Toggle(true)
	w:advance(2)
	return w, c
end

local function autoRun(words, before)
	local w, c = world()
	local L = c.ns.WuberLab
	if before then before(c) end
	local started, why = L.AutoStart({ words = words })
	ok(started, "the Auto check started: " .. tostring(why))
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	return L.lastAuto or {}, c, w
end

local function rowsOf(last, pat)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		local line = r.status .. " " .. tostring(r.name or "") .. " | " .. tostring(r.detail)
		if line:find(pat) then out[#out + 1] = line end
	end
	return out
end
local function stepRows(last, step)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		if r.steps and ("," .. (type(r.steps) == "table" and table.concat(r.steps, ",") or r.steps) .. ","):find("," .. step .. ",", 1, true) then
			out[#out + 1] = r.status .. " " .. tostring(r.detail)
		end
	end
	return out
end
local function screenOf(c, id)
	for _, s in ipairs(c.ns.WuberLab.AUTO_SCREENS) do if s.id == id then return s end end
end

-- an EditBox inside the Wuber window that listens for keys the way the client lets a box do it
local function addBox(c, focus)
	local win = c.W.UI.state.win
	local eb = c.env.CreateFrame("EditBox", nil, win)
	eb:SetSize(50, 20)
	eb:SetPoint("CENTER", win, "CENTER", 0, 0)
	if eb.SetAutoFocus then eb:SetAutoFocus(false) end
	if not focus and eb:HasFocus() then eb:ClearFocus() end
	eb:EnableKeyboard(true)
	eb:SetPropagateKeyboardInput(false)
	eb:Show()
	if focus then eb:SetFocus() end
	return eb
end

test("autocheck 237: KEYS-SETTINGS does not count an unfocused EditBox as taking keys", function()
	local last, c, w = autoRun({ "a_keys_settings" }, function(cl) addBox(cl, false) end)
	local r = stepRows(last, "KEYS-SETTINGS")
	eq(#r, 2, "one row per origin: " .. table.concat(r, " | "))
	for _, line in ipairs(r) do ok(line:find("^pass"), "passes: " .. line) end
	clean(w)
end)

-- guard: a plain frame that takes keys is still a look (the check still finds a real key taker)
test("autocheck 237: KEYS-SETTINGS still flags a plain frame that takes keys", function()
	local last, c, w = autoRun({ "a_keys_settings" }, function(cl)
		local win = cl.W.UI.state.win
		local f = cl.env.CreateFrame("Frame", nil, win)
		f:SetSize(50, 20)
		f:SetPoint("CENTER", win, "CENTER", 0, 0)
		f:EnableKeyboard(true)
		f:SetPropagateKeyboardInput(false)
		f:Show()
	end)
	local r = stepRows(last, "KEYS-SETTINGS")
	local looks = 0
	for _, line in ipairs(r) do if line:find("^look") and line:find("takes keys", 1, true) then looks = looks + 1 end end
	ok(looks >= 1, "flagged: " .. table.concat(r, " | "))
	clean(w)
end)

-- a text inside a row (the row's alpha is rowAlpha), and an opaque cue box over half of it ("+3 more below")
local function textAndCue(c, rowAlpha)
	local win = c.W.UI.state.win
	local base = win:GetFrameLevel() or 1
	local row = c.env.CreateFrame("Frame", "WuberRaidProbeRow", win)
	row:SetSize(200, 20)
	row:SetPoint("CENTER", win, "CENTER", 0, 0)
	row:SetFrameLevel(base + 100)
	local tf = c.env.CreateFrame("Frame", nil, row)
	tf:SetAllPoints(row)
	local fs = tf:CreateFontString(nil, "OVERLAY")
	fs:SetFont(c.W.Theme.FONTS.regular, 14, "")
	fs:SetPoint("LEFT", tf, "LEFT", 0, 0)
	fs:SetText("Probe words under a row")
	row:SetAlpha(rowAlpha)
	local cue = c.env.CreateFrame("Frame", "WuberRaidProbeCue", win)
	cue:SetSize(70, 40)
	cue:SetPoint("LEFT", row, "CENTER", -10, 0)
	cue:SetFrameLevel(base + 200)
	local tx = cue:CreateTexture(nil, "BACKGROUND")
	tx:SetAllPoints(cue)
	tx:SetColorTexture(0.2, 0.2, 0.3, 1)
end

-- the game's GetEffectiveAlpha need not say 0 for a child of a row at alpha 0: the check reads the row's own alpha too
local function underOf(rowAlpha)
	local w, c = world()
	textAndCue(c, rowAlpha)
	local row = c.env.WuberRaidProbeRow
	local mt = getmetatable(row)
	local was = mt.__index
	mt.__index = function(t, k)
		if k == "GetEffectiveAlpha" then return function() return 1 end end
		if type(was) == "function" then return was(t, k) end
		return was[k]
	end
	w:advance(1)
	local F = c.ns.WuberLab.AutoLook(c.W, "raid probe")
	mt.__index = was
	clean(w)
	local mine = {}
	for _, line in ipairs(F.under) do if line:find("Probe words", 1, true) then mine[#mine + 1] = line end end
	return mine
end

test("autocheck 237: the under check skips a text in a row at alpha 0 (the Raid rows under the cue)", function()
	local u = underOf(0)
	eq(#u, 0, "no finding for the invisible row: " .. table.concat(u, " | "))
end)

-- #317: a row whose fade ended just above 0 draws nothing either (run 4: the cue was still flagged over the Raid rows)
test("autocheck 317: the under check skips a text in a row at alpha 0.004", function()
	local u = underOf(0.004)
	eq(#u, 0, "no finding for the (all but) invisible row: " .. table.concat(u, " | "))
end)

-- guard: the same text in a drawn row, half under the cue, is still found
test("autocheck 237: the under check still finds a drawn text half under a cue box", function()
	local u = underOf(1)
	ok(#u >= 1, "found: " .. table.concat(u, " | "))
end)

-- each probe, run through the Auto check on the current Wuber: it must pass (these fail on the Lab before the fix)
local function passes(id, step, why)
	test("autocheck 237: " .. step .. " passes on the current Wuber (" .. why .. ")", function()
		local last, c, w = autoRun({ id })
		local r = stepRows(last, step)
		ok(#r >= 1, "a row for " .. step)
		for _, line in ipairs(r) do ok(line:find("^pass"), line) end
		clean(w)
	end)
end
passes("a_size", "AUD-172", "the Size card is below the fold of the home list: the probe scrolls to it")
passes("a_tip_words", "HUNT-43", "the advert tooltip's present words")
passes("a_wide_reset", "HUNT-72", "the Undo toast 'N settings reset.'")
passes("a_pos_reset", "HUNT-59", "the Undo toast 'N settings reset.'")
passes("a_wizard_friends", "AUD-200", "the picked card's glow look, methods not functions")
passes("a_msg_callsum", "AUD-201", "the preview is read in the editor")
passes("a_addbyname", "AUD-224", "'---' is refused with 'That isn't a player's name'")

-- the font check: the game snaps size 11 to whole pixels (run 3: +4.5% to +6.4%) and gives digits 0.5 px apart
local function fontRows(size11Factor, zeroExtra, bigFactor)
	local w, c = world()
	local fs = c.env.UIParent:CreateFontString(nil, "OVERLAY")
	local mt = getmetatable(fs)
	local was = mt.__index
	mt.__index = function(t, k)
		local v
		if type(was) == "function" then v = was(t, k) else v = was[k] end
		if k == "GetStringWidth" and type(v) == "function" then
			return function(self, ...)
				local width = v(self, ...)
				local _, size = self:GetFont()
				local text = self:GetText()
				if type(width) == "number" and text == "0000" then width = width + zeroExtra end
				return width
			end
		end
		return v
	end
	-- Wuber's table says what the fake game draws, with size 11 set so that the game is size11Factor wider than the table
	local T2 = c.W.Theme
	local scratch = c.env.UIParent:CreateFontString(nil, "OVERLAY")
	T2.MeasureText = function(text, size, wt)
		scratch:SetFont(T2.FONTS[wt], size, "")
		scratch:SetText(text)
		return scratch:GetStringWidth() * 1.03 / (size == 11 and size11Factor or (bigFactor or 1))
	end
	local rows = c.ns.WuberLab.AutoFontCheck(c.W)
	mt.__index = was
	local by = {}
	for _, r in ipairs(rows) do by[r.name] = r.status .. " " .. tostring(r.detail) end
	clean(w)
	return by
end

test("autocheck 237: font widths at size 11 within 8% and digits within 1 px pass", function()
	local by = fontRows(1.06, 0.5)
	ok(by.widths and by.widths:find("^pass"), "widths: " .. tostring(by.widths))
	ok(by.digits and by.digits:find("^pass"), "digits: " .. tostring(by.digits))
end)

-- guard: a real mistake still shows (size 11 20% off, digits 3 px apart)
test("autocheck 237: font widths 20% off at size 11 and digits 3 px apart still look", function()
	local by = fontRows(1.2, 3)
	ok(by.widths and by.widths:find("^look"), "widths: " .. tostring(by.widths))
	ok(by.digits and by.digits:find("^look"), "digits: " .. tostring(by.digits))
end)

-- the portal's picture: the game gives a file id number (negative for an addon's file) from GetTexture, and no path
test("autocheck 237: a_portal accepts the picture's file id number, and a negative id as loaded", function()
	local last, c, w = autoRun({ "a_portal" }, function(cl)
		local tx = cl.W.UI.state.win:CreateTexture(nil, "BACKGROUND")
		local mt = getmetatable(tx)
		local was = mt.__index
		local function base(t, k) if type(was) == "function" then return was(t, k) end return was[k] end
		mt.__index = function(t, k)
			local v = base(t, k)
			if k == "GetTexture" or k == "GetTextureFilePath" or k == "GetTextureFileID" or k == "IsObjectLoaded" then
				return function(self, ...)
					local path = base(self, "GetTextureFilePath")
					path = type(path) == "function" and path(self) or nil
					if type(path) == "string" and path:find("portal_still", 1, true) then
						if k == "GetTextureFilePath" or k == "IsObjectLoaded" then return nil end
						return -31613
					end
					return type(v) == "function" and v(self, ...) or nil
				end
			end
			return v
		end
		cl.restorePortal = function() mt.__index = was end
	end)
	c.restorePortal()
	-- a pass leaves no row (only looks and skips do): so no row may be about the picture's file or whether it loaded
	for _, r in ipairs(last.results or {}) do
		local name = tostring(r.kind or "")
		ok(not (name:find("portal file", 1, true) or name:find("portal loaded", 1, true)), "no look or skip: " .. r.status .. " " .. name .. " " .. tostring(r.detail))
	end
	ok((last.counts or {}).pass > 0, "the screen's rows passed")
	clean(w)
end)

-- #317: above size 11 the game's widths were measured 4.0 to 4.2% over the raw table (job 2885): within 5% they pass
test("autocheck 317: font widths 4.5% over at sizes 14 and 22 pass (measured: 4.0 to 4.2%)", function()
	local by = fontRows(1.06, 0.5, 1.045)
	ok(by.widths and by.widths:find("^pass"), "widths: " .. tostring(by.widths))
end)

-- guard: 10% over at sizes 14 and 22 still looks
test("autocheck 317: font widths 10% over at sizes 14 and 22 still look", function()
	local by = fontRows(1.06, 0.5, 1.10)
	ok(by.widths and by.widths:find("^look"), "widths: " .. tostring(by.widths))
end)
