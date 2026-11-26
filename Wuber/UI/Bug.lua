-- Module: UI.Bug
-- Purpose: /wuber bug (and "Report a bug" in Settings and Help): a full-height sheet over the phone (T.Sheet; the
--   window opens first when it is closed) with a ready-made bug
--   report in a copy box (version, game build, UI scale, folded, role, class and level, open or closed, the last 10 errors
--   and the last 20 events, the settings that differ from their defaults, and the other loaded addons) and a box for what happened. Other players' names become "player 1",
--   "player 2"; nothing from chat; nothing is ever sent: the player copies it to CurseForge.
-- API: UI.Bug, UI.Bug.Open, UI.Bug.Close, UI.Bug.Shown, UI.Bug.Report
-- Internals: names, anonymise, ago, line, shownName, build, frame
-- Uses: UI.Kit
-- Later: UI.Fold (IsUnfolded), UI.Window (UI.IsShown), Drive.Core (DR.Role), Drive.Careful (DR.OopsLog), Net.Beacons (W.DriverBeacon)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/bug_test.lua
-- From: new in Wuber 2.3.2 (BRIEF19 R3)
--
-- The logs are Core.Runtime's W.errorLog ({ at, where, text, n }) and W.blockedAt ({ at, func, where, n, guess }: the last 5 blocked actions and the Wuber file:line under the call; guess = taken from the last breadcrumb) and W.crumbs ({ at, tag, where, n }: the last 5 Wuber calls the game may refuse) and W.eventLog ({ at, name, n }:
-- W.Fire names only, never their values); the report shows RITUAL as SUMMON PORTAL (shownName). W.debugLog is not used (it holds advert texts).
-- UI.Bug.Report(note) -> the report text (note: what happened, as typed). UI.Bug.frame: the window
-- (a T.Sheet: f.note, f.copy: T.Field; f.select: the main button, f.close: the x; f.holder: the frame WuberBug it sits in), built on the first open.

