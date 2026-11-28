-- Mutation run guards for Wuber/UI/Commands.lua, Wuber/UI/Kit.lua, and Wuber/UI/InFlight.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function captureSay(c)
	local lines = {}
	local origAdd = c.env.DEFAULT_CHAT_FRAME and c.env.DEFAULT_CHAT_FRAME.AddMessage
	if c.env.DEFAULT_CHAT_FRAME then
		c.env.DEFAULT_CHAT_FRAME.AddMessage = function(self, msg)
			lines[#lines + 1] = tostring(msg)
			if origAdd then return origAdd(self, msg) end
		end
	end
	return lines, function()
		if c.env.DEFAULT_CHAT_FRAME and origAdd then
			c.env.DEFAULT_CHAT_FRAME.AddMessage = origAdd
		end
	end
end

local function hasLine(lines, pat)
	for _, l in ipairs(lines) do
		if l:find(pat, 1, true) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Wuber/UI/Commands.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Commands.lua:90 (if cond negated: drive on/off misreports when DriverBeacon is false)
-- guards Wuber/UI/Commands.lua:93 (drop statement: drive on omits online price message when DriverBeacon is true)
test("mutation b5 ui commands: /wuber drive on reports unloaded beacon or online price", function()
	local w = T.newWorld({ clubs = true })
	local c = T.driver(w, T.ANITA, { spot = "Orgrimmar", price = 50000 })
	T.settle(w)
	local lines, restore = captureSay(c)
	local origSet = c.W.SetDriving
	local origBeacon = c.W.DriverBeacon
	local origOnNet = c.W.OnNetwork
	local origActive = c.W.Drive.Active
	local origCmd = c.W.Drive.Command

	c.W.SetDriving = function() return true end
	c.W.OnNetwork = function() return true end
	c.W.Drive.Active = function() return false end
	c.W.Drive.Command = nil

	-- 1) DriverBeacon() == false -> "Driver mode isn't loaded"
	c.W.DriverBeacon = function() return false end
	c:slash("/wuber drive on")
	ok(hasLine(lines, "Driver mode isn't loaded"), "warns when DriverBeacon is false")

	-- 2) DriverBeacon() == true -> "You're online as a driver at ..."
	for i = 1, #lines do lines[i] = nil end
	c.W.DriverBeacon = function() return true end
	c:slash("/wuber drive on")
	ok(hasLine(lines, "You're online as a driver at"), "reports online price when DriverBeacon is true")

	restore()
	c.W.SetDriving = origSet
	c.W.DriverBeacon = origBeacon
	c.W.OnNetwork = origOnNet
	c.W.Drive.Active = origActive
	c.W.Drive.Command = origCmd
	T.clean(w)
end)

-- guards Wuber/UI/Commands.lua:140 (drop statement: /wuber price omits provider message)
-- guards Wuber/UI/Commands.lua:145 (drop statement: /wuber price with no arg omits current price)
-- guards Wuber/UI/Commands.lua:150 (drop statement: /wuber price with invalid arg omits error hint)
-- guards Wuber/UI/Commands.lua:162 (cmp ==->~=: /wuber price skips DR.SetPrice when engine is on)
-- guards Wuber/UI/Commands.lua:163 (drop statement: /wuber price does not update c.price)
-- guards Wuber/UI/Commands.lua:164 (drop statement: /wuber price does not fire SETTINGS price)
-- guards Wuber/UI/Commands.lua:165 (drop statement: /wuber price does not call W.SendBeacon)
-- guards Wuber/UI/Commands.lua:166 (drop statement: /wuber price does not confirm new price)
test("mutation b5 ui commands: /wuber price handles provider, query, invalid input, and full update", function()
	local w = T.newWorld({ clubs = true })
	local c = T.driver(w, T.ANITA, { spot = "Orgrimmar", price = 50000 })
	T.settle(w)
	local lines, restore = captureSay(c)
	local origProv = c.W.Provider

	-- 1) Provider set
	c.W.Provider = function() return "Ritual Rides" end
	c:slash("/wuber price 1g")
	ok(hasLine(lines, "Ritual Rides sets your price."), "provider message printed")

	-- 2) No arg query
	for i = 1, #lines do lines[i] = nil end
	c.W.Provider = function() return nil end
	c:slash("/wuber price")
	ok(hasLine(lines, "Your price is"), "current price printed on empty arg")

	-- 3) Invalid arg
	for i = 1, #lines do lines[i] = nil end
	c:slash("/wuber price notaprice")
	ok(hasLine(lines, "That isn't a price."), "invalid price hint printed")

	-- 4) Valid price update with engine on
	for i = 1, #lines do lines[i] = nil end
	local drSetPrice, firedPrice, sentBeacon
	local origActive = c.W.Drive.Active
	local origSetPrice = c.W.Drive.SetPrice
	local origFire = c.W.Fire
	local origSend = c.W.SendBeacon
	c.W.Drive.Active = function() return true end
	c.W.Drive.SetPrice = function(v) drSetPrice = v end
	c.W.Fire = function(ev, key)
		if ev == "SETTINGS" and key == "price" then firedPrice = true end
		return origFire(ev, key)
	end
	c.W.SendBeacon = function()
		sentBeacon = true
		return origSend()
	end
	c:slash("/wuber price 5g")
	eq(drSetPrice, 50000, "DR.SetPrice called with 50000 copper")
	eq(c.W.Char().price, 50000, "c.price updated")
	eq(firedPrice, true, "SETTINGS price event fired")
	eq(sentBeacon, true, "W.SendBeacon called")
	ok(hasLine(lines, "Your price is now"), "confirmation printed")

	restore()
	c.W.Provider = origProv
	c.W.Drive.Active = origActive
	c.W.Drive.SetPrice = origSetPrice
	c.W.Fire = origFire
	c.W.SendBeacon = origSend
	T.clean(w)
