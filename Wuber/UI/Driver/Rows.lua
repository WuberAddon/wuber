-- Module: UI.Driver.Rows
-- Purpose: Queue rows: what a row says (D.Describe, D.RowTip), what its clicks do (D.RowAction,
--   D.RowClick, D.OpenMenu, raid rows), D.Row / D.PaintRow.
-- API: D.STATE, D.Describe, D.RowTip, D.RowAction, D.RowClick, D.OpenMenu, D.RaidAction,
--   D.RaidRowClick, D.DescribeRaid, D.RaidTip, D.Row, D.LayRow, D.RideCount, D.PaintAgain,
--   D.PaintRaidRow, D.PaintRow, D.Passphrase, D.RaincheckRide, D.GiveRaincheck, D.ToggleGetApp
-- Internals: layRow (design 3: the chips flow onto more lines and the row grows, r.grown / r.laidH; lists place
--   the next row by its height), textW, paintGetApp (the "Invite to Wuber" pill on a chat rider's row, made
--   on first use; a tap only queues or cancels the whisper, the big button's next click sends it),
--   SUMMON_FORMS, summonSays (2.4: the game's word on a rider's summon, DR.SummonSeen: "has the summon
--   window", "summon accepted", "declined: summon again?", or a shorter form where the row is narrow)
-- Uses: UI.Driver.State
-- Later: UI.Driver.Mini (UI.ShowDrive, when D.OpenMenu finds the Drive page hidden)
-- Events: listens Listen DRIVE_PAID, Listen DRIVE_LOG; fires -; reads D.ui (UI.Driver.Console's ui)
-- Standalone: no
-- Test: tests/ui/driver/rows_test.lua
-- From: Driver.lua 438-855 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Rows", { "UI.Driver.State" })
local StateMod = W.Mod("UI.Driver.State")
local N, Price, ROW_H, S = StateMod.N, StateMod.Price, StateMod.ROW_H, StateMod.S
local call, dr, money, now = StateMod.call, StateMod.dr, StateMod.money, StateMod.now
local safeScript, setShown, short, toast = StateMod.safeScript, StateMod.setShown, StateMod.short, StateMod.toast
local T = W.Theme

local DR = W.Drive

local D = W.Driver

local function adv()
	return type(W.Advanced) ~= "function" or W.Advanced() == true
end

---------------------------------------------------------------------------
-- The queue: what a row says, and what its clicks do (RR's rules, unchanged)
---------------------------------------------------------------------------

-- the state colours (RR's STATE table, in the Wuber palette)
D.STATE = {
	lead = "off", queued = "muted", invited = "muted", joined = "white", summoning = "glow",
	waiting = "glow", arrived = "white", paid = "glow", done = "off",
}

-- (round 13, I17) a wait as a stopwatch, "0:30" / "4:05", from 10 minutes "17 min" (not a time of
-- day): "30s" read as 30 silver next to "owes 50s"
local function secs(n)
	n = math.max(0, math.floor(n or 0))
	if n >= 600 then return math.floor(n / 60) .. " min" end
	return ("%d:%02d"):format(math.floor(n / 60), n % 60)
end

local function due(c)
	local d = N(dr("Due", c))
	if d then return d end
	return math.max(0, (N(c.price) or Price()) - (N(c.paid) or 0))
end

-- (2.4) What the game itself says about this rider's summon (DR.SummonSeen, Drive.Cast: only for a rider without
-- Wuber, only an answer newer than the latest cast): the row's words, right-hand text and colour, or nil = the
-- row says what it always said. A summon that is waiting is the fact the rows already call "has the summon
-- window", so it keeps those words; accepted and declined are new. The declined words end in the question the
-- driver answers with a click on the row (its tooltip: "Click: summon this one next"). Each has shorter forms,
-- longest first: the row shows the first that fits (as a lead's chat line does), never a cut one. (The study's
-- "summon declined: summon again?" needs 214 px at the smallest size; the widest row has 217 for a three-letter
-- name, so it would never show: the rider is the subject here, as in "has the summon window" and "landed".)
local ACCEPTED = { "summon accepted", "accepted" }
local DECLINED = { "declined: summon again?", "summon declined", "declined" }
local SUMMON_FORMS = { [ACCEPTED[1]] = ACCEPTED, [DECLINED[1]] = DECLINED }
local function summonSays(c, t, right)
	local seen, since = dr("SummonSeen", c)
	if seen == "waiting" then return "has the summon window", right or secs(t - (N(since) or t)), "glow" end
	if seen == "accepted" then return ACCEPTED[1], right or "", "glow" end
	if seen == "declined" then return DECLINED[1], right or "", "red" end
	return nil
end

-- What a row says about its rider, the right-hand text and its colour (RR's describe()).
function D.Describe(c, t)
	t = t or now()
	local s = c.state
	if S(c.helperOf) then return "came with " .. short(c.helperOf) .. "?", "", "muted" end
	if s == "lead" then
		if c.busy then return "already in a group", "", "muted" end
		if c.wantsPrice then return c.priceTold and "asked the price - answered" or "asks the price", "", "muted" end
		local msg = W.Clean(S(c.msg) or "", 40)
		return msg ~= "" and ("\"" .. msg .. "\"") or "asked in chat", "", "muted"
	elseif s == "queued" then
		return "in the queue", secs(t - (N(c.at) or t)), "muted"
	elseif s == "invited" then
		return "invited", secs(t - (N(c.invitedAt) or N(c.at) or t)), "muted"
	elseif s == "joined" then
		local what, right, colour = summonSays(c, t)
		if what then return what, right, colour end
		return (N(c.tries) or 0) > 0 and "summon again" or "ready to summon", "", "white"
	elseif s == "summoning" then
		local who = c.caster == W.myKey and "you" or (S(dr("WhoIs", c.caster)) or "?")
		return "summoning (" .. who .. ")", "", "glow"
	elseif s == "waiting" then
		local what, right, colour = summonSays(c, t)
		if what and what ~= "has the summon window" then return what, right, colour end
		return "has the summon window", secs(t - (N(c.endAt) or N(c.at) or t)), "glow"
	elseif s == "arrived" then
		if c.walked then return "is here (no ride)", "", "muted" end
		-- they pay the summoner who cast them; one without Wuber can't see the trade
		local payee = D.PayeeName(c)
		if c.payeeBlind and payee then return "paid? ask " .. payee, "owes " .. money(due(c)), "gold" end
		if (N(c.paid) or 0) > 0 then return "paid " .. money(c.paid), "owes " .. money(due(c)), "gold" end
		return payee and ("landed · pays " .. payee) or "landed", "owes " .. money(due(c)), "gold"
	elseif s == "paid" then
		return c.gone and "paid, left" or "paid", (N(c.paid) or 0) > 0 and money(c.paid) or "", "glow"
	end
	return "done", (N(c.paid) or 0) > 0 and money(c.paid) or "", "muted"
end

local SOURCE_TEXT = { whisper = "whisper", public = "in chat", manual = "added by you", group = "in your group" }

-- (2.3) The two words an app rider sees on their Found screen ("Violet Otter"), from
-- the ride id (W.Passphrase, Net.Portal). Only for riders who booked through the app; nil
-- otherwise, or while the network can't say. (Round 9, C4) A crew window knows the ride only from
-- ST field 9 (c.rideId, its row's source "group" or "relay"): it shows the words only while the
-- passphrase setting is on (W.PassphraseOn, which follows the captain); with that setting off,
-- no window shows them (the rider doesn't see them either).
function D.Passphrase(c)
	if type(c) ~= "table" or type(W.Passphrase) ~= "function" then return nil end
	local ride = S(c.wuberRide) or S(c.rideId)
	if not ride then return nil end
	local on = type(W.PassphraseOn) == "function" and call(W.PassphraseOn) or nil
	if type(W.PassphraseOn) == "function" and on ~= true then return nil end
	if not (c.source == "wuber" or c.wuberRide) and on ~= true then return nil end
	local who = W.Key(S(c.wuberBuyer) or S(c.name) or "")
	if not who then return nil end
	local words = S(call(W.Passphrase, ride, who))
	if not words or words == "" then return nil end
	return W.Clean(words, 32)
end

-- the row's tooltip lines (all four actions, in this order)
function D.RowTip(c)
	if type(c) ~= "table" then return "" end
	local lines = {}
	local look = T.PioneerLook(S(c.name)) -- a Pioneer: the shipped list only
	if look then lines[#lines + 1] = T.PIONEER[look].tip end
	local label = S(c.wuberLabel)
	if label then lines[#lines + 1] = label end
	if S(c.msg) then lines[#lines + 1] = "\"" .. W.Clean(S(c.msg), 120) .. "\"" end
	if c.source == "wuber" then lines[#lines + 1] = "Booked through the Wuber app." end
	local pass = D.Passphrase(c)
	if pass then lines[#lines + 1] = "Passphrase: " .. pass .. " (the rider sees the same words)." end
	if D.CustomerTip then D.CustomerTip(c, lines) end -- round 9: the note and the Gifted stamp
	if S(c.station) and #D.Stations() >= 2 then lines[#lines + 1] = "Summoned at " .. S(c.station) .. "." end
	local payee = D.PayeeName(c)
	if payee and c.payeeBlind then
		lines[#lines + 1] = payee .. " has no Wuber, so nobody sees the trade: ask " .. payee .. " if they paid, then Mark as paid."
	elseif payee then
		lines[#lines + 1] = "Pays " .. payee .. " (the Warlock who summons them)."
	end
	lines[#lines + 1] = " "
	if S(c.helperOf) then
		lines[#lines + 1] = "Click: options." -- (r46 AUD-124) same order as D.RowClick: a helper row opens the menu
	elseif c.state == "lead" or (c.state == "queued" and dr("ClickInvites", c) == true) then
		lines[#lines + 1] = "Click: invite them."
	elseif c.state == "joined" or c.state == "waiting" then
		lines[#lines + 1] = "Click: summon this one next."
	else
		lines[#lines + 1] = "Click: options."
	end
	lines[#lines + 1] = "Ctrl-click: mark as paid."
	lines[#lines + 1] = "Right-click: take off the list."
	lines[#lines + 1] = "Shift-right-click: block (never serve again)."
	lines[#lines + 1] = "Hold, or the Options button: all options."
	return table.concat(lines, "\n")
end

-- is this still the engine's customer (not a stale row)?
local function live(c)
	if type(c) ~= "table" then return false end
	local cs = DR.customers
	if type(cs) ~= "table" or not c.key then return true end
	return cs[c.key] == c
end

-- what = "invite" | "next" | "paid" | "oops" | "drop" | "block" | "helper"
function D.RowAction(c, what, reason)
	if not live(c) then return false end
	local name = S(c.name)
	if not name then return false end
	if what == "invite" then
		if type(DR.Invite) == "function" then call(DR.Invite, c) else call(DR.Request, name, "manual", c.msg) end
	elseif what == "next" then
		if type(DR.SetPriority) == "function" then
			call(DR.SetPriority, c)
		else
			c.priority = true
			call(DR.SetState, c, "joined")
		end
	elseif what == "paid" then
		if type(DR.MarkPaid) == "function" then call(DR.MarkPaid, c) else call(DR.Do, "PAID", name, 0, "m") end
	elseif what == "oops" then
		if type(DR.Oops) ~= "function" or call(DR.Oops, c) ~= true then return false end
	elseif what == "drop" then
		call(DR.Do, "DROP", name)
	elseif what == "block" then
		call(DR.Blacklist, name, S(reason) or "blocked by hand")
		toast(short(name) .. " won't be served again. Undo it in Blocked.", "info")
	elseif what == "helper" then
		call(DR.NotRider, c)
	else
		return false
	end
	call(DR.Changed)
	D.Refresh()
	return true
end

-- a click on a row (button "LeftButton"/"RightButton"; ctrl/shift read from the game)
function D.RowClick(c, button)
	if not live(c) then return end
	local shift = call(IsShiftKeyDown) == true
	local ctrl = call(IsControlKeyDown) == true
	if button == "RightButton" then
		if shift then return D.RowAction(c, "block") end
		return D.RowAction(c, "drop")
	end
	if ctrl then return D.RowAction(c, "paid") end
	if S(c.helperOf) then return D.OpenMenu(c) end
	if c.state == "lead" then return D.RowAction(c, "invite") end
	-- (r30 HUNT-12) "Invite riders who whisper me" off: the click invites a queued rider
	if c.state == "queued" and dr("ClickInvites", c) == true then return D.RowAction(c, "invite") end
	if c.state == "joined" or c.state == "waiting" then return D.RowAction(c, "next") end
	return D.OpenMenu(c)
end

-- (2.3) A raincheck for this rider's failed paid ride: the ride id when the book
-- (DR.RaincheckEligible, Drive.Raincheck) says it may have one, else nil and why. The driver's
-- click gives it (DR.GiveRaincheck); it counts only once the rider accepts.
function D.RaincheckRide(c)
	if type(c) ~= "table" then return nil end
	local ride = S(c.wuberRide) or S(c.rideId)
	if not ride then return nil end
	local yes, why = dr("RaincheckEligible", ride)
	if yes ~= true then return nil, S(why) end
	return ride
end

function D.GiveRaincheck(c)
	local ride = D.RaincheckRide(c)
	local who = short(type(c) == "table" and c.name or nil)
	if not ride then
		toast("No raincheck for this ride: only a ride paid by trade that failed before " .. who .. " arrived", "warn")
		return false
	end
	if dr("GiveRaincheck", ride) ~= true then
		toast("Couldn't offer a raincheck to " .. who, "warn")
		return false
	end
	toast("Raincheck offered to " .. who .. ". It counts once they accept.", "info")
	D.Refresh()
	return true
end

-- "Get Wuber" for a chat rider without the app: queued for the big button's next
-- click (DR.AskGetApp; the whisper only ever leaves on that secure click), or cancelled when it
-- already is. The row's pill and the row menu both call this. Returns true when it changed.
function D.ToggleGetApp(c)
	if not live(c) then return false end
	local queued = dr("GetAppState", c) == "queued"
	local changed = dr("AskGetApp", c, not queued) == true
	if changed then
		toast(queued and "\"Get Wuber\" won't be sent"
			or ("Your next big-button click tells " .. short(c.name) .. " how to get Wuber"), "info")
	end
	D.Refresh(true)
	return changed
end

function D.OpenMenu(c)
	local f = D.screens and D.screens.menu
	if type(f) ~= "function" then return false end
	-- (round 33, AUD-121) from the floating mini console the Drive page is hidden: open the window on
	-- the Drive tab first (UI.ShowDrive, as the raincheck toast does), or the menu opens unseen
	local root = D.ui and D.ui.root
	if not (root and root:IsVisible()) and W.UI and type(W.UI.ShowDrive) == "function" then
		call(W.UI.ShowDrive, "console")
	end
	if not D.ui then return false end
	call(D.ShowSheet, "menu", c)
	return true
end

-- Raid summon rows (DR.RaidQueue(): name, asked, state, claimedBy, tries). what = "top" | "drop"
function D.RaidAction(row, what)
	local name = type(row) == "table" and S(row.name)
	if not name then return false end
	if what == "top" then
		if type(DR.RaidTop) ~= "function" then return false end
		call(DR.RaidTop, name)
		toast(short(name) .. " is summoned next", "info")
	elseif what == "drop" then
		call(DR.RaidDrop, name, "hand")
		toast(short(name) .. " is off the list", "info")
	else
		return false
	end
	D.Refresh(true)
	return true
end

-- left: summon this one next (unless a Warlock already has them), right: off the list
function D.RaidRowClick(row, button)
	if type(row) ~= "table" then return end
	if button == "RightButton" then return D.RaidAction(row, "drop") end
	if S(row.claimedBy) then return D.OpenMenu(row) end
	return D.RaidAction(row, "top")
end

function D.DescribeRaid(row, t)
	t = t or now()
	local asked = N(row.asked)
	local ago = asked and secs(t - asked) or ""
	local by = S(row.claimedBy)
	-- (2.4) the game's word on this raider's summon; a raider who is being summoned keeps "summoning (...)"
	local seenWhat, _, seenColour = summonSays(row, t, ago)
	if row.state == "waiting" then
		if seenWhat then return seenWhat, ago, seenColour end
		return "has the summon window", ago, "glow"
	end
	if by then
		local who = by == W.myKey and "you" or short(S(dr("WhoIs", by)) or by)
		return "summoning (" .. who .. ")", ago, "glow"
	end
	if seenWhat then return seenWhat, ago, seenColour end
	local tries = N(row.tries) or 0
	if tries > 0 then return "summon again (try " .. (tries + 1) .. ")", ago, "red" end
	return "asked for a summon", ago, "white"
end

function D.RaidTip(row)
	if type(row) ~= "table" then return "" end
	local lines = {}
	local what = D.DescribeRaid(row)
	local look = T.PioneerLook(S(row.name))
	if look then lines[#lines + 1] = T.PIONEER[look].tip end
	lines[#lines + 1] = (what:gsub("^%l", string.upper)) .. "."
	lines[#lines + 1] = " "
	lines[#lines + 1] = "Click: summon this one next."
	lines[#lines + 1] = "Right-click: take off the list (nothing is said)."
	lines[#lines + 1] = "Hold, or the Options button: all options."
	return table.concat(lines, "\n")
end

-- (design 1 J) the row menu button says "Options" (a small raised (card2) pill, white words), not three dots.
-- OPT_W is its width; the row keeps OPT_W + 12 free at its right end (layRow).
local OPT_W = 60
local OPT_H, OPT_LOW = 22, 20 -- its height; OPT_LOW in a 44-high row with a chip under its column (layRow)
local function optionsLook(b)
	b.fill = T.Rounded(b, "raised", 11, "BACKGROUND", 0) -- "raised" is card2 once group C sets the values
	b.label = T.Text(b, "caption", "white", "CENTER", "medium")
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetWidth(OPT_W - 4)
	b.label:SetText("Options")
end

-- the width a label's words take (Inter's own measure when the addon's fonts are on)
local function textW(fs)
	local t = fs.wuberText or ""
	if t == "" then return 0 end
	if T.poppins ~= false and fs.wuberPx then return math.ceil(T.MeasureText(t, fs.wuberPx, fs.wuberWeight)) + 1 end
	return math.ceil(T.TextWidth(fs, t)) + 1
end

-- A queue row (used by the console and the floating mini console): a ringed initial, then one
-- calm line "Dan · ready to summon", the time or what they owe on the right, and "...". The
-- repeat-rider and station chips sit on a second line only when there is one.
function D.Row(parent, w)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(w, ROW_H)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r.bg = T.Rounded(r, "card", 14, "BACKGROUND", 0)
	r.disc = T.Circle(r, 32, "panel", "ARTWORK")
	r.disc:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.ring = T.Tex(r, "ring", "ARTWORK", 1)
	r.ring:SetSize(34, 34)
	r.ring:SetPoint("CENTER", r.disc, "CENTER")
	r.initial = T.Text(r, "body", "white", "CENTER", "bold")
	r.initial:SetPoint("CENTER", r.disc, "CENTER", 0, 0)
	r.app = T.Tex(r, "portal", "OVERLAY", 2)
	r.app:SetSize(15, 15)
	r.app:SetPoint("CENTER", r.disc, "BOTTOMRIGHT", -2, 3)
	r.name = T.Text(r, "body", "white", "LEFT", "bold")
	-- (design round 3) the status words are one size under the name, as they always were (13 under 14 once):
	-- sub under body. At body the words box (242 at the usual console width) lost " · in your group"
	r.what = T.Text(r, "sub", "muted", "LEFT", "regular")
	r.right = T.Text(r, "body", "white", "RIGHT", "bold")
	r.right:SetPoint("RIGHT", r, "RIGHT", -(OPT_W + 10), 0)
	r.right:SetWidth(68)
	r.more = CreateFrame("Button", nil, r)
	r.more:SetSize(OPT_W, OPT_H)
	r.more:SetPoint("RIGHT", r, "RIGHT", -6, 0)
	r.more:RegisterForClicks("LeftButtonUp")
	optionsLook(r.more)
	T.Press(r.more, { fill = r.more.fill })
	safeScript(r.more, "OnClick", function() D.OpenMenu(r.c) end)
	T.Tip(r.more, "Options", function() return "Everything you can do for " .. short(r.c and r.c.name) .. "." end)
	-- the long press (0.4 s held = the menu): the OnUpdate runs only while the button is down,
	-- never on an idle row (review #27)
	local function holdStop(self)
		self.downAt = nil
		self:SetScript("OnUpdate", nil)
	end
	local function holdTick(self)
		if self.downAt and now() - self.downAt >= 0.4 then
			holdStop(self)
			self.held = true
			D.OpenMenu(self.c)
		elseif not self.downAt then
			holdStop(self)
		end
	end
	r.holdTick = holdTick
	safeScript(r, "OnEnter", function(self) self.bg:SetColor("hover") end)
	safeScript(r, "OnLeave", function(self)
		self.bg:SetColor("card")
		holdStop(self)
	end)
	safeScript(r, "OnMouseDown", function(self, button)
		if button == "LeftButton" or button == nil then
			self.downAt, self.held = now(), nil
			safeScript(self, "OnUpdate", holdTick)
		end
	end)
	safeScript(r, "OnMouseUp", holdStop)
	safeScript(r, "OnHide", holdStop)
	T.Press(r, { fill = r.bg })
	safeScript(r, "OnClick", function(self, button)
		if self.held then
			self.held = nil
			return
		end
		if self.raidRow then return D.RaidRowClick(self.c, button or "LeftButton") end
		D.RowClick(self.c, button or "LeftButton")
	end)
	T.Tip(r, function(self) return S(self.c and self.c.name) or "Rider" end, function(self)
		if self.raidRow then return D.RaidTip(self.c) end
		return D.RowTip(self.c)
	end)
	-- a returning rider (review #19): "3rd ride with you", on the second line
	r.again = T.Chip(r, "", "muted")
	r.again:Hide()
	-- the station this rider is summoned at (only with 2+ stations)
	r.station = T.Chip(r, "", "glow")
	r.station:Hide()
	-- (2.3) the app rider's passphrase, "· Violet Otter", made the first time one shows
	r:Hide()
	return r
end

-- room for the right-hand text before it is set, so T.Fit measures it at its base size, not
-- at the width the last (shorter) text left behind
local function roomRight(r)
	r.right:SetWidth(math.max(68, (N(r:GetWidth()) or 300) * 0.5))
end

-- Lays a row out: the name and what on one line (with the chips under them when shown).
-- (design 3) The chips flow: one that does not fit its line (beside the Options button when that sits on the
-- second line, else the row's width) starts the next line,
-- (design 3 R1) With the button on the name's line its 22-high box still reaches 1 into the 20-high chips'
-- line, so a chip that would lie under the button's column must be clear of it: a row of 52 or more (the
-- console's) lifts the button 2 and lowers the chip lines 1 (2 clear, 4 to the row's edges).
-- (design 3 R3) A lower row (the mini console's 44) has no height for that, and a third line for one unit is
-- too dear over the game world: there the button is OPT_LOW (20) high and the chips stay. Under it is nearly
-- always the 18-high Invite pill: the button sits 1 higher (2 to the row's top, 2 clear, 2 to its foot:
-- 2 + 20 + 2 + 18 + 2 = 44). Over a 20-high chip it sits 2 higher (1 + 20 + 2 + 20 + 1). The button is OPT_H
-- again in every other layout. The row grows CHIP_LINE for each line past the
-- second (r.grown; base height = what the list gave the row). Lists place the next row by r:GetHeight().
local CHIP_LINE = 22 -- an 18-high chip and 4 clear
local RowsTextW = textW
local function layRow(r)
	-- (#260, #272) the room a row gives its name and its right-hand words: textW (the font table's width) plus 7%, as the game
	-- draws them (Build.lua and Mini.lua use textW as it is, with their own spare)
	local function textW(fs) return math.ceil(RowsTextW(fs) * 1.07) end
	local wdt = N(r:GetWidth()) or 300
	-- the height the list gave the row: ours less what we added, unless the list has set it again since
	local hNow = N(r:GetHeight()) or ROW_H
	local base = (r.laidH and math.abs(hNow - r.laidH) < 0.5) and (hNow - (r.grown or 0)) or hNow
	local x0 = 52
	local rw = textW(r.right)
	r.right:SetWidth(math.max(1, rw))
	-- (design 1 J) the words keep their room: when they do not fit beside the Options button, the
	-- button drops to the row's second line (right end) and the words take the full width
	local gap = rw > 0 and rw + 10 or 0
	-- (#260) the 7% spare is for the width each word gets, not for the choice of line: that choice is made on the font table's own
	-- widths, as before #260, so a narrow row does not tip into a third chip line only because of the spare
	local rwRaw = RowsTextW(r.right)
	local gapRaw = rwRaw > 0 and rwRaw + 10 or 0
	-- (the same measure as fits() below, T.TextWidth: with a narrower one the words were judged to fit beside the
	-- button, then failed the stricter check and stepped down to a shorter form)
	local beside = wdt - x0 - (OPT_W + 12) - gapRaw
	local nameBeside = math.min(RowsTextW(r.name), math.floor(beside * 0.6))
	local need = N(T.TextWidth(r.what)) or textW(r.what)
	local stacked = need > math.max(20, beside - nameBeside) + 1
	local reserve = stacked and 10 or (OPT_W + 12)
	local room = wdt - x0 - reserve - gap
	local nw = math.min(textW(r.name), math.floor(room * 0.6))
	r.name:SetWidth(math.max(20, nw))
	r.what:SetWidth(math.max(20, room - nw))
	local invite = r.getapp ~= nil and r.getapp:IsShown()
	local pass = r.pass ~= nil and r.pass:IsShown()
	local chips = invite or r.again:IsShown() or r.station:IsShown() or pass
	-- the chip lines first (their count is the row's height): line 1 is the row's second line
	local line, x = 1, x0
	local full = wdt - 8
	local column = wdt - 6 - OPT_W - 8 -- where the Options button's column starts, less a gap of 8
	local places
	local function flow(limit) -- limit: where the first chip line ends
		line, x, places = 1, x0, {}
		for _, chip in ipairs({ r.station, r.again, r.getapp or false }) do
			if chip and chip:IsShown() then
				local cw = N(chip:GetWidth()) or 60
				if x + cw > limit and (x > x0 or limit < full) then
					line, x, limit = line + 1, x0, full
				end
				places[#places + 1] = { chip, x, line }
				x = x + cw + 5
			end
		end
	end
	flow(stacked and column or full)
	local lift = 0 -- the button up 2 and the chip lines down 1: only for a chip under the button's column
	local low = 0 -- a 44-high row: the button OPT_LOW high and up 1 (over an 18-high pill) or 2 instead
	if not stacked then
		local under, underH = false, 0
		for _, pl in ipairs(places) do
			if pl[3] == 1 and pl[2] + (N(pl[1]:GetWidth()) or 60) > column then
				under = true
				underH = math.max(underH, N(pl[1]:GetHeight()) or 20)
			end
		end
		if under and base >= 52 then
			lift = 1
		elseif under then
			low = underH > 18 and 2 or 1
		end
	end
	local passX, passLine, passW
	if pass then
		local pw = textW(r.pass)
		local plimit = line == 1 and (wdt - (OPT_W + 12)) or full
		if x + pw > plimit and (x > x0 or plimit < full) then
			line, x, plimit = line + 1, x0, full
		end
		passX, passLine, passW = x, line, math.max(20, plimit - x)
	end
	local grown = (line - 1) * CHIP_LINE
	r.grown, r.laidH = grown, base + grown
	if math.abs(hNow - r.laidH) > 0.01 then r:SetHeight(r.laidH) end
	-- a place by the row's left or right edge, dy from the middle of its base height (a grown row hangs
	-- its lines from the top, so the first two stay where an ungrown row has them)
	local function put(region, side, dx, dy)
		region:ClearAllPoints()
		if grown > 0 then
			region:SetPoint(side, r, "TOP" .. side, dx, dy - base / 2)
		else
			region:SetPoint(side, r, side, dx, dy)
		end
	end
	put(r.disc, "LEFT", 10, 0)
	local moreH = low > 0 and OPT_LOW or OPT_H
	if math.abs((N(r.more:GetHeight()) or OPT_H) - moreH) > 0.01 then r.more:SetHeight(moreH) end
	put(r.more, "RIGHT", -6, stacked and -11 or (chips and 9 + 2 * lift + low or 0))
	local two = chips or stacked
	-- (HUNT-119) with a chip line under, the right text rides the name's line, clear of the pill
	put(r.right, "RIGHT", -(stacked and 8 or (OPT_W + 10)), two and 9 or 0)
	put(r.name, "LEFT", x0, two and 9 or 0)
	r.what:ClearAllPoints()
	r.what:SetPoint("LEFT", r.name, "RIGHT", 0, 0)
	for _, p in ipairs(places) do put(p[1], "LEFT", p[2], -11 - lift - (p[3] - 1) * CHIP_LINE) end
	if pass then
		put(r.pass, "LEFT", passX, -11 - lift - (passLine - 1) * CHIP_LINE)
		r.pass:SetWidth(passW)
	end
end
D.LayRow = layRow

-- the station chip (2+ stations only)
local function paintStation(r, place)
	if place then
		r.station:SetChip(W.Clean(place, 14), "glow")
		r.station:Show()
	else
		r.station:Hide()
	end
end

-- How many rides this rider took with you before (B's DR.RideCount, from the log), cached
-- per name until the next payment or log change: rows repaint often, the log is long.
local againCache = {}
function D.RideCount(name)
	name = S(name)
	if not name or type(DR.RideCount) ~= "function" then return 0 end
	local k = W.Key(name) or name
	local n = againCache[k]
	if n == nil then
		n = math.max(0, math.floor(N(call(DR.RideCount, name)) or 0))
		againCache[k] = n
	end
	return n
end
W.Listen("DRIVE_PAID", function() againCache = {} end)
W.Listen("DRIVE_LOG", function() againCache = {} end)

-- the "3rd ride with you" chip (none for a first ride, or a raid row)
local function paintAgain(r, c)
	if not adv() then
		r.again:Hide()
		return
	end
	local before = c and D.RideCount(c.name) or 0
	if before < 1 then
		r.again:Hide()
		return
	end
	local nth = before + 1
	local suffix = (nth % 100 >= 11 and nth % 100 <= 13) and "th" or ({ "st", "nd", "rd" })[nth % 10] or "th"
	r.again:SetChip(nth .. suffix .. " ride with you", "muted")
	r.again:Show()
end
D.PaintAgain = paintAgain

-- the passphrase on the second line (made on first use: idle rows keep their 2.2 widgets)
local function paintPass(r, words)
	if not words then
		if r.pass then r.pass:Hide() end
		return
	end
	if not r.pass then
		r.pass = T.Text(r, "caption", "glow", "LEFT", "medium")
	end
	r.pass:SetText("· " .. words)
	r.pass:Show()
end

-- the "Invite to Wuber" pill on the second line: offered (teal tint) or queued (violet,
-- a tick, "Next click sends"); a tap toggles it. Made the first time a row offers it.
local GETAPP_TIP = {
	ok = "%s asked without the app. Tap: your next big-button click whispers them how to get Wuber"
		.. " (edit it in Messages). At most once a day per rider.",
	queued = "Queued: your next big-button click whispers %s how to get Wuber. Tap again to cancel.",
}

local function getAppPill(r)
	local b = CreateFrame("Button", nil, r)
	b:SetSize(100, 18)
	b:RegisterForClicks("LeftButtonUp")
	-- two fills, each at the alpha it keeps, shown or hidden: soft (Invite) and solid (Next click sends)
	b.fill = T.PillFill(b, { T.RGB("glow", 0.16) }, 18, "BACKGROUND", 1)
	b.solid = T.PillFill(b, "accent", 18, "BACKGROUND", 1)
	b.solid:SetShown(false)
	b.icon = T.Icon(b, "chat", 10, "glow", "OVERLAY")
	b.icon:SetPoint("LEFT", b, "LEFT", 7, 0)
	b.label = T.Text(b, "caption", "glow", "LEFT", "medium")
	b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
	T.Press(b, { fill = function(self) return self.queued and self.solid or self.fill end })
	safeScript(b, "OnClick", function() D.ToggleGetApp(r.c) end)
	T.Tip(b, function() return b.queued and "Next click sends" or "Invite to Wuber" end, function()
		return GETAPP_TIP[b.queued and "queued" or "ok"]:format(short(r.c and r.c.name))
	end)
	return b
end

local function paintGetApp(r, c)
	if not adv() then
		if r.getapp then r.getapp:Hide() end
		return
	end
	local state = c and dr("GetAppState", c, true) or nil -- read only: painting writes no saved data
	local on = state == "ok" or state == "queued"
	if not on then
		if r.getapp then r.getapp:Hide() end
		return
	end
	if not r.getapp then r.getapp = getAppPill(r) end
	local b, queued = r.getapp, state == "queued"
	local text = queued and "Next click sends" or "Invite to Wuber"
	if b.queued ~= queued or b.label:GetText() ~= text then
		b.queued = queued
		local colour = queued and "accent" or "glow"
		b.fill:SetShown(not queued)
		b.solid:SetShown(queued)
		b.label:SetText(text)
		b.label:SetTextColor(T.RGB(queued and "white" or colour))
		b.icon:SetTexture(T.MEDIA .. (queued and "check" or "chat"))
		b.icon:SetVertexColor(T.RGB(queued and "white" or colour))
		local width = T.TextWidth(b.label, text)
		if width <= 0 then width = #text * 6 end
		b:SetWidth(math.floor(width + 27))
		T.RefreshTip(b)
	end
	b:Show()
end

-- the ring and initial in a state's colour
local function paintDisc(r, name, colour)
	-- the first whole UTF-8 character (a lead byte and its continuation bytes); only ASCII is upper-cased
	local ch = name:match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
	r.initial:SetText(#ch == 1 and ch:upper() or ch)
	r.initial:SetTextColor(T.RGB(colour == "white" and "muted" or colour))
	local cr, cg, cb = T.RGB(colour == "white" and "off" or colour)
	r.disc:SetVertexColor(T.RGB("panel"))
	r.ring:SetVertexColor(cr, cg, cb, 0.9)
end

-- the Pioneer badge on the initial's top-left (made only for a listed rider)
local function paintPioneer(r, name)
	local b = T.ShowPioneer(r, "pioneer", T.PioneerLook(S(name)), 14)
	if b then
		b:ClearAllPoints()
		b:SetPoint("CENTER", r.disc, "TOPLEFT", 3, -3)
	end
end

-- whether a label's text fits its width (the game's own answer, and the measure)
local function fits(fs)
	local room = N(fs:GetWidth()) or 0
	if room <= 0 then return true end
	if type(fs.IsTruncated) == "function" then
		local okc, cut = pcall(fs.IsTruncated, fs)
		if okc and cut == true then return false end
	end
	return T.TextWidth(fs) <= room + 1
end

function D.PaintRaidRow(r, row, t)
	r.c, r.raidRow = row, true
	paintAgain(r, nil)
	paintGetApp(r, nil)
	local what, right, rc = D.DescribeRaid(row, t)
	local name = short(row.name)
	r.name:SetText(name)
	r.name:SetTextColor(T.RGB("white"))
	r.what:SetText(" · " .. what)
	roomRight(r)
	r.right:SetText(right or "")
	r.right:SetTextColor(T.RGB("muted"))
	paintDisc(r, name, rc)
	paintPioneer(r, row.name)
	r.app:Hide()
	paintStation(r, nil)
	paintPass(r, nil)
	if D.PaintMarks then D.PaintMarks(r, nil) end -- round 9 (UI.Driver.Customers)
	layRow(r)
	-- (2.4) the game's word on the summon gives way to a shorter form where the row is too narrow (never cut)
	local forms = SUMMON_FORMS[what]
	for i = 2, forms and #forms or 0 do
		if fits(r.what) then break end
		r.what:SetText(" · " .. forms[i])
	end
	r:Show()
end

-- A lead's line, longest first: the row shows the first that fits, so a chat line is
-- the whole quote or a shorter form ("asked for Loch Modan"), never cut ('"Any summons to loch modan?" · in...').
-- The whole line is in the row's tooltip.
local SHORT_SRC = { public = "asked in chat", whisper = "whispered you", manual = "added by you", group = "in your group" }
local function leadForms(c, what, src)
	local forms = {}
	local function add(s) if s and s ~= "" then forms[#forms + 1] = s end end
	local msg = not S(c.helperOf) and not c.busy and not c.wantsPrice and S(c.msg)
	if not msg then
		if src then add(what .. " · " .. src) end
		add(what)
		return forms
	end
	local q = "\"" .. W.Clean(msg, 120) .. "\""
	if src then add(q .. " · " .. src) end
	add(q)
	local place = S(c.askedFor) or S(dr("DestIn", msg))
	if place then
		if src then add("asked for " .. place .. " · " .. src) end
		add("asked for " .. place)
	end
	add(SHORT_SRC[c.source or ""] or "asked for a summon")
	return forms
end

function D.PaintRow(r, c, t)
	r.c, r.raidRow = c, nil
	local what, right, rc = D.Describe(c, t)
	local colour = D.STATE[c.state] or "white"
	if S(c.helperOf) then colour = "off" end
	local name = short(c.name)
	r.name:SetText(name)
	r.name:SetTextColor(T.RGB(colour == "off" and "muted" or "white"))
	local src = SOURCE_TEXT[c.source or ""]
	local forms = c.state == "lead" and leadForms(c, what, src) or SUMMON_FORMS[what] or { what } -- (2.4) the summon's forms
	r.what:SetText(" · " .. forms[1])
	roomRight(r)
	r.right:SetText(right or "")
	r.right:SetTextColor(T.RGB(rc == "white" and "muted" or (rc or "muted")))
	paintDisc(r, name, (c.state == "joined") and "accent" or colour)
	paintPioneer(r, c.name)
	setShown(r.app, c.source == "wuber")
	paintStation(r, S(c.station) and #D.Stations() >= 2 and S(c.station) or nil)
	paintAgain(r, c)
	paintGetApp(r, c)
	paintPass(r, D.Passphrase(c))
	if D.PaintMarks then D.PaintMarks(r, c) end -- round 9: note and gift marks
	layRow(r)
	for i = 2, #forms do
		if fits(r.what) then break end
		r.what:SetText(" · " .. forms[i])
	end
	r:Show()
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.textW = textW
