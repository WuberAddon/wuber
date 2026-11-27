-- T243-2 (Lab): the Auto check's a_paused_clicks row. It reads a fight the player is in anyway (never enters one), says
-- "needs combat: skipped" when it has read none, says pass on the current Wuber and look on a Wuber with the window-lift undone.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoSteps7.lua") then
	test("lab auto7 paused: AutoSteps7.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function undo(file, find, repl)
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find(file, 1, true) then return text end
		text = text:gsub("\r\n", "\n")
		local s, e = text:find(find, 1, true)
		if not s then error("the broken copy's text is not in " .. file .. ": " .. find) end
		hit = true
		return text:sub(1, s - 1) .. repl .. text:sub(e + 1)
	end
	return rewrite, function() return hit end
end

local function setup(rewrite)
	local w = newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	local W = c.W
	W.db.coach = true
	W.Char().wizard = true
	W.Driver.SetOnline(true)
	w:advance(2)
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Drive") w:advance(1.2)
	return w, c, W, c.ns.WuberLab
end

local function centre(f) return f:GetLeft() + f:GetWidth() / 2, f:GetBottom() + f:GetHeight() / 2 end

-- the player drags the window so the Settings cog lands where the paused button was left
local function moveCogOverButton(c, W)
	local b = c.env.WuberDriveButton
	local ui = W.UI.state
	local bx, by = centre(b)
	local gx, gy = centre(ui.gear)
	local win = c.env.WuberFrame
	local p, rel, rp, px, py = win:GetPoint(1)
	win:ClearAllPoints()
	win:SetPoint(p, rel, rp, px + (bx - gx), py + (by - gy))
end

-- guard: the label on its slot in a fight reads pass (the unchanged neighbouring path)
test("lab auto7 paused: a fight on the Drive tab: the label on the button on its slot reads pass", function()
	local w, c, W, L = setup()
	w:enterCombat(c) w:advance(2)
	local s = L.db.pausedClicks
	ok(s, "a reading was kept")
	eq(s and s.status, "pass", "pass: " .. tostring(s and s.detail))
	ok(tostring(s and s.detail):find("lies on the button", 1, true), "it says the label lies on the button: " .. tostring(s and s.detail))
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	eq(#w.errors, 0, "Lua errors: " .. table.concat(w.errors, "; "))
	w:leaveCombat(c) w:advance(1.5)
	clean(w)
end)

test("lab auto7 paused: the window moved over the left-behind button in a fight: pass on the current Wuber", function()
	local w, c, W, L = setup()
	w:enterCombat(c) w:advance(0.5)
	moveCogOverButton(c, W) w:advance(8)
	local s = L.db.pausedClicks
	eq(s and s.status, "pass", "pass: " .. tostring(s and s.detail))
	ok(tostring(s and s.detail):find("lie under the button's place, none with the button on top", 1, true), "a control lay under it: " .. tostring(s and s.detail))
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	w:leaveCombat(c) w:advance(1.5)
	clean(w)
end)

test("lab auto7 paused: the window-lift undone: the same fight reads look and names the click it loses", function()
	local rewrite, hit = undo("UI/Window.lua", "(over or ui.overOptions or ui.overPaused)", "(over or ui.overOptions)")
	local w, c, W, L = setup(rewrite)
	ok(hit(), "the broken copy was made")
	w:enterCombat(c) w:advance(0.5)
	moveCogOverButton(c, W) w:advance(8)
	local s = L.db.pausedClicks
	eq(s and s.status, "look", "look: " .. tostring(s and s.detail))
	ok(tostring(s and s.detail):find("is the big button", 1, true), "it says what is wrong: " .. tostring(s and s.detail))
	w:leaveCombat(c) w:advance(1.5)
	clean(w)
end)

test("lab auto7 paused: no fight read: the row says needs combat: skipped, and it entered no fight", function()
	local w, c, W, L = setup()
	W.Driver.SetOnline(false) w:advance(1)
	c.env.IsInGuild = function() return true end
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	eq(L.db.pausedClicks, nil, "control: nothing was read")
	local started, why = L.AutoStart({ words = { "a_paused_clicks" } })
	ok(started, "the Auto check started: " .. tostring(why))
	for _ = 1, 600 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	local found
	for _, r in ipairs((L.lastAuto or {}).results or {}) do
		if r.id == "a_paused_clicks" then found = (found and (found .. " | ") or "") .. tostring(r.status) .. ": " .. tostring(r.detail) end
	end
	ok(found and found:find("needs combat: skipped", 1, true), "the row says needs combat: skipped: " .. tostring(found))
	eq(c.player.combat, false, "the check did not enter a fight")
	eq(#w.violations, 0, "no protected call: " .. table.concat(w.violations, "; "))
	clean(w)
end)
