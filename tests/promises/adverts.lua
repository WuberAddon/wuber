-- Promises about adverts in public chat ([Wuber] lines): only from your click on the secure button, the setting that
-- switches the go-online advert off, the 15-minute gap, never in combat, the line's shape, the reminder that never posts.
-- Source above all: Settings > Driving > "Post an advert when I go online" tooltip, the Advertise tooltip, the reminder tooltip.
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
	end
	-- the tooltip's promise: the go-online click posts one line
	local function advertOnlineOn(sit) return sit.advertOnline ~= "off" end
	local PUBLIC = { general = true, trade = true, lookingforgroup = true, services = true }
	local function base(name) return (tostring(name or ""):lower():gsub("^%d+%.%s*", ""):match("^(%a+)")) end

	-- a closed shop, then the Open tap
	local function goOnline(ctx)
		openDrive(ctx)
		closeShop(ctx)
		if DR(ctx).IsOpen() then ctx:cannot("Close did not close") end
		local ok = press(ctx, "^Open$")
		if not ok then ctx:fail("You are closed on the Drive tab and there is no Open button to tap.", allText(ctx)) end
	end

	Hunt.promise{
		id = "adverts.go_online_posts_one",
		area = "Adverts",
		text = "With 'Post an advert when I go online' on, tapping Open also posts one [Wuber] line in public chat (Trade here, not your own Wuber channel).",
		source = "Settings tooltip (Post an advert when I go online); Open tooltip (This click also posts one advert line)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (advertOnlineOn(sit)) end,
		check = function(ctx)
			need(ctx)
			if #myPosts(ctx) > 0 then ctx:na("an advert was already posted in this build") end
			if DR(ctx).AdvertWait and ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			goOnline(ctx)
			local posts = myPosts(ctx)
			if #posts == 0 then
				ctx:fail("You tap Open with 'Post an advert when I go online' on and no advert goes out in public chat.", allText(ctx))
			end
			if #posts > 1 then ctx:fail("You tap Open once and " .. #posts .. " adverts go out in public chat.") end
			if posts[1].kind ~= "CHANNEL" or not PUBLIC[base(posts[1].channel)] then
				ctx:fail("You tap Open and the advert goes to '" .. tostring(posts[1].channel) .. "', not a public channel.", posts[1].text)
			end
		end,
	}

	Hunt.promise{
		id = "adverts.line_shape",
		area = "Adverts",
		text = "The advert line starts with [Wuber], names your place and your price, says to get the Wuber addon, and is short (200 bytes at most) with no link codes.",
		source = "Settings tooltip (the line shown in quotes); Advertise tooltip (always starting [Wuber])",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and (advertOnlineOn(sit)) end,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			local before = #myPosts(ctx)
			goOnline(ctx)
			local posts = myPosts(ctx)
			if #posts <= before then ctx:na("no advert went out") end
			local line = posts[#posts].text
			if not line:find("^%[Wuber%]") then ctx:fail("Your advert in public chat does not start with [Wuber]: " .. line) end
			if #line > 200 then ctx:fail("Your advert in public chat is " .. #line .. " bytes long: " .. line) end
			if line:find("|", 1, true) or line:find("http", 1, true) then ctx:fail("Your advert in public chat holds a link or colour code: " .. line) end
			local place = DR(ctx).Dest and DR(ctx).Dest() or ""
			if place == "" then place = "Ratchet" end
			if not line:find(place, 1, true) then ctx:fail("You summon to " .. place .. " and the advert does not say so: " .. line) end
			local price = DR(ctx).char().price
			local say = ctx.W.Money and ctx.W.Money(price) or nil
			if say and not line:find(say, 1, true) then ctx:fail("Your price is " .. say .. " and the advert does not say so: " .. line) end
			if not line:lower():find("wuber", 5, true) then ctx:fail("The advert does not tell buyers to get the Wuber addon: " .. line) end
		end,
	}

	Hunt.promise{
		id = "adverts.online_off_silent",
		area = "Adverts",
		text = "With 'Post an advert when I go online' off, tapping Open posts nothing in public chat.",
		source = "Settings tooltip (Post an advert when I go online)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "off" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			local before = #myPosts(ctx)
			goOnline(ctx)
			if #myPosts(ctx) > before then ctx:fail("You switched off 'Post an advert when I go online', tap Open, and an advert goes out anyway.", myPosts(ctx)[#myPosts(ctx)].text) end
		end,
	}

	Hunt.promise{
		id = "adverts.never_without_click",
		area = "Adverts",
		text = "Wuber never posts an advert without your click: going online by the /wuber drive open command posts nothing, and no advert appears by itself over twenty minutes open.",
		source = "Settings tooltip (never without your click); reminder tooltip (It never posts by itself)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			local before = #myPosts(ctx)
			ctx.me:slash("/wuber drive close")
			ctx:advance(1)
			ctx.me:slash("/wuber drive open")
			ctx:note("/wuber drive open")
			ctx:advance(2)
			if #myPosts(ctx) > before then ctx:fail("You go online by typing /wuber drive open and an advert goes out in public chat without a click.", myPosts(ctx)[#myPosts(ctx)].text) end
			for _ = 1, 20 do
				ctx:advance(60)
				if #myPosts(ctx) > before then
					ctx:fail("You sit open and an advert appears in public chat by itself, with no click.", myPosts(ctx)[#myPosts(ctx)].text)
				end
			end
		end,
	}

	Hunt.promise{
		id = "adverts.fifteen_minute_gap",
		area = "Adverts",
		text = "Adverts go at most once every 15 minutes: Advertise right after one posts nothing, and works again after 15 minutes.",
		source = "Settings tooltip and Advertise tooltip (At most once every 15 minutes)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "on" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			local start = #myPosts(ctx)
			goOnline(ctx)
			if #myPosts(ctx) ~= start + 1 then ctx:na("the first advert did not go out") end
			press(ctx, "^Advertise!?$")
			if #myPosts(ctx) > start + 1 then ctx:fail("An advert has just gone out and you tap Advertise: a second one goes out within minutes.", myPosts(ctx)[#myPosts(ctx)].text) end
			ctx:advance(905)
			local ok = press(ctx, "^Advertise!?$")
			if not ok then ctx:fail("Fifteen minutes after your advert there is no Advertise button to tap.", allText(ctx)) end
			if #myPosts(ctx) <= start + 1 then ctx:fail("Fifteen minutes after your last advert you tap Advertise and nothing is posted.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "adverts.advertise_button",
		area = "Adverts",
		text = "Tap Advertise and one [Wuber] line goes out in public chat.",
		source = "Advertise tooltip (Posts one line in public chat, always starting [Wuber])",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "off" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			openDrive(ctx)
			local before = #myPosts(ctx)
			local ok = press(ctx, "^Advertise!?$")
			if not ok then ctx:fail("There is no Advertise button on the Drive tab while you are open.", allText(ctx)) end
			local posts = myPosts(ctx)
			if #posts <= before then ctx:fail("You tap Advertise (out of combat, no advert for 15 minutes) and nothing goes out in public chat.", allText(ctx)) end
			if not posts[#posts].text:find("^%[Wuber%]") then ctx:fail("The advert you post does not start with [Wuber]: " .. posts[#posts].text) end
		end,
	}

	Hunt.promise{
		id = "adverts.no_post_in_combat",
		area = "Adverts",
		text = "In combat the Advertise button posts nothing.",
		source = "Settings tooltip and Advertise tooltip (never in combat)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "off", combat = "no" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			openDrive(ctx)
			local before = #myPosts(ctx)
			ctx.w:enterCombat(ctx.me)
			ctx:note("combat starts")
			ctx:advance(1)
			press(ctx, "^Advertise!?$")
			ctx.w:leaveCombat(ctx.me)
			if #myPosts(ctx) > before then ctx:fail("You are in combat, tap Advertise, and an advert goes out in public chat.", myPosts(ctx)[#myPosts(ctx)].text) end
		end,
	}

	Hunt.promise{
		id = "adverts.reminder_rings_not_posts",
		area = "Adverts",
		text = "When an advert is due the console reminds you to tap Advertise; the reminder never posts one for you.",
		source = "Settings tooltip (Advert reminder: The Advertise button turns gold and rings after this many minutes. It never posts by itself)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "off" },
		when = function(sit) return canDrive(sit) and (sit.opt_adEvery ~= "never" and sit.opt_adChannels ~= "services_only") end,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			openDrive(ctx)
			local before = #myPosts(ctx)
			local rang = false
			for _ = 1, 40 do
				ctx:advance(30)
				if has(ctx, "[Tt]ime to advertise") or has(ctx, "^Advertise!$") then rang = true end
				if #myPosts(ctx) > before then ctx:fail("The advert reminder posts an advert by itself.", myPosts(ctx)[#myPosts(ctx)].text) end
				if rang then break end
			end
			if not rang then ctx:fail("You have been open twenty minutes without advertising (reminder on) and nothing reminds you to tap Advertise.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "adverts.capital_uses_services",
		area = "Adverts",
		text = "In a capital city, with the Services channel joined, your advert goes in Services; elsewhere in Trade.",
		source = "Settings tooltip (It goes in Services (in a capital), else Trade, else LookingForGroup, else General)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "on" },
		when = function(sit) return canDrive(sit) and ((sit.opt_adChannels or "default") == "default") end,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			local okj, why = pcall(ctx.w.joinChannel, ctx.w, ctx.me, "Trade (Services) - Orgrimmar")
			if not okj then ctx:cannot("the fake game cannot join a Services channel: " .. tostring(why)) end
			ctx:advance(1)
			ctx.w:move(ctx.name, "Orgrimmar")
			ctx.me:fire("ZONE_CHANGED_NEW_AREA")
			ctx:note("walk to Orgrimmar (a capital)")
			ctx:advance(2)
			local before = #myPosts(ctx)
			goOnline(ctx)
			local posts = myPosts(ctx)
			if #posts <= before then ctx:na("no advert went out") end
			if (ctx.W.ChannelBase and ctx.W.ChannelBase(posts[#posts].channel)) ~= "services" then
				ctx:fail("You tap Open in a capital city with the Services channel joined and the advert goes to " .. tostring(posts[#posts].channel) .. ".", posts[#posts].text)
			end
		end,
	}

	-- a line that fits the 200 the Messages field allows for an advert, as long as it lets you write
	local function longLine()
		local words = "Fast friendly summons to Ratchet today with no waiting around, hop in and I bring you straight over, safe and quick, tips are always welcome and thanks for riding with me, see you soon at the stone, cheers my friends, see you again whenever you need a lift anywhere"
		return (words:sub(1, 198):gsub("%s+$", ""))
	end

	Hunt.promise{
		id = "adverts.own_line_posted_whole",
		area = "Adverts",
		text = "An advert line you write in Messages (within the length it allows) is posted whole, with [Wuber] in front.",
		source = "Messages editor (My advert line: in public chat when you click Advertise; the field's own length counter)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", advertOnline = "off" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.W.AdvertWait and ctx.W.AdvertWait() > 0 then ctx:na("an advert went out less than 15 minutes ago") end
			openDrive(ctx)
			if not press(ctx, "^Messages$") then ctx:fail("There is no Messages button on the Drive tab.", allText(ctx)) end
			if not has(ctx, "^My advert line$") then pressDirect(ctx, "^Messages$") end
			if not press(ctx, "^My advert line$") then ctx:fail("The Messages list has no 'My advert line' row.", allText(ctx)) end
			local box = editBoxWith(ctx, ".")
			if not box then ctx:fail("You tap 'My advert line' in Messages and no box opens.", allText(ctx)) end
			local mine = longLine()
			ctx.me:type(box, mine, false)
			ctx:advance(0.5)
			if not press(ctx, "^Save$") then ctx:fail("You write your advert line and there is no Save button.", allText(ctx)) end
			local saved = ctx.W.db.drive.templates and ctx.W.db.drive.templates.advert
			if saved ~= mine then ctx:na("Messages did not keep the line as written (" .. tostring(saved) .. ")") end
			ctx.W.UI.ShowDrive("console")
			ctx:advance(1)
			local before = #myPosts(ctx)
			press(ctx, "^Advertise!?$")
			local posts = myPosts(ctx)
			if #posts <= before then ctx:fail("You save your own advert line and tapping Advertise posts nothing.", allText(ctx)) end
			local line = posts[#posts].text
			if not line:find("^%[Wuber%] ") then ctx:fail("Your own advert goes out without [Wuber] in front: " .. line) end
			if not line:find(mine, 1, true) then
				ctx:fail("You save an advert line of " .. #mine .. " bytes that Messages accepts, and public chat gets it cut short.", "wrote: " .. mine .. " / posted: " .. line)
			end
		end,
	}

end
