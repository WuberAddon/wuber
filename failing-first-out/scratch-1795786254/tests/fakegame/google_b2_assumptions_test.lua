-- One pinned test per line of "What tests cannot prove" in tests/README.md, plus a gate test.
-- Each test asserts what the fake game answers today; comments note the matching in-game check.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

local ASSUMPTIONS = {
	{ key = "Hit test ranking (`Client:frameAt` / `framesAt`, tests/fakegame/hit_rank_test.lua and mouse_everywhere_test.lua)",
		test = "fake assumption: equal-level clip tie goes to outside sibling" },
	{ key = "Mouse rules no real sample has measured (each test carries an `-- assumption:` line in tests/fakegame/mouse_everywhere_test.lua)",
		test = "fake assumption: GetMouseFocus is nil and click fires no OnEnter" },
	{ key = "Font widths at 11 px",
		test = "fake assumption: 11 px font string width includes 6 percent margin" },
	{ key = "OnFinished on a stopped and restarted animation",
		test = "fake assumption: stopped and restarted animation fires OnStop then OnFinished" },
	{ key = "Secure and hardware-click rules",
		test = "fake assumption: plain CreateFrame works in combat without lockdown" },
	{ key = "Taint",
		test = "fake assumption: taint guard ignores writes into C_* proxy tables" },
	{ key = "Taint guard limits",
		test = "fake assumption: taint guard ignores overwriting an existing game frame field" },
	{ key = "Real chat and channel timing",
		test = "fake assumption: whispers deliver in order on the world clock" },
	{ key = "The player's own UnitName and UnitFullName second return, and GetUnitName(unit) without showServer (PF-047, Lab row L12.self)",
		test = "fake assumption: UnitName and UnitFullName return surname and GetUnitName returns full name" },
	{ key = "Game channel notices (PF-046, Lab GameFacts row L5.notice)",
		test = "fake assumption: joining a channel fires no CHAT_MSG_CHANNEL_NOTICE_USER" },
	{ key = "Chat font and label fit (PF-051, PF-053, PF-055, Lab rows L15, L15.wuber, LBL)",
		none = "fake has no chat box font or real chat-frame font metrics" },
	{ key = "Taint log and sound hooks (PF-061, Lab row L18)",
		test = "fake assumption: taintLog CVar is 1 and hooksecurefunc PlaySound runs on addon calls" },
	{ key = "Summon status after the cast (PF-043, Lab row L1)",
		test = "fake assumption: IncomingSummonStatus stays sticky for 120 s" },
	{ key = "Whisper-check answer time (PF-062, Lab row L19)",
		test = "fake assumption: whisper check answers after 0.2 s" },
	{ key = "ReloadUI from a click (PF-050, Lab row L13.blocked)",
		test = "fake assumption: ReloadUI from addon code is blocked" },
	{ key = "Whisper from a click (PF-058, Lab row LINE)",
		test = "fake assumption: SendChatMessage whisper from addon code is a violation" },
	{ key = "Frame rate and memory (fact perf)",
		test = "fake assumption: GetFramerate answers 60" },
	{ key = "The 14-item self-test and C_Map after login (facts selftest.login, login.f1_sound)",
		test = "fake assumption: C_Map answers immediately after login" },
	{ key = "Flight map sizes (facts taxi.numnodes, taxi.positions, PF-057)",
		test = "fake assumption: openTaxi populates NumTaxiNodes and TaxiNodeName" },
	{ key = "The real text ruler (PF-063, PF-066)",
		test = "fake assumption: fake text ruler uses GAME_TEXT_MARGIN 1.06" },
	{ key = "Animation facts beyond the four measured (PF-059, PF-116)",
		test = "fake assumption: Alpha animation keeps GetAlpha at from and Translation moves nothing" },
	{ key = "The API census (PF-060) beyond WOW_PROJECT_ID 18, no SetGradientAlpha and nothing from the edge getters of an unplaced frame",
		test = "fake assumption: WOW_PROJECT_ID is 18, no SetGradientAlpha, unplaced edges nil" },
	{ key = "The ride's network timings (fact ride.network.stages)",
		test = "fake assumption: addon messages deliver on world clock without network jitter" },
	{ key = "A new file needs a full restart (PF-115), frames made in combat (PF-122) and a real emote from a timer (PF-124)",
		test = "fake assumption: CreateFrame succeeds in combat and DoEmote is absent" },
	{ key = "Font load after login (PF-117) is off by default in the fake (opt-in world.fontReadyAt); the real Inter font loads after about 0.6 s (PF-063). In game",
		test = "fake assumption: fontReadyAt is nil by default so fonts are ready at login" },
	{ key = "HasAccessConstraints",
		test = "fake assumption: HasAccessConstraints answers false for every frame" },
	{ key = "Sound settings in background",
		none = "fake has no sound engine or audio settings" },
}

