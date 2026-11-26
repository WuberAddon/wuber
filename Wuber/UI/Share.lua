-- Module: UI.Share
-- Purpose: the share pills (flex, wrapped, cut): a page registers its pill and the line it shares;
--   the secure WuberShareButton (UI.Secure) docks over the visible one and posts it to party/raid
--   on the player's click.
-- API: UI.Share, UI.Share.Register, UI.Share.Target, UI.Share.Sync, UI.Share.State, UI.Share.Macro,
--   UI.Share.Shared
-- Internals: (none)
-- Uses: UI.Kit, UI.Secure
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/share_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 section 5.0; owner A)
--
-- How a page uses it (SPEC7 5.0):
--   UI.Share.Register(pill, textFn, opts)
--     pill: a T.Pill in the page's primary pane (never the side pane); textFn() -> the line to
--     share now, or nil when there is nothing to share (not arrived yet, already shared: the
--     page keeps its own limits - flex once per ride, wrapped once per 60 s, cut once per card);
--     opts.label: the pill's words (default "Share"); opts.guild: true to prefer guild chat ("/g ")
--     when in a guild; opts.onShared(line): after a post (opts may also be just that function).
--   UI.Share owns the pill's visibility and words from then on (UI.Share.Sync, run by the
--   window's refresh): hidden when not in a group (nor guild when opts.guild) or textFn() gives nil;
--   "Share after combat" (dimmed, no overlay) in combat; else opts.label. The page only places the pill.
--   UI.Share.Target() -> the visible pill the overlay docks on now (UI.Secure), else nil.
--   UI.Share.State(pill) -> "ok" | "combat" | "solo" | "none" | nil (not registered).
--   UI.Share.Macro(pill) -> "/p <line>" ("/ra <line>" in a raid), line; nil when the line fails
--     the checks (one line, at most 240 characters, W.SentenceSpam, no links, never the word
--     "gold": "Goldshire" and "Marigold" are fine).
--   UI.Share.Shared(pill, line): the overlay's PostClick (calls opts.onShared, a toast).
-- Hard rules: the macro text is set only in the secure button's PreClick and emptied in its
-- PostClick (UI.Secure); nothing is posted from code; out of combat only (H1, H6).

local _, W = ...
local Mod = W.Module("UI.Share", { "UI.Kit", "UI.Secure" })
local KitMod = W.Mod("UI.Kit")
local S = KitMod.S
local call = KitMod.call
local inCombat = KitMod.inCombat
local inGroup = KitMod.inGroup
local inRaid = KitMod.inRaid
local macroSafe = KitMod.macroSafe
local setShown = KitMod.setShown
local UI = W.UI

local Share = {}
UI.Share = Share

local MAX_LINE = 240 -- "/ra " + 240 stays well under the macro's 255
local AFTER_COMBAT = "Share after combat"
local COMBAT_W = 124 -- a pill reading AFTER_COMBAT is at least this wide

-- (HUNT-129) the pill is as wide as its words: their measured width, with the pill's own side padding (half its
-- height each side) and a little spare, never less than COMBAT_W
local function combatWidth(p)
	local T = W.Theme
	local h = tonumber((p.GetHeight and p:GetHeight())) or 30
	if not (T and T.MeasureText) then return COMBAT_W end
	local size, weight = "sub", "medium"
	if h >= 48 then size, weight = "heading", "bold" elseif h >= 36 then size = "body" end
	local ok, m = pcall(T.MeasureText, AFTER_COMBAT, size, weight)
	m = ok and tonumber(m) or 0
	return math.max(COMBAT_W, math.ceil(m * 1.06) + h + 2)
end

local pills = {} -- in the order they were registered: { pill, textFn, label, onShared }
local byPill = {}

local function inGuild()
	local v = type(IsInGuild) == "function" and W.Plain(call(IsInGuild))
	return v == true or v == 1
end

