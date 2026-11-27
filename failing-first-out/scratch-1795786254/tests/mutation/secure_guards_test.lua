-- Tests from the mutation run: the secure Request / Cancel / Share buttons (UI/Secure.lua).
-- Each test guards lines of UI/Secure.lua that no other test noticed when they were broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR
local AKEY = "anita lift"

-- a driver (Anita) online and a rider who has heard her
local function setup()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	return w, r, d, r.W.Mod("UI.Secure")
end

-- the rider has asked Anita and the Cancel overlay is up
local function booked()
	local w, r, d, Mod = setup()
	T.requestVia(r, AKEY)
	w:advance(1)
	r.W.UI.SyncSecure()
	return w, r, d, Mod, r.env.WuberCancelButton
end

local function lastWhisper(w)
	local l = w:whispersTo(ANITA, "macro")
	return l[#l] and l[#l].text, #l
end

-- records every toast text
local function toasts(r)
	local got = {}
	r.W.UI.Toast = function(text) got[#got + 1] = text end
	return got
end

local function counter(tbl, name, ret)
	local c = { n = 0 }
	tbl[name] = function(...) c.n = c.n + 1 c.args = { ... } if ret ~= nil then return ret end end
	return c
end


-- guards Wuber/UI/Secure.lua:80,82,83 (mutation run, mutants 23248, 31227, 17890: and->or, and->or, drop statement)
test("mutation secure: without the Rides macro helper the Request macro is built from the whisper text, or from the driver's own record", function()
	local w, r = setup()
	local W = r.W
	local Mod = W.Mod("UI.Secure")
	local _, d = Mod.requestBlock(AKEY)
	W.RequestMacro = nil
	W.RequestWhisper = function() return "hi there", "Anita-Lift" end
	eq(Mod.requestMacro(AKEY, d), "/w Anita-Lift hi there", "whisper text and name make the macro")
	W.RequestWhisper = function() return "hi there", nil end
	eq(Mod.requestMacro(AKEY, d), nil, "a line without a name is no macro")
	W.RequestWhisper = nil
	eq(Mod.requestMacro(AKEY, d), "/w Anita-Lift WTB summon to " .. d.dest .. " for " .. W.Money(d.price), "from the driver's record")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:92,94,95,100 (mutation run, mutants 422, 18820, 25417, 32159: cmp, if negated, and->or, if negated)
test("mutation secure: Cancel sends the whisper Rides gives, else the standard line to the driver's name", function()
	local w, r, _, _, b = booked()
	local _, n0 = lastWhisper(w)
	r.W.CancelMacro = function() return "/w Anita-Lift Never mind, thanks" end
	r:click(b)
	w:advance(0.5)
	local text, n = lastWhisper(w)
	eq(n, n0 + 1, "one whisper")
	eq(text, "Never mind, thanks", "the line Rides gave")
	T.clean(w)
	-- no line from Rides: the standard one, to the driver
	local w2, r2, _, _, b2 = booked()
	local _, m0 = lastWhisper(w2)
	r2.W.CancelMacro = function() return nil end
	r2:click(b2)
	w2:advance(0.5)
	local text2, m = lastWhisper(w2)
	eq(m, m0 + 1, "one whisper to the driver")
	eq(text2, "Sorry, I have to cancel - thanks anyway", "the standard line")
	T.clean(w2)
end)

-- guards Wuber/UI/Secure.lua:100,101,103 (mutation run, mutants 32159, 2348, 29185: if negated, or->and, return nil)
test("mutation secure: a Cancel line that reads like a request is replaced by the standard line, never sent as it is", function()
	local w, r, _, _, b = booked()
	local _, n0 = lastWhisper(w)
	r.W.CancelMacro = function() return "/w Anita-Lift please Summon me again" end
	r:click(b)
	w:advance(0.5)
	local text, n = lastWhisper(w)
	eq(n, n0 + 1, "still one whisper, to the driver")
	eq(text, "Sorry, I have to cancel - thanks anyway", "the standard line")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:333,334,343,344,345 (mutation run, mutants 26193, 27277, 31678, 24966, 25308; line 335 / mutant 9691 is guarded by the "armed quiet with an empty macro" test)
test("mutation secure: the Cancel overlay is armed only by a real click out of combat, and then holds the whisper macro", function()
	local w, r, _, _, b = booked()
	local pre = b:GetScript("PreClick")
	-- a key-down half arms nothing and clears what was armed
	b.armed = "whisper"
	b:SetAttribute("macrotext", "")
	pre(b, "LeftButton", true)
	eq(b.armed, nil, "down: nothing armed")
	eq(b:GetAttribute("macrotext"), "", "down: no macro")
	-- the click itself
	b:SetAttribute("type", "")
	b:SetAttribute("macrotext", "/w Stale old line")
	pre(b, "LeftButton", false)
	eq(b:GetAttribute("type"), "macro", "a macro button")
	eq(b:GetAttribute("macrotext"), "/w Anita-Lift Sorry, I have to cancel - thanks anyway", "the cancel whisper")
	eq(b.armed, "whisper", "armed to whisper")
	-- in combat nothing protected is touched
	b:SetAttribute("macrotext", "")
	b.armed = "whisper"
	r.player.combat = true
	pre(b, "LeftButton", false)
	eq(b.armed, nil, "combat: nothing armed")
	eq(b:GetAttribute("macrotext"), "", "combat: no macro")
	r.player.combat = false
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:335,340 (mutation run, mutants 9691, 21352: drop statement, drop statement)
test("mutation secure: a Cancel that cannot whisper is armed quiet with an empty macro; once the ride cannot be cancelled nothing is armed", function()
	local w, r, _, _, b = booked()
	local pre = b:GetScript("PreClick")
	r.W.CancelMacro = function() return nil end
	r.W.Tell = function() return "bad/name" end -- no usable name: nothing may be whispered
	b:SetAttribute("macrotext", "/w Stale old line")
	pre(b, "LeftButton", false)
	eq(b.armed, "quiet", "armed quiet")
	eq(b:GetAttribute("macrotext"), "", "no macro")
	-- the ride has moved past cancelling: the stale macro is wiped and nothing is armed
	r.W.ride.state = "arrived"
	b:SetAttribute("macrotext", "/w Stale old line")
	pre(b, "LeftButton", false)
	eq(b:GetAttribute("macrotext"), "", "stale macro wiped")
	eq(b.armed, nil, "nothing armed")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:110 (mutation run, mutant 5801: drop statement)
test("mutation secure: cancelling with no ride to cancel says it is too late and calls nothing off", function()
	local w, r, _, Mod = setup()
	local got = toasts(r)
	local cancel = counter(r.W, "CancelRide", true)
	Mod.doCancel(false)
	eq(got[1], "Too late to cancel now", "the rider is told")
	eq(cancel.n, 0, "no cancel sent")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:113,114,115 (mutation run, mutants 22449, 6540, 20026)
test("mutation secure: a cancel the ride refuses tells the rider and keeps the ride; an accepted one is sent once", function()
	local w, r, _, Mod = booked()
	local got = toasts(r)
	local clear = counter(r.W, "ClearRide")
	local cancel = counter(r.W, "CancelRide", false)
	Mod.doCancel(true)
	eq(cancel.n, 1, "the cancel was tried")
	eq(got[1], "Too late to cancel now", "refused: the rider is told")
	eq(clear.n, 0, "refused: the ride stays")
	cancel = counter(r.W, "CancelRide", true)
	Mod.doCancel(true)
	eq(cancel.n, 1, "accepted: sent once")
	eq(clear.n, 1, "accepted: the ride is cleared")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:118,119,120,121,122,124,126 (mutation run, mutants 25326, 10890, 29161, 2145, 17788, 27295, 15082)
test("mutation secure: a cancelled ride is dismissed, cleared, the rider sent home and told whether the whisper went", function()
	local w, r, _, Mod = booked()
	local ui = r.W.Mod("UI.Kit").ui
	local got = toasts(r)
	local clear = counter(r.W, "ClearRide")
	counter(r.W, "CancelRide", true)
	local refresh = counter(r.W.UI, "Refresh")
	local id = r.W.ride.id
	ui.manual = "somewhere"
	Mod.doCancel(true)
	eq(ui.dismissed[id], true, "the ride is dismissed")
	eq(clear.n, 1, "cleared")
	eq(ui.manual, "home", "back home")
	eq(got[#got], "Ride cancelled", "whisper went")
	eq(refresh.args[1], true, "refreshed")
	ui.dismissed[id] = nil
	Mod.doCancel(false)
	eq(got[#got], "Ride cancelled", "no click whisper needed out of combat")
	ui.dismissed[id] = nil
	r.player.combat = true
	Mod.doCancel(false)
	eq(got[#got], "Ride cancelled. No whisper in combat.", "combat, no whisper")
	r.player.combat = false
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:228 (mutation run, mutant 24922: local value -> nil)
test("mutation secure: a click in combat on a driver who has gone books nothing", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "setup: up")
	local got = toasts(r)
	local req = counter(r.W, "RequestRide")
	r.W.drivers[AKEY] = nil
	r.player.combat = true
	r:click(b)
	eq(req.n, 0, "no request sent")
	eq(got[1], "That driver has gone offline", "told why")
	r.player.combat = false
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:235 (mutation run, mutant 32190: drop statement)
test("mutation secure: a request booked in combat sends the rider home", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "setup: up")
	local ui = r.W.Mod("UI.Kit").ui
	r.player.combat = true
	ui.manual = "somewhere"
	r:click(b)
	ok(r.W.ride, "the request went")
	eq(ui.manual, "home", "back home")
	r.player.combat = false
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:282 (mutation run, mutant 24815: drop statement)
test("mutation secure: a Request click that throws is reported, not swallowed", function()
	local w, r = setup()
	T.openConfirm(r, AKEY)
	local b = r.env.WuberRequestButton
	local errs = counter(r.W, "Error")
	r.W.UI.Driver = function() error("boom") end
	b:GetScript("PreClick")(b, "LeftButton", false)
	eq(errs.n, 1, "reported once")
	eq(errs.args[1], "secure button", "under its name")
	eq(b.armed, nil, "nothing armed")
	T.clean(w)
end)

-- guards Wuber/UI/Secure.lua:399 (mutation run, mutant 30458: drop statement)
test("mutation secure: a Share click that lost the combat race tells the rider to share after combat", function()
	local w, r = setup()
	local b = r.env.WuberShareButton
	local got = toasts(r)
	b:GetScript("PostClick")(b, "LeftButton", false)
	eq(#got, 0, "out of combat nothing is said")
	r.player.combat = true
	b:GetScript("PostClick")(b, "LeftButton", false)
	eq(got[1], "Share after combat", "told")
	r.player.combat = false
	T.clean(w)
end)
