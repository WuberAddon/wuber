-- Fix round 2.4, group g: Settings labels are never cut (slider values, the key pill) and the
-- newer-version note opens Help at the address, with the way to turn the note off.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open(warlock)
	local w = T.newWorld()
	local c = warlock and T.driver(w, T.BOB) or T.rider(w, T.TESTCHAR)
	T.settle(w)
	c.W.db.coach = true
	c.W.db.advanced = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(warlock and "drive" or nil)
	w:advance(1)
	return w, c, c.W.UI.settings
end

test("fr g (HUNT-137, ING-08): slider values at their longest are drawn whole", function()
	local w, c, st = open(true)
	local worth = st.controls.timeValue
	worth:Set(1000000)
	ok(worth.label:GetText():find("100g / hour", 1, true), "reads 100g / hour: " .. tostring(worth.label:GetText()))
	ok(not worth.label:IsTruncated() and H.truncation(worth.label, true) == nil, "100g / hour not cut")
	local ad = st.controls["drive.adEvery"]
	ad:Set(60)
	ok(not ad.label:IsTruncated() and H.truncation(ad.label, true) == nil, "every 60 min not cut")
	ad:Set(15)
	ok(not ad.label:IsTruncated() and H.truncation(ad.label, true) == nil, "every 15 min not cut")
	T.clean(w)
end)

test("fr g (HUNT-142): the key pill reads Press... whole after Set", function()
	local w, c, st = open(true)
	local set = st.controls["drive.key"]
	set:GetScript("OnClick")(set)
	eq(set.label:GetText(), "Press...", "the words")
	ok(not set.label:IsTruncated() and H.truncation(set.label, true) == nil, "Press... not cut")
	T.clean(w)
end)

test("fr g (HUNT-135): the newer-version note opens Help at the address; its tip names that place", function()
	local w = T.newWorld({ realm = H.FOUNDER_REALM }) -- a D from another realm is dropped; the world names one (the game names none since build 71037)
	local r = T.rider(w, T.TESTCHAR, { version = "2.3.0" })
	T.settle(w)
	local toasts = {}
	local UI = r.W.UI
	local real = UI.Toast
	UI.Toast = function(text, kind, fn)
		toasts[#toasts + 1] = { text = text, kind = kind, fn = fn }
		local t = real(text, kind, fn)
		toasts[#toasts].t = t
		return t
	end
	w:inject(T.ANITA, "D~1~Ratchet~1413~500~500~5000~~open~1~0~~2.3.1", "CHANNEL")
	w:advance(6)
	ok(toasts[1], "the note is up")
	toasts[1].fn()
	w:advance(1)
	ok(UI.HelpShown(), "Help opens")
	local st = UI.settings
	ok(st.help.urlBox and st.help.urlBox:IsShown(), "the address box is on screen")
	ok(#r:findText("/wuber updates off", false, true) > 0, "it says how to turn the note off")
	ok(st.help.scroll > 0, "scrolled down to the address")
	local tip = toasts[1].t and toasts[1].t.tip or ""
	ok(tip:find("Where to get Wuber", 1, true) and not tip:find("This window", 1, true), "its tip names Help: " .. tip)
	T.clean(w)
end)
