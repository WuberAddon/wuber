-- The fake game routes a key press the way the 1.60.1 client does (conformance, from the client's documented rules):
--   1. a focused, shown EditBox takes the key (it types it): no binding runs, no jump (SPACE), nothing else sees it;
--   2. then every shown frame with keyboard input on gets OnKeyDown; one whose "propagate keyboard input" is off swallows the key;
--   3. only then the bindings (an addon's override binding, the key list) run.
-- Before this, Client:pressKey ran the binding whatever had the keyboard, so a test could not see "SPACE typed into the search box
-- also pressed the big button" or "the Settings key capture let the key through". Hand-written; no outside code or lists copied.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function bound(key)
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE" })
	local env = c.env
	local clicks = 0
	local btn = env.CreateFrame("Button", "KeyRouteBtn", env.UIParent)
	btn:SetSize(40, 40) btn:SetPoint("CENTER")
	btn:SetScript("OnClick", function() clicks = clicks + 1 end)
	env.SetOverrideBindingClick(env.UIParent, true, key, "KeyRouteBtn")
	return w, c, env, btn, function() return clicks end
end

test("key routing: a bound key clicks its button when nothing else has the keyboard (control)", function()
	local w, c, env, _, clicks = bound("SPACE")
	ok(c:pressKey("SPACE"), "the key was used")
	eq(clicks(), 1, "one click")
	T.clean(w)
end)

test("key routing: a focused EditBox takes SPACE; the bound button is not clicked", function()
	local w, c, env, _, clicks = bound("SPACE")
	local eb = env.CreateFrame("EditBox", "KeyRouteEdit", env.UIParent)
	eb:SetSize(100, 20) eb:SetPoint("TOP") eb:SetAutoFocus(false)
	eb:SetFocus()
	eq(c:pressKey("SPACE"), false, "the key is not handed to a binding while a box is being typed in")
	eq(clicks(), 0, "the bound button did not click")
	eb:ClearFocus()
	ok(c:pressKey("SPACE"), "focus gone: the binding works again")
	eq(clicks(), 1, "one click")
	T.clean(w)
end)

test("key routing: a shown keyboard frame with propagate off swallows the key after its OnKeyDown", function()
	local w, c, env, _, clicks = bound("SPACE")
	local cap = env.CreateFrame("Frame", "KeyRouteCap", env.UIParent)
	local got = {}
	cap:SetScript("OnKeyDown", function(_, k) got[#got + 1] = k end)
	cap:EnableKeyboard(true)
	cap:SetPropagateKeyboardInput(false)
	c:pressKey("SPACE")
	eq(got[1], "SPACE", "the frame saw the key")
	eq(clicks(), 0, "and the binding did not run")
	cap:Hide()
	c:pressKey("SPACE")
	eq(#got, 1, "a hidden frame sees nothing")
	eq(clicks(), 1, "the binding runs again")
	T.clean(w)
end)

test("key routing: propagate on lets the key through to the binding; keyboard off sees nothing", function()
	local w, c, env, _, clicks = bound("SPACE")
	local cap = env.CreateFrame("Frame", "KeyRouteCap2", env.UIParent)
	local got = 0
	cap:SetScript("OnKeyDown", function() got = got + 1 end)
	cap:EnableKeyboard(true)
	cap:SetPropagateKeyboardInput(true)
	c:pressKey("SPACE")
	eq(got, 1, "seen")
	eq(clicks(), 1, "and passed on to the binding")
	cap:EnableKeyboard(false)
	c:pressKey("SPACE")
	eq(got, 1, "keyboard off: not seen")
	eq(clicks(), 2, "binding ran")
	T.clean(w)
end)

-- Wuber on top of the rules: the Settings key capture (UI/Settings/Rows.lua) takes keys only while it waits for one
test("Wuber: the big-button key still clicks the button while Settings is open and no capture is running", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANA)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	d.W.Drive.SetKey("SPACE")
	w:advance(1)
	ok(d.binding and d.binding.key == "SPACE", "the key is bound")
	local btn = rawget(d.env, d.binding.button)
	local clicks = 0
	btn:HookScript("OnClick", function() clicks = clicks + 1 end)
	d.W.UI.OpenSettings()
	w:advance(1)
	ok(d:pressKey("SPACE"), "SPACE with Settings open reaches the big button")
	eq(clicks, 1, "one click")
	T.clean(w)
end)