local _, W = ...
local Mod = W.Module("UI.Bug", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local call = KitMod.call
local safeScript = KitMod.safeScript
local T = W.Theme
local Try = T.Try
local UI = W.UI

local Bug = {}
UI.Bug = Bug

local WHERE = "Paste it in the comments on Wuber's CurseForge page."
local HOW = "Copy this (Select all, Ctrl+C) and paste it in the comments on Wuber's CurseForge page. Nothing is sent; players' names are left out."
local HOW_OOPS = HOW .. " It includes the chat lines you marked as wrong invites, with names removed."
local SIZE = { w = 420, h = 486, inner = 380 }

---------------------------------------------------------------------------
-- Names: every other player becomes "player N" (the same name, the same N); you are "me"
---------------------------------------------------------------------------

-- the fields that hold a player's name in Wuber's tables (never "service": a driver's own words)
local NAME_FIELDS = { name = true, addr = true, driver = true, driverKey = true, buyer = true, buyerKey = true,
	summoner = true, caster = true, captain = true, key = true }

local function plain(v)
	v = W.Plain(v)
	if type(v) ~= "string" then return nil end
	v = v:gsub("^%s+", ""):gsub("%s+$", "")
	-- (review) two-letter names too: they only match whole and capitalised (anonymise)
	if #v < 2 or #v > 60 then return nil end
	return v
end

-- the person a written name stands for (W.Key: lower case, one form whatever the separator)
local function canon(v)
	local k = type(W.Key) == "function" and call(W.Key, v) or nil
	k = type(k) == "string" and k or v:lower()
	return (k:gsub("[%s%-]+", " "))
end

-- every name Wuber holds now: drivers, requests, the ride, trips, favourites, crew, the group
local function names()
	local found, list = {}, {}
	local function add(v)
		v = plain(v)
		if not v or found[v] then return end
		found[v] = true
		list[#list + 1] = v
	end
	-- t's name fields, and those of the tables in it down to `depth` levels (keys too when keysAreNames)
	local function walk(t, depth, keysAreNames)
		if type(t) ~= "table" then return end
		for k, v in pairs(t) do
			if keysAreNames and type(k) == "string" then add(k) end
			if type(v) == "string" and NAME_FIELDS[k] then add(v)
			elseif type(v) == "table" and depth > 0 then walk(v, depth - 1, false) end
		end
	end
	walk(W.drivers, 1, true)
	walk(W.incoming, 1, false)
	walk(W.ride, 1, false)
	local db = W.db
	if type(db) == "table" then
		walk(db.rides, 1, false)
		walk(db.favs, 0, true)
		walk(db.hidden, 0, true)
		walk(db.directory, 1, true)
	end
	local ok, c = pcall(W.Char)
	if ok and type(c) == "table" then
		walk(c.crew, 1, false)
		add(c.captain)
		add(c.caster)
		walk(c.queue, 2, false)
		-- (H24-11) the rank count's riders: [key] = day, the key is the rider's name
		if type(c.rank) == "table" then walk(c.rank.seen, 0, true) end
	end
	local DR = W.Drive
	if type(DR) == "table" then
		-- the driver's riders and group: [key] = customer, unit, crew window
		walk(DR.customers, 1, true)
		walk(DR.units, 0, true)
		walk(DR.peers, 0, true)
		walk(DR.apps, 0, true)
		walk(DR.attempts, 0, true)
	end
	if type(UnitName) == "function" then
		for i = 1, 4 do add(W.UnitName("party" .. i)) end
		if type(GetNumGroupMembers) == "function" and type(IsInRaid) == "function" and call(IsInRaid) then
			for i = 1, math.min(40, tonumber(call(GetNumGroupMembers)) or 0) do add(W.UnitName("raid" .. i)) end
		end
	end
	return list
end

-- the forms a name is written in: as held, with a space or a hyphen, and the first name alone
local function variants(list, me)
	local out, seen = {}, {}
	local function put(text, id)
		local low = text:lower()
		if #low < 2 or seen[low] then return end
		seen[low] = true
		out[#out + 1] = { low = low, id = id, short = #low <= 2 }
	end
	local function forms(v, id)
		put(v, id)
		put((v:gsub("%-", " ")), id)
		put((v:gsub(" ", "-")), id)
		local first = v:match("^([^%s%-]+)")
		if first then put(first, id) end
	end
	if me then forms(me, "me") end
	for _, v in ipairs(list) do
		local id = canon(v)
		local first = canon(v):match("^(%S+)")
		-- "Anita" and "Anita Lift" are one person: the full name's id wins
		forms(v, id)
		if first and first ~= id then
			for _, x in ipairs(out) do if x.low == first and x.id ~= "me" then x.id = id end end
		end
	end
	-- the longest first, so "Anita Lift" is taken before "Anita"
	table.sort(out, function(a, b) if #a.low ~= #b.low then return #a.low > #b.low end return a.low < b.low end)
	return out
end

local function isWordByte(c) return c ~= nil and c ~= "" and (c:match("[%w_]") ~= nil or c:byte() > 127) end

-- text with each name replaced; ctx = { vars, ids = { [id] = n }, n } shared by the whole report
-- a tail after "Name-": a capitalised word (a realm or surname) or what W.IsRealmTail accepts (digits, CAMWOW)
local function realmWord(tail)
	if not tail or tail == "" then return false end
	-- (a short tail such as the 1 of "Alt-1" or the 2 of "Wuber-2" is no realm: a server node is long and holds letters)
	return tail:find("^%u%l") ~= nil or (#tail >= 5 and tail:find("%a") ~= nil and W.IsRealmTail(tail))
end

local function anonymise(text, ctx)
	text = tostring(text or "")
	if text == "" then return text end
	local low, out, pos = text:lower(), {}, 1
	while pos <= #text do
		local bestS, bestE, bestId
		for _, v in ipairs(ctx.vars) do
			local from = pos
			while true do
				local s, e = low:find(v.low, from, true)
				if not s then break end
				-- whole words only; a two-letter name only where it is written with a capital ("Al", never "al")
				if not isWordByte(low:sub(s - 1, s - 1)) and not isWordByte(low:sub(e + 1, e + 1))
					and (not v.short or text:sub(s, s):match("%u")) then
					if not bestS or s < bestS then bestS, bestE, bestId = s, e, v.id end
					break
				end
				from = s + 1
			end
		end
		if not bestS then break end
		out[#out + 1] = text:sub(pos, bestS - 1)
		if bestId == "me" then
			out[#out + 1] = "me"
		else
			if not ctx.ids[bestId] then
				ctx.n = ctx.n + 1
				ctx.ids[bestId] = ctx.n
			end
			out[#out + 1] = "player " .. ctx.ids[bestId]
		end
		pos = bestE + 1
		-- "Name-Realm": the realm goes with the name
		local realm = text:match("^%-[%u%d][%w\128-\255']*", pos)
		if realm and not realmWord(realm:sub(2)) then realm = nil end
		if realm and not isWordByte(text:sub(pos + #realm, pos + #realm)) then pos = pos + #realm end
	end
	out[#out + 1] = text:sub(pos)
	return table.concat(out)
end

-- (review) in error lines, anything shaped like Name-Realm ("Zed-Argent": a capitalised word, a
-- hyphen, a capitalised word) is a player too, even one in none of Wuber's tables
local NAME_REALM = "()(%u%l[%w\128-\255']*%-[%u%d][%w\128-\255']*)()"

local function anonymiseRealms(text, ctx)
	return (text:gsub(NAME_REALM, function(s, word, e)
		if isWordByte(text:sub(s - 1, s - 1)) or isWordByte(text:sub(e, e)) or text:sub(e, e) == "-" then return nil end
		if not realmWord(word:match("%-(.*)$")) then return nil end
		local id = canon(word)
		if not ctx.ids[id] then
			ctx.n = ctx.n + 1
			ctx.ids[id] = ctx.n
		end
		return "player " .. ctx.ids[id]
	end))
end

---------------------------------------------------------------------------
-- The report
---------------------------------------------------------------------------

local function ago(at)
	local now = type(GetTime) == "function" and (tonumber(GetTime()) or 0) or 0
	local s = math.max(0, math.floor(now - (tonumber(at) or now) + 0.5))
	if s < 60 then return s .. " s ago" end
	if s < 3600 then return math.floor(s / 60) .. " min ago" end
	return math.floor(s / 3600) .. " h ago"
end

-- one line: no colour codes, no line breaks, at most 200 characters
local function line(text)
	text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n\t]+", " ")
	if #text > 200 then text = text:sub(1, 197) .. "..." end
	return text
end

-- Internal event names stay as they are; the report shows the old summoning addon's word as
-- SUMMON PORTAL (RITUAL), SUMMON_PORTAL inside a longer name (DRIVE_RITUAL).
local function shownName(name)
	name = tostring(name or "")
	if name:find("^[Rr][Ii][Tt][Uu][Aa][Ll]$") then return "SUMMON PORTAL" end
	return (name:gsub("[Rr][Ii][Tt][Uu][Aa][Ll]", "SUMMON_PORTAL"))
end

local function gameBuild()
	if type(GetBuildInfo) ~= "function" then return "unknown" end
	local ok, version, build, _, iface = pcall(GetBuildInfo)
	if not ok then return "unknown" end
	version, build, iface = W.Plain(version), W.Plain(build), W.Plain(iface)
	local parts = {}
	if version then parts[#parts + 1] = tostring(version) end
	if build then parts[#parts + 1] = "build " .. tostring(build) end
	if iface then parts[#parts + 1] = "interface " .. tostring(iface) end
	return #parts > 0 and table.concat(parts, ", ") or "unknown"
end

local function round2(v)
	v = tonumber(v)
	if not v then return "unknown" end
	return string.format("%.2f", v)
end

local function uiScale()
	local u = UIParent
	local game = u and call(u.GetEffectiveScale, u)
	local db = W.db
	local own = type(db) == "table" and tonumber(db.scale) or nil
	local w, h = u and tonumber((call(u.GetWidth, u))), u and tonumber((call(u.GetHeight, u)))
	local screen = (w and h) and (" · screen " .. math.floor(w + 0.5) .. " x " .. math.floor(h + 0.5)) or ""
	return round2(game) .. " · Wuber window " .. (own and round2(own) or "auto") .. screen
end

local ROLES = { driver = "driver", helper = "crew", alert = "alert character" }

local function role()
	local DR = W.Drive
	local r = type(DR) == "table" and type(DR.Role) == "function" and call(DR.Role) or nil
	return ROLES[r] or "rider", r
end

local function service(r)
	if r ~= "driver" and r ~= "helper" then return "not driving" end
	local b = type(W.DriverBeacon) == "function" and call(W.DriverBeacon) or nil
	if type(b) ~= "table" then return "closed" end
	local s = W.Plain(b.state)
	return (type(s) == "string" and s ~= "" and s ~= "open") and ("open (" .. s .. ")") or "open"
end

local function rideLine()
	local r = W.ride
	local s = type(r) == "table" and W.Plain(r.state) or nil
	return type(s) == "string" and s or "none"
end

local function oopsLines()
	local DR = W.Drive
	local list = type(DR) == "table" and type(DR.OopsLog) == "function" and call(DR.OopsLog, 10) or nil
	if type(list) ~= "table" or #list == 0 then return nil end
	return list
end

-- (Polestar 20) the settings that differ from their defaults, key = value, and the other loaded addons' folder names.
-- Only booleans and numbers (and the effects level and "advanced") are listed: tables, names, places and every other
-- text (service, destination, crew, captain, caster, badge) are left out, so nothing personal reaches the report.
local SAY_NIL = { advanced = true, scale = true }
local SAY_TEXT = { fx = true }
local SKIP = { minimapAngle = true, advertAt = true }

local function changedLines(db, defaults, out)
	if type(db) ~= "table" then return end
	local keys = {}
	for k in pairs(defaults) do keys[#keys + 1] = k end
	for k in pairs(SAY_NIL) do if defaults[k] == nil then keys[#keys + 1] = k end end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v, d = db[k], defaults[k]
		local t = type(v)
		local kind = t == "boolean" or t == "number" or (t == "string" and SAY_TEXT[k])
		if kind and not SKIP[k] and v ~= d and (d ~= nil or SAY_NIL[k]) then out[#out + 1] = "  " .. k .. " = " .. tostring(v) end
	end
end

local function settingsLines()
	local out = {}
	pcall(changedLines, W.db, W.DEFAULTS, out)
	local ok, c = pcall(W.Char)
	if ok then pcall(changedLines, c, W.CHAR_DEFAULTS, out) end
	if #out == 0 then out[1] = "  none" end
	return out
end

local function addonNames()
	local C = type(C_AddOns) == "table" and C_AddOns or nil
	local num = C and C.GetNumAddOns
	local info = C and C.GetAddOnInfo
	local loaded = C and C.IsAddOnLoaded or IsAddOnLoaded
	if type(num) ~= "function" or type(info) ~= "function" or type(loaded) ~= "function" then return nil end
	local okn, n = pcall(num)
	if not okn or type(tonumber(n)) ~= "number" then return nil end
	local names = {}
	for i = 1, okn and tonumber(n) or 0 do
		local oki, name = pcall(info, i)
		local okl, on = pcall(loaded, oki and name or i)
		if oki and okl and type(name) == "string" and on and name ~= "Wuber" and not name:find("^Blizzard_") then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- (Polestar 20) "WARLOCK level 60": the class file token and the level, never a name; "unknown" when the game gives none
local function characterLine()
	local okc, _, file = pcall(function() return UnitClass("player") end)
	local okl, level = pcall(function() return UnitLevel("player") end)
	file, level = okc and W.Plain(file), okl and tonumber(W.Plain(level))
	if type(file) == "string" and file:find("^%u+$") and level and level > 0 then
		return file .. " level " .. math.floor(level)
	end
	return "unknown"
end

local function build(note)
	local me = type(W.Me) == "function" and call(W.Me) or nil
	local ctx = { vars = variants(names(), plain(me)), ids = {}, n = 0 }
	local out = {}
	local function add(t) out[#out + 1] = t end
	local F = UI.Fold
	local unfolded = type(F) == "table" and type(F.IsUnfolded) == "function" and call(F.IsUnfolded) == true
	local shown = type(UI.IsShown) == "function" and call(UI.IsShown) == true
	local roleName, r = role()
	add("Wuber bug report")
	add("Wuber " .. tostring(W.VERSION or "?"))
	add("Game build: " .. gameBuild())
	add("UI scale: " .. uiScale())
	add("Window: " .. (shown and "open" or "closed") .. ", " .. (unfolded and "unfolded" or "folded"))
	add("Role: " .. roleName)
	add("Character: " .. characterLine())
	add("Service: " .. service(r))
	add("Ride: " .. rideLine())
	add("")
	add("What happened:")
	local n = tostring(note or ""):gsub("^%s+", ""):gsub("%s+$", "")
	add(n ~= "" and anonymiseRealms(anonymise(n, ctx), ctx) or "(not filled in)")
	add("")
	add("Errors (last 10):")
	local errs = type(W.errorLog) == "table" and W.errorLog or {}
	if #errs == 0 then add("  none") end
	for i = math.max(1, #errs - 9), #errs do
		local e = errs[i]
		add("  " .. ago(e.at) .. "  " .. anonymiseRealms(anonymise(line(shownName(e.where) .. ": " .. tostring(e.text)), ctx), ctx)
			.. ((e.n or 1) > 1 and (" (x" .. e.n .. ")") or ""))
	end
	add("")
	add("Events (last 20):")
	local evs = type(W.eventLog) == "table" and W.eventLog or {}
	if #evs == 0 then add("  none") end
	for i = math.max(1, #evs - 19), #evs do
		local e = evs[i]
		add("  " .. ago(e.at) .. "  " .. anonymise(line(shownName(e.name)), ctx) .. ((e.n or 1) > 1 and (" (x" .. e.n .. ")") or ""))
	end
	local blocked = type(W.blockedAt) == "table" and W.blockedAt or {}
	if #blocked > 0 then
		add("")
		add("Blocked actions (last 5, the Wuber code that made the call):")
		for _, b in ipairs(blocked) do
			add("  " .. ago(b.at) .. "  " .. anonymise(line(tostring(b.func) .. " from " .. tostring(b.where or "unknown")), ctx)
				.. (b.guess and " (the last Wuber call before it)" or "") .. ((b.n or 1) > 1 and (" (x" .. b.n .. ")") or ""))
		end
		local crumbs = type(W.crumbs) == "table" and W.crumbs or {}
		add("Wuber calls the game may refuse (last 5):")
		if #crumbs == 0 then add("  none recorded") end
		for _, c in ipairs(crumbs) do
			add("  " .. ago(c.at) .. "  " .. anonymise(line(tostring(c.tag) .. " from " .. tostring(c.where or "unknown")), ctx)
				.. ((c.n or 1) > 1 and (" (x" .. c.n .. ")") or ""))
		end
	end
	local oops = oopsLines()
	if oops then
		add("")
		add("Wrong invites (last 10):")
		for _, s in ipairs(oops) do
			add("  " .. anonymiseRealms(anonymise(line(s), ctx), ctx))
		end
	end
	add("")
	add("Changed settings:")
	for _, s in ipairs(settingsLines()) do add(s) end
	local others = addonNames()
	add("")
	if others then
		add("Other addons: " .. #others .. " loaded")
		if #others > 0 then add("  " .. table.concat(others, ", ")) end
	else
		add("Other addons: unknown")
	end
	return table.concat(out, "\n")
end

function Bug.Report(note)
	local ok, text = pcall(build, note)
	if ok then return text end
	W.Error("bug report", text)
	return "Wuber " .. tostring(W.VERSION or "?") .. "\n(the report could not be made)"
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function selectAll(f)
	local eb = f and f.copy and f.copy.edit
	if not eb then return end
	pcall(eb.SetFocus, eb)
	pcall(eb.HighlightText, eb)
end

-- (Design 2) the report is a full-height sheet over the phone (T.Sheet): the title "Report a bug" and the x, the
-- words, the two boxes, and "Select all" as the one main button. Its holder is the global frame WuberBug (Escape
-- closes it); the holder only shows while the sheet does.
-- (E3b-09) the room under the sheet: the tab bar's height, or 0 while the bar is away (the live ride page)
local function sheetFoot()
	if type(UI.TabsHidden) == "function" and UI.TabsHidden() then return 0 end
	return UI.TABBAR_H or 56
end

-- (H24-02) a page's big title (display size, from 47 below the window's top) can straddle the header zone's foot: the card
-- then starts under that title's foot, so its edge never cuts the title in two. No such title: the card starts at the foot.
local function titleDrop(f)
	local win = f.win
	local wt = win and win.GetTop and tonumber(win:GetTop())
	if not wt then return 0 end
	local head, drop, seen = UI.HEAD_H or 56, 0, {}
	local function walk(fr, depth)
		if seen[fr] or fr == f.holder or depth > 8 then return end
		seen[fr] = true
		for _, r in ipairs({ fr:GetRegions() }) do
			local size = r.GetFont and select(2, r:GetFont())
			local shown = r.GetText and r:GetText() and r:GetText() ~= "" and (r.IsVisible and r:IsVisible())
				and (tonumber(size) or 0) >= (T.SIZE and T.SIZE.display or 28)
			local t, b = shown and tonumber(r:GetTop()), shown and tonumber(r:GetBottom())
			if t and b then
				t, b = wt - t, wt - b
				if t < head - 0.5 and b > head + 0.5 and b - head > drop then drop = b - head end
			end
		end
		for _, c in ipairs({ fr:GetChildren() }) do walk(c, depth + 1) end
	end
	walk(win, 0)
	return math.ceil(drop)
end

local function layout(f)
	local w = f.win
	local h = (tonumber((w and w:GetHeight())) or SIZE.h) - (UI.HEAD_H or 56) - sheetFoot() - titleDrop(f)
	f:SetSheetHeight(math.max(300, h))
	-- (r49) the words have no height of their own: they take what their lines need at the width they have, and the labels,
	-- boxes and copy box hang from them, so a fold or an unfold under the sheet never leaves the words cut with "..."
	f.how:SetText(f.hasOops and HOW_OOPS or HOW)
	f.noteLbl:ClearAllPoints()
	f.noteLbl:SetPoint("TOPLEFT", f.how, "BOTTOMLEFT", 0, -12)
	f.noteLbl:SetPoint("TOPRIGHT", f.how, "BOTTOMRIGHT", 0, -12)
	f.note:ClearAllPoints()
	f.note:SetPoint("TOPLEFT", f.noteLbl, "TOPLEFT", 0, -16)
	f.note:SetPoint("TOPRIGHT", f.noteLbl, "TOPRIGHT", 0, -16)
	f.note:SetHeight(64)
	f.copyLbl:ClearAllPoints()
	f.copyLbl:SetPoint("TOPLEFT", f.note, "BOTTOMLEFT", 0, -12)
	f.copyLbl:SetPoint("TOPRIGHT", f.note, "BOTTOMRIGHT", 0, -12)
	f.copy:ClearAllPoints()
	f.copy:SetPoint("TOPLEFT", f.copyLbl, "TOPLEFT", 0, -16)
	f.copy:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -16, 4)
end

local function refresh(f)
	local hasOops = oopsLines() ~= nil
	if f.hasOops ~= hasOops then
		f.hasOops = hasOops
		layout(f)
	end
	f.text = Bug.Report(f.note:Text())
	f.copy:SetText(f.text)
end

local function label(parent, text)
	local fs = T.Text(parent, "caption", "white", "LEFT", "bold")
	fs:SetText(text)
	return fs
end

-- (E3b-01) the holder is the whole screen from the window's top down to the tab bar (or the foot): the dim lies over
-- the page whole, the header zone too, so no page row is cut by the sheet's edge; the dim's header strip takes no
-- mouse (T.Sheet opts.head), so the header's buttons (fold, x, Wide, back) stay usable
local function place(f)
	local holder, win = f.holder, f.win
	f.foot = sheetFoot()
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
	holder:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, f.foot)
end

local function frame()
	local win = KitMod.ui.win
	if not win then return nil end
	if Bug.frame and Bug.frame.win == win then return Bug.frame end
	local holder = CreateFrame("Frame", "WuberBug", win)
	-- (design 2) the tabs stay free below it; (E3b-01) the header buttons stay free through the dim's top strip
	-- (R49-7) DIALOG: the lifted big Drive button (FULLSCREEN_DIALOG) stays over the dim; the header buttons are lifted over it
	holder:SetFrameStrata("DIALOG")
	holder:SetFrameLevel(400)
	holder:Hide()
	local f = T.Sheet(holder, SIZE.h, "Report a bug", { head = UI.HEAD_H or 56 })
	f.win, f.holder = win, holder
	place(f)
	Bug.frame = f
	-- a tab click closes the report as its x would
	local tab
	holder:SetScript("OnUpdate", function()
		if not f.open then tab = nil return end
		if f.foot ~= sheetFoot() then place(f) layout(f) end
		if tab == nil then tab = KitMod.ui.tab or false end
		if (KitMod.ui.tab or false) ~= tab then tab = nil Bug.Close() end
	end)
	-- hidden any way (Close, Escape): the boxes let go of the keyboard
	holder:SetScript("OnHide", function()
		f.open = false
		f:Hide()
		if f.note then pcall(f.note.edit.ClearFocus, f.note.edit) end
		if f.copy then pcall(f.copy.edit.ClearFocus, f.copy.edit) end
	end)
	f:SetScript("OnHide", function() holder:Hide() f:HeadDown() end)
	if type(UISpecialFrames) == "table" and not W.GamepadUI() then table.insert(UISpecialFrames, "WuberBug") end -- (PST-01 B)
	local host = f.body
	f.how = T.Text(host, "caption", "muted", "LEFT", "regular")
	f.how:SetPoint("TOPLEFT", host, "TOPLEFT", 16, -4)
	f.how:SetPoint("TOPRIGHT", host, "TOPRIGHT", -16, -4)
	Try(f.how, "SetWordWrap", true)
	f.how:SetText(HOW)
	f.hasOops = false
	f.noteLbl = label(host, "What happened?")
	f.note = T.Field(host, SIZE.inner, 64, { multi = true, max = 500, size = "caption",
		placeholder = "What did you do, and what went wrong?",
		onChange = function() refresh(f) end,
		onEscape = function() Bug.Close() end })
	T.Tip(f.note.edit, "What happened?", "Type what you did and what went wrong. It goes into the report below. Names are left out.")
	f.copyLbl = label(host, "Your report")
	f.copy = T.Field(host, SIZE.inner, 218, { multi = true, max = 6000, size = "caption",
		get = function() return f.text or "" end,
		-- read-only: anything typed or pasted puts the report back, all selected
		onChange = function() f.copy:SetText(f.text or "") selectAll(f) end,
		onEscape = function() Bug.Close() end })
	Try(f.copy.inner, "SetClipsChildren", true)
	pcall(f.copy.edit.HookScript, f.copy.edit, "OnEditFocusGained", function(self) pcall(self.HighlightText, self) end)
	pcall(f.copy.edit.HookScript, f.copy.edit, "OnMouseUp", function(self) pcall(self.HighlightText, self) end)
	T.Tip(f.copy.edit, "Your report", "Click it to select it all, then press Ctrl+C to copy. " .. WHERE)
	f.select = f:MainButton("Select all", function() selectAll(f) end,
		"Selects the whole report. Then press Ctrl+C to copy it. " .. WHERE)
	f.onClose = function() pcall(f.note.edit.ClearFocus, f.note.edit) pcall(f.copy.edit.ClearFocus, f.copy.edit) end
	layout(f)
	return f
end

-- Opens the report with a fresh text, the report selected (Ctrl+C copies it). The window opens first when it is closed.
function Bug.Open()
	local ui = KitMod.ui
	if ui.win and not ui.win:IsShown() and UI.Toggle then call(UI.Toggle, true) end
	local f = frame()
	if not f then return false end
	f.note:SetText("")
	f.hasOops = nil
	place(f)
	layout(f)
	refresh(f)
	f:Open()
	f.holder:Show()
	selectAll(f)
	return true
end

function Bug.Close()
	local f = Bug.frame
	if not f then return end
	pcall(f.note.edit.ClearFocus, f.note.edit)
	pcall(f.copy.edit.ClearFocus, f.copy.edit)
	f:Close()
end

function Bug.Shown() return Bug.frame ~= nil and Bug.frame.open == true and Bug.frame.holder:IsShown() == true end
