-- #202 (T243-1) the back arrows in the real client: Texture:GetTexture() gives a numeric file id there, never the name, so the
-- old finder (a glyph texture ending "back") found no arrow, UI.HeadHit never cut the drag strip off it and the strip took every
-- real click. The fake game now answers GetTexture with a negative file id for the addon's own media (GetTextureFilePath keeps the
-- path). Each test clicks THROUGH the topmost frame at the arrow's centre (Client:clickOn, hit-tested), never OnClick directly.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function name(f) return (f and f.GetName and f:GetName()) or ("level " .. tostring(f and f:GetFrameLevel()) .. " " .. tostring(f and f:GetObjectType())) end

local function backs(a)
	local out = {}
	for _, f in ipairs(a.frames) do
		local ok1, ot = pcall(f.GetObjectType, f)
		if ok1 and ot == "Button" and rawget(f, "wuberBackArrow") and H.visible(f) then out[#out + 1] = f end
	end
	return out
end

local function world()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	a.W.UI.Toggle(true) w:advance(3)
	return w, a, a.W
end

local function realClick(w, a, what)
	local list = backs(a)
	eq(#list, 1, what .. ": exactly one back arrow shows")
	local arrow = list[1]
	local hit = a:clickOn(arrow) w:advance(2)
	eq(hit == arrow, true, what .. ": the real click landed on " .. name(hit) .. ", not on the back arrow")
end

test("#202 the fake game answers GetTexture with a file id and GetTextureFilePath with the path", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	W.UI.OpenSettings() w:advance(2)
	local arrow = backs(a)[1]
	ok(arrow ~= nil, "control: the back arrow is flagged wuberBackArrow")
	eq(type(arrow.glyph:GetTexture()), "number", "GetTexture is a file id")
	eq(arrow.glyph:GetTextureFilePath():sub(-4), "back", "GetTextureFilePath is the path")
	T.clean(w)
end)

test("#202 back arrow with file ids: Settings from Ride, the real click lands on the arrow and Settings closes", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	W.UI.OpenSettings() w:advance(2)
	eq(W.UI.SettingsShown(), true, "control: Settings shows")
	realClick(w, a, "Settings from Ride")
	eq(W.UI.SettingsShown(), false, "Settings is put away")
	eq(W.UI.state.tab, "Ride", "back on the Ride tab")
	T.clean(w)
end)

test("#202 back arrow with file ids: Settings from Drive, the real click lands on the arrow and the page changes", function()
	local w, a, W = world()
	W.UI.SelectTab("Drive") w:advance(2)
	W.UI.OpenSettings("drive") w:advance(2)
	eq(W.UI.SettingsShown(), true, "control: Settings shows")
	realClick(w, a, "Settings from Drive") -- opens at the Driving section: the first step stays in Settings
	realClick(w, a, "Settings home")
	eq(W.UI.SettingsShown(), false, "Settings is put away")
	eq(W.UI.state.tab, "Drive", "back on the Drive tab")
	T.clean(w)
end)

test("#202 back arrow with file ids: Your crew, the real click lands on the arrow and the crew page goes", function()
	local w, a, W = world()
	W.UI.SelectTab("Drive") w:advance(2)
	W.Driver.ShowScreen("crew") w:advance(3)
	eq(W.Driver.CurrentScreen(), "crew", "control: Your crew shows")
	realClick(w, a, "Your crew")
	ok(W.Driver.CurrentScreen() ~= "crew", "the crew page is gone: " .. tostring(W.Driver.CurrentScreen()))
	T.clean(w)
end)

test("#202 back arrow with file ids: Drive/customers, the real click lands on the arrow and the page goes", function()
	local w, a, W = world()
	W.UI.SelectTab("Drive") w:advance(2)
	W.Driver.ShowScreen("customers") w:advance(3)
	eq(W.Driver.CurrentScreen(), "customers", "control: Customers shows")
	realClick(w, a, "Drive/customers")
	eq(W.Driver.CurrentScreen(), "console", "back on Drive/console")
	T.clean(w)
end)
