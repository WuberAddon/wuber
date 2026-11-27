-- Module: Drive.Plan
-- Purpose: What the big button's next click does: DR.Plan and its steps.
-- API: DR.Plan
-- Internals: hook
-- Uses: Drive.Cast
-- Later: Drive.AutoLines (DR.LineTakes at run time: a greeting that goes by itself is not offered by the click)
-- Events: (none)
-- Standalone: no
-- Test: tests/drive/plan_test.lua
-- From: Drive_Button.lua 526-1018 (Wuber 2.2.1)
--
local ADDON, W = ...
local Mod = W.Module("Drive.Plan", { "Drive.Cast" })
local CastMod = W.Mod("Drive.Cast")
local CALL_AGAIN, SAY, VERB, call = CastMod.CALL_AGAIN, CastMod.SAY, CastMod.VERB, CastMod.call
local calls, due, isLeader, mode = CastMod.calls, CastMod.due, CastMod.isLeader, CastMod.mode
local money, myStation, now, opts = CastMod.money, CastMod.myStation, CastMod.now, CastMod.opts
local raidTold, ritualName, settled, short = CastMod.raidTold, CastMod.ritualName, CastMod.settled, CastMod.short
local sorted, str1, units, watching = CastMod.sorted, CastMod.str1, CastMod.units, CastMod.watching
local DR = W.Drive

local plain = W.Plain

---------------------------------------------------------------------------
-- What the next click does
---------------------------------------------------------------------------

