-- Mutation run guards for Wuber/UI/Secure.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR
local AKEY = "anita lift"

local function setupRider()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	return w, r, d
end

local function fightLocked(c)
	c.player.combat = true
	c:fire("PLAYER_REGEN_DISABLED")
end

local function captureToasts(c)
	local said = {}
	local UI = c.W.UI
	local orig = UI.Toast
	UI.Toast = function(text, ...)
		said[#said + 1] = tostring(text)
		return orig(text, ...)
	end
	return said
end

local function hasToast(said, text)
	for _, t in ipairs(said) do
		if t == text then return true end
	end
	return false
end

local function setupAdvertDriver()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	T.goOnline(d)
	w:advance(20)
	T.openDrive(d)
	d.W.UI.ShowDrive("console")
	w:advance(2)
	local pill = d.W.Driver.AdvertTarget("advert")
	return w, d, pill
end

local function setupShareDriver()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = d.W
	T.openDrive(d)
	W.UI.ShowDrive("console")
	w:advance(1)
	w:addBot("Vex Shade", { spot = "Orgrimmar" })
	w:group({ ANITA, "Vex Shade" })
	w:advance(1)
	W.Driver.lastShift = {
		rides = 5, copper = 20000, tips = 0, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = {
			rows = {
				{ key = W.myKey, name = ANITA, casts = 3, clicks = 0, share = 18000 },
				{ key = "vex shade", name = "Vex Shade", casts = 0, clicks = 2, share = 12000 },
			},
			rule = "clicks",
			pct = 40,
		},
	}
	W.Driver.ShowSheet("shift")
	w:advance(1)
	local pill = W.UI.drive.screens.shift.split.post
	return w, d, pill
end

-- guards Wuber/UI/Secure.lua:348 (cmp ==->~=: clicking Cancel in combat shows whisper-sent toast instead of no-whisper toast)
test("mutation b4 secure: clicking Cancel in combat shows no-whisper toast", function()
	local w, r = setupRider()
	T.openConfirm(r, AKEY)
	local reqPill = r.W.UI.state.screens.confirm.request
	r:clickOn(reqPill)
	w:advance(0.5)
	ok(r.W.ride, "ride booked")
	local cancelPill = r.W.UI.state.screens.found and r.W.UI.state.screens.found.cancel
	ok(cancelPill and H.visible(cancelPill), "Cancel pill is visible")
	ok(r.env.WuberCancelButton and H.visible(r.env.WuberCancelButton), "Cancel overlay is over pill")
	local said = captureToasts(r)
	fightLocked(r)
	w:advance(0.2)
	local hit = r:clickOn(cancelPill)
	ok(T.S[hit].secure, "click landed on secure Cancel overlay")
	ok(hasToast(said, "Ride cancelled. No whisper in combat."), "combat cancel shows no-whisper toast")
	ok(not hasToast(said, "Ride cancelled"), "does not claim whisper was sent")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:356 (swap or->and: clicking Advertise in combat touches protected macrotext attribute)
test("mutation b4 secure: clicking Advertise in combat leaves secure attributes untouched and posts nothing", function()
	local w, d, pill = setupAdvertDriver()
	ok(pill and H.visible(pill), "Advertise pill is visible")
	ok(d.env.WuberAdvertButton and d.env.WuberAdvertButton:IsShown(), "Advert overlay is over pill")
	local v0 = #w.violations
	fightLocked(d)
	w:advance(0.2)
	local hit = d:clickOn(pill)
	ok(T.S[hit].secure, "click landed on secure Advert overlay")
	eq(#w.violations, v0, "no protected attribute violation in combat")
	eq(d.env.WuberAdvertButton:GetAttribute("macrotext"), "", "macrotext stays empty in combat")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:384 (swap or->and: clicking Share in combat touches protected macrotext attribute)
test("mutation b4 secure: clicking Share in combat leaves secure attributes untouched and shows combat toast", function()
	local w, d, pill = setupShareDriver()
	ok(pill and H.visible(pill), "Share pill is visible")
	ok(d.env.WuberShareButton and d.env.WuberShareButton:IsShown(), "Share overlay is over pill")
	local v0 = #w.violations
	local said = captureToasts(d)
	fightLocked(d)
	w:advance(0.2)
	local hit = d:clickOn(pill)
	ok(T.S[hit].secure, "click landed on secure Share overlay")
	eq(#w.violations, v0, "no protected attribute violation in combat")
	ok(hasToast(said, "Share after combat"), "shows combat share toast")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:323 (swap and->or: RequestRide returning nil,nil shows spurious error toast)
test("mutation b4 secure: RequestRide returning nil with no reason does not show error toast", function()
	local w, r = setupRider()
	T.openConfirm(r, AKEY)
	local pill = r.W.UI.state.screens.confirm.request
	ok(pill and H.visible(pill), "Request pill is visible")
	local said = captureToasts(r)
	local origReq = r.W.RequestRide
	r.W.RequestRide = function() return nil, nil end
	local hit = r:clickOn(pill)
	r.W.RequestRide = origReq
	ok(T.S[hit].secure, "click landed on secure Request overlay")
	ok(not hasToast(said, "Couldn't send the request"), "no spurious failure toast when why is nil")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:324 (drop statement: clicking Request leaves manual screen on confirm)
test("mutation b4 secure: clicking Request clears manual confirm screen back to home", function()
	local w, r = setupRider()
	T.openConfirm(r, AKEY)
	local pill = r.W.UI.state.screens.confirm.request
	eq(r.W.UI.state.manual, "confirm", "manual screen starts on confirm")
	r:clickOn(pill)
	eq(r.W.UI.state.manual, "home", "manual screen resets to home after Request click")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:325 (drop statement: clicking Request does not call UI.Refresh(true))
test("mutation b4 secure: clicking Request immediately refreshes UI with force", function()
	local w, r = setupRider()
	T.openConfirm(r, AKEY)
	local pill = r.W.UI.state.screens.confirm.request
	ok(H.visible(r.env.WuberRequestButton), "Request overlay is visible before click")
	local UI = r.W.UI
	local origRefresh, origReq = UI.Refresh, r.W.RequestRide
	local sawForce = false
	r.W.RequestRide = function() return { id = "r1" } end
	UI.Refresh = function(force, ...)
		if force == true then sawForce = true end
		return origRefresh(force, ...)
	end
	r:clickOn(pill)
	UI.Refresh, r.W.RequestRide = origRefresh, origReq
	ok(sawForce, "UI.Refresh(true) called immediately after Request click")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:236 (drop statement: clicking Request in combat does not call UI.Refresh(true))
test("mutation b4 secure: clicking Request in combat immediately refreshes UI with force", function()
	local w, r = setupRider()
	T.openConfirm(r, AKEY)
	local pill = r.W.UI.state.screens.confirm.request
	local UI = r.W.UI
	local origRefresh, origReq, origToast = UI.Refresh, r.W.RequestRide, UI.Toast
	local sawForce = false
	r.W.RequestRide = function() return { id = "r1" } end
	UI.Toast = function(msg, ...)
		if msg == "Request sent. No whisper in combat." then sawForce = false end
		return origToast(msg, ...)
	end
	UI.Refresh = function(force, ...)
		if force == true then sawForce = true end
		return origRefresh(force, ...)
	end
	fightLocked(r)
	w:advance(0.2)
	local hit = r:clickOn(pill)
	UI.Refresh, r.W.RequestRide, UI.Toast = origRefresh, origReq, origToast
	ok(T.S[hit].secure, "click landed on secure Request overlay in combat")
	ok(sawForce, "UI.Refresh(true) called immediately after combat Request click")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:363 (swap or->and: clicking Advertise when AdvertPlan returns nil errors on nil macro)
test("mutation b4 secure: clicking Advertise when AdvertPlan returns nil does not error", function()
	local w, d, pill = setupAdvertDriver()
	local Dr = d.W.Driver
	local origTarget, origPlan = Dr.AdvertTarget, Dr.AdvertPlan
	Dr.AdvertTarget = function() return pill end
	Dr.AdvertPlan = function() return nil end
	local hit = d:clickOn(pill)
	Dr.AdvertTarget, Dr.AdvertPlan = origTarget, origPlan
	ok(T.S[hit].secure, "click landed on secure Advert overlay")
	eq(#w.errors, 0, "no Lua error when AdvertPlan returns nil")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:375 (drop statement: clicking Advertise does not refresh UI immediately)
test("mutation b4 secure: clicking Advertise immediately refreshes UI", function()
	local w, d, pill = setupAdvertDriver()
	ok(d.env.WuberAdvertButton:IsShown(), "Advert overlay is visible before click")
	local UI = d.W.UI
	local origRefresh = UI.Refresh
	local refreshed = 0
	UI.Refresh = function(...)
		refreshed = refreshed + 1
		return origRefresh(...)
	end
	d:clickOn(pill)
	UI.Refresh = origRefresh
	ok(refreshed >= 1, "UI.Refresh called immediately after Advertise click")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:388 (swap and->or: clicking Share when Share.Target returns nil still calls Share.Macro)
test("mutation b4 secure: clicking Share when Target is nil does not call Share.Macro", function()
	local w, d, pill = setupShareDriver()
	local Sh = d.W.UI.Share
	local origTarget, origMacro = Sh.Target, Sh.Macro
	local macroCalled = 0
	Sh.Target = function() return nil end
	Sh.Macro = function(...)
		macroCalled = macroCalled + 1
		return origMacro(...)
	end
	local hit = d:clickOn(pill)
	Sh.Target, Sh.Macro = origTarget, origMacro
	ok(T.S[hit].secure, "click landed on secure Share overlay")
	eq(macroCalled, 0, "Share.Macro is not called when Target is nil")
	eq(#w.errors, 0, "no error when Target is nil")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:390 (drop statement: Share.Macro returning a secret value is not sanitized by S())
test("mutation b4 secure: clicking Share ignores secret value from Share.Macro without error", function()
	local w, d, pill = setupShareDriver()
	local Sh = d.W.UI.Share
	local origMacro, origShared = Sh.Macro, Sh.Shared
	local sharedCalled = 0
	Sh.Macro = function() return T.H.SECRET, "secret" end
	Sh.Shared = function() sharedCalled = sharedCalled + 1 end
	local hit = d:clickOn(pill)
	Sh.Macro, Sh.Shared = origMacro, origShared
	ok(T.S[hit].secure, "click landed on secure Share overlay")
	eq(sharedCalled, 0, "Share.Shared is not called for secret macro")
	eq(#w.errors, 0, "no error on secret macro value")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:391 (swap or->and: clicking Share when Share.Macro returns nil errors on nil macro)
test("mutation b4 secure: clicking Share when Share.Macro returns nil does not error", function()
	local w, d, pill = setupShareDriver()
	local Sh = d.W.UI.Share
	local origMacro, origShared = Sh.Macro, Sh.Shared
	local sharedCalled = 0
	Sh.Macro = function() return nil end
	Sh.Shared = function() sharedCalled = sharedCalled + 1 end
	local hit = d:clickOn(pill)
	Sh.Macro, Sh.Shared = origMacro, origShared
	ok(T.S[hit].secure, "click landed on secure Share overlay")
	eq(sharedCalled, 0, "Share.Shared is not called for nil macro")
	eq(#w.errors, 0, "no error when Share.Macro returns nil")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:402 (drop statement: clicking Share does not refresh UI immediately)
test("mutation b4 secure: clicking Share immediately refreshes UI", function()
	local w, d, pill = setupShareDriver()
	local UI = d.W.UI
	local origRefresh = UI.Refresh
	local refreshed = 0
	UI.Refresh = function(...)
		refreshed = refreshed + 1
		return origRefresh(...)
	end
	local hit = d:clickOn(pill)
	UI.Refresh = origRefresh
	ok(T.S[hit].secure, "click landed on secure Share overlay")
	ok(refreshed >= 1, "UI.Refresh called immediately after Share click")
	T.clean(w)
end)
