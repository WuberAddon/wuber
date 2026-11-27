-- Conformance test for tests/fixtures/client/api/world.lua (Batch 4 Part 5, Lane e4).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local LEDGER_PATH = T.dir .. "/fixtures/client/api/world.lua"
local VALID_EVIDENCE = {
	["one-real-case"] = true,
	["docs"] = true,
	["borrowed"] = true,
	["guess"] = true,
}

test("b4 api world: ledger schema, honest evidence, and fake-game conformance", function()
	local rows = assert(dofile(LEDGER_PATH))
	ok(type(rows) == "table" and #rows == 87, "ledger has 87 rows")

	local seen = {}
	for i, row in ipairs(rows) do
		local tag = "row " .. i .. " (" .. tostring(row.name) .. ")"
		ok(type(row.name) == "string" and row.name ~= "", tag .. " has name")
		ok(not seen[row.name], tag .. " is not duplicated")
		seen[row.name] = true

		ok(type(row.calls) == "number" and row.calls >= 1, tag .. " has calls >= 1")
		ok(type(row.first) == "string" and row.first:find("^Wuber/.+:%d+$") ~= nil, tag .. " has valid first path:line")
		ok(type(row.fake) == "string" and row.fake ~= "", tag .. " has fake description")
		ok(VALID_EVIDENCE[row.evidence], tag .. " has valid evidence word (never measured): " .. tostring(row.evidence))
		ok(type(row.source) == "string" and row.source ~= "", tag .. " has source")

		if row.evidence == "one-real-case" then
			ok(type(row.build) == "string" and row.build ~= "", tag .. " one-real-case has build")
		else
			ok(row.build == nil, tag .. " non-one-real-case has build = nil")
			ok((type(row.game) == "string" and row.game ~= "") or (type(row.offline) == "string" and row.offline ~= ""),
				tag .. " guess/docs/borrowed has game or offline")
		end
	end

	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	local e = c.env

	-- 1. Widget / Object :Methods (10)
	local f = e.CreateFrame("Frame", nil, e.UIParent)
	local ag = f:CreateAnimationGroup()
	local fb = ag:CreateAnimation("FlipBook")

	eq(type(e.GameTooltip.AddLine), "function", ":AddLine exists on GameTooltip")
	eq(e.GameTooltip:AddLine("b4-world-test", 1, 1, 1), nil, ":AddLine returns nil")
	eq(type(e.GameTooltip.NumLines), "function", ":NumLines exists on GameTooltip")
	eq(type(e.GameTooltip:NumLines()), "number", ":NumLines returns number")

	eq(type(e.WorldMapFrame.GetMapID), "function", ":GetMapID exists on WorldMapFrame")
	eq(type(e.WorldMapFrame:GetMapID()), "number", ":GetMapID returns number")
	eq(type(e.WorldMapFrame.SetMapID), "function", ":SetMapID exists on WorldMapFrame")
	eq(e.WorldMapFrame:SetMapID(1454), nil, ":SetMapID returns nil")

	eq(type(e.WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition), "function",
		":GetNormalizedCursorPosition exists on ScrollContainer")
	local nx, ny = e.WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
	eq(type(nx), "number", ":GetNormalizedCursorPosition x is number")
	eq(type(ny), "number", ":GetNormalizedCursorPosition y is number")

	local vec = e.CreateVector2D(0.25, 0.75)
	eq(type(vec.GetXY), "function", ":GetXY exists on Vector2D")
	local vx, vy = vec:GetXY()
	eq(vx, 0.25, ":GetXY x matches")
	eq(vy, 0.75, ":GetXY y matches")

	eq(type(e.ChatFrameUtil.RemoveChannel), "function", ":RemoveChannel exists on ChatFrameUtil")
	eq(e.ChatFrameUtil.RemoveChannel(e.DEFAULT_CHAT_FRAME, "WuberNet"), nil, ":RemoveChannel returns nil")

	eq(type(fb.SetFlipBookFrameHeight), "function", ":SetFlipBookFrameHeight exists")
	eq(fb:SetFlipBookFrameHeight(64), nil, ":SetFlipBookFrameHeight returns nil")
	eq(type(fb.SetFlipBookFrameWidth), "function", ":SetFlipBookFrameWidth exists")
	eq(fb:SetFlipBookFrameWidth(64), nil, ":SetFlipBookFrameWidth returns nil")
	eq(type(f.SetMouseMotionEnabled), "function", ":SetMouseMotionEnabled exists")
	eq(f:SetMouseMotionEnabled(false), nil, ":SetMouseMotionEnabled returns nil")

	-- 2. C_* Namespace calls (35)
	eq(type(e.C_AddOns.DisableAddOn), "function", "C_AddOns.DisableAddOn exists")
	eq(e.C_AddOns.GetAddOnInfo, nil, "C_AddOns.GetAddOnInfo is nil (not modelled)")
	eq(e.C_AddOns.GetNumAddOns, nil, "C_AddOns.GetNumAddOns is nil (not modelled)")
	eq(type(e.C_AddOns.IsAddOnLoaded), "function", "C_AddOns.IsAddOnLoaded exists")
	local loaded, finished = e.C_AddOns.IsAddOnLoaded("Wuber")
	eq(loaded, true, "C_AddOns.IsAddOnLoaded Wuber loaded")
	eq(finished, true, "C_AddOns.IsAddOnLoaded Wuber finished")

	eq(type(e.C_CVar.GetCVar), "function", "C_CVar.GetCVar exists")
	eq(e.C_CVar.GetCVar("taintLog"), "1", "C_CVar.GetCVar taintLog returns '1'")
	eq(type(e.C_CVar.GetCVarBool), "function", "C_CVar.GetCVarBool exists")
	eq(e.C_CVar.GetCVarBool("Sound_EnableSFX"), true, "C_CVar.GetCVarBool Sound_EnableSFX returns true")
	eq(type(e.C_CVar.SetCVar), "function", "C_CVar.SetCVar exists")
	eq(type(e.C_CVar.SetCVar("b4test", "1")), "boolean", "C_CVar.SetCVar returns boolean")

	eq(type(e.C_IncomingSummon.IncomingSummonStatus), "function", "C_IncomingSummon.IncomingSummonStatus exists")
	eq(e.C_IncomingSummon.IncomingSummonStatus("player"), 0, "C_IncomingSummon.IncomingSummonStatus returns 0")

	eq(type(e.C_InputInterfaceStyle.GetCurrentStyle), "function", "C_InputInterfaceStyle.GetCurrentStyle exists")
	eq(e.C_InputInterfaceStyle.GetCurrentStyle(), 0, "C_InputInterfaceStyle.GetCurrentStyle returns 0")

	eq(type(e.C_Item.GetItemCount), "function", "C_Item.GetItemCount exists")
	eq(type(e.C_Item.GetItemCount(6265)), "number", "C_Item.GetItemCount returns number")

	eq(type(e.C_LFGList.HasActiveEntryInfo), "function", "C_LFGList.HasActiveEntryInfo exists")
	eq(e.C_LFGList.HasActiveEntryInfo(), false, "C_LFGList.HasActiveEntryInfo returns false")
	eq(type(e.C_LFGList.GetActiveEntryInfo), "function", "C_LFGList.GetActiveEntryInfo exists")
	eq(e.C_LFGList.GetActiveEntryInfo(), nil, "C_LFGList.GetActiveEntryInfo returns nil when unlisted")
	eq(type(e.C_LFGList.GetActivityInfoTable), "function", "C_LFGList.GetActivityInfoTable exists")
	eq(e.C_LFGList.GetActivityInfoTable(1), nil, "C_LFGList.GetActivityInfoTable(1) returns nil")
	eq(type(e.C_LFGList.GetAvailableActivities), "function", "C_LFGList.GetAvailableActivities exists")
	eq(type(e.C_LFGList.GetAvailableActivities()), "table", "C_LFGList.GetAvailableActivities returns table")
	eq(type(e.C_LFGList.GetSearchResults), "function", "C_LFGList.GetSearchResults exists")
	local resCount, resList = e.C_LFGList.GetSearchResults()
	eq(type(resCount) == "table" or type(resList) == "table", true, "C_LFGList.GetSearchResults returns table")
	eq(type(e.C_LFGList.GetSearchResultInfo), "function", "C_LFGList.GetSearchResultInfo exists")
	eq(e.C_LFGList.GetSearchResultInfo(1), nil, "C_LFGList.GetSearchResultInfo(1) returns nil")
	eq(type(e.C_LFGList.GetSearchResultPlayerInfo), "function", "C_LFGList.GetSearchResultPlayerInfo exists")
	eq(e.C_LFGList.GetSearchResultPlayerInfo(1, 1), nil, "C_LFGList.GetSearchResultPlayerInfo(1, 1) returns nil")
	eq(type(e.C_LFGList.RemoveListing), "function", "C_LFGList.RemoveListing exists")
	eq(type(e.C_LFGList.Search), "function", "C_LFGList.Search exists")

	eq(type(e.C_Map.GetBestMapForUnit), "function", "C_Map.GetBestMapForUnit exists")
	local mapID = e.C_Map.GetBestMapForUnit("player")
	eq(type(mapID), "number", "C_Map.GetBestMapForUnit returns number")
	eq(type(e.C_Map.GetMapInfo), "function", "C_Map.GetMapInfo exists")
	eq(type(e.C_Map.GetMapInfo(mapID)), "table", "C_Map.GetMapInfo returns table")
	eq(type(e.C_Map.GetMapArtLayers), "function", "C_Map.GetMapArtLayers exists")
	eq(type(e.C_Map.GetMapArtLayers(mapID)), "table", "C_Map.GetMapArtLayers returns table")
	eq(type(e.C_Map.GetMapArtLayerTextures), "function", "C_Map.GetMapArtLayerTextures exists")
	eq(type(e.C_Map.GetMapArtLayerTextures(mapID, 1)), "table", "C_Map.GetMapArtLayerTextures returns table")
	eq(type(e.C_Map.GetMapChildrenInfo), "function", "C_Map.GetMapChildrenInfo exists")
	eq(type(e.C_Map.GetMapChildrenInfo(1414)), "table", "C_Map.GetMapChildrenInfo returns table")
	eq(type(e.C_Map.GetMapInfoAtPosition), "function", "C_Map.GetMapInfoAtPosition exists")
	eq(e.C_Map.GetMapInfoAtPosition(mapID, 0.5, 0.5), nil, "C_Map.GetMapInfoAtPosition returns nil by default")
	eq(type(e.C_Map.GetPlayerMapPosition), "function", "C_Map.GetPlayerMapPosition exists")
	eq(type(e.C_Map.GetPlayerMapPosition(mapID, "player")), "table", "C_Map.GetPlayerMapPosition returns Vector2D")
	eq(type(e.C_Map.GetWorldPosFromMapPos), "function", "C_Map.GetWorldPosFromMapPos exists")
	local instID, wpos = e.C_Map.GetWorldPosFromMapPos(mapID, vec)
	eq(type(instID), "number", "C_Map.GetWorldPosFromMapPos returns instanceID")
	eq(type(wpos), "table", "C_Map.GetWorldPosFromMapPos returns Vector2D")
	eq(type(e.C_Map.GetMapPosFromWorldPos), "function", "C_Map.GetMapPosFromWorldPos exists")
	local m2, mpos = e.C_Map.GetMapPosFromWorldPos(0, { x = 0, y = 0 })
	eq(type(m2), "number", "C_Map.GetMapPosFromWorldPos returns mapID")
	eq(type(mpos), "table", "C_Map.GetMapPosFromWorldPos returns Vector2D")
	eq(type(e.C_Map.OpenWorldMap), "function", "C_Map.OpenWorldMap exists")

	eq(type(e.C_SummonInfo.ConfirmSummon), "function", "C_SummonInfo.ConfirmSummon exists")
	eq(type(e.C_SummonInfo.GetSummonConfirmSummoner), "function", "C_SummonInfo.GetSummonConfirmSummoner exists")
	eq(e.C_SummonInfo.GetSummonConfirmSummoner(), nil, "C_SummonInfo.GetSummonConfirmSummoner returns nil when no summon")

	eq(type(e.C_TaxiMap.GetAllTaxiNodes), "function", "C_TaxiMap.GetAllTaxiNodes exists")
	eq(type(e.C_TaxiMap.GetAllTaxiNodes(1414)), "table", "C_TaxiMap.GetAllTaxiNodes returns table")
	eq(e.C_TaxiMap.GetTaxiNodesForMap, nil, "C_TaxiMap.GetTaxiNodesForMap is nil (not modelled)")

	eq(type(e.C_Timer.After), "function", "C_Timer.After exists")
	eq(e.C_Timer.After(0.1, function() end), nil, "C_Timer.After returns nil")
	eq(type(e.C_Timer.NewTicker), "function", "C_Timer.NewTicker exists")
	local ticker = e.C_Timer.NewTicker(0.1, function() end)
	eq(type(ticker), "table", "C_Timer.NewTicker returns handle table")
	ticker:Cancel()

	-- 3. Globals (42)
	eq(type(e.CreateVector2D), "function", "CreateVector2D exists")
	eq(type(e.FlashClientIcon), "function", "FlashClientIcon exists")
	eq(e.FlashClientIcon(), nil, "FlashClientIcon returns nil")

	eq(type(e.GetBuildInfo), "function", "GetBuildInfo exists")
	local bVer, bNum, _, bIface = e.GetBuildInfo()
	eq(type(bVer), "string", "GetBuildInfo version is string")
	eq(type(bNum), "string", "GetBuildInfo build is string")
	eq(type(bIface), "number", "GetBuildInfo interface is number")

	eq(type(e.GetCVar), "function", "GetCVar exists")
	eq(e.GetCVar("taintLog"), "1", "GetCVar taintLog returns '1'")
	eq(type(e.GetCVarBool), "function", "GetCVarBool exists")
	eq(e.GetCVarBool("Sound_EnableSFX"), true, "GetCVarBool Sound_EnableSFX returns true")
	eq(type(e.SetCVar), "function", "SetCVar exists")
	eq(type(e.SetCVar("b4test", "1")), "boolean", "SetCVar returns boolean")

	eq(type(e.GetGameTime), "function", "GetGameTime exists")
	local gh, gm = e.GetGameTime()
	eq(type(gh), "number", "GetGameTime hour is number")
	eq(type(gm), "number", "GetGameTime minute is number")

	eq(type(e.GetGuildInfo), "function", "GetGuildInfo exists")
	eq(e.GetGuildInfo("player"), nil, "GetGuildInfo returns nil when not in guild")
	eq(type(e.IsInGuild), "function", "IsInGuild exists")
	eq(e.IsInGuild(), false, "IsInGuild returns false")

	eq(type(e.GetInboxNumItems), "function", "GetInboxNumItems exists")
	local inb, inbTot = e.GetInboxNumItems()
	eq(inb, 0, "GetInboxNumItems returns 0")
	eq(inbTot, 0, "GetInboxNumItems total returns 0")
	eq(type(e.GetInboxHeaderInfo), "function", "GetInboxHeaderInfo exists")
	eq(e.GetInboxHeaderInfo(1), nil, "GetInboxHeaderInfo(1) returns nil when empty")

	eq(type(e.GetMoney), "function", "GetMoney exists")
	eq(type(e.GetMoney()), "number", "GetMoney returns number")
	eq(type(e.GetPlayerTradeMoney), "function", "GetPlayerTradeMoney exists")
	eq(e.GetPlayerTradeMoney(), 0, "GetPlayerTradeMoney returns 0")
	eq(type(e.GetTargetTradeMoney), "function", "GetTargetTradeMoney exists")
	eq(e.GetTargetTradeMoney(), 0, "GetTargetTradeMoney returns 0")
	eq(type(e.GetTradePlayerItemInfo), "function", "GetTradePlayerItemInfo exists")
	eq(e.GetTradePlayerItemInfo(1), nil, "GetTradePlayerItemInfo(1) returns nil")
	eq(type(e.InitiateTrade), "function", "InitiateTrade exists")

	eq(type(e.GetRealZoneText), "function", "GetRealZoneText exists")
	eq(e.GetRealZoneText(), "Orgrimmar", "GetRealZoneText returns Orgrimmar")
	eq(type(e.GetSubZoneText), "function", "GetSubZoneText exists")
	eq(type(e.GetSubZoneText()), "string", "GetSubZoneText returns string")
	eq(type(e.GetZoneText), "function", "GetZoneText exists")
	eq(e.GetZoneText(), "Orgrimmar", "GetZoneText returns Orgrimmar")

	eq(type(e.GetServerTime), "function", "GetServerTime exists")
	eq(type(e.GetServerTime()), "number", "GetServerTime returns number")
	eq(type(e.GetTime), "function", "GetTime exists")
	eq(type(e.GetTime()), "number", "GetTime returns number")

	eq(e.InCinematic, nil, "InCinematic is nil (not modelled)")
	eq(e.IsInCinematicScene, nil, "IsInCinematicScene is nil (not modelled)")

	eq(type(e.IsInInstance), "function", "IsInInstance exists")
	local inInst, instType = e.IsInInstance()
	eq(inInst, false, "IsInInstance returns false")
	eq(instType, "none", "IsInInstance type returns 'none'")

	eq(type(e.IsMounted), "function", "IsMounted exists")
	eq(e.IsMounted(), false, "IsMounted returns false")

	eq(e.GetTaxiMapID, nil, "GetTaxiMapID is nil (not modelled)")
	eq(e.NumTaxiNodes, nil, "NumTaxiNodes is nil before first TAXIMAP_OPENED")
	eq(e.TaxiNodeCost, nil, "TaxiNodeCost is nil before first TAXIMAP_OPENED")
	eq(e.TaxiNodeGetType, nil, "TaxiNodeGetType is nil before first TAXIMAP_OPENED")
	eq(e.TaxiNodeName, nil, "TaxiNodeName is nil before first TAXIMAP_OPENED")
	eq(type(e.TakeTaxiNode), "function", "TakeTaxiNode exists")
	eq(type(e.TaxiNodePosition), "function", "TaxiNodePosition exists")
	local tx, ty = e.TaxiNodePosition(1)
	eq(tx, 0, "TaxiNodePosition missing node x is 0")
	eq(ty, 0, "TaxiNodePosition missing node y is 0")

	eq(type(e.PlaySound), "function", "PlaySound exists")
	local willPlay, soundHandle = e.PlaySound(1)
	eq(willPlay, true, "PlaySound willPlay is true")
	eq(type(soundHandle), "number", "PlaySound handle is number")

	eq(type(e.UnitIsGroupAssistant), "function", "UnitIsGroupAssistant exists")
	eq(e.UnitIsGroupAssistant("player"), false, "UnitIsGroupAssistant returns false")
	eq(type(e.UnitIsRaidOfficer), "function", "UnitIsRaidOfficer exists")
	eq(e.UnitIsRaidOfficer("player"), false, "UnitIsRaidOfficer returns false")

	eq(type(e.canaccessvalue), "function", "canaccessvalue exists")
	eq(e.canaccessvalue("x"), true, "canaccessvalue returns true for plain value")
	eq(type(e.date), "function", "date exists")
	eq(type(e.date("%Y-%m-%d")), "string", "date returns formatted string")
	eq(e.debugstack, nil, "debugstack is nil (not modelled)")
	eq(type(e.geterrorhandler), "function", "geterrorhandler exists")
	eq(type(e.geterrorhandler()), "function", "geterrorhandler returns function")
	eq(type(e.hooksecurefunc), "function", "hooksecurefunc exists")
	eq(type(e.issecretvalue), "function", "issecretvalue exists")
	eq(e.issecretvalue("x"), false, "issecretvalue returns false for plain value")
	eq(type(e.time), "function", "time exists")
	eq(type(e.time()), "number", "time returns number")

	T.clean(w)
end)
