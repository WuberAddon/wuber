-- tests/promises/universal.lua: the universal promises of Wuber (the bug hunt). Owner: UNIVERSAL.
-- Each is one plain sentence and a check. "always" checks only look and run after every build and every step of a long
-- session (kept cheap: about 30 ms; the expensive ones, layout and the saved-data round trip, run on the first call and then
-- every Nth: U.EVERY, set with the environment variable HUNT_EVERY, default 5; HUNT_EVERY=1 checks every step, a sweep
-- that wants speed can set 20). "scenario" checks act (click, wait, reload) and get a fresh build.
--
-- RULE for sends (promise universal.no_unclicked_send), learned from the docs (the CurseForge page, CHANGELOGs, Help texts, SPEC*):
--   Background, no click needed ("hidden addon messages between addons, never shown in anyone's chat"): the beacon D, the
--   offline notice X, the discovery ping Q, driver-name gossip K, shared flight prices F, "booked elsewhere" B and any
--   kind added by W.NetKind (G, V, W: bounty and the like). They only fill lists; no human sees them.
--   Reaches a human, needs the player's own click (or a session that click started): the ride request R, the cancel C,
--   the rating T, and a driver's answers A, N, S, P (their engine takes riders by itself once the driver pressed Open).
--   A human-reaching addon message is accepted when a hardware event of that player happened within 60 s, or a ride is
--   under way (W.ride active: the click that asked started it; R is sent again after 8 s), or the player is a driver who
--   is online (the Open click started it). Whispers, chat lines, invites, macros are never background: they must happen
--   INSIDE a hardware event of that player (the harness's w.hardware), and SendChatMessage from the addon is never fine.
--
-- EXEMPTIONS in the reload promise (each has its reason, below): the clock, the "TIP n OF m" card, fade-ins that were
-- playing, texts with a running count-down.
return function(Hunt)
local U = dofile("tests/hunt/lib/universal_util.lua")
local H, S, E = U.H, U.S, U.E
U.Hunt = Hunt
U.EVERY = tonumber(os.getenv("HUNT_EVERY") or "") or 5

-- HUNT_SKIP=id,id: promises muted for this run (a walk stops at its first failure: mute a known finding to look for others)
local SKIP = {}
for id in (os.getenv("HUNT_SKIP") or ""):gmatch("[^,%s]+") do SKIP[id] = true end
local function P(t)
	t.area = t.area or "Universal"
	t.source = t.source or "inferred"
	if SKIP[t.id] then
		local check = t.check
		t.check = function(ctx) end
	end
	Hunt.promise(t)
end

local function first(list, n) local out = {} for i = 1, math.min(n or 3, #list) do out[i] = list[i] end return out end

-- every Nth call per world (the first always)
local function everyNth(ctx, key)
	local w = U.world(ctx)
	local n = (w.huntU.steps[key] or 0) + 1
	w.huntU.steps[key] = n
	return n == 1 or n % U.EVERY == 0
end

-- all Wuber's visible text, top to bottom, plus an open tooltip of a Wuber widget: { { text, obj } }
local function wuberTexts(c)
	local out = {}
	for _, obj in ipairs(U.shown(c, { "FontString" })) do
		local s = S[obj]
		if type(s.text) == "string" and s.text:match("%S") then out[#out + 1] = { text = U.plain(s.text), obj = obj } end
	end
	for _, obj in ipairs(U.shown(c, { "EditBox" })) do
		local s = S[obj]
		if type(s.text) == "string" and s.text:match("%S") then out[#out + 1] = { text = U.plain(s.text), obj = obj, edit = true } end
	end
	local gt = c.env.GameTooltip
	if gt and S[gt].shown then
		local owner = gt:GetOwner()
		if owner and U.isWuber(owner) then
			for i = 1, 8 do
				local fs = c.env["GameTooltipTextLeft" .. i]
				if fs and S[fs].text and S[fs].text:match("%S") then out[#out + 1] = { text = U.plain(S[fs].text), obj = fs, tip = true } end
			end
		end
	end
	return out
end
U.wuberTexts = wuberTexts

local function liveClients(w)
	local out = {}
	for _, c in ipairs(w.clients) do if c.alive and c.W then out[#out + 1] = c end end
	return out
end

local function say(ctx, fmt, ...) ctx:fail(fmt:format(...)) end

---------------------------------------------------------------------------
-- 1. No Lua error
---------------------------------------------------------------------------
P{ id = "universal.no_lua_error", kind = "always", text = "Wuber never raises a Lua error, and never hides one.",
	source = "tests/run.lua clean()",
	check = function(ctx)
		local w = ctx.w
		-- the hunt's own stop (tests/hunt/lib.lua: "the hunt stopped it: over N s" / "the run's time is up") can fire inside addon code and
		-- be recorded as an error: it is the hunt's, never Wuber's. Counted apart, in a note.
		local function huntStop(e) return tostring(e):find("the hunt stopped it:", 1, true) ~= nil end
		local own, mine = 0, {}
		for _, e in ipairs(w.errors) do if huntStop(e) then own = own + 1 else mine[#mine + 1] = e end end
		if #mine > 0 then
			say(ctx, "Wuber raised a Lua error (%d so far): %s", #mine, tostring(mine[1]):match("^[^\n]*"))
		end
		for _, c in ipairs(liveClients(w)) do
			if c.W.lastError ~= nil then
				if huntStop(c.W.lastError) then own = own + 1
				else say(ctx, "Wuber caught and hid a Lua error on %s: %s", c.player.name, tostring(c.W.lastError):match("^[^\n]*")) end
			end
		end
		if own > 0 then ctx:note(("%d error(s) were the hunt's own time stop, not counted as Wuber errors"):format(own)) end
		for path, kind in pairs(w.missingFiles) do
			say(ctx, "Wuber uses a %s file that is not there: %s", kind, tostring(path))
		end
	end }

---------------------------------------------------------------------------
-- 1b. The rules the game enforces (violations, throttle, 255 bytes)
---------------------------------------------------------------------------
P{ id = "universal.game_rules", kind = "always", text = "Wuber keeps the game's rules: no rule-breaking call, no message the game throttles or refuses, no addon message over 255 bytes.",
	source = "tests/run.lua clean()",
	check = function(ctx)
		local w = ctx.w
		local wu = U.world(ctx).huntU
		-- forbidden calls are the next promise
		for _, v in ipairs(w.violations) do
			if not tostring(v):find(H.FORBID_MARK, 1, true) then
				say(ctx, "Wuber broke a game rule: %s", tostring(v):sub(1, 200))
			end
		end
		for _, c in ipairs(liveClients(w)) do
			if (c.throttled or 0) > 0 then
				say(ctx, "The game throttled %d of the addon messages %s sent (Wuber sent too many too fast).", c.throttled, c.player.name)
			end
		end
		for _, e in ipairs(w.addonLog) do
			if #e.text > 255 then say(ctx, "Wuber sent an addon message of %d bytes (the limit is 255).", #e.text) end
		end
	end }

---------------------------------------------------------------------------
-- 6. Forbidden calls
---------------------------------------------------------------------------
P{ id = "universal.no_forbidden", kind = "always", text = "Wuber never calls anything this game client forbids (tools/forbidden.lua).",
	source = "CLAUDE.md hard rules; tests/run.lua runOne",
	check = function(ctx)
		local left = H.forbiddenLeft()
		-- forbiddenLeft covers every world since the last release: only this world's lines count here
		local mine = {}
		for _, v in ipairs(ctx.w.violations) do if tostring(v):find(H.FORBID_MARK, 1, true) then mine[#mine + 1] = tostring(v) end end
		if #mine > 0 then
			say(ctx, "Wuber called something this game forbids: %s", mine[1]:gsub(H.FORBID_MARK:gsub("%p", "%%%0"), ""):sub(1, 200))
		end
	end }

---------------------------------------------------------------------------
-- 8a. Combat: nothing protected changes, the phone does not open by itself
---------------------------------------------------------------------------
P{ id = "universal.no_blocked_action", kind = "always", text = "In combat Wuber never tries to show, hide, move or change a protected frame (the game would block it).",
	source = "CLAUDE.md: secure frames are never changed in combat",
	check = function(ctx)
		local w = U.world(ctx)
		for _, c in ipairs(liveClients(w)) do
			if not c.huntFireWrapped then
				c.huntFireWrapped = true
				local fire = c.fire
				c.fire = function(self, event, ...)
					if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
						local a = ...
						w.huntU.blocked = w.huntU.blocked or {}
						w.huntU.blocked[#w.huntU.blocked + 1] = { who = self.player.name, addon = tostring(a), what = tostring(select(2, ...)) }
					end
					return fire(self, event, ...)
				end
			end
		end
		local b = w.huntU.blocked
		if b and #b > 0 then
			local x = b[1]
			if x.addon:find("Wuber", 1, true) or x.addon == "nil" then
				say(ctx, "The game blocked Wuber (%s) from %s: Wuber changed a protected thing it must not touch.", x.who, x.what)
			end
		end
		for _, v in ipairs(w.violations) do
			if tostring(v):find("protected", 1, true) or tostring(v):find("combat", 1, true) then
				say(ctx, "Wuber broke the combat rules: %s", tostring(v):sub(1, 200))
			end
		end
	end }

P{ id = "universal.phone_stays_shut_in_combat", kind = "scenario", text = "The phone never opens by itself while you are in combat.",
	source = "inferred (CLAUDE.md: secure frames are never shown in combat; the phone holds them)",
	needs = { phone = "closed" },
	check = function(ctx)
		local W, w, me = ctx.W, ctx.w, ctx.me
		if W.UI.IsShown() then ctx:na("the phone is already open") end
		w:enterCombat(me)
		ctx:advance(60)
		local ev = { "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PARTY_INVITE_REQUEST", "ZONE_CHANGED_NEW_AREA" }
		for _, e in ipairs(ev) do pcall(me.fire, me, e) end
		ctx:advance(30)
		if ctx.W.UI.IsShown() then
			say(ctx, "You are in combat with Wuber closed and the phone opens by itself.")
		end
		w:leaveCombat(me)
	end }

---------------------------------------------------------------------------
-- 2. Layout
---------------------------------------------------------------------------
-- which page and tab are up: when this changes the old page cross-fades out for about 0.2 s over the new one (Window.lua
-- A.FadeIn): overlaps in that moment are the animation, not a layout bug, so they are judged only once the page has rested 1 s.
local function pageSig(ctx)
	local W = ctx.W
	local parts = {}
	pcall(function() parts[#parts + 1] = tostring(W.UI.Fold.Page()) end)
	pcall(function() parts[#parts + 1] = tostring(W.UI.IsShown()) end)
	for _, n in ipairs({ "Ride", "Trips", "Drive" }) do
		pcall(function() local b = W.UI.GetTab(n) parts[#parts + 1] = (b and b:IsShown()) and "1" or "0" end)
	end
	return table.concat(parts, ",")
end
local CROSSFADE = { emptycue = true, boxes = true, under = true, windows = true, overlap = true, straddle = true }

local function layoutCheck(ctx, force)
		local c = ctx.me
		if not (c and c.alive) then return end
		-- the splash ("Summons, on demand") covers the whole window for 1.2 s after the phone opens (Phone.lua:88-100, ends by itself): the
		-- page under it is not judged while it is up. It is still up while it fades out: EndSplash clears splashing at the START of the
		-- 0.4 s fade (Phone.lua:72-82), and the fade hides the frame at its end (A.FadeOut), so "shown" covers the fade and no longer.
		local kitUI
		pcall(function() kitUI = ctx:mod("UI.Kit").ui end)
		if kitUI and (kitUI.splashing or (kitUI.splash and kitUI.splash:IsShown())) then return end
		local wu = U.world(ctx).huntU
		local sig = pageSig(ctx)
		if wu.sig ~= sig then wu.sig, wu.sigAt = sig, (wu.sig == nil) and (ctx.w.time - 100) or ctx.w.time end
		local settling = ctx.w.time - wu.sigAt < 1.0
		-- a click in the last second (the last step of a scenario check, or of a walk) may have started a page change that this
		-- check is the first to see: the old page is still fading out
		local hw = wu.lastHW[ctx.name]
		if hw and ctx.w.time - hw < 1.0 then settling = true end
		if not force and not everyNth(ctx, "layout") then return end
		local screen, fold = U.screen(ctx)
		if screen:find("closed", 1, true) and #U.shown(c, { "FontString" }) == 0 then return end
		local ok, hits = pcall(E.check, c, { TL = U.TL })
		if not ok then error("layout checker threw: " .. tostring(hits), 0) end -- a BROKEN check, never a bug
		local shot = screen:gsub("%s*%(phone closed%)", "") .. "/" .. fold
		-- overlaps that are meant: (1) the coach card / tip card lie over what they explain; (2) an effect or toast (Wuber/FX,
		-- Toasts) plays over the window for a moment: only an overlap that is still there 3 s after it was first seen counts.
		-- A check never advances time, so "first seen" is the world's clock at an earlier check (a walk, or a scenario then the
		-- always run). The card or effect ITSELF cut off or off screen (kinds cut, offscreen, spill, clipped) is always judged.
		local OVERLAP = { boxes = true, under = true, overlap = true, straddle = true, windows = true }
		local now, seenFx, live = ctx.w.time, wu.fxSeen or {}, {}
		wu.fxSeen = seenFx
		local wheelViews
		for _, h in ipairs(hits) do
			local skip = false
			-- a row cut at the edge of a view the player can scroll with the wheel is a scrolled list (the same reason as the Settings
			-- entry in tests/layout/allow.lua): what is cut scrolls into view. A cut by a view that does not scroll is still reported.
			if h.kind == "clipped" and not U.allowed(shot, h) then
				local view, side = tostring(h.detail):match("cut by its view (.-) %((%a+) by")
				if view and (side == "top" or side == "bottom") then
					if not wheelViews then
						wheelViews = {}
						for _, o in ipairs(c.widgets) do
							local sc = S[o].scripts
							if sc and sc.OnMouseWheel and U.isWuber(o) then wheelViews[E.nameOf(o)] = true end
						end
					end
					if wheelViews[view] then skip = true end
				end
			end
			if OVERLAP[h.kind] and not U.allowed(shot, h) then
				local a, b = U.sides(h)
				if a and b then
					if U.coachOwned(a) ~= U.coachOwned(b) then skip = true
					elseif U.fxOwned(a) or U.fxOwned(b) then
						local key = h.kind .. "|" .. tostring(h.key)
						live[key] = true
						local t0 = seenFx[key]
						if t0 == nil then seenFx[key] = now t0 = now end
						if now - t0 < 3 then skip = true end
					end
				end
			end
			h.skip = skip
		end
		for key in pairs(seenFx) do if not live[key] then seenFx[key] = nil end end
		-- (1) the clamp gap. The real game keeps a window with SetClampedToScreen(true) on the screen (Window.lua:415, the clamp rect
		-- Phone.lua:234 keeps the whole handset on it); the fake game only stores the flag and never moves the frame, so a phone saved
		-- far off the screen (pos=offscreen) or an island 2 to 6 px over the top edge shows as "off screen" here and cannot in the game.
		-- THIS IS A GAP IN THE FAKE GAME, NOT A PASS: only what lies inside a clamped frame is left out; anything else that is off the
		-- screen is still reported.
		local names
		for _, h in ipairs(hits) do
			if h.kind == "offscreen" and not h.skip then
				local name = tostring(h.key):match("^(.-) off screen$")
				if name then
					if not names then
						names = {}
						for _, o in ipairs(c.widgets) do
							if S[o] and S[o].shown and U.isWuber(o) then
								local nm = E.nameOf(o)
								local x, clamped = o, false
								-- (only the Wuber window, WuberFrame: that is the gap the judge proved. Other clamped frames, the Drive console
								-- (Mini.lua:168) for one, are not excused: its real overflow, repro 667d2d, must still be reported.)
								while x and S[x] do if S[x].clamped and S[x].name == "WuberFrame" then clamped = true break end x = S[x].parent end
								local e = names[nm]
								if e == nil then names[nm] = clamped else names[nm] = e and clamped end
							end
						end
					end
					if names[name] == true then h.skip = true end
				end
			end
		end
		-- (2) a toast slides in from above the screen for its first 0.3 s (Toasts.lua:405-410): not judged in its first 0.6 s
		local toastAge
		for _, h in ipairs(hits) do
			if not h.skip and tostring(h.key):find("Toasts%.lua:") then
				if toastAge == nil then
					toastAge = false
					for _, o in ipairs(c.widgets) do
						local so = S[o]
						if so and so.shown and so.lcSrc and so.lcSrc:find("^Toasts%.lua:") then
							local x = o
							while x and S[x] do
								local at = rawget(x, "at")
								if type(at) == "number" then
									local age = ctx.w.time - at
									if toastAge == false or age < toastAge then toastAge = age end
									break
								end
								x = S[x].parent
							end
						end
					end
				end
				if toastAge and toastAge < 0.6 then h.skip = true end
				-- a toast is transient: not judged over the big Drive button (or its mini) while it is shown
				if h.kind == "windows" and toastAge ~= nil and (tostring(h.key):find("WuberDriveButton", 1, true) or tostring(h.key):find("WuberDriveMini", 1, true)) then h.skip = true end
			end
		end
		-- (3) the big button and its console list: a secure frame is never moved in combat (CLAUDE.md), so a window opened or
		-- unfolded in combat lies over them until combat ends (Drive/Button.lua:604 re-places at PLAYER_REGEN_ENABLED); the combat
		-- dial never leaves combat. universal.layout_after_combat judges the re-place. And right after the window moved the watch
		-- has not re-placed them yet (about 0.5 s): not judged for 1 s.
		local inCombat = c.player and c.player.combat == true
		local wf = rawget(c.env, "WuberFrame")
		local movedAt = wf and S[wf] and S[wf].huntMovedAt
		local justMoved = movedAt and ctx.w.time - movedAt < 1.0
		for _, h in ipairs(hits) do
			if not h.skip and h.kind == "windows" then
				local k = tostring(h.key)
				if k:find("WuberDriveButton", 1, true) or k:find("WuberDriveMini", 1, true) then
					if inCombat or justMoved then h.skip = true end
				end
			end
		end
		-- (4) the phone over a nameplate badge is ordinary layering. The "? Frame" of the hit is a nameplate of the fake game (an unnamed,
		-- untagged UIParent frame) that holds a badge Wuber made (Wuber/FX/Nameplates.lua, FX/Emblem.lua): the phone over a badge at
		-- somebody's nameplate is the world under the window. Only when every such frame holds nothing but those badge widgets. The
		-- other order (a badge over the button's text) is still reported.
		local badge
		for _, h in ipairs(hits) do
			if not h.skip and h.kind == "windows" and tostring(h.key) == "WuberFrame over ? Frame" then
				if badge == nil then
					badge = false
					local any, other = false, false
					for _, o in ipairs(c.widgets) do
						local so = S[o]
						if so and so.shown and not so.lcTag and E.nameOf(o) == "? Frame" then
							local function walk(x, d)
								for _, k in ipairs(S[x].children or {}) do
									local sk = S[k]
									if sk.lcSrc then
										if sk.lcSrc:find("^Nameplates%.lua:") or sk.lcSrc:find("^Emblem%.lua:") then any = true else other = true end
									end
									if d < 4 then walk(k, d + 1) end
								end
							end
							walk(o, 0)
						end
					end
					badge = any and not other
				end
				if badge then h.skip = true end
			end
		end
		-- (5) while Settings is open its panel is opaque and covers the whole page: what lies on the page (Wuber/UI/Rider, Wuber/UI/Driver) is
		-- hidden, not seen, so a hit with a page object on either side is not judged; hits among the panel and the header stay judged
		if kitUI and kitUI.settingsOpen then
			for _, h in ipairs(hits) do
				if not h.skip and (h.kind == "chrome" or OVERLAP[h.kind] or h.kind == "emptycue") then
					local a, b = U.sides(h)
					if (a and U.pageOwned(a)) or (b and U.pageOwned(b)) or (not a and U.pageOwned(tostring(h.key or ""))) then h.skip = true end
				end
			end
		end
		if os.getenv("HUNT_LAYOUT_DEBUG") then
			for _, h in ipairs(hits) do
				io.stderr:write(("LAYOUT %s | %s | skip=%s allowed=%s settling=%s\n"):format(tostring(h.kind), tostring(h.key), tostring(h.skip), tostring(U.allowed(shot, h)), tostring(settling and CROSSFADE[h.kind])))
			end
		end
		for _, h in ipairs(hits) do
			if not h.skip and not U.allowed(shot, h) and not (settling and CROSSFADE[h.kind]) then
				local what = tostring(h.what or h.key):gsub("%s+", " ")
				-- the plain line says what is wrong and names the regions, never the screen: the same cause on another screen, fold or
				-- window size is the same finding. The screen, fold and the engine's detail go in the detail.
				local line
				local tag, rest = what:match("^(%S+) text (.+)$")
				if h.kind == "cut" and tag then
					line = ("The text %s is cut off (%s)."):format(rest, tag)
				elseif h.kind == "cut" then
					line = ("Text is cut off: %s."):format(what)
				else
					line = ("A layout problem (%s): %s."):format(tostring(h.kind), what)
				end
				ctx:fail(line, ("On the %s screen (%s): %s"):format(screen, fold, tostring(h.detail)))
			end
		end
end

P{ id = "universal.layout", kind = "always", text = "Nothing of Wuber is off the screen, cut off or on top of something else.",
	source = "tests/layout/engine.lua; allow-list tests/layout/allow.lua",
	check = function(ctx) layoutCheck(ctx, false) end }

-- The Drive button and its console never move in combat, so a window opened in combat lies over them until combat ends; then the
-- watch re-places them (Drive/Button.lua:604, about 0.5 s). The always-check leaves those hits out while you are in combat; this
-- one leaves combat the way the harness does, waits 2 s and judges the same layout: a real overlap shows here.
P{ id = "universal.layout_after_combat", kind = "scenario", text = "When a fight ends, the Drive button and its console are moved clear of the phone and nothing of Wuber is off the screen, cut off or on top of something else.",
	source = "Wuber/Drive/Button.lua:604 (re-placed at PLAYER_REGEN_ENABLED); CLAUDE.md (secure frames are never moved in combat)",
	when = function(sit) return sit.combat == "before" or sit.combat == "after" end,
	check = function(ctx)
		local me = ctx.me
		if not (me and me.alive) then ctx:na("no client") end
		if not me.player.combat then ctx:na("not in combat") end
		ctx.w:leaveCombat(me)
		ctx:advance(2)
		layoutCheck(ctx, true)
	end }

---------------------------------------------------------------------------
-- 3. Buttons: a tip, a label, and (scenario) something happens
---------------------------------------------------------------------------
local function wuberButtons(c)
	local out = {}
	-- while the Settings panel is open it is an opaque, mouse-enabled panel over the whole window: a control under it
	-- (a Home map pin) cannot be pointed at, so only buttons inside the panel count (judge: HUNT-103 stays, the Bell banner is not under it)
	local panel
	pcall(function()
		if c.W and c.W.UI and c.W.UI.SettingsShown and c.W.UI.SettingsShown() and c.W.UI.settings then panel = c.W.UI.settings.panel end
	end)
	for _, b in ipairs(U.shown(c, { "Button", "CheckButton" })) do
		local s = S[b]
		local under = false
		if panel and S[panel] then
			-- only what lives in the main window (WuberFrame) and not in the panel is covered; the Bell banner and its "1 alert"
			-- box hang off UIParent, are not covered, and stay reported (HUNT-103)
			local x, n, inWin = b, 0, false
			while x and S[x] and n < 60 do
				if x == panel then inWin = false break end
				if S[x].name == "WuberFrame" then inWin = true end
				x, n = S[x].parent, n + 1
			end
			under = inWin
		end
		-- a Home map pin lingers up to 1 s after its driver expired (a clock jump with no refresh): the player cannot reach it, and
		-- an always-check must not advance the clock. Skip a pin whose driver key is gone from W.drivers.
		local gone = false
		if s.lcSrc and s.lcSrc:find("^HomeMap%.lua:") then
			local key = rawget(b, "key")
			if key ~= nil and c.W and type(c.W.drivers) == "table" and c.W.drivers[key] == nil then gone = true end
		end
		if s.enabled ~= false and s.mouse ~= false and not under and not gone then out[#out + 1] = b end
	end
	return out
end
U.wuberButtons = wuberButtons

-- hover a control the way the player does and see whether the game tooltip shows (T.Tip hooks OnEnter; a secure overlay
-- forwards OnEnter to the pill under it, so the tip's owner may be that pill)
local function hoverShowsTip(c, b)
	local gt = c.env.GameTooltip
	local was = S[gt].shown
	if was then gt:Hide() end
	local s = S[b]
	local shown = false
	if s.scripts and s.scripts.OnEnter then
		pcall(H.runScript, b, "OnEnter")
		shown = S[gt].shown == true
		pcall(H.runScript, b, "OnLeave")
		gt:Hide()
	end
	return shown
end
U.hoverShowsTip = hoverShowsTip

P{ id = "universal.control_has_tip", kind = "always", text = "Every control Wuber shows has a tooltip.",
	source = "CLAUDE.md: every control has a tooltip (T.Tip)",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		for _, b in ipairs(wuberButtons(c)) do
			if not U.tipOf(b) and not hoverShowsTip(c, b) then
				say(ctx, "You point at %s on the %s screen and no tooltip shows (every control needs one).", U.nameOf(b), (U.screen(ctx)))
			end
		end
	end }

P{ id = "universal.button_has_label", kind = "always", text = "Every button you can click shows words or a tooltip title, and no label is blank.",
	source = "brief item 8",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		for _, b in ipairs(wuberButtons(c)) do
			local s = S[b]
			if type(s.text) == "string" and s.text ~= "" and not s.text:match("%S") then
				say(ctx, "A button on the %s screen has a blank label.", (U.screen(ctx)))
			end
		end
		for _, t in ipairs(wuberTexts(c)) do
			if S[t.obj].otype == "FontString" and t.text:match("^%s*$") then say(ctx, "A label on the %s screen is empty.", (U.screen(ctx))) end
		end
	end }

-- what the player can see change (the before / after of one click)
local function deepSig(v, seen, depth)
	local t = type(v)
	if t ~= "table" then return tostring(v) end
	if S[v] then return "<widget>" end
	if depth > 6 then return "{...}" end
	seen = seen or {}
	if seen[v] then return "<cycle>" end
	seen[v] = true
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. deepSig(v[k], seen, depth + 1) end
	seen[v] = nil
	return "{" .. table.concat(parts, ",") .. "}"
end
U.deepSig = deepSig

local function snapshot(ctx)
	local c, w, W = ctx.me, ctx.w, ctx.W
	local texts = {}
	for _, t in ipairs(wuberTexts(c)) do texts[#texts + 1] = t.text end
	local shown = {}
	for _, f in ipairs(c.frames) do
		local s = S[f]
		if s.shown and U.isWuber(f) and H.visible(f) then shown[#shown + 1] = tostring(f) end
	end
	local gt = c.env.GameTooltip
	local fx = {}
	for _, rr in ipairs(c.widgets) do
		local s = S[rr]
		if s.otype == "Texture" and s.shown and U.isWuber(rr) and H.visible(rr) then fx[#fx + 1] = tostring(s.texture) .. tostring(s.color and s.color[1]) end
	end
	local saved = rawget(c.env, "WuberDB")
	return {
		texts = table.concat(texts, "\n"), shown = table.concat(shown, ","), tip = S[gt].shown and (gt:GetOwner() and tostring(gt:GetOwner())) or "",
		sounds = #c.sounds, chat = #c.chatLines, addon = #w.addonLog, whispers = #w.whispers, chatPosts = #(w.chatPosts or {}), macros = #w.macros,
		saved = deepSig(saved, nil, 0), invites = #w.invites, casts = w.casts, trades = w.trades, tex = #fx,
		ride = deepSig(W.ride, nil, 0), money = c.player.money,
	}
end
U.snapshot = snapshot

local function changed(a, b)
	for k, v in pairs(a) do if b[k] ~= v then return k end end
	return nil
end

-- a stable reference for a button: its label (or tip) and which of the same-labelled buttons it is
local function buttonRefs(c)
	local refs, count = {}, {}
	for _, b in ipairs(wuberButtons(c)) do
		local key = U.labelOf(b) .. "|" .. (U.tipOf(b) or "") .. "|" .. (b:GetName() or E.nameOf(b))
		count[key] = (count[key] or 0) + 1
		refs[#refs + 1] = { key = key, ord = count[key], obj = b }
	end
	return refs
end
U.buttonRefs = buttonRefs

local function findRef(c, key, ord)
	for _, r in ipairs(buttonRefs(c)) do if r.key == key and r.ord == ord then return r.obj end end
	return nil
end
U.findRef = findRef

-- buttons that must not be clicked blindly: they leave the game or are the harness's, not Wuber's story
local SKIP_KEY = { "Close", "Hide this tip", "Skip tips" }

-- The ONE exception: "Clear" on the "Key for the big button" row while that row reads "None set" has nothing to clear
-- (Settings/Rows.lua keyRow; its tip says "No key for the big button."). No general escape: only this row, only this text.
local function clearWithNoKey(cx, b)
	if U.labelOf(b) ~= "Clear" then return false end
	local row
	pcall(function() row = cx.W.UI.settings.keyRow end)
	if not row or S[b].parent ~= row then return false end
	local ok, t = pcall(function() return row.desc:GetText() end)
	return ok and t == "None set"
end

P{ id = "universal.button_does_something", kind = "scenario", text = "Every button you can click does something you can see.",
	source = "brief: tests pass and features then fail in the first minute",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then ctx:na("no client") end
		local refs = buttonRefs(c)
		if #refs == 0 then ctx:na("no button is shown") end
		-- which buttons: all when few, else a seeded sample (never math.random)
		local cap = tonumber(os.getenv("HUNT_BTN_MAX") or "") or 10
		local pick = {}
		if #refs <= cap then for i = 1, #refs do pick[i] = i end
		else
			local used = {}
			for _ = 1, cap * 20 do
				if #pick >= cap then break end
				local i = ctx.rng:int(#refs)
				if not used[i] then used[i] = true pick[#pick + 1] = i end
			end
			for i = 1, #refs do if #pick < cap and not used[i] then used[i] = true pick[#pick + 1] = i end end
			table.sort(pick)
		end
		local list = {}
		for _, i in ipairs(pick) do list[#list + 1] = { key = refs[i].key, ord = refs[i].ord, label = U.nameOf(refs[i].obj), screen = (U.screen(ctx)) } end
		for n, item in ipairs(list) do
			local cx = ctx
			if n > 1 then
				-- a fresh copy of the situation for every button after the first
				cx = U.fresh(ctx, Hunt)
				if not cx then break end
			end
			local b = findRef(cx.me, item.key, item.ord)
			if os.getenv("HUNT_TRACE") then io.stderr:write("click ", item.label, " ", tostring(b ~= nil), " ", os.clock(), "\n") end
			-- a control drawn dim (alpha under 0.5: the Fold button without room) says "not now": it may do nothing
			-- (the tab you are already on: clicking it changes nothing, as in any tab bar)
			local onTab = false
			if b and b.tabName then pcall(function() local body = cx.W.UI.GetTab(b.tabName) onTab = body ~= nil and body:IsShown() end) end
			-- (2.4) in combat the Drive console's rows read "Paused during combat" and do nothing: not a click to try
			local inFight = cx.me and cx.me.player and cx.me.player.combat == true
			if b and E.effAlpha(b) >= 0.5 and not onTab and not inFight and not clearWithNoKey(cx, b) then
				cx:advance(0.1)
				local before = snapshot(cx)
				local ok, err = pcall(cx.me.clickOn, cx.me, b)
				if not ok then
					if tostring(err):find("nothing takes the mouse", 1, true) or tostring(err):find("not visible", 1, true) then
						-- covered by something: not clickable here (not this promise's story)
					else error(err, 0) end
				else
					cx:advance(0.2)
					local after = snapshot(cx)
					-- (a window that zooms out takes 0.18 s and hides at its end: Theme/Anim.lua; give a slow change time to land)
					if not changed(before, after) then
						cx:advance(0.5)
						after = snapshot(cx)
					end
					if not changed(before, after) then
						-- hardware / hover effects the snapshot cannot see: a hover tip would have changed "tip" only on enter
						-- (fail on the ORIGINAL ctx: the sweep reads the plain line from it, not from the fresh copy cx, and showed "?")
						say(ctx, "You click %s on %s and nothing happens.", item.label, item.screen)
					end
				end
			end
		end
	end }

-- a fresh copy of ctx's situation: Hunt.build(sit, seed) (the core's way). Returns a ctx or nil.
function U.fresh(ctx, HuntObj)
	if type(HuntObj.build) ~= "function" then return nil end
	local cur = HuntObj.current
	local sit = type(HuntObj.full) == "function" and HuntObj.full(ctx.sit) or ctx.sit
	local ok, c2 = pcall(HuntObj.build, sit, ctx.seed)
	HuntObj.current = cur
	if not ok or type(c2) ~= "table" then return nil end
	return c2
end

---------------------------------------------------------------------------
-- 4. Nothing reaches another player without a click
---------------------------------------------------------------------------
local BACKGROUND = { D = true, X = true, Q = true, K = true, F = true, B = true, G = true, V = true, W = true }
local HUMAN = { R = true, C = true, T = true, A = true, N = true, S = true, P = true }

-- judged at the time of the SEND (e.at; the facts were recorded then, universal_util.lua note()), not at check time: a scenario may
-- advance the clock past 60 s or end the ride before this always-check looks
local function sessionAuthorised(ctx, w, e)
	if e.hw then return true, "inside a click" end
	local hw = e.hwAt
	if hw and (e.at or w.time) - hw <= 60 then return true, "a click " .. string.format("%.0f", (e.at or w.time) - hw) .. " s before" end
	-- a message a click queued in a boss fight leaves when the fight ends: the click counts if it came up to 60 s before the fight
	-- or during it, and the send is up to 60 s after the fight's end (Net/Transport.lua holds the queue for the whole fight)
	local f = e.fight
	if f and f.hw and f.hw >= f.start - 60 and (e.at or w.time) - f.stop <= 60 then return true, "a click queued it before a boss fight ended" end
	if e.rideOn then return true, "a ride was under way" end
	if e.driveOn then return true, "the driver was online" end
	return false
end

P{ id = "universal.no_unclicked_send", kind = "always", text = "Wuber sends nothing that reaches another player (a whisper, a chat line, an invite, a ride request) unless you clicked; the exceptions are the whisper back to someone asking for a summon in public chat (2.4, with its own switch) and three lines to your own rider (the greeting, the pay reminder, \"You're next\"), each only when its own switch is on and that rider asked you for a ride.",
	source = "CLAUDE.md secure rules; CurseForge page: background messages are hidden addon messages between addons; CHANGELOG-2.4.0 (the whisper back)",
	check = function(ctx)
		local w = U.world(ctx)
		local wu = w.huntU
		wu.cur = wu.cur or {}
		local from = wu.cur.send or 0
		wu.cur.send = #wu.sends
		for i = from + 1, #wu.sends do
			local e = wu.sends[i]
			-- (a send made while a dial builds the situation is the dial acting for the player, e.g. the ride dial running the
			-- secure macro itself: not judged; only sends after the build, in a scenario check or a walk step)
			local building = e.stage == "pre" or e.stage == "world" or e.stage == "login" or e.stage == "apply"
			if e.from == ctx.name and e.ok and not building then
				if e.via == "addon" then
					if e.prefix == "WUBER" and HUMAN[e.kind or ""] then
						local ok, why = sessionAuthorised(ctx, w, e)
						if not ok then
							say(ctx, "Wuber sent a %s message (%s) to %s and you had not clicked anything.", e.kind, e.kind == "R" and "a ride request" or "a ride message", tostring(e.target or e.chat))
						end
					elseif e.prefix == "WUBER" and not BACKGROUND[e.kind or ""] and e.kind ~= nil and e.kind ~= "" then
						-- an unknown kind: background by the doc rule only if registered with W.NetKind; not judged here
					end
				elseif e.via == "whisper" then
					if e.how == "addon" then
						say(ctx, "Wuber whispered \"%s\" to %s by itself, not from a click.", tostring(e.text):sub(1, 60), tostring(e.to))
					elseif e.how == "auto" then
						-- (2.4 Messages: the greeting, the pay reminder and "You're next", Drive/AutoLines.lua; judged at send time in
						-- universal_util.lua: that line's own switch is on and the receiver asked this driver for a ride)
						if e.autoWhy then
							say(ctx, "Wuber whispered \"%s\" to %s by itself and %s.", tostring(e.text):sub(1, 60), tostring(e.to), e.autoWhy)
						end
					elseif not e.hw and e.how ~= "user" and e.how ~= "macro" and e.how ~= "reply" then
						-- (job 146: how = "reply" is the 2.4 whisper back, Drive/AutoReply.lua, the one allowed send without a click; the
						-- harness gives that mark only inside H.replyRule's limits and raises on anything outside them)
						-- (a secure macro: the harness runs one only on a click path, harness.lua whisper "macro" / SecureActionButton)
						say(ctx, "Wuber whispered \"%s\" to %s and you had not clicked.", tostring(e.text):sub(1, 60), tostring(e.to))
					end
				elseif e.via == "chat" then
					if e.how ~= "user" and not e.hw then
						say(ctx, "Wuber posted \"%s\" in chat and you had not clicked.", tostring(e.text):sub(1, 60))
					end
				end
			end
		end
		-- invites, trades, summons the addon made without a click are violations in the harness (needClick): game_rules
	end }

---------------------------------------------------------------------------
-- 5. Saved data
---------------------------------------------------------------------------
-- the game writes saved variables with plain Lua values only
local function savedProblems(root)
	local seen, out = {}, {}
	local function walk(v, path, depth)
		local t = type(v)
		if t == "function" or t == "userdata" or t == "thread" then out[#out + 1] = path .. " is a " .. t return end
		if t == "number" then
			if v ~= v then out[#out + 1] = path .. " is NaN" elseif v == math.huge or v == -math.huge then out[#out + 1] = path .. " is infinite" end
			return
		end
		if t ~= "table" then return end
		if S[v] then out[#out + 1] = path .. " is a frame or a region" return end
		if getmetatable(v) ~= nil then out[#out + 1] = path .. " has a metatable (it would save as a plain table)" end
		if seen[v] then out[#out + 1] = path .. " is the same table as " .. seen[v] .. " (saved twice, it loads as two)" return end
		if depth > 12 then out[#out + 1] = path .. " is nested more than 12 deep" return end
		seen[v] = path
		for k, x in pairs(v) do
			local kt = type(k)
			if kt == "number" and (k ~= k or k == math.huge or k == -math.huge) then out[#out + 1] = path .. " has a NaN or infinite key"
			elseif kt ~= "string" and kt ~= "number" and kt ~= "boolean" then out[#out + 1] = path .. " has a key that is a " .. kt
			else walk(x, path .. "." .. tostring(k), depth + 1) end
			if #out >= 5 then return end
		end
		seen[v] = nil -- the same table under two parents is flagged only for a cycle's sake above: allow shared leaves
	end
	walk(root, "WuberDB", 0)
	return out
end
U.savedProblems = savedProblems

-- write a table as Lua text the way the game does and read it back
local function serialise(v, out, depth)
	local t = type(v)
	if t == "number" then out[#out + 1] = string.format("%.17g", v)
	elseif t == "string" then out[#out + 1] = string.format("%q", v)
	elseif t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
	elseif t == "table" then
		out[#out + 1] = "{"
		for k, x in pairs(v) do
			out[#out + 1] = "["
			serialise(k, out, depth + 1)
			out[#out + 1] = "]="
			serialise(x, out, depth + 1)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	else out[#out + 1] = "nil" end
end
local function sameTable(a, b, path, depth)
	if type(a) ~= type(b) then return path .. " changed type" end
	if type(a) ~= "table" then
		if a ~= b then return path .. " changed from " .. tostring(a) .. " to " .. tostring(b) end
		return nil
	end
	if depth > 12 then return nil end
	for k, v in pairs(a) do
		if b[k] == nil then return path .. "." .. tostring(k) .. " was lost" end
		local d = sameTable(v, b[k], path .. "." .. tostring(k), depth + 1)
		if d then return d end
	end
	for k in pairs(b) do if a[k] == nil then return path .. "." .. tostring(k) .. " appeared" end end
	return nil
end

P{ id = "universal.saved_roundtrip", kind = "always", text = "What Wuber saves survives being written to disk and read back unchanged.",
	source = "brief item 5",
	check = function(ctx)
		if not everyNth(ctx, "saved") then return end
		local db = rawget(ctx.me.env, "WuberDB")
		if type(db) ~= "table" then return end
		local bad = savedProblems(db)
		if #bad > 0 then say(ctx, "Wuber's saved data cannot be saved as it is: %s.", bad[1]) end
		local out = {}
		serialise(db, out, 0)
		local f = loadstring("return " .. table.concat(out))
		if not f then say(ctx, "Wuber's saved data cannot be written out as text.") return end
		setfenv(f, {})
		local ok, back = pcall(f)
		if not ok then say(ctx, "Wuber's saved data cannot be read back: %s", tostring(back)) return end
		local d = sameTable(db, back, "WuberDB", 0)
		if d then say(ctx, "After a save and load, Wuber's saved data differs: %s.", d) end
	end }

-- what the player sees, for the reload comparison. EXEMPT (each with its reason):
--   * the clock text (hh:mm, "19:33"): the phone's status bar clock changes with game time, a /reload takes none but the settle does
--   * "TIP n OF m", the tip card text and its buttons (Next tip, Skip tips, Hide this tip): the tip tour re-offers after a reload on purpose
--   * Wuber's signal bars and "Ping drivers" countdown numbers: they run live
--   * the splash caption "Summons, on demand" (Phone.lua:65): the splash plays only just after the phone opens
--   * for a window that is not a rider's (crew, driver) or one whose driver is an old Wuber: the drivers list refills with the next
--     beacon (every 60 s +- 10: Net/Base.lua BEACON_EVERY), so the check waits 75 s there instead of 15 (a rider's Q is answered at once)
local function normText(t)
	if t:match("^%d%d:%d%d$") then return nil end
	if t:match("^Tip %d+ of %d+$") then return nil end
	return (t:gsub("%d+ ?s ago", "N s ago"):gsub("%d+ ?min ago", "N min ago"))
end

-- a text of the big button or its console (the frames WuberDriveButton and WuberDriveMini): in combat it shows out of combat's words only
local function underBigButton(obj)
	local o, hops = obj, 0
	while o and hops < 40 do
		local ok, name = pcall(function() return o:GetName() end)
		if ok and (name == "WuberDriveButton" or name == "WuberDriveMini") then return true end
		o = S[o].parent
		hops = hops + 1
	end
	return false
end

-- skipBig: leave out the big button's own texts (read in combat)
local function sees(ctx, skipBig)
	local out = {}
	for _, t in ipairs(wuberTexts(ctx.me)) do
		local n = normText(t.text)
		if skipBig and underBigButton(t.obj) then n = nil end
		-- (the bird card and toasts stay a few seconds by design, e.g. the bird card 6 s: gone after the 15 s the reload waits)
		local nm = E.nameOf(t.obj)
		if nm:find("^Bird%.lua:") or nm:find("^Toasts%.lua:") then n = nil end
		-- (the splash caption "Summons, on demand" plays for the first moments after the phone opens (Phone.lua:65): over after the reload's wait)
		if nm:find("^Phone%.lua:") and t.text == "Summons, on demand" then n = nil end
		-- (every text of the tip card and the coach marks: the tip tour re-offers after a reload on purpose, as the header says for "TIP n OF m")
		if nm:find("^Tips%.lua:") or nm:find("^Coach%.lua:") or nm:find("^WuberTipCard") then n = nil end
		if n and not t.tip then out[#out + 1] = n end
	end
	table.sort(out)
	return out
end

-- every text that is gone, or new, after the reload (at most 16), one entry each: { text, "gone" | "new" }
local function listDiffs(a, b)
	local ca, cb, out = {}, {}, {}
	for _, x in ipairs(a) do ca[x] = (ca[x] or 0) + 1 end
	for _, x in ipairs(b) do cb[x] = (cb[x] or 0) + 1 end
	for x, n in pairs(ca) do if (cb[x] or 0) < n then out[#out + 1] = { x, "gone" } end end
	for x, n in pairs(cb) do if (ca[x] or 0) < n then out[#out + 1] = { x, "new" } end end
	table.sort(out, function(p, q) if p[2] ~= q[2] then return p[2] < q[2] end return p[1] < q[1] end)
	while #out > 16 do table.remove(out) end
	return out
end

local function mainState(ctx)
	local W = ctx.W
	local st = {}
	pcall(function()
		local r = W.ride
		-- a ride that ended unpaid is dropped on purpose by a /reload (Net/Rides restoreRide): compared only if live,
		-- or paid (a paid ride that failed is kept for 30 minutes)
		if r and not (W.RideActive and W.RideActive()) and not r.paid then r = nil end
		st.ride = r and { id = r.id, state = r.state, dest = r.dest, price = r.price, driver = r.driver } or false
	end)
	pcall(function()
		local ds = {}
		-- (keys only: the fake world's driver bots re-beacon with new prices after the reload; the drivers listed are the promise)
		for _, d in ipairs(W.UI.Drivers()) do ds[#ds + 1] = d.key end
		table.sort(ds)
		st.drivers = table.concat(ds, ",")
	end)
	pcall(function() st.drive = W.Char().drive == true end)
	pcall(function() st.price = W.Char().price end)
	return st
end

-- A driver's queue (who you invited, who waits on your console) lives in memory only (nothing of it is saved), so a /reload empties
-- it. That is judged on its own, by universal.reload_driver_queue, in its own plain line; everything else that changed is
-- judged by universal.reload_same. One reload gives a list of findings, each of one thing that changed; the two promises pick theirs.
-- (qname: the invited rider's name, read from the "Invited Dan" line; the pieces of that row are the name, its first letter, the
-- row's clock "0:00", "· invited" and "waiting for them to join the group")
local function isDriverQueueLine(ctx, x, qname)
	local role = ctx.sit and ctx.sit.role
	if role == nil or role == "rider" then return false end
	if x:lower():find("invited", 1, true) then return true end
	if not qname then return false end
	return x == qname or (#x == 1 and x == qname:sub(1, 1):upper()) or x:find("^%d+:%d%d$") ~= nil or x:find("waiting for them to join", 1, true) ~= nil
end

local function reloadFindings(ctx)
		local found = {}
		local function add(kind, fmt, ...) found[#found + 1] = { kind = kind, line = fmt:format(...) } end
		if not (ctx.me and ctx.me.alive) then ctx:na("no client") end
		local W = ctx.W
		local shown = W.UI.IsShown()
		local page, unfolded = nil, false
		pcall(function() page = W.UI.Fold.Page() unfolded = W.UI.Fold.IsUnfolded() end)
		local tab
		for _, n in ipairs({ "Ride", "Trips", "Drive" }) do
			pcall(function() local b = W.UI.GetTab(n) if b and b:IsShown() and shown then tab = tab or n end end)
		end
		-- (page is nil in a folded window too: then a sub-screen -- Settings, Help, a Drive sub-screen, the booking card -- is not a tab page)
		local sub = false
		pcall(function()
			local K = ctx:mod("UI.Kit")
			local kui = K and K.ui
			if kui and kui.settingsOpen then sub = true end
			if kui and kui.screen and kui.screen ~= "home" and kui.screen ~= "ride" and kui.screen ~= "trips" and kui.screen ~= "drive" then sub = true end
			if W.UI.HelpShown and W.UI.HelpShown() then sub = true end
			if W.Driver and W.Driver.CurrentScreen and tab == "Drive" and W.Driver.CurrentScreen() ~= "console" then sub = true end
		end)
		local tabPage = page == "ride" or page == "trips" or not shown or (page == nil and not sub)
		-- overlays that are not meant to survive a /reload (the Report a bug sheet, a Wrapped story, the What's new card: the game closes
		-- them too) are closed first the way a player would (their x, "Got it"), so the page under them is the one compared
		local closedOverlay = false
		pcall(function() if W.UI.Bug and W.UI.Bug.Shown and W.UI.Bug.Shown() then W.UI.Bug.Close() closedOverlay = true end end)
		pcall(function() local WM = ctx:mod("UI.Rider.Wrapped") if WM and WM.Shown and WM.Shown() then WM.Close() closedOverlay = true end end)
		-- (a What's new card that is only pending shows a few seconds after login: wait for it, then close it, so it does not come up
		-- on one side of the reload only)
		pcall(function()
			local WN = ctx:mod("UI.WhatsNew")
			local waited = 0
			while WN and WN.Pending and WN.Pending() and waited < 30 do
				local nc = rawget(ctx.me.env, "WuberNewsCard")
				if nc and S[nc] and S[nc].shown then break end
				ctx:advance(2) waited = waited + 2
			end
		end)
		pcall(function()
			local nc = rawget(ctx.me.env, "WuberNewsCard")
			if not (nc and S[nc] and S[nc].shown) then return end
			-- the pop-up says "Not now", the opened card "Got it": both count as the player's close
			local b = ctx.me:button("Got it")
			if not (b and ctx:visible(b)) then b = ctx.me:button("Not now") end
			if b and ctx:visible(b) then ctx.me:clickOn(b) closedOverlay = true end
		end)
		if closedOverlay then ctx:advance(1) end
		-- a tab's numbers count up for about 3 s when it opens ("49m" then "50m"): read only after they settle
		ctx:advance(3)
		local beforeTexts, beforeNoBig = sees(ctx), sees(ctx, true)
		-- (in combat the big button shows its words out of combat only, Drive/Button.lua: its texts are left out of the comparison
		-- when either read is in combat; every other text is still compared)
		local inFight = ctx.me.player.combat == true
		local beforeState = mainState(ctx)
		local beforeSaved = deepSig(rawget(ctx.me.env, "WuberDB"), nil, 0)
		local screen = (U.screen(ctx))
		ctx:reload()
		-- the network joins its channel about 10 s after login; a driver's, crew's or old peer's list refills with the next beacon (60 s +- 10)
		local riderish = (ctx.sit == nil or ctx.sit.role == nil or ctx.sit.role == "rider") and not (ctx.sit and ctx.sit.net == "oldpeer")
		ctx:advance(riderish and 15 or 75)
		W = ctx.W
		if shown and not W.UI.IsShown() then
			W.UI.Toggle(true)
			ctx:advance(3)
			if tab then pcall(W.UI.SelectTab, tab) ctx:advance(3) end -- the tab you were on (a window always closes in a /reload)
		end
		if page and not unfolded then
			-- the same page: the window opens where the player left it only for rides in progress; nothing to select here
		end
		local afterState = mainState(ctx)
		for k, v in pairs(beforeState) do
			local a = afterState[k]
			if type(v) == "table" then
				for kk, vv in pairs(v) do if a == false or a == nil or a[kk] ~= vv then
					add("state", "After a /reload your ride's %s on the %s screen has changed from %s to %s.", kk, screen, tostring(vv), tostring(a and a[kk])) end end
			elseif a ~= v then
				add("state", "After a /reload your %s has changed from %s to %s.", k, tostring(v), tostring(a))
			end
		end
		-- (a page that is not a tab's own page -- settings, a confirm card, the drive screens -- cannot be reopened by tab: texts are not compared)
		if tabPage then
			local combatRead = inFight or ctx.me.player.combat == true
			local diffs, qname = listDiffs(combatRead and beforeNoBig or beforeTexts, sees(ctx, combatRead)), nil
			for _, d in ipairs(diffs) do
				if d[2] == "gone" then qname = qname or d[1]:match("^[Ii]nvited (.+)$") end
			end
			for _, d in ipairs(diffs) do
				local x, how = d[1], d[2]
				if os.getenv("HUNT_RELOAD_DEBUG") then io.stderr:write(("RELOAD %s: %q\n"):format(how, x)) end
				if (how == "gone" and isDriverQueueLine(ctx, x, qname)) or (how == "new" and qname and x:find("waiting for riders", 1, true)) then
					add("driverq", "You are driving with a rider invited, you /reload, and the rider is gone from your console.")
				else
					add("text", "You /reload on the %s screen and %s: \"%s\".", screen, how == "gone" and "this is gone afterwards" or "this appears that was not there before", x:sub(1, 80))
				end
			end
		end
		local afterSaved = deepSig(rawget(ctx.me.env, "WuberDB"), nil, 0)
		-- (the saved table legitimately gains session stamps: not compared as a whole; the round-trip promise judges the table)
		return found
end

local RELOAD_TEXT = "After a /reload Wuber shows you the same things as before: the same ride, the same drivers, the same settings."
P{ id = "universal.reload_same", kind = "scenario", text = RELOAD_TEXT,
	source = "brief item 5",
	check = function(ctx)
		for _, f in ipairs(reloadFindings(ctx)) do
			if f.kind ~= "driverq" then ctx:fail(f.line) return end
		end
	end }

P{ id = "universal.reload_driver_queue", kind = "scenario", text = "When you are driving with a rider invited and you /reload, the rider is still on your console afterwards.",
	source = "inferred (the driver's queue lives in memory only: Net/Drive state is not saved; a judge rules whether that is intended)",
	when = function(sit) return sit.role ~= nil and sit.role ~= "rider" end,
	check = function(ctx)
		for _, f in ipairs(reloadFindings(ctx)) do
			if f.kind == "driverq" then ctx:fail(f.line) return end
		end
	end }

---------------------------------------------------------------------------
-- 7. Gold
---------------------------------------------------------------------------
-- every amount of gold Wuber shows is written the way W.Money writes it (no 100s, no 5g 0s), and while a ride is under
-- way an amount shown on a ride screen is one the ride, the driver or the player's own purse holds.
local function knownAmounts(ctx)
	local W, c = ctx.W, ctx.me
	local set = {}
	local function add(n, why) n = tonumber(n) if n then set[math.floor(n + 0.5)] = why end end
	pcall(function()
		local r = W.ride
		if r then
			add(r.price, "the ride's price") add(r.fare, "the fare") add(r.tip, "the tip") add(r.voucherCover, "the raincheck")
			add(r.flightCost, "the flying cost")
			if r.price and r.voucherCover then add(r.price - r.voucherCover, "price less raincheck") end
			if r.price and r.tip then add(r.price + r.tip, "price and tip") end
			if r.price then
				local pct = tonumber(W.db.tipPct) or 0
				add(r.price * (100 + pct) / 100, "price and tip percent") add(math.floor(r.price * pct / 100), "tip percent")
				add(math.ceil(r.price * pct / 100), "tip percent")
				-- what the code itself holds for the tip (whole silver, rounded up: 15% of 50s is 8s) and the total to type;
				-- the tip stop buttons show "(+5s)" for every stop, the line shows the chosen one
				local UI = W.UI
				if UI and UI.TipFor then
					add(UI.TipFor(r.price, UI.TipPct and UI.TipPct()), "the chosen tip (UI.TipFor)")
					for _, stop in ipairs(UI.TIP_STOPS or {}) do add(UI.TipFor(r.price, stop), "a tip stop (UI.TipFor)") end
				end
				if UI and UI.PayTotal then add(UI.PayTotal({ price = r.price }), "the total to type (UI.PayTotal)") end
			end
		end
	end)
	pcall(function() for _, d in pairs(W.drivers) do add(d.price, "a driver's price") end end)
	pcall(function() add(W.Char().price, "my price") add(W.MIN_PRICE, "the minimum price") end)
	pcall(function() add(c.env.GetMoney(), "my purse") end)
	pcall(function() for _, rr in ipairs(W.db.rides) do add(rr.price, "a past ride") add(rr.tip, "a past tip") end end)
	pcall(function() for _, rr in ipairs(W.db.earnings or {}) do add(rr.price, "an earning") add(rr.tip, "an earning's tip") end end)
	return set
end

P{ id = "universal.gold_matches", kind = "always", text = "Every amount of gold Wuber shows is written properly and is an amount the ride, the driver or your purse really holds.",
	source = "brief item 7",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		local known
		for _, t in ipairs(wuberTexts(c)) do
			if not t.tip or true then
				for _, m in ipairs(U.moneyIn(t.text)) do
					if not m.canonical then
						say(ctx, "Wuber shows the amount \"%s\" in \"%s\" and it is not written the usual way (%s).", m.text, t.text:sub(1, 60), (ctx.W.Money(m.copper)))
					end
					known = known or knownAmounts(ctx)
					if not known[m.copper] and not t.text:find("%f[%a]about%f[%A]") and not t.text:find("%d+ ?[gsc]/") then
						-- an amount that nothing holds: only worth a failure while a ride is shown or the line names the fare
						local r = ctx.W.ride
						if r and (t.text:lower():find("fare") or t.text:lower():find("pay") or t.text:lower():find("type")) then
							say(ctx, "Wuber shows %s in \"%s\" but your ride costs %s.", m.text, t.text:sub(1, 70), ctx.W.Money(r.price))
						end
					end
				end
			end
		end
	end }

---------------------------------------------------------------------------
-- 8. What the words say
---------------------------------------------------------------------------
local PLACEHOLDERS = {
	{ "nil", "%f[%w]nil%f[%W]" }, { "table: 0x", "table: 0x" }, { "function: 0x", "function: 0x" }, { "a %s", "%%s" }, { "a %d", "%%d" },
	{ "a %1", "%%%d" }, { "undefined", "%f[%w]undefined%f[%W]" }, { "null", "%f[%w]null%f[%W]" }, { "NaN", "%f[%w]NaN%f[%W]" },
	{ "{0}", "{%d}" }, { "<name>", "<%a+>" },
}
local function guildTag(c)
	local ok, g = pcall(function() return c.env.GetGuildInfo("player") end)
	if ok and type(g) == "string" and g ~= "" then return ("<" .. g .. ">"):gsub("%p", "%%%0") end
	return "\1\1" -- (matches nothing)
end
-- is this start of a text one of the player's own saved strings (a message template they wrote: "<Wuber> Your driver has arrived! ...")
local function inSaved(c, start)
	local db = rawget(c.env, "WuberDB")
	local found = false
	local function walk(v, depth)
		if found or depth > 6 then return end
		if type(v) == "string" then if v:find(start, 1, true) then found = true end
		elseif type(v) == "table" and not S[v] then for _, x in pairs(v) do walk(x, depth + 1) end end
	end
	walk(db, 0)
	return found
end
P{ id = "universal.no_placeholder_text", kind = "always", text = "No text of Wuber's shows a blank placeholder: nil, table: 0x, %s, %d, NaN, undefined.",
	source = "brief item 8",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		local typed = U.world(ctx).huntU.typed
		for _, t in ipairs(wuberTexts(c)) do
			local txt = t.text
			local echo = t.edit
			for _, ty in ipairs(typed) do if txt:find(ty, 1, true) then echo = true break end end -- what the player typed shows as typed
			for _, p in ipairs(PLACEHOLDERS) do
				-- (the player's own guild in brackets is the {guild} word of a message template (Drive/Chat.lua guildName): not a placeholder)
				-- (a tag in the player's own saved message template shows as they wrote it: not a placeholder)
				if not echo and txt:gsub(guildTag(c), ""):find(p[2]) and not (p[1] == "<name>" and inSaved(c, txt:match("<[^<>]+>") or "\1")) then
					say(ctx, "On the %s screen Wuber shows \"%s\" (it contains %s).", (U.screen(ctx)), txt:sub(1, 80), p[1])
					break
				end
			end
		end
	end }

P{ id = "universal.sane_numbers", kind = "always", text = "No number Wuber shows is NaN, infinite or negative where it cannot be.",
	source = "brief item 8",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		for _, t in ipairs(wuberTexts(c)) do
			local bad = U.hasBadNumber(t.text)
			local echo = t.edit
			for _, ty in ipairs(U.world(ctx).huntU.typed) do if t.text:find(ty, 1, true) then echo = true break end end
			if echo then bad = nil end
			if bad then say(ctx, "On the %s screen Wuber shows \"%s\" (%s).", (U.screen(ctx)), t.text:sub(1, 80), bad) end
			local txt = t.text
			if not echo and (txt:find("^%-%d") or txt:find("%s%-%d+%s?[gscmh]") or txt:find("about %-") or txt:find("%-%d+%s?min") or txt:find("%-%d+%s?sec")) then
				say(ctx, "On the %s screen Wuber shows a negative amount or time: \"%s\".", (U.screen(ctx)), txt:sub(1, 80))
			end
			if txt:find("%d+%.%d%d%d%d+") then
				say(ctx, "On the %s screen Wuber shows a number with a long tail of decimals: \"%s\".", (U.screen(ctx)), txt:sub(1, 80))
			end
		end
	end }

P{ id = "universal.estimates_say_about", kind = "always", text = "Wuber labels an estimate with \"about\" and never with a tilde, \"approx\" or \"roughly\".",
	source = "CLAUDE.md: estimates are labelled about",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		for _, t in ipairs(wuberTexts(c)) do
			local l = t.text:lower()
			if t.text:find("~%s?%d") or l:find("%f[%a]approx") or l:find("%f[%a]roughly%f[%A]") or l:find("%f[%a]circa%f[%A]") then
				say(ctx, "On the %s screen Wuber writes an estimate without \"about\": \"%s\".", (U.screen(ctx)), t.text:sub(1, 80))
			end
		end
	end }

local BANNED = {
	{ "the old summoning addon (\"ritual\")", "ritual" },
	{ "the test addon (\"WuberLab\")", "wuberlab" }, { "the test addon (\"Wuber Lab\")", "wuber lab" },
	{ "a free claim", "for free" }, { "a free claim", "free of charge" }, { "a free claim", "free ride" }, 	{ "a free claim", "free trip" }, { "a free claim", "free flight" }, { "a free claim", "at no cost" },
	{ "a one-click payment claim", "one click" }, { "a one-click payment claim", "one-click" }, { "a one-click payment claim", "1-click" },
	{ "a one-click payment claim", "click to pay" }, { "a one-click payment claim", "auto-pay" }, { "a one-click payment claim", "autopay" },
	{ "a one-click payment claim", "pays for you" }, { "a one-click payment claim", "pay with one" },
}
P{ id = "universal.no_banned_words", kind = "always", text = "Wuber never says anything the author forbade: no free claims, no one-click payment, no old addon, no test addon.",
	source = "CLAUDE.md hard rules",
	check = function(ctx)
		local c = ctx.me
		if not (c and c.alive) then return end
		for _, t in ipairs(wuberTexts(c)) do
			local l = t.text:lower()
			for _, b in ipairs(BANNED) do
				if l:find(b[2], 1, true) then
					say(ctx, "On the %s screen Wuber says \"%s\" (%s).", (U.screen(ctx)), t.text:sub(1, 90), b[1])
					break
				end
			end
		end
		for _, b in ipairs(wuberButtons(c)) do
			local l = U.labelOf(b):lower()
			if l:find("^pay%f[%A]") or l == "pay" then
				say(ctx, "A button on the %s screen says \"%s\", as if one click pays: the trade needs your own steps.", (U.screen(ctx)), U.labelOf(b))
			end
		end
	end }

P{ id = "universal.only_wuber_drivers", kind = "always", text = "The rider's list shows only Wuber drivers, never someone whose only trace is a line in public chat.",
	source = "CLAUDE.md: only [Wuber] drivers ever appear",
	check = function(ctx)
		local c, w = ctx.me, ctx.w
		if not (c and c.alive) then return end
		local ok, list = pcall(function() return ctx.W.UI.Drivers() end)
		if not ok or type(list) ~= "table" then return end
		local posters = {}
		for _, p in ipairs(w.chatPosts or {}) do posters[H.key(p.from)] = true end
		for _, e in ipairs(w.addonLog) do posters[H.key(e.from)] = nil end
		for _, d in ipairs(list) do
			local p = d.name and w:player(d.name)
			if p and not p.client and posters[H.key(d.name)] then
				say(ctx, "The rider's list shows %s as a driver but %s only spoke in public chat and never ran Wuber.", tostring(d.name), tostring(d.name))
			end
			if type(ctx.W.drivers) == "table" and d.key and ctx.W.drivers[d.key] == nil then
				say(ctx, "The rider's list shows %s but Wuber's own driver table does not hold them.", tostring(d.name))
			end
		end
	end }

end
