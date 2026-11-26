-- Module: UI.Rider.Cards
-- Purpose: Driver cards: favourite/hide, heart button, the card menu, the creator look, buildCard/fillCard,
--   search box and filtering. (Design 2, item 10) A driver "card" is a ROW of one card (T.RowGroup of Theme.Forms):
--   the driver's picture at the left (c.avatar: their own badge c.mark, else their initial on a violet-soft disc), the
--   name (c.title) with the Founder badge after it (c.royal.chip, thin gold outline), the second line (c.sub:
--   "To Undercity · No helpers needed", then the state words "Busy · 3 waiting", "Group full", "Usually about 45 sec";
--   it wraps, the row grows), and at the right the PvP shield when hot, the price in gold (c.price), the heart
--   (c.heart) and a chevron (c.chevron); the price and the heart stand on the name's line when the name leaves room. A name whose longest word is too wide for the price's column: the price and the heart go under the words (c.priceBox). No crown, badge or Pioneer emblem after the name: their words are in the
--   row's tooltip. buildCard(group) makes the row in that group (a plain frame: in a one-row card of its own);
--   fillCard(c, d, glow, hold) lays the group out again unless hold is true (the caller then calls group:Layout()).
-- API: UI.IsFav, UI.ToggleFav, UI.HideDriver, UI.HeartButton, UI.DangerOf, UI.DangerLine
-- Internals: applySearch, buildCard, buildSearch, chipFor, fillCard, heartButton, isFav, matches,
--   updatedText, shieldChip, usualSummon (FEAT-01 b: "about 45 sec" for an open driver with nobody waiting who sends
--   their average summon; the list card's right-hand line says "Usually about 45 sec", Confirm's grey line ends with it)
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens Listen SETTINGS; fires SETTINGS
-- Standalone: no
-- Test: tests/ui/rider/cards_test.lua
-- From: UI.lua 1407-1858 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Rider.Cards", { "UI.Kit" })

local KitMod = W.Mod("UI.Kit")
local INNER = KitMod.INNER
local N = KitMod.N
local PAD = KitMod.PAD
local S = KitMod.S
local call = KitMod.call
local money = KitMod.money
local now = KitMod.now
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local ui = KitMod.ui
local T = W.Theme
local A = T.Animate
-- (design 2) the right end of a driver row: the heart's box, the chevron, the gap between them, the shield's room
local ROWK = { heart = 21, chev = 12, gap = 4, price = 2, lead = 4, shield = 24, paused = 0.55, initial = "body" }
local Try = T.Try
local UI = W.UI

-- Favourites (W.ToggleFav / W.IsFav from Net, else W.db.favs directly).
local function isFav(key)
	if not key then return false end
	if type(W.IsFav) == "function" then return call(W.IsFav, key) == true end
	return W.db ~= nil and type(W.db.favs) == "table" and W.db.favs[key] == true
end
UI.IsFav = isFav

local function toggleFav(key, name)
	if not key then return end
	local on
	if type(W.ToggleFav) == "function" then
		on = call(W.ToggleFav, key)
		if type(on) ~= "boolean" then on = isFav(key) end
	elseif W.db then
		if type(W.db.favs) ~= "table" then W.db.favs = {} end
		on = not W.db.favs[key]
		W.db.favs[key] = on or nil
		W.Fire("SETTINGS", "favs")
	end
	local who = name and W.Short(name) or "This driver"
	UI.Toast(on and (who .. " is a favourite. We'll tell you when they're online.") or (who .. " is no longer a favourite"), on and "fav" or "info")
	UI.Refresh(true)
	return on
end
UI.ToggleFav = toggleFav

local function hideDriver(key, name)
	if not key then return end
	if type(W.HideDriver) == "function" then
		call(W.HideDriver, key)
	elseif W.db then
		if type(W.db.hidden) ~= "table" then W.db.hidden = {} end
		W.db.hidden[key] = true
		W.Fire("SETTINGS", "hidden")
	end
	UI.Toast((name and W.Short(name) or "That driver") .. " is hidden. Show them again in Settings.", "info")
	UI.Refresh(true)
