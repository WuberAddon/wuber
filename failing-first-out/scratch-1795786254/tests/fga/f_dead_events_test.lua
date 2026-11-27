-- fga f (A3 dead events): events Wuber listens to must be known to the fake and fired by a helper. Adapted from proposal 14.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H, S = T.H, T.S

-- Every event name Wuber's source asks for (static scan of the TOC's .lua files for W.On("X"), RegisterEvent("X"), RegisterUnitEvent("X")),
-- plus the ones that are asked through a variable (a loop or a constant), which the scan cannot read:
--   Net/Transport.lua:39 ASK.EVENT (CAN_LOCAL_WHISPER_TARGET_RESPONSE; known to the fake only in a world with whisperCheck, by design:
--   harness.lua:2842-2845), Net/Inbox.lua:182-184 (the nine CLUB_ events), Drive/Raid.lua:505-507 (CHAT_MSG_RAID, _RAID_LEADER, _PARTY, _PARTY_LEADER).
local DYNAMIC = { "CAN_LOCAL_WHISPER_TARGET_RESPONSE", "CLUB_ADDED", "CLUB_REMOVED", "CLUB_STREAMS_LOADED", "CLUB_STREAM_ADDED",
	"CLUB_STREAM_REMOVED", "INITIAL_CLUBS_LOADED", "CLUB_MEMBER_ROLE_UPDATED", "CLUB_INVITATION_ADDED_FOR_SELF",
	"CLUB_INVITATION_REMOVED_FOR_SELF", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }
-- documented in the real client, left out of the fake's list on purpose
local BY_DESIGN = { CAN_LOCAL_WHISPER_TARGET_RESPONSE = "only with w.whisperCheck (harness.lua:1657)" }

