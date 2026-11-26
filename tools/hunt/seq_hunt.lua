-- Sequence hunt (blind-spot check 4: "no way out"; job 206). A TOOL, not part of the suite (about 6 s).
-- Built on top of tests/hunt/lib.lua's seeded-situation infrastructure (the bug hunt's fake game).
-- Runs targeted and seeded random chains of actions and checks no-way-out invariants. What the invariants allow
-- follows the decisions of the run 1 fix round (201b, 205), not a stricter reading:
--   1. drop_leave_ask:            take-off-list -> rider leaves -> walks off -> asks again: a rider again, not ignored (item 8)
--   2. cancelled_trade_mark_paid: cancelled trade -> driver takes the rider out of the group: the pay step ends in 8 s (item 7);
--                                 only "paying" counts as stuck, a rider who never reached the pay step keeps 60 s
--   3. drop_then_remove:          take-off-list -> the big button offers Remove, unless a trade is open (item 6)
--   4. cancel_summon_leave:       group exit with the summon box up (CANCEL_SUMMON at the same instant) -> not "ingroup" (REC-04)
--   5. cancel_then_leave (pending): CANCEL_SUMMON first (summon ran out in the group), the group exit 0.5 s later:
--                                 the ride stays "ingroup" with no group; not covered by the real recordings (20 of 20 same instant)
--   6. random:                    seeded random action chains over the same action pool
--
-- Usage (from repo/):
--   lua5.1 tools/hunt/seq_hunt.lua [--seed N] [--n N] [--steps N] [--chain id] [--verbose] [--addon <folder with Wuber.toc>] [--out <dir>]
-- --addon judges another Wuber copy (as sweep.lua --addon does); --out writes seq.tsv (status, id, seed, line) there.
-- Last line: "SEQ chains=<n> pass=<n> new=<n> known=<n> cannot=<n>"; exit 0 nothing new, 1 a new failure, 2 could not run.
-- A "pending" chain that still fails is KNOWN (cancel_then_leave, BUGS-NEXT BS-01), never new.
local SRC = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
local here = SRC:match("^(.*)/[^/]*$") or "."
local ROOT = here .. "/../.."
local Hunt = dofile(ROOT .. "/tests/hunt/lib.lua")

local SeqHunt = { Hunt = Hunt }

local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

local function initHunt(opts)
	if Hunt.promiseOrder and #Hunt.promiseOrder > 0 then return end
	Hunt.init(opts or {})
end

local function buildSit(overrides, seed)
	local sit = Hunt.full(overrides or {})
	local ctx = Hunt.build(sit, seed or 1)
	return ctx, sit
end

