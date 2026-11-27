-- Promises about the flight map's price tags and pins (2.4.1: H24-04, E3b-07, G13, "a marker ring is not drawn over
-- Wuber's window"): they step aside from every shown Wuber frame, re-checked every 0.25 s and after a drag.
return function(Hunt)

	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		return v == want
	end
	local function applies(sit)
		return is(sit, "combat", "no") and sit.net ~= "none" and is(sit, "place", "town") and is(sit, "ride", "none") and sit.session ~= "first"
	end

	local function FPOf(ctx)
		local FP = ctx:mod("UI.FlightPins")
		if not (FP and type(FP.Pins) == "function") then ctx:cannot("this Wuber has no UI.FlightPins") end
		return FP
	end

	-- the player stands at the Thunder Bluff flight master; an open driver summons to Orgrimmar; the map is open
	local function openMapWithTag(ctx)
		local FP = FPOf(ctx)
		if ctx.W.db and ctx.W.db.flightOffers == false then ctx:na("flight map prices are off in Settings") end
		if ctx.me.player.combat then ctx:na("in combat") end
		local hasOrg = false
		for _, d in ipairs(ctx.W.UI.Drivers() or {}) do
			if type(d) == "table" and d.state == "open" and type(d.dest) == "string" and d.dest:find("Orgrimmar", 1, true) then hasOrg = true end
		end
		if not hasOrg then
			local dname = (ctx.name == "Mia Runner") and "Anita Lift" or "Mia Runner"
			local d = ctx.w:addClient(dname, { spot = "Orgrimmar", class = "WARLOCK" })
			if d.W.Char then d.W.Char().wizard = true end
			if not (d.W.Driver and d.W.Driver.SetOnline and d.W.Driver.SetOnline(true) ~= false) then ctx:cannot("the driver could not go online") end
			ctx:advance(15)
		end
		ctx.w:move(ctx.name, "Thunder Bluff")
		ctx:advance(1)
		local nodes
		if ctx.H and type(ctx.H.realTaxi) == "function" then
			nodes = ctx.H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
		else
			nodes = { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } }
		end
		ctx.w:openTaxiMap(ctx.me, nodes)
		ctx:note("open the flight map at Thunder Bluff")
		ctx:advance(1.2)
		local pins = FP.Pins()
		local n = 0
		for _, p in ipairs(pins) do if p.tag and ctx:visible(p.tag) then n = n + 1 end end
		if n == 0 then ctx:na("no price tag shows on the flight map to begin with") end
		return FP, n
	end

	local function rect(ctx, f)
		local r = ctx.H.rect(f)
		if not r then return nil end
		return { l = r.l, r = r.l + r.w, b = r.b, t = r.b + r.h }
	end
	local function crosses(a, b)
		return a.l + 0.5 < b.r and b.l + 0.5 < a.r and a.b + 0.5 < b.t and b.b + 0.5 < a.t
	end

	-- every Wuber frame the player can see now
	local NAMES = { "WuberDriveButton", "WuberDriveMini", "WuberDriveFrame", "WuberInFlight", "WuberNewsCard", "WuberCrewOffer", "WuberBell" }
	local function wuberRects(ctx)
		local out = {}
		local K = ctx:mod("UI.Kit")
		local s = K and K.ui or {}
		for _, f in ipairs({ s.win, s.phone, s.top }) do
			if type(f) == "table" and ctx:visible(f) then
				local r = rect(ctx, f)
				if r and r.r > r.l and r.t > r.b then out[#out + 1] = { name = "the Wuber window", r = r } end
			end
		end
		for _, n in ipairs(NAMES) do
			local f = ctx.me.env[n]
			if type(f) == "table" and ctx:visible(f) then
				local r = rect(ctx, f)
				if r and r.r > r.l and r.t > r.b then out[#out + 1] = { name = n, r = r } end
			end
		end
		return out
	end
	local function tagUnder(ctx, FP)
		local frames = wuberRects(ctx)
		for _, p in ipairs(FP.Pins()) do
			if p.tag and ctx:visible(p.tag) then
				local tr = rect(ctx, p.tag)
				if tr then
					for _, f in ipairs(frames) do
						if crosses(tr, f.r) then return p.node, f.name end
					end
				end
			end
		end
		return nil
	end
	local function shownTags(ctx, FP)
		local n = 0
		for _, p in ipairs(FP.Pins()) do if p.tag and ctx:visible(p.tag) then n = n + 1 end end
		return n
	end
	local function openWuber(ctx)
		if not ctx.W.UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.6)
		end
		if not ctx.W.UI.IsShown() then ctx:cannot("Wuber did not open on /wuber") end
	end
	-- drops the Wuber window with its left edge 2 px inside the first tag
	local function dropOverTag(ctx, FP)
		local K = ctx:mod("UI.Kit")
		local win = K and K.ui and K.ui.win
		if not win then ctx:cannot("no Wuber window") end
		local tag
		for _, p in ipairs(FP.Pins()) do if p.tag and ctx:visible(p.tag) then tag = p.tag break end end
		if not tag then ctx:na("no tag to drop over") end
		local tr = ctx.H.rect(tag)
		local before = ctx.H.rect(win)
		win:ClearAllPoints()
		win:SetPoint("LEFT", ctx.me.env.UIParent, "BOTTOMLEFT", before.l, before.b + before.h / 2)
		local k = ctx.H.rect(win).l / before.l
		win:ClearAllPoints()
		win:SetPoint("LEFT", ctx.me.env.UIParent, "BOTTOMLEFT", (tr.l + 2) / k, (tr.b + tr.h / 2) / k)
		return win
	end
	local function failUnder(ctx, node, what, when)
		ctx:fail(("%s: a price tag for %s sits under %s on the flight map."):format(when, tostring(node), what), "")
	end

	Hunt.promise{
		id = "v241.flightmap.tags_clear_of_window",
		area = "FlightMap",
		text = "You open the flight map, then open Wuber: no price tag sits under Wuber's window, and the tags come back when you close it.",
		source = "r49 D (every shown Wuber frame); H24-04",
		kind = "scenario",
		when = applies,
		check = function(ctx)
			local FP = openMapWithTag(ctx)
			openWuber(ctx)
			ctx:advance(0.6)
			local node, what = tagUnder(ctx, FP)
			if node then failUnder(ctx, node, what, "You open Wuber over the flight map") end
			ctx.W.UI.Toggle(false)
			ctx:note("close Wuber")
			ctx:advance(0.8)
			if ctx.W.UI.IsShown() then ctx:cannot("Wuber did not close") end
			-- a driver's own small cards (drive button, mini card) may still lie over flight points: then tags may stay hidden
			local left = wuberRects(ctx)
			for _, p in ipairs(FP.Pins()) do
				if not (p.tag and ctx:visible(p.tag)) then
					local m = rect(ctx, p.marker)
					local near = false
					if m then
						local cx, cy = (m.l + m.r) / 2, (m.b + m.t) / 2
						local box = { l = cx - 90, r = cx + 90, b = cy - 90, t = cy + 90 }
						for _, f in ipairs(left) do if crosses(box, f.r) then near = true end end
					end
					if not near then
						ctx:fail(("You close Wuber and the price tag for %s does not come back, though no Wuber card is near that flight point."):format(tostring(p.node)), "")
					end
				end
			end
		end,
	}

	local function dragCheck(grip)
		return function(ctx)
			local FP = openMapWithTag(ctx)
			openWuber(ctx)
			ctx:advance(0.6)
			local K = ctx:mod("UI.Kit")
			local ui = K and K.ui or {}
			local g = grip(ui)
			if not (g and g.GetScript and g:GetScript("OnDragStop")) then ctx:na("this Wuber window has no such drag handle") end
			if g:GetScript("OnDragStart") then g:GetScript("OnDragStart")(g) end
			dropOverTag(ctx, FP)
			g:GetScript("OnDragStop")(g)
			ctx:note("drag the window over a price tag")
			ctx:advance(0.1)
			local node, what = tagUnder(ctx, FP)
			if node then failUnder(ctx, node, what, "You drag Wuber over a price tag by its handle") end
		end
	end

	Hunt.promise{
		id = "v241.flightmap.drag_by_pill",
		area = "FlightMap",
		text = "You drag Wuber by its pill over a price tag on the flight map: the tag steps aside when you let go.",
		source = "H24-04 (r50 E)",
		kind = "scenario",
		when = applies,
		check = dragCheck(function(ui) return ui.phone and ui.phone.island end),
	}

	Hunt.promise{
		id = "v241.flightmap.drag_by_status_bar",
		area = "FlightMap",
		text = "You drag Wuber by its status bar over a price tag on the flight map: the tag steps aside when you let go.",
		source = "H24-04 (r50 E)",
		kind = "scenario",
		when = applies,
		check = dragCheck(function(ui) return ui.phone and ui.phone.status end),
	}

	Hunt.promise{
		id = "v241.flightmap.moved_window_within_a_moment",
		area = "FlightMap",
		text = "Wuber is open and something moves its window over a price tag on the open flight map: within half a second the tag is not under it.",
		source = "r49 D (re-checked every 0.25 s)",
		kind = "scenario",
		when = applies,
		check = function(ctx)
			local FP = openMapWithTag(ctx)
			openWuber(ctx)
			ctx:advance(0.6)
			dropOverTag(ctx, FP)
			ctx:note("the window lands over a price tag (no drag event)")
			ctx:advance(0.6)
			local node, what = tagUnder(ctx, FP)
			if node then failUnder(ctx, node, what, "Wuber's window moved over the flight map and half a second later") end
		end,
	}

	-- guard: the header drag was hooked before 2.4.1
	Hunt.promise{
		id = "v241.flightmap.guard_drag_by_header",
		area = "FlightMap",
		text = "You drag Wuber by its header over a price tag on the flight map: the tag steps aside (guard: this worked before 2.4.1).",
		source = "H24-04 guard",
		kind = "scenario",
		when = applies,
		check = dragCheck(function(ui) return ui.top end),
	}

	-- guard: with flight map prices off no tag shows at all, and switching them on shows them again
	Hunt.promise{
		id = "v241.flightmap.guard_prices_off_no_tags",
		area = "FlightMap",
		text = "With flight map prices off in Settings the flight map shows no Wuber price tag.",
		source = "UI.FlightPins header (flightOffers setting)",
		kind = "scenario",
		when = applies,
		check = function(ctx)
			local FP, n = openMapWithTag(ctx)
			ctx.W.db.flightOffers = false
			ctx.w:closeTaxiMap(ctx.me)
			ctx:advance(0.5)
			ctx.w:openTaxiMap(ctx.me, ctx.H.realTaxi and ctx.H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }) or { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
			ctx:advance(1.2)
			local k = shownTags(ctx, FP)
			ctx.W.db.flightOffers = nil
			if k > 0 then ctx:fail(("Flight map prices are off and the flight map still shows %d price tag(s)."):format(k), "") end
		end,
	}
end
