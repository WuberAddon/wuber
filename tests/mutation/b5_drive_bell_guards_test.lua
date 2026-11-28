-- Mutation run guards for Wuber/Drive/Bell.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupDriver(opts)
	opts = opts or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", saved = opts.saved })
	T.settle(w)
	return w, a, a.W.Drive
end

-- guards Wuber/Drive/Bell.lua:174 (swap and->or: throttle result 3 not retried when C_ChatInfo.SendAddonMessage returns 3)
-- guards Wuber/Drive/Bell.lua:181 (drop statement: DR.bell.sent not incremented after successful send)
test("mutation b5 drive bell: pump retries throttle result 3 and increments bell.sent on success", function()
	local w, a, DR = setupDriver()
	DR.Whisper = nil -- exercise C_ChatInfo.SendAddonMessage path
	local calls = 0
	local origSend = a.env.C_ChatInfo.SendAddonMessage
	a.env.C_ChatInfo.SendAddonMessage = function(prefix, text, ch, target)
		if prefix == "WUBERT" then
			calls = calls + 1
			if calls == 1 then return 3 end
			return 0
		end
		return origSend(prefix, text, ch, target)
	end
	ok(DR.BellSet("Bea Jones"), "BellSet succeeds")
	w:advance(2)
	local sentBefore = DR.bell.sent
	ok(DR.Ring("Dan Miller arrived", true), "Ring queues alert")
	w:advance(3)
	ok(DR.bell.sent > sentBefore, "bell.sent incremented after retry succeeds")
	ok(calls >= 2, "SendAddonMessage retried after throttle result 3")
	a.env.C_ChatInfo.SendAddonMessage = origSend
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:278 (if cond negated: safe() does not report error via W.Error)
-- guards Wuber/Drive/Bell.lua:279 (drop statement: safe() recurses infinitely when W.Error throws)
test("mutation b5 drive bell: safe() reports DRIVE_ALERT listener errors once without infinite recursion", function()
	local w, a, DR = setupDriver()
	local origRing = DR.Ring
	local origErr = a.W.Error
	local errCount = 0
	DR.Ring = function() error("bell safe boom") end
	a.W.Error = function(tag, msg)
		if tag == "alert character" then
			errCount = errCount + 1
			if errCount == 1 then
				-- Trigger a nested DRIVE_ALERT inside W.Error to exercise inError guard
				a.W.Fire("DRIVE_ALERT", "nested")
				error("nested error")
			end
		end
	end
	a.W.Fire("DRIVE_ALERT", "hello")
	DR.Ring = origRing
	a.W.Error = origErr
	a.W.lastError = nil
	eq(errCount, 1, "W.Error called once and guarded against recursion")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:440 (local value -> nil: bellNotFound never matches offline player system message)
test("mutation b5 drive bell: CHAT_MSG_SYSTEM not-found message prints offline notice and quiets bell", function()
	local w, a, DR = setupDriver()
	DR.Whisper = nil
	local origSend = a.env.C_ChatInfo.SendAddonMessage
	a.env.C_ChatInfo.SendAddonMessage = function(prefix, text, ch, target)
		if prefix == "WUBERT" then return 0 end
		return origSend(prefix, text, ch, target)
	end
	DR.BellSet("Bea Jones")
	w:advance(0.1)
	a:fire("CHAT_MSG_SYSTEM", "No player named 'Bea Jones' is currently playing.")
	a.env.C_ChatInfo.SendAddonMessage = origSend
	ok(a:said("is not online"), "prints offline notice for alert character")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:465 (drop statement: DR.bell.ignored not incremented on ignored BH)
-- guards Wuber/Drive/Bell.lua:467 (drop statement: strangerHint not recorded so unknown crew hint repeats)
-- guards Wuber/Drive/Bell.lua:488 (if cond negated: AlertWindow ignores own driver or accepts stranger)
-- guards Wuber/Drive/Bell.lua:489 (drop statement: AlertWindow does not ignore stranger BH)
test("mutation b5 drive bell: AlertWindow ignores stranger BH, increments bell.ignored, and throttles stranger hint", function()
	local w, a, DR = setupDriver()
	DR.SetAlertWindow(true)
	DR.BellForget()
	-- Stranger BH when team is empty and AlertWindow is true -> ignored silently
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~Strangers~stranger~Stranger~2.4.0", "WHISPER", "Stranger")
	eq(#a.W.db.drive.bell.team, 0, "stranger not added to team in AlertWindow mode")
	eq(DR.bell.ignored, 1, "bell.ignored incremented")
	-- Own-account driver BH -> accepted into team
	local origBookOwn = DR.BookOwn
	DR.BookOwn = function(k) return k == "bea jones" end
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~MyCrew~bea jones~Bea Jones~2.4.0", "WHISPER", "Bea Jones")
	DR.BookOwn = origBookOwn
	eq(#a.W.db.drive.bell.team, 1, "own driver added to team")
	-- Now team is non-empty: non-overlapping stranger BH prints hint once, not twice
	local hintCount = 0
	local origPrint = a.W.Print
	a.W.Print = function(s, ...)
		if tostring(s):find("not one of your crew", 1, true) then hintCount = hintCount + 1 end
		return origPrint(s, ...)
	end
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~OtherCrew~bob~Bob~2.4.0", "WHISPER", "Bob")
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~OtherCrew~bob~Bob~2.4.0", "WHISPER", "Bob")
	a.W.Print = origPrint
	eq(DR.bell.ignored, 3, "bell.ignored incremented for both stranger messages")
	eq(hintCount, 1, "stranger hint printed only once per sender")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:502 (if cond negated: b.team reset even when under MAX_TEAM)
-- guards Wuber/Drive/Bell.lua:503 (drop statement: b.team not reset when exceeding MAX_TEAM)
-- guards Wuber/Drive/Bell.lua:507 (drop statement: b.service not updated on BH)
-- guards Wuber/Drive/Bell.lua:509 (cmp ~=->==: b.lead overwritten with empty string)
-- guards Wuber/Drive/Bell.lua:510 (if cond negated: flashes-for print skipped when new keys added)
-- guards Wuber/Drive/Bell.lua:513 (drop statement: flashes-for message not printed)
test("mutation b5 drive bell: heardHello updates service and lead, prints team, and resets when exceeding MAX_TEAM", function()
	local w, a, DR = setupDriver()
	DR.BellForget()
	a.W.db.drive.bell.lead = "Existing Lead"
	-- Pre-fill team with 6 keys (one overlapping: bea jones) so adding 6 new keys exceeds MAX_TEAM (8)
	a.W.db.drive.bell.team = { "bea jones", "k2", "k3", "k4", "k5", "k6" }
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~NewSvc~bea jones,a1,a2,a3,a4,a5~~2.4.0", "WHISPER", "Bea Jones")
	eq(a.W.db.drive.bell.service, "NewSvc", "service updated")
	eq(a.W.db.drive.bell.lead, "Existing Lead", "empty lead in BH does not clear existing lead")
	eq(#a.W.db.drive.bell.team, 6, "team reset to new keys when exceeding MAX_TEAM")
	ok(a:said("this window flashes for NewSvc"), "prints flashes-for confirmation")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:693 (cmp ==->~=: BellAlert accepts empty text or rejects valid text)
-- guards Wuber/Drive/Bell.lua:695 (swap and->or: BellAlert rejects different text within SAME window)
-- guards Wuber/Drive/Bell.lua:696 (drop statement: BellAlert does not deduplicate identical text)
-- guards Wuber/Drive/Bell.lua:713 (drop statement: BellAlert does not print alert line)
test("mutation b5 drive bell: BellAlert rejects empty text, deduplicates identical text, and prints alert", function()
	local w, a, DR = setupDriver()
	eq(DR.BellAlert(""), false, "empty text rejected")
	eq(DR.BellAlert("Dan arrived"), true, "first alert shown")
	ok(a:said("Dan arrived"), "alert printed")
	eq(DR.BellAlert("Dan arrived"), false, "duplicate alert within SAME window suppressed")
	eq(DR.BellAlert("Bea arrived"), true, "different alert within SAME window still shown")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:747 (return -> nil: BellSet allows crew member as alert character)
-- guards Wuber/Drive/Bell.lua:751 (cmp ~=->==: BellSet sends hello when setting self as alert character)
-- guards Wuber/Drive/Bell.lua:761 (cmp ==->~=: BellTest does not show local banner when alert character is self)
-- guards Wuber/Drive/Bell.lua:762 (drop statement: BellTest skips BellAlert when alert character is self)
test("mutation b5 drive bell: BellSet rejects crew member and BellTest shows local banner for self", function()
	local w, a, DR = setupDriver()
	DR.SetCrewMember("Bea Jones", "lock", true)
	local okCrew, whyCrew = DR.BellSet("Bea Jones")
	eq(okCrew, false, "crew member rejected as alert character")
	ok(tostring(whyCrew):find("in your crew", 1, true) ~= nil, "rejection explains crew rule")
	local okSelf = DR.BellSet(T.ANITA)
	eq(okSelf, true, "self allowed as alert character")
	local bhSent = false
	local origWhisper = DR.Whisper
	DR.Whisper = function(target, kind)
		if kind == "BH" then bhSent = true end
		return true
	end
	eq(DR.BellSet("Cal Brown"), true, "non-crew other player allowed as alert character")
	DR.Whisper = origWhisper
	eq(bhSent, true, "BellSet sends BH hello when setting another player")
	eq(DR.BellSet(T.ANITA), true, "reset to self")
	local okTest, whatTest = DR.BellTest()
	eq(okTest, true, "BellTest succeeds for self")
	eq(whatTest, "here", "BellTest reports local banner")
	ok(a:said("the alert works"), "BellTest showed local alert")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:775 (drop statement: BellForget does not reset bell.ignored)
-- guards Wuber/Drive/Bell.lua:776 (drop statement: BellForget does not clear strangerHint)
-- guards Wuber/Drive/Bell.lua:788 (drop statement: SetAlertWindow does not persist c.alertWindow)
-- guards Wuber/Drive/Bell.lua:789 (drop statement: SetAlertWindow does not fire SETTINGS alertWindow)
test("mutation b5 drive bell: BellForget resets ignored/hints and SetAlertWindow persists and fires SETTINGS", function()
	local w, a, DR = setupDriver()
	DR.SetAlertWindow(false)
	local settingsFired = false
	a.W.Listen("SETTINGS", function(k) if k == "alertWindow" then settingsFired = true end end)
	ok(DR.SetAlertWindow(true), "SetAlertWindow returns true")
	eq(a.W.Char().alertWindow, true, "alertWindow persisted")
	eq(settingsFired, true, "SETTINGS alertWindow fired")
	-- Trigger a stranger hint and ignored count, then BellForget
	local hintCount = 0
	local origPrint = a.W.Print
	a.W.Print = function(s, ...)
		if tostring(s):find("not one of your crew", 1, true) then hintCount = hintCount + 1 end
		return origPrint(s, ...)
	end
	a.W.db.drive.bell.team = { "bea jones" }
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~OtherCrew~bob~Bob~2.4.0", "WHISPER", "Bob")
	ok(DR.bell.ignored > 0, "ignored count > 0 before forget")
	ok(DR.BellForget(), "BellForget succeeds")
	eq(DR.bell.ignored, 0, "bell.ignored reset to 0")
	-- After BellForget, stranger hint can print again for Bob
	a.W.db.drive.bell.team = { "bea jones" }
	a:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~OtherCrew~bob~Bob~2.4.0", "WHISPER", "Bob")
	a.W.Print = origPrint
	eq(hintCount, 2, "stranger hint prints again after BellForget")
	T.clean(w)
end)
