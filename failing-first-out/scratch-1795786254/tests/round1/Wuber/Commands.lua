-- Commands: /wuber (and /ride).
--
--   /wuber              open or close the Wuber window
--   /wuber drive        go online or offline as a driver (Warlocks)
--   /wuber price 50s    your driver price
--   /wuber ping         ask every driver to check in
--   /wuber map          drivers on the world map: on or off
--   /wuber minimap      the minimap button: on or off
--   /wuber status       network, drivers, your ride, version
--   /wuber test         check what this game client supports
--   /wuber help         this list

local _, W = ...

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

local function help()
	say("commands:")
	say("  " .. Y .. "/wuber" .. R .. " - open or close the window")
	say("  " .. Y .. "/wuber drive" .. R .. " - go online or offline as a driver")
	say("  " .. Y .. "/wuber price 50s" .. R .. " - set your driver price")
	say("  " .. Y .. "/wuber ping" .. R .. " - ask drivers to check in")
	say("  " .. Y .. "/wuber map" .. R .. " - drivers on the world map on or off")
	say("  " .. Y .. "/wuber minimap" .. R .. " - minimap button on or off")
	say("  " .. Y .. "/wuber status" .. R .. " - network, drivers and version")
	say("  " .. Y .. "/wuber test" .. R .. " - check what this game supports")
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
		if why == "class" then say("Only Warlocks can drive.") else say("You can't drive right now.") end
		return
	end
	if on and not W.DriverBeacon() then
		say("Driver mode isn't loaded, so riders can't see you yet.")
	elseif on then
		say("You're online as a driver at " .. W.Money(c.price) .. ".")
		if not W.OnNetwork() then say("You're not on the network yet, so riders can't see you.") end
	else
		say("You're offline.")
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
	c.price = copper
	W.Fire("SETTINGS", "price")
	W.SendBeacon()
	say("Your price is now " .. W.Money(copper) .. ".")
end

local function ping()
	local sent, why = W.Ping()
	if sent then
		say("Asked drivers to check in.")
	elseif why == "offline" then
		say("You're not on the Wuber network yet.")
	else
		say("Wait " .. tostring(why) .. " s before asking again.")
	end
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
	if idx then
		say("Network: joined (channel " .. idx .. ").")
	else
		say("Network: not joined. Requests still work by whisper.")
	end
	say("Drivers online: " .. count .. ".")
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

local testFrame, testTexture, testFont -- made once, reused

