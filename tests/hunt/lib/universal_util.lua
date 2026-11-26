-- tests/hunt/lib/universal_util.lua: helpers of the UNIVERSAL promises and actions (the bug hunt).
-- Owner: UNIVERSAL. Loaded by tests/promises/universal.lua and tests/hunt/actions.lua with
--   local U = dofile("tests/hunt/lib/universal_util.lua")      (cached: the same table every time)
--
-- What it does, once per process:
--   * U.install(): (a) loads the layout engine (tests/layout/engine.lua) and tags every widget with the addon that made it
--     (E.tag must be installed BEFORE a client is created, so it wraps H.NewWorld and tags there; the hook the core
--     could offer instead is Hunt.onWorld(fn(ctx)): not needed, this works without it); (b) watches every world:
--     each addon message, whisper, chat line and macro that a client sends is logged in w.huntU.sends with whether a
--     hardware event of that client was under way (w.hardware), and the time of each client's last hardware event.
--   * the small readers the promises share: visible Wuber widgets, button labels, money strings, the screen's name.
-- Nothing here changes addon behaviour; the only writes are to the harness objects (instance fields on w and the clients).
local U = {}
if rawget(_G, "__HUNT_UNIVERSAL_UTIL") then return rawget(_G, "__HUNT_UNIVERSAL_UTIL") end
rawset(_G, "__HUNT_UNIVERSAL_UTIL", U)

package.path = "tests/?.lua;" .. package.path
local H = require("harness")
U.H, U.S = H, H.state
local S = H.state

-- the layout engine and its allow-list (the same list the layout check uses)
local E = assert(loadfile("tests/layout/engine.lua"))(H)
U.E = E
U.ALLOW = dofile("tests/layout/allow.lua")

