-- Module: UI.Driver.Sheets
-- Purpose: Price and place sheet, raid "pick summoners", the row menu, the retire card, the
--   end-of-shift card (its fair split and "Post to party").
-- API: D.screens.sheet, D.screens.raidpick, D.screens.menu, D.screens.retire, D.screens.shift,
--   D.SplitText, D.PaintSplit
-- Internals: (none)
-- Uses: UI.Driver.Screens, UI.Driver.Wizard
-- Later: (none)
-- Events: listens SETTINGS; fires SETTINGS
-- Standalone: no
-- Test: tests/ui/driver/sheets_test.lua
-- From: UI_Drive.lua 2111-2668 (Wuber 2.2.1); the shift card: UI.Driver.Earnings (2.2.3)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Sheets", { "UI.Driver.Screens", "UI.Driver.Wizard" })

local ScreensMod = W.Mod("UI.Driver.Screens")
local WizardMod = W.Mod("UI.Driver.Wizard")
local Char, INNER, Pool, call = ScreensMod.Char, ScreensMod.INNER, ScreensMod.Pool, ScreensMod.call
local dr, inCombat, money, nameOf = ScreensMod.dr, ScreensMod.inCombat, ScreensMod.money, ScreensMod.nameOf
local para, plural, safeScript, setShown = ScreensMod.para, ScreensMod.plural, ScreensMod.safeScript, ScreensMod.setShown
local short, st, toast = ScreensMod.short, ScreensMod.st, ScreensMod.toast
local indexOf, isWarlock, saveOrder = WizardMod.indexOf, WizardMod.isWarlock, WizardMod.saveOrder
local T = W.Theme
local noGlow = T.NoGlow -- (design round 1) the shared no-op glow, Theme.Widgets

local DR = W.Drive
local D = W.Driver

local K = D.kit or {}

local S, N = W.Str, W.Num

local function adv() return type(W.Advanced) ~= "function" or W.Advanced() == true end

---------------------------------------------------------------------------
-- The price and place sheet
---------------------------------------------------------------------------

local function placeName(p)
	if type(p) == "table" then return S(p.name) end
	return S(p)
end

