-- tests/hunt/actions.lua: what a player can do, for the long random sessions of the bug hunt. Owner: UNIVERSAL.
-- Format (tests/hunt/README.md): Hunt.action{ id, weight, pick = function(ctx, rng) -> args | nil, run = function(ctx, args) -> line }.
-- pick only LOOKS (never changes the game) and returns plain data (strings and numbers) so a step replays from its record;
-- it returns nil when the action does not apply (nothing to click, no peer, not in combat ...). run is safe in any state:
-- every game call is under pcall, a clicked thing that is gone is a quiet no-op ("gone"), never an error of the hunt.
-- A click is referenced the way a replay can find it again: the button's words (or tip, or frame name) and its ordinal
-- among buttons with the same name (tests/promises/universal.lua: U.buttonRefs).
-- Weights: mostly clicks and waits, as a real player. What is a POKE (a player cannot do it in a test) is marked (poke):
-- the date jump, a peer's ride request through the API, the window scale.
return function(Hunt)
local U = dofile("tests/hunt/lib/universal_util.lua")
local H, S = U.H, U.S

-- THIS STANDS IN FOR THE GAME'S CLAMP. Wuber sets SetClampedToScreen(true) on WuberFrame (UI/Window.lua:415) with the handset's
-- clamp insets (UI/Phone.lua:234: bezel 8, status bar 26 + bezel on top, home strip 15 + bezel below), so the real client never
-- leaves the window hanging off the screen after a scale or a fold. The fake game only stores the flag (tests/harness.lua:1692),
-- so after every action the window is moved to the nearest place where the whole handset is on screen (top left wins when the
-- handset is bigger than the screen, as in the game). Only the offsets of a single anchor are changed; nothing is saved.
local CLAMP_L, CLAMP_R, CLAMP_T, CLAMP_B = 8, 8, 34, 23
local function clampWindow(ctx)
	pcall(function()
		local c = ctx.me
		local wf = c and c.alive and rawget(c.env, "WuberFrame")
		local ui = c and c.env.UIParent
		if not (wf and ui and S[wf] and S[wf].shown) then return end
		if wf:GetNumPoints() ~= 1 then return end
		local l, b, w, h = wf:GetScaledRect()
		local sl, sb, sw, sh = ui:GetScaledRect()
		if not (l and sl) then return end
		local e = wf:GetEffectiveScale()
		local L, R, T, B = l - CLAMP_L * e, l + w + CLAMP_R * e, b + h + CLAMP_T * e, b - CLAMP_B * e
		local dx, dy = 0, 0
		if R > sl + sw then dx = sl + sw - R end
		if L + dx < sl then dx = sl - L end
		if B < sb then dy = sb - B end
		if T + dy > sb + sh then dy = sb + sh - T end
		if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return end
		local point, rel, relPoint, x, y = wf:GetPoint(1)
		wf:ClearAllPoints()
		wf:SetPoint(point, rel, relPoint, x + dx / e, y + dy / e)
	end)
end

local function A(t)
	local run = t.run
	if run then t.run = function(ctx, a) local line = run(ctx, a) clampWindow(ctx) return line end end
	Hunt.action(t)
end
local function client(ctx) local c = ctx.me if c and c.alive then return c end return nil end

