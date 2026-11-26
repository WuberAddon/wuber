-- Old code patterns the real game refused, rebuilt as a fixture (job 2861). NOT Wuber code.
local M = {}
WuberFxOld = M

-- B4: the old lab/WuberLab/AutoKeys.lua:108 shape: the answer of IsEventRegistered on a Blizzard frame was compared straight away.
-- (in the game it is a secret boolean: "attempt to compare a secret boolean value (execution tainted by 'WuberLab')")
function M.B4old(up)
	local n = 0
	for _, c in ipairs({ up:GetChildren() }) do
		local reg = c:IsEventRegistered("GLOBAL_MOUSE_DOWN")
		if reg == true then n = n + 1 end
	end
	return n
end

-- B4 as fixed in the lab today: the answer is looked at with issecretvalue first
function M.B4fixed(up)
	local n, hidden = 0, 0
	for _, c in ipairs({ up:GetChildren() }) do
		local reg = c:IsEventRegistered("GLOBAL_MOUSE_DOWN")
		if issecretvalue(reg) then hidden = hidden + 1
		elseif reg == true then n = n + 1 end
	end
	return n, hidden
end

-- B5a: WuberLabBar Bar.lua:247 shape: ReloadUI from a C_Timer callback
function M.B5timer() C_Timer.After(0.1, function() ReloadUI() end) end

-- B5b: GameFacts2.lua shape: ReloadUI fetched by name (rawget on _G) and called with pcall
local function gfn(name) return rawget(_G, name) end
function M.B5gamefacts() local f = gfn("ReloadUI") if f then pcall(f) end end

-- B5c: a click handler (a real click is a hardware event, but ReloadUI is still refused from addon code)
function M.B5button()
	local b = CreateFrame("Button", nil, UIParent)
	b:SetSize(40, 20) b:SetPoint("CENTER")
	b:SetScript("OnClick", function() ReloadUI() end)
	M.btn = b
	return b
end

-- B5d (job 2894): ReloadUI called through a thin wrapper (callm): the guard also judges the next Wuber frame up
local function callm(fn) local a = fn() return a end
function M.B5wrapped()
	callm(ReloadUI) -- WRAPPED-CALL-SITE
end

-- other classes of the guard
function M.CVar() SetCVar("nameplateShowAll", "1") end
function M.Invite() InviteUnit("Somebody") end
function M.InviteButton()
	local b = CreateFrame("Button", nil, UIParent)
	b:SetSize(40, 20) b:SetPoint("CENTER", 0, 40)
	b:SetScript("OnClick", function() InviteUnit("Somebody") end)
	return b
end
function M.Macro() CastSpellByName("Shadow Bolt") end
function M.Undoc() local r = WuberNoSuchApi() return r end
function M.UndocTail() return WuberNoSuchApi() end
function M.UndocNs() local r = C_Map.NoSuchThing() return r end
function M.UndocGuarded() if type(WuberNoSuchApi) == "function" then return WuberNoSuchApi() end end
function M.SecretArg(v) local r = C_ChatInfo.SendAddonMessage("WFX", v, "WHISPER", "Nobody") return r end
function M.ResetCVarOk() return GetCVar("nameplateShowAll") end
