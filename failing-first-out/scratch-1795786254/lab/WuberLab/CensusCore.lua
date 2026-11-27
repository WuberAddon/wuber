-- census_core.lua: the measuring part of the "a_census" Auto check (job 2630, item 13). DRAFT.
-- Copy 1 goes into the Lab as WuberLab/CensusCore.lua (loaded before AutoSteps5.lua in WuberLab.toc), where it hands itself to the Lab as L.CensusCore.
-- Copy 2 is tests/lib/census_core.lua in the repo: the offline conformance test runs the SAME calls against the fake game (env = a client's environment),
-- so the real answers and the fake's are always keyed alike. Keep the two files identical.
--
--   M.run(env, done, opts)   env: the table the game's globals live in (_G in the game, client.env in the fake). done(a) is called with the answers when
--                            the last timed reading is in. opts.fonts = { regular =, medium =, bold = } (Wuber's own font files, W.Theme.FONTS),
--                            opts.fontSizes = { 12, 16, 22 } (optional), opts.events = list (default M.EVENTS).
--   M.cleanup()              what M.run made (two holders and their children) is hidden and its scripts cleared; also called by M.run at the end.
--
-- a is a flat table, key -> short string, so a Game facts entry or a fixture file can hold it as plain data. Every call goes through pcall; a
-- call that is missing gives "missing", one that raises gives "error" (the message is kept in key .. ".err"). A call's answer is written as its
-- SIGNATURE: "n=<how many values>:<type>,<type>" (so "n=0:" is a bare return: no value, not one nil), plus a value only where the question is about the value.
-- Nothing is sent, nothing is hooked, no cvar is set, no protected function is called; throwaway frames only.

local addon, ns = ...

local M = {}

local unpack = unpack
local function pack(...) return { n = select("#", ...), ... } end
local function typ(v) if v == nil then return "nil" end return type(v) end
local function sigOf(r)
	local t = {}
	for i = 1, r.n do t[i] = typ(r[i]) end
	return "n=" .. r.n .. ":" .. table.concat(t, ",")
end
local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
local function bucket(v)
	if type(v) ~= "number" then return typ(v) end
	if v ~= v then return "nan" end
	if v == 0 then return "zero" end
	return v > 0 and "pos" or "neg"
end
local function short(s, n) s = tostring(s) if #s > (n or 120) then return s:sub(1, n or 120) .. "~" end return s end

-- f(...) -> signature or "missing" / "error", and the packed results (nil on a failure), the message
local function ask(f, ...)
	if type(f) ~= "function" then return "missing" end
	local r = pack(pcall(f, ...))
	if not r[1] then return "error", nil, short(r[2], 100) end
	local out = { n = r.n - 1 }
	for i = 2, r.n do out[i - 1] = r[i] end
	return sigOf(out), out
end
local function askm(o, name, ...)
	if type(o) ~= "table" then return "missing" end
	local okf, f = pcall(function() return o[name] end)
	if not okf then return "error", nil, short(f, 100) end
	if type(f) ~= "function" then return "missing" end
	return ask(f, o, ...)
end
local function put(a, key, sig, msg)
	a[key] = sig
	if msg then a[key .. ".err"] = msg end
end
-- a signature plus the bucket of the first value (zero / pos / neg / nil / its type)
local function putB(a, key, sig, r, msg)
	if r and r.n >= 1 then sig = sig .. "|" .. bucket(r[1]) end
	put(a, key, sig, msg)
end

-- t[k] under pcall (the fake game's environment may refuse a global it does not know)
local function field(t, k)
	if type(t) ~= "table" then return nil end
	local ok, v = pcall(function() return t[k] end)
	if ok then return v end
	return nil
end

local function path(env, dotted)
	local cur = env
	for part in dotted:gmatch("[^%.]+") do
		if type(cur) ~= "table" then return nil end
		local ok, v = pcall(function() return cur[part] end)
		if not ok then return nil end
		cur = v
	end
	return cur
end

local function keysOf(t, withValues)
	if type(t) ~= "table" then return nil end
	local names = {}
	for k, v in pairs(t) do
		if type(k) == "string" then names[#names + 1] = withValues and (k .. "=" .. tostring(v)) or k end
	end
	table.sort(names)
	local text = table.concat(names, " ")
	return short(text, 400)
end

-- the events Wuber registers (a grep of Wuber/ for W.On("EVENT") and RegisterEvent("EVENT"); regenerate when Wuber's list changes)
M.EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "ADDON_LOADED", "BAG_UPDATE_DELAYED", "CANCEL_SUMMON", "CHANNEL_UI_UPDATE",
	"CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_SAY", "CHAT_MSG_SYSTEM",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_YELL", "CONFIRM_SUMMON", "DISPLAY_SIZE_CHANGED", "ENCOUNTER_END", "ENCOUNTER_START",
	"GLOBAL_MOUSE_DOWN", "GROUP_JOINED", "GROUP_LEFT", "GROUP_ROSTER_UPDATE", "MAIL_INBOX_UPDATE", "MAIL_SHOW", "NAME_PLATE_UNIT_ADDED",
	"NAME_PLATE_UNIT_REMOVED", "PARTY_INVITE_REQUEST", "PARTY_LEADER_CHANGED", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST",
	"PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_MONEY", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "PLAYER_TRADE_MONEY", "SPELLS_CHANGED", "TAXIMAP_CLOSED", "TAXIMAP_OPENED", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED",
	"TRADE_MONEY_CHANGED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_REQUEST_CANCEL", "TRADE_SHOW", "TRADE_TARGET_ITEM_CHANGED", "TRADE_UPDATE",
	"UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "UI_SCALE_CHANGED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
	"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
	"NOT_A_REAL_EVENT_FOR_THE_CENSUS" } -- (the last one is the control: how this client refuses an event it does not know)

M.EXIST = { "JoinTemporaryChannel", "JoinChannelByName", "JoinPermanentChannel", "GetCameraZoom", "InterfaceOptions_AddCategory",
	"ERR_TRADE_COMPLETE", "ERR_DECLINE_GROUP_S", "ERR_ALREADY_IN_GROUP_S", "ERR_BAD_PLAYER_NAME_S", "ERR_IGNORING_YOU_S", "GetTaxiMapID",
	"GetZonePVPInfo", "TaxiIsDirectFlight", "AcceptGroup", "GetChannelList", "Ambiguate", "SendChatMessage", "UNKNOWNOBJECT",
	"Enum.FlightPathFaction", "Enum.SummonStatus", "C_IncomingSummon", "C_Secrets", "C_RestrictedActions", "C_PvP.GetZonePVPInfo",
	"C_ChatInfo.RequestCanLocalWhisperTarget", "C_ChatInfo.AreOutgoingAddonChatMessagesRestricted", "OpenMapAPI" }

local STRATA = { "WORLD", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP", "BLIZZARD", "NOT_A_STRATUM" }
local LEVELS = { -1, 0, 1, 9999, 10000, 10001, 65535, 65536 }
local GETTERS = { "GetLeft", "GetRight", "GetTop", "GetBottom", "GetCenter", "GetRect", "GetScaledRect", "GetPoint", "GetNumPoints",
	"GetWidth", "GetHeight", "GetSize" }

local state -- what M.run made

function M.cleanup()
	local s = state
	if not s then return end
	state = nil
	for _, f in ipairs(s.frames) do
		pcall(function() f:SetScript("OnUpdate", nil) end)
		pcall(function() f:UnregisterAllEvents() end)
		pcall(function() f:Hide() end)
	end
	for _, h in ipairs({ s.vis, s.hid }) do pcall(function() h:Hide() end) end
end

---------------------------------------------------------------------------
-- 1 and 2: existence, constants
---------------------------------------------------------------------------

local function section1(env, a)
	for _, name in ipairs(M.EXIST) do
		local v = path(env, name)
		a["ex." .. name] = typ(v)
		if type(v) == "string" then a["val." .. name] = short(v) end
		if type(v) == "table" then a["keys." .. name] = keysOf(v, name:find("^Enum%.") ~= nil) or "-" end
	end
end

local function section2(env, a)
	local project = field(env, "WOW_PROJECT_ID")
	a["const.WOW_PROJECT_ID"] = typ(project) .. ":" .. tostring(project)
	a["const.WOW_PROJECT_CAMELOT"] = tostring(field(env, "WOW_PROJECT_CAMELOT"))
	local sig, r = ask(field(env, "GetBuildInfo"))
	put(a, "const.GetBuildInfo.sig", sig)
	if r then
		local v = {}
		for i = 1, r.n do v[i] = tostring(r[i]) end
		a["const.GetBuildInfo.values"] = short(table.concat(v, " | "), 200)
	end
	for _, name in ipairs({ "GetRealmName", "GetNormalizedRealmName" }) do
		local s2, r2_ = ask(field(env, name))
		put(a, "const." .. name .. ".sig", s2)
		if r2_ and r2_.n >= 1 and type(r2_[1]) == "string" then a["const." .. name .. ".len"] = tostring(#r2_[1]) end
	end
	local s3 = ask(field(env, "UnitName"), "player")
	put(a, "const.UnitName.sig", s3)
	local ci = field(env, "C_ChatInfo")
	local s4, r4 = ask(field(ci, "AreOutgoingAddonChatMessagesRestricted"))
	put(a, "const.AreOutgoingAddonChatMessagesRestricted", s4 .. (r4 and r4.n >= 1 and (":" .. tostring(r4[1])) or ""))
end

---------------------------------------------------------------------------
-- 3: RegisterEvent on a throwaway frame
---------------------------------------------------------------------------

local function section3(env, a, s, events)
	local f = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = f
	for _, ev in ipairs(events) do
		local sig, r, msg = askm(f, "RegisterEvent", ev)
		put(a, "ev." .. ev, sig .. (r and r.n >= 1 and (":" .. tostring(r[1])) or ""), msg)
		local reg = askm(f, "IsEventRegistered", ev)
		a["ev." .. ev .. ".registered"] = reg
		askm(f, "UnregisterEvent", ev)
	end
	pcall(f.UnregisterAllEvents, f)
end

---------------------------------------------------------------------------
-- 4: geometry
---------------------------------------------------------------------------

local function readGetters(a, prefix, obj)
	for _, g in ipairs(GETTERS) do
		local sig, r, msg = askm(obj, g, g == "GetPoint" and 1 or nil)
		putB(a, prefix .. "." .. g, sig, r, msg)
	end
end

local function section4(env, a, s, later)
	local UI = env.UIParent
	-- brand-new unplaced objects
	local fr = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = fr
	readGetters(a, "geo.frame", fr)
	local okFs, fs = pcall(fr.CreateFontString, fr, nil, "OVERLAY", "GameFontNormal")
	if okFs and fs then readGetters(a, "geo.fontstring", fs) else a["geo.fontstring"] = "error" end
	local okT, tex = pcall(fr.CreateTexture, fr, nil, "ARTWORK")
	if okT and tex then readGetters(a, "geo.texture", tex) else a["geo.texture"] = "error" end

	-- a frame anchored by two points: its size in the same frame it was anchored, one frame later, 0.3 s later
	local two = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = two
	two:SetPoint("TOPLEFT", UI, "BOTTOMLEFT", 200, 600)
	two:SetPoint("BOTTOMRIGHT", UI, "BOTTOMLEFT", 400, 500)
	two:Show()
	local function readTwo(tag)
		for _, g in ipairs({ "GetWidth", "GetHeight", "GetLeft", "GetSize" }) do
			local sig, r, msg = askm(two, g)
			putB(a, "geo.two." .. tag .. "." .. g, sig, r, msg)
		end
	end
	readTwo("now")
	later("frame", function() readTwo("frame1") end)
	later(0.3, function() readTwo("t0.3") end)

	-- clamped to the screen, put far off it
	local clamp = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = clamp
	clamp:SetSize(100, 100)
	a["geo.clamp.SetClampedToScreen"] = (askm(clamp, "SetClampedToScreen", true))
	clamp:SetPoint("CENTER", UI, "CENTER", 50000, 0)
	clamp:Show()
	local function readClamp(tag)
		local sig, r = askm(clamp, "GetLeft")
		local uw = (select(2, askm(UI, "GetWidth")) or {})[1]
		local class = "none"
		if r and r.n >= 1 and type(r[1]) == "number" and type(uw) == "number" then
			class = r[1] > uw and "offscreen" or "onscreen"
		elseif r and r.n == 0 then class = "no value" end
		a["geo.clamp." .. tag] = class
	end
	readClamp("now")
	later("frame", function() readClamp("frame1") end)
	later(0.3, function() readClamp("t0.3") end)

	-- units under SetScale(2): the ratio of GetLeft (and of the scaled rect) to the 100 asked for
	local sc = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = sc
	sc:SetSize(50, 50)
	sc:SetScale(2)
	sc:SetPoint("TOPLEFT", UI, "TOPLEFT", 100, -100)
	sc:Show()
	local function readScale(tag)
		local _, rl = askm(sc, "GetLeft")
		local _, rr = askm(sc, "GetScaledRect")
		local _, re = askm(sc, "GetEffectiveScale")
		local es = re and tonumber(re[1]) or nil
		a["geo.scale." .. tag .. ".leftRatio"] = (rl and rl.n >= 1 and type(rl[1]) == "number") and tostring(r2(rl[1] / 100)) or "none"
		a["geo.scale." .. tag .. ".scaledRectRatio"] = (rr and rr.n >= 1 and type(rr[1]) == "number" and es and es > 0) and tostring(r2(rr[1] / (100 * es))) or "none"
		local _, ru = askm(UI, "GetEffectiveScale")
		a["geo.scale." .. tag .. ".scaleFromParent"] = (es and ru and tonumber(ru[1]) and tonumber(ru[1]) > 0) and tostring(r2(es / tonumber(ru[1]))) or "none"
	end
	readScale("now")
	later("frame", function() readScale("frame1") end)

	-- valid strata and levels
	local lv = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = lv
	for _, name in ipairs(STRATA) do
		local ok, err = pcall(lv.SetFrameStrata, lv, name)
		a["strata." .. name] = ok and ("ok:" .. tostring(lv:GetFrameStrata())) or "error"
		if not ok then a["strata." .. name .. ".err"] = short(err, 100) end
	end
	pcall(lv.SetFrameStrata, lv, "MEDIUM")
	for _, n in ipairs(LEVELS) do
		local ok, err = pcall(lv.SetFrameLevel, lv, n)
		local after = ok and select(2, askm(lv, "GetFrameLevel")) or nil
		a["level." .. n] = ok and ("ok:" .. tostring(after and after[1])) or "error"
		if not ok then a["level." .. n .. ".err"] = short(err, 100) end
	end
	local child = env.CreateFrame("Frame", nil, lv)
	s.frames[#s.frames + 1] = child
	a["level.child-minus-parent"] = tostring((child:GetFrameLevel() or 0) - (lv:GetFrameLevel() or 0))
end

---------------------------------------------------------------------------
-- 5: text
---------------------------------------------------------------------------

local function section5(env, a, s, opts)
	local okF, fs = pcall(s.vis.CreateFontString, s.vis, nil, "OVERLAY", "GameFontNormal")
	if not okF or not fs then a["text"] = "error: no font string" return end
	local sig, r = askm(fs, "GetText")
	a["text.GetText.fresh"] = sig .. (r and r.n >= 1 and (":" .. typ(r[1])) or "")
	pcall(fs.SetText, fs, "")
	sig, r = askm(fs, "GetText")
	a["text.GetText.afterEmpty"] = sig .. (r and r.n >= 1 and (":" .. typ(r[1]) .. ":" .. tostring(#tostring(r[1]))) or "")
	local ok, err = pcall(fs.SetText, fs, nil)
	a["text.SetText.nil"] = ok and "ok" or "error"
	if not ok then a["text.SetText.nil.err"] = short(err, 100) end
	sig, r = askm(fs, "GetText")
	a["text.GetText.afterNil"] = sig .. (r and r.n >= 1 and (":" .. typ(r[1])) or "")
	-- SetFont: return values for Wuber's files, a missing file, and the game's own
	local fonts = opts.fonts or {}
	local files = { arial = "Fonts\\ARIALN.TTF", missing = "Interface\\AddOns\\Wuber\\Media\\fonts\\NoSuchFileForTheCensus.ttf",
		regular = fonts.regular, medium = fonts.medium, bold = fonts.bold }
	for _, key in ipairs({ "arial", "regular", "medium", "bold", "missing" }) do
		local file = files[key]
		if type(file) == "string" then
			local g = s.vis:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			local sg, rg, msg = askm(g, "SetFont", file, 16, "")
			put(a, "text.SetFont." .. key, sg .. (rg and rg.n >= 1 and (":" .. tostring(rg[1])) or ""), msg)
			local sf, rf = askm(g, "GetFont")
			a["text.GetFont." .. key] = sf .. (rf and rf.n >= 1 and (":" .. typ(rf[1]) .. ":" .. tostring(rf[1] == file)) or "")
		else
			a["text.SetFont." .. key] = "no file given"
		end
	end
	-- the height of one line against the font size, for each of Wuber's fonts (and the game's)
	for _, key in ipairs({ "arial", "regular", "medium", "bold" }) do
		local file = files[key]
		if type(file) == "string" then
			for _, size in ipairs(opts.fontSizes or { 12, 16, 22 }) do
				local g = s.vis:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				local okS = pcall(g.SetFont, g, file, size, "")
				if okS then
					pcall(g.SetWidth, g, 0)
					pcall(g.SetText, g, "Ag")
					local _, rh = askm(g, "GetStringHeight")
					local _, rw = askm(g, "GetStringWidth")
					a["text.line." .. key .. "." .. size] = (rh and rh[1] and tostring(r2(rh[1] / size)) or "none") .. " / width " .. (rw and rw[1] and tostring(r2(rw[1] / size)) or "none")
				end
			end
		end
	end
	-- SetMaxLines(0): three lines in a 200-wide string
	local g = s.vis:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pcall(g.SetWidth, g, 200)
	pcall(g.SetText, g, "one\ntwo\nthree")
	local _, h0 = askm(g, "GetStringHeight")
	local base = h0 and h0[1]
	for _, n in ipairs({ 0, 1, 2 }) do
		local okM, errM = pcall(g.SetMaxLines, g, n)
		local _, hh = askm(g, "GetStringHeight")
		local _, tr = askm(g, "IsTruncated")
		local _, gm = askm(g, "GetMaxLines")
		a["text.MaxLines." .. n] = (okM and "ok" or ("error " .. short(errM, 60))) .. " heightRatio " .. ((hh and hh[1] and base and base > 0) and tostring(r2(hh[1] / base)) or "none")
			.. " truncated " .. tostring(tr and tr[1]) .. " GetMaxLines " .. tostring(gm and gm[1])
	end
end

---------------------------------------------------------------------------
-- 6: texture calls
---------------------------------------------------------------------------

local function section6(env, a, s)
	local ok, tex = pcall(s.vis.CreateTexture, s.vis, nil, "ARTWORK")
	if not ok or not tex then a["tex"] = "error" return end
	a["tex.type.SetGradient"], a["tex.type.SetGradientAlpha"] = typ(tex.SetGradient), typ(tex.SetGradientAlpha)
	local cc = field(env, "CreateColor")
	local c0, c1
	if type(cc) == "function" then c0, c1 = cc(1, 0, 0, 0), cc(1, 0, 0, 1) end
	local sig, _, msg = askm(tex, "SetGradient", "VERTICAL", c0, c1)
	put(a, "tex.SetGradient", sig, msg)
	sig, _, msg = askm(tex, "SetGradientAlpha", "VERTICAL", 1, 0, 0, 0, 1, 0, 0, 1)
	put(a, "tex.SetGradientAlpha", sig, msg)
	sig, _, msg = askm(tex, "SetTexCoord", 0, 1, 0, 1)
	put(a, "tex.SetTexCoord4", sig, msg)
	sig, _, msg = askm(tex, "SetTexCoord", 0, 0, 0, 1, 1, 0, 1, 1)
	put(a, "tex.SetTexCoord8", sig, msg)
	local sg, rg = askm(tex, "GetTexCoord")
	a["tex.GetTexCoord"] = sg
	sig, _, msg = askm(tex, "SetRotation", 1.0)
	put(a, "tex.SetRotation", sig, msg)
	local sr, rr = askm(tex, "GetRotation")
	a["tex.GetRotation"] = sr .. (rr and rr.n >= 1 and (":" .. tostring(r2(tonumber(rr[1]) or -1))) or "")
end

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------

function M.run(env, done, opts)
	opts = opts or {}
	M.cleanup()
	local a = {}
	local s = { frames = {}, clock = 0, tasks = {} }
	state = s
	local function holder(shown)
		local h = env.CreateFrame("Frame", nil, env.UIParent)
		h:SetSize(1, 1)
		h:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 0, 0)
		h:SetFrameStrata("BACKGROUND")
		if shown then h:Show() else h:Hide() end
		return h
	end
	s.vis, s.hid = holder(true), holder(false)
	-- the clock of the timed readings: one OnUpdate on a shown holder child
	local waiter = env.CreateFrame("Frame", nil, s.vis)
	s.frames[#s.frames + 1] = waiter
	waiter:Show()
	local function later(when, fn) s.tasks[#s.tasks + 1] = { at = (when == "frame") and -1 or (s.clock + when), fn = fn } end
	local finished = false
	local function finish()
		if finished then return end
		finished = true
		M.cleanup()
		a["census.done"] = "yes"
		if done then pcall(done, a) end
	end
	waiter:SetScript("OnUpdate", function(_, elapsed)
		if finished then return end
		s.clock = s.clock + (tonumber(elapsed) or 0)
		local keep = {}
		for _, t in ipairs(s.tasks) do
			if t.at <= s.clock then pcall(t.fn) else keep[#keep + 1] = t end
		end
		s.tasks = keep
		if #keep == 0 then finish() end
	end)
	for _, step in ipairs({
		function() section1(env, a) end, function() section2(env, a) end,
		function() section3(env, a, s, opts.events or M.EVENTS) end,
		function() section4(env, a, s, later) end,
		function() section5(env, a, s, opts) end, function() section6(env, a, s) end,
	}) do
		local ok, err = pcall(step)
		if not ok then
			s.errs = (s.errs or 0) + 1
			a["census.err." .. s.errs] = short(err, 160)
		end
	end
	-- the run ends when the last timed reading is in (the one after 0.3 s); this empty task keeps it open until then even if none was booked
	later(0.4, function() end)
	return a
end

if type(ns) == "table" then ns.CensusCore = M end
return M
