-- Extra tour screens for the layout sweep (tools/layout-check.lua), added to the lab's L.PHOTO_SCREENS at run time so
-- the lab (a separate repo) need not change. Each is added only when the Wuber module it shows is present.
--   tipcard      the login tip card (UI.Tips) with the longest tip text, folded and unfolded phone
--   worldmap_sea the World view with both continents, pins with price tags and a sea route with the
--                "continues by zeppelin" arrow (UI.Rider.WorldMap + UI.Rider.SeaRoute)
--   confirm_avg900 / confirm_avg59  the tour's Confirm screen, the driver sending an average summon (D field 21,
--                FEAT-01) of 900 s and of 59 s: the dial's longest waits ("~15 min", "~59 sec")
--   home_usual   (FEAT-01 b) the rider's list with open drivers sending their average summon: "Usually about 59 sec" and
--                "Usually about 15 min" on the cards' small right-hand line
--   confirm_usual_long / confirm_usual_summoner  (FEAT-01 b) the booking card, the longest place, the usual summon and two
--                friends to bring, or a 12-letter Warlock who summons: the grey line
--                "Feathermoon Stronghold · Bring 2 friends · Open · usually about 59 sec" wraps, whole
--   confirm_dial the tour's Confirm screen with a flight time known: the dial shows and the route header is on the map
--                strip next to the destination pin (REV-r37-1)
--   confirm_dial_low  the same with the destination low on the strip (REV-r37-2): the pin, the route's ends and the you
--                dot stay above the lifted sheet and out of the route header (X.stripCheck fails the shot otherwise)
--   confirm_dial_zeppelin  (AUD-155) the dial for a free zeppelin trip: the unfolded verdict "The zeppelin is free,
--                about 25 min slower" wraps and the dial makes room for its second line (the shot fails otherwise)
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

local function mod(W, name)
	local ok, m = pcall(W.Mod, name)
	if ok and type(m) == "table" then return m end
end

-- the longest text of UI.TipTexts (strings, or tables with a text/body/msg field)
function X.longest(list)
	local best, bestId = "", nil
	for k, v in pairs(type(list) == "table" and list or {}) do
		local s = type(v) == "string" and v or (type(v) == "table" and (v.text or v.body or v.msg or v[1])) or nil
		if type(s) == "string" and #s > #best then best, bestId = s, (type(v) == "table" and v.id) or k end
	end
	return best, bestId
end

local function homeWith(W)
	W.db.coach = true
	local Coach = mod(W, "UI.Coach") -- the first-open marks may be up already; tips start once they are done
	if Coach and type(Coach.stopCoachForNow) == "function" then Coach.stopCoachForNow() end
	W.UI.Show("home")
	return true
end

-- realistic, DIFFERENT world sizes for the two continents (the harness gives both the same fake
-- 10000-yard square, so a scale rule could never fail). u runs along -y and v along -x, as the game's maps:
-- Kalimdor from the author's saved calibration (u = 0.4507 - 4.1085e-5 wy, v = 0.5123 - 4.1085e-5 wx); the Eastern
-- Kingdoms taller than wide (33333 yards along y, 21739 along x).
X.CAL = {
	[1414] = { cont = 1, u0 = 0.4507, du = 4.1085e-5, v0 = 0.5123, dv = 4.1085e-5 },
	[1415] = { cont = 0, u0 = 0.55, du = 3.0e-5, v0 = 0.5, dv = 4.6e-5 },
}
function X.stubWorld(c)
	local CM = c.env and c.env.C_Map
	if not (CM and CM.GetWorldPosFromMapPos) then return false end
	local orig = CM.GetWorldPosFromMapPos
	CM.GetWorldPosFromMapPos = function(id, pos)
		local k = X.CAL[id]
		if k and type(pos) == "table" and type(pos.x) == "number" then
			local cont, p = orig(id, pos)
			if not p then return nil end
			local wy, wx = (k.u0 - pos.x) / k.du, (k.v0 - pos.y) / k.dv
			local vec = type(p.GetXY) == "function" and p or nil
			if vec and p.SetXY then p:SetXY(wx, wy) return k.cont, p end
			p.x, p.y = wx, wy
			return k.cont, p
		end
		return orig(id, pos)
	end
	local okm, WM = pcall(c.W.Mod, "UI.Rider.WorldMap")
	if okm and type(WM) == "table" and type(WM.Reset) == "function" then WM.Reset() end
	return true
end

