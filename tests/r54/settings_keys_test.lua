-- #203 (T243-4) "I can't use any keys when the window's open ... on settings you cannot use any of the keys".
-- In the game a click on the Settings search pill puts the keyboard in the box and a click elsewhere does NOT take it out
-- again, so every key goes to the box until Escape. Promise: keys reach the game unless the player is typing in a box:
-- a press outside the box (Settings background, a row, a tab, the window header), Settings hiding and showing, and a tab
-- switch all let go of the box; a press in the box still keeps it; the key-capture row never leaves the keyboard taken.
-- The key routing below is this test's own (the fake game has none): a key goes to the focused EditBox, else it is swallowed
-- by a visible keyboard-enabled frame that does not propagate it, else it reaches the game.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function route(w, a)
	for _, f in ipairs(a.frames) do
		local okT, ot = pcall(f.GetObjectType, f)
		if okT and ot == "EditBox" and f:HasFocus() and f:IsVisible() then return "box" end
	end
	for _, f in ipairs(a.frames) do
		local okK, kb = pcall(f.IsKeyboardEnabled, f)
		if okK and kb == true and f:IsVisible() and f:GetPropagateKeyboardInput() ~= true then return "swallowed" end
	end
	return "game"
end

local function world(where)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	a.W.UI.Toggle(true) w:advance(3)
	a.W.UI.SelectTab(where) w:advance(2)
	a.W.UI.OpenSettings() w:advance(2) -- (Settings' home, where the search box is; from the Drive tab the window came from Drive)
	eq(a.W.UI.SettingsShown(), true, "control: Settings shows")
	return w, a, a.W
end

-- a real press: the fake game's hit test; the game itself puts the keyboard in an EditBox that takes the press
local function press(a, f)
	local hit = a:clickOn(f)
	if hit and hit.GetObjectType and hit:GetObjectType() == "EditBox" then hit:SetFocus() end
	return hit
end

local function box(W) return W.UI.settings.find.box end

local function eachWhere(name, fn)
	for _, where in ipairs({ "Ride", "Drive" }) do
		test(name .. " (Settings from " .. where .. ")", function()
			local w, a, W = world(where)
			fn(w, a, W)
			T.clean(w)
		end)
	end
end

eachWhere("#203 keys: a press on the search pill takes the keyboard, a press on the Settings background gives it back", function(w, a, W)
	local b = box(W)
	eq(route(w, a), "game", "control: nothing focused, keys reach the game")
	press(a, b) w:advance(1)
	eq(b.edit:HasFocus(), true, "control: the press on the pill focuses the box")
	eq(route(w, a), "box", "control: keys go to the box while the player types")
	local st = W.UI.settings
	local hit = press(a, st.panel) w:advance(1)
	ok(hit ~= nil, "the press landed on something")
	eq(b.edit:HasFocus(), false, "the box lets go after a press on the Settings background (" .. tostring(hit and hit.GetName and hit:GetName()) .. ")")
	eq(route(w, a), "game", "keys reach the game again")
end)

eachWhere("#203 keys: a press on the window header or a tab gives the keyboard back", function(w, a, W)
	local b = box(W)
	press(a, b) w:advance(1)
	eq(b.edit:HasFocus(), true, "control: focused")
	local ui = W.UI.state
	press(a, ui.top) w:advance(1)
	eq(b.edit:HasFocus(), false, "a press on the window header lets go")
	press(a, b) w:advance(1)
	eq(b.edit:HasFocus(), true, "control: focused again")
	local sec
	for _, f in ipairs(W.UI.settings.rows or {}) do if f.IsShown and f:IsShown() and f.GetObjectType and f:GetObjectType() == "Button" then sec = f break end end
	if sec then press(a, sec) w:advance(1) eq(b.edit:HasFocus(), false, "a press on a Settings row lets go") end
end)

-- guard: a press inside the box must keep the focus, the fix must not take typing away
eachWhere("#203 keys: a press inside the box keeps the keyboard so the player can type", function(w, a, W)
	local b = box(W)
	press(a, b) w:advance(1)
	press(a, b) w:advance(1)
	eq(b.edit:HasFocus(), true, "still typing")
	eq(route(w, a), "box", "keys go to the box")
end)

eachWhere("#203 keys: a focused box does not survive Settings hiding and showing, or a tab switch", function(w, a, W)
	local b = box(W)
	b.edit:SetFocus()
	W.UI.CloseSettings(true) w:advance(1)
	eq(b.edit:HasFocus(), false, "closing Settings lets go")
	b.edit:SetFocus() -- a focus that outlived the page (the game keeps it on a hidden box)
	W.UI.OpenSettings() w:advance(1)
	eq(b.edit:HasFocus(), false, "showing Settings starts without the keyboard")
	b.edit:SetFocus()
	W.UI.SelectTab("Trips") w:advance(2)
	eq(b.edit:HasFocus(), false, "a tab switch lets go")
	eq(route(w, a), "game", "keys reach the game")
end)

test("#203 keys: the key-capture row gives the keyboard back when the player presses elsewhere", function()
	local w, a, W = world("Drive")
	W.UI.OpenSettings("drive") w:advance(2) -- the Driving section, where the key row is
	local st = W.UI.settings
	local row = W.Mod("UI.Settings.Rows").st.keyRow
	ok(row ~= nil and row:IsVisible(), "control: the key row shows")
	local set
	for _, f in ipairs({ row:GetChildren() }) do
		if f.GetObjectType and f:GetObjectType() == "Button" and f.label and f.label:GetText() == "Set" then set = f end
	end
	ok(set ~= nil, "control: the Set button of the key row")
	press(a, set) w:advance(1)
	eq(route(w, a), "swallowed", "control: while capturing, the key row takes the keys")
	press(a, st.panel) w:advance(1)
	eq(route(w, a), "game", "after a press elsewhere the keys reach the game")
	T.clean(w)
end)
