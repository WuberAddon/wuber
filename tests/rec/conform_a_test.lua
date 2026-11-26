-- Conformance, group A (job 2766): the fake game's login, realm, spell book, summon, chat and API facts against what
-- the real client did (WoW Forever build 71037). Sources: tests/fixtures/rec/lab-real-facts.lua (recorder facts) and the
-- Lab's "Game facts" run of 24 Nov 2026 (PROVEN-FACTS PF-041 to PF-064; the Lab rows are the GameFacts ids L1 to L19).
-- A test with "-- guard:" above it already passed on the fake as it was: it pins the real value from now on.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- every event the named player's game windows fire while fn runs: { ev, at, args }
local function listen(name, fn)
	local got, orig = {}, H.Client.fire
	H.Client.fire = function(self, ev, ...)
		if self.player and self.player.name == name then
			got[#got + 1] = { ev = ev, at = self.world.time, args = { n = select("#", ...), ... } }
		end
		return orig(self, ev, ...)
	end
	local okf, err = pcall(fn, got)
	H.Client.fire = orig
	if not okf then error(err, 0) end
	return got
end

-- the events an addon's own event frame gets (with the argument count the addon sees)
local function capture(r, ev)
	local list = {}
	local fr = r.env.CreateFrame("Frame")
	fr:RegisterEvent(ev)
	fr:SetScript("OnEvent", function(_, e, ...) list[#list + 1] = { ev = e, n = select("#", ...), at = r.world and r.world.time, ... } end)
	return list
end

-- PF-054 (L16): "realm  (, id 0), region 3, hardcore false, war mode false": an empty realm name, not nil
test("rec: conform a: realm facts: empty name, id 0, region 3, hardcore false, war mode false (PF-054, L16)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local e = r.env
	eq(e.GetRealmName(), "", "GetRealmName")
	eq(e.GetNormalizedRealmName(), "", "GetNormalizedRealmName")
	eq(type(e.GetRealmID), "function", "GetRealmID exists")
	eq(e.GetRealmID(), 0, "realm id")
	eq(type(e.GetCurrentRegion), "function", "GetCurrentRegion exists")
	eq(e.GetCurrentRegion(), 3, "region")
	eq(e.C_GameRules.IsHardcoreActive(), false, "hardcore")
	eq(e.C_PvP.IsWarModeActive(), false, "war mode active")
	eq(e.C_PvP.IsWarModeDesired(), false, "war mode wanted")
	T.clean(w)
end)

-- PF-047 (L12.self): "UnitName len 5; UnitFullName len 5; GetUnitName(,true) len 11 space; GUID Player"
test("rec: conform a: the player's own name: UnitName and UnitFullName are the short name, GetUnitName(,true) the long one (PF-047, L12.self)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local e = r.env
	local n1, n2 = e.UnitName("player")
	eq(n1, "Wuber", "UnitName's first return is the first name only (measured: len 5)")
	-- assumption: the second return is the surname, as for other units; not measured (Lab L12.self logs only lengths)
	eq(n2, "TestCharacter", "UnitName's second return")
	local f1, f2 = e.UnitFullName("player")
	eq(f1, "Wuber", "UnitFullName's first return (measured: len 5)")
	-- assumption: the second return is the surname, as for other units; not measured (Lab L12.self logs only lengths)
	eq(f2, "TestCharacter", "UnitFullName's second return")
	eq(e.GetUnitName("player", true), "Wuber TestCharacter", "GetUnitName(,true): the long form, with a space")
	ok(e.UnitGUID("player"):find("^Player"), "the GUID starts with Player")
	T.clean(w)
end)

-- guard: PF-048 (L12.whisper): a whisper's sender is the long form with a space and its GUID starts with Player
test("rec: conform a: a whisper's sender is the long name with a space, its GUID starts with Player (PF-048, L12.whisper)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	w:advance(5)
	local list = capture(r, "CHAT_MSG_WHISPER")
	local fn = assert(loadstring("SendChatMessage('hi', 'WHISPER', nil, ...)", "@" .. H.root .. "/lab/WuberLab/Fake.lua"))
	setfenv(fn, ana.env)
	w.hardware = ana
	fn(T.TESTCHAR)
	w.hardware = nil
	w:advance(1)
	ok(list[1], "the whisper arrived")
	eq(list[1][1], "hi", "text")
	eq(list[1][2], T.ANITA, "sender: long name")
	ok(list[1][2]:find(" ", 1, true), "with a space")
	ok(tostring(list[1][12]):find("^Player"), "the GUID starts with Player")
	T.clean(w)
end)

-- PF-041 (L7): a Warlock knows the ritual spell 698 at 0 s after login: IsPlayerSpell, IsSpellKnown, C_Spell.GetSpellInfo
test("rec: conform a: a Warlock's spell book is not empty at login: IsPlayerSpell, IsSpellKnown, GetSpellInfo yes at 0 s (PF-041, L7)", function()
	local w = T.newWorld()
	local ana = T.driver(w, T.ANITA)
	local e = ana.env
	eq(type(e.IsPlayerSpell), "function", "IsPlayerSpell exists")
	eq(e.IsPlayerSpell(698), true, "IsPlayerSpell")
	eq(e.IsSpellKnown(698), true, "IsSpellKnown")
	ok(e.C_Spell.GetSpellInfo(698), "C_Spell.GetSpellInfo")
	T.clean(w)
end)

-- guard: PF-042 (L6): GetSummonConfirmSummoner gives the summoner's name at 0 ms on every CONFIRM_SUMMON
test("rec: conform a: the summoner's name is there at 0 ms of a CONFIRM_SUMMON (PF-042, L6)", function()
	local w = T.newWorld()
	w:addBot("Hayley Cab", { spot = "Orgrimmar", class = "WARLOCK" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Durotar" })
	w:advance(4)
	local list = capture(r, "CONFIRM_SUMMON")
	w:summon(w:player("Hayley Cab"), T.TESTCHAR)
	w:advance(0.001)
	ok(list[1], "CONFIRM_SUMMON came")
	eq(r.env.C_SummonInfo.GetSummonConfirmSummoner(), "Hayley Cab", "the name, straight away")
	T.clean(w)
end)

-- PF-043 (L1, L1.table): C_IncomingSummon has two calls, HasIncomingSummon and IncomingSummonStatus; status 0 without a cast
test("rec: conform a: C_IncomingSummon is there by default with its two calls; status 0 with no summon (PF-043, L1)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local t = r.env.C_IncomingSummon
	eq(type(t), "table", "C_IncomingSummon exists")
	eq(type(t.HasIncomingSummon), "function", "HasIncomingSummon")
	eq(type(t.IncomingSummonStatus), "function", "IncomingSummonStatus")
	eq(t.IncomingSummonStatus("player"), 0, "no summon: status 0")
	eq(t.HasIncomingSummon("player"), false, "no summon: none incoming")
	T.clean(w)
end)

-- guard: PF-044 (L3.read): chat lockdown is false at login, outside an instance
test("rec: conform a: the chat lockdown is false at login (PF-044, L3.read)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	eq(r.env.C_ChatInfo.InChatMessagingLockdown(), false, "no lockdown")
	T.clean(w)
end)

-- guard: PF-045 (L5): Wuber's channel is at slot 7 of 9 / 6 of 7, and there is no GetChannelRosterInfo ("no such call")
test("rec: conform a: no GetChannelRosterInfo in the game; WuberNet is joined after the game's own channels (PF-045, L5)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(12)
	eq(r.env.GetChannelRosterInfo, nil, "no such call")
	local list, idx = { r.env.GetChannelList() }, nil
	for i = 1, #list, 3 do if list[i + 1] == "WuberNet" then idx = list[i] end end
	ok(idx and idx > 5, "WuberNet's slot follows the game's channels, got " .. tostring(idx))
	T.clean(w)
end)

-- PF-049 (L13.style): input style 0 (mouse and keyboard) and CVar InputDeviceInterfaceStyle "0"
test("rec: conform a: input style 0 and the CVar InputDeviceInterfaceStyle 0 (PF-049, L13.style)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	eq(r.env.C_InputInterfaceStyle.GetCurrentStyle(), 0, "style")
	eq(r.env.GetCVar("InputDeviceInterfaceStyle"), "0", "CVar")
	T.clean(w)
end)

-- guard: PF-052 (L10): Enum.SendAddonMessageResult has the 13 codes with these values
test("rec: conform a: Enum.SendAddonMessageResult: the 13 codes of the real game (PF-052, L10)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local want = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4, NotInGroup = 5,
		TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 }
	local n = 0
	for k, v in pairs(r.env.Enum.SendAddonMessageResult) do n = n + 1; eq(want[k], v, k) end
	eq(n, 13, "13 codes")
	T.clean(w)
end)

-- guard: PF-056 (L4): ten whispers to yourself 0.2 s after a loading screen all return 0 (Success): no throttle
test("rec: conform a: ten addon whispers to yourself right after a loading screen all succeed (PF-056, L4)", function()
	local w = T.newWorld()
	w:addBot("Hayley Cab", { spot = "Orgrimmar", class = "WARLOCK" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff" })
	w:advance(4)
	r.env.C_ChatInfo.RegisterAddonMessagePrefix("CONFA")
	local pew = capture(r, "PLAYER_ENTERING_WORLD")
	w:summon(w:player("Hayley Cab"), T.TESTCHAR)
	w:advance(0.5)
	w.hardware = r
	r.env.C_SummonInfo.ConfirmSummon()
	w.hardware = nil
	w:advance(5)
	ok(pew[1], "a loading screen came")
	w:advance(0.3)
	for i = 1, 10 do
		eq(r.env.C_ChatInfo.SendAddonMessage("CONFA", "x" .. i, "WHISPER", T.TESTCHAR), 0, "send " .. i)
	end
	T.clean(w)
end)

-- PF-061 (L18): the taint log switch reads 1 (on)
test("rec: conform a: the taint log CVar reads 1 (PF-061, L18)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	eq(r.env.GetCVar("taintLog"), "1", "taintLog")
	T.clean(w)
end)

-- PF-062 (L19): C_ChatInfo.RequestCanLocalWhisperTarget exists and answers 0 (can whisper) within a quarter second
test("rec: conform a: RequestCanLocalWhisperTarget exists and answers 0 for a player who is online (PF-062, L19)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	w:advance(1)
	eq(type(r.env.C_ChatInfo.RequestCanLocalWhisperTarget), "function", "the call exists")
	local list = capture(r, "CAN_LOCAL_WHISPER_TARGET_RESPONSE")
	local t0 = w.time
	r.env.C_ChatInfo.RequestCanLocalWhisperTarget("Player-1-" .. T.ANITA:lower())
	w:advance(0.5)
	local ev = list[1]
	ok(ev, "the answer came")
	eq(ev[2], 0, "status 0")
	ok(ev.at - t0 <= 0.25, "within a quarter second")
	T.clean(w)
end)

-- guard: PF-064 (SECRETS): CHAT_MSG_CHANNEL with no lockdown: text, sender and GUID are plain strings, 18 arguments
test("rec: conform a: CHAT_MSG_CHANNEL: 18 plain arguments (PF-064)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	w:advance(12)
	local list = capture(r, "CHAT_MSG_CHANNEL")
	w:publicLine(T.ANITA, "Horde", "hello", "CHANNEL", "General", "test")
	w:advance(0.1)
	ok(list[1], "a channel line arrived")
	eq(list[1].n, 18, "18 arguments")
	eq(type(list[1][1]), "string", "text")
	eq(type(list[1][2]), "string", "sender")
	eq(type(list[1][12]), "string", "GUID")
	T.clean(w)
end)

-- PF-050 (L13.blocked): ReloadUI called from addon code is blocked ("Interface action failed because of an AddOn")
test("rec: conform a: ReloadUI from addon code is blocked, the window is not reloaded (PF-050, L13.blocked)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local alive = r.client
	local got = listen(T.TESTCHAR, function()
		r.env.ReloadUI()
		w:advance(1)
	end)
	local logout = false
	for _, g in ipairs(got) do if g.ev == "PLAYER_LOGOUT" then logout = true end end
	eq(logout, false, "no reload happened")
	local blocked = false
	for _, g in ipairs(got) do if g.ev == "ADDON_ACTION_FORBIDDEN" or g.ev == "ADDON_ACTION_BLOCKED" then blocked = true end end
	eq(blocked, true, "the game says an AddOn blocked it")
	T.clean(w)
end)

-- PF-058 (LINE, LINE.reply): a whisper line sent from a Lab button's own click goes out ("WHISPER sent") and is answered.
-- The caller must be another addon's file (the Lab's, lab/): a test file or the harness under a click gets no such leave.
test("rec: conform a: a whisper sent from another addon's button click goes out as a click line (PF-058, LINE)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	w:advance(5)
	local list = capture(ana, "CHAT_MSG_WHISPER")
	local b = r.env.CreateFrame("Button", nil, r.env.UIParent)
	b:SetSize(100, 30)
	b:SetPoint("CENTER")
	local chunk = "local to = ...; return function() SendChatMessage('summon pls', 'WHISPER', nil, to) end"
	local fn = assert(loadstring(chunk, "@" .. H.root .. "/lab/WuberLab/Fake.lua"))
	setfenv(fn, r.env)
	b:SetScript("OnClick", fn(T.ANITA))
	r:clickOn(b)
	w:advance(1)
	ok(list[1], "the whisper arrived")
	eq(list[1][1], "summon pls", "the text")
	eq(#w:whispersTo(T.ANITA, "click"), 1, "delivered as a click line")
	T.clean(w)
end)

-- a click handler in a test file (or the harness) gets no leave: the line is blocked as an addon line
test("rec: conform a: a whisper from a click handler written in a test file is still blocked (PF-058)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	w:advance(5)
	local b = r.env.CreateFrame("Button", nil, r.env.UIParent)
	b:SetSize(100, 30)
	b:SetPoint("CENTER")
	b:SetScript("OnClick", function() r.env.SendChatMessage("summon pls", "WHISPER", nil, T.ANITA) end)
	r:clickOn(b)
	w:advance(1)
	eq(#w:whispersTo(T.ANITA, "click"), 0, "not a click line")
	w.violations = {} -- (the block is the point of the test)
	T.clean(w)
end)

-- PF-050 (L13.blocked): the evidence is a CLICK: "BLOCKED WuberLabBar Reload()" from the Lab bar's Reload button
test("rec: conform a: ReloadUI inside a button's click handler is blocked too (PF-050, L13.blocked)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local b = r.env.CreateFrame("Button", nil, r.env.UIParent)
	b:SetSize(100, 30)
	b:SetPoint("CENTER")
	b:SetScript("OnClick", function() r.env.ReloadUI() end)
	local blocked, logout = capture(r, "ADDON_ACTION_BLOCKED"), capture(r, "PLAYER_LOGOUT")
	r:clickOn(b)
	w:advance(1)
	eq(#logout, 0, "no reload happened")
	eq(#blocked, 1, "the game says an AddOn blocked it")
	T.clean(w)
end)

-- channel.join.timing: "GetChannelList already shows the channel (index=6 channels=7) when the call returns, but the Lab's
-- CheckChannel(true) is false; 0.1-0.45 s later CHANNEL_UI_UPDATE and CheckChannel true" ("Hayley Cab 20 Nov 10:11:01.099
-- 'JoinTemporaryChannel(WuberNet) called' ... 10:11:01.449 'CheckChannel(false) -> true index=6 channels=7'")
test("rec: conform a: JoinTemporaryChannel: the list shows the channel at once, GetChannelName and CHANNEL_UI_UPDATE 0.1-0.45 s later (channel.join.timing)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local function inList(name)
		local list = { r.env.GetChannelList() }
		for i = 1, #list, 3 do if list[i + 1] == name then return list[i] end end
	end
	local list = capture(r, "CHANNEL_UI_UPDATE")
	local t0 = w.time
	r.env.JoinTemporaryChannel("ConfATest")
	ok(inList("ConfATest"), "in GetChannelList when the call returns")
	eq((r.env.GetChannelName("ConfATest")), 0, "GetChannelName does not know it yet")
	w:advance(0.05)
	eq((r.env.GetChannelName("ConfATest")), 0, "still not at 0.05 s")
	w:advance(0.5)
	ok((r.env.GetChannelName("ConfATest")) > 0, "known after the delay")
	ok(list[1], "CHANNEL_UI_UPDATE came")
	local dt = list[1].at - t0
	ok(dt >= 0.1 and dt <= 0.45, "CHANNEL_UI_UPDATE after " .. tostring(dt))
	T.clean(w)
end)

-- guard: login.order.login_before_pew ("Wuber Rocks 23:54:52 login line, 'channels=0 wuberIndex=nil (login)', PEW"): PLAYER_LOGIN
-- comes before PLAYER_ENTERING_WORLD and the channel list is empty at that moment on a fresh login
test("rec: conform a: PLAYER_LOGIN comes before PLAYER_ENTERING_WORLD, with no channel yet (login.order.login_before_pew)", function()
	local w = T.newWorld()
	local order, chanAtLogin = {}, nil
	local orig = H.Client.fire
	H.Client.fire = function(self, ev, ...)
		if self.player and self.player.name == T.TESTCHAR then
			order[#order + 1] = ev
			if ev == "PLAYER_LOGIN" and self.env and self.env.GetChannelList then chanAtLogin = select("#", self.env.GetChannelList()) end
		end
		return orig(self, ev, ...)
	end
	local okf, err = pcall(function() T.rider(w, T.TESTCHAR) end)
	H.Client.fire = orig
	if not okf then error(err, 0) end
	local at = {}
	for i, e in ipairs(order) do at[e] = at[e] or i end
	ok(at.PLAYER_LOGIN and at.PLAYER_ENTERING_WORLD and at.PLAYER_LOGIN < at.PLAYER_ENTERING_WORLD, "login before PEW")
	eq(chanAtLogin, 0, "no channel at PLAYER_LOGIN")
	T.clean(w)
end)

-- guard: api.unitname.plate: UnitName("nameplateN") gives two values, first name and surname
test("rec: conform a: UnitName of a nameplate gives first name and surname (api.unitname.plate)", function()
	local w = T.newWorld()
	local ana = T.driver(w, T.ANITA)
	w:addBot("Ally Foe", { faction = "Alliance", spot = "Orgrimmar" })
	w:advance(3)
	ana:showPlate("Ally Foe")
	local a, b = ana.env.UnitName("nameplate1")
	eq(a, "Ally", "first name")
	eq(b, "Foe", "surname")
	T.clean(w)
end)

-- guard: api.setfont.missing: SetFont with a missing file returns false and GetFont stays nil; a present file returns true
test("rec: conform a: SetFont with a missing file returns false and GetFont stays nil (api.setfont.missing)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local fs = r.env.UIParent:CreateFontString(nil, "OVERLAY")
	eq(fs:SetFont("Interface\\AddOns\\Wuber\\Media\\Nothing.ttf", 12, ""), false, "missing file")
	eq(fs:GetFont(), nil, "no font")
	w.missingFiles = {} -- (the missing file is the point of the test, not a fault of the addon)
	T.clean(w)
end)

-- guard: summon.box.visible: 1 s after the accept the summon box is still there when the summon is a far one (12 of 15)
test("rec: conform a: the summon box is still up 1 s after AcceptSummon of a far summon (summon.box.visible)", function()
	local w = T.newWorld()
	w:addBot("Hayley Cab", { spot = "Orgrimmar", class = "WARLOCK" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff" })
	w:advance(4)
	w:summon(w:player("Hayley Cab"), T.TESTCHAR)
	w:advance(0.5)
	w.hardware = r
	r.env.C_SummonInfo.ConfirmSummon()
	w.hardware = nil
	w:advance(1)
	ok(r.env.StaticPopup_Visible("CONFIRM_SUMMON"), "the box is visible at 1 s")
	T.clean(w)
end)

-- guard: msg.format: addon messages carry the sender as a plain long name, no realm suffix, on WHISPER and CHANNEL; results 0
test("rec: conform a: addon messages: the sender is the plain long name on WHISPER and CHANNEL, the result 0 (msg.format)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	w:advance(12)
	r.env.C_ChatInfo.RegisterAddonMessagePrefix("CONFA")
	ana.env.C_ChatInfo.RegisterAddonMessagePrefix("CONFA")
	local list = capture(r, "CHAT_MSG_ADDON")
	eq(ana.env.C_ChatInfo.SendAddonMessage("CONFA", "hello", "WHISPER", T.TESTCHAR), 0, "whisper result")
	w:advance(1)
	ok(list[1], "the message arrived")
	eq(list[1][4], T.ANITA, "sender: plain long name")
	eq(list[1][3], "WHISPER", "channel type")
	T.clean(w)
end)

-- guard: community.channel: a channel named "Community:<club>:<stream>" is shared across realms (one copy)
test("rec: conform a: a community channel is one copy for every realm (community.channel)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local ana = T.driver(w, T.ANITA)
	ok(w.sameCopy, "World:sameCopy exists")
	eq(w:sameCopy(r, ana, "Community:216847842:1"), true, "a community channel is shared")
	T.clean(w)
end)
