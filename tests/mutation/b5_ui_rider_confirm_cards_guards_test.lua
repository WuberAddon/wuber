-- Mutation run guards for Wuber/UI/Rider/Confirm.lua and Wuber/UI/Rider/Cards.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupRiderAndDriver(opts)
	opts = opts or {}
	local w = T.newWorld({ clubs = true })
	local d = T.driver(w, T.ANITA, {
		spot = opts.spot or "Orgrimmar",
		price = opts.price or 50000,
		seats = opts.seats,
		busy = opts.busy,
	})
	local r = T.rider(w, T.DAN, { spot = "Durotar", money = 200000, screenW = opts.screenW, screenH = opts.screenH })
	w:advance(15)
	if not r.W.drivers[d.W.myKey] then
		r.W.drivers[d.W.myKey] = {
			name = d.W.myName,
			key = d.W.myKey,
			dest = opts.spot or "Orgrimmar",
			price = opts.price or 50000,
			state = opts.busy and "busy" or "open",
			seats = opts.seats ~= nil and opts.seats or 4,
			team = 1,
			service = opts.service or "Anita's Rides",
			creator = opts.creator,
			rank = opts.rank,
			heard = r.env.GetTime(),
		}
	end
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r.W.UI.Refresh(true)
	return w, d, r
end

local function openConfirm(w, r, driverKey)
	local UI = r.W.UI
	UI.Show("confirm", driverKey)
	w:advance(0.5)
	return UI.state.screens.confirm
end

local function hoverBody(c, region)
	local enter = region:GetScript("OnEnter")
	ok(type(enter) == "function", "OnEnter script present")
	enter(region)
	local fs = c.env.GameTooltipTextLeft2
	local text = fs and fs:GetText() or ""
	local leave = region:GetScript("OnLeave")
	if leave then leave(region) end
	return text
end

