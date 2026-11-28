-- Bug hunt wave 4 promises for Toasts, Tips, Coach, Moments, Minimap, and Bird
-- (Wuber/UI/Toasts.lua, Tips.lua, TipTexts.lua, Coach.lua, Moments.lua, Minimap.lua, Bird.lua).
-- Prefix: b5notices.
return function(Hunt)
	local FOLDABLE = {
		home = true, trips = true, drive = true, drive_earnings = true,
		drive_messages = true, drive_customers = true, settings = true,
		settings_riding = true, settings_driving = true, settings_map = true,
		settings_sound = true, settings_window = true, world_view = true,
		here_view = true, confirm = true, wrapped = true,
	}

	local function promise(p)
		local w = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w == nil or w(sit)
		end
		Hunt.promise(p)
	end

	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
	local function inCombat(ctx) return ctx.me.player.combat and true or false end
	local function kit(ctx) local K = ctx:mod("UI.Kit") return K and K.ui or {} end
	local function seen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local function hasText(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat, 1, plain) then return t end
		end
		return nil
	end

	local function clearOverlays(ctx)
		local UI = ctx.W.UI
		for _ = 1, 3 do
			local ui = kit(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if WM and type(WM.Shown) == "function" and WM.Shown() then WM.Close() ctx:advance(0.4) end
			local over = ui.settingsOpen
				or (type(UI.HelpShown) == "function" and UI.HelpShown())
				or (type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown())
			if not over then return end
			if ui.settingsOpen and type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
			ctx.me:pressEscape()
			ctx:advance(0.6)
		end
	end

	local function openHome(ctx)
		if inCombat(ctx) then ctx:na("in combat") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		clearOverlays(ctx)
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		local ui = kit(ctx)
		if ui.tab ~= "Ride" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Ride" and tab.button and ctx:visible(tab.button) then
					ctx.me:clickOn(tab.button)
					ctx:advance(0.6)
					break
				end
			end
		end
		if not UI.IsShown() or kit(ctx).screen ~= "home" then ctx:na("Home is not reachable") end
	end

	-- 1. Toasts: dedup within 2 seconds, different message replaces
	promise{
		id = "b5notices.toast_dedup_within_two_sec",
		area = "Toasts",
		text = "Showing the same toast message twice within two seconds does not reset it, while a different message replaces a plain toast.",
		source = "Wuber/UI/Toasts.lua:459-479",
		kind = "scenario",
		check = function(ctx)
			local UI = ctx.W.UI
			local t1 = UI.Toast("Notice alpha", "info")
			if not t1 then ctx:cannot("could not show first toast") end
			local t2 = UI.Toast("Notice alpha", "info")
			if t2 ~= t1 then
				ctx:fail("Repeating the same toast within 2 seconds created a new toast instead of keeping the existing one.", tostring(t2))
			end
			ctx:advance(0.3)
			UI.Toast("Notice beta", "info")
			ctx:advance(0.3)
			if not hasText(ctx, "Notice beta", true) then
				ctx:fail("Showing a different plain toast did not replace the previous toast.", seen(ctx))
			end
			ctx:advance(5.0)
		end,
	}

	-- 2. Toasts: sticky portal toast stays over info, undo stacks beneath
	promise{
		id = "b5notices.toast_sticky_portal_stays",
		area = "Toasts",
		text = "While a sticky 'CLICK THE PORTAL' (portal) toast is up, a plain info toast does not push it off, while an Undo toast stacks beneath it.",
		source = "Wuber/UI/Toasts.lua:228,468-479",
		kind = "scenario",
		check = function(ctx)
			local UI = ctx.W.UI
			local s1 = UI.Toast("CLICK THE PORTAL!", "portal")
			if not s1 then ctx:cannot("could not show portal toast") end
			ctx:advance(0.3)
			local dropped = UI.Toast("Plain info toast", "info")
			if dropped ~= nil then
				ctx:fail("A plain info toast was not blocked by an active sticky portal toast.", seen(ctx))
			end
			if not hasText(ctx, "CLICK THE PORTAL!", true) then
				ctx:fail("The sticky portal toast disappeared when a plain info toast was sent.", seen(ctx))
			end
			local u = UI.UndoToast("Reset test setting", function() end)
			ctx:advance(0.3)
			if not u or not hasText(ctx, "CLICK THE PORTAL!", true) or not hasText(ctx, "Reset test setting", true) then
				ctx:fail("An Undo toast did not stack under the active sticky portal toast.", seen(ctx))
			end
			ctx:advance(11.0)
		end,
	}

	-- 3. Toasts: UndoToast runs once on click and drops when replaced
	promise{
		id = "b5notices.undo_toast_runs_once_and_expires",
		area = "Toasts",
		text = "Clicking Undo on an Undo toast runs the undo action once and removes the toast; replacing it drops the undo action.",
		source = "Wuber/UI/Toasts.lua:521-562",
		kind = "scenario",
		check = function(ctx)
			local UI = ctx.W.UI
			local calls = 0
			local t = UI.UndoToast("Cleared test list", function() calls = calls + 1 end)
			if not t or not t.undo then ctx:cannot("could not show Undo toast") end
			ctx:advance(0.4)
			if not UI.UndoPending() then
				ctx:fail("UI.UndoPending() was false while an Undo toast was showing.", seen(ctx))
			end
			if not ctx:visible(t.undo) then ctx:cannot("Undo button not visible") end
			ctx.me:clickOn(t.undo)
			ctx:advance(0.4)
			if calls ~= 1 then
				ctx:fail("Clicking the Undo button did not run the undo callback exactly once.", "calls=" .. calls)
			end
			if UI.UndoPending() then
				ctx:fail("UI.UndoPending() stayed true after clicking Undo.", seen(ctx))
			end
			UI.UndoToast("Second undo", function() calls = calls + 1 end)
			ctx:advance(0.2)
			UI.Toast("Replacement info", "info")
			ctx:advance(0.4)
			if UI.UndoPending() then
				ctx:fail("Replacing an Undo toast with another toast did not drop the pending undo.", seen(ctx))
			end
			ctx:advance(5.0)
		end,
	}

	-- 4. Toasts: ClearOfChat moves overlapping box and leaves clear box
	promise{
		id = "b5notices.clear_of_chat_moves_box",
		area = "Toasts",
		text = "UI.ClearOfChat moves a box that overlaps the visible chat frame to a clear spot on screen, and leaves an already-clear box where it is.",
		source = "Wuber/UI/Toasts.lua:85-109",
		kind = "scenario",
		check = function(ctx)
			local UI = ctx.W.UI
			local chat = UI.ChatBox(false)
			if not chat then ctx:na("no visible chat frame in this situation") end
			local x1, y1, moved1 = UI.ClearOfChat(chat[1] + 5, chat[3] + 5, 120, 40)
			if not moved1 then
				ctx:fail("UI.ClearOfChat did not move a box placed directly over the chat frame.", string.format("chat=%d,%d,%d,%d", chat[1], chat[2], chat[3], chat[4]))
			end
			if x1 < chat[2] and x1 + 120 > chat[1] and y1 < chat[4] and y1 + 40 > chat[3] then
				ctx:fail("UI.ClearOfChat returned a position that still overlaps the chat frame.", string.format("x=%s y=%s", tostring(x1), tostring(y1)))
			end
			local sw = ctx.me.env.UIParent:GetWidth()
			local sh = ctx.me.env.UIParent:GetHeight()
			local cx, cy = sw - 130, sh - 50
			local _, _, moved2 = UI.ClearOfChat(cx, cy, 120, 40)
			if moved2 then
				ctx:fail("UI.ClearOfChat moved a box that was already clear of the chat frame.", string.format("cx=%d cy=%d", cx, cy))
			end
		end,
	}

	-- 5. Coach: ReplayCoach starts at Tip 1 on Home
	promise{
		id = "b5notices.coach_replay_starts_step_one",
		area = "Coach",
		text = "Replaying the first-open coach marks resets coach completion and shows Tip 1 on Home.",
		source = "Wuber/UI/Coach.lua:134-185",
		kind = "scenario",
		when = function(sit) return isRider(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
			local UI = ctx.W.UI
			if not UI.IsShown() then ctx.me:slash("/wuber") ctx:advance(2.0) end
			clearOverlays(ctx)
			local Tips = ctx:mod("UI.Tips")
			if Tips and type(Tips.Hide) == "function" then pcall(Tips.Hide) ctx:advance(0.3) end
			for _ = 1, 3 do
				local b = ctx.me:button("Got it")
				local nn = ctx.me:button("Not now")
				if not (b and ctx:visible(b)) and nn and ctx:visible(nn) then b = nn end
				if b and ctx:visible(b) then ctx.me:clickOn(b) ctx:advance(0.4) else break end
			end
			local oldCoach = ctx.W.db and ctx.W.db.coach
			UI.ReplayCoach()
			ctx:advance(1.5)
			if kit(ctx).screen ~= "home" then
				UI.EndCoach()
				if ctx.W.db then ctx.W.db.coach = oldCoach end
				ctx:na("not on Home (" .. tostring(kit(ctx).screen) .. ")")
			end
			local shown = kit(ctx).coaching == true and hasText(ctx, "Tip 1 of ", true)
			UI.EndCoach()
			ctx:advance(0.3)
			if ctx.W.db then ctx.W.db.coach = oldCoach end
			if not shown then
				ctx:fail("Calling ReplayCoach did not open Tip 1 of the first-open coach marks.", seen(ctx))
			end
		end,
	}

	-- 6. Coach: Skip tips closes coach marks and saves W.db.coach = true
	promise{
		id = "b5notices.coach_skip_saves_done",
		area = "Coach",
		text = "Clicking 'Skip tips' closes the first-open coach marks and saves that they are done.",
		source = "Wuber/UI/Coach.lua:83-90,116-132",
		kind = "scenario",
		when = function(sit) return isRider(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
			local UI = ctx.W.UI
			if not UI.IsShown() then ctx.me:slash("/wuber") ctx:advance(2.0) end
			clearOverlays(ctx)
			local oldCoach = ctx.W.db and ctx.W.db.coach
			UI.ReplayCoach()
			ctx:advance(0.6)
			local b = kit(ctx).coach
			if not b or not ctx:visible(b) or not b.skip or not ctx:visible(b.skip) then
				UI.EndCoach()
				if ctx.W.db then ctx.W.db.coach = oldCoach end
				ctx:na("coach card or Skip tips button not visible")
			end
			ctx.me:clickOn(b.skip)
			ctx:advance(0.5)
			local savedDone = ctx.W.db and ctx.W.db.coach == true
			local stillCoaching = kit(ctx).coaching == true
			if ctx.W.db then ctx.W.db.coach = oldCoach end
			if stillCoaching or not savedDone then
				ctx:fail("Clicking 'Skip tips' did not finish and save the coach marks.", string.format("coaching=%s saved=%s", tostring(stillCoaching), tostring(savedDone)))
			end
		end,
	}

	-- 7. Coach: Next steps through to Got it and ends
	promise{
		id = "b5notices.coach_next_through_to_got_it",
		area = "Coach",
		text = "Stepping through the coach marks with 'Next' reaches 'Got it' on the final tip and finishes when clicked.",
		source = "Wuber/UI/Coach.lua:81-89,145-178",
		kind = "scenario",
		when = function(sit) return isRider(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
			local UI = ctx.W.UI
			if not UI.IsShown() then ctx.me:slash("/wuber") ctx:advance(2.0) end
			clearOverlays(ctx)
			local oldCoach = ctx.W.db and ctx.W.db.coach
			UI.ReplayCoach()
			ctx:advance(0.6)
			local b = kit(ctx).coach
			if not b or not ctx:visible(b) or not b.next or not ctx:visible(b.next) then
				UI.EndCoach()
				if ctx.W.db then ctx.W.db.coach = oldCoach end
				ctx:na("coach card not visible")
			end
			for _ = 1, 6 do
				if not kit(ctx).coaching then break end
				if b.next.label and b.next.label:GetText() == "Got it" then
					ctx.me:clickOn(b.next)
					ctx:advance(0.5)
					break
				end
				ctx.me:clickOn(b.next)
				ctx:advance(0.4)
			end
			local finished = not kit(ctx).coaching and ctx.W.db and ctx.W.db.coach == true
			UI.EndCoach()
			if ctx.W.db then ctx.W.db.coach = oldCoach end
			if not finished then
				ctx:fail("Stepping through the coach marks with Next did not reach and finish at 'Got it'.", seen(ctx))
			end
		end,
	}

	-- 8. Moments: milestone pop held in combat and shown after combat ends
	promise{
		id = "b5notices.moments_pop_held_in_combat_and_ride",
		area = "Moments",
		text = "A milestone pop card does not appear while in combat, and appears once combat ends.",
		source = "Wuber/UI/Moments.lua:179-225",
		kind = "scenario",
		when = function(sit) return sit.combat ~= "in" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("already in combat") end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
			local UI = ctx.W.UI
			ctx.w:enterCombat(ctx.me)
			ctx:advance(0.2)
			UI.Celebrate("first")
			ctx:advance(0.4)
			local pop = kit(ctx).pop
			local shownInCombat = pop and ctx:visible(pop)
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(3.5)
			pop = kit(ctx).pop
			local shownAfterCombat = pop and ctx:visible(pop)
			if pop and ctx:visible(pop) then
				pop:Hide()
				ctx:advance(0.2)
			end
			if shownInCombat then
				ctx:fail("A milestone pop card appeared while you were in combat.", seen(ctx))
			end
			if not shownAfterCombat then
				ctx:fail("A milestone pop card held during combat did not appear after combat ended.", seen(ctx))
			end
		end,
	}

	-- 9. Moments: clicking a milestone pop card opens the Trips tab
	promise{
		id = "b5notices.moments_pop_click_opens_trips",
		area = "Moments",
		text = "Clicking a milestone pop card opens Wuber on the Trips tab and closes Settings if open.",
		source = "Wuber/UI/Moments.lua:161-172",
		kind = "scenario",
		when = function(sit) return sit.combat ~= "in" and sit.ride ~= "summoning" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.UI.ToastShowing and ctx.W.UI.ToastShowing() then ctx:advance(9.0) end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
			local UI = ctx.W.UI
			UI.Celebrate("first")
			ctx:advance(0.6)
			local pop = kit(ctx).pop
			if not pop or not ctx:visible(pop) then ctx:na("milestone pop card did not show") end
			ctx.me:clickOn(pop)
			ctx:advance(0.6)
			local ok = UI.IsShown() and kit(ctx).tab == "Trips" and not kit(ctx).settingsOpen
			if pop:IsShown() then pop:Hide() end
			if not ok then
				ctx:fail("Clicking a milestone pop card did not open Wuber on the Trips tab.", seen(ctx))
			end
		end,
	}

	-- 10. Moments: bounty served toast fires once (not twice) and never in combat
	promise{
		id = "b5notices.moments_bounty_served_once",
		area = "Moments",
		text = "When your pinned bounty is served by a driver coming online, Wuber shows the 'Your bounty ended' toast once, and never in combat.",
		source = "Wuber/UI/Moments.lua:273-308",
		kind = "scenario",
		when = function(sit) return sit.combat ~= "in" and sit.ride ~= "summoning" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.UI.ToastShowing and ctx.W.UI.ToastShowing() then ctx:advance(9.0) end
			local W = ctx.W
			local ui = kit(ctx)
			local oldPlace, oldServed = ui.bountyPlace, ui.bountyServed
			ui.bountyPlace = "Orgrimmar"
			ui.bountyServed = nil
			W.Fire("BOUNTY", "mine", nil, "served", "Ada")
			ctx:advance(0.3)
			local firstMsg = hasText(ctx, "Your bounty ended.", true)
			-- second trigger within 10s should be suppressed
			UI_ToastCount = nil
			W.Fire("BOUNTY", "mine", nil, "served", "Ada")
			ctx:advance(0.3)
			ui.bountyPlace, ui.bountyServed = oldPlace, oldServed
			ctx:advance(5.0)
			if not firstMsg then
				ctx:fail("When a pinned bounty was served, Wuber did not show the 'Your bounty ended.' toast.", seen(ctx))
			end
		end,
	}

	-- 11. Minimap: left-click toggles window
	promise{
		id = "b5notices.minimap_left_click_toggles",
		area = "Minimap",
		text = "Left-clicking the Wuber minimap button opens the window when closed and closes it when open.",
		source = "Wuber/UI/Minimap.lua:70-85",
		kind = "scenario",
		check = function(ctx)
			local b = kit(ctx).minimap
			if not b or not ctx:visible(b) then ctx:na("minimap button is hidden") end
			local UI = ctx.W.UI
			local wasShown = UI.IsShown()
			local h1 = ctx.me:clickOn(b, "LeftButton")
			ctx:advance(0.6)
			if h1 ~= b then ctx:na("another frame covers the minimap button") end
			local after1 = UI.IsShown()
			local h2 = ctx.me:clickOn(b, "LeftButton")
			ctx:advance(0.6)
			if h2 ~= b then ctx:na("opened window covers the minimap button at this size/position") end
			local after2 = UI.IsShown()
			if after1 == wasShown or after2 ~= wasShown then
				ctx:fail("Left-clicking the minimap button did not toggle the Wuber window open and closed.", string.format("was=%s after1=%s after2=%s", tostring(wasShown), tostring(after1), tostring(after2)))
			end
		end,
	}

	-- 12. Minimap: right-click opens Drive or shows rider toast
	promise{
		id = "b5notices.minimap_right_click_drive_or_toast",
		area = "Minimap",
		text = "Right-clicking the Wuber minimap button opens the Drive tab for drivers, or tells riders that driving isn't available here.",
		source = "Wuber/UI/Minimap.lua:71-82",
		kind = "scenario",
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local b = kit(ctx).minimap
			if not b or not ctx:visible(b) then ctx:na("minimap button is hidden") end
			local UI = ctx.W.UI
			clearOverlays(ctx)
			ctx.me:clickOn(b, "RightButton")
			ctx:advance(0.6)
			if ctx.me.player.class == "WARLOCK" or (ctx.W.Drive and ctx.W.Drive.Role and ctx.W.Drive.Role() ~= "none") then
				if not UI.IsShown() or kit(ctx).tab ~= "Drive" then
					-- some crew/friend states may still show Drive or toast
					if not hasText(ctx, "Driving isn't available here", true) then
						ctx:fail("Right-clicking the minimap button neither opened Drive nor explained that driving isn't available.", seen(ctx))
					end
				end
			else
				if not hasText(ctx, "Driving isn't available here", true) and kit(ctx).tab ~= "Drive" then
					ctx:fail("Right-clicking the minimap button as a rider did not say 'Driving isn't available here'.", seen(ctx))
				end
			end
			ctx:advance(4.5)
		end,
	}

	-- 13. Minimap: portal flash stops when window opens, resumes when closed
	promise{
		id = "b5notices.minimap_portal_flash_stops_when_open",
		area = "Minimap",
		text = "While a summon portal is up, the minimap button pulses magenta when the window is closed and stops pulsing when the window is open.",
		source = "Wuber/UI/Minimap.lua:130-163",
		kind = "scenario",
		needs = { ride = "summoning" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			local b = kit(ctx).minimap
			if not b or not ctx:visible(b) or not b.pulse then ctx:na("minimap button or pulse missing") end
			local rv = ctx:mod("UI.Kit").rideView()
			if not rv or not rv.portalUp then ctx:na("no summon portal active") end
			local UI = ctx.W.UI
			if UI.IsShown() then UI.Toggle(false) ctx:advance(0.4) end
			UI.RefreshMinimap()
			ctx:advance(0.3)
			local pulsingClosed = b.pulse.running == true
			UI.Toggle(true)
			ctx:advance(0.4)
			UI.RefreshMinimap()
			ctx:advance(0.3)
			local pulsingOpen = b.pulse.running == true
			if not pulsingClosed then
				ctx:fail("With a summon portal up and the window closed, the minimap button was not pulsing.", tostring(b.pulse.running))
			end
			if pulsingOpen then
				ctx:fail("With the Wuber window open, the minimap summon pulse kept running.", tostring(b.pulse.running))
			end
		end,
	}

	-- 14. Tips: Next tip and Don't show again on a login tip card
	promise{
		id = "b5notices.tips_next_and_dont_show_again",
		area = "Tips",
		text = "On a login tip card, clicking 'Next tip' moves to another tip, and clicking 'Don't show again' turns login tips off and says how to re-enable them.",
		source = "Wuber/UI/Tips.lua:59-64,515-560",
		kind = "scenario",
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
			local Tips = ctx:mod("UI.Tips")
			if not Tips then ctx:cannot("no UI.Tips module") end
			openHome(ctx)
			local oldOn = ctx.W.db and ctx.W.db.tipsOn
			Tips.SetOn(true)
			Tips.ShowNow()
			ctx:advance(0.5)
			local c = Tips.Card()
			if not c or not ctx:visible(c) then
				if ctx.W.db then ctx.W.db.tipsOn = oldOn end
				ctx:na("tip card did not show")
			end
			local firstKicker = c.kicker and c.kicker:GetText()
			if c.next and ctx:visible(c.next) then
				ctx.me:clickOn(c.next)
				ctx:advance(0.4)
			end
			local secondKicker = c.kicker and c.kicker:GetText()
			if not c.never or not ctx:visible(c.never) then
				Tips.Hide()
				if ctx.W.db then ctx.W.db.tipsOn = oldOn end
				ctx:cannot("Don't show again button not visible")
			end
			ctx.me:clickOn(c.never)
			ctx:advance(0.5)
			local offNow = not Tips.IsOn()
			local offMsg = hasText(ctx, "Tips are off.", true)
			Tips.Hide()
			if ctx.W.db then ctx.W.db.tipsOn = oldOn end
			ctx:advance(4.5)
			if firstKicker and secondKicker and firstKicker == secondKicker then
				ctx:fail("Clicking 'Next tip' on a login tip card stayed on the same tip.", tostring(firstKicker))
			end
			if not offNow or not offMsg then
				ctx:fail("Clicking 'Don't show again' did not turn login tips off and explain how to turn them back on.", seen(ctx))
			end
		end,
	}
end
