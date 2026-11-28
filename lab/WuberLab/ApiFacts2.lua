-- Wuber Lab (developer only, never ship): ApiFacts2.lua - read-only in-game checks for the
-- `evidence = "guess"` rows in tests/fixtures/client/api/frames.lua (31) and chat.lua (7).
--
-- Every check here:
--   - ONLY READS (never joins/leaves channels, sets passwords, changes keybindings, or opens/hides popups/panels).
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

local SCRATCH
local function getScratch()
	if SCRATCH then return SCRATCH end
	local cf = gfn("CreateFrame")
	if type(cf) ~= "function" then
		SCRATCH = {}
		return SCRATCH
	end
	local okF, f = pcall(cf, "Frame")
	local okE, eb = pcall(cf, "EditBox")
	local tex, ag, anim
	if okF and f then
		if type(f.CreateTexture) == "function" then
			local okT, t = pcall(f.CreateTexture, f)
			if okT then tex = t end
		end
		if type(f.CreateAnimationGroup) == "function" then
			local okAG, g = pcall(f.CreateAnimationGroup, f)
			if okAG and g then
				ag = g
				if type(g.CreateAnimation) == "function" then
					local okA, a = pcall(g.CreateAnimation, g, "Alpha")
					if okA then anim = a end
				end
			end
		end
	end
	SCRATCH = {
		frame = okF and f or nil,
		editBox = okE and eb or nil,
		texture = tex,
		animGroup = ag,
		anim = anim,
	}
	return SCRATCH
end