end
UI.HideDriver = hideDriver

-- A heart button: filled magenta when the driver is a favourite.
local function heartButton(parent, size)
	local h = CreateFrame("Button", nil, parent)
	h:SetSize(size + 8, size + 8)
	h.outline = T.Icon(h, "heart_outline", size, "muted", "ARTWORK")
	h.outline:SetPoint("CENTER", h, "CENTER")
	h.fill = T.Icon(h, "heart", size, "magenta", "ARTWORK")
	h.fill:SetPoint("CENTER", h, "CENTER")
	h.fill:Hide()
	h:RegisterForClicks("LeftButtonUp")
	function h.SetFav(self, on)
		self.on = on and true or false
		setShown(self.fill, self.on)
		setShown(self.outline, not self.on)
	end
	safeScript(h, "OnEnter", function(self) self.outline:SetVertexColor(T.RGB("white")) end)
	safeScript(h, "OnLeave", function(self) self.outline:SetVertexColor(T.RGB("muted")) end)
	T.Press(h)
	safeScript(h, "OnClick", function(self)
		if not self.key then return end
		self:SetFav(toggleFav(self.key, self.name))
		A.Pop(self, 0.3)
	end)
	T.Tip(h, "Favourite", function(self)
		if self.on then return "Remove from your favourites." end
		return "Add to your favourites: we'll tell you when they come online."
	end)
	return h
end
UI.HeartButton = heartButton

-- The right-click menu on a driver card: Favourite, Hide this driver.
local cardMenu
local function showCardMenu(card)
	if not W.Advanced() then return end
	if not cardMenu then
		cardMenu = CreateFrame("Frame", nil, UIParent)
		cardMenu:SetSize(190, 92)
		cardMenu:SetFrameStrata("FULLSCREEN_DIALOG")
		cardMenu:EnableMouse(true)
		local host = T.Card(cardMenu, 190, 92, { colour = "panel", radius = 12, border = "line" })
		host:SetAllPoints(cardMenu)
		cardMenu.fav = T.Pill(host, "Favourite", "ghost", 178, 38)
		cardMenu.fav:SetPoint("TOP", cardMenu, "TOP", 0, -6)
		cardMenu.hide = T.Pill(host, "Hide this driver", "ghost", 178, 38)
		cardMenu.hide:SetPoint("TOP", cardMenu.fav, "BOTTOM", 0, -4)
		cardMenu.hide.label:SetTextColor(T.RGB("red"))
		safeScript(cardMenu.fav, "OnClick", function()
			cardMenu:Hide()
			toggleFav(cardMenu.key, cardMenu.name)
		end)
		safeScript(cardMenu.hide, "OnClick", function()
			cardMenu:Hide()
			hideDriver(cardMenu.key, cardMenu.name)
		end)
		T.Tip(cardMenu.fav, "Favourite", "Favourites get a heart, and a note when they come online.")
		T.Tip(cardMenu.hide, "Hide this driver", "You won't see this driver anywhere in Wuber. Settings can show them again.")
		cardMenu:Hide()
		W.On("GLOBAL_MOUSE_DOWN", function()
			if cardMenu:IsShown() and not cardMenu:IsMouseOver() then cardMenu:Hide() end
		end)
	end
	-- (r47, AUD-164) closing Wuber (Escape, /wuber) takes the menu with it, and so does leaving Home while the
	-- window stays open: every frame from the card up to the window is hooked once
	local p = card
	if ui.win and not (cardMenu.hooked and cardMenu.hooked[ui.win]) then
		cardMenu.hooked = cardMenu.hooked or {}
		cardMenu.hooked[ui.win] = true
		pcall(ui.win.HookScript, ui.win, "OnHide", function() cardMenu:Hide() end)
	end
	while p and p ~= UIParent do
		cardMenu.hooked = cardMenu.hooked or {}
		if not cardMenu.hooked[p] then
			cardMenu.hooked[p] = true
			pcall(p.HookScript, p, "OnHide", function() cardMenu:Hide() end)
		end
		p = p.GetParent and p:GetParent() or nil
	end
	cardMenu.key, cardMenu.name = card.key, card.view and card.view.name
	cardMenu.fav:SetLabel(isFav(card.key) and "Remove favourite" or "Favourite")
	cardMenu:ClearAllPoints()
	local we, ue = N(ui.win and ui.win:GetEffectiveScale()) or 1, N(UIParent:GetEffectiveScale()) or 1
	cardMenu:SetScale(ue > 0 and we / ue or 1)
	cardMenu:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, -2)
	A.Pop(cardMenu, 0.2)
