-- Wuber 2.4, fix round 3 group H: Wuber in the game's own Key Bindings list (Wuber/Bindings.xml).
-- The game loads Bindings.xml from the addon folder by itself (the TOC must NOT list it: a listed copy registers twice;
-- source: another addon's TOC note, FAKE-GAME-HINTS), so the fake game reads it the same way (Client:gameBindings,
-- Client:setGameKey, Client:pressKey).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local TOGGLE = "WUBER_TOGGLE"
local CLICK = "CLICK WuberDriveButton:LeftButton"

local function bindingNamed(c, name)
	for _, b in ipairs(c.gameBindings or {}) do
		if b.name == name then return b end
	end
end

local function openDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver open")
	w:advance(3)
	return w, a
end

test("v24 f3h: Bindings.xml lists Open Wuber and the big button under a Wuber heading, and the TOC leaves it to the game", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local t = bindingNamed(a, TOGGLE)
	ok(t, "a binding " .. TOGGLE)
	eq(t and t.header, "WUBER", "its heading")
	eq(t and t.category, "ADDONS", "in the AddOns category")
	local c = bindingNamed(a, CLICK)
	ok(c, "a click binding on the existing secure button")
	eq(c and c.header, nil, "one heading, on the first entry only")
	eq(a.env.BINDING_HEADER_WUBER, "Wuber", "the heading text")
	eq(a.env.BINDING_NAME_WUBER_TOGGLE, "Open or close Wuber", "the toggle's name")
	eq(a.env["BINDING_NAME_" .. CLICK], "Key for the big button", "the big button's name is the Settings row's")
	for _, f in ipairs(T.H.tocFiles("Wuber")) do
		ok(not f:lower():match("bindings"), "the TOC does not list " .. f)
	end
	for _, b in ipairs(a.gameBindings) do ok(#(a.env["BINDING_NAME_" .. b.name] or "") <= 22, "short name: " .. b.name) end
end)

test("v24 f3h: a key bound to Open Wuber in the game's list opens and closes the window", function()
	local w, a = openDriver()
	ok(a:setGameKey("F6", TOGGLE), "the key is set in the game's list")
	local ui = a.W.UI
	ok(not ui.IsShown(), "closed at first")
	ok(a:pressKey("F6"), "the key did something")
	w:advance(1)
	ok(ui.IsShown(), "open after the key")
	ok(a:pressKey("F6"), "the key again")
	w:advance(1)
	ok(not ui.IsShown(), "closed after the second press")
	T.clean(w)
end)

test("v24 f3h: a key bound to the big button in the game's list is a real click on the secure button", function()
	local w, a = openDriver()
	local DR = a.W.Drive
	local clicks = 0
	a.env.WuberDriveButton:HookScript("PreClick", function() clicks = clicks + 1 end)
	ok(a:setGameKey("F7", CLICK), "the key is set in the game's list")
	ok(a:pressKey("F7"), "the key clicks")
	eq(clicks, 1, "one click on WuberDriveButton")
	-- the Settings row's own key keeps working beside it, and the two do not fight
	DR.SetKey("F5")
	w:advance(0.5)
	ok(a:pressKey("F5"), "the Settings key still clicks")
	eq(clicks, 2, "one click from the Settings key")
	ok(a:pressKey("F7"), "the game's list key still clicks")
	eq(clicks, 3, "one click from the list key")
	-- the same key in both places: still one click per press
	ok(a:setGameKey("F5", CLICK), "the same key set in the list too")
	ok(a:pressKey("F5"), "pressed")
	eq(clicks, 4, "one click, not two")
	DR.SetKey(nil)
	w:advance(0.5)
	ok(a:pressKey("F5"), "clearing the Settings key leaves the list's key")
	eq(clicks, 5, "the list key clicks after Clear")
	T.clean(w)
end)

test("v24 f3h: loading the bindings and pressing an unset key in a fight touch nothing secure", function()
	local w, a = openDriver()
	eq(#w.violations, 0, "no protected call from loading the bindings")
	w:enterCombat(a)
	ok(a:pressKey("F6") == false, "no key set, no press")
	eq(#w.violations, 0, "nothing secure touched in combat")
	w:leaveCombat(a)
	T.clean(w)
end)
