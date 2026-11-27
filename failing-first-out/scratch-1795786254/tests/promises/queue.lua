-- Promises about the driver's queue: how riders get on it, the states they go through, and what a click on a row does.
-- Written from what the player was told: Settings tooltips (Driving: inviting / whispers and trades), the row tips
-- ("hold a name for options", Skip), BRIEF18 (a place the driver does not serve), REPORT18/REPORT23.
return function(Hunt)
	-- a driver on his own can only exist with no saved crew: the author's saved characters are all in a crew, so the
	-- situations that pair role=warlock with them cannot be built (the role dial says so); they are skipped here
	local function canDrive(sit) return sit.saved == nil or sit.saved == "fresh" end

	-- ---- shared little helpers (each promise file keeps its own copy) ----
	local function has(ctx, pat)
		for _, t in ipairs(ctx:texts()) do if t:find(pat) then return t end end
		return nil
	end
	local function allText(ctx) return table.concat(ctx:texts(), " | ") end
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DR(ctx) return ctx.W.Drive end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end

	-- the player gets to the Drive tab's console (opens the phone, clicks the Drive tab)
	local function openDrive(ctx)
		local UI = ctx.W.UI
		-- the bug report (phone=bug) opens over the phone with edit boxes of its own: a player closes it first
		if UI.Bug and UI.Bug.Shown and UI.Bug.Shown() then
			if UI.Bug.Close then UI.Bug.Close() end
			ctx:note("close the bug report")
			ctx:advance(0.5)
		end
		if not (UI.IsShown and UI.IsShown()) then
			UI.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(3)
		else
			ctx:advance(4) -- (a phone that is already up may still be playing its splash or moving to a tip)
		end
		-- (a phone that opened by itself is still playing its splash: the player waits a moment)
		for _ = 1, 3 do
			if has(ctx, "^Riders$") then break end
			ctx:advance(3)
		end
		if not has(ctx, "^Riders$") then
			pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
			ctx:note("click the Drive tab")
			ctx:advance(1)
		end
		if not has(ctx, "^Riders$") and UI.ShowDrive then
			pcall(UI.ShowDrive, "console")
			ctx:advance(1)
		end
		if not has(ctx, "^Riders$") then ctx:cannot("could not reach the Drive console") end
		-- a sub-screen (Messages, Customers...) or a sheet left open over the console: back to the console
		local D = ctx.W.Driver
		if D and D.CurrentScreen and UI.ShowDrive and (D.CurrentScreen() ~= "console" or (D.SheetOpen and D.SheetOpen())) then
			if D.CurrentScreen() ~= "console" then
				pcall(UI.ShowDrive, "console")
				ctx:note("back to the Drive console")
				ctx:advance(1)
			end
			if D.SheetOpen and D.SheetOpen() then
				-- Escape closes a sheet (and the phone with it): the player opens the phone on the Drive tab again
				ctx.me:pressEscape()
				ctx:note("Escape closes the sheet")
				ctx:advance(1)
				if not (UI.IsShown and UI.IsShown()) then
					UI.Toggle(true)
					ctx:advance(4)
					if not has(ctx, "^Riders$") then
						pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
						ctx:advance(1)
					end
				end
			end
		end
	end

	-- the fake game lets a scrolled-off row take a click aimed at a button under it (it ignores the scroll frame's
	-- clip); a player would simply click the button, so this clicks the button the text belongs to
	local function pressDirect(ctx, pat)
		for _, obj in ipairs(ctx.me.widgets) do
			if obj.GetObjectType and obj:GetObjectType() == "FontString" and ctx:visible(obj) then
				local t = (obj:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
				if t:find(pat) then
					local p = obj:GetParent()
					while p and p.GetObjectType and p:GetObjectType() ~= "Button" do p = p:GetParent() end
					if p then
						ctx.me:click(p)
						ctx:note("click " .. pat .. " by its button (a scrolled-off row covers the drawn spot in the fake game)")
						ctx:advance(1)
						return true
					end
				end
			end
		end
		return false
	end

	-- a click on visible text; false and why when it is not on screen
	local function press(ctx, pat, opts)
		opts = opts or {}
		opts.pattern = true
		local ok, err = pcall(ctx.me.clickText, ctx.me, pat, opts)
		ctx:note("click " .. pat)
		ctx:advance(opts.wait or 1)
		return ok, err
	end

	-- a stranger without Wuber whispers the driver
	local function strangerWhisper(ctx, name, text)
		local w = ctx.w
		if not w:player(name) then w:addBot(name, {}) end
		w:botWhisper(name, ctx.me, text)
		ctx:note("whisper from " .. name .. ": " .. text)
		ctx:advance(2)
	end

	local function myWhispers(ctx, to)
		local out = {}
		for _, x in ipairs(ctx.w.whispers) do
			if key(x.from) == key(ctx.name) and (not to or key(x.to) == key(to)) then out[#out + 1] = x end
		end
		return out
	end
	local function myPosts(ctx)
		local out = {}
		for _, p in ipairs(ctx.w.chatPosts or {}) do
			if key(p.from) == key(ctx.name) then out[#out + 1] = p end
		end
		return out
	end

	local function editBoxWith(ctx, pat)
		for _, obj in ipairs(ctx.me.widgets) do
			if obj.GetObjectType and obj:GetObjectType() == "EditBox" and ctx:visible(obj) then
				local t = obj:GetText() or ""
				if t:find(pat) then return obj end
			end
		end
		return nil
	end

	local function confirmClose(ctx)
		local env = ctx.me and ctx.me.env
		if env and env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS") then
			local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
			env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
			if dlg and dlg.OnAccept then dlg.OnAccept() end
			ctx:advance(1)
		end
	end

	local function closeShop(ctx)
		if DR(ctx).IsOpen() then
			press(ctx, "^Close$")
			confirmClose(ctx)
			-- closing after a ride shows the shift card: the player taps its Nice button
			local D = ctx.W.Driver
			if D and D.SheetOpen and D.SheetOpen() and has(ctx, "^Nice$") then press(ctx, "^Nice$") end
		end
	end

	local function need(ctx)
		noCombat(ctx)
		local d = ctx.W.Drive
		if not (d and d.IsOpen) then ctx:cannot("no driver engine") end
		if not d.IsOpen() then ctx:na("not open") end
		if d.IsPaused() then ctx:na("paused") end
	end
	-- a stranger without Wuber writes in a public channel (a real player standing somewhere: invites can reach them)
	local function publicLine(ctx, name, text, chan)
		if not ctx.w:player(name) then ctx.w:addBot(name, {}) end
		ctx.w:chatFrom(name, text, "CHANNEL", chan or "Trade")
		ctx:note(name .. " in " .. (chan or "Trade") .. ": " .. text)
	end
	-- the place I summon to now (where I stand, or the one I typed)
	local function servedPlace(ctx)
		local d = ctx.W.Drive.Dest and ctx.W.Drive.Dest() or ""
		return d ~= "" and d or "Ratchet"
	end
	-- who is on the list, as the rider's state word ("lead", "queued", "invited", "joined", ...)
	local function stateOf(ctx, name)
		local c = ctx.W.Drive.customers[key(name)]
		return c and c.state or nil
	end
	local function inGroup(ctx, name)
		local p = ctx.w:player(name)
		return p and (p.group ~= nil or p.pendingInvite ~= nil) or false
	end
	local function free(ctx, ...)
		for _, n in ipairs({ ... }) do if ctx.w:player(n) then ctx:na("the name " .. n .. " is taken") end end
	end
	local function autoInviteOn(sit) return sit.opt_autoInvite ~= "off" end

	Hunt.promise{
		id = "queue.whisper_invited",
		area = "Queue",
		text = "While you are open with 'Invite riders who whisper me' on, a stranger who whispers 'summon pls' is listed and invited to your group.",
		source = "Settings tooltip (Invite riders who whisper me); console (Whisper word: summon)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (autoInviteOn(sit) and (sit.opt_oneAtATime or "default") ~= "on" and sit.group ~= "raid") end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:fail("You are open, a stranger whispers 'summon pls' and they are not on your list.", allText(ctx)) end
			if not inGroup(ctx, "Zed Quick") then
				ctx:fail("You are open with whisper invites on, a stranger whispers 'summon pls', and they are on your list but never invited (" .. tostring(stateOf(ctx, "Zed Quick")) .. ").", allText(ctx))
			end
			if not has(ctx, "^Zed") then ctx:fail("A rider is on your list and the Drive tab never shows their name.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.whisper_listed_when_invites_off",
		area = "Queue",
		text = "With 'Invite riders who whisper me' off, a stranger who whispers 'summon pls' is listed but not invited until you act.",
		source = "Settings tooltip (Invite riders who whisper me)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", opt_autoInvite = "off" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:fail("Whisper invites are off, a stranger whispers 'summon pls' and they are not on your list at all.", allText(ctx)) end
			if inGroup(ctx, "Zed Quick") then ctx:fail("Whisper invites are off and a stranger who whispers 'summon pls' is invited anyway.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.invite_follows_claim",
		area = "Queue",
		text = "When the console tells you a waiting rider 'will be invited as soon as there is room', an invite does go out to them (a minute is plenty).",
		source = "the big button's own words on the Drive tab (the invite goes out as soon as there is room)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", opt_autoInvite = "off" },
		when = function(sit) return canDrive(sit) and sit.group ~= "raid" and (sit.opt_oneAtATime or "default") ~= "on" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:na("not queued") end
			if not has(ctx, "invite goes out as soon as there is room") then ctx:na("the console makes no such claim here: " .. tostring(stateOf(ctx, "Zed Quick"))) end
			ctx:advance(60)
			if not inGroup(ctx, "Zed Quick") then
				ctx:fail("A rider whispered, the console says their invite goes out as soon as there is room, and a minute later nobody has invited them (the group has room).", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "queue.other_place_not_invited",
		area = "Queue",
		text = "A whisper that asks for a summon to a place you do not serve is listed as a lead, never invited unasked.",
		source = "BRIEF18 00:53 (a request naming a place we don't serve is a lead, never invited)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			free(ctx, "Amy Far")
			openDrive(ctx)
			strangerWhisper(ctx, "Amy Far", "summon to darkshore pls")
			if inGroup(ctx, "Amy Far") then
				ctx:fail("You summon to Ratchet, a stranger whispers 'summon to darkshore pls' and you invite them at once.", allText(ctx))
			end
			if stateOf(ctx, "Amy Far") ~= "lead" and stateOf(ctx, "Amy Far") ~= nil then
				ctx:fail("A stranger asks you for a summon to Darkshore, which you do not serve, and they join your queue as '" .. tostring(stateOf(ctx, "Amy Far")) .. "' instead of a lead.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "queue.public_buyer_listed",
		area = "Queue",
		text = "With 'List people asking in public chat' on, someone who asks for a summon in Trade shows in your list (grey) so you can invite them.",
		source = "Settings tooltip (List people asking in public chat)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (sit.opt_watchPublic ~= "off") end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Pub Guy")
			openDrive(ctx)
			publicLine(ctx, "Pub Guy", "wtb summon to " .. servedPlace(ctx):lower())
			ctx:advance(2)
			-- the console lists at most 8 rows and says "+N more" under them (Driver/State.lua MAX_ROWS): a buyer past the cap is listed, but out of sight
			if not has(ctx, "Pub") and has(ctx, "^%+%d+ more") then ctx:na("the console shows '+N more': the buyer is past the 8 rows it lists") end
			if not stateOf(ctx, "Pub Guy") then ctx:fail("Someone writes 'wtb summon to ratchet' in Trade and they are not in your list, though you list people asking in public chat.", allText(ctx)) end
			if not has(ctx, "^Pub") then ctx:fail("A public chat buyer is in your list and the Drive tab does not show their name.", allText(ctx)) end
			if inGroup(ctx, "Pub Guy") and DR(ctx).opts().autoPublic ~= true then ctx:fail("Someone asks for a summon in Trade and you invite them without a click (the public chat invite is off unless you chose it).", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.adverts_not_buyers",
		area = "Queue",
		text = "A seller's line in public chat (another driver's [Wuber] advert, or 'wts summon to UC 70s') is never listed as a buyer.",
		source = "BRIEF18 (seller adverts are ignored); universal rule: an advert is never a buyer",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			free(ctx, "Sam Seller", "Ada Advert")
			openDrive(ctx)
			publicLine(ctx, "Sam Seller", "wts summon to ratchet 70s, whisper me")
			publicLine(ctx, "Ada Advert", "[Wuber] Summons to Ratchet 50s - I'm a Wuber driver, get the Wuber addon on CurseForge")
			ctx:advance(3)
			for _, n in ipairs({ "Sam Seller", "Ada Advert" }) do
				if stateOf(ctx, n) then
					ctx:fail("Another player advertises summons in Trade and " .. n .. " appears in your queue as a buyer.", allText(ctx))
				end
			end
		end,
	}

	local function rowClick(ctx, first, button)
		local ok, err = pcall(ctx.me.clickText, ctx.me, "^" .. first .. "$", { pattern = true, button = button })
		ctx:note("click " .. (button or "left") .. " on the row of " .. first)
		ctx:advance(1)
		if not ok then ctx:fail("A rider is on your list and there is no row with their name to click.", allText(ctx)) end
	end

	-- (job 146) the row's frame (the Button that holds the name text), or nil
	local function rowFrameOf(ctx, first)
		for _, obj in ipairs(ctx.me.widgets) do
			if obj.GetObjectType and obj:GetObjectType() == "FontString" and ctx:visible(obj) then
				local t = (obj:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
				if t == first then
					local p = obj:GetParent()
					while p and p.GetObjectType and p:GetObjectType() ~= "Button" do p = p:GetParent() end
					return p
				end
			end
		end
		return nil
	end
	-- (job 146) does a click at the row's name reach the row (not a tab button over a scrolled-off row)?
	local function rowReachable(ctx, row)
		local name = row and row.name
		if not (name and name.GetLeft) then return false end
		local x = (name:GetLeft() or 0) + (name:GetWidth() or 0) / 2
		local y = (name:GetBottom() or 0) + (name:GetHeight() or 0) / 2
		local f = ctx.me:frameAt(x, y)
		while f do
			if f == row then return true end
			f = f.GetParent and f:GetParent() or nil
		end
		return false
	end
	-- (job 146) a player scrolls the list until the row is under the finger; false when it still is not reachable
	local function scrollToRow(ctx, row)
		if rowReachable(ctx, row) then return true end
		local p = row and row:GetParent()
		while p do
			if p.ScrollTo and p.max then
				pcall(p.ScrollTo, p, p.max, true)
				ctx:note("scroll the list down to the row")
				ctx:advance(0.5)
				break
			end
			p = p.GetParent and p:GetParent() or nil
		end
		return rowReachable(ctx, row)
	end

	Hunt.promise{
		id = "queue.lead_click_invites",
		area = "Queue",
		text = "A tap on a grey chat buyer's row invites them.",
		source = "row tip (Tip: hold a name for options) and the grey rows' own purpose",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (sit.opt_watchPublic ~= "off") and sit.group ~= "raid" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Pub Guy")
			openDrive(ctx)
			publicLine(ctx, "Pub Guy", "wtb summon to " .. servedPlace(ctx):lower())
			ctx:advance(2)
			if stateOf(ctx, "Pub Guy") ~= "lead" then ctx:na("the buyer is not a lead here") end
			rowClick(ctx, "Pub")
			if not inGroup(ctx, "Pub Guy") then ctx:fail("You tap a chat buyer's row and they are not invited.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.right_click_drops_silently",
		area = "Queue",
		text = "Right-click a rider's row and they are off your list; nothing is said to them.",
		source = "row menu (Take off the list: Nothing is said (right-click))",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and sit.group ~= "raid" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:na("not queued") end
			local before = #myWhispers(ctx, "Zed Quick")
			rowClick(ctx, "Zed", "RightButton")
			if stateOf(ctx, "Zed Quick") then ctx:fail("You right-click a rider's row to take them off the list and they are still on it.", allText(ctx)) end
			if #myWhispers(ctx, "Zed Quick") > before then ctx:fail("You right-click a rider off your list, which says nothing is said, and they are whispered.") end
		end,
	}

	Hunt.promise{
		id = "queue.shift_right_click_blocks",
		area = "Queue",
		text = "Shift-right-click a rider's row blocks them: they are off the list, listed under Blocked, and their next whisper is not listed.",
		source = "row menu (Block...: Never serve them again (shift-right-click)); toast: won't be served again",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and sit.group ~= "raid" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:na("not queued") end
			-- (job 146) the row must be inside the list's view: a player scrolls to it first
			local zrow = rowFrameOf(ctx, "Zed")
			if not zrow then ctx:fail("A rider is on your list and there is no row with their name to click.", allText(ctx)) end
			if not scrollToRow(ctx, zrow) then ctx:na("the row is below the list's visible part, under the tab bar, even after scrolling") end
			ctx.me.mods.shift = true
			local ok, err = pcall(rowClick, ctx, "Zed", "RightButton")
			ctx.me.mods.shift = false
			if not ok then error(err, 0) end
			if stateOf(ctx, "Zed Quick") then ctx:fail("You shift-right-click a rider's row to block them and they are still on your list.", allText(ctx)) end
			if not DR(ctx).BlockEntry(key("Zed Quick")) then ctx:fail("You shift-right-click a rider to block them and they are not in your blocked list.") end
			ctx.w:botWhisper("Zed Quick", ctx.me, "summon pls please")
			ctx:advance(2)
			if stateOf(ctx, "Zed Quick") then ctx:fail("You blocked a rider and their next whisper puts them on your list again.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.ctrl_click_marks_paid",
		area = "Queue",
		text = "Ctrl-click a rider's row marks them as paid. (job 146: the row must be inside the list's view; a player scrolls to it first.)",
		source = "row menu (Mark as paid: They paid some other way (Ctrl-click))",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and sit.group ~= "raid" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:na("not queued") end
			local row = rowFrameOf(ctx, "Zed")
			if not row then ctx:fail("A rider is on your list and there is no row with their name to click.", allText(ctx)) end
			if not scrollToRow(ctx, row) then ctx:na("the row is below the list's visible part, under the tab bar, even after scrolling") end
			ctx.me.mods.ctrl = true
			local ok, err = pcall(rowClick, ctx, "Zed")
			ctx.me.mods.ctrl = false
			if not ok then error(err, 0) end
			local c = DR(ctx).customers[key("Zed Quick")]
			if c and c.state ~= "paid" and c.state ~= "done" then
				ctx:fail("You ctrl-click a rider's row to mark them paid and their row says '" .. tostring(c.state) .. "'.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "queue.row_menu",
		area = "Queue",
		text = "With whisper invites off, tapping a queued rider's row invites them (HUNT-12), and tapping Options opens a menu offering Mark as paid, Not a rider, Take off the list and Block; Take off the list works.",
		source = "row menu (Sheets.lua), Options button (Rows.lua:352-404), and HUNT-12 (Rows.lua:229)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", opt_autoInvite = "off" },
		when = function(sit) return canDrive(sit) and sit.group ~= "raid" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if stateOf(ctx, "Zed Quick") ~= "queued" then ctx:na("not simply queued: " .. tostring(stateOf(ctx, "Zed Quick"))) end
			-- (HUNT-12) tapping a queued rider's row invites them when auto-invite is off
			rowClick(ctx, "Zed")
			if not inGroup(ctx, "Zed Quick") then
				ctx:fail("With whisper invites off, you tap a queued rider's row and they are not invited.", allText(ctx))
			end
			-- the Options button on the row opens the row menu
			local optBtn
			for _, obj in ipairs(ctx.me.widgets) do
				if type(obj) == "table" and obj.more and type(obj.c) == "table" and obj.c.name == "Zed Quick" and ctx:visible(obj.more) then
					optBtn = obj.more
					break
				end
			end
			if optBtn then
				ctx.me:clickOn(optBtn)
				ctx:note("click Options on Zed Quick's row")
				ctx:advance(1)
			else
				press(ctx, "^Options$")
			end
			for _, w in ipairs({ "^Mark as paid$", "^Not a rider", "^Take off the list$", "^Block" }) do
				if not has(ctx, w) then ctx:fail("You tap Options on a rider's row and the menu has no " .. w:gsub("[%^%$]", "") .. ".", allText(ctx)) end
			end
			press(ctx, "^Take off the list$")
			if stateOf(ctx, "Zed Quick") then ctx:fail("You pick Take off the list in a rider's menu and they are still on your list.", allText(ctx)) end
		end,
	}

	-- (ride dial) what each stage reads on the row and on the big button
	local STAGE = {
		invited = { row = "invited", why = "invited" },
		summoning = { row = "summon", why = "summon" },
		arrived = { row = "owes", why = "owing" },
		paid = { row = "paid", why = "paid" },
	}
	Hunt.promise{
		id = "queue.row_says_stage",
		area = "Queue",
		text = "A rider's row says where they are: invited, has the summon, owes you, paid; and the big button names them.",
		source = "inferred (row words: Describe; the big button tip: Its words always say what your next click does)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = function(sit) return canDrive(sit) and (STAGE[sit.ride or "none"] ~= nil) and (sit.opt_whisperMode or "default") ~= "off" end,
		check = function(ctx)
			need(ctx)
			local st = ctx.facts.rideState
			local want = ({ invited = "invited", waiting = "summon", arrived = "owes", paid = "paid" })[st]
			if not want then ctx:na("the ride is not at a stage with words: " .. tostring(st)) end
			openDrive(ctx)
			local first = (ctx.facts.riderName or "?"):match("^(%S+)")
			if not has(ctx, "^" .. first .. "$") then
				ctx:fail("A rider (" .. first .. ") is " .. st .. " on your list and the Drive tab does not show their name.", allText(ctx))
			end
			local found = false
			for _, t in ipairs(ctx:texts()) do if t:lower():find(want, 1, true) then found = true end end
			if not found then ctx:fail("A rider is " .. st .. " on your list and no row or button says '" .. want .. "'.", allText(ctx)) end
			local named = false
			for _, t in ipairs(ctx:texts()) do if t:find(first, 1, true) and #t > #first and not t:find("^ ·") then named = true end end
			if not named then ctx:fail("A rider is " .. st .. " and the big button's words never name " .. first .. ".", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.thank_click",
		area = "Queue",
		text = "Once a rider has paid, the big button says Thank and one click whispers them thanks.",
		source = "tooltip (The big button: summon, accept the gold, thank)",
		kind = "scenario",
		needs = { role = "warlock", ride = "paid" },
		when = function(sit) return canDrive(sit) and ((sit.opt_whisperMode or "default") ~= "off" and (sit.opt_whisperMode or "default") ~= "box") end,
		check = function(ctx)
			need(ctx)
			if ctx.facts.rideState ~= "paid" then ctx:na("the rider is not at paid") end
			openDrive(ctx)
			local rider = ctx.facts.riderName
			-- (job 2680) openDrive's fallback click on the Drive tab can land on the floating big button, which sits above the
			-- phone when it has no clear place at this size (Drive.Button): that click is the thank click already
			do
				local c0 = ctx.W.Drive.Find and ctx.W.Drive.Find(rider)
				if not c0 or c0.thanked then ctx:na("the click that opened the Drive tab hit the big button and thanked the rider") end
			end
			if not has(ctx, "^Thank ") then ctx:fail("A rider has paid you by trade and the big button does not say Thank.", allText(ctx)) end
			local b = ctx.me.env.WuberDriveButton
			if not (b and ctx:visible(b)) then ctx:na("no big button on screen") end
			local before = #myWhispers(ctx, rider)
			ctx.me:click(b)
			ctx:advance(2)
			if #myWhispers(ctx, rider) <= before then ctx:fail("A rider has paid, you click the big button that says Thank, and they get no thanks whisper.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.one_at_a_time",
		area = "Queue",
		text = "With 'One rider at a time' on, a second rider is not invited while the first is in your group.",
		source = "Settings tooltip (One rider at a time: the next is invited when the last has paid)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", opt_oneAtATime = "on" },
		when = function(sit) return canDrive(sit) and (sit.opt_autoInvite ~= "off") end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick", "Amy Near")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			strangerWhisper(ctx, "Amy Near", "summon pls")
			if not inGroup(ctx, "Zed Quick") then ctx:na("the first rider was not invited") end
			if inGroup(ctx, "Amy Near") then ctx:fail("'One rider at a time' is on, one rider is in your group, and a second is invited as well.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "queue.away_guard_pauses",
		area = "Queue",
		text = "If a rider sits in your group for 4 minutes with no summon, Wuber pauses you and rings, so nobody waits for nothing.",
		source = "Settings tooltip (Pause me if I'm away)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (sit.opt_awayGuard ~= "off" and sit.opt_autoInvite ~= "off" and sit.group ~= "raid") end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not inGroup(ctx, "Zed Quick") then ctx:na("the rider was not invited") end
			ctx:advance(270)
			if not inGroup(ctx, "Zed Quick") then ctx:na("the rider left") end
			if not DR(ctx).IsPaused() then
				ctx:fail("A rider sat in your group for over four minutes and you never summoned them: with 'Pause me if I'm away' on, Wuber has not paused you.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "queue.leaving_unpaid_blocks",
		area = "Queue",
		text = "A rider who was summoned, landed and left your group owing gold is blocked by themselves.",
		source = "Settings tooltip (Block riders who leave without paying)",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived" },
		when = function(sit) return canDrive(sit) and (sit.opt_autoBlock ~= "off") end,
		check = function(ctx)
			need(ctx)
			if ctx.facts.rideState ~= "arrived" then ctx:na("the rider is not at arrived") end
			local rider = ctx.facts.riderName
			ctx.w:leave(rider)
			ctx:note(rider .. " leaves the group without paying")
			ctx:advance(20)
			if not DR(ctx).BlockEntry(key(rider)) then
				ctx:fail("A rider lands, owes you gold, leaves your group, and 'Block riders who leave without paying' (on) never blocks them.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "queue.reload_keeps_riders",
		area = "Queue",
		text = "After a /reload the riders who are already in your group are still on your list.",
		source = "REPORT18/REPORT23 (Reloading within ten minutes restores your riders); universal reload promise",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (sit.session ~= "first") and sit.opt_autoInvite ~= "off" and sit.group ~= "raid" end,
		check = function(ctx)
			need(ctx)
			free(ctx, "Zed Quick")
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not stateOf(ctx, "Zed Quick") then ctx:na("not queued") end
			local before = stateOf(ctx, "Zed Quick")
			ctx:reload()
			ctx:advance(3)
			if not ctx.W.Drive.IsOpen() then ctx:na("a reload left me closed") end
			if not stateOf(ctx, "Zed Quick") then
				ctx:fail("A rider (" .. before .. ") is on your list, you /reload, and they are gone from it.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "queue.careful_auto",
		area = "Queue",
		text = "Wuber never invites a seller by itself: every rider it invited by itself asked in words the careful rule calls a clear request when it invited them. (job 146: a rider who carries the Oops mark was invited before the Oops taught Wuber those words as a wrong invite, so they are skipped.)",
		source = "Drive.Careful (DR.Careful)",
		kind = "always",
		check = function(ctx)
			local dr = ctx.W and ctx.W.Drive
			if type(dr) ~= "table" or type(dr.customers) ~= "table" or type(dr.Careful) ~= "function" then return end
			for _, c in pairs(dr.customers) do
				if type(c) == "table" and c.auto and c.auto ~= "" and type(c.autoMsg) == "string" and not c.oops then
					local channel = c.auto == "public" and "public" or "whisper"
					local verdict, why = dr.Careful(c.autoMsg, channel)
					if verdict ~= "invite" then
						ctx:fail("A rider (" .. tostring(c.state) .. ") was invited by itself from '" .. c.autoMsg .. "', which Careful calls " .. tostring(verdict) .. " (" .. tostring(why) .. ").", allText(ctx))
					end
				end
			end
		end,
	}

end
