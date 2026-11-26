-- Promises that the 2.4 hunt's long random sessions found and no short test pinned (tests/promises/v24_rerun.lua).
-- Each builds its state directly the way a player would and checks the one thing the judge's ruling names
-- (tests/out/hunt-scratch/097/judge4/RULINGS.md: F025, F027, F032, F010). Layout is judged with the layout engine the
-- universal layout promise uses (tests/layout/engine.lua through tests/hunt/lib/universal_util.lua).
return function(Hunt)
	local U = dofile("tests/hunt/lib/universal_util.lua")
	local E = U.E
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")) end
	local function find(ctx, pat)
		for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p end end
		return nil
	end
	local function press(ctx, pat, o)
		o = o or {}
		o.pattern = true
		local ok, err = pcall(ctx.me.clickText, ctx.me, pat, o)
		ctx:note("click " .. pat)
		ctx:advance(o.wait or 1)
		return ok, err
	end
	-- the hits of the layout engine whose key or text matches pat, of one kind (nil: any)
	local function hits(ctx, pat, kind)
		local ok, list = pcall(E.check, ctx.me, { TL = U.TL })
		if not ok then error("layout checker threw: " .. tostring(list), 0) end
		local out = {}
		for _, h in ipairs(list) do
			local s = tostring(h.key) .. " " .. tostring(h.what) .. " " .. tostring(h.detail)
			if (not kind or h.kind == kind) and s:find(pat) and not U.allowed("rerun", h) then out[#out + 1] = h end
		end
		return out
	end
	local function describe(list)
		local t = {}
		for i, h in ipairs(list) do if i <= 3 then t[#t + 1] = h.kind .. ": " .. tostring(h.what or h.key) .. " | " .. tostring(h.detail) end end
		return table.concat(t, " ;; ")
	end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end
	local function closeNotes(ctx)
		-- the What's new card / simpler note can take the first tap (older saved data): close what is over the page
		for _, pat in ipairs({ "^Got it$", "^Close$", "^Skip$" }) do
			if find(ctx, "What's new") or find(ctx, "simpler now") then press(ctx, pat, { wait = 0.5 }) end
		end
	end

	-- the mouse wheel on every visible scroll view of Wuber's (what a player does with the page)
	local function wheel(ctx, delta)
		local c = ctx.me
		for _, f in ipairs(c.frames) do
			local st = U.S[f]
			if st.shown and st.scripts and st.scripts.OnMouseWheel and U.isWuber(f) and U.H.visible(f) then
				c.world.hardware = nil
				pcall(U.H.runScript, f, "OnMouseWheel", delta)
			end
		end
		ctx:advance(0.5)
	end
	local function bigger(ctx, scale)
		pcall(function() ctx.W.db.scale = scale ctx.W.UI.ApplyScale() end)
		ctx:advance(0.5)
	end

	local MATES = { "Alder Mate", "Birch Mate", "Cedar Mate", "Dune Mate", "Elm Mate", "Fir Mate", "Gorse Mate", "Holly Mate", "Ivy Mate" }
	local function DR(ctx) return ctx.W.Drive end

	-- a driver in Raid summons mode with one raider who is not here (the raid page shows "Not here (1)")
	local function raidWithAway(ctx, want)
		noCombat(ctx)
		if not (DR(ctx) and DR(ctx).RaidOn) then ctx:cannot("no raid module") end
		if not find(ctx, "^Raid summons$") then ctx:cannot("no Raid summons tab on screen") end
		if not press(ctx, "^Raid summons$") then ctx:cannot("no Raid summons tab") end
		if not press(ctx, "^Start", { wait = 2 }) then ctx:cannot("no Start button") end
		if not DR(ctx).RaidOn() then ctx:cannot("raid summons did not start") end
		local away = "Orgrimmar"
		if tostring(ctx.me.player.zone or "") == "Orgrimmar" then away = "Undercity" end
		if not ctx.w:player(MATES[1]) then ctx:cannot("no raider " .. MATES[1]) end
		ctx.w:move(MATES[1], away)
		ctx:advance(5)
		if not find(ctx, "^Not here %(%d+%)") then ctx:na("the raid page shows no Not here header here") end
		-- raiders who ask in raid chat fill the list until the page is longer than the window: the header then lies below the edge
		-- and the page shows its small "below" pill
		if want then
			for i = 2, #MATES do
				if find(ctx, want) then break end
				if not ctx.w:player(MATES[i]) then break end
				ctx.w:move(MATES[i], away)
				ctx:advance(2)
				ctx.w:chatFrom(MATES[i], "123", "RAID")
				ctx:advance(2)
			end
		end
	end

	local RAID_NEEDS = { phone = "drive", role = "warlock", group = "raid" }

	Hunt.promise{
		id = "rerun.raid_cue_only_on_raid_page",
		area = "Raid summons",
		text = "The Raid page's small 'below' pill (\"Not here (1) below\") is only on the Raid page: when you open Messages, Earnings or Crew it is not drawn over them.",
		source = "judge4 F025/F026 (HUNT-115 family: the cue was lifted clear of Settings and sheets only)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid", fold = "narrow" },
		check = function(ctx)
			raidWithAway(ctx, "[Bb]elow")
			ctx:advance(2)
			if not find(ctx, "[Bb]elow") then ctx:na("the Raid page's small 'below' pill is not up here") end
			-- Messages, Earnings and Crew open over the Drive page through UI.ShowDrive (the Settings "Edit" button, the console's
			-- crew chips and today line call it); the Raid page's pill is lifted clear of Settings and sheets, not of these
			local function cueUp() return find(ctx, "[Mm]ore below") or find(ctx, "Not here %(%d+%) below") end
			local u = ctx.W.UI
			if not (u and u.ShowDrive) then ctx:cannot("no UI.ShowDrive") end
			local tried = 0
			for _, screen in ipairs({ "messages", "earnings", "crew", "blocked", "customers" }) do
				if not press(ctx, "^Raid summons$") then ctx:cannot("no Raid summons tab") end
				ctx:advance(2)
				if cueUp() then
					tried = tried + 1
					ctx:note("UI.ShowDrive " .. screen)
					if not u.ShowDrive(screen) then ctx:note("the " .. screen .. " screen did not open") else
						ctx:advance(2)
						local cue = cueUp()
						if cue then
							ctx:fail("You open " .. screen .. " from the Drive page in Raid summons and the Raid page's small \"" .. cue .. "\" pill is still drawn over it.", "texts: " .. table.concat(ctx:texts(), " | "))
						end
						pcall(u.ShowDrive, "console")
						ctx:advance(1)
					end
				end
			end
			if tried == 0 then ctx:na("the Raid page's pill was not up when a screen was opened") end
		end,
	}

	Hunt.promise{
		id = "rerun.raid_not_here_header_clear",
		area = "Raid summons",
		text = "On the Raid page the 'Not here (1)' header is never half under the page's own 'below' pill.",
		source = "judge4 F027 (Raid.lua updateCue fades the rows under the pill, not the header)",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid", fold = "narrow" },
		check = function(ctx)
			-- the pill only exists on the narrow page, when the header is below the view's edge: the number of raiders who
			-- asked and the window size decide; look at every count
			raidWithAway(ctx)
			local looked = 0
			local function look(why)
				ctx:advance(1)
				if not find(ctx, "[Bb]elow") then return end
				looked = looked + 1
				local bad = hits(ctx, "Raid%.lua")
				for _, h in ipairs(bad) do
					if (tostring(h.what or "") .. " " .. tostring(h.key)):find("Not here") then
						ctx:fail("On the Raid page the \"Not here\" header is half under the page's own \"below\" pill.", why .. ": " .. describe(bad))
					end
				end
			end
			look("no raider waiting")
			local away = (tostring(ctx.me.player.zone or "") == "Orgrimmar") and "Undercity" or "Orgrimmar"
			for i = 2, #MATES do
				if not ctx.w:player(MATES[i]) then break end
				ctx.w:move(MATES[i], away)
				ctx:advance(2)
				ctx.w:chatFrom(MATES[i], "123", "RAID")
				ctx:advance(2)
				look((i - 1) .. " raiders waiting")
			end
			for _, sc in ipairs({ 1.5, 2, 0.8 }) do
				bigger(ctx, sc)
				look("window scale " .. sc)
			end
			if looked == 0 then ctx:na("the pill was not up at any of the sizes tried") end
		end,
	}

	Hunt.promise{
		id = "rerun.key_row_press_fits",
		area = "Settings",
		text = "In Settings, after you click Set on the key row for the big button, the button reads 'Press...' whole, not cut.",
		source = "judge4 F032 (Rows.lua:632-639)",
		kind = "scenario",
		needs = { phone = "settings_driving", role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			for _ = 1, 8 do
				if find(ctx, "Key for the big button") then break end
				wheel(ctx, -5)
			end
			if not find(ctx, "Key for the big button") then ctx:na("the key row is not on this Settings page (Simple mode or another page)") end
			if not press(ctx, "^Set$") then ctx:cannot("no Set button") end
			if not find(ctx, "^Press") then ctx:na("the key capture did not start here") end
			local bad = hits(ctx, "Press", "cut")
			if #bad > 0 then ctx:fail("You click Set on the key row for the big button and the button reads cut off instead of \"Press...\".", describe(bad)) end
		end,
	}

	Hunt.promise{
		id = "rerun.why_link_clear_of_ping",
		area = "Ride screen",
		text = "On the Ride screen with nobody online, the 'Why?' link under the subtitle and the 'Ping drivers' button do not touch.",
		source = "judge4 F010 (Home.lua:667 Why? is anchored under the subtitle, Ping drivers at the foot)",
		kind = "scenario",
		needs = { phone = "home", net = "none", ride = "none" },
		check = function(ctx)
			ctx:advance(2)
			if not find(ctx, "^Why%?$") then ctx:na("no Why? link on the Ride screen here") end
			local bad = hits(ctx, "Home%.lua")
			local mine = {}
			for _, h in ipairs(bad) do
				if tostring(h.key):find("Home.lua:%d+") and (tostring(h.what or h.key) .. tostring(h.detail)):find("Why") then mine[#mine + 1] = h end
			end
			if #mine > 0 then ctx:fail("On the Ride screen with nobody online the Why? link touches the Ping drivers button.", describe(mine)) end
		end,
	}
end