end)

-- guards Wuber/UI/Commands.lua:197 (if cond negated: /wuber tips runs ShowAgain when ShowNow is missing)
test("mutation b5 ui commands: /wuber tips on calls ShowNow and skips when ShowNow is not a function", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local lines, restore = captureSay(c)
	local tipsMod = c.W.Mod("UI.Tips")
	local origShowNow = tipsMod.ShowNow
	local origShowAgain = tipsMod.ShowAgain
	local called = 0
	tipsMod.ShowNow = function()
		called = called + 1
		return false
	end
	c:slash("/wuber tips on")
	eq(called, 1, "ShowNow called on /wuber tips on")
	ok(hasLine(lines, "The next one shows when you open Wuber."), "deferred tips message shown when ShowNow returns false")

	-- Negative case: when ShowNow is nil, /wuber tips again must NOT run ShowAgain
	for i = 1, #lines do lines[i] = nil end
	local againCalled = 0
	tipsMod.ShowNow = nil
	tipsMod.ShowAgain = function()
		againCalled = againCalled + 1
		return false
	end
	c:slash("/wuber tips again")
	eq(againCalled, 0, "ShowAgain not called when ShowNow is nil")
	ok(hasLine(lines, "Tips are on."), "plain 'Tips are on.' shown when ShowNow is nil")

	restore()
	tipsMod.ShowNow = origShowNow
	tipsMod.ShowAgain = origShowAgain
	T.clean(w)
end)

-- guards Wuber/UI/Commands.lua:232 (cmp ==->~=: /wuber why skips module Why functions)
test("mutation b5 ui commands: /wuber why queries module Why functions and prints reasons", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local lines, restore = captureSay(c)
	local tipsMod = c.W.Mod("UI.Tips")
	local origWhy = tipsMod.Why
	tipsMod.Why = function() return "Tips: off for test." end
	c:slash("/wuber why")
	ok(hasLine(lines, "Hidden right now, and why:"), "header printed when a reason exists")
	ok(hasLine(lines, "Tips: off for test."), "module Why reason printed")

	restore()
	tipsMod.Why = origWhy
	T.clean(w)
end)

