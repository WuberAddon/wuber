-- Adopted from the fable-2411 draft in r52 (job 2706).
-- Final home: tests/ui/driver/screens_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the shared helpers every driver page leans on: nameOf (blocked keys to names), plural, short, money, N/S guards (a number is not a name, a string is not money).
-- Pins: call / dr / safeScript turn a failing page script into a reported error, never a raised one; dr of a missing DR function is nil.
-- Pins: opts() is always a table, Char() is nil without a character, inCombat, setShown, toast (through UI.Toast, nothing without it).
-- Pins: para follows its text's height both ways, Pool makes each row once and hides the spare ones, Screen's back chevron (onBack first, else the console), title lift, bar, Wide.
-- Why it matters to a player: every driver page (crew, messages, earnings, wizard) is built from these. If they broke, a page would show "nil" or an
-- error instead of a name, a bad saved value would stop a page opening, and the back chevron would strand the driver on a page.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	return w, r, r.W, r.W.Mod("UI.Driver.Screens")
end

local function frame(r) return r.env.CreateFrame("Frame", nil, r.env.UIParent) end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: contract (registered, no deps, public names and the helpers other pages use)", function()
	local W, w, r, Mod = T.contract("UI.Driver.Screens", "tests/ui/driver/screens_test.lua", {
		["W.Drive"] = "table", ["W.Driver"] = "table", ["D.screens"] = "table", ["UI.drive"] = "table",
		["Mod.Char"] = "function", ["Mod.Pool"] = "function", ["Mod.Screen"] = "function", ["Mod.call"] = "function",
		["Mod.dr"] = "function", ["Mod.inCombat"] = "function", ["Mod.money"] = "function", ["Mod.nameOf"] = "function",
		["Mod.now"] = "function", ["Mod.opts"] = "function", ["Mod.para"] = "function", ["Mod.plural"] = "function",
		["Mod.safeScript"] = "function", ["Mod.setShown"] = "function", ["Mod.short"] = "function", ["Mod.toast"] = "function",
		["Mod.st"] = "table", ["Mod.INNER"] = "number", ["Mod.PAD"] = "number", ["Mod.WIDTH"] = "number",
	})
	eq(W.UI.drive, Mod.st, "UI.drive is the module's state") -- Screens.lua: UI.drive = st
	eq(Mod.WIDTH, 360, "a page is the phone's width") -- Screens.lua:WIDTH
	eq(Mod.INNER, Mod.WIDTH - Mod.PAD * 2, "the inner width is the width less both pads")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: nameOf turns a blocked key into a name, and anything that is not a name into '?'", function()
	local w, r, W, Mod = rider()
	eq(Mod.nameOf("dan rider"), "Dan Rider", "keys are lower case; names are not") -- Screens.lua nameOf
	eq(Mod.nameOf("o'neil dan"), "O'neil Dan", "an apostrophe stays in the word")
	eq(Mod.nameOf("dan-realm"), "Dan-Realm", "a realm after a hyphen too")
	eq(Mod.nameOf("ANA smith"), "ANA Smith", "only the first letter is raised")
	eq(Mod.nameOf(nil), "?", "nil")
	eq(Mod.nameOf(""), "?", "empty")
	eq(Mod.nameOf(42), "?", "a number is not a name (W.Str refuses it)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: plural and short, with the zero, one and custom-plural cases", function()
	local w, r, W, Mod = rider()
	eq(Mod.plural(1, "ride"), "1 ride", "one")
	eq(Mod.plural(0, "ride"), "0 rides", "none is plural")
	eq(Mod.plural(2, "shard"), "2 shards", "two")
	eq(Mod.plural(3, "box", "boxes"), "3 boxes", "own plural")
	eq(Mod.plural(1, "box", "boxes"), "1 box", "own plural, one")
	eq(Mod.short("Vex Shade"), "Vex", "the first name") -- Screens.lua short: W.Short
	eq(Mod.short(nil), "?", "nil is a question mark, never an error")
	eq(Mod.short(42), "?", "a number is not a name")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: money says gold for a number and 0 for anything else (a saved string is not trusted)", function()
	local w, r, W, Mod = rider()
	eq(Mod.money(12345), W.Money(12345), "a number") -- Screens.lua money
	eq(Mod.money(nil), W.Money(0), "nil is zero")
	eq(Mod.money("12345"), W.Money(0), "a string is not a number (W.Num)")
	eq(Mod.money(0 / 0), W.Money(0), "NaN is zero")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: call and dr report a failing function instead of raising it; a missing DR function is nil", function()
	local w, r, W, Mod = rider()
	local a, b = Mod.call(function(x, y) return x + y, "second" end, 1, 2)
	eq(a, 3, "the first result") -- Screens.lua call
	eq(b, "second", "the second result")
	eq(Mod.call(nil), nil, "not a function: nil, no error")
	eq(W.lastError, nil, "and nothing reported")
	eq(Mod.call(function() error("boom") end), nil, "a raising function gives nil")
	ok(tostring(W.lastError):find("drive screens: ", 1, true) and tostring(W.lastError):find("boom", 1, true), "and the error is reported: " .. tostring(W.lastError))
	W.lastError = nil
	eq(Mod.dr("NoSuchDriveFunction"), nil, "dr of a name DR lacks is nil")
	eq(W.lastError, nil, "with no error")
	W.Drive.zzTest = function(n) return n * 2 end
	eq(Mod.dr("zzTest", 21), 42, "dr passes its arguments")
	W.Drive.zzTest = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: opts is always a table, even when the engine gives something else", function()
	local w, r, W, Mod = rider()
	eq(type(Mod.opts()), "table", "the engine's options")
	local real = W.Drive.opts
	W.Drive.opts = function() return "bad saved value" end
	eq(type(Mod.opts()), "table", "a string from the engine becomes a table") -- Screens.lua opts
	eq(next(Mod.opts()), nil, "an empty one")
	W.Drive.opts = function() return nil end
	eq(type(Mod.opts()), "table", "nil too")
	W.Drive.opts = real
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: Char is the character table, or nil without a character, with a failing W.Char, or with a non-table", function()
	local w, r, W, Mod = rider()
	ok(W.myKey, "control: there is a character")
	eq(Mod.Char(), W.Char(), "the same table W.Char gives") -- Screens.lua Char
	local key, real = W.myKey, W.Char
	W.myKey = nil
	eq(Mod.Char(), nil, "no character key: nil")
	W.myKey = key
	W.Char = function() error("no character") end
	eq(Mod.Char(), nil, "W.Char raising: nil, not an error")
	W.Char = function() return "oops" end
	eq(Mod.Char(), nil, "W.Char giving a non-table: nil")
	W.Char = real
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: inCombat follows the fight; setShown shows and hides; now is the game's clock", function()
	local w, r, W, Mod = rider()
	eq(Mod.inCombat(), false, "out of combat")
	w:enterCombat(r)
	eq(Mod.inCombat(), true, "in a fight") -- Screens.lua inCombat: W.InCombat
	w:leaveCombat(r)
	eq(Mod.inCombat(), false, "fight over")
	local f = frame(r)
	Mod.setShown(f, true) ok(f:IsShown(), "shown")
	Mod.setShown(f, false) ok(not f:IsShown(), "hidden")
	Mod.setShown(f, true) Mod.setShown(f, nil) ok(not f:IsShown(), "nil hides")
	eq(Mod.now(), r.env.GetTime(), "now is GetTime")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: toast goes through UI.Toast with its kind and click, and does nothing without it", function()
	local w, r, W, Mod = rider()
	local got
	local real = W.UI.Toast
	W.UI.Toast = function(text, kind, onClick) got = { text, kind, onClick } return "shown" end
	local click = function() end
	eq(Mod.toast("Hello", "warn", click), "shown", "the answer of UI.Toast") -- Screens.lua toast
	eq(got[1], "Hello", "text")
	eq(got[2], "warn", "kind")
	eq(got[3], click, "click")
	W.UI.Toast = nil
	eq(Mod.toast("Nobody home", "info"), nil, "no UI.Toast: nothing, no error")
	W.UI.Toast = real
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: safeScript passes the arguments and reports a failing script instead of raising", function()
	local w, r, W, Mod = rider()
	local f = r.env.CreateFrame("Button", nil, r.env.UIParent)
	local seen
	Mod.safeScript(f, "OnClick", function(self, btn) seen = { self, btn } end)
	f:GetScript("OnClick")(f, "RightButton")
	eq(seen[1], f, "the frame") -- Screens.lua safeScript
	eq(seen[2], "RightButton", "and the button")
	eq(W.lastError, nil, "no error yet")
	Mod.safeScript(f, "OnClick", function() error("zap") end)
	f:GetScript("OnClick")(f, "LeftButton")
	ok(tostring(W.lastError):find("drive OnClick: ", 1, true) and tostring(W.lastError):find("zap", 1, true), "the error names the script: " .. tostring(W.lastError))
	W.lastError = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: para's height follows its text, taller for more lines and back again", function()
	local w, r, W, Mod = rider()
	local fs = Mod.para(frame(r), "caption", "muted", 300)
	fs:SetText("Short.")
	local h1 = fs.paraH
	ok(h1 and h1 > 0, "a one-line height: " .. tostring(h1))
	eq(fs:GetHeight(), h1, "the frame is that tall") -- Screens.lua para: self:SetHeight(self.paraH)
	fs:SetText(("A long line of words that has to wrap onto more lines than one. "):rep(8))
	ok(fs.paraH > h1, "more lines, taller: " .. tostring(fs.paraH) .. " vs " .. h1)
	eq(fs:GetHeight(), fs.paraH, "the frame follows")
	fs:SetText("Short.")
	eq(fs.paraH, h1, "and shrinks back")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: Pool makes each row once, keeps their order and hides the spare ones", function()
	local w, r, W, Mod = rider()
	local made = 0
	local parent = frame(r)
	local pool = Mod.Pool(parent, function(p) made = made + 1 return r.env.CreateFrame("Frame", nil, p) end)
	local a, b = pool.get(1), pool.get(2)
	eq(made, 2, "two rows made") -- Screens.lua Pool.get
	eq(pool.get(1), a, "the first again is the same row")
	eq(pool.get(2), b, "and the second")
	eq(made, 2, "nothing made twice")
	eq(#pool.list, 2, "both listed in order")
	a:Show() b:Show()
	pool.hideFrom(1)
	ok(a:IsShown() and not b:IsShown(), "hideFrom(1) hides what is after the first") -- Screens.lua hideFrom
	pool.hideFrom(0)
	ok(not a:IsShown(), "hideFrom(0) hides all")
	pool.hideFrom(5)
	eq(#pool.list, 2, "hiding past the end is harmless")
	T.clean(w)
end)

local function open()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	T.openDrive(a)
	w:advance(1)
	return w, a, a.W, a.W.Driver, a.W.Mod("UI.Driver.Screens")
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: a page's back chevron asks onBack first and only goes to the console when it says no", function()
	local w, a, W, D, Mod = open()
	D.ShowScreen("crew") w:advance(1)
	eq(D.CurrentScreen(), "crew", "control: on the crew page")
	local s = Mod.Screen(D.ui.root, "Test page", 64)
	ok(not s.frame:IsShown(), "a new page starts hidden") -- Screens.lua Screen: f:Hide()
	s.frame:Show()
	-- two pages never show at once: the test page is the one really shown, so the crew page steps aside
	D.ui.subs.crew.frame:Hide()
	local asked = 0
	s.onBack = function() asked = asked + 1 return true end
	a:click(s.back)
	eq(asked, 1, "onBack was asked")
	eq(D.CurrentScreen(), "crew", "it said it handled the back: the page stays") -- Screens.lua back OnClick
	s.onBack = function() asked = asked + 1 return false end
	a:click(s.back) w:advance(1.5)
	eq(asked, 2, "asked again")
	eq(D.CurrentScreen(), "console", "it said no: back to the console")
	s.frame:Hide()
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.screens: a page's title lifts for the small words under it, a big title does not, the bar has the height asked, Wide shows the stretched middle", function()
	local w, a, W, D, Mod = open()
	local s = Mod.Screen(D.ui.root, "Test page", 64)
	eq(s.title:GetText(), "Test page", "the title") -- Screens.lua Screen
	eq(s.scrollY, 50, "the scroll starts under the header") -- Screens.lua:s.scrollY = 50
	eq(s.bar:GetHeight(), 64, "the bar has the height asked")
	local _, _, _, _, y0 = s.title:GetPoint(1)
	eq(y0, 0, "no small words: the title sits on the line")
	s.right:SetText("2 in crew")
	local _, _, _, _, y1 = s.title:GetPoint(1)
	eq(y1, 7, "small words under it: the title goes up 7") -- Screens.lua s.right.SetText
	s.right:SetText("")
	local _, _, _, _, y2 = s.title:GetPoint(1)
	eq(y2, 0, "words gone: back on the line")
	ok(not s.frame.bgMid:IsShown(), "folded: no stretched middle")
	s.Wide(true)
	ok(s.frame.bgMid:IsShown(), "unfolded: the stretched middle shows") -- Screens.lua s.Wide
	s.Wide(false)
	ok(not s.frame.bgMid:IsShown(), "folded again")
	local bare = Mod.Screen(D.ui.root, "No bar")
	eq(bare.bar, nil, "no bottom: no bar")
	local big = Mod.Screen(D.ui.root, "Big", nil, { bigTitle = true })
	ok(big.scrollY > 50, "a big title pushes the scroll area down: " .. tostring(big.scrollY)) -- Screens.lua scrollY = 46 + th + 2
	big.right:SetText("words")
	local _, _, _, _, yb = big.title:GetPoint(1)
	eq(yb, -46, "a big title does not lift") -- Screens.lua:if big then return end
	T.clean(w)
end)
