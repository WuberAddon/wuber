-- Promises from the bug hunt's second lead list (owner: LEADS-2). Each is a review lead (two places of Wuber that disagree)
-- that a read of the code showed to be a real player-facing difference. Ids: leads.c###_short_name.
return function(Hunt)
	local function fxPlaying(ctx)
		local FX = ctx.W.FX
		if type(FX) ~= "table" or type(FX.Stats) ~= "function" then ctx:cannot("no FX.Stats") end
		return FX.Stats().playing or 0
	end

	Hunt.promise{
		id = "leads.c076_reload_replays_portal",
		area = "Effects",
		text = "After a /reload while your summon is up, the full-screen portal does not play again.",
		source = "Google lead C076: FX/Moments.lua:184-193 (seen[] set at login) vs Net/Inbox.lua:198-207 (restoreRide fires RIDE first)",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning", fx = "full", combat = "no" },
		check = function(ctx)
			local r = ctx.W.ride
			if not (r and r.state == "portal") then ctx:na("the ride is not at the portal state") end
			ctx:advance(5)
			local before = fxPlaying(ctx)
			ctx:reload()
			ctx:advance(0.2)
			local r2 = ctx.W.ride
			if not (r2 and r2.state == "portal") then ctx:na("the ride was not restored at the portal") end
			local after = fxPlaying(ctx)
			if after > 0 then
				ctx:fail("You reload your game while the summon is up and the full-screen portal effect plays all over again.", "effects playing after reload: " .. after .. " (before: " .. before .. ")")
			end
		end,
	}
	local function kit(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end

	Hunt.promise{
		id = "leads.c077_reload_hides_later_portal",
		area = "Effects",
		text = "If you reload while your ride is only requested, the portal effect still plays when the portal opens later.",
		source = "Google lead C077: FX/Moments.lua:186-191 (seen[id:portal] set for any saved ride) vs FX/Moments.lua:71-76",
		kind = "scenario",
		needs = { role = "rider", ride = "requested", fx = "full", combat = "no" },
		check = function(ctx)
			local r = ctx.W.ride
			if not (r and r.state == "accepted" or r and r.state == "requested") then ctx:na("the ride is not at requested or accepted") end
			ctx:reload()
			ctx:advance(0.5)
			local r2 = ctx.W.ride
			if not r2 then ctx:na("the ride was not restored") end
			if fxPlaying(ctx) > 0 then ctx:na("an effect played at the reload already") end
			-- the summon box comes up (what the network does at the portal state)
			r2.state = "portal"
			ctx.W.Fire("RIDE", r2)
			ctx:advance(0.3)
			if fxPlaying(ctx) == 0 then
				ctx:fail("You reload your game before the portal is up, and when your summon portal opens there is no portal effect.", "state poked to portal after the reload; no effect playing")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c094_minimap_pulse_effects_off",
		area = "Effects",
		text = "With Effects set to Off only the minimap button still pulses while your summon is up: no portal or other effect plays. (job 146: the author kept the minimap pulse and corrected the words, round 46, CHANGELOG-2.3.4 line 320.)",
		source = "Google lead C094: Settings/Panel.lua:371 (Off: nothing moves) vs UI/Minimap.lua:128-141, Theme/Anim.lua:416-474",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning", fx = "off", phone = "closed" },
		check = function(ctx)
			local m = kit(ctx).minimap
			if not (m and m.pulse) then ctx:na("no minimap button with a pulse in the fake game") end
			local UI = ctx.W.UI
			if UI.IsShown and UI.IsShown() then ctx:na("the phone is open") end
			ctx:advance(1)
			-- (job 146: the minimap pulse is allowed; every other effect must be quiet)
			local n = fxPlaying(ctx)
			if n > 0 then
				ctx:fail("Effects is Off and your summon is up, and an effect still plays on the screen.", "FX playing: " .. tostring(n))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c095_minimap_pulse_after_closing",
		area = "Minimap",
		text = "While your summon is up and the window is closed, the minimap button pulses (also after you opened the window and closed it again).",
		source = "Google lead C095: UI/Minimap.lua:126 (pulse while the summon is up and the window is closed) vs UI/Moments.lua:49-52,78, UI/Window.lua:503, UI/Minimap.lua:151-152",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning", fx = "full" },
		check = function(ctx)
			local m = kit(ctx).minimap
			if not (m and m.pulse) then ctx:na("no minimap button with a pulse in the fake game") end
			local UI = ctx.W.UI
			if not (UI.IsShown and UI.Toggle) then ctx:cannot("no UI.IsShown / UI.Toggle") end
			if not UI.IsShown() then UI.Toggle(true) ctx:advance(1) end
			UI.Toggle(false) -- the player closes the window again
			ctx:advance(1)
			if UI.IsShown() then ctx:na("the window did not close") end
			local r = ctx.W.ride
			if not (r and r.state == "portal") then ctx:na("the summon is no longer up") end
			if not m.pulse.running then
				ctx:fail("Your summon is up and you closed the Wuber window, and the minimap button does not pulse.", "pulse not running, window closed, portal up")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c075_light_has_fullscreen",
		area = "Effects",
		text = "With Effects set to Light there are no full-screen effects (Settings says: Light: no full-screen effects, still badges).",
		source = "Google lead C058/C075: Settings/Panel.lua:371,374 vs FX/Effects.lua:1098-1119 (FX.Fullscreen plays in light mode)",
		kind = "scenario",
		needs = { fx = "light", combat = "no" },
		check = function(ctx)
			local FX = ctx.W.FX
			if type(FX) ~= "table" or type(FX.Fullscreen) ~= "function" then ctx:cannot("no FX.Fullscreen") end
			-- the screen moments the addon plays for a paid ride, a rating and a portal all go through this call
			local h = FX.Fullscreen("paid")
			if h ~= nil then
				ctx:fail("You set Effects to Light, which says no full-screen effects, and a full-screen effect plays anyway.", "FX.Fullscreen(\"paid\") returned a handle in light mode")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c068_usual_counts_unpaid",
		area = "Home",
		text = "A ride that ended without paying counts for nothing, so it never becomes your usual driver and place.",
		source = "Google lead C068: Core/Stats.lua:63-65 (unpaid counts for nothing) vs Net/Favourites.lua:201-213 (W.Usual counts every trip)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived", saved = "fresh" },
		check = function(ctx)
			local W = ctx.W
			if type(W.Usual) ~= "function" or type(W.EndRide) ~= "function" then ctx:cannot("no W.Usual / W.EndRide") end
			if not W.EndRide("rider") then ctx:na("the ride could not be ended by hand") end
			ctx:advance(1)
			local last = W.db.rides[#W.db.rides]
			if not (last and last.unpaid) then ctx:na("the ended ride was not saved as unpaid") end
			local paid = 0
			for _, t in ipairs(W.db.rides) do if not t.unpaid then paid = paid + 1 end end
			if paid > 0 then ctx:na("the rider has paid trips too") end
			local u = W.Usual()
			if u then
				ctx:fail("You end your only ride without paying (End ride) and Wuber already treats that driver and place as your usual.", "W.Usual() -> " .. tostring(u.driver) .. " to " .. tostring(u.dest) .. ", count " .. tostring(u.count))
			end
		end,
	}
	Hunt.promise{
		id = "leads.c054_shift_open_counts_pause",
		area = "Earnings",
		text = "The Shift complete card's open time (labelled 'open, not paused') leaves out the time you were paused.",
		source = "Google lead C054: UI/Driver/Sheets.lua:889-890 ('open, not paused') vs Drive/Log.lua:677-709 (shift = wall clock while DR.Selling) and Drive/Service.lua:57-61",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", combat = "no" },
		check = function(ctx)
			local DR = ctx.W.Drive
			if not (DR and DR.IsOpen and DR.SetPaused and DR.SetOpen and DR.ShiftSummary) then ctx:cannot("the Drive API is missing") end
			if not DR.IsOpen() then ctx:na("the driver is not open") end
			DR.ShiftCheck()
			ctx:advance(600)   -- ten minutes open
			local ok = DR.SetPaused(true)
			if not ok then ctx:na("pause refused") end
			for _ = 1, 50 do ctx:advance(60) end -- fifty minutes paused
			DR.SetPaused(false)
			ctx:advance(600)   -- ten minutes open again
			DR.SetOpen(false)  -- the player closes: the shift ends
			ctx:advance(1)
			local s = DR.ShiftSummary()
			if not s then ctx:na("no shift summary") end
			local mins = s.open / 60
			if mins > 30 then
				ctx:fail("Your shift card says you were open " .. math.floor(mins + 0.5) .. " minutes ('open, not paused') but you were open for 20 minutes and paused for 50.", "ShiftSummary().open = " .. s.open .. " s")
			end
		end,
	}
	local function line(n, seed)
		local words = "Quick friendly summons to Ratchet with no waiting around hop in and I bring you straight over safe and quick tips welcome thanks for riding see you soon at the stone cheers my friends and see you again soon "
		local s = (seed or "") .. words
		while #s < n + 20 do s = s .. words end
		return (s:sub(1, n):gsub("%s+$", "x"))
	end

	Hunt.promise{
		id = "leads.c078_second_payment_burst",
		area = "Effects",
		text = "Every payment you take in a trade gets its coin burst, even two riders paying a few seconds apart.",
		source = "Google lead C078: FX/Moments.lua:121-139 (one global FX.paidAt, 5 s) vs the comment 'once per payment'",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", fx = "full", combat = "no" },
		check = function(ctx)
			local FX, W = ctx.W.FX, ctx.W
			if type(FX) ~= "table" or type(FX.OnDrivePaid) ~= "function" then ctx:cannot("no FX.OnDrivePaid") end
			local n = 0
			local real = FX.Fullscreen
			FX.Fullscreen = function(...) n = n + 1 return real(...) end
			local me = W.myKey or W.Key(W.Me())
			W.Fire("DRIVE_PAID", "Una Hale", 5000, 0, me, true, "t", 5000)
			ctx:advance(2)
			W.Fire("DRIVE_PAID", "Vic Moor", 5000, 0, me, true, "t", 5000)
			ctx:advance(0.2)
			FX.Fullscreen = real
			if n < 2 then
				ctx:fail("Two riders pay you by trade two seconds apart and only the first payment gets a coin burst.", "full-screen bursts: " .. n)
			end
		end,
	}

	Hunt.promise{
		id = "leads.c087_crew_member_message_not_shared",
		area = "Messages",
		text = "Only the captain's save in Messages reaches the crew windows ('Saved - your crew uses it too'); a crew member's save stays in their own window and its toast makes no claim about the crew. (job 146: round 32 reworded the toast: a member sees only 'Saved', Messages.lua:266-270.)",
		source = "Google lead C087: UI/Driver/Messages.lua:239 vs Drive/Team.lua:626,677-682 (TPL only from the captain or group leader); round 32 (the toast says only Saved for a member)",
		kind = "scenario",
		needs = { role = "crew", ride = "none", combat = "no" },
		check = function(ctx)
			local DR = ctx.W.Drive
			local cap = ctx.peers and ctx.peers.driver
			if not (DR and DR.SetTemplate and cap and cap.W and cap.W.Drive) then ctx:cannot("no crew window to compare with") end
			if cap.W.Drive.IsLeader and not cap.W.Drive.IsLeader() then ctx:na("the captain is not the group leader") end
			local isMember = type(DR.char) == "function" and tostring((DR.char() or {}).captain or "") ~= ""
			if not isMember then ctx:na("this window is not a crew member's") end
			local Sc = ctx:mod("UI.Driver.Screens")
			local scr = Sc and Sc.st and Sc.st.screens and Sc.st.screens.messages
			local mine = "Thanks for riding with us, see you again soon"
			if scr and scr.edit and scr.editor and scr.editor.field and scr.editor.save then
				-- a player opens the Thanks message, types it and taps Save; the toast says only 'Saved'
				pcall(scr.edit, "thanks")
				scr.editor.field:SetText(mine)
				local before = #ctx.me.chatLines
				local okc, saveErr = pcall(ctx.me.click, ctx.me, scr.editor.save)
				ctx:note("tap Save on the Thanks message")
				ctx:advance(0.5)
				for _, t in ipairs(ctx:texts()) do
					if t:find("your crew uses it too", 1, true) then
						ctx:fail("You are a crew member, you save a message and the toast says 'your crew uses it too'; only the captain's save reaches the crew.", t)
					end
				end
				if not okc then ctx:note("Save tap failed: " .. tostring(saveErr)) end
			else
				if not DR.SetTemplate("thanks", mine) then ctx:na("the message was refused") end
			end
			ctx:advance(3)
			local theirs = cap.W.Drive.Template("thanks")
			-- (a member's save staying with the member is the promise now; the captain's own text must not have changed to it)
			if theirs == mine then
				ctx:fail("A crew member saves a message and the captain's window changes to it: only the captain's save is meant to reach the crew.", "captain's thanks text: " .. tostring(theirs))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c088_crew_advert_cut_at_190",
		area = "Messages",
		text = "An advert line of up to 200 characters that the captain saves reaches the crew windows whole. (job 146: only when the captain leads the group; the template is taken only from the leader or captain, Team.lua:693.)",
		source = "Google lead C088: Drive/Chat.lua:38,353 (advert up to 200, sent as TPL) vs Drive/Queue.lua:1096-1102 (received TPL cleaned at DR.TEXT_MAX 190)",
		kind = "scenario",
		needs = { role = "crew", ride = "none", combat = "no" },
		check = function(ctx)
			local DR = ctx.W.Drive
			local cap = ctx.peers and ctx.peers.driver
			if not (DR and DR.Template and cap and cap.W and cap.W.Drive and cap.W.Drive.SetTemplate) then ctx:cannot("no crew window") end
			-- (job 146: the crew window takes a template only from the leader or captain, as IT sees them, Team.lua:752; with group=party/raid someone else may lead the group, so the captain's text is then not taken)
			do
				local k = ctx.W.Key(cap.player and cap.player.name or cap.name or "")
				local seen = DR.IsLeaderKey and DR.IsLeaderKey(k) -- (the group's leader as this window sees them; being only the crew's captain is not enough here)
				if not seen then ctx:na("this crew window does not see the captain as the leader or captain of the group, so it takes no template from them") end
			end
			local text = line(198, "A ")
			local ok = cap.W.Drive.SetTemplate("advert", text)
			if not ok then ctx:na("the captain's window refused the advert line") end
			ctx:advance(3)
			local got = DR.Template("advert")
			if got == text then return end
			if got == nil or #got == 0 or #got >= #text then ctx:na("the crew window has: " .. tostring(got)) end
			ctx:fail("The captain saves an advert line of " .. #text .. " characters and the crew window ends up with " .. #got .. ": the end is cut off.", "crew text length " .. #got .. ": " .. got)
		end,
	}

	Hunt.promise{
		id = "leads.c089_advert_cut_by_tag",
		area = "Messages",
		text = "An advert line the Messages editor accepts (up to 200 characters, the counter never goes red) is posted whole after '[Wuber] '.",
		source = "Google lead C089: UI/Driver/Messages.lua:72,299-307 (limit 200, no tag in the count) vs Net/Outreach.lua:159-172 (the line plus '[Wuber] ' cut at 200)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		check = function(ctx)
			local DR, W = ctx.W.Drive, ctx.W
			if not (DR and DR.SetTemplate and W.AdvertOwnText) then ctx:cannot("no advert API") end
			local text = line(200, "B ")
			if not DR.SetTemplate("advert", text) then ctx:na("the editor's rule refused a 200 character line") end
			local out = W.AdvertOwnText(DR.Template("advert"))
			if not out then ctx:na("no advert line built") end
			if not out:find(text, 1, true) then
				ctx:fail("You write an advert line of exactly " .. #text .. " characters (the limit Messages shows) and the line posted in chat is cut short by " .. (#text + 8 - #out) .. " characters.", "posted " .. #out .. " bytes: " .. out)
			end
		end,
	}
	Hunt.promise{
		id = "leads.c101_plates_button_toast",
		area = "Settings",
		text = "When Settings' button can't turn friendly nameplates on, the message you are left with says to press Shift+V.",
		source = "Google lead C101: FX/Nameplates.lua:403-419 (own toast with Shift+V) vs UI/Settings/Rows.lua:256-272 (a second toast replaces it)",
		kind = "scenario",
		needs = { combat = "no" },
		check = function(ctx)
			local Rows = ctx:mod("UI.Settings.Rows")
			if not (Rows and type(Rows.turnOnPlates) == "function") then ctx:cannot("no Settings button handler") end
			local P = ctx.W.Plates
			if type(P) ~= "table" or type(P.FriendlyPlatesOn) ~= "function" then ctx:cannot("no W.Plates") end
			-- the client does not know the friendly nameplate switches (the button cannot work)
			local cv = ctx.w and ctx.w.cvars
			if type(cv) ~= "table" then ctx:cannot("no world cvars") end
			cv.nameplateShowFriends, cv.nameplateShowFriendlyPlayers = nil, nil
			rawset(ctx.me.cvars, "nameplateShowFriends", nil)
			Rows.turnOnPlates()
			ctx:advance(0.5)
			local shown = table.concat(ctx:texts(), " | ")
			if shown:find("Friendly nameplates are on", 1, true) then ctx:na("the game let the button switch them on") end
			if not shown:find("Shift", 1, true) then
				ctx:fail("You tap the nameplates button in Settings, it can't switch them on, and the message you are left with does not tell you to press Shift+V.", shown)
			end
		end,
	}
	Hunt.promise{
		id = "leads.c097_trade_toast_leaves_out_tip",
		area = "Pay",
		text = "The 'Trade <driver> <amount>' toast names the same amount as the pay card (the fare plus the tip you chose).",
		source = "Google lead C097: UI/Moments.lua:69-70 (toast uses the bare price and the driver) vs UI/Rider/Pay.lua:35,91-95 (PayTotal drives every payment line)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived" },
		pre = function(ctx)
			local s = ctx.saved
			if type(s) ~= "table" then s = {} ctx.saved = s end
			if type(s.Wuber) ~= "table" then
				if s.chars ~= nil or s.rides ~= nil or s.fx ~= nil then s.tipPct = 20 return end
				s.Wuber = {}
			end
			s.Wuber.tipPct = 20
		end,
		check = function(ctx)
			local UI = ctx.W.UI
			local n = ctx.facts.payee or ctx.facts.driverName
			local drv = n and ctx.w:player(n)
			if not drv then ctx:cannot("no driver player to trade with") end
			if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(0.5) end
			if not ctx.w:openTrade(drv, ctx.me.player) then ctx:cannot("could not open a trade with the driver") end
			ctx:note("the driver opens a trade with me")
			ctx:advance(0.5)
			local rv = ctx:mod("UI.Kit") and ctx:mod("UI.Kit").rideView and ctx:mod("UI.Kit").rideView()
			if not (rv and (rv.state == "paying" or rv.state == "arrived")) then ctx:na("the ride is not at the trade") end
			if (UI.TipPct and UI.TipPct() or 0) <= 0 then ctx:na("no tip chosen in this build") end
			local total = UI.PayTotal(rv)
			if total <= (rv.price or 0) then ctx:na("no tip in the total") end
			local sought = "Trade " .. tostring(rv.short) .. " " .. ctx.W.Money(rv.price)
			local want = ctx.W.Money(total)
			local shown
			for _, t in ipairs(ctx:texts()) do if t:find("^Trade ") then shown = t end end
			if not shown then ctx:na("the toast is no longer up") end
			if not shown:find(want, 1, true) then
				ctx:fail("The toast says '" .. shown .. "' but the pay card asks you to type " .. want .. " (fare plus your tip).", sought)
			end
		end,
	}
end
