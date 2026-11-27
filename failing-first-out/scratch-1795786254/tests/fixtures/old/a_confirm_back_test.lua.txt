local T = ...
local test = T.test
-- r53 A (the author 24 Nov, bug 1): from Ride/confirm one click on the Ride tab, the back chevron, or close + reopen reaches Ride/home
local function setup()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local UI = c.W.UI
	local K = c.W.Mod("UI.Kit")
	UI.Toggle(true) w:advance(3)
	return w, c, UI, K
end
local function openConfirm(w, c, UI, K)
	local key = "Mia Runner-Test"
	c.W.drivers = c.W.drivers or {}
	c.W.drivers[key] = { name = "Mia Runner", key = key, dest = "Undercity", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = c.env.GetTime() }
	UI.Show("confirm", key) w:advance(1)
	assert(K.ui.screen == "confirm", "control: on confirm, is " .. tostring(K.ui.screen))
	return key
end
local function rideButton(K)
	for _, tab in ipairs(K.ui.tabs) do if tab.name == "Ride" then return tab.button end end
end
test("r53 A: the Ride tab on Ride/confirm leads to Ride/home", function()
	local w, c, UI, K = setup()
	openConfirm(w, c, UI, K)
	rideButton(K):GetScript("OnClick")(rideButton(K)) w:advance(1)
	assert(K.ui.screen == "home", "still on " .. tostring(K.ui.screen))
	T.clean(w)
end)
test("r53 A: close and reopen on Ride/confirm (no request sent) opens Ride/home", function()
	local w, c, UI, K = setup()
	openConfirm(w, c, UI, K)
	UI.Toggle(false) w:advance(2)
	UI.Toggle(true) w:advance(2)
	assert(K.ui.screen == "home", "reopened on " .. tostring(K.ui.screen))
	T.clean(w)
end)
-- guard: the back chevron already led to Home
test("r53 A guard: the back chevron on Ride/confirm leads to Ride/home", function()
	local w, c, UI, K = setup()
	openConfirm(w, c, UI, K)
	local back = K.ui.screens and K.ui.screens.confirm and K.ui.screens.confirm.back
	assert(back, "control: the chevron exists")
	back:GetScript("OnClick")(back) w:advance(1)
	assert(K.ui.screen == "home", "on " .. tostring(K.ui.screen))
	T.clean(w)
end)
-- guard: UI.Show("confirm", key) from a shut window still opens that driver's page
test("r53 A guard: Show confirm from a shut window opens that driver's confirm page", function()
	local w, c, UI, K = setup()
	local key = "Mia Runner-Test"
	c.W.drivers = c.W.drivers or {}
	c.W.drivers[key] = { name = "Mia Runner", key = key, dest = "Undercity", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = c.env.GetTime() }
	UI.Toggle(false) w:advance(2)
	UI.Show("confirm", key) w:advance(2)
	assert(K.ui.screen == "confirm" and K.ui.confirmKey == key, "on " .. tostring(K.ui.screen))
	T.clean(w)
end)