-- ---- Sequence actions ----
local ACTIONS = {
	take_off_list = function(ctx, st)
		local d = st.driverClient or ctx.me
		local DR = d and d.W and d.W.Drive
		local D = d and d.W and d.W.Driver
		if not (DR and st.riderName) then return false, "no driver/rider" end
		local c = DR.customers[key(st.riderName)]
		if not c then return false, "rider not on list" end
		if D and D.RowAction then
			D.RowAction(c, "drop")
		else
			DR.Do("DROP", st.riderName)
		end
		st.dropped = true
		st.askedAgain = nil -- a new take-off-list: the rider's last ask is not newer than it
		ctx:advance(0.5)
		return true, "take-off-list (" .. st.riderName .. ")"
	end,

	rider_leaves = function(ctx, st)
		local who = st.riderName or ctx.name
		local p = ctx.w:player(who)
		if not (p and p.group) then return false, "not in group" end
		ctx.w:leave(who)
		st.leftGroup = true
		ctx:advance(1)
		return true, "rider leaves group (" .. who .. ")"
	end,

	rider_asks_again = function(ctx, st)
		if not st.riderName then return false, "no rider" end
		local driver = st.driverClient or ctx.me
		if st.riderClient and st.riderClient.alive then
			ctx.w:whisper(st.riderClient, driver.player.name, "summon pls", "macro")
		else
			ctx.w:botWhisper(st.riderName, driver, "summon pls")
		end
		st.askedAgain = true
		ctx:advance(2)
		if st.riderClient and st.riderClient.alive and st.riderClient.player.pendingInvite then
			ctx.w.hardware = st.riderClient
			st.riderClient.env.AcceptGroup()
			ctx.w.hardware = nil
			ctx:advance(1)
		end
		return true, "rider asks again ('summon pls')"
	end,

	open_trade = function(ctx, st)
		local d = st.driverClient
		local r = st.riderClient or ctx.me
		if not (d and r and d.alive and r.alive) then return false, "missing client" end
		ctx.w:openTrade(d, r)
		st.tradeOpened = true
		ctx:advance(0.5)
		return true, "driver opens trade"
	end,

	cancel_trade = function(ctx, st)
		local r = st.riderClient or ctx.me
		if not (r and r.env and r.env.CancelTrade) then return false, "no CancelTrade" end
		r.env.CancelTrade()
		st.tradeCancelled = true
		ctx:advance(0.5)
		return true, "rider cancels trade"
	end,

	mark_paid = function(ctx, st)
		local d = st.driverClient or ctx.me
		local rName = st.riderName or ctx.name
		local DR = d and d.W and d.W.Drive
		if not DR then return false, "no driver" end
		local c = DR.customers[key(rName)]
		if c then
			if d.W.Driver and d.W.Driver.RowAction then
				d.W.Driver.RowAction(c, "paid")
			else
				DR.MarkPaid(c)
			end
		else
			DR.Do("PAID", rName, 0, "m")
		end
		st.markedPaid = true
		ctx:advance(0.5)
		return true, "driver marks paid (" .. rName .. ")"
	end,

	driver_removes = function(ctx, st)
		local d = st.driverClient or ctx.me
		local rName = st.riderName or ctx.name
		local p = ctx.w:player(rName)
		if not (p and p.group) then return false, "not in group" end
		ctx.w:uninvite(d, rName)
		st.removedFromGroup = true
		ctx:advance(1)
		return true, "driver removes " .. rName .. " from group"
	end,

	rider_walks_off = function(ctx, st)
		local who = st.riderName or ctx.name
		local p = ctx.w:player(who)
		if not p then return false, "no player" end
		ctx.w:move(who, "Ratchet")
		st.walkedOff = true
		ctx:advance(1)
		return true, "rider walks off (" .. who .. ")"
	end,

	cancel_summon = function(ctx, st)
		local r = st.riderClient or ctx.me
		if not (r and r.W and r.W.ride and r.W.ride.state == "portal") then
			return false, "no active portal"
		end
		r:fire("CANCEL_SUMMON")
		st.summonCancelled = true
		ctx:advance(0.5)
		return true, "CANCEL_SUMMON"
	end,

	advance_5s = function(ctx, st)
		ctx:advance(5)
		return true, "advance 5s"
	end,

	-- the pay step ends 5 s after the group is gone, seen on the next 1 s tick (run1_j): 8 s is enough
	advance_8s = function(ctx, st)
		ctx:advance(8)
		if st.removedFromGroup then st.waitedAfterRemoval = true end
		return true, "advance 8s"
	end,
}

-- ---- Invariants checked on state ----
local function checkDriverRemoveInvariant(ctx, st)
	if not (st.dropped and st.riderName) then return nil end
	if st.askedAgain then return nil end -- the rider asked again after the take-off-list: a NEW ride, which was not taken off the list
	local DR = ctx.W and ctx.W.Drive
	if not DR then return nil end
	local rKey = key(st.riderName)
	local p = ctx.w:player(st.riderName)
	if not (p and p.group and DR.units and DR.units[rKey]) then return nil end
	if DR.trade then return nil end -- the Remove offer waits for a trade or other pending step (run 1 item 6)
	local plan = DR.Plan and DR.Plan() or {}
	local hasUninvite = type(plan.macrotext) == "string" and plan.macrotext:lower():find("/uninvite", 1, true) ~= nil
	local hasRemoveTitle = type(plan.title) == "string" and plan.title:lower():find("remove", 1, true) ~= nil
	if not (hasUninvite or hasRemoveTitle) then
		return "item6: after take-off-list, " .. st.riderName .. " is still in group with no Remove/uninvite offered (plan: " .. tostring(plan.title) .. ")"
	end
	return nil
end

local function checkRiderStuckPayingInvariant(ctx, st)
	if not (st.tradeCancelled and st.removedFromGroup and st.waitedAfterRemoval) then return nil end
	local r = ctx.W and ctx.W.ride
	if not r then return nil end
	if r.state == "paying" then
		return "item7: after cancelled trade + mark paid + group removal, rider is still stuck in 'paying' (Waiting for driver to trade) after 8 s"
	end
	return nil
end

local function checkIgnoredAfterAskInvariant(ctx, st)
	if not (st.dropped and st.askedAgain and st.riderName) then return nil end
	local DR = ctx.W and ctx.W.Drive
	if not DR then return nil end
	local rKey = key(st.riderName)
	if DR.IsOpen and not DR.IsOpen() then return nil end -- a closed driver does not answer a request
	local plan = DR.Plan and DR.Plan() or {}
	if DR.ignored and DR.ignored[rKey] then
		return "item8: DR.ignored[" .. rKey .. "] persisted after rider asked again; big button says '" .. tostring(plan.title) .. "'"
	end
	if not (DR.customers and DR.customers[rKey]) then
		return "item8: after take-off-list -> leave -> ask again, the rider is not on the list again (big button: '" .. tostring(plan.title) .. "')"
	end
	return nil
