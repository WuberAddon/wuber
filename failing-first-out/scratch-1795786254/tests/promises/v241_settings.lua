-- 2.4.1 promises for Settings and the small fixes round 50 made (tests/r50/d_rows, f_earncue, m_driver): the Settings search
-- finds Flight offers by "skip" (H24-03), the shard slider's singular (AU24-26), the minimap line with no takings (AU24-20, G2),
-- Blocked rows that wrap the reason (AU24-34), the Earnings "Scroll for more" cue that never covers the reset link (H24-05).
-- Each acts like a player: types in the search box, drags the slider, hovers the minimap button, scrolls the page.
return function(Hunt)
	local U = dofile("tests/hunt/lib/universal_util.lua")
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")) end
	local function find(ctx, pat)
		for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p end end
		return nil
	end
	local function ui(ctx) local K = ctx:mod("UI.Kit") return K and K.ui or {} end
	local function settingsUp(ctx)
		local st = ctx.W.UI and ctx.W.UI.settings
		return st and st.controls and ui(ctx).settingsOpen == true and st or nil
	end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end
	local function closeBug(ctx)
		local B = ctx.W.UI and ctx.W.UI.Bug
		if type(B) == "table" and type(B.Shown) == "function" and B.Shown() and type(B.Close) == "function" then
			B.Close() ctx:note("close the bug report") ctx:advance(0.5)
		end
	end
	local function openSettings(ctx, section)
		closeBug(ctx)
		if not settingsUp(ctx) then
			ctx.me:slash("/wuber help")
			ctx:note("/wuber help")
			ctx:advance(2.4)
		end
		local st = settingsUp(ctx)
		if not st then ctx:cannot("/wuber help did not open Settings") end
		local offer
		pcall(function() offer = ui(ctx).rcOffer end)
		if offer and offer.IsShown and offer:IsShown() then ctx:na("the rain check offer card is up over Settings") end
		ctx.W.UI.OpenSettings(section)
		ctx:advance(1)
		ctx:note("open Settings" .. (section and (" " .. section) or ""))
		return settingsUp(ctx) or st
	end
	local function typeInto(ctx, st, word)
		local box = st.find and st.find.box and st.find.box.edit
		if not box then ctx:cannot("no search box in Settings") end
		ctx.me:type(box, word, false)
		ctx:advance(0.6)
		ctx:note("type \"" .. word .. "\" in the settings search")
	end
	local function matches(ctx, st)
		local out = {}
		for _, b in ipairs(st.find.items or {}) do
			if b.m and ctx:visible(b) then out[#out + 1] = b.m.label end
		end
		return out
	end
	-- a region's box with every edge (y goes up: t above b)
	local function R(o)
		local r = U.H.rect(o)
		if not r then return nil end
		return { l = r.l, r = r.l + r.w, b = r.b, t = r.b + r.h, w = r.w, h = r.h }
	end
	local function has(list, label)
		for _, l in ipairs(list) do if l == label then return true end end
		return false
	end

	-- the words a player may type for a row: each must list it
	local ROWS = {
		{ label = "Flight offers", words = { "skip", "bird", "flight master", "gryphon" } },
		{ label = "Auto-accept my driver's invite", words = { "invite", "party" } },
	}
	Hunt.promise{
		id = "v241.settings.search_skip_finds_flight_offers",
		area = "Settings",
		text = "Typing \"skip\" into the Settings search lists the Flight offers setting (it is the one that skips the bird), and the other words that found it and other rows before still do.",
		source = "H24-03 (Rows.lua KEYWORDS; tests/r50/d_rows_test.lua)",
		kind = "scenario",
		check = function(ctx)
			noCombat(ctx)
			local st = openSettings(ctx)
			for _, row in ipairs(ROWS) do
				for _, word in ipairs(row.words) do
					ctx.W.UI.OpenSettings() ctx:advance(0.6)
					typeInto(ctx, st, word)
					local got = matches(ctx, st)
					if #got == 0 and st.find.none and ctx:visible(st.find.none) and row.label ~= "Flight offers" then
						ctx:na("this player has no " .. row.label .. " row")
					end
					if not has(got, row.label) then
						ctx:fail(("You type \"%s\" in the Settings search and the %s setting is not listed (you see: %s)."):format(word, row.label, #got > 0 and table.concat(got, ", ") or "nothing"),
							"on screen: " .. table.concat(ctx:texts(), " | "))
					end
				end
			end
		end,
	}

	local SHARD_WORD = { [0] = "never", [1] = "1 shard", [2] = "2 shards", [3] = "3 shards", [10] = "10 shards" }
	Hunt.promise{
		id = "v241.settings.shard_slider_singular",
		area = "Settings",
		text = "The \"Warn me at this many shards\" slider reads \"1 shard\" at one, \"2 shards\" and more above, and \"never\" at zero.",
		source = "AU24-26 (Rows.lua lowShards format; tests/r50/d_rows_test.lua)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local st = openSettings(ctx, "driving")
			local sl = st.controls["drive.lowShards"]
			if not sl then ctx:na("no shard slider in Driving settings here") end
			for _, n in ipairs({ 1, 2, 0, 10, 1 }) do
				if not pcall(sl.SetValue, sl, n) then ctx:cannot("slider would not take a value") end
				ctx:advance(1)
				ctx:note("slide the shard warning to " .. n)
				local t = strip(sl.label:GetText())
				local want = SHARD_WORD[n]
				if t ~= want then
					ctx:fail(("You slide \"Warn me at this many shards\" to %d and it reads \"%s\" instead of \"%s\"."):format(n, t, want))
				end
			end
		end,
	}

	local function hoverMinimap(ctx)
		local b = ctx.me.env.WuberMinimapButton
		if not b then ctx:na("no minimap button") end
		if not (b.IsShown and b:IsShown()) then ctx:na("the minimap button is hidden") end
		local okh = pcall(U.H.runScript, b, "OnEnter")
		if not okh then ctx:cannot("hover on the minimap button failed") end
		ctx:advance(0.3)
	end
	Hunt.promise{
		id = "v241.settings.minimap_line_zero_gold",
		area = "Minimap",
		text = "A driver who is open and has earned nothing today sees \"0g today\" in the minimap button's tip, never a blank or an error; once a ride is paid the amount shows instead.",
		source = "AU24-20, G2 (Mini.lua UI.DriveSummary; tests/r50/m_driver_test.lua)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local D = ctx.W.Driver
			if not (D and D.Today) then ctx:na("no Today") end
			local _, copper = D.Today()
			if (copper or 0) ~= 0 then ctx:na("this driver has takings already") end
			hoverMinimap(ctx)
			local line = find(ctx, "^Driving:")
			if not line then ctx:na("the tip shows no Driving line (driver not open)") end
			if not line:find("0g today", 1, true) then
				ctx:fail("You hover the minimap button as an open driver with no takings and the Driving line reads \"" .. line .. "\" not \"... 0g today\".")
			end
			local old = D.Today
			D.Today = function() return 1, 15000 end
			pcall(U.H.runScript, ctx.me.env.WuberMinimapButton, "OnLeave")
			hoverMinimap(ctx)
			local line2 = find(ctx, "^Driving:")
			D.Today = old
			pcall(U.H.runScript, ctx.me.env.WuberMinimapButton, "OnLeave")
			ctx:advance(0.3)
			if not (line2 and line2:find("1g 50s today", 1, true)) then
				ctx:fail("You hover the minimap button after earning 1g 50s and the Driving line reads \"" .. tostring(line2) .. "\".")
			end
		end,
	}

	Hunt.promise{
		id = "v241.settings.blocked_reason_wraps",
		area = "Blocked",
		text = "A long reason on the Blocked list wraps inside its row (no cut-off words), and a one-line reason's row is not pushed apart or over the next.",
		source = "AU24-34 (Messages.lua screens.blocked; tests/r50/m_driver_test.lua)",
		kind = "scenario",
		needs = { role = "warlock", phone = "drive" },
		check = function(ctx)
			noCombat(ctx)
			local DR, D = ctx.W.Drive, ctx.W.Driver
			if not (DR and DR.Blacklist and D and D.ShowScreen) then ctx:cannot("no Blacklist / ShowScreen") end
			DR.SetOpt("autoBlock", true)
			local c = { name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1, caster = ctx.W.myKey }
			pcall(DR.NonPayer, c)
			DR.Blacklist("Eve Short", "rude")
			ctx:note("two riders blocked")
			ctx:advance(1)
			D.ShowScreen("blocked")
			ctx:advance(1)
			local s = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.blocked
			if not (s and s.rows and s.rows.list) then ctx:cannot("no Blocked screen") end
			local longRow, shortRow
			for _, r in ipairs(s.rows.list) do
				if r:IsShown() and r.why then
					if strip(r.why:GetText()):find("pay", 1, true) then longRow = r elseif strip(r.why:GetText()):find("rude", 1, true) then shortRow = r end
				end
			end
			if not longRow then ctx:na("the non-payer is not listed as blocked") end
			if U.H.truncation(longRow.why) ~= nil then
				ctx:fail("A rider blocked for not paying is on the Blocked list and the reason is cut off: \"" .. tostring(longRow.why:GetText()) .. "\".")
			end
			if shortRow then
				if shortRow:GetHeight() ~= 50 then
					ctx:fail("A rider blocked with a one-word reason has a row " .. shortRow:GetHeight() .. " tall instead of the usual 50.")
				end
				local a, b = R(longRow), R(shortRow)
				if a and b and a.l == b.l and not (a.b <= b.t + 0.5 or b.b <= a.t + 0.5) then
					ctx:fail("Two blocked riders' rows overlap on the Blocked list.")
				end
			end
		end,
	}

	-- the Earnings page: the "Scroll for more" pill must not sit on a word or button of the page, at any scroll position
	Hunt.promise{
		id = "v241.settings.earnings_cue_clear_of_reset",
		area = "Earnings",
		text = "On Earnings the small \"Scroll for more\" pill never covers any word or button (the Reset link at the bottom included), and it is gone once you are at the bottom.",
		source = "H24-05 (Earnings.lua cue strip; tests/r50/f_earncue_test.lua)",
		kind = "scenario",
		needs = { role = "warlock", phone = "drive" },
		check = function(ctx)
			noCombat(ctx)
			local u = ctx.W.UI
			if not (u and u.ShowDrive and u.ShowDrive("earnings")) then ctx:cannot("Earnings did not open") end
			ctx:advance(2)
			local s = u.drive and u.drive.screens and u.drive.screens.earnings
			if not (s and s.scroll and s.cue and s.content) then ctx:cannot("no Earnings scroll view") end
			local function items()
				local out, seen = {}, {}
				local function walk(f)
					if seen[f] then return end
					seen[f] = true
					for _, g in ipairs({ f:GetRegions() }) do
						if g.GetText and U.H.visible(g) then
							local t = g:GetText()
							if type(t) == "string" and t ~= "" then out[#out + 1] = { o = g, t = strip(t) } end
						end
					end
					if f:GetObjectType() == "Button" and U.H.visible(f) then out[#out + 1] = { o = f, t = "button " .. tostring(U.labelOf(f) or U.nameOf(f) or f:GetName() or "?") } end
					for _, ch in ipairs({ f:GetChildren() }) do walk(ch) end
				end
				walk(s.content)
				return out
			end
			local max = tonumber(s.scroll.max) or 0
			local steps = { 0, max / 2, max }
			for _, y in ipairs(steps) do
				pcall(s.scroll.ScrollTo, s.scroll, y, true)
				ctx:advance(0.8)
				ctx:note("scroll Earnings to " .. math.floor(y))
				if s.cue:IsShown() then
					local c = R(s.cue)
					local view = R(s.scroll)
					for _, it in ipairs(items()) do
						local r = R(it.o)
						local vb, vt = math.max(r and r.b or 0, view.b), math.min(r and r.t or 0, view.t) -- only the part of the item inside the view is drawn
						if c and r and r.w > 0 and vt - vb > 1 and r.l < c.r and r.r > c.l and vb < c.t - 1 and vt > c.b + 1 then
							ctx:fail("On Earnings the \"Scroll for more\" pill is drawn over \"" .. it.t .. "\".", ("scroll %d of %d; pill y %d-%d x %d-%d; item y %d-%d x %d-%d; view y %d-%d"):format(y, max, c.b, c.t, c.l, c.r, r.b, r.t, r.l, r.r, view.b, view.t))
						end
					end
					if y >= max - 0.5 and max > 0 then
						ctx:fail("You scroll Earnings all the way down and the \"Scroll for more\" pill is still showing.")
					end
				end
			end
		end,
	}
end
