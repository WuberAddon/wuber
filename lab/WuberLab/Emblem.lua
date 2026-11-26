-- Wuber Lab (developer only, never ship): the Pioneer emblem's look (Wuber 2.3.2, BRIEF15). The fake
-- game can't draw a 3D model over a head, so the tester judges it: each check shows Wuber's own local
-- preview ("/wuber emblem preview": only this screen, nothing sent) in one of the three looks and asks
-- one short Yes/No. The answers (and which model loaded, or the flat ring) go in the report, so the
-- look can be picked: "/wuber emblem 1|2|3".
--
-- Scene "emblem" ("/lab run emblem"; not in "Start test run"; loose, one window: Anita Lift; no run
-- messages): look 1, 2, 3, the drivers' colour,
-- then over another player's nameplate (target Farra Way with friendly nameplates on). The look the tester
-- had before is put back after each answer. Every Wuber name is looked up at run time and nil-guarded.

local _, L = ...

local EM = {}
L.emblem = EM

local function E()
	local W = L.W()
	return W and type(W.Emblem) == "table" and W.Emblem or nil
end

local function db()
	local W = L.W()
	return W and type(W.db) == "table" and W.db or nil
end

-- shows the preview in look n and colour kind (the first time: remembers the tester's own look)
local function show(n, kind)
	local e, d = E(), db()
	if not (e and d and type(e.Preview) == "function") then return false end
	if EM.was == nil then EM.was = d.emblemLook or false end
	pcall(e.SetLook, n)
	pcall(e.Preview, true, kind)
	return true
end

-- the preview off and the tester's look back
local function done()
	local e, d = E(), db()
	if not (e and d) then return end
	pcall(e.Preview, false)
	if EM.was ~= nil then
		pcall(e.SetLook, EM.was or 1)
		EM.was = nil
	end
end
EM.Done = done

local function status()
	local e = E()
	if not (e and type(e.Status) == "function") then return nil end
	local ok, s = pcall(e.Status)
	return ok and type(s) == "table" and s or nil
end

local function shape(s)
	if s and s.flat then return "a flat ring (no 3D model loaded)" end
	return "a small glowing 3D emblem"
end

L.AddScene({ id = "emblem", title = "2.3.2: the Pioneer emblem's look", linked = false, loc = true, prio = 5, only = true })

local function lookCheck(n, kind, id, title, words)
	L.AddCheck({ id = id, title = title, scene = "emblem", who = "driver", secs = 20, timeout = 150,
		click = "stand still in the open world, camera a few steps back; look above your character's head",
		when = function(ctx) if ctx.sim then return "skip", "test mode: the 3D emblem can only be seen in game" end end,
		begin = function(ctx)
			if not show(n, kind) then return "fail", "Wuber's emblem (W.Emblem) isn't loaded" end
		end,
		poll = function(ctx)
			local s = status()
			if not s then ctx.data.waitWhy = "W.Emblem.Status is missing" return end
			if not s.selfShown then ctx.data.waitWhy = "the preview isn't showing (in an instance?)" return end
			ctx.data.auto = "look " .. tostring(s.look) .. " (" .. tostring(s.lookName) .. "), " .. kind .. " colour, model: " .. tostring(s.model)
			ctx.data.shape = shape(s)
		end,
		ask = function(ctx)
			if not ctx.data.auto then return nil end
			return "Do you see " .. ctx.data.shape .. ", " .. words .. ", slowly spinning above your head?"
		end,
		answer = function(ctx, yes)
			local what = tostring(ctx.data.auto)
			done()
			return yes and "pass" or "fail", (yes and "Tester: yes; " or "Tester: not as described; ") .. what
		end,
		onTimeout = function(ctx)
			done()
			if not ctx.data.auto then return "skip", "the preview never showed (" .. tostring(ctx.data.waitWhy) .. ")" end
		end })
end

lookCheck(1, "rider", "em_look1", "Emblem look 1: Ring", "violet, small, just above your head")
lookCheck(2, "rider", "em_look2", "Emblem look 2: Orb", "violet, bigger and higher")
lookCheck(3, "rider", "em_look3", "Emblem look 3: Spark", "violet, small and faint")
lookCheck(1, "driver", "em_driver", "Emblem: the drivers' colour", "teal (not violet)")

L.AddCheck({ id = "em_plate", title = "Emblem over a nameplate", scene = "emblem", who = "driver", secs = 30, timeout = 180,
	click = "turn on friendly nameplates (Shift+V), stand near Farra Way and target her",
	when = function(ctx) if ctx.sim then return "skip", "test mode: nameplates can only be seen in game" end end,
	begin = function(ctx)
		if not show(1, "rider") then return "fail", "Wuber's emblem (W.Emblem) isn't loaded" end
	end,
	poll = function(ctx)
		local e = E()
		if not e then ctx.data.waitWhy = "W.Emblem is missing" return end
		local okP, on = pcall(e.Previewing)
		if okP and not on then show(1, "rider") end -- the preview ends after two minutes
		local okC, n = pcall(e.Count)
		if not (okC and type(n) == "number" and n > 0) then
			ctx.data.waitWhy = "no emblem on a nameplate yet (target a player whose nameplate shows)"
			return
		end
		ctx.data.auto = "on " .. n .. " nameplate(s), " .. shape(status())
	end,
	ask = function(ctx) return ctx.data.auto and "Is it floating just above your target's name, not covering it?" or nil end,
	answer = function(ctx, yes)
		local what = tostring(ctx.data.auto)
		done()
		return yes and "pass" or "fail", (yes and "Tester: yes; " or "Tester: placed wrong; ") .. what
	end,
	onTimeout = function(ctx)
		done()
		if not ctx.data.auto then return "skip", "no emblem on a nameplate (" .. tostring(ctx.data.waitWhy) .. ")" end
	end })