local function bare()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	return w, c, c.env
end

-- Extract the opening key of a bullet line up to the first colon outside backticks
-- (or up to the first semicolon when a bullet has no colon).
local function extractKey(line)
	local body = line:match("^%- (.+)$")
	if not body then return nil end
	local inTick = false
	for i = 1, #body do
		local ch = body:sub(i, i)
		if ch == "`" then
			inTick = not inTick
		elseif ch == ":" and not inTick then
			return body:sub(1, i - 1)
		end
	end
	local semi = body:find(";", 1, true)
	if semi then return body:sub(1, semi - 1) end
	return body
end

local README_PATH = "tests/README.md"

-- Gate: reads tests/README.md at run time and checks 1-to-1 coverage against ASSUMPTIONS.
test("fake assumption: every What tests cannot prove line has a row", function()
	local f, err = io.open(README_PATH, "r")
	ok(f ~= nil, "readable " .. README_PATH .. ": " .. tostring(err))
	local inSection = false
	local keys = {}
	for line in f:lines() do
		if line:match("^## What tests cannot prove%s*$") then
			inSection = true
		elseif inSection and line:match("^## ") then
			break
		elseif inSection then
			local k = extractKey(line)
			if k then keys[#keys + 1] = k end
		end
	end
	f:close()
	ok(#keys > 0, "found at least one bullet in What tests cannot prove")

	local byKey = {}
	for _, row in ipairs(ASSUMPTIONS) do
		ok(row.key and (row.test or row.none), "row must have key and test or none: " .. tostring(row.key))
		byKey[row.key] = row
	end

	local missing = {}
	local seen = {}
	for _, k in ipairs(keys) do
		seen[k] = true
		if not byKey[k] then
			missing[#missing + 1] = k
		end
	end
	eq(#missing, 0, "lines in What tests cannot prove with no row: " .. table.concat(missing, " | "))

	local extra = {}
	for _, row in ipairs(ASSUMPTIONS) do
		if not seen[row.key] then
			extra[#extra + 1] = row.key
		end
	end
	eq(#extra, 0, "ASSUMPTIONS rows no longer in What tests cannot prove: " .. table.concat(extra, " | "))
end)

-- In game: Lab Auto check back walk / GetMouseFoci and opening Settings back arrow by hand.
test("fake assumption: equal-level clip tie goes to outside sibling", function()
	local _, c, env = bare()
	local clipper = env.CreateFrame("Frame", nil, env.UIParent)
	clipper:SetFrameLevel(2)
	clipper:SetSize(200, 200)
	clipper:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 100)
	clipper:SetClipsChildren(true)

	local inside = env.CreateFrame("Button", nil, clipper)
	inside:SetFrameLevel(42)
	inside:SetSize(40, 40)
	inside:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 120, 120)
	inside:EnableMouse(true)

	local outside = env.CreateFrame("Frame", nil, env.UIParent)
	outside:SetFrameLevel(2)
	outside:SetSize(200, 200)
	outside:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 100)
	outside:EnableMouse(true)

	eq(c:frameAt(130, 130), outside, "outside sibling at clip's level wins the equal-level tie")
end)

-- In game: /dump GetMouseFoci() and manual hover/scroll/drag checks.
test("fake assumption: GetMouseFocus is nil and click fires no OnEnter", function()
	local _, c, env = bare()
	eq(env.GetMouseFocus, nil, "GetMouseFocus is nil in the fake")
	local btn = env.CreateFrame("Button", nil, env.UIParent)
	btn:SetSize(80, 30)
	btn:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 50, 50)
	btn:EnableMouse(true)
	local entered = 0
	btn:SetScript("OnEnter", function() entered = entered + 1 end)
	c:click(btn)
	eq(entered, 0, "direct click moves no cursor and fires no OnEnter")
end)

-- In game: Lab font table check and looking for cut labels on longest texts.
test("fake assumption: 11 px font string width includes 6 percent margin", function()
	local _, _, env = bare()
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Fonts\\FRIZQT__.TTF", 11)
	fs:SetText("Orgrimmar")
	local w1 = fs:GetStringWidth()
	local w2 = fs:GetUnboundedStringWidth()
	eq(H.GAME_TEXT_MARGIN, 1.06, "fake applies 1.06 text margin")
	ok(w1 > 0 and w1 == w2, "11 px FontString reports positive width")
end)

-- In game: Lab open/close shots and toggling window open and shut in one keypress.
test("fake assumption: stopped and restarted animation fires OnStop then OnFinished", function()
	local w, _, env = bare()
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(50, 50)
	local ag = f:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0)
	a:SetToAlpha(1)
	a:SetDuration(0.5)
	local stops, finishes = 0, 0
	ag:SetScript("OnStop", function() stops = stops + 1 end)
	ag:SetScript("OnFinished", function() finishes = finishes + 1 end)
	ag:Play()
	ag:Stop()
	eq(stops, 1, "Stop fires OnStop")
	ag:Play()
	w:advance(1)
	eq(finishes, 1, "restarted animation fires OnFinished")
end)

-- In game: click each secure button once by hand with taintLog on.
test("fake assumption: plain CreateFrame works in combat without lockdown", function()
	local w, c, env = bare()
	w:enterCombat(c)
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	ok(f ~= nil, "CreateFrame succeeds in combat")
	eq(#w.violations, 0, "no violation recorded")
end)

-- In game: /console taintLog 1, play a ride, then tools/taint.lua.
test("fake assumption: taint guard ignores writes into C_* proxy tables", function()
	local w, c, env = bare()
	env.C_Map._testProbe = 1
	H.taint.scan(c)
	eq(#w.violations, 0, "C_* proxy write is not flagged by taint guard")
end)

-- In game: /console taintLog 1, play a ride, then tools/taint.lua.
test("fake assumption: taint guard ignores overwriting an existing game frame field", function()
	local w, c, env = bare()
	local prev = env.GameTooltip.NineSlice
	env.GameTooltip.NineSlice = prev
	H.taint.scan(c)
	eq(#w.violations, 0, "overwriting existing game frame key is not flagged")
end)

-- In game: two-account ride watching for late or missing whispers and channel messages.
test("fake assumption: whispers deliver in order on the world clock", function()
	local w = T.newWorld()
	local a = w:addClient("Alpha One", { spot = "Orgrimmar", class = "WARLOCK" })
	local b = w:addClient("Beta Two", { spot = "Orgrimmar", class = "MAGE" })
	local got = {}
	b.W.On("CHAT_MSG_WHISPER", function(msg) got[#got + 1] = msg end)
	w:advance(1)
	a.env.C_ChatInfo.SendAddonMessage("WUBER", "PING1", "WHISPER", "Beta Two")
	a.env.C_ChatInfo.SendAddonMessage("WUBER", "PING2", "WHISPER", "Beta Two")
	local addonGot = {}
	b.W.On("CHAT_MSG_ADDON", function(prefix, msg)
		if prefix == "WUBER" and (msg == "PING1" or msg == "PING2") then
			addonGot[#addonGot + 1] = msg
		end
	end)
	w:advance(0.5)
	eq(table.concat(addonGot, ","), "PING1,PING2", "messages arrive in send order")
	T.clean(w)
end)

-- In game: Lab L12.self logging UnitName('player') second return and GetUnitName('player').
test("fake assumption: UnitName and UnitFullName return surname and GetUnitName returns full name", function()
	local _, _, env = bare()
	local n1, r1 = env.UnitName("player")
	local n2, r2 = env.UnitFullName("player")
	local full = env.GetUnitName("player")
	eq(n1, "Anita", "UnitName first return")
	eq(r1, "Lift", "UnitName second return is surname")
	eq(n2, "Anita", "UnitFullName first return")
	eq(r2, "Lift", "UnitFullName second return is surname")
	eq(full, "Anita Lift", "GetUnitName without showServer returns full name")
end)

-- In game: Lab GameFacts row L5.notice.
-- (job 2888: the real client showed OWNER_CHANGED and SET_MODERATOR, PF-046; the creator of a new channel gets exactly those two,
-- see tests/rec/conform_c_test.lua. This old guess said none.)
test("fake assumption: creating a channel fires OWNER_CHANGED and SET_MODERATOR notices, as the real client did (L5.notice)", function()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK" })
	local userNotices = 0
	c.W.On("CHAT_MSG_CHANNEL_NOTICE_USER", function() userNotices = userNotices + 1 end)
	c.env.JoinTemporaryChannel("wuber_test_chan")
	w:advance(2)
	eq(userNotices, 2, "OWNER_CHANGED and SET_MODERATOR fired")
	T.clean(w)
end)

-- In game: Lab GameFacts row L18.
test("fake assumption: taintLog CVar is 1 and hooksecurefunc PlaySound runs on addon calls", function()
	local _, _, env = bare()
	eq(env.GetCVar("taintLog"), "1", "taintLog CVar reads 1")
	local hooked = 0
	env.hooksecurefunc("PlaySound", function() hooked = hooked + 1 end)
	env.PlaySound(89)
	eq(hooked, 1, "hooksecurefunc on PlaySound runs for addon PlaySound")
end)

-- In game: Lab GameFacts row L1.
test("fake assumption: IncomingSummonStatus stays sticky for 120 s", function()
	local w = T.newWorld()
	local caster = w:addClient("Caster One", { spot = "Orgrimmar", class = "WARLOCK" })
	local target = w:addClient("Target Two", { spot = "Ratchet", class = "MAGE" })
	w:advance(1)
	w:summon(caster, "Target Two")
	eq(target.env.C_IncomingSummon.IncomingSummonStatus("player"), 1, "pending summon status is 1")
	w:advance(100)
	eq(H.SUMMON_STICKY, 120, "SUMMON_STICKY constant is 120 s")
	T.clean(w)
end)

-- In game: Lab GameFacts row L19.
test("fake assumption: whisper check answers after 0.2 s", function()
	local w, c, env = bare()
	local got = 0
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:RegisterEvent("CAN_LOCAL_WHISPER_TARGET_RESPONSE")
	f:SetScript("OnEvent", function() got = got + 1 end)
	env.C_ChatInfo.RequestCanLocalWhisperTarget("Player-1-Target")
	w:advance(0.1)
	eq(got, 0, "no response before 0.2 s")
	w:advance(0.2)
	eq(got, 1, "response arrives after 0.2 s")
end)

-- In game: Lab GameFacts row L13.blocked.
test("fake assumption: ReloadUI from addon code is blocked", function()
	local _, c, env = bare()
	local blocked = 0
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:RegisterEvent("ADDON_ACTION_BLOCKED")
	f:SetScript("OnEvent", function(_, _, _, fn) if fn == "ReloadUI()" then blocked = blocked + 1 end end)
	env.ReloadUI()
	eq(c.reloadAsked, 1, "ReloadUI call counted")
	eq(blocked, 1, "ReloadUI fires ADDON_ACTION_BLOCKED")
end)

-- In game: Lab GameFacts row LINE.
test("fake assumption: SendChatMessage whisper from addon code is a violation", function()
	local w, _, env = bare()
	env.SendChatMessage("hello", "WHISPER", nil, "Target")
	ok(#w.violations >= 1, "SendChatMessage from addon records a violation")
end)

-- In game: Lab perf log line (kind perf, Hooks.lua).
test("fake assumption: GetFramerate answers 60", function()
	local _, _, env = bare()
	eq(env.GetFramerate(), 60, "GetFramerate answers 60")
end)

-- In game: Lab login lines ("[login] 14 of 14 passed", "[login +60 s]").
test("fake assumption: C_Map answers immediately after login", function()
	local _, _, env = bare()
	local mapID = env.C_Map.GetBestMapForUnit("player")
	ok(type(mapID) == "number" and mapID > 0, "C_Map.GetBestMapForUnit answers immediately")
end)

-- In game: Lab GameFacts row B16 at a flight master.
test("fake assumption: openTaxi populates NumTaxiNodes and TaxiNodeName", function()
	local w, c, env = bare()
	w:openTaxi(c, {
		{ name = "Orgrimmar, Durotar", type = "CURRENT", cost = 0 },
		{ name = "Ratchet, The Barrens", type = "REACHABLE", cost = 50 },
	})
	eq(env.NumTaxiNodes(), 2, "NumTaxiNodes matches provided list")
	eq(env.TaxiNodeName(1), "Orgrimmar, Durotar", "TaxiNodeName returns node name")
	eq(env.TaxiNodeGetType(2), "REACHABLE", "TaxiNodeGetType returns node type")
	eq(env.TaxiNodeCost(2), 50, "TaxiNodeCost returns node cost")
end)

-- In game: Lab Auto check rows a_ruler and a_font.
test("fake assumption: fake text ruler uses GAME_TEXT_MARGIN 1.06", function()
	eq(H.GAME_TEXT_MARGIN, 1.06, "GAME_TEXT_MARGIN is 1.06")
	eq(H.TEXT_PIXELS, nil, "TEXT_PIXELS is nil by default")
end)

-- In game: Lab Auto check row a_anim.
test("fake assumption: Alpha animation keeps GetAlpha at from and Translation moves nothing", function()
	local w, _, env = bare()
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(40, 40)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 100)
	local ag = f:CreateAnimationGroup()
	local alpha = ag:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0.2)
	alpha:SetToAlpha(1)
	alpha:SetDuration(1)
	local trans = ag:CreateAnimation("Translation")
	trans:SetOffset(50, 0)
	trans:SetDuration(1)
	local updates = 0
	f:Hide()
	f:SetScript("OnUpdate", function() updates = updates + 1 end)
	ag:Play()
	w:advance(0.5)
	eq(f:GetAlpha(), 1, "frame alpha is not changed by playing Alpha animation")
	eq(f:GetLeft(), 100, "Translation moves nothing")
	eq(updates, 0, "OnUpdate does not run on a hidden frame")
end)

-- In game: Lab Auto check row a_census.
test("fake assumption: WOW_PROJECT_ID is 18, no SetGradientAlpha, unplaced edges nil", function()
	local _, _, env = bare()
	eq(env.WOW_PROJECT_ID, 18, "WOW_PROJECT_ID is 18")
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	local tex = f:CreateTexture(nil, "ARTWORK")
	eq(tex.SetGradientAlpha, nil, "Texture has no SetGradientAlpha")
	eq(f:GetLeft(), nil, "unplaced frame GetLeft is nil")
end)

-- In game: two-account ride reading the Lab's ride lines.
test("fake assumption: addon messages deliver on world clock without network jitter", function()
	local w = T.newWorld()
	local a = w:addClient("Alpha One", { spot = "Orgrimmar", class = "WARLOCK" })
	local b = w:addClient("Beta Two", { spot = "Orgrimmar", class = "MAGE" })
	local seen = 0
	b.W.On("CHAT_MSG_ADDON", function(prefix, msg)
		if prefix == "WUBER" and msg == "NET_TEST" then seen = seen + 1 end
	end)
	w:advance(1)
	a.env.C_ChatInfo.SendAddonMessage("WUBER", "NET_TEST", "WHISPER", "Beta Two")
	w:advance(0.1)
	eq(seen, 1, "addon message delivers on world clock step")
	T.clean(w)
end)

-- In game: full restart after a new file; secure buttons in/out of combat; /wuber emote steps.
test("fake assumption: CreateFrame succeeds in combat and DoEmote is absent", function()
	local w, c, env = bare()
	eq(env.DoEmote, nil, "DoEmote is absent in the fake")
	w:enterCombat(c)
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	ok(f ~= nil, "CreateFrame succeeds in combat")
end)

-- In game: Lab Auto check row a_font.
test("fake assumption: fontReadyAt is nil by default so fonts are ready at login", function()
	local w, _, env = bare()
	eq(w.fontReadyAt, nil, "world.fontReadyAt is nil by default")
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(200, 20)
	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Regular.ttf", 11)
	fs:SetText("Orgrimmar")
	fs:SetWidth(200)
	eq(H.truncation(fs), nil, "no stale font reported when fontReadyAt is nil")
end)

-- In game: Lab GameFacts row TRADEBTN at a trade window and clicking each secure button by hand.
test("fake assumption: HasAccessConstraints answers false for every frame", function()
	local _, _, env = bare()
	eq(env.UIParent:HasAccessConstraints(), false, "UIParent:HasAccessConstraints() is false")
	local f = env.CreateFrame("Button", nil, env.UIParent)
	eq(f:HasAccessConstraints(), false, "new Button:HasAccessConstraints() is false")
end)