local function selfTest()
	local missing, passed = {}, 0
	local function check(label, ok)
		if ok then passed = passed + 1 else missing[#missing + 1] = label end
	end
	local function has(fn) return type(fn) == "function" end
	local function try(fn, ...)
		if type(fn) ~= "function" then return false end
		local ok, res = pcall(fn, ...)
		return ok, res
	end

	if not has(CreateFrame) then
		say("CreateFrame is missing: nothing can be drawn.")
		return
	end
	if not testFrame then
		local ok, f = pcall(CreateFrame, "Frame", nil, UIParent)
		if not ok or not f then
			say("CreateFrame failed: " .. tostring(f))
			return
		end
		testFrame = f
		testFrame:Hide()
		local okT, t = pcall(testFrame.CreateTexture, testFrame, nil, "ARTWORK")
		testTexture = okT and t or nil
		local okF, fs = pcall(testFrame.CreateFontString, testFrame, nil, "OVERLAY")
		testFont = okF and fs or nil
	end

	-- textures
	check("CreateTexture", testTexture ~= nil)
	if testTexture then
		local t = testTexture
		for _, name in ipairs(MEDIA) do
			local ok, res = try(t.SetTexture, t, "Interface\\AddOns\\Wuber\\Media\\" .. name)
			check("texture Media\\" .. name, ok and W.Plain(res) ~= false)
		end
		check("SetColorTexture", (try(t.SetColorTexture, t, 0, 0, 0, 1)))
		check("SetVertexColor", (try(t.SetVertexColor, t, 1, 1, 1, 1)))
		check("SetTexCoord", (try(t.SetTexCoord, t, 0, 1, 0, 1)))
		local grad = false
		if has(CreateColor) then
			grad = (try(t.SetGradient, t, "VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(1, 1, 1, 1)))
		end
		if not grad then grad = (try(t.SetGradientAlpha, t, "VERTICAL", 0, 0, 0, 1, 1, 1, 1, 1)) end
		check("SetGradient", grad)
	end

	-- fonts
	check("CreateFontString", testFont ~= nil)
	if testFont then
		for _, path in ipairs(fontList()) do
			local ok, res = try(testFont.SetFont, testFont, path, 14, "")
			check("font " .. (path:match("[^\\\\]+$") or path), ok and W.Plain(res) ~= false)
		end
		check("SetText", (try(testFont.SetText, testFont, "Wuber")))
	end

	-- animations
	local okAG, ag = try(testFrame.CreateAnimationGroup, testFrame)
	check("CreateAnimationGroup", okAG and ag ~= nil)
	if okAG and ag then
		check("SetLooping", (try(ag.SetLooping, ag, "REPEAT")))
		local kinds = {
			Alpha = { { "SetFromAlpha", 0 }, { "SetToAlpha", 1 } },
			Translation = { { "SetOffset", 0, 10 } },
			Scale = { { "SetScaleFrom", "SetFromScale", 1, 1 }, { "SetScaleTo", "SetToScale", 1.1, 1.1 } },
			Rotation = { { "SetDegrees", 90 } },
		}
		for _, kind in ipairs({ "Alpha", "Translation", "Scale", "Rotation" }) do
			local ok, a = try(ag.CreateAnimation, ag, kind)
			check("animation " .. kind, ok and a ~= nil)
			if ok and a then
				for _, m in ipairs(kinds[kind]) do
					if kind == "Scale" then
						local fn = a[m[1]] or a[m[2]]
						check(kind .. ":" .. m[1], (try(fn, a, m[3], m[4])))
					else
						check(kind .. ":" .. m[1], (try(a[m[1]], a, m[2], m[3])))
					end
				end
				check(kind .. ":SetDuration", (try(a.SetDuration, a, 0.2)))
				check(kind .. ":SetStartDelay", (try(a.SetStartDelay, a, 0)))
				check(kind .. ":SetSmoothing", (try(a.SetSmoothing, a, "OUT")))
				check(kind .. ":SetOrder", (try(a.SetOrder, a, 1)))
			end
		end
	end

	-- the map
	local CM = type(C_Map) == "table" and C_Map or {}
	local okM, mapID = try(CM.GetBestMapForUnit, "player")
	mapID = okM and num(mapID) or nil
	check("C_Map.GetBestMapForUnit", mapID ~= nil)
	if mapID then
		local okP, pos = try(CM.GetPlayerMapPosition, mapID, "player")
		check("C_Map.GetPlayerMapPosition", okP and W.Plain(pos) ~= nil)
		local okI, info = try(CM.GetMapInfo, mapID)
		check("C_Map.GetMapInfo", okI and type(W.Plain(info)) == "table")
		local okA, art = try(CM.GetMapArtLayerTextures, mapID, 1)
		check("C_Map.GetMapArtLayerTextures", okA and type(W.Plain(art)) == "table")
		local world = false
		if has(CreateVector2D) and has(CM.GetWorldPosFromMapPos) and has(CM.GetMapPosFromWorldPos) then
			local okW, cont, wpos = pcall(CM.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
			if okW and num(cont) and W.Plain(wpos) ~= nil then
				world = (pcall(CM.GetMapPosFromWorldPos, cont, wpos, mapID))
			end
		end
		check("C_Map world positions", world)
	end

	-- the network, groups, summons and the rest
	local CI = type(C_ChatInfo) == "table" and C_ChatInfo or {}
	check("C_ChatInfo.SendAddonMessage", has(CI.SendAddonMessage))
	check("C_ChatInfo.RegisterAddonMessagePrefix", has(CI.RegisterAddonMessagePrefix))
	check("JoinTemporaryChannel", has(JoinTemporaryChannel) or has(JoinChannelByName))
	check("GetChannelName", has(GetChannelName))
	check("ChatFrame_RemoveChannel", has(ChatFrame_RemoveChannel)
		or (type(ChatFrameUtil) == "table" and has(ChatFrameUtil.RemoveChannel)))
	check("ChatFrame_AddMessageEventFilter", has(ChatFrame_AddMessageEventFilter))
	check("InviteUnit", (type(C_PartyInfo) == "table" and has(C_PartyInfo.InviteUnit)) or has(InviteUnit))
	check("AcceptGroup", has(AcceptGroup))
	check("StaticPopup_FindVisible", has(StaticPopup_FindVisible))
	check("ConfirmSummon", (type(C_SummonInfo) == "table" and has(C_SummonInfo.ConfirmSummon)) or has(ConfirmSummon))
	check("GetMoney", has(GetMoney))
	check("UnitFactionGroup", W.Faction() ~= "")
	check("GetSubZoneText", has(GetSubZoneText))
	check("InCombatLockdown", has(InCombatLockdown))
	if not W.InCombat() then
		local ok, b = pcall(CreateFrame, "Button", nil, UIParent, "SecureActionButtonTemplate")
		check("SecureActionButtonTemplate", ok and b ~= nil)
		if ok and b then pcall(b.Hide, b) end
	end

	if #missing == 0 then
		say("All " .. passed .. " checks passed.")
	else
		say(passed .. " checks passed, " .. #missing .. " failed:")
		local line = {}
		for i, m in ipairs(missing) do
			line[#line + 1] = m
			if #line == 4 or i == #missing then
				say("  " .. table.concat(line, ", "))
				line = {}
			end
		end
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
		drive(rest:lower())
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
	else
		help()
	end
end
W.SlashCommand = run

SLASH_WUBER1 = "/wuber"
SLASH_WUBER2 = "/ride"
if type(SlashCmdList) == "table" then
	SlashCmdList["WUBER"] = function(msg) W.Safe("/wuber", run, msg) end
end