end

local function checkCancelSummonInvariant(ctx, st)
	if not st.summonCancelled then return nil end
	local r = ctx.W and ctx.W.ride
	if not r then return nil end
	if r.state == "ingroup" and ctx.W.InGroup and not ctx.W.InGroup() then
		return "REC-04: out of the group the ride still says 'ingroup'"
	end
	return nil
end

local function checkAllInvariants(ctx, st)
	local checks = {
		checkDriverRemoveInvariant,
		checkRiderStuckPayingInvariant,
		checkIgnoredAfterAskInvariant,
		checkCancelSummonInvariant,
	}
	for _, fn in ipairs(checks) do
		local err = fn(ctx, st)
		if err then return err end
	end
	return nil
end

-- ---- Targeted chains ----
local CHAINS = {
	{
		id = "drop_leave_ask",
		about = "item 8: take-off-list -> rider leaves -> rider asks again",
		sit = { role = "warlock", ride = "arrived" },
		steps = { "take_off_list", "rider_leaves", "rider_walks_off", "rider_asks_again" },
		check = checkIgnoredAfterAskInvariant,
	},
	{
		id = "cancelled_trade_mark_paid",
		about = "item 7: cancelled trade -> driver takes the rider out of the group (marking paid by hand is a message that ends the ride by itself, so it is left out)",
		sit = { role = "rider", ride = "arrived" },
		steps = { "open_trade", "cancel_trade", "driver_removes", "advance_8s" },
		check = checkRiderStuckPayingInvariant,
	},
	{
		id = "drop_then_remove",
		about = "item 6: take-off-list -> driver wants to remove/kick",
		sit = { role = "warlock", ride = "arrived" },
		steps = { "take_off_list" },
		check = checkDriverRemoveInvariant,
	},
	{
		id = "cancel_summon_leave",
		about = "REC-04: CANCEL_SUMMON -> rider leaves group",
		sit = { role = "rider", ride = "summoning" },
		steps = { "rider_leaves", "advance_5s" },
		check = function(ctx, st)
			local r = ctx.W and ctx.W.ride
			if r and r.state == "ingroup" and not ctx.W.InGroup() then
				return "REC-04: out of the group with the summon box up the ride still says 'ingroup'"
			end
		end,
	},
	{
		id = "cancel_then_leave",
		about = "REC-04: CANCEL_SUMMON in the group, the group exit 0.5 s later",
		sit = { role = "rider", ride = "summoning" },
		steps = { "cancel_summon", "rider_leaves", "advance_5s" },
		check = checkCancelSummonInvariant,
	},
}

local function makeState(ctx, sit)
	local st = {}
	if sit.role == "warlock" then
		st.driverClient = ctx.me
		st.riderClient = ctx.peers and ctx.peers.rider
		st.riderName = st.riderClient and st.riderClient.player.name or nil
	else
		st.driverClient = ctx.peers and ctx.peers.driver
		st.riderClient = ctx.me
		st.riderName = ctx.name
	end
	return st
end