-- Each event name -> where Blizzard documents it (Interface/AddOns/Blizzard_APIDocumentationGenerated/<file>:<line>, Gethe/wow-ui-source @734f065,
-- found with: grep -n 'LiteralName = "X"'). A new event in Wuber needs a line here, which is the point: someone has read the docs for it.
local DOCUMENTED = {
	ADDON_ACTION_BLOCKED = "RestrictedActionsDocumentation.lua:77",
	ADDON_ACTION_FORBIDDEN = "RestrictedActionsDocumentation.lua:88",
	ADDON_LOADED = "AddOnsDocumentation.lua:391",
	BAG_UPDATE_DELAYED = "ContainerDocumentation.lua:677",
	CANCEL_SUMMON = "UnitDocumentation.lua:3565",
	CAN_LOCAL_WHISPER_TARGET_RESPONSE = "ChatInfoDocumentation.lua:625",
	CHANNEL_UI_UPDATE = "ChatInfoDocumentation.lua:732",
	CHAT_MSG_ADDON = "ChatInfoDocumentation.lua:803",
	CHAT_MSG_CHANNEL = "ChatInfoDocumentation.lua:1172",
	CHAT_MSG_CHANNEL_NOTICE = "ChatInfoDocumentation.lua:1294",
	CHAT_MSG_CHANNEL_NOTICE_USER = "ChatInfoDocumentation.lua:1322",
	CHAT_MSG_PARTY = "ChatInfoDocumentation.lua:2066",
	CHAT_MSG_PARTY_LEADER = "ChatInfoDocumentation.lua:2094",
	CHAT_MSG_RAID = "ChatInfoDocumentation.lua:2231",
	CHAT_MSG_RAID_LEADER = "ChatInfoDocumentation.lua:2315",
	CHAT_MSG_SAY = "ChatInfoDocumentation.lua:2398",
	CHAT_MSG_SYSTEM = "ChatInfoDocumentation.lua:2454",
	CHAT_MSG_WHISPER = "ChatInfoDocumentation.lua:2594",
	CHAT_MSG_WHISPER_INFORM = "ChatInfoDocumentation.lua:2622",
	CHAT_MSG_YELL = "ChatInfoDocumentation.lua:2650",
	CLUB_ADDED = "ClubDocumentation.lua:1239",
	CLUB_INVITATION_ADDED_FOR_SELF = "ClubDocumentation.lua:1261",
	CLUB_INVITATION_REMOVED_FOR_SELF = "ClubDocumentation.lua:1271",
	CLUB_MEMBER_ROLE_UPDATED = "ClubDocumentation.lua:1325",
	CLUB_REMOVED = "ClubDocumentation.lua:1395",
	CLUB_STREAMS_LOADED = "ClubDocumentation.lua:1485",
	CLUB_STREAM_ADDED = "ClubDocumentation.lua:1427",
	CLUB_STREAM_REMOVED = "ClubDocumentation.lua:1439",
	CONFIRM_SUMMON = "UnitDocumentation.lua:3587",
	DISPLAY_SIZE_CHANGED = "VideoDocumentation.lua:137",
	ENCOUNTER_END = "EncounterInfoDocumentation.lua:40",
	ENCOUNTER_START = "EncounterInfoDocumentation.lua:55",
	GLOBAL_MOUSE_DOWN = "SystemDocumentation.lua:66",
	GLOBAL_MOUSE_UP = "SystemDocumentation.lua:76",
	GROUP_JOINED = "PartyInfoDocumentation.lua:658",
	GROUP_LEFT = "PartyInfoDocumentation.lua:669",
	GROUP_ROSTER_UPDATE = "PartyInfoDocumentation.lua:680",
	-- the three Group Finder events: line numbers from the client's own UI dump for build 71037
	LFG_LIST_ACTIVE_ENTRY_UPDATE = "LFGListInfoDocumentation.lua:697",
	LFG_LIST_SEARCH_FAILED = "LFGListInfoDocumentation.lua:792",
	LFG_LIST_SEARCH_RESULTS_RECEIVED = "LFGListInfoDocumentation.lua:812",
	INITIAL_CLUBS_LOADED = "ClubDocumentation.lua:1536",
	MAIL_INBOX_UPDATE = "MailInfoDocumentation.lua:111",
	MAIL_SHOW = "MailInfoDocumentation.lua:148",
	NAME_PLATE_UNIT_ADDED = "NamePlateManagerDocumentation.lua:120",
	NAME_PLATE_UNIT_REMOVED = "NamePlateManagerDocumentation.lua:141",
	PARTY_INVITE_REQUEST = "PartyInfoDocumentation.lua:767",
	PARTY_LEADER_CHANGED = "PartyInfoDocumentation.lua:785",
	PLAYER_CONTROL_GAINED = "LossOfControlDocumentation.lua:134",
	PLAYER_CONTROL_LOST = "LossOfControlDocumentation.lua:140",
	PLAYER_ENTERING_WORLD = "SystemDocumentation.lua:136",
	PLAYER_LEAVING_WORLD = "SystemDocumentation.lua:147",
	PLAYER_LOGIN = "SystemDocumentation.lua:153",
	PLAYER_LOGOUT = "SystemDocumentation.lua:159",
	PLAYER_MONEY = "CurrencyInfoDocumentation.lua:637",
	PLAYER_REGEN_DISABLED = "UnitDocumentation.lua:3887",
	PLAYER_REGEN_ENABLED = "UnitDocumentation.lua:3893",
	PLAYER_TRADE_MONEY = "TradeInfoDocumentation.lua:61",
	SPELLS_CHANGED = "SpellBookDocumentation.lua:968",
	TAXIMAP_CLOSED = "TaxiMapDocumentation.lua:70",
	TAXIMAP_OPENED = "TaxiMapDocumentation.lua:76",
	TRADE_ACCEPT_UPDATE = "TradeInfoDocumentation.lua:67",
	TRADE_CLOSED = "TradeInfoDocumentation.lua:78",
	TRADE_MONEY_CHANGED = "TradeInfoDocumentation.lua:90",
	TRADE_PLAYER_ITEM_CHANGED = "TradeInfoDocumentation.lua:96",
	TRADE_REQUEST_CANCEL = "TradeInfoDocumentation.lua:137",
	TRADE_SHOW = "TradeInfoDocumentation.lua:143",
	TRADE_TARGET_ITEM_CHANGED = "TradeInfoDocumentation.lua:149",
	TRADE_UPDATE = "TradeInfoDocumentation.lua:159",
	UI_ERROR_MESSAGE = "SystemDocumentation.lua:229",
	UI_INFO_MESSAGE = "SystemDocumentation.lua:251",
	UI_SCALE_CHANGED = "UIManagerDocumentation.lua:91",
	UNIT_SPELLCAST_CHANNEL_START = "UnitDocumentation.lua:4615",
	UNIT_SPELLCAST_CHANNEL_STOP = "UnitDocumentation.lua:4629",
	UNIT_SPELLCAST_FAILED = "UnitDocumentation.lua:4716",
	UNIT_SPELLCAST_INTERRUPTED = "UnitDocumentation.lua:4744",
	UNIT_SPELLCAST_SENT = "UnitDocumentation.lua:4805",
	UNIT_SPELLCAST_START = "UnitDocumentation.lua:4819",
	UNIT_SPELLCAST_SUCCEEDED = "UnitDocumentation.lua:4847",
	ZONE_CHANGED = "MapDocumentation.lua:653",
	ZONE_CHANGED_INDOORS = "MapDocumentation.lua:659",
	ZONE_CHANGED_NEW_AREA = "MapDocumentation.lua:665",
}