-- guards Wuber/UI/Commands.lua:263 (if cond negated: /wuber status mishandles nil ChannelIndex)
-- guards Wuber/UI/Commands.lua:266 (drop statement: /wuber status omits not-joined line)
test("mutation b5 ui commands: /wuber status reports not joined when NetStatusLines absent and ChannelIndex nil", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local lines, restore = captureSay(c)
	local origNetStatus = c.W.NetStatusLines
	local origChanIdx = c.W.ChannelIndex
	c.W.NetStatusLines = nil
	c.W.ChannelIndex = function() return nil end
	c:slash("/wuber status")
	ok(hasLine(lines, "Network: not joined. Requests still work by whisper."), "not-joined message printed")

	restore()
	c.W.NetStatusLines = origNetStatus
	c.W.ChannelIndex = origChanIdx
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/UI/Kit.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Kit.lua:97 (return -> nil: inCombat returns nil when W.InCombat absent)
test("mutation b5 ui kit: Kit.inCombat falls back to InCombatLockdown when W.InCombat is absent", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local Kit = c.W.Mod("UI.Kit")
	local origWInCombat = c.W.InCombat
	local origICL = c.env.InCombatLockdown
	c.W.InCombat = nil
	c.env.InCombatLockdown = function() return true end
	eq(Kit.inCombat(), true, "Kit.inCombat returns true in combat")
	c.env.InCombatLockdown = function() return false end
	eq(Kit.inCombat(), false, "Kit.inCombat returns false out of combat")

	c.W.InCombat = origWInCombat
	c.env.InCombatLockdown = origICL
	T.clean(w)
end)

-- guards Wuber/UI/Kit.lua:167 (cmp <=->>: FillSaved fails to hide strip when seconds <= 0)
-- guards Wuber/UI/Kit.lua:173 (cmp >-><=: FillSaved marks value <= price as worth)
-- guards Wuber/UI/Kit.lua:174 (drop statement: FillSaved leaves strip.sub blank)
-- guards Wuber/UI/Kit.lua:176 (if cond negated: FillSaved anchors head at TOPLEFT when not worth)
-- guards Wuber/UI/Kit.lua:182 (return -> nil: FillSaved returns nil instead of sec)
test("mutation b5 ui kit: FillSaved hides on non-positive seconds and formats worth/non-worth strips", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local UI = c.W.UI
	local TTheme = c.W.Theme
	local strip = c.env.CreateFrame("Frame", nil, c.env.UIParent)
	strip:SetSize(280, 44)
	strip.head = TTheme.Text(strip, "sub", "white", "LEFT", "bold")
	strip.sub = TTheme.Text(strip, "caption", "muted", "LEFT", "regular")

	-- 1) seconds == 0 -> hides and returns nil
	strip:Show()
	eq(UI.FillSaved(strip, "Orgrimmar", 5000, 0), nil, "0 seconds returns nil")
	eq(strip:IsShown(), false, "0 seconds hides strip")

	-- 2) value > price -> worth true, sub populated, head at TOPLEFT, returns sec
	local origTV = c.W.TimeValue
	c.W.TimeValue = function() return 20000 end
	eq(UI.FillSaved(strip, "Orgrimmar", 5000, 600), 600, "returns 600 seconds")
	ok((strip.sub:GetText() or ""):find("Worth about", 1, true) ~= nil, "sub text set when worth > price")
	local ptWorth = strip.head:GetPoint(1)
	eq(ptWorth, "TOPLEFT", "head anchored TOPLEFT when worth is true")

	-- 3) value <= price -> worth false, sub empty, head at LEFT
	c.W.TimeValue = function() return 5000 end
	eq(UI.FillSaved(strip, "Orgrimmar", 5000, 600), 600, "returns 600 seconds when value == price")
	eq(strip.sub:GetText() or "", "", "sub text empty when value == price")
	local ptNotWorth = strip.head:GetPoint(1)
	eq(ptNotWorth, "LEFT", "head anchored LEFT when worth is false")

	c.W.TimeValue = origTV
	T.clean(w)
end)

-- guards Wuber/UI/Kit.lua:237 (cmp ~=->==: Prominence gives non-open driver non-zero glow)
-- guards Wuber/UI/Kit.lua:242 (cmp <->>=: Prominence miscounts cheaper open drivers)
-- guards Wuber/UI/Kit.lua:245 (cmp <=->>: Prominence divides by zero when n == 1)
-- guards Wuber/UI/Kit.lua:246 (return -> nil: Prominence returns nil for n >= 2)
test("mutation b5 ui kit: Prominence handles non-open, single open, and multi-open price ranking", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local UI = c.W.UI
	local origGlow = c.W.Prominence
	c.W.Prominence = nil

	local busy = { key = "b", state = "busy", price = 1000 }
	local open1 = { key = "o1", state = "open", price = 2000 }
	local open2 = { key = "o2", state = "open", price = 5000 }

	local gBusy, crBusy = UI.Prominence(busy, { busy, open1, open2 })
	eq(gBusy, 0, "busy driver gets 0 glow")
	eq(crBusy, false, "busy non-creator is false")

	local gSingle = UI.Prominence(open1, { open1, busy })
	eq(gSingle, 0.7, "single open driver gets 0.7 glow")

	local gCheapest = UI.Prominence(open1, { open1, open2 })
	eq(gCheapest, 0.7, "cheapest of 2 open drivers gets 0.7")

	local gPricier = UI.Prominence(open2, { open1, open2 })
	ok(math.abs(gPricier - 0.15) < 0.001, "pricier of 2 open drivers gets 0.15: " .. tostring(gPricier))

	c.W.Prominence = origGlow
	T.clean(w)
end)

