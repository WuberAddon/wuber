-- T243-4 again (run 2): "on Drive > cog > Settings (the driving page) I cannot move or jump"; Ride's Settings home and Trips are fine.
-- Cause: the key-capture row (UI/Settings/Rows.lua keyRow) switches its full-row cover frame's keyboard off BEFORE it sets
-- OnKeyDown on it; the real client turns keyboard input on for a frame when OnKeyDown is set, and propagate is off by default,
-- so the visible cover ate every key. The fake game now does the same (tests/harness.lua SetScript/HookScript).
-- Promise: with Settings on the driving page and nobody capturing a key, keys reach the game; capturing takes them; ending it gives them back.
-- The key routing is this test's own: a key goes to the focused EditBox, else it is swallowed by a visible keyboard-enabled
-- frame that does not propagate it, else it reaches the game.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function route(a)
	for _, f in ipairs(a.frames) do
		local okT, ot = pcall(f.GetObjectType, f)
		if okT and ot == "EditBox" and f:HasFocus() and f:IsVisible() then return "box" end
	end
	for _, f in ipairs(a.frames) do
		local okK, kb = pcall(f.IsKeyboardEnabled, f)
		if okK and kb == true and f:IsVisible() and f:GetPropagateKeyboardInput() ~= true then return "swallowed", f end
	end
	return "game"
end

local function press(a, f)
	local hit = a:clickOn(f)
	if hit and hit.GetObjectType and hit:GetObjectType() == "EditBox" then hit:SetFocus() end
	return hit
end

local function cogSettings(where)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	a.W.UI.Toggle(true) w:advance(3)
	a.W.UI.SelectTab(where) w:advance(2)
	-- the window's cog opens Settings; from Drive it asks for the driving page (UI/Window.lua:878-880)
	a.W.UI.OpenSettings(where == "Drive" and "drive" or nil) w:advance(2)
	eq(a.W.UI.SettingsShown(), true, "control: Settings shows")
	return w, a, a.W
end

for _, where in ipairs({ "Drive", "Ride" }) do
	test("T243-4 run 2: Settings from " .. where .. " lets keys through while no key is being set", function()
		local w, a = cogSettings(where)
		local r, f = route(a)
		eq(r, "game", "keys reach the game (took them: " .. tostring(f and f.GetName and f:GetName()) .. ")")
		T.clean(w)
	end)
end

-- guard: Set must still take the next key after the fix (behaviour kept), so it passes on the base too
test("T243-4 run 2: Drive's driving page, Set takes the next key, a press elsewhere gives the keys back", function()
	local w, a, W = cogSettings("Drive")
	local row = W.Mod("UI.Settings.Rows").st.keyRow
	ok(row ~= nil and row:IsVisible(), "control: the key row shows")
	local set
	for _, f in ipairs({ row:GetChildren() }) do
		if f.GetObjectType and f:GetObjectType() == "Button" and f.label and f.label:GetText() == "Set" then set = f end
	end
	ok(set ~= nil, "control: Set button")
	eq(route(a), "game", "before Set: keys reach the game")
	press(a, set) w:advance(1)
	eq(route(a), "swallowed", "while capturing, the row takes the keys")
	press(a, W.UI.settings.panel) w:advance(1)
	eq(route(a), "game", "after a press elsewhere the keys are back")
	-- hiding and showing Settings must not leave the cover taking keys
	W.UI.CloseSettings(true) w:advance(1)
	W.UI.OpenSettings("drive") w:advance(2)
	eq(route(a), "game", "after Settings closes and opens again the keys reach the game")
	T.clean(w)
end)
