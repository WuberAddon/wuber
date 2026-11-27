-- Promises about the Warlock driver's console (the hunt, role DRIVER): going online, pausing, closing, the price sheet,
-- Soul Shards, the big button, Skip, the Messages editor, the alert character, slash commands.
-- Written from what the player was told: Settings tooltips (Driving), the Drive tab's tooltips, the sheet's own words.
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
			return true
		end
		return false
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
		if not (ctx.W.Drive and ctx.W.Drive.IsOpen) then ctx:cannot("no driver engine") end
	end

	Hunt.promise{
		id = "driver.open_button",
		area = "Driver",
		text = "Tap Open on the Drive tab and you are open: the button turns into Close, and with nobody on your list the console says it is waiting for riders.",
		source = "tooltip (Open: Start taking riders)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			closeShop(ctx)
			if DR(ctx).IsOpen() then ctx:fail("You tap Close on the Drive tab and Wuber still thinks you are open.") end
			local ok = press(ctx, "^Open$")
			if not ok then ctx:fail("You are closed on the Drive tab and there is no Open button to tap.", allText(ctx)) end
			if not DR(ctx).IsOpen() then
				ctx:fail("You tap Open on the Drive tab and you are still closed.", allText(ctx))
			end
			if not has(ctx, "^Close$") then
				ctx:fail("You tap Open and the Open button never turns into Close.", allText(ctx))
			end
			if #DR(ctx).Sorted() == 0 and not has(ctx, "waiting for riders") then
				ctx:fail("You tap Open with nobody on your list and the console never says you are waiting for riders.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "driver.close_button",
		area = "Driver",
		text = "Tap Close and you are closed: the console says so and a stranger who whispers 'summon' is not put on your list.",
		source = "tooltip (Close: Stop taking riders)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			if not DR(ctx).IsOpen() then ctx:na("not open to begin with") end
			local ok = press(ctx, "^Close$")
			if not ok then ctx:fail("You are open on the Drive tab and there is no Close button to tap.", allText(ctx)) end
			confirmClose(ctx)
			if DR(ctx).IsOpen() then ctx:fail("You tap Close and the console still says you are open.", allText(ctx)) end
			if not has(ctx, "^Closed$") then ctx:fail("You tap Close and the status line never says Closed.", allText(ctx)) end
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if DR(ctx).customers[key("Zed Quick")] then
				ctx:fail("You are closed and a stranger who whispers 'summon pls' is put on your list anyway.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "driver.pause_resume",
		area = "Driver",
		text = "Tap Pause and nobody new is invited; tap Resume and the waiting rider is invited.",
		source = "tooltip (Pause: A short break: no new invites; Resume: Start inviting new riders again)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = function(sit) return canDrive(sit) and (sit.opt_autoInvite ~= "off" and (sit.opt_oneAtATime or "default") ~= "on" and sit.group ~= "raid") end,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Quick") then ctx:na("the name is taken") end
			openDrive(ctx)
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			if DR(ctx).IsPaused() then ctx:na("paused to begin with") end
			if not press(ctx, "^Pause$") then ctx:fail("You are open on the Drive tab and there is no Pause button.", allText(ctx)) end
			if not DR(ctx).IsPaused() then ctx:fail("You tap Pause and Wuber is not paused.", allText(ctx)) end
			if not has(ctx, "^Resume$") then ctx:fail("You tap Pause and the button does not turn into Resume.", allText(ctx)) end
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			local p = ctx.w:player("Zed Quick")
			if p.group or p.pendingInvite then
				ctx:fail("You are paused and a stranger who whispers 'summon pls' is invited to your group at once.", allText(ctx))
			end
			if not press(ctx, "^Resume$") then ctx:fail("You are paused and there is no Resume button.", allText(ctx)) end
			ctx:advance(4)
			if not (p.group or p.pendingInvite) then
				ctx:fail("You tap Resume and the stranger who asked while you were paused is still not invited.", allText(ctx))
			end
		end,
	}

	local function openSheet(ctx)
		openDrive(ctx)
		local ok = press(ctx, "%d+[gsc].- to %a")
		if not ok or not editBoxWith(ctx, "^%d+[gsc]") then
			ctx:fail("You tap your price on the Drive tab and no Price and place sheet opens.", allText(ctx))
		end
		return editBoxWith(ctx, "^%d+[gsc]")
	end

	Hunt.promise{
		id = "driver.price_sheet_saves",
		area = "Driver",
		text = "Change your price in the Price and place sheet and tap Save: the console shows the new price.",
		source = "tooltip (Save: Riders see the new price and place at once)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			local box = openSheet(ctx)
			ctx.me:type(box, "80s", false)
			ctx:note("type 80s")
			ctx:advance(0.5)
			local ok = press(ctx, "^Save$")
			if not ok then ctx:fail("You type a new price in the sheet and there is no Save button.", allText(ctx)) end
			if DR(ctx).char().price ~= 8000 then
				ctx:fail("You type 80s in the Price and place sheet, tap Save, and your price is " .. tostring(DR(ctx).char().price) .. " copper.", allText(ctx))
			end
			if not has(ctx, "80s") then ctx:fail("You save a price of 80s and the Drive tab never shows 80s.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "driver.price_floor",
		area = "Driver",
		text = "Wuber's lowest fare is 50s: a smaller price you type becomes 50s, and the sheet says so.",
		source = "the Price and place sheet's own words (Wuber's lowest fare is 50s: it'll be 50s)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			local box = openSheet(ctx)
			ctx.me:type(box, "10s", false)
			ctx:advance(0.5)
			if not has(ctx, "lowest fare is 50s") then ctx:fail("You type 10s as your price and the sheet never mentions the 50s lowest fare.", allText(ctx)) end
			press(ctx, "^Save$")
			local p = DR(ctx).char().price
			if p == nil or p < 5000 then
				ctx:fail("You type 10s as your price, tap Save, and your price is " .. tostring(p) .. " copper, under the 50s lowest fare.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "driver.low_shards_warning",
		area = "Driver",
		text = "With 'Warn me at this many shards' at 3 (the default), Wuber warns you when your Soul Shards fall to 3, and not before.",
		source = "Settings tooltip (Warn me at this many shards: A warning when your Soul Shards drop to this many)",
		kind = "scenario",
		needs = { role = "warlock", opt_lowShards = "default" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			local function shards(n)
				ctx.me.player.shards = n
				ctx.me:fire("BAG_UPDATE_DELAYED")
				ctx:note("shards now " .. n)
				ctx:advance(2)
			end
			local function warned() return has(ctx, "[Ss]hard.*[Ll]ow") or has(ctx, "[Ll]ow.*[Ss]hard") or has(ctx, "[Rr]unning low") or has(ctx, "only %d+ [Ss]hard") or has(ctx, "[Ss]hards? left") end
			shards(6)
			if warned() then ctx:fail("You have 6 Soul Shards and Wuber already warns that you are low.", allText(ctx)) end
			shards(3)
			if not warned() then ctx:fail("Your Soul Shards fall to 3 and Wuber gives no warning, though the setting says it warns at 3.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "driver.pvp_warning",
		area = "Driver",
		text = "When an enemy player who can attack you stands near your summon spot with a nameplate in view, the Drive tab says PvP nearby.",
		source = "tooltip (PvP nearby: An enemy player who can attack you showed near your summon spot)",
		kind = "scenario",
		needs = { role = "warlock", enemies = "near" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			ctx:advance(6)
			if not has(ctx, "PvP") then ctx:fail("A flagged enemy player stands near your summon spot with a nameplate showing and the Drive tab has no PvP warning.", allText(ctx)) end
		end,
	}

	-- the Messages screen: every whisper previewed for a made-up rider called Dan
	local function openMessages(ctx)
		openDrive(ctx)
		-- the What's new card (Got it) can sit over the page: the player closes it first
		for _ = 1, 3 do
			local g = ctx.me:button("Got it")
			if g and ctx:visible(g) then ctx.me:clickOn(g) ctx:advance(0.6) ctx:note("close the What's new card (Got it)") else break end
		end
		-- since 2.4 Messages is a row in "Your business" at the END of the scrolling Drive page: the player scrolls down to it
		local function messagesRow()
			for _, obj in ipairs(ctx.me.widgets) do
				-- (not only what is visible: the row may be below the page's clip until the player scrolls)
				if obj.GetObjectType and obj:GetObjectType() == "FontString" and obj:IsShown() then
					local t = (obj:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
					if t:find("^Messages$") then
						local p = obj:GetParent()
						while p and p.GetObjectType and p:GetObjectType() ~= "Button" do p = p:GetParent() end
						return obj, p
					end
				end
			end
		end
		local function drawnAt(fs, row)
			local okc, cx, cy = pcall(fs.GetCenter, fs)
			if not (okc and cx) then return true end
			local ratio = fs:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
			local f = ctx.me:frameAt(cx * ratio, cy * ratio)
			while f do
				if f == row then return true end
				f = f.GetParent and f:GetParent() or nil
			end
			return false
		end
		-- Simple mode hides the Messages row by design (Draw.lua showMessages); the player turns Advanced on (/wuber advanced)
		if ctx.W.Advanced and ctx.W.Advanced() ~= true then
			ctx.me:slash("/wuber advanced")
			ctx:note("Messages is not listed in Simple mode: turn Advanced on (/wuber advanced)")
			ctx:advance(2)
			if ctx.W.Advanced() ~= true then ctx:na("Messages is only listed in Advanced mode and it would not turn on") end
			openDrive(ctx)
			for _ = 1, 3 do
				local g = ctx.me:button("Got it")
				if g and ctx:visible(g) then ctx.me:clickOn(g) ctx:advance(0.6) else break end
			end
		end
		local fs, row = messagesRow()
		if not (fs and row) then ctx:fail("There is no Messages button on the Drive tab.", allText(ctx)) end
		for _ = 1, 15 do
			if drawnAt(fs, row) then break end
			local anc, fn = row:GetParent(), nil
			while anc do
				fn = anc.GetScript and anc:GetScript("OnMouseWheel")
				if fn then break end
				anc = anc.GetParent and anc:GetParent() or nil
			end
			if not fn then break end
			fn(anc, -1)
			ctx:advance(0.6)
			ctx:note("scroll the Drive page down")
		end
		if not drawnAt(fs, row) then ctx:na("the Messages row cannot be scrolled clear of the tab bar here") end
		ctx.me:clickOn(row)
		ctx:note("click Messages")
		ctx:advance(1)
		if not has(ctx, "^Greeting$") then pressDirect(ctx, "^Messages$") end
		if not (has(ctx, "^Greeting$")) then ctx:fail("You tap Messages on the Drive tab and no list of your whispers shows.", allText(ctx)) end
	end

	Hunt.promise{
		id = "driver.messages_preview_clean",
		area = "Driver",
		text = "Open a message in Messages and the preview shows the whisper as the rider reads it: no curly-bracket words left unfilled.",
		source = "tooltip (Preview: Exactly what Wuber whispers, here for a made-up rider called Dan)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openMessages(ctx)
			-- (job 2680) the list shows only the rows; the preview is in the editor a tap on a row opens
			if not press(ctx, "^Greeting$") then ctx:fail("The Messages list has no Greeting row to tap.", allText(ctx)) end
			ctx:advance(0.5)
			for _, t in ipairs(ctx:texts()) do
				if not t:find("^{%a+}$") and (t:find("[{}]") or t:find("%%[sd]") or t:find("nil")) then
					ctx:fail("The Messages list shows an unfilled word in a whisper preview: " .. t, allText(ctx))
				end
			end
			if not has(ctx, "As the rider reads it") and not has(ctx, "%f[%w]Dan%f[%W]") and not has(ctx, "Ratchet") then ctx:fail("You open a message in Messages and there is no preview of what the rider reads.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "driver.messages_save_used",
		area = "Driver",
		text = "A greeting you write in Messages and save is what the big button whispers to the next rider.",
		source = "tooltip (Save: Uses this message from now on. If you lead the crew, every window of your crew uses it too)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and ((sit.opt_whisperMode or "default") ~= "off" and (sit.opt_whisperMode or "default") ~= "box" and sit.group ~= "raid" and sit.opt_autoInvite ~= "off") end,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Quick") then ctx:na("the name is taken") end
			openMessages(ctx)
			if not press(ctx, "^Greeting$") then ctx:fail("The Messages list has no Greeting row to tap.", allText(ctx)) end
			local box = editBoxWith(ctx, ".")
			if not box then ctx:fail("You tap Greeting in Messages and no box to write it in opens.", allText(ctx)) end
			ctx.me:type(box, "Hop in {name}, banana", false)
			ctx:advance(0.5)
			if not press(ctx, "^Save$") then ctx:fail("You write a greeting and there is no Save button.", allText(ctx)) end
			ctx.W.UI.ShowDrive("console")
			ctx:advance(1)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			local b = ctx.me.env.WuberDriveButton
			if not (b and ctx:visible(b)) then ctx:na("no big button on screen") end
			for _ = 1, 3 do
				ctx.me:click(b)
				ctx:advance(1.5)
			end
			local said
			for _, x in ipairs(myWhispers(ctx, "Zed Quick")) do
				if x.text:find("banana", 1, true) then said = x end
			end
			if not said then
				local all = {}
				for _, x in ipairs(myWhispers(ctx, "Zed Quick")) do all[#all + 1] = x.text end
				ctx:fail("You save the greeting 'Hop in {name}, banana' and the rider is whispered something else.", table.concat(all, " / "))
			end
			if said.text:find("{", 1, true) then ctx:fail("The greeting you saved reaches the rider with its curly-bracket word unfilled: " .. said.text) end
		end,
	}

	Hunt.promise{
		id = "driver.button_whispers_on_click",
		area = "Driver",
		text = "With whispers on Button, your first big-button click on a waiting rider sends them a whisper.",
		source = "Settings tooltip (How whispers leave: Button: each whisper goes out when you click the big button)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (((sit.opt_whisperMode or "default") == "default" or sit.opt_whisperMode == "auto") and sit.group ~= "raid" and sit.opt_autoInvite ~= "off") end,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Quick") then ctx:na("the name is taken") end
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			local b = ctx.me.env.WuberDriveButton
			if not (b and ctx:visible(b)) then ctx:na("no big button on screen") end
			local before = #myWhispers(ctx, "Zed Quick")
			ctx.me:click(b)
			ctx:advance(2)
			if #myWhispers(ctx, "Zed Quick") <= before then
				ctx:fail("A rider is waiting, whispers are on Button, you click the big button and they get no whisper.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "driver.whispers_off_silent",
		area = "Driver",
		text = "With whispers set to Off, riders are told nothing: the big button sends no whisper.",
		source = "Settings tooltip (How whispers leave: Off: riders are told nothing)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", opt_whisperMode = "off" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Quick") then ctx:na("the name is taken") end
			openDrive(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			local b = ctx.me.env.WuberDriveButton
			if not (b and ctx:visible(b)) then ctx:na("no big button on screen") end
			for _ = 1, 3 do ctx.me:click(b) ctx:advance(1.5) end
			local sent = myWhispers(ctx, "Zed Quick")
			if #sent > 0 then
				ctx:fail("Whispers are set to Off, you click the big button, and the rider is whispered anyway: " .. sent[1].text)
			end
		end,
	}

	Hunt.promise{
		id = "driver.slash_drive",
		area = "Driver",
		text = "/wuber drive opens the Drive tab and leaves it there; /wuber drive close closes you, /wuber drive open opens you again.",
		source = "/wuber drive help",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			ctx.me:slash("/wuber drive")
			ctx:note("/wuber drive")
			ctx:advance(1)
			if not has(ctx, "^Riders$") then ctx:fail("You type /wuber drive and the Drive tab does not open.", allText(ctx)) end
			ctx:advance(6)
			if not has(ctx, "^Riders$") then
				ctx:fail("You type /wuber drive, the Drive tab opens, and a few seconds later Wuber moves you off it to another tab.", allText(ctx))
			end
			ctx.me:slash("/wuber drive close")
			ctx:note("/wuber drive close")
			ctx:advance(1)
			if DR(ctx).IsOpen() then ctx:fail("You type /wuber drive close and you are still open.") end
			ctx.me:slash("/wuber drive open")
			ctx:note("/wuber drive open")
			ctx:advance(1)
			if not DR(ctx).IsOpen() then ctx:fail("You type /wuber drive open and you are still closed.") end
		end,
	}

	Hunt.promise{
		id = "driver.bell_rings",
		area = "Driver",
		text = "When a rider whispers you, your alert character (on another account) gets an alert banner.",
		source = "Settings tooltip (Alert character: it flashes, beeps and shows a banner when one of your windows needs a click)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Quick") or ctx.w:player("Bell Ringer") then ctx:na("a name is taken") end
			local ok, bellc = pcall(ctx.w.addClient, ctx.w, "Bell Ringer", { spot = "Orgrimmar", class = "MAGE", money = 10000 })
			if not ok then ctx:cannot("could not add a second window: " .. tostring(bellc)) end
			ctx:advance(2)
			local okSet, why = DR(ctx).BellSet("Bell Ringer")
			ctx:note("Alert character set to Bell Ringer")
			if okSet == false then ctx:fail("You set a character on another account as your alert character and Wuber refuses: " .. tostring(why)) end
			ctx:advance(3)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			ctx:advance(3)
			local seen = false
			for _, t in ipairs(bellc:visibleTexts()) do
				if t:find("Zed") or t:find("whisper") then seen = true end
			end
			if not seen then ctx:fail("A rider whispers you, your alert character is set, and its window shows no alert.", table.concat(bellc:visibleTexts(), " | ")) end
		end,
	}
end
