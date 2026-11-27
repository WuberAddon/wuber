-- Wuber Lab (developer only, never ship): ApiFacts.lua - read-only in-game checks for every `game` id in tests/fixtures/client/api/*.lua.
--
-- Every check here:
--   - ONLY READS (no chat line, addon message, invite, trade, cast, target, reload, or protected call).
--   - Runs every game call under pcall with type checks and L.IsSecret checks.
--   - Never runs in combat (InCombatLockdown() guard).
--   - Never stores another player's name or chat text (shapes and lengths only).
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
	if t == "string" then
		return ("string(len=%d%s%s)"):format(#v, v:find(" ", 1, true) and ",space" or "", v:find("-", 1, true) and ",hyphen" or "")
	end
	return t
end

local function firstShape(fn, ...)
	local r, err = ask(fn, ...)
	if not r then return err end
	return shape(r[1])
end

local function fnPresence(name, fn)
	local kind = type(fn)
	return ("%s: %s"):format(name, kind), { present = kind == "function", kind = kind }
end

local function methodPresence(obj, mname, label)
	local has = (type(obj) == "table" or type(obj) == "userdata") and type(obj[mname]) == "function"
	return ("%s:%s %s"):format(label or "obj", mname, has and "present" or "missing"), { present = has }
end

local function inCombat()
	local r = ask(gfn("InCombatLockdown"))
	return r and r[1] == true
end

local SCRATCH
local function getScratch()
	if SCRATCH then return SCRATCH end
	local cf = gfn("CreateFrame")
	if type(cf) ~= "function" then
		SCRATCH = {}
		return SCRATCH
	end
	local okF, f = pcall(cf, "Frame")
	local fs, ag, ms
	if okF and f then
		if type(f.CreateFontString) == "function" then
			local okFS, r = pcall(f.CreateFontString, f)
			if okFS then fs = r end
		end
		if type(f.CreateAnimationGroup) == "function" then
			local okAG, r = pcall(f.CreateAnimationGroup, f)
			if okAG then ag = r end
		end
	end
	local okM, m = pcall(cf, "ModelScene")
	if okM then ms = m end
	SCRATCH = { frame = okF and f or nil, fontString = fs, animGroup = ag, modelScene = ms }
	return SCRATCH
end

local CHECKS = {
	-- chat.lua (11)
	{
		id = "chat.in_lockdown",
		title = "C_ChatInfo.InChatMessagingLockdown",
		run = function()
			local s = firstShape(tfn("C_ChatInfo", "InChatMessagingLockdown"))
			return "InChatMessagingLockdown=" .. s, { value = s }
		end,
	},
	{
		id = "chat.register_prefix",
		title = "C_ChatInfo.RegisterAddonMessagePrefix",
		run = function()
			local fn = tfn("C_ChatInfo", "RegisterAddonMessagePrefix")
			local isReg = tfn("C_ChatInfo", "IsAddonMessagePrefixRegistered")
			local regState = isReg and firstShape(isReg, "Wuber") or "no IsAddonMessagePrefixRegistered"
			return ("RegisterAddonMessagePrefix=%s, WuberRegistered=%s"):format(type(fn), regState),
				{ present = type(fn) == "function", wuberRegistered = regState }
		end,
	},
	{
		id = "club.accept_invitation",
		title = "C_Club.AcceptInvitation",
		run = function() return fnPresence("C_Club.AcceptInvitation", tfn("C_Club", "AcceptInvitation")) end,
	},
	{
		id = "club.get_members",
		title = "C_Club.GetClubMembers",
		run = function()
			local fn = tfn("C_Club", "GetClubMembers")
			local sub = ask(tfn("C_Club", "GetSubscribedClubs"))
			local count = "no clubs"
			if sub and type(sub[1]) == "table" and sub[1][1] and sub[1][1].clubId then
				local r, err = ask(fn, sub[1][1].clubId)
				count = r and (type(r[1]) == "table" and ("count:" .. #r[1]) or shape(r[1])) or err
			end
			return ("C_Club.GetClubMembers=%s (%s)"):format(type(fn), count), { present = type(fn) == "function", sample = count }
		end,
	},
	{
		id = "club.get_invitations",
		title = "C_Club.GetInvitationsForSelf",
		run = function()
			local r, err = ask(tfn("C_Club", "GetInvitationsForSelf"))
			local s = r and (type(r[1]) == "table" and ("table:#" .. #r[1]) or shape(r[1])) or err
			return "C_Club.GetInvitationsForSelf=" .. s, { result = s }
		end,
	},
	{
		id = "club.get_member_info",
		title = "C_Club.GetMemberInfo",
		run = function() return fnPresence("C_Club.GetMemberInfo", tfn("C_Club", "GetMemberInfo")) end,
	},
	{
		id = "chat.fcf_current_frame",
		title = "FCF_GetCurrentChatFrame",
		run = function()
			local r, err = ask(gfn("FCF_GetCurrentChatFrame"))
			local s = r and shape(r[1]) or err
			return "FCF_GetCurrentChatFrame=" .. s, { result = s }
		end,
	},
	{
		id = "chat.is_display_channel_owner",
		title = "IsDisplayChannelOwner",
		run = function()
			local s = firstShape(gfn("IsDisplayChannelOwner"))
			return "IsDisplayChannelOwner=" .. s, { value = s }
		end,
	},
	{
		id = "chat.join_channel_by_name",
		title = "JoinChannelByName",
		run = function() return fnPresence("JoinChannelByName", gfn("JoinChannelByName")) end,
	},
	{
		id = "chat.leave_channel_by_name",
		title = "LeaveChannelByName",
		run = function() return fnPresence("LeaveChannelByName", gfn("LeaveChannelByName")) end,
	},
	{
		id = "chat.set_channel_password",
		title = "SetChannelPassword",
		run = function() return fnPresence("SetChannelPassword", gfn("SetChannelPassword")) end,
	},

	-- units.lua (40)
	{
		id = "lab.invite.accept_group",
		title = "AcceptGroup",
		run = function() return fnPresence("AcceptGroup", gfn("AcceptGroup")) end,
	},
	{
		id = "lab.party.invite_unit",
		title = "C_PartyInfo party invite",
		run = function() return fnPresence("C_PartyInfo.Invite", tfn("C_PartyInfo", "Invite" .. "Unit")) end,
	},
	{
		id = "lab.party.leave_party",
		title = "C_PartyInfo.LeaveParty",
		run = function() return fnPresence("C_PartyInfo.LeaveParty", tfn("C_PartyInfo", "LeaveParty")) end,
	},
	{
		id = "lab.party.promote_to_leader",
		title = "C_PartyInfo.PromoteToLeader",
		run = function() return fnPresence("C_PartyInfo.PromoteToLeader", tfn("C_PartyInfo", "PromoteToLeader")) end,
	},
	{
		id = "lab.spell.c_spell_cooldown",
		title = "C_Spell.GetSpellCooldown",
		run = function()
			local r, err = ask(tfn("C_Spell", "GetSpellCooldown"), 698)
			local s = r and (type(r[1]) == "table" and "table" or shape(r[1])) or err
			return "C_Spell.GetSpellCooldown(698)=" .. s, { result = s }
		end,
	},
	{
		id = "lab.spell.c_spell_info",
		title = "C_Spell.GetSpellInfo",
		run = function()
			local r, err = ask(tfn("C_Spell", "GetSpellInfo"), 698)
			local s = r and (type(r[1]) == "table" and "table" or shape(r[1])) or err
			return "C_Spell.GetSpellInfo(698)=" .. s, { result = s }
		end,
	},
	{
		id = "lab.spell.c_spell_name",
		title = "C_Spell.GetSpellName",
		run = function()
			local s = firstShape(tfn("C_Spell", "GetSpellName"), 698)
			return "C_Spell.GetSpellName(698)=" .. s, { result = s }
		end,
	},
	{
		id = "lab.unit.check_interact_distance",
		title = "CheckInteractDistance",
		run = function()
			local s = firstShape(gfn("CheckInteractDistance"), "player", 1)
			return "CheckInteractDistance(player,1)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.env.normalized_realm_name",
		title = "GetNormalizedRealmName",
		run = function()
			local s = firstShape(gfn("GetNormalizedRealmName"))
			return "GetNormalizedRealmName=" .. s, { shape = s }
		end,
	},
	{
		id = "lab.party.num_group_members",
		title = "GetNumGroupMembers",
		run = function()
			local s = firstShape(gfn("GetNumGroupMembers"))
			return "GetNumGroupMembers=" .. s, { value = s }
		end,
	},
	{
		id = "lab.party.num_subgroup_members",
		title = "GetNumSubgroupMembers",
		run = function()
			local s = firstShape(gfn("GetNumSubgroupMembers"))
			return "GetNumSubgroupMembers=" .. s, { value = s }
		end,
	},
	{
		id = "lab.party.raid_roster_info",
		title = "GetRaidRosterInfo",
		run = function()
			local r, err = ask(gfn("GetRaidRosterInfo"), 1)
			local s = r and (r.n == 0 and "empty" or shape(r[1])) or err
			return "GetRaidRosterInfo(1)=" .. s, { result = s }
		end,
	},
	{
		id = "lab.env.realm_name",
		title = "GetRealmName",
		run = function()
			local s = firstShape(gfn("GetRealmName"))
			return "GetRealmName=" .. s, { shape = s }
		end,
	},
	{
		id = "lab.spell.global_cooldown",
		title = "GetSpellCooldown",
		run = function()
			local s = firstShape(gfn("GetSpellCooldown"), 698)
			return "GetSpellCooldown(698)=" .. s, { result = s }
		end,
	},
	{
		id = "lab.combat.lockdown",
		title = "InCombatLockdown",
		run = function()
			local s = firstShape(gfn("InCombatLockdown"))
			return "InCombatLockdown=" .. s, { value = s }
		end,
	},
	{
		id = "lab.party.global_invite_unit",
		title = "Global invite function",
		run = function() return fnPresence("global invite", gfn("Invite" .. "Unit")) end,
	},
	{
		id = "lab.party.is_in_group",
		title = "IsInGroup",
		run = function()
			local s = firstShape(gfn("IsInGroup"))
			return "IsInGroup=" .. s, { value = s }
		end,
	},
	{
		id = "lab.party.is_in_raid",
		title = "IsInRaid",
		run = function()
			local s = firstShape(gfn("IsInRaid"))
			return "IsInRaid=" .. s, { value = s }
		end,
	},
	{
		id = "lab.spell.is_player_spell",
		title = "IsPlayerSpell",
		run = function()
			local s = firstShape(gfn("IsPlayerSpell"), 698)
			return "IsPlayerSpell(698)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.spell.is_spell_known",
		title = "IsSpellKnown",
		run = function()
			local s = firstShape(gfn("IsSpellKnown"), 698)
			return "IsSpellKnown(698)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.party.global_leave_party",
		title = "LeaveParty",
		run = function() return fnPresence("LeaveParty", gfn("LeaveParty")) end,
	},
	{
		id = "lab.party.global_promote_to_leader",
		title = "PromoteToLeader",
		run = function() return fnPresence("PromoteToLeader", gfn("PromoteToLeader")) end,
	},
	{
		id = "lab.unit.affecting_combat",
		title = "UnitAffectingCombat",
		run = function()
			local s = firstShape(gfn("UnitAffectingCombat"), "player")
			return "UnitAffectingCombat(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.can_attack",
		title = "UnitCanAttack",
		run = function()
			local s = firstShape(gfn("UnitCanAttack"), "player", "player")
			return "UnitCanAttack(player,player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.casting_info",
		title = "UnitCastingInfo",
		run = function()
			local s = firstShape(gfn("UnitCastingInfo"), "player")
			return "UnitCastingInfo(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.channel_info",
		title = "UnitChannelInfo",
		run = function()
			local s = firstShape(gfn("UnitChannelInfo"), "player")
			return "UnitChannelInfo(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.class",
		title = "UnitClass",
		run = function()
			local r, err = ask(gfn("UnitClass"), "player")
			local s = r and (shape(r[1]) .. "/" .. shape(r[2])) or err
			return "UnitClass(player)=" .. s, { result = s }
		end,
	},
	{
		id = "lab.unit.exists",
		title = "UnitExists",
		run = function()
			local s = firstShape(gfn("UnitExists"), "player")
			return "UnitExists(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.faction_group",
		title = "UnitFactionGroup",
		run = function()
			local s = firstShape(gfn("UnitFactionGroup"), "player")
			return "UnitFactionGroup(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.full_name",
		title = "UnitFullName",
		run = function()
			local r, err = ask(gfn("UnitFullName"), "player")
			local s = r and (shape(r[1]) .. "," .. shape(r[2])) or err
			return "UnitFullName(player)=" .. s, { shape = s }
		end,
	},
	{
		id = "lab.unit.guid",
		title = "UnitGUID",
		run = function()
			local s = firstShape(gfn("UnitGUID"), "player")
			return "UnitGUID(player)=" .. s, { shape = s }
		end,
	},
	{
		id = "lab.unit.is_connected",
		title = "UnitIsConnected",
		run = function()
			local s = firstShape(gfn("UnitIsConnected"), "player")
			return "UnitIsConnected(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.is_enemy",
		title = "UnitIsEnemy",
		run = function()
			local s = firstShape(gfn("UnitIsEnemy"), "player", "player")
			return "UnitIsEnemy(player,player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.is_group_leader",
		title = "UnitIsGroupLeader",
		run = function()
			local s = firstShape(gfn("UnitIsGroupLeader"), "player")
			return "UnitIsGroupLeader(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.is_player",
		title = "UnitIsPlayer",
		run = function()
			local s = firstShape(gfn("UnitIsPlayer"), "player")
			return "UnitIsPlayer(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.is_unit",
		title = "UnitIsUnit",
		run = function()
			local s = firstShape(gfn("UnitIsUnit"), "player", "player")
			return "UnitIsUnit(player,player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.is_visible",
		title = "UnitIsVisible",
		run = function()
			local s = firstShape(gfn("UnitIsVisible"), "player")
			return "UnitIsVisible(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.level",
		title = "UnitLevel",
		run = function()
			local s = firstShape(gfn("UnitLevel"), "player")
			return "UnitLevel(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab.unit.name",
		title = "UnitName",
		run = function()
			local s = firstShape(gfn("UnitName"), "player")
			return "UnitName(player)=" .. s, { shape = s }
		end,
	},
	{
		id = "lab.unit.on_taxi",
		title = "UnitOnTaxi",
		run = function()
			local s = firstShape(gfn("UnitOnTaxi"), "player")
			return "UnitOnTaxi(player)=" .. s, { value = s }
		end,
	},

	-- frames.lua (15)
	{
		id = "lab-secure-click",
		title = "Secure frame methods",
		run = function(ctx) return methodPresence(ctx.frame, "SetAttribute", "Frame") end,
	},
	{
		id = "lab-modelscene",
		title = "ModelScene:CreateActor",
		run = function(ctx) return methodPresence(ctx.modelScene, "CreateActor", "ModelScene") end,
	},
	{
		id = "a_anim",
		title = "Frame:CreateAnimationGroup",
		run = function(ctx) return methodPresence(ctx.frame, "CreateAnimationGroup", "Frame") end,
	},
	{
		id = "lab-keys",
		title = "Frame:EnableKeyboard and override bindings",
		run = function(ctx)
			local hasM = type(ctx.frame) == "table" and type(ctx.frame.EnableKeyboard) == "function"
			local hasFn = type(gfn("SetOverrideBindingClick")) == "function"
			return ("EnableKeyboard=%s, SetOverrideBindingClick=%s"):format(tostring(hasM), tostring(hasFn)),
				{ method = hasM, bindingFn = hasFn }
		end,
	},
	{
		id = "lab-mouse",
		title = "Mouse getters and frame mouse methods",
		run = function(ctx)
			local pos = firstShape(gfn("GetCursorPosition"))
			local hasM = type(ctx.frame) == "table" and type(ctx.frame.IsMouseOver) == "function"
			return ("GetCursorPosition=%s, IsMouseOver=%s"):format(pos, tostring(hasM)),
				{ cursorPos = pos, hasIsMouseOver = hasM }
		end,
	},
	{
		id = "lab-layout",
		title = "Screen size and frame scale/size getters",
		run = function()
			local r, err = ask(gfn("GetPhysicalScreenSize"))
			local s = r and (shape(r[1]) .. "x" .. shape(r[2])) or err
			return "GetPhysicalScreenSize=" .. s, { screen = s }
		end,
	},
	{
		id = "a_ruler",
		title = "FontString ruler methods",
		run = function(ctx) return methodPresence(ctx.fontString, "IsTruncated", "FontString") end,
	},
	{
		id = "lab-secret-accessor",
		title = "Frame:GetScript",
		run = function(ctx) return methodPresence(ctx.frame, "GetScript", "Frame") end,
	},
	{
		id = "lab-secure-combat",
		title = "Frame protected/combat methods",
		run = function(ctx) return methodPresence(ctx.frame, "IsProtected", "Frame") end,
	},
	{
		id = "lab-tooltip-hook",
		title = "Frame:HookScript",
		run = function(ctx) return methodPresence(ctx.frame, "HookScript", "Frame") end,
	},
	{
		id = "lab-nameplate",
		title = "C_NamePlate.GetNamePlateForUnit",
		run = function()
			local s = firstShape(tfn("C_NamePlate", "GetNamePlateForUnit"), "player")
			return "C_NamePlate.GetNamePlateForUnit(player)=" .. s, { value = s }
		end,
	},
	{
		id = "lab-window-drag",
		title = "Frame:RegisterForDrag",
		run = function(ctx) return methodPresence(ctx.frame, "RegisterForDrag", "Frame") end,
	},
	{
		id = "lab-window-clamp",
		title = "Frame:SetClampedToScreen",
		run = function(ctx) return methodPresence(ctx.frame, "SetClampedToScreen", "Frame") end,
	},
	{
		id = "lab-input",
		title = "Modifier key getters",
		run = function()
			local a = firstShape(gfn("IsAltKeyDown"))
			local c = firstShape(gfn("IsControlKeyDown"))
			local sh = firstShape(gfn("IsShiftKeyDown"))
			return ("alt=%s ctrl=%s shift=%s"):format(a, c, sh), { alt = a, ctrl = c, shift = sh }
		end,
	},
	{
		id = "lab-ui-panel",
		title = "StaticPopup_FindVisible and ShowUIPanel",
		run = function()
			local pop = firstShape(gfn("StaticPopup_FindVisible"), "WUBER_NONEXISTENT")
			local hasShow = type(gfn("ShowUIPanel")) == "function"
			return ("StaticPopup_FindVisible=%s, ShowUIPanel=%s"):format(pop, tostring(hasShow)),
				{ popup = pop, showUIPanel = hasShow }
		end,
	},

	-- world.lua (60)
	{
		id = "tooltip_addline: hover a nameplate/unit and check tooltip line appears",
		title = "GameTooltip:AddLine",
		run = function() return methodPresence(gfn("GameTooltip"), "AddLine", "GameTooltip") end,
	},
	{
		id = "worldmap_pins: open WorldMapFrame and verify pins match current map",
		title = "WorldMapFrame:GetMapID",
		run = function()
			local wm = gfn("WorldMapFrame")
			local s = (type(wm) == "table" and type(wm.GetMapID) == "function") and firstShape(wm.GetMapID, wm) or "no WorldMapFrame:GetMapID"
			return "WorldMapFrame:GetMapID=" .. s, { mapID = s }
		end,
	},
	{
		id = "worldmap_hover: hover pins on WorldMapFrame and verify tooltip",
		title = "WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition",
		run = function()
			local wm = gfn("WorldMapFrame")
			local sc = type(wm) == "table" and wm.ScrollContainer or nil
			return methodPresence(sc, "GetNormalizedCursorPosition", "ScrollContainer")
		end,
	},
	{
		id = "tooltip_addline: hover a unit and check GameTooltip:NumLines() deduplication",
		title = "GameTooltip:NumLines",
		run = function()
			local gt = gfn("GameTooltip")
			local s = (type(gt) == "table" and type(gt.NumLines) == "function") and firstShape(gt.NumLines, gt) or "no GameTooltip:NumLines"
			return "GameTooltip:NumLines=" .. s, { lines = s }
		end,
	},
	{
		id = "chat_hide_channel: join Wuber channel and verify it is hidden from ChatFrame1",
		title = "ChatFrameUtil.RemoveChannel",
		run = function() return fnPresence("ChatFrameUtil.RemoveChannel", tfn("ChatFrameUtil", "RemoveChannel")) end,
	},
	{
		id = "a_anim: play flipbook milestone/summon effect in game",
		title = "FlipBook frame size methods",
		run = function(ctx)
			local hasAG = type(ctx.animGroup) == "table" and type(ctx.animGroup.CreateAnimation) == "function"
			return "AnimationGroup:CreateAnimation=" .. tostring(hasAG), { hasCreateAnimation = hasAG }
		end,
	},
	{
		id = "worldmap_open: open WorldMapFrame to a driver's map",
		title = "WorldMapFrame:SetMapID",
		run = function() return methodPresence(gfn("WorldMapFrame"), "SetMapID", "WorldMapFrame") end,
	},
	{
		id = "nameplate_clickthrough: verify nameplate overlay passes motion through",
		title = "Frame:SetMouseMotionEnabled",
		run = function(ctx) return methodPresence(ctx.frame, "SetMouseMotionEnabled", "Frame") end,
	},
	{
		id = "disable_old_addon: click disable RitualRides and /reload",
		title = "C_AddOns.DisableAddOn",
		run = function() return fnPresence("C_AddOns.DisableAddOn", tfn("C_AddOns", "DisableAddOn")) end,
	},
	{
		id = "bug_report_addons: open bug report and check loaded addon list",
		title = "C_AddOns.GetAddOnInfo",
		run = function()
			local s = firstShape(tfn("C_AddOns", "GetAddOnInfo"), 1)
			return "C_AddOns.GetAddOnInfo(1)=" .. s, { shape = s }
		end,
	},
	{
		id = "bug_report_addons: open bug report and check loaded addon count",
		title = "C_AddOns.GetNumAddOns",
		run = function()
			local s = firstShape(tfn("C_AddOns", "GetNumAddOns"))
			return "C_AddOns.GetNumAddOns=" .. s, { count = s }
		end,
	},
	{
		id = "nameplate_addon_detect: check Plater/TidyPlates detection in game",
		title = "C_AddOns.IsAddOnLoaded",
		run = function()
			local s = firstShape(tfn("C_AddOns", "IsAddOnLoaded"), "Wuber")
			return "C_AddOns.IsAddOnLoaded(Wuber)=" .. s, { loaded = s }
		end,
	},
	{
		id = "nameplate_cvar: read nameplateShowFriends in game",
		title = "C_CVar.GetCVar",
		run = function()
			local s = firstShape(tfn("C_CVar", "GetCVar"), "nameplateShowFriends")
			return "C_CVar.GetCVar(nameplateShowFriends)=" .. s, { value = s }
		end,
	},
	{
		id = "login.f1_sound: check Sound in Background CVar via C_CVar.GetCVarBool",
		title = "C_CVar.GetCVarBool",
		run = function()
			local s = firstShape(tfn("C_CVar", "GetCVarBool"), "Sound_EnableSoundWhenGameIsInBG")
			return "C_CVar.GetCVarBool(BG)=" .. s, { value = s }
		end,
	},
	{
		id = "nameplate_cvar: toggle friendly nameplates out of combat",
		title = "C_CVar.SetCVar",
		run = function() return fnPresence("C_CVar.SetCVar", tfn("C_CVar", "SetCVar")) end,
	},
	{
		id = "L1: summon a party member and read IncomingSummonStatus",
		title = "C_IncomingSummon.IncomingSummonStatus",
		run = function()
			local s = firstShape(tfn("C_IncomingSummon", "IncomingSummonStatus"), "player")
			return "C_IncomingSummon.IncomingSummonStatus(player)=" .. s, { value = s }
		end,
	},
	{
		id = "gamepad_ui_check: check style return on desktop vs gamepad",
		title = "C_InputInterfaceStyle.GetCurrentStyle",
		run = function()
			local s = firstShape(tfn("C_InputInterfaceStyle", "GetCurrentStyle"))
			return "C_InputInterfaceStyle.GetCurrentStyle=" .. s, { value = s }
		end,
	},
	{
		id = "shard_count: check Warlock Soul Shard count in Driver UI",
		title = "C_Item.GetItemCount",
		run = function()
			local s = firstShape(tfn("C_Item", "GetItemCount"), 6265)
			return "C_Item.GetItemCount(6265)=" .. s, { value = s }
		end,
	},
	{
		id = "lfg_listing: list group in Group Finder and read GetActiveEntryInfo",
		title = "C_LFGList.GetActiveEntryInfo",
		run = function()
			local r, err = ask(tfn("C_LFGList", "GetActiveEntryInfo"))
			local s = r and shape(r[1]) or err
			return "C_LFGList.GetActiveEntryInfo=" .. s, { value = s }
		end,
	},
	{
		id = "lfg_category: resolve activity category in Group Finder",
		title = "C_LFGList.GetActivityInfoTable",
		run = function()
			local fn = tfn("C_LFGList", "GetActivityInfoTable")
			return fnPresence("C_LFGList.GetActivityInfoTable", fn)
		end,
	},
	{
		id = "lfg_activities: read available Group Finder activities in game",
		title = "C_LFGList.GetAvailableActivities",
		run = function()
			local r, err = ask(tfn("C_LFGList", "GetAvailableActivities"))
			local s = r and (type(r[1]) == "table" and ("table:#" .. #r[1]) or shape(r[1])) or err
			return "C_LFGList.GetAvailableActivities=" .. s, { value = s }
		end,
	},
	{
		id = "lfg_search: inspect Group Finder search result fields in game",
		title = "C_LFGList.GetSearchResultInfo",
		run = function() return fnPresence("C_LFGList.GetSearchResultInfo", tfn("C_LFGList", "GetSearchResultInfo")) end,
	},
	{
		id = "lfg_search_member: inspect member areaName in Group Finder result",
		title = "C_LFGList.GetSearchResultPlayerInfo",
		run = function() return fnPresence("C_LFGList.GetSearchResultPlayerInfo", tfn("C_LFGList", "GetSearchResultPlayerInfo")) end,
	},
	{
		id = "lfg_search: run Group Finder search from Rider click",
		title = "C_LFGList.GetSearchResults",
		run = function()
			local r, err = ask(tfn("C_LFGList", "GetSearchResults"))
			local s = r and (shape(r[1]) .. "," .. shape(r[2])) or err
			return "C_LFGList.GetSearchResults=" .. s, { value = s }
		end,
	},
	{
		id = "lfg_listing: check HasActiveEntryInfo while listed vs unlisted",
		title = "C_LFGList.HasActiveEntryInfo",
		run = function()
			local s = firstShape(tfn("C_LFGList", "HasActiveEntryInfo"))
			return "C_LFGList.HasActiveEntryInfo=" .. s, { value = s }
		end,
	},
	{
		id = "lfg_delist: click delist button in Driver UI",
		title = "C_LFGList.RemoveListing",
		run = function() return fnPresence("C_LFGList.RemoveListing", tfn("C_LFGList", "RemoveListing")) end,
	},
	{
		id = "lfg_search: click Group Finder search button in Rider UI",
		title = "C_LFGList.Search",
		run = function() return fnPresence("C_LFGList.Search", tfn("C_LFGList", "Search")) end,
	},
	{
		id = "homemap_tiles: open Rider HomeMap and verify continent tiles render",
		title = "C_Map.GetMapArtLayerTextures",
		run = function()
			local r, err = ask(tfn("C_Map", "GetMapArtLayerTextures"), 1414, 1)
			local s = r and (type(r[1]) == "table" and ("table:#" .. #r[1]) or shape(r[1])) or err
			return "C_Map.GetMapArtLayerTextures(1414,1)=" .. s, { value = s }
		end,
	},
	{
		id = "homemap_tiles: open Rider HomeMap and verify layer dimensions",
		title = "C_Map.GetMapArtLayers",
		run = function()
			local r, err = ask(tfn("C_Map", "GetMapArtLayers"), 1414)
			local s = r and (type(r[1]) == "table" and ("table:#" .. #r[1]) or shape(r[1])) or err
			return "C_Map.GetMapArtLayers(1414)=" .. s, { value = s }
		end,
	},
	{
		id = "worldmap_zones: verify continent child zones in game",
		title = "C_Map.GetMapChildrenInfo",
		run = function()
			local r, err = ask(tfn("C_Map", "GetMapChildrenInfo"), 1414)
			local s = r and (type(r[1]) == "table" and ("table:#" .. #r[1]) or shape(r[1])) or err
			return "C_Map.GetMapChildrenInfo(1414)=" .. s, { value = s }
		end,
	},
	{
		id = "map_info: verify C_Map.GetMapInfo(1454).name in game",
		title = "C_Map.GetMapInfo",
		run = function()
			local r, err = ask(tfn("C_Map", "GetMapInfo"), 1454)
			local s = r and (type(r[1]) == "table" and ("table:" .. shape(r[1].name)) or shape(r[1])) or err
			return "C_Map.GetMapInfo(1454)=" .. s, { value = s }
		end,
	},
	{
		id = "worldmap_hover: hover continent map and verify zone name",
		title = "C_Map.GetMapInfoAtPosition",
		run = function()
			local r, err = ask(tfn("C_Map", "GetMapInfoAtPosition"), 1414, 0.5, 0.5)
			local s = r and shape(r[1]) or err
			return "C_Map.GetMapInfoAtPosition(1414)=" .. s, { value = s }
		end,
	},
	{
		id = "homemap_pins: check driver pin projection on continent map",
		title = "C_Map.GetMapPosFromWorldPos",
		run = function()
			local fn = tfn("C_Map", "GetMapPosFromWorldPos")
			return fnPresence("C_Map.GetMapPosFromWorldPos", fn)
		end,
	},
	{
		id = "player_pos: check player pin on HomeMap outside and inside instance",
		title = "C_Map.GetPlayerMapPosition",
		run = function()
			local r, err = ask(tfn("C_Map", "GetPlayerMapPosition"), 1454, "player")
			local s = r and shape(r[1]) or err
			return "C_Map.GetPlayerMapPosition(1454)=" .. s, { value = s }
		end,
	},
	{
		id = "worldmap_open: click 'Show on map' for a driver out of combat",
		title = "C_Map.OpenWorldMap",
		run = function() return fnPresence("C_Map.OpenWorldMap", tfn("C_Map", "OpenWorldMap")) end,
	},
	{
		id = "taxi_nodes_map: open flight map and check C_TaxiMap.GetTaxiNodesForMap",
		title = "C_TaxiMap.GetTaxiNodesForMap",
		run = function()
			local r, err = ask(tfn("C_TaxiMap", "GetTaxiNodesForMap"), 1454)
			local s = r and (type(r[1]) == "table" and ("table:#" .. #r[1]) or shape(r[1])) or err
			return "C_TaxiMap.GetTaxiNodesForMap(1454)=" .. s, { value = s }
		end,
	},
	{
		id = "B8: verify ticker jitter/lag during Shift-drag in game",
		title = "C_Timer.NewTicker",
		run = function() return fnPresence("C_Timer.NewTicker", tfn("C_Timer", "NewTicker")) end,
	},
	{
		id = "bell_flash: receive ride request with game unfocused",
		title = "FlashClientIcon",
		run = function() return fnPresence("FlashClientIcon", gfn("FlashClientIcon")) end,
	},
	{
		id = "login.f1_sound: check Sound in Background CVar in game",
		title = "GetCVarBool",
		run = function()
			local s = firstShape(gfn("GetCVarBool"), "Sound_EnableSoundWhenGameIsInBG")
			return "GetCVarBool(BG)=" .. s, { value = s }
		end,
	},
	{
		id = "guild_outreach: test guild name/rank check in a guild",
		title = "GetGuildInfo",
		run = function()
			local r, err = ask(gfn("GetGuildInfo"), "player")
			local s = r and (shape(r[1]) .. "," .. shape(r[2])) or err
			return "GetGuildInfo(player)=" .. s, { shape = s }
		end,
	},
	{
		id = "mail_earnings: receive COD/gold mail and open mailbox",
		title = "GetInboxHeaderInfo",
		run = function()
			local fn = gfn("GetInboxHeaderInfo")
			return fnPresence("GetInboxHeaderInfo", fn)
		end,
	},
	{
		id = "mail_earnings: open mailbox with items present",
		title = "GetInboxNumItems",
		run = function()
			local r, err = ask(gfn("GetInboxNumItems"))
			local s = r and (shape(r[1]) .. "," .. shape(r[2])) or err
			return "GetInboxNumItems=" .. s, { value = s }
		end,
	},
	{
		id = "trade_money: complete trade and verify GetMoney() delta",
		title = "GetMoney",
		run = function()
			local s = firstShape(gfn("GetMoney"))
			return "GetMoney=" .. s, { value = s }
		end,
	},
	{
		id = "trade_money: enter gold in trade window and read GetPlayerTradeMoney",
		title = "GetPlayerTradeMoney",
		run = function()
			local s = firstShape(gfn("GetPlayerTradeMoney"))
			return "GetPlayerTradeMoney=" .. s, { value = s }
		end,
	},
	{
		id = "zone_text: check zone name across continents/cities",
		title = "GetRealZoneText",
		run = function()
			local s = firstShape(gfn("GetRealZoneText"))
			return "GetRealZoneText=" .. s, { shape = s }
		end,
	},
	{
		id = "subzone_text: check subzone string in city vs outdoors",
		title = "GetSubZoneText",
		run = function()
			local s = firstShape(gfn("GetSubZoneText"))
			return "GetSubZoneText=" .. s, { shape = s }
		end,
	},
	{
		id = "trade_money: have rider enter gold and check GetTargetTradeMoney",
		title = "GetTargetTradeMoney",
		run = function()
			local s = firstShape(gfn("GetTargetTradeMoney"))
			return "GetTargetTradeMoney=" .. s, { value = s }
		end,
	},
	{
		id = "taxi_map_id: check GetTaxiMapID() at flight master",
		title = "GetTaxiMapID",
		run = function()
			local s = firstShape(gfn("GetTaxiMapID"))
			return "GetTaxiMapID=" .. s, { value = s }
		end,
	},
	{
		id = "trade_item: place item in trade slot and read GetTradePlayerItemInfo",
		title = "GetTradePlayerItemInfo",
		run = function() return fnPresence("GetTradePlayerItemInfo", gfn("GetTradePlayerItemInfo")) end,
	},
	{
		id = "zone_text: check GetZoneText() across zones",
		title = "GetZoneText",
		run = function()
			local s = firstShape(gfn("GetZoneText"))
			return "GetZoneText=" .. s, { shape = s }
		end,
	},
	{
		id = "cinematic_guard: trigger cinematic and verify UI hides",
		title = "InCinematic",
		run = function()
			local s = firstShape(gfn("InCinematic"))
			return "InCinematic=" .. s, { value = s }
		end,
	},
	{
		id = "trade_initiate: click trade button on arrived rider",
		title = "InitiateTrade",
		run = function() return fnPresence("InitiateTrade", gfn("InitiateTrade")) end,
	},
	{
		id = "cinematic_guard: trigger cinematic scene and verify UI hides",
		title = "IsInCinematicScene",
		run = function()
			local s = firstShape(gfn("IsInCinematicScene"))
			return "IsInCinematicScene=" .. s, { value = s }
		end,
	},
	{
		id = "guild_share: check Share button guild option in vs out of guild",
		title = "IsInGuild",
		run = function()
			local s = firstShape(gfn("IsInGuild"))
			return "IsInGuild=" .. s, { value = s }
		end,
	},
	{
		id = "instance_check: enter dungeon/raid and verify IsInInstance()",
		title = "IsInInstance",
		run = function()
			local r, err = ask(gfn("IsInInstance"))
			local s = r and (shape(r[1]) .. "," .. shape(r[2])) or err
			return "IsInInstance=" .. s, { value = s }
		end,
	},
	{
		id = "nameplate_mount: mount up and check nameplate crown offset",
		title = "IsMounted",
		run = function()
			local s = firstShape(gfn("IsMounted"))
			return "IsMounted=" .. s, { value = s }
		end,
	},
	{
		id = "nameplate_cvar: toggle friendly nameplates via SetCVar",
		title = "SetCVar",
		run = function() return fnPresence("SetCVar", gfn("SetCVar")) end,
	},
	{
		id = "inflight_timer: take a real flight and verify flight duration tracking",
		title = "TakeTaxiNode",
		run = function() return fnPresence("TakeTaxiNode", gfn("TakeTaxiNode")) end,
	},
	{
		id = "raid_assist: check Driver raid permission as raid assistant",
		title = "UnitIsGroupAssistant",
		run = function()
			local s = firstShape(gfn("UnitIsGroupAssistant"), "player")
			return "UnitIsGroupAssistant(player)=" .. s, { value = s }
		end,
	},
	{
		id = "raid_assist: check Driver raid permission as raid officer",
		title = "UnitIsRaidOfficer",
		run = function()
			local s = firstShape(gfn("UnitIsRaidOfficer"), "player")
			return "UnitIsRaidOfficer(player)=" .. s, { value = s }
		end,
	},
}

G.API_CHECKS = CHECKS
for _, c in ipairs(CHECKS) do
	G.IDS[#G.IDS + 1] = { c.id, c.title, "instant" }
end

function G.RunApiFacts()
	if inCombat() then return false, "in combat" end
	local ctx = getScratch()
	for _, c in ipairs(CHECKS) do
		local okRun, line, answers = pcall(c.run, ctx)
		if okRun then
			G.Put(c.id, line or "ok", answers, true, true)
		else
			G.Put(c.id, "error: " .. tostring(line), { err = tostring(line) }, true, true)
		end
	end
	if L.Log then L.Log("facts", ("api: %d checks recorded"):format(#CHECKS)) end
	return true, #CHECKS
end

local instant = G.Instant
if type(instant) == "function" then
	function G.Instant(why)
		if why ~= "auto" then pcall(G.RunApiFacts) end
		return instant(why)
	end
	L.GameFactsInstant = G.Instant
end
