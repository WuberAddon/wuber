-- Promises from the Google contradiction leads (LEADS-1 judge). Each id is leads.c### and says what the player sees
-- when it fails. See tests/out/hunt-scratch/leads1/verdicts.tsv for the full verdicts.
return function(Hunt)
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")) end
	local function find(ctx, pat) for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p, t end end return nil end
	local function logOf(ctx) local d = ctx.W.db and ctx.W.db.drive return d and d.log end
	local function env(ctx) return ctx.me.env end

	local function earnings(ctx)
		local S = ctx:mod("UI.Driver.Screens")
		local e = S and S.st and S.st.screens and S.st.screens.earnings
		if not (e and e.heat) then ctx:cannot("the Earnings screen is not built") end
		if not (find(ctx, "Gold an hour, by time of day") or find(ctx, "My target per hour")) then ctx:cannot("the Earnings screen is not up") end
		return e
	end

	-- the heatmap that is showing (the card, or the side pane's when unfolded) and its square for weekday/hour
	local function squareAt(ctx, e, t)
		local heat = (e.heatW and ctx:visible(e.heatW)) and e.heatW or e.heat
		local wd, hr = tonumber(env(ctx).date("%w", t)), tonumber(env(ctx).date("%H", t))
		for _, b in ipairs(heat.cells or {}) do
			if b.wday == wd and b.hour == hr then return b, heat end
		end
		ctx:cannot("no heatmap square for that hour")
	end

	local function hourKey(ctx, t) return env(ctx).date("%Y%m%d%H", t) end

	local function colourOf(ctx, b)
		local s = ctx.H.state[b.fill]
		return s and s.color
	end

	Hunt.promise{
		id = "leads.c052_violet_only_when_closed",
		area = "Earnings",
		text = "On the Earnings heatmap a violet square means buyers asked while you were closed; an hour you were open is never violet.",
		source = "Google lead C052: UI/Driver/Earnings.lua:946-947 (tooltip) vs 1011-1013 (heatColour)",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earnings(ctx)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			l.open[hourKey(ctx, t)] = 60 -- open the whole hour
			table.insert(l.asks, t .. ",nomatch,Buyer Bob,wtb summon")
			ctx:note("the log: open 60 minutes this hour, one buyer asked, no gold")
			ctx:advance(2)
			if type(e.update) == "function" then e.update() end
			ctx:advance(1)
			local b = squareAt(ctx, e, t)
			local c = colourOf(ctx, b)
			local r, g, bl = ctx.W.Theme.RGB("accent")
			if c and math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - bl) < 0.01 then
				ctx:fail("You were open this whole hour, a buyer asked and you earned nothing: the heatmap paints the hour violet, which its tooltip says means buyers asked while you were closed.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c050_short_hour_no_rate",
		area = "Earnings",
		text = "A heatmap hour you were open for under half an hour shows no gold-per-hour rate (the best-hours list ignores it too).",
		source = "Google lead C050: Drive/Log.lua:544,603 (30 open minutes needed) vs UI/Driver/Earnings.lua:968,1030",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earnings(ctx)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			l.open[hourKey(ctx, t)] = 2 -- open two minutes this hour
			table.insert(l.rides, t .. ",5000,Quick Customer,Ratchet,t,5000")
			ctx:note("the log: open 2 minutes this hour, one 50s ride")
			ctx:advance(2)
			if type(e.update) == "function" then e.update() end
			ctx:advance(1)
			local b = squareAt(ctx, e, t)
			ctx.me:clickOn(b)
			ctx:note("tap this hour's square")
			ctx:advance(0.5)
			local p = find(ctx, "/h")
			local q = p and p:find("open 2 min") and p
			if not q then
				for _, tx in ipairs(ctx:texts()) do local s = strip(tx) if s:find("/h") and s:find("%d%d:00") then q = s end end
			end
			if q then
				ctx:fail("You tap an hour you were open for 2 minutes and it shows a gold-per-hour rate (" .. q .. "), where the best-hours list needs 30 open minutes.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c051_reset_changes_earnings",
		area = "Earnings",
		text = "Reset stats (clicked twice) clears the /wuber drive stats and session counters; the Earnings totals come from the hour-by-hour log and stay. (job 146: was 'sets the Earnings counters to zero'; Earnings.lua:653 tooltip, HUNT-15.)",
		source = "Google lead C051: UI/Driver/Earnings.lua:615-639 (tooltip) vs 653 (LogTotals) and Drive/Log.lua:386-392",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earnings(ctx)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			table.insert(l.rides, t .. ",5000,Quick Customer,Ratchet,t,5000")
			ctx:note("the log: one 50s ride today")
			ctx:advance(2)
			if type(e.update) == "function" then e.update() end
			ctx:advance(1)
			local before = find(ctx, "^%d+ rides? ")
			-- (a saved main already has rides: the line says "N rides", so compare before and after, not "1 ride")
			local n0 = before and tonumber(before:match("^(%d+)"))
			if not n0 or n0 < 1 then ctx:cannot("the Earnings totals line does not show the ride (" .. tostring(before) .. ")") end
			-- (job 146: the button sits under the tab bar until a player scrolls the page down)
			do
				local Sc = ctx:mod("UI.Driver.Screens")
				local sx = Sc and Sc.st and Sc.st.screens and Sc.st.screens.earnings
				if sx and sx.scroll and sx.scroll.ScrollTo then
					pcall(sx.scroll.ScrollTo, sx.scroll, sx.scroll.max or 0, true)
					ctx:advance(0.5)
				end
			end
			ctx.me:clickText("Reset stats")
			ctx:advance(0.3)
			if not find(ctx, "Click again to reset") then ctx:cannot("the first click on Reset stats did not reach the button") end
			ctx.me:clickText("Click again to reset")
			ctx:advance(1)
			ctx:note("Reset stats, clicked twice")
			local after = find(ctx, "^%d+ rides? ")
			local n1 = after and tonumber(after:match("^(%d+)"))
			-- the totals come from the log: they must NOT drop because of the reset
			if n1 and n1 < n0 then
				ctx:fail("You click Reset stats twice and the Earnings totals went down to \"" .. after:sub(1, 40) .. "\", though they come from the hour-by-hour log, which stays.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c010_bird_no_zero_saving",
		area = "Bird",
		text = "The Skip the bird card never says the summon saves 0 gold.",
		source = "Google lead C010: UI/Bird.lua:225-226 (comment: savings branch when the flight costs more) vs 231-236 (also fires at equal cost)",
		kind = "scenario",
		check = function(ctx)
			local Bird = ctx:mod("UI.Bird")
			if not (Bird and type(Bird.Message) == "function") then ctx:cannot("no UI.Bird.Message") end
			local text = strip(Bird.Message({ short = "Mia", dest = "Orgrimmar", price = 5000 }, { cost = 5000, secs = 300, about = false }))
			ctx:note(text)
			if text:find("saves free") or text:find("saves 0") or text:find("saves nothing") then
				ctx:fail("At a flight master where the summon costs exactly what the flight costs, the card says: " .. text)
			end
		end,
	}

	Hunt.promise{
		id = "leads.c020_bug_note_names_left_out",
		area = "Bug report",
		text = "The bug report leaves out other players' names, including one you type in What happened?",
		source = "Google lead C020: UI/Bug.lua:365,371 (Other players' names are left out) vs 288 (the note only goes through anonymise, not anonymiseRealms)",
		kind = "scenario",
		check = function(ctx)
			local Bug = ctx.W.UI and ctx.W.UI.Bug
			if not (Bug and type(Bug.Report) == "function") then ctx:cannot("no UI.Bug.Report") end
			local text = Bug.Report("Quinn-Argent whispered me and then my request failed")
			if text:find("Quinn%-Argent") then
				ctx:fail("You type another player's Name-Realm in What happened? and the report you copy still has it (Quinn-Argent), though the window says other players' names are left out.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c021_bug_error_realm",
		area = "Bug report",
		text = "In the bug report's error lines a player written as Name-Realm becomes player N, realm and all.",
		source = "Google lead C021: UI/Bug.lua:295 (anonymise before anonymiseRealms) and 143 (isWordByte: - is not a word byte)",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local W = ctx.W
			local Bug = W.UI and W.UI.Bug
			if not (Bug and type(Bug.Report) == "function") then ctx:cannot("no UI.Bug.Report") end
			local DR = W.Drive
			if type(DR) ~= "table" then ctx:cannot("no driver engine") end
			DR.units = DR.units or {}
			DR.units["zed"] = { name = "Zed" } -- Wuber holds the bare name Zed (a group member, as UnitName gives it)
			W.errorLog = W.errorLog or {}
			table.insert(W.errorLog, { at = 0, where = "request", text = "no reply from Zed-Argent", n = 1 })
			ctx:note("an error line names Zed-Argent while Wuber holds Zed")
			local text = Bug.Report("")
			if text:find("Argent") then
				ctx:fail("A bug report's error line says " .. (text:match("[^\n]*Argent[^\n]*") or "?") .. ": the player became player N but the realm stayed in.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c022_bug_escape_closes",
		area = "Bug report",
		text = "Pressing Escape once closes the bug report window you just opened with /wuber bug.",
		source = "Google lead C022: UI/Bug.lua:348-353,403 (UISpecialFrames, auto-focus) vs Theme/Forms.lua:139-143 (Escape in a focused box only lets go)",
		kind = "scenario",
		check = function(ctx)
			local Bug = ctx.W.UI and ctx.W.UI.Bug
			if not (Bug and type(Bug.Open) == "function") then ctx:cannot("no UI.Bug") end
			ctx.me:slash("/wuber bug")
			ctx:advance(0.5)
			if not Bug.Shown() then ctx:cannot("/wuber bug did not open the window") end
			ctx:note("/wuber bug")
			-- the real client gives Escape to a focused edit box first (its OnEscapePressed), and only otherwise closes special windows
			local box = Bug.frame and Bug.frame.copy and Bug.frame.copy.edit
			if box and box:HasFocus() then
				local fn = box:GetScript("OnEscapePressed")
				if fn then fn(box) end
				ctx:note("Escape (the box has the keyboard)")
			else
				ctx.me:pressEscape()
				ctx:note("Escape")
			end
			ctx:advance(0.3)
			if Bug.Shown() then
				ctx:fail("You type /wuber bug and press Escape once: the report window stays open (the first Escape only lets go of the keyboard).")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c024_price_command_cap",
		area = "Driver",
		text = "/wuber price keeps your price within what Wuber can show drivers (99,999,999 copper at most).",
		source = "Google lead C024: UI/Commands.lua:153-154 (DR.SetPrice caps, then c.price is overwritten with the uncapped number)",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local W = ctx.W
			ctx.me:slash("/wuber price 50000g")
			ctx:advance(0.5)
			local price = W.Char and W.Char().price
			if type(price) == "number" and price > 99999999 then
				ctx:fail("You type /wuber price 50000g and your price is saved as " .. price .. " copper, above the 99,999,999 the driver engine and the network allow.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c026_missing_parts_notice",
		area = "Start up",
		text = "After a /reload that leaves a newer part of Wuber unloaded, login says to restart the game.",
		source = "Google lead C026: UI/Commands.lua:558-571 (W.MissingParts checks only the 12 old Drive parts and UI.ShowDrive)",
		kind = "scenario",
		check = function(ctx)
			local W = ctx.W
			if type(W.MissingParts) ~= "function" then ctx:cannot("no W.MissingParts") end
			local gone = {}
			for _, name in ipairs({ "Bug", "Tips", "Fold", "Bird" }) do
				if type(W.UI[name]) == "table" then gone[#gone + 1] = name W.UI[name] = nil end
			end
			if #gone == 0 then ctx:cannot("none of UI.Bug, UI.Tips, UI.Fold, UI.Bird to leave unloaded") end
			ctx:note("after a /reload these are not loaded: UI." .. table.concat(gone, ", UI."))
			local missing = W.MissingParts()
			if #missing == 0 then
				ctx:fail("A /reload after an update leaves UI." .. table.concat(gone, ", UI.") .. " unloaded and the login check finds nothing missing, so no restart notice shows.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c035_notes_stay_on_character",
		area = "Customers",
		text = "With Share notes with my own accounts off, customer notes stay on this account (the tooltip says so).",
		source = "Google lead C035: UI/Settings/Rows.lua:846-848 (Off: they stay on this account, now true) vs Drive/Book.lua:22,128-136 (the book is W.db.drive, account-wide)",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local W = ctx.W
			local DR = W.Drive
			if not (DR and type(DR.SetNote) == "function" and type(DR.SetOpt) == "function") then ctx:cannot("no Drive.SetNote") end
			DR.SetOpt("shareNotes", false)
			ctx:note("Share notes with my own accounts: off")
			DR.SetNote("Some Rider", "likes the long way round")
			ctx:note("save a note on Some Rider")
			local acct = W.db and W.db.drive and W.db.drive.book
			if type(acct) ~= "table" then
				ctx:fail("You switch note sharing off and save a note: it is not kept on the account (W.db.drive.book), though the switch says it stays on this account.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c017_demand_follows_switch",
		area = "Bounty",
		text = "With Show what riders want switched off, what riders want is not listed or drawn. (job 146: the raw heard list W.Bounty.Demand() keeps the wish on purpose, CHANGELOG-2.3.4 line 251; what is listed is the Demand screen's List and what the World map draws.)",
		source = "Google lead C017: Net/Bounty.lua:31,243 (header, heard) vs 279-304 (Demand never checks watchBounty) and UI/Rider/WorldMap.lua:981",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" and sit.opt_watchBounty ~= "off" end, -- (with the switch off Bounty.heard drops the bounty on purpose)
		check = function(ctx)
			local W = ctx.W
			local B = ctx:mod("Net.Bounty")
			if not (B and type(B.heard) == "function") or not (W.Bounty and type(W.Bounty.Demand) == "function") then ctx:cannot("no Net.Bounty") end
			local place
			for _, p in ipairs(W.PLACES or {}) do if p.kind ~= "zone" and p.name and not W.SamePlace(p.name, "Ratchet") then place = p.name break end end
			if not place then ctx:cannot("no place to pin") end
			B.heard("Rider One-Realm", "Rider One", "rider one", { place, 5000, W.Faction(), 10 })
			if #W.Bounty.Demand() == 0 then ctx:cannot("the bounty was not heard (switch on)") end
			ctx:note("a rider's bounty for " .. place .. " is heard")
			do
				local DM0 = ctx:mod("UI.Driver.Demand")
				local ok0, l0 = pcall(DM0 and DM0.List or function() return {} end, 8)
				if not (ok0 and type(l0) == "table" and #l0 > 0) then ctx:na("the Demand list shows nothing even with the switch on here") end
			end
			W.Drive.SetOpt("watchBounty", false)
			ctx:note("Show what riders want: off")
			-- (job 146) what the player is shown: the Demand list of the Drive screens (empty when the switch is off)
			local DM = ctx:mod("UI.Driver.Demand")
			if not (DM and type(DM.List) == "function") then ctx:cannot("no UI.Driver.Demand.List") end
			local ok, list = pcall(DM.List, 8)
			if not ok then error(list, 0) end
			if type(list) == "table" and #list > 0 then
				ctx:fail("You switch Show what riders want off and the bounty heard a minute ago (" .. place .. ") is still listed on your Drive screen.")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c003_long_advert_not_cut",
		area = "Adverts",
		text = "A driver's own advert line of 200 bytes (the Messages editor's limit) is posted whole, after the [Wuber] tag.",
		source = "Google lead C003: UI/Driver/Messages.lua:72,342 (limit 200, Wuber adds [Wuber] in front) vs Net/Outreach.lua:172 (tag plus text cut to 200)",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local W = ctx.W
			local DR = W.Drive
			if not (DR and type(DR.SetTemplate) == "function" and type(W.AdvertOwnText) == "function") then ctx:cannot("no advert editor") end
			local text = ("Fast friendly summons from a patient Warlock who never rushes you "):rep(4):sub(1, 200):gsub("%s+$", "")
			text = text .. ("x"):rep(200 - #text)
			if #text ~= 200 then ctx:cannot("the test line is not 200 bytes") end
			local ok = DR.SetTemplate("advert", text)
			if ok ~= true then ctx:cannot("the editor refused the 200 byte line") end
			ctx:note("Messages > Advert: a 200 byte line saved")
			local line = W.AdvertOwnText(DR.Template("advert"))
			if not line then ctx:cannot("no advert line made") end
			if line:sub(-#text) ~= text then
				ctx:fail("You save a 200 byte advert (the editor said 200 / 200 and that Wuber adds [Wuber] in front) and the posted line loses its last " .. (#text + #W.ADVERT_TAG + 1 - #line) .. " bytes (" .. #line .. " bytes posted).")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c018_bounty_cancel_reaches_drivers",
		area = "Bounty",
		text = "Taking your bounty down tells drivers who heard it to drop it (a cancel goes out for the place they heard).",
		source = "Google lead C018: Net/Bounty.lua:137-144 (finish sends only when b.sends > 0) with Pin at 164 (a newer bounty starts at sends = 0 inside the 60 s gap)",
		kind = "scenario",
		needs = { ride = "none" }, -- (Bounty.Pin refuses while a ride is under way)
		when = function(sit) return sit.role == "rider" or sit.role == nil end,
		check = function(ctx)
			local W = ctx.W
			local B = W.Bounty
			if not (B and type(B.Pin) == "function" and type(B.Cancel) == "function") then ctx:cannot("no Net.Bounty") end
			local sent = {}
			local real = W.SendChannel
			W.SendChannel = function(kind, place, copper, ...)
				if kind == "W" then sent[#sent + 1] = { place = place, copper = copper } end
				return real(kind, place, copper, ...)
			end
			-- the places to pin: Bounty.Pin refuses a place an open driver serves ("served") or any pin while a ride is on ("ride"),
			-- so each place is tried with Pin itself and a refused one is skipped
			local cands = {}
			for _, p in ipairs(W.PLACES or {}) do
				if p.kind ~= "zone" and p.name then cands[#cands + 1] = p.name end
			end
			local a, b, okA, okB
			for _, p in ipairs(cands) do
				if B.Pin(p, 5000) then a, okA = p, true break end
			end
			if not a then W.SendChannel = real ctx:na("no place accepts a bounty (every pin was refused)") end
			ctx:note("pin a bounty for " .. a)
			ctx:advance(5)
			for _, p in ipairs(cands) do
				if not W.SamePlace(p, a) and B.Pin(p, 5000) then b, okB = p, true break end
			end
			if not b then W.SendChannel = real ctx:na("no second place accepts a bounty") end
			ctx:note("pin a bounty for " .. b .. " five seconds later (inside the one minute gap)")
			ctx:advance(5)
			B.Cancel()
			ctx:note("take the bounty down")
			ctx:advance(80)
			W.SendChannel = real
			local heardA, cancelledA = false, false
			for _, s in ipairs(sent) do
				if s.place == a and s.copper and s.copper > 0 then heardA = true end
				if s.place == a and s.copper == 0 then cancelledA = true end
			end
			if not heardA then ctx:cannot("the first bounty was never sent") end
			if not cancelledA then
				ctx:fail("You pin a bounty for " .. a .. ", change it to " .. b .. " within a minute and take it down: no cancel for " .. a .. " ever goes out, so drivers keep seeing " .. a .. " until it expires.")
			end
		end,
	}
end