D.screens.sheet = function(parent)
	local sh = T.Sheet(parent, 412, "Price and place")
	local s = { frame = sh }
	st.screens.sheet = s
	local b = sh.body
	local y = 4
	local function rowLabel(text, yy)
		local l = T.Text(b, "caption", "muted", "LEFT", "medium")
		l:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -yy)
		l:SetWidth(200)
		l:SetText(text)
		return l
	end
	rowLabel("My price", y + 9)
	s.price = T.Field(b, 140, 32, { justify = "RIGHT", max = 16, onChange = function() s.check() end,
		onEnter = function() s.commit(true) end })
	s.price:SetPoint("TOPRIGHT", b, "TOPRIGHT", -20, -y)
	T.Tip(s.price.edit, "My price", "What one summon costs. Type 50s, 1g or 1g 50s, then Enter or Save. Wuber's lowest fare is 50s.")
	s.priceNote = T.Text(b, "caption", "muted", "RIGHT", "regular")
	s.priceNote:SetPoint("TOPRIGHT", b, "TOPRIGHT", -22, -(y + 36))
	s.priceNote:SetWidth(300)
	y = y + 56
	s.toLabel = rowLabel("Summon to", y + 7)
	s.where = T.Segmented(b, {
		{ value = "here", label = "Where I stand", tip = "Riders are summoned to the place you're standing in (it follows you)." },
		{ value = "choose", label = "Choose", tip = "Pick a place by name: it stays the same wherever you stand." },
	}, "here", function(v)
		s.mode = v
		s.layout()
	end, 220, 28, { byLabel = true }) -- (#262) each segment as wide as its words, the spare shared: "Where I stand" is the longer one
	D.CalmSegmented(s.where)
	s.where:SetPoint("TOPRIGHT", b, "TOPRIGHT", -20, -y)
	y = y + 38
	s.yChoose = y
	s.search = T.Field(b, 320, 32, { placeholder = "Search places (Undercity, Ratchet...)", max = 40,
		onChange = function(text) s.results(text) end,
		onEnter = function() s.commit(true) end }) -- (#304) Enter saves, like in the price box
	T.Tip(s.search.edit, "Choose a place", "Type part of a place's name and tap it below.")
	-- an empty place box means "where I stand" (ING-04): say so under it
	s.emptyNote = T.Text(b, "caption", "muted", "LEFT", "regular")
	s.emptyNote:SetWidth(320)
	s.emptyNote:SetText("Leave it empty to use where you stand.")
	s.capH = 18
	s.hits = {}
	for i = 1, 3 do
		local h = T.Pill(b, "", "dark", 100, 26)
		h.fill:SetColor("raised")
		h:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
		safeScript(h, "OnClick", function(self)
			s.dest = self.place
			s.search:SetText(self.place)
			pcall(s.search.edit.ClearFocus, s.search.edit)
			for _, x in ipairs(s.hits) do x:Hide() end
			s.check()
		end)
		T.Tip(h, function(self) return self.place end, "Summon riders to this place.")
		h:Hide()
		s.hits[i] = h
	end
	s.alsoLabel = rowLabel("Also called", 0)
	s.also = T.Field(b, 190, 30, { placeholder = "uc, under city", max = 60, onEnter = function() s.commit(true) end }) -- (#304)
	T.Tip(s.also.edit, "Also called", "Other words riders use for this place, separated by commas (uc, under city). Wuber spots them in chat.")
	s.nameLabel = rowLabel("Name riders see", 0)
	s.service = T.Field(b, 190, 32, { max = 32, onChange = function() s.check() end, onEnter = function() s.commit(true) end,
		placeholder = W.myName or "Your name" })
	T.Tip(s.service.edit, "Name riders see", "On your card, your map pin and in your whispers. Leave it empty to use your character's name.")
	s.why = T.Text(b, "caption", "red", "RIGHT", "regular")
	s.why:SetWidth(320)
	s.save = T.Pill(b, "Save", "primary", 320, 46)
	safeScript(s.save, "OnClick", function() s.commit() end)
	T.Tip(s.save, "Save", "Riders see the new price and place at once; your crew gets them too.")
	function s.results(text)
		local list = (text and text ~= "" and type(W.SearchPlaces) == "function") and call(W.SearchPlaces, text, 3) or {}
		local x, row = 20, 0
		for i, h in ipairs(s.hits) do
			local name = list and placeName(list[i])
			local wd = name and math.min(320, math.floor(T.MeasureText(name, h.label.wuberBase or "caption", h.label.wuberWeight) + 36))
			-- a name that does not fit the rest of the row wraps onto the next row (the sheet grows by it), never skipped
			if name and x > 20 and x + wd > 340 then x = 20 row = row + 1 end
			if name then
				h.place = name
				-- width first, so the label fits that room at its normal size; pills past the card's edge are not placed
				h:SetWidth(wd)
				h:SetLabel(name)
				h.label.wuberRoom = wd - 26 -- (the label sits 13 in from each edge)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", b, "TOPLEFT", x, -(s.yChoose + 38 + (s.capH or 0) + row * 32))
				x = x + wd + 6
				h:Show()
			else
				h:Hide()
			end
		end
		if (s.hitRows or 0) ~= row then
			s.hitRows = row
			s.layout()
		end
	end
	function s.check()
		local copper = W.ParseMoney(s.price:Text())
		local floor = W.MIN_PRICE or 5000
		local okPrice = true
		if not copper then
			s.priceNote:SetText("Type it like 50s, 1g or 1g 50s")
			s.priceNote:SetTextColor(T.RGB("red"))
			okPrice = false
		elseif copper < floor then
			s.priceNote:SetText("Wuber's lowest fare is " .. money(floor) .. ": it'll be " .. money(floor))
			s.priceNote:SetTextColor(T.RGB("muted"))
		else
			s.priceNote:SetText("Wuber's lowest fare is " .. money(floor))
			s.priceNote:SetTextColor(T.RGB("muted"))
		end
		local name = s.service:Text()
		local why = (adv() and name ~= "" and type(W.SpamReason) == "function") and call(W.SpamReason, name) or nil
		if why then
			s.why:SetText("That name looks like spam to the filter (" .. tostring(why) .. "). Try another.")
			s.why:Show()
		else
			s.why:Hide()
		end
		s.save:SetActive(okPrice and not why)
		return okPrice and not why
	end
	-- 2+ stations: each Warlock summons where they stand; no place to choose
	s.multi = T.Text(b, "sub", "white", "LEFT", "medium")
	s.multi:SetWidth(320)
	s.multi:SetText("Each Warlock summons to where they stand")
	s.multiSub = T.Text(b, "caption", "muted", "LEFT", "regular")
	s.multiSub:SetWidth(320)
	function s.layout()
		local yy = s.yChoose
		local list = D.Stations and D.Stations() or {}
		local multi = #list >= 2
		s.isMulti = multi
		setShown(s.toLabel, not multi)
		setShown(s.where, not multi)
		setShown(s.multi, multi)
		setShown(s.multiSub, multi)
		if multi then
			local names = {}
			for _, st in ipairs(list) do names[#names + 1] = S(st.place) end
			s.multi:ClearAllPoints()
			s.multi:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(yy - 34))
			s.multiSub:ClearAllPoints()
			s.multiSub:SetPoint("TOPLEFT", s.multi, "BOTTOMLEFT", 0, -4)
			s.multiSub:SetText("Right now: " .. table.concat(names, " · "))
			yy = yy + 8
		end
		local isAdv = adv()
		local choose = s.mode == "choose" and not multi
		local showAlso = choose and isAdv
		setShown(s.search, choose)
		setShown(s.emptyNote, choose)
		setShown(s.alsoLabel, showAlso)
		setShown(s.also, showAlso)
		if choose then
			s.search:ClearAllPoints()
			s.search:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -yy)
			s.emptyNote:ClearAllPoints()
			s.emptyNote:SetPoint("TOPLEFT", b, "TOPLEFT", 22, -(yy + 36))
			s.capH = math.max(18, math.ceil(N(call(s.emptyNote.GetStringHeight, s.emptyNote), 14)) + 6)
			yy = yy + 70 + s.capH + (s.hitRows or 0) * 32
			if showAlso then
				s.alsoLabel:ClearAllPoints()
				s.alsoLabel:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(yy + 8))
				s.also:ClearAllPoints()
				s.also:SetPoint("TOPRIGHT", b, "TOPRIGHT", -20, -yy)
				yy = yy + 40
			end
		else
			for _, h in ipairs(s.hits) do h:Hide() end
			s.hereText = s.hereText or T.Text(b, "sub", "white", "LEFT", "medium")
			yy = yy + 2
		end
		if s.hereText then
			setShown(s.hereText, not choose and not multi)
			s.hereText:ClearAllPoints()
			s.hereText:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -yy)
			s.hereText:SetWidth(320)
			local here = type(W.DestHere) == "function" and call(W.DestHere) or nil
			s.hereText:SetText("Right now: " .. (placeName(here) or "where you are"))
			if not choose and not multi then yy = yy + 30 end
		end
		setShown(s.nameLabel, isAdv)
		setShown(s.service, isAdv)
		if isAdv then
			s.nameLabel:ClearAllPoints()
			s.nameLabel:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(yy + 9))
			s.service:ClearAllPoints()
			s.service:SetPoint("TOPRIGHT", b, "TOPRIGHT", -20, -yy)
			yy = yy + 38
			s.why:ClearAllPoints()
			s.why:SetPoint("TOPRIGHT", b, "TOPRIGHT", -22, -yy)
			yy = yy + 18
		else
			s.why:Hide()
		end
		s.save:ClearAllPoints()
		s.save:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -yy)
		sh:SetSheetHeight(62 + yy + 46 + 20)
	end
	function s.commit(byKey)
		if not s.check() then return end
		local c = Char()
		if not c then return end
		local copper = W.ParseMoney(s.price:Text()) or W.MIN_PRICE or 5000
		local floor = W.MIN_PRICE or 5000
		if copper < floor then
			copper = floor
			toast("Wuber's lowest fare is " .. money(floor) .. ": your price is " .. money(floor), "info")
		end
		if type(DR.SetPrice) == "function" then dr("SetPrice", math.floor(copper + 0.5)) else c.price = math.floor(copper + 0.5) end
		-- with 2+ stations the place is where each Warlock stands: it isn't changed here
		if not s.isMulti then
			local dest = s.mode == "choose" and W.Clean(s.search:Text(), 40) or ""
			if type(DR.SetDest) == "function" then dr("SetDest", dest) else c.dest = dest end
			c.destWords = s.mode == "choose" and W.Clean(s.also:Text(), 60) or ""
		end
		local ok, why = true, nil
		if type(DR.SetService) == "function" then ok, why = dr("SetService", s.service:Text()) else c.service = s.service:Text() end
		if ok == false then
			s.why:SetText("Name not saved: " .. (S(why) or "refused"))
			s.why:Show()
			return
		end
		W.Fire("SETTINGS", "price")
		if type(W.SendBeacon) == "function" then call(W.SendBeacon) end
		call(DR.Changed)
		if byKey then W.Sound("click") end -- Enter in a field: no control was pressed (Save clicks by itself)
		sh:Close()
		D.Refresh(true)
	end
	s.enter = function(arg)
		local c = Char() or {}
		s.price:SetText(money((K.Price and K.Price()) or N(c.price) or 5000))
		s.dest = S(c.dest) ~= "" and S(c.dest) or nil
		-- (2.3) "Serve it" from what riders want: that place chosen
		local want = type(arg) == "table" and S(arg.dest) or nil
		if want and want ~= "" then s.dest = W.Clean(want, 40) end
		s.mode = s.dest and "choose" or "here"
		s.where:SetValue(s.mode)
		s.search:SetText(s.dest or "")
		s.also:SetText((want and want ~= "" and not W.SamePlace(want, S(c.dest) or "")) and "" or (S(c.destWords) or ""))
		s.service:SetText(S(c.service) or "")
		for _, h in ipairs(s.hits) do h:Hide() end
		s.hitRows = 0
		s.layout()
		s.check()
	end
	return s