local CHECKS = {
	-- chat.lua (7 guess rows)
	{
		id = "apifacts2.chat.in_lockdown",
		name = "C_ChatInfo.InChatMessagingLockdown",
		source = "chat.lua",
		readOnly = true,
		run = function()
			local s = firstShape(tfn("C_ChatInfo", "InChatMessagingLockdown"))
			return "InChatMessagingLockdown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts2.club.get_invitations",
		name = "C_Club.GetInvitationsForSelf",
		source = "chat.lua",
		readOnly = true,
		run = function()
			local fn = tfn("C_Club", "GetInvitationsForSelf")
			local r, err = ask(fn)
			local s = r and (type(r[1]) == "table" and ("table:" .. #r[1]) or shape(r[1])) or err
			return "C_Club.GetInvitationsForSelf=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.chat.fcf_current_frame",
		name = "FCF_GetCurrentChatFrame",
		source = "chat.lua",
		readOnly = true,
		run = function()
			local fn = gfn("FCF_GetCurrentChatFrame")
			local r, err = ask(fn)
			local s = r and shape(r[1]) or err
			return "FCF_GetCurrentChatFrame=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.chat.is_display_channel_owner",
		name = "IsDisplayChannelOwner",
		source = "chat.lua",
		readOnly = true,
		run = function()
			local fn = gfn("IsDisplayChannelOwner")
			local s = firstShape(fn)
			return "IsDisplayChannelOwner=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.chat.join_channel_by_name",
		name = "JoinChannelByName",
		source = "chat.lua",
		readOnly = false,
		run = function() return fnPresence("JoinChannelByName", gfn("JoinChannelByName"), "not checkable read-only") end,
	},
	{
		id = "apifacts2.chat.leave_channel_by_name",
		name = "LeaveChannelByName",
		source = "chat.lua",
		readOnly = false,
		run = function() return fnPresence("LeaveChannelByName", gfn("LeaveChannelByName"), "not checkable read-only") end,
	},
	{
		id = "apifacts2.chat.set_channel_password",
		name = "SetChannelPassword",
		source = "chat.lua",
		readOnly = false,
		run = function() return fnPresence("SetChannelPassword", gfn("SetChannelPassword"), "not checkable read-only") end,
	},

	-- frames.lua (31 guess rows)
	{
		id = "apifacts2.frame.clear_focus",
		name = ":ClearFocus",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.editBox, "ClearFocus", "EditBox", true) end,
	},
	{
		id = "apifacts2.frame.does_clip_children",
		name = ":DoesClipChildren",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.frame, "DoesClipChildren", "Frame", true) end,
	},
	{
		id = "apifacts2.anim.get_duration",
		name = ":GetDuration",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.anim, "GetDuration", "Animation", true) end,
	},
	{
		id = "apifacts2.frame.get_num_points",
		name = ":GetNumPoints",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.frame, "GetNumPoints", "Frame", true) end,
	},
	{
		id = "apifacts2.tex.get_texture",
		name = ":GetTexture",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.texture, "GetTexture", "Texture", true) end,
	},
	{
		id = "apifacts2.edit.has_focus",
		name = ":HasFocus",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.editBox, "HasFocus", "EditBox", true) end,
	},
	{
		id = "apifacts2.frame.is_mouse_enabled",
		name = ":IsMouseEnabled",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.frame, "IsMouseEnabled", "Frame", true) end,
	},
	{
		id = "apifacts2.anim.is_playing",
		name = ":IsPlaying",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.animGroup, "IsPlaying", "AnimationGroup", true) end,
	},
	{
		id = "apifacts2.tex.set_color_texture",
		name = ":SetColorTexture",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.texture, "SetColorTexture", "Texture", true, 0, 0, 0, 0) end,
	},
	{
		id = "apifacts2.tex.set_desaturated",
		name = ":SetDesaturated",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.texture, "SetDesaturated", "Texture", true, false) end,
	},
	{
		id = "apifacts2.edit.set_focus",
		name = ":SetFocus",
		source = "frames.lua",
		readOnly = false,
		run = function(ctx) return methodCheck(ctx.editBox, "SetFocus", "EditBox", false) end,
	},
	{
		id = "apifacts2.tex.set_tex_coord",
		name = ":SetTexCoord",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.texture, "SetTexCoord", "Texture", true, 0, 1, 0, 1) end,
	},
	{
		id = "apifacts2.tex.set_texture",
		name = ":SetTexture",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.texture, "SetTexture", "Texture", true, nil) end,
	},
	{
		id = "apifacts2.tex.set_vertex_color",
		name = ":SetVertexColor",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.texture, "SetVertexColor", "Texture", true, 1, 1, 1, 1) end,
	},
	{
		id = "apifacts2.anim.stop",
		name = ":Stop",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx) return methodCheck(ctx.animGroup, "Stop", "AnimationGroup", true) end,
	},
	{
		id = "apifacts2.keys.clear_override_bindings",
		name = "ClearOverrideBindings",
		source = "frames.lua",
		readOnly = false,
		run = function() return fnPresence("ClearOverrideBindings", gfn("ClearOverrideBindings"), "not checkable read-only") end,
	},
	{
		id = "apifacts2.create_color",
		name = "CreateColor",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local fn = gfn("CreateColor")
			local s = firstShape(fn, 1, 1, 1, 1)
			return "CreateColor=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.create_font",
		name = "CreateFont",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local fn = gfn("CreateFont")
			return fnPresence("CreateFont", fn)
		end,
	},
	{
		id = "apifacts2.create_frame",
		name = "CreateFrame",
		source = "frames.lua",
		readOnly = true,
		run = function(ctx)
			local fn = gfn("CreateFrame")
			return ("CreateFrame: %s (scratch=%s)"):format(type(fn), ctx.frame and "ok" or "nil"),
				{ present = type(fn) == "function", scratch = ctx.frame ~= nil }
		end,
	},
	{
		id = "apifacts2.mouse.get_cursor_position",
		name = "GetCursorPosition",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local s = pairShape(gfn("GetCursorPosition"))
			return "GetCursorPosition=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts2.mouse.get_mouse_foci",
		name = "GetMouseFoci",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local fn = gfn("GetMouseFoci")
			local r, err = ask(fn)
			local s = r and (type(r[1]) == "table" and ("table:" .. #r[1]) or shape(r[1])) or err
			return "GetMouseFoci=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.mouse.get_mouse_focus",
		name = "GetMouseFocus",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local fn = gfn("GetMouseFocus")
			local s = firstShape(fn)
			return "GetMouseFocus=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.layout.get_physical_screen_size",
		name = "GetPhysicalScreenSize",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local s = pairShape(gfn("GetPhysicalScreenSize"))
			return "GetPhysicalScreenSize=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts2.input.is_alt_key_down",
		name = "IsAltKeyDown",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsAltKeyDown"))
			return "IsAltKeyDown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts2.input.is_control_key_down",
		name = "IsControlKeyDown",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsControlKeyDown"))
			return "IsControlKeyDown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts2.input.is_shift_key_down",
		name = "IsShiftKeyDown",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local s = firstShape(gfn("IsShiftKeyDown"))
			return "IsShiftKeyDown=" .. s, { value = s }
		end,
	},
	{
		id = "apifacts2.keys.set_override_binding_click",
		name = "SetOverrideBindingClick",
		source = "frames.lua",
		readOnly = false,
		run = function() return fnPresence("SetOverrideBindingClick", gfn("SetOverrideBindingClick"), "not checkable read-only") end,
	},
	{
		id = "apifacts2.ui.show_ui_panel",
		name = "ShowUIPanel",
		source = "frames.lua",
		readOnly = false,
		run = function() return fnPresence("ShowUIPanel", gfn("ShowUIPanel"), "not checkable read-only") end,
	},
	{
		id = "apifacts2.ui.static_popup_find_visible",
		name = "StaticPopup_FindVisible",
		source = "frames.lua",
		readOnly = true,
		run = function()
			local fn = gfn("StaticPopup_FindVisible")
			local s = firstShape(fn, "WUBER_PROBE_NONE")
			return "StaticPopup_FindVisible=" .. s, { present = type(fn) == "function", value = s }
		end,
	},
	{
		id = "apifacts2.ui.static_popup_hide",
		name = "StaticPopup_Hide",
		source = "frames.lua",
		readOnly = false,
		run = function() return fnPresence("StaticPopup_Hide", gfn("StaticPopup_Hide"), "not checkable read-only") end,
	},
	{
		id = "apifacts2.ui.static_popup_show",
		name = "StaticPopup_Show",
		source = "frames.lua",
		readOnly = false,
		run = function() return fnPresence("StaticPopup_Show", gfn("StaticPopup_Show"), "not checkable read-only") end,
	},
}

G.API_CHECKS2 = CHECKS

function G.RunApiFacts2()
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
	if L.Log then L.Log("facts", ("api2: %d checks recorded"):format(#CHECKS)) end
	return true, #CHECKS
end
