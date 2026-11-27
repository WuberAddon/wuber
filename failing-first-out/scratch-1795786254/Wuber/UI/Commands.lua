-- Module: UI.Commands
-- Purpose: /wuber and /ride (was Commands.lua): open or close the app; older words still work; W.SelfTest
--   for Settings' "Check my game".
-- API: W.SelfTest, W.SlashCommand, W.MissingParts, SLASH_WUBER1, SLASH_WUBER2, BINDING_HEADER_WUBER, BINDING_NAME_WUBER_TOGGLE
-- Internals: (none)
-- Uses: (none: Core via W)
-- Later: FX.Emblem (W.Emblem.Command: /wuber emblem), UI.Bug (UI.Bug.Open: /wuber bug), UI.Tips (IsOn, SetOn, ShowNow, ShowAgain: /wuber tips),
--   /wuber why: UI.Tips (Why), UI.Bird (Why), UI.FlightPins (Why), UI.InFlight (Why), UI.Driver.Customers (WhyInvite), UI.Rider.Home (WhyUsual, WhyBounty),
--   UI.Coach (Why), Net.Update (Why), UI.Moments (WhyMilestone), UI.WhatsNew (Why)
-- Events: listens login; fires SETTINGS
-- Standalone: no
-- Test: tests/ui/commands_test.lua
-- From: Commands.lua 1-481 (Wuber 2.2.1)
--
-- Commands: /wuber (and /ride) open or close the app; everything else lives in the app's
-- Settings screen. "/wuber help" (and any word Wuber doesn't know) opens Settings.
-- "/wuber bug" opens the bug report to copy (UI.Bug; also "Report a bug" in Settings and Help).
--
-- "/wuber tips" turns the login tips on and shows one now (already on: the last tip again); "/wuber tips off" turns them off (also Settings > Riding > Tips).
-- "/wuber advanced" switches Advanced mode on or off (W.SetAdvanced; also the switch at the top of Settings).
-- "/wuber updates [on|off]" turns the newer-version note on or off (WuberDB.updateNotes); alone, says which it is.
-- "/wuber why" lists what is hidden right now (the tip card, Skip the bird, ...) and the first rule that hides each, one line each.
--
-- Older words still work, quietly, and are not advertised anywhere:
--   drive [on|off], price 50s, ping, map, minimap, status, test (the self-test's summary)
--   emblem [1|2|3|preview|stop|on|off|mine on|off] (the Pioneers' emblem: FX.Emblem)
--
-- W.SelfTest() -> { { name, ok, detail }, ... }: what this game client supports, for
-- Settings' "Check my game" panel (and /wuber test).

local _, W = ...
local Mod = W.Module("UI.Commands", {})

local str, num = W.Str, W.Num

local Y = "|cffffd200" -- command colour
local R = "|r"

local function say(text) W.Print(text) end

local function toggleWindow()
	local ui = W.UI
	if type(ui) == "table" and type(ui.Toggle) == "function" then
		W.Safe("window", ui.Toggle)
	else
		say("The Wuber window isn't loaded.")
	end
end

-- Opens the app on its Settings screen (no list of commands any more).
local function help()
	local ui = W.UI
	if type(ui) == "table" and type(ui.Show) == "function" then
		W.Safe("settings", ui.Show, "settings")
	else
		toggleWindow()
	end
end

-- /wuber bug: the bug report window (UI.Bug); nothing is sent.
local function bug()
	local ui = W.UI
	local b = type(ui) == "table" and ui.Bug or nil
	if type(b) == "table" and type(b.Open) == "function" then
		W.Safe("bug", b.Open)
	else
		say("The bug report isn't loaded. Restart the game to finish updating Wuber.")
	end
end

local function drive(arg)
	local provider = W.Provider()
	if provider then
		say("You drive with " .. provider .. ". Use its own window.")
		return
	end
	local c = W.Char()
	local on
	if arg == "on" then on = true elseif arg == "off" then on = false else on = not c.drive end
	local ok, why = W.SetDriving(on)
	if not ok then
		if why == "class" then
			-- 2.1: any class runs a service, with a Warlock who summons
			say("Set up driving in the Drive tab first (" .. Y .. "/wuber drive" .. R .. "): pick the Warlock who summons for you.")
		else
			say("You can't drive right now.")
		end
		return
	end
	if on and not W.DriverBeacon() then
		say("Driver mode isn't loaded, so riders can't see you yet.")
	elseif on then
		say("You're online as a driver at " .. W.Money(c.price) .. ".")
		if not W.OnNetwork() then say("You're not on the Wuber network yet, so riders can't see you unless your community is joined.") end
	else
		say("You're offline.")
	end
end

-- The built-in engine (W.Drive) runs here: "/wuber drive <command>" goes to it.
local function engineOn()
	local DR = W.Drive
	if type(DR) ~= "table" or type(DR.Command) ~= "function" or type(DR.Active) ~= "function" then return false end
	local ok, on = pcall(DR.Active)
	return ok and on == true
end

-- "/wuber drive" alone opens the Drive tab; "/wuber drive <command>" runs Ritual Rides'
-- old commands under their names (Drive_Commands.lua). Without the engine (another addon
-- drives, or a character that never set up driving) the 1.x words still work: drive [on|off].
local function driveCommand(rest)
	rest = rest or ""
	local DR = W.Drive
	if rest == "" then
		local ui = W.UI
		if type(DR) == "table" and type(DR.Command) == "function" and type(ui) == "table" and type(ui.ShowDrive) == "function" then
			DR.Command("")
		elseif type(W.Driver) == "table" and type(W.Driver.Toggle) == "function" then
			W.Safe("drive", W.Driver.Toggle)
		end
		return
	end
	if engineOn() then
		DR.Command(rest)
		return
	end
	local low = rest:lower()
	if low == "on" or low == "off" then
		drive(low)
	elseif type(DR) == "table" and type(DR.Command) == "function" and W.Provider() == nil then
		DR.Command(rest)
	else
		drive(low)
	end
end

local function price(arg)
	local provider = W.Provider()
	if provider then
		say(provider .. " sets your price.")
		return
	end
	local c = W.Char()
	if not arg or arg == "" then
		say("Your price is " .. W.Money(c.price) .. ". Change it with " .. Y .. "/wuber price 50s" .. R .. ".")
		return
	end
	local copper = W.ParseMoney(arg)
	if not copper then
		say("That isn't a price. Try " .. Y .. "/wuber price 50s" .. R .. " or " .. Y .. "/wuber price 1g" .. R .. ".")
		return
	end
	if copper < W.MIN_PRICE then
		say("The lowest fare on Wuber is " .. W.Money(W.MIN_PRICE) .. ". A driver's time is worth it.")
		return
	end
	if copper > 99999999 then -- the most the driver engine and the network carry
		say("The highest fare on Wuber is " .. W.Money(99999999) .. ".")
		return
	end
	local DR = W.Drive
	if engineOn() and type(DR.SetPrice) == "function" then W.Safe("price", DR.SetPrice, copper) end
	c.price = copper
	W.Fire("SETTINGS", "price")
	W.SendBeacon()
	say("Your price is now " .. W.Money(copper) .. ".")
end

local function ping()
	local sent, why = W.Ping()
	if sent then
		say("Drivers have been asked to check in.")
	elseif why == "offline" then
		say("You're not on the Wuber network yet.")
	else
		say("Wait " .. tostring(why) .. " s before asking again.")
	end
end

-- /wuber tips [off]: UI.Tips owns the switch; without it the saved flag is set directly.
local function tips(rest)
	local m = W.Mod("UI.Tips")
	local has = type(m) == "table" and type(m.SetOn) == "function"
	local off = (rest or ""):lower() == "off"
	-- already on: bring back this session's tip (Show me or Close hid it)
	local again = has and not off and type(m.IsOn) == "function" and m.IsOn() == true and type(m.ShowAgain) == "function"
	if has then
		W.Safe("tips", m.SetOn, not off)
	else
		(W.db or W.InitDB()).tipsOn = not off
	end
	if off then
		say("Tips are off. Turn Login tips back on in Settings > Riding, or type /wuber tips.")
		return
	end
	-- ShowNow says false (combat, a ride, the coach marks, nothing left) when it cannot show one now
	if has and type(m.ShowNow) == "function" then
		local ok, shown = pcall(again and m.ShowAgain or m.ShowNow)
		if ok and shown == false then
			say("Tips are on. The next one shows when you open Wuber.")
			return
		end
	end
	say("Tips are on.")
end

-- /wuber updates [on|off]: WuberDB.updateNotes (false = off; anything else = on).
local function updates(rest)
	local db = W.db or W.InitDB()
	local v = (rest or ""):lower()
	if v == "on" or v == "off" then
		db.updateNotes = v == "on"
		W.Fire("SETTINGS", "updateNotes")
	end
	say("Update notes: " .. (db.updateNotes ~= false and "on" or "off") .. ".")
end

-- /wuber why: each surface a rule can hide says (Mod.Why-style, no arguments) nil or one line naming
-- the first rule that hides it; looked up at run time, a missing module or function is skipped, one
-- that throws is skipped and the rest still print.
local WHY = {
	{ "UI.Tips", "Why" }, { "UI.Bird", "Why" }, { "UI.FlightPins", "Why" }, { "UI.InFlight", "Why" },
	{ "UI.Driver.Customers", "WhyInvite" }, { "UI.Rider.Home", "WhyUsual" },
	{ "UI.Rider.Home", "WhyBounty" }, { "UI.Coach", "Why" }, { "Net.Update", "Why" }, { "UI.Moments", "WhyMilestone" },
	{ "UI.WhatsNew", "Why" },
}
local function why()
	local lines = {}
	for _, e in ipairs(WHY) do
		local m = W.Mod(e[1])
		local fn = type(m) == "table" and m[e[2]] or nil
		if type(fn) == "function" then
			local okWhy, line = pcall(fn)
			line = okWhy and str(line) or nil
			if line and line ~= "" then lines[#lines + 1] = line end
		end
	end
	if #lines == 0 then
		say("Nothing is hidden right now.")
		return
	end
	say("Hidden right now, and why:")
	for _, line in ipairs(lines) do say(line) end
end

local function toggleSetting(key, label, invert)
	local db = W.db or W.InitDB()
	db[key] = not db[key]
	W.Fire("SETTINGS", key)
	local on = db[key]
	if invert then on = not on end
	say(label .. ": " .. (on and "on" or "off") .. ".")
end

local function status()
	local count = 0
	for _ in pairs(W.drivers) do count = count + 1 end
	local idx = W.ChannelIndex()
	say("version " .. tostring(W.VERSION) .. ".")
	if type(W.NetStatusLines) == "function" then
		for _, line in ipairs(W.NetStatusLines()) do say(line) end -- network; drivers with their realms
	else
		if idx then
			say("Network: joined (channel " .. idx .. ").")
		else
			say("Network: not joined. Requests still work by whisper.")
		end
		say("Drivers online: " .. count .. ".")
	end
	local provider = W.Provider()
	if provider then
		say("Driving: with " .. provider .. ".")
	elseif W.DriverBeacon() then
		say("Driving: online at " .. W.Money(W.Char().price) .. ". Requests waiting: " .. #W.incoming .. ".")
	else
		say("Driving: offline.")
	end
	local r = W.ride
	if r then
		say("Your ride: " .. tostring(r.state) .. ", " .. tostring(r.dest) .. " with " .. W.Short(r.driver) .. ".")
	end
	local n = W.net
	say("Messages: " .. n.sent .. " sent, " .. n.heard .. " heard, " .. n.failed .. " failed, " .. W.QueueLength() .. " waiting.")
end

---------------------------------------------------------------------------
-- /wuber test: what this client supports, each call under pcall
---------------------------------------------------------------------------

local MEDIA = { "icon", "arc", "back", "badge", "check", "circle", "close", "fade", "glow", "gradient",
	"header", "mapbg", "minimap", "pill", "pin", "portal", "pulse", "radar", "ride", "ring", "rounded",
	"search", "shadow", "star", "star_outline", "summon", "wordmark" }

-- The fonts to try: the game's two, and the ones W.Theme uses (if it is loaded).
local function fontList()
	local list, seen = {}, {}
	local function add(path)
		if type(path) == "string" and path ~= "" and not seen[path] then
			seen[path] = true
			list[#list + 1] = path
		end
	end
	add("Fonts\\ARIALN.TTF")
	add("Fonts\\FRIZQT__.TTF")
	local T = W.Theme
	if type(T) == "table" then
		add(T.FONT)
		if type(T.FONTS) == "table" then
			for _, k in ipairs({ "regular", "medium", "bold" }) do add(T.FONTS[k]) end
			for _, v in pairs(T.FONTS) do add(v) end
		end
	end
	return list
end

local testFrame, testTexture, testFont -- made once (by the first self-test), reused
local testGroup, testSecure -- likewise: the animation group and the hidden request button

-- The hidden frame, picture and text the self-test tries things on. ok, or false and the error.
local function makeTest()
	if testFrame then return true end
	local ok, f = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok or not f then return false, f end
	testFrame = f
	testFrame:Hide()
	local okT, t = pcall(testFrame.CreateTexture, testFrame, nil, "ARTWORK")
	testTexture = okT and t or nil
	local okF, fs = pcall(testFrame.CreateFontString, testFrame, nil, "OVERLAY")
	testFont = okF and fs or nil
	return true
end

-- Fonts. The game loads a font file a moment after it is first asked for, and this client's
-- SetFont says false (and GetFont nil) until then (the author's test of 2.2.3: the addon's regular font file, which
-- nothing had drawn yet, read "not working" in the self-test 8 s after login). So the self-test
-- believes any one sign that a font works, and gives a font it asks for the first time a few
-- seconds to load (fontWorks); FONT.asked: when each file was first asked for (GetTime).
local FONT = { arialn = "Fonts\\ARIALN.TTF", frizqt = "Fonts\\FRIZQT__.TTF", grace = 5, asked = {} }
local ARIALN, FRIZQT = FONT.arialn, FONT.frizqt

local function samePath(a, b)
	if type(a) ~= "string" or type(b) ~= "string" then return false end
	return (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

-- One of Wuber's own texts drawn in that file now (W.Theme keeps them all in T.allText).
local function drawnIn(path)
	local T = W.Theme
	local all = type(T) == "table" and type(T.allText) == "table" and T.allText or {}
	local n = 0
	for fs in pairs(all) do
		n = n + 1
		if n > 500 then break end
		if type(fs) == "table" and type(fs.GetFont) == "function" then
			local ok, got = pcall(fs.GetFont, fs)
			if ok and samePath(W.Plain(got), path) then return true end
		end
	end
	return false
end

-- Whether a font file works here. Any one sign is enough: SetFont didn't say no, GetFont gives
-- the file back, one of Wuber's texts is drawn in it, or the sample's width moved away from BOTH
-- game fonts' (one alone can't tell a font that failed and fell back to another). With no sign,
-- a font first asked for under FONT.grace seconds ago is still loading: not called broken yet.
-- widths: the sample's width in Arial Narrow and in Friz Quadrata; fs holds the sample.
local function fontWorks(fs, path, widths)
	local now = num(GetTime()) or 0
	local first = FONT.asked[path]
	if not first then FONT.asked[path] = now end
	local ok, res = pcall(fs.SetFont, fs, path, 14, "")
	if ok and W.Plain(res) ~= false then return true end
	local okG, got = pcall(fs.GetFont, fs)
	if okG and samePath(W.Plain(got), path) then return true end
	local okW, wd = pcall(fs.GetStringWidth, fs)
	wd = okW and num(wd) or nil
	if wd and widths[1] and widths[2] and math.abs(wd - widths[1]) > 0.5 and math.abs(wd - widths[2]) > 0.5 then return true end
	if drawnIn(path) then return true end
	return first == nil or now - first < FONT.grace
end

-- Checks what this game client supports, each call under pcall. Returns a list of
-- { name, ok, detail }: a short plain name for the Settings panel, whether it works, and
-- (when it doesn't) what is missing. Nothing is printed.
function W.SelfTest()
	local out = {}
	local function add(name, okAll, missing)
		out[#out + 1] = { name = name, ok = okAll and true or false,
			detail = (not okAll and missing and #missing > 0) and table.concat(missing, ", ") or nil }
	end
	local function has(fn) return type(fn) == "function" end
	local function try(fn, ...)
		if type(fn) ~= "function" then return false end
		local ok, res = pcall(fn, ...)
		return ok, res
	end
	-- a group of checks: name, then pairs of label/ok
	local function group(name, checks)
		local missing = {}
		for _, c in ipairs(checks) do
			if not c[2] then missing[#missing + 1] = c[1] end
		end
		add(name, #missing == 0, missing)
	end

	if not has(CreateFrame) then
		add("Drawing windows", false, { "CreateFrame" })
		return out
	end
	local made, why = makeTest()
	if not made then
		add("Drawing windows", false, { "CreateFrame: " .. tostring(why) })
		return out
	end

	-- pictures
	local pics = { { "CreateTexture", testTexture ~= nil } }
	if testTexture then
		local t = testTexture
		for _, name in ipairs(MEDIA) do
			local ok, res = try(t.SetTexture, t, "Interface\\AddOns\\Wuber\\Media\\" .. name)
			pics[#pics + 1] = { name, ok and W.Plain(res) ~= false }
		end
		pics[#pics + 1] = { "SetColorTexture", (try(t.SetColorTexture, t, 0, 0, 0, 1)) }
		pics[#pics + 1] = { "SetVertexColor", (try(t.SetVertexColor, t, 1, 1, 1, 1)) }
		pics[#pics + 1] = { "SetTexCoord", (try(t.SetTexCoord, t, 0, 1, 0, 1)) }
		local grad = false
		if has(CreateColor) then
			grad = (try(t.SetGradient, t, "VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(1, 1, 1, 1)))
		end
		if not grad then grad = (try(t.SetGradientAlpha, t, "VERTICAL", 0, 0, 0, 1, 1, 1, 1, 1)) end
		pics[#pics + 1] = { "SetGradient", grad }
	end
	group("Pictures", pics)

	-- fonts
	local fonts = { { "CreateFontString", testFont ~= nil } }
	if testFont then
		local fs = testFont
		try(fs.SetText, fs, "Wuber summons Ratchet 50s")
		-- the sample's width in two very different game fonts (see fontWorks)
		local widths = {}
		for i, base in ipairs({ ARIALN, FRIZQT }) do
			try(fs.SetFont, fs, base, 14, "")
			local okW, wd = try(fs.GetStringWidth, fs)
			widths[i] = okW and num(wd) or nil
		end
		for _, path in ipairs(fontList()) do
			try(fs.SetFont, fs, ARIALN, 14, "") -- (a font that fails leaves Arial Narrow)
			fonts[#fonts + 1] = { path:match("[^\\\\]+$") or path, fontWorks(fs, path, widths) }
		end
		try(fs.SetFont, fs, ARIALN, 14, "")
		fonts[#fonts + 1] = { "SetText", (try(fs.SetText, fs, "Wuber")) }
	end
	group("Fonts", fonts)

	-- animations
	local anims = {}
	local okAG, ag = true, testGroup
	if not ag then okAG, ag = try(testFrame.CreateAnimationGroup, testFrame) end
	if okAG and ag then testGroup = ag end
	anims[#anims + 1] = { "CreateAnimationGroup", okAG and ag ~= nil }
	if okAG and ag then
		anims[#anims + 1] = { "SetLooping", (try(ag.SetLooping, ag, "REPEAT")) }
		local kinds = {
			Alpha = { { "SetFromAlpha", 0 }, { "SetToAlpha", 1 } },
			Translation = { { "SetOffset", 0, 10 } },
			Scale = { { "SetScaleFrom", "SetFromScale", 1, 1 }, { "SetScaleTo", "SetToScale", 1.1, 1.1 } },
			Rotation = { { "SetDegrees", 90 } },
		}
		for _, kind in ipairs({ "Alpha", "Translation", "Scale", "Rotation" }) do
			local ok, a = try(ag.CreateAnimation, ag, kind)
			anims[#anims + 1] = { kind, ok and a ~= nil }
			if ok and a then
				for _, m in ipairs(kinds[kind]) do
					if kind == "Scale" then
						local fn = a[m[1]] or a[m[2]]
						anims[#anims + 1] = { kind .. ":" .. m[1], (try(fn, a, m[3], m[4])) }
					else
						anims[#anims + 1] = { kind .. ":" .. m[1], (try(a[m[1]], a, m[2], m[3])) }
					end
				end
				anims[#anims + 1] = { kind .. ":SetDuration", (try(a.SetDuration, a, 0.2)) }
				anims[#anims + 1] = { kind .. ":SetStartDelay", (try(a.SetStartDelay, a, 0)) }
				anims[#anims + 1] = { kind .. ":SetSmoothing", (try(a.SetSmoothing, a, "OUT")) }
				anims[#anims + 1] = { kind .. ":SetOrder", (try(a.SetOrder, a, 1)) }
			end
		end
	end
	group("Animations", anims)

	-- the map
	local CM = type(C_Map) == "table" and C_Map or {}
	local okM, mapID = try(CM.GetBestMapForUnit, "player")
	mapID = okM and num(mapID) or nil
	local maps = { { "C_Map.GetBestMapForUnit", mapID ~= nil } }
	local world = false
	-- inside an instance the game answers nil for the map calls: that is not a fault
	local mapSkipped = W.InInstance() and mapID == nil
	if mapID then
		local okP, pos = try(CM.GetPlayerMapPosition, mapID, "player")
		maps[#maps + 1] = { "C_Map.GetPlayerMapPosition", okP and W.Plain(pos) ~= nil }
		local okI, info = try(CM.GetMapInfo, mapID)
		maps[#maps + 1] = { "C_Map.GetMapInfo", okI and type(W.Plain(info)) == "table" }
		local okA, art = try(CM.GetMapArtLayerTextures, mapID, 1)
		maps[#maps + 1] = { "C_Map.GetMapArtLayerTextures", okA and type(W.Plain(art)) == "table" }
		if has(CreateVector2D) and has(CM.GetWorldPosFromMapPos) and has(CM.GetMapPosFromWorldPos) then
			local okW, cont, wpos = pcall(CM.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
			if okW and num(cont) and W.Plain(wpos) ~= nil then
				world = (pcall(CM.GetMapPosFromWorldPos, cont, wpos, mapID))
			end
		end
	end
	-- (the two map rows are left out there: nothing was checked, and no row claims otherwise)
	if not mapSkipped then
		group("Your position on the map", maps)
		add("Distances (time saved, map pins)", world, { "C_Map world positions" })
	end

	-- the network
	local CI = type(C_ChatInfo) == "table" and C_ChatInfo or {}
	group("Wuber network", {
		{ "C_ChatInfo.SendAddonMessage", has(CI.SendAddonMessage) },
		{ "C_ChatInfo.RegisterAddonMessagePrefix", has(CI.RegisterAddonMessagePrefix) },
		{ "JoinTemporaryChannel", has(JoinTemporaryChannel) or has(JoinChannelByName) },
		{ "GetChannelName", has(GetChannelName) },
		{ "ChatFrame_RemoveChannel", has(ChatFrame_RemoveChannel)
			or (type(ChatFrameUtil) == "table" and has(ChatFrameUtil.RemoveChannel)) },
		{ "ChatFrame_AddMessageEventFilter", has(ChatFrame_AddMessageEventFilter)
			or (type(ChatFrameUtil) == "table" and has(ChatFrameUtil.AddMessageEventFilter)) },
	})
	add("Network channel joined", W.OnNetwork(), { "not joined yet (or 10 channels already)" })
	group("Invites and groups", {
		{ "InviteUnit", (type(C_PartyInfo) == "table" and has(C_PartyInfo.InviteUnit)) or has(InviteUnit) },
		{ "AcceptGroup", has(AcceptGroup) },
		{ "StaticPopup_FindVisible", has(StaticPopup_FindVisible) },
	})
	group("Summons", {
		{ "ConfirmSummon", (type(C_SummonInfo) == "table" and has(C_SummonInfo.ConfirmSummon)) or has(ConfirmSummon) },
	})
	group("Money and where you are", {
		{ "GetMoney", has(GetMoney) },
		{ "UnitFactionGroup", W.Faction() ~= "" },
		{ "GetSubZoneText", has(GetSubZoneText) },
	})
	local secure = { { "InCombatLockdown", has(InCombatLockdown) } }
	-- the hidden request button was made once at PLAYER_LOGIN (secure frames are made at login only); never touched here
	secure[#secure + 1] = { "SecureActionButtonTemplate", testSecure ~= nil }
	group("Request buttons", secure)
	-- the automatic help (only whether the calls exist: none is made here)
	add("Accept the driver's invite for you", has(AcceptGroup) and not W.IsBlocked("accept"),
		{ has(AcceptGroup) and "the game refused it on this version (you click Accept invite instead)" or "AcceptGroup" })
	add("Leave the group after the ride", ((type(C_PartyInfo) == "table" and has(C_PartyInfo.LeaveParty)) or has(LeaveParty))
		and not W.IsBlocked("leave"),
		{ ((type(C_PartyInfo) == "table" and has(C_PartyInfo.LeaveParty)) or has(LeaveParty))
			and "the game refused it on this version" or "LeaveParty" })
	add("Crowns over heads (nameplates)", type(C_NamePlate) == "table" and has(C_NamePlate.GetNamePlateForUnit),
		{ "C_NamePlate.GetNamePlateForUnit" })
	return out
end

-- /wuber test: one line, or the names of what failed.
local function selfTest()
	local list = W.SelfTest()
	local failed = {}
	for _, c in ipairs(list) do
		if not c.ok then failed[#failed + 1] = c.name .. (c.detail and (" (" .. c.detail .. ")") or "") end
	end
	if #failed == 0 then
		say("All " .. #list .. " checks passed.")
	else
		say(#failed .. " of " .. #list .. " checks failed: " .. table.concat(failed, "; "))
	end
end

---------------------------------------------------------------------------

local function run(msg)
	msg = (str(msg) or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	rest = rest or ""
	if cmd == "" then
		toggleWindow()
	elseif cmd == "drive" then
		driveCommand(rest)
	elseif cmd == "price" then
		price(rest)
	elseif cmd == "ping" then
		ping()
	elseif cmd == "map" then
		toggleSetting("mapPins", "Drivers on the world map")
	elseif cmd == "minimap" then
		toggleSetting("minimapHidden", "Minimap button", true)
	elseif cmd == "status" then
		status()
	elseif cmd == "test" then
		selfTest()
	elseif cmd == "tips" then
		tips(rest)
	elseif cmd == "why" then
		why()
	elseif cmd == "advanced" then
		W.SetAdvanced(not W.Advanced())
		say("Advanced mode: " .. (W.Advanced() and "on" or "off") .. ".")
	elseif cmd == "updates" then
		updates(rest)
	elseif cmd == "bug" then
		bug()
	elseif cmd == "emblem" and type(W.Emblem) == "table" then
		W.Safe("emblem", W.Emblem.Command, rest)
	else
		help() -- "help", "settings", "options" or anything else: the Settings screen
	end
end
W.SlashCommand = run

-- A /reload after an update that added files half-loads Wuber (new files need a game
-- restart): one toast says so.
local DRIVE_PARTS = {
	{ "Drive_Core", "InitDB" }, { "Drive_Places", "PublicWant" }, { "Drive_Team", "Send" }, { "Drive_Queue", "Request" },
	{ "Drive_Chat", "Text" }, { "Drive_Trade", "PumpTrade" }, { "Drive_Service", "IsOpen" }, { "Drive_Log", "LogTick" },
	{ "Drive_Button", "BuildButton" }, { "Drive_Net", "NetBeacon" }, { "Drive_Bell", "Ring" }, { "Drive_Commands", "Command" },
	{ "Drive_Ready", "Readiness" }, { "Drive_Raid", "RaidTick" }, { "Drive_Cast", "CastWatch" }, { "Drive_Danger", "DangerTick" },
	{ "Drive_Kitchen", "KitchenSend" }, { "Drive_Cut", "CutTick" }, { "Drive_Raincheck", "RaincheckTick" }, { "Drive_Book", "BookTick" },
}
-- Rider-side parts that load late: a table of that name under W.UI (UI.Bug, UI.Fold, UI.Share, UI.Bird, UI.Tips).
local UI_PARTS = { "Bug", "Fold", "Share" }
local MOD_PARTS = { { "UI.Bird", "Show" }, { "UI.Tips", "ShowNow" } } -- modules without a UI.* table: a function on the module
function W.MissingParts()
	local DR = W.Drive
	local out = {}
	for _, p in ipairs(DRIVE_PARTS) do
		if type(DR) ~= "table" or type(DR[p[2]]) ~= "function" then out[#out + 1] = p[1] end
	end
	if type(W.UI) ~= "table" or type(W.UI.ShowDrive) ~= "function" then out[#out + 1] = "UI_Drive" end
	for _, name in ipairs(UI_PARTS) do
		if type(W.UI) ~= "table" or type(W.UI[name]) ~= "table" then out[#out + 1] = "UI_" .. name end
	end
	if type(W.Words) ~= "table" then out[#out + 1] = "Core_Words" end -- Core/Words.lua (2.4.2): the spam check reads it
	for _, p in ipairs(MOD_PARTS) do
		local ok, mod = pcall(W.Mod, p[1])
		if not ok or type(mod) ~= "table" or type(mod[p[2]]) ~= "function" then out[#out + 1] = p[1]:gsub("%.", "_") end
	end
	return out
end

W.OnLogin(function()
	if not testSecure and not W.InCombat() then
		local ok, b = pcall(CreateFrame, "Button", nil, UIParent, "SecureActionButtonTemplate")
		if ok and b then
			testSecure = b
			-- same click rule as every secure button: fires on the way up, once
			pcall(b.RegisterForClicks, b, "LeftButtonUp")
			pcall(b.SetAttribute, b, "useOnKeyDown", false)
			pcall(b.Hide, b)
		end
	end
	local missing = W.MissingParts()
	if #missing == 0 then return end
	W.Debug("update", "not loaded: " .. table.concat(missing, ", "))
	local text = "Restart the game to finish updating Wuber."
	local ui = W.UI
	W.After(3, function()
		if type(ui) == "table" and type(ui.Toast) == "function" then
			ui.Toast(text, "info")
		else
			say(text)
		end
	end)
end)

-- (PST-01 B) with the game's Gamepad UI on no slash command is registered (the chat box closes itself inside the addon's code)
local noSlash = W.GamepadUI()
if not noSlash then
	SLASH_WUBER1 = "/wuber"
	SLASH_WUBER2 = "/ride"
end

-- The game's Key Bindings list (Wuber/Bindings.xml, which the game loads by itself): the heading and the two names.
-- Short names (the list shows about 22 letters). The big button's key there is a CLICK binding on the secure
-- WuberDriveButton, a real key press; the Set row in Settings (Drive/Button.lua, an override binding) is a second way
-- to the same button: the override wins when both use one key, so one press is one click, and neither clears the other.
BINDING_HEADER_WUBER = "Wuber"
BINDING_NAME_WUBER_TOGGLE = "Open or close Wuber"
if type(_G) == "table" then
	_G["BINDING_NAME_CLICK WuberDriveButton:LeftButton"] = "Key for the big button"
end
-- the handler stays with the Gamepad UI too: Bindings.xml's "Open or close Wuber" key calls it (no SLASH_ name: no chat command)
if type(SlashCmdList) == "table" then
	SlashCmdList["WUBER"] = function(msg) W.Safe("/wuber", run, msg) end
end