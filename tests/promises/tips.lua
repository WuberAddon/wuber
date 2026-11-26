-- Promises about the login tips (owner CORE: the starter set that proves the hunt on the bugs the author hit).
-- Written from what the player was told (Settings > Riding > Login tips: "On: when you open Wuber after logging in,
-- a small tip card shows inside the phone, one tip at a time, each only once", round 26 item 1).
-- A tip card here is the card showing a tip (its Show me button is up), not the "Tips are off" line.
return function(Hunt)
	-- phone values where the dial's own open IS the first open (nothing clicked after it)
	local OPENS = { closed = true, splash = true, home = true, trips_direct = true, drive_direct = true, world_view = true, here_view = true }

	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end -- the dial is not loaded: its default world
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	-- login tips on, the coach marks done, no ride, no combat, a session after the first ever run
	local function base(sit)
		return sit.session ~= "first" and is(sit, "coach", "done") and is(sit, "ride", "none") and is(sit, "combat", "no")
	end

	local function tipsMod(ctx)
		local m = ctx:mod("UI.Tips")
		if not (m and type(m.Card) == "function") then ctx:cannot("this Wuber has no login tips (UI.Tips)") end
		return m
	end

	local function cardOf(ctx, Tips)
		local ok, c = pcall(Tips.Card)
		if ok and type(c) == "table" and ctx:visible(c) then return c end
		return nil
	end

	-- the card is up showing a tip (its buttons are up; the "Tips are off" line has none)
	local function tipUp(ctx, Tips)
		local c = cardOf(ctx, Tips)
		if c and type(c.show) == "table" and ctx:visible(c.show) then return c end
		return nil
	end

	local function ui(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end

	local function phoneShown(ctx)
		local UI = ctx.W.UI
		if UI and type(UI.IsShown) == "function" then return UI.IsShown() == true end
		local win = ui(ctx).win
		return win ~= nil and win:IsShown() == true
	end

	local function rideActiveNow(ctx)
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			return ok and active == true
		end
		return false
	end

	-- the player opens Wuber (the minimap button's toggle)
	local function open(ctx)
		ctx.W.UI.Toggle(true)
		ctx:note("open the phone")
	end

	local function waitTip(ctx, Tips, secs)
		for _ = 1, secs or 8 do
			ctx:advance(1)
			local c = tipUp(ctx, Tips)
			if c then return c end
		end
		return nil
	end

	-- the promise's conditions, as the build reached them
	local function conditions(ctx, needOn)
		if ctx.me.player.combat then ctx:na("in combat") end
		local db = ctx.W.db
		if type(db) ~= "table" or db.coach ~= true then ctx:na("the first-open coach marks are not done") end
		if needOn and db.tipsOn == false then ctx:na("login tips are off") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			if ok and active then ctx:na("a ride is on") end
		end
	end

	local function onScreen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local TAB = { Ride = "Home", Drive = "the Drive tab", Trips = "the Trips tab" }

	Hunt.promise{
		id = "tips.first_open",
		area = "Tips",
		text = "The first time you open Wuber after logging in, you see one tip card, whatever tab the phone opens on — except when opened directly on Drive (/wuber drive or minimap Drive click), where it stays on Drive and shows the tip at the next open (HR-1).",
		source = "BRIEF25 T1; round 26 item 1 (Settings > Riding > Login tips); HR-1 (UI/Tips.lua:533)",
		kind = "scenario",
		when = function(sit) return base(sit) and sit.tipsOn ~= "off" and is(sit, "phone", OPENS) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, true)
			local okn, nextTip = pcall(Tips.Next)
			if okn and nextTip == nil then ctx:na("every tip this player gets has been seen") end
			local how = "the phone dial opened it"
			if not phoneShown(ctx) then
				open(ctx)
				how = "the check opened it"
			end
			ctx:advance(0.1)
			local tab = ui(ctx).tab
			if ctx.sit and ctx.sit.phone == "drive_direct" then
				ctx:advance(1)
				if ui(ctx).tab ~= "Drive" then
					ctx:fail("You opened Wuber directly on Drive and it did not stay on the Drive tab.",
						"now on tab " .. tostring(ui(ctx).tab) .. "; " .. onScreen(ctx))
				end
				if tipUp(ctx, Tips) then
					ctx:fail("You opened Wuber directly on Drive and a tip card showed over Drive.", onScreen(ctx))
				end
				ctx.W.UI.Toggle(false)
				ctx:note("close the phone")
				ctx:advance(1)
				open(ctx)
				ctx:advance(0.1)
				if waitTip(ctx, Tips, 8) then return end
				ctx:fail("You opened Wuber directly on Drive, then closed and opened it again, and no tip card shows.",
					"now on tab " .. tostring(ui(ctx).tab) .. ", screen " .. tostring(ui(ctx).screen) .. "; " .. onScreen(ctx))
			end
			if waitTip(ctx, Tips, 8) then return end
			-- (2.4) UI.MayOpen runs one card at a time and the Skip the bird card / mid-flight offer stand before the tip:
			-- the tip waits. A player dismisses that card ("Don't show again"), and then the tip must come.
			do
				local function up(f) return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() == true end
				local Bird = ctx:mod("UI.Bird")
				local bird = Bird and type(Bird.Card) == "function" and Bird.Card() or nil
				if up(ctx.me.env.WuberInFlight) then ctx:na("the mid-flight offer is up first; the tip waits for it (UI.MayOpen)") end
				if up(bird) then
					local b = ctx.me:button("Don't show again")
					if not (b and ctx:visible(b)) then ctx:cannot("the Skip the bird card is up and has no Don't show again button to tap") end
					ctx.me:click(b)
					ctx:note("dismiss the Skip the bird card (Don't show again): it stands before the tip")
					ctx:advance(0.5)
					if waitTip(ctx, Tips, 8) then return end
				end
				-- (job 2680) 2.4.1: the What's new pop-up (See what's new / Not now) stands before the tip as well (UI.MayOpen); a player taps Not now, then the tip must come
				local nn = ctx.me:button("Not now")
				if nn and ctx:visible(nn) then
					ctx.me:click(nn)
					ctx:note("tap Not now on the What's new card: it stands before the tip")
					ctx:advance(0.5)
					if waitTip(ctx, Tips, 8) then return end
				end
			end
			ctx:fail(("You log in%s, open Wuber for the first time (it opens on %s) and no tip card shows."):format(
				ctx.facts.reloaded and " and /reload" or "", TAB[tab] or tostring(tab)),
				how .. "; now on tab " .. tostring(ui(ctx).tab) .. ", screen " .. tostring(ui(ctx).screen) .. "; " .. onScreen(ctx))
		end,
	}

	-- Settings > Riding > Login tips: the switch, clicked where it is drawn; true when it now says on
	local function flip(ctx, want)
		local UI = ctx.W.UI
		if type(UI.OpenSettings) ~= "function" then ctx:cannot("no Settings in this Wuber") end
		if not ctx.W.UI.settingsOpen and not (ui(ctx).settingsOpen) then UI.OpenSettings("riding") ctx:advance(1) end
		local st = UI.settings
		local t = st and st.controls and st.controls.tips
		if not (t and ctx:visible(t)) then ctx:cannot("the Login tips switch is not on screen (Settings > Riding)") end
		ctx.me:clickOn(t)
		ctx:advance(0.5)
		ctx:note("click Login tips (" .. (want and "on" or "off") .. ")")
		if t.get() ~= want and type(t.Click) == "function" then
			-- the click where it is drawn landed elsewhere (scrolled, a big window): the player scrolls to it and clicks
			pcall(t.Click, t)
			ctx:advance(0.5)
			ctx:note("Login tips clicked by its button (the drawn spot was covered or scrolled)")
		end
		if t.get() ~= want then ctx:cannot("the Login tips switch could not be clicked") end
	end

	Hunt.promise{
		id = "tips.off_on",
		area = "Tips",
		text = "Turning Login tips off and then on again shows a tip the next time you open Wuber.",
		source = "round 26 item 1",
		kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return base(sit) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, false)
			open(ctx)
			ctx:advance(4)
			flip(ctx, false)
			flip(ctx, true)
			ctx.W.UI.Toggle(false)
			ctx:note("close the phone")
			ctx:advance(2)
			open(ctx)
			ctx:advance(0.1)
			local tab = ui(ctx).tab
			if waitTip(ctx, Tips, 8) then return end
			-- (job 2680) as tips.first_open: the Skip the bird card stands before the tip (UI.MayOpen, 2.4); a player dismisses it, then the tip must come
			do
				local function up(f) return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() == true end
				local Bird = ctx:mod("UI.Bird")
				local bird = Bird and type(Bird.Card) == "function" and Bird.Card() or nil
				if up(ctx.me.env.WuberInFlight) then ctx:na("the mid-flight offer is up first; the tip waits for it (UI.MayOpen)") end
				if up(bird) then
					local b = ctx.me:button("Don't show again")
					if not (b and ctx:visible(b)) then ctx:cannot("the Skip the bird card is up and has no Don't show again button to tap") end
					ctx.me:click(b)
					ctx:note("dismiss the Skip the bird card (Don't show again): it stands before the tip")
					ctx:advance(0.5)
					if waitTip(ctx, Tips, 8) then return end
				end
			end
			ctx:fail(("You turn Login tips off and on again in Settings, close Wuber, open it again (on %s) and no tip card shows."):format(
				TAB[tab] or tostring(tab)), "now on tab " .. tostring(ui(ctx).tab) .. ", screen " .. tostring(ui(ctx).screen) .. "; " .. onScreen(ctx))
		end,
	}

	-- every visible widget inside the phone, apart from the card and what is on it
	local function inside(obj, top)
		local cur, n = obj, 0
		while cur and n < 60 do
			if cur == top then return true end
			local ok, p = pcall(cur.GetParent, cur)
			if not ok then return false end
			cur, n = p, n + 1
		end
		return false
	end
	local function snapshot(ctx, card)
		local win = ui(ctx).win
		local set, texts = {}, {}
		for _, obj in ipairs(ctx.me.widgets or {}) do
			if ctx:visible(obj) and win and inside(obj, win) and not inside(obj, card) then
				set[obj] = true
				local s = ctx.S[obj]
				if s and s.otype == "FontString" and type(s.text) == "string" and s.text ~= "" then texts[#texts + 1] = s.text end
			end
		end
		return set, table.concat(texts, "\1"), tostring(ui(ctx).tab) .. "/" .. tostring(ui(ctx).screen)
	end

	Hunt.promise{
		id = "tips.show_me",
		area = "Tips",
		text = "Show me on a tip card does something you can see.",
		source = "round 26 item 1",
		kind = "scenario",
		when = function(sit) return base(sit) and sit.tipsOn ~= "off" and is(sit, "phone", OPENS) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, true)
			if not phoneShown(ctx) then open(ctx) end
			local card = waitTip(ctx, Tips, 8)
			if not card then
				ctx.me:slash("/wuber tips")
				ctx:note("/wuber tips")
				card = waitTip(ctx, Tips, 3)
			end
			if not card then ctx:cannot("no tip card came up to press Show me on (tips.first_open covers the login tip)") end
			local okc, tipText = pcall(card.text.GetText, card.text)
			local beforeSet, beforeTexts, beforeWhere = snapshot(ctx, card)
			ctx.me:clickOn(card.show)
			ctx:note("click Show me")
			ctx:advance(1.5)
			local afterSet, afterTexts, afterWhere = snapshot(ctx, card)
			if afterWhere ~= beforeWhere or afterTexts ~= beforeTexts then return end
			for obj in pairs(afterSet) do if not beforeSet[obj] then return end end
			if not phoneShown(ctx) then return end
			ctx:fail("You press Show me on a tip card and nothing you can see happens: the card just closes.",
				"the tip: " .. tostring(okc and tipText) .. "; on " .. afterWhere .. "; " .. onScreen(ctx))
		end,
	}

	Hunt.promise{
		id = "tips.off_none",
		area = "Tips",
		text = "With Login tips off, no tip card shows when you open Wuber after logging in.",
		source = "Settings > Riding > Login tips (Off: no tips)",
		kind = "scenario",
		needs = { tipsOn = "off" },
		when = function(sit) return base(sit) and is(sit, "phone", OPENS) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, false)
			if ctx.W.db.tipsOn ~= false then ctx:cannot("the saved tipsOn = false did not reach Wuber") end
			if not phoneShown(ctx) then open(ctx) end
			for _ = 1, 6 do
				ctx:advance(1)
				if tipUp(ctx, Tips) then
					ctx:fail("Login tips are off, you open Wuber after logging in and a tip card shows.", onScreen(ctx))
				end
			end
		end,
	}
	---------------------------------------------------------------------------
	-- SHELL additions: the coach marks, "Show a tip" in Help, /wuber tips, Show me targets, never in a ride or a fight,
	-- each tip once.
	---------------------------------------------------------------------------
	local function pressAt(ctx, obj)
		local okc, cx, cy = pcall(obj.GetCenter, obj)
		local ratio = okc and cx and obj:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale() or 1
		local hit = okc and cx and ctx.me:frameAt(cx * ratio, cy * ratio) or nil
		if hit and inside(hit, obj) and pcall(ctx.me.clickOn, ctx.me, obj) then return end
		ctx.me:click(obj)
	end

	Hunt.promise{
		id = "tips.coach_marks_first",
		area = "Tips",
		text = "The first time you ever open Wuber, short first-open tips (Where to? ...) show inside it, and the login tips wait for them.",
		source = "Settings > This window > Tips (\"The first-open tips: finding, paying, driving\"); Tips.lua header (never while the coach marks show)",
		kind = "scenario",
		needs = { coach = "not_done" },
		-- (a phone that opens by itself on Trips or Drive never runs the coach: Window.lua stops it off Home, on purpose)
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and is(sit, "phone", { closed = true, splash = true, home = true, world_view = true, here_view = true }) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			if rideActiveNow(ctx) then ctx:na("a ride is on") end
			if not phoneShown(ctx) then open(ctx) end
			local coachSeen = false
			for _ = 1, 8 do
				ctx:advance(1)
				for _, t in ipairs(ctx:texts()) do if t == "Where to?" and ui(ctx).coach and ctx:visible(ui(ctx).coach) then coachSeen = true end end
				if coachSeen then break end
			end
			-- (job 2680) the Skip the bird card (a flight map open) or the What's new pop-up stands before the coach (UI.MayOpen, 2.4);
			-- a player closes it and the first-open tips must come
			if not coachSeen then
				local function up(f) return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() == true end
				local Bird = ctx:mod("UI.Bird")
				local bird = Bird and type(Bird.Card) == "function" and Bird.Card() or nil
				local b = up(bird) and ctx.me:button("Don't show again") or nil
				if not (b and ctx:visible(b)) then b = ctx.me:button("Not now") end
				if b and ctx:visible(b) then
					ctx.me:click(b)
					ctx:note("close the card that stands before the first-open tips")
					for _ = 1, 8 do
						ctx:advance(1)
						for _, t in ipairs(ctx:texts()) do if t == "Where to?" and ui(ctx).coach and ctx:visible(ui(ctx).coach) then coachSeen = true end end
						if coachSeen then break end
					end
				end
			end
			if not coachSeen then
				ctx:fail("You open Wuber for the very first time and the first-open tips (Where to?) do not show.", onScreen(ctx))
			end
			if tipUp(ctx, Tips) then
				ctx:fail("You open Wuber for the very first time and a login tip shows together with the first-open tips.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "tips.help_show_a_tip",
		area = "Tips",
		text = "Settings > Help > Show a tip shows a tip card on the Ride tab.",
		source = "Help page (\"Show a tip: A short hint on the Ride tab\"); round 26", kind = "scenario",
		when = function(sit) return base(sit) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, false)
			ctx.me:slash("/wuber help")
			ctx:advance(2.5)
			ctx:note("/wuber help")
			-- Help is a card in the settings home (folded) or a row (unfolded): open it by its words
			-- (unfolded the row reads "Help: finding drivers", in a folded window the card reads "Help: how Wuber finds drivers")
			local okh = pcall(ctx.me.clickText, ctx.me, "Help: finding drivers")
			if not okh then okh = pcall(ctx.me.clickText, ctx.me, "Help: how Wuber finds drivers") end
			ctx:advance(1)
			ctx:note("open Help")
			if not okh then ctx:cannot("no Help row on screen") end
			local okt = pcall(ctx.me.clickText, ctx.me, "Show a tip")
			if not okt then ctx:cannot("no Show a tip row in Help") end
			ctx:note("click Show a tip")
			local card = waitTip(ctx, Tips, 4)
			if not card then
				local okn, nextTip = pcall(Tips.Next)
				if okn and nextTip == nil and not (ctx.W.db.tipsSeen == nil) then ctx:na("every tip has been seen") end
				ctx:fail("You press Show a tip in Help and no tip card shows.", "tab " .. tostring(ui(ctx).tab) .. "; " .. onScreen(ctx))
			end
			if ui(ctx).tab ~= "Ride" then
				ctx:fail("You press Show a tip in Help and the tip does not show on the Ride tab.", "tab " .. tostring(ui(ctx).tab))
			end
		end,
	}

	Hunt.promise{
		id = "tips.slash_tips",
		area = "Tips",
		text = "/wuber tips turns login tips on and shows a tip now; /wuber tips off turns them off and says how to get them back.",
		source = "Commands.lua header; Settings > Login tips tooltip (\"type /wuber tips to see one now, or /wuber tips off\")", kind = "scenario",
		when = function(sit) return base(sit) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, false)
			ctx.me:slash("/wuber tips")
			ctx:advance(0.5)
			ctx:note("/wuber tips")
			if ctx.W.db.tipsOn == false then ctx:fail("You type /wuber tips and login tips stay off.") end
			local card = waitTip(ctx, Tips, 4)
			if not card then
				local okn, nextTip = pcall(Tips.Next)
				if okn and nextTip == nil then ctx:na("every tip has been seen") end
				ctx:fail("You type /wuber tips (nothing else going on) and no tip shows.", onScreen(ctx))
			end
			local n = #ctx.me.chatLines
			ctx.me:slash("/wuber tips off")
			ctx:advance(0.5)
			ctx:note("/wuber tips off")
			if ctx.W.db.tipsOn ~= false then ctx:fail("You type /wuber tips off and login tips stay on.") end
			if #ctx.me.chatLines == n then ctx:fail("You type /wuber tips off and Wuber says nothing about how to turn them back on.") end
			if not (ctx.me:said("/wuber tips") or ctx.me:said("Login tips")) then
				ctx:fail("You type /wuber tips off and the answer does not say how to turn them back on.", tostring(ctx.me.chatLines[#ctx.me.chatLines]))
			end
		end,
	}

	Hunt.promise{
		id = "tips.show_me_targets_exist",
		area = "Tips",
		text = "Show me on every tip you can get opens something and points at a thing that is really on screen.",
		source = "Tips.lua header (Show me opens the tip's screen and rings its target); TipTexts.lua", kind = "scenario",
		when = function(sit) return base(sit) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, false)
			local TT = ctx:mod("UI.TipTexts")
			if not (TT and type(TT.list) == "table") then ctx:cannot("no tip texts") end
			if not phoneShown(ctx) then open(ctx) end
			ctx:advance(2.5)
			local drives = ctx.sit.role ~= "rider" and ctx.sit.role ~= nil
			for _, tip in ipairs(TT.list) do
				if not tip.driver or drives then
					pcall(Tips.ShowNow, tip.id)
					ctx:advance(0.8)
					local card = tipUp(ctx, Tips)
					if card then
						ctx:note("tip " .. tip.id .. ": click Show me")
						pressAt(ctx, card.show)
						ctx:advance(1.2)
						local target = TT.Target(tip)
						if not target or not ctx:visible(target) then
							ctx:fail(("You press Show me on the tip \"%s\" and the thing it should point at is not on screen."):format(tip.text:sub(1, 60)),
								"tip " .. tip.id .. " (screen " .. tostring(tip.screen) .. ", target " .. tostring(tip.target) .. "); tab " .. tostring(ui(ctx).tab) .. "; " .. onScreen(ctx))
						end
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "tips.none_in_ride_or_fight",
		area = "Tips",
		text = "No tip card shows while you have a ride going or are in a fight.",
		source = "Tips.lua header (never in combat, never during a ride)", kind = "scenario",
		when = function(sit)
			return sit.session ~= "first" and is(sit, "coach", "done") and sit.tipsOn ~= "off" and (not is(sit, "ride", "none") or not is(sit, "combat", "no"))
				and is(sit, "phone", OPENS)
		end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			local busy = ctx.me.player.combat or rideActiveNow(ctx)
			if not busy then ctx:na("neither a ride nor a fight here") end
			if ctx.W.db.tipsOn == false then ctx:na("login tips are off") end
			if not phoneShown(ctx) then open(ctx) end
			for _ = 1, 6 do
				ctx:advance(1)
				if tipUp(ctx, Tips) then
					ctx:fail(ctx.me.player.combat and "You are in a fight, open Wuber, and a tip card shows." or "You have a ride going, open Wuber, and a tip card shows.", onScreen(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "tips.each_once",
		area = "Tips",
		text = "Next tip never shows the same tip twice.",
		source = "Settings > Login tips tooltip (\"each only once\")", kind = "scenario",
		when = function(sit) return base(sit) and sit.tipsOn ~= "off" and is(sit, "phone", OPENS) end,
		check = function(ctx)
			local Tips = tipsMod(ctx)
			conditions(ctx, true)
			if not phoneShown(ctx) then open(ctx) end
			local card = waitTip(ctx, Tips, 8)
			if not card then ctx:na("no tip came up (tips.first_open covers that)") end
			local seen = {}
			for i = 1, 20 do
				local okc, text = pcall(card.text.GetText, card.text)
				if okc and type(text) == "string" then
					if seen[text] then ctx:fail("You press Next tip again and again and the same tip comes back.", text:sub(1, 80)) end
					seen[text] = true
				end
				if not (card.next and ctx:visible(card.next)) then break end
				pressAt(ctx, card.next)
				ctx:advance(0.8)
				ctx:note("click Next tip")
				card = tipUp(ctx, Tips)
				if not card then break end
			end
		end,
	}
end
