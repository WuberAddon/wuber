-- Comfort and accessibility (job 2903): "Reduce motion" stops every animation that moves, grows, turns or loops.
-- While it is on, no animation group may START that has a Scale, Translation or Rotation animation, or that repeats; a
-- one-shot fade in place is what Reduce motion allows. The monitor wraps the fake game's AnimationGroup:Play, the tour
-- walks every screen of both sides (the lab's photo tour), then toasts and the minimap button are poked directly.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/Photo.lua") then
	test("comfort.motion: Wuber Lab's Photo.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

-- who started it: the first Wuber line of the Lua stack, "Wuber/UI/Rider/Home.lua:576"
local function who()
	local tb = debug.traceback("", 3)
	for line in tb:gmatch("[^\n]+") do
		local f, n = line:match("(Wuber[/\\][%w_/\\%.]+):(%d+):")
		if f and not f:find("Theme[/\\]Anim") then return (f:gsub("\\", "/")) .. ":" .. n end
	end
	local f, n = tb:match("(Wuber[/\\][%w_/\\%.]+):(%d+):")
	return f and ((f:gsub("\\", "/")) .. ":" .. n) or "?"
end

-- names the line that made each group (set before the client loads, so the groups made at login are named too)
local function naming()
	local origin = setmetatable({}, { __mode = "k" })
	local mk = H.newAnimGroup
	H.newAnimGroup = function(...)
		local g = mk(...)
		origin[g] = who()
		return g
	end
	return origin, function() H.newAnimGroup = mk end
end

local function install(c, found, origin)
	if type(c.playing) ~= "table" then return false end
	local real = c.playing
	local function record(g)
		local W = c.W
		if not (W.db and W.db.reduceMotion == true) then return end
		local why
		local okL, loop = pcall(g.GetLooping, g)
		if okL and loop ~= "NONE" then why = "repeats (" .. tostring(loop) .. ")" end
		local okA, anims = pcall(function() return { g:GetAnimations() } end)
		-- what really moves, grows or turns (a Translation of 0 px or a Scale of 1 to 1 is a fade in place: allowed)
		for _, an in ipairs(okA and anims or {}) do
			local kind = an:GetObjectType()
			if kind == "Translation" then
				local x, y = an:GetOffset()
				if math.abs(x or 0) > 0.5 or math.abs(y or 0) > 0.5 then why = why or "slides" end
			elseif kind == "Scale" then
				local fx, fy = an:GetScaleFrom()
				local tx, ty = an:GetScale()
				if math.abs((tx or 1) - (fx or 1)) > 0.001 or math.abs((ty or 1) - (fy or 1)) > 0.001 then why = why or "grows or shrinks" end
			elseif kind == "Rotation" then
				if math.abs(an:GetDegrees() or 0) > 0.5 then why = why or "turns" end
			elseif kind == "Path" or kind == "LineScale" or kind == "LineTranslation" then
				why = why or ("a " .. kind .. " animation")
			end
		end
		if why then
			local trail = {}
			for line in debug.traceback("", 2):gmatch("[^\n]+") do
				local f, n = line:match("(Wuber[/\\][%w_/\\%.]+):(%d+):")
				if f and #trail < 4 then trail[#trail + 1] = (f:gsub("\\", "/")):gsub("^Wuber/", "") .. ":" .. n end
			end
			local key = (origin[g] or "(made before the tour)") .. " " .. why .. " <- " .. table.concat(trail, " <- ")
			found[key] = (found[key] or 0) + 1
		end
	end
	c.playing = setmetatable({}, { __newindex = function(t, g, v) rawset(t, g, v) if v then pcall(record, g) end end })
	for g, v in pairs(real) do rawset(c.playing, g, v) end
	return function() c.playing = real end
end

local function list(found)
	local out = {}
	for k, n in pairs(found) do out[#out + 1] = k .. " x" .. n end
	table.sort(out)
	return table.concat(out, "\n  ")
end

-- the client with the monitor on from its first frame (so every group is named by the line that made it)
local function client(w, name, class, found, motion)
	local origin, unname = naming()
	local c = w:addClient(name, { spot = "Undercity", class = class, money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	local undo0 = install(c, found, origin)
	local undo = function() undo0() unname() end
	ok(undo0, "control: the monitor is installed")
	if c.W.db then c.W.db.reduceMotion = motion end
	T.settle(w)
	c.W.db.reduceMotion = motion
	flagWanted = motion
	-- as the settings switch does when it is turned on: what already runs (a pulse started at login) stops
	if motion then c.W.Fire("SETTINGS", "reduceMotion") end
	return c, undo
end

local flagWanted
local function tour(c, w)
	local L = c.ns.WuberLab
	ok(L.TourStart(), "the tour started")
	for _ = 1, 900 do
		if not L.Touring() then break end
		if c.W.db and flagWanted ~= nil then c.W.db.reduceMotion = flagWanted end -- the tour swaps saved data in and out: keep the switch as the player set it
		w:advance(1)
	end
end

for _, side in ipairs({ { "Wuber Rocks", "MAGE", "a rider" }, { "Anita Lift", "WARLOCK", "a driver" } }) do
	test("comfort.motion: Reduce motion on, " .. side[3] .. "'s whole tour starts no moving, growing, turning or repeating animation", function()
		local w = T.newWorld()
		local found = {}
		local c, undo = client(w, side[1], side[2], found, true)
		c.W.UI.Toast("Reduce motion check", "info")
		c.W.UI.Toast("Reduce motion check", "warn")
		w:advance(3)
		tour(c, w)
		undo()
		eq(list(found), "", "animations that start while Reduce motion is on:\n  " .. list(found))
		T.clean(w)
	end)
end

test("comfort.motion: control: with Reduce motion OFF the monitor sees the animations that start (so the empty list above means something)", function()
	local w = T.newWorld()
	local found = {}
	local c, undo = client(w, "Wuber Rocks", "MAGE", found, false)
	c.W.db.reduceMotion = true -- the monitor only counts while it is on: switch it on for the opening of the window
	c.W.UI.Toggle(true)
	w:advance(3)
	undo()
	ok(next(found) ~= nil, "the monitor saw animations start when the window opened")
	T.clean(w)
end)