-- a page's share pill and the function giving its line
function Share.Register(pill, textFn, opts)
	if type(pill) ~= "table" or type(pill.IsVisible) ~= "function" or type(textFn) ~= "function" then return false end
	if type(opts) == "function" then opts = { onShared = opts } end -- (the short form: onShared)
	opts = type(opts) == "table" and opts or {}
	local e = byPill[pill]
	if not e then
		e = { pill = pill }
		pills[#pills + 1] = e
		byPill[pill] = e
	end
	e.textFn = textFn
	e.label = S(opts.label) or "Share"
	e.onShared = type(opts.onShared) == "function" and opts.onShared or nil
	e.guild = opts.guild == true
	W.Safe("share", Share.Sync)
	return true
end

-- the line to share, cleaned (nil: nothing to share, or it fails a check)
local function lineOf(e)
	local line = macroSafe(call(e.textFn), MAX_LINE)
	if not line then return nil end
	local low = line:lower()
	if low:find("%f[%a]gold%f[%A]") or low:find("http", 1, true) or low:find("www.", 1, true) or low:find("://", 1, true) then
		return nil
	end
	if type(W.SentenceSpam) == "function" and call(W.SentenceSpam, line) then return nil end
	return line
end

local function state(e)
	if not (inGroup() or (e.guild and inGuild())) then return "solo" end
	if not lineOf(e) then return "none" end
	if inCombat() then return "combat" end
	return "ok"
end

function Share.State(pill)
	local e = pill and byPill[pill]
	if not e then return nil end
	return state(e)
end

-- Shows, hides and words every registered pill (the window's refresh runs it).
function Share.Sync()
	for _, e in ipairs(pills) do
		local p = e.pill
		local st = state(e)
		local show = st == "ok" or st == "combat"
		setShown(p, show)
		local words = st == "combat" and AFTER_COMBAT or e.label
		if show and e.words ~= words then
			e.words = words
			-- HUNT-97: "Share after combat" is wider than the plain pill, so the pill widens for it and goes back
			if type(p.SetWidth) == "function" and type(p.GetWidth) == "function" then
				e.baseW = e.baseW or tonumber((p:GetWidth()))
				if e.baseW then p:SetWidth(st == "combat" and math.max(e.baseW, combatWidth(p)) or e.baseW) end
			end
			if type(p.SetLabel) == "function" then
				p:SetLabel(words)
			elseif p.label and type(p.label.SetText) == "function" then
				p.label:SetText(words)
			end
			if type(p.SetActive) == "function" then p:SetActive(st ~= "combat") else p:SetAlpha(st == "combat" and 0.5 or 1) end
		end
	end
end

-- the pill the share overlay should sit on now
function Share.Target()
	if inCombat() then return nil end
	for _, e in ipairs(pills) do
		if e.pill:IsVisible() and not e.pill.dockHold and state(e) == "ok" then return e.pill end
	end
	return nil
end

-- "/g <line>" (guild when opts.guild), "/p <line>" (party) or "/ra <line>" (raid) for the pill's line now, and the line
function Share.Macro(pill)
	local e = pill and byPill[pill]
	if not e or inCombat() then return nil end
	local prefix
	if e.guild and inGuild() then
		prefix = "/g "
	elseif inGroup() then
		prefix = inRaid() and "/ra " or "/p "
	else
		return nil
	end
	local line = lineOf(e)
	if not line then return nil end
	return prefix .. line, line
end

-- the overlay was clicked and the line went out
function Share.Shared(pill, line)
	local e = pill and byPill[pill]
	if not e then return end
	local toGuild = e.guild and inGuild()
	if e.onShared then W.Safe("share", e.onShared, line) end
	if UI.Toast then
		local msg = toGuild and "Shared with your guild" or (inRaid() and "Shared with your raid" or "Shared with your party")
		UI.Toast(msg, "info")
	end
	Share.Sync()
end
