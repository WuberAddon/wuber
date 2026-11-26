-- Mutation guard tests for Wuber/UI/Driver/Raid.lua (Batch 4).
-- Each test guards one or more unprotected lines against player-visible promises.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local SPOT = "Undercity"
local NAMES = {
	"Dan Rider", "Gus Hill", "Ivy Moss", "Jo King", "Kim Lane",
	"Lou Park", "Max Reed", "Ned Cole", "Ora Shaw", "Pat Bell",
}

local function setupRaidUI(opts)
	opts = opts or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	local sidePane
	local origSidePane = W.Driver.SidePane
	W.Driver.SidePane = function(holder)
		local p = origSidePane(holder)
		sidePane = p
		return p
	end
	if opts.wide then
		a.wide = true
		W.db.coach = true
		if W.UI.WindowWide then W.UI.WindowWide(true) end
	elseif W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	DR.SetMode("raid")
	w:advance(2)
	DR.Role = function() return "driver" end
	DR.IsOpen = function() return opts.open ~= false end
	DR.RaidOn = function() return opts.raidOn ~= false end
	DR.CanRunRaid = function() return true end
	if opts.queue then
		DR.RaidQueue = function()
			local q = {}
			for i = 1, opts.queue do
				q[i] = { name = NAMES[i] or ("Raider " .. i), asked = a.env.GetTime() - 10 * i, state = "queued", tries = 0 }
			end
			return q
		end
	end
	if opts.notHere then
		DR.NotHere = function() return opts.notHere end
	end
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR, function() return sidePane end
end

