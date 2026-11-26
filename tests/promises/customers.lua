-- Promises about the driver's CUSTOMER BOOK: one note per rider, the Gifted stamp, the rides the list shows and who
-- may see a note. (owner crewearn). Written from what the screens tell the driver: the Note box ("One note per rider,
-- 200 letters at most ... Only you and the crew windows you marked as your own accounts see it; the rider never does."),
-- Save ("To remove one, empty the box and click Save twice"), Gifted ("it stamps today's date, so you never gift the
-- same person twice"), the Customers page ("Riders who pay you show here, the latest first").
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

	local function riderName(ctx)
		local n = ctx.facts.riderName
		if not n then ctx:cannot("no customer in this situation") end
		return n
	end

	local function customersUp(ctx)
		if not find(ctx, "^Customers$") then ctx:cannot("the Customers screen is not up") end
	end

	-- the note box of the right pane or the Note sheet: the last visible edit box (the search box is made first)
	local function noteBox(ctx)
		local boxes = {}
		for _, obj in ipairs(ctx.me:findText("")) do
			local okT, ty = pcall(obj.GetObjectType, obj)
			if okT and ty == "EditBox" then boxes[#boxes + 1] = obj end
		end
		return boxes[#boxes]
	end

	local function pick(ctx, name)
		local ok = pcall(ctx.me.clickText, ctx.me, "^" .. name .. "$", { pattern = true })
		if not ok then ctx:cannot("the customer " .. name .. " is not listed on Customers") end
		ctx:advance(0.5)
		ctx:note("click " .. name .. " in the Customers list")
	end

	local function typeNote(ctx, text)
		local box = noteBox(ctx)
		if not box then ctx:cannot("no note box on screen") end
		ctx.me:type(box, text, false)
		ctx:note("type the note: " .. text)
	end

	local function save(ctx)
		local ok = pcall(ctx.me.clickText, ctx.me, "^Save$", { pattern = true })
		if not ok then ctx:cannot("no Save button on screen") end
		ctx:advance(0.5)
		ctx:note("click Save")
	end

	local function noteOf(ctx, name)
		local rec = dr(ctx).BookEntry(name)
		return rec and rec.note or nil
	end

	local function onlyPaid(sit) return sit.role == "warlock" end

	Hunt.promise{
		id = "customers.note_saved",
		area = "Customers",
		text = "You pick a customer, type a note, click Save, and the note is kept, also after a /reload.",
		source = "tooltip (Note, Save); BRIEF17 B1; CHANGELOG 2.3.0 (customer book)",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = onlyPaid,
		check = function(ctx)
			local name = riderName(ctx)
			customersUp(ctx)
			pick(ctx, name)
			typeNote(ctx, "Likes quick rides")
			save(ctx)
			if noteOf(ctx, name) ~= "Likes quick rides" then
				say(ctx, "You pick %s on Customers, type a note, click Save and the note is not kept (the book holds %s).", name, tostring(noteOf(ctx, name)))
			end
			if not find(ctx, "Note saved for") and not find(ctx, "Saved") then
				ctx:fail("You click Save on a customer's note and nothing says it was saved.")
			end
			ctx:reload()
			if noteOf(ctx, name) ~= "Likes quick rides" then
				say(ctx, "You saved a note for %s, then /reload, and the note is gone.", name)
			end
		end,
	}

	Hunt.promise{
		id = "customers.note_removed",
		area = "Customers",
		text = "To remove a note you empty the box and click Save twice: the first click asks, the second removes it.",
		source = "tooltip (Save: To remove one, empty the box and click Save twice); BRIEF17 B1",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = onlyPaid,
		check = function(ctx)
			local name = riderName(ctx)
			customersUp(ctx)
			if not dr(ctx).SetNote(name, "Tips well") then ctx:cannot("could not set a first note") end
			ctx:advance(0.5)
			pick(ctx, name)
			typeNote(ctx, "")
			save(ctx)
			if noteOf(ctx, name) == nil then ctx:fail("You empty a note and click Save once and the note is already gone (it should ask first).") end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Remove note%?$", { pattern = true })
			if not ok then save(ctx) end
			ctx:advance(0.5)
			if noteOf(ctx, name) ~= nil then
				say(ctx, "You empty a customer's note and click Save twice and the note is still there (%s).", tostring(noteOf(ctx, name)))
			end
		end,
	}

	Hunt.promise{
		id = "customers.gifted_once",
		area = "Customers",
		text = "Gifted stamps today's date on a customer once; a second click only tells you when they were gifted, and the date never changes.",
		source = "tooltip (Gifted: it stamps today's date, so you never gift the same person twice)",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = onlyPaid,
		check = function(ctx)
			local name = riderName(ctx)
			customersUp(ctx)
			pick(ctx, name)
			local function gift()
				local ok = pcall(ctx.me.clickText, ctx.me, "^Gifted", { pattern = true })
				if not ok then ctx:cannot("no Gifted button on screen") end
				ctx:advance(0.3)
				ctx:note("click Gifted")
			end
			gift()
			local rec = dr(ctx).BookEntry(name)
			local first = rec and rec.gift
			if not first then say(ctx, "You click Gifted on %s and no stamp is kept.", name) end
			if not find(ctx, "stamped gifted") then ctx:fail("You click Gifted and no message says the customer was stamped.") end
			ctx:advance(120)
			gift()
			local again = dr(ctx).BookEntry(name)
			if not find(ctx, "already gifted") then ctx:fail("You click Gifted a second time and nothing says they were already gifted.") end
			if not again or again.gift ~= first then ctx:fail("You click Gifted twice and the stamp's date changed.") end
			ctx:reload()
			local kept = dr(ctx).BookEntry(name)
			if not kept or kept.gift ~= first then ctx:fail("You stamped a customer Gifted, then /reload, and the stamp is gone.") end
		end,
	}

	Hunt.promise{
		id = "customers.rides_listed",
		area = "Customers",
		text = "A rider who paid you shows on Customers with their rides, the day of the last one and where it went.",
		source = "Customers page text (Riders who pay you show here, the latest first)",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = onlyPaid,
		check = function(ctx)
			local name = riderName(ctx)
			customersUp(ctx)
			if not find(ctx, "^" .. name .. "$") then say(ctx, "%s paid you a minute ago and is not on the Customers list.", name) end
			if not find(ctx, "^1 ride") then say(ctx, "%s paid you once and the Customers list does not say 1 ride.", name) end
			local place = tostring(dr(ctx).Dest and dr(ctx).Dest() or "Ratchet")
			if not find(ctx, "last %d+ %a+ · " .. place:gsub("%p", "%%%0")) then
				say(ctx, "%s paid you for a summon to %s and the Customers list does not give the day and %s.", name, place, place)
			end
		end,
	}

	Hunt.promise{
		id = "customers.close_payments_one_ride",
		area = "Customers",
		text = "A fare and a tip paid minutes apart count as one ride for that customer; a payment much later is another ride.",
		source = "Drive.Book header (rides within 30 minutes are one ride); inferred",
		kind = "scenario",
		needs = { phone = "drive_customers" },
		when = onlyPaid,
		check = function(ctx)
			customersUp(ctx)
			local l = ctx.W.db.drive.log
			local t = ctx.me.env.time() - 86400
			for _, off in ipairs({ 0, 600, 2800 }) do
				table.insert(l.rides, (t + off) .. ",5000,Tess Regular,Ratchet,t,5000")
			end
			ctx:note("saved history: three payments by Tess Regular: now, +10 min, +47 min")
			ctx.W.Drive.Customers("tess") -- (the list reads the log afresh when it is shown again)
			ctx:reload()
			ctx.W.UI.ShowDrive("customers")
			ctx:advance(1)
			if not find(ctx, "^Tess Regular$") then ctx:cannot("Tess Regular is not listed") end
			if not find(ctx, "^2 rides") then
				say(ctx, "Tess Regular paid you three times (two within ten minutes, one 47 minutes after) and the Customers list does not say 2 rides.")
			end
		end,
	}

	-- the crew window of mine that is another player (not me)
	local function mate(ctx)
		return ctx.peers.summoner or ctx.peers.captain
	end

	Hunt.promise{
		id = "customers.notes_stay_private",
		area = "Customers",
		text = "A note is only yours: a crew window you have not marked as your own account never gets it, and no rider hears it.",
		source = "tooltip (Note: Only you and the crew windows you marked as your own accounts see it; the rider never does)",
		kind = "scenario",
		when = function(sit) return sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			local other = mate(ctx)
			if not other then ctx:cannot("no crew window") end
			local name = ctx.facts.riderName or "Dan Miller"
			local secret = "ZZsecretnoteZZ"
			-- saved data can already mark the crew mate as an own account (acct1 does): the promise is about a mate who is NOT marked
			do
				local mine, theirs = key(ctx.name), key(other.player.name)
				local D, OD = dr(ctx), other.W.Drive
				if D.BookOwn and D.BookOwn(theirs) then D.SetBookOwn(theirs, false) ctx:note("unmark " .. other.player.name .. " as my own account") end
				if OD and OD.BookOwn and OD.BookOwn(mine) then OD.SetBookOwn(mine, false) end
				if D.BookOwn and D.BookOwn(theirs) then ctx:na("the crew mate is marked as an own account and cannot be unmarked") end
			end
			if not dr(ctx).SetNote(name, secret) then ctx:cannot("could not set a note") end
			ctx:note("write the note " .. secret .. " for " .. name)
			ctx:advance(150)
			local rec = other.W.Drive.BookEntry(name)
			if rec and rec.note then
				say(ctx, "You write a private note for %s and %s, a crew mate you have NOT marked as your own account, can read it.", name, other.player.name)
			end
			for _, e in ipairs(ctx.w.addonLog or {}) do
				if type(e.text) == "string" and e.text:find(secret, 1, true) then
					local to = tostring(e.target or e.chatType)
					if e.chatType ~= "WHISPER" or key(to) ~= key(other.player.name) then
						say(ctx, "You write a private note and it goes out in a %s addon message to %s.", tostring(e.chatType), to)
					else
						say(ctx, "You write a private note and Wuber sends it to %s, a crew mate you have not marked as your own account.", to)
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "customers.notes_reach_own_account",
		area = "Customers",
		text = "A note reaches a crew window once both windows are marked as your own accounts, and stays on yours if you switch sharing off.",
		source = "tooltip (Save: Your own accounts get it too, once each has marked the other on the Crew page); Settings: Share notes with my own accounts",
		kind = "scenario",
		when = function(sit) return (sit.role == "friend" or sit.role == "crew") and sit.opt_shareNotes ~= "off" end,
		check = function(ctx)
			-- the group dial replaces the captain's group, so the crew or friend window is no longer in the player's group; notes sync by design
			-- only to a window heard in the last 45 s (Drive/Book.lua BookPeers), and hellos only come from group members: so the
			-- player invites the other window into the group first
			if (ctx.sit.group == "party" or ctx.sit.group == "raid") and (ctx.sit.role == "crew" or ctx.sit.role == "friend") then
				local mateWin = mate(ctx)
				if mateWin and not (mateWin.player.group and mateWin.player.group == ctx.me.player.group) then
					if mateWin.player.group then ctx.w:leave(mateWin.player.name) ctx:advance(1) end
					ctx.w:join(ctx.me.player, mateWin.player)
					ctx:note("invite the other window into the group")
					ctx:advance(5)
				end
			end
			local other = mate(ctx)
			if not other then ctx:cannot("no crew window") end
			local name = "Dan Miller"
			local mine, theirs = key(ctx.name), key(other.player.name)
			-- the Crew card's "my account" switch, on each window for the other
			if not dr(ctx).SetBookOwn(theirs, true) then ctx:cannot("could not mark the crew window as my account") end
			other.W.Drive.SetBookOwn(mine, true)
			ctx:note("both windows mark each other as my own account")
			ctx:advance(20)
			dr(ctx).SetNote(name, "Always asks for the Barrens")
			ctx:note("write a note for " .. name)
			ctx:advance(90)
			local rec = other.W.Drive.BookEntry(name)
			if not (rec and rec.note == "Always asks for the Barrens") then
				say(ctx, "You mark both windows as your own accounts, write a note for %s, and after a minute and a half the other window has %s.", name, tostring(rec and rec.note))
			end
		end,
	}
end