-- guards Wuber/UI/Kit.lua:259 (cmp <->>=: sortDrivers reverses key tie-breaker)
test("mutation b5 ui kit: UI.Drivers sorts same-name same-price drivers by key ascending", function()
	local w = T.newWorld({ clubs = true })
	local c = T.rider(w, T.DAN, { spot = "Durotar" })
	T.settle(w)
	local origDS = c.W.DriversSorted
	c.W.DriversSorted = nil
	c.W.drivers["alpha-b"] = { name = "Alpha", key = "alpha-b", dest = "Orgrimmar", price = 5000, state = "open", heard = c.env.GetTime() }
	c.W.drivers["alpha-a"] = { name = "alpha", key = "alpha-a", dest = "Orgrimmar", price = 5000, state = "open", heard = c.env.GetTime() }
	local list = c.W.UI.Drivers()
	eq(#list, 2, "two drivers returned")
	eq(list[1].key, "alpha-a", "alpha-a sorted before alpha-b")
	eq(list[2].key, "alpha-b", "alpha-b sorted after alpha-a")

	c.W.DriversSorted = origDS
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/UI/InFlight.lua guards
---------------------------------------------------------------------------

local function setupInFlight(opts)
	opts = opts or {}
	local w = T.newWorld({ clubs = true })
	local r = T.rider(w, T.DAN, { spot = "Durotar", screenW = 1024, screenH = 768 })
	T.settle(w)
	local origTaxi = r.env.UnitOnTaxi
	local origLeft = r.W.FlightLeft
	r.env.UnitOnTaxi = function() return opts.onTaxi ~= false end
	r.W.FlightLeft = function() return opts.left or 180, opts.dest or "Orgrimmar" end
	r.W.drivers["anita lift"] = {
		name = "Anita Lift",
		key = "anita lift",
		dest = opts.dest or "Orgrimmar",
		price = 50000,
		state = "open",
		heard = r.env.GetTime(),
	}
	return w, r, function()
		r.env.UnitOnTaxi = origTaxi
		r.W.FlightLeft = origLeft
	end
end

-- guards Wuber/UI/InFlight.lua:412 (return false->true: Mod.Check returns true when not on taxi)
test("mutation b5 ui inflight: Mod.Check returns false when not on taxi", function()
	local w, r, restore = setupInFlight({ onTaxi = false })
	local IF = r.W.Mod("UI.InFlight")
	eq(IF.Check(), false, "Mod.Check returns false when UnitOnTaxi is false")
	restore()
	T.clean(w)
end)

-- guards Wuber/UI/InFlight.lua:170 (cmp <=->>: frameRect uses zero scale instead of uScale)
-- guards Wuber/UI/InFlight.lua:273 (if cond negated: placeCard errors/skips frameRect when cl is non-nil)
-- guards Wuber/UI/InFlight.lua:282 (if cond negated: placeCard skips placing above overlapping WuberFrame)
test("mutation b5 ui inflight: placeCard scales zero-scale frame and moves above overlapping WuberFrame", function()
	local w, r, restore = setupInFlight()
	local IF = r.W.Mod("UI.InFlight")
	r.env.UIParent:SetSize(1024, 768)
	local wf = r.env.CreateFrame("Frame", "WuberFrame", r.env.UIParent)
	wf:SetSize(360, 400)
	-- Place WuberFrame at center-top where default flight card lands (wt=500), leaving room above (500+10+ch <= 768)
	wf:ClearAllPoints()
	wf:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 332, 100)
	wf:Show()

	eq(IF.Check(), true, "Mod.Check places card above WuberFrame")
	local card = IF.Card()
	ok(card ~= nil and card:IsShown(), "InFlight card shown")
	-- Line 282 places card with BOTTOM anchor above wf (wt + WIN_GAP)
	local pt = card:GetPoint(1)
	eq(pt, "BOTTOM", "card anchored BOTTOM above overlapping WuberFrame")

	-- Line 170: if card:GetEffectiveScale() returns 0, saveCardPos / frameRect falls back to uScale
	local origScale = card.GetEffectiveScale
	card.GetEffectiveScale = function() return 0 end
	local onDragStop = card:GetScript("OnDragStop")
	if onDragStop then onDragStop(card) end
	card.GetEffectiveScale = origScale
	ok(type(r.W.db.flightCardPos) == "table" and r.W.db.flightCardPos[1] ~= 0, "zero fScale falls back to uScale in frameRect")

	wf:Hide()
	restore()
	T.clean(w)
end)

-- guards Wuber/UI/InFlight.lua:199 (swap or->and: winChanged misses left-only WuberFrame resize/move)
-- guards Wuber/UI/InFlight.lua:299 (return false->true: placeCard returns true when no room exists)
-- guards Wuber/UI/InFlight.lua:360 (if cond negated: watch step hides card even when placeCard succeeds)
-- guards Wuber/UI/InFlight.lua:430 (return false->true: Mod.Check returns true when initial placeCard fails)
-- guards Wuber/UI/InFlight.lua:439 (return -> nil: Mod.Check returns nil when post-Show placeCard fails)
test("mutation b5 ui inflight: Mod.Check and watch handle full-screen window block and winChanged", function()
	local w, r, restore = setupInFlight()
	local IF = r.W.Mod("UI.InFlight")
	r.env.UIParent:SetSize(1024, 768)
	local wf = r.env.CreateFrame("Frame", "WuberFrame", r.env.UIParent)
	wf:Show()

	-- 1) Full-screen WuberFrame leaves no room -> placeCard returns false at line 299, Check returns false at line 430
	wf:ClearAllPoints()
	wf:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 0, 0)
	wf:SetSize(1024, 768)
	eq(IF.Check(), false, "Mod.Check returns false when WuberFrame covers screen")

	-- 2) Place WuberFrame on right edge (wl=700, wr=1024, wt=768, wb=0) so card fits on left
	wf:ClearAllPoints()
	wf:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 700, 0)
	wf:SetSize(324, 768)
	eq(IF.Check(), true, "Mod.Check succeeds when WuberFrame is on right edge")
	local card = IF.Card()
	ok(card and card:IsShown(), "card is shown")
	-- Keep card shown while moving WuberFrame slightly (still fits) to guard line 360
	wf:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 710, 0)
	wf:SetSize(314, 768)
	w:advance(1.0)
	ok(card:IsShown(), "card stays shown when placeCard succeeds after winChanged")

	-- Now expand ONLY left edge (wl 710->0; wr=1024, wt=768, wb=0 unchanged) -> winChanged must detect via OR (line 199)
	wf:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 0, 0)
	wf:SetSize(1024, 768)
	w:advance(1.0)
	eq(card:IsShown(), false, "card hidden when WuberFrame left edge expands to cover screen")

	-- 3) Line 439: initial placeCard returns true (card had no rect yet), post-Show placeCard returns false -> returns false (not nil)
	local origTaxi = r.env.UnitOnTaxi
	r.env.UnitOnTaxi = function() return false end
	IF.Check()
	r.env.UnitOnTaxi = function() return true end
	-- Reset WuberFrame to overlap card's bottom-left fallback when card:GetLeft becomes 0 after card:Show()
	wf:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 0, 0)
	wf:SetSize(1024, 768)
	-- First let initial placeCard succeed by hiding wf until card:Show() runs
	wf:Hide()
	local origShow = card.Show
	local origGetLeft = card.GetLeft
	local origGetRight = card.GetRight
	local origGetTop = card.GetTop
	local origGetBottom = card.GetBottom
	local shownFired = false
	card.Show = function(self)
		shownFired = true
		wf:Show()
		return origShow(self)
	end
	card.GetLeft = function(self)
		if not shownFired then return nil end
		return 0
	end
	card.GetRight = function() return 1024 end
	card.GetTop = function() return 768 end
	card.GetBottom = function() return 0 end
	local res = IF.Check()
	card.Show = origShow
	card.GetLeft = origGetLeft
	card.GetRight = origGetRight
	card.GetTop = origGetTop
	card.GetBottom = origGetBottom
	r.env.UnitOnTaxi = origTaxi
	eq(res, false, "Mod.Check returns false (not nil) when post-Show placeCard fails")

	wf:Hide()
	restore()
	T.clean(w)
end)