-- Hunt-side allow table (the hunt's own; tests/layout/allow.lua is not edited). ONLY true variants of an entry that list
-- allows, one line each with the reason. Same fields as allow.lua (kind, screen, key, what, detail, reason).
U.HUNT_ALLOW = {
	-- variant of allow.lua's "windows ^Moments.lua:%d+ .* over ": the same moment card (a card over the phone on purpose) when
	-- the phone was opened after it, so the phone is the window listed first
	{ kind = "windows", key = "^WuberFrame over Moments%.lua:%d+", reason = "a moment card is a card over the phone on purpose (the other order of an allowed pair)" },
	-- variants of allow.lua's "empty Earnings: the note is drawn on the empty heatmap": the same note over a picked cell, and the
	-- note straddling it, in either order
	{ kind = "boxes", key = "^Earnings%.lua:%d+ empty over Earnings%.lua:%d+ picked", reason = "empty Earnings: the 'Open for a few hours' note is drawn on the empty heatmap (its picked cell) on purpose" },
	{ kind = "straddle", key = "^Earnings%.lua:%d+.- straddles Earnings%.lua:%d+.-picked", reason = "empty Earnings: the note is drawn on the empty heatmap (its picked cell) on purpose" },
	-- the big Drive BUTTON (not its console list) lifted above the opened-out phone when no clear place is left beside it:
	-- the documented fallback (Drive/Button.lua 340-344, 434-440, BRIEF18). The console list over the phone stays reported (HUNT-92).
	{ kind = "windows", key = "^WuberDriveButton over WuberFrame$", reason = "no clear place beside the opened-out phone: the big button goes above it (Drive/Button.lua, BRIEF18)" },
	-- Finding your driver: the route pill sits over the radar's top left corner on purpose (Rider/Confirm.lua:641, "the route header")
	{ kind = "boxes", key = "^Booking%.lua:%d+.- over Confirm%.lua:%d+", reason = "Finding your driver: the route pill lies over the radar's corner on purpose (Confirm.lua:641)" },
	-- a route pill's words sit under its opaque pill, which hides the map pin they seem to straddle (the pill over the pin is allowed in allow.lua)
	{ kind = "straddle", key = "^Booking%.lua:%d+.- straddles HomeMap%.lua:%d+", reason = "the route pill is opaque and lies over the map strip on purpose: only a pin's edge peeks out" },
	-- the ride screen's big title ("Time to pay", "You've arrived") is drawn over the map strip on purpose (Rider/Ride.lua:261-278)
	{ kind = "straddle", key = "^Ride%.lua:%d+.- straddles HomeMap%.lua:%d+", reason = "the ride title is drawn over the map strip on purpose (Ride.lua:270-278)" },
	-- the booked driver stands at the route end, where the destination portal pin is (Confirm.lua:168): the driver pin (higher, clickable)
	-- over the portal pin is by design. NOT the portal pin hidden under the sheet (Confirm.lua:192, HUNT-116): that is a different frame
	{ kind = "boxes", key = "^HomeMap%.lua:%d+ Button over Confirm%.lua:168 Frame", reason = "the driver stands at the route end, over the portal pin, on purpose (Confirm.lua:166-168)" },
	-- the alert banner and its counter are deliberate full-screen alerts (Drive/Bell.lua header)
	{ kind = "windows", key = "^WuberBell", reason = "the alert banner and its counter are deliberate full-screen alerts (Bell.lua)" },
	-- /wuber bug is a window of its own (DIALOG): the other order of the pair allow.lua lets sit over the phone
	-- (2.4 judge rulings, universal.layout) each entry below is one frame, one kind of hit, one state
	{ kind = "windows", key = "^WuberFrame over WuberFlightPins$", reason = "WuberFlightPins is a holder of price tags lying on the game's own flight map (FlightPins.lua:141): the phone over the game's map covers tags, the world under a window" },
	{ kind = "windows", key = "^WuberNewsCard over WuberFlightPins$", reason = "WuberFlightPins is a holder of price tags lying on the game's own flight map (FlightPins.lua:141): the What's new card over the game's map covers tags, the world under a window" },
	-- (2.4.2 merge) hunt's "Report a bug over the Ride page's button" allowance (job 097) is left out: it masks E3b-01, a real
	-- regression the guard tests/v24/e3b11c_layout_allow_test.lua keeps failing
	{ kind = "boxes", key = "^Confirm%.lua:648", detail = "half over Confirm%.lua:697", reason = "Finding your driver: the level chip lies at the corner of the radar's empty square holder (Confirm.lua:697); the rings are round and do not reach it" },
	{ kind = "boxes", key = "^Phone%.lua:175", detail = "half over Confirm%.lua:697", reason = "Finding your driver: the fold button lies over the corner of the radar's empty square holder (Confirm.lua:697)" },
	{ kind = "boxes", key = "^Window%.lua:672", detail = "half over Confirm%.lua:697", reason = "Finding your driver: the close button lies over the corner of the radar's empty square holder (Confirm.lua:697)" },
	{ kind = "boxes", key = "^Window%.lua:710", detail = "half over Confirm%.lua:697", reason = "Finding your driver: the gear lies over the corner of the radar's empty square holder (Confirm.lua:697)" },
	{ kind = "boxes", key = "^Window%.lua:672", detail = "half over Confirm%.lua:213", reason = "Confirm: the destination pin (Confirm.lua:213) is placed on the map strip by the route; the header's close button lies over the map strip" },
	{ kind = "chrome", key = "^Confirm%.lua:213", detail = "in the place of the header button Window%.lua:672", reason = "Confirm: the destination pin (Confirm.lua:213) is placed on the map strip by the route; the header's close button lies over the map strip (same pin as the boxes entry; the chrome rule sees it as a piece of the map)" },
	{ kind = "boxes", key = "^HomeMap%.lua:172", detail = "half over Confirm%.lua:213", reason = "Confirm: the destination pin (Confirm.lua:213) is placed on the map strip by the route; the map's own button lies over the map strip" },
	{ kind = "under", key = "^SeaRoute%.lua:%d+", detail = "WorldMap%.lua:1341", reason = "World map layers: the sea route's label lies under the 'you are here' dot on the pin layer where the route passes the rider" },
	{ kind = "under", key = "^WorldMap%.lua:1321", detail = "WorldMap%.lua:1059", reason = "World map layers: a continent's name lies under the 'You' tag on the pin layer" },
	{ kind = "straddle", key = "^Trips%.lua:342.- straddles Wrapped%.lua:183", reason = "Trips: the 'Scroll for your trips' cue floats over the bottom edge on purpose (Trips.lua:329-338, mouse off)" },
	{ kind = "boxes", key = "^Trips%.lua:335", detail = "half over Wrapped%.lua:183", reason = "Trips: the 'Scroll for your trips' cue floats over the bottom edge on purpose (Trips.lua:329-338, mouse off)" },
	{ kind = "boxes", key = "^Trips%.lua:335", detail = "half over Trips%.lua:286", reason = "Trips: the 'Scroll for your trips' cue floats over the tray at the bottom edge on purpose (Trips.lua:329-338, mouse off)" },
	{ kind = "windows", key = " over WuberBug$", reason = "the /wuber bug window is a window of its own; the phone's or the button's top layers lie over it (the other order of an allowed pair)" },
	-- F033: the splash screen (Phone.lua:51-69) covers the whole window on purpose while it plays
	{ kind = "chrome", key = "^Phone%.lua:%d+ Frame", what = "Summons, on demand", reason = "the splash screen covers the whole window on purpose while it plays (Phone.lua:51-69)" },
	-- F037-F042, F049: Finding your driver (Confirm.lua:698 radar) shares Fold.Page() == "confirm", so allow.lua's ^finding rules do not match in the hunt
	{ kind = "boxes", screen = "^confirm", key = "^Confirm%.lua:%d+%(Widgets%.lua%) Frame over Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the rider level chip sits at the top right corner of the radar's square holder on purpose (allow.lua:27)" },
	{ kind = "boxes", screen = "^confirm", key = "^Window%.lua:%d+%(Widgets%.lua%) Button over Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the window's round buttons lie over the top right corner of the radar's square holder on purpose (allow.lua:37)" },
	{ kind = "boxes", screen = "^confirm", key = "^Phone%.lua:%d+ Button over Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the window's fold button lies over the top right corner of the radar's square holder on purpose (allow.lua:37)" },
	{ kind = "chrome", screen = "^confirm", key = "^Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the radar's square holder lies under the header's corner on purpose (allow.lua:38)" },
}

-- Rounding of what the layout engine scanned. tests/layout/engine.lua drops a box that lies whole under another only with a slop
-- of 0 (engine.lua:473), so float noise in the last bits (a cover frame and the page under it equal to 10 decimals, "inside" false)
-- leaves the covered page in the list and every row of the sheet over it is "half over" it. The engine is not ours to edit: every
-- rectangle it scanned is snapped to 0.01 of a unit (a hundredth of a pixel) before it judges, so edges equal to within noise are
-- equal. Nothing the player could see is a hundredth of a unit.
local scan0 = E.scan
local function snap(r)
	if r then
		r.l, r.b, r.r, r.t = math.floor(r.l * 100 + 0.5) / 100, math.floor(r.b * 100 + 0.5) / 100, math.floor(r.r * 100 + 0.5) / 100, math.floor(r.t * 100 + 0.5) / 100
	end
end
function E.scan(c)
	local sc = scan0(c)
	if os.getenv("HUNT_NOSNAP") then return sc end -- (to see what the rounding changes)
	snap(sc.screen)
	for _, t in ipairs(sc.texts) do snap(t.rect) snap(t.ink) snap(t.clip) end
	for _, b in ipairs(sc.boxes) do snap(b.rect) snap(b.clip) end
	for _, k in ipairs(sc.controls) do snap(k.rect) snap(k.clip) end
	return sc
end

-- the files of the pages (Wuber/UI/Rider, Wuber/UI/Driver; read from the TOC once): what Settings, an opaque panel over the whole window, hides
local pageFiles
function U.pageOwned(name)
	if not pageFiles then
		pageFiles = {}
		local f = io.open(tostring(H.ADDONS.Wuber) .. "/Wuber.toc", "r")
		if f then
			for line in f:lines() do
				local base = line:match("^UI[\\/]Rider[\\/]([%w_]+%.lua)") or line:match("^UI[\\/]Driver[\\/]([%w_]+%.lua)")
				if base then pageFiles[base] = true end
			end
			f:close()
		end
	end
	local base = tostring(name):match("^([%w_]+%.lua):")
	return base ~= nil and pageFiles[base] == true
end

function U.allowed(shot, h)
	for _, list in ipairs({ U.ALLOW, U.HUNT_ALLOW }) do
	for _, a in ipairs(list) do
		if (not a.kind or a.kind == h.kind) and (not a.screen or shot:find(a.screen)) and (not a.key or h.key:find(a.key))
			and (not a.what or h.what:find(a.what)) and (not a.detail or h.detail:find(a.detail)) then
			return a.known or a.reason or "allowed"
		end
	end
	end
	return nil
end

-- the two sides of an overlap-type hit by the engine's key: upper, lower (names as E.nameOf gives them), or nil
function U.sides(h)
	local k = tostring(h.key or "")
	local a, b = k:match("^(.-) over (.+)$")
	if a then return a, b end
	a, b = k:match("^(.-) under (.+)$") -- a text under a box: the box is the upper one
	if a then return b, a end
	a, b = k:match("^(.-) straddles (.+)$") -- the text is drawn over the box's edge
	if a then return a, b end
	a, b = k:match("^(.-) x (.+)$")
	if a then return a, b end
	return nil
end

-- the files of Wuber/FX (read from the TOC once): effects that play over the window for a moment
local fxFiles
function U.fxOwned(name)
	if not fxFiles then
		fxFiles = {}
		local f = io.open(tostring(H.ADDONS.Wuber) .. "/Wuber.toc", "r")
		if f then
			for line in f:lines() do
				local base = line:match("^FX[\\/]([%w_]+%.lua)")
				if base then fxFiles[#fxFiles + 1] = base end
			end
			f:close()
		end
	end
	for _, base in ipairs(fxFiles) do
		if name:find("^" .. base:gsub("%p", "%%%0") .. ":") or name:find("(" .. base .. ")", 1, true) then return true end
	end
	-- toasts and the bird card are the same kind of thing: a card that shows over the window for a few seconds (the bird card
	-- fades in 0.2 s, stays 6 s, fades out: UI/Bird.lua header)
	return name:find("^Toasts%.lua:") ~= nil or name:find("^Bird%.lua:") ~= nil
end

-- the first-open coach card and the tip card with their ring (UI/Coach.lua, UI/Tips.lua): meant to lie over what they explain
function U.coachOwned(name)
	return name:find("^Coach%.lua:") ~= nil or name:find("^Tips%.lua:") ~= nil or name:find("^WuberTipCard") ~= nil
end

---------------------------------------------------------------------------
-- Watching a world
---------------------------------------------------------------------------

-- the human-reaching kinds of the Wuber addon message (see tests/promises/universal.lua, promise no_unclicked_send)
local function watchClient(w, c)
	if c.huntWatched then return c end
	c.huntWatched = true
	local name = c.player.name
	for _, m in ipairs({ "click", "clickOn", "clickText", "type", "pressEscape", "slash", "drag", "pressKey", "enter" }) do
		local orig = c[m]
		if type(orig) == "function" then
			c[m] = function(self, ...)
				w.huntU.lastHW[name] = w.time
				w.huntU.hwCount[name] = (w.huntU.hwCount[name] or 0) + 1
				if m == "type" then
					local _, text = ...
					if type(text) == "string" and #text >= 2 then w.huntU.typed[#w.huntU.typed + 1] = text end
				end
				return orig(self, ...)
			end
		end
	end
	-- a boss fight holds the sender's messages; the ones a click queued leave when it ends, maybe over 60 s after the click
	-- (Net/Transport.lua). Remember when it began and ended and his last click by then, so that a send is judged by the click that queued it.
	-- Call through to the class's CURRENT fire at each event, not the one found now: a test that patches the class's fire
	-- later (the rec tests listen that way) must still see the events of a client built before.
	local ownFire = rawget(c, "fire")
	local function classFire()
		local mt = getmetatable(c)
		local idx = mt and mt.__index
		return type(idx) == "table" and idx.fire or nil
	end
	if type(c.fire) == "function" then
		c.fire = function(self, event, ...)
			local hu = w.huntU
			if event == "ENCOUNTER_START" then
				hu.fight[name] = { start = w.time }
			elseif event == "ENCOUNTER_END" and hu.fight[name] then
				hu.fight[name].stop = w.time
				hu.fight[name].hw = hu.lastHW[name]
			end
			return (ownFire or classFire() or error("no fire"))(self, event, ...)
		end
	end
	return c
end

local function watchWorld(w)
	if w.huntU then return w end
	w.huntU = { sends = {}, lastHW = {}, fight = {}, hwCount = {}, cursor = 0, steps = {}, typed = {} }
	local function hwOf(from)
		local c = w.hardware
		return c ~= nil and c.player ~= nil and c.player.name == from
	end
	-- e.stage: the core's stage when it was sent ("pre", "world", "login", "apply" = a dial is building the situation and
	-- acts for the player; "built" / "check" = judged). The send promise judges only the last two.
	local function note(e)
		local cur = U.Hunt and U.Hunt.current
		e.stage = (cur and cur.w == w) and cur.stage or nil
		-- what authorised the send is judged at SEND time (a check may advance the clock past 60 s or end the ride afterwards):
		-- the sender's last hardware event, whether a ride was under way, whether he was an online driver
		e.hwAt = w.huntU.lastHW[e.from]
		local f = w.huntU.fight[e.from]
		if f and f.stop then e.fight = { start = f.start, stop = f.stop, hw = f.hw } end
		local c = w.clientOf and w:clientOf(e.from)
		if c and c.W then
			local okr, a = pcall(function() return c.W.RideActive() end)
			e.rideOn = okr and a and true or false
			local okd, d = pcall(function() return c.W.Char().drive == true end)
			e.driveOn = okd and d and true or false
		end
		w.huntU.sends[#w.huntU.sends + 1] = e
	end
	local sendAddon = w.sendAddon
	w.sendAddon = function(self, client, prefix, text, chatType, target)
		local n = #self.addonLog
		local r = sendAddon(self, client, prefix, text, chatType, target)
		local e = self.addonLog[#self.addonLog]
		if #self.addonLog > n and e then
			note({ via = "addon", from = client.player.name, prefix = prefix, kind = prefix == "WUBER" and tostring(text):match("^([^~]*)") or nil,
				text = text, chat = chatType, target = target, at = self.time, hw = hwOf(client.player.name), ok = e.result == 0 })
		end
		return r
	end
	local whisper = w.whisper
	w.whisper = function(self, client, target, text, how)
		local n = #self.whispers
		local r = whisper(self, client, target, text, how)
		local e = { via = "whisper", from = client.player.name, to = target, text = text, how = how, at = self.time, hw = hwOf(client.player.name), ok = #self.whispers > n }
		if how == "auto" then
			-- one of Wuber's three self-sent lines (Drive/AutoLines.lua: the greeting, the pay reminder, "You're next"): judged at SEND time.
			-- Allowed only when that line's own switch is on and the receiver is a rider on this driver's list who asked (the app or a whisper)
			local okc, why = pcall(function()
				local DR, row = client.W.Drive, nil
				for _, x in pairs(DR.customers or {}) do
					if type(x) == "table" and type(x.name) == "string" and self:player(x.name) == self:player(target) then row = x break end
				end
				if not row then return "the receiver is not on the driver's list" end
				if row.source ~= "wuber" and row.source ~= "whisper" then return "the receiver did not ask this driver for a ride (" .. tostring(row.source) .. ")" end
				local kinds = { "greet", "pay", "next" }
				local words, on = nil, false
				for _, k in ipairs(kinds) do
					local okt, t = pcall(DR.Text, k, row)
					if okt and t == text then words = k on = DR.LineOn(k) end
				end
				if not words then
					for _, k in ipairs(kinds) do if DR.LineOn(k) then on = true end end
					if not on then return "no line's own switch is on" end
					return nil
				end
				if not on then return 'the switch of the "' .. words .. '" line is off' end
				return nil
			end)
			if okc then e.autoWhy = why else e.autoWhy = "could not check the line's switch (" .. tostring(why) .. ")" end
		end
		note(e)
		return r
	end
	local publicLine = w.publicLine
	w.publicLine = function(self, fromName, faction, text, kind, cname, how, fromClient)
		note({ via = "chat", from = fromName, kind = kind, channel = cname, text = text, how = how, at = self.time, hw = hwOf(fromName), ok = true })
		return publicLine(self, fromName, faction, text, kind, cname, how, fromClient)
	end
	local groupLine = w.groupLine
	w.groupLine = function(self, fromName, text, kind, how)
		note({ via = "chat", from = fromName, kind = kind, text = text, how = how, at = self.time, hw = hwOf(fromName), ok = true })
		return groupLine(self, fromName, text, kind, how)
	end
	local addClient = w.addClient
	w.addClient = function(self, name, opts)
		if U.TL then
			-- pixels per UI unit of this window (the game window's physical height over the UI's)
			local physH = (opts and opts.physH) or 2160
			local unitH = (opts and opts.screenH) or 1080
			U.TL.PX = physH / unitH
		end
		return watchClient(w, addClient(self, name, opts))
	end
	for _, c in ipairs(w.clients or {}) do watchClient(w, c) end
	return w
end
U.watchWorld = watchWorld

-- (fonts) the layout check measures text with the shipped fonts' real metrics (tools/preview/textlayout.lua) instead of
-- the harness's rough rule, which cuts or fits words wrongly: set HUNT_REAL_FONTS=0 to go without. TL.PX = pixels per UI unit.
local okTL, TL = pcall(dofile, "tools/preview/textlayout.lua")
if okTL and type(TL) == "table" and os.getenv("HUNT_REAL_FONTS") ~= "0" then
	U.TL = TL
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	local width, layout = TL.width, TL.layout
	local wc, lc = {}, {}
	function TL.width(path, size, text, scale)
		local k = tostring(path) .. "\1" .. tostring(size) .. "\1" .. tostring(scale) .. "\1" .. tostring(text)
		local v = wc[k]
		if v == nil then v = width(path, size, text, scale) wc[k] = v end
		return v
	end
	function TL.layout(path, size, text, o)
		o = o or {}
		local k = table.concat({ tostring(path), tostring(size), tostring(text), tostring(o.width), tostring(o.height), tostring(o.wrap),
			tostring(o.maxLines), tostring(o.spacing), tostring(o.scale) }, "\1")
		local v = lc[k]
		if v == nil then v = layout(path, size, text, o) lc[k] = v end
		return v
	end
	-- Hunt.build sets H.textMetrics = U.TL for each Hunt world and release() restores it,
	-- so loading this file once never leaks or drops real fonts across tests/shards.
end

local tagOff
function U.install()
	local want = H.ADDONS.Wuber
	if U.tagged ~= want then
		if tagOff then tagOff() end
		tagOff = E.tag({ Wuber = want, WuberLab = H.ADDONS.WuberLab })
		U.tagged = want
		-- when the Wuber window (WuberFrame) last moved, was shown, hidden or resized: huntMovedAt on its state (world clock). The big
		-- button and its console re-place within about 0.5 s of it (Drive/Button.lua watch), so the layout check does not judge them
		-- over the window in that moment. (E.tag's own restore puts the real newWidget back, so a re-install wraps again.)
		local tagged = H.newWidget
		H.newWidget = function(client, otype, name, parent, kind)
			local obj = tagged(client, otype, name, parent, kind)
			if name == "WuberFrame" then
				for _, m in ipairs({ "SetPoint", "SetAllPoints", "ClearAllPoints", "SetScale", "SetSize", "SetWidth", "SetHeight", "Show", "Hide" }) do
					local orig = obj[m]
					if type(orig) == "function" then
						obj[m] = function(self, ...)
							local w = client.world
							if w then S[obj].huntMovedAt = w.time end
							return orig(self, ...)
						end
					end
				end
			end
			return obj
		end
	end
	if not U.wrapped then
		U.wrapped = true
		local NewWorld = H.NewWorld
		H.NewWorld = function(...)
			U.install() -- the tagger is (re)installed before this world creates a client
			return watchWorld(NewWorld(...))
		end
	end
end
U.install()

-- the player's click, for a check that stands in for one by calling the addon's function: runs fn inside a hardware event of
-- ctx.me (w.hardware, as Client:click does) and records it as his last click, so a message the click queued and the outbox
-- sends a few seconds later still counts as sent after a click. Returns what fn returns.
function U.asClick(ctx, fn)
	local w = ctx.w
	if w.huntU then w.huntU.lastHW[ctx.name] = w.time end
	w.hardware = ctx.me
	local res = { pcall(fn) }
	w.hardware = nil
	if not res[1] then error(res[2], 0) end
	return unpack(res, 2)
end

-- a world the core made before this file loaded, or one made some other way
function U.world(ctx) return watchWorld(ctx.w) end

---------------------------------------------------------------------------
-- Readers
---------------------------------------------------------------------------

function U.plain(t)
	return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"))
end

-- is this widget one of Wuber's (the tagger saw Wuber code make it)
function U.isWuber(obj) return E.tagOf(obj) == "Wuber" end

-- the visible Wuber widgets of a client with this Lua type ("Button", "CheckButton", "EditBox", "FontString", "Slider")
function U.shown(c, otypes)
	local out = {}
	local set = {}
	for _, t in ipairs(otypes) do set[t] = true end
	for _, obj in ipairs(c.widgets) do
		local s = S[obj]
		if set[s.otype] and s.shown and U.isWuber(obj) and H.visible(obj) then out[#out + 1] = obj end
	end
	return out
end

-- the visible text a button shows: its own text, or its visible font strings' text, top to bottom, or ""
function U.labelOf(b)
	local s = S[b]
	if type(s.text) == "string" and s.text ~= "" then return U.plain(s.text) end
	local parts = {}
	local function walk(o, depth)
		local os_ = S[o]
		for _, ch in ipairs(os_.children or {}) do
			local cs = S[ch]
			if cs.otype == "FontString" and type(cs.text) == "string" and cs.text:match("%S") and cs.shown then parts[#parts + 1] = U.plain(cs.text)
			elseif depth < 3 and cs.shown ~= false and (cs.kind == "frame") and cs.otype ~= "Button" then walk(ch, depth + 1) end
		end
	end
	walk(b, 0)
	return table.concat(parts, " ")
end

-- a tip title for a button (a string or a function(frame)), or nil. The frame's own, else an ancestor's
function U.tipOf(b)
	local o, n = b, 0
	while o and n < 4 do
		local t = o.wuberTip
		if t then
			local title = t.title
			if type(title) == "function" then local ok, v = pcall(title, o) title = ok and v or nil end
			if type(title) == "string" and title ~= "" then return title end
		end
		o = S[o].parent
		n = n + 1
	end
	return nil
end

-- a name for a control in a failure line: its words, else its tip, else where the code made it
function U.nameOf(b)
	local l = U.labelOf(b)
	if l ~= "" then return '"' .. l:sub(1, 40) .. '"' end
	local t = U.tipOf(b)
	if t then return 'the button "' .. t:sub(1, 40) .. '"' end
	return "a button (" .. E.nameOf(b) .. ")"
end

-- the screen the player is on, in words: "Trips", "Settings", "Ride", "Drive: console", or "the phone"
function U.screen(ctx)
	local W = ctx.W
	local parts = {}
	local ok, page = pcall(function() return W.UI and W.UI.Fold and W.UI.Fold.Page() end)
	if ok and page then parts[#parts + 1] = tostring(page) end
	local ok2, shown = pcall(function() return W.UI and W.UI.IsShown() end)
	if not (ok2 and shown) then parts[#parts + 1] = "(phone closed)" end
	local fold = false
	pcall(function() fold = W.UI.Fold.IsUnfolded() end)
	return (#parts > 0 and table.concat(parts, " ") or "phone"), fold and "unfolded" or "folded"
end

---------------------------------------------------------------------------
-- Money
---------------------------------------------------------------------------

-- every money string in a text: { { text = "5g 25s", copper = 52500, canonical = bool } }. A money string is
-- one to three of <n>g <n>s <n>c in that order, separated by single spaces, and not part of a longer word or number.
function U.moneyIn(text)
	local out = {}
	local t = U.plain(text)
	local pos = 1
	while pos <= #t do
		local s1, e1, a = t:find("(%d+)([gsc])%f[%A]", pos)
		if not s1 then break end
		local ok = s1 == 1 or not t:sub(s1 - 1, s1 - 1):match("[%w%.]")
		if not ok then pos = e1 + 1
		else
			local units, cur, last = { { a, t:sub(e1, e1)} }, e1, nil
			-- more parts
			while true do
				local s2, e2, n2, u2 = t:find("^ (%d+)([gsc])%f[%A]", cur + 1)
				if not s2 then break end
				units[#units + 1] = { n2, u2 }
				cur = e2
			end
			local g, s_, c_ = 0, 0, 0
			local order, canon, prev = { g = 1, s = 2, c = 3 }, true, 0
			local seen = {}
			for _, u in ipairs(units) do
				local n, k = tonumber(u[1]), u[2]
				if seen[k] or order[k] < prev then canon = false end
				seen[k], prev = true, order[k]
				if k == "g" then g = n elseif k == "s" then s_ = n if n > 99 then canon = false end else c_ = n if n > 99 then canon = false end end
				if u[1]:match("^0%d") or (n == 0 and not (#units == 1 and k == "g")) then canon = false end -- "0g" alone is how Wuber writes nothing
			end
			local nextc = t:sub(cur + 1, cur + 1)
			if nextc:match("[%w]") then pos = cur + 1 -- "5gold", "10sec": not money
			else
				out[#out + 1] = { text = t:sub(s1, cur), copper = g * 10000 + s_ * 100 + c_, canonical = canon }
				pos = cur + 1
			end
		end
	end
	return out
end

-- every number written in a text (digits, with an optional minus and a decimal point), for the NaN / negative check
function U.hasBadNumber(text)
	local t = U.plain(text):lower()
	if t:find("%f[%w]nan%f[%W]") or t:find("%f[%w]%-?inf%f[%W]") or t:find("%f[%w]inf%f[%W]") then return "not a number" end
	return nil
end

return U