---------------------------------------------------------------------------
-- Wuber/UI/Rider/Confirm.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Rider/Confirm.lua:78 (if cond negated: leaveGroup skips W.LeaveGroup when it is a function)
-- guards Wuber/UI/Rider/Confirm.lua:81 (local value -> nil: leaveGroup skips C_PartyInfo.LeaveParty fallback)
-- guards Wuber/UI/Rider/Confirm.lua:82 (cmp ~=->==: leaveGroup skips LeaveParty global fallback)
test("mutation b5 ui rider confirm: Leave group button uses W.LeaveGroup, then C_PartyInfo.LeaveParty, then LeaveParty", function()
	local w, d, r = setupRiderAndDriver()
	local origInGroup = r.W.InGroup
	r.W.InGroup = function() return true end
	local s = openConfirm(w, r, d.W.myKey)
	-- 1) W.LeaveGroup path
	local origWLeave = r.W.LeaveGroup
	local called = 0
	r.W.LeaveGroup = function()
		called = called + 1
		return true
	end
	r:clickOn(s.leave)
	eq(called, 1, "W.LeaveGroup called when present")

	-- 2) C_PartyInfo.LeaveParty fallback
	w:advance(1)
	r.W.LeaveGroup = nil
	local origCPI = r.env.C_PartyInfo
	local cpiCalled = 0
	r.env.C_PartyInfo = {
		LeaveParty = function()
			cpiCalled = cpiCalled + 1
		end,
	}
	r:clickOn(s.leave)
	eq(cpiCalled, 1, "C_PartyInfo.LeaveParty called when W.LeaveGroup is absent")

	-- 3) Global LeaveParty fallback
	w:advance(1)
	r.env.C_PartyInfo = {}
	local origGlobalLeave = r.env.LeaveParty
	local globalCalled = 0
	r.env.LeaveParty = function()
		globalCalled = globalCalled + 1
	end
	r:clickOn(s.leave)
	eq(globalCalled, 1, "global LeaveParty called when C_PartyInfo.LeaveParty is absent")

	r.env.LeaveParty = origGlobalLeave
	r.env.C_PartyInfo = origCPI
	r.W.LeaveGroup = origWLeave
	r.W.InGroup = origInGroup
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Confirm.lua:129 (cmp ==->~=: stackCard removes wrong block instead of s.pay on overflow)
-- guards Wuber/UI/Rider/Confirm.lua:130 (drop statement: stackCard leaves s.pay in blocks on overflow)
-- guards Wuber/UI/Rider/Confirm.lua:132 (drop statement: stackCard leaves s.pay visible on overflow)
test("mutation b5 ui rider confirm: stackCard hides and removes how-you-pay when confirm sheet overflows", function()
	local w, d, r = setupRiderAndDriver({ screenW = 800, screenH = 600 })
	r.W.db.adv = true
	local origInGroup = r.W.InGroup
	local origDanger = r.W.UI.DangerOf
	local origRC = r.W.Raincheck
	local origFlight = r.W.TravelSaved
	r.W.InGroup = function() return true end
	r.W.UI.DangerOf = function() return 2, 30 end
	-- Raincheck must be nil so s.pay is added to blocks and then removed on overflow
	r.W.Raincheck = nil
	r.W.TravelSaved = function() return 600, "flight", true end
	local drv = r.W.drivers[d.W.myKey]
	if drv then
		drv.dest = "Orgrimmar " .. string.rep("Gate ", 20)
		drv.flight = 50000
		drv.service = "Anita Express Summons One Two Three Four"
		drv.note = "Note 1\nNote 2\nNote 3\nNote 4"
	end
	local s = openConfirm(w, r, d.W.myKey)
	s.wide = false
	r.W.UI.Refresh(true)
	eq(s.pay:IsShown(), false, "s.pay hidden (cardTop=" .. tostring(s.cardTop) .. ", wide=" .. tostring(s.wide) .. ")")
	eq(s.dial:IsShown(), true, "s.dial stays shown (not removed by ~=)")
	-- s.warn must be right after s.pvp (not shifted down by s.pay's height)
	local _, _, _, _, yPvp = s.pvp:GetPoint(1)
	local _, _, _, _, yWarn = s.warn:GetPoint(1)
	ok(yPvp and yWarn and (yPvp - yWarn) < 80, "s.warn is not pushed down by removed s.pay block")

	r.W.InGroup = origInGroup
	r.W.UI.DangerOf = origDanger
	r.W.Raincheck = origRC
	r.W.TravelSaved = origFlight
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Confirm.lua:368 (local value -> nil: Request OnClick ignores requestBlock reason)
-- guards Wuber/UI/Rider/Confirm.lua:382 (drop statement: Request OnClick skips warning toast when blocked)
-- guards Wuber/UI/Rider/Confirm.lua:386 (drop statement: Request OnClick skips UI.SyncSecure when not blocked)
test("mutation b5 ui rider confirm: Request button fallback toasts block reason and syncs secure when unblocked", function()
	local w, d, r = setupRiderAndDriver()
	local s = openConfirm(w, r, d.W.myKey)
	-- Hide secure overlay so clickOn hits s.request's own OnClick handler
	if r.env.WuberRequestButton then r.env.WuberRequestButton:Hide() end
	local toasts = {}
	local origToast = r.W.UI.Toast
	r.W.UI.Toast = function(msg, kind)
		toasts[#toasts + 1] = { msg = msg, kind = kind }
		return origToast(msg, kind)
	end

	-- Blocked case: rider becomes in_group after button was rendered active
	local origInGroup = r.W.InGroup
	r.W.InGroup = function() return true end
	r:clickOn(s.request)
	ok(#toasts >= 1 and toasts[#toasts].kind == "warn", "warning toast shown when blocked")
	ok(toasts[#toasts].msg:find("group", 1, true) ~= nil, "in_group toast message shown: " .. tostring(toasts[#toasts].msg))
	r.W.InGroup = origInGroup

	-- Unblocked fallback case: click s.request directly when SyncSecure hasn't placed overlay
	local syncCalls = 0
	local origSync = r.W.UI.SyncSecure
	r.W.UI.SyncSecure = function()
		syncCalls = syncCalls + 1
		return origSync()
	end
	toasts = {}
	r:clickOn(s.request)
	eq(syncCalls, 1, "UI.SyncSecure called when unblocked fallback is clicked")
	ok(#toasts >= 1 and toasts[#toasts].msg == "One moment - click Request again", "re-click toast shown")

	r.W.UI.SyncSecure = origSync
	r.W.UI.Toast = origToast
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Confirm.lua:377 (swap or->and: in-combat Request failure loses BLOCK_TEXT[no] message)
test("mutation b5 ui rider confirm: in-combat Request failure shows specific BLOCK_TEXT[no] toast", function()
	local w, d, r = setupRiderAndDriver()
	local s = openConfirm(w, r, d.W.myKey)
	if r.env.WuberRequestButton then r.env.WuberRequestButton:Hide() end
	local toasts = {}
	local origToast = r.W.UI.Toast
	r.W.UI.Toast = function(msg, kind)
		toasts[#toasts + 1] = { msg = msg, kind = kind }
		return origToast(msg, kind)
	end
	local origCombat = r.env.InCombatLockdown
	local origReq = r.W.RequestRide
	r.env.InCombatLockdown = function() return true end
	r.W.RequestRide = function() return nil, "paused" end
	r:clickOn(s.request)
	r.env.InCombatLockdown = origCombat
	r.W.RequestRide = origReq
	r.W.UI.Toast = origToast

	ok(#toasts >= 1, "toast emitted on in-combat RequestRide failure")
	ok(toasts[#toasts].msg ~= "Couldn't send the request", "specific BLOCK_TEXT['paused'] used instead of generic fallback")
	ok(toasts[#toasts].msg:find("paused", 1, true) ~= nil, "paused reason text shown: " .. tostring(toasts[#toasts].msg))
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Confirm.lua:391 (return -> nil: Request tooltip returns nil out of combat)
test("mutation b5 ui rider confirm: Request button tooltip describes whisper and pay-after-arrival out of combat", function()
	local w, d, r = setupRiderAndDriver()
	local s = openConfirm(w, r, d.W.myKey)
	local body = hoverBody(r, s.request)
	ok(body:find("Whispers the driver and sends your request.", 1, true) ~= nil, "tooltip body present: " .. tostring(body))
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Confirm.lua:666 (swap and->or: tierChip tooltip breaks pluralization when 1 ride to next tier)
-- guards Wuber/UI/Rider/Confirm.lua:668 (return -> nil: tierChip tooltip returns nil at Gold tier)
test("mutation b5 ui rider confirm: tierChip tooltip formats 1-more-ride and Gold max-tier text", function()
	local w, _, r = setupRiderAndDriver()
	r.W.db.adv = true
	local tc = r.W.UI.TierChip(r.env.UIParent)
	local origTP = r.W.TierProgress
	local origTier = r.W.Tier

	-- 1 ride away from Silver (nextAt=10, rides=9 -> n=1)
	r.W.Tier = function() return 1 end
	r.W.TierProgress = function() return 1, 9, 3, 10 end
	tc:Update()
	local body1 = hoverBody(r, tc)
	ok(body1:find("1 more ride to the next level.", 1, true) ~= nil, "singular '1 more ride' text: " .. tostring(body1))

	-- Gold tier (nextAt=nil)
	r.W.Tier = function() return 3 end
	r.W.TierProgress = function() return 3, 30, 25, nil end
	tc:Update()
	local bodyMax = hoverBody(r, tc)
	ok(bodyMax:find("Drivers see your level.", 1, true) ~= nil, "max-tier tooltip text: " .. tostring(bodyMax))

	r.W.TierProgress = origTP
	r.W.Tier = origTier
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Confirm.lua:1073 (drop statement: aboutCard leaves block in blocks when it does not fit)
test("mutation b5 ui rider confirm: aboutCard removes its block when it does not fit", function()
	local w, d, r = setupRiderAndDriver()
	r.W.db.adv = true
	local drv = r.W.UI.Driver(d.W.myKey)
	local s = openConfirm(w, r, d.W.myKey)
	local ConfMod = r.W.Mod("UI.Rider.Confirm")
	ConfMod.aboutBuild(s.card)
	s.wide = true
	local blocks = {
		{ frame = s.dial, h = 88 },
		{ frame = s.card.row, h = 56 },
		{ frame = s.pvp, h = 64 },
		{ frame = s.rc, h = 44 },
		{ frame = s.warn, h = 90 },
	}
	ConfMod.wideBlocks(s, blocks, drv, 50000, "save", true, false)
	eq(#blocks, 5, "unfit aboutCard block is removed from blocks")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/UI/Rider/Cards.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Rider/Cards.lua:75 (cmp ~=->==: HideDriver initializes W.db.hidden when missing)
test("mutation b5 ui rider cards: HideDriver initializes W.db.hidden table if missing", function()
	local w, d, r = setupRiderAndDriver()
	local origHide = r.W.HideDriver
	r.W.HideDriver = nil
	r.W.db.hidden = nil
	r.W.UI.HideDriver(d.W.myKey, d.W.myName)
	ok(type(r.W.db.hidden) == "table" and r.W.db.hidden[d.W.myKey] == true, "W.db.hidden created and key marked hidden")
	r.W.HideDriver = origHide
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Cards.lua:109 (return -> nil: HeartButton tooltip returns nil when not favourited)
test("mutation b5 ui rider cards: HeartButton tooltip explains favourites when unfavourited", function()
	local w, _, r = setupRiderAndDriver()
	local hb = r.W.UI.HeartButton(r.env.UIParent, 14)
	hb:SetFav(false)
	local body = hoverBody(r, hb)
	ok(body:find("Add to your favourites:", 1, true) ~= nil, "unfavourited heart tooltip shown: " .. tostring(body))
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Cards.lua:166 (drop statement: cardMenu does not match win/UIParent scale)
test("mutation b5 ui rider cards: right-click cardMenu matches window effective scale", function()
	local w, d, r = setupRiderAndDriver()
	r.W.db.adv = true
	r.W.UI.Refresh(true)
	local card = r.W.UI.state.cards and r.W.UI.state.cards[d.W.myKey]
	ok(card ~= nil, "driver card present on home")
	local win = r.W.UI.state.win
	local origWinScale = win.GetEffectiveScale
	win.GetEffectiveScale = function() return 0.75 end
	r:clickOn(card, "RightButton")
	local menu
	for _, ch in ipairs({ r.env.UIParent:GetChildren() }) do
		if ch.fav and ch:IsShown() then
			menu = ch
			break
		end
	end
	ok(menu ~= nil, "cardMenu opened on right click")
	eq(menu:GetScale(), 0.75, "cardMenu scale matches win/UIParent effective scale ratio")
	win.GetEffectiveScale = origWinScale
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Cards.lua:377 (drop statement: heart not anchored to rightFrame when not onLine and not stacked)
-- guards Wuber/UI/Rider/Cards.lua:396 (swap and->or: rchip jumps onto line 1 when first chip wrapped below)
test("mutation b5 ui rider cards: layoutCard anchors heart to rightFrame and keeps rchip below when first chip wraps", function()
	-- 1) First render short (priceOnLine=true, heart anchored to title), then switch to long multi-word (line 377)
	local w, d, r = setupRiderAndDriver({
		screenW = 800,
		screenH = 600,
		price = 100000,
		service = "Short",
		creator = true,
		rank = 1,
	})
	local origRankOf = r.W.RankOf
	r.W.RankOf = function() return 1, "A" end
	r.W.UI.Refresh(true)
	local card = r.W.UI.state.cards and r.W.UI.state.cards[d.W.myKey]
	ok(card ~= nil, "driver card present")
	eq(card.priceOnLine, true, "initially priceOnLine is true")

	-- Switch to long multi-word title so priceOnLine=false, priceStacked=false -> heart must move to rightFrame
	local drv = r.W.drivers[d.W.myKey]
	drv.service = "Anita Express Summons " .. string.rep("Word ", 20)
	drv.price = 100001
	drv.dest = "Gadgetzan"
	w:advance(1)
	r.W.UI.Refresh(true)
	card = r.W.UI.state.cards and r.W.UI.state.cards[d.W.myKey]
	eq(card.priceOnLine, false, "priceOnLine is false (title=" .. tostring(card.titleText) .. ")")
	eq(card.priceStacked, false, "priceStacked is false")
	local p, rel = card.heart:GetPoint(1)
	ok(p ~= nil and rel == card.rightFrame, "card.heart is re-anchored to card.rightFrame")

	-- 2) Adjust service length + chip widths so chip wraps below while rchip would fit on line 1
	ok(card.royal and card.royal.chip and card.rankChip and card.rankChip:IsShown(), "creator chip and rankChip shown")
	card.royal.chip:SetWidth(500)
	card.rankChip:SetWidth(10)
	drv.service = "Hi"
	drv.price = 100002
	w:advance(1)
	r.W.UI.Refresh(true)
	card = r.W.UI.state.cards and r.W.UI.state.cards[d.W.myKey]
	eq(card.priceStacked, false, "priceStacked is false")
	ok(card.belowBox and card.belowBox:IsShown(), "both chip and rchip wrap into belowBox instead of rchip jumping to line 1")
	r.W.RankOf = origRankOf
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Cards.lua:455 (cmp ==->~=: DangerOf ignores string 'level:secs' danger field)
-- guards Wuber/UI/Rider/Cards.lua:457 (swap or->and: DangerOf drops parsed seconds from string danger)
-- guards Wuber/UI/Rider/Cards.lua:461 (return -> nil: DangerOf returns nil instead of level, secs)
test("mutation b5 ui rider cards: DangerOf parses string 'level:secs' and returns level and seconds", function()
	local w, _, r = setupRiderAndDriver()
	local level, secs = r.W.UI.DangerOf({ danger = "2:90" })
	eq(level, 2, "parsed danger level 2")
	eq(secs, 90, "parsed danger seconds 90")
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Cards.lua:543 (drop statement: fillCard leaves c.stateText nil)
-- guards Wuber/UI/Rider/Cards.lua:545 (drop statement: fillCard leaves c.subText nil)
test("mutation b5 ui rider cards: fillCard populates stateText and subText on driver card", function()
	local w, d, r = setupRiderAndDriver({ busy = true, seats = 0 })
	local card = r.W.UI.state.cards and r.W.UI.state.cards[d.W.myKey]
	ok(card ~= nil, "driver card present")
	ok(type(card.stateText) == "string" and card.stateText:find("Group full", 1, true) ~= nil, "stateText populated: " .. tostring(card.stateText))
	ok(type(card.subText) == "string" and card.subText:find("To ", 1, true) == 1, "subText populated: " .. tostring(card.subText))
	T.clean(w)
end)
