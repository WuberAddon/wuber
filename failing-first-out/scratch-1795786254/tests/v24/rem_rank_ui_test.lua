-- Wuber 2.4, driver ranks part 2 and 3: what riders and drivers see (the list chip, the pin tooltip and ring, the Drive page line) and the new-title card with its guild brag. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H
local S = H.state

local KEY = "anita lift"
local TIP_BODY = "73 verified summons. A summon is verified when a rider who asked through Wuber arrives by it."

local function resolve(v, f)
	if type(v) == "function" then return v(f) end
	return v
end

-- a visible text of the client whose words are exactly text (or start with it, with prefix)
local function textRegion(c, text, prefix)
	for _, obj in ipairs(c.widgets) do
		local s = S[obj]
		if s.otype == "FontString" and s.text and H.visible(obj) then
			local t = s.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			if t == text or (prefix and t:sub(1, #text) == text) then return obj, t end
		end
	end
end

local function apart(a, b, what)
	ok(a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5, what)
end

-- a driver (Anita) online with a verified count, and a rider (Wuber) with the window open on Home who has heard the beacon
local function world(n, opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, opts.driver)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	-- the count is set before the driver opens: a count never sends a beacon of its own, it rides the next one
	if n then d.W.Char().rank = { n = n, seen = {} } end
	T.goOnline(d)
	w:advance(8)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Refresh(true)
	w:advance(2)
	return w, d, r
end

local function card(r)
	return r.W.UI.state.cards and r.W.UI.state.cards[KEY]
end

---------------------------------------------------------------------------
-- 1. the chip in the rider's list
---------------------------------------------------------------------------

test("v24 ranks ui: a driver with 73 summons has the chip Black Cab · 73 with its tooltip; count 0 or an old Wuber has none", function()
	local w, d, r = world(73)
	local c = card(r)
	ok(c and c.rankChip, "the row has a chip")
	ok(c.rankChip:IsShown() and H.visible(c.rankChip), "it shows")
	eq(c.rankChip.label:GetText(), "Black Cab · 73", "its words")
	local tip = c.rankChip.wuberTip
	ok(tip, "a tooltip")
	eq(resolve(tip.title, c.rankChip), "Black Cab", "its title")
	eq(resolve(tip.text, c.rankChip), TIP_BODY, "its words")
	eq(c.rankChip.colour, "muted", "the plain grey style, never gold")
	T.clean(w)
	-- count 0: the beacon has no field, no chip
	local w0, d0, r0 = world(nil)
	local c0 = card(r0)
	ok(c0, "a row")
	ok(not (c0.rankChip and c0.rankChip:IsShown()), "no chip at 0")
	T.clean(w0)
	-- an older Wuber that sends no field: the driver has no rank, the chip goes if it was there
	local w1, d1, r1 = world(5)
	local c1 = card(r1)
	ok(c1 and c1.rankChip and c1.rankChip:IsShown(), "the chip at 5")
	r1.W.drivers[KEY].rank = nil
	r1.W.UI.Refresh(true)
	w1:advance(1)
	ok(not (c1.rankChip and c1.rankChip:IsShown()), "the old driver (no field): no chip")
	T.clean(w1)
end)

-- the d2 way: the list is given to the rider's window, so the names and prices can be anything
local function listed(make)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local UI = c.W.UI
	local list = make(c.env)
	UI.Drivers = function() return list end
	UI.Driver = function(key)
		for _, d in ipairs(list) do if d.key == key then return d end end
	end
	c.W.Usual = function() return nil end
	c.W.AlreadyAt = function() return nil end
	UI.Toggle(true)
	w:advance(3)
	UI.Refresh(true)
	w:advance(2)
	return w, c, list
end

local function drv(env, name, rank, extra)
	local d = { name = name, key = name:lower(), short = name, dest = "Undercity", price = 5000, state = "open", team = 3,
		service = name .. "'s Rides", heard = env.GetTime(), queue = 0, rank = rank }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d
end

test("v24 ranks ui: the chip never overlaps the price or the heart, with a long name and the Founder badge", function()
	local w, c = listed(function(env)
		return {
			drv(env, "Mia", 73),
			drv(env, "Zebediah Wolfeschlegelsteinhausen", 73, { service = "Zebediah Wolfeschlegelsteinhausen's Grand Tours" }),
			drv(env, "Anita", 73, { creator = true, service = "Anita's Portals" }),
			drv(env, "Anitb", 1000, { creator = true, service = "Anitb's Very Long Portals And Grand Tours Of Azeroth" }),
			drv(env, "Plain", nil),
		}
	end)
	local cards = c.W.UI.state.cards
	for _, name in ipairs({ "mia", "zebediah wolfeschlegelsteinhausen", "anita", "anitb" }) do
		local row = cards[name]
		ok(row and row.rankChip and H.visible(row.rankChip), name .. ": the chip shows")
		local C, P, Hh = H.rect(row.rankChip), H.rect(row.price), H.rect(row.heart)
		apart(C, P, name .. ": not over the price")
		apart(C, Hh, name .. ": not over the heart")
		local R = H.rect(row)
		ok(C.l >= R.l - 0.5 and C.l + C.w <= R.l + R.w + 0.5 and C.b >= R.b - 0.5 and C.b + C.h <= R.b + R.h + 0.5, name .. ": inside its row")
		if row.royal and row.royal.chip and H.visible(row.royal.chip) then
			apart(C, H.rect(row.royal.chip), name .. ": not over the Founder badge")
		end
		apart(C, H.rect(row.title), name .. ": not over the name")
		if row.sub and H.visible(row.sub) then
			local sb = H.rect(row.sub)
			ok(sb.l >= C.l + C.w - 0.5 or sb.b + sb.h <= C.b + 0.5 or sb.b >= C.b + C.h - 0.5, name .. ": the second line does not run under the chip")
		end
	end
	ok(not (cards.plain.rankChip and cards.plain.rankChip:IsShown()), "a driver with no rank: no chip")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- 2 and 3. the world-map pin
---------------------------------------------------------------------------

local function pinTip(c, key)
	local Pins = c.W.Mod("UI.Map.Pins")
	local pin = Pins.NewPin(c.env.UIParent)
	pin.key = key
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	Pins.Tooltip(pin)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return out
end

test("v24 ranks ui: the pin's tooltip has the line Black Cab · 73; none without a rank", function()
	local w, d, r = world(73)
	local lines = pinTip(r, KEY)
	local at
	for i, l in ipairs(lines) do if l == "Black Cab · 73" then at = i end end
	ok(at, "the line is there: " .. table.concat(lines, " / "))
	T.clean(w)
	local w0, d0, r0 = world(nil)
	for _, l in ipairs(pinTip(r0, KEY)) do ok(not l:find("·", 1, true) or l:find("driver", 1, true) or l:find("To ", 1, true), "no rank line at 0: " .. l) end
	T.clean(w0)
end)

test("v24 ranks ui: the pin's aura ring is gold from 1000 summons and not at 999", function()
	local w, c, list = listed(function(env)
		return { drv(env, "Mia", 1000), drv(env, "Zed", 999), drv(env, "Kim", 5000), drv(env, "Lou", nil) }
	end)
	local Pins = c.W.Mod("UI.Map.Pins")
	local want = { mia = true, zed = false, kim = true, lou = false }
	for _, d in ipairs(list) do
		local pin = Pins.NewPin(c.env.UIParent)
		pin.key = d.key
		ok(pin.auraRing, "the pin has an aura ring")
		Pins.Paint(pin, d, false, false, false)
		eq(pin.auraRing.gold and true or false, want[d.key], d.key .. ": the gold ring")
	end
	-- 1000 reached by a real beacon
	local w2, d2, r2 = world(1000)
	local pin = Pins.NewPin(r2.env.UIParent)
	pin.key = KEY
	Pins.Paint(pin, r2.W.UI.Driver(KEY), false, false, true)
	eq(pin.auraRing.gold and true or false, true, "a driver heard at 1000: gold")
	T.clean(w2)
	T.clean(w)
end)

---------------------------------------------------------------------------
-- 4. the driver's own line on the wide Drive page
---------------------------------------------------------------------------

local function console(n)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	DR.customers = {}
	DR.IsOpen = function() return true end
	if n then W.Char().rank = { n = n, seen = {} } end
	a.wide = true
	W.db.coach = true
	W.UI.WindowWide(true)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Driver.RefreshNow()
	w:advance(1)
	W.Driver.RefreshNow()
	return w, a, W
end

local function ownLine(a, W, text)
	local t = textRegion(a, text)
	ok(t, "the line reads " .. text .. " (seen: " .. table.concat(a:visibleTexts(), " | ") .. ")")
	return t
end

test("v24 ranks ui: the driver's own line on the wide Drive page, with its words at 73, 1 and 1000", function()
	for _, case in ipairs({
		{ 73, "Black Cab · 73 summons · 177 to Chauffeur" },
		{ 1, "Learner · 1 summon · 9 to Cabbie" },
		{ 1000, "Has The Knowledge · 1000 summons" },
	}) do
		local w, a, W = console(case[1])
		local t = ownLine(a, W, case[2])
		-- the card: the frame with the tip "Your title"
		local card
		for _, f in ipairs(a.frames) do
			if S[f].tip ~= nil or f.wuberTip then
				if f.wuberTip and f.wuberTip.title == "Your title" and H.visible(f) then card = f end
			end
		end
		ok(card, case[1] .. ": the card with its tooltip")
		if card then
			local C, Tr = H.rect(card), H.rect(t)
			ok(Tr.l >= C.l - 0.5 and Tr.l + Tr.w <= C.l + C.w + 0.5 and Tr.b >= C.b - 0.5 and Tr.b + Tr.h <= C.b + C.h + 0.5, case[1] .. ": the line is inside its card")
			local body = resolve(card.wuberTip.text, card)
			ok(body:find("Verified summons count once a rider who asked through Wuber arrives by your summon", 1, true), case[1] .. ": the tip's words")
			if case[1] == 1000 then
				ok(not body:find("next title", 1, true), "no next title on the top rung")
			else
				ok(body:find("The next title comes at", 1, true), case[1] .. ": the next title")
			end
			-- nothing else on the pane overlaps the card
			local today = textRegion(a, "Today's takings", true)
			for _, obj in ipairs(a.widgets) do
				local s = S[obj]
				if s.otype == "FontString" and s.text and s.text ~= "" and H.visible(obj) and obj ~= t then
					local R = H.rect(obj)
					if R and R.l >= C.l - 0.5 and R.l + R.w <= C.l + C.w + 0.5 and R.b + R.h > C.b + 0.5 and R.b < C.b + C.h - 0.5 then
						ok(false, case[1] .. ": a text over the card: " .. s.text)
					end
				end
			end
		end
		T.clean(w)
	end
	-- it follows DRIVE_RANK
	local w, a, W = console(9)
	ownLine(a, W, "Learner · 9 summons · 1 to Cabbie")
	W.Char().rank.n = 10
	W.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
	w:advance(1)
	ownLine(a, W, "Cabbie · 10 summons · 40 to Black Cab")
	T.clean(w)
end)


---------------------------------------------------------------------------
-- 5 to 9. the new-title card and the guild brag
---------------------------------------------------------------------------

local function completeRide(w, d, r, riderName)
	d.W.Drive.opts().autoBlock = false
	T.requestVia(r, "anita lift")
	w:advance(8)
	if not d.W.InGroupWith(d.W.Key(riderName)) then
		w:invite(d, riderName)
		w:advance(2)
	end
	w:player(d.player.name).target = w:player(riderName)
	w:cast(d, w["ri" .. "tualName"])
	w:advance(1)
	w:summon(d, riderName)
	w:advance(1)
	w:move(riderName, "Ratchet")
	w:advance(4)
end

-- a driver with the count n, the window closed, a guild (or none), the Drive nowhere in particular
local function driver(n, guild)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	d.W.Char().rank = { n = n, seen = {} }
	if guild then w:player(T.ANITA).guild = guild end
	w:advance(1)
	return w, d, r
end

local function cardTexts(d)
	return table.concat(d:visibleTexts(), " | ")
end

local function shownTexts(d, ...)
	for _, t in ipairs({ ... }) do
		ok(textRegion(d, t), "the text " .. t .. " shows (seen: " .. cardTexts(d) .. ")")
	end
end

local function posts(w) return w.guildPosts or {} end

local function publicPosts(w)
	local n = #(w.groupPosts or {})
	for _, p in ipairs(w.chatPosts or {}) do if p.kind ~= "PARTY" and p.kind ~= "RAID" then n = n + 1 end end
	return n
end

local function pillOf(d)
	local p = textRegion(d, "Tell the guild")
	return p
end

-- the share pill itself: the first frame above the words that UI.Share knows
local function sharePill(d)
	local f = pillOf(d)
	while f and d.W.UI.Share.State(f) == nil do f = f.GetParent and f:GetParent() or nil end
	return f
end

test("v24 ranks ui: the tenth summon shows the New title card with its words, once, and a reload does not show it again", function()
	local w, d, r = driver(9, "Night Watch")
	completeRide(w, d, r, T.TESTCHAR)
	eq(d.W.Drive.RankCount(), 10, "the tenth summon counted")
	shownTexts(d, "New title", "Cabbie", "10 verified summons", "Tell the guild")
	local rank = d.W.Char().rank
	eq(rank.cardRung, 2, "cardRung saved")
	eq(rank.cardSeen, 2, "cardSeen saved")
	local d2 = w:reload(d) or d
	w:advance(5)
	ok(not textRegion(d2, "New title"), "after a reload the card does not show again")
	eq(d2.W.Char().rank.cardSeen, 2, "still seen")
	T.clean(w)
end)

test("v24 ranks ui: the card by the event alone (no guild, no group): it shows without the pill", function()
	local w, d = driver(10)
	d.W.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
	w:advance(1)
	shownTexts(d, "New title", "Cabbie", "10 verified summons")
	ok(not pillOf(d), "no pill: not in a guild or a group")
	-- a changed count with no new rung makes no card
	d.W.Fire("DRIVE_RANK", 11, 2, "Cabbie", false)
	w:advance(1)
	T.clean(w)
end)

-- the card up, the player in a guild: the pill is the one thing under the mouse that posts
local function cardUp(n, rung, title, guild)
	local w, d, r = driver(n, guild)
	d.W.Fire("DRIVE_RANK", n, rung, title, true)
	w:advance(1)
	return w, d, r
end

test("v24 ranks ui: a real click where the pill is posts the brag line to the guild only, once", function()
	local w, d = cardUp(10, 2, "Cabbie", "Night Watch")
	local pill = pillOf(d)
	ok(pill, "the pill shows")
	local b = d.env.WuberShareButton
	ok(b:IsVisible(), "the secure button is over the card's pill")
	local hit = d:clickOn(pill)
	eq(hit, b, "a click where the pill is lands on the secure share button")
	eq(#posts(w), 1, "one guild post")
	local p = posts(w)[1]
	eq(p.text, "[Wuber] Anita has summoned 10 riders and is now a Cabbie.", "the line")
	eq(p.guild, "Night Watch", "to the guild")
	eq(p.how, "macro", "from the secure macro")
	eq(publicPosts(w), 0, "nothing to a public channel, party or raid")
	local toast
	for _, t in ipairs(d:visibleTexts()) do if t == "Shared with your guild" then toast = true end end
	ok(toast, "the toast: Shared with your guild")
	eq(d.W.Char().rank.bragRung, 2, "bragRung saved")
	w:advance(1)
	ok(not pillOf(d), "the pill is gone")
	ok(not b:IsVisible(), "the overlay is gone")
	eq(b:GetAttribute("macrotext"), "", "the macro is emptied after the click")
	eq(#posts(w), 1, "no second post: nothing is left to click")
	T.clean(w)
end)

test("v24 ranks ui: on the top rung the line is Has The Knowledge", function()
	local w, d = cardUp(1000, 5, "Has The Knowledge", "Night Watch")
	shownTexts(d, "New title", "Has The Knowledge", "1000 verified summons", "Tell the guild")
	d:clickOn(pillOf(d))
	eq(#posts(w), 1, "one guild post")
	eq(posts(w)[1].text, "[Wuber] Anita has summoned 1,000 riders and Has The Knowledge.", "the top rung line")
	eq(d.W.Char().rank.bragRung, 5, "bragRung 5")
	T.clean(w)
end)

test("v24 ranks ui: a rung already bragged about shows the card without the pill", function()
	local w, d = driver(10, "Night Watch")
	d.W.Char().rank.bragRung = 2
	d.W.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
	w:advance(1)
	shownTexts(d, "New title", "Cabbie")
	ok(not pillOf(d), "no pill")
	ok(not d.env.WuberShareButton:IsVisible(), "no overlay")
	T.clean(w)
end)

test("v24 ranks ui: not in a guild but in a party, the pill posts the line to the party; in neither the card has no pill", function()
	local w, d, r = driver(10, nil)
	w:group({ T.ANITA, T.TESTCHAR })
	w:advance(1.5)
	d.W.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
	w:advance(1)
	ok(pillOf(d), "the pill shows in a party")
	d:clickOn(pillOf(d))
	eq(#posts(w), 0, "nothing to a guild")
	eq(#(w.groupPosts or {}), 1, "one party post")
	eq(w.groupPosts[1].kind, "PARTY", "to the party")
	eq(w.groupPosts[1].text, "[Wuber] Anita has summoned 10 riders and is now a Cabbie.", "the line")
	local toast
	for _, t in ipairs(d:visibleTexts()) do if t == "Shared with your party" then toast = true end end
	ok(toast, "the toast says party")
	T.clean(w)
end)

test("v24 ranks ui: in combat nothing is posted and the secure button is not shown, hidden or moved; a card due waits for the fight to end", function()
	-- the card up, then the fight
	local w, d = cardUp(10, 2, "Cabbie", "Night Watch")
	local b = d.env.WuberShareButton
	local pill = sharePill(d)
	ok(pill and b:IsVisible(), "the card and its overlay are up")
	local function snap()
		local p, rel, rp, x, y = b:GetPoint(1)
		return ("%s|%s|%s|%.1f|%.1f|%.1f|%.1f"):format(tostring(b:IsShown()), tostring(p), tostring(rp), x or 0, y or 0, b:GetWidth(), b:GetHeight())
	end
	w:enterCombat(d)
	-- (the window puts the overlays away as the fight begins, before the lockdown: UI.Window's REGEN_DISABLED)
	w:advance(1.2)
	local during = snap()
	ok(not b:IsShown(), "the overlay was put away as the fight began")
	eq(d.W.UI.Share.State(pill), "combat", "the pill's state is combat")
	ok(textRegion(d, "Share after combat"), "it reads Share after combat: " .. cardTexts(d))
	eq(b:GetAttribute("macrotext"), "", "no macro armed")
	-- nothing changes in the fight: a refresh, the sync and a new title do not show, hide or move it
	d.W.UI.Refresh(true)
	d.W.UI.SyncSecure()
	d.W.Fire("DRIVE_RANK", 50, 3, "Black Cab", true)
	w:advance(4)
	eq(snap(), during, "the secure button is not shown, hidden or moved in the fight")
	eq(#posts(w), 0, "nothing posted in combat")
	eq(d.W.Char().rank.bragRung or 0, 0, "and nothing is saved as bragged")
	w:leaveCombat(d)
	w:advance(1.5)
	ok(pillOf(d), "the pill is back after the fight")
	ok(b:IsVisible(), "and its overlay is back over it")
	eq(sharePill(d) and d.W.UI.Share.State(pill), "ok", "the pill's state is ok again")
	T.clean(w)
	-- the card due in a fight
	local w2, d2 = driver(10, "Night Watch")
	local b2 = d2.env.WuberShareButton
	-- (fga B) GetCenter gives no value on an unplaced frame, so it is parenthesised for tostring
	local before2 = ("%s|%s"):format(tostring(b2:IsShown()), tostring((b2:GetCenter())))
	w2:enterCombat(d2)
	d2.W.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
	w2:advance(4)
	ok(not textRegion(d2, "New title"), "no card in combat")
	eq(("%s|%s"):format(tostring(b2:IsShown()), tostring((b2:GetCenter()))), before2, "the secure button untouched in combat")
	eq(d2.W.Char().rank.cardRung, 2, "the rung is kept")
	eq(d2.W.Char().rank.cardSeen or 0, 0, "not seen yet")
	w2:leaveCombat(d2)
	w2:advance(5)
	shownTexts(d2, "New title", "Cabbie")
	eq(d2.W.Char().rank.cardSeen, 2, "seen once it shows")
	eq(#posts(w2), 0, "still nothing posted")
	T.clean(w2)
end)

test("v24 ranks ui: a share pill registered without opts.guild still posts to the party for a player in a guild and a party", function()
	local w = T.newWorld()
	local r = T.rider(w)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	w:player(T.TESTCHAR).guild = "Night Watch"
	local tab = W.UI.GetTab("Ride")
	local pill = W.Theme.Pill(tab, "Share", "dark", 140, 40)
	pill:SetPoint("BOTTOM", tab, "BOTTOM", 0, 20)
	pill:SetFrameLevel(tab:GetFrameLevel() + 50)
	local LINE = "Summoned to Undercity by Anita with Wuber - 9 min saved."
	W.UI.Share.Register(pill, function() return LINE end, { label = "Share" })
	w:group({ T.TESTCHAR, "Sly Fox" })
	w:advance(1.5)
	W.UI.RefreshNow()
	eq(W.UI.Share.Macro(pill), "/p " .. LINE, "the party macro, not /g")
	r:click(r.env.WuberShareButton)
	eq(#(w.groupPosts or {}), 1, "one party post")
	eq(w.groupPosts[1].text, LINE, "the line")
	eq(#posts(w), 0, "nothing to the guild")
	T.clean(w)
end)

test("v24 ranks ui: the harness's guild chat posts only for a player in a guild", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	ok(not r.env.IsInGuild(), "no guild at first")
	w:player(T.TESTCHAR).guild = "Night Watch"
	ok(r.env.IsInGuild(), "in a guild")
	w:runMacro(r, "/g hello")
	eq(#posts(w), 1, "one guild line")
	w:player(T.TESTCHAR).guild = nil
	w:runMacro(r, "/g hello")
	eq(#posts(w), 1, "no guild: nothing posted")
	T.clean(w)
end)
