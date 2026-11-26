-- Promises about the driver's TEAM: the crew offer, the crew's windows staying in step, who casts, the clicker cut and
-- the fair split, raid summons and the hot-drop shield. (owner crewearn). Written from what the driver is told:
-- the Crew screen ("Sends them a crew offer. They tap Yes in their Wuber", "Takes them out of your crew. They're told"),
-- the wizard, "Fair split, this shift" ("Every crew window counts the same way, so you all see the same numbers",
-- "any silver left goes to the runner", "Wuber never moves gold"), the Raid screens ("Raiders type 123 in raid chat"),
-- and the PvP chip ("Riders booking you see a warning ... It clears after 5 quiet minutes").
return function(Hunt)

-- helpers shared by this crew's files (each file has its own copy: a file owner edits only its own)
local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")) end
-- money written with the game's coin icons or as 1g 2s 3c: every amount in a text, in copper
local function amounts(text)
	local t = tostring(text or "")
	t = t:gsub("(%d+)|TInterface\\MoneyFrame\\UI%-(%a+)Icon[^|]*|t", function(n, k) return n .. k:sub(1, 1):lower() end)
	t = strip(t)
	local out, pos = {}, 1
	while true do
		local s1, e1, n1, u1 = t:find("(%d+)([gsc])%f[%A]", pos)
		if not s1 then break end
		local sum, cur = 0, e1
		local mult = { g = 10000, s = 100, c = 1 }
		sum = sum + tonumber(n1) * mult[u1]
		while true do
			local s2, e2, n2, u2 = t:find("^%s?(%d+)([gsc])%f[%A]", cur + 1)
			if not s2 then break end
			sum = sum + tonumber(n2) * mult[u2]
			cur = e2
		end
		out[#out + 1] = sum
		pos = cur + 1
	end
	return out
end
-- (2.4.2 merge) the hunt's two cut promises still call answerClose, which branch hunt's merge of 2.4.1-fix dropped (a
-- broken check: "attempt to call global 'answerClose'"); restored as job 097 wrote it: answer Yes when the question shows
local function answerClose(ctx)
	local env = ctx.me.env
	local shown = env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS")
	local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
	if shown and dlg and dlg.OnAccept then
		env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
		dlg.OnAccept()
		ctx:advance(1)
		return true
	end
	return false
end
-- (2.4, FAB-02) Close with riders still listed first asks "N riders are still with you. Close anyway?": the player
-- answers Yes, then the shop closes. A Close that skips the question while riders are listed is still a fault.
local function closeAnswering(ctx, act)
	local W, env = ctx.W, ctx.me.env
	local n = 0
	for _, c in pairs(W.Drive.customers or {}) do
		-- r50 AU24-19: a rider who paid and left is not "still with you"
		if type(c) == "table" and c.state ~= "lead" and c.state ~= "done" and not (c.state == "paid" and c.gone) then n = n + 1 end
	end
	local okm, mode = pcall(function() return W.Drive.Mode and W.Drive.Mode() end)
	local wasOpen = W.Drive.IsOpen and W.Drive.IsOpen()
	local asks = wasOpen and n > 0 and W.Driver and W.Driver.Role and W.Driver.Role() == "driver" and not (okm and mode == "raid")
	act()
	local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
	local shown = env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS")
	if shown and dlg then
		local want = (n == 1) and "1 rider is still with you. Close anyway?" or (n .. " riders are still with you. Close anyway?")
		if dlg.text ~= want then
			ctx:fail("You tap Close with " .. n .. " rider(s) listed and the question about closing does not give the real count.", tostring(dlg.text) .. " (wanted: " .. want .. ")")
		end
		env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
		dlg.OnAccept()
		ctx:note("answer Yes to " .. want)
		ctx:advance(1)
	elseif asks then
		ctx:fail("You tap Close with " .. n .. " rider(s) listed and Wuber does not ask 'Close anyway?' first.")
	end
end
local function say(ctx, fmt, ...) ctx:fail((select("#", ...) > 0 and fmt:format(...) or fmt)) end
local function texts(ctx) return ctx:texts() end
local function find(ctx, pat) for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p, t end end return nil end
local function waitFor(ctx, pred, max, step)
	step = step or 0.25
	local t = 0
	while not pred() do
		if t >= max then return false end
		ctx:advance(step)
		t = t + step
	end
	return true
end

	local function dr(ctx) return ctx.W.Drive end
	local function crewScreen(ctx)
		local S = ctx:mod("UI.Driver.Screens")
		return S and S.st and S.st.screens and S.st.screens.crew
	end
	local function crewUp(ctx)
		if not find(ctx, "^Your crew$") then ctx:cannot("the Crew screen is not up") end
	end
	local function crewKeys(c)
		local out = {}
		for _, m in ipairs(c.W.Drive.Crew() or {}) do out[#out + 1] = key(m.name or m.key or "?") end
		table.sort(out)
		return table.concat(out, ",")
	end

	-- a new Warlock with Wuber, standing where I stand, who is in nobody's crew
	local function newWarlock(ctx, name)
		if ctx.w:player(name) then ctx:cannot("name taken") end
		local c = ctx.w:addClient(name, { spot = ctx.me.player.mapID and { mapID = ctx.me.player.mapID, x = ctx.me.player.x, y = ctx.me.player.y, zone = ctx.me.player.zone, sub = ctx.me.player.subZone } or "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
		ctx:advance(2)
		return c
	end

	-- the player types a name into Add by name and clicks Add
	local function addByName(ctx, name)
		local s = crewScreen(ctx)
		if not (s and s.adder and ctx:visible(s.adder)) then ctx:cannot("the Add by name box is not on screen") end
		ctx.me:type(s.adder.field.edit, name, false)
		ctx.me:clickOn(s.adder.add)
		ctx:note("type " .. name .. " in Add by name and click Add")
		ctx:advance(1)
	end

	Hunt.promise{
		-- (job 2680) the name is one word: since ING-02 (bbf509ab) Add by name refuses "Fay Moss" like the game would
		id = "crew.offer_card",
		area = "Crew",
		text = "When you add a player by name on the Crew screen, they get a card asking to join your crew with Yes and No thanks, and you are told the offer went.",
		source = "tooltip (Add by name: Sends a crew offer to this player. They tap Yes in their Wuber); Crew screen",
		kind = "scenario",
		needs = { phone = "drive_crew", role = "warlock" },
		check = function(ctx)
			crewUp(ctx)
			local other = newWarlock(ctx, "Faymoss")
			addByName(ctx, "Faymoss")
			ctx:advance(2)
			if not find(ctx, "Crew offer sent to") then ctx:fail("You add Faymoss by name and nothing tells you the crew offer was sent.") end
			local yes = other:findText("^Yes$")
			if #yes == 0 then
				ctx:fail("You add Faymoss by name and her window shows no card with Yes (offers: " .. tostring(next(other.W.Drive.pendingOffers or {})) .. ").")
			end
			if #other:findText("^No thanks$") == 0 then ctx:fail("The crew offer card on the other window has a Yes and no No thanks.") end
		end,
	}

	local function joinByUi(ctx, other)
		local ok = pcall(other.clickText, other, "^Yes$", { pattern = true })
		if not ok then ctx:cannot("no Yes on the card") end
		ctx:advance(3)
		ctx:note("the other player clicks Yes")
	end

	Hunt.promise{
		id = "crew.yes_joins",
		area = "Crew",
		text = "When the player you invited taps Yes, they are in your crew on both windows and on your Crew screen, and no longer a Just you.",
		source = "Crew screen; tooltip (Add: Sends them a crew offer. They tap Yes in their Wuber)",
		kind = "scenario",
		needs = { phone = "drive_crew", role = "warlock" },
		check = function(ctx)
			crewUp(ctx)
			local other = newWarlock(ctx, "Faymoss")
			addByName(ctx, "Faymoss")
			joinByUi(ctx, other)
			if not dr(ctx).CrewEntry(key("Faymoss")) then ctx:fail("Faymoss taps Yes on your crew offer and she is not in your crew.") end
			if key(other.W.Drive.char().captain or "") ~= key(ctx.name) then
				ctx:fail("Faymoss taps Yes on your crew offer and her own window does not say she is in your crew.")
			end
			if not find(ctx, "Fay") then ctx:fail("Faymoss joined your crew and your Crew screen does not list her.") end
			if find(ctx, "^Just you$") then ctx:fail("Faymoss joined your crew and your Crew screen still says Just you.") end
			ctx:advance(5)
			if crewKeys(ctx) ~= crewKeys(other) then
				say(ctx, "Faymoss joined your crew: your window lists the crew as %s and hers as %s.", crewKeys(ctx), crewKeys(other))
			end
		end,
	}

	Hunt.promise{
		id = "crew.no_stays_out",
		area = "Crew",
		text = "When the player you invited taps No, they are not in your crew and you are told they said no.",
		source = "Wizard (Waiting for X to tap Yes / X said no)",
		kind = "scenario",
		needs = { phone = "drive_crew", role = "warlock" },
		check = function(ctx)
			crewUp(ctx)
			local other = newWarlock(ctx, "Faymoss")
			addByName(ctx, "Faymoss")
			local ok = pcall(other.clickText, other, "^No thanks$", { pattern = true })
			if not ok then ctx:cannot("no No thanks on the card") end
			ctx:advance(3)
			ctx:note("the other player clicks No")
			if dr(ctx).CrewEntry(key("Faymoss")) then ctx:fail("Faymoss taps No on your crew offer and she is in your crew.") end
			if key(other.W.Drive.char().captain or "") == key(ctx.name) then ctx:fail("Faymoss taps No and her window says she is in your crew.") end
		end,
	}

	Hunt.promise{
		id = "crew.just_you",
		area = "Crew",
		text = "With nobody in your crew the Crew screen shows a Just you card, and with crew mates it lists each of them.",
		source = "Crew screen (Riders bring two friends to click the portal)",
		kind = "scenario",
		needs = { phone = "drive_crew" },
		when = function(sit) return sit.role == "warlock" or sit.role == "friend" end,
		check = function(ctx)
			crewUp(ctx)
			local mates = {}
			for _, m in ipairs(dr(ctx).Crew() or {}) do if not m.me then mates[#mates + 1] = m end end
			local just = find(ctx, "^Just you$") ~= nil
			if #mates == 0 and not just then ctx:fail("You have nobody in your crew and the Crew screen has no Just you card.") end
			if #mates > 0 and just then ctx:fail(("You have %d crew mate(s) and the Crew screen still says Just you."):format(#mates)) end
			for _, m in ipairs(mates) do
				if not find(ctx, (tostring(m.name):match("^(%S+)") or "?")) then
					say(ctx, "%s is in your crew and your Crew screen does not list them.", tostring(m.name))
				end
			end
		end,
	}

	Hunt.promise{
		id = "crew.remove_member",
		area = "Crew",
		text = "Remove on a crew mate's card takes them out of your crew, tells them, and they are no longer one of your summoners.",
		source = "tooltip (Remove: Takes them out of your crew. They're told, and are treated like anyone else again)",
		kind = "scenario",
		needs = { phone = "drive_crew", role = "friend" },
		check = function(ctx)
			crewUp(ctx)
			local other = ctx.peers.summoner
			if not other then ctx:cannot("no crew mate") end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Remove$", { pattern = true })
			if not ok then ctx:cannot("no Remove button on screen") end
			-- the whisper to the mate can wait in the shared outbox (10 + 1/s allowance): give it up to 15 s
			ctx:advance(4)
			for _ = 1, 11 do
				if key(other.W.Drive.char().captain or "") ~= key(ctx.name) then break end
				ctx:advance(1)
			end
			ctx:note("click Remove on the crew mate's card")
			if dr(ctx).CrewEntry(key(other.player.name)) then ctx:fail("You click Remove on your Warlock friend and she is still in your crew.") end
			if key(other.W.Drive.char().captain or "") == key(ctx.name) then
				ctx:fail("You click Remove on your Warlock friend and her own window still says she is in your crew.")
			end
			for _, k in ipairs(dr(ctx).Summoners and dr(ctx).Summoners() or {}) do
				if k == key(other.player.name) then ctx:fail("You remove your Warlock friend from your crew and she is still in your summoning order.") end
			end
		end,
	}

	Hunt.promise{
		id = "crew.leave_crew",
		area = "Crew",
		text = "Leave this crew, clicked twice, takes you out of the captain's crew on both windows.",
		source = "tooltip (Leave this crew: You stop helping this captain ... Click twice)",
		kind = "scenario",
		needs = { phone = "drive_crew", role = "crew" },
		check = function(ctx)
			crewUp(ctx)
			local cap = ctx.peers.captain
			if not cap then ctx:cannot("no captain window") end
			for i = 1, 2 do
				local okc = pcall(ctx.me.clickText, ctx.me, "^Leave this crew$", { pattern = true })
				if not okc then okc = pcall(ctx.me.clickText, ctx.me, "^Click again to leave$", { pattern = true }) end
				if not okc then ctx:cannot("no Leave this crew button") end
				ctx:advance(0.5)
			end
			ctx:note("click Leave this crew twice")
			ctx:advance(4)
			if (dr(ctx).char().captain or "") ~= "" then ctx:fail("You click Leave this crew twice and your own window still names a captain.") end
			if cap.W.Drive.CrewEntry(key(ctx.name)) then ctx:fail("You leave your captain's crew and the captain's window still lists you.") end
		end,
	}

	Hunt.promise{
		id = "crew.windows_agree",
		area = "Crew",
		text = "Everyone in a crew sees the same crew: the captain's window and each member's window list the same people.",
		source = "Drive.Team header (the CRW list goes to all crew members); inferred",
		kind = "scenario",
		when = function(sit) return sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			local other = ctx.peers.summoner or ctx.peers.captain
			if not other then ctx:cannot("no other crew window") end
			ctx:advance(20)
			if crewKeys(ctx) ~= crewKeys(other) then
				say(ctx, "Your crew list reads %s and your crew mate's window reads %s.", crewKeys(ctx), crewKeys(other))
			end
		end,
	}

	Hunt.promise{
		id = "crew.nonwarlock_never_casts",
		area = "Crew",
		text = "If you run the service on a class that cannot summon, your big button never offers to cast; your Warlock friend's does.",
		source = "Drive.Cast header (A helper who is not a Warlock never gets a cast step); wizard (You need a Warlock to cast)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			if ctx.me.player.class == "WARLOCK" then ctx:na("a Warlock") end
			local b = ctx.me.env.WuberDriveButton
			if not b then ctx:na("no big button on this window") end
			local macro = tostring(b:GetAttribute("macrotext") or "") .. tostring(b:GetAttribute("macrotext1") or "") .. tostring(b:GetAttribute("spell") or "")
			if macro:find("Ritual of Summoning", 1, true) then
				ctx:fail("You are not a Warlock and your big button holds the Ritual of Summoning cast.")
			end
		end,
	}
	---------------------------------------------------------------------------
	-- the clicker cut: casts, clicks, the fair split
	---------------------------------------------------------------------------
	local function cutOf(c)
		local rows, rule, info = c.W.Drive.Cut()
		return rows or {}, rule, info or {}
	end

	local function paid(sit) return sit.ride == "paid" or sit.ride == "ended" end

	Hunt.promise{
		id = "cut.ledger_counts",
		area = "Cut",
		gap = "bots that click the portal send the caster's window no channel event, so a friend without Wuber is never named and never counted",
		text = "After one summon the fair split counts one cast for the Warlock who cast and one click for each friend who clicked the portal.",
		source = "tooltip (This shift: Who cast and who clicked the portal since you opened); Drive.Cut header",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return sit.role == "warlock" or sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			ctx:advance(3)
			local rows = cutOf(ctx)
			local casts, clicks = 0, 0
			for _, r in ipairs(rows) do casts, clicks = casts + r.casts, clicks + r.clicks end
			local team = ctx.facts.team or {}
			-- a click counts only from the caster's own place (Cast.lua): a window on another continent cannot click
			do
				local cp = team.caster and ctx.w:player(team.caster)
				local cc = cp and cp.mapID and ctx.H.continentOf(cp.mapID)
				for _, n in ipairs(team.clickers or {}) do
					local p = ctx.w:player(n)
					local pc = p and p.mapID and ctx.H.continentOf(p.mapID)
					if cc and pc and cc ~= pc then ctx:na("the clicking window (" .. n .. ") is on another continent from the caster") end
				end
			end
			-- (FAKE-GAME GAP: a friend without Wuber who clicks the portal is a bot: the caster's window gets no
			-- channel event for it, so only the friends who are Wuber windows can be counted here)
			local wantClicks = 0
			for _, n in ipairs(team.clickers or {}) do
				local cl = ctx.w:clientOf(n)
				if cl and cl.alive then wantClicks = wantClicks + 1 end
			end
			if casts ~= 1 or clicks < wantClicks then
				local seen = {}
				for _, r in ipairs(rows) do seen[#seen + 1] = ("%s %dc/%dk"):format(r.name, r.casts, r.clicks) end
				say(ctx, "A rider was summoned with one cast and %d friend window(s) clicking the portal; the fair split says %d cast(s) and %d click(s) (%s).", wantClicks, casts, clicks, table.concat(seen, ", "))
			end
			-- the caster is the one credited with the cast
			local caster = team.caster and key(team.caster)
			for _, r in ipairs(rows) do
				if r.casts > 0 and caster and key(r.name) ~= caster and r.key ~= caster then
					say(ctx, "%s cast the summon and the fair split credits the cast to %s.", team.caster, tostring(r.name))
				end
			end
		end,
	}

	Hunt.promise{
		id = "cut.shares_add_up",
		area = "Cut",
		text = "The fair split shares out exactly what the shift took: the shares add up to the gold paid, with no silver lost or invented.",
		source = "Drive.Cut header (shares are floored to whole silver; what is left goes to the runner); inferred",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return sit.role == "warlock" or sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			ctx:advance(3)
			local rows, rule, info = cutOf(ctx)
			if #rows == 0 then ctx:na("nobody cast or clicked") end
			local total = 0
			for _, r in ipairs(rows) do total = total + r.share end
			local fare = ctx.facts.paid or info.gold
			if info.gold ~= fare then
				say(ctx, "A rider paid %s this shift and the fair split starts from %s.", ctx.W.Money(fare or 0), ctx.W.Money(info.gold or 0))
			end
			if total ~= info.gold then
				say(ctx, "The shift took %s and the fair split hands out %s in all.", ctx.W.Money(info.gold), ctx.W.Money(total))
			end
			for _, r in ipairs(rows) do
				if r.share % 100 ~= 0 and (r.key ~= (dr(ctx).CaptainKey and dr(ctx).CaptainKey() or ctx.W.myKey)) then
					say(ctx, "%s's share of the fair split is %s, not whole silver.", tostring(r.name), ctx.W.Money(r.share))
				end
			end
		end,
	}

	Hunt.promise{
		id = "cut.windows_agree",
		area = "Cut",
		text = "Every crew window counts the same fair split: the same people, casts, clicks and gold.",
		source = "tooltip (This shift: Every crew window counts the same way, so you all see the same numbers)",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			local other = ctx.peers.summoner or ctx.peers.captain
			if not other then ctx:cannot("no other crew window") end
			ctx:advance(5)
			local function sig(c)
				local rows, _, info = cutOf(c)
				local out = {}
				for _, r in ipairs(rows) do out[#out + 1] = ("%s:%d:%d"):format(key(r.name), r.casts, r.clicks) end
				table.sort(out)
				return table.concat(out, " ") .. " gold=" .. tostring(info.gold)
			end
			local a, b = sig(ctx), sig(other)
			if a ~= b then say(ctx, "Your fair split reads [%s] and your crew mate's window reads [%s].", a, b) end
		end,
	}

	Hunt.promise{
		id = "cut.default_forty",
		area = "Cut",
		text = "By default the Warlock who cast shares 40 percent of the takings and the clickers share the rest.",
		source = "tooltip (Casters share 40% by casts, clickers 60% by clicks, in whole silver); Settings > Driving",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return (sit.role == "warlock" or sit.role == "friend" or sit.role == "crew") and sit.opt_cutRule ~= "equal" end,
		check = function(ctx)
			ctx:advance(3)
			local rows, rule, info = cutOf(ctx)
			if #rows == 0 then ctx:na("nobody cast or clicked") end
			local pct = dr(ctx).Opt("cutCaster") or 40
			local casters, anyClick = 0, false
			for _, r in ipairs(rows) do
				if r.casts > 0 then casters = casters + r.share end
				if r.clicks > 0 then anyClick = true end
			end
			if not anyClick then ctx:na("nobody clicked (a friend without Wuber cannot be seen by the fake game)") end
			local anyCast = false
			for _, r in ipairs(rows) do if r.casts > 0 then anyCast = true end end
			if not anyCast then ctx:na("this window counted no cast (cut.ledger_counts reports that)") end
			local want = math.floor(info.gold * pct / 100 / 100) * 100
			if casters < want or casters > want + 100 * (#rows + 1) then
				say(ctx, "The shift took %s and the caster's share is %s, not the %d percent (%s) the Earnings tooltip promises.", ctx.W.Money(info.gold), ctx.W.Money(casters), pct, ctx.W.Money(want))
			end
		end,
	}

	Hunt.promise{
		id = "cut.equal_rule",
		area = "Cut",
		text = "With the split set to equal, everyone who cast or clicked gets the same share, give or take the silver left for the runner.",
		source = "Settings > Driving (How the shift's gold is split: equal); Drive.Cut header",
		kind = "scenario",
		needs = { ride = "paid", opt_cutRule = "equal" },
		when = function(sit) return sit.role == "warlock" or sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			ctx:advance(3)
			local rows, rule = cutOf(ctx)
			if rule ~= "equal" then ctx:cannot("the rule is " .. tostring(rule)) end
			if #rows < 2 then ctx:na("fewer than two people") end
			local lo, hi
			for _, r in ipairs(rows) do
				if r.casts + r.clicks > 0 then
					lo = lo and math.min(lo, r.share) or r.share
					hi = hi and math.max(hi, r.share) or r.share
				end
			end
			if hi - lo > 100 * #rows then
				say(ctx, "The split is set to equal and the shares run from %s to %s.", ctx.W.Money(lo), ctx.W.Money(hi))
			end
		end,
	}

	Hunt.promise{
		id = "cut.new_shift_starts_clean",
		area = "Cut",
		text = "When you close and open again, the fair split starts from nothing: no casts, clicks or gold from the last shift.",
		source = "Drive.Cut header (a new shift clears the tallies)",
		kind = "scenario",
		needs = { ride = "paid", role = "warlock" },
		check = function(ctx)
			ctx:advance(3)
			local rows = cutOf(ctx)
			if #rows == 0 then ctx:na("no casts to forget") end
			local D = ctx.W.Driver
			D.SetOnline(false)
			ctx:advance(1)
			answerClose(ctx)
			ctx:advance(5)
			if dr(ctx).IsOpen and dr(ctx).IsOpen() then ctx:na("the shop would not close") end
			ctx:note("close the shop")
			if ctx:visible(ctx.me.env.WuberFrame) then pcall(ctx.me.clickText, ctx.me, "^Nice$", { pattern = true }) end
			D.SetOnline(true)
			ctx:advance(5)
			ctx:note("open the shop again")
			local rows2, _, info = cutOf(ctx)
			local n = 0
			for _, r in ipairs(rows2) do n = n + r.casts + r.clicks + r.share end
			if n ~= 0 or (info.gold or 0) ~= 0 then
				say(ctx, "You close and open again and the fair split still counts last shift's casts and %s.", ctx.W.Money(info.gold or 0))
			end
		end,
	}

	Hunt.promise{
		id = "cut.shift_card_split",
		area = "Cut",
		text = "The Shift complete card and the Fair split line in the log give each person the same share you saw during the shift.",
		source = "Sheets (Fair split, Post to party); Drive.Cut header (the shift log's cut entries)",
		kind = "scenario",
		needs = { ride = "paid", role = "warlock", phone = "drive" },
		check = function(ctx)
			ctx:advance(3)
			local rows = cutOf(ctx)
			if #rows == 0 then ctx:na("no casts") end
			local before = {}
			for _, r in ipairs(rows) do before[#before + 1] = ("%s:%d"):format(key(r.name), r.share) end
			table.sort(before)
			local ok = pcall(ctx.me.clickText, ctx.me, "^Close$", { pattern = true })
			if not ok then ctx:cannot("no Close button") end
			ctx:advance(1)
			answerClose(ctx)
			ctx:advance(2)
			ctx:note("click Close")
			local env = ctx.me and ctx.me.env
			if env and env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS") then
				local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
				env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
				if dlg and dlg.OnAccept then dlg.OnAccept() end
				ctx:advance(1)
			end
			local log = dr(ctx).CutLog()
			local last = log[#log]
			if not last then ctx:fail("You close a shift with a paid ride and the shift log holds no split.") end
			if last.gold ~= ctx.facts.paid then say(ctx, "You close a shift that took %s and the shift log holds %s.", ctx.W.Money(ctx.facts.paid or 0), ctx.W.Money(last.gold)) end
			local text = dr(ctx).CutText()
			local rows2 = cutOf(ctx)
			local after = {}
			for _, r in ipairs(rows2) do after[#after + 1] = ("%s:%d"):format(key(r.name), r.share) end
			table.sort(after)
			if table.concat(before, " ") ~= table.concat(after, " ") then
				say(ctx, "The shift's split read [%s] and after you close it reads [%s].", table.concat(before, " "), table.concat(after, " "))
			end
		end,
	}
	---------------------------------------------------------------------------
	-- raid summons
	---------------------------------------------------------------------------
	local RAIDERS = { "Alder Mate", "Birch Mate", "Cedar Mate" }

	-- the leader taps Raid summons, then Start (the way the screen says)
	local function startRaid(ctx)
		if ctx.me.player.combat then ctx:na("in combat: the big button is paused until the fight is over") end
		local ok = pcall(ctx.me.clickText, ctx.me, "^Raid summons$", { pattern = true })
		if not ok then ctx:cannot("no Raid summons tab") end
		ctx:advance(1)
		local ok2 = pcall(ctx.me.clickText, ctx.me, "^Start", { pattern = true })
		if not ok2 then ctx:cannot("no Start button") end
		ctx:advance(2)
		ctx:note("tap Raid summons, then Start")
	end

	-- raiders stand away from the leader (they cannot walk: they ask for a summon)
	local function sendAway(ctx, names)
		local away = "Orgrimmar"
		local here = tostring(ctx.me.player.zone or "")
		if here == "Orgrimmar" or tostring(ctx.me.player.mapID) == "1454" then away = "Undercity" end
		for _, n in ipairs(names) do
			if not ctx.w:player(n) then ctx:cannot("no raider " .. n) end
			ctx.w:move(n, away)
		end
		ctx:advance(4)
		ctx:note("the raiders " .. table.concat(names, ", ") .. " stand in Orgrimmar")
	end

	local function raidSay(ctx, who, text)
		ctx.w:chatFrom(who, text, "RAID")
		ctx:advance(2)
		ctx:note(who .. " says in raid chat: " .. text)
	end

	local function waiting(ctx)
		local out = {}
		local q = dr(ctx).RaidQueue and dr(ctx).RaidQueue() or {}
		for _, e in ipairs(q) do out[#out + 1] = key(e.name or e.key or "?") end
		return out
	end

	local function raidSit(sit) return sit.role == "warlock" and sit.group == "raid" and sit.ride == "none" end

	Hunt.promise{
		id = "raid.type_123",
		area = "Raid",
		text = "While raid summons run, a raider who types 123 in raid chat joins the queue and you see them waiting.",
		source = "Raid screen (Raiders type 123 in raid chat)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid" },
		when = function(sit) return sit.ride == "none" or sit.ride == nil end,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { RAIDERS[1] })
			raidSay(ctx, RAIDERS[1], "123")
			local q = waiting(ctx)
			if #q ~= 1 then say(ctx, "Raid summons are running, Alder types 123 in raid chat and the queue holds %d raiders.", #q) end
			if not find(ctx, "^Alder") then ctx:fail("Alder types 123 in raid chat and the Raid summons screen does not show her waiting.") end
		end,
	}

	Hunt.promise{
		id = "raid.cancel_word",
		area = "Raid",
		text = "A raider who typed 123 and then says nvm, cancel or here in raid chat is taken out of the queue.",
		source = "Drive.Raid (cancel words); Raid screen",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid" },
		when = function(sit) return sit.ride == "none" or sit.ride == nil end,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { RAIDERS[1], RAIDERS[2] })
			raidSay(ctx, RAIDERS[1], "123")
			raidSay(ctx, RAIDERS[2], "summon pls")
			if #waiting(ctx) ~= 2 then say(ctx, "Two raiders ask for a summon in raid chat and the queue holds %d.", #waiting(ctx)) end
			raidSay(ctx, RAIDERS[1], "nvm")
			local q = waiting(ctx)
			if #q ~= 1 or q[1] ~= key(RAIDERS[2]) then
				say(ctx, "Alder asked for a summon, then said nvm in raid chat, and the queue reads [%s].", table.concat(q, ", "))
			end
		end,
	}

	Hunt.promise{
		id = "raid.order_asked",
		area = "Raid",
		text = "Raiders are summoned in the order they asked: the one who asked first is at the top.",
		source = "inferred (a queue)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid" },
		when = function(sit) return sit.ride == "none" or sit.ride == nil end,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { RAIDERS[1], RAIDERS[2], RAIDERS[3] })
			raidSay(ctx, RAIDERS[2], "123")
			raidSay(ctx, RAIDERS[3], "123")
			raidSay(ctx, RAIDERS[1], "123")
			local q = waiting(ctx)
			local want = { key(RAIDERS[2]), key(RAIDERS[3]), key(RAIDERS[1]) }
			if table.concat(q, ",") ~= table.concat(want, ",") then
				say(ctx, "Birch, Cedar and Alder ask for a summon in that order and the queue reads [%s].", table.concat(q, ", "))
			end
		end,
	}

	Hunt.promise{
		id = "raid.long_chatter_ignored",
		area = "Raid",
		text = "Someone chatting in raid chat who happens to write 123 in a long sentence is not put in the summon queue.",
		source = "Drive.Raid (a request is a short line); inferred",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid" },
		when = function(sit) return sit.ride == "none" or sit.ride == nil end,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { RAIDERS[1] })
			raidSay(ctx, RAIDERS[1], "ok so the boss drops about 123 gold of loot in total, who wants what from the pile")
			if #waiting(ctx) ~= 0 then ctx:fail("A raider chats about 123 gold in a long raid chat line and is put in the summon queue.") end
		end,
	}

	Hunt.promise{
		id = "raid.empty_words",
		area = "Raid",
		text = "With nobody in the queue the Raid summons screen says whether raid summons are stopped or running, and what raiders should type.",
		source = "Raid screen texts (Raid summons are stopped / Nobody waiting, Raiders type 123 in raid chat)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid" },
		when = function(sit) return sit.ride == "none" or sit.ride == nil end,
		check = function(ctx)
			local ok = pcall(ctx.me.clickText, ctx.me, "^Raid summons$", { pattern = true })
			if not ok then ctx:cannot("no Raid summons tab") end
			ctx:advance(1)
			if not dr(ctx).RaidOn() then
				if not find(ctx, "Raid summons are stopped") then ctx:fail("Raid summons are stopped and the screen does not say so.") end
			end
			startRaid(ctx)
			if not find(ctx, "Nobody waiting") then ctx:fail("Raid summons run with nobody waiting and the screen does not say Nobody waiting.") end
			if not find(ctx, "123") then ctx:fail("Raid summons run and nothing tells raiders to type 123 in raid chat.") end
			local ok2 = pcall(ctx.me.clickText, ctx.me, "^Stop$", { pattern = true })
			if not ok2 then ctx:cannot("no Stop button") end
			ctx:advance(2)
			ctx:note("tap Stop")
			if not find(ctx, "Raid summons are stopped") then ctx:fail("You tap Stop and the screen does not say raid summons are stopped.") end
		end,
	}

	Hunt.promise{
		id = "raid.back_to_selling",
		area = "Raid",
		text = "When you switch back to selling summons, raid summons stop and nobody stays queued for a free summon.",
		source = "Drive.Raid header (Raid summons stopped: you're back to selling summons)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid" },
		when = function(sit) return sit.ride == "none" or sit.ride == nil end,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { RAIDERS[1] })
			raidSay(ctx, RAIDERS[1], "123")
			local ok = pcall(ctx.me.clickText, ctx.me, "^Sell summons$", { pattern = true })
			if not ok then ctx:cannot("no Sell summons tab") end
			ctx:advance(2)
			ctx:note("tap Sell summons")
			if dr(ctx).RaidOn() then ctx:fail("You switch from raid summons back to selling summons and raid summons are still running.") end
			if find(ctx, "^Running$") then ctx:fail("You switch back to selling summons and the screen still says Running.") end
		end,
	}

	---------------------------------------------------------------------------
	-- the hot-drop shield
	---------------------------------------------------------------------------
	local function pvpChip(ctx) return find(ctx, "PvP nearby") ~= nil end

	Hunt.promise{
		id = "danger.enemy_near_warns",
		area = "Danger",
		text = "When you are open and an enemy player who can fight you shows near your summon spot, your console says PvP nearby and that riders are warned.",
		source = "Draw (PvP nearby, riders are warned); SPEC7 5.6",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", enemies = "near" },
		check = function(ctx)
			ctx:advance(6)
			if not dr(ctx).IsOpen() then ctx:na("not open") end
			if not pvpChip(ctx) then
				ctx:fail("You are open at your summon spot, a flagged enemy player stands close with a nameplate in view, and the console shows no PvP nearby warning.")
			end
		end,
	}

	Hunt.promise{
		id = "danger.fight_warns",
		area = "Danger",
		text = "After you fight an enemy player near your summon spot, the console warns PvP nearby and riders booking you are told of a hot drop.",
		source = "tooltip (PvP nearby: Your crew fought enemy players ... Riders booking you see a warning)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", enemies = "fought" },
		-- (job 2680) not after a rain check: that dial closes and reopens the shop after the fight, and closing forgets it by design
		when = function(sit) return sit.ride ~= "raincheck" end,
		check = function(ctx)
			if ctx.sit.ride == "raincheck" then ctx:na("the rain check closed and reopened the shop after the fight") end
			ctx:advance(6)
			if not pvpChip(ctx) then
				ctx:fail("You fought a flagged enemy player at your summon spot a few seconds ago and the console shows no PvP nearby warning.")
			end
			local level = dr(ctx).DangerLevel()
			if (level or 0) < 2 then
				say(ctx, "You fought an enemy player and your danger level is %s, not the red hot-drop level.", tostring(level))
			end
		end,
	}

	Hunt.promise{
		id = "danger.fight_clears",
		area = "Danger",
		text = "The PvP nearby warning clears by itself after five quiet minutes.",
		source = "tooltip (PvP nearby: It clears after 5 quiet minutes)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", enemies = "fought" },
		check = function(ctx)
			ctx:advance(6)
			if not pvpChip(ctx) then ctx:na("no warning to clear") end
			ctx:advance(330)
			if pvpChip(ctx) then ctx:fail("Five and a half quiet minutes after a fight the PvP nearby warning is still on your console.") end
		end,
	}

	Hunt.promise{
		id = "danger.closed_no_warning",
		area = "Danger",
		text = "When you are closed, Wuber watches nothing for PvP: no warning on your console and no hot-drop level for riders.",
		source = "Drive.Danger header (Only while open (selling): closed, nothing is listened to and my level is 0)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", enemies = "near" },
		check = function(ctx)
			closeAnswering(ctx, function() ctx.W.Driver.SetOnline(false) end)
			ctx:advance(5)
			if dr(ctx).IsOpen and dr(ctx).IsOpen() then ctx:na("the shop would not close") end
			ctx:note("close the shop")
			ctx.w:advance(1)
			ctx:advance(10)
			if pvpChip(ctx) then ctx:fail("You are closed and the console still warns PvP nearby.") end
			local level = dr(ctx).DangerLevel()
			if (level or 0) ~= 0 then say(ctx, "You are closed and riders are still told a hot-drop level of %s.", tostring(level)) end
		end,
	}
end
