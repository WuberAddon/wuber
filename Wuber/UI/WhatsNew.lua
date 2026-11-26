-- Module: UI.WhatsNew
-- Purpose: a "What's new" card after an update: one card per version, once per account, a couple of seconds
--   after login; never on a fresh install, in combat, on a ride, on a flight, while summoning or over another card
--   that opened by itself. The words are one table keyed by version (Mod.NOTES).
-- API: Mod.NOTES, Mod.Version, Mod.Pending, Mod.Card, Mod.Show, Mod.Expand, Mod.Hide, Mod.Block, Mod.Why, Mod.Longest, Mod.Layout, Mod.PlaceBeside
--   Show(v[, expanded]): the card as a pop-up (the title, [See what's new], [Not now]); Expand(): [See what's new] opens the same card
--   with the lines and one button, [Got it]. [Not now], [Got it] and the cross all count as seen.
--   Version(): this copy's version as "major.minor.patch" ("2.4.3-dev" counts as "2.4.3"), or nil.
--   Pending(): the version whose card is due this session, or nil. Block(): the first rule that holds it back, or nil.
--   Why(): nil, or the line /wuber why prints while the card is held back ("What's new card: ..."); read-only.
-- Internals: decide, blocked, buildCard, setMode, layout, frameRect, placeBeside, place, watch, try, schedule, close
-- Uses: UI.Kit
-- Later: Drive (Busy); UI.MayOpen (UI.Kit) answers for the other self-opening things
-- Events: listens On PLAYER_REGEN_DISABLED, Listen RIDE, login; fires NEWS_MOVED (the card stands somewhere new)
-- Standalone: no
-- Test: tests/v24/f3_j_whatsnew_test.lua
-- From: new in Wuber 2.4 (round FIX3, group J)
--
-- Saved per account: W.db.newsSeen, the newest version whose card the player closed (or that had nothing to show:
-- a fresh install, or a version with no entry). Fresh install: no earlier version saved and nothing used yet
-- (the first-open guide not done, no trips, no driving log): the current version is saved silently and no card shows.
-- A player from before this field existed (guide done, or trips, or a driving log) counts as updated. Only the player's own close (the
-- Close or Got it control) counts as seen: a card the game hid (combat, a ride, a cinematic) comes back later.
-- The waiting rules are the ones the other self-opening cards use: combat and ride (UI.Tips), a toast up and
-- summoning (Net.Update), the login tip card and the first-open guide (UI.Coach), the splash, the Skip the bird card,
-- the mid-flight offer and the milestone card. (Design 2) The card is a T.SheetCard (the one sheet look: flat, corner 14,
-- no outline, a title, an x, the words with line spacing and the one main button "Got it") inside a plain frame that
-- carries the name WuberNewsCard and the place. It rises and fades; nothing holding text is Scale-animated.

local _, W = ...
local Mod = W.Module("UI.WhatsNew", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local call = KitMod.call
local rideActive = KitMod.rideActive
local safeScript = KitMod.safeScript
local T = W.Theme

-- one to three short lines per version; a version with no entry shows no card. The title is the card's heading.
Mod.NOTES = {
	["2.4.3"] = {
		title = "What's new in Wuber 2.4",
		"Auto mode is careful now: Wuber invites by itself when a whisper clearly asks for a ride (public chat buyers only if you switch that on). Anything a whisper leaves unclear waits in your list as a lead.",
		"Wuber can whisper back once to a clear public request for a summon to your place. Settings, Driving, \"Whisper back to public requests\" turns it off.",
		"The flight master's map shows price tags beside places an open driver summons to, and mid-flight Wuber may offer a faster summon.",
	},
}
Mod.NOTES["2.4.2"] = Mod.NOTES["2.4.3"] -- the same card for a 2.4.2 build (no new words; 2.4.3 only fixes and polishes)

local K = { W = 300, PAD = 16, TOP = 56, FOOT = 70, LINK = 30, TOP_Y = -120, GAP = 32, FIRST = 3, RETRY = 10, TRIES = 60, SLOW = 30, MINH = 120 }

local st = { pending = nil, tries = 0, waiting = false, shown = false }
local card

local function db() return W.db end

-- this copy's version as "a.b.c" ("2.4.2-dev" is 2.4.2: a dev build of a version shows that version's card)
function Mod.Version()
	local v = W.Str(W.VERSION)
	if type(v) ~= "string" then return nil end
	v = v:match("^(%d+%.%d+%.%d+)")
	if not v then return nil end
	return (W.ParseVersion(v))
end

local function entry(v) return v and Mod.NOTES[v] or nil end