end

-- A chip or crown on a card takes the mouse for its own tooltip. The card under it still shows its
-- hover and its press, and still takes the left or right click (no other button: the card's OnClick
-- reads anything but a right click as a booking).
local function overCard(f, c)
	f:EnableMouse(true) -- a frame takes no hover (so no tooltip) until it takes the mouse
	local function run(name, ...)
		local fn = c:GetScript(name)
		if fn then fn(c, ...) end
	end
	pcall(f.HookScript, f, "OnEnter", function() run("OnEnter") end)
	pcall(f.HookScript, f, "OnLeave", function()
		run("OnLeave")
		T.PressUp(c)
	end)
	-- (the card's press look and click: T.PressDown does nothing more when the card's script did them already)
	safeScript(f, "OnMouseDown", function()
		run("OnMouseDown")
		T.PressDown(c)
	end)
	safeScript(f, "OnMouseUp", function(_, button)
		T.PressUp(c)
		-- only a release that is still over the card is a click (dragging off cancels it)
		if (button == "LeftButton" or button == "RightButton") and c:IsMouseOver() then c:Click(button) end
	end)
end

-- (design 2) the Founder badge after a founder's name: gold words in a thin gold outline (T.Badge), nothing that
-- glows, sweeps or breathes. Made once per row, shown only while the row shows a founder; cardMarks places it.
local function creatorLook(c, on)
	if on and not c.royal then
		local chip = T.Badge(c, "Founder", "gold")
		overCard(chip, c)
		T.Tip(chip, "Wuber founder", "The people who made Wuber. Rides with them are the real deal.")
		c.royal = { chip = chip }
	end
	if c.royal then setShown(c.royal.chip, on and true or false) end
end

-- (2.4) the driver's verified summon rank chip: plain grey T.Badge after the name (after Founder when there is one)
local function rankLook(c, rank)
	local n = N(rank)
	n = (n and n >= 1) and math.floor(n) or nil
	local title
	if n and type(W.RankOf) == "function" then
		local _, t = W.RankOf(n)
		title = t
	end
	if not (n and title) then
		if c.rankChip then c.rankChip:Hide() end
		c.rankTitle, c.rankTipBody = nil, nil
		return
	end
	local text = title .. " · " .. n
	if not c.rankChip then
		local chip = T.Badge(c, text, "muted")
		overCard(chip, c)
		T.Tip(chip, function() return c.rankTitle end, function() return c.rankTipBody end)
		c.rankChip = chip
	else
		c.rankChip:SetBadge(text, "muted")
	end
	c.rankTitle = title
	c.rankTipBody = (n == 1 and "1 verified summon" or (n .. " verified summons"))
		.. ". A summon is verified when a rider who asked through Wuber arrives by it."
	c.rankChip:Show()
end

