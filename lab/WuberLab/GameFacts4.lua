-- Wuber Lab (developer only, never ship): GameFacts4.lua - two passive Game facts checks for the combat edge (job 2630, item 11, DRAFT).
--   REGEN     R1: what InCombatLockdown() answers INSIDE PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED, and again one frame, 0.1 s, 0.5 s and 2 s later
--   TRADEBTN  R2: at every trade window, the two answers that decide whether a secure "click" action may click TradeFrameTradeButton
--
-- Why Game facts, passive: R1 needs real fights over ordinary play (the order of an event against a lock cannot be set up by an Auto check, and a recorder
-- snapshot is timed, not event-driven); R2 needs a real trade window, which a second account opens for us in the normal Wuber ride and which the Lab already waits for.
-- Both are READ ONLY: no click, no protected call, nothing typed, nothing sent, nobody spoken to. Safe in combat: InCombatLockdown, UnitAffectingCombat, IsProtected,
-- IsForbidden, HasAccessConstraints, HasAnyForbiddenAspects and GetTime are plain getters; each is under pcall and its answer tested with issecretvalue.
-- No frame, event or timer at load (as GameFacts2.lua): wired by G.StartPassive. Answers in WuberLabDB.facts.REGEN and .TRADEBTN, one log line each (kind "facts").
--
-- R1 saved entry a = { ev = "PLAYER_REGEN_ENABLED" | "PLAYER_REGEN_DISABLED", inside = { lock, affecting, restrictCombat }, frame1, t100, t500, t2000 (the lock flag),
--   gap = seconds from the event to the first sample that differs from "inside" (nil: it never did in 2 s) }.
--   line "PLAYER_REGEN_ENABLED: lock inside true, +1 frame true, +0.1 s false, +0.5 s false, +2 s false"
--   Turned into the fixture tests/fixtures/rec/regen-order.lua: rows regen.enabled.lock_inside = a.inside.lock of the first ENABLED entry, regen.disabled.lock_inside likewise.
-- R2 saved entry a = { exists, hasAccessConstraints, scriptedInput64, scriptedInputEnum, forbidden, protected, shown, enabled, wuberBlocked, enumValue }.
--   Each is true/false/"secret"/"no such call"/"error". The secure click action refuses when hasAccessConstraints or scriptedInput64 is true (SecureTemplates.lua#L561).
--   line "TradeFrameTradeButton: constraints false, ScriptedInput false: the secure click would be allowed" (or "REFUSED", or "unknown").
--   Turned into a fixture row tests/fixtures/rec/trade-button.lua { id = "tradebutton.click_refused", value = true|false }, which the fake can then use as the default for
--   its secure click on that button.

local _, L = ...

local G = L.GameFacts
if type(G) ~= "table" or type(G.Put) ~= "function" or type(G.ask) ~= "function" then return end

local secret = L.IsSecret
local S = { wired = false, regen = 0, trades = 0 }
G.Combat = S -- (for the offline test)

G.IDS[#G.IDS + 1] = { "REGEN", "Combat lock against PLAYER_REGEN_*", "passive", "no fight seen yet (fight something and leave combat)" }
G.IDS[#G.IDS + 1] = { "TRADEBTN", "Trade button and the secure click", "passive", "no trade window seen yet (take a ride with a second account)" }

local function gfn(name) return rawget(_G, name) end
local function tfn(tname, name)
	local t = rawget(_G, tname)
	return type(t) == "table" and t[name] or nil
end

-- the first result of a guarded call as true / false / "secret" / "nothing" / "no such call" / "error"
local function flag(fn, ...)
	if type(fn) ~= "function" then return "no such call" end
	local r = { pcall(fn, ...) }
	if not r[1] then return "error" end
	if #r < 2 then return "nothing" end
	if secret(r[2]) then return "secret" end
	if r[2] == nil then return "nil" end
	return r[2]
end

---------------------------------------------------------------------------
-- R1: the combat lock against the two events
---------------------------------------------------------------------------

local function sample()
	return { lock = flag(gfn("InCombatLockdown")), affecting = flag(gfn("UnitAffectingCombat"), "player"),
		restrictCombat = flag(tfn("C_RestrictedActions", "GetAddOnRestrictionState"), 0) }
end

local function regenEvent(ev)
	S.regen = S.regen + 1
	local a = { ev = ev, inside = sample(), n = S.regen }
	local t0 = type(GetTime) == "function" and GetTime() or nil
	local function later(key, delay)
		L.After(delay, function()
			local s = sample()
			a[key] = s.lock
			if a.gap == nil and s.lock ~= a.inside.lock and t0 and type(GetTime) == "function" then a.gap = math.floor((GetTime() - t0) * 1000 + 0.5) / 1000 end
		end)
	end
	later("frame1", 0)   -- C_Timer.After(0) runs on the next frame
	later("t100", 0.1)
	later("t500", 0.5)
	later("t2000", 2)
	L.After(2.2, function()
		G.Put("REGEN", ("%s: lock inside %s, +1 frame %s, +0.1 s %s, +0.5 s %s, +2 s %s (UnitAffectingCombat inside %s)"):format(ev, tostring(a.inside.lock),
			tostring(a.frame1), tostring(a.t100), tostring(a.t500), tostring(a.t2000), tostring(a.inside.affecting)), a)
	end)
end

---------------------------------------------------------------------------
-- R2: would the secure click action be allowed to click TradeFrameTradeButton?
---------------------------------------------------------------------------

local function tradeButton(why)
	local b = gfn("TradeFrameTradeButton")
	local a = { why = why, exists = type(b) == "table" }
	if a.exists then
		-- the two checks of Blizzard_FrameXML/SecureTemplates.lua#L561, asked the way it asks them
		a.hasAccessConstraints = flag(b.HasAccessConstraints, b)
		a.scriptedInput64 = flag(b.HasAnyForbiddenAspects, b, 64)
		local E = rawget(_G, "Enum")
		local fa = type(E) == "table" and type(E.ForbiddenAspect) == "table" and E.ForbiddenAspect or nil
		a.enumValue = fa and flag(function() return fa.ScriptedInput end) or "no Enum.ForbiddenAspect"
		a.scriptedInputEnum = (type(a.enumValue) == "number" and a.enumValue ~= 64) and flag(b.HasAnyForbiddenAspects, b, a.enumValue) or a.scriptedInput64
		a.forbidden = flag(b.IsForbidden, b)
		a.protected = flag(b.IsProtected, b)
		a.shown = flag(b.IsShown, b)
		a.enabled = flag(b.IsEnabled, b)
	end
	-- what Wuber recorded for its own forwarded click (cap "trade"; Wuber/Core/Runtime.lua:396-426)
	local W = L.W and L.W() or nil
	a.wuberBlocked = "no Wuber"
	if type(W) == "table" and type(W.IsBlocked) == "function" then a.wuberBlocked = flag(W.IsBlocked, "trade") end
	local verdict = "unknown"
	if a.exists then
		if a.hasAccessConstraints == true or a.scriptedInput64 == true or a.scriptedInputEnum == true then verdict = "REFUSED"
		elseif a.hasAccessConstraints == false and a.scriptedInput64 == false then verdict = "allowed" end
	else
		verdict = "no button"
	end
	a.verdict = verdict
	S.trades = S.trades + 1
	return G.Put("TRADEBTN", ("TradeFrameTradeButton: constraints %s, ScriptedInput %s, forbidden %s, protected %s, Wuber's recorded refusal %s: the secure click would be %s"):format(
		tostring(a.hasAccessConstraints), tostring(a.scriptedInput64), tostring(a.forbidden), tostring(a.protected), tostring(a.wuberBlocked), verdict), a)
end
G.TradeButtonNow = tradeButton

---------------------------------------------------------------------------
-- Wiring (never at load) and the press
---------------------------------------------------------------------------

local function wire()
	if S.wired then return end
	S.wired = true
	L.On("PLAYER_REGEN_DISABLED", function() regenEvent("PLAYER_REGEN_DISABLED") end)
	L.On("PLAYER_REGEN_ENABLED", function() regenEvent("PLAYER_REGEN_ENABLED") end)
	-- the window is built when it opens: read it 0.4 s after TRADE_SHOW (the first time in a trade only; the answer does not change within one)
	local seenThisTrade = false
	L.On("TRADE_SHOW", function()
		if seenThisTrade then return end
		seenThisTrade = true
		L.After(0.4, function() tradeButton("trade opened") end)
	end)
	L.On("TRADE_CLOSED", function() seenThisTrade = false end)
end
G.WireCombat = wire

local startPassive = G.StartPassive
function G.StartPassive(pressed)
	local started = startPassive(pressed)
	wire()
	return started
end

-- a press of "Game facts" asks the trade button too (the window exists only while a trade is open: "no button" otherwise, which is also an answer)
local instant = G.Instant
function G.Instant(why)
	if why ~= "auto" or (type(L.db) == "table" and L.db.factsOn == true) then
		local b = gfn("TradeFrameTradeButton")
		if type(b) == "table" and flag(b.IsVisible, b) == true then pcall(tradeButton, why == "auto" and "auto" or "press") end
	end
	return instant(why)
end
L.GameFactsInstant = G.Instant