-- the version whose card is due, or nil (also records a fresh install / a version with no entry as seen)
local function decide()
	local d = db()
	local v = Mod.Version()
	if type(d) ~= "table" or not v then return nil end
	local last = W.Str(d.newsSeen)
	if last and W.CompareVersions(v, last) ~= 1 then return nil end -- seen (or an older copy)
	if not last then
		local used = d.coach == true or (type(d.rides) == "table" and #d.rides > 0)
			or (type(d.drive) == "table" and type(d.drive.log) == "table" and type(d.drive.log.rides) == "table" and #d.drive.log.rides > 0) -- a driver who never rode
		if not used then
			d.newsSeen = v -- a fresh install has no "what's new"
			return nil
		end
	end
	if not entry(v) then
		d.newsSeen = v
		return nil
	end
	return v
end

function Mod.Pending() return st.pending end

-- the first rule that holds the card back, or nil: the common rules (UI.MayOpen: combat, a cinematic, the first
-- seconds after login, another self-opening thing up) and this card's own (a ride, a flight, a toast, summoning)
local function blocked()
	local UI = W.UI
	local _, gate = UI.MayOpen("news")
	if gate == "combat" or gate == "cinematic" then return gate end
	if rideActive() then return "ride" end
	if type(W.OnTaxi) == "function" and W.OnTaxi() == true then return "flight" end
	if type(UI) == "table" and type(UI.ToastShowing) == "function" and UI.ToastShowing() == true then return "toast" end
	local DR = W.Drive
	if type(DR) == "table" and type(DR.Busy) == "function" and DR.Busy() == true then return "summoning" end
	if type(W.incoming) == "table" and #W.incoming > 0 then return "summoning" end
	return gate -- "other" (the tip card, the guide, the splash, Skip the bird, the mid-flight offer, the milestone card), "login" or nil
end
function Mod.Block() return blocked() end

local WHY = {
	combat = "What's new card: not in combat.",
	cinematic = "What's new card: not during a cinematic.",
	login = "What's new card: shows a few seconds after login.",
	ride = "What's new card: not during a ride.",
	flight = "What's new card: not during a flight.",
	toast = "What's new card: waits for another message to close.",
	summoning = "What's new card: not while you are summoning.",
	other = "What's new card: waits for the card or guide on screen to close.",
}

function Mod.Why()
	if card and card:IsShown() then return nil end
	if not st.pending then return nil end
	local why = blocked()
	if why then return WHY[why] end
	if st.noRoom then return "What's new card: no room beside the Wuber window." end
	if st.waiting then return "What's new card: shows a few seconds after login." end
	return nil
end

-- the entry with the most text (the layout sweep shows it): version, entry
function Mod.Longest()
	local best, bestV, n = nil, nil, -1
	for v, e in pairs(Mod.NOTES) do
		local len = 0
		for _, line in ipairs(e) do len = len + #line end
		if len > n then best, bestV, n = e, v, len end
	end
	return bestV, best
end

---------------------------------------------------------------------------
-- The card (the login tip card's look: same colours, rim and buttons)
---------------------------------------------------------------------------

-- sizes the card from its text: the sheet's title block (56), the words (their lines and the line spacing), the foot
-- (the main button, 46 high, 12 clear of the bottom and the words); never cut, never shrunk
local function layout(c)
	c = c or card
	if not c then return nil end
	local texth = c.expanded and (tonumber(c.text.paraH) or c.text:GetHeight() or 0) or 0
	local foot = c.expanded and K.FOOT or (K.FOOT + K.LINK) -- the pop-up has the link "Not now" under its button
	local h = math.max(K.MINH, K.TOP + texth + (c.expanded and 8 or 0) + foot)
	c:SetSize(K.W, h)
	c.sheet:SetSize(K.W, h)
	c.sheet:ClearAllPoints()
	c.sheet:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.text:ClearAllPoints()
	c.text:SetPoint("TOPLEFT", c.sheet.body, "TOPLEFT", K.PAD, 0)
	return K.W, h
end
Mod.Layout = layout

-- a frame's box in UIParent units: left, right, top, bottom (or nil)
local function frameRect(f)
	if type(f) ~= "table" then return nil end
	local u = tonumber(call(UIParent.GetEffectiveScale, UIParent)) or 1
	local s = tonumber(call(f.GetEffectiveScale, f)) or u
	if u <= 0 then u = 1 end
	if s <= 0 then s = u end
	local l, r = tonumber((call(f.GetLeft, f))), tonumber((call(f.GetRight, f)))
	local t, b = tonumber((call(f.GetTop, f))), tonumber((call(f.GetBottom, f)))
	if not (l and r and t and b) then return nil end
	local k = s / u
	return l * k, r * k, t * k, b * k
end

-- Wuber's own top-level windows that can be up with the card; it keeps K.GAP clear of every one that shows
local WINDOWS = { "WuberFrame", "WuberDriveButton", "WuberDriveMini", "WuberInFlight" }

local function shownRects()
	local rects = {}
	for _, name in ipairs(WINDOWS) do
		local f = rawget(_G, name)
		if type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() then
			local l, r, t, b = frameRect(f)
			if l then rects[#rects + 1] = { l, r, t, b } end
		end
	end
	return rects
end

-- top centre of the screen; else beside a window of Wuber's, left then right; never over one (parts of their art stick out
-- past their frames, so K.GAP stays clear). false when there is no such place (the card waits).
-- (the shared one: the New title card of UI.Moments asks for it through Mod.PlaceBeside)
local function placeBeside(c, w, h, topY)
	topY = topY or K.TOP_Y
	local sw, sh = tonumber((call(UIParent.GetWidth, UIParent))) or 0, tonumber((call(UIParent.GetHeight, UIParent))) or 0
	if sw <= 0 or sh <= 0 or not w then
		c:ClearAllPoints()
		c:SetPoint("TOP", UIParent, "TOP", 0, topY)
		return true
	end
	local rects = shownRects()
	local top = sh + topY
	local tries = { { (sw - w) / 2, top } }
	for _, r in ipairs(rects) do
		tries[#tries + 1] = { r[1] - K.GAP - w, math.min(r[3], sh - 20) }
		tries[#tries + 1] = { r[2] + K.GAP, math.min(r[3], sh - 20) }
	end
	for _, t in ipairs(tries) do
		local l, tp = t[1], t[2]
		local inside = l >= 0 and l + w <= sw and tp - h >= 0 and tp <= sh
		local clear = true
		for _, r in ipairs(rects) do
			if not (l >= r[2] + K.GAP or l + w <= r[1] - K.GAP or tp - h >= r[3] + K.GAP or tp <= r[4] - K.GAP) then clear = false break end
		end
		if inside and clear then
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, tp)
			return true
		end
	end
	return false
end
-- PlaceBeside(card, w, h, topY): the card (w x h) at the top centre, else beside one of Wuber's windows, clear of all
-- that show; true when it stands, false when there is no such place (the card is left where it was)
Mod.PlaceBeside = placeBeside

-- the card is placed, and tells the flight map's price tags when it ended up somewhere new, so they step aside from where it
-- stands now (not from where it was)
local function place(c)
	local w, h = layout(c)
	local l0, _, t0 = frameRect(c)
	local ok = placeBeside(c, w, h)
	local l1, _, t1 = frameRect(c)
	if ok and l1 and (not l0 or math.abs(l1 - l0) > 0.5 or math.abs(t1 - t0) > 0.5) then W.Fire("NEWS_MOVED") end
	return ok
end

-- gone at once (the game hid it, or Hide): the sheet inside is closed without its drop
local function hideNow()
	if not card then return end
	card.sheet:Close(true)
	card:Hide()
end

-- the window's drag handles (the header, the phone, its status bar and its pill): when one is let go the shown card follows
-- at once, not at the next second of its watch
local followHooked = {}
local function hookFollow()
	local ui = KitMod.ui
	if type(ui) ~= "table" then return end
	local ph = type(ui.phone) == "table" and ui.phone or {}
	local list = { ui.top, ui.phone, ph.status, ph.island }
	for i = 1, 4 do -- fixed count: a missing frame must not skip the later ones
		local f = list[i]
		if type(f) == "table" and not followHooked[f] and type(f.HookScript) == "function" then
			followHooked[f] = true
			call(f.HookScript, f, "OnDragStop", function()
				if card and card:IsShown() then W.Safe("whatsnew", place, card) end
			end)
		end
	end
end

local function close()
	local d = db()
	if type(d) == "table" and st.pending then d.newsSeen = st.pending end
	st.pending = nil
	if card then
		if card:IsShown() then card.sheet:Close() else hideNow() end
	end
end

local function buildCard()
	if card then return card end
	local c = CreateFrame("Frame", "WuberNewsCard", UIParent)
	c:SetFrameStrata("FULLSCREEN_DIALOG")
	c:SetSize(K.W, K.MINH)
	c:SetClampedToScreen(true)
	local sc = T.SheetCard(c, K.W, K.MINH, "")
	sc:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.sheet = sc
	c.title, c.close = sc.title, sc.close
	c.text = T.Para(sc.body, "sub", "white", K.W - 2 * K.PAD)
	-- (the 20 rewrites, W-20) the pop-up is a title and two buttons: [See what's new] opens the list of lines, [Not now] closes it
	-- as seen; in the list the one button is [Got it]. c.got is the main button in both.
	c.got = sc:MainButton("See what's new", function() Mod.Expand() end, "Show what changed in this version.")
	c.notNow = sc:Link("Not now", close, "Hide this card. You won't see it again.")
	c.linkSlot = sc.card.linkBtn
	T.Press(c.close)
	safeScript(c.close, "OnClick", close)
	T.Tip(c.close, "Close", "Hide this card. You won't see it again.")
	-- the sheet's own fade-out ends hidden: the frame that carries the name goes with it
	sc:HookScript("OnHide", function() c:Hide() end)
	c:Hide()
	card = c
	return c
end
function Mod.Card() return card or buildCard() end

-- the card as a pop-up (title, [See what's new], [Not now]) or as the list (the lines, [Got it])
local function setMode(c, expanded, e)
	c.expanded = expanded and true or false
	if c.expanded then
		c.text:SetPara(table.concat(e, "\n\n"))
		c.text:Show()
		c.got:SetLabel("Got it")
		safeScript(c.got, "OnClick", close)
		T.Tip(c.got, "Got it", "Hide this card. You won't see it again.")
		if c.linkSlot then c.linkSlot:Hide() end
		c.sheet.card.linkBtn = nil
	else
		c.text:SetPara("")
		c.text:Hide()
		c.got:SetLabel("See what's new")
		safeScript(c.got, "OnClick", function() Mod.Expand() end)
		T.Tip(c.got, "See what's new", "Show what changed in this version.")
		c.sheet.card.linkBtn = c.linkSlot
		if c.linkSlot then c.linkSlot:Show() end
	end
	if c.sheet.card.layFoot then c.sheet.card.layFoot() end
end

-- [See what's new]: the same card, now with the lines and one button, [Got it]
function Mod.Expand()
	if not (card and card:IsShown() and st.pending) then return false end
	local e = entry(st.pending)
	if not e then return false end
	setMode(card, true, e)
	place(card)
	return true
end

function Mod.Hide()
	hideNow()
end

-- shows the card for this version (no rules checked: the sweep and tests use it); true when it shows
function Mod.Show(v, expanded)
	v = v or st.pending
	local e = entry(v)
	if not e then return false end
	st.pending = v
	local c = buildCard()
	c.sheet:SetTitle(e.title or "What's new")
	setMode(c, expanded == true, e)
	if not place(c) then
		hideNow()
		st.noRoom = true
		return false
	end
	st.noRoom = false
	hookFollow()
	if not c:IsShown() then
		c.sheet:Open() -- (first: an Open ends a drop still running, which hides the frame that carries the name)
		c:Show()
	end
	return true
end

---------------------------------------------------------------------------
-- When
---------------------------------------------------------------------------

local schedule
local watch
-- while it shows: the phone opened or moved under it: beside the phone again, or hidden (not seen) until there is room
watch = function(token)
	if token ~= st.watch or not (card and card:IsShown()) then return end
	if not place(card) then
		hideNow()
		st.noRoom, st.tries = true, 0
		if st.pending then schedule(K.RETRY) end
		return
	end
	W.After(1, function() watch(token) end)
end

local function try()
	st.waiting = false
	if not st.pending then return end
	if card and card:IsShown() then return end
	if blocked() then
		-- held back (a long ride or crew job): keep looking, more slowly after K.TRIES, so the card still shows when the hold ends
		st.tries = st.tries + 1
		schedule(st.tries < K.TRIES and K.RETRY or K.SLOW)
		return
	end
	st.shown = Mod.Show(st.pending)
	if st.shown then
		st.watch = (st.watch or 0) + 1
		local token = st.watch
		W.After(1, function() watch(token) end)
	elseif st.noRoom then
		st.tries = st.tries + 1
		if st.tries < K.TRIES then schedule(K.RETRY) end
	end
end

schedule = function(secs)
	if st.waiting then return end
	st.waiting = true
	W.After(secs, try)
end

W.OnLogin(function()
	st.pending = decide()
	st.tries = 0
	if st.pending then schedule(K.FIRST) end
end)

-- the game closes it (combat, a ride): hidden, not seen; it comes back when the rules allow
local function gameHid()
	if card and card:IsShown() then
		hideNow()
		st.tries = 0
		if st.pending then schedule(K.RETRY) end
	end
end
W.On("PLAYER_REGEN_DISABLED", gameHid)
W.Listen("RIDE", function() if card and card:IsShown() and rideActive() then gameHid() end end)