end

---------------------------------------------------------------------------
-- (Group Finder, B1) "List me in the Group Finder": the steps and a short note in big letters for the driver to TYPE by hand
-- (the game's Note box refuses paste and addon SetText, so there is no copy box). Wuber never creates the listing: he does it in
-- Blizzard's own window. Words: W.GroupFinder.DRAFT_WORDS (drafts).
---------------------------------------------------------------------------

D.screens.gflist = function(parent)
	local WD = W.GroupFinder.DRAFT_WORDS
	local sh = T.Sheet(parent, 300, WD.listButton)
	local s = { frame = sh }
	local b = sh.body
	s.steps = T.Para(b, "caption", "muted", 320)
	s.steps:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -8)
	-- the note to type: big letters, never edited here (a label, not a box)
	s.note = T.Para(b, "title", "white", 320, "bold")
	-- a label takes no mouse, so the steps' tip sits on a frame laid over it
	local hit = CreateFrame("Frame", nil, b)
	hit:SetAllPoints(s.note)
	hit:EnableMouse(true)
	T.Tip(hit, WD.listButton, WD.steps)
	s.enter = function()
		local dest = K.Dest and K.Dest() or WD.here
		s.text = string.format(WD.note, dest)
		local h = s.steps:SetPara(WD.steps)
		s.note:ClearAllPoints()
		s.note:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(8 + h + 12))
		local nh = s.note:SetPara(s.text)
		sh:SetSheetHeight(56 + 8 + h + 12 + nh + 24)
	end
	return s
end

---------------------------------------------------------------------------
-- Raid summons: "Pick summoners": the raid's Warlocks, tick who summons
---------------------------------------------------------------------------

-- the raid's Warlocks (DR.RaidWarlocks(): key, name, shards, app), me first when I'm one
local function raidWarlocks()
	local out, seen = {}, {}
	local list = dr("RaidWarlocks")
	if isWarlock() and W.myKey then
		out[1] = { key = W.myKey, name = W.Me and W.Me() or "Me", me = true, app = true, shards = dr("Shards"), class = "WARLOCK" }
		seen[W.myKey] = true
	end
	if type(list) == "table" then
		for _, x in ipairs(list) do
			local k = type(x) == "table" and S(x.key) or (S(x.name) and W.Key(x.name))
			if k and not seen[k] then
				seen[k] = true
				out[#out + 1] = { key = k, name = S(x.name) or nameOf(k), app = x.app ~= false, shards = x.shards,
					offer = S(x.offer), picked = x.picked == true, class = S(x.class) or "WARLOCK" }
			end
		end
	end
	return out
end

local function pickRow(parent, onTick)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(320, 48)
	r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
	r.disc = T.Circle(r, 30, "panel", "ARTWORK")
	r.disc:SetPoint("LEFT", r, "LEFT", 9, 0)
	r.num = T.Text(r, "body", "white", "CENTER", "bold")
	r.num:SetPoint("CENTER", r.disc, "CENTER", 0, 0)
	r.icon = T.Icon(r, "summon", 15, "muted", "OVERLAY")
	r.icon:SetPoint("CENTER", r.disc, "CENTER")
	r.name = T.Text(r, "body", "white", "LEFT", "bold")
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 48, -8)
	r.name:SetPoint("RIGHT", r, "RIGHT", -128, 0)
	r.app = T.Chip(r, "Wuber", "glow")
	r.app:SetPoint("TOPRIGHT", r, "TOPRIGHT", -62, -6)
	r.sub = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.sub:SetPoint("TOPLEFT", r, "TOPLEFT", 48, -27)
	r.sub:SetPoint("RIGHT", r, "RIGHT", -62, 0)
	r.toggle = T.Toggle(r, false, function(on) onTick(r, on) end)
	r.toggle:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	T.Tip(r.toggle, "Summons for the raid", function()
		if r.p and r.p.me then return "On: you summon raiders too." end
		if r.p and not r.p.app then return "On: this Warlock has no Wuber, so your big button asks them in raid chat to summon each raider." end
		return "On: this Warlock gets a card to say yes; then their big button summons the next raider."
	end)
	r:EnableMouse(true)
	T.Tip(r, function() return S(r.p and r.p.name) or "Warlock" end, function() return r.tipText end)
	return r
end