local function macroLength(lines)
	local n = 0
	for i = 1, #lines do n = n + #lines[i] end
	return n + math.max(0, #lines - 1)
end

local function count(s) return tonumber(call("Count", s)) or 0 end

local function idlePlan(plan)
	local waiting, arrived, invited, queued, joined
	for _, c in ipairs(sorted()) do
		if c.state == "joined" and units()[c.key] and not (plan.station and c.station and c.station ~= plan.station) then joined = joined or c end
		if c.state == "waiting" then waiting = waiting or c
		elseif c.state == "arrived" and not c.walked and due(c) > 0 then arrived = arrived or c
		elseif c.state == "invited" then invited = invited or c
		elseif c.state == "queued" then queued = queued or c end
	end
	local paused = call("IsPaused") == true
	-- (2.4) a rider DR.NextSummon passed over because the game says they have a summon waiting already (DR.SummonHeld)
	local held = call("SummonHeld", plan.station)
	if waiting then
		plan.color = "wait"
		plan.title = "Summon sent to " .. short(waiting.name)
		plan.sub = "waiting for them to accept it"
	elseif type(held) == "table" then
		plan.color = "wait"
		plan.title = short(held.name) .. " has a summon waiting"
		plan.sub = "no second summon while it is up: it would waste a Soul Shard"
	elseif arrived then
		plan.color = "wait"
		plan.title = "Waiting for " .. short(arrived.name) .. "'s " .. money(due(arrived))
		plan.sub = "they open a trade with any of you and type the gold"
	elseif invited then
		plan.title = "Invited " .. short(invited.name)
		plan.sub = "waiting for them to join the group"
	elseif queued and paused then
		plan.color = "wait"
		plan.title = "Paused - " .. count("queued") .. " waiting"
		plan.sub = "nobody new is invited: tap Resume"
	elseif queued then
		plan.title = short(queued.name) .. " is in the queue"
		-- (r30 HUNT-12) "Invite riders who whisper me" off: nothing invites them by itself, a click on the name does
		local byHand = call("ClickInvites", queued) == true
		plan.sub = (byHand and "click a name in the list to invite")
			or (isLeader() and "the invite goes out as soon as there is room" or "the group leader invites")
	elseif paused then
		plan.color = "wait"
		plan.title = "Paused"
		plan.sub = "nobody new is invited: tap Resume"
	elseif joined then
		-- (run 1 item 8) a rider is in the group but DR.NextSummon passed over them: say why, not "waiting for riders"
		local u = units()[joined.key]
		plan.color = "wait"
		plan.title = short(joined.name) .. " is in the group"
		if call("Online", u) == false then plan.sub = "they are offline"
		elseif call("Here", u) then plan.sub = "they are already here - no summon needed"
		elseif call("PlaceStale", joined) == true then plan.sub = "they asked for another place"
		else plan.sub = "no summon to send right now" end
	else
		local stray = DR.StrayIgnored and DR.StrayIgnored()
		if stray then
			plan.color = "wait"
			plan.title = short(stray.name) .. " is in the group"
			plan.sub = "taken off the list: right-click their portrait to remove them"
			return plan
		end
		local dest = call("Dest") or ""
		plan.title = "Open - waiting for riders"
		plan.sub = money(tonumber(W.Char().price) or W.MIN_PRICE) .. " to " .. tostring(dest) .. " - whisper word: " .. (DR.Keyword and DR.Keyword() or "summon")
	end
	return plan
end

-- (run 1 item 6) A rider taken off the list ("Take off the list" keeps DR.ignored[key]) who is still in the group
-- has no customer row, so the kick loop never saw them. A stub per key keeps kickedAt/kicks between plans.
local strays = {}
function DR.StrayIgnored(needKick)
	local t = now()
	for key in pairs(DR.ignored or {}) do
		local u = units()[key]
		if u then
			local name = W.UnitName and W.UnitName(u)
			if name and not (DR.customers and DR.customers[key]) and not (DR.NeverRider and DR.NeverRider(key)) then
				local s = strays[key] or { key = key }
				strays[key] = s
				s.name = name
				if not needKick or ((s.kicks or 0) < 3 and t - (s.kickedAt or -100) >= 8) then return s end
			end
		end
	end
	return nil
end

local function whisper(c, kind)
	local text = DR.Text and DR.Text(kind, c) or ""
	return "/w " .. W.Tell(c.name) .. " " .. text
end

-- The trade step: returns true when the plan is complete (accept, or waiting on them).
local function tradeStep(plan)
	local t = DR.trade
	local tc = t and t.key and DR.customers and DR.customers[t.key]
	if not tc then return false end
	local who = short(tc.name)
	if t.ready and t.mine ~= 1 then
		plan.color = "go"
		plan.title = "Accept " .. money(t.money) .. " from " .. who
		plan.say = "accepts the trade: " .. money(t.money) .. " from " .. tc.name
		local tb = TradeFrameTradeButton
		-- the game refused the forwarded click once (cap "trade"): the player clicks Trade
		-- in the trade window, until "Retry blocked actions"
		if tb and not W.IsBlocked("trade") then
			plan.type, plan.clickbutton = "click", tb
			plan.sub = "click: accepts the trade"
		else
			plan.sub = "click Trade in the trade window"
		end
		return true
	elseif t.ready then
		plan.color = "wait"
		plan.title, plan.sub = "Waiting for " .. who .. " to accept", money(t.money) .. " is in the trade window"
		return true
	elseif t.giving then
		plan.tradeTitle, plan.tradeSub = who .. " is trading", "you put something in - accept by hand"
	elseif (t.money or 0) > 0 then
		plan.tradeTitle, plan.tradeSub = who .. " offers " .. money(t.money), money(t.due) .. " is due - accept by hand if that is fine"
	else
		plan.tradeTitle, plan.tradeSub = who .. " is trading", "waiting for " .. money(t.due)
	end
	return false
end

-- The two lines of a summon: "/target ..." and "/cast Ritual of Summoning". the test addon's test
-- mode (never shipped) may stand in for the cast (DR.SimHooks, nil in Wuber): castLine gives
-- another line ("/stopmacro"), or cast set = no cast line at all and the hook is called after
-- the click. /target always stays.
local function hook(name, ...)
	local h = DR.SimHooks
	local fn = type(h) == "table" and h[name]
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then
		W.Error("drive sim " .. name, v)
		return nil
	end
	return v
end

local function summonLines(targetLine, name)
	local lines = { targetLine }
	local h = DR.SimHooks
	if type(h) == "table" and type(h.cast) == "function" then return lines, true, true end
	local line = "/cast " .. ritualName()
	local l = hook("castLine", line, name)
	local faked = type(l) == "string" and l ~= line
	if type(l) == "string" then line = l end
	if line ~= "" then lines[2] = line end
	return lines, false, faked -- (faked: no real cast in these lines)
end

-- Is the greeting still this click's to send? Not once it went, and not for a rider whose greeting goes by itself
-- when their summon starts (Drive.AutoLines, its switch on): that click goes straight to the cast.
local function owesGreet(c)
	return not c.greeted and call("LineTakes", "greet", c) ~= true
end

-- The cast step (Warlocks only): adds greet + target + cast, or the greeting alone.
local function castStep(plan, add, whisperOf, mode)
	local o = opts()
	local marks, doing, says = plan.marks, plan.doing, plan.says
	local up = (not plan.busyName) and DR.NextSummon(plan.station) or nil
	plan.up = up
	if not up then return end
	if not W.IsWarlock() then
		-- any class runs the service (2.1): a chosen Warlock casts, this button never does
		local nc = str1(call("NextCaster", up.name))
		if not nc then
			local _, turn = call("MayCast")
			nc = str1(turn)
		end
		plan.turn = nc
		return
	end
	-- (for this rider: the test addon's test mode stands in only for riders who run it too)
	local shards = call("Shards", up.name)
	plan.shards = shards
	plan.dry = o.needShards ~= false and shards == 0
	local mayCast, turn = call("MayCast")
	if mayCast == nil and type(DR.MayCast) ~= "function" then mayCast = true end
	plan.mayCast, plan.turn = mayCast, turn
	if plan.dry or not mayCast then return end
	local unit = units()[up.key]
	if not unit then return end
	local cast, sim = summonLines("/target [@" .. unit .. "]", up.name)
	local summon, greets
	if mode == "macro" and owesGreet(up) then
		local greet = whisperOf(up, "greet")
		local all = { greet }
		for i = 1, #cast do all[#all + 1] = cast[i] end
		if add(all) then
			summon, greets = up, true
		elseif plan.lines == 0 and add({ greet }) then
			-- too long for one macro: the greeting now, the cast on the next click
			marks[#marks + 1] = { kind = "greet", c = up }
			doing[#doing + 1] = "Greet " .. short(up.name)
			says[#says + 1] = "whispers " .. short(up.name) .. " the greeting (the summon is the next click)"
		end
		-- otherwise this click is full: the summon, with its greeting, is the next one
	elseif add(cast) then
		summon = up
		if mode == "box" and owesGreet(up) and not plan.box then plan.box = { c = up, kind = "greet" } end
	end
	if summon then
		if greets then marks[#marks + 1] = { kind = "greet", c = up } end
		marks[#marks + 1] = { kind = "cast", c = up, sim = sim or nil }
		plan.summon, plan.greets = summon, greets
		says[#says + 1] = (greets and "whispers " .. short(up.name) .. " the greeting, " or "") .. "targets " .. short(up.name) .. " and casts the summon" -- (round 13, I8: the spell's name only in the /cast line)
	end
end

local function groupSlash()
	local r = call("InRaid")
	if r == nil and type(IsInRaid) == "function" then
		local ok, v = pcall(IsInRaid)
		r = ok and plain(v) == true
	end
	return r and "/ra " or "/p "
end

-- The summoner call (2.1): a crew Warlock without Wuber is asked in party/raid chat
-- ("Bea: please summon Dan"), with the rider's greeting when it is still owed. Only the
-- runner's window calls; a summoner is asked again after CALL_AGAIN when nothing happened.
local function addCall(plan, add, whisperOf, chatMode, c, key)
	local line = groupSlash() .. DR.Text("callsum", { name = c.name, summoner = key })
	local greets = chatMode == "macro" and owesGreet(c) and c.state ~= "raid"
	local ok = greets and add({ whisperOf(c, "greet"), line })
	if not ok then
		greets = false
		ok = add({ line })
	end
	if not ok then return false end
	local who, marks = DR.ShortOf and DR.ShortOf(key) or key, plan.marks
	if greets then marks[#marks + 1] = { kind = "greet", c = c } end
	marks[#marks + 1] = { kind = "callsum", c = c, summoner = key }
	plan.doing[#plan.doing + 1] = "Ask " .. who .. " to summon " .. short(c.name)
	plan.says[#plan.says + 1] = (greets and ("whispers " .. short(c.name) .. " the greeting, ") or "") .. "asks " .. who
		.. " in " .. (line:sub(1, 3) == "/ra" and "raid" or "party") .. " chat to summon " .. short(c.name)
	plan.called = plan.called or c
	-- (r33 AUD-101) whispers by chat box: the greeting this call line left out goes into the chat box
	if chatMode == "box" and owesGreet(c) and c.state ~= "raid" and not plan.box then
		plan.box = { c = c, kind = "greet" }
		plan.doing[#plan.doing + 1] = (VERB.greet or "Tell") .. " " .. short(c.name) .. " (chat box)"
		plan.says[#plan.says + 1] = "puts " .. (SAY.greet or "greet") .. " for " .. short(c.name) .. " into the chat box"
	end
	return true
end

local function summonerBusy(key, t)
	for _, c in pairs(DR.customers or {}) do
		if type(c) == "table" and c.caster == key and c.state == "summoning" then return true end
	end
	if watching[key] then return true end
	local cl = calls[key]
	return cl ~= nil and t - cl.at < CALL_AGAIN
end

local function callStep(plan, add, whisperOf, chatMode)
	if not (DR.RunnerWindow and DR.RunnerWindow()) or plan.busyName then return end
	local t, asked = now(), {}
	for _, c in ipairs(sorted()) do
		local unit = c.state == "joined" and units()[c.key]
		-- (AUD-91) the same guards as DR.NextSummon: an offline rider, one already here or a place we left takes no call slot
		local key = unit and call("Online", unit) ~= false and not call("Here", unit) and call("PlaceStale", c) ~= true
			and call("SummonPending", c) ~= true -- (2.4) nobody is asked to summon a rider who has a summon waiting
			and str1(call("NextCaster", c.name))
		if key and not asked[key] and DR.IsPlainSummoner(key) and not summonerBusy(key, t)
			and t - (c.calledAt or -100) >= CALL_AGAIN and addCall(plan, add, whisperOf, chatMode, c, key) then
			asked[key] = true
		end
	end
end

-- Raid summons (2.1): this Warlock summons the raider it takes (target by name, the raid's
-- click line and the raider's whisper when they fit); the runner calls summoners without
-- Wuber. No price, no trade, no whispers but raidsum.
local function raidPlan(plan, add, whisperOf)
	local o, t = opts(), now()
	local marks, doing, says = plan.marks, plan.doing, plan.says
	local assign, rows = DR.RaidAssign()
	plan.raid, plan.queued = true, 0
	for _, r in ipairs(rows) do
		if type(r) == "table" and not settled(r.state) then plan.queued = plan.queued + 1 end
		-- a raider with the summon window is still on the console's rows
		if type(r) == "table" and r.state == "waiting" and not plan.accepting then plan.accepting = r end
	end
	if call("IsPaused") == true then return end
	-- the whisper owed to a raider I am summoning (it did not fit beside the cast)
	for _, r in ipairs(rows) do
		local k = type(r) == "table" and r.name and W.Key(r.name)
		if k and o.raidsum ~= false and r.claimedBy == W.myKey and r.state == "summoning" and t - (raidTold[k] or -100) > 60 then
			local who = { name = r.name, key = k, caster = W.myKey }
			if add({ "/w " .. W.Tell(r.name) .. " " .. DR.Text("raidsum", who) }) then
				marks[#marks + 1] = { kind = "raidsum", c = who }
				doing[#doing + 1] = "Tell " .. short(r.name)
				says[#says + 1] = "whispers " .. short(r.name) .. " that the summon is coming"
			end
		end
	end
	for _, a in ipairs(assign) do
		local row = a.row
		-- (the test addon's test mode: a raider who doesn't run it needs a real cast, so real shards)
		local dry = DR.SimHooks and a.key == W.myKey and o.needShards ~= false and call("Shards", row.name) == 0
		if dry then plan.simDry = row end
		-- (2.4) the game says this raider has a summon waiting already (DR.SummonPending): no cast and no call for
		-- them. The assignment stays as every window works it out, so no other summoner takes them either.
		local held = call("SummonPending", row) == true
		if held and a.key == W.myKey and not dry then
			dry = true
			plan.held = row
		end
		-- (review 2.2 #8) with other summoners planning too, a raider just planned for me waits
		-- 0.3 s x my place among the free summoners before the cast goes on the button: a window
		-- that still sees an older state (an END on its way) hears it and moves on, so two
		-- clicks at once (keys sent to every window) never cast at the same raider
		if a.key == W.myKey and not dry and #assign >= 2 then
			local mine = DR.raidMine or {}
			DR.raidMine = mine
			local rk = W.Key(row.name)
			if mine.key ~= rk then mine.key, mine.at = rk, t end
			local hold = 0.3 * (tonumber(a.index) or 1)
			if t - mine.at < hold then
				dry = true
				plan.raidHold = row
				if not mine.timer then
					mine.timer = true
					W.After(hold + 0.05, function() mine.timer = nil call("Changed") end)
				end
			end
		end
		if a.key == W.myKey and W.IsWarlock() and not DR.cast and not dry then
			local k = W.Key(row.name)
			local cast, sim, faked = summonLines("/target " .. row.name, row.name)
			local sum = o.raidsum ~= false and ("/w " .. W.Tell(row.name) .. " " .. DR.Text("raidsum", { name = row.name, caster = W.myKey })) or nil
			local click = o.raidclick ~= false and (groupSlash() .. DR.Text("raidclick", { name = row.name })) or nil
			-- a pretend cast: no raid line unless everyone in the group runs the test mode too
			if faked and hook("groupChat") ~= true then click = nil end
			local function with(...)
				local l = {}
				for _, x in ipairs({ ... }) do if x then l[#l + 1] = x end end
				for i = 1, #cast do l[#l + 1] = cast[i] end
				return l
			end
			local told = sum and add(with(sum, click))
			local clicked = told and click ~= nil
			if not told then clicked = click ~= nil and add(with(click)) end
			if told or clicked or add(cast) then
				if told then marks[#marks + 1] = { kind = "raidsum", c = { name = row.name, key = k, caster = W.myKey } } end
				marks[#marks + 1] = { kind = "cast", c = row, sim = sim or nil }
				plan.summon, plan.clickLine = row, clicked
				says[#says + 1] = (told and ("whispers " .. short(row.name) .. " the summon is coming, ") or "")
					.. (clicked and "asks the raid to click, " or "") .. "targets " .. short(row.name) .. " and casts the summon"
			end
		elseif a.key ~= W.myKey and not held and DR.IsPlainSummoner(a.key) and DR.RunnerWindow() and not summonerBusy(a.key, t) then
			addCall(plan, add, whisperOf, "raid", row, a.key)
		end
	end
	plan.shards = W.IsWarlock() and call("Shards") or nil
end

-- The raid button's words.
local function raidTitle(plan)
	local also = #plan.doing > 0 and table.concat(plan.doing, ", ") or nil
	local busyName, busyCaster = DR.RitualBusy()
	local n = plan.queued or 0
	if plan.summon then
		plan.color = "go"
		plan.title = "Summon " .. short(plan.summon.name)
		plan.sub = "click: " .. (plan.clickLine and "calls the clickers, " or "") .. "targets and casts"
			.. (also and ("; " .. also) or "") .. (plan.shards and ("  -  " .. plan.shards .. " shards") or "")
	elseif also then
		plan.color, plan.title, plan.sub = "go", also, "click"
	elseif plan.raidHold then
		plan.color, plan.title, plan.sub = "wait", "Summon " .. short(plan.raidHold.name), "a moment - making sure no other summoner takes them"
	elseif DR.cast then
		plan.color = "wait"
		plan.title = "Summoning " .. short(DR.cast.name or "?")
		plan.sub = "the raid clicks the portal"
	elseif busyName and busyCaster ~= W.myKey then
		plan.color = "alert"
		plan.title = "CLICK THE PORTAL"
		plan.sub = "right-click the portal (" .. tostring((DR.ShortOf and DR.ShortOf(busyCaster)) or "a Warlock") .. " summons " .. short(busyName) .. ")"
	elseif call("IsPaused") == true then
		plan.color, plan.title, plan.sub = "wait", "Paused - " .. n .. " waiting", "nobody is summoned: tap Resume"
	elseif W.IsWarlock() and opts().needShards ~= false and (call("Shards") == 0 or plan.simDry) then
		plan.color, plan.title, plan.sub = "wait", "No Soul Shards on this Warlock", "the other summoners take the raiders"
		if plan.simDry then plan.sub = short(plan.simDry.name) .. " isn't in test mode: a real summon needs Soul Shards" end
	elseif plan.held then
		-- (2.4) the raider this Warlock would summon has a summon waiting already
		plan.color = "wait"
		plan.title = short(plan.held.name or "?") .. " has a summon waiting"
		plan.sub = "no second summon while it is up: it would waste a Soul Shard"
	elseif n > 0 then
		plan.color = "wait"
		plan.title = n .. (n == 1 and " raider wants" or " raiders want") .. " a summon"
		plan.sub = "your summoners take them in turn"
	elseif plan.accepting then
		-- never "nobody waiting" while their row says "has the summon window"
		plan.color = "wait"
		plan.title = "Summon sent to " .. short(plan.accepting.name or "?")
		plan.sub = "waiting for them to accept it"
	else
		plan.title = "Raid summons - nobody waiting"
		plan.sub = "raiders say 123 in raid chat to ask"
	end
end

-- The lead handover (A's DR.LeadFix: { name, short, title, run }): a step of its own.
local function leadStep(plan)
	if call("Mode") == "raid" then return false end -- (review 2.2 #6: raid summons need no invites)
	local fix = call("LeadFix")
	if type(fix) ~= "table" or type(fix.run) ~= "function" then return false end
	local who = fix.short or short(fix.name or "?")
	plan.lead = fix
	plan.color = "go"
	plan.title = fix.title or ("Give lead to " .. who)
	plan.sub = "click: makes " .. who .. " the group leader, so riders get their invites"
	plan.say = "makes " .. who .. " the group leader (only the leader can invite riders)"
	return true
end

-- The words on the button once the steps are chosen.
local function title(plan)
	local also = #plan.doing > 0 and table.concat(plan.doing, ", ") or nil
	local busyName, busyCaster = plan.busyName, plan.busyCaster
	if busyName then
		if busyCaster == W.myKey then
			plan.color = "wait"
			plan.title = "Summoning " .. short(busyName)
			plan.sub = "your crew clicks the portal"
		else
			plan.color = "alert"
			plan.title = "CLICK THE PORTAL"
			local p = busyCaster and DR.peers and DR.peers[busyCaster]
			local who = (p and p.name and short(p.name)) or (busyCaster and call("WhoIs", busyCaster)) or "your crew"
			plan.sub = "right-click the portal (" .. tostring(who) .. " is casting)"
		end
		if also then plan.sub = plan.sub .. " · also " .. also end
	elseif plan.summon then
		plan.color = "go"
		plan.title = "Summon " .. short(plan.summon.name)
		plan.sub = "click: " .. (plan.greets and "tells the price, " or "") .. "targets and casts"
			.. ((plan.box and plan.box.kind == "greet") and ", then Enter sends the price" or "")
			.. (also and ("; " .. also) or "") .. (plan.shards and ("  -  " .. plan.shards .. " shards") or "")
	elseif also then
		plan.color = "go"
		plan.title = also
		plan.sub = plan.box and "click, then press Enter to send it" or "click"
	elseif plan.tradeTitle then
		plan.color, plan.title, plan.sub = "wait", plan.tradeTitle, plan.tradeSub
	elseif plan.up and W.IsWarlock() and not plan.mayCast then
		plan.color = "wait"
		plan.title = tostring(call("WhoIs", plan.turn) or "Your crew") .. " summons " .. short(plan.up.name)
		plan.sub = "click the portal here when it opens"
	elseif plan.up and plan.dry then
		plan.color = "wait"
		plan.title = "No Soul Shards on this Warlock"
		plan.sub = "summon " .. short(plan.up.name) .. " from another window"
		if DR.SimHooks then plan.sub = short(plan.up.name) .. " isn't in test mode: a real summon needs Soul Shards" end
	elseif plan.up and not W.IsWarlock() then
		plan.color = "wait"
		local who = plan.turn and DR.ShortOf and DR.ShortOf(plan.turn)
		plan.title = (who or "Your Warlock") .. " summons " .. short(plan.up.name)
		plan.sub = (now() - (plan.up.calledAt or -100) < CALL_AGAIN) and "asked in chat - click the portal when it opens"
			or "click the portal when it opens"
	else
		idlePlan(plan)
	end
end

-- { type, macrotext | clickbutton, marks, box, title, sub, color, say, here, below }
-- (here, round 9: the words under the title while the button sits in Wuber's Drive tab, when they
-- differ from sub, which is for the button floating on screen; below: floating with its
-- console under it, when that differs from sub, which is then for the button alone)
function DR.Plan()
	local plan = { marks = {}, color = "idle", title = "", sub = "", doing = {}, says = {}, lines = 0 }
	if call("Lock") ~= nil then
		plan.color, plan.title = "off", "Closed"
		plan.sub = (W.Provider and W.Provider() or "another addon") .. " is driving"
		return plan
	end
	local raid = mode() == "raid"
	if not call("IsOpen") then
		plan.color, plan.title = "off", raid and "Raid summons stopped" or "Closed"
		plan.sub = raid and "tap Start in Wuber's Drive tab" or "tap Open in Wuber's Drive tab"
		plan.here = raid and "Tap Start below to begin raid summons" or "Tap Open below to start taking riders"
		-- floating with its console right under it: the pill is below
		plan.below = raid and "tap Start below" or "tap Open below"
		return plan
	end

	-- 1. a rider's trade is open: with the right amount in it the click accepts it and does
	-- nothing else; otherwise the trade is only mentioned and the button goes on (raids are free)
	if not raid and tradeStep(plan) then return plan end

	-- 1b. this window leads the group but can't invite (a helper): the click hands the lead to
	-- a crew Warlock. PromoteToLeader runs only from this click (2.2, review #29), never a timer.
	if leadStep(plan) then return plan end

	local chat = DR.ChatMode and DR.ChatMode() or "macro"
	local lines, marks, doing, says = {}, plan.marks, plan.doing, plan.says
	local function add(more)
		local all = {}
		for i = 1, #lines do all[i] = lines[i] end
		for i = 1, #more do all[#all + 1] = more[i] end
		if macroLength(all) > DR.MACRO_MAX then return false end
		lines = all
		plan.lines = #lines
		return true
	end

	if raid then
		raidPlan(plan, add, whisper)
		if #lines > 0 then plan.type, plan.macrotext = "macro", table.concat(lines, "\n") end
		raidTitle(plan)
		if #says > 0 then plan.say = table.concat(says, "; ") end
		return plan
	end

	-- 1c. oops: undo a wrong automatic invite (sorry whisper + /uninvite), before any other step
	for _, c in ipairs(sorted()) do
		if c.oops then
			local uline = "/uninvite " .. c.name
			local added
			if chat == "macro" then
				local wline = whisper(c, "oops")
				added = add({ wline, uline })
				if not added then
					added = add({ wline:sub(1, math.max(1, DR.MACRO_MAX - #uline - 1)), uline })
				end
			elseif chat == "box" then
				added = add({ uline })
				if added then plan.box = { c = c, kind = "oops" } end
			else
				added = add({ uline })
			end
			if added then
				marks[#marks + 1] = { kind = "oops", c = c }
				doing[#doing + 1] = "Oops: remove " .. short(c.name)
				says[#says + 1] = "says sorry to " .. short(c.name) .. " and takes them out of the group"
				plan.type, plan.macrotext = "macro", table.concat(lines, "\n")
				title(plan)
				plan.say = table.concat(says, "; ")
				return plan
			end
		end
	end

	-- 2. the whispers this window owes
	local thanking = {}
	local pending = DR.Pending and DR.Pending() or {}
	if chat == "macro" then
		for _, w in ipairs(pending) do
			if add({ whisper(w.c, w.kind) }) then
				marks[#marks + 1] = { kind = w.kind, c = w.c }
				doing[#doing + 1] = (VERB[w.kind] or "Tell") .. " " .. short(w.c.name)
				says[#says + 1] = "whispers " .. short(w.c.name) .. " " .. (SAY[w.kind] or w.kind)
				if w.kind == "thanks" or w.kind == "tip" then thanking[w.c.key] = true end
			end
		end
	elseif chat == "box" and pending[1] then
		plan.box = pending[1]
		doing[#doing + 1] = (VERB[pending[1].kind] or "Tell") .. " " .. short(pending[1].c.name) .. " (chat box)"
		says[#says + 1] = "puts " .. (SAY[pending[1].kind] or pending[1].kind) .. " for " .. short(pending[1].c.name) .. " into the chat box"
	end

	-- 3. riders who are done leave the group (the leader's window)
	local t = now()
	if opts().kickAfter ~= false and W.InGroup() and isLeader() then
		local kicks = 0
		for _, c in ipairs(sorted()) do
			local over = c.state == "done" or (c.state == "paid" and (thanking[c.key] or t - (c.paidAt or c.at or t) > 60))
			if over and kicks < 2 and units()[c.key] and (c.kicks or 0) < 3 and t - (c.kickedAt or -100) >= 8 then
				if add({ "/uninvite " .. c.name }) then
					marks[#marks + 1] = { kind = "kick", c = c }
					doing[#doing + 1] = "Remove " .. short(c.name)
					says[#says + 1] = "takes " .. short(c.name) .. " out of the group"
					kicks = kicks + 1
				end
			end
		end
	end

	-- 4. the ritual (Warlocks only; with a main caster only the one whose turn it is), for
	-- riders of this window's station; then the call for a summoner without Wuber
	plan.station = myStation()
	plan.busyName, plan.busyCaster = DR.RitualBusy(plan.station)
	castStep(plan, add, whisper, chat)
	callStep(plan, add, whisper, chat)

	-- 3b. (run 1 item 6) a rider taken off the list who is still in the group: offered at once, never automatic
	if opts().kickAfter ~= false and W.InGroup() and isLeader() and #lines == 0 and not plan.box then
		local s = DR.StrayIgnored(true)
		if s and add({ "/uninvite " .. s.name }) then
			marks[#marks + 1] = { kind = "kick", c = s }
			doing[#doing + 1] = "Remove " .. short(s.name)
			says[#says + 1] = "takes " .. short(s.name) .. " out of the group"
		end
	end

	if #lines > 0 then plan.type, plan.macrotext = "macro", table.concat(lines, "\n") end
	title(plan)
	if #says > 0 then plan.say = table.concat(says, "; ") end
	return plan
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.hook = hook
