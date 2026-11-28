-- Wuber Lab (developer only, never ship): ApiFacts3.lua - read-only in-game checks for the
-- `evidence = "guess"` rows in tests/fixtures/client/api/units.lua (15) and world.lua (38).
--
-- Every check here:
--   - ONLY READS (never invites, leaves party, promotes, removes channels/listings, sets CVars, mutates tooltips, or takes taxi nodes).
--   - Runs every game call under pcall with type checks and L.IsSecret checks.
--   - Never runs in combat (InCombatLockdown() guard).
--   - Creates no frame, event, or timer at load time.

local _, L = ...

local G = L.GameFacts
if type(G) ~= "table" or type(G.Put) ~= "function" or type(G.ask) ~= "function" then return end

local secret = L.IsSecret or function() return false end
local ask = G.ask

local function gfn(name) return rawget(_G, name) end
local function tfn(tname, name)
	local t = rawget(_G, tname)
	return type(t) == "table" and t[name] or nil
end

local function shape(v)
	if secret(v) then return "secret" end
	local t = type(v)
	if t == "nil" then return "nil" end
	if t == "boolean" or t == "number" then return t .. ":" .. tostring(v) end
	if t == "string" then return ("string(len=%d)"):format(#v) end
	return t
end

local function firstShape(fn, ...)
	local r, err = ask(fn, ...)
	if not r then return err end
	return shape(r[1])
end

local function pairShape(fn, ...)
	local r, err = ask(fn, ...)
	if not r then return err end
	return shape(r[1]) .. "," .. shape(r[2])
end

local function fnPresence(name, fn, readOnlyNote)
	local kind = type(fn)
	local suffix = readOnlyNote and (" (" .. readOnlyNote .. ")") or ""
	return ("%s: %s%s"):format(name, kind, suffix), { present = kind == "function", kind = kind, readOnly = not readOnlyNote }
end

local function methodCheck(obj, mname, label, callReadOnly, ...)
	if type(obj) ~= "table" and type(obj) ~= "userdata" then
		return ("%s:%s no-widget"):format(label, mname), { present = false }
	end
	local m = obj[mname]
	local has = type(m) == "function"
	if not has then
		return ("%s:%s missing"):format(label, mname), { present = false }
	end
	if not callReadOnly then
		return ("%s:%s present (not checkable read-only)"):format(label, mname), { present = true, readOnly = false }
	end
	local r, err = ask(m, obj, ...)
	local val = r and shape(r[1]) or err
	return ("%s:%s=%s"):format(label, mname, val), { present = true, value = val, readOnly = true }
end

local function inCombat()
	local r = ask(gfn("InCombatLockdown"))
	return r and r[1] == true
end

local CHECKS = {
	-- units.lua (15 guess rows)
	{
		id = "apifacts3.units.c_spell_get_spell_info",
		name = "C_Spell.GetSpellInfo",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_Spell", "GetSpellInfo"), 688)
			return "C_Spell.GetSpellInfo=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.c_spell_get_spell_name",
		name = "C_Spell.GetSpellName",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_Spell", "GetSpellName"), 688)
			return "C_Spell.GetSpellName=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.get_normalized_realm_name",
		name = "GetNormalizedRealmName",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetNormalizedRealmName"))
			return "GetNormalizedRealmName=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.get_num_group_members",
		name = "GetNumGroupMembers",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetNumGroupMembers"))
			return "GetNumGroupMembers=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.get_num_subgroup_members",
		name = "GetNumSubgroupMembers",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetNumSubgroupMembers"))
			return "GetNumSubgroupMembers=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.get_raid_roster_info",
		name = "GetRaidRosterInfo",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetRaidRosterInfo"), 1)
			return "GetRaidRosterInfo=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.get_spell_cooldown",
		name = "GetSpellCooldown",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = pairShape(gfn("GetSpellCooldown"), 688)
			return "GetSpellCooldown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.in_combat_lockdown",
		name = "InCombatLockdown",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("InCombatLockdown"))
			return "InCombatLockdown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.invite_unit",
		name = "InviteUnit",
		source = "units.lua",
		readOnly = false,
		run = function()
			return fnPresence("InviteUnit", gfn("InviteUnit"), "not checkable read-only: sends group invite")
		end,
	},
	{
		id = "apifacts3.units.is_in_group",
		name = "IsInGroup",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsInGroup"))
			return "IsInGroup=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.is_in_raid",
		name = "IsInRaid",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsInRaid"))
			return "IsInRaid=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.is_player_spell",
		name = "IsPlayerSpell",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsPlayerSpell"), 688)
			return "IsPlayerSpell=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.is_spell_known",
		name = "IsSpellKnown",
		source = "units.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsSpellKnown"), 688)
			return "IsSpellKnown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.units.leave_party",
		name = "LeaveParty",
		source = "units.lua",
		readOnly = false,
		run = function()
			return fnPresence("LeaveParty", gfn("LeaveParty"), "not checkable read-only: leaves party or raid")
		end,
	},
	{
		id = "apifacts3.units.promote_to_leader",
		name = "PromoteToLeader",
		source = "units.lua",
		readOnly = false,
		run = function()
			return fnPresence("PromoteToLeader", gfn("PromoteToLeader"), "not checkable read-only: promotes group member")
		end,
	},

	-- world.lua (38 guess rows)
	{
		id = "apifacts3.world.add_line",
		name = ":AddLine",
		source = "world.lua",
		readOnly = false,
		run = function()
			return methodCheck(rawget(_G, "GameTooltip"), "AddLine", "GameTooltip", false)
		end,
	},
	{
		id = "apifacts3.world.get_map_id",
		name = ":GetMapID",
		source = "world.lua",
		readOnly = true,
		run = function()
			return methodCheck(rawget(_G, "WorldMapFrame"), "GetMapID", "WorldMapFrame", true)
		end,
	},
	{
		id = "apifacts3.world.get_normalized_cursor_position",
		name = ":GetNormalizedCursorPosition",
		source = "world.lua",
		readOnly = true,
		run = function()
			local wmf = rawget(_G, "WorldMapFrame")
			local sc = type(wmf) == "table" and wmf.ScrollContainer or nil
			return methodCheck(sc, "GetNormalizedCursorPosition", "WorldMapScrollContainer", true)
		end,
	},
	{
		id = "apifacts3.world.get_xy",
		name = ":GetXY",
		source = "world.lua",
		readOnly = true,
		run = function()
			local cv = gfn("CreateVector2D")
			local r = type(cv) == "function" and ask(cv, 0.25, 0.75) or nil
			local v = r and r[1] or nil
			return methodCheck(v, "GetXY", "Vector2D", true)
		end,
	},
	{
		id = "apifacts3.world.num_lines",
		name = ":NumLines",
		source = "world.lua",
		readOnly = true,
		run = function()
			return methodCheck(rawget(_G, "GameTooltip"), "NumLines", "GameTooltip", true)
		end,
	},
	{
		id = "apifacts3.world.remove_channel",
		name = ":RemoveChannel",
		source = "world.lua",
		readOnly = false,
		run = function()
			return methodCheck(rawget(_G, "DEFAULT_CHAT_FRAME"), "RemoveChannel", "ChatFrame", false)
		end,
	},
	{
		id = "apifacts3.world.c_addons_get_num_addons",
		name = "C_AddOns.GetNumAddOns",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_AddOns", "GetNumAddOns"))
			return "C_AddOns.GetNumAddOns=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.c_input_interface_style_get_current_style",
		name = "C_InputInterfaceStyle.GetCurrentStyle",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_InputInterfaceStyle", "GetCurrentStyle"))
			return "C_InputInterfaceStyle.GetCurrentStyle=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.c_lfglist_get_available_activities",
		name = "C_LFGList.GetAvailableActivities",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_LFGList", "GetAvailableActivities"))
			return "C_LFGList.GetAvailableActivities=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.c_lfglist_get_search_results",
		name = "C_LFGList.GetSearchResults",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = pairShape(tfn("C_LFGList", "GetSearchResults"))
			return "C_LFGList.GetSearchResults=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.c_lfglist_has_active_entry_info",
		name = "C_LFGList.HasActiveEntryInfo",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_LFGList", "HasActiveEntryInfo"))
			return "C_LFGList.HasActiveEntryInfo=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.c_lfglist_remove_listing",
		name = "C_LFGList.RemoveListing",
		source = "world.lua",
		readOnly = false,
		run = function()
			return fnPresence("C_LFGList.RemoveListing", tfn("C_LFGList", "RemoveListing"), "not checkable read-only: removes active LFG listing")
		end,
	},
	{
		id = "apifacts3.world.create_vector_2d",
		name = "CreateVector2D",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("CreateVector2D"), 0.25, 0.75)
			return "CreateVector2D=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_cvar_bool",
		name = "GetCVarBool",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetCVarBool"), "Sound_EnableSFX")
			return "GetCVarBool=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_game_time",
		name = "GetGameTime",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = pairShape(gfn("GetGameTime"))
			return "GetGameTime=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_guild_info",
		name = "GetGuildInfo",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetGuildInfo"), "player")
			return "GetGuildInfo=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_inbox_header_info",
		name = "GetInboxHeaderInfo",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetInboxHeaderInfo"), 1)
			return "GetInboxHeaderInfo=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_inbox_num_items",
		name = "GetInboxNumItems",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = pairShape(gfn("GetInboxNumItems"))
			return "GetInboxNumItems=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_money",
		name = "GetMoney",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetMoney"))
			return "GetMoney=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_player_trade_money",
		name = "GetPlayerTradeMoney",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetPlayerTradeMoney"))
			return "GetPlayerTradeMoney=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_server_time",
		name = "GetServerTime",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetServerTime"))
			return "GetServerTime=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_sub_zone_text",
		name = "GetSubZoneText",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetSubZoneText"))
			return "GetSubZoneText=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_target_trade_money",
		name = "GetTargetTradeMoney",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetTargetTradeMoney"))
			return "GetTargetTradeMoney=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_taxi_map_id",
		name = "GetTaxiMapID",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetTaxiMapID"))
			return "GetTaxiMapID=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_time",
		name = "GetTime",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetTime"))
			return "GetTime=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_trade_player_item_info",
		name = "GetTradePlayerItemInfo",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetTradePlayerItemInfo"), 1)
			return "GetTradePlayerItemInfo=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.get_zone_text",
		name = "GetZoneText",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("GetZoneText"))
			return "GetZoneText=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.in_cinematic",
		name = "InCinematic",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("InCinematic"))
			return "InCinematic=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.is_in_cinematic_scene",
		name = "IsInCinematicScene",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsInCinematicScene"))
			return "IsInCinematicScene=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.is_in_guild",
		name = "IsInGuild",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsInGuild"))
			return "IsInGuild=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.is_in_instance",
		name = "IsInInstance",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = pairShape(gfn("IsInInstance"))
			return "IsInInstance=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.is_mounted",
		name = "IsMounted",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsMounted"))
			return "IsMounted=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.set_cvar",
		name = "SetCVar",
		source = "world.lua",
		readOnly = false,
		run = function()
			return fnPresence("SetCVar", gfn("SetCVar"), "not checkable read-only: modifies client CVar")
		end,
	},
	{
		id = "apifacts3.world.take_taxi_node",
		name = "TakeTaxiNode",
		source = "world.lua",
		readOnly = false,
		run = function()
			return fnPresence("TakeTaxiNode", gfn("TakeTaxiNode"), "not checkable read-only: starts taxi flight")
		end,
	},
	{
		id = "apifacts3.world.date",
		name = "date",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("date"), "%Y-%m-%d")
			return "date=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.debugstack",
		name = "debugstack",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("debugstack"), 1, 1, 0)
			return "debugstack=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.geterrorhandler",
		name = "geterrorhandler",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("geterrorhandler"))
			return "geterrorhandler=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts3.world.time",
		name = "time",
		source = "world.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("time"))
			return "time=" .. s, { value = s }
		end,
	},
}

G.API_CHECKS3 = CHECKS

function G.RunApiFacts3()
	if inCombat() then return false, "in combat" end
	for _, c in ipairs(CHECKS) do
		local okRun, line, answers = pcall(c.run)
		if okRun then
			G.Put(c.id, line or "ok", answers, true, true)
		else
			G.Put(c.id, "error: " .. tostring(line), { err = tostring(line) }, true, true)
		end
	end
	if L.Log then L.Log("facts", ("api3: %d checks recorded"):format(#CHECKS)) end
	return true, #CHECKS
end
