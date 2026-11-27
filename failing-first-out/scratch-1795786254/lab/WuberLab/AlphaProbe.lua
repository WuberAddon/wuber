-- Wuber Lab (developer only, never ship): the alpha rule probe, "/lab alphaprobe".
--
-- Settles in the real client what the offline fake only infers: is a texture's SetAlpha ignored when the
-- texture was already drawn and its frame is then hidden, or while an Alpha animation runs on its frame?
-- It shows four red swatches, each one set to alpha 0.15 in a different way; a swatch that honours the call
-- looks faint, one that ignores it stays solid red. Press Faint or Solid under each, and the lab logs one
-- "probe" line with the answer (also saved in WuberLabDB.alphaProbe). The calls only touch the probe's own
-- frames. /lab alphaprobe result  prints the last answer; /lab alphaprobe stop  closes the window.

local _, L = ...

local str, call = L.str, L.call

if type(L.KINDS) == "table" and not L.KINDS.probe then L.KINDS.probe = "probe answers (in-game rules the fake only infers)" end

local WANT = 0.15 -- the alpha every swatch is set to

-- name, what is done, then the rule it tests
local CASES = {
	{ id = "plain", label = "A: drawn, then SetAlpha while shown (control)" },
	{ id = "hidden", label = "B: drawn, frame hidden, SetAlpha, shown again" },
	{ id = "anim", label = "C: SetAlpha while an Alpha animation runs on the frame" },
	{ id = "texhide", label = "D: drawn, the texture itself hidden, SetAlpha, shown again" },
}
L.ALPHA_CASES = CASES

-- answers = { plain = "faint"|"solid", ... } -> the line the lab logs
function L.AlphaVerdict(a)
	local function word(id) return a[id] or "?" end
	local parts = {}
	for _, c in ipairs(CASES) do parts[#parts + 1] = c.id .. "=" .. word(c.id) end
	local out = table.concat(parts, " ")
	if a.plain ~= "faint" then return out .. " -> control did not fade: the probe itself is unreliable, run it again" end
	local function rule(id) return a[id] == "solid" and "ignored" or (a[id] == "faint" and "honoured" or "unknown") end
	return out .. (" -> drawn-then-hidden frame: alpha %s; under an Alpha animation: %s; hidden texture: %s"):format(rule("hidden"), rule("anim"), rule("texhide"))
end

local P = { rows = {}, answers = {} }
L.alphaProbeState = P

local function finish()
	for _, c in ipairs(CASES) do if not P.answers[c.id] then return end end
	local text = L.AlphaVerdict(P.answers)
	if L.db then L.db.alphaProbe = { at = L.Epoch(), answers = P.answers, text = text } end
	L.Log("probe", "alphaprobe: " .. text)
	L.Say("alphaprobe: " .. text)
end

local function answer(id, v)
	P.answers[id] = v
	local row = P.rows[id]
	if row and row.said then row.said:SetText(v) end
	finish()
end

-- one swatch: a dark box (so faint shows) with a red texture on it
local function makeRow(parent, i, c)
	local row = { }
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(60, 30)
	box:SetPoint("TOPLEFT", 16, -40 - (i - 1) * 44)
	local back = box:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(0.05, 0.05, 0.05, 1)
	local tex = box:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetColorTexture(1, 0, 0, 1)
	row.box, row.tex = box, tex
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", box, "RIGHT", 10, 0)
	fs:SetWidth(250); fs:SetJustifyH("LEFT")
	fs:SetText(c.label)
	local function btn(text, x, v)
		local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		b:SetSize(54, 22); b:SetPoint("LEFT", box, "RIGHT", x, 0); b:SetText(text)
		b:SetScript("OnClick", function() answer(c.id, v) end)
	end
	btn("Faint", 270, "faint")
	btn("Solid", 328, "solid")
	row.said = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.said:SetPoint("LEFT", box, "RIGHT", 388, 0)
	P.rows[c.id] = row
	return row
end

local function readback(id)
	local row = P.rows[id]
	local v = row and row.tex and call(row.tex.GetAlpha, row.tex)
	if type(v) == "number" then L.Log("probe", ("alphaprobe %s: GetAlpha reads %.2f after SetAlpha(%.2f)"):format(id, v, WANT)) end
end

-- Every step is on its own timer, so a hidden swatch really is hidden for a while when the alpha is set:
-- drawn shown (0 s), hidden (0.5 s), alpha set while hidden (0.8 s), shown again (1.1 s).
local function run()
	local plain, hidden, anim, texhide = P.rows.plain, P.rows.hidden, P.rows.anim, P.rows.texhide
	local gen = P.gen
	local function at(t, fn) L.After(t, function() if P.gen == gen then fn() end end) end
	at(0.5, function()
		hidden.box:Hide(); texhide.tex:Hide()
		plain.tex:SetAlpha(WANT); readback("plain")
		-- C: an Alpha animation that loops until Close, the alpha set while it runs
		local ok, ag = pcall(anim.box.CreateAnimationGroup, anim.box)
		if ok and ag then
			P.ag = ag
			local a = ag:CreateAnimation("Alpha")
			a:SetFromAlpha(1); a:SetToAlpha(1); a:SetDuration(2)
			pcall(ag.SetLooping, ag, "REPEAT")
			ag:Play()
		end
	end)
	at(0.8, function()
		hidden.tex:SetAlpha(WANT); readback("hidden")
		texhide.tex:SetAlpha(WANT); readback("texhide")
		anim.tex:SetAlpha(WANT); readback("anim")
	end)
	at(1.1, function() hidden.box:Show(); texhide.tex:Show() end)
end

local function stopAnim()
	P.gen = (P.gen or 0) + 1
	if P.ag then pcall(P.ag.Stop, P.ag); P.ag = nil end
end

function L.AlphaProbe(arg)
	arg = (str(arg) or ""):lower()
	if arg == "result" then
		local r = L.db and L.db.alphaProbe
		L.Say(r and ("alphaprobe: " .. tostring(r.text)) or "alphaprobe: not run yet (/lab alphaprobe)")
		return
	end
	if arg == "stop" or arg == "close" then
		stopAnim()
		if P.frame then P.frame:Hide() end
		return
	end
	if InCombatLockdown and InCombatLockdown() then L.Say("alphaprobe: not in combat"); return end
	stopAnim()
	if P.frame then P.frame:Hide() end
	P.answers = {}
	local f = CreateFrame("Frame", "WuberLabAlphaProbe", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	P.frame, P.rows = f, {}
	f:SetSize(520, 40 + #CASES * 44 + 40)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	f:SetFrameStrata("DIALOG")
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		f:SetBackdropColor(0.043, 0.043, 0.086, 0.97)
		f:SetBackdropBorderColor(0.533, 0.247, 0.855, 1)
	end
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Alpha probe: each swatch was set to a faint alpha. Is it faint or solid red?")
	for i, c in ipairs(CASES) do makeRow(f, i, c) end
	local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	close:SetSize(60, 22); close:SetPoint("BOTTOMRIGHT", -12, 10); close:SetText("Close")
	close:SetScript("OnClick", function() stopAnim(); f:Hide() end)
	f:Show()
	L.Say("alphaprobe: look at the four swatches, then press Faint or Solid under each")
	run()
end