-- (round 37, REV-r37-2) what the booking card's map strip draws for the route, in the strip's own units (x right, y down
-- from its top): the sheet's top (s.cardTop), the route header's box, the destination pin's, the you dot's, the driver
-- pins' and the route's two ends (ends: { from = {x, y}, to = {x, y} } as fractions, from W.Map.RouteOnPanel's calls)
local function shown(f) return f and f.IsVisible and f:IsVisible() end
function X.stripBox(m, f)
	if not (shown(m) and shown(f)) then return nil end
	local me, fe = m:GetEffectiveScale(), f:GetEffectiveScale()
	local ml, mt, fl, ft = m:GetLeft(), m:GetTop(), f:GetLeft(), f:GetTop()
	if not (ml and mt and fl and ft) then return nil end
	local l, t = (fl * fe - ml * me) / me, (mt * me - ft * fe) / me
	local w, h = f:GetWidth() * fe / me, f:GetHeight() * fe / me
	return { l = l, r = l + w, t = t, b = t + h }
end
function X.stripBoxes(s, ends)
	local m = s.map
	local out = { cardTop = s.cardTop, header = X.stripBox(m, s.route), pin = X.stripBox(m, m.destPin), you = X.stripBox(m, m.me), drivers = {} }
	for _, p in ipairs(m.pins or {}) do local b = X.stripBox(m, p) if b then out.drivers[#out.drivers + 1] = b end end
	if ends and ends.from and ends.to then
		local w, h = m.mapW or m:GetWidth(), m.mapH or m:GetHeight()
		out.from = { x = ends.from[1] * w, y = ends.from[2] * h }
		out.to = { x = ends.to[1] * w, y = ends.to[2] * h }
	end
	return out
end
local function fmtBox(b) return b and string.format("x %d..%d y %d..%d", math.floor(b.l + 0.5), math.floor(b.r + 0.5), math.floor(b.t + 0.5), math.floor(b.b + 0.5)) or "none" end
function X.stripText(o)
	local t = { "sheet top " .. tostring(o.cardTop), "header " .. fmtBox(o.header), "pin " .. fmtBox(o.pin), "you " .. fmtBox(o.you) }
	for i, d in ipairs(o.drivers) do t[#t + 1] = "driver pin " .. i .. " " .. fmtBox(d) end
	if o.from then t[#t + 1] = string.format("route (%d,%d) to (%d,%d)", math.floor(o.from.x + 0.5), math.floor(o.from.y + 0.5), math.floor(o.to.x + 0.5), math.floor(o.to.y + 0.5)) end
	return table.concat(t, "; ")
end
-- the problems: anything of the route under the sheet (y below its top) or in the header's box (1 px of rounding)
function X.stripProblems(o)
	local bad, top, hd = {}, o.cardTop or 168, o.header
	local function inHeader(b) return hd and b.l < hd.r - 1 and b.r > hd.l + 1 and b.t < hd.b - 1 and b.b > hd.t + 1 end
	local function point(name, p)
		if not p then return end
		if p.y > top + 1 then bad[#bad + 1] = name .. " at y " .. math.floor(p.y + 0.5) .. " is under the sheet (top " .. top .. ")" end
		if hd and p.x > hd.l + 1 and p.x < hd.r - 1 and p.y > hd.t + 1 and p.y < hd.b - 1 then bad[#bad + 1] = name .. " is in the route header" end
	end
	local function box(name, b)
		if not b then return end
		if b.b > top + 1 then bad[#bad + 1] = name .. " (" .. fmtBox(b) .. ") goes under the sheet (top " .. top .. ")" end
		if inHeader(b) then bad[#bad + 1] = name .. " (" .. fmtBox(b) .. ") is in the route header (" .. fmtBox(hd) .. ")" end
	end
	box("the destination pin", o.pin)
	box("the you dot", o.you)
	for i, d in ipairs(o.drivers) do if inHeader(d) then bad[#bad + 1] = "driver pin " .. i .. " is in the route header" end end
	point("the route's start", o.from)
	point("the route's end", o.to)
	return bad
end

-- the strip drawn again with the route's ends recorded (W.Map.RouteOnPanel is put back at once): true, or the problems.
-- Folded only: unfolded the map is docked beside the sheet (nothing covers it)
function X.stripCheck(w, s, what)
	if not (s and s.map) then return what .. ": no booking card" end
	if s.wide then return true end
	local Map, ends = w.Map, nil
	local route = type(Map) == "table" and Map.RouteOnPanel
	if type(route) == "function" and s.map:IsVisible() then
		local HM = mod(w, "UI.Rider.HomeMap")
		Map.RouteOnPanel = function(m, a, b, o) if m == s.map and a then ends = { from = a, to = b } end return route(m, a, b, o) end
		local ok = HM and pcall(HM.updateMap, s.map, w.UI.Drivers())
		Map.RouteOnPanel = route
		if not ok then return what .. ": the map strip could not be drawn" end
	end
	local o = X.stripBoxes(s, ends)
	if os and os.getenv and os.getenv("WUBER_STRIP_PROBE") then print("STRIP " .. what .. ": " .. X.stripText(o)) end
	local bad = X.stripProblems(o)
	if #bad > 0 then return what .. ": " .. table.concat(bad, "; ") .. " [" .. X.stripText(o) .. "]" end
	return true
end

function X.install(L, W)
	local added = {}
	local Tips, Sea = mod(W, "UI.Tips"), mod(W, "UI.Rider.SeaRoute")
	local WM = mod(W, "UI.Rider.WorldMap")
	if Tips and type(Tips.ShowNow) == "function" then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "tipcard", side = "rider", unfold = true,
			title = "Login tip card: the longest tip, in the phone",
			run = function(w)
				homeWith(w)
				local TT = mod(w, "UI.TipTexts")
				local id
				if type(Tips.Longest) == "function" then local t = Tips.Longest() id = t and t.id end
				if not id then local _, i2 = X.longest(TT and TT.list) id = i2 end
				w.db.tipsOn = true
				w.db.tipsSeen = {}
				local shown, why = Tips.ShowNow(id)
				if not shown then return "the tip card did not show: " .. tostring(why) end
				return true
			end }
		added[#added + 1] = "tipcard"
	end
	if WM and type(WM.Show) == "function" and Sea then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "worldmap_sea", side = "rider", only = "unfolded",
			title = "World view: both continents, price-tag pins, a sea route with the zeppelin arrow",
			run = function(w) return homeWith(w) end,
			post = function(w)
				-- a Horde crossing (Orgrimmar to Undercity: flight, then the zeppelin) so the cut-edge arrow is drawn
				if not WM.Show("world", { route = { from = "Orgrimmar", to = "Undercity" } }) then return "the World view isn't built" end
				-- the shot must really show the arrow, or the sweep says so (a silent miss would cover nothing)
				local last = WM.cache and WM.cache.last
				if not (last and last.seaArrow) then return "the sea route drew no zeppelin arrow" end
				return true
			end }
		added[#added + 1] = "worldmap_sea"
	end
	-- (round 37, FEAT-01) the Confirm screen's dial with a driver's own average as the wait: the tour's confirm
	-- shot, then Bob's beacon (to Ratchet) carries 900 s (and 59 s) and he is ready (queue 0), so the dial shows it
	local base
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "confirm" then base = s end end
	local K = L.PhotoKit
	-- a stub for this shot only, as the tour's own shotStub: L.PhotoReset puts it back before the next screen
	local function shotStub(tbl, key, value)
		local t = K and type(K.tour) == "function" and K.tour()
		if not (t and type(K.stub) == "function") then return false end
		t.shotStubs = t.shotStubs or {}
		t.shotStubs[#t.shotStubs + 1] = { tbl, key, tbl[key] }
		return K.stub(tbl, key, value)
	end
	local Booking = mod(W, "UI.Rider.Booking")
	if base and type(base.run) == "function" and Booking then
		for _, secs in ipairs({ 900, 59 }) do
			local id = "confirm_avg" .. secs
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = id, side = "rider", unfold = true,
				title = "Confirm: the Fly or summon dial with the driver's average summon of " .. secs .. " s",
				run = function(w)
					local r = base.run(w)
					if r ~= true then return r end
					local d = type(w.drivers) == "table" and w.drivers["bob stone"]
					if not d then return "the tour has no Bob Stone" end
					shotStub(d, "avgSummon", secs) -- this shot only: Bob is as before for the screens after it
					shotStub(d, "queue", 0)
					shotStub(d, "state", "open")
					-- the tour's spot has no flight time there (the dial stays hidden): 25 min, as a long flight
					if shotStub(w, "TravelSaved", function() return 1500, "same continent", true end) == false then
						return "no shot stub (L.PhotoKit)"
					end
					w.UI.Show("confirm", "bob stone")
					if w.UI.RefreshNow then w.UI.RefreshNow() end
					local info = Booking.DialInfo(w.UI.Driver("bob stone"), d.price)
					if not (info and info.wait == secs) then return "the dial's wait is " .. tostring(info and info.wait) .. ", not " .. secs .. "" end
					return true
				end }
			added[#added + 1] = id
		end
	end
	-- (round 46, FEAT-01 a) the Drive console's "Today's takings" card with its "Your summons: about N" line: the tour's
	-- console_open shot with three counted summons seeded (W.db.drive.summons); 900 s is the longest text, "about 15 min"
	local consoleBase
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "console_open" then consoleBase = s end end
	if consoleBase and type(consoleBase.run) == "function" then
		for _, secs in ipairs({ 45, 900 }) do
			local id = "console_summons" .. secs
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = id, side = "driver", unfold = true,
				title = "Driver console: the takings card with the average summon line (" .. secs .. " s)",
				run = function(w)
					w.db.drive = w.db.drive or {}
					local keep = w.db.drive.summons
					w.db.drive.summons = { { total = secs, cast = 20 }, { total = secs, cast = 20 }, { total = secs, cast = 20 } }
					local r = consoleBase.run(w)
					if r ~= true then w.db.drive.summons = keep return r end
					if w.Driver and w.Driver.RefreshNow then w.Driver.RefreshNow() end
					return true
				end }
			added[#added + 1] = id
		end
	end
	-- (round 46, FEAT-01 b) the usual summon said: on the rider's list (the tour's home shot, the open drivers sending
	-- 59 s and 900 s, nobody waiting) and at the end of the booking card's grey line with a long place (Bob, two friends)
	local homeBase
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "home" then homeBase = s end end
	if homeBase and type(homeBase.run) == "function" and mod(W, "UI.Rider.Cards") then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "home_usual", side = "rider", unfold = true,
			title = "Rider home: open drivers' cards say Usually about 59 sec and Usually about 15 min",
			run = function(w)
				local r = homeBase.run(w)
				if r ~= true then return r end
				local set = { ["mia runner"] = 59, ["bob stone"] = 900, ["anita lift"] = 59 }
				for key, secs in pairs(set) do
					local d = type(w.drivers) == "table" and w.drivers[key]
					if d then
						shotStub(d, "avgSummon", secs)
						shotStub(d, "queue", 0)
						shotStub(d, "state", "open")
					end
				end
				w.UI.Show("home")
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				return true
			end }
		added[#added + 1] = "home_usual"
	end
	-- the longest place (Feathermoon Stronghold), with two friends to bring, or with a 12-letter Warlock who summons
	if base and type(base.run) == "function" and mod(W, "UI.Rider.Confirm") then
		for _, v in ipairs({ { "confirm_usual_long", 1, nil }, { "confirm_usual_summoner", 2, "Bartholomewx" } }) do
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = v[1], side = "rider", unfold = true,
				title = "Confirm: the longest place and usually about 59 sec at the end of the grey line" .. (v[3] and ", a Warlock who summons" or ""),
				run = function(w)
					local r = base.run(w)
					if r ~= true then return r end
					local d = type(w.drivers) == "table" and w.drivers["bob stone"]
					if not d then return "the tour has no Bob Stone" end
					shotStub(d, "avgSummon", 59)
					shotStub(d, "queue", 0)
					shotStub(d, "state", "open")
					shotStub(d, "team", v[2])
					shotStub(d, "summoner", v[3])
					shotStub(d, "dest", "Feathermoon Stronghold")
					w.UI.Show("confirm", "bob stone")
					if w.UI.RefreshNow then w.UI.RefreshNow() end
					return true
				end }
			added[#added + 1] = v[1]
		end
	end
	-- (round 37, REV-r37-1) the tour's own Confirm shot (Mia Runner, to Undercity) with a flight time there known, the
	-- usual case in the game: the dial shows, the sheet moves up and the route header sits on the map strip by the pin
	local ConfirmMod = mod(W, "UI.Rider.Confirm")
	if base and type(base.run) == "function" and ConfirmMod then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "confirm_dial", side = "rider", unfold = true,
			title = "Confirm: the booking card with the Fly or summon dial showing",
			run = function(w)
				local r = base.run(w)
				if r ~= true then return r end
				if shotStub(w, "TravelSaved", function() return 1500, "same continent", true end) == false then
					return "no shot stub (L.PhotoKit)"
				end
				w.UI.Show("confirm", "mia runner")
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				local s = type(ConfirmMod.side) == "table" and ConfirmMod.side.conf
				if not (s and s.dial and s.dial:IsShown()) then return "the Fly or summon dial is not showing" end
				return true
			end,
			-- (REV-r37-2) once the page has settled, folded: the strip's route above the sheet and out of the header
			post = function(w) return X.stripCheck(w, ConfirmMod.side.conf, "confirm_dial") end }
		added[#added + 1] = "confirm_dial"
		-- (round 37, REV-r37-2) the same with the destination low on the strip (x 0.5, y 0.99 of the rider's map): the
		-- sheet is lifted for the dial, and the pin, the route and the you dot keep above it and out of the route header
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "confirm_dial_low", side = "rider", unfold = true,
			title = "Confirm: the dial showing and the destination low on the map strip",
			run = function(w)
				local r = base.run(w)
				if r ~= true then return r end
				if shotStub(w, "TravelSaved", function() return 1500, "same continent", true end) == false then
					return "no shot stub (L.PhotoKit)"
				end
				w.UI.Show("confirm", "mia runner")
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				local s = type(ConfirmMod.side) == "table" and ConfirmMod.side.conf
				local mapID = s and s.map and s.map.artFor
				if not mapID then return "the map strip has no map" end
				shotStub(w, "ExactPlace", function(name)
					if name == "Undercity" then return { name = "Undercity", mapID = mapID, x = 0.5, y = 0.99 } end
				end)
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				if not (s.dial and s.dial:IsShown()) then return "the Fly or summon dial is not showing" end
				return true
			end,
			post = function(w) return X.stripCheck(w, ConfirmMod.side.conf, "confirm_dial_low") end }
		added[#added + 1] = "confirm_dial_low"
	end
	-- (round 32, k4) the Waiting-for-the-driver screen with a rider in another group: the "You're in a group. Leave it
	-- so <driver> can invite you." line and its Leave button, which showed for nobody before. Added last: it
	-- stubs W.InGroup and W.ride for the rest of the tour.
	if mod(W, "UI.Rider.Confirm") then
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "finding_grouped", side = "rider", unfold = true,
		title = "Waiting for the driver, the rider in another group: the Leave your group line and button",
		run = function(w)
			homeWith(w)
			w.ride = { id = "k4finding", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000,
				state = "requesting", at = (type(GetTime) == "function" and GetTime() or 0), service = "Mia's Rides" }
			w.InGroup = function() return true end
			w.InGroupWith = function() return false end
			w.UI.Show("finding")
			if w.UI.RefreshNow then w.UI.RefreshNow() end
			return true
		end }
	added[#added + 1] = "finding_grouped"
	end
	-- (round 46, HUNT-76) the empty Blocked screen with "Block riders who leave without paying" off: its longest note
	if mod(W, "UI.Driver.Messages") then
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "blocked_off", side = "driver", unfold = true,
		title = "Blocked, nobody blocked, the self-block switch off: the longer empty note",
		run = function(w)
			local base -- the Messages scene sets the console up (driver, closed); then this screen goes over it
			for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "messages" then base = s end end
			if not base then return "no Messages scene to start from" end
			local r = base.run(w)
			if r ~= true then return r end
			if w.Drive and w.Drive.SetOpt then w.Drive.SetOpt("autoBlock", false) end
			w.Driver.ShowScreen("blocked")
			if w.Driver.RefreshNow then w.Driver.RefreshNow() end
			return true
		end }
	added[#added + 1] = "blocked_off"
	-- (r50 M, AU24-34) a filled Blocked list: a rider the addon blocked for leaving owing, whose reason wraps to a second line
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "blocked_full", side = "driver", unfold = true,
		title = "Blocked, one rider auto-blocked for not paying: the long reason wraps, the row grows",
		run = function(w)
			local base
			for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "messages" then base = s end end
			if not base then return "no Messages scene to start from" end
			local r = base.run(w)
			if r ~= true then return r end
			w.Drive.SetOpt("autoBlock", true)
			w.Drive.NonPayer({ name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1, caster = w.myKey })
			w.Driver.ShowScreen("blocked")
			if w.Driver.RefreshNow then w.Driver.RefreshNow() end
			return true
		end }
	added[#added + 1] = "blocked_full"
	end
	-- (round 46 R, HUNT-108) Settings > Check my game with the longest heading: every game check passed and twelve
	-- driver lines need a look ("All 14 game checks passed. 12 driver lines need a look: see your Drive tab.")
	local settingsBase
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "settings" then settingsBase = s end end
	if settingsBase and type(settingsBase.run) == "function" then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "settings_check_long", side = "settings", unfold = true,
			title = "Settings: Check my game, the longest heading (twelve driver lines need a look)",
			run = function(w)
				local r = settingsBase.run(w)
				if r ~= true then return r end
				local DR = w.Drive
				if type(DR) ~= "table" then return "no Drive" end
				-- the twelve stand-in lines only for the click: left in place they also fill the Drive console's own
				-- checklist, which no real driver has that long
				local keep = DR.Readiness
				DR.Readiness = function()
					local t = {}
					for i = 1, 12 do t[i] = { text = "Driver line number " .. i .. " needs a look", ok = false } end
					return t
				end
				local st = w.UI.settings
				if not (st and st.controls and st.controls.check) then DR.Readiness = keep return "no Check my game button" end
				st.controls.check:GetScript("OnClick")(st.controls.check, "LeftButton", false)
				DR.Readiness = keep
				if w.Driver and w.Driver.RefreshNow then w.Driver.RefreshNow() end
				local head = st.results and st.results.head and st.results.head:GetText() or ""
				if not head:find("12 driver lines need a look", 1, true) then return "heading is: " .. head end
				return true
			end }
		added[#added + 1] = "settings_check_long"
	end
	-- (round 47 H, AUD-155) the Confirm screen's dial for a free zeppelin trip: "The zeppelin is free, about 25 min
	-- slower" takes two lines at the unfolded verdict's 15 px, and the dial makes room for the second
	if base and type(base.run) == "function" and ConfirmMod then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "confirm_dial_zeppelin", side = "rider", unfold = true,
			title = "Confirm: the Fly or summon dial, a free zeppelin trip with a two-line verdict",
			run = function(w)
				local r = base.run(w)
				if r ~= true then return r end
				-- worked out from the flight paths (about), free, and time worth little: the zeppelin wins
				if shotStub(w, "TravelSaved", function() return 1500, "by zeppelin", false end) == false then
					return "no shot stub (L.PhotoKit)"
				end
				shotStub(w.UI, "FlightCostTo", function() return 0 end)
				shotStub(w.db, "timeValue", 1)
				w.UI.Show("confirm", "mia runner")
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				local s = type(ConfirmMod.side) == "table" and ConfirmMod.side.conf
				local dial = s and s.dial
				if not (dial and dial:IsShown()) then return "the Fly or summon dial is not showing" end
				return true
			end,
			-- once the page has settled (unfolded: the dial 96 high, the verdict at 15 px, two lines where the card is
			-- narrow enough): the room under the verdict is the lines it is drawn on
			post = function()
				local s = type(ConfirmMod.side) == "table" and ConfirmMod.side.conf
				local dial = s and s.dial
				if not (dial and dial:IsShown()) then return "the Fly or summon dial is not showing" end
				local fs = dial.verdict
				local said = fs.wuberText or ""
				if not said:find("costs nothing, about", 1, true) then return "the verdict is: " .. said end
				if ((dial.extra or 0) > 0) ~= (fs.wuberWrapped == true) then
					return "the verdict at " .. tostring(fs.wuberPx) .. " px has room for the wrong number of lines (extra "
						.. tostring(dial.extra) .. "): " .. said
				end
				return true
			end }
		added[#added + 1] = "confirm_dial_zeppelin"
	end
	-- (round 47 M, AUD-163) the Drive console with the "Join the Wuber community" card showing: a driver who holds a
	-- founder invitation (the community calls are stubbed for this shot only)
	do
		local openBase
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "console_open" then openBase = s end end
		if openBase and type(openBase.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "console_join", side = "driver", unfold = true,
				title = "Driver console: the Join the Wuber community card (a club invitation held)",
				run = function(w)
					local r = openBase.run(w)
					if r ~= true then return r end
					if shotStub(w, "CommunityAvailable", function() return true end) == false then return "no shot stub" end
					shotStub(w, "CommunityMember", function() return false end)
					shotStub(w, "CommunityInvite", function() return 12345 end)
					if w.Driver and w.Driver.RefreshNow then w.Driver.RefreshNow() end
					-- the card is the foot of the scroll: show the bottom, or the sweep would not see it
					local ui = w.Driver and w.Driver.ui
					local sc = ui and ui.console and ui.console.scroll
					if not (sc and sc.ScrollTo) then return "no console scroll" end
					sc:ScrollTo(sc.max or 9999, true)
					return true
				end }
			added[#added + 1] = "console_join"
		end
	end
	-- (round 47, AUD-157/158) the Price and place card with three long place matches ("ea"): pills at their normal size, none past the card's edge
	do
		local base
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "console_open" then base = s end end
		if base and type(base.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "sheet_places", side = "driver", unfold = true,
				title = "Price and place card: three long place matches typed (ea)",
				run = function(w)
					local r = base.run(w)
					if r ~= true then return r end
					if not (w.Driver and w.Driver.ShowSheet) then return "no ShowSheet" end
					w.Driver.ShowSheet("sheet")
					local s = w.UI.drive and w.UI.drive.screens and w.UI.drive.screens.sheet
					if not (s and s.layout and s.results) then return "no price and place card" end
					s.mode = "choose" s.layout()
					s.results("ea")
					return true
				end }
			added[#added + 1] = "sheet_places"
		end
	end
	-- (round 47, AUD-147) the setup's Step 2 (and the Crew screen) with one row in "No answer: <name> may not have Wuber"
	-- for the longest allowed name (12 letters) and the Add anyway button showing: the line must be whole, inside its
	-- row and clear of the button, at every size
	do
		local wizBase
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "wizard_summoner" then wizBase = s end end
		local function noAnswer(w)
			local DR = w.Drive
			if type(DR) ~= "table" then return "no Drive" end
			local key = "wolfgangbert"
			shotStub(DR, "Crew", function() return {} end)
			shotStub(DR, "Roster", function() return { { name = "Wolfgangbert", key = key, class = "WARLOCK" } } end)
			shotStub(DR, "offers", { [key] = { name = "Wolfgangbert", at = 0, state = "noapp" } })
			return true
		end
		local function rowCheck(w, rows, want)
			for _, r in ipairs(rows or {}) do
				if type(r) == "table" and r.sub and r.IsShown and r:IsShown() and r.person then
					local txt = r.sub:GetText() or ""
					if txt ~= "No answer: Wolfgangbert may not have Wuber" then return "the row says: " .. txt end
					if not (r.btn and r.btn:IsShown()) then return "no Add anyway button on the row" end
					-- whole, inside the row and clear of the button (the frame edges, in screen units)
					local sb, rb, sr, bl = r.sub:GetBottom(), r:GetBottom(), r.sub:GetRight(), r.btn:GetLeft()
					if sb and rb and sb < rb then return "the line runs below its row (" .. sb .. " < " .. rb .. ")" end
					if sr and bl and sr > bl then return "the line reaches the button (" .. sr .. " > " .. bl .. ")" end
					if r.sub.IsTruncated and r.sub:IsTruncated() then return "the line is cut" end
					return true
				end
			end
			return "no " .. want .. " row is showing"
		end
		if wizBase and type(wizBase.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "wizard_noanswer_long", side = "driver", video = true,
				title = "Setup step 2: a 12-letter name with \"No answer\" and the Add anyway button",
				run = function(w)
					local r = wizBase.run(w)
					if r ~= true then return r end
					return noAnswer(w)
				end,
				post = function(w)
					if not w.UI.ShowDrive("wizard") then return "no setup screen" end
					local ui = type(w.Driver) == "table" and w.Driver.ui
					local s = type(ui) == "table" and type(ui.subs) == "table" and ui.subs.wizard
					if not (type(s) == "table" and type(s.paint) == "function") then return "no setup screen" end
					s.choice, s.step = "friends", 2
					s.paint()
					return rowCheck(w, s.people and s.people.list, "setup")
				end }
			added[#added + 1] = "wizard_noanswer_long"
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "crew_noanswer_long", side = "driver", video = true,
				title = "Your crew: a 12-letter name with \"No answer\" and the Add anyway button",
				run = function(w)
					local r = wizBase.run(w)
					if r ~= true then return r end
					return noAnswer(w)
				end,
				post = function(w)
					if not w.UI.ShowDrive("crew") then return "no crew screen" end
					local ui = type(w.Driver) == "table" and w.Driver.ui
					local s = type(ui) == "table" and type(ui.subs) == "table" and ui.subs.crew
					if type(s) ~= "table" then return "no crew screen" end
					if type(s.paint) == "function" then s.paint() end
					local rows = {}
					for _, key in ipairs({ "others", "members" }) do
						if type(s[key]) == "table" and type(s[key].list) == "table" then
							for _, r in ipairs(s[key].list) do rows[#rows + 1] = r end
						end
					end
					return rowCheck(w, rows, "crew")
				end }
			added[#added + 1] = "crew_noanswer_long"
		end
	end
	-- (round 47, AUD-168) busy driver cards with the longest sub line ("To Feathermoon Stronghold · Summoned by
	-- Bartholomewx") beside the amber state text: busy with a long queue, busy and the group full
	if homeBase and type(homeBase.run) == "function" and mod(W, "UI.Rider.Cards") then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "home_busy_long", side = "rider", unfold = true,
			title = "Rider home: busy cards with the longest place and Warlock name beside Busy, N waiting",
			run = function(w)
				local r = homeBase.run(w)
				if r ~= true then return r end
				local mix = { ["mia runner"] = { "busy", 12, 3 }, ["bob stone"] = { "busy", 99, 0 } }
				local n = 0
				for key, v in pairs(mix) do
					local d = type(w.drivers) == "table" and w.drivers[key]
					if d then
						n = n + 1
						shotStub(d, "state", v[1])
						shotStub(d, "queue", v[2])
						shotStub(d, "seats", v[3])
						shotStub(d, "dest", "Feathermoon Stronghold")
						shotStub(d, "summoner", "Bartholomewx")
					end
				end
				if n == 0 then return "the tour has no drivers to make busy" end
				w.UI.Show("home")
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				-- the list scrolls and the tour's window puts a card across its bottom edge: scroll to the end. The tour
				-- then changes the window's size (folded, unfolded, the scale), which changes the list's room, so the
				-- scroll is taken again from the list's own numbers at every step until the tour has shot it
				local kit = mod(w, "UI.Kit")
				local kui = kit and kit.ui
				local function toEnd()
					if type(kui) ~= "table" or type(kui.cards) ~= "table" then return end
					-- (round 47 lead) only while this scene's own stub is up: once the tour has put Bob back, the
					-- timers below do nothing, so no later scene is scrolled by them
					local bob = type(w.drivers) == "table" and w.drivers["bob stone"]
					if not (type(bob) == "table" and bob.queue == 99) then return end
					local any = next(kui.cards)
					-- (design 2) a driver is a row of one card: the row's parent is that card, the card's is the content
					local row = any and kui.cards[any]
					local content = row and (row.group and row.group:GetParent() or row:GetParent())
					local clip = content and content:GetParent()
					if not (clip and clip.GetHeight and content.GetHeight) then return end
					local gap = row.group and 0 or (kit.CARD_GAP or 8)
					local mx = math.max(0, content:GetHeight() - gap - clip:GetHeight())
					kui.scrollMax, kui.scroll, kui.scrollTarget = mx, mx, mx
					content:ClearAllPoints()
					content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, mx)
				end
				toEnd()
				if type(w.After) == "function" then
					for i = 1, 40 do w.After(i * 0.25, toEnd) end
				end
				return true
			end }
		added[#added + 1] = "home_busy_long"
	end
	-- (round 47, REV-r47-1) Home searched for the longest place: "Drivers to Feathermoon Stronghold" beside "N open · M online"
	do
		local hb
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "home" then hb = s end end
		if hb and type(hb.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "home_search_long", side = "rider", unfold = true,
				title = "Rider home: a search for the longest place, the heading beside its count and the bell",
				run = function(w)
					local r = hb.run(w)
					if r ~= true then return r end
					local n = 0
					local d = type(w.drivers) == "table" and w.drivers["bob stone"]
					if d then n = 1 shotStub(d, "dest", "Feathermoon Stronghold") end
					if n == 0 then return "the tour has no drivers" end
					w.UI.Show("home")
					if w.UI.SetSearch then w.UI.SetSearch("Feathermoon Stronghold") end
					if w.UI.RefreshNow then w.UI.RefreshNow() end
					return true
				end }
			added[#added + 1] = "home_search_long"
		end
	end
	-- (the lead, 2.4) a scene "flightpins" (five price tags on the flight map) worked alone but not inside a whole sweep and was
	-- taken out; the flight map's tag is in the sweep's own bird shot. Its text is kept in the review folder for a later try.
	-- Wuber 2.4, part 6: mid-flight offer card with 6 min left to the longest flight point and 123g 45s 67c
	do
		local IF = mod(W, "UI.InFlight")
		if IF and type(IF.Check) == "function" and type(IF.Hide) == "function" then
			local saved = {}
			local function stub(tbl, key, val)
				if saved[tbl] == nil then saved[tbl] = {} end
				if saved[tbl][key] == nil then saved[tbl][key] = { had = tbl[key] ~= nil, val = tbl[key] } end
				return shotStub(tbl, key, val)
			end
			local function restoreAll()
				for tbl, keys in pairs(saved) do
					for key, rec in pairs(keys) do
						tbl[key] = rec.had and rec.val or nil
					end
				end
				saved = {}
			end
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "inflight", side = "rider", unfold = true,
				title = "Mid-flight offer: card with longest place name and longest price text",
				run = function(w)
					saved = {}
					homeWith(w)
					local env = (type(getfenv) == "function" and getfenv(IF.Check)) or _G
					local numNodes = env and type(env.NumTaxiNodes) == "function" and env.NumTaxiNodes() or 0
					if numNodes <= 0 then return "no flight points on the map" end
					local bestPlace
					for i = 1, numNodes do
						local raw = type(env.TaxiNodeName) == "function" and env.TaxiNodeName(i) or nil
						if type(raw) == "string" and raw ~= "" then
							local place = (type(w.FLY) == "table" and type(w.FLY.NodePlace) == "function" and w.FLY.NodePlace(raw))
								or raw:match("^([^,]+)") or raw
							place = place:match("^%s*(.-)%s*$")
							if place ~= "" and (not bestPlace or #place > #bestPlace) then
								bestPlace = place
							end
						end
					end
					if not bestPlace then return "no flight point names on the map" end
					local origOnTaxi = w.OnTaxi
					w.OnTaxi = function() return false end
					IF.Hide()
					IF.Check()
					w.OnTaxi = origOnTaxi
					if stub(w, "OnTaxi", function() return true end) == false then
						restoreAll()
						return "no shot stub (L.PhotoKit)"
					end
					stub(w, "FlightLeft", function() return 372, bestPlace end)
					local now = (env and type(env.GetTime) == "function" and env.GetTime()) or 0
					stub(w.UI, "Drivers", function()
						return {
							{
								name = "Wolfgangbert",
								short = "Wolfgangbert",
								key = "inflight demo",
								dest = bestPlace,
								price = 1234567,
								state = "open",
								queue = 0,
								team = 3,
								service = "Wolfgangbert's Rides",
								heard = now,
							},
						}
					end)
					if w.ride ~= nil then stub(w, "ride", nil) end
					if type(w.db) == "table" then
						if w.db.flightOffers == false then stub(w.db, "flightOffers", true) end
						if w.db.midFlight == false then stub(w.db, "midFlight", true) end
					end
					local shown = IF.Check()
					if not shown then
						local why = type(IF.Why) == "function" and IF.Why() or "unknown"
						restoreAll()
						local curOnTaxi = w.OnTaxi
						w.OnTaxi = function() return false end
						IF.Hide()
						IF.Check()
						w.OnTaxi = curOnTaxi
						-- (lead) with no room beside Wuber's window the card rightly waits: the shot is the phone alone
						if tostring(why):find("no room beside", 1, true) then return true end
						return "the mid-flight offer card did not show: " .. tostring(why)
					end
					return true
				end,
				hide = function()
					restoreAll()
					local curOnTaxi = W.OnTaxi
					W.OnTaxi = function() return false end
					IF.Hide()
					IF.Check()
					W.OnTaxi = curOnTaxi
				end }
			added[#added + 1] = "inflight"
		end
	end
	-- (FIX3 group E) the game's word on a rider's summon, on the console's rows and the big button: its scenes are in
	-- tests/layout/f3_e_screens.lua (console_summon_seen, console_summon_long, float_summon_held)
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/f3_e_screens.lua")
		if ch then
			local okx, E3 = pcall(ch)
			if okx and type(E3) == "table" and E3.install then
				local oki, ids = pcall(E3.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (decisions round, group Q) payment by mail: the unpaid Done screen's "Send ... by mail" line and the Customers
	-- screen's "Mail seen" note: tests/layout/dec_q_screens.lua (done_unpaid_mail, customers_mail)
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/dec_q_screens.lua")
		if ch then
			local okx, Q = pcall(ch)
			if okx and type(Q) == "table" and Q.install then
				local oki, ids = pcall(Q.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (words244 C) the ended page of a rider removed from the group: the "Removed from the group" line above the unpaid card
	do
		local base, at
		for i, s in ipairs(L.PHOTO_SCREENS) do if s.id == "done_unpaid" then base, at = s, i end end
		if base and type(base.run) == "function" then
			table.insert(L.PHOTO_SCREENS, at + 1, { id = "done_removed", side = "rider", unfold = base.unfold, only = base.only,
				title = "Ride ended: removed from the group while the summon box was up",
				run = function(w)
					local r = base.run(w)
					if r ~= true then return r end
					if type(w.ride) ~= "table" then return "no demo ride" end
					w.ride.removed = true
					w.Fire("RIDE")
					w.UI.Show("done")
					local scr = type(w.UI.state) == "table" and type(w.UI.state.screens) == "table" and w.UI.state.screens.done
					if type(scr) == "table" and type(scr.update) == "function" then scr.update() end
					local text = type(scr) == "table" and scr.unpaidText and scr.unpaidText:GetText() or ""
					if not tostring(text):find("Removed from the group", 1, true) then return "the card does not show the line" end
					return true
				end })
			added[#added + 1] = "done_removed"
		end
	end
	-- (design 4, group H) "Don't serve again until": tests/layout/d4_h_screens.lua (note_serve, customers_serve)
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/d4_h_screens.lua")
		if ch then
			local okx, H4 = pcall(ch)
			if okx and type(H4) == "table" and H4.install then
				local oki, ids = pcall(H4.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (design 4, C) the tab bar that hides during a ride, and Home during a ride: scenes in their own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/d4_c_screens.lua")
		if ch then
			local okx, C4 = pcall(ch)
			if okx and type(C4) == "table" and C4.install then
				local oki, ids = pcall(C4.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (round 47 lead) NEW SCENES GO ABOVE THIS LINE, each as its own do ... end block. The pay_part block below stays LAST.
	-- (round 46 lead) LAST on purpose: this scene leaves a ride under way, and a scene after it that needs none
	-- (the tip card) would be skipped
	-- (round 46, REV-r30-1) the pay card after a part payment, the longest realistic small line: 12g 34s 56c fare,
	-- 6g 17s 28c paid, a tip, a 12-letter payee ("12g 34s 56c" = 123456 copper)
	do
		local payBase
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "pay" then payBase = s end end
		if payBase and type(payBase.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "pay_part", side = "rider", unfold = true,
				title = "Pay card after a part payment: fare in g/s/c, part paid, a tip, a long payee",
				run = function(w)
					local r = payBase.run(w)
					if r ~= true then return r end
					local ride = w.ride
					if type(ride) ~= "table" then return "the pay shot has no ride" end
					ride.price, ride.payto, ride.paidSoFar = 123456, "Wolfgangbert", 61728
					w.db.tipPct = 20
					w.UI.Show("found")
					if w.UI.RefreshNow then w.UI.RefreshNow() end
					return true
				end }
			added[#added + 1] = "pay_part"
		end
	end
	-- (job 2525, E) the Report a bug sheet over the hunt's states (tests/layout/sheet_states.lua)
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/sheet_states.lua")
		if ch then
			local okx, J = pcall(ch)
			if okx and type(J) == "table" and J.install then
				local oki, ids = pcall(J.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (Group Finder, B1) the driver console's Group Finder card and its sheet: scenes in their own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/gf_b1_screens.lua")
		if ch then
			local okx, J = pcall(ch)
			if okx and type(J) == "table" and J.install then
				local oki, ids = pcall(J.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (FIX3 group J) the What's new card's scene lives in its own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/f3_j_screens.lua")
		if ch then
			local okx, J = pcall(ch)
			if okx and type(J) == "table" and J.install then
				local oki, ids = pcall(J.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (decisions N) the "What Wuber sends" row and the Undo toast: scenes in their own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/dec_n_screens.lua")
		if ch then
			local okx, J = pcall(ch)
			if okx and type(J) == "table" and J.install then
				local oki, ids = pcall(J.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (the toast fit fix) a long toast, a long word, a stack of toasts: the scenes' own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/toast_fit_screens.lua")
		if ch then
			local okx, J = pcall(ch)
			if okx and type(J) == "table" and J.install then
				local oki, ids = pcall(J.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (the decisions round, group R) the switches of the messages that can go by themselves: their scenes' own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/dec_r_screens.lua")
		if ch then
			local okx, R = pcall(ch)
			if okx and type(R) == "table" and R.install then
				local oki, ids = pcall(R.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (the remaining-work round) Simple mode, driver ranks and the merged Settings rows: the scenes' own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/rem_screens.lua")
		if ch then
			local okx, R = pcall(ch)
			if okx and type(R) == "table" and R.install then
				local oki, ids = pcall(R.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (design round 4, group D) Wuber's own tooltip at the screen's edge and with many words: the scenes' own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/d4_d_screens.lua")
		if ch then
			local okx, R = pcall(ch)
			if okx and type(R) == "table" and R.install then
				local oki, ids = pcall(R.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (Group Finder, group B2) the rider's search row, card lines and count line: the scenes' own file
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/gf_b2_screens.lua")
		if ch then
			local okx, R = pcall(ch)
			if okx and type(R) == "table" and R.install then
				local oki, ids = pcall(R.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	-- (Group Finder, group D) the tallest card on the empty Home with a bounty to pin
	do
		local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
		local dir = src:match("^@(.*)[/\\]")
		local ch = dir and loadfile(dir .. "/gf_d_screens.lua")
		if ch then
			local okx, R = pcall(ch)
			if okx and type(R) == "table" and R.install then
				local oki, ids = pcall(R.install, L, W)
				if oki and type(ids) == "table" then for _, id in ipairs(ids) do added[#added + 1] = id end end
			end
		end
	end
	return added
end

return X