local function wuberEventNames()
	local files, dir = H.tocFiles("Wuber")
	local seen, out = {}, {}
	local function add(name)
		if not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	for _, file in ipairs(files) do
		if file:match("%.lua$") then
			local fh = io.open(dir .. "/" .. file, "rb")
			if fh then
				local text = fh:read("*a")
				fh:close()
				for line in (text .. "\n"):gmatch("(.-)\r?\n") do
					if not line:match("^%s*%-%-") then
						for name in line:gmatch('W%.On%(%s*"([A-Z][A-Z0-9_]+)"') do add(name) end
						for name in line:gmatch('Register%a*Event%(%s*"([A-Z][A-Z0-9_]+)"') do add(name) end
					end
				end
			end
		end
	end
	for _, name in ipairs(DYNAMIC) do add(name) end
	table.sort(out)
	return out
end

-- Runs fn and says which event names the fake was asked about and did not know (Frame:RegisterEvent and Client:fire both read
-- H.KNOWN_EVENTS[name]; a missing name goes through this table's __index for the length of fn).
local function unknownAsked(fn)
	local missed = {}
	local K = H.KNOWN_EVENTS
	local old = getmetatable(K)
	setmetatable(K, { __index = function(_, k) missed[k] = (missed[k] or 0) + 1 return nil end })
	local okf, err = pcall(fn)
	setmetatable(K, old)
	if not okf then error(err, 0) end
	local list = {}
	for name in pairs(missed) do list[#list + 1] = name end
	table.sort(list)
	return list
end

local function listOf(t) return table.concat(t, ", ") end

---------------------------------------------------------------------------------------------------------------
-- Gate 1a: what Wuber asks for is documented (a guard: passes today)
---------------------------------------------------------------------------------------------------------------

-- guard: every event name in Wuber's source is documented by Blizzard for this client (the DOCUMENTED table above)
test("fga f: every event Wuber registers is in the real client's API documentation", function()
	local names = wuberEventNames()
	local missing = {}
	for _, name in ipairs(names) do
		if not DOCUMENTED[name] then missing[#missing + 1] = name end
	end
	ok(#names > 50, "control: the scan found " .. #names .. " event names")
	ok(#missing == 0, "not in DOCUMENTED (read the docs for it, then add it): " .. listOf(missing))
end)

---------------------------------------------------------------------------------------------------------------
-- Gate 1b: the fake knows them, seen two ways
---------------------------------------------------------------------------------------------------------------

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: every game event Wuber's source asks for is known to the fake", function()
	local names = wuberEventNames()
	local unknown = {}
	for _, name in ipairs(names) do
		if not H.KNOWN_EVENTS[name] and not BY_DESIGN[name] then unknown[#unknown + 1] = name end
	end
	print("      fga f: Wuber asks for " .. #names .. " events; unknown to the fake: " .. (#unknown > 0 and listOf(unknown) or "none"))
	ok(#unknown == 0, "documented in the real game, unknown to the fake (RegisterEvent raises, W.On hides it): " .. listOf(unknown))
end)

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: a fresh rider and a fresh driver never ask the fake for an event it does not know", function()
	local asked = unknownAsked(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		local r = T.rider(w, T.TESTCHAR)
		T.settle(w)
		r.W.UI.Toggle(true)
		w:advance(3)
	end)
	local real = {}
	for _, name in ipairs(asked) do
		if not BY_DESIGN[name] then real[#real + 1] = name end
	end
	ok(#real == 0, "asked for and refused (the handler never runs offline): " .. listOf(real))
end)

-- guard: the correction of the notes. MAIL_SHOW, MAIL_INBOX_UPDATE and MAIL_CLOSED are known in every world (tests/lib/mail.lua:25),
-- not "only with the mail lib" as w2-login-saved-group.md row 18 says: the harness loads that lib itself (harness.lua:6651).
-- guard: the mail events were already known; this keeps them known beside the new ones
test("fga f: the mail events are known to the fake in every world", function()
	for _, name in ipairs({ "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" }) do
		ok(H.KNOWN_EVENTS[name], name .. " is not known")
	end
end)

---------------------------------------------------------------------------------------------------------------
-- Behaviour: GLOBAL_MOUSE_DOWN
---------------------------------------------------------------------------------------------------------------

-- Real: GLOBAL_MOUSE_DOWN(button), documented in SystemDocumentation.lua:64-72 (payload button, SynchronousEvent); Blizzard's own code closes
-- things on it the same way Wuber does (Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua:61-84:
-- https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua#L76-L85).
-- The real client accepted the registration: the recorder asked for 76 of Wuber's events (GLOBAL_MOUSE_DOWN and TRADE_UPDATE among them,
-- WuberRec/Data.lua) and its unknownEvents list is empty (triage/item13.md:7).
-- Wuber: UI/Window.lua:1161-1164 "the splash ends at any click"; UI/Phone.lua:55 (the splash is click-through).
local MOUSE = {}

local function openOnSplash()
	local w = T.newWorld(MOUSE)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(0.2)
	local ui = r.W.UI.state
	ok(ui.splashing, "control: the first open plays the splash (if this fails, this world has no splash: see README)")
	return w, r, ui
end

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: GLOBAL_MOUSE_DOWN ends the opening splash", function()
	local w, r, ui = openOnSplash()
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") -- today: the harness refuses the event ("doesn't list")
	ok(not ui.splashing, "the splash is still on after a mouse press")
	T.clean(w)
end)

-- The fake's click helper (Client:click, harness.lua:4711) should do what the game does: a press anywhere fires GLOBAL_MOUSE_DOWN with the
-- button, with the mouse already over the frame clicked (so IsMouseOver is true for it). Engine order against the frame's own
-- OnMouseDown is not in the source: probe P5 (README).
-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: a real click anywhere ends the opening splash", function()
	local w, r, ui = openOnSplash()
	local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	f:SetSize(40, 40)
	f:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 5, 5)
	f:EnableMouse(true)
	f:Show()
	r:click(f)
	ok(not ui.splashing, "the splash is still on after a click on another frame")
	T.clean(w)
end)

-- Wuber/UI/Rider/Cards.lua:142-144: the right-click menu on a driver card closes on a press that is not on it.
local function openCardMenu(r)
	local CM = r.W.Mod("UI.Rider.Cards")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	-- a card the player sees is placed, so its menu has a place too
	parent:SetSize(300, 60)
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	local card = CM.buildCard(parent)
	local d = { name = "Farra Way", key = "farra way", dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Farra's Rides", heard = r.env.GetTime() }
	card.view = d
	CM.fillCard(card, d)
	card:GetScript("OnClick")(card, "RightButton")
	r.world:advance(0.6)
	local fs = r:findText("Hide this driver")[1]
	ok(fs and H.visible(fs), "control: the card menu is open")
	local menu, p = nil, fs
	while p do
		local q = p:GetParent()
		if q == r.env.UIParent then menu = p break end
		p = q
	end
	ok(menu, "control: found the menu frame")
	return fs, menu
end

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: the card menu closes when the player presses the mouse somewhere else", function()
	local w = T.newWorld(MOUSE)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	local fs = openCardMenu(r)
	local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	f:SetSize(40, 40)
	f:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 5, 5)
	f:EnableMouse(true)
	f:Show()
	r:click(f)
	ok(not H.visible(fs), "the menu is still open after a click on another frame")
	T.clean(w)
end)

-- guard: a press ON the menu must not close it (passes today because nothing closes the menu; the fix must not over-close)
test("fga f: the card menu stays open when the mouse is pressed on the menu", function()
	local w = T.newWorld(MOUSE)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	local fs, menu = openCardMenu(r)
	r:clickOn(menu)
	ok(H.visible(fs), "the menu closed on a press that was on it")
	T.clean(w)
end)

---------------------------------------------------------------------------------------------------------------
-- Behaviour: TRADE_UPDATE
---------------------------------------------------------------------------------------------------------------

-- Real: TRADE_UPDATE, documented in TradeInfoDocumentation.lua:156-161; Blizzard's trade window re-reads everything on it
-- (Blizzard_UIPanels_Game/Mainline/TradeFrame.lua:8 and 37-45). Wuber: Drive/Trade.lua:137 W.On("TRADE_UPDATE", update), update =
-- re-read the other side's money and recompute "ready" (Drive/Trade.lua:96-110). NOT proven: that the real client fires it when the other
-- player changes their money (the one full trade the recorder saw had TRADE_SHOW, 22 TRADE_TARGET_ITEM_CHANGED, 2 TRADE_CLOSED and no
-- TRADE_UPDATE: triage/item13.md:7). So this test fires it by hand; the fake's own trade helpers need not fire it.
-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: TRADE_UPDATE makes the driver read the trade window again", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpt("autoTrade", false)
	A.SetOpen(true)
	local dan = w:addBot("Dan Miller", { spot = "Undercity" })
	A.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1 }
	ok(w:openTrade(dan, a.player), "control: the trade opens")
	w:advance(0.5)
	ok(A.trade, "control: Wuber noticed the trade window (TRADE_SHOW)")
	eq(A.trade.money, 0, "control: nothing in the window yet")
	-- the other side's gold changes with no other event (what TRADE_UPDATE is for): the fake's trade state is player.trade.money[name]
	a.player.trade.money[dan.name] = 5000
	a:fire("TRADE_UPDATE") -- today: the harness refuses the event ("doesn't list"), and Wuber's registration was refused too
	eq(A.trade.money, 5000, "Wuber read the new amount")
	T.clean(w)
end)

---------------------------------------------------------------------------------------------------------------
-- Helpers that fire the events
---------------------------------------------------------------------------------------------------------------

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: a click fires GLOBAL_MOUSE_DOWN with the button, then GLOBAL_MOUSE_UP", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local seen = {}
	local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	f:SetSize(40, 40)
	f:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 5, 5)
	f:EnableMouse(true)
	f:Show()
	f:RegisterEvent("GLOBAL_MOUSE_DOWN")
	f:RegisterEvent("GLOBAL_MOUSE_UP")
	f:SetScript("OnEvent", function(_, ev, button) seen[#seen + 1] = ev .. ":" .. tostring(button) end)
	r:click(f, "RightButton")
	eq(table.concat(seen, ","), "GLOBAL_MOUSE_DOWN:RightButton,GLOBAL_MOUSE_UP:RightButton")
	T.clean(w)
end)

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: mouseEvents = false keeps a click silent", function()
	local w = T.newWorld({ mouseEvents = false })
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local n = 0
	local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	f:SetSize(40, 40)
	f:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 5, 5)
	f:EnableMouse(true)
	f:Show()
	f:RegisterEvent("GLOBAL_MOUSE_DOWN")
	f:SetScript("OnEvent", function() n = n + 1 end)
	r:click(f)
	eq(n, 0)
	T.clean(w)
end)

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: a withdrawn invite fires PARTY_INVITE_CANCEL and clears the box", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local got, nargs
	local f = r.env.CreateFrame("Frame")
	f:RegisterEvent("PARTY_INVITE_CANCEL")
	f:SetScript("OnEvent", function(...) got, nargs = true, select("#", ...) end)
	w:invite(a, r.player.name)
	w:advance(1)
	ok(r.popups.PARTY_INVITE, "control: the invite box is up")
	ok(w:withdrawInvite(a.player, r.player), "withdrawn")
	eq(got, true, "the event came")
	eq(nargs, 2, "frame and event name only: the documented payload is empty")
	ok(not r.popups.PARTY_INVITE, "the box is gone")
	ok(not r.player.pendingInvite, "nothing left to accept")
	T.clean(w)
end)

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: withdrawing an invite that is not pending does nothing", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	ok(not w:withdrawInvite(a.player, r.player))
	T.clean(w)
end)

-- guard: infra, failed before because the fake (tests/harness.lua, not reverted by failing-first; proved by hand on the base harness: 11 of 14 fail) lacked it
test("fga f: INCOMING_SUMMON_CHANGED and PARTY_INVITE_CANCEL are known events", function()
	ok(H.KNOWN_EVENTS.INCOMING_SUMMON_CHANGED and H.KNOWN_EVENTS.PARTY_INVITE_CANCEL and H.KNOWN_EVENTS.TRADE_UPDATE_WARNINGS)
end)