local function buttons(c)
	local out, count = {}, {}
	for _, b in ipairs(U.shown(c, { "Button", "CheckButton" })) do
		local s = S[b]
		if s.enabled ~= false and s.mouse ~= false then
			local key = U.labelOf(b) .. "|" .. (U.tipOf(b) or "") .. "|" .. (b:GetName() or U.E.nameOf(b))
			count[key] = (count[key] or 0) + 1
			out[#out + 1] = { key = key, ord = count[key], obj = b }
		end
	end
	return out
end
local function findButton(c, key, ord)
	for _, r in ipairs(buttons(c)) do if r.key == key and r.ord == ord then return r.obj end end
	return nil
end

-- a click on a covered or hidden thing: the player's click lands elsewhere or nowhere; not an error of the hunt
local function quietClick(c, obj)
	local ok, err = pcall(c.clickOn, c, obj)
	if not ok then
		local e = tostring(err)
		if e:find("not visible", 1, true) or e:find("nothing takes the mouse", 1, true) or e:find("no position", 1, true) then return false, "covered" end
		error(err, 0)
	end
	return true
end

A{ id = "click", weight = 40,
	pick = function(ctx, rng)
		local c = client(ctx)
		if not c then return nil end
		local list = buttons(c)
		if #list == 0 then return nil end
		local r = list[rng:int(#list)]
		return { key = r.key, ord = r.ord }
	end,
	run = function(ctx, a)
		local c = client(ctx)
		local b = c and findButton(c, a.key, a.ord)
		if not b then return "click: gone (" .. a.key:sub(1, 30) .. ")" end
		local ok, why = quietClick(c, b)
		ctx:advance(0.3)
		return "click " .. a.key:sub(1, 40) .. (ok and "" or (" (" .. why .. ")"))
	end }

local WAITS = { 1, 10, 300 }
A{ id = "wait", weight = 25,
	pick = function(ctx, rng)
		local x = rng:int(20)
		return { secs = x <= 12 and 1 or (x <= 19 and 10 or 300) }
	end,
	run = function(ctx, a) ctx:advance(a.secs) return "wait " .. a.secs .. " s" end }

A{ id = "phone", weight = 8,
	pick = function(ctx, rng)
		if not client(ctx) then return nil end
		return { how = rng:pick({ "slash", "slash", "minimap", "ride" }) }
	end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "phone: no window" end
		if a.how == "minimap" then
			local b = c.env.WuberMinimapButton
			if b and H.visible(b) then quietClick(c, b) else pcall(c.slash, c, "/wuber") end
		elseif a.how == "ride" then pcall(c.slash, c, "/ride")
		else pcall(c.slash, c, "/wuber") end
		ctx:advance(0.5)
		return "phone via " .. a.how
	end }

A{ id = "tab", weight = 6,
	pick = function(ctx, rng)
		local c = client(ctx)
		if not c or not ctx.W.UI.IsShown() then return nil end
		local names = {}
		for _, r in ipairs(buttons(c)) do
			local l = U.labelOf(r.obj)
			if l == "Ride" or l == "Trips" or l == "Drive" then names[#names + 1] = l end
		end
		if #names == 0 then return nil end
		return { tab = names[rng:int(#names)] }
	end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "tab: no window" end
		local ok = pcall(c.clickText, c, a.tab)
		ctx:advance(0.5)
		return "tab " .. a.tab .. (ok and "" or " (not shown)")
	end }

A{ id = "fold", weight = 3,
	pick = function(ctx, rng)
		local c = client(ctx)
		if not c or not ctx.W.UI.IsShown() then return nil end
		for _, r in ipairs(buttons(c)) do
			local t = U.tipOf(r.obj)
			if t == "Fold" or t == "Unfold" then return { tip = t } end
		end
		return nil
	end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "fold: no window" end
		for _, r in ipairs(buttons(c)) do
			if U.tipOf(r.obj) == a.tip then quietClick(c, r.obj) ctx:advance(1) return a.tip end
		end
		return "fold: gone"
	end }

local function scrollers(c)
	local out = {}
	for _, f in ipairs(c.frames) do
		local s = S[f]
		if s.shown and s.scripts and s.scripts.OnMouseWheel and U.isWuber(f) and H.visible(f) then out[#out + 1] = f end
	end
	return out
end
A{ id = "scroll", weight = 4,
	pick = function(ctx, rng)
		local c = client(ctx)
		if not c then return nil end
		local list = scrollers(c)
		if #list == 0 then return nil end
		return { ord = rng:int(#list), delta = rng:pick({ -1, -1, -3, 1, 1, 5 }) }
	end,
	run = function(ctx, a)
		local c = client(ctx)
		local f = c and scrollers(c)[a.ord]
		if not f then return "scroll: gone" end
		c.world.hardware = nil
		pcall(H.runScript, f, "OnMouseWheel", a.delta)
		ctx:advance(0.2)
		return "scroll " .. a.delta
	end }

local SAMPLES = {
	"", "Undercity", "ratchet", "50", "1g 20s", "0", "-5", "99999999", "a note", "   ", "Thunder Bluff please",
	string.rep("x", 300), string.rep("Long words ", 40), "%s %d %1", "|cffff0000red|r", "<b>tag</b>", "Zul'Gurub", "\195\169\195\177 odd", "[Wuber] hi", "/run print(1)",
}
local function edits(c)
	local out = {}
	for _, o in ipairs(U.shown(c, { "EditBox" })) do out[#out + 1] = o end
	return out
end
A{ id = "type", weight = 6,
	pick = function(ctx, rng)
		local c = client(ctx)
		if not c then return nil end
		local list = edits(c)
		if #list == 0 then return nil end
		return { ord = rng:int(#list), sample = rng:int(#SAMPLES), enter = rng:chance(0.7) }
	end,
	run = function(ctx, a)
		local c = client(ctx)
		local box = c and edits(c)[a.ord]
		if not box then return "type: gone" end
		local ok, err = pcall(c.type, c, box, SAMPLES[a.sample], a.enter)
		ctx:advance(0.5)
		return "type #" .. a.sample .. (a.enter and " + Enter" or "") .. (ok and "" or " (not possible)")
	end }

local SLASH = { "/wuber", "/ride", "/wuber drive", "/wuber drive on", "/wuber drive off", "/wuber drive price 60", "/wuber drive price 1g",
	"/wuber drive dest Undercity", "/wuber drive dest auto", "/wuber price 75", "/wuber ping", "/wuber map", "/wuber minimap", "/wuber status",
	"/wuber test", "/wuber tips", "/wuber tips off", "/wuber bug", "/wuber help", "/wuber settings", "/wuber nonsense", "/wuber emblem" }
A{ id = "slash", weight = 5,
	pick = function(ctx, rng) if not client(ctx) then return nil end return { n = rng:int(#SLASH) } end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "slash: no window" end
		local ok = pcall(c.slash, c, SLASH[a.n])
		ctx:advance(0.5)
		return SLASH[a.n] .. (ok and "" or " (refused)")
	end }

A{ id = "escape", weight = 3,
	pick = function(ctx, rng) if not client(ctx) then return nil end return {} end,
	run = function(ctx) local c = client(ctx) if c then pcall(c.pressEscape, c) ctx:advance(0.3) end return "Escape" end }

A{ id = "combat", weight = 2,
	pick = function(ctx, rng)
		local c = client(ctx)
		if not c then return nil end
		return { enter = not c.player.combat }
	end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "combat: no window" end
		if a.enter then ctx.w:enterCombat(c) else ctx.w:leaveCombat(c) end
		ctx:advance(1)
		return a.enter and "enter combat" or "leave combat"
	end }

A{ id = "flightmap", weight = 2,
	pick = function(ctx, rng) if not client(ctx) then return nil end return { open = not ctx.huntFlightOpen } end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "flight map: no window" end
		if a.open then
			ctx.huntFlightOpen = true
			pcall(ctx.w.openTaxiMap, ctx.w, c, { { name = "Orgrimmar, Durotar", type = "CURRENT", cost = 0, x = 0.6, y = 0.3 },
				{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 300, x = 0.5, y = 0.5 },
				{ name = "Thunder Bluff, Mulgore", type = "REACHABLE", cost = 500, x = 0.4, y = 0.6 } }, { frame = "FlightMapFrame" })
		else
			ctx.huntFlightOpen = nil
			pcall(c.fire, c, "TAXIMAP_CLOSED")
			local f = c.env.FlightMapFrame
			if f and f.Hide then pcall(f.Hide, f) end
		end
		ctx:advance(1)
		return a.open and "open flight map" or "close flight map"
	end }

local SPOTS = { "Orgrimmar", "Ratchet", "Undercity", "Thunder Bluff", "Crossroads", "Barrens", "Stormwind", "Durotar", "Booty Bay" }
A{ id = "zone", weight = 3,
	pick = function(ctx, rng) if not client(ctx) then return nil end return { spot = SPOTS[rng:int(#SPOTS)], loading = rng:chance(0.5) } end,
	run = function(ctx, a)
		local c = client(ctx)
		if not c then return "zone: no window" end
		if a.loading then pcall(c.fire, c, "LOADING_SCREEN_ENABLED") end
		pcall(ctx.w.move, ctx.w, ctx.name, a.spot)
		if a.loading then ctx:advance(2) pcall(c.fire, c, "PLAYER_ENTERING_WORLD", false, false) pcall(c.fire, c, "LOADING_SCREEN_DISABLED") end
		ctx:advance(1)
		return "go to " .. a.spot .. (a.loading and " (loading screen)" or "")
	end }

A{ id = "reload", weight = 1, pick = function(ctx, rng) if not client(ctx) then return nil end return {} end,
	run = function(ctx) ctx:reload() ctx:advance(3) return "/reload" end }
A{ id = "relog", weight = 1, pick = function(ctx, rng) if not client(ctx) then return nil end return {} end,
	run = function(ctx) ctx:relog() ctx:advance(3) return "logout and login" end }

-- (poke) the date: a night passes. The fake clock jumps; nothing a player can click.
A{ id = "new_day", weight = 1, pick = function(ctx, rng) if not client(ctx) then return nil end return {} end,
	run = function(ctx)
		local w = ctx.w
		w.time = w.time + 86400
		w.lastFrame = w.lastFrame + 86400
		ctx:advance(2)
		return "a new day"
	end }

-- (poke) the window scale: what the Settings window-size slider ends in
A{ id = "scale", weight = 1,
	pick = function(ctx, rng) if not client(ctx) then return nil end return { scale = rng:pick({ 0.8, 1, 1.25, 1.5, 2 }) } end,
	run = function(ctx, a)
		local W = ctx.W
		pcall(function() W.db.scale = a.scale W.UI.ApplyScale() end)
		ctx:advance(0.5)
		return "window scale " .. a.scale
	end }

---------------------------------------------------------------------------
-- other players (ctx.peers: the core's other windows, by role)
---------------------------------------------------------------------------
local function peer(ctx, role)
	local p = ctx.peers and ctx.peers[role]
	if p and p.alive and p.W then return p end
	return nil
end

A{ id = "driver_online", weight = 3,
	pick = function(ctx, rng)
		local p = peer(ctx, "driver")
		if not p then return nil end
		local on = false
		pcall(function() on = p.W.Char().drive == true end)
		return { on = not on }
	end,
	run = function(ctx, a)
		local p = peer(ctx, "driver")
		if not p then return "driver: gone" end
		pcall(p.slash, p, a.on and "/wuber drive on" or "/wuber drive off")
		ctx:advance(3)
		return a.on and "a driver goes online" or "a driver goes offline"
	end }

A{ id = "driver_price", weight = 2,
	pick = function(ctx, rng) if not peer(ctx, "driver") then return nil end return { price = rng:pick({ 50, 60, 75, 120, 250 }) } end,
	run = function(ctx, a)
		local p = peer(ctx, "driver")
		if not p then return "driver: gone" end
		pcall(p.slash, p, "/wuber drive price " .. a.price .. "s")
		ctx:advance(8)
		return "driver changes price to " .. a.price .. "s"
	end }

-- (poke) a peer rider asks the first driver for a ride through the addon's own call
A{ id = "peer_request", weight = 2,
	pick = function(ctx, rng) if not peer(ctx, "rider") then return nil end return {} end,
	run = function(ctx)
		local p = peer(ctx, "rider")
		if not p then return "rider: gone" end
		local ok = pcall(function()
			local list = p.W.UI.Drivers()
			if list[1] then p.W.RequestRide(list[1].key) end
		end)
		ctx:advance(3)
		return "another rider asks for a ride" .. (ok and "" or " (could not)")
	end }

A{ id = "peer_invite", weight = 2,
	pick = function(ctx, rng)
		local p = peer(ctx, "driver") or peer(ctx, "rider")
		if not p then return nil end
		return { kind = rng:pick({ "invite", "summon", "trade" }), role = peer(ctx, "driver") and "driver" or "rider" }
	end,
	run = function(ctx, a)
		local p = peer(ctx, a.role)
		local c = client(ctx)
		if not (p and c) then return "peer: gone" end
		local w = ctx.w
		if a.kind == "invite" then pcall(w.invite, w, p, ctx.name)
		elseif a.kind == "summon" then pcall(w.summon, w, p, ctx.name)
		else pcall(w.openTrade, w, p, c) end
		ctx:advance(2)
		return "a peer starts a " .. a.kind
	end }

A{ id = "party", weight = 2,
	pick = function(ctx, rng)
		local p = peer(ctx, "driver") or peer(ctx, "rider")
		if not p then return nil end
		local me = ctx.w:player(ctx.name)
		return { join = not (me and me.group), role = peer(ctx, "driver") and "driver" or "rider" }
	end,
	run = function(ctx, a)
		local p = peer(ctx, a.role)
		local w = ctx.w
		local me = w:player(ctx.name)
		if not (p and me) then return "party: gone" end
		if a.join then pcall(w.join, w, p.player, me) else pcall(w.leave, w, ctx.name) end
		ctx:advance(2)
		return a.join and "join a party" or "leave the party"
	end }

end