D.screens.raidpick = function(parent)
	local sh = T.Sheet(parent, 420, "Pick summoners")
	local s = { frame = sh }
	st.screens.raidpick = s
	local b = sh.body
	s.scroll = T.Scroll(b)
	s.scroll:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	s.scroll:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 64)
	local c = s.scroll.content
	s.none = para(c, "sub", "muted", 300, 3)
	s.none:SetPoint("TOPLEFT", c, "TOPLEFT", 22, -6)
	-- (AUD-226) a full crew and one more Warlock ticked: said, with the real limit
	local function crewFull()
		local max = tonumber(DR.CREW_MAX) or 8
		local c = dr("char")
		if type(c) ~= "table" or type(c.crew) ~= "table" or #c.crew >= max then toast("Crew is full (" .. max .. " players)", "warn") end
	end
	local function onTick(r, on)
		local p = r.p
		if not p then return end
		local order = {}
		for _, k in ipairs(type(dr("Summoners")) == "table" and dr("Summoners") or {}) do order[#order + 1] = k end
		local at = indexOf(order, p.key)
		if on then
			if p.me then
				if not at then order[#order + 1] = p.key end
				saveOrder(order)
			elseif p.app then
				local inCrew = dr("CrewEntry", p.key) -- (already crew: no card, he summons at once)
				local okOffer = dr("OfferCrew", p.name, "raid")
				if not inCrew or okOffer == false then toast(okOffer == false and ("Couldn't ask " .. short(p.name)) or ("Asked " .. short(p.name) .. " to summon"), okOffer == false and "warn" or "info") end
			elseif type(DR.AddPlainSummoner) == "function" then
				-- nil: the crew is full, he is not added, so no "summons" toast (the switch flips back off)
				if dr("AddPlainSummoner", p.name) then
					toast(short(p.name) .. " summons (no Wuber: your button calls them in raid chat)", "info")
				else
					crewFull()
				end
			else
				if dr("AddPlainHelper", p.name, "L") then
					toast(short(p.name) .. " summons (no Wuber: your button calls them in raid chat)", "info")
				else
					crewFull()
				end
			end
		else
			if at then table.remove(order, at) saveOrder(order) end
			if not p.me then dr("RemoveCrew", p.name) end
		end
		D.Refresh(true)
		s.update()
	end
	s.rows = Pool(c, function(p) return pickRow(p, onTick) end)
	s.done = T.Pill(b, "Done", "primary", 320, 44)
	s.done:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 20, 14)
	safeScript(s.done, "OnClick", function() sh:Close() end)
	T.Tip(s.done, "Done", "Back to the raid console. Ticked Warlocks who said yes summon in this order.")
	s.update = function()
		local list = raidWarlocks()
		local order = dr("Summoners")
		order = type(order) == "table" and order or {}
		local pos = {}
		for i, k in ipairs(order) do pos[k] = i end
		local y = 4
		for i, p in ipairs(list) do
			local r = s.rows.get(i)
			r.p = p
			local n = pos[p.key]
			local o = type(DR.offers) == "table" and DR.offers[p.key] or nil
			local waiting = not n and ((type(o) == "table" and o.state == "waiting") or p.offer == "waiting")
			local said = not n and ((type(o) == "table" and o.state) or p.offer)
			r.name:SetText(p.me and ("You (" .. short(p.name) .. ")") or short(p.name))
			r.name:SetTextColor(T.RGB(D.ClassColour and D.ClassColour(p.class) or "glow"))
			r.app:SetChip(p.app and "Wuber" or "no Wuber", p.app and "glow" or "off")
			local bits = {}
			if n then bits[#bits + 1] = n == 1 and "summons first" or ("summons " .. (({ "", "second", "third" })[n] or (n .. "th"))) end
			if waiting then bits[#bits + 1] = "waiting for a yes" elseif said == "no" then bits[#bits + 1] = "said no" end
			local sh2 = N(p.shards)
			bits[#bits + 1] = sh2 and plural(sh2, "shard") or "shards unknown"
			r.sub:SetText(table.concat(bits, " · "))
			r.sub:SetTextColor(T.RGB((sh2 and sh2 == 0) and "red" or (n and "glow" or "muted")))
			r.num:SetText(n and tostring(n) or "")
			setShown(r.icon, not n)
			r.toggle:SetOn(n ~= nil or waiting == true)
			r.tipText = p.app and "Has Wuber: gets the big button and the portal call." or "No Wuber: you call them in raid chat when it's their turn."
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -y)
			r:Show()
			y = y + 54
		end
		s.rows.hideFrom(#list)
		if #list == 0 then
			s.none:SetText("No Warlocks in your raid yet. Invite them, then tick who summons here.")
			s.none:Show()
			y = y + 50
		else
			s.none:Hide()
		end
		-- the sheet grows first, so the scroll range is worked out against the new window height
		sh:SetSheetHeight(math.min(470, 66 + math.max(y, 60) + 72))
		s.scroll:SetContentHeight(y + 4)
	end
	s.enter = function()
		sh:SetTitle("Pick summoners", "Warlocks in your raid · tick who summons")
		s.scroll:ScrollTo(0, true)
	end
	return s
end

---------------------------------------------------------------------------
-- The row menu (hold a name, or its "..."): big labelled rows
---------------------------------------------------------------------------

D.screens.menu = function(parent)
	local sh = T.Sheet(parent, 380, "Rider")
	local s = { frame = sh }
	st.menu = s
	local b = sh.body
	s.items = {}
	local function item(id, text, sub, glyph, colour)
		local r = T.ListButton(b, 320, 46, text, sub, glyph, colour)
		r.id = id
		safeScript(r, "OnClick", function(self) s.pick(self.id) end)
		T.Tip(r, function() return (r.label and r.label:GetText()) or text end, function() return (r.sub and r.sub:GetText()) or sub end)
		s.items[id] = r
		return r
	end
	item("invite", "Invite", "Invite them to your group now", "ride", "glow")
	item("next", "Summon next", "Their summon comes before the others", "summon", "glow")
	item("paid", "Mark as paid", "They paid some other way (Ctrl-click)", "coin", "glow")
	item("helper", "Not a rider (a helper)", "They came to click the portal: never billed", "star", "glow")
	item("oops", "Oops, wrong invite", "Says sorry and removes them", "close", "glow")
	item("drop", "Take off the list", "Nothing is said (right-click)", "close", "muted")
	item("block", "Block...", "Never serve them again (shift-right-click)", "lock", "red")
	-- raid summons: no money, no blocks
	item("top", "Move to top", "Summoned next, before the others (click)", "summon", "glow")
	item("rdrop", "Take off the list", "Nothing is said (right-click)", "close", "muted")
	-- the block step: a reason, then Block
	s.reason = T.Field(b, 320, 34, { max = 60, placeholder = "Why (they're told if you chose Block and tell them)",
		-- (job 2767) Enter confirms like the Block button
		onEnter = function()
			local click = s.doBlock and s.doBlock:GetScript("OnClick")
			if click and s.doBlock:IsShown() then pcall(click, s.doBlock) end
		end })
	s.reason:Hide()
	T.Tip(s.reason.edit, "Reason", "A few words on why. Shared with your crew; told to them if that setting is on.")
	s.doBlock = T.Pill(b, "Block", "danger", 320, 42)
	s.doBlock:Hide()
	safeScript(s.doBlock, "OnClick", function()
		local why = W.Clean(s.reason:Text(), 60)
		if K and D.RowAction then D.RowAction(s.c, "block", why ~= "" and why or "blocked by hand") end
		sh:Close()
	end)
	T.Tip(s.doBlock, "Block", "They won't be invited or summoned again by your crew. Undo it in Blocked.")
	function s.pick(id)
		-- round 9: "Get Wuber", "Note..." and "Gifted" (UI.Driver.Customers)
		if D.CustomerPick and D.CustomerPick(s, id) then return end
		if id == "top" or id == "rdrop" then
			D.RaidAction(s.c, id == "top" and "top" or "drop")
			sh:Close()
			return
		end
		if id == "raincheck" then
			D.GiveRaincheck(s.c)
			sh:Close()
			return
		end
		if id == "block" then
			s.blocking = true
			s.layout()
			pcall(s.reason.edit.SetFocus, s.reason.edit)
			return
		end
		D.RowAction(s.c, id)
		sh:Close()
	end
	function s.layout()
		local c = s.c or {}
		for _, r in pairs(s.items) do r:Hide() end
		s.reason:Hide()
		s.doBlock:Hide()
		local y = 0
		if s.blocking then
			sh:SetTitle("Block " .. short(c.name) .. "?", "They won't be served again")
			s.reason:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -y)
			s.reason:Show()
			s.doBlock:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(y + 46))
			s.doBlock:Show()
			sh:SetSheetHeight(66 + 46 + 42 + 30)
			return
		end
		local isAdv = adv()
		local list = {}
		if s.raid then
			list = { "top", "rdrop" }
			if S(c.claimedBy) then list = { "rdrop" } end
		end
		if not s.raid and c.state == "lead" then list[#list + 1] = "invite" end
		local iou = isAdv and not s.raid and D.RaincheckRide and D.RaincheckRide(c) ~= nil
		-- (2.3) a paid ride that failed before they arrived: one free summon later
		-- (the row is made the first time it is offered)
		if iou and not s.items.raincheck then
			item("raincheck", "Give raincheck", "One summon later at no charge from your crew, instead of a refund", "coin", "glow")
		end
		if c.iouOnly then
			list = iou and { "raincheck" } or {}
		elseif not s.raid then
			if c.state == "joined" or c.state == "waiting" then
				list[#list + 1] = "next"
				s.items.next.label:SetText((c.state == "waiting" or (N(c.tries) or 0) > 0) and "Summon again" or "Summon next")
			end
			if isAdv then
				list[#list + 1] = "paid"
				if iou then list[#list + 1] = "raincheck" end
				list[#list + 1] = "helper"
			end
			if dr("CanOops", c) == true then list[#list + 1] = "oops" end
			s.items.drop.sub:SetText(isAdv and "Nothing is said (right-click)" or "Nothing is said")
			s.items.block.sub:SetText(isAdv and "Never serve them again (shift-right-click)" or "Never serve them again")
			list[#list + 1] = "drop"
			list[#list + 1] = "block"
		end
		-- round 9: the customer book's items (UI.Driver.Customers)
		if D.CustomerMenu then D.CustomerMenu(s, list, item, c) end
		for _, id in ipairs(list) do
			local r = s.items[id]
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", b, "TOPLEFT", 16, -y)
			r:SetPoint("TOPRIGHT", b, "TOPRIGHT", -16, -y) -- the sheet is the phone's width: the row takes what it has
			-- words are never cut: a second line that does not fit its room wraps, and the row grows to hold it
			local room = (b:GetWidth() or 360) - 32 - 64
			local text = r.sub and r.sub.GetText and r.sub:GetText()
			local long = text and text ~= "" and T.MeasureText(text, "caption", "regular") * 1.04 > room
			if r.sub then
				r.sub:SetWordWrap(long and true or false)
				r.sub:SetHeight(long and 26 or 13)
			end
			r:SetHeight(long and 62 or 46)
			r:Show()
			y = y + (long and 68 or 52)
		end
		sh:SetSheetHeight(66 + y + 18)
	end
	s.enter = function(c)
		s.c = c
		s.blocking = nil
		s.raid = K.RaidMode and K.RaidMode() == true
		-- a Pioneer rider's header says so first (the shipped list only)
		local look = T.PioneerLook(S(c and c.name))
		local pioneer = look and T.PIONEER[look].word or nil
		if s.raid then
			sh:SetTitle(S(c and c.name) or "Raider", (pioneer and (pioneer .. " · ") or "") .. "Raid summon · no charge")
			s.layout()
			if W.db then W.db.holdTip = true end
			return
		end
		if c and c.iouOnly then
			-- (2.3) from the raincheck alert: only "Give raincheck"
			local yes, why = nil, nil
			if D.RaincheckRide then yes, why = D.RaincheckRide(c) end
			sh:SetTitle(S(c.name) or "Rider", yes and "Paid by trade · the summon failed before they arrived"
				or (S(why) or "No raincheck for this ride now"))
			s.layout()
			return
		end
		local reason = (c and (N(c.paid) or 0) == 0 and (c.state == "arrived" or c.state == "waiting")) and "didn't pay" or "blocked by hand"
		s.reason:SetText(reason)
		local sub = S(c and c.wuberLabel) or (c and c.source == "wuber" and "Booked through Wuber") or nil
		-- (2.3) the app rider's passphrase in the header
		local pass = D.Passphrase and D.Passphrase(c) or nil
		if pass then sub = (sub and (sub .. " · ") or "") .. pass end
		if pioneer then sub = pioneer .. (sub and (" · " .. sub) or "") end
		sh:SetTitle(S(c and c.name) or "Rider", sub)
		s.layout()
		if W.db then W.db.holdTip = true end
	end
	return s
end

---------------------------------------------------------------------------
-- The retire card (in the Drive tab's provider view while the old 1.x summoning addon still
-- drives). Never names it on screen (the author, 18 Nov): "Your old summoning addon is still on".
---------------------------------------------------------------------------

local laterThisSession = false

local function disableRR()
	-- what the old addon recorded since the import comes over now, while its data is loaded
	dr("MergeRetired")
	local done = false
	if type(C_AddOns) == "table" and type(C_AddOns.DisableAddOn) == "function" then
		done = pcall(C_AddOns.DisableAddOn, "RitualRides")
	elseif type(DisableAddOn) == "function" then
		done = pcall(DisableAddOn, "RitualRides")
	end
	return done
end

D.screens.retire = function(parent)
	local card = T.Card(parent, INNER, 186, { colour = "card", radius = 16, shadow = false })
	card.glow = noGlow() -- (design 1) no gold outline or halo
	local icon = T.Icon(card, "summon", 20, "glow", "OVERLAY")
	icon:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
	card.title = T.Text(card, "body", "white", "LEFT", "bold")
	card.title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	card.title:SetWidth(INNER - 60)
	card.title:SetText("Your old summoning addon is still on")
	card.text = para(card, "caption", "muted", INNER - 32, 3)
	card.text:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -44)
	card.text:SetText("Your price, crew, messages, blocked list and earnings are copied into Wuber. Switch the old addon off and Wuber drives from now on.")
	card.go = T.Pill(card, "Switch it off and reload", "primary", INNER - 32, 40)
	card.go:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 46)
	safeScript(card.go, "OnClick", function()
		if inCombat() then toast("After the fight", "warn") return end
		if disableRR() then
			-- (#230) ReloadUI from addon code is blocked in the real client (tainted): the player types it
			card.text:SetText("Type /reload to finish")
			return
		end
		card.failed = true
		card.text:SetText("Untick your old summoning addon in the AddOns list (Esc > AddOns), then type /reload.")
		card.text:SetTextColor(T.RGB("red"))
	end)
	T.Tip(card.go, "Switch it off", "Turns your old summoning addon off and asks you to type /reload to finish. Wuber then drives with everything it had.")
	card.later = T.Pill(card, "Later", "ghost", 100, 30)
	card.later:SetPoint("BOTTOM", card, "BOTTOM", 0, 10)
	card.later.label:SetTextColor(T.RGB("muted"))
	safeScript(card.later, "OnClick", function()
		laterThisSession = true
		local db = DR.db or (W.db and W.db.drive)
		if type(db) == "table" then db.rrCard = "later" end
		D.Refresh(true)
	end)
	T.Tip(card.later, "Later", "Keep the old addon driving for now. The card comes back next time you log in.")
	card.update = function()
		local db = DR.db or (W.db and W.db.drive)
		local imported = type(db) == "table" and db.imported ~= nil
		local want = dr("Lock") == "rr" and imported and not laterThisSession
		setShown(card, want)
		return want
	end
	st.retire = card
	return card
end

---------------------------------------------------------------------------
-- The end-of-shift card (review #20): when a seller closes, what the shift brought
---------------------------------------------------------------------------

-- (moved here from UI.Driver.Earnings in 2.3: the card is a sheet) "1.5g" an hour, "2.5 h" open
local function gph(copper)
	copper = N(copper) or 0
	if copper >= 10000 then
		local g = copper / 10000
		return (g >= 10 and tostring(math.floor(g + 0.5)) or (("%.1f"):format(g):gsub("%.0$", ""))) .. "g"
	end
	return money(copper)
end

local function hoursText(minutes)
	minutes = N(minutes) or 0
	if minutes < 60 then return math.floor(minutes + 0.5) .. " min" end
	local h = minutes / 60
	return (h >= 10 and tostring(math.floor(h + 0.5)) or (("%.1f"):format(h):gsub("%.0$", ""))) .. " h"
end


-- (2.3) The fair split under the tiles: "Farra · 9 clicks · 1g 40s" per person (from
-- the cut taken when the shift closed: D.lastShift.cut), the rule in small words, "Wuber never
-- moves gold", and "Post to party" (a share pill: the secure WuberShareButton posts it on the
-- player's click, once per card). Without a crew's casts or clicks the card is as in 2.2.
local SPLIT_MAX = 6

-- the line "Post to party" shares (<= 240 characters; nil when there is nothing to share)
function D.SplitText(cut)
	if type(cut) ~= "table" then return nil end
	local text = S(cut.text)
	if not text then
		local bits = {}
		for _, x in ipairs(cut.rows or {}) do
			if N(x.share) and x.share > 0 then bits[#bits + 1] = W.Short(x.name) .. " " .. money(x.share) end
		end
		if #bits == 0 then return nil end
		text = "Shift split: " .. table.concat(bits, ", ")
	end
	return W.Clean(text, 240)
end

local function inGroup() return type(W.InGroup) == "function" and call(W.InGroup) == true end

local function postPillWidth()
	local m = T.MeasureText and tonumber((T.MeasureText("Share after combat", "body", "medium"))) or 0
	return math.max(156, math.ceil(m * 1.06) + 46)
end

local function buildSplit(s, b, sh)
	local p = {}
	p.head = T.Text(b, "body", "white", "LEFT", "bold")
	p.head:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -218)
	p.head:SetText("Fair split")
	p.headHit = CreateFrame("Frame", nil, b)
	p.headHit:SetPoint("TOPLEFT", p.head, "TOPLEFT", 0, 2)
	p.headHit:SetSize(math.ceil(T.MeasureText("Fair split", "body", "bold") * 1.1) + 8, 18)
	p.headHit:EnableMouse(true)
	T.Tip(p.headHit, "Fair split", function()
		local cut = D.lastShift and D.lastShift.cut
		if type(cut) ~= "table" then return D.CutRuleText() end
		return D.CutRuleText(cut.rule, cut.pct, cut.rows)
	end)
	p.lines = {}
	p.rule = T.Text(b, "caption", "muted", "LEFT", "regular")
	p.rule:SetWidth(320)
	T.Lines(p.rule, 2)
	p.note = T.Text(b, "caption", "muted", "LEFT", "medium")
	p.note:SetWidth(320)
	p.note:SetText("Pay your helpers by trade.")
	p.post = T.Pill(b, "Post to party", "primary", 156, 44)
	p.post:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 20, 14)
	if type(p.post.HookScript) == "function" then
		call(p.post.HookScript, p.post, "OnSizeChanged", function(_, w)
			if p.post:IsShown() and s.done then
				s.done:SetWidth(math.max(76, 320 - 8 - (tonumber(w) or 156)))
			end
		end)
	end
	safeScript(p.post, "OnClick", function()
		-- reached only when the secure share button isn't over it: say why
		if call(W.InCombat) == true then toast("Share after combat", "warn") return end
		toast("Join a party to post the split", "info")
	end)
	T.Tip(p.post, "Post to party", function()
		local line = D.SplitText(D.lastShift and D.lastShift.cut)
		return (call(W.InCombat) == true and "Waits for the fight to end, then you can post the split in party chat (raid chat in a raid), once, on your click."
			or "Posts the split in party chat (raid chat in a raid), once, on your click.")
			.. (line and ("\n\n" .. line) or "") .. "\n\nNothing is paid by this: trade your helpers their share."
	end)
	-- the share overlay (UI.Share, the secure WuberShareButton) docks over the pill; once per card
	local function textFn()
		local sum = D.lastShift
		if not adv() or not (sum and sum.cut) or s.sharedAt == sum.at or not sh.open then return nil end
		return D.SplitText(sum.cut)
	end
	-- (#16) the pill shows at once, but while the card rises it lies under the window's foot: the secure overlay
	-- must not dock there. pill.dockHold (read by UI.Share.Target and UI.Secure) is true while the sheet moves and the
	-- pill is outside the window; the sheet's own OnUpdate looks again each frame and docks the overlay when it clears.
	local function inside()
		local pb, pt = tonumber((call(p.post.GetBottom, p.post))), tonumber((call(p.post.GetTop, p.post)))
		local sb, st = tonumber((call(sh.GetBottom, sh))), tonumber((call(sh.GetTop, sh)))
		return not (pb and pt and sb and st) or (pb >= sb - 0.5 and pt <= st + 0.5)
	end
	s.holdDock = function() p.post.dockHold = (sh.run ~= nil and not inside()) or nil end
	if type(sh.HookScript) == "function" then
		call(sh.HookScript, sh, "OnUpdate", function()
			if p.post.dockHold and inside() then
				p.post.dockHold = nil
				if W.UI and type(W.UI.SyncSecure) == "function" then call(W.UI.SyncSecure) end
			end
		end)
	end
	local function shared()
		s.sharedAt = D.lastShift and D.lastShift.at
		if s.update then call(s.update) end
	end
	p.post.onShared = shared
	if W.UI and W.UI.Share and type(W.UI.Share.Register) == "function" then
		call(W.UI.Share.Register, p.post, textFn, { label = "Post to party", onShared = shared })
	end
	s.split = p
	return p
end

-- how tall the shift card may be: its top stays under the driver status strip (the real
-- client drew it over the strip's words). nil when the console's rects are not known yet.
local function roomUnderStrip()
	local ui = D.ui
	local sb = ui and ui.console and ui.console.statusBox
	local top, base = sb and tonumber((call(sb.GetBottom, sb))), ui and ui.root and tonumber((call(ui.root.GetBottom, ui.root)))
	if top and base and top > base then return top - base - 10 end
	return nil
end

-- the four tiles: normal, or squeezed (lower and flatter) when the card must give up room
local function layoutTiles(s, b, compact)
	local tw = math.floor((320 - 8) / 2)
	local h, pitch = compact and 56 or 66, compact and 60 or 74
	local isAdv = adv()
	for i, t in ipairs(s.tiles) do
		setShown(t, i <= 2 or isAdv)
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		t:SetHeight(h)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", b, "TOPLEFT", 20 + col * (tw + 8), -(66 + row * pitch))
		t.label:ClearAllPoints()
		t.label:SetPoint("TOPLEFT", t, "TOPLEFT", 12, compact and -6 or -8)
		t.value:ClearAllPoints()
		t.value:SetPoint("TOPLEFT", t, "TOPLEFT", 12, compact and -19 or -26)
		t.sub:ClearAllPoints()
		t.sub:SetPoint("TOPLEFT", t, "TOPLEFT", 12, compact and -41 or -50)
	end
end

function D.PaintSplit(s, sh)
	local isAdv = adv()
	local cut = isAdv and D.lastShift and D.lastShift.cut
	local rows = type(cut) == "table" and type(cut.rows) == "table" and cut.rows or {}
	local p = s.split
	local b0 = sh.body
	if #rows == 0 then
		s.compact = false
		layoutTiles(s, b0, false)
		if p then
			for _, f in ipairs({ p.head, p.headHit, p.rule, p.note, p.post }) do if f then f:Hide() end end
			for _, l in ipairs(p.lines) do l.name:Hide() l.what:Hide() end
			local Share = W.UI and W.UI.Share
			if Share and type(Share.Sync) == "function" then call(Share.Sync) end
		end
		s.done:SetWidth(320)
		s.done:ClearAllPoints()
		s.done:SetPoint("BOTTOMLEFT", b0, "BOTTOMLEFT", 20, 14)
		sh:SetSheetHeight(isAdv and 352 or 278)
		return
	end
	local b = sh.body
	p = p or buildSplit(s, b, sh)
	-- the card's top must clear the status strip: first squeeze the tiles, then show fewer rows
	local room = roomUnderStrip()
	local function need(rowsN, compact) return ((sh.card and sh.card.topPad) or 56) + (compact and 214 or 238) + 20 * rowsN + 48 + 6 + 44 + 14 end
	local n = math.min(#rows, SPLIT_MAX)
	local compact = room ~= nil and need(n, false) > room + 0.01
	if compact then
		while n > 1 and need(n, true) > room + 0.01 do n = n - 1 end
	end
	s.compact = compact
	layoutTiles(s, b, compact)
	p.head:ClearAllPoints()
	p.head:SetPoint("TOPLEFT", b, "TOPLEFT", 20, compact and -194 or -218)
	local y = compact and 214 or 238
	for i = 1, n do
		local x = rows[i]
		local l = p.lines[i]
		if not l then
			l = { name = T.Text(b, "sub", "white", "LEFT", "medium"), what = T.Text(b, "sub", "gold", "RIGHT", "bold") }
			l.name:SetWidth(230)
			l.what:SetWidth(86)
			l.name.wuberMin = T.SIZE.sub -- one size for every row: never shrunk to fit
			l.what.wuberMin = T.SIZE.sub
			p.lines[i] = l
		end
		-- one size: a line too long for 230 px drops its casts and clicks, never shrinks
		local who = x.key == W.myKey and "You" or W.Short(x.name)
		local words = " · " .. D.CutWords(x.casts, x.clicks)
		if T.MeasureText(who .. words, "sub", "medium") * 1.04 > 230 then words = "" end
		l.name:SetText(who .. T.Code("muted") .. words .. "|r")
		l.what:SetText(N(x.share) and money(x.share) or "-")
		l.name:ClearAllPoints()
		l.name:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -y)
		l.what:ClearAllPoints()
		l.what:SetPoint("TOPRIGHT", b, "TOPLEFT", 340, -y)
		l.name:Show()
		l.what:Show()
		y = y + 20
	end
	for i = n + 1, #p.lines do p.lines[i].name:Hide() p.lines[i].what:Hide() end
	p.head:Show()
	if p.headHit then p.headHit:Show() end
	p.rule:SetText((#rows > n and ("+" .. (#rows - n) .. " more in Earnings. ") or "") .. D.CutRuleText(cut.rule, cut.pct, rows, true))
	p.rule:ClearAllPoints()
	p.rule:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(y + 2))
	p.rule:Show()
	p.note:ClearAllPoints()
	p.note:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(y + 30))
	p.note:Show()
	-- the share pill: only in a group and with a line to share; in a fight it waits. UI.Share
	-- owns its words and whether it shows (UI.Share.State); without it, the same rules here.
	local Share = W.UI and W.UI.Share
	-- a fight may have ended while the card was closed: bring the pill's words and dimming up to date first
	if Share and type(Share.Sync) == "function" then call(Share.Sync) end
	local state = Share and type(Share.State) == "function" and call(Share.State, p.post) or nil
	local show
	if state ~= nil then
		show = state == "ok" or state == "combat"
	else
		local posted = s.sharedAt ~= nil and s.sharedAt == D.lastShift.at
		show = inGroup() and D.SplitText(cut) ~= nil
		local fight = call(W.InCombat) == true
		p.post:SetWidth(fight and postPillWidth() or 156)
		p.post:SetLabel(posted and "Posted" or (fight and "Share after combat" or "Post to party"))
		p.post:SetActive(not posted and not fight)
	end
	setShown(p.post, show)
	local doneW = show and math.max(76, 320 - 8 - (tonumber((p.post:GetWidth())) or 156)) or 320
	s.done:SetWidth(doneW)
	s.done:ClearAllPoints()
	s.done:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", 340, 14)
	sh:SetSheetHeight(((sh.card and sh.card.topPad) or 56) + y + 48 + 6 + 44 + 14)
end

-- one tile of the shift card: a small label, the number, a quiet line under it
local function tile(parent, w, h, label, colour)
	local t = T.Card(parent, w, h, { colour = "hover", radius = 12, shadow = false })
	t.label = T.Text(t, "caption", "muted", "LEFT", "medium")
	t.label:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -8)
	t.label:SetWidth(w - 24)
	t.label:SetText(label)
	t.value = T.Text(t, "heading", colour or "white", "LEFT", "bold")
	t.value:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -26)
	t.value:SetWidth(w - 24)
	t.sub = T.Text(t, "caption", "muted", "LEFT", "regular")
	t.sub:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -50)
	t.sub:SetWidth(w - 24)
	return t
end

-- (run 1, group o) the sheet's top must not land inside the console's Open / Pause / Advertise row, which showed
-- the pills' labels cut in half (an in-game screenshot): when it would, the sheet grows to cover the whole row (never past
-- the status strip). Units are the phone's own: the pills' edges less the root's bottom.
local function coverPills(sh)
	local ui = D.ui
	local v, root = ui and ui.console, ui and ui.root
	local base = root and tonumber((call(root.GetBottom, root)))
	local h = sh and sh.sheetH
	if not (v and base and h) then return end
	local top
	for _, name in ipairs({ "open", "pause", "advert", "pick" }) do
		local p = v[name]
		if p and call(p.IsShown, p) then
			local t, b = tonumber((call(p.GetTop, p))), tonumber((call(p.GetBottom, p)))
			if t and b and b - base + 0.5 < h and h < t - base - 0.5 then top = math.max(top or 0, t - base) end
		end
	end
	if not top then return end
	local want = top + 6
	local room = roomUnderStrip()
	if room and want > room + 0.01 then return end
	sh:SetSheetHeight(want)
end

D.screens.shift = function(parent)
	local sh = T.Sheet(parent, 352, "Shift complete")
	local s = { frame = sh }
	st.screens.shift = s
	local b = sh.body
	s.gold = T.Text(b, "display", "gold", "LEFT", "bold")
	s.gold:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -6)
	s.gold:SetWidth(320)
	s.goldSub = T.Text(b, "caption", "muted", "LEFT", "regular")
	s.goldSub:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -40)
	s.goldSub:SetWidth(320)
	local tw = math.floor((320 - 8) / 2)
	s.tiles = {}
	for i, def in ipairs({ { "Rides", "white" }, { "Tips", "gold" }, { "Best hour", "glow" }, { "Open", "white" } }) do
		local t = tile(b, tw, 66, def[1], def[2])
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		t:SetPoint("TOPLEFT", b, "TOPLEFT", 20 + col * (tw + 8), -(70 + row * 74))
		setShown(t, i <= 2 or adv())
		s.tiles[i] = t
	end
	s.done = T.Pill(b, "Nice", "primary", 320, 44)
	s.done:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 20, 14)
	safeScript(s.done, "OnClick", function() sh:Close() end)
	T.Tip(s.done, "Done", "Back to your console. Earnings has every shift's numbers.")
	-- (#16) a closed card has no line to share: the pill and its overlay go with the first frame of the drop
	sh.onClose = function()
		local Share = W.UI and W.UI.Share
		if Share and type(Share.Sync) == "function" then call(Share.Sync) end
	end
	s.update = function()
		D.PaintSplit(s, sh)
		if s.holdDock then s.holdDock() end
		coverPills(sh)
		local sum = D.lastShift or {}
		local copper, rides, tips = N(sum.copper) or 0, N(sum.rides) or 0, N(sum.tips) or 0
		local crewR, crewC = N(sum.crewRides) or 0, N(sum.crewCopper) or 0
		local open = N(sum.open)
		-- (round 13, I11) the fair split below shares the crew's whole takings (mine and what my crew
		-- took), so the headline and the rate are that total; "your crew took" (not "to your crew",
		-- which read as their share)
		local whole = copper + crewC
		s.gold:SetText(money(whole))
		local rate = (open and open >= 600) and (" · " .. gph(whole / (open / 3600)) .. " an hour") or ""
		-- (review 13) with a crew the whole isn't all mine: "taken", beside "your crew took"
		s.goldSub:SetText("this shift" .. rate)
		s.tiles[1].value:SetText(tostring(rides + crewR))
		s.tiles[1].sub:SetText(crewR > 0 and (rides .. " yours · " .. crewR .. " crew") or (rides == 1 and "rider paid" or "riders paid"))
		s.tiles[2].value:SetText(tips > 0 and money(tips) or "-")
		s.tiles[2].sub:SetText("")
		local bh = N(sum.bestHour)
		s.tiles[3].value:SetText(bh and ("%02d:00"):format(bh) or "-")
		s.tiles[3].sub:SetText((bh and N(sum.bestCopper)) and money(sum.bestCopper) or "")
		s.tiles[4].value:SetText(open and hoursText(open / 60) or "-")
		s.tiles[4].sub:SetText("")
	end
	return s
end

W.Listen("SETTINGS", function(key)
	if key ~= "advanced" then return end
	local sheet = st.screens and st.screens.sheet
	if sheet and sheet.frame and sheet.frame.open then
		sheet.layout()
		sheet.check()
	end
	local menu = st.menu
	if menu and menu.frame and menu.frame.open then menu.layout() end
	local shift = st.screens and st.screens.shift
	if shift and shift.frame and shift.frame.open then shift.update() end
end)
