-- Wuber Lab tests: the photo tour and Snap (WuberLab/Photo.lua, developer only, never shipped).
-- (round 10: every 2.3.0 screen, each page that unfolds also unfolded; the shot list in the log.)
-- Loaded by run.lua like tests/lab.lua, with the same helpers; skipped with one passing note
-- when the lab isn't there. The game's Screenshot() is a stub here that notes what is on
-- screen at the moment of each shot.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean = T.newWorld, T.settle, T.clean
local HAVE_UI = T.HAVE_UI

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/Photo.lua") then
	test("lab photo: Wuber Lab's Photo.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function labOf(c) return c.ns.WuberLab end

-- (2.4, the settings diet) two shots open Settings rows that 2.4 removed for good ("Who summons" and the "Report a
-- bug" row on This window; the Report a bug card on the home page and Help stay, and have their own shots), so the
-- tour skips exactly these. Anything else skipped still fails.
local REMOVED_ROWS = { settings_summoner = true, settings_bug = true }
local function otherSkips(skipped)
	local out = {}
	for _, id in ipairs(skipped or {}) do
		if not REMOVED_ROWS[(tostring(id):gsub("%+unfolded$", ""))] then out[#out + 1] = id end
	end
	return out
end

-- WuberDB as text, keys sorted: the same text means the same saved file
local function serialize(v, out)
	local t = type(v)
	if t == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then
		out[#out + 1] = tostring(v)
	elseif t == "table" then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
			return type(a) < type(b)
		end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			out[#out + 1] = "["
			serialize(k, out)
			out[#out + 1] = "]="
			serialize(v[k], out)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "<" .. t .. ">"
	end
end
local function dbText(c)
	local out = {}
	serialize(c.env.WuberDB, out)
	return table.concat(out)
end

-- Everything this window sent into the world so far (addon messages of any prefix, whispers,
-- chat lines, invites).
local function sentBy(w, name)
	local n = 0
	for _, e in ipairs(w.addonLog or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.whispers or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.chatPosts or {}) do if e.from == name then n = n + 1 end end
	for _, e in ipairs(w.invites or {}) do if e.from == name then n = n + 1 end end
	return n
end

-- Screenshot(): noted with the texts on screen and the window's width. blockFn() true = the game refuses it.
-- Like the game, it says SCREENSHOT_SUCCEEDED a moment later (saveDelay s, 0.2 by default; false: never).
local function cameraOn(c, blockFn, saveDelay)
	local shots = {}
	c.env.Screenshot = function()
		if blockFn and blockFn() then
			c:fire("ADDON_ACTION_BLOCKED", "WuberLab", "Screenshot()")
			return
		end
		if saveDelay ~= false then c.env.C_Timer.After(saveDelay or 0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
		local st = c.W.UI and c.W.UI.settings
		local win = c.W.UI and c.W.UI.state and c.W.UI.state.win
		local UI = c.W.UI
		local hp = UI and UI.settings and UI.settings.help
		local fv = c.env.StaticPopup_FindVisible
		local wn = UI and UI.state and UI.state.win
		local pt1 = wn and { wn:GetPoint(1) }
		shots[#shots + 1] = { texts = c:visibleTexts(), savedPos = c.W.db and c.W.db.pos, point = pt1 and pt1[1], popup = type(fv) == "function" and fv("WUBER_AUTO_PUBLIC") ~= nil or false,
			bug = UI and UI.Bug and UI.Bug.Shown and UI.Bug.Shown() or false,
			helpShown = UI and UI.HelpShown and UI.HelpShown() or false, helpScroll = hp and hp.scroll, helpMax = hp and hp.scrollMax,
			labShown = c.env.WuberLabPanel and c.env.WuberLabPanel:IsShown() or false,
			scroll = st and st.panel and st.panel:IsShown() and st.scroll or nil, width = win and win:GetWidth() or nil,
			-- the game's file name for this shot (one per clock second) and the moment
			file = "WoWScrnShot_" .. c.env.date("%m%d%y_%H%M%S"), at = c.env.GetTime() }
	end
	return shots
end

local function joined(texts) return table.concat(texts, " | ") end

-- what each shot must show (a plain substring, any case); folded, and a few unfolded ones
local EXPECT = {
	home = "Mia", home_empty = "No drivers online", home_bounty = "Gadgetzan", confirm = "Mia", portal = "Accept summon",
	portal_founder = "Nia", tracker = "clickers tapped", pay = "20%", stranger = "isn't your driver", done_paid = "Share",
	done_unpaid = "Not paid", raincheck = "offers a raincheck", trips = "Your trips", wrapped = "Azeroth", wrapped_summary = "That's a wrap",
	console_open = "Summon Dan", button_summoning = "Summoning Dan", button_portal = "CLICK THE PORTAL",
	button_waiting = "Waiting for Eve", console_closed = "Closed", menu_chat = "Get Wuber", note = "Never the rider",
	row_marks = "Dan Rider", customers = "Fay Storm", crew = "my account", demand = "want Gadgetzan", pvp = "PvP nearby",
	raid = "Gus", earnings = "Earnings", earnings_heatmap = "Earnings", earnings_empty = "Earnings", shift = "Fair split",
	messages = "Messages", messages_edit = "Tap to add", settings = "Settings", settings_driving = "Driving",
	settings_search = "price", settings_nomatch = "No settings match", settings_opened = "passphrase",
	help = "How Wuber finds drivers",
	-- the bug report, the Driving switch that asks first, wide Customers with a queued rider
	settings_bug = "Report a bug", settings_invite = "Invite public chat riders", settings_invite_warning = "Invite public chat riders",
	help_bug = "Something not working?", bug_window = "Select all", customers_queued = "Fay Storm",
}
-- (round 18, 3c) the floating button + console in every plan state: its title is on screen at the shot
for id, want in pairs({ open = "Open - waiting", paused = "Resume", paused_queue = "Paused - 3 waiting", summon_sent = "Summon sent to Dan",
	invited = "Invited Dan", arrived = "Waiting for Eve", queued = "Dan is in the queue", queued_member = "group leader invites",
	summon = "Summon Dan", trade_accept = "Accept 50s from Eve", trade_accept_hand = "click Trade in the trade window",
	trade_waiting = "Waiting for Eve to accept", trade_offer = "Eve offers 30s", portal_click = "CLICK THE PORTAL",
	crew_summons = "Vex Ember summons Dan", crew_clicks = "your crew clicks the portal", no_shards = "No Soul Shards",
	lead = "Give lead to Vex Ember", cantpause = "Warlocks pause", combat = "Paused during combat", closed = "tap Open below",
	raid_summon = "calls the clickers", raid_paused = "tap Resume", raid_wants = "3 raiders want", raid_idle = "Raid summons - nobody",
	raid_stopped = "tap Start below" }) do EXPECT["float_" .. id] = want end
local EXPECT_UNFOLDED = { worldmap = "Bounty", demand = "Wanted nearby", earnings = "This shift" }

local function has(text, want) return text:lower():find(want:lower(), 1, true) ~= nil end

-- A window with some history of its own (trips, a favourite, a driving log line), so a changed
-- WuberDB would show.
local function photoClient(w, name, class)
	local c = w:addClient(name, { spot = "Undercity", class = class, money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	local W = c.W
	W.db.rides[#W.db.rides + 1] = { dest = "Ratchet", driver = "Real Driver", price = 5000, at = 1700000000, stars = 4 }
	W.db.favs["real driver"] = true
	W.db.tipPct = 10
	if W.Drive and W.Drive.db then W.Drive.db.photoProbe = "kept" end
	return c
end

local function runTour(c, w, opts)
	local L = labOf(c)
	ok(L.TourStart(opts), "the tour started")
	for _ = 1, 900 do
		if not L.Touring() then break end
		w:advance(1)
	end
	ok(not L.Touring(), "the tour ended")
	return L.lastTour
end

-- the window's anchor as text (its place on the screen)
local function placeOf(c)
	local win = c.W.UI.state.win
	if not win then return "none" end
	local out = {}
	for i = 1, win:GetNumPoints() do
		local p, rel, rp, x, y = win:GetPoint(i)
		out[#out + 1] = table.concat({ tostring(p), tostring(rel and rel.GetName and rel:GetName() or rel), tostring(rp),
			string.format("%.1f", x or 0), string.format("%.1f", y or 0) }, ",")
	end
	return table.concat(out, ";")
end

-- the plan the tour should take: each screen folded, then unfolded where it unfolds
-- (job 2858) the plan of a tour that has run: the tour's screens plus the gated shots it took (bird_card_text, a stand-in card
-- when no real flight map is open), in tour order
local function plannedShot(L, result)
	local took = {}
	for _, k in ipairs(result.shot or {}) do took[tostring(k):match("^[^+]+")] = true end
	local out = {}
	for _, s in ipairs(L.PhotoScreens()) do
		if (not s.need or took[s.id]) and not REMOVED_ROWS[s.id] then
			if s.only ~= "unfolded" then out[#out + 1] = { id = s.id, view = "folded", title = s.title } end
			if s.unfold or s.only == "unfolded" then out[#out + 1] = { id = s.id, view = "unfolded", title = s.title } end
		end
	end
	return out
end

local function planned(L)
	local out = {}
	for _, s in ipairs(L.PHOTO_SCREENS) do
		if not REMOVED_ROWS[s.id] then -- (the tour skips these two, see REMOVED_ROWS)
			if s.only ~= "unfolded" then out[#out + 1] = { id = s.id, view = "folded", title = s.title } end
			if s.unfold or s.only == "unfolded" then out[#out + 1] = { id = s.id, view = "unfolded", title = s.title } end
		end
	end
	return out
end

---------------------------------------------------------------------------

test("lab photo: the tour shoots every screen, folded and unfolded (720 wide), nothing sent, WuberDB byte-identical, the shot list logged", function()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" }) -- someone listening on the network
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local shots = cameraOn(c)
	c:slash("/lab")
	w:advance(1)
	ok(c.env.WuberLabPanel:IsShown(), "lab panel open before the tour")
	W.UI.Toggle(true)
	w:advance(2)
	local place = placeOf(c)
	local before = dbText(c)
	local drivers, ride, customers = W.drivers, W.ride, W.Drive.customers
	local sendTo, flush = W.SendTo, W.FlushQueue
	local sent = sentBy(w, "Anita Lift")
	local labLines = #c.env.WuberLabDB.chars["Anita Lift"].lines
	local result = runTour(c, w)
	-- no screen changes a texture's alpha where the game would not draw it (tests/ui/alpha_test.lua)
	local heldAlpha = {}
	for line in pairs(w.alphaKept or {}) do if line:find("^Wuber/") and not (H.alphaKnown or {})[line] then heldAlpha[#heldAlpha + 1] = line end end -- known: tests/fixtures/alpha-known.txt
	table.sort(heldAlpha)
	eq(table.concat(heldAlpha, ", "), "", "Wuber lines whose alpha change the game would not draw")
	-- nothing sent, nothing saved
	eq(sentBy(w, "Anita Lift") - sent, 0, "messages, whispers, chat lines or invites sent during the tour")
	eq(dbText(c), before, "WuberDB after the tour")
	-- every planned shot, in order
	local plan = plannedShot(L, result)
	local extra = 0
	ok(#L.PHOTO_SCREENS >= 40, "screens in the tour: " .. #L.PHOTO_SCREENS)
	eq(#otherSkips(result.skipped), 0, "skipped besides the removed rows: " .. list(otherSkips(result.skipped)))
	eq(result.planned, #plan + 4 + extra, "shots planned (the four skipped ones are counted by the tour)")
	eq(list(result.skipped), "settings_summoner; settings_summoner+unfolded; settings_bug; settings_bug+unfolded", "the removed rows are what the tour skips")
	eq(#result.missed, 0, "no shot: " .. list(result.missed))
	eq(#shots, #plan + extra, "Screenshot() calls")
	eq(result.shots, #plan + extra, "shots counted")
	local narrowW, wideW = 0, 0
	local bad = {}
	for i, p in ipairs(plan) do
		local s = shots[i]
		if not s then break end
		local text = joined(s.texts)
		if os.getenv("PHOTO_DUMP") then print("SHOT " .. p.id .. " " .. p.view .. " " .. tostring(s.width) .. ": " .. text) end
		local want = p.view == "folded" and EXPECT[p.id] or EXPECT_UNFOLDED[p.id]
		if want and not has(text, want) then bad[#bad + 1] = p.id .. " " .. p.view .. ": '" .. want .. "' not on screen at its shot: " .. text:sub(1, 300) end
		if text:find("DEMO", 1, true) then bad[#bad + 1] = p.id .. ": a DEMO banner" end
		if text:find("WuberLab", 1, true) then bad[#bad + 1] = p.id .. ": Wuber mentions the lab" end
		if s.labShown then bad[#bad + 1] = p.id .. ": the lab panel is in the shot" end
		local wantW = p.view == "unfolded" and 720 or 360
		if s.width ~= wantW then bad[#bad + 1] = p.id .. " " .. p.view .. ": the window is " .. tostring(s.width) .. " wide, not " .. wantW end
		if p.view == "unfolded" then wideW = wideW + 1 else narrowW = narrowW + 1 end
	end
	ok(#bad == 0, #bad .. " shots wrong:\n" .. table.concat(bad, "\n"))
	ok(wideW >= 25 and narrowW >= 40, "folded and unfolded shots: " .. narrowW .. " / " .. wideW)
	-- the shot list: WuberLabDB.photoTour and one timeline line per shot
	local pt = c.env.WuberLabDB.photoTour
	ok(type(pt) == "table" and type(pt.shots) == "table", "WuberLabDB.photoTour written")
	eq(#pt.shots, #plan, "shots in WuberLabDB.photoTour")
	ok(type(pt.started) == "number" and type(pt.ended) == "number" and pt.ended >= pt.started, "started and ended")
	local lastAt = 0
	for i, p in ipairs(plan) do
		local r = pt.shots[i] or {}
		eq(r.n, i, "shot " .. i .. ": n")
		eq(r.id, p.id, "shot " .. i .. ": id")
		eq(r.view, p.view, "shot " .. i .. ": view")
		eq(r.title, p.title, "shot " .. i .. ": title")
		ok(type(r.at) == "number" and r.at >= lastAt and r.at >= pt.started, "shot " .. i .. ": at, in order")
		ok(not tostring(r.id):find("%s"), "shot " .. i .. ": id has no spaces")
		lastAt = r.at or lastAt
	end
	local lines = c.env.WuberLabDB.chars["Anita Lift"].lines
	local tourLines, fileLines = {}, 0
	for i = labLines + 1, #lines do
		local at, kind, rest = lines[i]:match("^([%d%.]+)|[^|]*|([^|]*)|(.*)$")
		if kind == "photo" then
			local n, total, id, view, title = rest:match("^tour shot (%d+)/(%d+) (%S+) (%S+) / (.*)$")
			if n then tourLines[#tourLines + 1] = { n = tonumber(n), total = tonumber(total), id = id, view = view, title = title, at = tonumber(at) } end
			if rest:find("WoWScrnShot_", 1, true) then fileLines = fileLines + 1 end
		end
	end
	eq(#tourLines, #plan, "a 'tour shot' timeline line per shot")
	for i, t in ipairs(tourLines) do
		local r = pt.shots[i] or {}
		ok(t.n == i and t.total == result.planned and t.id == r.id and t.view == r.view and t.title == r.title,
			"timeline line " .. i .. " matches the saved shot: " .. t.n .. "/" .. t.total .. " " .. t.id .. " " .. t.view)
		ok(math.abs((t.at or 0) - (r.at or -9)) < 0.5, "timeline line " .. i .. ": the same clock as the saved shot")
	end
	eq(fileLines, #plan, "a photo line with the file time per shot")
	-- (for the README's time estimate) the tour's length and the shots that didn't settle in time
	local moving, took = {}, nil
	for i = labLines + 1, #lines do
		local rest = lines[i]:match("^[%d%.]+|[^|]*|photo|(.*)$")
		if rest and rest:find("still moving", 1, true) then moving[#moving + 1] = rest:match("^(%S+ %S+)") end
		if rest and rest:find("^photo tour done") then took = rest:match(" in (%d+) s") end
	end
	print("PHOTO tour: " .. #plan .. " shots in " .. tostring(took) .. " s (simulated); not settled in time: " .. #moving .. " " .. table.concat(moving, ", "))
	ok(list(c.chatLines, " / "):find(#plan .. " screenshots taken", 1, true), "said in chat: " .. list(c.chatLines, " / "))
	-- everything put back
	eq(placeOf(c), place, "the window's place put back")
	ok(W.drivers == drivers and W.ride == ride and W.Drive.customers == customers, "Wuber's tables are its own again")
	ok(W.SendTo == sendTo and W.FlushQueue == flush, "Wuber's senders are its own again")
	eq(L.photo, false, "the lab's photo flag is off")
	ok(c.env.WuberLabPanel:IsShown(), "the lab panel is back")
	-- Wuber still works afterwards: the network is back
	w:advance(30)
	ok(sentBy(w, "Anita Lift") >= sent, "sends again after the tour")
	clean(w)
end)

test("lab photo: two shots never share a clock second (the game names the file by the second: a second shot would overwrite the first)", function()
	-- (the tester's tour on 19 Nov: 3 of 69 shots had no file)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local shots = cameraOn(c)
	W.UI.Toggle(true)
	w:advance(2)
	local ids = { "home", "home_empty", "home_bounty", "confirm", "worldmap", "demand", "settings", "settings_search", "settings_nomatch", "help" }
	local result = runTour(c, w, { only = ids })
	ok(result.shots >= #ids, "shots taken: " .. tostring(result.shots))
	eq(#shots, result.shots, "Screenshot() calls")
	local files, bad = {}, {}
	for i, s in ipairs(shots) do
		if files[s.file] then bad[#bad + 1] = "shots " .. files[s.file] .. " and " .. i .. " share " .. s.file end
		files[s.file] = files[s.file] or i
		local prev = shots[i - 1]
		if prev and s.at - prev.at < 1.1 then bad[#bad + 1] = ("shot %d only %.2f s after shot %d"):format(i, s.at - prev.at, i - 1) end
	end
	ok(#bad == 0, #bad .. " shots too close:\n" .. table.concat(bad, "\n"))
	-- the estimate said in chat allows for it (at least 1.1 s a shot)
	ok(L.PhotoEstimate(69) >= math.ceil(69 * 1.1), "estimate for 69 shots: " .. L.PhotoEstimate(69))
	clean(w)
end)

test("lab photo: each shot on its own builds without errors and puts WuberDB back exactly", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L = labOf(c)
	local shots = cameraOn(c)
	c.W.Drive.Active = function() return false end -- (no minute of the driving log ticks between two tours)
	local errs = #w.errors
	for _, s in ipairs(L.PHOTO_SCREENS) do
		local n = #shots
		local before = dbText(c)
		local result = runTour(c, w, { only = { s.id } })
		if REMOVED_ROWS[s.id] then
			-- (2.4) its row is gone: the tour skips it (folded and unfolded) and takes no shot
			eq(list(result.skipped), s.id .. "; " .. s.id .. "+unfolded", s.id .. " alone: skipped")
			eq(#shots - n, 0, s.id .. " alone: no shot")
		else
		eq(#result.skipped, 0, s.id .. " alone: skipped " .. list(result.skipped))
		eq(#shots - n, (s.only and 0 or 1) + ((s.unfold or s.only) and 1 or 0), s.id .. " alone: shots")
		end
		eq(dbText(c), before, s.id .. " alone: WuberDB put back")
		eq(#w.errors, errs, s.id .. " alone: errors " .. list(w.errors, " / "))
		errs = #w.errors
		w:advance(1)
	end
	clean(w)
end)

test("lab photo: a rider's window (not a Warlock) tours every screen too", function()
	local w = newWorld()
	local c = photoClient(w, "Wuber Rocks", "MAGE")
	local L = labOf(c)
	local shots = cameraOn(c)
	local before = dbText(c)
	local sent = sentBy(w, "Wuber Rocks")
	local result = runTour(c, w)
	eq(#otherSkips(result.skipped), 0, "skipped besides the removed rows: " .. list(otherSkips(result.skipped)))
	-- (job 2858) plus the stand-in card shot (bird_card_text): a gated shot taken when no real flight map is open
	local extra = 0
	for _, k in ipairs(result.shot or {}) do if tostring(k):find("^bird_card_text") then extra = extra + 1 end end
	eq(#shots, #planned(L) + extra, "Screenshot() calls")
	eq(sentBy(w, "Wuber Rocks") - sent, 0, "sent during the tour")
	eq(dbText(c), before, "WuberDB after the tour")
	clean(w)
end)

test("lab photo: a small screen shoots only the folded pages and says why the unfolded ones are skipped", function()
	local w = newWorld()
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", addons = { "Wuber", "WuberLab" },
		allowMissing = not HAVE_UI, screenW = 640, screenH = 720 })
	settle(w)
	local L = labOf(c)
	local shots = cameraOn(c)
	local before = dbText(c)
	local result = runTour(c, w, { only = { "home", "crew" } })
	eq(#shots, 2, "the two folded shots")
	eq(list(result.skipped), "home+unfolded", "the unfolded one skipped")
	eq(dbText(c), before, "WuberDB put back")
	clean(w)
end)

test("lab photo: combat stops the tour at once and puts everything back", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local shots = cameraOn(c)
	local before = dbText(c)
	local drivers = W.drivers
	ok(L.TourStart(), "started")
	w:advance(8)
	ok(L.Touring() and #shots > 0, "under way")
	w:enterCombat(c)
	eq(L.Touring(), false, "stopped by combat")
	eq(L.lastTour.reason, "combat", "the reason")
	local n = #shots
	w:advance(10)
	eq(#shots, n, "no shot after the fight began")
	eq(dbText(c), before, "WuberDB put back")
	ok(W.drivers == drivers and W.ride == nil, "tables put back")
	eq(#c.env.WuberLabDB.photoTour.shots, n, "the shot list has the shots taken")
	-- and no tour can start in combat
	eq(L.TourStart(), false, "refused in combat")
	w:leaveCombat(c)
	w:advance(2)
	clean(w)
end)

test("lab photo: refused during a ride or while open; a click anywhere stops it", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	cameraOn(c)
	W.ride = { id = "real", state = "accepted", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000 }
	local okStart, why = L.TourStart()
	eq(okStart, false, "refused during a ride")
	ok(tostring(why):find("ride", 1, true), "says why: " .. tostring(why))
	W.ride = nil
	local before = dbText(c)
	ok(L.TourStart(), "started")
	w:advance(4)
	c:clickOn(c.env.WuberLabPhotoCatcher)
	eq(L.Touring(), false, "a click stopped it")
	eq(L.lastTour.reason, "a click", "the reason")
	eq(dbText(c), before, "WuberDB put back")
	clean(w)
end)

test("lab photo: refused while a trade window is open or a summon is waiting (the tour would hold their closing events back)", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L = labOf(c)
	cameraOn(c)
	local before = dbText(c)
	c.env.TradeFrame:Show()
	local okStart, why = L.TourStart()
	eq(okStart, false, "refused with the trade window open")
	ok(tostring(why):find("trade", 1, true), "says why: " .. tostring(why))
	eq(L.Touring(), false, "no tour")
	c.env.TradeFrame:Hide()
	local si = c.env.C_SummonInfo
	local left = si.GetSummonConfirmTimeLeft
	si.GetSummonConfirmTimeLeft = function() return 90 end
	okStart, why = L.TourStart()
	eq(okStart, false, "refused with a summon waiting")
	ok(tostring(why):find("summon", 1, true), "says why: " .. tostring(why))
	eq(L.Touring(), false, "no tour")
	si.GetSummonConfirmTimeLeft = left
	eq(dbText(c), before, "WuberDB untouched")
	ok(L.TourStart(), "starts once both are gone")
	L.TourStop("test")
	clean(w)
end)

test("lab photo: /lab snap and the Snap button take one shot without the lab in it", function()
	local w = newWorld()
	local c = photoClient(w, "Wuber Rocks", "MAGE")
	local L = labOf(c)
	local shots = cameraOn(c)
	c:slash("/lab")
	w:advance(1)
	c:slash("/lab snap")
	eq(#shots, 1, "one shot")
	eq(shots[1].labShown, false, "the panel stepped aside")
	w:advance(1.5)
	ok(c.env.WuberLabPanel:IsShown(), "and came back")
	for _, t in ipairs(L.panel.tabs) do if t.name == "Tools" then c:clickOn(t) end end
	w:advance(0.6)
	c:clickOn(L.panel.toolButtons.snap)
	eq(#shots, 2, "the button took one")
	ok(list(c.chatLines, " / "):find("screenshot 2 saved", 1, true), "said where: " .. list(c.chatLines, " / "))
	clean(w)
end)

test("lab photo: where the game refuses Screenshot() from a timer, each shot is a click on Snap (logged the same)", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L = labOf(c)
	local fromClick = false
	local shots = cameraOn(c, function() return not fromClick end)
	local before = dbText(c)
	ok(L.TourStart({ only = { "home", "crew", "help" } }), "started")
	local clicks = 0
	for _ = 1, 120 do
		if not L.Touring() then break end
		w:advance(0.5)
		local b = c.env.WuberLabPhotoSnap
		if b and b:IsShown() then
			fromClick = true
			c:clickOn(b)
			fromClick = false
			clicks = clicks + 1
			ok(not b:IsShown(), "the Snap button hid itself for the shot")
		end
	end
	eq(L.Touring(), false, "done")
	eq(clicks, 5, "one click per shot (home and help folded and unfolded, crew)")
	eq(#shots, 5, "five shots")
	eq(L.photoClick, true, "learned: a click per shot")
	local pt = c.env.WuberLabDB.photoTour
	eq(#pt.shots, 5, "the shot list has every clicked shot")
	eq(pt.shots[5] and pt.shots[5].id, "help", "the last one")
	eq(dbText(c), before, "WuberDB put back")
	clean(w)
end)

---------------------------------------------------------------------------
-- Round 13 (I33, I34): the tour's demo data adds up everywhere; shots wait for animations
---------------------------------------------------------------------------

-- the tour's plan for a few screens (in the tour's own order)
local function planFor(L, ids)
	local want, list = {}, {}
	for _, id in ipairs(ids) do want[id] = true end
	for _, s in ipairs(L.PHOTO_SCREENS) do if want[s.id] then list[#list + 1] = s end end
	return L.PhotoPlan(list)
end

-- what Wuber itself says at the moment of each shot (its real functions, over the demo data)
local function probeOn(c)
	local probes = {}
	local W = c.W
	local DR, D = W.Drive, W.Driver
	local base = c.env.Screenshot
	c.env.Screenshot = function(...)
		base(...)
		local p = { texts = c:visibleTexts() }
		p.lastShift = D.lastShift
		p.today = { D.Today() }
		-- (counted here from the log itself, not by Wuber's sums, which a shot may have replaced)
		local mid = DR.LogSince("today")
		local l = W.db.drive and W.db.drive.log or {}
		p.todayLog = { rides = 0, copper = 0 }
		for _, line in ipairs(l.rides or {}) do
			local at, copper = tostring(line):match("^(%d+),(%d+),")
			if at and tonumber(at) >= mid then p.todayLog.rides, p.todayLog.copper = p.todayLog.rides + 1, p.todayLog.copper + tonumber(copper) end
		end
		local e = W.UI.drive and W.UI.drive.screens and W.UI.drive.screens.earnings
		if e then
			p.range, p.tot, p.hours = e.range, e.tot, e.hours
			local hm = (e.heatW and e.heatW:IsShown()) and e.heatW or e.heat
			p.grid, p.picked = hm and hm.grid, hm and hm.picked
			p.info = hm and hm.info and hm.info:GetText()
		end
		p.customers = {}
		for _, x in ipairs(DR.Customers() or {}) do p.customers[x.key] = x.rides end
		p.counts = {}
		for _, n in ipairs({ "Dan Rider", "Eve Night", "Gus Hill" }) do p.counts[W.Key(n)] = DR.RideCount(n) end
		p.tier = { W.TierProgress() }
		p.stats = W.Stats()
		p.ms = {}
		for k, v in pairs(W.db.milestones or {}) do p.ms[k] = v end
		p.trips = #W.db.rides
		probes[#probes + 1] = p
	end
	return probes
end

local function sum(t, k)
	local n = 0
	for h = 0, 23 do n = n + ((t[h] or {})[k] or 0) end
	return n
end

test("lab photo: the tour's demo data adds up (shift split = takings, casts = rides, bars = heatmap = summary, ride counts, trips)", function()
	-- (round 13, I33: a reviewer's review of the 19 Nov tour: '1g to your crew' but the split gives 2g, 9 rides
	-- from 7 casts, bars at 00-12 where the heatmap is empty, 8 rides from 6 buyers, 'Eve 1 ride' vs
	-- '11th ride', 11 rides vs 12, Hour Saver locked after 1h 50m saved)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local DR = W.Drive
	cameraOn(c)
	local probes = probeOn(c)
	W.UI.Toggle(true)
	w:advance(2)
	local ids = { "trips", "console_open", "customers", "earnings", "earnings_heatmap", "earnings_empty", "shift" }
	local result = runTour(c, w, { only = ids })
	eq(#result.skipped, 0, "skipped: " .. list(result.skipped))
	local plan = planFor(L, ids)
	eq(#probes, #plan, "a probe per shot")
	local bad = {}
	local function check(cond, what) if not cond then bad[#bad + 1] = what end end
	for i, e in ipairs(plan) do
		local p = probes[i] or {}
		local tag = e.s.id .. " " .. e.view .. ": "
		local text = joined(p.texts or {})
		-- today's rides and gold on the console: the log's (every driver shot, the empty Earnings one too)
		if p.today and p.todayLog and e.s.side == "driver" then
			check(p.today[1] == p.todayLog.rides and p.today[2] == p.todayLog.copper, tag .. "today " .. p.today[1] .. " rides " .. p.today[2]
				.. " vs the log's " .. tostring(p.todayLog.rides) .. " / " .. tostring(p.todayLog.copper))
		end
		if e.s.id == "trips" then
			local st = p.stats or {}
			check(p.tier[2] == st.rides and st.rides == p.trips, tag .. "level rides " .. tostring(p.tier[2]) .. ", stats " .. tostring(st.rides) .. ", trips " .. tostring(p.trips))
			for _, m in ipairs(W.MILESTONES) do
				local earned = m.test(st) == true
				check(earned == (p.ms[m.id] ~= nil), tag .. m.id .. (earned and " earned but locked" or " locked but marked earned"))
			end
			check(has(text, W.UI.TripsHM(st.saved)), tag .. "time saved " .. W.UI.TripsHM(st.saved) .. " not on screen (still counting up?)")
		elseif e.s.id == "console_open" or e.s.id == "customers" then
			for k, n in pairs(p.counts) do
				check((p.customers[k] or 0) == n, tag .. k .. ": " .. tostring(p.customers[k]) .. " rides in Customers, " .. n .. " before this ride in the queue")
			end
		elseif e.s.id == "earnings" or e.s.id == "earnings_heatmap" then
			local hrs, grid, tot = p.hours or {}, p.grid, p.tot or {}
			check(grid ~= nil, tag .. "a heatmap")
			for h = 0, 23 do
				local col = { copper = 0, rides = 0, open = 0, asks = 0 }
				for wd = 0, 6 do
					local cell = grid and grid[wd] and grid[wd][h] or {}
					for k in pairs(col) do col[k] = col[k] + (cell[k] or 0) end
					check((cell.asks or 0) >= (cell.rides or 0), tag .. "heatmap " .. wd .. "/" .. h .. ": " .. tostring(cell.rides) .. " rides from " .. tostring(cell.asks) .. " buyers")
				end
				local b = hrs[h] or {}
				for k, v in pairs(col) do
					check((b[k] or 0) == v, tag .. ("hour %02d: the bar's %s %s, the heatmap's %s"):format(h, k, tostring(b[k]), tostring(v)))
				end
			end
			for _, k in ipairs({ "copper", "rides", "open", "asks" }) do
				check(sum(hrs, k) == (tot[k] or -1), tag .. "summary " .. k .. " " .. tostring(tot[k]) .. ", the bars add up to " .. sum(hrs, k))
			end
			check((tot.rides or 0) > 0, tag .. "rides logged")
			if e.s.id == "earnings_heatmap" then
				check(p.picked ~= nil, tag .. "no square tapped")
				check(p.info and not has(p.info, "Tap a square") and has(p.info, "riders asked"), tag .. "the tapped square's numbers: " .. tostring(p.info))
			end
		elseif e.s.id == "shift" then
			local ls = p.lastShift or {}
			local rows = ls.cut and ls.cut.rows or {}
			local shares, casts = 0, 0
			for _, r in ipairs(rows) do shares, casts = shares + (r.share or 0), casts + (r.casts or 0) end
			local pot = (ls.copper or 0) + (ls.crewCopper or 0)
			check(shares == pot, tag .. "the split gives " .. shares .. ", the shift took " .. pot)
			check(casts == (ls.rides or 0) + (ls.crewRides or 0), tag .. casts .. " casts for " .. tostring(ls.rides) .. " + " .. tostring(ls.crewRides) .. " rides")
			local ck, cl = {}, {}
			for _, r in ipairs(rows) do ck[r.key], cl[r.key] = r.casts, r.clicks end
			local want = DR.CutSplit(pot, ck, cl, ls.cut.rule, ls.cut.pct, W.myKey)
			for _, r in ipairs(rows) do
				check(want[r.key] == r.share, tag .. r.name .. ": " .. tostring(r.share) .. ", the fair split rule gives " .. tostring(want[r.key]))
			end
			check(text:find(tostring((ls.rides or 0) + (ls.crewRides or 0)), 1, true) ~= nil, tag .. "the rides tile")
			-- (round 13, I11 with agent B's card) the headline is the whole the split shares
			local money = W.Driver.kit and W.Driver.kit.money
			check(money and has(text, money(pot)), tag .. "the headline is the split's whole " .. tostring(money and money(pot)))
		end
	end
	ok(#bad == 0, #bad .. " things don't add up:\n" .. table.concat(bad, "\n"))
	clean(w)
end)

test("lab photo: the tapped heatmap hour shows folded and unfolded", function()
	-- (round 13, I34: shot 50, unfolded, had no square tapped: the unfolded page has its own heatmap)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	cameraOn(c)
	local probes = probeOn(c)
	W.UI.Toggle(true)
	w:advance(2)
	local result = runTour(c, w, { only = { "earnings_heatmap" } })
	eq(result.shots, 2, "folded and unfolded")
	for i, view in ipairs({ "folded", "unfolded" }) do
		local p = probes[i] or {}
		ok(p.picked ~= nil, view .. ": a square tapped")
		ok(p.info and not has(p.info, "Tap a square") and has(p.info, "ride"), view .. ": its numbers: " .. tostring(p.info))
		ok(has(joined(p.texts or {}), tostring(p.info)), view .. ": the numbers on screen")
	end
	clean(w)
end)

test("lab photo: the count-up on Trips has finished at the shot", function()
	-- (round 13, I34: shots 18, 19 caught time saved at 1h 37m on its way to 1h 50m)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	cameraOn(c)
	local probes = probeOn(c)
	W.UI.Toggle(true)
	w:advance(2)
	local result = runTour(c, w, { only = { "trips" } })
	eq(result.shots, 2, "folded and unfolded")
	for i, view in ipairs({ "folded", "unfolded" }) do
		local p = probes[i] or {}
		local want = W.UI.TripsHM((p.stats or {}).saved or 0)
		ok(has(joined(p.texts or {}), want), view .. ": time saved " .. want .. " on screen: " .. joined(p.texts or {}):sub(1, 200))
	end
	clean(w)
end)

test("lab photo: the next shot waits until the game has saved the last one, in a later clock second", function()
	-- (round 13, I34: shots 31, 38 and 66 had no file and 65 showed the next screen: two shots in one second)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local shots = cameraOn(c, nil, false)
	local base = c.env.Screenshot
	local saved = {}
	-- the game saves the file a while after Screenshot() (here 0.9 s), then says so
	c.env.Screenshot = function()
		base()
		local n = #shots
		c.env.C_Timer.After(0.9, function()
			saved[n] = { at = c.env.GetTime(), file = "WoWScrnShot_" .. c.env.date("%m%d%y_%H%M%S") }
			c:fire("SCREENSHOT_SUCCEEDED")
		end)
	end
	W.UI.Toggle(true)
	w:advance(2)
	local ids = { "home", "home_empty", "settings", "settings_nomatch", "settings_opened", "help" }
	local result = runTour(c, w, { only = ids })
	eq(#result.missed, 0, "no shot missed")
	eq(#shots, #planFor(L, ids), "a shot per plan line")
	local files, bad = {}, {}
	for i, s in ipairs(shots) do
		local sv = saved[i]
		ok(sv ~= nil, "shot " .. i .. " saved")
		if sv then
			if files[sv.file] then bad[#bad + 1] = "shots " .. files[sv.file] .. " and " .. i .. " saved as " .. sv.file end
			files[sv.file] = files[sv.file] or i
		end
		local prev = saved[i - 1]
		if prev and s.at - prev.at < 1.1 then bad[#bad + 1] = ("shot %d only %.2f s after shot %d was saved"):format(i, s.at - prev.at, i - 1) end
	end
	ok(#bad == 0, #bad .. " shots too close:\n" .. table.concat(bad, "\n"))
	clean(w)
end)

test("lab photo: the queue rows follow the big button, the waiting line is neutral, the marked row unfolds", function()
	-- (round 13, I13: Dan's row said 'ready to summon' under 'Summoning Dan'; I28: 'she pays in a trade';
	-- I4: unfolded, the riders' rows are only in the side pane, where row_marks must find Dan)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local shots = cameraOn(c)
	W.UI.Toggle(true)
	w:advance(2)
	local ids = { "button_summoning", "button_portal", "button_waiting", "row_marks" }
	local result = runTour(c, w, { only = ids })
	local plan = planFor(L, ids)
	local bad = {}
	for i, e in ipairs(plan) do
		local text = joined(shots[i] and shots[i].texts or {})
		local tag = e.s.id .. " " .. e.view .. ": "
		if e.s.id == "button_summoning" or e.s.id == "button_portal" then
			-- button_portal says Vex Ember is casting, so Dan's row says (Vex), not (you)
			local want = e.s.id == "button_portal" and "summoning (Vex)" or "summoning (you)"
			if not has(text, want) then bad[#bad + 1] = tag .. "Dan's row doesn't say he is being summoned" end
			if has(text, "ready to summon") then bad[#bad + 1] = tag .. "a row still 'ready to summon'" end
		elseif e.s.id == "button_waiting" then
			if not has(text, "Eve is here · waiting for the trade") then bad[#bad + 1] = tag .. "no neutral waiting line" end
			if has(text, "pays in a trade") then bad[#bad + 1] = tag .. "'pays in a trade'" end
		end
	end
	ok(#bad == 0, #bad .. " rows or lines wrong:\n" .. table.concat(bad, "\n"))
	eq(#result.skipped, 0, "skipped: " .. list(result.skipped))
	eq(#shots, #plan, "a shot per plan line")
	clean(w)
end)

test("lab photo: no made-up flight price (Orgrimmar to Undercity is a zeppelin): Wuber's own FlightCost, no flight cost on the demo rides", function()
	-- (round 13, I14 demo data: the tour stubbed W.FlightCost to 23s, a price no route has)
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L, W = labOf(c), c.W
	local own = W.FlightCost
	local seen = {}
	cameraOn(c)
	local base = c.env.Screenshot
	c.env.Screenshot = function(...)
		base(...)
		seen[#seen + 1] = { own = W.FlightCost == own, ride = W.ride and W.ride.flightCost, trips = 0 }
		for _, r in ipairs(W.db.rides or {}) do if r.flightCost then seen[#seen].trips = seen[#seen].trips + 1 end end
	end
	W.UI.Toggle(true)
	w:advance(2)
	local result = runTour(c, w, { only = { "confirm", "pay", "done_paid", "trips" } })
	eq(#result.skipped, 0, "skipped: " .. list(result.skipped))
	ok(#seen >= 5, "shots: " .. #seen)
	for i, s in ipairs(seen) do
		ok(s.own, "shot " .. i .. ": W.FlightCost is Wuber's own")
		eq(s.ride, nil, "shot " .. i .. ": the demo ride's flight cost")
		eq(s.trips, 0, "shot " .. i .. ": demo trips with a flight cost")
	end
	clean(w)
end)

-- the shots a reviewer asked for, and the two demo states that contradicted their own names. Each is judged
-- the way the real client draws it: the texts on screen, the popup up, the help page at its end, the log really empty.
test("lab photo: B9 - empty Earnings is empty, the tips shot has sparse hours, and the bug report, the public-chat warning and a queued rider's pill each have a shot", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L = labOf(c)
	local shots = cameraOn(c)
	c.W.UI.Toggle(true)
	w:advance(2)
	-- (2.4) no settings_bug here: its Settings row is gone (REMOVED_ROWS); the card on the home page and Help stay
	local ids = { "earnings", "earnings_empty", "earnings_tips", "settings_invite", "settings_invite_warning",
		"help_bug", "bug_window", "customers", "customers_queued", "settings" }
	local before = dbText(c)
	local result = runTour(c, w, { only = ids })
	eq(#result.skipped, 0, "skipped: " .. list(result.skipped))
	eq(#result.missed, 0, "missed: " .. list(result.missed))
	local by = {}
	local plan = planned(L)
	local n = 0
	for _, p in ipairs(plan) do
		local keep = false
		for _, id in ipairs(ids) do if id == p.id then keep = true end end
		if keep then
			n = n + 1
			by[p.id .. "/" .. p.view] = shots[n]
		end
	end
	eq(n, #shots, "every shot matched to the plan")
	local function text(id, view) local s = by[id .. "/" .. view]; return s and joined(s.texts) or "" end
	local function count(s, what) local k = 0 for _ in s:gmatch(what) do k = k + 1 end return k end
	for _, view in ipairs({ "folded", "unfolded" }) do
		-- really empty: no rides, no minutes, no buyers; not the week's 65 rides
		local e = text("earnings_empty", view)
		ok(e:find("0 rides", 1, true) and not e:find("65 rides", 1, true) and e:find("0 min open", 1, true), "earnings_empty " .. view .. " is empty: " .. e:sub(1, 400))
		ok(e:find("Open for a few hours and your best times", 1, true), "earnings_empty " .. view .. " says so under the heatmap")
		ok(not e:find("Top window", 1, true) and not e:find("Try ", 1, true), "earnings_empty " .. view .. " has no tips")
		-- sparse: Wuber's own TopWindow has none, so both tips are true
		local t = text("earnings_tips", view)
		ok(t:find("Open a few hours to find your best ones", 1, true) and t:find("Try ", 1, true), "earnings_tips " .. view .. " has both tips: " .. t:sub(1, 300))
		ok(not t:find("65 rides", 1, true) and t:find("2 rides", 1, true) and t:find("45 min open", 1, true), "earnings_tips " .. view .. " is sparse")
		-- the full week still there for earnings
		ok(text("earnings", view):find("65 rides", 1, true), "earnings " .. view .. " has the full week")
	end
	-- the warning is up in its shot only; the bug window likewise
	for _, view in ipairs({ "folded", "unfolded" }) do
		ok(by["settings_invite_warning/" .. view].popup, "the public-chat warning is on screen (" .. view .. ")")
		ok(not by["settings_invite/" .. view].popup, "not in the shot before it")
		ok(not by["help_bug/" .. view].popup, "nor elsewhere")
		ok(by["settings_invite/" .. view].texts and text("settings_invite", view):find("Invite public chat riders", 1, true), "the row is on screen")
		ok(text("help_bug", view):find("Something not working?", 1, true), "Something not working? on screen in Help (" .. view .. ")")
		ok(by["help_bug/" .. view].helpShown, "Help is open (" .. view .. ")")
		ok((by["help_bug/" .. view].helpMax or 0) > 0 and by["help_bug/" .. view].helpScroll >= by["help_bug/" .. view].helpMax - 1,
			"Help is scrolled to its end (" .. view .. "): " .. tostring(by["help_bug/" .. view].helpScroll) .. " of " .. tostring(by["help_bug/" .. view].helpMax))
	end
	ok(by["bug_window/folded"].bug and not by["settings/folded"].bug, "the bug window is in its own shot only")
	ok(text("bug_window", "folded"):find("Select all", 1, true), "its Select all and report")
	-- Settings folded: the scrolled shots are scrolled (the row isn't at the top of the page)
	ok((by["settings_invite/folded"].scroll or 0) > 100, "Invite public chat riders scrolled to: " .. tostring(by["settings_invite/folded"].scroll))
	-- the home has a visible Report a bug card
	ok(text("settings", "folded"):find("Report a bug", 1, true), "Settings home offers Report a bug")
	-- wide Customers with a queued rider picked: one more Invite to Wuber (the right pane's), only in that shot
	local a = count(text("customers", "unfolded"), "Invite to Wuber")
	local b = count(text("customers_queued", "unfolded"), "Invite to Wuber")
	eq(b, a + 1, "the queued rider's pill in the right pane: " .. a .. " -> " .. b)
	eq(dbText(c), before, "WuberDB put back")
	clean(w)
end)

-- the tour shows Wuber's own default place, not a place of its own saved as the player's choice
test("lab photo: the phone stands at Wuber's default place for every shot (no saved position), and the player's own place is put back", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local shots = cameraOn(c)
	c.W.UI.Toggle(true)
	w:advance(2)
	c.W.db.pos = { "TOPLEFT", "TOPLEFT", 33, -44 } -- a place the player chose
	local result = runTour(c, w, { only = { "home", "trips", "chat_home" } })
	eq(#result.skipped, 0, "skipped: " .. list(result.skipped))
	ok(#shots >= 3, "shots: " .. #shots)
	for i, s in ipairs(shots) do
		eq(s.savedPos, nil, "shot " .. i .. ": no saved position during the tour")
	end
	-- (the folded home: the unfolded ones are placed by Wuber's own fold, off to the left edge)
	eq(shots[1].point, "CENTER", "the first shot is at the default place (the middle, clear of the chat)")
	eq(c.W.db.pos[3], 33, "the player's own place is back after the tour")
	clean(w)
end)

-- the floating-button shots agree with their own titles (they were demo contradictions, not Wuber's)
test("lab photo: B5 - the floating button shots match their titles (who casts, shards, helper, empty raid, tap Open below)", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L = labOf(c)
	local shots = cameraOn(c)
	c.W.UI.Toggle(true)
	w:advance(2)
	local ids = { "button_portal", "float_portal_click", "float_no_shards", "float_cantpause", "float_raid_idle", "float_closed", "float_raid_stopped", "float_open" }
	local result = runTour(c, w, { only = ids })
	eq(#result.skipped, 0, "skipped: " .. list(result.skipped))
	local by, n = {}, 0
	for _, p in ipairs(planned(L)) do
		for _, id in ipairs(ids) do
			if id == p.id then n = n + 1 if p.view == "folded" then by[id] = joined(shots[n].texts) end end
		end
	end
	local function has2(id, s) return by[id] and by[id]:find(s, 1, true) ~= nil end
	ok(has2("float_portal_click", "summoning (Vex)") and not has2("float_portal_click", "(you)"), "the portal click: Dan's row is Vex's cast, not yours")
	ok(has2("button_portal", "Vex Ember is casting"), "the big button names who casts")
	ok(has2("float_no_shards", "| 0 shards |") and not has2("float_no_shards", "| 12 shards |"), "no shards: the gauge says 0: " .. tostring(by.float_no_shards):sub(-120))
	ok(has2("float_cantpause", "Warlocks pause") and has2("float_cantpause", "| 23 shards |") and not has2("float_cantpause", "| 12 shards |"),
		"a crew helper: the Warlocks' shards (23), not shards of its own")
	ok(not has2("float_raid_idle", "Dan") and not has2("float_raid_idle", "Eve") and not has2("float_raid_idle", "Gus"), "raid idle: nobody listed")
	ok(has2("float_closed", "tap Open below") and not has2("float_closed", "Pause"), "closed: tap Open below, no Pause")
	ok(has2("float_raid_stopped", "tap Start below") and not has2("float_raid_stopped", "Pause"), "raid stopped: tap Start below")
	ok(has2("float_open", "Close | 12"), "an open Warlock still shows its own 12 (the stubs don't leak)")
	clean(w)
end)

test("lab photo: S6 - a partial tour by group or id start: the subset is saved and logged, a full tour is unchanged", function()
	local w = newWorld()
	local c = photoClient(w, "Anita Lift", "WARLOCK")
	local L = labOf(c)
	local ids, label, unknown = L.TourResolve({ "earnings", "home_b" })
	eq(table.concat(ids, ","), "home_bounty,earnings,earnings_heatmap,earnings_tips,earnings_empty", "group and prefix, in tour order")
	eq(label, "earnings,home_b", "label")
	eq(#unknown, 0, "nothing unknown")
	local _, _, bad = L.TourResolve({ "nonsense" })
	eq(bad[1], "nonsense", "an unknown word is reported")
	for _, g in ipairs({ "ride", "drive", "float", "settings", "earnings" }) do
		local gi = L.TourResolve({ g })
		ok(#gi >= 3, g .. " group has screens: " .. #gi)
	end
	local fl = L.TourResolve({ "float" })
	for _, id in ipairs(fl) do ok(id:find("float_") or id == "chat_float", "float group: " .. id) end
	local shots = cameraOn(c)
	L.Slash("tour earnings_tips, home")
	w:advance(30)
	eq(L.Touring(), false, "the partial tour finished")
	local pt = c.env.WuberLabDB.photoTour
	eq(pt.subset, "earnings_tips,home", "subset saved with the shot list")
	eq(#pt.shots, #shots, "every shot listed")
	eq(pt.shots[1].id, "home", "the shots keep their numbers and ids")
	ok(list(c.chatLines, " / "):find("/reload", 1, true), "the done message says /reload: " .. list(c.chatLines, " / "))
	clean(w)
end)
