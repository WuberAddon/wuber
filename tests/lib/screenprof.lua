-- tests/lib/screenprof.lua: what one screen change costs in the fake game (job 2749, speed; tools/profile-tests.lua --screens).
--   local P = dofile(root .. "/tests/lib/screenprof.lua")(H)
--   local sess = P.session(client)        -- counts this client's widget calls until sess:close()
--   local m = sess:measure(function() UI.SelectTab("Trips") end, { settle = 1, deep = false })
--   sess:close()                          -- puts the harness's methods back (other tests see the plain fake)
-- m (one change):
--   ms        Lua CPU ms of the change itself (os.clock; the fake's own checks included: compare, don't quote)
--   settleMs  CPU ms of the settle that follows (opts.settle game seconds of frames: animations, timers)
--   kb        KB allocated by the change (GC stopped while it runs; fake widgets included)
--   new       widgets created: { Frame = n, FontString = n, Texture = n, ... } and newTotal
--   calls     widget calls by this client: setPoint (SetPoint/SetAllPoints), clearPoints, setText, setSize
--             (SetSize/SetWidth/SetHeight), measure (GetStringWidth/Height, GetUnboundedStringWidth), show, hide, setFont, alpha
--   idleUpdates  OnUpdate scripts that run every frame after the settle (shown frames with one), idleSrc their file:line
--   idleAnims    animation groups still playing after the settle
--   hot       (opts.deep) the addon functions called most: { { where, name, calls } }, layout = calls to functions
--             named *layout*/*Layout*/relayout/reflow (the layout passes)
-- Counting wraps the harness's widget methods with tail calls (no extra stack level: error levels and the API report
-- lines stay right) only while a session is open.
return function(H)
local S = H.state
local P = {}

local function upvalue(fn, name)
	if type(fn) ~= "function" then return nil end
	local i = 1
	while true do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v end
		i = i + 1
	end
end
-- the harness's class tables (local in harness.lua): H.newWidget -> meta -> classes; searched through the upvalues
-- (a few levels) because a full run may have wrapped H.newWidget or H.createFrame
local function findClasses()
	local seen = {}
	local function visit(fn, depth)
		if type(fn) ~= "function" or seen[fn] or depth > 5 then return nil end
		seen[fn] = true
		local i = 1
		while true do
			local n, v = debug.getupvalue(fn, i)
			if not n then return nil end
			if n == "classes" and type(v) == "table" and type(v.Frame) == "table" then return v end
			if type(v) == "function" then
				local r = visit(v, depth + 1)
				if r then return r end
			end
			i = i + 1
		end
	end
	return visit(H.newWidget, 0) or visit(H.createFrame, 0)
end
local classes = upvalue(upvalue(H.newWidget, "meta"), "classes") or findClasses()
P.ok = type(classes) == "table"

local COUNTED = {
	SetPoint = "setPoint", SetAllPoints = "setPoint", ClearAllPoints = "clearPoints",
	SetText = "setText", SetSize = "setSize", SetWidth = "setSize", SetHeight = "setSize",
	GetStringWidth = "measure", GetStringHeight = "measure", GetUnboundedStringWidth = "measure",
	Show = "show", Hide = "hide", SetFont = "setFont", SetAlpha = "alpha",
}
P.KEYS = { "setPoint", "clearPoints", "setText", "setSize", "measure", "show", "hide", "setFont", "alpha" }

local active -- { client, n }
local saved -- { { class, method, original } }

local function wrap()
	if saved or not classes then return end
	saved = {}
	for _, c in pairs(classes) do
		for m, key in pairs(COUNTED) do
			local f = rawget(c, m)
			if type(f) == "function" then
				saved[#saved + 1] = { c, m, f }
				c[m] = function(self, ...)
					local a = active
					if a then
						local s = S[self]
						if s and s.client == a.client then a.n[key] = (a.n[key] or 0) + 1 end
					end
					return f(self, ...)
				end
			end
		end
	end
end
local function unwrap()
	if not saved then return end
	for _, x in ipairs(saved) do x[1][x[2]] = x[3] end
	saved = nil
end

local function addonSrc(src)
	src = tostring(src or ""):gsub("\\", "/")
	if src:find("WuberLab", 1, true) then return nil end
	local p = src:match("(Wuber/.*)$")
	return p
end

-- OnUpdate scripts that run each frame now (shown frames), and animations playing
function P.idle(c)
	local n, src = 0, {}
	for _, f in ipairs(c.updaters or {}) do
		local s = S[f]
		if s and s.scripts.OnUpdate and H.visible(f) then
			local i = debug.getinfo(s.scripts.OnUpdate, "S")
			local where = i and addonSrc(i.source)
			if where then
				n = n + 1
				src[#src + 1] = where .. ":" .. tostring(i.linedefined)
			end
		end
	end
	local anims = 0
	for g in pairs(c.playing or {}) do anims = anims + 1 end
	table.sort(src)
	return n, src, anims
end

local LAYOUT = { "layout", "Layout", "relayout", "Relayout", "reflow", "Reflow" }
local function isLayout(name)
	if not name then return false end
	for _, p in ipairs(LAYOUT) do if name:find(p, 1, true) then return true end end
	return false
end

local Sess = {}
Sess.__index = Sess

function P.session(c)
	wrap()
	return setmetatable({ c = c, w = c.world }, Sess)
end

function Sess:close() active = nil debug.sethook() unwrap() end

function Sess:measure(fn, o)
	o = o or {}
	local c, w = self.c, self.w
	local a = { client = c, n = {} }
	local w0 = #c.widgets
	collectgarbage("collect")
	collectgarbage("stop")
	local kb0 = collectgarbage("count")
	local fcalls, fname = {}, {}
	if o.deep then
		debug.sethook(function()
			local i = debug.getinfo(2, "Sn")
			local where = i and addonSrc(i.source)
			if where then
				local k = where .. ":" .. tostring(i.linedefined)
				fcalls[k] = (fcalls[k] or 0) + 1
				if i.name and not fname[k] then fname[k] = i.name end
			end
		end, "c")
	end
	active = a
	local t0 = os.clock()
	local ok, err = pcall(fn)
	local ms = (os.clock() - t0) * 1000
	local kb = collectgarbage("count") - kb0
	local t1 = os.clock()
	if (o.settle or 1) > 0 then w:advance(o.settle or 1) end
	local settleMs = (os.clock() - t1) * 1000
	active = nil
	debug.sethook()
	collectgarbage("restart")
	local m = { ms = ms, settleMs = settleMs, kb = kb, ok = ok, err = (not ok) and tostring(err) or nil, calls = a.n, new = {}, newTotal = #c.widgets - w0 }
	for i = w0 + 1, #c.widgets do
		local s = S[c.widgets[i]]
		local t = s and s.otype or "?"
		m.new[t] = (m.new[t] or 0) + 1
	end
	m.idleUpdates, m.idleSrc, m.idleAnims = P.idle(c)
	if o.deep then
		local list, layout = {}, 0
		for k, n in pairs(fcalls) do
			list[#list + 1] = { where = k, name = fname[k], calls = n }
			if isLayout(fname[k]) then layout = layout + n end
		end
		table.sort(list, function(x, y) if x.calls ~= y.calls then return x.calls > y.calls end return x.where < y.where end)
		m.hot, m.layout = list, layout
	end
	return m
end

return P
end