function SeqHunt.runChain(chain, seed, opts)
	opts = opts or {}
	initHunt(opts)
	local okBuild, ctx, full = pcall(buildSit, chain.sit, seed or 1)
	if not okBuild or not ctx then
		Hunt.release()
		return { id = chain.id, status = "cannot-build", detail = tostring(ctx), seed = seed or 1 }
	end
	local st = makeState(ctx, full)
	local log = {}
	local failure
	for _, stepName in ipairs(chain.steps) do
		local fn = ACTIONS[stepName]
		if not fn then
			failure = "unknown action: " .. tostring(stepName)
			break
		end
		local okStep, line = fn(ctx, st)
		log[#log + 1] = stepName .. ": " .. tostring(line)
		if not okStep then
			-- Not applicable / couldn't execute step
			break
		end
		local checkFn = chain.check or checkAllInvariants
		failure = checkFn(ctx, st)
		if failure then break end
	end
	Hunt.release()
	return {
		id = chain.id,
		about = chain.about,
		seed = seed or 1,
		status = failure and (chain.pending and "pending" or "fail") or "pass",
		failure = failure,
		log = log,
	}
end

local RANDOM_STARTS = {
	{ role = "warlock", ride = "arrived" },
	{ role = "rider", ride = "arrived" },
	{ role = "rider", ride = "summoning" },
}

local ACTION_POOL = {
	"take_off_list", "rider_leaves", "rider_asks_again",
	"open_trade", "cancel_trade", "mark_paid",
	"driver_removes", "rider_walks_off", "advance_8s",
}

function SeqHunt.runRandom(seed, nRuns, nSteps, opts)
	opts = opts or {}
	initHunt(opts)
	seed = seed or 1
	nRuns = nRuns or 6
	nSteps = nSteps or 5
	local rng = Hunt.rng(seed)
	local results = {}
	for run = 1, nRuns do
		local startSit = RANDOM_STARTS[rng:int(#RANDOM_STARTS)]
		local caseSeed = rng:int(100000)
		local okBuild, ctx, full = pcall(buildSit, startSit, caseSeed)
		if okBuild and ctx then
			local st = makeState(ctx, full)
			local log = {}
			local failure
			for step = 1, nSteps do
				-- Pick an applicable action
				local picked
				for _ = 1, #ACTION_POOL do
					local name = ACTION_POOL[rng:int(#ACTION_POOL)]
					local okStep, line = ACTIONS[name](ctx, st)
					if okStep then
						picked = name .. ": " .. tostring(line)
						break
					end
				end
				if not picked then break end
				log[#log + 1] = picked
				failure = checkAllInvariants(ctx, st)
				if failure then break end
			end
			results[#results + 1] = {
				id = "random#" .. run,
				seed = caseSeed,
				sit = Hunt.sitString(full),
				status = failure and "fail" or "pass",
				failure = failure,
				log = log,
			}
		end
		Hunt.release()
	end
	return results
end

function SeqHunt.runAll(opts)
	opts = opts or {}
	local seed = opts.seed or 1
	local out = { chains = {}, random = {}, passed = 0, failed = 0 }
	for _, chain in ipairs(CHAINS) do
		if not opts.chain or opts.chain == chain.id then
			local r = SeqHunt.runChain(chain, seed, opts)
			out.chains[#out.chains + 1] = r
			if r.status == "fail" then out.failed = out.failed + 1 elseif r.status == "pass" then out.passed = out.passed + 1 end
		end
	end
	if not opts.chain or opts.chain == "random" then
		local rands = SeqHunt.runRandom(seed, opts.n or 6, opts.steps or 5, opts)
		for _, r in ipairs(rands) do
			out.random[#out.random + 1] = r
			if r.status == "fail" then out.failed = out.failed + 1 else out.passed = out.passed + 1 end
		end
	end
	return out
end

-- CLI entry point when invoked directly
local isCli = arg and arg[0] and tostring(arg[0]):gsub("\\", "/"):find("seq_hunt%.lua$")
if isCli then
	local o = { seed = 1, n = 6, steps = 5 }
	local outDir
	local i = 1
	while arg[i] do
		local a = arg[i]
		if a == "--seed" then i = i + 1; o.seed = tonumber(arg[i]) or 1
		elseif a == "--n" then i = i + 1; o.n = tonumber(arg[i]) or 6
		elseif a == "--steps" then i = i + 1; o.steps = tonumber(arg[i]) or 5
		elseif a == "--chain" then i = i + 1; o.chain = arg[i]
		elseif a == "--addon" then i = i + 1; o.addon = arg[i]
		elseif a == "--out" then i = i + 1; outDir = arg[i]
		elseif a == "--verbose" then o.verbose = true
		end
		i = i + 1
	end
	local okRun, res = pcall(SeqHunt.runAll, o)
	if not okRun then
		io.stderr:write(tostring(res) .. "\n")
		print("SEQ chains=0 pass=0 new=0 known=0 cannot=0 error=1")
		os.exit(2)
	end
	local pass, new, known, cannot, total, tsv = 0, 0, 0, 0, 0, {}
	local function show(r)
		total = total + 1
		local st = r.status
		if st == "pass" then pass = pass + 1
		elseif st == "pending" then known = known + 1
		elseif st == "cannot-build" then cannot = cannot + 1
		else new = new + 1 end
		local line = (r.failure or r.detail or "ok"):gsub("[\t\r\n]+", " ")
		print(("%-8s %-26s %s"):format(st:upper(), r.id, line))
		tsv[#tsv + 1] = table.concat({ st, r.id, tostring(r.seed or ""), line, r.log and table.concat(r.log, " > "):gsub("[\t\r\n]+", " ") or "" }, "\t")
		if o.verbose and r.log then
			for _, l in ipairs(r.log) do print("   " .. l) end
		end
	end
	for _, r in ipairs(res.chains) do show(r) end
	for _, r in ipairs(res.random) do show(r) end
	if outDir then
		SeqHunt.Hunt.mkdir(outDir)
		SeqHunt.Hunt.writeFile(outDir .. "/seq.tsv", table.concat(tsv, "\n") .. "\n")
	end
	print(("SEQ chains=%d pass=%d new=%d known=%d cannot=%d"):format(total, pass, new, known, cannot))
	os.exit(new > 0 and 1 or (total == 0 and 2 or 0))
end

return SeqHunt
