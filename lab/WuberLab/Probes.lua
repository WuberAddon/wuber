-- Wuber Lab (developer only, never ship): self-marking checks for Wuber 2.3.0's in-game probes
-- (SPEC7 section 10, items 1-10: what the harness can't prove). Same rules as Checks.lua (README
-- "How to add a check"): each check judges itself from what it can see - API presence and return
-- shapes, Wuber's own state and events, frame geometry - and where only the tester can judge it asks one
-- short Yes/No (check.ask, Run.lua). Every Wuber name is looked up at run time and nil-guarded.
--
-- Scenes:
--   probes8  loose checks (after the ride when both are in a run; the same window back to back):
--            pb_fold (1), pb_worldmap (2), pb_flight + pb_flycal (3; skipped when the character's
--            last flight map showed no place to fly to), pb_taxinode (4), pb_summoner (6),
--            pb_share_party / pb_share_raid / pb_share_combat (7), pb_bird (8), pb_gold + pb_violet (9)
--   rain8    the lag-drop raincheck, whole (10): paid by trade, closed before casting, ask, give,
--            accept, rebook free
-- Passive watchers (every window, from login): the summon box (CONFIRM_SUMMON: the game's summoner
-- and Wuber's gold/violet verdict), the arrival, the share button's macro and the group lines it
-- posted, combat and the last flight map (how many places this character can fly to from there).
-- (Round 17: the PvP probe (5) is gone, with its enemy nameplate watcher: the zone's PvP type is not
-- read any more. The lab never touches the combat log: the game no longer lets addons read it.)
-- What they saw is kept in WuberLabDB.probe8[character] (so a /reload keeps it); a check that
-- needs a moment that already happened (the ride's summon) reads it from there.

local _, L = ...

local str, num, call = L.str, L.num, L.call
local J = L.J

local P8 = { shares = {}, chat = {} } -- this session
L.probe8 = P8

-- this character's saved observations
local function store()
	local d, me = L.db, L.me
	if type(d) ~= "table" or not me then return nil end
	if type(d.probe8) ~= "table" then d.probe8 = {} end
	local s = d.probe8[me]
	if type(s) ~= "table" then
		s = {}
		d.probe8[me] = s
	end
	return s
end
L.Probe8Store = store

local function UIx()
	local W = L.W()
	return W and type(W.UI) == "table" and W.UI or nil
end
local function fold()
	local U = UIx()
	return U and type(U.Fold) == "table" and U.Fold or nil
end
local function share()
	local U = UIx()
	return U and type(U.Share) == "table" and U.Share or nil
end
-- another Wuber module's table (W.Mod), or nil
local function mod(name)
	local W = L.W()
	if not (W and type(W.Mod) == "function") then return nil end
	local m = call(W.Mod, name)
	return type(m) == "table" and m or nil
end
local function fn(t, name) return type(t) == "table" and type(t[name]) == "function" end
local function mmss(s)
	s = num(s)
	if not s then return "?" end
	s = math.floor(s + 0.5)
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end
local function shown(f) return type(f) == "table" and call(f.IsShown, f) == true end
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

-- the game's flight map that is showing (TaxiFrame, else FlightMapFrame)
local function taxiMap()
	for _, n in ipairs({ "TaxiFrame", "FlightMapFrame" }) do
		local f = rawget(_G, n)
		if shown(f) then return f, n end
	end
	return nil
end

-- a summon by the tester's founder (Anita) or a crew window
local function roleName(key)
	for _, role in ipairs(L.RUN_ROLE_ORDER or {}) do
		if J.key(role) == key then return L.RunShort(role) end
	end
	return nil
end

---------------------------------------------------------------------------
-- Passive watchers
---------------------------------------------------------------------------

-- The game's summon box: who it names, and Wuber's verdict for the portal (gold only for a
-- genuine founder's summon).
function L.Probe8Summon()
	local s = store()
	if not s then return end
	local SI = rawget(_G, "C_SummonInfo")
	local has = type(SI) == "table" and type(SI.GetSummonConfirmSummoner) == "function"
	local name = has and str(call(SI.GetSummonConfirmSummoner)) or nil
	local W = L.W()
	local r = J.ride()
	local rec = { at = L.Epoch(), has = has, name = name, sim = L.sim or nil }
	if r then
		rec.ride = str(r.id)
		rec.driver = str(r.driver) or str(r.driverKey)
		rec.gold = fn(W, "FounderSummon") and call(W.FounderSummon, r) == true or false
	end
	rec.founder = name and fn(W, "IsCreator") and call(W.IsCreator, name) == true or false
	rec.ruleset = fn(W, "OnFounderRuleset") and call(W.OnFounderRuleset) == true or false
	s.summon = rec
	L.Log("probe", ("summon box: %s names %s%s"):format(has and "GetSummonConfirmSummoner" or "no GetSummonConfirmSummoner",
		tostring(name), rec.gold ~= nil and (", portal " .. (rec.gold and "gold" or "violet")) or ""))
	L.Signal("probe8_summon", rec) -- (a step waiting for the summon box hears it)
end

-- The rider arrived: Wuber's arrival verdict (needs the game's summoner, W.ride.summonedBy).
function L.Probe8Arrival()
	local r = J.ride()
	if not r or J.rideRank(r.state) < J.rideRank("arrived") then return end
	local id = str(r.id) or "?"
	if P8.arrived == id then return end
	P8.arrived = id
	local s = store()
	if not s then return end
	local W = L.W()
	local by = str(r.summonedBy)
	s.arrival = { at = L.Epoch(), ride = id, by = by, driver = str(r.driver) or str(r.driverKey),
		gold = fn(W, "FounderSummon") and call(W.FounderSummon, r, "arrival") == true or false,
		founder = by and fn(W, "IsCreator") and call(W.IsCreator, by) == true or false, sim = L.sim or nil }
	L.Log("probe", ("arrival: summoned by %s, %s"):format(tostring(by), s.arrival.gold and "gold" or "violet"))
end

-- The share button: the macro it was armed with at the click (after Wuber's PreClick).
local function onSharePre(self, _, down)
	if down then return end
	local macro = str(call(self.GetAttribute, self, "macrotext")) or ""
	local rec = { t = L.Now(), macro = macro, raid = J.inRaid(), group = J.inGroup(), combat = L.InCombat() }
	P8.lastShareAt = rec.t
	P8.shares[#P8.shares + 1] = rec
	while #P8.shares > 20 do table.remove(P8.shares, 1) end
	L.Log("probe", ("share click: '%s'%s"):format(macro:sub(1, 60), rec.combat and " (in combat)" or ""))
	if rec.combat and macro ~= "" then P8.combatBad = "the share button was armed in combat: " .. macro:sub(1, 40) end
end

local function hookShare()
	if P8.shareHooked then return true end
	local b = rawget(_G, "WuberShareButton")
	if type(b) ~= "table" or type(b.HookScript) ~= "function" then return false end
	P8.shareHooked = pcall(b.HookScript, b, "PreClick", function(...) pcall(onSharePre, ...) end)
	return P8.shareHooked
end

-- my own lines in party or raid chat (what the share macro posted)
local GROUP_CHAT = { CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid" }
for ev, kind in pairs(GROUP_CHAT) do
	L.On(ev, function(text, sender)
		if not L.myKey or L.Key(str(sender) or "") ~= L.myKey then return end
		P8.chat[#P8.chat + 1] = { t = L.Now(), kind = kind, text = str(text) or "", combat = L.InCombat() }
		while #P8.chat > 20 do table.remove(P8.chat, 1) end
		if L.InCombat() and P8.lastShareAt and L.Now() - P8.lastShareAt < 5 then P8.combatBad = "a line went to " .. kind .. " chat in combat" end
	end)
end

-- In combat: the share overlay must stay off (no macro, not shown over a pill).
function L.Probe8CombatTick()
	if not L.InCombat() then
		P8.combatFrom = nil
		return
	end
	P8.combatFrom = P8.combatFrom or L.Now()
	P8.combatLast = L.Now()
	local b = rawget(_G, "WuberShareButton")
	if type(b) == "table" then
		local macro = str(call(b.GetAttribute, b, "macrotext")) or ""
		if macro ~= "" then P8.combatBad = "in combat the share button holds a macro: " .. macro:sub(1, 40) end
	end
end

-- The flight master's map: how many places this character can fly to from there (REACHABLE
-- nodes), kept at every map, so the flight checks know a character with no flight paths at once
-- instead of waiting for a flight that can't come. (Learning a new path opens the map too.)
local NO_PATHS = "no flight paths known on this character"
function L.Probe8Taxi()
	local s = store()
	if not s then return end
	local n = num(call(rawget(_G, "NumTaxiNodes"))) or 0
	if n == 0 then return end -- (the map's nodes not there yet: nothing learned)
	local reach = 0
	for i = 1, math.min(n, 300) do
		if str(call(rawget(_G, "TaxiNodeGetType"), i)) == "REACHABLE" then reach = reach + 1 end
	end
	s.taxi = { at = L.Epoch(), reach = reach, nodes = n }
	L.Log("probe", ("flight map: %d of %d nodes reachable"):format(reach, n))
end
local function noPaths()
	local s = store()
	return s and type(s.taxi) == "table" and s.taxi.reach == 0 or false
end

L.OnLogin(function()
	local s = store()
	if s then s.hit, s.plate = nil, nil end -- (old saved sightings: lab 1.2's combat-log hit, round 12's nameplate)
	L.On("CONFIRM_SUMMON", function() L.Probe8Summon() end)
	L.On("TAXIMAP_OPENED", function() L.Probe8Taxi() end)
	L.Every(0.5, function()
		hookShare()
		L.Probe8CombatTick()
		L.Probe8Arrival()
	end)
end)

-- a share click since `since` with the wanted macro, and my line in that chat after it
local function shareSeen(since, prefix, kind)
	for i = #P8.shares, 1, -1 do
		local s = P8.shares[i]
		if s.t >= since and s.macro ~= "" then
			if s.macro:sub(1, #prefix) ~= prefix then return "fail", "the share macro was '" .. s.macro:sub(1, 40) .. "', not " .. prefix:gsub(" $", "") end
			for _, c in ipairs(P8.chat) do
				if c.t >= s.t - 0.5 and c.kind == kind then return "pass", prefix:gsub(" $", "") .. " posted to " .. kind .. " chat: '" .. c.text:sub(1, 50) .. "'" end
			end
			return nil, "the macro went (" .. prefix:gsub(" $", "") .. "), no line in " .. kind .. " chat yet"
		end
	end
	return nil
end

local function realSummon(ctx)
	if ctx.sim then return "skip", "test mode: the pretend ritual has no real summon box" end
	return true
end

---------------------------------------------------------------------------
-- Scene: the 2.3 probes (loose: each stands alone; after the ride)
---------------------------------------------------------------------------

L.AddScene({ id = "probes8", title = "Wuber 2.3 probes", linked = false, prio = 3, after = "ride" })

-- 1. The Fold: a width tween (never a scale), both ways; the small windows stay folded.
local function foldHooks(ctx)
	local win = rawget(_G, "WuberFrame")
	if type(win) ~= "table" then return false end
	local d = ctx.data
	d.scale0 = d.scale0 or num(call(win.GetScale, win))
	if not P8.foldHooked then
		P8.foldHooked = L.Hook(win, "SetWidth", function(_, w)
			local c = P8.foldCtx
			if c and not c.done then c.data.widths[#c.data.widths + 1] = num(w) end
		end)
		L.Hook(win, "SetScale", function(_, s)
			local c = P8.foldCtx
			if c and not c.done and num(s) ~= c.data.scale0 then c.data.scaled = num(s) end
		end)
	end
	return true
end

local function foldVerdict(ctx)
	local d = ctx.data
	if d.scaled then return "fail", ("the window's scale changed (%.2f -> %.2f): the fold must tween the width only"):format(d.scale0 or 0, d.scaled) end
	for who, f in pairs(d.facts or {}) do
		if f:find("^small") and f:find("unfolded", 1, true) then return "fail", who .. "'s window is too small yet unfolded (" .. f .. ")" end
	end
	if not (d.opened and d.closed) then
		d.waitWhy = d.opened and "it unfolded but never folded: press the fold button" or "it never unfolded"
		return nil
	end
	local lo, hi, mid = math.huge, 0, 0
	for _, w in ipairs(d.widths) do
		if w < lo then lo = w end
		if w > hi then hi = w end
	end
	for _, w in ipairs(d.widths) do if w > lo + 1 and w < hi - 1 then mid = mid + 1 end end
	if mid < 3 then
		d.waitWhy = "no width tween seen (" .. #d.widths .. " widths): press the fold button while the window is open"
		return nil
	end
	local others = {}
	for who, f in pairs(d.facts or {}) do others[#others + 1] = who .. " " .. f end
	table.sort(others)
	return "pass", ("width %d-%d in %d steps, scale %.2f kept%s"):format(lo, hi, mid, d.scale0 or 1,
		#others > 0 and ("; " .. table.concat(others, ", ")) or "")
end

L.AddCheck({ id = "pb_fold", title = "The Fold (4K)", scene = "probes8", who = "driver", secs = 40, timeout = 180,
	click = "open Wuber's Settings (it unfolds), press the fold button twice (fold, unfold), then answer",
	also = { "rider", "crew1", "crew2" },
	observe = function(o)
		local F = fold()
		if not F then o.Tell("no fold") return end
		local fits, why = call(F.Fits)
		o.Tell((fits and "fits" or tostring(why or "no room")) .. ", " .. (call(F.IsUnfolded) and "unfolded" or "folded"))
	end,
	when = function()
		if not fn(fold(), "IsUnfolded") then return "skip", "UI.Fold is missing (an older Wuber)" end
		return true
	end,
	begin = function(ctx)
		ctx.data.widths = {}
		P8.foldCtx = ctx
		local fits, why = call(fold().Fits)
		if not fits and why == "small" then return "skip", "Anita's window is too small to unfold here (needs the big screen)" end
		foldHooks(ctx)
	end,
	watch = { "wuber:FOLD", "fact" },
	test = function(ctx, ev, a, b)
		if ev == "fact" then
			ctx.data.facts = ctx.data.facts or {}
			ctx.data.facts[L.RunShort(L.RunRoleOf(tostring(a)) or "") or tostring(a)] = tostring(b)
			return
		end
		if a then ctx.data.opened = true else ctx.data.closed = true end
	end,
	poll = function(ctx)
		if not foldHooks(ctx) then ctx.data.waitWhy = "Wuber's window isn't built yet: open it" return end
		local r, why = foldVerdict(ctx)
		if r == "fail" then return r, why end
		ctx.data.auto = r == "pass" and why or nil
		if ctx.data.auto and ctx.data.answer == "yes" then return "pass", ctx.data.auto end
	end,
	ask = function(ctx) return ctx.data.auto and "Smooth, text sharp, buttons on their pills after unfolding?" or nil end,
	answer = function(ctx, yes)
		if not yes then return "fail", "Tester: not smooth, blurred, or a button off its pill (" .. tostring(ctx.data.auto) .. ")" end
		return "pass", "Tester: smooth; " .. tostring(ctx.data.auto)
	end })

-- 2. The world map: which art won, CreateLine with REPEAT texcoords; the tester sees the dashes.
local function lineProbe()
	if P8.line then return P8.line[1], P8.line[2] end
	local okF, f = pcall(CreateFrame, "Frame", nil, UIParent)
	if not okF or type(f) ~= "table" then return false, "no frame" end
	pcall(f.Hide, f)
	if type(f.CreateLine) ~= "function" then
		P8.line = { false, "CreateLine is missing" }
	else
		local ok, line = pcall(f.CreateLine, f)
		if not ok or type(line) ~= "table" then
			P8.line = { false, "CreateLine failed: " .. tostring(line) }
		else
			local okT = pcall(line.SetTexture, line, "Interface\\AddOns\\Wuber\\Media\\dash", "REPEAT", "REPEAT")
			pcall(line.SetTexCoord, line, 0, 4, 0, 1)
			local tc = { call(line.GetTexCoord, line) }
			local okS = pcall(line.SetStartPoint, line, "LEFT", f, 0, 0) and pcall(line.SetEndPoint, line, "RIGHT", f, 0, 0)
			local wrap = num(tc[5]) or num(tc[3])
			if not (okT and okS) then
				P8.line = { false, "Line:SetTexture(REPEAT) or Set*Point failed" }
			else
				P8.line = { true, "CreateLine ok, REPEAT texture, texcoords " .. (wrap and ("to " .. wrap) or "unreadable") }
			end
		end
	end
	return P8.line[1], P8.line[2]
end
L.Probe8Line = lineProbe

L.AddCheck({ id = "pb_worldmap", title = "World map art and routes", scene = "probes8", who = "rider", secs = 40, timeout = 180,
	click = "in Wuber tap Anita's card (Confirm unfolds), then World at the top of the right pane",
	poll = function(ctx)
		local ok, why = lineProbe()
		if not ok then return "fail", why end
		local F, WM = fold(), mod("UI.Rider.WorldMap")
		if not (fn(F, "IsUnfolded") and fn(WM, "Probe")) then return "skip", "UI.Fold or the world map is missing (an older Wuber)" end
		if call(F.IsUnfolded) ~= true then ctx.data.waitWhy = "the window never unfolded" return end
		local art = str(call(WM.Probe)) or "?"
		ctx.data.auto = "art: " .. art .. "; " .. why
		if ctx.data.answer == "yes" then return "pass", ctx.data.auto end
	end,
	ask = function(ctx) return ctx.data.auto and "On World: routes dashed, ending on the coast towns?" or nil end,
	answer = function(ctx, yes)
		return yes and "pass" or "fail", (yes and "Tester: dashed, on the towns; " or "Tester: routes wrong; ") .. tostring(ctx.data.auto)
	end })

-- 3. Flight times: a real flight recorded, against the estimate taken before it.
local ROUTES = { { "Undercity", "Tarren Mill", "undercity", "tarren" }, { "Orgrimmar", "Crossroads", "orgrimmar", "crossroads" } }

L.AddCheck({ id = "pb_flight", title = "A flight timed", scene = "probes8", who = "rider", secs = 240, timeout = 600,
	click = "fly Undercity to Tarren Mill (or Orgrimmar to the Crossroads) and land there",
	when = function()
		local W = L.W()
		if not fn(W, "FlightTime") then return "skip", "W.FlightTime is missing (an older Wuber)" end
		if noPaths() then return "skip", NO_PATHS end
		return true
	end,
	poll = function()
		if noPaths() then return "skip", NO_PATHS end
	end,
	begin = function(ctx)
		local W, FT = L.W(), mod("Core.FlightTimes")
		ctx.data.est = {}
		for i, r in ipairs(ROUTES) do
			local secs
			if fn(W.FLY, "Pair") and fn(FT, "Estimate") then
				local to, from, mine = call(W.FLY.Pair, r[1], r[2])
				if to then secs = num(call(FT.Estimate, from, to, mine)) end
			end
			if not secs then
				local t, src = call(W.FlightTime, r[1], r[2])
				if src == "est" then secs = num(t) end
			end
			ctx.data.est[i] = secs
		end
	end,
	watch = { "wuber:FLIGHT_TIME" },
	test = function(ctx, _, from, to, secs)
		from, to, secs = tostring(from):lower(), tostring(to):lower(), num(secs)
		for i, r in ipairs(ROUTES) do
			if from:find(r[3], 1, true) and to:find(r[4], 1, true) then
				local est = ctx.data.est[i]
				if not secs then return "fail", "FLIGHT_TIME came without seconds" end
				if not est then return "pass", ("%s to %s took %s (no estimate to compare)"):format(r[1], r[2], mmss(secs)) end
				local off = (secs - est) / est * 100
				local line = ("%s to %s: flew %s, estimate about %s (%+d%%)"):format(r[1], r[2], mmss(secs), mmss(est), math.floor(off + 0.5))
				if math.abs(off) <= 25 then return "pass", line end
				return "fail", line .. ": more than 25% off"
			end
		end
		ctx.data.waitWhy = "a flight was timed (" .. from .. " to " .. to .. "), but not one of the two routes"
	end })

L.AddCheck({ id = "pb_flycal", title = "Flight estimate calibrated", scene = "probes8", who = "rider", secs = 2, timeout = 10,
	say = "Wuber calibrates its flight estimate after 3 of your own flights",
	begin = function()
		local FT = mod("Core.FlightTimes")
		if not fn(FT, "Calibration") then return "skip", "Core.FlightTimes is missing (an older Wuber)" end
		local ratio, n = call(FT.Calibration)
		ratio, n = num(ratio) or 1, num(n) or 0
		if n < 3 and noPaths() then return "skip", NO_PATHS end
		if n < 3 then return "skip", ("%d of 3 own flights timed: fly %d more"):format(n, 3 - n) end
		if ratio == 1 then return "fail", n .. " flights timed, but no calibration in use (ratios out of range?)" end
		return "pass", ("calibrated x%.2f from %d flights"):format(ratio, n)
	end })

-- 4. TaxiNodePosition gives continent map positions (the calibration fallback).
local function taxiNodes()
	if type(TaxiNodePosition) ~= "function" then return "fail", "TaxiNodePosition is missing" end
	local n = num(call(rawget(_G, "NumTaxiNodes"))) or 0
	if n == 0 then return nil, "the flight map has no nodes yet" end
	local good, seen, first = 0, {}, nil
	for i = 1, n do
		local x, y = call(TaxiNodePosition, i)
		x, y = num(x), num(y)
		if x and y and (x > 0 or y > 0) and x <= 1 and y <= 1 then
			local k = ("%.3f,%.3f"):format(x, y)
			if not seen[k] then
				seen[k] = true
				good = good + 1
				first = first or ("%s at %.2f, %.2f"):format(tostring(str(call(rawget(_G, "TaxiNodeName"), i)) or i), x, y)
			end
		end
	end
	if good < 3 then return "fail", ("only %d of %d nodes have a map position (0, 0 is unknown)"):format(good, n) end
	return "pass", ("%d of %d nodes have continent positions (%s)"):format(good, n, first)
end

L.AddCheck({ id = "pb_taxinode", title = "Flight map positions", scene = "probes8", who = "rider", secs = 30, timeout = 240,
	click = "talk to a flight master (open the flight map)",
	poll = function(ctx)
		if not taxiMap() then ctx.data.waitWhy = "the flight map never opened" ctx.data.mapAt = nil return end
		ctx.data.mapAt = ctx.data.mapAt or ctx.t
		if ctx.t - ctx.data.mapAt < 0.5 then return end
		local r, why = taxiNodes()
		if r then return r, why end
		ctx.data.waitWhy = why
	end })

-- 8. The bird card: beside the flight map, never over it, a strata below; the tester tries the map.
local function birdGeometry(card, map)
	local cl, cr, ml, mr = num(call(card.GetLeft, card)), num(call(card.GetRight, card)), num(call(map.GetLeft, map)), num(call(map.GetRight, map))
	if not (cl and cr and ml and mr) then return nil, "no position" end
	if cl < mr - 1 and cr > ml + 1 then return false, "the card overlaps the map" end
	local cs, ms = STRATA[str(call(card.GetFrameStrata, card)) or ""] or 0, STRATA[str(call(map.GetFrameStrata, map)) or ""] or 0
	if cs > ms then return false, "the card is a strata above the map" end
	return true, (cl >= mr - 1 and "right" or "left") .. " of the map, a strata below"
end

L.AddCheck({ id = "pb_bird", title = "Skip the bird card", scene = "probes8", who = "rider", secs = 25, timeout = 120,
	click = "with Anita open (selling), open the flight map far from her",
	poll = function(ctx)
		local B, W = mod("UI.Bird"), L.W()
		if not fn(B, "Card") then return "skip", "UI.Bird is missing (an older Wuber)" end
		local map, name = taxiMap()
		if not map then ctx.data.waitWhy = "the flight map never opened" ctx.data.mapAt = nil return end
		ctx.data.mapAt = ctx.data.mapAt or ctx.t
		local card = call(B.Card)
		if shown(card) then
			local ok, why = birdGeometry(card, map)
			if ok == false then return "fail", why end
			if ok then ctx.data.auto = "beside " .. name .. ": " .. why end
		elseif ctx.data.auto then
			ctx.data.waitWhy = "the card came and went (" .. ctx.data.auto .. ")"
		elseif ctx.t - ctx.data.mapAt > 3 then
			if W and type(W.db) == "table" and W.db.birdTip == false then return "skip", "Settings: Flight master tip is off" end
			if fn(B, "Pick") and not call(B.Pick) then return "skip", "no card: no open driver beats flying from here" end
			ctx.data.waitWhy = "the map is open but no card came"
		end
		if ctx.data.auto and ctx.data.answer == "yes" then return "pass", ctx.data.auto end
	end,
	ask = function(ctx) return ctx.data.auto and "Card beside the map, and the whole map still clickable?" or nil end,
	answer = function(ctx, yes)
		return yes and "pass" or "fail", (yes and "Tester: the map stays usable; " or "Tester: the card gets in the way; ") .. tostring(ctx.data.auto)
	end })

-- 6. C_SummonInfo.GetSummonConfirmSummoner names the summoner (seen at the ride's summon box).
local function summonerVerdict(rec)
	if not rec.has then return "fail", "C_SummonInfo.GetSummonConfirmSummoner is missing" end
	if not rec.name then return "fail", "it returned nothing" end
	local who = roleName(L.Key(rec.name))
	if who then return "pass", "it named " .. rec.name .. (rec.driver and (" (the ride's driver: " .. rec.driver .. ")") or "") end
	return "fail", "it named " .. rec.name .. ", none of the tester's four"
end

L.AddCheck({ id = "pb_summoner", title = "Who is summoning", scene = "probes8", who = "rider", secs = 3, timeout = 60,
	say = "the summon box names its caster (Anita's summon in the ride)",
	when = realSummon,
	begin = function()
		local s = store()
		if s and s.summon and not s.summon.sim then return summonerVerdict(s.summon) end
	end,
	watch = { "probe8_summon" },
	test = function(_, _, rec) if type(rec) == "table" then return summonerVerdict(rec) end end,
	onTimeout = function() return "skip", "no summon box seen yet (it comes with the ride)" end })

-- 9. The founder's gold portal (Anita) and violet for anyone else.
L.AddCheck({ id = "pb_gold", title = "Gold portal from Anita", scene = "probes8", who = "rider", secs = 10, timeout = 90,
	say = "think back to Anita's summon in the ride",
	when = realSummon,
	begin = function(ctx)
		local W, s = L.W(), store()
		if not fn(W, "FounderSummon") then return "skip", "W.FounderSummon is missing (an older Wuber)" end
		if fn(W, "OnFounderRuleset") and call(W.OnFounderRuleset) ~= true then return "skip", "not the founders' ruleset (EU-PvE): every portal is violet here" end
		local a, b = s and s.arrival, s and s.summon
		local rec = (a and a.founder and not a.sim) and a or ((b and b.ride and b.founder and not b.sim) and b or nil)
		if not rec then return "skip", "no summon by a founder seen yet (the ride does it)" end
		if not rec.gold then return "fail", "Wuber chose violet for " .. tostring(rec.by or rec.name) .. "'s summon (W.FounderSummon false)" end
		ctx.data.auto = "W.FounderSummon: gold for " .. tostring(rec.by or rec.name)
	end,
	ask = "When Anita summoned Wuber Rocks, were the portal and arrival gold?",
	answer = function(ctx, yes)
		return yes and "pass" or "fail", (yes and "Tester: gold; " or "Tester: not gold; ") .. tostring(ctx.data.auto)
	end })

L.AddCheck({ id = "pb_violet", title = "Violet for a non-founder", scene = "probes8", who = "rider", secs = 2, timeout = 10,
	say = "a summon by someone who isn't a founder stays violet",
	when = realSummon,
	begin = function()
		local s = store()
		for _, rec in ipairs({ s and s.arrival or false, s and s.summon or false }) do
			if rec and rec.ride and not rec.founder and (rec.by or rec.name) then
				if rec.gold then return "fail", "gold for " .. tostring(rec.by or rec.name) .. ", who isn't a founder" end
				return "pass", "violet for " .. tostring(rec.by or rec.name)
			end
		end
		return "skip", "needs a summon by someone who isn't a founder (all four of the tester's characters are)"
	end })

-- 7. The share macro: /p in a party, /ra in a raid, nothing in combat.
local function shareCheck(prefix, kind, inRaid)
	return function(ctx)
		if not share() then return "skip", "UI.Share is missing (an older Wuber)" end
		if P8.combatBad then return "fail", P8.combatBad end
		if not hookShare() then ctx.data.waitWhy = "no WuberShareButton (Wuber's secure share button)" return end
		if not J.inGroup() then ctx.data.waitWhy = "Wuber Rocks isn't in a group" return end
		if J.inRaid() ~= inRaid then ctx.data.waitWhy = "Wuber Rocks is in a " .. (J.inRaid() and "raid" or "party") .. ", this one needs a " .. kind return end
		local r, why = shareSeen(ctx.started, prefix, kind)
		if r then return r, why end
		ctx.data.waitWhy = why or "no Share was tapped"
	end
end

L.AddCheck({ id = "pb_share_party", title = "Share in a party (/p)", scene = "probes8", who = "rider", secs = 40, timeout = 150,
	click = "Anita: /invite Wuber Rocks (a party). Wuber Rocks: tap Share (Trips: this month's Wrapped)",
	poll = shareCheck("/p ", "party", false) })

L.AddCheck({ id = "pb_share_raid", title = "Share in a raid (/ra)", scene = "probes8", who = "rider", secs = 40, timeout = 150,
	click = "in Anita's raid (Anita: Convert to Raid), tap Share again (a minute after the last)",
	poll = shareCheck("/ra ", "raid", true) })

L.AddCheck({ id = "pb_share_combat", title = "No share in combat", scene = "probes8", who = "rider", secs = 30, timeout = 120,
	click = "start a fight (attack a mob or a dummy), tap Share during it",
	poll = function(ctx)
		if not share() then return "skip", "UI.Share is missing (an older Wuber)" end
		if P8.combatBad then return "fail", P8.combatBad end
		for _, s in ipairs(P8.shares) do
			if s.t >= ctx.started and s.combat and s.macro ~= "" then return "fail", "a share went in combat: " .. s.macro:sub(1, 40) end
		end
		local d = ctx.data
		if L.InCombat() then
			d.from = d.from or L.Now()
			d.last = L.Now()
		end
		if d.from and d.last - d.from >= 4 and (not L.InCombat() or d.last - d.from >= 8) then
			return "pass", ("%d s in combat: no share overlay, nothing posted"):format(math.floor(d.last - d.from))
		end
		d.waitWhy = d.from and "the fight was shorter than 4 s" or "never in combat"
	end })

---------------------------------------------------------------------------
-- Scene: the lag-drop raincheck (10): paid, closed before casting, ask, give, accept, rebook free
---------------------------------------------------------------------------

L.AddScene({ id = "rain8", title = "Raincheck after a failed paid ride", prio = 4, after = "ride",
	intro = "Wuber Rocks away from Anita (another zone); Anita has never cast on this ride" })

local rain = {} -- the scene's ride id on the driver's window

local function rainRide()
	local DR = J.DR()
	local c = J.cust("rider")
	return c and fn(DR, "RideIdOf") and call(DR.RideIdOf, c) or rain.ride
end

L.AddCheck({ id = "rc_open", title = "Anita open", scene = "rain8", who = "driver", secs = 15, timeout = 90,
	click = "Drive tab: Sell summons, Open",
	when = function()
		local DR, W = J.DR(), L.W()
		if not (fn(DR, "RaincheckEligible") and W and type(W.Raincheck) == "table") then return "skip", "no raincheck in this Wuber (an older one)" end
		return true
	end,
	poll = function() if J.selling() then return "pass", "open, selling" end end })

L.AddCheck({ id = "rc_book", title = "Rider books", scene = "rain8", who = "rider", secs = 20, timeout = 90,
	click = "/wuber, tap Anita's card, Request summon",
	poll = function()
		local r = J.ride()
		local ended = (L.W() or {}).RIDE_ENDED or {}
		if r and r.driverKey == J.key("driver") and not ended[r.state or ""] then return "pass", "booked Anita (" .. tostring(r.state) .. ")" end
	end })

L.AddCheck({ id = "rc_join", title = "In Anita's group", scene = "rain8", who = "rider", secs = 10, timeout = 45,
	say = "the invite arrives and is taken",
	poll = function() if J.inGroupWith("driver") then return "pass", "in Anita's group" end end })

L.AddCheck({ id = "rc_pay", title = "Paid before the summon", scene = "rain8", who = "rider", judge = "driver", secs = 40, timeout = 150,
	click = "trade Anita the fare now (before any summon): type it, click Trade",
	poll = function(ctx)
		local DR = J.DR()
		local rid = rainRide()
		if not rid then ctx.data.waitWhy = "Wuber Rocks isn't in Anita's queue" return end
		rain.ride = rid
		local ok, why = call(DR.RaincheckEligible, rid)
		if why == "open" then return "pass", "paid by trade; the ride is still open" end
		if ok then return "pass", "paid by trade" end
		ctx.data.waitWhy = "not paid by trade yet (" .. tostring(why) .. ")"
	end })

L.AddCheck({ id = "rc_close", title = "Anita closes, no cast", scene = "rain8", who = "driver", secs = 15, timeout = 90,
	click = "press Close on the Drive tab (don't summon)",
	poll = function(ctx)
		local DR = J.DR()
		if type(DR) == "table" and type(DR.cast) == "table" and L.Key(DR.cast.name) == J.key("rider") then
			return "fail", "Anita cast on Wuber Rocks: the ride didn't fail before the summon"
		end
		if J.selling() then return end
		local ok, why = call(DR.RaincheckEligible, rain.ride)
		if ok then return "pass", "closed: the paid ride failed, a raincheck may be given" end
		ctx.data.waitWhy = "closed, but not eligible: " .. tostring(why)
	end })

L.AddCheck({ id = "rc_ask", title = "Rider asks", scene = "rain8", who = "rider", judge = "driver", secs = 15, timeout = 90,
	click = "on the Done screen tap Ask for a raincheck",
	watch = { "wuber:RAINCHECK" },
	test = function(_, _, op) if op == "ask" then return "pass", "Anita's Wuber heard the ask" end end })

L.AddCheck({ id = "rc_give", title = "Anita gives", scene = "rain8", who = "driver", judge = "rider", secs = 20, timeout = 90,
	click = "click the raincheck alert (or Wuber Rocks' row), then Give raincheck",
	watch = { "wuber:RAINCHECK" },
	test = function(_, _, op, id) if op == "offer" then return "pass", "offered (" .. tostring(id) .. ")" end end })

L.AddCheck({ id = "rc_accept", title = "Rider accepts", scene = "rain8", who = "rider", secs = 15, timeout = 90,
	click = "Accept on the raincheck card",
	watch = { "wuber:RAINCHECK" },
	test = function(_, _, op, id) if op == "active" then return "pass", "kept (" .. tostring(id) .. ")" end end })

L.AddCheck({ id = "rc_reopen", title = "Anita open again", scene = "rain8", who = "driver", secs = 15, timeout = 90,
	click = "Drive tab: Open again (Sell summons)",
	poll = function() if J.selling() then return "pass", "open again" end end })

L.AddCheck({ id = "rc_rebook", title = "Rebooked free", scene = "rain8", who = "rider", secs = 25, timeout = 120,
	click = "tap Anita's card (Use raincheck on), Request summon",
	watch = { "wuber:RAINCHECK" },
	test = function(_, _, op)
		if op == "refused" then return "fail", "Anita's Wuber refused the raincheck: the normal fare" end
		if op == "taken" then
			local r = J.ride()
			return "pass", "Anita's Wuber took the raincheck" .. (r and (": due " .. J.money(r.price or 0)) or "")
		end
	end })

L.AddCheck({ id = "rc_end", title = "Free ride cancelled", scene = "rain8", who = "rider", secs = 10, timeout = 60,
	click = "tap Cancel (the free ride isn't needed now; the raincheck stays for later)",
	poll = function()
		local r = J.ride()
		local ended = (L.W() or {}).RIDE_ENDED or {}
		if not r or ended[r.state or ""] then return "pass", "cancelled" end
	end })