-- guards Wuber/UI/Driver/Raid.lua:171 (drop statement: clicking Not here header does not toggle the away list)
test("mutation b4 ui driver raid: clicking Not here header toggles the away list open and closed", function()
	local w, a, W = setupRaidUI({
		queue = 0,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	local R = W.Driver.ui.console.raid
	ok(H.visible(R.nhHead), "Not here header is visible")
	eq(R.nh[1], nil, "Not here list starts closed")
	a:clickOn(R.nhHead)
	w:advance(1)
	ok(R.nh[1] and H.visible(R.nh[1]), "clicking Not here opens the away list")
	a:clickOn(R.nhHead)
	w:advance(1)
	ok(not H.visible(R.nh[1]), "clicking Not here again closes the away list")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:105 (local name = nil: + button loses target name and fails to queue)
-- guards Wuber/UI/Driver/Raid.lua:112 (drop statement: + button queues without confirming toast)
test("mutation b4 ui driver raid: clicking + on a Not here row queues that raider and toasts confirmation", function()
	local w, a, W, DR = setupRaidUI({
		queue = 0,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	local added
	DR.RaidAdd = function(name)
		added = name
		return true
	end
	local toasts = {}
	local origToast = W.UI.Toast
	W.UI.Toast = function(text, kind, ...)
		toasts[#toasts + 1] = { text = tostring(text), kind = kind }
		return origToast(text, kind, ...)
	end
	local R = W.Driver.ui.console.raid
	a:clickOn(R.nhHead)
	w:advance(1)
	ok(R.nh[1] and H.visible(R.nh[1].add), "+ button is visible")
	a:clickOn(R.nh[1].add)
	w:advance(1)
	eq(added, "Fay Storm", "RaidAdd was called with the row's raider name")
	local sawInfo = false
	for _, t in ipairs(toasts) do
		if t.text:find("is in the queue", 1, true) and t.kind == "info" then sawInfo = true end
	end
	ok(sawInfo, "info toast confirms raider is in the queue")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:109 (cmp ==->~=: failed RaidAdd shows success toast instead of warning)
test("mutation b4 ui driver raid: clicking + when RaidAdd rejects shows the warning reason", function()
	local w, a, W, DR = setupRaidUI({
		queue = 0,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	DR.RaidAdd = function() return false, "Already in queue" end
	local toasts = {}
	local origToast = W.UI.Toast
	W.UI.Toast = function(text, kind, ...)
		toasts[#toasts + 1] = { text = tostring(text), kind = kind }
		return origToast(text, kind, ...)
	end
	local R = W.Driver.ui.console.raid
	a:clickOn(R.nhHead)
	w:advance(1)
	a:clickOn(R.nh[1].add)
	w:advance(1)
	local sawWarn, sawInfo = false, false
	for _, t in ipairs(toasts) do
		if t.text:find("Already in queue", 1, true) and t.kind == "warn" then sawWarn = true end
		if t.text:find("is in the queue", 1, true) then sawInfo = true end
	end
	ok(sawWarn, "warning toast shows RaidAdd rejection reason")
	ok(not sawInfo, "does not claim raider was queued")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:110 (swap or->and: failed RaidAdd without reason drops fallback text)
test("mutation b4 ui driver raid: clicking + when RaidAdd rejects without reason falls back to Couldn't add", function()
	local w, a, W, DR = setupRaidUI({
		queue = 0,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	DR.RaidAdd = function() return false end
	local toasts = {}
	local origToast = W.UI.Toast
	W.UI.Toast = function(text, kind, ...)
		toasts[#toasts + 1] = { text = tostring(text), kind = kind }
		return origToast(text, kind, ...)
	end
	local R = W.Driver.ui.console.raid
	a:clickOn(R.nhHead)
	w:advance(1)
	a:clickOn(R.nh[1].add)
	w:advance(1)
	local sawFallback = false
	for _, t in ipairs(toasts) do
		if t.text:find("Couldn't add ", 1, true) and t.kind == "warn" then sawFallback = true end
	end
	ok(sawFallback, "fallback warning toast is shown")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:79 (drop statement: + button is not dimmed when raid summons are stopped)
test("mutation b4 ui driver raid: + button is dimmed while raid summons are stopped and bright when started", function()
	local w, a, W, DR = setupRaidUI({
		queue = 0,
		raidOn = false,
		open = false,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	local R = W.Driver.ui.console.raid
	R.open = true
	W.Driver.RefreshNow()
	w:advance(1)
	ok(R.nh[1] and R.nh[1].add:GetAlpha() < 0.5, "+ button is dimmed before Start")
	DR.RaidOn = function() return true end
	W.Driver.RefreshNow()
	w:advance(1)
	eq(R.nh[1].add:GetAlpha(), 1, "+ button is full alpha once raid summons are active")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:120 (swap and->or: Not here row tooltip breaks zone formatting)
test("mutation b4 ui driver raid: Not here row tooltip names the member's zone", function()
	local w, a, W = setupRaidUI({
		queue = 0,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	local R = W.Driver.ui.console.raid
	a:clickOn(R.nhHead)
	w:advance(1)
	R.nh[1]:GetScript("OnEnter")(R.nh[1])
	ok(#a:findText("(in Orgrimmar)", false, true) > 0, "tooltip shows the member's current zone")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:45 (swap and->or: malformed RaidWarlocks entry crashes RaidSummoners)
test("mutation b4 ui driver raid: RaidSummoners ignores malformed RaidWarlocks entries", function()
	local w, a, W, DR = setupRaidUI({ queue = 0 })
	DR.RaidWarlocks = function()
		return {
			"not-a-table",
			{ name = "Missing Key" },
			{ key = "cal lock", name = "Cal Lock", shards = 6 },
		}
	end
	DR.Summoners = function() return { "cal lock" } end
	local sums = W.Driver.RaidSummoners()
	eq(#sums, 1, "one valid summoner returned")
	eq(sums[1].shards, 6, "valid warlock metadata preserved")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:53 (if cond negated: Summoners list skips valid keys or crashes on nil)
test("mutation b4 ui driver raid: RaidSummoners skips blank entries and returns chosen summoners", function()
	local w, a, W, DR = setupRaidUI({ queue = 0 })
	DR.RaidWarlocks = function() return { { key = "cal lock", name = "Cal Lock", shards = 4 } } end
	DR.Summoners = function() return { "", "cal lock" } end
	local sums = W.Driver.RaidSummoners()
	eq(#sums, 1, "blank entry skipped and valid summoner kept")
	eq(sums[1].key, "cal lock", "chosen summoner key matches")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:66 (swap and->or: malformed NotHere table entry crashes)
test("mutation b4 ui driver raid: Not here ignores malformed table entries without a name", function()
	local w, a, W = setupRaidUI({
		queue = 0,
		notHere = { { class = "MAGE" }, { name = "Fay Storm", zone = "Orgrimmar" } },
	})
	local R = W.Driver.ui.console.raid
	eq(R.nhHead.label.wuberText, "Not here (1)", "only the named member is counted")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:71 (cmp ==->~=: ClassColour stops using RAID_CLASS_COLORS)
test("mutation b4 ui driver raid: ClassColour uses RAID_CLASS_COLORS when present and falls back to white", function()
	local w, a, W = setupRaidUI({ queue = 0 })
	a.env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
	local c = W.Driver.ClassColour("MAGE")
	eq(type(c), "table", "returns RGB table when RAID_CLASS_COLORS is a table")
	eq(c[1], 0.25, "red channel matches class color")
	a.env.RAID_CLASS_COLORS = false
	eq(W.Driver.ClassColour("MAGE"), "white", "falls back to white when RAID_CLASS_COLORS is absent")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:364 (swap and->or: empty summoners with nil turn indexes sums[1].key and errors)
test("mutation b4 ui driver raid: folded raid page handles no summoners and nil turn without error", function()
	local w, a, W, DR = setupRaidUI({ queue = 0 })
	DR.Summoners = function() return {} end
	DR.MayCast = function() return false, nil end
	W.Driver.RefreshNow()
	w:advance(1)
	local R = W.Driver.ui.console.raid
	ok(H.visible(R.none), "Nobody summons yet warning is shown")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:378 (drop statement: Nobody summons yet stays visible when summoners are picked)
-- guards Wuber/UI/Driver/Raid.lua:379 (drop statement: summoner chips are not drawn in folded mode)
test("mutation b4 ui driver raid: picking a summoner hides Nobody summons yet and shows summoner chips", function()
	local w, a, W, DR = setupRaidUI({ queue = 0 })
	DR.Summoners = function() return {} end
	W.Driver.RefreshNow()
	w:advance(1)
	local R = W.Driver.ui.console.raid
	ok(H.visible(R.none), "control: warning shown when no summoners picked")
	DR.RaidWarlocks = function() return { { key = "anita lift", name = "Anita Lift", shards = 5 } } end
	DR.Summoners = function() return { "anita lift" } end
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not H.visible(R.none), "warning hides once a summoner is picked")
	ok(R.chips[1] and H.visible(R.chips[1]), "summoner chip is shown")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:408 (drop statement: +N more text not set when queue > 8)
-- guards Wuber/UI/Driver/Raid.lua:409 (drop statement: +N more label not shown when queue > 8)
-- guards Wuber/UI/Driver/Raid.lua:412 (drop statement: +N more label stays visible when queue shrinks <= 8)
test("mutation b4 ui driver raid: folded queue shows +N more over 8 raiders and hides it at 8 or fewer", function()
	local w, a, W, DR = setupRaidUI({ queue = 10 })
	local v = W.Driver.ui.console
	ok(H.visible(v.more), "+N more label is shown when 10 raiders are waiting")
	eq(v.more.wuberText, "+2 more", "overflow count is +2 more")
	DR.RaidQueue = function()
		return { { name = NAMES[1], asked = a.env.GetTime(), state = "queued", tries = 0 } }
	end
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not H.visible(v.more), "+N more hides when queue drops to 1")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:448 (drop statement: Not here fails to cap at 12 rows in folded mode)
-- guards Wuber/UI/Driver/Raid.lua:469 (drop statement: Not here +N more text not set when > 12 away)
test("mutation b4 ui driver raid: folded Not here caps at 12 rows and shows +N more", function()
	local many = {}
	for i = 1, 14 do many[i] = { name = "Away " .. string.char(64 + i), class = "WARRIOR", zone = "Orgrimmar" } end
	local w, a, W = setupRaidUI({ queue = 0, notHere = many })
	local R = W.Driver.ui.console.raid
	R.open = true
	W.Driver.RefreshNow()
	w:advance(1)
	ok(R.nh[12] and H.visible(R.nh[12]), "12th Not here row is shown")
	eq(R.nh[13], nil, "13th Not here row is not created")
	eq(R.nhMore.wuberText, "+2 more", "remaining away count shown")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:471 (drop statement: stale +N more text remains when away list shrinks)
-- guards Wuber/UI/Driver/Raid.lua:476 (cmp ~=->==: Summoned tonight overlaps +N more when non-empty)
test("mutation b4 ui driver raid: shrinking Not here clears +N more and Summoned tonight sits below +N more", function()
	local many = {}
	for i = 1, 14 do many[i] = { name = "Away " .. string.char(64 + i), class = "WARRIOR", zone = "Orgrimmar" } end
	local w, a, W, DR = setupRaidUI({ queue = 0, notHere = many })
	local R = W.Driver.ui.console.raid
	R.open = true
	W.Driver.RefreshNow()
	w:advance(1)
	ok(R.nhMore:GetTop() - R.tonight:GetTop() >= 18, "Summoned tonight sits below +N more line")
	DR.NotHere = function()
		return { { name = "Away A", class = "WARRIOR", zone = "Orgrimmar" } }
	end
	W.Driver.RefreshNow()
	w:advance(1)
	eq(R.nhMore.wuberText, "", "overflow text cleared when all away rows fit")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:483 (drop statement: Summoned tonight text not updated)
test("mutation b4 ui driver raid: folded raid page displays Summoned tonight count", function()
	local w, a, W = setupRaidUI({ queue = 0 })
	W.Driver.RaidTonight = function() return 7 end
	W.Driver.RefreshNow()
	w:advance(1)
	local R = W.Driver.ui.console.raid
	eq(R.tonight.wuberText, "Summoned tonight: 7", "Summoned tonight shows driver's count")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:287 (swap or->and: mouse wheel on scroll cue fails when scroll target is nil)
test("mutation b4 ui driver raid: mouse wheel over the more-below cue scrolls the list", function()
	local w, a, W = setupRaidUI({ queue = 6 })
	local v = W.Driver.ui.console
	local R = v.raid
	ok(R.cue and H.visible(R.cue), "scroll cue is visible")
	v.scroll.target = nil
	R.cue:GetScript("OnMouseWheel")(R.cue, -1)
	ok((v.scroll.target or 0) > 0, "scrolling wheel down over cue advances scroll target")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:293 (cmp >-><=: cueHolder OnUpdate stops throttling by CUE.EVERY)
test("mutation b4 ui driver raid: cueHolder OnUpdate throttles updates until CUE.EVERY elapses", function()
	local w, a, W = setupRaidUI({ queue = 6 })
	local R = W.Driver.ui.console.raid
	ok(R.cue and H.visible(R.cue), "cue is initially visible")
	R.cue:Hide()
	R.cueHolder.wait = 0.2
	R.cueHolder:GetScript("OnUpdate")(R.cueHolder, 0.05)
	ok(not H.visible(R.cue), "cue stays hidden before CUE.EVERY elapses")
	R.cueHolder:GetScript("OnUpdate")(R.cueHolder, 0.2)
	ok(H.visible(R.cue), "cue updates once CUE.EVERY elapses")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:330 (drop statement: faded row keeps alpha 0 after switching to wide mode)
-- guards Wuber/UI/Driver/Raid.lua:331 (drop statement: faded row stays unclickable after switching to wide mode)
test("mutation b4 ui driver raid: switching from folded to wide restores row alpha and mouse", function()
	local w, a, W = setupRaidUI({ queue = 6 })
	local v = W.Driver.ui.console
	local fadedIdx
	for i = 1, 6 do
		if v.rows[i]:GetAlpha() == 0 and not v.rows[i]:IsMouseEnabled() then
			fadedIdx = i
			break
		end
	end
	ok(fadedIdx ~= nil, "control: at least one row is faded under the cue")
	W.UI.WindowWide(true)
	W.Driver.RefreshNow()
	w:advance(1)
	eq(v.rows[fadedIdx]:GetAlpha(), 1, "row alpha restored in wide mode")
	ok(v.rows[fadedIdx]:IsMouseEnabled(), "row mouse restored in wide mode")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:498 (if cond negated: hideRaid skips restoring row alpha/mouse)
-- guards Wuber/UI/Driver/Raid.lua:499 (drop statement: hideRaid leaves faded row at alpha 0)
-- guards Wuber/UI/Driver/Raid.lua:500 (drop statement: hideRaid leaves faded row unclickable)
-- guards Wuber/UI/Driver/Raid.lua:650 (drop statement: Mod.hideRaid not exported)
test("mutation b4 ui driver raid: leaving raid mode hides raid widgets and restores row alpha and mouse", function()
	local w, a, W, DR = setupRaidUI({ queue = 6 })
	local v = W.Driver.ui.console
	local R = v.raid
	local fadedIdx
	for i = 1, 6 do
		if v.rows[i]:GetAlpha() == 0 and not v.rows[i]:IsMouseEnabled() then
			fadedIdx = i
			break
		end
	end
	ok(fadedIdx ~= nil, "control: at least one row is faded under the cue")
	DR.SetMode("solo")
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not H.visible(R.sumHead), "raid summoners header hidden after leaving raid mode")
	eq(v.rows[fadedIdx]:GetAlpha(), 1, "row alpha restored after leaving raid mode")
	ok(v.rows[fadedIdx]:IsMouseEnabled(), "row mouse restored after leaving raid mode")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:567 (drop statement: extra wide-mode raider rows stay visible when queue shrinks)
-- guards Wuber/UI/Driver/Raid.lua:568 (drop statement: extra wide-mode raider rows keep stale .c data)
test("mutation b4 ui driver raid: wide mode hides extra raider rows and clears stale data when queue shrinks", function()
	local w, a, W, DR, getSide = setupRaidUI({ queue = 3, wide = true })
	local p = getSide()
	ok(p and p.rows[3] and H.visible(p.rows[3]), "3rd side-pane row shown for 3 raiders")
	ok(p.rows[3].c ~= nil, "3rd row holds raider data")
	DR.RaidQueue = function()
		return { { name = NAMES[1], asked = a.env.GetTime(), state = "queued", tries = 0 } }
	end
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not H.visible(p.rows[3]), "3rd row hides when queue shrinks to 1")
	eq(p.rows[3].c, nil, "3rd row clears stale .c reference")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:588 (if cond negated: wide mode omits nobodyAway text when nobody is away)
-- guards Wuber/UI/Driver/Raid.lua:597 (cmp <=->: wide mode skips Not here rows)
-- guards Wuber/UI/Driver/Raid.lua:610 (drop statement: wide mode Not here row stays hidden when someone goes away again)
-- guards Wuber/UI/Driver/Raid.lua:613 (drop statement: wide mode Not here row stays visible after arrival)
test("mutation b4 ui driver raid: wide mode shows away members, updates nobodyAway on arrival, and re-shows rows", function()
	local w, a, W, DR, getSide = setupRaidUI({
		queue = 0,
		wide = true,
		notHere = { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } },
	})
	local p = getSide()
	ok(not H.visible(p.nhNone), "nobodyAway text hidden while someone is away")
	ok(p.nh[1] and H.visible(p.nh[1]), "away member row shown in side pane")
	ok(p.nhHead:GetTop() - p.nh[1]:GetTop() < 30, "away row sits directly under Not here header without empty-state gap")
	DR.NotHere = function() return {} end
	W.Driver.RefreshNow()
	w:advance(1)
	ok(H.visible(p.nhNone), "nobodyAway text shown once everyone is here")
	ok((p.nhNone.wuberText or "") ~= "", "nobodyAway text is populated")
	ok(not H.visible(p.nh[1]), "stale away row hidden once everyone is here")
	DR.NotHere = function()
		return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } }
	end
	W.Driver.RefreshNow()
	w:advance(1)
	ok(H.visible(p.nh[1]), "away row re-shown when someone is away again")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:627 (cmp ==->~=: wide mode side pane inverts Nobody summons yet visibility)
-- guards Wuber/UI/Driver/Raid.lua:634 (drop statement: wide mode side pane skips drawing summoner chips)
test("mutation b4 ui driver raid: wide mode side pane shows Nobody summons yet until a summoner is picked", function()
	local w, a, W, DR, getSide = setupRaidUI({ queue = 0, wide = true })
	DR.Summoners = function() return {} end
	W.Driver.RefreshNow()
	w:advance(1)
	local p = getSide()
	ok(H.visible(p.none), "Nobody summons yet shown in side pane when no summoners picked")
	DR.RaidWarlocks = function() return { { key = "anita lift", name = "Anita Lift", shards = 4 } } end
	DR.Summoners = function() return { "anita lift" } end
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not H.visible(p.none), "Nobody summons yet hides once a summoner is picked")
	ok(p.chips[1] and H.visible(p.chips[1]), "summoner chip shown in side pane")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Raid.lua:606 (drop statement: wide mode Not here row ignores class color)
test("mutation b4 ui driver raid: wide mode Not here row colors the member name by class", function()
	local w, a, W, _, getSide = setupRaidUI({ queue = 0, wide = true })
	a.env.RAID_CLASS_COLORS = { PRIEST = { r = 0.9, g = 0.2, b = 0.3 } }
	W.Drive.NotHere = function()
		return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } }
	end
	W.Driver.RefreshNow()
	w:advance(1)
	local p = getSide()
	local r, g, b = p.nh[1].name:GetTextColor()
	eq(r, 0.9, "name red channel matches class color")
	eq(g, 0.2, "name green channel matches class color")
	eq(b, 0.3, "name blue channel matches class color")
	T.clean(w)
end)