-- A driver in the list (design 2, item 10): one ROW of the drivers' card. parent: the T.RowGroup the row joins
-- (Home's s.rows); a plain frame gets a one-row card of its own at its top left.
local function buildCard(parent)
	local group = parent
	if type(parent) ~= "table" or type(parent.Row) ~= "function" then
		group = T.RowGroup(parent, INNER)
		group:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		group:SetFrameLevel(parent:GetFrameLevel() + 3)
	end
	local av = CreateFrame("Frame", nil, group)
	av:SetSize(T.ROW.disc, T.ROW.disc)
	av.disc = T.Circle(av, T.ROW.disc, { T.C.accent[1], T.C.accent[2], T.C.accent[3], 0.18 }, "ARTWORK")
	av.disc:SetPoint("CENTER", av, "CENTER")
	av.initial = T.Text(av, ROWK.initial, "accent", "CENTER", "bold")
	av.initial:SetPoint("CENTER", av, "CENTER", 0, 0)
	local c = group:Row({ avatar = av, right = "price", value = "", onClick = function() end, tip = false })
	-- the right end: [shield] price, heart, chevron (the row's own holder, widened by fillCard)
	local holder = c.rightFrame
	c.price = c.value
	c.chevron = T.Icon(holder, "chevron", ROWK.chev, "offText", "OVERLAY")
	c.chevron:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
	c.heart = heartButton(holder, 13)
	c.heart:SetPoint("RIGHT", holder, "RIGHT", -(ROWK.chev + ROWK.gap), 0)
	c.price:ClearAllPoints()
	c.price:SetPoint("RIGHT", c.heart, "LEFT", -ROWK.price, 0)
	c.bg = c.fill
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	safeScript(c, "OnClick", function(self, button)
		if not self.key then return end
		if button == "RightButton" then
			if W.Advanced() then showCardMenu(self) end
			return
		end
		if self.disabled then
			UI.Toast((self.short or "This driver") .. " has paused for now", "info")
			return
		end
		UI.Show("confirm", self.key)
	end)
	T.Tip(c, function(self)
		local d = self.view
		if not d then return nil end
		return d.service
	end, function(self)
		local d = self.view
		if not d then return nil end
		local lines = d.name .. " summons you to " .. d.dest .. " for " .. money(d.price) .. "."
		if d.summoner then lines = d.name .. " runs it; " .. d.summoner .. " (a Warlock) summons you to " .. d.dest .. " for " .. money(d.price) .. ". You pay " .. d.summoner .. "." end
		-- (design 2) the crown after the name is gone: its words are here
		if d.creator then lines = lines .. " A Wuber founder. Wuber was made by this driver's team." end
		local look = T.PioneerLook(d.key) -- the shipped list only; a founder: none
		if look then lines = lines .. " " .. T.PIONEER[look].tip .. "." end
		if self.updated then lines = lines .. " " .. self.updated .. "." end
		if self.disabled then return lines .. " Paused for now." end
		return lines .. (W.Advanced() and " Click to book. Right-click to favourite or hide." or " Click to book.")
	end)
	return c
end

-- the first letter of a name (whole, also when it is more than one byte), in capitals when plain
local function initialOf(name)
	local ch = tostring(name or ""):match("^[%z\1-\127\194-\244][\128-\191]*") or ""
	if ch == "" then return "?" end
	return #ch == 1 and ch:upper() or ch
end

-- (design 2) The driver's picture and the Founder badge. The picture is the driver's own badge when they have one
-- (W.BADGES id, the still icon, made once per row and id), else their initial on the violet-soft disc. No crown and
-- no Pioneer emblem after the name any more (the row's tooltip says both). The Founder badge sits after the name
-- when it fits on the name's line, else under the words (the row grows; nothing is cut).
local function cardMarks(c, d)
	local av = c.avatar
	local id = d.badge
	if id and id ~= c.badgeId then
		if c.mark then c.mark:Hide() end
		c.marks = c.marks or {}
		c.mark = c.marks[id] or T.DriverBadge(av, id, T.ROW.disc, true)
		c.marks[id] = c.mark
		c.badgeId = id
	elseif not id and c.mark then
		c.mark:Hide()
		c.badgeId = nil
	end
	-- (r54 B) a founder with no badge picked: the crown stands in the picture, not the initial
	local crown = d.creator and id == nil
	if crown and not c.crownMark then
		c.crownMark = T.Icon(av, "crown", T.ROW.disc - 8, "gold", "OVERLAY")
		c.crownMark:SetPoint("CENTER", av, "CENTER")
	end
	if c.crownMark then setShown(c.crownMark, crown and true or false) end
	local has = id ~= nil and c.mark ~= nil
	if has then
		c.mark:ClearAllPoints()
		c.mark:SetPoint("CENTER", av, "CENTER")
		c.mark:Show()
	end
	setShown(av.disc, not has)
	setShown(av.initial, not has and not crown)
	local initial = initialOf(d.name or d.service)
	if av.initialShown ~= initial then
		av.initialShown = initial
		av.initial:SetText(initial)
	end
	if c.crown then c.crown:Hide() end
	if c.pioneer then c.pioneer:Hide() end
	-- The right end. The price and the heart sit on the name's line when the name (and the Founder badge) leave them
	-- room there: the second line then runs under them, up to the chevron. A name too long for that keeps its own
	-- column: the price, the heart and the chevron stand together at the row's middle, as wide as they are.
	local chip = (d.creator and c.royal and c.royal.chip) or nil
	local rchip = (c.rankChip and c.rankChip:IsShown()) and c.rankChip or nil
	local block = c.blockW or 0 -- [shield] price, heart
	local tw = math.ceil((N(T.MeasureText(c.titleText, T.ROW.title, "bold")) or 0) * 1.04)
	local cw = chip and (N(chip:GetWidth()) or 60) + ROWK.gap or 0
	local rw = rchip and (N(rchip:GetWidth()) or 60) + ROWK.gap or 0
	local function roomFor(rightW) return math.max(40, c.group.width - c.textX - (rightW + T.ROW.gap) - T.ROW.pad) end
	local roomA = roomFor(ROWK.chev)
	local onLine = tw + ROWK.lead + block <= roomA
	-- (#236) the name's longest word is one piece (the row wraps at spaces only): when the price's column would leave it
	-- less room than it needs, the price and the heart go under the words (the row grows) and the name gets the row
	local longW = 0
	for word in c.titleText:gmatch("%S+") do longW = math.max(longW, N(T.MeasureText(word, T.ROW.title, "bold")) or 0) end
	local stack = not onLine and math.ceil(longW * 1.07) > roomFor(block + ROWK.gap + ROWK.chev)
	c.priceOnLine = onLine
	c.priceStacked = stack
	c.rightW = (onLine or stack) and ROWK.chev or (block + ROWK.gap + ROWK.chev)
	c.rightFrame:SetWidth(c.rightW)
	local pbox = nil
	if stack then
		pbox = c.priceBox
		if not pbox then
			pbox = CreateFrame("Frame", nil, c)
			c.priceBox = pbox
		end
		pbox:SetSize(block, ROWK.heart)
		pbox:Show()
		T.PlaceOnce(c.heart, "RIGHT", pbox, "RIGHT", 0, 0)
	elseif onLine then
		T.PlaceOnce(c.heart, "RIGHT", c.title, "LEFT", roomA, 0)
	else
		T.PlaceOnce(c.heart, "RIGHT", c.rightFrame, "RIGHT", -(ROWK.chev + ROWK.gap), 0)
	end
	if not stack and c.priceBox then c.priceBox:Hide() end
	c.below = nil
	if c.belowBox then c.belowBox:Hide() end
	local avail = roomFor(c.rightW) - (onLine and (ROWK.lead + block) or 0)
	local used = tw
	local chipBelow, rchipBelow = false, false
	if chip then
		chip:ClearAllPoints()
		if used + cw <= avail then
			chip:SetPoint("LEFT", c.title, "LEFT", used + ROWK.gap, 0)
			used = used + cw
		else
			chipBelow = true
		end
	end
	if rchip then
		rchip:ClearAllPoints()
		if not chipBelow and used + rw <= avail then
			if chip then
				rchip:SetPoint("LEFT", chip, "RIGHT", ROWK.gap, 0)
			else
				rchip:SetPoint("LEFT", c.title, "LEFT", used + ROWK.gap, 0)
			end
		else
			rchipBelow = true
		end
	end
	local items = {}
	if chipBelow then items[#items + 1] = chip end
	if rchipBelow then items[#items + 1] = rchip end
	if pbox then items[#items + 1] = pbox end
	if #items >= 2 then
		local box = c.belowBox
		if not box then
			box = CreateFrame("Frame", nil, c)
			c.belowBox = box
		end
		local maxW = roomFor(c.rightW)
		local function wOf(it) return N(it:GetWidth()) or 60 end
		local function hOf(it) return N(it:GetHeight()) or 18 end
		local total = 0
		for i, it in ipairs(items) do total = total + wOf(it) + (i > 1 and ROWK.gap or 0) end
		local side = total <= maxW
		local prev = items[1]
		prev:ClearAllPoints()
		prev:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
		local bw, bh = wOf(prev), hOf(prev)
		for i = 2, #items do
			local it = items[i]
			it:ClearAllPoints()
			if side then
				it:SetPoint("LEFT", prev, "RIGHT", ROWK.gap, 0)
				bw, bh = bw + ROWK.gap + wOf(it), math.max(bh, hOf(it))
			else
				it:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
				bw, bh = math.max(bw, wOf(it)), bh + 4 + hOf(it)
			end
			prev = it
		end
		box:SetSize(bw, bh)
		box:Show()
		c.below = box
	elseif #items == 1 then
		c.below = items[1]
	end
end

-- PvP near the summon spot: the driver's beacon (D field 18, kept by Net on the
-- driver as danger = level 0..2 and dangerAt = GetTime() of the fight; also read: dangerSecs, or
-- the raw "level:seconds") or, during a ride, the live tracker's G. Returns level (0 when unknown), seconds since (or nil).
function UI.DangerOf(d)
	local raw = type(d) == "table" and (d.raw or d) or nil
	if type(raw) ~= "table" then return 0, nil end
	local level, secs = raw.danger, N(raw.dangerSecs)
	-- the time of the fight wins over the age as sent, so the age keeps growing after the beacon came
	if N(raw.dangerAt) then secs = math.max(0, now() - N(raw.dangerAt)) end
	if type(level) == "string" then
		local l, s2 = level:match("^(%d)[:]?(%d*)")
		level, secs = tonumber(l), secs or tonumber(s2)
	end
	level = N(level) or 0
	level = math.max(0, math.min(2, math.floor(level)))
	return level, secs
end

-- The warning's words: head, body ("Hot drop", "Anita's crew fought enemy players 2 min ago. You
-- may land in a fight."); nil at level 0. Never a block, only a warning.
function UI.DangerLine(level, secs, who)
	level = N(level) or 0
	if level < 1 then return nil end
	if level >= 2 then
		local ago = secs and (secs < 60 and "just now" or (W.UI.Duration(secs) .. " ago")) or "recently"
		return "Hot drop", (who and (who .. "'s crew") or "The crew") .. " fought enemy players " .. ago .. ". You may land in a fight."
	end
	return "Hot drop", "Enemy players were seen near the summon spot."
end

-- the small shield on a card whose summon spot is hot (made the first time it is needed)
local function shieldChip(c, level)
	if level < 1 then
		if c.shield then c.shield:Hide() end
		return
	end
	if not c.shield then
		local sh = CreateFrame("Frame", nil, c)
		sh:SetSize(18, 18)
		sh.icon = T.Icon(sh, "shield", 16, "red", "ARTWORK")
		sh.icon:SetPoint("CENTER", sh, "CENTER")
		overCard(sh, c) -- takes the mouse for its tooltip, passes hover and clicks to the card
		T.Tip(sh, "PvP near the summon", function()
			local _, body = UI.DangerLine(c.dangerLevel, c.dangerSecs, c.short)
			return body
		end)
		c.shield = sh
	end
	c.shield.icon:SetVertexColor(T.RGB("red"))
	c.shield:ClearAllPoints()
	c.shield:SetPoint("RIGHT", c.price, "LEFT", -6, 0)
	c.shield:Show()
end

local function helpersText(d)
	if d.team >= 3 then return "No helpers needed" end
	local n = 3 - d.team
	return "Bring " .. n .. (n == 1 and " helper" or " helpers")
end

local function chipFor(d)
	if d.state == "open" then return "Open", "glow" end
	if d.state == "busy" then
		if d.queue and d.queue > 0 then return "Busy · " .. d.queue .. " waiting", "muted" end
		return "Busy · about 2 min", "muted"
	end
	return "Paused", "off"
end

-- (FEAT-01 b) A driver's usual summon, said: "about 45 sec", "about 2 min" (the Fly or summon card's words and
-- rounding: seconds under a minute, else UI.Duration), only for a driver who is open with nobody waiting (queue 0)
-- whose advert carries their average (d.avgSummon, D field 21: 3+ counted rides). nil in every other case.
local function usualSummon(d)
	if type(d) ~= "table" or d.state ~= "open" or N(d.queue) ~= 0 then return nil end
	local avg = N(d.avgSummon)
	if not avg or avg < 10 or avg > 900 then return nil end
	local wait = UI.SummonWait(d)
	return "about " .. (wait < 60 and (math.floor(wait + 0.5) .. " sec") or UI.Duration(wait))
end

local function updatedText(d)
	if not d.heard then return "" end
	return "Updated " .. W.Ago(now() - d.heard)
end

-- (design 2) Fills a driver row. The state words that sat beside the heart ("Busy · 3 waiting", "Group full",
-- "Usually about 45 sec", "Paused") join the second line as plain words (c.stateText keeps them alone); the row
-- wraps and grows, nothing is cut or shrunk. hold: the caller lays the group out itself (Home: once for all rows).
local function fillCard(c, d, glow, hold)
	c.key, c.short = d.key, d.short
	c.titleText = tostring(d.service or "")
	local state = nil
	if d.state ~= "open" then state = (chipFor(d)) end
	if d.seats == 0 then state = (state and (state .. " · ") or "") .. "Group full" end
	-- (FEAT-01 b) an open driver with nobody waiting who sends their average: "Usually about 45 sec"
	local usual = not state and usualSummon(d)
	if usual then state = "Usually " .. usual end
	c.stateText = state
	-- "To Undercity · No helpers"; who casts, when it isn't the driver
	c.subText = "To " .. d.dest .. " · " .. (d.summoner and ("Summoned by " .. d.summoner) or helpersText(d))
		.. (state and (" · " .. state) or "")
	-- (Group Finder) a driver the last search found listed there: the second line says where (it wraps, nothing is cut)
	local GF = W.GroupFinder
	local gz = GF and GF.ListedZone(d.key)
	if gz then
		c.subText = c.subText .. " · " .. string.format(GF.DRAFT_WORDS.card, gz)
	end
	local p = money(d.price)
	-- the row's own SetValue would stop at once (valueText already says p) and leave the price blank: write the words raw
	c.valueText = p
	local pw = math.ceil(N(T.MeasureText(p, T.ROW.title, "bold")) or 40) + 2
	if c.priceShown ~= p or c.priceW ~= pw then -- the same price is not written again
		c.priceShown, c.priceW = p, pw
		c.valueRaw(c.price, p)
		c.price:SetWidth(pw)
	end
	c.disabled = d.state == "paused"
	c.heard = d.heard
	c.updated = d.heard and updatedText(d) or nil
	c.heart.key, c.heart.name = d.key, d.name
	c.heart:SetFav(isFav(d.key))
	c.glowLevel = glow or 0 -- (kept for callers: nothing glows)
	c.dangerLevel, c.dangerSecs = UI.DangerOf(d)
	shieldChip(c, c.dangerLevel)
	c.blockW = pw + ROWK.price + ROWK.heart + (c.dangerLevel >= 1 and ROWK.shield or 0)
	creatorLook(c, d.creator)
	rankLook(c, d.rank)
	cardMarks(c, d)
	c:SetAlpha(c.disabled and ROWK.paused or 1)
	c.view = d
	if not hold then c.group:Layout() end
end

local function matches(d, filter)
	if not filter then return true end
	if filter.place then
		if W.SamePlace then
			local same = call(W.SamePlace, d.dest, filter.place)
			if same == true then return true end
			if same == nil and d.dest:lower() == filter.place:lower() then return true end
		elseif d.dest:lower() == filter.place:lower() then
			return true
		end
		-- a driver whose name or service holds the typed text is shown too ("Gadget" vs Gadgetzan)
		local pt = filter.text and filter.text:lower()
		return pt ~= nil and (d.service:lower():find(pt, 1, true) ~= nil or d.name:lower():find(pt, 1, true) ~= nil)
	end
	local t = filter.text:lower()
	return d.dest:lower():find(t, 1, true) ~= nil or d.service:lower():find(t, 1, true) ~= nil
		or d.name:lower():find(t, 1, true) ~= nil
end

local function applySearch(text, final)
	text = S(text)
	if text then text = text:gsub("^%s+", ""):gsub("%s+$", "") end
	if not text or text == "" then
		ui.filter = nil
	else
		local place = (#text >= 2) and call(W.FindPlace, text)
		local name = type(place) == "table" and S(place.name) or nil
		ui.filter = name and { place = name, text = text } or { text = text }
		if final and name and W.db then W.db.lastDest = name end
	end
	ui.scrollTarget = 0
	UI.Refresh(true)
end

local function buildSearch(sheet)
	local box = CreateFrame("Frame", nil, sheet)
	box:SetSize(INNER, 46)
	box:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -20)
	box.fill = T.PillFill(box, "card", 46, "BACKGROUND", 1)
	box.icon = T.Icon(box, "search", 18, "white", "ARTWORK")
	box.icon:SetPoint("LEFT", box, "LEFT", 18, 0)
	local e = CreateFrame("EditBox", nil, box)
	e:SetPoint("TOPLEFT", box, "TOPLEFT", 46, 0)
	e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -40, 0)
	e:SetAutoFocus(false)
	Try(e, "SetMaxLetters", 40)
	T.OwnFont(e)
	T.SetFont(e, "heading", "bold")
	Try(e, "SetTextColor", 1, 1, 1, 1)
	Try(e, "SetTextInsets", 0, 0, 0, 0)
	box.edit = e
	box.hint = T.Text(box, "heading", "white", "LEFT", "bold")
	box.hint:SetPoint("LEFT", box, "LEFT", 46, 0)
	box.hint:SetText("Where to?")
	box.clear = T.RoundButton(box, "close", 26, "line")
	box.clear:SetPoint("RIGHT", box, "RIGHT", -10, 0)
	box.clear:Hide()
	local function hint()
		local t = S(e:GetText()) or ""
		setShown(box.hint, t == "" and not ui.searchFocus)
		setShown(box.clear, t ~= "")
	end
	box.Hint = hint
	safeScript(e, "OnEditFocusGained", function()
		ui.searchFocus = true
		box.fill:SetColor("hover")
		hint()
	end)
	safeScript(e, "OnEditFocusLost", function()
		ui.searchFocus = false
		box.fill:SetColor("card")
		hint()
	end)
	safeScript(e, "OnTextChanged", function(self)
		hint()
		applySearch(self:GetText(), false)
	end)
	safeScript(e, "OnEnterPressed", function(self)
		self:ClearFocus()
		applySearch(self:GetText(), true)
		local f = ui.filter
		if f and f.place then
			local any = false
			for _, d in ipairs(UI.Drivers()) do
				if matches(d, f) then any = true break end
			end
			if not any then UI.Toast("No drivers to " .. f.place .. " right now", "info") end
		elseif f then
			local any = false
			for _, d in ipairs(UI.Drivers()) do
				if matches(d, f) then any = true break end
			end
			if not any then UI.Toast("No place called " .. f.text, "warn") end
		end
	end)
	safeScript(e, "OnEscapePressed", function(self) self:ClearFocus() end)
	safeScript(box.clear, "OnClick", function()
		e:SetText("")
		e:ClearFocus()
		applySearch("", false)
	end)
	T.Tip(e, "Where to?", "Type a place, like Undercity or Booty Bay. Only drivers who match are listed.")
	T.Tip(box.clear, "Clear", "Clear the search and show every driver.")
	return box
end

W.Listen("SETTINGS", function(key)
	if key == "advanced" and cardMenu and cardMenu:IsShown() and not W.Advanced() then cardMenu:Hide() end
end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.applySearch = applySearch
Mod.buildCard = buildCard
Mod.buildSearch = buildSearch
Mod.chipFor = chipFor
Mod.fillCard = fillCard
Mod.heartButton = heartButton
Mod.isFav = isFav
Mod.matches = matches
Mod.updatedText = updatedText
Mod.usualSummon = usualSummon
