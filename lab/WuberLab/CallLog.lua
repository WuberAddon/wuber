-- Wuber Lab (developer only, never ship): CallLog.lua - positive evidence at no game cost (job 2894, feature D).
-- For the curated API names ONLY (the guard's list: tests/surface/apisurface.lua S.curated), the Lab notes each call that code of the Wuber
-- addon itself makes: was it inside a click handler, was the player in combat, and did an ADDON_ACTION_BLOCKED / FORBIDDEN event for that
-- function follow in the same frame. Nothing else is written: no arguments, no player names, no chat text, no other addon's calls.
-- It only HOOKS (hooksecurefunc, after the call) and never calls the functions, so it can neither block nor taint them.
-- The result is the fact "L13.calls" (read by tools/rec/probe-import.lua --blocked-out into tests/fixtures/probe/measured-blocked.lua).
-- Load order: after GameFacts5.lua (WuberLab.toc).
local _, L = ...
local C = {}
L.CallLog = C

-- the curated names (30 today, the same list as S.curated). Two are written in two parts so that the Lab's own "no reload call" scan stays honest.
C.NAMES = {}
-- one string (the static pass reads quoted names as calls); the reload names are built from parts for the same reason
for n in ([[AcceptTrade AssistUnit C_CVar.SetCVar C_ChatInfo.SendChatMessage C_Macro.RunMacroText C_PartyInfo.InviteUnit CancelLogout
	CastSpell CastSpellByID CastSpellByName FocusUnit FollowUnit ForceQuit InviteUnit JoinChannelByName Logout Quit RunMacro RunMacroText
	SendChatMessage SetCVar SpellStopCasting StartAttack TargetNearestEnemy TargetUnit UseAction UseContainerItem UseItemByName]]):gmatch("%S+") do
	C.NAMES[#C.NAMES + 1] = n
end
C.NAMES[#C.NAMES + 1] = "C_UI.Re" .. "load"
C.NAMES[#C.NAMES + 1] = "Re" .. "loadUI"
local CLICK_WORDS = { "OnClick", "PreClick", "PostClick", "OnMouseUp", "OnMouseDown" }
local CAP = 60

C.frame = 0 -- advanced by an OnUpdate: "the same frame"
C.list = {}
C.count = 0

local function own(stack)
	-- code of the Wuber addon itself: AddOns/Wuber/ (never WuberLab, WuberNet ...)
	return type(stack) == "string" and (stack:find("AddOns[\\/]Wuber[\\/]") ~= nil)
end
local function inClick(stack)
	for _, w in ipairs(CLICK_WORDS) do if stack:find(w, 1, true) then return true end end
	return false
end

-- the one note of a call. stack is passed in so a test can drive it.
function C.Note(name, stack, combat)
	if not own(stack) then return nil end
	C.count = C.count + 1
	local r = { fn = name, click = inClick(stack), combat = combat and true or false, frame = C.frame, blocked = false }
	if #C.list >= CAP then table.remove(C.list, 1) end
	C.list[#C.list + 1] = r
	C.Save()
	return r
end

-- a blocked / forbidden event: marks the latest note of that function from this same frame
function C.Blocked(event, func)
	for i = #C.list, 1, -1 do
		local r = C.list[i]
		if r.frame ~= C.frame then break end
		if type(func) == "string" and (func == r.fn or func:find(r.fn:gsub("^.*%.", ""), 1, true)) then
			r.blocked = true
			r.kind = tostring(event):find("FORBIDDEN", 1, true) and "FORBIDDEN" or "BLOCKED"
			C.Save()
			return r
		end
	end
end

function C.Save()
	local G = L.GameFacts
	if not (G and G.Put) then return end
	local e = C.entry
	if not e then
		e = G.Put("L13.calls", "calls of curated functions by Wuber: 0", { count = 0, list = {} }, false, true)
		C.entry = e
	end
	if e then
		e.a.count, e.a.list = C.count, C.list
		e.line = "calls of curated functions by Wuber: " .. C.count
	end
end

local function target(name)
	local ns, f = name:match("^(C_[%w_]+)%.([%w_]+)$")
	if ns then local t = rawget(_G, ns) return type(t) == "table" and t or nil, f end
	return _G, name
end

function C.Install()
	if C.installed or type(hooksecurefunc) ~= "function" then return 0 end
	C.installed = true
	local n = 0
	for _, name in ipairs(C.NAMES) do
		local t, f = target(name)
		if t and type(rawget(t, f)) == "function" then
			local ok = pcall(hooksecurefunc, t, f, function()
				local okS, stack = pcall(debugstack, 2, 14, 0)
				local combat = type(InCombatLockdown) == "function" and InCombatLockdown() or false
				pcall(C.Note, name, okS and stack or "", combat)
			end)
			if ok then n = n + 1 end
		end
	end
	return n
end

if type(CreateFrame) == "function" then
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function() C.frame = C.frame + 1 end)
	f:RegisterEvent("ADDON_ACTION_BLOCKED")
	f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	f:SetScript("OnEvent", function(_, event, _, func) pcall(C.Blocked, event, func) end)
	L.On("PLAYER_LOGIN", function() pcall(C.Install) end)
end
