-- A small World of Warcraft: Forever (1.60.1) for Wuber's tests.
--
-- One World holds the players, the chat channels, groups, summons, trades and the clock.
-- Each game window is a Client: the addons' files are loaded into an environment of its own,
-- with the game API answered from the World. Bots (players without a client) play extras.
--
-- The rules the real client enforces are enforced here, and breaking one is recorded in
-- world.violations (the tests assert it stays empty):
--   * chat lines (SendChatMessage) are blocked for addons; a whisper goes out only from a
--     secure macro button clicked by the player. ONE exception (Wuber 2.4, the author's rule of
--     21 Nov 2026): the auto-reply whisper from Wuber/Drive/AutoReply.lua, inside the limits of
--     H.replyRule (a whisper only, a full two-part name, nobody in the group, never in combat, a
--     raid or an instance, once per player per hour). A SECOND and last exception (the decisions
--     round, the author's yes of 21 Nov 2026 22:28): a line Wuber sends by itself from
--     Wuber/Drive/AutoLines.lua, inside the limits of H.linesRule (a whisper only, only to a rider
--     on the sender's own list who asked by the app or a whisper and is in the sender's group,
--     never in combat, a raid or an instance, paced). Anything else is a violation as before;
--   * protected frames (secure buttons, and every frame holding one) can't be changed in combat;
--   * AcceptTrade needs a hardware click (AcceptGroup and ConfirmSummon do not: measured, opts.acceptGroupNeedsClick / confirmSummonNeedsClick bring the strict rule back);
--   * addon messages: 255 bytes at most (an error, as in the client), a throttle;
--   * macros: 255 characters at most.
-- Script, timer and event errors are caught (as the client would show them) and recorded in
-- world.errors. The frame API is strict: a widget method the fake doesn't define is nil (so
-- calling it is an error naming it) and is listed in H.unknown for the report.

local H = {}
-- (REC realm.name.empty71037, measured on build 71037 since 20 Nov, four accounts) the game names no realm: "".
-- A test that needs a realm gives the world (opts.realm) or the client (opts.realm) one, e.g. H.FOUNDER_REALM.
H.DEFAULT_REALM = ""
H.FOUNDER_REALM = "CAMWOW EU5 Realm 5 PvE" -- the founders' ruleset (EU Normal), as named before build 71037

---------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------

local here = (arg and arg[0] or "tests/run.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
H.root = here .. "/.."

local function exists(path)
	local f = io.open(path, "rb")
	if f then f:close() return true end
	-- Windows cannot io.open a folder (Linux can): a path ending in a slash is checked as a folder there
	if package.config:sub(1, 1) == "\\" and path:find("[/\\]$") then
		local p = io.popen('if exist "' .. path:gsub("/", "\\") .. '*" echo 1')
		local out = p and p:read("*a") or ""
		if p then p:close() end
		return out:find("1", 1, true) ~= nil
	end
	return false
end
H.exists = exists

-- Paths are relative to the repo (SPEC5 paths, review #30: the suite runs from any checkout).
-- "RitualRides" (loadRR = "1.4.1") is a small stand-in written for these tests, in tests/fixtures/addons/OldDriver:
-- an old driver addon still installed next to Wuber. The real old addon is not needed and not in the repository.
H.ADDONS = {
	Wuber = H.root .. "/Wuber",
	RitualRides = here .. "/fixtures/addons/OldDriver",
	Wuber1 = here .. "/round1/Wuber", -- round one as installed (17 Nov 20:49): a real old peer
}

-- Ritual Rides 1.5.0 (RitualRides = { retired = true }): the repo's own copy
H.RR_TOMBSTONE = H.root .. "/tools/RitualRides"

-- The files in a folder with this extension ("tga"), with no shell of either kind assumed:
-- `dir /b` on Windows, `ls -1` elsewhere. Full paths, sorted.
function H.listFiles(dir, ext)
	local windows = package.config:sub(1, 1) == "\\"
	local cmd = windows and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('ls -1 "' .. dir .. '" 2>/dev/null')
	local p = io.popen(cmd)
	local out = {}
	if not p then return out end
	for name in p:read("*a"):gmatch("[^\r\n]+") do
		if not ext or name:lower():match("%." .. ext:lower() .. "$") then out[#out + 1] = dir .. "/" .. name end
	end
	p:close()
	table.sort(out)
	return out
end

-- An addon's TOC field ("OptionalDeps", "Dependencies"...) as a list of names
function H.tocField(addon, field, dirOverride)
	local dir = dirOverride or H.ADDONS[addon]
	local f = dir and io.open(dir .. "/" .. addon .. ".toc", "r")
	if not f then return {} end
	local out = {}
	for line in f:lines() do
		local k, v = line:gsub("\r", ""):match("^##%s*([%w]+)%s*:%s*(.-)%s*$")
		if k == field then for n in v:gmatch("[^,%s]+") do out[#out + 1] = n end end
	end
	f:close()
	return out
end

-- The order the game loads addons in: by name, each one's dependencies (and optional
-- dependencies that are enabled) first; a dependency already being loaded is skipped.
function H.loadOrder(addons, dirs)
	local want, out, state = {}, {}, {}
	for _, a in ipairs(addons) do want[a] = true end
	local names = { unpack(addons) }
	table.sort(names)
	local function load(a)
		if state[a] then return end
		state[a] = "loading"
		local deps = H.tocField(a, "Dependencies", dirs and dirs[a])
		for _, d in ipairs(H.tocField(a, "RequiredDeps", dirs and dirs[a])) do deps[#deps + 1] = d end
		for _, d in ipairs(H.tocField(a, "OptionalDeps", dirs and dirs[a])) do deps[#deps + 1] = d end
		for _, d in ipairs(deps) do if want[d] then load(d) end end
		out[#out + 1] = a
		state[a] = "done"
	end
	for _, a in ipairs(names) do load(a) end
	return out
end

-- the .lua files of an addon's TOC, in order
function H.tocFiles(addon, dirOverride)
	local dir = dirOverride or H.ADDONS[addon]
	local out = {}
	local f = io.open(dir .. "/" .. addon .. ".toc", "r")
	if not f then return nil end
	for line in f:lines() do
		line = line:gsub("\r", ""):gsub("%s+$", ""):gsub("^%s+", "")
		-- "/" paths (the TOC may use the game's "\\" in folder paths: Core\\Base.lua)
		if line ~= "" and not line:match("^#") then out[#out + 1] = (line:gsub("\\", "/")) end
	end
	f:close()
	return out, dir
end

-- where an old (2.2.1) file's code lives now: tests/lib/files.lua (REFACTOR-MAP 4.1)
do
	local self = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
	local libDir = (self:match("^(.*)/[^/]*$") or here) .. "/lib"
	H.F = dofile(libDir .. "/files.lua").init(H)
end

---------------------------------------------------------------------------
-- Secret values
---------------------------------------------------------------------------
-- A value the client hides. Using it is an error, as in the game: it may only be stored and
-- handed to issecretvalue. (Plain Lua cannot make "== nil" or "if v" fail.)

local function forbidden() H.rule("secret.use-raises") error("the addon used a secret value", 2) end
local SECRET = newproxy(true)
do
	local mt = getmetatable(SECRET)
	mt.__tostring = function() return "<secret>" end
	mt.__index = forbidden
	mt.__newindex = forbidden
	mt.__call = forbidden
	mt.__concat = forbidden
	mt.__len = forbidden
	mt.__add = forbidden
	mt.__sub = forbidden
	mt.__mul = forbidden
	mt.__div = forbidden
	mt.__mod = forbidden
	mt.__pow = forbidden
	mt.__unm = forbidden
	mt.__lt = forbidden
	mt.__le = forbidden
	mt.__eq = forbidden
end
H.SECRET = SECRET
-- (#233) tests/fixtures/secret-api.lua, read where the file's folder is known (H.SECRET_API, H.SECRET_METHODS)
H.SECRET_METHODS = {}

-- Evidence ledger (job 2882, tests/fixtures/client/rules.lua, tools/evidence-report.lua): a fake-game rule that rests on a claim about the
-- real client calls H.rule with its id on its code path. Only a counter: it adds the hit to the test now running (H.testName), nothing else.
-- WUBER_RULE_LOG=<file> makes tests/run.lua append "<id><TAB><test><TAB><count>" lines at its end (H.ruleDump); the report reads them.
H.ruleHits = {}
function H.rule(id)
	local r = H.ruleHits[id]
	if not r then r = { n = 0, tests = {} } H.ruleHits[id] = r end
	r.n = r.n + 1
	local t = H.testName or "(outside a test)"
	r.tests[t] = (r.tests[t] or 0) + 1
end
function H.ruleDump(path)
	local f = path and io.open(path, "ab")
	if not f then return false end
	for id, r in pairs(H.ruleHits) do
		for t, n in pairs(r.tests) do f:write(id, "\t", (t:gsub("[\t\r\n]", " ")), "\t", n, "\n") end
	end
	f:close()
	return true
end

---------------------------------------------------------------------------
-- What the report lists
---------------------------------------------------------------------------

H.unknown = {}    -- "Type:Method" the addon looked up on a widget and the fake lacks
H.uncertain = {}  -- "Type:Method" / "Api" the addon used that may not exist in the real 1.60.1 client
H.missingGlobals = {} -- global names the addon read that the fake doesn't define

-- methods the fake has but which may not exist (or differ) in the real 1.60.1 client
local UNCERTAIN = {
	SetGradient = "signature differs between clients (modern: orientation, minColor, maxColor)",
	SetClipsChildren = "7.0+",
	SetRotation = "Texture:SetRotation 4.0+/modern",
	SetScaleFrom = "Scale animation, 7.1+",
	SetScaleTo = "Scale animation, 7.1+",
	SetChildKey = "Animation:SetChildKey 6.x+",
	SetTargetKey = "Animation:SetTargetKey 6.x+",
	SetIgnoreParentAlpha = "7.0+",
	SetIgnoreParentScale = "7.0+",
	GetUnboundedStringWidth = "7.0+",
	SetResizeBounds = "10.0+ / 1.14+",
	SetTextScale = "10.0+",
	SetSnapToPixelGrid = "8.0+",
	SetTexelSnappingBias = "8.0+",
	SetFlattensRenderLayers = "8.0+",
	SetToFinalAlpha = "6.x+",
	AdjustPointsOffset = "8.0+",
	ClearPointsOffset = "8.0+",
	SetFixedFrameStrata = "8.0+",
	SetFixedFrameLevel = "8.0+",
	SetPropagateKeyboardInput = "protected in combat on some clients",
	SetCountInvisibleLetters = "old",
	CreateLine = "7.0+",
	SetDesaturation = "8.0+",
	SetVertexOffset = "8.0+",
	GetCanvasScale = "MapCanvasScrollControllerMixin (Blizzard Lua, modern map)",
	SetTextToFit = "Blizzard mixin",
	SetMotionScriptsWhileDisabled = "4.0+",
	GetTextWidth = "Button:GetTextWidth",
	SetRadians = "Rotation animation",
	SetEndDelay = "",
	SetObeyStepOnDrag = "Slider, 7.0+",
	SetPlaying = "AnimationGroup:SetPlaying 10.0+",
	GetPointByName = "10.0+",
	-- models and ModelScenes: guarded no-ops here; what they draw can only be seen in game
	SetModel = "Model:SetModel (file paths differ between clients)", SetDisplayInfo = "Model:SetDisplayInfo",
	SetCreature = "Model:SetCreature", SetUnit = "Model:SetUnit", SetCamDistanceScale = "Model", SetPortraitZoom = "Model",
	SetSpellVisualKit = "Model/Actor:SetSpellVisualKit 8.0+", CreateActor = "ModelScene 7.0+",
	SetCameraPosition = "ModelScene", SetCameraOrientationByYawPitchRoll = "ModelScene", SetCameraFieldOfView = "ModelScene",
	SetModelByFileID = "ModelSceneActor", SetModelByCreatureDisplayID = "ModelSceneActor", SetModelByUnit = "ModelSceneActor",
	SetYaw = "ModelSceneActor", SetPitch = "ModelSceneActor", SetRoll = "ModelSceneActor", PlayAnimationKit = "ModelSceneActor 9.0+",
	SetFlipBookRows = "FlipBook animation 10.0+", SetFlipBookColumns = "FlipBook animation 10.0+",
	SetFlipBookFrames = "FlipBook animation 10.0+", SetFlipBookFrameWidth = "FlipBook animation 10.0+",
	SetFlipBookFrameHeight = "FlipBook animation 10.0+",
}

local function noteUncertain(kind, name)
	if UNCERTAIN[name] then H.uncertain[kind .. ":" .. name] = UNCERTAIN[name] end
end

-- Which addon file (and line) is running code at a stack level, or nil for the harness.
function H.caller(level)
	local info = debug.getinfo((level or 2) + 1, "Sl")
	if not info then return nil end
	local src = info.source or ""
	for name, dir in pairs(H.ADDONS) do
		local at = src:find(dir, 1, true)
		if at then return name .. "/" .. src:sub(at + #dir + 1) .. ":" .. tostring(info.currentline) end
	end
	return nil
end

-- What the addons used: H.used.method[name] / H.used.api[name] = "File.lua:line" (first use)
H.used = { method = {}, api = {} }
function H.noteUse(kind, name, owner, level)
	local t = H.used[kind]
	if t[name] then return end
	local who = H.caller((level or 2) + 1)
	if not who then return end
	t[name] = who .. (owner and (" (" .. owner .. ")") or "")
	if kind == "method" then noteUncertain(owner or "?", name) end
end

-- What was proven in game: every name Ritual Rides 1.3.0 and the Wuber Test addon use, and
-- the "Client facts" section of SPEC.md.
H.proven = {}
do
	local function scan(text)
		for name in text:gmatch("[%a_][%w_]*") do H.proven[name] = true end
	end
	local function read(path)
		local f = io.open(path, "r")
		if not f then return nil end
		local t = f:read("*a")
		f:close()
		return t
	end
	local rr = H.root .. "/ref/RitualRides-1.3.0/RitualRides/"
	for _, file in ipairs({ "Button.lua", "Chat.lua", "Comm.lua", "Commands.lua", "Core.lua", "Panel.lua", "Places.lua",
		"Queue.lua", "Service.lua", "Setup.lua", "Team.lua", "Trade.lua" }) do
		local t = read(rr .. file)
		if t then scan(t) end
	end
	local t = read(H.root .. "/ref/WuberTest.lua")
	if t then scan(t) end
	-- OpenMap's own API file: what OpenMapAPI offers (OpenMapAPI.X counts as proven)
	local om = read(H.root .. "/ref/OpenMap-API.lua")
	if om then for name in om:gmatch("function API%.([%w_]+)") do H.proven["OpenMapAPI." .. name] = true end end
	H.proven["OpenMapAPI.major"], H.proven["OpenMapAPI.version"] = true, true
	for i = 1, 10 do H.proven["ChatFrame" .. i] = true end -- WuberTest walks _G["ChatFrame" .. i]
	local spec = read(H.root .. "/SPEC.md")
	if spec then
		local facts = spec:match("## Client facts(.-)\n## ")
		if facts then scan(facts) end
	end
	H.provenLoaded = t ~= nil
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- widget -> its private state
H.state = S
H.fonts = setmetatable({}, { __mode = "k" }) -- font objects made by CreateFont (env.CreateFont)

-- Every client made since the last H.release(). A widget's state points back at the widget,
-- so the weak table alone never lets go (Lua 5.1 has no ephemerons): run.lua releases them
-- after each test, or the suite grows by gigabytes.
H.made = {}
-- (BRIEF21 S3, speed) Each addon file is compiled once per process, not once per window: the same
-- main chunk is given each window's environment (setfenv) and run again, which loads the file exactly as
-- a fresh loadfile would (the functions it makes take the environment it runs in). Kept by path and
-- text, so a file a test rewrites is compiled again. The text is read as loadfile reads it (text mode).
H.chunks = {}
function H.compiled(path)
	local f = io.open(path, "r")
	local src = f and f:read("*a")
	if f then f:close() end
	local hit = src and H.chunks[path]
	if hit and hit.src == src then return hit.fn end
	local chunk, err = loadfile(path)
	if chunk and src then H.chunks[path] = { src = src, fn = chunk } end
	return chunk, err
end

function H.release()
	H.forbidOrphans = {}
	for _, client in ipairs(H.made) do
		for _, obj in ipairs(client.widgets or {}) do S[obj] = nil end
		client.widgets, client.frames = {}, {}
	end
	H.made = {}
end

local classes = {}
H.classes = classes -- (surface guard hook 1/3)
local metas = {}
local function class(name, parent)
	local c = { __name = name, __parent = parent and classes[parent] or nil }
	classes[name] = c
	return c
end

local function lookup(c, k)
	while c do
		local v = c[k] -- class tables have no metatable: the same as rawget, without a call (BRIEF21 S3)
		if v ~= nil then return v end
		c = c.__parent
	end
	return nil
end

local function meta(name)
	if metas[name] then return metas[name] end
	local c = classes[name]
	local mt = {
		__index = function(t, k)
			local fs = S[t]
			if fs and fs.forbidden and k ~= "IsForbidden" and type(k) == "string" then
				-- a forbidden frame (a nameplate in an instance): addon code may not touch it
				local who = H.caller(2)
				if who then
					local w = fs.client.world
					w.violations[#w.violations + 1] = who .. ": touched a forbidden nameplate (" .. k .. ")"
					return function() error("Attempt to access forbidden object from code tainted by an AddOn", 2) end
				end
			end
			-- (#233) a foreign frame with a secret aspect (Client:secretFrame): the methods the client documents as
			-- secret answers (tests/fixtures/secret-api.lua) hand back a secret value, not the real one
			if fs and fs.secretAspect and type(k) == "string" and H.SECRET_METHODS[k] then
				return function() return SECRET end
			end
			local v = lookup(c, k)
			if v ~= nil then
				if H.used.method[k] == nil and type(k) == "string" then H.noteUse("method", k, name, 2) end
				return v
			end
			if type(k) == "string" and k:match("^%u") and k ~= "Text" and k ~= "Left" and k ~= "Right" and k ~= "Middle" then
				local who = H.caller(2)
				if who then H.unknown[name .. ":" .. k] = who end
			end
			return nil
		end,
		-- the taint guard: a field written onto a game frame by Wuber's code (a hook by assignment); the write itself goes on as before
		__newindex = function(t, k, v)
			if H.taint then H.taint.field(t, k) end
			rawset(t, k, v)
		end,
		__tostring = function(t)
			local s = S[t]
			return name .. "(" .. tostring(s and s.name or "anon") .. ")"
		end,
	}
	metas[name] = mt
	return mt
end

local function st(self)
	local s = S[self]
	if not s then error("a widget method was called on something that is not a widget (use ':' not '.')", 3) end
	return s
end

local function argerr(self, method, msg)
	error(("%s:%s(): %s"):format(st(self).otype, method, msg), 3)
end

local POINTS = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
	RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local STRATA = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8, BLIZZARD = 9 }
local LAYERS = { BACKGROUND = true, BORDER = true, ARTWORK = true, OVERLAY = true, HIGHLIGHT = true }
local BLEND = { DISABLE = true, BLEND = true, ALPHAKEY = true, ADD = true, MOD = true }
local SMOOTH = { NONE = true, IN = true, OUT = true, IN_OUT = true, OUT_IN = true }
local LOOPING = { NONE = true, REPEAT = true, BOUNCE = true }
local FONT_FLAGS = { [""] = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true, THICK = true }

local function isWidget(v) return type(v) == "table" and S[v] ~= nil end

-- the world a widget lives in (through its client)
local function worldOf(self) return st(self).client.world end

---------------------------------------------------------------------------
-- ScriptObject / Region (everything)
---------------------------------------------------------------------------

local Object = class("Object")

function Object:GetName() return st(self).name end
function Object:GetObjectType() return st(self).otype end
function Object:IsObjectType(t)
	local s = st(self)
	if s.otype == t then return true end
	local c = classes[s.otype]
	while c do
		if c.__name == t then return true end
		c = c.__parent
	end
	return (t == "Region" or t == "ScriptObject" or t == "Object")
end
function Object:IsForbidden() return st(self).forbidden == true end
function Object:GetParent() return st(self).parent end
function Object:GetDebugName() return tostring(st(self).name or st(self).otype) end

local Region = class("Region", "Object")

-- visibility
local function visible(obj)
	local s = S[obj]
	while s do
		if not s.shown then return false end
		if not s.parent then return true end
		s = S[s.parent]
	end
	return true
end
H.visible = visible

-- (BRIEF21 S5, BRIEF23 H3) What the game draws of a vertex colour's alpha. Seen in game twice (BRIEF19
-- F5, the Earnings period pills; BRIEF20 B1, the top nav), and settled by the in-game alpha probe of
-- 20 Nov: while an Alpha animation plays on a texture or a frame above it (A.SlideIn on every Drive
-- screen, fades), an alpha change is not taken; the colour (r, g, b) is. That is the default rule
-- (H.ALPHA_HOLD = "anim"). The probe also showed that an alpha change on a frame that was drawn and
-- then hidden, and on a hidden texture, IS taken, so the BRIEF21 guess that a texture the game had
-- drawn kept its alpha while not drawn (its window shut, or shown again in the same frame) is only an
-- opt-in: H.ALPHA_HOLD = "drawn" adds it to the animation rule; "off" takes every change (the fake
-- before BRIEF21). env WUBER_ALPHA_HOLD sets it for a run; a test may set H.ALPHA_HOLD and put it
-- back (the drawn bookkeeping below runs whatever the setting). Here: world.drawn
-- counts the frames drawn (World:frame); s.visAt is the count when a region last became visible
-- (s.bornAt: made visible; both cleared when it is hidden). s.drawnOnce ("the game has drawn it at
-- least once") is set lazily, not by walking every region each frame: when a region that was visible
-- over at least one frame is hidden (becameHidden), or when SetVertexColor finds it visible over a
-- frame (drawnNow); only the "drawn" rule reads it. The Alpha-animation hold holds on any texture. The alpha the
-- addon asked for is kept as s.vertexAsked (H.vertexAsked); world.alphaKept counts the calls kept,
-- by the addon line that made them.
local function drawCount(s)
	local c = s.client
	local w = c and c.world
	return w and w.drawn or 0
end
local function becameVisible(s) s.visAt = drawCount(s) end
-- only on a real visible -> hidden change; drawn when a frame passed while it was visible
local function becameHidden(s)
	local since = s.visAt or s.bornAt
	if since and drawCount(s) > since then s.drawnOnce = true end
	s.visAt, s.bornAt = nil, nil
end
-- true when the game draws this region now (visible, and a frame drawn since it showed)
local function drawnNow(obj)
	local s = S[obj]
	if not visible(obj) then return false end
	local since = s.visAt or s.bornAt
	if not since then
		-- visible by a way the harness did not note (a direct .shown): counted from now
		s.visAt = drawCount(s)
		return false
	end
	if drawCount(s) > since then
		s.drawnOnce = true
		return true
	end
	return false
end
H.drawnNow = drawnNow

-- (#232) What the screen shows of the addon right now: every FontString of this client that has words,
-- is shown (it and every parent), has an effective alpha above 0 and sits at least partly on the screen.
-- The sim evaluation of 26 Nov 2026 caught "Paused during combat" left drawn over Settings on 76b3b5a with
-- exactly this view of the scene; the fake game only looked at the one button. Each entry:
-- { text =, name = (own or nearest named parent), alpha = effective alpha, rect = {l, b, w, h} }.
-- opts.match: only entries whose text contains this plain string.
function H.drawnTexts(client, opts)
	opts = opts or {}
	local out = {}
	local up = client.env.UIParent
	local scr = up and H.rect(up)
	for _, obj in ipairs(client.widgets) do
		local s = S[obj]
		if s.otype == "FontString" then
			local txt = s.text
			if type(txt) == "string" and txt ~= "" and visible(obj) and obj:GetEffectiveAlpha() > 0
				and (not opts.match or txt:find(opts.match, 1, true)) then
				local r = H.rect(obj)
				local on = true
				if r and scr then on = r.l < scr.l + scr.w and r.l + r.w > scr.l and r.b < scr.b + scr.h and r.b + r.h > scr.b end
				if on then
					local nm, p = s.name, s.parent
					while not nm and p do nm = S[p].name p = S[p].parent end
					out[#out + 1] = { text = txt, name = nm, alpha = obj:GetEffectiveAlpha(), rect = r }
				end
			end
		end
	end
	return out
end
-- the texts of H.drawnTexts as a set (text -> true)
function H.drawnTextSet(client)
	local set = {}
	for _, e in ipairs(H.drawnTexts(client)) do set[e.text] = true end
	return set
end
-- an Alpha animation playing on this region or a frame above it
local function underAlphaAnim(obj)
	local s = S[obj]
	while s do
		for _, g in ipairs(s.animGroups or {}) do
			local gs = S[g]
			if gs.playing and not gs.paused then
				for _, a in ipairs(gs.anims) do if S[a].otype == "Alpha" then return true end end
			end
		end
		s = s.parent and S[s.parent]
	end
	return false
end
H.underAlphaAnim = underAlphaAnim

-- (BRIEF24 F1) the hold, shared by Layered:SetVertexColor and Region:SetAlpha on a texture (the probe showed
-- the game drops both under an Alpha animation): true when the game would not take an alpha change from old
-- to a. A held call is counted in world.alphaKept by the addon line that made it, and written to
-- WUBER_ALPHA_REPORT (once per line per run, with two callers and which call it was). The caller is three
-- levels up from here (this, the widget method, the addon line).
local function alphaHeld(obj, s, old, a, how)
	local mode = H.ALPHA_HOLD
	if not (mode == "anim" or mode == "drawn") or math.abs(old - a) <= 1e-6 then return false end
	local hold = (mode == "drawn" and s.drawnOnce ~= nil and not drawnNow(obj)) or underAlphaAnim(obj)
	if not hold then return false end
	local w = s.client and s.client.world
	if w then
		w.alphaKept = w.alphaKept or {}
		local who = H.caller(3) or "?"
		w.alphaKept[who] = (w.alphaKept[who] or 0) + 1
		-- WUBER_ALPHA_REPORT=<file>: each addon line (with two callers) whose alpha change the game would
		-- not draw, once per run; the chain is only built then
		local path = H.ALPHA_REPORT
		if path then
			local chain = {}
			for lv = 3, 5 do chain[#chain + 1] = H.caller(lv) end
			local line = (#chain > 0 and table.concat(chain, " <- ") or "?") .. " (" .. how .. ")"
			if not H.alphaReported[line] then
				H.alphaReported[line] = true
				local f = io.open(path, "a")
				if f then f:write(line, "\n") f:close() end
			end
		end
	end
	return true
end
H.alphaHeld = alphaHeld
H.ALPHA_HOLD = os.getenv("WUBER_ALPHA_HOLD") or "anim"
H.ALPHA_REPORT = os.getenv("WUBER_ALPHA_REPORT")
H.alphaReported = {}
-- (BRIEF24 F1) tests/fixtures/alpha-known.txt: held lines reported for the next round, skipped by the held-line checks
H.alphaKnown = {}
do
	local f = io.open("tests/fixtures/alpha-known.txt", "r")
	if f then
		for l in f:lines() do
			l = l:gsub("%s+$", "")
			if l ~= "" and not l:find("^#") then H.alphaKnown[l] = true end
		end
		f:close()
	end
end
-- the regions under root (root first) that are shown up to root
local function shownUpTo(f, root)
	local s = S[f]
	while s do
		if not s.shown then return false end
		if f == root then return true end
		f = s.parent
		s = f and S[f]
	end
	return false
end

-- every frame in a subtree (the frame first)
local function subtree(obj, out)
	out = out or {}
	out[#out + 1] = obj
	for _, c in ipairs(S[obj].children) do subtree(c, out) end
	return out
end

local function isProtected(obj)
	local s = S[obj]
	if s.secure then return true end
	for _, c in ipairs(s.children) do
		if S[c].kind == "frame" and isProtected(c) then H.rule("combat.protected-propagation") return true end
	end
	return false
end

local runScript -- forward

-- A toplevel frame (SetToplevel) is raised when it is shown or clicked, as the client does:
-- its level goes above every other shown frame in its strata, its own subtree moves with it
-- (explicit levels shift by the same amount), 10000 at most.
local function raiseFrame(obj)
	local s = S[obj]
	if not s or s.kind ~= "frame" or not s.client then return end
	local strata = obj:GetFrameStrata()
	local mine = {}
	for _, f in ipairs(subtree(obj)) do mine[f] = true end
	local top = -1
	for _, f in ipairs(s.client.frames or {}) do
		if not mine[f] and S[f].kind == "frame" and visible(f) and not S[f].isUIParent and f:GetFrameStrata() == strata then
			local l = f:GetFrameLevel()
			if l > top then top = l end
		end
	end
	local cur = obj:GetFrameLevel()
	if top < cur then return end
	local delta = math.min(10000, top + 1) - cur
	if delta <= 0 then return end
	for f in pairs(mine) do
		local fs = S[f]
		if f == obj then fs.level = cur + delta
		elseif fs.kind == "frame" and fs.level then fs.level = math.min(10000, fs.level + delta) end
	end
end
H.raiseFrame = raiseFrame

-- combat lockdown: a protected frame can't be changed by an addon
local function blocked(self, method)
	local s = st(self)
	local client = s.client
	if not client.player.combat then return false end
	if s.kind ~= "frame" or not isProtected(self) then return false end
	H.rule("combat.secure-frozen")
	local w = client.world
	w.violations[#w.violations + 1] = client.player.name .. ": " .. method .. "() on protected frame " .. tostring(s.name or s.otype) .. " in combat"
	client:fire("ADDON_ACTION_BLOCKED", client:callerAddon(), s.otype .. ":" .. method .. "()")
	return true
end

local function setShown(self, on, method)
	if blocked(self, method) then return end
	local s = st(self)
	on = on and true or false
	if s.shown == on then return end
	local before = {}
	local list = subtree(self)
	if s.kind == "frame" then
		for _, f in ipairs(list) do before[f] = visible(f) end
	end
	local wasVis = s.kind ~= "frame" and visible(self) -- (BRIEF21 S5) the region's own visibility before
	s.shown = on
	if s.kind ~= "frame" then
		-- (BRIEF21 S5) a region shown or hidden by itself: drawn from the next frame on, or no more
		local now = visible(self)
		if now and not wasVis then becameVisible(s) elseif wasVis and not now then becameHidden(s) end
		return
	end
	if on and s.toplevel and visible(self) then raiseFrame(self) end
	for _, f in ipairs(list) do
		local fs = S[f]
		if fs.kind ~= "frame" then
			local now = visible(f)
			if now ~= before[f] then if now then becameVisible(fs) else becameHidden(fs) end end
		end
	end
	for _, f in ipairs(list) do
		local now = visible(f)
		if now ~= before[f] and S[f].kind == "frame" then
			runScript(f, now and "OnShow" or "OnHide")
		end
	end
end

-- (design 4) Wuber's tips are drawn on its own card, the frame "WuberTip" (Theme.Widgets: T.TipShow), not on the
-- game's tooltip. Hundreds of tests ask "what does this control's tip say" by reading the game tooltip's state
-- (S[GameTooltip].tipLines, .tipMeta, .owner, .shown, GameTooltipTextLeftN). So that they keep asking the same
-- question, the fake game copies what the CARD really shows into that state each time the card is shown or
-- hidden: its visible texts in order (title, then lines), their colours, its owner. S[GameTooltip].wuberMirror
-- is the card while the copy is what the state holds (the layout engine and the renderer then draw the card
-- itself, not a made-up game tooltip). Nothing here calls the game tooltip's own methods or scripts.
function H.mirrorTip(card, on)
	local s = S[card]
	local c = s and s.client
	local gt = c and c.env and c.env.GameTooltip
	local g = gt and S[gt]
	if not g then return end
	if not on then
		if g.wuberMirror == card then
			g.wuberMirror = nil
			g.shown = false
		end
		return
	end
	local lines, meta = {}, {}
	local texts = { card.title }
	for _, fs in ipairs(type(card.lines) == "table" and card.lines or {}) do texts[#texts + 1] = fs end
	for _, fs in ipairs(texts) do
		local fss = S[fs]
		if fss and fss.shown and fss.text and fss.text ~= "" then
			lines[#lines + 1] = tostring(fss.text)
			local col = fss.textColor or { 1, 1, 1, 1 }
			meta[#lines] = { col[1], col[2], col[3], fss.wrap ~= false }
		end
	end
	g.tipLines, g.tipMeta, g.tipUnit = lines, meta, nil
	g.owner = card.owner
	g.tipAnchor = { card.anchor or "ANCHOR_RIGHT", 0, 0 }
	g.wuberMirror = card
	g.shown = true
	if H.syncTip then H.syncTip(gt) end
end
local function tipCard(self) return S[self] and S[self].name == "WuberTip" end
function Region:Show()
	setShown(self, true, "Show")
	if tipCard(self) then H.mirrorTip(self, true) end
end
function Region:Hide()
	-- a test (or the tour) that dismisses "the tooltip" by hiding the game's while it holds the card's copy means
	-- the tip that shows: the card goes too
	local card = S[self] and S[self].wuberMirror
	setShown(self, false, "Hide")
	if tipCard(self) then H.mirrorTip(self, false) end
	if card and S[card] and S[card].shown then card:Hide() end
end
function Region:SetShown(v)
	setShown(self, v, "SetShown")
	if tipCard(self) then H.mirrorTip(self, v and true or false) end
end
function Region:IsShown() return st(self).shown end
function Region:IsVisible() return visible(self) end

-- (BRIEF24 F1) a texture's own alpha is held as its vertex alpha is (alphaHeld: under an Alpha animation on it
-- or a frame above it; "drawn" adds that rule); GetAlpha returns the drawn alpha, H.alphaAsked(tex) the asked
-- one. A frame's or a font string's SetAlpha is always taken (the probe tested textures only).
local HELD_ALPHA = { Texture = true, Line = true, MaskTexture = true }
function Region:SetAlpha(a)
	if type(a) ~= "number" then argerr(self, "SetAlpha", "Usage: SetAlpha(alpha)") end
	local s = st(self)
	a = math.max(0, math.min(1, a))
	if HELD_ALPHA[s.otype] then
		s.alphaAsked = a
		if alphaHeld(self, s, s.alpha, a, "SetAlpha") then return end
	end
	s.alpha = a
end
function H.alphaAsked(region)
	local s = S[region]
	if not s then return 1 end
	return s.alphaAsked or s.alpha
end
function Region:GetAlpha() return st(self).alpha end
function Region:GetEffectiveAlpha()
	local a, s = 1, S[self]
	while s do
		a = a * s.alpha
		if not s.parent then break end
		s = S[s.parent]
	end
	return a
end
function Region:SetIgnoreParentAlpha(v) st(self).ignoreParentAlpha = v and true or false end
function Region:SetIgnoreParentScale(v) st(self).ignoreParentScale = v and true or false end

function Region:SetScale(scale)
	if blocked(self, "SetScale") then return end
	if type(scale) ~= "number" or scale <= 0 then argerr(self, "SetScale", "Scale must be > 0") end
	st(self).scale = scale
end
function Region:GetScale() return st(self).scale end
function Region:GetEffectiveScale() return H.effScale(self) end

function Region:SetParent(parent)
	if blocked(self, "SetParent") then return end
	if type(parent) == "string" then parent = st(self).client.env[parent] end
	if parent ~= nil and not isWidget(parent) then argerr(self, "SetParent", "Usage: SetParent(parent)") end
	if parent ~= nil and S[parent].forbidden then
		local w = st(self).client.world
		w.violations[#w.violations + 1] = tostring(H.caller(2) or "?") .. ": parented a frame to a forbidden nameplate"
		error("Attempt to access forbidden object from code tainted by an AddOn", 2)
	end
	local s = st(self)
	if parent ~= nil and H.taint then H.taint.parented(s.client, parent) end -- (the taint guard)
	local was = visible(self)
	if s.parent then
		local kids = S[s.parent].children
		for i, c in ipairs(kids) do if c == self then table.remove(kids, i) break end end
	end
	s.parent = parent
	if parent then table.insert(S[parent].children, self) end
	-- (BRIEF21 S5) a new parent can show or hide the whole subtree
	local now = visible(self)
	if now ~= was then
		for _, f in ipairs(subtree(self)) do
			if shownUpTo(f, self) then if now then becameVisible(S[f]) else becameHidden(S[f]) end end
		end
	end
end

-- anchors
local function relOf(self, rel, method)
	if rel == nil then return st(self).parent or st(self).client.env.UIParent end
	if type(rel) == "string" then
		local name = rel:gsub("%$parent", S[st(self).parent] and S[st(self).parent].name or "")
		local f = st(self).client.env[name]
		if not isWidget(f) then argerr(self, method, "Couldn't find region named '" .. rel .. "'") end
		return f
	end
	if not isWidget(rel) then argerr(self, method, "Usage: " .. method .. "(point [, relativeTo [, relativePoint]] [, offsetX, offsetY])") end
	if S[rel].forbidden then
		local w = st(self).client.world
		w.violations[#w.violations + 1] = tostring(H.caller(3) or "?") .. ": anchored a frame to a forbidden nameplate"
		error("Attempt to access forbidden object from code tainted by an AddOn", 3)
	end
	return rel
end

-- would anchoring self to rel make a loop?
local function dependsOn(rel, target, seen)
	if rel == target then return true end
	seen = seen or {}
	if seen[rel] then return false end
	seen[rel] = true
	for _, p in ipairs(S[rel].points) do
		if p.rel and dependsOn(p.rel, target, seen) then return true end
	end
	return false
end

function Region:SetPoint(point, a, b, c, d)
	if blocked(self, "SetPoint") then return end
	if type(point) ~= "string" or not POINTS[point:upper()] then argerr(self, "SetPoint", "Invalid anchor point " .. tostring(point)) end
	point = point:upper()
	local rel, relPoint, x, y
	if type(a) == "number" then
		x, y = a, b
	else
		rel, relPoint, x, y = a, b, c, d
		if type(relPoint) == "number" then relPoint, x, y = nil, relPoint, c end
	end
	rel = relOf(self, rel, "SetPoint")
	relPoint = relPoint and relPoint:upper() or point
	if not POINTS[relPoint] then argerr(self, "SetPoint", "Invalid relative point " .. tostring(relPoint)) end
	if x ~= nil and type(x) ~= "number" then argerr(self, "SetPoint", "offsetX must be a number") end
	if y ~= nil and type(y) ~= "number" then argerr(self, "SetPoint", "offsetY must be a number") end
	if rel == self then argerr(self, "SetPoint", "Cannot anchor to itself") end
	if rel and dependsOn(rel, self) then
		error("Action[SetPoint] failed because[Cannot anchor to a region dependent on it]: attempted from: " .. tostring(self), 2)
	end
	local s = st(self)
	for i, p in ipairs(s.points) do
		if p.point == point then table.remove(s.points, i) break end
	end
	s.points[#s.points + 1] = { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
end

function Region:SetAllPoints(rel)
	if blocked(self, "SetAllPoints") then return end
	rel = relOf(self, rel, "SetAllPoints")
	if rel == self then argerr(self, "SetAllPoints", "Cannot anchor to itself") end
	if dependsOn(rel, self) then error("Action[SetAllPoints] failed because[Cannot anchor to a region dependent on it]", 2) end
	st(self).points = {
		{ point = "TOPLEFT", rel = rel, relPoint = "TOPLEFT", x = 0, y = 0 },
		{ point = "BOTTOMRIGHT", rel = rel, relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
	}
end
function Region:ClearAllPoints()
	if blocked(self, "ClearAllPoints") then return end
	st(self).points = {}
end
function Region:GetNumPoints() return #st(self).points end
function Region:GetPoint(i)
	local p = st(self).points[i or 1]
	if not p then return end -- the game answers no values at all (MayReturnNothing)
	return p.point, p.rel, p.relPoint, p.x, p.y
end
function Region:GetPointByName(name)
	for _, p in ipairs(st(self).points) do
		if p.point == name then return p.point, p.rel, p.relPoint, p.x, p.y end
	end
end
function Region:AdjustPointsOffset(dx, dy)
	for _, p in ipairs(st(self).points) do p.x, p.y = p.x + dx, p.y + dy end
end
function Region:ClearPointsOffset()
	for _, p in ipairs(st(self).points) do p.x, p.y = 0, 0 end
end
function Region:IsAnchoringRestricted() return false end

local function setW(self, w, method)
	if blocked(self, method) then return end
	if type(w) ~= "number" then argerr(self, method, "Usage: " .. method .. "(width)") end
	local s = st(self)
	local old = s.w
	s.w = w
	if old ~= w and s.kind == "frame" then runScript(self, "OnSizeChanged", s.w or 0, s.h or 0) end
end
local function setH(self, h, method)
	if blocked(self, method) then return end
	if type(h) ~= "number" then argerr(self, method, "Usage: " .. method .. "(height)") end
	local s = st(self)
	local old = s.h
	s.h = h
	if old ~= h and s.kind == "frame" then runScript(self, "OnSizeChanged", s.w or 0, s.h or 0) end
end
function Region:SetWidth(w) setW(self, w, "SetWidth") end
function Region:SetHeight(h) setH(self, h, "SetHeight") end
function Region:SetSize(w, h)
	if blocked(self, "SetSize") then return end
	if type(w) ~= "number" or type(h) ~= "number" then argerr(self, "SetSize", "Usage: SetSize(width, height)") end
	local s = st(self)
	local changed = s.w ~= w or s.h ~= h
	s.w, s.h = w, h
	if changed and s.kind == "frame" then runScript(self, "OnSizeChanged", w, h) end
end

-- A small layout engine. Positions are kept in screen units (UIParent's at scale 1); a
-- frame's own numbers (offsets, sizes, GetLeft...) are in its units: screen / effective scale.
local function effScale(obj)
	local sc, s = 1, S[obj]
	while s do
		sc = sc * (s.scale or 1)
		if not s.parent then break end
		s = S[s.parent]
	end
	return sc
end
H.effScale = effScale

local function rect(obj, depth)
	depth = (depth or 0) + 1
	if depth > 60 then return nil end
	local s = S[obj]
	local e = effScale(obj)
	if s.isUIParent then return { l = 0, b = 0, w = s.w * e, h = s.h * e } end
	if #s.points == 0 then return nil end
	local left, right, cx, top, bottom, cy
	for _, p in ipairs(s.points) do
		local r = rect(p.rel, depth)
		if not r then return nil end
		local rp, pp = POINTS[p.relPoint], POINTS[p.point]
		local ax = r.l + rp[1] * r.w + p.x * e
		local ay = r.b + rp[2] * r.h + p.y * e
		if pp[1] == 0 then left = ax elseif pp[1] == 1 then right = ax else cx = ax end
		if pp[2] == 0 then bottom = ay elseif pp[2] == 1 then top = ay else cy = ay end
	end
	local ownW = s.w or (s.textWidth and s.textWidth(obj)) or 0
	local ownH = s.h or (s.textHeight and s.textHeight(obj)) or 0
	local w = (left and right) and (right - left) or ownW * e
	local h = (top and bottom) and (top - bottom) or ownH * e
	local l = left or (right and right - w) or (cx and cx - w / 2) or 0
	local b = bottom or (top and top - h) or (cy and cy - h / 2) or 0
	return { l = l, b = b, w = w, h = h }
end
H.rect = rect
function H.STRATA_RANK(strata) return STRATA[strata] or -1 end

function Region:GetWidth()
	local s = st(self)
	if s.w and not (#s.points >= 2) then return s.w end
	local r = rect(self)
	if r then return r.w / effScale(self) end
	return s.w or (s.textWidth and s.textWidth(self)) or 0
end
function Region:GetHeight()
	local s = st(self)
	if s.h and not (#s.points >= 2) then return s.h end
	local r = rect(self)
	if r then return r.h / effScale(self) end
	return s.h or (s.textHeight and s.textHeight(self)) or 0
end
function Region:GetSize() return self:GetWidth(), self:GetHeight() end
local function own(self)
	local r = rect(self)
	if not r then return nil end
	local e = effScale(self)
	return { l = r.l / e, b = r.b / e, w = r.w / e, h = r.h / e }
end
function Region:GetCenter()
	local r = own(self)
	if not r then return end -- (unplaced: no values, as the game; A1)
	return r.l + r.w / 2, r.b + r.h / 2
end
function Region:GetLeft() local r = own(self) if r then return r.l end end
function Region:GetRight() local r = own(self) if r then return r.l + r.w end end
function Region:GetTop() local r = own(self) if r then return r.b + r.h end end
function Region:GetBottom() local r = own(self) if r then return r.b end end
function Region:GetRect()
	local r = own(self)
	if not r then return end
	return r.l, r.b, r.w, r.h
end
function Region:GetScaledRect()
	local r = rect(self)
	if not r then return end
	return r.l, r.b, r.w, r.h
end
-- Plain geometry once the mouse has been moved to a point (Client:moveMouse): the game's IsMouseOver ranks nothing (a frame covered
-- by another is still over) and does not know clipping (a frame cut off by a clipping ancestor is still over). Before any
-- moveMouse a test names the frame itself (client.mouseOver, or a click): that frame and its ancestors are over.
function Region:IsMouseOver()
	local c = st(self).client
	local at = c.mouseAt
	if at and c.mouseOver == at.focus then
		local r = rect(self)
		return r ~= nil and at.x >= r.l and at.x <= r.l + r.w and at.y >= r.b and at.y <= r.b + r.h
	end
	local over = c.mouseOver
	while over do
		if over == self then return true end
		over = S[over] and S[over].parent
	end
	return false
end
function Region:IsRectValid() return rect(self) ~= nil end

-- A nameplate's size, scale and position can be secret in the game: an addon must never read
-- them (Moo's rule). Reading one here is a violation and hands back a secret value.
for _, m in ipairs({ "GetWidth", "GetHeight", "GetSize", "GetScale", "GetEffectiveScale", "GetCenter", "GetLeft", "GetRight",
	"GetTop", "GetBottom", "GetRect", "GetScaledRect", "GetPoint", "GetNumPoints" }) do
	local orig = Region[m]
	Region[m] = function(self, ...)
		local s = S[self]
		if s and s.plate then
			local who = H.caller(2)
			if who then
				local w = s.client.world
				w.violations[#w.violations + 1] = who .. ": read a nameplate's geometry (" .. m .. "), which can be secret"
				return SECRET, SECRET, SECRET, SECRET
			end
		end
		return orig(self, ...)
	end
end

-- layered regions (textures, font strings)
local Layered = class("LayeredRegion", "Region")
function Layered:SetDrawLayer(layer, sub)
	if not LAYERS[layer] then argerr(self, "SetDrawLayer", "Invalid layer " .. tostring(layer)) end
	if sub ~= nil and (type(sub) ~= "number" or sub < -8 or sub > 7) then argerr(self, "SetDrawLayer", "Sublevel must be in -8..7") end
	st(self).layer, st(self).sublevel = layer, sub or 0
end
function Layered:GetDrawLayer() return st(self).layer, st(self).sublevel or 0 end
function Layered:SetVertexColor(r, g, b, a)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or (a ~= nil and type(a) ~= "number") then
		argerr(self, "SetVertexColor", "Usage: SetVertexColor(r, g, b [, a])")
	end
	local s = st(self)
	a = a or 1
	s.vertexAsked = { r, g, b, a }
	-- (BRIEF21 S5, BRIEF23 H3) the game keeps the alpha under an Alpha animation; with H.ALPHA_HOLD =
	-- "drawn" also that of a texture it has drawn while it is not drawing it (opt-in, not the client's rule)
	local old = s.vertex
	if old and alphaHeld(self, s, old[4], a, "SetVertexColor") then
		s.vertex = { r, g, b, old[4] }
		return
	end
	s.vertex = { r, g, b, a }
end
-- what the game draws (the kept alpha); H.vertexAsked(region): what the addon last asked for
function Layered:GetVertexColor() local v = st(self).vertex or { 1, 1, 1, 1 } return v[1], v[2], v[3], v[4] end
function H.vertexAsked(region)
	local s = S[region]
	local v = s and (s.vertexAsked or s.vertex) or { 1, 1, 1, 1 }
	return v[1], v[2], v[3], v[4]
end

-- animation groups can be made on any region
function Region:CreateAnimationGroup(name, template)
	local s = st(self)
	return H.newAnimGroup(s.client, self, name)
end
function Region:GetAnimationGroups()
	local out = {}
	for _, g in ipairs(st(self).animGroups or {}) do out[#out + 1] = g end
	return unpack(out)
end
function Region:StopAnimating()
	for _, g in ipairs(st(self).animGroups or {}) do g:Stop() end
end

---------------------------------------------------------------------------
-- Texture
---------------------------------------------------------------------------

local Texture = class("Texture", "LayeredRegion")

local BUILTIN_TEXTURE_PREFIX = { "^Interface\\Buttons\\", "^Interface\\Icons\\", "^Interface\\Common\\", "^Interface\\Tooltips\\",
	"^Interface\\DialogFrame\\", "^Interface\\Minimap\\", "^Interface\\ChatFrame\\", "^Interface\\TargetingFrame\\",
	"^Interface\\CharacterFrame\\", "^Interface\\WorldMap\\", "^Interface\\GLUES\\", "^Interface\\PaperDollInfoFrame\\",
	"^Interface\\RaidFrame\\", "^Interface\\COMMON\\", "^Interface\\FriendsFrame\\", "^Interface\\Cooldown\\",
	"^Interface\\GossipFrame\\", "^Interface\\MoneyFrame\\", "^Interface\\Glues\\", "^Interface\\QuestFrame\\",
	"^Interface\\HELPFRAME\\", "^Interface\\Scenarios\\", "^Interface\\TutorialFrame\\", "^Interface\\Calendar\\",
	"^Interface\\Spellbook\\", "^Interface\\PVPFrame\\", "^Interface\\AddOns\\", "^Interface\\TARGETINGFRAME\\", "^Interface\\BUTTONS\\",
	"^Interface\\Timer\\", "^Interface\\Garrison\\", "^Interface\\Collections\\", "^Interface\\Artifacts\\",
}

-- a file path the game would load: an addon's file must exist on disk
-- (BRIEF21 S3) a media file found once is not looked for again (one file open per texture made it slow);
-- a missing one is looked for every time, as before
local mediaFound = {}
local function mediaExists(file)
	if mediaFound[file] then return true end
	if exists(file) then mediaFound[file] = true return true end
	return false
end

function H.checkFile(client, path, kind, exts)
	if type(path) ~= "string" then return true end
	local p = path:gsub("/", "\\")
	local addon, rest = p:match("^[Ii]nterface\\[Aa]dd[Oo]ns\\([^\\]+)\\(.+)$")
	if addon then
		-- (design 3) a client loaded from its own install (the old Wuber 1.0 peer) is judged against what that install shipped
		local dir = client.addonDirs and client.addonDirs[addon] or H.ADDONS[addon]
		if not dir then return true end -- another addon's media: not ours to check
		local file = dir .. "/" .. rest:gsub("\\", "/")
		if file:match("%.%w%w%w$") then
			if mediaExists(file) then return true end
		else
			for _, e in ipairs(exts) do
				if mediaExists(file .. e) then return true end
			end
		end
		local w = client.world
		w.missingFiles[path] = kind
		return false
	end
	return true
end

function Texture:SetTexture(path, wrapH, wrapV, filter)
	local s = st(self)
	if path ~= nil and type(path) ~= "string" and type(path) ~= "number" then argerr(self, "SetTexture", "Usage: SetTexture(file or fileID [, wrapH, wrapV, filter])") end
	s.texture = path
	s.color = nil
	if type(path) == "string" and path ~= "" then
		local c = s.client
		c.texturePaths[path] = (c.texturePaths[path] or 0) + 1
		c.textureWhere = c.textureWhere or {}
		if not c.textureWhere[path] then c.textureWhere[path] = H.caller(2) or debug.traceback("", 2):gsub("\n%s*", " <- "):sub(1, 900) end
		return H.checkFile(s.client, path, "texture", { ".tga", ".blp", ".png", ".jpg" })
	end
	return true
end
-- the real client gives a file id (a number, negative for an addon's own file) from GetTexture, never the path;
-- GetTextureFilePath keeps the path. Here: a stable negative id per addon media path (other values pass as set).
local mediaIds, mediaNext = {}, 0
-- (probe pack) H.fileIds[lower-case path with backslashes] = the id a real client answered (tests/lib/probe_learn.lua fills it
-- from a probe fixture); H.fileIdFn(key) is the same as a function (a stand-in client). Both nil: the invented negative ids below.
H.fileIds, H.fileIdFn = nil, nil
local function mediaId(p)
	if type(p) == "string" then
		local key = (p:gsub("/", "\\"):lower())
		if key:find("^interface\\addons\\") then H.rule("tex.file-id") end
		local learned = H.fileIds and H.fileIds[key]
		if learned == nil and H.fileIdFn then learned = H.fileIdFn(key) end
		if learned ~= nil then return learned end
	end
	if type(p) == "string" and p:gsub("/", "\\"):lower():find("^interface\\addons\\") then
		local id = mediaIds[p]
		if not id then mediaNext = mediaNext + 1 id = -(1000000 + mediaNext) mediaIds[p] = id end
		return id
	end
	return p
end
function Texture:GetTexture() return mediaId(st(self).texture) end
function Texture:GetTextureFilePath()
	local p = st(self).texture
	if type(p) == "string" and p:gsub("/", "\\"):lower():find("^interface\\addons\\") then H.rule("tex.file-id") end
	return p
end
function Texture:GetTextureFileID() local t = mediaId(st(self).texture) return type(t) == "number" and t or nil end
function Texture:SetColorTexture(r, g, b, a)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or (a ~= nil and type(a) ~= "number") then
		argerr(self, "SetColorTexture", "Usage: SetColorTexture(r, g, b [, a])")
	end
	st(self).color = { r, g, b, a or 1 }
	st(self).texture = "color"
end
function Texture:SetAtlas(atlas, useSize)
	if type(atlas) ~= "string" then argerr(self, "SetAtlas", "Usage: SetAtlas(atlas [, useAtlasSize])") end
	st(self).atlas = atlas
	H.uncertain["Texture:SetAtlas(" .. atlas .. ")"] = "atlas names differ between clients"
end
function Texture:GetAtlas() return st(self).atlas end
function Texture:SetTexCoord(...)
	local n = select("#", ...)
	if n ~= 4 and n ~= 8 then argerr(self, "SetTexCoord", "Usage: SetTexCoord(left, right, top, bottom) or 8 corner values") end
	for i = 1, n do
		if type((select(i, ...))) ~= "number" then argerr(self, "SetTexCoord", "coordinates must be numbers") end
	end
	local s = st(self)
	s.texCoord = { ... }
	s.texCoordSets = (s.texCoordSets or 0) + 1
end
function Texture:GetTexCoord() local t = st(self).texCoord or { 0, 1, 0, 1 } return unpack(t) end
local function isColor(c) return type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" end
function Texture:SetGradient(orientation, minColor, maxColor)
	if orientation ~= "HORIZONTAL" and orientation ~= "VERTICAL" then argerr(self, "SetGradient", "Usage: SetGradient(orientation, minColor, maxColor)") end
	if not isColor(minColor) or not isColor(maxColor) then
		argerr(self, "SetGradient", "Usage: SetGradient(orientation, minColor, maxColor) - colours are ColorMixin tables (CreateColor)")
	end
	st(self).gradient = { orientation, minColor, maxColor }
end
-- (conformance, PF-060: the census of build 71037) a texture has NO SetGradientAlpha; SetGradient is the only one
function Texture:SetBlendMode(mode)
	if not BLEND[mode] then argerr(self, "SetBlendMode", "Invalid blend mode " .. tostring(mode)) end
	st(self).blend = mode
end
function Texture:GetBlendMode() return st(self).blend or "BLEND" end
function Texture:SetDesaturated(v) st(self).desaturated = v and true or false end
function Texture:IsDesaturated() return st(self).desaturated == true end
function Texture:SetDesaturation(v) st(self).desaturated = (v or 0) > 0 end
function Texture:SetRotation(rad, pivot)
	if type(rad) ~= "number" then argerr(self, "SetRotation", "Usage: SetRotation(radians [, normalizedRotationPoint])") end
	st(self).rotation = rad
end
function Texture:GetRotation() return st(self).rotation or 0 end
function Texture:SetHorizTile(v) st(self).htile = v end
function Texture:SetVertTile(v) st(self).vtile = v end
function Texture:SetSnapToPixelGrid(v) end
function Texture:SetTexelSnappingBias(v) end
function Texture:SetMask(path) st(self).mask = path return H.checkFile(st(self).client, path, "mask", { ".tga", ".blp" }) end
function Texture:AddMaskTexture(m)
	if not isWidget(m) or st(m).otype ~= "MaskTexture" then argerr(self, "AddMaskTexture", "Usage: AddMaskTexture(maskTexture)") end
end
function Texture:RemoveMaskTexture(m) end
function Texture:SetVertexOffset() end

local Mask = class("MaskTexture", "Texture")

local Line = class("Line", "Texture")
function Line:SetStartPoint(...) st(self).startPoint = { ... } end
function Line:SetEndPoint(...) st(self).endPoint = { ... } end
function Line:SetThickness(t) st(self).thickness = t end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

local FONT_OBJECTS = {}
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontNormalLarge",
	"GameFontHighlightLarge", "GameFontNormalHuge", "GameFontDisable", "GameFontDisableSmall", "GameFontWhite", "GameFontRed",
	"GameFontGreen", "GameFontBlack", "NumberFontNormal", "NumberFontNormalSmall", "ChatFontNormal", "ChatFontSmall",
	"SystemFont_Small", "SystemFont_Med1", "SystemFont_Large", "SystemFont_Huge1", "GameTooltipText", "GameTooltipTextSmall",
	"GameTooltipHeaderText", "QuestFont", "GameFontNormalMed3", "GameFontHighlightMedium", "GameFontNormalMed2",
	"GameFontHighlightSmallLeft", "GameFontNormalLeft", "GameFontHighlightLeft", "GameFontNormalSmallLeft", "Game15Font", "Game18Font", "Game24Font" }) do
	FONT_OBJECTS[n] = { path = "Fonts\\FRIZQT__.TTF", size = (n:find("Small") and 10) or (n:find("Large") and 16) or (n:find("Huge") and 20) or 12, flags = "" }
end
local GAME_FONTS = { ["Fonts\\ARIALN.TTF"] = true, ["Fonts\\FRIZQT__.TTF"] = true, ["Fonts\\MORPHEUS.TTF"] = true,
	["Fonts\\SKURRI.TTF"] = true, ["Fonts\\FRIZQT___CYR.TTF"] = true, ["Fonts\\2002.TTF"] = true }

local function checkFontArgs(self, method, path, size, flags)
	if type(path) ~= "string" then argerr(self, method, "Usage: SetFont(path, height [, flags])") end
	if type(size) ~= "number" or size <= 0 then argerr(self, method, "font height must be a number > 0") end
	if flags ~= nil and type(flags) ~= "string" then argerr(self, method, "flags must be a string") end
	for f in (flags or ""):gmatch("[^,%s]+") do
		if not FONT_FLAGS[f] then argerr(self, method, "unknown font flag " .. f) end
	end
	local p = path:gsub("/", "\\")
	if p:match("^[Ii]nterface\\") then
		return H.checkFile(st(self).client, p, "font", {})
	end
	if not GAME_FONTS[p] and not GAME_FONTS[p:upper():gsub("^FONTS", "Fonts")] then
		st(self).client.world.missingFiles[path] = "font"
		return false
	end
	return true
end

local FontString = class("FontString", "LayeredRegion")
function FontString:SetFont(path, size, flags)
	local ok = checkFontArgs(self, "SetFont", path, size, flags)
	local was = st(self).font
	if ok then st(self).font = { path = path, size = size, flags = flags or "" } end
	if ok and H.textMetrics and not st(self).fontAt then -- (preview mode) when this string first got a font
		st(self).fontAt = st(self).client.world.time
	end
	-- (BRIEF18) set while the addon font was loading; the same font and size again changes nothing
	if ok and H.markStale and not (was and was.path == path and was.size == size) then H.markStale(self) end
	return ok
end
function FontString:GetFont()
	local f = st(self).font
	if not f then return nil end
	return f.path, f.size, f.flags
end
function FontString:SetFontObject(obj)
	if type(obj) == "string" then obj = FONT_OBJECTS[obj] end
	if type(obj) ~= "table" then argerr(self, "SetFontObject", "Usage: SetFontObject(font)") end
	local f = obj.path and obj or (S[obj] and S[obj].font)
	st(self).font = f and { path = f.path, size = f.size, flags = f.flags } or st(self).font
end
function FontString:GetFontObject() return nil end
local function setText(self, text, method)
	local s = st(self)
	if text ~= nil and type(text) ~= "string" and type(text) ~= "number" then
		argerr(self, method, "Usage: " .. method .. "(text)")
	end
	if not s.font then error(s.otype .. ":" .. method .. "(): Font not set", 3) end
	local was = s.text
	s.text = text ~= nil and tostring(text) or nil
	-- (BRIEF18) laid out again only when the text really changes (the same text again keeps the
	-- layout: the author's button, repainted every few seconds, stayed cut until the window re-set it)
	if H.markStale and s.text ~= was then H.markStale(self) end
end
function FontString:SetText(text) setText(self, text, "SetText") end
function FontString:GetText() return st(self).text end
function FontString:SetFormattedText(fmt, ...)
	if type(fmt) ~= "string" then argerr(self, "SetFormattedText", "Usage: SetFormattedText(format, ...)") end
	setText(self, fmt:format(...), "SetFormattedText")
end
function FontString:SetTextColor(r, g, b, a)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then argerr(self, "SetTextColor", "Usage: SetTextColor(r, g, b [, a])") end
	st(self).textColor = { r, g, b, a or 1 }
end
function FontString:GetTextColor() local c = st(self).textColor or { 1, 1, 1, 1 } return unpack(c) end
function FontString:SetShadowColor(r, g, b, a)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then argerr(self, "SetShadowColor", "Usage: SetShadowColor(r, g, b [, a])") end
	st(self).shadowColor = { r, g, b, a or 1 }
end
function FontString:GetShadowColor() local c = st(self).shadowColor or { 0, 0, 0, 1 } return unpack(c) end
function FontString:SetShadowOffset(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetShadowOffset", "Usage: SetShadowOffset(x, y)") end
	st(self).shadowOffset = { x, y }
end
function FontString:GetShadowOffset() local o = st(self).shadowOffset or { 0, 0 } return o[1], o[2] end
function FontString:SetJustifyH(j)
	if j ~= "LEFT" and j ~= "CENTER" and j ~= "RIGHT" then argerr(self, "SetJustifyH", "Invalid justify " .. tostring(j)) end
	st(self).justifyH = j
end
function FontString:GetJustifyH() return st(self).justifyH or "CENTER" end
function FontString:SetJustifyV(j)
	if j ~= "TOP" and j ~= "MIDDLE" and j ~= "BOTTOM" then argerr(self, "SetJustifyV", "Invalid justify " .. tostring(j)) end
	st(self).justifyV = j
end
function FontString:GetJustifyV() return st(self).justifyV or "MIDDLE" end
function FontString:SetWordWrap(v) st(self).wrap = v and true or false end
function FontString:CanWordWrap() return st(self).wrap ~= false end
function FontString:SetNonSpaceWrap(v) end
function FontString:SetIndentedWordWrap(v) end
function FontString:SetMaxLines(n) if type(n) ~= "number" then argerr(self, "SetMaxLines", "Usage: SetMaxLines(n)") end st(self).maxLines = n end
function FontString:GetMaxLines() return st(self).maxLines or 0 end
function FontString:SetSpacing(n) if type(n) == "number" then st(self).spacing = n end end
function FontString:GetSpacing() return st(self).spacing or 0 end
function FontString:SetTextHeight(h) local f = st(self).font if f then f.size = h end end
function FontString:SetTextScale(s) end
-- Preview mode (tools/preview/tour.lua): H.textMetrics = tools/preview/textlayout.lua measures,
-- wraps and truncates text with the shipped fonts' real advances, as the game does, so the addon
-- lays out what the player sees. nil in the tests (the simple rule below; the transcript keeps it).
H.textMetrics = nil
local function metricLayout(self)
	local s = S[self]
	local f = s.font
	local M = H.textMetrics
	local width, height
	if not s.measuring then
		s.measuring = true -- (rect() asks for the height again: the plain one then)
		local ok, r = pcall(H.rect, self)
		s.measuring = nil
		local e = effScale(self)
		local side = {}
		for _, p in ipairs(s.points) do
			local pp = POINTS[p.point]
			if pp then side["x" .. pp[1]] = true side["y" .. pp[2]] = true end
		end
		local twoPoints = #s.points >= 2
		if twoPoints and side.x0 and side.x1 and ok and r then width = r.w / e elseif s.w then width = s.w end
		if twoPoints and side.y0 and side.y1 and ok and r then height = r.h / e elseif s.h then height = s.h end
	end
	if width and width <= 0 then width = nil end
	return M.layout(f and f.path, (f and f.size) or 12, s.text or "", { width = width, height = height,
		wrap = s.wrap ~= false, maxLines = s.maxLines, spacing = s.spacing, scale = effScale(self) })
end
-- (probe pack) H.measuredWidths(fontPath, size, text) -> the width a real client measured, or nil (tests/lib/probe_learn.lua sets it
-- from a probe fixture). nil by default: the harness's own metrics answer.
H.measuredWidths = nil
local function textWidth(self)
	local s = S[self]
	local f = s.font
	if H.measuredWidths then
		local w = H.measuredWidths(f and f.path, (f and f.size) or 12, s.text or "")
		if w then return w end
	end
	if H.textMetrics then
		-- the game answers with Arial Narrow's widths until it has the font loaded for a new string
		-- (Wuber's own comment in Theme/Tokens.lua, seen in game): H.textMetrics.LOADING seconds
		local w = s.client and s.client.world
		local seen = s.fontAt
		if H.textMetrics.LOADING and seen and w and w.time < seen + H.textMetrics.LOADING then
			return H.textMetrics.width("Fonts\\ARIALN.TTF", (f and f.size) or 12, s.text or "", effScale(self))
		end
		return H.textMetrics.width(f and f.path, (f and f.size) or 12, s.text or "", effScale(self))
	end
	local text = (s.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW")
	-- (BRIEF18) laid out while the addon font was loading: Arial Narrow's narrower widths
	return #text * ((f and f.size) or 12) * 0.5 * (s.stale and H.STALE_WIDTH or 1)
end
local function textHeight(self)
	local f = S[self].font
	if H.textMetrics then
		if S[self].measuring then return ((f and f.size) or 12) * H.textMetrics.LINE end
		return metricLayout(self).height
	end
	return ((f and f.size) or 12) * 1.2
end
function FontString:GetStringWidth()
	if H.textMetrics and S[self].wrap ~= false and textWidth(self) == H.textMetrics.width(S[self].font and S[self].font.path, (S[self].font and S[self].font.size) or 12, S[self].text or "", effScale(self)) then
		local L = metricLayout(self)
		return L.width
	end
	return textWidth(self)
end
function FontString:GetUnboundedStringWidth() return textWidth(self) end
function FontString:GetStringHeight() return textHeight(self) end
function FontString:GetNumLines() if not H.textMetrics then H.rule("font.no-wrap") end return H.textMetrics and #metricLayout(self).lines or 1 end
-- (round 13, I18) truncation as the game draws it: a font string with a width (SetWidth, or anchored
-- left and right) whose text is wider than that width is cut with "..." when it may not wrap; when
-- it wraps, it is cut when its words need more lines than SetMaxLines allows. Widths: the addon's
-- own Inter measure (fs.wuberPx, W.Theme.MeasureText, as drawn) when it has one, else the
-- harness's rough one. H.truncation(fs) -> nil, or { need = px, room = px, lines = n, max = n }.
-- The game draws small addon-font text a little wider than its advance widths (letters land on whole
-- screen pixels): Google's shots cut '17:00–20:00' at '20:' and 'Orgrimmar' at 'Orgrim' in room our
-- measure called just enough. The check asks for that much spare (round 13, I18).
H.GAME_TEXT_MARGIN = 1.06
-- (BRIEF18) text as the game draws it at a given screen: each glyph's advance lands on whole screen
-- pixels at the string's effective scale (as tools/preview/textlayout.lua, calibrated on the 19 Nov
-- shots: rounded, no tracking). H.TEXT_PIXELS = { px = screen pixels per UI unit, snap = "round" or
-- "ceil", track = pixels added per glyph } turns it on; nil keeps the flat GAME_TEXT_MARGIN (the
-- transcript keeps it).
H.TEXT_PIXELS = nil
-- (BRIEF18, the author's clue) a string whose font or text was set before the game had loaded its addon
-- font (world.fontReadyAt, opt-in) is laid out with Arial Narrow's widths (H.STALE_WIDTH of
-- the addon font's) and keeps that layout until it is set again: the game's answers (GetStringWidth,
-- IsTruncated) are the narrow ones, and what it draws is wrong (H.truncation reports it: stale).
H.STALE_WIDTH = 0.75
local function fontPending(self)
	local s = S[self]
	local w = s and s.client and s.client.world
	return w ~= nil and w.fontReadyAt ~= nil and (w.time or 0) < w.fontReadyAt
end
local function addonFont(f)
	return f ~= nil and type(f.path) == "string" and f.path:gsub("/", "\\"):match("^[Ii]nterface\\") ~= nil
end
local function markStale(self)
	local s = S[self]
	s.stale = addonFont(s.font) and fontPending(self) or nil
end
H.fontPending = fontPending
H.markStale = markStale
local function measureFS(self, text, asGame)
	local s = S[self]
	local c = s.client
	local th = c and type(c.W) == "table" and c.W.Theme
	local px = rawget(self, "wuberPx")
	local v
	if type(th) == "table" and type(th.MeasureText) == "function" and px and th.poppins ~= false then
		local weight = rawget(self, "wuberWeight")
		local tp = H.TEXT_PIXELS
		if type(tp) == "table" and tonumber(tp.px) then
			local k = tonumber(tp.px) * effScale(self)
			local sum = 0
			for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
				local ok, a = pcall(th.MeasureText, ch, px, weight)
				if ok and tonumber(a) then
					local p = a / 1.03 * k
					p = tp.snap == "ceil" and math.ceil(p - 1e-6) or math.floor(p + 0.5)
					sum = sum + p + (tonumber(tp.track) or 0)
				end
			end
			v = sum / k
		else
			local ok, a = pcall(th.MeasureText, text, px, weight)
			if ok and tonumber(a) then v = a / 1.03 * H.GAME_TEXT_MARGIN H.rule("font.small-width") end
		end
	end
	v = v or (#text * ((s.font and s.font.size) or 12) * 0.5)
	if asGame and s.stale then v = v * H.STALE_WIDTH end
	return v
end
function H.textRoom(self)
	local s = S[self]
	local hasL, hasR = false, false
	for _, p in ipairs(s.points) do
		local x = POINTS[p.point][1]
		if x == 0 then hasL = true elseif x == 1 then hasR = true end
	end
	if hasL and hasR then
		local r = rect(self)
		return r and (r.w / effScale(self)) or nil
	end
	return s.w
end
-- (round 13 review) a font string's fixed height (SetHeight / SetSize, or anchored top and bottom), or nil
function H.textTall(self)
	local s = S[self]
	local hasT, hasB = false, false
	for _, p in ipairs(s.points) do
		local y = POINTS[p.point][2]
		if y == 0 then hasB = true elseif y == 1 then hasT = true end
	end
	if hasT and hasB then
		local r = rect(self)
		return r and (r.h / effScale(self)) or nil
	end
	return s.h
end
-- (BRIEF18) asGame: the game's own answer (IsTruncated), which a string laid out before its font
-- loaded gets wrong; without it, what the player sees (a stale string counts as cut).
-- H.textLines(fs): the lines its words take as the game wraps them (1 without wrap), or nil.
local function wrapLines(self, text, room, asGame)
	local slop = 1
	local lines = 0
	for para in (text .. "\n"):gmatch("(.-)\n") do
		local cur = ""
		lines = lines + 1
		for word in para:gmatch("%S+") do
			if measureFS(self, word, asGame) > room + slop then return lines, measureFS(self, word, asGame) end
			local try = cur == "" and word or (cur .. " " .. word)
			if cur ~= "" and measureFS(self, try, asGame) > room + slop then
				lines, cur = lines + 1, word
			else
				cur = try
			end
		end
	end
	return lines
end
local function plainText(s)
	return (s.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW"):gsub("|n", "\n")
end
function H.textLines(self)
	local s = S[self]
	if not s or s.otype ~= "FontString" then return nil end
	local text = plainText(s)
	if not text:match("%S") then return 0 end
	if s.wrap == false then return 1 end
	local room = H.textRoom(self)
	if not room or room <= 0 then return nil end
	return (wrapLines(self, text, room))
end
function H.truncation(self, asGame)
	local s = S[self]
	if not s or s.otype ~= "FontString" then return nil end
	local text = plainText(s)
	if not text:match("%S") then return nil end
	local room = H.textRoom(self)
	if not room or room <= 0 then return nil end
	if s.stale and not asGame then return { stale = true, need = measureFS(self, text), room = room, lines = 1, max = 1 } end
	local slop = 1
	if s.wrap == false then
		local need = 0
		for line in (text .. "\n"):gmatch("(.-)\n") do need = math.max(need, measureFS(self, line, asGame)) end
		if need > room + slop then return { need = need, room = room, lines = 1, max = 1 } end
		return nil
	end
	local lines, wide = wrapLines(self, text, room, asGame)
	if wide then return { need = wide, room = room, lines = lines, max = lines } end
	local max = s.maxLines or 0
	-- (round 13 review) a fixed height is a line limit too: the game cuts the lines that don't fit
	local tall = H.textTall(self)
	if tall then
		local lineH = ((s.font and s.font.size) or 12) * 1.2
		local byHeight = math.max(1, math.floor((tall + 1) / lineH))
		if max <= 0 or byHeight < max then max = byHeight end
	end
	if max > 0 and lines > max then return { need = room * lines, room = room, lines = lines, max = max } end
	return nil
end
function FontString:IsTruncated()
	if H.textMetrics then return metricLayout(self).truncated end -- (preview mode, tools/preview/tour.lua)
	return H.truncation(self, true) ~= nil
end
H.metricLayout = metricLayout
function FontString:SetAlphaGradient() return true end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local Frame = class("Frame", "Region")

local SCRIPTS = {
	Frame = { OnEvent = 1, OnUpdate = 1, OnShow = 1, OnHide = 1, OnEnter = 1, OnLeave = 1, OnMouseDown = 1, OnMouseUp = 1,
		OnMouseWheel = 1, OnDragStart = 1, OnDragStop = 1, OnReceiveDrag = 1, OnSizeChanged = 1, OnLoad = 1,
		OnAttributeChanged = 1, OnKeyDown = 1, OnKeyUp = 1, OnChar = 1, OnEnable = 1, OnDisable = 1, OnHyperlinkClick = 1,
		OnHyperlinkEnter = 1, OnHyperlinkLeave = 1 },
	Button = { OnClick = 1, PreClick = 1, PostClick = 1, OnDoubleClick = 1 },
	EditBox = { OnTextChanged = 1, OnEnterPressed = 1, OnEscapePressed = 1, OnEditFocusGained = 1, OnEditFocusLost = 1,
		OnTabPressed = 1, OnSpacePressed = 1, OnCursorChanged = 1, OnTextSet = 1, OnInputLanguageChanged = 1, OnArrowPressed = 1 },
	Slider = { OnValueChanged = 1, OnMinMaxChanged = 1 },
	StatusBar = { OnValueChanged = 1, OnMinMaxChanged = 1 },
	ScrollFrame = { OnVerticalScroll = 1, OnHorizontalScroll = 1, OnScrollRangeChanged = 1 },
	GameTooltip = { OnTooltipSetItem = 1, OnTooltipSetUnit = 1, OnTooltipSetSpell = 1, OnTooltipCleared = 1 },
	Cooldown = { OnCooldownDone = 1 },
	AnimationGroup = { OnPlay = 1, OnFinished = 1, OnStop = 1, OnLoop = 1, OnPause = 1, OnUpdate = 1 },
	Animation = { OnPlay = 1, OnFinished = 1, OnStop = 1, OnLoop = 1, OnPause = 1, OnUpdate = 1 },
}
for _, t in ipairs({ "Model", "PlayerModel", "DressUpModel", "CinematicModel", "ModelScene" }) do
	SCRIPTS[t] = { OnModelLoaded = 1, OnAnimFinished = 1, OnAnimStarted = 1 }
end
local MODERN_TIP_SCRIPTS = { OnTooltipSetUnit = true, OnTooltipSetItem = true, OnTooltipSetSpell = true }
local function hasScript(s, name)
	local t = s.otype
	if SCRIPTS.Frame[name] and s.kind == "frame" then return true end
	if t == "CheckButton" and SCRIPTS.Button[name] then return true end
	if t == "GameTooltip" and s.modernTip and MODERN_TIP_SCRIPTS[name] then return false end -- 10.0.2+: TooltipDataProcessor instead
	if SCRIPTS[t] and SCRIPTS[t][name] then return true end
	if s.kind == "anim" and SCRIPTS.Animation[name] then return true end
	return false
end

local function scriptCheck(self, method, name)
	local s = st(self)
	if type(name) ~= "string" or not hasScript(s, name) then
		error(("%s:%s(): %s doesn't have a \"%s\" script"):format(s.otype, method, s.otype, tostring(name)), 3)
	end
end

function Frame:SetScript(name, fn)
	scriptCheck(self, "SetScript", name)
	if fn ~= nil and type(fn) ~= "function" then argerr(self, "SetScript", "Usage: SetScript(\"type\", function)") end
	st(self).scripts[name] = fn
	if fn ~= nil and H.keyRules and H.KEY_SCRIPTS[name] then H.keyOp(self, name) end
	if name == "OnUpdate" then H.trackUpdate(self) end
	-- the real client turns keyboard input ON for a frame when an OnKeyDown/OnKeyUp script is set (an EditBox takes keys by focus)
	if fn ~= nil and (name == "OnKeyDown" or name == "OnKeyUp") and st(self).otype ~= "EditBox" then st(self).keyboard = true H.rule("keys.onkeydown-enables") end
	if fn ~= nil and H.mapTaint then H.mapTaint.script(st(self).client, self, name) end -- (tests/lib/maptaint.lua, rule b)
end
function Frame:GetScript(name) scriptCheck(self, "GetScript", name) return st(self).scripts[name] end
function Frame:HookScript(name, fn)
	scriptCheck(self, "HookScript", name)
	if type(fn) ~= "function" then argerr(self, "HookScript", "Usage: HookScript(\"type\", function)") end
	local s = st(self)
	local old = s.scripts[name]
	s.scripts[name] = old and function(...) old(...) fn(...) end or fn
	if (name == "OnKeyDown" or name == "OnKeyUp") and s.otype ~= "EditBox" then s.keyboard = true end
	if name == "OnUpdate" then H.trackUpdate(self) end
	if H.mapTaint then H.mapTaint.script(s.client, self, name) end -- (tests/lib/maptaint.lua, rule b)
end
function Frame:HasScript(name) return hasScript(st(self), name) end

H.KNOWN_EVENTS = {}
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "CHAT_MSG_ADDON",
	"CHAT_MSG_ADDON_LOGGED", "GROUP_ROSTER_UPDATE", "GROUP_JOINED", "GROUP_LEFT", "PARTY_INVITE_REQUEST", "PARTY_LEADER_CHANGED",
	"CONFIRM_SUMMON", "CANCEL_SUMMON", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "TRADE_SHOW", "TRADE_CLOSED", "TRADE_REQUEST_CANCEL", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE",
	"TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "PLAYER_TRADE_MONEY", "PLAYER_MONEY", "CHANNEL_UI_UPDATE",
	"CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_SYSTEM", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_AFK", "CHAT_MSG_DND", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
	"UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
	"PLAYER_TARGET_CHANGED", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
	"PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "NEW_WMO_CHUNK", "WORLD_MAP_OPEN", "WORLD_MAP_CLOSE",
	"PLAYER_FLAGS_CHANGED", "PARTY_MEMBER_DISABLE", "PARTY_MEMBER_ENABLE", "SPELL_UPDATE_COOLDOWN", "PLAYER_LEVEL_UP",
	"UPDATE_BINDINGS", "MODIFIER_STATE_CHANGED", "CVAR_UPDATE", "VARIABLES_LOADED", "SAVED_VARIABLES_TOO_LARGE",
	"FRIENDLIST_UPDATE", "IGNORELIST_UPDATE", "PLAYER_ALIVE", "PLAYER_DEAD", "PLAYER_UNGHOST", "INSTANCE_GROUP_SIZE_CHANGED",
	"RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "UNIT_PORTRAIT_UPDATE", "CINEMATIC_START", "CINEMATIC_STOP",
	"LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED", "CHANNEL_COUNT_UPDATE", "CHANNEL_ROSTER_UPDATE", "CHANNEL_FLAGS_UPDATED",
	"CHANNEL_LEFT", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE", "UPDATE_CHAT_WINDOWS", "UPDATE_CHAT_COLOR",
	"PLAYER_CAMPING", "PLAYER_QUITING", "TIME_PLAYED_MSG", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "UNIT_AURA",
	"PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "MINIMAP_UPDATE_ZOOM", "MINIMAP_PING",
	"NAME_PLATE_CREATED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "FORBIDDEN_NAME_PLATE_CREATED",
	"FORBIDDEN_NAME_PLATE_UNIT_ADDED", "FORBIDDEN_NAME_PLATE_UNIT_REMOVED", "UPDATE_MOUSEOVER_UNIT", "CURSOR_CHANGED",
	"PLAYER_SOFT_INTERACT_CHANGED", "SCREENSHOT_STARTED", "SCREENSHOT_SUCCEEDED", "UNIT_MODEL_CHANGED",
	"CLUB_ADDED", "CLUB_REMOVED", "CLUB_STREAMS_LOADED", "CLUB_STREAM_ADDED", "CLUB_STREAM_REMOVED", "INITIAL_CLUBS_LOADED",
	"SPELLS_CHANGED", "CLUB_MEMBER_ROLE_UPDATED", "CLUB_INVITATION_ADDED_FOR_SELF", "CLUB_INVITATION_REMOVED_FOR_SELF",
	-- boss fight start and end (FAKE-GAME-HINTS LRN-G03; ThicPortals Events.lua 141-144)
	"ENCOUNTER_START", "ENCOUNTER_END",
	-- (fga f) documented for this client and asked for by Wuber or likely to be: a mouse press anywhere, the trade window re-read,
	-- an invite taken back, a summon changing
	"GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "TRADE_UPDATE", "TRADE_UPDATE_WARNINGS", "PARTY_INVITE_CANCEL", "INCOMING_SUMMON_CHANGED" }) do
	H.KNOWN_EVENTS[e] = true
end

-- What this client forbids to addons (tools/forbidden.lua, loaded at the end of this file): like
-- the real client, ADDON_ACTION_FORBIDDEN with "UNKNOWN()"; here also a violation (so the test
-- fails) and an error. `what` names it for the violation.
-- Round 15: the violation stays on the world until the test clears it (w.violations = {}); run.lua
-- fails any test that ends with one left (H.forbiddenLeft), even one that never calls clean(w) and
-- whose addon code swallowed the error under pcall. A hit with no client (no world) counts too.
H.FORBID_MARK = " is forbidden in this client (only available to the Blizzard UI; tools/forbidden.lua)"
H.forbidOrphans = {}
function H.forbid(client, what)
	if client then
		local w = client.world
		w.violations[#w.violations + 1] = client.player.name .. ": " .. what .. H.FORBID_MARK
		client:fire("ADDON_ACTION_FORBIDDEN", client:callerAddon(), "UNKNOWN()")
	else
		H.forbidOrphans[#H.forbidOrphans + 1] = "(no client): " .. what .. H.FORBID_MARK
	end
	error("ADDON_ACTION_FORBIDDEN: " .. what .. " is only available to the Blizzard UI", 3)
end
-- every forbidden-list hit still standing in a world made since the last H.release()
function H.forbiddenLeft()
	local out, seen = {}, {}
	if H.taint then for _, client in ipairs(H.made) do H.taint.scan(client) end end
	for _, v in ipairs(H.forbidOrphans) do out[#out + 1] = v end
	for _, client in ipairs(H.made) do
		local w = client.world
		if w and not seen[w] then
			seen[w] = true
			for _, v in ipairs(w.violations or {}) do
				if tostring(v):find(H.FORBID_MARK, 1, true) or (H.mapTaint and tostring(v):find(H.mapTaint.MARK, 1, true))
					or (H.taint and tostring(v):find(H.taint.MARK, 1, true)) then
					out[#out + 1] = tostring(v)
				end
			end
		end
	end
	return out
end
H.FORBIDDEN_EVENTS = {}
H.FORBIDDEN_METHODS = {}

local function forbiddenEvent(self, method, event)
	if H.FORBIDDEN_EVENTS[event] then H.forbid(st(self).client, method .. "(\"" .. event .. "\")") end
end

function Frame:RegisterEvent(event)
	if type(event) ~= "string" then argerr(self, "RegisterEvent", "Usage: RegisterEvent(\"event\")") end
	forbiddenEvent(self, "RegisterEvent", event)
	local sc = st(self).client
	local wcOn = event == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" and sc and sc.world and sc.world.whisperCheck
	if not H.KNOWN_EVENTS[event] and not wcOn then
		error(("Frame:RegisterEvent(): Attempt to register unknown event \"%s\""):format(event), 2)
	end
	local s = st(self)
	s.events[event] = true
	return true
end
function Frame:RegisterUnitEvent(event, ...) return self:RegisterEvent(event) end
function Frame:UnregisterEvent(event)
	forbiddenEvent(self, "UnregisterEvent", event)
	st(self).events[event] = nil
end
-- every event, the combat log too: forbidden in this client (tools/forbidden.lua, kind "method":
-- the loader at the end of this file wraps every method on that list, this one included)
function Frame:RegisterAllEvents()
	local s = st(self)
	for event in pairs(H.KNOWN_EVENTS) do s.events[event] = true end
end
function Frame:UnregisterAllEvents() st(self).events = {} end
function Frame:IsEventRegistered(event) return st(self).events[event] == true end

function Frame:SetFrameStrata(strata)
	if not STRATA[strata] then argerr(self, "SetFrameStrata", "Invalid strata " .. tostring(strata)) end
	st(self).strata = strata
end
function Frame:GetFrameStrata()
	local s = S[self]
	while s do
		if s.strata then return s.strata end
		if not s.parent then break end
		s = S[s.parent]
	end
	return "MEDIUM"
end
function Frame:SetFixedFrameStrata(v) end
function Frame:SetFixedFrameLevel(v) end
function Frame:SetFrameLevel(level)
	if type(level) ~= "number" then argerr(self, "SetFrameLevel", "Usage: SetFrameLevel(level)") end
	if level < 0 or level > 10000 then argerr(self, "SetFrameLevel", "level must be 0..10000") end
	st(self).level = math.floor(level)
end
function Frame:GetFrameLevel()
	local s = st(self)
	if s.level then return s.level end
	local p = s.parent
	return p and (p:GetFrameLevel() + 1) or 0
end
function Frame:SetToplevel(v) st(self).toplevel = v end
function Frame:IsToplevel() return st(self).toplevel == true end
function Frame:Raise() raiseFrame(self) end
function Frame:Lower() end
-- (probe pack) H.keyRules[ "<object type>|<calls, comma separated>" ] = { kb, mouse, prop }: what a real client answered for a
-- frame that went through exactly that sequence (tests/lib/probe_learn.lua L.keyRules, from the probe's keysAuto answers).
-- The sequence is only written down while H.keyRules is set; the calls are named: kb:true, mouse:false, prop:true, and the script
-- names OnKeyDown OnKeyUp OnChar OnMouseDown OnEnter OnMouseWheel OnClick. nil by default: the harness's own rules answer.
H.keyRules = nil
H.KEY_SCRIPTS = { OnKeyDown = true, OnKeyUp = true, OnChar = true, OnMouseDown = true, OnEnter = true, OnMouseWheel = true, OnClick = true }
function H.keyOp(self, op)
	local s = S[self]
	if s then s.keyOps = s.keyOps or {} s.keyOps[#s.keyOps + 1] = op end
end
function H.keyRule(self)
	local s = S[self]
	return s and H.keyRules[(s.otype or "?") .. "|" .. table.concat(s.keyOps or {}, ",")]
end
function Frame:EnableMouse(v)
	if blocked(self, "EnableMouse") then return end
	st(self).mouse = v and true or false
	if H.keyRules then H.keyOp(self, "mouse:" .. tostring(v and true or false)) end
end
function Frame:IsMouseEnabled()
	local r = H.keyRules and H.keyRule(self)
	if r and r.mouse ~= nil then return r.mouse end
	return st(self).mouse == true
end
function Frame:EnableMouseWheel(v) st(self).wheel = v and true or false end
function Frame:IsMouseWheelEnabled() return st(self).wheel == true end
function Frame:SetMouseClickEnabled(v) st(self).mouse = v and true or false end
function Frame:SetMouseMotionEnabled(v) end
function Frame:EnableKeyboard(v)
	st(self).keyboard = v and true or false
	if H.keyRules then H.keyOp(self, "kb:" .. tostring(v and true or false)) end
end
function Frame:SetPropagateKeyboardInput(v)
	local s = st(self)
	if s.client.player.combat then
		local w = s.client.world
		w.violations[#w.violations + 1] = s.client.player.name .. ": SetPropagateKeyboardInput in combat"
		return
	end
	s.propagate = v and true or false
	if H.keyRules then H.keyOp(self, "prop:" .. tostring(v and true or false)) end
end
function Frame:GetPropagateKeyboardInput()
	local r = H.keyRules and H.keyRule(self)
	if r and r.prop ~= nil then return r.prop end
	H.rule("keys.propagate-default-off")
	return st(self).propagate == true
end
function Frame:IsKeyboardEnabled()
	local r = H.keyRules and H.keyRule(self)
	if r and r.kb ~= nil then return r.kb end
	return st(self).keyboard == true
end
function Frame:SetMovable(v) st(self).movable = v and true or false end
function Frame:IsMovable() return st(self).movable == true end
function Frame:SetResizable(v) st(self).resizable = v and true or false end
function Frame:SetResizeBounds(a, b, c, d) end
function Frame:RegisterForDrag(...) st(self).drag = { ... } end
function Frame:StartMoving()
	if blocked(self, "StartMoving") then return end
	local s = st(self)
	if not s.movable then error("Frame:StartMoving(): Frame is not movable", 2) end
	s.moving = true
end
function Frame:StartSizing()
	local s = st(self)
	if not s.resizable then error("Frame:StartSizing(): Frame is not resizable", 2) end
end
function Frame:StopMovingOrSizing()
	local s = st(self)
	if s.moving then
		H.rule("drag.anchor-center")
		s.moving = nil
		-- the game re-anchors a moved frame to UIParent by one point, where it was dropped
		local r = rect(self)
		local up = s.client.env.UIParent
		if r then
			local e = effScale(self)
			local ur = rect(up)
			s.points = { { point = "CENTER", rel = up, relPoint = "CENTER",
				x = (r.l + r.w / 2 - ur.w / 2) / e + (s.client.dragDX or 0), y = (r.b + r.h / 2 - ur.h / 2) / e + (s.client.dragDY or 0) } }
		end
	end
end
function Frame:SetUserPlaced(v) end
function Frame:IsUserPlaced() return false end
function Frame:SetDontSavePosition(v) end
function Frame:SetClampedToScreen(v) st(self).clamped = v and true or false if v then H.rule("frame.clamp-ignored") end end
function Frame:IsClampedToScreen() return st(self).clamped == true end
function Frame:SetClampRectInsets(l, r, t, b) end
function Frame:SetClipsChildren(v) st(self).clips = v and true or false end
function Frame:DoesClipChildren() return st(self).clips == true end
-- (real game: the mouse hit rect is the frame's rect shrunk by the insets; a negative inset grows it)
function Frame:SetHitRectInsets(l, r, t, b) st(self).hitIns = { l or 0, r or 0, t or 0, b or 0 } end
function Frame:GetHitRectInsets() local h = st(self).hitIns or { 0, 0, 0, 0 } return h[1], h[2], h[3], h[4] end
function Frame:SetFlattensRenderLayers(v) end
function Frame:SetID(id) st(self).id = id end
function Frame:GetID() return st(self).id or 0 end
function Frame:IsProtected() local s = st(self) return isProtected(self), s.secure == true end
-- (conformance, PF-065: TradeFrameTradeButton on build 71037) no access constraints on the game's own frames
function Frame:HasAccessConstraints() return false end
function Frame:GetChildren()
	local out = {}
	for _, c in ipairs(st(self).children) do if S[c].kind == "frame" then out[#out + 1] = c end end
	return unpack(out)
end
function Frame:GetNumChildren() return select("#", self:GetChildren()) end
function Frame:GetRegions()
	local out = {}
	for _, c in ipairs(st(self).children) do if S[c].kind == "region" then out[#out + 1] = c end end
	return unpack(out)
end
function Frame:GetNumRegions() return select("#", self:GetRegions()) end

function Frame:SetAttribute(k, v)
	local s = st(self)
	if s.client.player.combat and isProtected(self) then
		local w = s.client.world
		w.violations[#w.violations + 1] = s.client.player.name .. ": SetAttribute(" .. tostring(k) .. ") on protected frame " .. tostring(s.name or s.otype) .. " in combat"
		s.client:fire("ADDON_ACTION_BLOCKED", s.client:callerAddon(), s.otype .. ":SetAttribute()")
		error("ADDON_ACTION_BLOCKED: " .. s.client:callerAddon() .. " tried to call the protected function '" .. tostring(s.name or s.otype) .. ":SetAttribute()'", 2)
	end
	s.attrs[k] = v
	runScript(self, "OnAttributeChanged", k, v)
end
function Frame:GetAttribute(k) return st(self).attrs[k] end

local function newRegion(self, otype, name, layer, template, sub)
	local s = st(self)
	if layer ~= nil and not LAYERS[layer] then argerr(self, "Create" .. otype, "Invalid draw layer " .. tostring(layer)) end
	if sub ~= nil and (type(sub) ~= "number" or sub < -8 or sub > 7) then argerr(self, "Create" .. otype, "sublevel must be -8..7") end
	local r = H.newWidget(s.client, otype, name, self, "region")
	S[r].layer, S[r].sublevel = layer or "ARTWORK", sub or 0
	return r
end
function Frame:CreateTexture(name, layer, template, sub)
	local t = newRegion(self, "Texture", name, layer, template, sub)
	if template ~= nil then H.uncertain["CreateTexture template " .. tostring(template)] = "texture template" end
	return t
end
function Frame:CreateMaskTexture(name, layer, template, sub) return newRegion(self, "MaskTexture", name, layer, template, sub) end
function Frame:CreateLine(name, layer, template, sub) return newRegion(self, "Line", name, layer, template, sub) end
function Frame:CreateFontString(name, layer, template)
	local fs = newRegion(self, "FontString", name, layer)
	local fst = S[fs]
	fst.textWidth, fst.textHeight = textWidth, textHeight
	if template ~= nil then
		local fo = type(template) == "string" and FONT_OBJECTS[template] or (type(template) == "table" and template.path and template)
		if not fo then
			error(("CreateFontString(): Couldn't find inherited node \"%s\""):format(tostring(template)), 2)
		end
		fst.font = { path = fo.path, size = fo.size, flags = fo.flags }
	end
	return fs
end

-- backdrop (BackdropTemplate only)
local Backdrop = {}
function Backdrop:SetBackdrop(b)
	if b ~= nil and type(b) ~= "table" then argerr(self, "SetBackdrop", "Usage: SetBackdrop(backdropInfo)") end
	st(self).backdrop = b
	if b then
		if b.bgFile then H.checkFile(st(self).client, b.bgFile, "texture", { ".tga", ".blp" }) end
		if b.edgeFile then H.checkFile(st(self).client, b.edgeFile, "texture", { ".tga", ".blp" }) end
	end
end
function Backdrop:SetBackdropColor(r, g, b, a)
	if not st(self).backdrop then error("SetBackdropColor(): no backdrop set", 2) end
end
function Backdrop:SetBackdropBorderColor(r, g, b, a)
	if not st(self).backdrop then error("SetBackdropBorderColor(): no backdrop set", 2) end
end
function Backdrop:GetBackdrop() return st(self).backdrop end
function Backdrop:ApplyBackdrop() end

---------------------------------------------------------------------------
-- Button, CheckButton, EditBox, Slider, StatusBar, ScrollFrame, GameTooltip, Cooldown
---------------------------------------------------------------------------

local Button = class("Button", "Frame")
local CLICKS = {}
for _, b in ipairs({ "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5", "Any" }) do
	CLICKS[b .. "Up"] = true
	CLICKS[b .. "Down"] = true
end
function Button:RegisterForClicks(...)
	local s = st(self)
	s.clicks = {}
	for i = 1, select("#", ...) do
		local c = select(i, ...)
		if not CLICKS[c] then argerr(self, "RegisterForClicks", "Unknown click type " .. tostring(c)) end
		s.clicks[c] = true
	end
end
function Button:SetText(text)
	local s = st(self)
	if text ~= nil and type(text) ~= "string" and type(text) ~= "number" then argerr(self, "SetText", "Usage: SetText(text)") end
	if not s.fontString then
		-- a plain button makes its own text when given one, with the normal font object
		if not s.normalFont then
			s.text = text and tostring(text) or nil
			if text and text ~= "" then error("Button:SetText(): Font not set (no SetNormalFontObject or font string)", 2) end
			return
		end
		s.fontString = Frame.CreateFontString(self, nil, "OVERLAY")
		S[s.fontString].font = s.normalFont
		s.fontString:SetPoint("CENTER", self, "CENTER")
	end
	s.fontString:SetText(text)
	s.text = text and tostring(text) or nil
end
function Button:GetText()
	local s = st(self)
	if s.fontString then return s.fontString:GetText() end
	return s.text
end
function Button:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
function Button:GetTextWidth() local s = st(self) return s.fontString and s.fontString:GetStringWidth() or 0 end
function Button:SetFontString(fs) st(self).fontString = fs end
function Button:GetFontString() return st(self).fontString end
local function fontObj(o)
	if type(o) == "string" then o = FONT_OBJECTS[o] end
	if type(o) == "table" and o.path then return { path = o.path, size = o.size, flags = o.flags } end
	if isWidget(o) and S[o].font then return S[o].font end
	return nil
end
function Button:SetNormalFontObject(o)
	local f = fontObj(o)
	if not f then argerr(self, "SetNormalFontObject", "Usage: SetNormalFontObject(font)") end
	st(self).normalFont = f
	if st(self).fontString then S[st(self).fontString].font = f end
end
function Button:SetHighlightFontObject(o) end
function Button:SetDisabledFontObject(o) end
function Button:GetNormalFontObject() return nil end
local function buttonTexture(self, key, tex, method)
	local s = st(self)
	if tex == nil then s[key] = nil return end
	if isWidget(tex) then s[key] = tex return end
	if type(tex) ~= "string" and type(tex) ~= "number" then argerr(self, method, "Usage: " .. method .. "(file or texture)") end
	local t = s[key] or Frame.CreateTexture(self, nil, key == "highlightTex" and "HIGHLIGHT" or "ARTWORK")
	t:SetTexture(tex)
	t:SetAllPoints(self)
	s[key] = t
end
function Button:SetNormalTexture(t) buttonTexture(self, "normalTex", t, "SetNormalTexture") end
function Button:SetPushedTexture(t) buttonTexture(self, "pushedTex", t, "SetPushedTexture") end
function Button:SetHighlightTexture(t, mode) buttonTexture(self, "highlightTex", t, "SetHighlightTexture") end
function Button:SetDisabledTexture(t) buttonTexture(self, "disabledTex", t, "SetDisabledTexture") end
function Button:GetNormalTexture() return st(self).normalTex end
function Button:GetPushedTexture() return st(self).pushedTex end
function Button:GetHighlightTexture() return st(self).highlightTex end
function Button:GetDisabledTexture() return st(self).disabledTex end
function Button:SetNormalAtlas(a) end
function Button:SetHighlightAtlas(a) end
function Button:SetPushedAtlas(a) end
function Button:Enable()
	local s = st(self)
	if s.enabled == false then s.enabled = true runScript(self, "OnEnable") end
end
function Button:Disable()
	local s = st(self)
	if s.enabled ~= false then s.enabled = false runScript(self, "OnDisable") end
end
function Button:SetEnabled(v) if v then self:Enable() else self:Disable() end end
function Button:IsEnabled() return st(self).enabled ~= false end
function Button:LockHighlight() end
function Button:UnlockHighlight() end
function Button:SetButtonState(state, lock) st(self).buttonState = state end
function Button:GetButtonState() return st(self).buttonState or "NORMAL" end
function Button:SetMotionScriptsWhileDisabled(v) end
-- Click() from code: the same handlers, not a hardware event (unless one is under way)
function Button:Click(button, down)
	local s = st(self)
	s.client:runClick(self, button or "LeftButton", down and true or false)
end

local CheckButton = class("CheckButton", "Button")
function CheckButton:SetChecked(v) st(self).checked = v and true or false end
function CheckButton:GetChecked() return st(self).checked == true end
function CheckButton:SetCheckedTexture(t) buttonTexture(self, "checkedTex", t, "SetCheckedTexture") end
function CheckButton:GetCheckedTexture() return st(self).checkedTex end
function CheckButton:SetDisabledCheckedTexture(t) end

local EditBox = class("EditBox", "Frame")
function EditBox:SetText(t)
	if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then argerr(self, "SetText", "Usage: SetText(text)") end
	local s = st(self)
	s.text = t and tostring(t) or ""
	s.highlight = nil
	runScript(self, "OnTextChanged", false)
end
function EditBox:GetText() return st(self).text or "" end
function EditBox:Insert(t) local s = st(self) s.text = (s.text or "") .. tostring(t) runScript(self, "OnTextChanged", false) end
function EditBox:GetNumber() return tonumber(st(self).text or "") or 0 end
function EditBox:SetNumber(n) self:SetText(tostring(n)) end
function EditBox:SetAutoFocus(v) st(self).autoFocus = v and true or false end
function EditBox:IsAutoFocus() return st(self).autoFocus ~= false end
function EditBox:SetFocus()
	local s = st(self)
	s.client.focusedEdit = self
	if not s.focus then s.focus = true runScript(self, "OnEditFocusGained") end
end
function EditBox:ClearFocus()
	local s = st(self)
	if s.focus then s.focus = false runScript(self, "OnEditFocusLost") end
end
function EditBox:HasFocus() return st(self).focus == true end
function EditBox:SetMaxLetters(n) st(self).maxLetters = n end
function EditBox:GetMaxLetters() return st(self).maxLetters or 0 end
function EditBox:SetMaxBytes(n) st(self).maxBytes = n end
function EditBox:SetNumeric(v) st(self).numeric = v end
function EditBox:SetMultiLine(v) st(self).multiLine = v end
function EditBox:IsMultiLine() return st(self).multiLine == true end
-- H.shareEditFont (off by default): the real game gives an EditBox made with no template the ONE font
-- object that ChatFrame1EditBox uses, so SetFont on such a box changes the chat box too (Polestar's
-- notes, lesson 11: "an EditBox without a template shares its font object with the chat box";
-- the addon-learning notes). SetFontObject(own object) gives the box a font of its own.
local function sharedEditFont(self)
	if not H.shareEditFont or st(self).ownFont then return nil end
	local c = st(self).client
	c.sharedEditFont = c.sharedEditFont or { path = "Fonts\\ARIALN.TTF", size = 14, flags = "" }
	return c.sharedEditFont
end
function EditBox:SetFontObject(o)
	local f = fontObj(o)
	if not f then argerr(self, "SetFontObject", "Usage: SetFontObject(font)") end
	st(self).font = f
	st(self).ownFont = true
end
function EditBox:SetFont(path, size, flags)
	local ok = checkFontArgs(self, "SetFont", path, size, flags)
	local shared = sharedEditFont(self)
	if ok and shared then shared.path, shared.size, shared.flags = path, size, flags or "" end
	if ok and not shared then st(self).font = { path = path, size = size, flags = flags or "" } end
	if ok and H.textMetrics and not st(self).fontAt then -- (preview mode) when this string first got a font
		st(self).fontAt = st(self).client.world.time
	end
	return ok
end
function EditBox:GetFont() local f = sharedEditFont(self) or st(self).font if f then return f.path, f.size, f.flags end end
function EditBox:SetTextColor(r, g, b, a) end
function EditBox:SetTextInsets(l, r, t, b) end
function EditBox:SetJustifyH(j) end
function EditBox:SetJustifyV(j) end
function EditBox:SetShadowColor() end
function EditBox:SetShadowOffset() end
-- (r244) the selection is recorded: H.state[box].highlight = { from, to } (to = -1: through the end); SetText drops it, as the client does
function EditBox:HighlightText(a, b) st(self).highlight = { a or 0, b or -1 } end
function EditBox:SetCursorPosition(n) end
function EditBox:GetCursorPosition() return #(st(self).text or "") end
function EditBox:SetBlinkSpeed(n) end
function EditBox:SetCountInvisibleLetters(v) end
function EditBox:SetHistoryLines(n) end
function EditBox:AddHistoryLine(t) end
function EditBox:SetSpacing(n) end
function EditBox:SetAltArrowKeyMode(v) end
function EditBox:SetEnabled(v) st(self).enabled = v and true or false end
function EditBox:Enable() st(self).enabled = true end
function EditBox:Disable() st(self).enabled = false end
function EditBox:IsEnabled() return st(self).enabled ~= false end

local Slider = class("Slider", "Frame")
function Slider:SetMinMaxValues(a, b) st(self).min, st(self).max = a, b end
function Slider:GetMinMaxValues() return st(self).min or 0, st(self).max or 0 end
function Slider:SetValue(v)
	local s = st(self)
	if type(v) ~= "number" then argerr(self, "SetValue", "Usage: SetValue(value)") end
	s.value = v
	runScript(self, "OnValueChanged", v, false)
end
function Slider:GetValue() return st(self).value or 0 end
function Slider:SetValueStep(v) end
function Slider:SetObeyStepOnDrag(v) end
function Slider:SetOrientation(o) end
function Slider:SetThumbTexture(t) end
function Slider:SetStepsPerPage(n) end
function Slider:Enable() end
function Slider:Disable() end

local StatusBar = class("StatusBar", "Frame")
function StatusBar:SetMinMaxValues(a, b)
	if type(a) ~= "number" or type(b) ~= "number" then argerr(self, "SetMinMaxValues", "Usage: SetMinMaxValues(min, max)") end
	st(self).min, st(self).max = a, b
end
function StatusBar:GetMinMaxValues() return st(self).min or 0, st(self).max or 1 end
function StatusBar:SetValue(v)
	if type(v) ~= "number" then argerr(self, "SetValue", "Usage: SetValue(value)") end
	st(self).value = v
	runScript(self, "OnValueChanged", v)
end
function StatusBar:GetValue() return st(self).value or 0 end
function StatusBar:SetStatusBarTexture(t)
	local s = st(self)
	if not s.barTex then s.barTex = Frame.CreateTexture(self, nil, "ARTWORK") end
	if isWidget(t) then s.barTex = t else s.barTex:SetTexture(t) end
end
function StatusBar:GetStatusBarTexture()
	local s = st(self)
	if not s.barTex then s.barTex = Frame.CreateTexture(self, nil, "ARTWORK") end
	return s.barTex
end
function StatusBar:SetStatusBarColor(r, g, b, a) end
function StatusBar:SetOrientation(o) end
function StatusBar:SetReverseFill(v) end
function StatusBar:SetFillStyle(v) end

local ScrollFrame = class("ScrollFrame", "Frame")
function ScrollFrame:SetScrollChild(c) st(self).scrollChild = c if c then c:SetParent(self) end end
function ScrollFrame:GetScrollChild() return st(self).scrollChild end
function ScrollFrame:SetVerticalScroll(v) st(self).vscroll = v end
function ScrollFrame:GetVerticalScroll() return st(self).vscroll or 0 end
function ScrollFrame:SetHorizontalScroll(v) st(self).hscroll = v end
function ScrollFrame:GetHorizontalScroll() return st(self).hscroll or 0 end
function ScrollFrame:GetVerticalScrollRange() return 0 end
function ScrollFrame:GetHorizontalScrollRange() return 0 end
function ScrollFrame:UpdateScrollChildRect() end

local Tooltip = class("GameTooltip", "Frame")
-- GameTooltipTextLeft1..n show the lines (the game's own font strings)
local function syncTip(self)
	local s = S[self]
	if not s or not s.lineFS then return end
	for i, fs in ipairs(s.lineFS) do
		local t = (s.tipLines or {})[i]
		S[fs].text = t
		S[fs].shown = t ~= nil
	end
end
H.syncTip = syncTip
function Tooltip:SetOwner(owner, anchor, x, y)
	if not isWidget(owner) then argerr(self, "SetOwner", "Usage: SetOwner(owner [, anchor, x, y])") end
	st(self).owner = owner
	st(self).tipAnchor = { anchor or "ANCHOR_RIGHT", tonumber(x) or 0, tonumber(y) or 0 }
	st(self).tipLines = {}
	st(self).tipMeta = {}
	st(self).tipUnit = nil
	st(self).wuberMirror = nil -- the game's own tooltip from here on, not a copy of Wuber's tip card
	syncTip(self)
end
function Tooltip:GetOwner() return st(self).owner end
function Tooltip:IsOwned(f) return st(self).owner == f end
function Tooltip:ClearLines() st(self).tipLines = {} syncTip(self) end
function Tooltip:AddLine(text, r, g, b, wrap)
	local s = st(self)
	s.tipLines = s.tipLines or {}
	s.tipLines[#s.tipLines + 1] = tostring(text)
	s.tipMeta = s.tipMeta or {}
	s.tipMeta[#s.tipLines] = { tonumber(r), tonumber(g), tonumber(b), wrap and true or false } -- (for tools/preview)
	syncTip(self)
end
function Tooltip:AddDoubleLine(a, b)
	local s = st(self)
	s.tipLines = s.tipLines or {}
	s.tipLines[#s.tipLines + 1] = tostring(a) .. " | " .. tostring(b)
	syncTip(self)
end
function Tooltip:SetText(text)
	st(self).tipLines = { tostring(text) }
	syncTip(self)
end
function Tooltip:NumLines() return #(st(self).tipLines or {}) end
function Tooltip:SetMinimumWidth(w) end
function Tooltip:SetPadding() end
-- the game shows a unit: its name line, then the hooks (OnTooltipSetUnit on older clients,
-- TooltipDataProcessor post-calls on newer ones)
function Tooltip:SetUnit(unit)
	local s = st(self)
	local c = s.client
	if H.caller(2) and c.inTipHook then
		c.world.violations[#c.world.violations + 1] = tostring(H.caller(2)) .. ": GameTooltip:SetUnit() from inside a tooltip hook"
		return
	end
	local u = c:unit(unit)
	s.tipLines = {}
	s.tipUnit = nil
	if not u then return end
	s.tipUnit = unit
	s.tipLines = { u.name, "Level " .. tostring(u.level or 60) }
	syncTip(self)
	setShown(self, true, "Show")
	c.inTipHook = true
	if s.modernTip then
		local data = { type = 2, guid = "Player-1-" .. H.key(u.name), lines = {} }
		for _, kind in ipairs({ 2, "ALL" }) do
			for _, fn in ipairs(c.tipPostCalls[kind] or {}) do
				H.protect(c.world, c, "TooltipDataProcessor post-call", fn, self, data)
			end
		end
	else
		runScript(self, "OnTooltipSetUnit")
	end
	c.inTipHook = false
end
function Tooltip:GetUnit()
	local s = st(self)
	if not s.tipUnit then return nil end
	local c = s.client
	local u = c:unit(s.tipUnit)
	if not u then return nil end
	if c.secrets.UnitName then return SECRET, s.tipUnit end
	return u.name, s.tipUnit
end
function Tooltip:Show()
	local s = st(self)
	if H.caller(2) and s.client.inTipHook then
		s.client.world.violations[#s.client.world.violations + 1] = tostring(H.caller(2)) .. ": GameTooltip:Show() from inside a tooltip hook"
	end
	setShown(self, true, "Show")
end
function Tooltip:GetLines() return st(self).tipLines or {} end
function Tooltip:FadeOut() self:Hide() end

local Cooldown = class("Cooldown", "Frame")
function Cooldown:SetCooldown(start, dur) end
function Cooldown:Clear() end
function Cooldown:SetSwipeColor() end
function Cooldown:SetDrawEdge() end
function Cooldown:SetHideCountdownNumbers() end
function Cooldown:SetReverse() end

local MessageFrame = class("MessageFrame", "Frame")
function MessageFrame:AddMessage(text, r, g, b)
	local s = st(self)
	s.lines = s.lines or {}
	s.lines[#s.lines + 1] = tostring(text)
	local c = s.client
	if s.isChat then c.chatLines[#c.chatLines + 1] = tostring(text) end
end
function MessageFrame:Clear() st(self).lines = {} end
function MessageFrame:SetFading() end
function MessageFrame:SetMaxLines() end
function MessageFrame:SetFontObject() end
function MessageFrame:SetTimeVisible() end
function MessageFrame:SetInsertMode() end
local ScrollingMessageFrame = class("ScrollingMessageFrame", "MessageFrame")
local SimpleHTML = class("SimpleHTML", "Frame")
function SimpleHTML:SetText(t) st(self).text = t end
-- Models and ModelScenes: guarded no-ops (what they draw can only be seen in game). The calls
-- are counted so a test can see the addon used them, and a world can lack ModelScene.
local Model = class("Model", "Frame")
local PlayerModel = class("PlayerModel", "Model")
class("DressUpModel", "PlayerModel")
class("CinematicModel", "PlayerModel")
local function modelNoop(name)
	return function(self, ...)
		local s = st(self)
		s.modelCalls = (s.modelCalls or 0) + 1
		s.client.modelCalls = (s.client.modelCalls or 0) + 1
		return nil
	end
end
for _, m in ipairs({ "SetModel", "SetDisplayInfo", "SetCreature", "SetUnit", "ClearModel", "SetCamDistanceScale", "SetPortraitZoom",
	"SetPosition", "SetFacing", "SetModelScale", "SetAnimation", "SetSequence", "SetSequenceTime", "SetSpellVisualKit", "SetLight",
	"SetFogColor", "ClearFog", "SetKeepModelOnHide", "SetCamera", "SetCustomCamera", "SetCameraPosition", "SetCameraTarget",
	"SetCameraDistance", "SetRotation", "SetPaused", "RefreshCamera", "SetDesaturation", "SetGlow", "SetParticlesEnabled" }) do
	Model[m] = modelNoop(m)
end
function Model:GetFacing() return 0 end
function Model:GetPosition() return 0, 0, 0 end
function Model:GetModelScale() return 1 end
function Model:GetModelFileID() return nil end

local ModelScene = class("ModelScene", "Frame")
local Actor = class("ModelSceneActor", "Object")
function ModelScene:CreateActor(name, template)
	local s = st(self)
	s.client.modelCalls = (s.client.modelCalls or 0) + 1
	local a = H.newWidget(s.client, "ModelSceneActor", name, self, "actor")
	s.actors = s.actors or {}
	table.insert(s.actors, a)
	return a
end
function ModelScene:GetNumActors() return #(st(self).actors or {}) end
function ModelScene:GetActorAtIndex(i) return (st(self).actors or {})[i] end
for _, m in ipairs({ "SetCameraPosition", "SetCameraOrientationByYawPitchRoll", "SetCameraOrientationByAxisVectors",
	"SetCameraFieldOfView", "SetCameraNearClip", "SetCameraFarClip", "SetLightVisible", "SetLightPosition", "SetLightDirection",
	"SetLightAmbientColor", "SetLightDiffuseColor", "SetLightType", "SetFogColor", "SetFogNear", "SetFogFar", "ClearFog",
	"SetViewInsets", "SetPaused", "SetDrawLayer", "SetDesaturation" }) do
	ModelScene[m] = modelNoop(m)
end
function ModelScene:Project3DPointTo2D() return nil end
for _, m in ipairs({ "SetModelByFileID", "SetModelByCreatureDisplayID", "SetModelByUnit", "SetModelByPath", "SetPosition", "SetYaw",
	"SetPitch", "SetRoll", "SetScale", "SetAlpha", "SetSpellVisualKit", "PlayAnimationKit", "StopAnimationKit", "SetAnimation",
	"ClearModel", "SetUseCenterForOrigin", "SetAnimationBlendOperation", "SetDesaturation", "SetParticleOverrideScale" }) do
	Actor[m] = modelNoop(m)
end
function Actor:Show() st(self).shown = true end
function Actor:Hide() st(self).shown = false end
function Actor:SetShown(v) st(self).shown = v and true or false end
function Actor:IsShown() return st(self).shown end
function Actor:IsVisible() return visible(self) end
function Actor:GetScale() return 1 end
function Actor:SetScript(name, fn)
	if name ~= "OnModelLoaded" and name ~= "OnAnimFinished" and name ~= "OnAnimStarted" then
		error(("ModelSceneActor:SetScript(): ModelSceneActor doesn't have a \"%s\" script"):format(tostring(name)), 2)
	end
	st(self).scripts[name] = fn
end

---------------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------------

local AnimGroup = class("AnimationGroup", "Object")
local Anim = class("Animation", "Object")
local AlphaAnim = class("Alpha", "Animation")
local TransAnim = class("Translation", "Animation")
local ScaleAnim = class("Scale", "Animation")
local RotAnim = class("Rotation", "Animation")
local PathAnim = class("Path", "Animation")
local FlipBook = class("FlipBook", "Animation")

function H.newAnimGroup(client, owner, name)
	local g = H.newWidget(client, "AnimationGroup", name, owner, "anim")
	local os = S[owner]
	os.animGroups = os.animGroups or {}
	table.insert(os.animGroups, g)
	S[g].anims = {}
	S[g].looping = "NONE"
	client.animSeq = (client.animSeq or 0) + 1
	S[g].seq = client.animSeq
	client.animGroups[#client.animGroups + 1] = g
	return g
end

local function animScript(self, method, name, fn)
	scriptCheck(self, method, name)
	if fn ~= nil and type(fn) ~= "function" then argerr(self, method, "Usage: " .. method .. "(\"type\", function)") end
end
function AnimGroup:SetScript(name, fn) animScript(self, "SetScript", name, fn) st(self).scripts[name] = fn end
function AnimGroup:GetScript(name) return st(self).scripts[name] end
function AnimGroup:HookScript(name, fn)
	animScript(self, "HookScript", name, fn)
	local s = st(self)
	local old = s.scripts[name]
	s.scripts[name] = old and function(...) old(...) fn(...) end or fn
end
function AnimGroup:CreateAnimation(kind, name, template)
	kind = kind or "Animation"
	if kind == "FlipBook" and st(self).client.world.noFlipBook then
		error(("AnimationGroup:CreateAnimation(): Unknown animation type \"%s\""):format(kind), 2)
	end
	if not classes[kind] or not (kind == "Animation" or lookup(classes[kind], "__name") and (classes[kind].__parent == Anim or kind == "Animation")) then
		error(("AnimationGroup:CreateAnimation(): Unknown animation type \"%s\""):format(tostring(kind)), 2)
	end
	local s = st(self)
	local a = H.newWidget(s.client, kind, name, self, "anim")
	local as = S[a]
	as.duration, as.delay, as.endDelay, as.order, as.smoothing = 0, 0, 0, 1, "NONE"
	table.insert(s.anims, a)
	return a
end
function AnimGroup:GetAnimations() return unpack(st(self).anims) end
function AnimGroup:SetLooping(l)
	if not LOOPING[l] then argerr(self, "SetLooping", "Invalid looping type " .. tostring(l)) end
	st(self).looping = l
end
function AnimGroup:GetLooping() return st(self).looping end
function AnimGroup:GetLoopState() return st(self).playing and "FORWARD" or "NONE" end
function AnimGroup:SetToFinalAlpha(v) st(self).toFinal = v and true or false end
function AnimGroup:IsSetToFinalAlpha() return st(self).toFinal == true end
local function groupDuration(g)
	local orders = {}
	for _, a in ipairs(S[g].anims) do
		local as = S[a]
		local d = as.delay + as.duration + as.endDelay
		orders[as.order] = math.max(orders[as.order] or 0, d)
	end
	local total = 0
	for _, d in pairs(orders) do total = total + d end
	return total
end
function AnimGroup:GetDuration() return groupDuration(self) end
function AnimGroup:Play(reverse, offset)
	local s = st(self)
	if s.playing and not s.paused then return end
	s.playing, s.paused, s.elapsed = true, false, offset or 0
	s.client.playing[self] = true
	runScript(self, "OnPlay")
	for _, a in ipairs(s.anims) do runScript(a, "OnPlay") end
end
function AnimGroup:Restart(...) self:Stop() self:Play(...) end
function AnimGroup:SetPlaying(v) if v then self:Play() else self:Stop() end end
function AnimGroup:Pause() local s = st(self) if s.playing then s.paused = true runScript(self, "OnPause") end end
function AnimGroup:Stop()
	local s = st(self)
	if not s.playing then return end
	s.playing, s.paused = false, false
	runScript(self, "OnStop", false)
	for _, a in ipairs(s.anims) do runScript(a, "OnStop", false) end
end
function AnimGroup:Finish() local s = st(self) if s.playing then s.elapsed = math.huge end end
function AnimGroup:IsPlaying() return st(self).playing == true and not st(self).paused end
function AnimGroup:IsPaused() return st(self).paused == true end
function AnimGroup:IsDone() return not st(self).playing end
function AnimGroup:IsPendingFinish() return false end
function AnimGroup:GetProgress()
	local s = st(self)
	local d = groupDuration(self)
	if not s.playing or d <= 0 then return 0 end
	return math.min(1, (s.elapsed or 0) / d)
end
function AnimGroup:GetElapsed() return st(self).elapsed or 0 end
function AnimGroup:SetIgnoreFramerateThrottle(v) end

-- the clock moves an animation group on
function H.stepAnimGroup(g, dt)
	local s = S[g]
	if not s.playing or s.paused then return end
	local owner = s.parent
	s.elapsed = (s.elapsed or 0) + dt
	if s.scripts.OnUpdate then runScript(g, "OnUpdate", dt) end
	local d = groupDuration(g)
	if s.elapsed < d then return end
	if s.looping ~= "NONE" and d > 0 then
		s.elapsed = s.elapsed % d
		runScript(g, "OnLoop", "FORWARD")
		return
	end
	s.playing = false
	if s.toFinal then
		for _, a in ipairs(s.anims) do
			local as = S[a]
			if as.otype == "Alpha" and as.toAlpha then
				local target = as.target or owner
				if target and S[target] then S[target].alpha, S[target].alphaAsked = as.toAlpha, nil end
			end
		end
	end
	for _, a in ipairs(s.anims) do runScript(a, "OnFinished", false) end
	runScript(g, "OnFinished", false)
end

function Anim:SetScript(name, fn) animScript(self, "SetScript", name, fn) st(self).scripts[name] = fn end
function Anim:GetScript(name) return st(self).scripts[name] end
function Anim:HookScript(name, fn)
	animScript(self, "HookScript", name, fn)
	local s = st(self)
	local old = s.scripts[name]
	s.scripts[name] = old and function(...) old(...) fn(...) end or fn
end
local function num(self, method, v, min)
	if type(v) ~= "number" or v ~= v then argerr(self, method, "Usage: " .. method .. "(number)") end
	if min and v < min then argerr(self, method, "value must be >= " .. min) end
end
function Anim:SetDuration(d) num(self, "SetDuration", d, 0) st(self).duration = d end
function Anim:GetDuration() return st(self).duration end
function Anim:SetStartDelay(d) num(self, "SetStartDelay", d, 0) st(self).delay = d end
function Anim:GetStartDelay() return st(self).delay end
function Anim:SetEndDelay(d) num(self, "SetEndDelay", d, 0) st(self).endDelay = d end
function Anim:GetEndDelay() return st(self).endDelay end
function Anim:SetSmoothing(sm)
	if not SMOOTH[sm] then argerr(self, "SetSmoothing", "Invalid smoothing type " .. tostring(sm)) end
	st(self).smoothing = sm
end
function Anim:GetSmoothing() return st(self).smoothing end
function Anim:SetOrder(o)
	num(self, "SetOrder", o, 0)
	if o > 100 then argerr(self, "SetOrder", "order must be <= 100") end
	st(self).order = o
end
function Anim:GetOrder() return st(self).order end
function Anim:SetTarget(t)
	if not isWidget(t) then argerr(self, "SetTarget", "Usage: SetTarget(region)") end
	st(self).target = t
end
function Anim:GetTarget() return st(self).target or S[st(self).parent].parent end
function Anim:SetTargetKey(k) st(self).targetKey = k end
function Anim:SetChildKey(k)
	if type(k) ~= "string" then argerr(self, "SetChildKey", "Usage: SetChildKey(key)") end
	st(self).childKey = k
end
function Anim:SetTargetName(n) st(self).targetName = n end
function Anim:SetTargetParent() end
function Anim:GetRegionParent() return S[st(self).parent].parent end
function Anim:GetProgress() return 0 end
function Anim:GetSmoothProgress() return 0 end
function Anim:GetElapsed() return 0 end
function Anim:IsPlaying() return S[st(self).parent].playing == true end
function Anim:IsDone() return not S[st(self).parent].playing end
function Anim:IsStopped() return not S[st(self).parent].playing end
function Anim:Play() end
function Anim:Stop() end
function Anim:Pause() end

local function originArgs(self, method, point, x, y)
	if not POINTS[point] then argerr(self, method, "Usage: " .. method .. "(point, offsetX, offsetY)") end
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, method, "offsets must be numbers") end
end
function AlphaAnim:SetFromAlpha(a) num(self, "SetFromAlpha", a) st(self).fromAlpha = a end
function AlphaAnim:SetToAlpha(a) num(self, "SetToAlpha", a) st(self).toAlpha = a end
function AlphaAnim:GetFromAlpha() return st(self).fromAlpha or 0 end
function AlphaAnim:GetToAlpha() return st(self).toAlpha or 0 end
function TransAnim:SetOffset(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetOffset", "Usage: SetOffset(x, y)") end
	st(self).offset = { x, y }
end
function TransAnim:GetOffset() local o = st(self).offset or { 0, 0 } return o[1], o[2] end
function ScaleAnim:SetScaleFrom(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetScaleFrom", "Usage: SetScaleFrom(x, y)") end
	st(self).scaleFrom = { x, y }
end
function ScaleAnim:SetScaleTo(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetScaleTo", "Usage: SetScaleTo(x, y)") end
	st(self).scaleTo = { x, y }
end
function ScaleAnim:SetFromScale(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetFromScale", "Usage: SetFromScale(x, y)") end
	st(self).scaleFrom = { x, y }
end
function ScaleAnim:SetToScale(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetToScale", "Usage: SetToScale(x, y)") end
	st(self).scaleTo = { x, y }
end
function ScaleAnim:SetScale(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then argerr(self, "SetScale", "Usage: SetScale(x, y)") end
	st(self).scaleTo = { x, y }
end
function ScaleAnim:GetScale() local s = st(self).scaleTo or { 1, 1 } return s[1], s[2] end
function ScaleAnim:GetScaleFrom() local s = st(self).scaleFrom or { 1, 1 } return s[1], s[2] end -- (job 2903) the motion monitor reads it
function ScaleAnim:SetOrigin(point, x, y) originArgs(self, "SetOrigin", point, x, y) end
function ScaleAnim:GetOrigin() return "CENTER", 0, 0 end
function RotAnim:SetDegrees(d) num(self, "SetDegrees", d) st(self).degrees = d end
function RotAnim:GetDegrees() return st(self).degrees or 0 end
function RotAnim:SetRadians(r) num(self, "SetRadians", r) st(self).degrees = r * 180 / math.pi end
function RotAnim:GetRadians() return (st(self).degrees or 0) * math.pi / 180 end
function RotAnim:SetOrigin(point, x, y) originArgs(self, "SetOrigin", point, x, y) end
function RotAnim:GetOrigin() return "CENTER", 0, 0 end
function PathAnim:CreateControlPoint() return nil end
for _, m in ipairs({ "SetFlipBookRows", "SetFlipBookColumns", "SetFlipBookFrames", "SetFlipBookFrameWidth", "SetFlipBookFrameHeight" }) do
	FlipBook[m] = function(self, n) num(self, m, n, 0) st(self)[m] = n end
end
function PathAnim:SetCurve(c) end

---------------------------------------------------------------------------
-- Making widgets
---------------------------------------------------------------------------

local FRAME_TYPES = { Frame = true, Button = true, CheckButton = true, EditBox = true, Slider = true, StatusBar = true,
	ScrollFrame = true, GameTooltip = true, Cooldown = true, MessageFrame = true, ScrollingMessageFrame = true,
	SimpleHTML = true, Model = true, PlayerModel = true, DressUpModel = true, CinematicModel = true, ModelScene = true }

function H.newWidget(client, otype, name, parent, kind)
	local obj = setmetatable({}, meta(otype))
	local s = {
		client = client, otype = otype, kind = kind, name = nil, parent = parent, children = {}, points = {},
		shown = true, alpha = 1, scale = 1, scripts = {}, events = {}, attrs = {},
	}
	S[obj] = s
	if parent then table.insert(S[parent].children, obj) end
	-- (BRIEF21 S5) made visible: visible from this frame on (made under a hidden parent: from when it shows)
	if visible(obj) then s.bornAt = client and client.world and client.world.drawn or 0 end
	if type(name) == "string" and name ~= "" then
		if parent and S[parent].name then name = name:gsub("%$parent", S[parent].name) else name = name:gsub("%$parent", "") end
		s.name = name
		rawset(client.env, name, obj)
	end
	client.widgets[#client.widgets + 1] = obj
	if kind == "frame" then client.frames[#client.frames + 1] = obj end
	return obj
end

-- Blizzard's templates the addon may use
local TEMPLATES = {}
TEMPLATES.SecureActionButtonTemplate = function(f, s) s.secure = true end
TEMPLATES.SecureHandlerBaseTemplate = function(f, s) s.secure = true end
TEMPLATES.BackdropTemplate = function(f, s)
	s.backdropTemplate = true
	for k, v in pairs(Backdrop) do rawset(f, k, v) end
end
TEMPLATES.UIPanelButtonTemplate = function(f, s, client)
	if s.otype ~= "Button" and s.otype ~= "CheckButton" then error("UIPanelButtonTemplate on a " .. s.otype) end
	f.Left = Frame.CreateTexture(f, nil, "BACKGROUND")
	f.Middle = Frame.CreateTexture(f, nil, "BACKGROUND")
	f.Right = Frame.CreateTexture(f, nil, "BACKGROUND")
	s.normalFont = { path = "Fonts\\FRIZQT__.TTF", size = 12, flags = "" }
	local fs = Frame.CreateFontString(f, nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER", f, "CENTER")
	s.fontString = fs
	f.Text = fs
end
TEMPLATES.UIPanelCloseButton = function(f, s)
	s.normalFont = { path = "Fonts\\FRIZQT__.TTF", size = 12, flags = "" }
	s.scripts.OnClick = function(self) local p = self:GetParent() if p then p:Hide() end end
end
TEMPLATES.UIPanelCloseButtonNoScripts = function(f, s) end
TEMPLATES.InputBoxTemplate = function(f, s)
	if s.otype ~= "EditBox" then error("InputBoxTemplate on a " .. s.otype) end
	f.Left = Frame.CreateTexture(f, nil, "BACKGROUND")
	f.Middle = Frame.CreateTexture(f, nil, "BACKGROUND")
	f.Right = Frame.CreateTexture(f, nil, "BACKGROUND")
	s.font = { path = "Fonts\\ARIALN.TTF", size = 12, flags = "" }
	s.scripts.OnEscapePressed = function(self) self:ClearFocus() end
end
TEMPLATES.UICheckButtonTemplate = function(f, s)
	if s.otype ~= "CheckButton" then error("UICheckButtonTemplate on a " .. s.otype) end
	local fs = Frame.CreateFontString(f, nil, "ARTWORK", "GameFontNormalSmall")
	f.Text = fs
	f.text = fs
end
TEMPLATES.GameTooltipTemplate = function(f, s) end
TEMPLATES.TooltipBorderedFrameTemplate = function(f, s) end
TEMPLATES.UIPanelScrollFrameTemplate = function(f, s)
	f.ScrollBar = H.newWidget(s.client, "Slider", nil, f, "frame")
end

function H.fakeOptionsList(env, client, kind)
-- The game's Options > AddOns registry. Default "new" (this build has only the Settings API; every client gets it unless
-- a client's prepare calls H.fakeOptionsList(env, client, "old") (the old API only, to test the fallback) or "none").
-- Source: addon-study FAKE-GAME-HINTS (Settings.RegisterCanvasLayoutCategory + Settings.RegisterAddOnCategory in the
-- newer client; InterfaceOptions_AddCategory(frame) with frame.name in the older one). Registered pages land in
-- client.settingsCats ({ frame, name, ID }) or client.optionPanels; the game's own window is never closed here
-- (client.gameOptionsClosed stays 0 unless an addon calls HideUIPanel on it).
env = client.api or env -- the game's own API table (a write to env itself would count as an addon global)
if kind == "new" then
	client.settingsCats = {}
	env.InterfaceOptions_AddCategory, env.InterfaceOptionsFrame_OpenToCategory = nil, nil -- absent in this build
	env.Settings = {
		-- two values, as in the game (build 71037 source): the category and its layout
		RegisterCanvasLayoutCategory = function(frame, name) return { frame = frame, name = name, ID = name }, { frame = frame, name = name } end,
		RegisterAddOnCategory = function(cat) client.settingsCats[#client.settingsCats + 1] = cat end,
		OpenToCategory = function(id) client.openedCategory = id end,
	}
elseif kind == "none" then
	client.settingsCats, client.optionPanels = nil, nil
	env.Settings, env.InterfaceOptions_AddCategory = nil, nil
elseif kind == "old" then
	client.optionPanels = {}
	env.Settings = nil
	env.InterfaceOptions_AddCategory = function(frame) client.optionPanels[#client.optionPanels + 1] = frame end
	env.InterfaceOptionsFrame_OpenToCategory = function(frame) client.openedCategory = frame end
end
end

function H.createFrame(client, ftype, name, parent, template, id)
	if type(ftype) ~= "string" or not FRAME_TYPES[ftype] or (ftype == "ModelScene" and client.world.noModelScene) then
		error(("CreateFrame: Unknown frame type '%s'"):format(tostring(ftype)), 2)
	end
	if name ~= nil and type(name) ~= "string" then error("CreateFrame: name must be a string or nil", 2) end
	if type(parent) == "string" then parent = client.env[parent] end
	if parent ~= nil and not isWidget(parent) then error("CreateFrame: parent must be a frame", 2) end
	local list = {}
	if template ~= nil then
		if type(template) ~= "string" then error("CreateFrame: template must be a string", 2) end
		for t in template:gmatch("[^,%s]+") do
			if not TEMPLATES[t] then error(("CreateFrame: Couldn't find inherited node \"%s\""):format(t), 2) end
			list[#list + 1] = t
		end
	end
	local f = H.newWidget(client, ftype, name, parent, "frame")
	local s = S[f]
	if parent and H.mapTaint then H.mapTaint.created(client, parent) end -- (tests/lib/maptaint.lua, rule a)
	if parent and H.taint then H.taint.parented(client, parent) end -- (the taint guard: a frame under a game window)
	s.mouse = (ftype == "Button" or ftype == "CheckButton" or ftype == "EditBox" or ftype == "Slider") or nil
	if ftype == "Button" or ftype == "CheckButton" then s.clicks = { LeftButtonUp = true } end
	if ftype == "EditBox" then s.autoFocus = true s.text = "" end
	for _, t in ipairs(list) do TEMPLATES[t](f, s, client) end
	s.templates = list
	if ftype == "EditBox" and s.autoFocus and visible(f) then
		-- an EditBox with autofocus grabs the keyboard when shown: a classic trap
		s.focus = true
	end
	return f
end

---------------------------------------------------------------------------
-- Script runs: errors are caught and recorded (the client would show them)
---------------------------------------------------------------------------

local function traceback(e) return debug.traceback(tostring(e), 2) end

function H.protect(world, client, where, fn, ...)
	local args = { n = select("#", ...), ... }
	local ok, err = xpcall(function() return fn(unpack(args, 1, args.n)) end, traceback)
	if not ok then
		world.errors[#world.errors + 1] = (client and client.player.name or "?") .. " " .. where .. ": " .. tostring(err)
	end
	return ok
end

runScript = function(obj, name, ...)
	local s = S[obj]
	local fn = s and s.scripts[name]
	if not fn then return end
	H.protect(s.client.world, s.client, (s.name or s.otype) .. ":" .. name, fn, obj, ...)
end
H.runScript = runScript

---------------------------------------------------------------------------
-- Maps: a fake geography (continent units 0..10000) good enough for pins
---------------------------------------------------------------------------

-- (design round 4, E3) World positions are as the real client gives them: yards, x north, y west, and a map's u
-- runs along MINUS world y, its v along MINUS world x (the real flight-map fit, lab-real-facts "mapCal": u = -4.1e-5 y
-- + c, v = -4.1e-5 x + f). Per continent: map = the continent map's west edge (world y), north edge (world x), width
-- and height in yards (the classic client's public numbers; 3:2, as the 1002 x 668 art); land = the same four for the
-- box the zone rectangles below (units 0..10000, x right, y down) are spread over: the coastline, so every zone and
-- every player stands on land. The continents' own rectangles (units) are worked out from these below the table.
H.WORLD = {
	[1] = { map = { 17066.6, 12799.9, 36799.81, 24533.2 }, land = { 4200, 11100, 11900, 20900 } },
	[0] = { map = { 18171.97, 11176.34, 40741.18, 27149.69 }, land = { 3200, 10400, 11200, 25400 } },
}

-- id = { name, mapType (0 cosmic, 1 world, 2 continent, 3 zone, 4 dungeon, 5 micro), parent, rect = { x, y, w, h } on the continent }
H.MAPS = {
	[947] = { "Azeroth", 1, nil },
	[1414] = { "Kalimdor", 2, 947, { 0, 0, 10000, 10000 }, continent = 1 }, -- the two continents' rects are replaced below (H.WORLD)
	[1415] = { "Eastern Kingdoms", 2, 947, { 0, 0, 10000, 10000 }, continent = 0 },
	[1413] = { "The Barrens", 3, 1414, { 4500, 3500, 2000, 3500 } },
	[1411] = { "Durotar", 3, 1414, { 6600, 3000, 1200, 2000 } },
	[1454] = { "Orgrimmar", 3, 1411, { 6800, 3000, 600, 500 } },
	[1412] = { "Mulgore", 3, 1414, { 3500, 5000, 1000, 1500 } },
	[1456] = { "Thunder Bluff", 3, 1412, { 3700, 5300, 300, 250 } },
	[1446] = { "Tanaris", 3, 1414, { 5200, 8000, 1500, 1500 } },
	[1444] = { "Feralas", 3, 1414, { 2200, 6800, 1400, 1500 } },
	[1445] = { "Dustwallow Marsh", 3, 1414, { 6500, 5800, 1200, 1200 } },
	[1443] = { "Desolace", 3, 1414, { 2000, 4500, 1200, 1300 } },
	[1442] = { "Stonetalon Mountains", 3, 1414, { 2800, 3200, 1200, 1300 } },
	[1440] = { "Ashenvale", 3, 1414, { 3500, 2200, 2400, 1000 } },
	[1441] = { "Thousand Needles", 3, 1414, { 4800, 7000, 1400, 900 } },
	[1451] = { "Silithus", 3, 1414, { 2500, 8300, 1000, 1000 } },
	[1452] = { "Winterspring", 3, 1414, { 5800, 800, 1500, 1500 } },
	[1438] = { "Teldrassil", 3, 1414, { 3000, 200, 900, 900 } },
	[1457] = { "Darnassus", 3, 1438, { 3100, 400, 300, 300 } },
	[1420] = { "Tirisfal Glades", 3, 1415, { 3000, 1500, 1500, 1000 } },
	[1458] = { "Undercity", 3, 1420, { 3900, 1900, 300, 250 } },
	[1429] = { "Elwynn Forest", 3, 1415, { 3500, 7200, 1300, 900 } },
	[1453] = { "Stormwind City", 3, 1429, { 3600, 7300, 400, 350 } },
	[1426] = { "Dun Morogh", 3, 1415, { 3800, 5000, 1300, 900 } },
	[1455] = { "Ironforge", 3, 1426, { 4300, 5200, 300, 250 } },
	[1434] = { "Stranglethorn Vale", 3, 1415, { 3300, 8300, 1300, 1600 } },
	[1424] = { "Hillsbrad Foothills", 3, 1415, { 3800, 3000, 1100, 900 } },
	[1423] = { "Eastern Plaguelands", 3, 1415, { 6000, 1500, 1300, 1100 } },
	[1428] = { "Burning Steppes", 3, 1415, { 4500, 6300, 1100, 700 } },
	[1418] = { "Badlands", 3, 1415, { 5300, 5600, 900, 700 } },
	[1435] = { "Swamp of Sorrows", 3, 1415, { 5300, 7600, 900, 700 } },
	[1417] = { "Arathi Highlands", 3, 1415, { 5000, 3200, 1000, 900 } },
	[1425] = { "The Hinterlands", 3, 1415, { 5600, 2500, 1100, 900 } },
	[1416] = { "Alterac Mountains", 3, 1415, { 3900, 2300, 900, 700 } },
	[1419] = { "Blasted Lands", 3, 1415, { 5400, 8400, 900, 900 } },
	[1421] = { "Silverpine Forest", 3, 1415, { 2700, 2500, 1100, 1300 } },
}

-- a named spot: where a player can stand
H.SPOTS = {
	Ratchet = { mapID = 1413, x = 0.627, y = 0.370, zone = "The Barrens", sub = "Ratchet" },
	Crossroads = { mapID = 1413, x = 0.517, y = 0.300, zone = "The Barrens", sub = "The Crossroads" },
	Barrens = { mapID = 1413, x = 0.300, y = 0.600, zone = "The Barrens", sub = "" },
	Undercity = { mapID = 1458, x = 0.5, y = 0.5, zone = "Undercity", sub = "" },
	Orgrimmar = { mapID = 1454, x = 0.5, y = 0.5, zone = "Orgrimmar", sub = "Valley of Strength" },
	Stormwind = { mapID = 1453, x = 0.5, y = 0.5, zone = "Stormwind City", sub = "Trade District" },
	Ironforge = { mapID = 1455, x = 0.5, y = 0.5, zone = "Ironforge", sub = "" },
	["Thunder Bluff"] = { mapID = 1456, x = 0.5, y = 0.5, zone = "Thunder Bluff", sub = "" },
	["Booty Bay"] = { mapID = 1434, x = 0.270, y = 0.770, zone = "Stranglethorn Vale", sub = "Booty Bay" },
	Gadgetzan = { mapID = 1446, x = 0.515, y = 0.285, zone = "Tanaris", sub = "Gadgetzan" },
	["Tarren Mill"] = { mapID = 1424, x = 0.620, y = 0.200, zone = "Hillsbrad Foothills", sub = "Tarren Mill" },
	Everlook = { mapID = 1452, x = 0.615, y = 0.385, zone = "Winterspring", sub = "Everlook" },
	["Blackrock Mountain"] = { mapID = 1428, x = 0.300, y = 0.300, zone = "Burning Steppes", sub = "Blackrock Mountain" },
	Durotar = { mapID = 1411, x = 0.5, y = 0.5, zone = "Durotar", sub = "" },
}

-- continent units <-> world yards
local function unitsToYards(cont, cx, cy)
	local l = H.WORLD[cont].land
	return l[2] - cy / 10000 * l[4], l[1] - cx / 10000 * l[3]
end
local function yardsToUnits(cont, wx, wy)
	local l = H.WORLD[cont].land
	return (l[1] - wy) / l[3] * 10000, (l[2] - wx) / l[4] * 10000
end
H.unitsToYards, H.yardsToUnits = unitsToYards, yardsToUnits
for _, m in pairs(H.MAPS) do
	if m.continent then
		local g = H.WORLD[m.continent]
		local x0, y0 = yardsToUnits(m.continent, g.map[2], g.map[1])
		m[4] = { x0, y0, g.map[3] / g.land[3] * 10000, g.map[4] / g.land[4] * 10000 }
	end
end

function H.continentOf(mapID)
	local m = H.MAPS[mapID]
	local guard = 0
	while m and guard < 10 do
		if m[2] == 2 then return m.continent, mapID end
		mapID = m[3]
		m = mapID and H.MAPS[mapID]
		guard = guard + 1
	end
	return nil
end

-- map (x, y 0..1) -> continent and world yards (x north, y west)
function H.toWorld(mapID, x, y)
	local m = H.MAPS[mapID]
	if not m or not m[4] then return nil end
	local cont = H.continentOf(mapID)
	if not cont then return nil end
	local r = m[4]
	return cont, unitsToYards(cont, r[1] + x * r[3], r[2] + y * r[4])
end

function H.fromWorld(cont, wx, wy, mapID)
	local m = H.MAPS[mapID]
	if not m or not m[4] or H.continentOf(mapID) ~= cont then return nil end
	local r = m[4]
	local cx, cy = yardsToUnits(cont, wx, wy)
	return (cx - r[1]) / r[3], (cy - r[2]) / r[4]
end

-- OpenMap's stitched world: Kalimdor on the left half, the Eastern Kingdoms on the right
function H.stitchedFromWorld(cont, wx, wy)
	if cont ~= 0 and cont ~= 1 then return nil end
	local cx, cy = yardsToUnits(cont, wx, wy)
	if cont == 1 then return 0.02 + cx / 10000 * 0.44, 0.05 + cy / 10000 * 0.9 end
	return 0.54 + cx / 10000 * 0.44, 0.05 + cy / 10000 * 0.9
end
function H.worldFromStitched(u, v)
	if u < 0.5 then return 1, unitsToYards(1, (u - 0.02) / 0.44 * 10000, (v - 0.05) / 0.9 * 10000) end
	return 0, unitsToYards(0, (u - 0.54) / 0.44 * 10000, (v - 0.05) / 0.9 * 10000)
end

-- the deepest map at a world point
function H.mapAt(cont, wx, wy)
	local best, bestArea
	if not H.WORLD[cont] or type(wx) ~= "number" or type(wy) ~= "number" then return nil end
	wx, wy = yardsToUnits(cont, wx, wy)
	for id, m in pairs(H.MAPS) do
		if m[4] and H.continentOf(id) == cont then
			local r = m[4]
			if wx >= r[1] and wx <= r[1] + r[3] and wy >= r[2] and wy <= r[2] + r[4] then
				local area = r[3] * r[4]
				if not bestArea or area < bestArea then best, bestArea = id, area end
			end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------

local World = {}
World.__index = World
H.World = World
H.MIN_TIMER = 0.01 -- one frame at 100 fps

H.EPOCH = os.time({ year = 2026, month = 11, day = 17, hour = 19, min = 0, sec = 0 })

local function key(name) return (name:lower():gsub("[%s%-]+", " "):gsub("^ ", ""):gsub(" $", "")) end
H.key = key

function H.NewWorld(opts)
	opts = opts or {}
	math.randomseed(opts.seed or 42)
	local w = setmetatable({
		time = 1000, frameStep = opts.frameStep or 0.1, lastFrame = 1000,
		restricted = opts.restricted ~= false,
		senderFormat = opts.senderFormat or "space", -- how CHAT_MSG_ADDON spells its sender: space, hyphen, realm
		realm = opts.realm, -- every client's realm name unless the client gives its own (nil: H.DEFAULT_REALM, "")
		latency = opts.latency or 0.1,
		joinDelay = opts.joinDelay or 0.3,   -- a join takes a moment before GetChannelName knows it (0.1-0.45 s in the real game)
		joinFails = opts.joinFails or false,
		-- (REC login.channels.fresh, login.pew.fresh) a fresh login starts with no channel; the game's own channels
		-- and ZONE_CHANGED_NEW_AREA come loginDelay s after PLAYER_ENTERING_WORLD. "atOnce": both at login (the old fake)
		channelsArrive = opts.channelsArrive or "real", loginDelay = opts.loginDelay or 3,
		clickMode = opts.clickMode or "modern", -- "modern" (useOnKeyDown attribute / ActionButtonUseKeyDown) or "legacy"
		cvars = { ActionButtonUseKeyDown = opts.useKeyDown == false and "0" or "1",
			nameplateShowFriends = "0", nameplateShowEnemies = "1", nameplateShowAll = "1", nameplateShowFriendlyNPCs = "0",
			nameplateMaxDistance = "41", nameplateMinScale = "0.8", nameplateMaxScale = "1", nameplateGlobalScale = "1",
			nameplateMotion = "0", ShowClassColorInFriendlyNameplate = "1", Sound_EnableSFX = "1", Sound_EnableAllSound = "1",
			InputDeviceInterfaceStyle = "0", taintLog = "1",
			screenshotFormat = "jpeg" }, -- (PF-049 L13.style: mouse and keyboard; PF-061 L18: the taint log switch reads 1)
		tooltipStyle = opts.tooltipStyle or "processor", -- "processor" (TooltipDataProcessor) or "legacy" (OnTooltipSetUnit)
		noModelScene = opts.noModelScene,
		noFlipBook = opts.noFlipBook, -- a client without the FlipBook animation type
		throttleBurst = opts.throttleBurst or 10, throttleRate = opts.throttleRate or 1,
		clubsOn = opts.clubs == true, -- C_Club in every client (World:addClub)
		-- AcceptGroup / LeaveParty work from events and timers in modern clients (Leatrix Plus does it);
		-- a world can still ask for the old strict rule
		acceptGroupNeedsClick = opts.acceptGroupNeedsClick == true,
		confirmSummonNeedsClick = opts.confirmSummonNeedsClick == true,
		tradeOrder = opts.tradeOrder, -- nil: the recorded order; "old" (money, close, line), "real", "closeMoneyLine" (World:tradeAccept)
		mouseEvents = opts.mouseEvents, -- (fga f) false: a click fires no GLOBAL_MOUSE_DOWN/UP
		cancelSummonOnExit = opts.cancelSummonOnExit, -- false: no CANCEL_SUMMON on leaving a group (World:groupExit)
		summonArrival = opts.summonArrival, -- "old": every summon lands 1 s after with a loading screen (World:confirmSummon)
		summonFar = opts.summonFar, -- seconds from ConfirmSummon to a far summon's PLAYER_ENTERING_WORLD (default H.SUMMON_FAR)
		-- ON by default (PF-062 L19: the real game has the call): nil is { delay = 0.2 }; false gives no C_ChatInfo.RequestCanLocalWhisperTarget
		-- and no CAN_LOCAL_WHISPER_TARGET_RESPONSE event. A table shapes it: { delay = 0.2 (seconds to the answer), silent = true (never
		-- answers), wrong = true (says "offline" for an online player) }; a test may change the table's fields while it runs.
		whisperCheck = opts.whisperCheck == nil and { delay = 0.2 } or (opts.whisperCheck or nil), -- (PF-062 L19: the real client has the call and answers 0 in about 0.12-0.23 s; whisperCheck = false: a client without it)
		incomingSummon = opts.incomingSummon ~= false, -- (PF-043 L1.table: the real client has C_IncomingSummon; incomingSummon = false: one without it)
		reloadAllowed = opts.reloadAllowed == true, -- (PF-050 L13.blocked: ReloadUI from addon code is blocked in the real client; true: an old fake that reloads)
		-- (FAKE-GAME-HINTS 39, TimbersRaidSummoner.lua:3100-3112, implied by its code only) the Soul Shard goes when the
		-- summon completes, not when the cast starts: the default here. shardAtCast = true is a game where that hint is
		-- wrong and the shard goes as the cast turns into the channel (so a count that dropped proves nothing)
		shardAtCast = opts.shardAtCast == true,
		zonePvpInfo = opts.zonePvpInfo == true, -- the real client has no GetZonePVPInfo; true: the old fake one (lib/fakes8.lua)
		players = {}, clients = {}, timers = {}, seq = 0, channels = {},
		whispers = {}, macros = {}, invites = {}, violations = {}, blocked = {}, errors = {}, missingFiles = {},
		addonLog = {}, summons = {}, casts = 0, trades = 0, ritualName = "Ritual of Summoning",
	}, World)
	return w
end

function World:player(name) return name and self.players[key(name)] or nil end

function World:placePlayer(p, spot)
	local s = type(spot) == "table" and spot or H.SPOTS[spot]
	if not s then error("no such spot: " .. tostring(spot)) end
	p.mapID, p.x, p.y = s.mapID, s.x, s.y
	p.zone = s.zone or H.MAPS[s.mapID][1]
	p.subZone = s.sub or ""
end

function World:addBot(name, opts)
	opts = opts or {}
	local first, surname = name:match("^(%S+)%s+(.+)$")
	local p = {
		name = name, first = first or name, surname = surname, online = true, money = opts.money or 1000000,
		shards = opts.shards or 0, acceptsInvites = opts.acceptsInvites ~= false, declines = opts.declines,
		acceptsSummon = opts.acceptsSummon ~= false, combat = false, class = opts.class or "MAGE", level = opts.level or 60,
		faction = opts.faction or "Horde",
	}
	self:placePlayer(p, opts.spot or "Orgrimmar")
	self.players[key(name)] = p
	return p
end

function World:after(delay, fn, client, where)
	self.seq = self.seq + 1
	-- as in the game, a timer fires on a later frame at the earliest (never at the same instant)
	local t = { at = self.time + math.max(H.MIN_TIMER, delay or 0), fn = fn, seq = self.seq, client = client, where = where or "timer" }
	self.timers[#self.timers + 1] = t
	return t
end

-- frames with an OnUpdate script, per client (in the order they got one)
function H.trackUpdate(f)
	local s = S[f]
	local c = s.client
	if c.updaterSet[f] then return end
	c.updaterSet[f] = true
	c.updaters[#c.updaters + 1] = f
end

-- one frame of every client: OnUpdate scripts and animations
function World:frame(dt)
	for _, c in ipairs(self.clients) do
		if c.alive then
			local list = c.updaters
			for i = 1, #list do
				local f = list[i]
				local s = S[f]
				if s.scripts.OnUpdate and visible(f) then runScript(f, "OnUpdate", dt) end
			end
			if next(c.playing) ~= nil then -- (BRIEF21 S3) most frames play no animation: no list, no sort
				local playing = {}
				for g in pairs(c.playing) do playing[#playing + 1] = g end
				table.sort(playing, function(a, b) return S[a].seq < S[b].seq end)
				for _, g in ipairs(playing) do
					H.stepAnimGroup(g, dt)
					if not S[g].playing then c.playing[g] = nil end
				end
			end
		end
	end
	-- (BRIEF21 S5) the game draws the frame: what shows now has been drawn
	self.drawn = (self.drawn or 0) + 1
end

-- Runs the clock forward, firing every timer that falls due and every frame on the way.
function World:advance(seconds)
	local target = self.time + seconds
	-- (BRIEF21 S3) the timer due first is looked for again only when the list changed: a timer is only
	-- ever added (World:after, a repeat: both bump self.seq) or removed here (the list gets shorter)
	local best, index
	local seenN, seenSeq, timers = -1, -1, nil
	while true do
		if #self.timers ~= seenN or self.seq ~= seenSeq or self.timers ~= timers then
			best, index = nil, nil
			for i, t in ipairs(self.timers) do
				if t.at <= target and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then best, index = t, i end
			end
			timers, seenN, seenSeq = self.timers, #self.timers, self.seq
		end
		local nextFrame = self.lastFrame + self.frameStep
		if nextFrame <= target and (not best or nextFrame <= best.at) then
			self.time = nextFrame
			self.lastFrame = nextFrame
			self:frame(self.frameStep)
		elseif best then
			table.remove(self.timers, index)
			if best.at > self.time then self.time = best.at end
			if not best.cancelled and (not best.client or best.client.alive) then
				if best.every then
					self.seq = self.seq + 1
					best.at, best.seq = self.time + best.every, self.seq
					if best.iterations then
						best.iterations = best.iterations - 1
						if best.iterations > 0 then self.timers[#self.timers + 1] = best end
					else
						self.timers[#self.timers + 1] = best
					end
				end
				H.protect(self, best.client, best.where, best.fn)
			end
		else
			break
		end
	end
	self.time = target
end

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------

local DEFAULT_CHANNELS = { "General", "Trade", "LocalDefense", "LookingForGroup" }
local DEFAULT_CHANNEL_SET = {}
for _, n in ipairs(DEFAULT_CHANNELS) do DEFAULT_CHANNEL_SET[n:lower()] = true end

function World:channelOf(p, index)
	for _, c in ipairs(p.channels) do
		if c.index == index then return c end
	end
	return nil
end

function World:joinChannel(client, name)
	local p = client.player
	client.joinCalls = (client.joinCalls or 0) + 1
	if type(name) ~= "string" or name == "" then error("Usage: JoinTemporaryChannel(name [, password, frameID, hasVoice])", 3) end
	for _, c in ipairs(p.channels) do
		if c.name:lower() == name:lower() then return end
	end
	local locked = self.channels[name:lower()]
	if locked and locked.password then
		self:after(self.joinDelay, function()
			client:fire("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "", "", name, "", "", 0, 0, name)
		end, client, "channel join")
		client.joinFailures = (client.joinFailures or 0) + 1
		return
	end
	if self.joinFails or #p.channels >= 10 then
		self:after(self.joinDelay, function()
			client:fire("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", name, "", "", 0, 0, name)
		end, client, "channel join")
		client.joinFailures = (client.joinFailures or 0) + 1
		return
	end
	-- (channel.join.timing: "GetChannelList already shows the channel (index=6 channels=7) when the call returns, but CheckChannel is
	-- false; 0.1-0.45 s later CHANNEL_UI_UPDATE and CheckChannel true") the list has it at once, GetChannelName only after joinDelay
	local used = {}
	for _, c in ipairs(p.channels) do used[c.index] = true end
	local index = 1
	while used[index] do index = index + 1 end
	local entry = { index = index, name = name, pending = true }
	table.insert(p.channels, entry)
	table.sort(p.channels, function(a, b) return a.index < b.index end)
	self:after(self.joinDelay, function()
		local still = false
		for _, c in ipairs(p.channels) do if c == entry then still = true end end
		if not still then return end -- left again before the join finished
		entry.pending = nil
		local ch = self.channels[name:lower()]
		local created = false
		if not ch then
			ch = { name = name, members = {} }
			self.channels[name:lower()] = ch
			created = true
		end
		ch.members[client] = true
		client:fire("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", index .. ". " .. name, "", "", 0, index, name)
		if created then -- (PF-046 L5.notice) the creator is made owner and moderator: two NOTICE_USER notices
			local me = p.name
			client:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "OWNER_CHANGED", "", "", index .. ". " .. name, me, "", "", 0, index, name)
			client:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "SET_MODERATOR", "", "", index .. ". " .. name, me, "", "", 0, index, name)
		end
		client:fire("CHANNEL_UI_UPDATE")
	end, client, "channel join")
	return 0, name
end

-- Test helpers (FAKE-GAME-HINTS 21): who owns a channel, and someone setting a password on it. A password makes a join
-- fail with a WRONG_PASSWORD notice (the Blizzard notice name; the exact words are not proven in game).
function World:setChannelOwner(name, client)
	local ch = self.channels[name:lower()]
	if not ch then ch = { name = name, members = {} }; self.channels[name:lower()] = ch end
	ch.owner = client
end

function World:setChannelPassword(name, pw, actor)
	local ch = self.channels[name:lower()]
	if not ch then return end
	ch.password = pw
	for c in pairs(ch.members) do
		c:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", "", "", name, actor or "?", "", "", 0, name)
	end
end

function World:leaveChannel(client, name)
	local p = client.player
	for i, c in ipairs(p.channels) do
		if c.name:lower() == name:lower() then
			table.remove(p.channels, i)
			local ch = self.channels[name:lower()]
			if ch then ch.members[client] = nil end
			client.leftChannels = (client.leftChannels or 0) + 1
			if client.healOnRejoin then client.channelCopy, client.healOnRejoin = nil, nil end
			client:fire("CHANNEL_UI_UPDATE")
			return
		end
	end
end

-- Forever's internal realms: the same custom channel name joined on two of them makes two
-- separate channels. A client in another copy gets none of the channel messages of the
-- main copy (nor they its own); whispers still go everywhere. copy nil: back to the main one.
-- opts.healOnRejoin: leaving the channel puts it back in the main copy.
function World:splitChannel(client, copy, opts)
	client.channelCopy = copy
	client.healOnRejoin = opts and opts.healOnRejoin or nil
end

-- Whether two clients are in the same copy of a custom channel (the game's own channels
-- are shared by everyone).
function World:sameCopy(a, b, cname)
	if cname and DEFAULT_CHANNEL_SET[cname:lower()] then return true end
	-- a community stream's channel is Battle.net's: it reaches every internal realm
	if cname and cname:lower():find("^community:") then return true end
	return (a.channelCopy or "") == (b.channelCopy or "")
end

-- A loading screen: custom channels may be lost
function World:dropChannels(client)
	local p = client.player
	for i = #p.channels, 1, -1 do
		local c = p.channels[i]
		local ch = self.channels[c.name:lower()]
		if ch then
			ch.members[client] = nil
			table.remove(p.channels, i)
		end
	end
	client:fire("CHANNEL_UI_UPDATE")
end

function World:channelMembers(name)
	local ch = self.channels[name:lower()]
	local out = {}
	if not ch then return out end
	for c in pairs(ch.members) do out[#out + 1] = c end
	-- in the order the clients were made: pairs() over a table keyed by clients follows their
	-- addresses, which change from run to run (the behaviour transcript must not)
	local seq = {}
	for i, c in ipairs(self.clients) do seq[c] = i end
	table.sort(out, function(a, b) return (seq[a] or math.huge) < (seq[b] or math.huge) end)
	return out
end

---------------------------------------------------------------------------
-- Communities (C_Club): a world with opts.clubs = true gives every client C_Club
---------------------------------------------------------------------------
-- w:addClub({ id, name, streams = { { streamId, name, streamType, leadersAndModeratorsOnly } },
--   members = { ["Anita Lift"] = 1 } })  roles: 1 owner, 2 leader, 3 moderator, 4 member.
-- A stream's channel is "Community:<id>:<streamId>" and crosses internal realms (sameCopy).
-- w.clubInviteNeedsRealm: SendCharacterInvitation errors for a name without "-Realm".
-- w.acceptInvitationFails: AcceptInvitation raises. w.communitySend: the result (or "error")
-- of an addon message on a community channel (nil: delivered).
function World:addClub(c)
	self.clubs = self.clubs or {}
	c.streams = c.streams or { { streamId = 1, name = "General", streamType = 0 } }
	local members = {}
	for n, role in pairs(c.members or {}) do members[key(n)] = role end
	c.members = members
	c.invites = c.invites or {}
	self.clubs[#self.clubs + 1] = c
	return c
end

function World:club(id)
	for _, c in ipairs(self.clubs or {}) do
		if c.id == id then return c end
	end
	return nil
end

function World:clubInfo(c)
	local n = 0
	for _ in pairs(c.members) do n = n + 1 end
	return { clubId = c.id, name = c.name, shortName = c.name, clubType = 1, memberCount = n, description = "" }
end

-- an invitation to a club from inviter (a name), to player name: CLUB_INVITATION_ADDED_FOR_SELF
function World:clubInvite(c, inviter, name)
	local k = key(name)
	c.invites[k] = { inviter = inviter, at = self.time }
	local p = self.players[k]
	if p and p.client and p.client.alive then p.client:fire("CLUB_INVITATION_ADDED_FOR_SELF", { club = self:clubInfo(c) }) end
end

---------------------------------------------------------------------------
-- Addon messages and whispers
---------------------------------------------------------------------------

local VALID_CHAT = { PARTY = true, RAID = true, GUILD = true, OFFICER = true, WHISPER = true, CHANNEL = true, INSTANCE_CHAT = true, SAY = true, YELL = true }
H.SEND_RESULT = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4,
	NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11,
	TargetOffline = 12 } -- 13 values, ChatConstantsDocumentation.lua SendAddonMessageResult
H.REGISTER_RESULT = { Success = 0, DuplicatePrefix = 1, InvalidPrefix = 2, MaxPrefixes = 3 }
-- the chat events carry 18 values (ChatInfoDocumentation.lua CHAT_MSG_WHISPER); a short call gets the rest as the game's blanks
local CHAT18 = { "", "", "", "", "", "", 0, 0, "", 0, 0, "", 0, false, false, false, false, {} }
H.CHAT18_EVENTS = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_CHANNEL = true, CHAT_MSG_CHANNEL_NOTICE = true,
	CHAT_MSG_CHANNEL_NOTICE_USER = true, CHAT_MSG_GUILD = true, CHAT_MSG_SYSTEM = true }
local function padChat(event, ...)
	local a = { n = select("#", ...), ... }
	if H.CHAT18_EVENTS[event] then
		for i = a.n + 1, 18 do a[i] = CHAT18[i] end
		if a.n < 18 then a.n = 18 end
	end
	return a
end

H.CHAT_LOCKED = 11 -- the game's number for "addon messages are locked just now"
H.TOUCHY_SECS = 5

function World:senderName(p)
	if self.senderFormat == "hyphen" then return (p.name:gsub(" ", "-")) end
	if self.senderFormat == "realm" then return p.name .. "-Forever" end
	return p.name
end

-- the throttle: a bucket of messages per client that refills over time
-- (one bucket per prefix, as the game's allowance is per prefix: 10, +1 a second)
local function takeToken(w, client, prefix)
	client.buckets = client.buckets or {}
	local b = client.buckets[prefix or "?"]
	if not b then
		b = { tokens = w.throttleBurst, at = w.time }
		client.buckets[prefix or "?"] = b
	end
	local now = w.time
	b.tokens = math.min(w.throttleBurst, b.tokens + (now - b.at) * w.throttleRate)
	b.at = now
	if b.tokens < 1 then return false end
	b.tokens = b.tokens - 1
	return true
end

-- how many ~fields (the kind first) a round-one client sends
H.ROUND_ONE_FIELDS = { D = 13, R = 5 }

function World:sendAddon(client, prefix, text, chatType, target)
	local p = client.player
	-- bad input is answered with a SendAddonMessageResult, never a Lua error (the documented API returns a number); a nil chat type is the party
	if type(prefix) ~= "string" or prefix == "" or #prefix > 16 then return H.SEND_RESULT.InvalidPrefix end
	if type(text) ~= "string" then return H.SEND_RESULT.InvalidMessage end
	if chatType == nil then chatType = "PARTY" end
	if type(chatType) ~= "string" or not VALID_CHAT[chatType] then return H.SEND_RESULT.InvalidChatType end
	if #text > 255 then
		self.violations[#self.violations + 1] = p.name .. ": addon message of " .. #text .. " bytes: " .. text:sub(1, 60)
		return H.SEND_RESULT.InvalidMessage
	end
	if text:find("<secret>", 1, true) then
		self.violations[#self.violations + 1] = p.name .. ": a secret value went into an addon message: " .. text
	end
	if client.roundOne and prefix == "WUBER" then
		-- a round-one client: no P, and D / R without the round-two fields at the end
		local k = text:match("^([^~]*)")
		if k == "P" then
			client.strippedP = (client.strippedP or 0) + 1
			return 0
		end
		local keep = H.ROUND_ONE_FIELDS[k]
		if keep then
			local parts = {}
			for f in (text .. "~"):gmatch("(.-)~") do parts[#parts + 1] = f end
			if #parts > keep then
				client.stripped = (client.stripped or 0) + 1
				text = table.concat(parts, "~", 1, keep)
			end
		end
	end
	local entry = { from = p.name, prefix = prefix, text = text, chatType = chatType, target = target, at = self.time }
	if chatType == "WHISPER" then
		if type(target) ~= "string" or target == "" then return H.SEND_RESULT.TargetRequired end
	elseif chatType == "CHANNEL" then
		local index = tonumber(target)
		if not index then return H.SEND_RESULT.InvalidChannel end
		local c = self:channelOf(p, index)
		if not c then
			entry.result = H.SEND_RESULT.InvalidChannel
			client.sendFailures = (client.sendFailures or 0) + 1
			self.addonLog[#self.addonLog + 1] = entry
			return H.SEND_RESULT.InvalidChannel
		end
		entry.channel = c.name
		if c.name:lower():find("^community:") then
			client.commSends = (client.commSends or 0) + 1
			local how = self.communitySend
			if type(how) == "function" then how = how(client, text) end
			if how == "error" then error("C_ChatInfo.SendAddonMessage(): this channel doesn't take addon messages", 3) end
			if how ~= nil and how ~= 0 then
				entry.result = how
				self.addonLog[#self.addonLog + 1] = entry
				return how
			end
		end
	elseif chatType == "PARTY" or chatType == "RAID" then
		if not p.group then
			entry.result = H.SEND_RESULT.NotInGroup
			self.addonLog[#self.addonLog + 1] = entry
			return H.SEND_RESULT.NotInGroup
		end
	end
	local kind = prefix == "WUBER" and text:match("^([^~]*)") or nil
	if client.chatLock then
		-- the game's chat lock (a raid or boss fight): every addon send is refused with 11
		-- (FAKE-GAME-HINTS LRN-G03; Polestar stub_party.lua 213 lists 11 as "locked"). Off by default.
		entry.result = H.CHAT_LOCKED
		client.lockRefused = (client.lockRefused or 0) + 1
		self.addonLog[#self.addonLog + 1] = entry
		return H.CHAT_LOCKED
	end
	if self.touchyLoad and client.pewAt and self.time - client.pewAt < H.TOUCHY_SECS then
		-- the touchy period after a loading screen (LRN-G04; ChatThrottleLib 321-323, 436-441):
		-- a send in the first seconds is answered "too fast". Off by default (w.touchyLoad).
		client.touchyRefused = (client.touchyRefused or 0) + 1
		entry.result = H.SEND_RESULT.AddonMessageThrottle
		self.addonLog[#self.addonLog + 1] = entry
		return H.SEND_RESULT.AddonMessageThrottle
	end
	if client.addonFails then
		-- a trial or veteran account: the game refuses every addon message
		entry.result = H.SEND_RESULT.GeneralError
		client.sendFailures = (client.sendFailures or 0) + 1
		self.addonLog[#self.addonLog + 1] = entry
		return H.SEND_RESULT.GeneralError
	end
	if self.forceThrottle and self.forceThrottle > 0 then
		self.forceThrottle = self.forceThrottle - 1
		client.throttled = (client.throttled or 0) + 1
		entry.result = H.SEND_RESULT.AddonMessageThrottle
		self.addonLog[#self.addonLog + 1] = entry
		return H.SEND_RESULT.AddonMessageThrottle
	end
	if not takeToken(self, client, prefix) then
		client.throttled = (client.throttled or 0) + 1
		client.throttledBy = client.throttledBy or {}
		client.throttledBy[prefix] = (client.throttledBy[prefix] or 0) + 1
		entry.result = H.SEND_RESULT.AddonMessageThrottle
		self.addonLog[#self.addonLog + 1] = entry
		return H.SEND_RESULT.AddonMessageThrottle
	end
	entry.result = 0
	client.sent = (client.sent or 0) + 1
	self.addonLog[#self.addonLog + 1] = entry
	-- a message lost on the way (the test says which kinds)
	if kind and self.drop and (self.drop[kind] or 0) > 0 then
		self.drop[kind] = self.drop[kind] - 1
		entry.dropped = true
		return 0
	end
	local from = self:senderName(p)
	local w = self
	if chatType == "WHISPER" then
		local to = self:player((target:gsub("%-[^%-]*$", function(realm)
			-- "First-Surname" is a name, "First Surname-Realm" has a realm
			return realm
		end):gsub("%-", " ")))
		if not to then
			-- maybe "Name-Realm"
			to = self:player(target:gsub("%-[^%-]+$", ""))
		end
		self:after(self.latency, function()
			if not to or not to.online then
				-- the chat window shows it unless a message filter hides it
				w.failedAddonWhispers = (w.failedAddonWhispers or 0) + 1
				client:chatEvent("CHAT_MSG_SYSTEM", ("No player named '%s' is currently playing."):format(target))
				return
			end
			if to.client and to.client.alive and to.client.prefixes[prefix] then
				to.client:fire("CHAT_MSG_ADDON", to.client:secretArg("sender", prefix), text, "WHISPER", to.client:secretArg("sender", from), to.name, 0, 0, "", 0)
			end
		end, client, "addon whisper")
	elseif chatType == "CHANNEL" then
		local index = tonumber(target)
		local cname = entry.channel
		self:after(self.latency, function()
			for _, c in ipairs(w:channelMembers(cname)) do
				if c.alive and c.prefixes[prefix] and w:sameCopy(client, c, cname) then
					local local_ = nil
					for _, ch in ipairs(c.player.channels) do if ch.name:lower() == cname:lower() then local_ = ch.index end end
					c:fire("CHAT_MSG_ADDON", prefix, text, "CHANNEL", c:secretArg("sender", from), "", 0, local_ or 0, cname, 0)
				end
			end
		end, client, "addon channel")
	elseif chatType == "PARTY" or chatType == "RAID" then
		local g = p.group
		self:after(self.latency, function()
			if p.group ~= g then return end
			self:eachClient(g, function(c)
				if c.prefixes[prefix] then c:fire("CHAT_MSG_ADDON", prefix, text, chatType, c:secretArg("sender", from), "", 0, 0, "", 0) end
			end)
		end, client, "addon group")
	end
	return 0
end

-- A message from someone without the addon (a bot, an attacker): delivered as the game would.
-- chatType "CHANNEL" reaches every member of channelName (default WuberNet); "WHISPER" reaches toClient.
function World:inject(fromName, text, chatType, toClient, prefix, channelName)
	prefix = prefix or "WUBER"
	local from = fromName
	if chatType == "CHANNEL" then
		local cname = channelName or "WuberNet"
		for _, c in ipairs(self:channelMembers(cname)) do
			if c.alive and c.prefixes[prefix] then
				local idx = 0
				for _, ch in ipairs(c.player.channels) do if ch.name:lower() == cname:lower() then idx = ch.index end end
				c:fire("CHAT_MSG_ADDON", prefix, text, "CHANNEL", from, "", 0, idx, cname, 0)
			end
		end
	else
		if toClient.prefixes[prefix] then
			toClient:fire("CHAT_MSG_ADDON", prefix, text, chatType or "WHISPER", from, toClient.player.name, 0, 0, "", 0)
		end
	end
end

-- messages of Wuber's protocol sent so far (optionally of one kind / from one player)
function World:messages(kind, from, chatType)
	local out = {}
	for _, e in ipairs(self.addonLog) do
		if e.prefix == "WUBER" and e.result == 0 and not e.dropped and (not from or e.from == from) and (not chatType or e.chatType == chatType) then
			local k = e.text:match("^([^~]*)")
			if not kind or k == kind then out[#out + 1] = e end
		end
	end
	return out
end

-- a visible chat line between players. how: "macro" (a secure macro), "addon" (SendChatMessage from an addon), "user"
function World:whisper(client, target, text, how)
	local from = client.player
	-- macroChatWorks = false: a "/w" line in a secure macro never leaves (some clients)
	if how == "macro" and self.macroChatWorks == false then
		self.lostMacroWhispers = (self.lostMacroWhispers or 0) + 1
		return false
	end
	if how == "addon" and self.restricted then
		self.blocked[#self.blocked + 1] = { from = from.name, text = text, to = target }
		self.violations[#self.violations + 1] = from.name .. ": an addon tried to send a chat line (SendChatMessage): " .. tostring(text)
		client:fire("ADDON_ACTION_BLOCKED", client:callerAddon(), "UNKNOWN()")
		return false
	end
	if type(text) == "string" and text:find("<secret>", 1, true) then
		self.violations[#self.violations + 1] = from.name .. ": a secret value went into a whisper: " .. text
	end
	local p = self:player(target)
	if not p or not p.online then
		self.failedWhispers = (self.failedWhispers or 0) + 1
		client:fire("CHAT_MSG_SYSTEM", ("No player named '%s' is currently playing."):format(target))
		return false
	end
	if #text > 255 then
		self.violations[#self.violations + 1] = from.name .. ": chat line longer than 255 characters"
		text = text:sub(1, 255)
	end
	self.whispers[#self.whispers + 1] = { from = from.name, to = p.name, text = text, how = how, at = self.time }
	self.lineID = (self.lineID or 0) + 1
	if p.client and p.client.alive then
		p.client:chatEvent("CHAT_MSG_WHISPER", text, p.client:secretArg("sender", from.name), "", "", from.name, "", 0, 0, "", 0, self.lineID, p.client:secretArg("guid", "Player-1-" .. key(from.name)), 0, false, false, false, false, {})
	end
	client:chatEvent("CHAT_MSG_WHISPER_INFORM", text, p.name, "", "", p.name, "", 0, 0, "", 0, self.lineID, "Player-1-" .. key(p.name), 0, false, false, false, false, {})
	return true
end

-- A whisper typed by a player without a client (a bot): CHAT_MSG_WHISPER on the target's
-- window, as the game delivers it (with message filters applied).
function World:botWhisper(fromName, toClient, text)
	local from = self:player(fromName) or self:addBot(fromName)
	toClient = toClient.player and toClient or (self:player(toClient) and self:player(toClient).client)
	if not (toClient and toClient.alive) then return false end
	self.whispers[#self.whispers + 1] = { from = from.name, to = toClient.player.name, text = text, how = "user", at = self.time }
	self.lineID = (self.lineID or 0) + 1
	toClient:chatEvent("CHAT_MSG_WHISPER", text, toClient:secretArg("sender", self:senderName(from)), "", "", from.name, "", 0, 0, "", 0,
		self.lineID, toClient:secretArg("guid", "Player-1-" .. key(from.name)))
	return true
end

function World:whispersTo(name, how)
	local out = {}
	for _, x in ipairs(self.whispers) do
		if key(x.to) == key(name) and (not how or x.how == how) then out[#out + 1] = x end
	end
	return out
end

-- The ONE chat line addon code may send by itself (CLAUDE.md, "Secure and hardware-click rules"; the author,
-- 21 Nov 2026): Wuber's auto-reply whisper. The game lets an addon whisper without a click (proved in game);
-- Wuber's own rule is narrower, and the fake client holds it to that rule: a WHISPER, sent from the one call
-- site H.REPLY_SITE, to a full two-part name, never to the sender or anyone in the sender's group, never in
-- combat, in a raid or in an instance, and at most once per player per H.REPLY_EVERY seconds.
-- Returns nil when the line may go, else why not (the caller records a violation). src: the calling file
-- (a test may pass it; else the nearest addon file on the stack).
H.REPLY_SITE = "Wuber/Drive/AutoReply.lua"
H.REPLY_EVERY = 3600
function H.replyRule(w, client, kind, target, src)
	local p = client.player
	if type(kind) ~= "string" or kind:upper() ~= "WHISPER" then return "only a whisper may be sent by addon code" end
	if src == nil then
		for level = 2, 40 do
			local info = debug.getinfo(level, "S")
			if not info then break end
			local s = (info.source or ""):gsub("\\", "/")
			for _, dir in pairs(H.ADDONS) do
				if s:find((dir:gsub("\\", "/")), 1, true) then src = s break end
			end
			if src then break end
		end
	end
	src = type(src) == "string" and src:gsub("\\", "/") or ""
	if src:sub(-#H.REPLY_SITE) ~= H.REPLY_SITE then return "not sent from the auto-reply call site (" .. H.REPLY_SITE .. ")" end
	if type(target) ~= "string" or not target:match("^[^%s%-]+[%s%-][^%s%-]+$") then return "not a full two-part name" end
	local t = w:player(target)
	if t and t == p then return "a whisper to yourself" end
	if t and p.group ~= nil and t.group == p.group then return "a whisper to someone in the group" end
	if p.combat then return "in combat" end
	if p.group ~= nil and p.group.raid then return "in a raid" end
	if p.instance then return "in an instance" end
	local last = w.replies and w.replies[p.name] and w.replies[p.name][key(target)]
	if last and w.time - last < H.REPLY_EVERY then return "a second whisper to the same player within the hour" end
	return nil
end

-- The addon file a chat call came from: the nearest addon file on the stack, "" when there is none.
-- from: the stack level to start at (2: the caller of the function that calls this).
function H.chatSite(from)
	for level = (from or 2) + 1, 40 do
		local info = debug.getinfo(level, "S")
		if not info then break end
		local s = (info.source or ""):gsub("\\", "/")
		for _, dir in pairs(H.ADDONS) do
			if s:find((dir:gsub("\\", "/")), 1, true) then return s end
		end
	end
	return ""
end

-- The SECOND and last chat line addon code may send by itself (the decisions round; the author's yes of
-- 21 Nov 2026 22:28): a line Wuber sends by itself to the driver's OWN RIDER (the greeting, the pay reminder),
-- from the one call site H.LINES_SITE. The fake client holds it to its rule, and the module cannot switch this
-- off: a WHISPER, never in combat, a raid or an instance, only to a player who at that moment
--   * is on the sender's list (the sender's DR.customers) as a rider in the group (H.LINE_STATES), never a lead row,
--   * asked this driver by the app or by a whisper (H.LINE_SOURCES; a whisper the fake game itself saw),
--   * is in the sender's group (the fake game's own fact: the driver invited or accepted them),
--   * is no Wuber driver, no crew member and not blocked,
-- and paced: nothing within H.LINES.gap seconds of the sender's last self-sent whisper, at most H.LINES.minute
-- in a minute, no second one to the same player within H.LINES.person seconds, and never the same words to the
-- same player within H.LINES.same seconds. Returns nil when the line may go, else why not: the caller records a
-- violation AND raises. src: the calling file; text: the words.
-- ONE line more, "You're next" (the author asked for it by name): its target need not be in the group, but then must
-- be on the sender's list as a QUEUED rider who asked by a whisper the fake game saw, and the words must be the
-- sender's own "You're next" message for that rider (the greeting or the pay reminder to a queued player raises).
H.LINES_SITE = "Wuber/Drive/AutoLines.lua"
H.LINES = { same = 600, person = 20, gap = 2, minute = 8 }
H.LINE_STATES = { joined = true, summoning = true, waiting = true, arrived = true }
H.LINE_SOURCES = { wuber = true, whisper = true }
function H.linesRule(w, client, kind, target, src, text)
	local p = client.player
	if type(kind) ~= "string" or kind:upper() ~= "WHISPER" then return "only a whisper may be sent by addon code" end
	src = type(src) == "string" and src:gsub("\\", "/") or ""
	if src:sub(-#H.LINES_SITE) ~= H.LINES_SITE then return "not sent from the self-sent lines call site (" .. H.LINES_SITE .. ")" end
	if p.combat then return "in combat" end
	if p.group ~= nil and p.group.raid then return "in a raid" end
	if p.instance then return "in an instance" end
	local t = type(target) == "string" and w:player(target) or nil
	if not t then return "to a player the game does not know" end
	if t == p then return "a whisper to yourself" end
	local Wn = client.W
	local DR = type(Wn) == "table" and Wn.Drive or nil
	local list = type(DR) == "table" and type(DR.customers) == "table" and DR.customers or {}
	local c
	for _, x in pairs(list) do
		if type(x) == "table" and type(x.name) == "string" and w:player(x.name) == t then c = x break end
	end
	if not c then return "to a player who is not on the sender's list" end
	if c.state == "lead" then return "to a lead row, not a rider" end
	local queued = c.state == "queued"
	if not queued and not H.LINE_STATES[c.state] then return "to a rider who is not in the group yet or any more (" .. tostring(c.state) .. ")" end
	if not H.LINE_SOURCES[c.source] then return "to a rider who did not ask this driver by the app or a whisper (" .. tostring(c.source) .. ")" end
	if queued then
		-- waiting in the sender's line: only the "You're next" line, in the sender's words for this rider
		if p.group ~= nil and t.group == p.group then return "to a queued row of a player who is in the group already" end
		local okText, words = pcall(function() return DR.Text("next", c) end)
		if not okText or type(words) ~= "string" or words == "" or words ~= text then
			return "to a rider who waits in the line: only the You're next line may go to them"
		end
	elseif p.group == nil or t.group ~= p.group then
		return "to a player who is not in the sender's group"
	end
	if c.source == "whisper" then
		local asked = false
		for _, x in ipairs(w.whispers) do
			if x.from == t.name and x.to == p.name then asked = true break end
		end
		if not asked then return "to a player who never whispered the sender" end
	end
	local k = c.key or key(c.name)
	if type(Wn.drivers) == "table" and Wn.drivers[k] then return "to another Wuber driver" end
	if type(DR.IsCrewKey) == "function" and DR.IsCrewKey(k) then return "to a crew member" end
	if type(DR.db) == "table" and type(DR.db.blocklist) == "table" and DR.db.blocklist[k] then return "to a blocked player" end
	local minute = 0
	for _, x in ipairs(w.autoLines and w.autoLines[p.name] or {}) do
		local age = w.time - x.at
		if age < 60 then minute = minute + 1 end
		if age < H.LINES.gap then return "two self-sent whispers within " .. H.LINES.gap .. " seconds" end
		if x.to == t.name and age < H.LINES.person then return "two self-sent lines to the same player within " .. H.LINES.person .. " seconds" end
		if x.to == t.name and x.text == text and age < H.LINES.same then return "the same line twice to the same player within 10 minutes" end
	end
	if minute >= H.LINES.minute then return "more than " .. H.LINES.minute .. " self-sent whispers in a minute" end
	return nil
end

-- Public chat lines (a secure macro's "/2 text", "/s text", "/y text"; or w:chatFrom for anyone):
-- CHAT_MSG_CHANNEL to every client of the same faction in a channel of that name (the
-- game's own channels are shared; custom ones only within a channel copy), CHAT_MSG_SAY /
-- _YELL to every client of the same faction. Each line is kept in w.chatPosts { from, kind,
-- channel, index, text, how, at }.
function World:publicLine(fromName, faction, text, kind, cname, how, fromClient)
	local fromLayer = self:layerOf(fromName, fromClient)
	self.chatPosts = self.chatPosts or {}
	if #text > 255 then
		self.violations[#self.violations + 1] = tostring(fromName) .. ": chat line longer than 255 characters"
		text = text:sub(1, 255)
	end
	self.chatPosts[#self.chatPosts + 1] = { from = fromName, kind = kind, channel = cname, text = text, how = how, at = self.time }
	self.lineID = (self.lineID or 0) + 1
	for _, c in ipairs(self.clients) do
		if c.alive and (c.player.faction or "Horde") == (faction or "Horde") then
			if kind == "CHANNEL" then
				for _, ch in ipairs(c.player.channels) do
					if ch.name:lower() == cname:lower() and (not fromClient or self:sameCopy(fromClient, c, cname)) then
						c:chatEvent("CHAT_MSG_CHANNEL", text, c:secretArg("sender", fromName), "", ch.index .. ". " .. ch.name, "", "", 0,
							ch.index, ch.name, 0, self.lineID, c:secretArg("guid", "Player-1-" .. key(fromName)))
					end
				end
			elseif (c.layer or 1) == fromLayer then -- /say and /yell stay within one Forever layer (addon whispers do not)
				c:chatEvent("CHAT_MSG_" .. kind, text, c:secretArg("sender", fromName), "", "", "", "", 0, 0, "", 0, self.lineID, c:secretArg("guid", "Player-1-" .. key(fromName)))
			end
		end
	end
end

-- The Forever layer a speaker is on: a client's opts.layer (default 1); a bot has the layer of
-- w.botLayers[name] (default 1).
function World:layerOf(name, client)
	if client then return client.layer or 1 end
	for _, c in ipairs(self.clients) do
		if c.player.name == name then return c.layer or 1 end
	end
	return (self.botLayers or {})[name] or 1
end

-- A public line from anyone (a bot, or a player without Wuber): kind "CHANNEL" (cname, default
-- "Trade"), "SAY" or "YELL"; faction default "Horde".
function World:chatFrom(fromName, text, kind, cname, faction)
	kind = kind or "CHANNEL"
	self:publicLine(fromName, faction or "Horde", text, kind, cname or "Trade", "user")
end

local SAY_CMDS = { ["/s"] = "SAY", ["/say"] = "SAY", ["/y"] = "YELL", ["/yell"] = "YELL" }

local GUILD_CMDS = { ["/g"] = true, ["/guild"] = true }

local GROUP_CMDS = { ["/p"] = "PARTY", ["/party"] = "PARTY", ["/ra"] = "RAID", ["/raid"] = "RAID", ["/rw"] = "RAID" }

local WHISPER_CMDS = { ["/w"] = true, ["/whisper"] = true, ["/tell"] = true, ["/t"] = true, ["/send"] = true }

function World:runMacro(client, text)
	self.macros[#self.macros + 1] = { by = client.player.name, text = text, at = self.time }
	if #text > 255 then
		self.violations[#self.violations + 1] = client.player.name .. ": macro of " .. #text .. " characters"
		text = text:sub(1, 255)
	end
	for line in (text .. "\n"):gmatch("(.-)\n") do
		line = line:gsub("^%s+", "")
		local cmd, rest = line:match("^(/%S+)%s*(.*)$")
		cmd = cmd and cmd:lower()
		if line == "" then
			-- nothing
		elseif WHISPER_CMDS[cmd] then
			-- Blizzard's chat box: the target is one word ("First-Surname" for regional names)
			local target, message = rest:match("^(%S+)%s+(.+)$")
			if target then
				self:whisper(client, (target:gsub("%-", " ")), message, "macro")
			else
				self.violations[#self.violations + 1] = client.player.name .. ": a /w macro line with no message: " .. line
			end
		elseif cmd and cmd:match("^/%d+$") then
			-- "/2 text": the player's channel number 2
			local index = tonumber(cmd:sub(2))
			local ch = self:channelOf(client.player, index)
			if not ch then
				self.violations[#self.violations + 1] = client.player.name .. ": a macro posts to channel " .. index .. ", which it isn't in"
			elseif rest == "" then
				self.violations[#self.violations + 1] = client.player.name .. ": a channel macro line with no message: " .. line
			else
				self:publicLine(client.player.name, client.player.faction, rest, "CHANNEL", ch.name, "macro", client)
			end
		elseif GROUP_CMDS[cmd or ""] then
			if rest == "" then
				self.violations[#self.violations + 1] = client.player.name .. ": a group chat macro line with no message: " .. line
			else
				self:groupLine(client.player.name, rest, GROUP_CMDS[cmd], "macro")
			end
		elseif GUILD_CMDS[cmd or ""] then
			if rest == "" then
				self.violations[#self.violations + 1] = client.player.name .. ": a guild chat macro line with no message: " .. line
			else
				self:guildLine(client.player.name, rest, "macro")
			end
		elseif SAY_CMDS[cmd or ""] then
			self:publicLine(client.player.name, client.player.faction, rest, SAY_CMDS[cmd], nil, "macro", client)
		elseif cmd == "/target" or cmd == "/tar" then
			local unit = rest:match("^%[@(%w+)%]$")
			local p = unit and client:unit(unit) or self:player((rest:gsub("%-", " ")))
			if p then client.player.target = p end
		elseif cmd == "/cast" then
			self:cast(client, rest)
		elseif cmd == "/uninvite" or cmd == "/kick" then
			self:uninvite(client, rest)
		elseif cmd == "/invite" or cmd == "/inv" then
			self:invite(client, (rest:gsub("%-", " ")))
		elseif cmd == "/run" or cmd == "/script" then
			self.violations[#self.violations + 1] = client.player.name .. ": /run in a secure macro (taint risk): " .. line
		else
			self.violations[#self.violations + 1] = client.player.name .. ": a macro line the game would not understand: " .. line
		end
	end
end

---------------------------------------------------------------------------
-- Groups
---------------------------------------------------------------------------

-- The game's system lines of a group and a trade (fact chat.system.lines: the texts the real client
-- printed, 17-21 Nov 2026), set in every client under the game's global names. ERR_SET_LOOT_GROUP's
-- name is not checked against the game (the text is the recorded one; Wuber does not read it).
H.SYSTEM_LINES = {
	JOINED_PARTY = "%s joins the party.",
	LEFT_PARTY = "%s leaves the party.",
	ERR_UNINVITE_YOU = "You have been removed from the group.",
	ERR_LEFT_GROUP_YOU = "You leave the group.",
	ERR_GROUP_DISBANDED = "Your group has been disbanded.",
	ERR_NEW_LEADER_S = "%s is now the group leader.",
	ERR_INITIATE_TRADE_S = "You have requested to trade with %s.",
	ERR_SET_LOOT_GROUP = "Looting set to Group Loot.",
}
local SYSL = H.SYSTEM_LINES
local function systemLine(c, text)
	if c and c.alive then c:chatEvent("CHAT_MSG_SYSTEM", text) end
end
H.systemLine = systemLine

function World:eachClient(group, fn)
	for _, name in ipairs(group.members) do
		local p = self:player(name)
		if p and p.client and p.client.alive then fn(p.client, p) end
	end
end

function World:rosterChanged(group, extra)
	self:eachClient(group, function(client) client:fire("GROUP_ROSTER_UPDATE") end)
	if extra and extra.client and extra.client.alive then extra.client:fire("GROUP_ROSTER_UPDATE") end
end

-- A raid leader makes a member an assistant (or takes it back): GROUP_ROSTER_UPDATE for all.
function World:setAssist(name, on)
	local p = self:player(name)
	local g = p and p.group
	if not g then return false end
	g.assists = g.assists or {}
	g.assists[p.name] = on and true or nil
	self:rosterChanged(g)
	return true
end

-- The unit token `client` uses for player `other` ("player", "partyN" or "raidN"), or nil.
local function tokenOf(self, other)
	local p = self.player
	if other == p then return "player" end
	local g = p.group
	if not g or other.group ~= g then return nil end
	if g.raid then
		for i, n in ipairs(g.members) do if n == other.name then return "raid" .. i end end
		return nil
	end
	local n = 0
	for _, name in ipairs(g.members) do
		if name ~= p.name then
			n = n + 1
			if name == other.name then return "party" .. n end
		end
	end
	return nil
end

-- A spell event of `caster` as every other window in the group sees it (UNIT_SPELLCAST_* with
-- the caster's unit token there), as the game does for party and raid members.
function World:unitEvent(caster, event, ...)
	local g = caster.group
	if not g then return end
	local args = { ... }
	self:eachClient(g, function(c, p)
		if p ~= caster then
			local token = tokenOf(c, caster)
			if token then c:fire(event, token, unpack(args)) end
		end
	end)
end

-- A party or raid chat line ("/p", "/ra", "/rw" in a macro, or w:groupSay for anyone): CHAT_MSG_
-- PARTY(_LEADER) to the speaker's subgroup of five (in a raid) or the party, CHAT_MSG_RAID(_LEADER)
-- to the whole raid. Kept in w.groupPosts { from, kind, text, how, at }. "/ra" outside a raid
-- is refused by the game (a system line).
function World:groupLine(fromName, text, kind, how)
	local p = self:player(fromName)
	local g = p and p.group
	self.groupPosts = self.groupPosts or {}
	if #text > 255 then
		self.violations[#self.violations + 1] = tostring(fromName) .. ": chat line longer than 255 characters"
		text = text:sub(1, 255)
	end
	if not g or (kind == "RAID" and not g.raid) then
		if how == "macro" then
			self.violations[#self.violations + 1] = tostring(fromName) .. ": a " .. kind:lower() .. " chat line outside a "
				.. (kind == "RAID" and "raid" or "group") .. ": " .. text
		end
		if p and p.client and p.client.alive then
			p.client:fire("CHAT_MSG_SYSTEM", g and "You are not in a raid group." or "You aren't in a party.")
		end
		return false
	end
	local post = { from = p.name, kind = kind, text = text, how = how, at = self.time }
	self.groupPosts[#self.groupPosts + 1] = post
	self.chatPosts = self.chatPosts or {}
	self.chatPosts[#self.chatPosts + 1] = post
	local lead = g.leader == p.name
	local event = (kind == "RAID" and "CHAT_MSG_RAID" or "CHAT_MSG_PARTY") .. (lead and "_LEADER" or "")
	local sub
	if kind == "PARTY" and g.raid then
		for i, n in ipairs(g.members) do if n == p.name then sub = math.floor((i - 1) / 5) end end
	end
	self.lineID = (self.lineID or 0) + 1
	for i, n in ipairs(g.members) do
		local q = self:player(n)
		if q and q.client and q.client.alive and (not sub or math.floor((i - 1) / 5) == sub) then
			q.client:chatEvent(event, text, q.client:secretArg("sender", p.name), "", "", p.name, "", 0, 0, "", 0, self.lineID,
				"Player-1-" .. key(p.name))
		end
	end
	return true
end

-- A guild chat line ("/g", "/guild" in a macro): CHAT_MSG_GUILD to every online player with the same
-- p.guild (a test sets w:player(name).guild = "Some Guild"). Kept in w.guildPosts { from, guild, text,
-- how, at }. A player with no guild posts nothing (the game says "You are not in a guild.").
-- Minimal: no roster, no officer chat, no rank rights (FAKE-GAPS.md).
function World:guildLine(fromName, text, how)
	local p = self:player(fromName)
	self.guildPosts = self.guildPosts or {}
	if #text > 255 then
		self.violations[#self.violations + 1] = tostring(fromName) .. ": chat line longer than 255 characters"
		text = text:sub(1, 255)
	end
	if not p or not p.guild then
		if p and p.client and p.client.alive then p.client:fire("CHAT_MSG_SYSTEM", "You are not in a guild.") end
		return false
	end
	self.guildPosts[#self.guildPosts + 1] = { from = p.name, guild = p.guild, text = text, how = how, at = self.time }
	self.lineID = (self.lineID or 0) + 1
	for _, q in pairs(self.players) do
		if q.guild == p.guild and q.client and q.client.alive then
			q.client:chatEvent("CHAT_MSG_GUILD", text, q.client:secretArg("sender", p.name), "", "", p.name, "", 0, 0, "", 0, self.lineID,
				"Player-1-" .. key(p.name))
		end
	end
	return true
end

-- Somebody without a client (or anyone) says a line in raid chat ("RAID", default when in a raid)
-- or party chat ("PARTY").
function World:groupSay(fromName, text, kind)
	local p = self:player(fromName)
	if not kind then kind = (p and p.group and p.group.raid) and "RAID" or "PARTY" end
	return self:groupLine(fromName, text, kind, "user")
end

-- puts players into one group at once (the test's shortcut for grouping your own alts)
function World:group(names)
	local g = { leader = names[1], members = {}, raid = #names > 5 }
	for _, n in ipairs(names) do
		local p = self:player(n)
		g.members[#g.members + 1] = p.name
		p.group = g
	end
	self:eachClient(g, function(client) client:fire("GROUP_JOINED", 1, "Party-0-" .. g.leader) end)
	self:rosterChanged(g)
	return g
end

-- (fact chat.system.lines) the one who joins reads "Looting set to Group Loot.", the others
-- "X joins the party." (the leader of a group just made: both), in the instant of the roster update
function World:join(inviter, p)
	local g = inviter.group
	local made = false
	if not g then
		g = { leader = inviter.name, members = { inviter.name }, raid = false }
		inviter.group = g
		made = true
		if inviter.client and inviter.client.alive then inviter.client:fire("GROUP_JOINED", 1, "Party-0-" .. g.leader) end
	end
	if #g.members >= 5 and not g.raid then g.raid = true end
	if #g.members >= 40 then return end -- a raid holds 40
	if made then systemLine(inviter.client, SYSL.ERR_SET_LOOT_GROUP) end
	self:eachClient(g, function(c) systemLine(c, SYSL.JOINED_PARTY:format(p.name)) end)
	g.members[#g.members + 1] = p.name
	p.group = g
	systemLine(p.client, SYSL.ERR_SET_LOOT_GROUP)
	if p.client and p.client.alive then p.client:fire("GROUP_JOINED", 1, "Party-0-" .. g.leader) end
	self:rosterChanged(g)
end

-- Out of the group, as the real client (fact group.leave.cancel_summon, 20 of 20 exits): the roster
-- update first, then 0.1 s later (recorded 37-157 ms) the system line (fact chat.system.lines: kind
-- "removed", "left" or "disbanded") and CANCEL_SUMMON in the same instant. CANCEL_SUMMON fires on every
-- exit, a summon or not; any summon still offered goes with it. A world made with
-- H.NewWorld({ cancelSummonOnExit = false }) keeps the old exit (the line, no CANCEL_SUMMON).
local EXIT_LINE = { removed = SYSL.ERR_UNINVITE_YOU, left = SYSL.ERR_LEFT_GROUP_YOU, disbanded = SYSL.ERR_GROUP_DISBANDED }
function World:groupExit(p, kind)
	local c = p.client
	local cancel = self.cancelSummonOnExit ~= false
	if not (c and c.alive) then
		if cancel then p.pendingSummon = nil end
		return
	end
	self:after(0.1, function()
		if p.group then return end -- (back in a group already)
		systemLine(c, EXIT_LINE[kind] or EXIT_LINE.left)
		if not cancel then return end
		p.pendingSummon = nil
		c.popups.CONFIRM_SUMMON = nil
		c:fire("CANCEL_SUMMON")
	end, c, "group exit")
end

-- how: "removed" (World:uninvite) or "left" (LeaveParty, the default)
function World:leave(name, how)
	local p = self:player(name)
	local g = p and p.group
	if not g then return end
	for i, n in ipairs(g.members) do
		if n == p.name then table.remove(g.members, i) break end
	end
	p.group = nil
	if p.client and p.client.alive then
		-- (REC 22 Nov, WuberRec 1.1.0) GROUP_LEFT carries (1, "<->") and CHANNEL_UI_UPDATE fires at the same instant
		p.client:fire("GROUP_LEFT", 1, "<->")
		p.client:fire("CHANNEL_UI_UPDATE")
		p.client:fire("GROUP_ROSTER_UPDATE")
	end
	self:groupExit(p, how == "removed" and "removed" or "left")
	local newLeader = g.leader == p.name and #g.members > 1
	if g.leader == p.name then g.leader = g.members[1] end
	if #g.members == 1 then
		local last = self:player(g.members[1])
		last.group = nil
		if last.client and last.client.alive then
			last.client:fire("GROUP_LEFT", 1, "<->")
			last.client:fire("CHANNEL_UI_UPDATE")
			last.client:fire("GROUP_ROSTER_UPDATE")
		end
		self:groupExit(last, "disbanded")
		return
	end
	-- (fact chat.system.lines) the others: "X leaves the party." with the roster update; a new leader
	-- named 0.1 s later (recorded 50 ms before to 150 ms after)
	self:eachClient(g, function(c) systemLine(c, SYSL.LEFT_PARTY:format(p.name)) end)
	self:rosterChanged(g)
	if newLeader then
		local lead = g.leader
		self:after(0.1, function()
			if p.group == g or g.leader ~= lead then return end
			self:eachClient(g, function(c) systemLine(c, SYSL.ERR_NEW_LEADER_S:format(lead)) end)
		end, nil, "new leader")
	end
end

function World:invite(client, name)
	local inviter = client.player
	if type(name) ~= "string" then error("InviteUnit(name): name must be a string", 3) end
	self.invites[#self.invites + 1] = { from = inviter.name, to = name, at = self.time }
	local p = self:player((name:gsub("%-", " ")))
	-- the server's answer comes a moment later (at once with syncSystem, to test that too)
	local function answer(text)
		if self.syncSystem then client:fire("CHAT_MSG_SYSTEM", text) return end
		self:after(0.2, function() client:fire("CHAT_MSG_SYSTEM", text) end, client, "invite answer")
	end
	if not p or not p.online then
		answer(("Cannot find player '%s'."):format(name))
		return
	end
	if p.group then
		answer(("%s is already in a group."):format(p.name))
		return
	end
	local g = inviter.group
	if g and g.leader ~= inviter.name then
		answer("You are not the party leader.")
		return
	end
	if g and #g.members >= 40 then
		answer(rawget(client.env, "ERR_GROUP_FULL") or "Your party is full.")
		return
	end
	if g and #g.members >= 5 and not g.raid and not self.autoConvert then
		-- a full party: the game asks to make it a raid (CONVERT_TO_RAID); the invite goes out
		-- only once the player says yes (World:answerConvert)
		self.convertAsked = (self.convertAsked or 0) + 1
		client.popups.CONVERT_TO_RAID = { which = "CONVERT_TO_RAID", name = name }
		return
	end
	answer(("You have invited %s to join your group."):format(p.name))
	if p.client and p.client.alive then
		p.pendingInvite = inviter
		local c = p.client
		self:after(self.latency, function()
			if p.pendingInvite ~= inviter then return end
			c.popups.PARTY_INVITE = { which = "PARTY_INVITE" }
			-- (REC invite.args, 41 of 41) the inviter and 8 more: isTank, isHealer, isDamage, isNativeRealm, allowMultipleRoles,
			-- inviterGUID, questSessionActive (the 7 documented for retail) and one this client adds (meaning unknown)
			c:fire("PARTY_INVITE_REQUEST", c:secretArg("sender", inviter.name), false, false, false, true, false, "Player-1-x", false, false)
			-- (REC chat.system.lines, 41 of 41) the invitee's line, in the same frame, after the event
			c:fire("CHAT_MSG_SYSTEM", ("|Hplayer:%s|h[%s]|h has invited you to join a group."):format(inviter.name, inviter.name))
		end, c, "invite")
		return
	end
	if p.declines then
		self:after(1, function() client:fire("CHAT_MSG_SYSTEM", ("%s declines your group invitation."):format(p.name)) end, client, "invite")
	elseif p.acceptsInvites then
		self:after(1, function() if not p.group then self:join(inviter, p) end end, client, "invite")
	end
end

-- The player answers the game's "Convert to raid?" question.
function World:answerConvert(client, yes)
	local d = client.popups.CONVERT_TO_RAID
	if not d then return false end
	client.popups.CONVERT_TO_RAID = nil
	if not yes then return true end
	local g = client.player.group
	if g then
		g.raid = true
		self:rosterChanged(g)
	end
	self:invite(client, d.name)
	return true
end

-- (fga f) the inviter takes a pending invite back (or it times out): the invitee's box goes and PARTY_INVITE_CANCEL (no payload) fires.
function World:withdrawInvite(inviter, p)
	if not p.pendingInvite or p.pendingInvite ~= inviter then return false end
	p.pendingInvite = nil
	local c = p.client
	if c and c.alive then
		c.popups.PARTY_INVITE = nil
		c:fire("PARTY_INVITE_CANCEL") -- no payload (PartyInfoDocumentation.lua): the inviter's name is not given
	end
	return true
end

function World:uninvite(client, name)
	local g = client.player.group
	local p = self:player((name:gsub("%-", " ")))
	if not g or g.leader ~= client.player.name or not p or p.group ~= g then return end
	self:leave(p.name, "removed")
end

---------------------------------------------------------------------------
-- Summons
---------------------------------------------------------------------------

-- A Warlock (team) finishes a summon on a player: the target is asked (CONFIRM_SUMMON).
-- opts.shownBy (round 8): the name C_SummonInfo.GetSummonConfirmSummoner gives instead of the caster's.
-- opts.nameLate (v2.4 fix3 LRN-05): the name is empty for that many seconds after the box opens (default: at once),
-- as a client whose summon box has not filled its caster yet (an addon's note, FAKE-GAME-HINTS lesson LRN-G06).
function World:summon(caster, targetName, opts)
	local c = caster.player or caster
	local t = self:player(targetName)
	assert(t, "no such player " .. tostring(targetName))
	self.summons[#self.summons + 1] = { by = c.name, to = t.name, at = self.time }
	-- (d4 x4) The driver's own Wuber saw its cast (UNIT_SPELLCAST_START records it with DR.Do("CAST")): the
	-- customer's tries is at least 1 and the row says "summoning". A summon landing on a waiting rider with no
	-- cast counted is what the list now reads as "arrived another way" (walked up) and drops after 4 s.
	-- Only when the caster is a live driver client whose list has the target waiting and uncounted, and no
	-- cast of its own is already open (a real w:cast has recorded itself); a crew Warlock's window (the target
	-- is not on its list) tells the crew the same way.
	local dc = c.client
	local DRm = dc and dc.alive and dc.W and dc.W.Drive
	if DRm and DRm.customers and not DRm.cast and DRm.Role and DRm.Role() == "driver" then
		local rc = DRm.customers[dc.W.Key(t.name)]
		if not rc and t.group and t.group == c.group then
			DRm.Do("CAST", t.name)
		elseif rc and (rc.tries or 0) == 0 and (rc.state == "joined" or rc.state == "waiting") then
			DRm.Do("CAST", rc.name)
		end
	end
	local pending = { by = c, at = self.time, mapID = c.mapID, x = c.x, y = c.y, zone = c.zone, sub = c.subZone,
		shownBy = opts and opts.shownBy or nil, nameLate = opts and opts.nameLate or nil, lateWord = opts and opts.lateWord or nil }
	t.pendingSummon = pending
	t.summonAnswer = nil -- (hint 40) a new summon: the game says "pending" again, whatever the last answer was
	if t.client and t.client.alive then
		t.client.popups.CONFIRM_SUMMON = { which = "CONFIRM_SUMMON" }
		t.client:fire("CONFIRM_SUMMON", 0, false)
		self:after(120, function()
			if t.pendingSummon == pending then
				t.pendingSummon = nil
				t.client.popups.CONFIRM_SUMMON = nil
				t.client:fire("CANCEL_SUMMON")
			end
		end, t.client, "summon timeout")
	elseif t.acceptsSummon then
		self:after(3, function()
			t.summonAnswer = { status = 2, at = self.time }
			self:arrive(t, pending)
		end)
	elseif self.incomingSummon then
		-- a bot who answers by hand (World:answerSummon): the offer runs out after 120 s, as a client's does
		self:after(120, function() if t.pendingSummon == pending then t.pendingSummon = nil end end)
	end
end

-- C_IncomingSummon (FAKE-GAME-HINTS 40; SteaSummonForever 1.0.3 summon.lua:467-473 and 1008-1016, its author's
-- comments; the status numbers as EllesmereUI's raid frames read Enum.SummonStatus): what the game tells any client
-- about a group member's summon: 0 none, 1 pending, 2 accepted, 3 declined. Accepted and declined stay for
-- H.SUMMON_STICKY s ("a couple of minutes") after the answer, also when the summon is long over; a new summon says
-- pending again. Nobody has seen this in the game yet (Lab check L1). Off by default, as on a client without the
-- table (no existing test changes): H.NewWorld({ incomingSummon = true }) or World:setIncomingSummon(true) gives every
-- client the table, setIncomingSummon(false) takes it away ("missing"); client:secret("IncomingSummon") makes its
-- answers secret (in an instance).
H.SUMMON_STICKY = 120
function World:summonStatus(p)
	local a = p and p.summonAnswer
	if a and self.time - a.at < H.SUMMON_STICKY then return a.status end
	if p and p.pendingSummon then return 1 end
	return 0
end

function H.incomingSummonApi(w, client)
	local function status(unit)
		if client.secrets.IncomingSummon then return SECRET end
		local u = client:unit(unit)
		local me = client.player
		if not u or (u ~= me and (not me.group or u.group ~= me.group)) then return 0 end -- group members only
		return w:summonStatus(u)
	end
	return {
		IncomingSummonStatus = status,
		HasIncomingSummon = function(unit)
			local s = status(unit)
			if s == SECRET then return SECRET end
			return s ~= 0
		end,
	}
end

function World:setIncomingSummon(on)
	self.incomingSummon = on == true
	for _, c in ipairs(self.clients) do
		-- (the game's API is c.api; c.env, the addons' global table, falls back to it)
		if c.api then c.api.C_IncomingSummon = self.incomingSummon and H.incomingSummonApi(self, c) or nil end
		if c.env and c.env ~= c.api then rawset(c.env, "C_IncomingSummon", nil) end
	end
end

-- A player without a window answers the summon box: accept = true (the game says "accepted" at once; they land
-- H.SUMMON_FAR s later, as a client's far summon does) or false (declined: the box is gone, they stay where they are).
function World:answerSummon(name, accept)
	local p = self:player(name)
	local s = p and p.pendingSummon
	if not s then return false end
	p.summonAnswer = { status = accept and 2 or 3, at = self.time }
	if accept then
		self:after(self.summonFar or H.SUMMON_FAR, function() if p.pendingSummon == s then self:arrive(p, s) end end)
	else
		p.pendingSummon = nil
	end
	return true
end

-- The map just below the continent that holds mapID (a city's zone: Orgrimmar -> Durotar), or nil.
function H.zoneRoot(mapID)
	local guard = 0
	while mapID and guard < 10 do
		local m = H.MAPS[mapID]
		if not m then return nil end
		local up = m[3] and H.MAPS[m[3]]
		if m[2] ~= 2 and up and up[2] == 2 then return mapID end
		mapID = m[3]
		guard = guard + 1
	end
	return nil
end

-- A summon accepted (ConfirmSummon), as the real client did (fact summon.arrival.pew, 14 summons):
-- from the same zone (a city and the zone around it) there is no loading screen and no
-- PLAYER_ENTERING_WORLD, only ZONE_CHANGED_NEW_AREA 0.6 s later (recorded 0.3-0.9 s); from anywhere
-- else (another zone, even on the same continent: Thunder Bluff -> Orgrimmar) the loading screen,
-- PLAYER_ENTERING_WORLD(false, false) 2.4 s later and the zone 0.35 s after that: the fastest of the 7
-- far summons recorded (Thunder Bluff -> Orgrimmar, 20 Nov 13:58; the 7 ranged 2.4-4.0 s and the zone
-- 0.24-2.73 s after the PEW), so tests that wait 3 s for a landing still see it; a world can ask for a
-- slower one with H.NewWorld({ summonFar = 4.0 }). The loading screen's own events are not in the
-- recording: they come at 1.2 s and with the PEW. The summon box is recorded still up 1 s after the click (12 of 15); when it goes
-- is not: here at 1.2 s, or with the landing if that is later. World option summonArrival = "old":
-- the former fake, the whole loading-screen set 1 s after, whatever the distance.
H.SUMMON_NEAR, H.SUMMON_FAR, H.SUMMON_ZONE_AFTER, H.SUMMON_BOX = 0.6, 2.4, 0.35, 1.2
function World:summonNear(p, pending)
	local a, b = H.zoneRoot(p.mapID), H.zoneRoot(pending.mapID)
	return a ~= nil and a == b
end

function World:confirmSummon(p, s)
	local c = p.client
	if self.summonArrival == "old" then
		self:after(1, function() self:arrive(p, s) end, c, "summon")
		return
	end
	local function land()
		if p.pendingSummon ~= s then return false end
		p.pendingSummon = nil
		p.mapID, p.x, p.y, p.zone, p.subZone = s.mapID, s.x, s.y, s.zone, s.sub or ""
		return true
	end
	local function closeBox() if c.popups.CONFIRM_SUMMON then c.popups.CONFIRM_SUMMON = nil end end
	if self:summonNear(p, s) then
		self:after(H.SUMMON_NEAR, function()
			if not land() or not c.alive then return end
			c:fire("ZONE_CHANGED_NEW_AREA")
			c:fire("ZONE_CHANGED")
		end, c, "summon")
		self:after(H.SUMMON_BOX, function() if p.pendingSummon == nil then closeBox() end end, c, "summon box")
		return
	end
	self:after(H.SUMMON_BOX, function()
		if p.pendingSummon ~= s or not c.alive then return end
		closeBox()
		if self.loadingDropsChannels then self:dropChannels(c) end
		c:fire("LOADING_SCREEN_ENABLED")
		c:fire("PLAYER_LEAVING_WORLD")
		self:after((self.summonFar or H.SUMMON_FAR) - H.SUMMON_BOX, function()
			if not land() or not c.alive then return end
			c:fire("LOADING_SCREEN_DISABLED")
			c:fire("PLAYER_ENTERING_WORLD", false, false)
			self:after(H.SUMMON_ZONE_AFTER, function()
				if not c.alive then return end
				c:fire("ZONE_CHANGED_NEW_AREA")
				c:fire("ZONE_CHANGED")
			end, c, "summon zone")
		end, c, "summon loading")
	end, c, "summon")
end

-- the player lands where the summon put them (summonArrival = "old", and a bot's summon)
function World:arrive(p, pending)
	p.pendingSummon = nil
	local oldZone = p.zone
	p.mapID, p.x, p.y, p.zone, p.subZone = pending.mapID, pending.x, pending.y, pending.zone, pending.sub or ""
	local c = p.client
	if c and c.alive then
		c.popups.CONFIRM_SUMMON = nil
		local cont = H.continentOf(p.mapID)
		if self.loadingDropsChannels then self:dropChannels(c) end
		c:fire("LOADING_SCREEN_ENABLED")
		c:fire("PLAYER_LEAVING_WORLD")
		c:fire("LOADING_SCREEN_DISABLED")
		c:fire("PLAYER_ENTERING_WORLD", false, false)
		c:fire("ZONE_CHANGED_NEW_AREA")
		c:fire("ZONE_CHANGED")
	end
end

-- moves a player (no summon)
function World:move(name, spot)
	local p = self:player(name)
	self:placePlayer(p, spot)
	if p.client and p.client.alive then
		p.client:fire("ZONE_CHANGED_NEW_AREA")
		p.client:fire("ZONE_CHANGED")
	end
end

-- Ritual Rides' ritual (ported from its harness): a Warlock casts on a target in the group;
-- two helpers click the portal; then the target is summoned.
function World:spellId() return self.hideSpellIds and SECRET or 698 end

-- One ritual per caster (two Warlocks at two stations can channel at once). w.ritual is the
-- latest one still going (what older tests read).
local function ritualDone(self, r)
	if self.rituals then self.rituals[r.caster.name] = nil end
	if self.ritual == r then
		self.ritual = nil
		for _, other in pairs(self.rituals or {}) do self.ritual = other end
	end
end

-- `client` casts (a /cast in its macro). A Warlock without a client: World:botCast.
function World:cast(client, spell)
	return self:castBy(client.player, spell, client)
end

function World:castBy(p, spell, client)
	self.rituals = self.rituals or {}
	local guid = "Cast-" .. (self.casts + 1)
	local t = p.target
	local function fire(event, ...) if client and client.alive then client:fire(event, ...) end end
	if spell ~= self.ritualName or not p.knowsRitual or p.combat or self.rituals[p.name] or not t or t == p or t.group ~= p.group or not p.group
		or p.shards < 1 or t.zone == p.zone then
		fire("UNIT_SPELLCAST_FAILED", "player", guid, self:spellId())
		self.failedCasts = (self.failedCasts or 0) + 1
		return
	end
	self.casts = self.casts + 1
	local r = { caster = p, target = t, guid = guid, clicks = {}, stage = "cast", t0 = self.time }
	self.rituals[p.name] = r
	self.ritual = r
	fire("UNIT_SPELLCAST_SENT", "player", t.name, guid, self:spellId())
	fire("UNIT_SPELLCAST_START", "player", guid, self:spellId())
	self:unitEvent(p, "UNIT_SPELLCAST_START", guid, self:spellId())
	self:after(0.5, function()
		if self.rituals[p.name] ~= r then return end
		r.stage = "channel"
		r.t1 = self.time
		if self.shardAtCast then p.shards = p.shards - 1 end
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, self:spellId())
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", guid, self:spellId())
		self:unitEvent(p, "UNIT_SPELLCAST_SUCCEEDED", guid, self:spellId())
		self:unitEvent(p, "UNIT_SPELLCAST_CHANNEL_START", guid, self:spellId())
	end, client, "ritual")
end

-- A Warlock without a Wuber window (a bot) targets `targetName` and casts the ritual. The
-- group's windows see it as UNIT_SPELLCAST_* of that member's party/raid unit.
function World:botCast(lockName, targetName)
	local p = self:player(lockName)
	assert(p, "no such player " .. tostring(lockName))
	if p.class == "WARLOCK" and p.knowsRitual == nil then p.knowsRitual = true end
	p.shards = p.shards or 10
	p.target = targetName and self:player(targetName) or p.target
	return self:castBy(p, self.ritualName, p.client)
end

-- That bot's ritual ends without a summon (it moved, or stopped channeling).
function World:botCastEnd(lockName) return self:cancelRitual(lockName) end

-- The ritual a clicker can reach: the caster's in their group, on their map first.
local function ritualFor(self, p)
	local best
	for _, r in pairs(self.rituals or {}) do
		if r.stage == "channel" and p ~= r.caster and p.group and p.group == r.caster.group then
			if r.caster.zone == p.zone then return r end
			best = best or r
		end
	end
	return best
end

-- `who`: a client, or the name of a player without one (a helper without Wuber). Any class
-- may click; the clicker must be in the caster's group. The clicker channels too (UNIT_SPELLCAST_
-- CHANNEL_START on its own window) unless the world says the client shows no such event
-- (helperEvents = false).
function World:clickPortal(who)
	local client = type(who) == "table" and who.player and who or nil
	local p = client and client.player or self:player(who)
	local r = p and ritualFor(self, p)
	if not p or not r then return false end
	r.clicks[p.name] = true
	if client and client.alive and self.helperEvents ~= false then
		client:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Help-" .. p.name, self:spellId())
	end
	local n = 0
	for _ in pairs(r.clicks) do n = n + 1 end
	if n < 2 then return true end
	ritualDone(self, r)
	if not self.shardAtCast then r.caster.shards = r.caster.shards - 1 end -- (hint 39) the shard goes when the summon completes
	if r.caster.client and r.caster.client.alive then
		r.caster.client:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", r.guid, self:spellId(), "")
	end
	self:unitEvent(r.caster, "UNIT_SPELLCAST_CHANNEL_STOP", r.guid, self:spellId(), "")
	if self.helperEvents ~= false then
		for helper in pairs(r.clicks) do
			local hc = self:player(helper).client
			if hc and hc.alive then hc:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Help-" .. helper, self:spellId(), "") end
		end
	end
	self:summon(r.caster.client or r.caster, r.target.name)
	return true
end

-- A helper lets go of the portal before the ritual completes (their channel stops).
function World:releasePortal(who)
	local client = type(who) == "table" and who.player and who or nil
	local p = client and client.player or self:player(who)
	local r
	for _, x in pairs(self.rituals or {}) do if p and x.clicks[p.name] then r = x end end
	if not p or not r then return false end
	r.clicks[p.name] = nil
	if client and client.alive and self.helperEvents ~= false then
		client:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Help-" .. p.name, self:spellId(), "")
	end
	return true
end

-- The caster moves: the ritual is gone without a summon (the latest one, or `casterName`'s).
function World:cancelRitual(casterName)
	local r = casterName and self.rituals and self.rituals[(self:player(casterName) or {}).name or casterName] or self.ritual
	if not r then return end
	ritualDone(self, r)
	local c = r.caster.client
	local event = r.stage == "channel" and "UNIT_SPELLCAST_CHANNEL_STOP" or "UNIT_SPELLCAST_INTERRUPTED"
	self:unitEvent(r.caster, event, r.guid, self:spellId(), "")
	if not (c and c.alive) then return end
	c:fire(event, "player", r.guid, self:spellId(), "")
end

-- (fga d) `client` casts a Hearthstone or a teleport: UnitCastingInfo answers its 11 values for `seconds`, then SUCCEEDED.
-- localizedName is the client-language spell name (Wuber must see the id, not the English name).
function World:castTravel(client, spellID, seconds, localizedName)
	local guid = "Cast-T" .. (self.casts + 1)
	self.casts = self.casts + 1
	local c = { spellID = spellID, name = localizedName or "Hearthstone", guid = guid, t0 = self.time, t1 = self.time + seconds }
	client.player.travelCast = c
	client:fire("UNIT_SPELLCAST_SENT", "player", "", guid, spellID)
	client:fire("UNIT_SPELLCAST_START", "player", guid, spellID)
	self:after(seconds, function()
		if client.player.travelCast ~= c then return end
		client.player.travelCast = nil
		client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
	end, client, "travel cast")
end

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------

-- As in the game, PLAYER_REGEN_DISABLED comes while secure frames can still be changed.
function World:enterCombat(client)
	client:fire("PLAYER_REGEN_DISABLED")
	client.player.combat = true
end

function World:leaveCombat(client)
	client.player.combat = false
	client:fire("PLAYER_REGEN_ENABLED")
end

-- A fight with `foe` (a player or NPC name) as an addon can see it in this client (the combat
-- log is closed to addons): the foe is in combat targeting the player, its nameplate shows, then
-- the player enters combat, and leaves it at once unless opts.stay (the foe's combat and target
-- are put back then).
function World:pvpFight(client, foe, opts)
	opts = opts or {}
	local f = self:player(foe)
	local was = f and { combat = f.combat, target = f.target }
	if f then f.combat, f.target = true, client.player end
	client:showPlate(foe)
	self:enterCombat(client)
	if not opts.stay then
		self:leaveCombat(client)
		if f then f.combat, f.target = was.combat, was.target end
	end
end

---------------------------------------------------------------------------
-- Trade
---------------------------------------------------------------------------

function World:openTrade(a, b)
	a, b = a.player or a, b.player or b
	if a.trade or b.trade or a.zone ~= b.zone then return false end
	local t = { money = { [a.name] = 0, [b.name] = 0 }, accepted = { [a.name] = 0, [b.name] = 0 }, a = a, b = b }
	a.trade, b.trade = t, t
	-- (fact chat.system.lines) the side that asks reads this line; recorded 0.17-0.36 s before its
	-- TRADE_SHOW, which still comes at once here
	systemLine(a.client, SYSL.ERR_INITIATE_TRADE_S:format(b.name))
	-- (REC 22 Nov, WuberRec 1.1.0) the window opens with PLAYER_TRADE_MONEY, TRADE_SHOW, three more
	-- PLAYER_TRADE_MONEY, then 0.11 s later TRADE_TARGET_ITEM_CHANGED (1, n) for slots 1-7, twice (14)
	for _, p in ipairs({ a, b }) do
		local c = p.client
		if c and c.alive then
			c:fire("PLAYER_TRADE_MONEY")
			c:fire("TRADE_SHOW")
			for _ = 1, 3 do c:fire("PLAYER_TRADE_MONEY") end
			self:after(0.11, function()
				if not (c.alive and p.trade == t) then return end
				for _ = 1, 2 do
					for slot = 1, 7 do c:fire("TRADE_TARGET_ITEM_CHANGED", slot) end
				end
			end, c, "trade items")
		end
	end
	return true
end

local function other(t, p) return t.a == p and t.b or t.a end

function World:tradeMoney(p, copper)
	p = p.player or p
	local t = p.trade
	if not t then return end
	t.money[p.name] = copper
	t.accepted[t.a.name], t.accepted[t.b.name] = 0, 0
	local o = other(t, p)
	if o.client and o.client.alive then o.client:fire("TRADE_MONEY_CHANGED") end
	if p.client and p.client.alive then p.client:fire("PLAYER_TRADE_MONEY") end
end

-- A trade's end as the real client gave it (default; facts trade.close.double, trade.complete.order,
-- trade.accept.update in tests/fixtures/rec/lab-real-facts.lua, 21 trade windows): the first to
-- accept sees TRADE_ACCEPT_UPDATE(1,0) and the other side (0,1); the last to accept sees (1,1) and the
-- first sees nothing more; then both get TRADE_CLOSED twice in the same instant and PLAYER_MONEY 0.3 s
-- later (recorded 0.10-0.45 s), when GetMoney changes too. "Trade complete." (UI_INFO_MESSAGE) is not
-- in the recording; it comes after the two closes, as review 2.2 #2 found.
-- The older orders stay as options: tradeOrder = "old" (the purse, one close, the line: the fake's
-- former default), "real" and "closeMoneyLine" (review 2.2 #2's guesses: one close).
local function tradeAcceptRecorded(self, t, p, o)
	local completes = t.accepted[o.name] == 1
	if completes then
		if p.client and p.client.alive then p.client:fire("TRADE_ACCEPT_UPDATE", 1, 1) end
	else
		if p.client and p.client.alive then p.client:fire("TRADE_ACCEPT_UPDATE", 1, 0) end
		if o.client and o.client.alive then o.client:fire("TRADE_ACCEPT_UPDATE", 0, 1) end
		return
	end
	local gain = { [p] = t.money[o.name] - t.money[p.name], [o] = t.money[p.name] - t.money[o.name] }
	p.trade, o.trade = nil, nil
	self.trades = self.trades + 1
	for _, x in ipairs({ p, o }) do
		local c = x.client
		if c and c.alive then
			c:fire("TRADE_CLOSED")
			c:fire("TRADE_CLOSED")
			c:fire("UI_INFO_MESSAGE", 0, "Trade complete.")
			self:after(0.3, function()
				x.money = x.money + gain[x]
				if c.alive then c:fire("PLAYER_MONEY") end
			end, c, "trade money")
		else
			x.money = x.money + gain[x]
		end
	end
end

function World:tradeAccept(p)
	p = p.player or p
	local t = p.trade
	if not t then return end
	t.accepted[p.name] = 1
	local o = other(t, p)
	if self.tradeOrder == nil then return tradeAcceptRecorded(self, t, p, o) end
	-- tradeOrder "real" / "closeMoneyLine" (review 2.2 #2): as a TrinityCore-style server
	-- does, the last accepter gets no TRADE_ACCEPT_UPDATE(1,1); the server just completes
	local real = self.tradeOrder == "real" or self.tradeOrder == "closeMoneyLine"
	local completes = t.accepted[o.name] == 1
	for _, x in ipairs({ p, o }) do
		if x.client and x.client.alive and not (real and completes and x == p) then
			x.client:fire("TRADE_ACCEPT_UPDATE", t.accepted[x.name], t.accepted[other(t, x).name])
		end
	end
	if t.accepted[o.name] ~= 1 then return end
	p.money = p.money + t.money[o.name] - t.money[p.name]
	o.money = o.money + t.money[p.name] - t.money[o.name]
	p.trade, o.trade = nil, nil
	self.trades = self.trades + 1
	if real then
		-- "real": the window closes, then "Trade complete.", then the purse a moment later;
		-- "closeMoneyLine": the window closes, the purse changes, the line comes last
		local lineLast = self.tradeOrder == "closeMoneyLine"
		for _, x in ipairs({ p, o }) do
			local c = x.client
			if c and c.alive then
				c:fire("TRADE_CLOSED")
				if not lineLast then c:fire("UI_INFO_MESSAGE", 0, "Trade complete.") end
				self:after(lineLast and 0.1 or 0.3, function() if c.alive then c:fire("PLAYER_MONEY") end end, c, "trade money")
				if lineLast then
					self:after(0.4, function() if c.alive then c:fire("UI_INFO_MESSAGE", 0, "Trade complete.") end end, c, "trade line")
				end
			end
		end
		return
	end
	-- as in the game: the money changes, then the window closes
	for _, x in ipairs({ p, o }) do
		if x.client and x.client.alive then x.client:fire("PLAYER_MONEY") end
	end
	for _, x in ipairs({ p, o }) do
		if x.client and x.client.alive then
			x.client:fire("TRADE_CLOSED")
			x.client:fire("UI_INFO_MESSAGE", 0, "Trade complete.")
		end
	end
end

-- A cancel (fact trade.cancel.sequence, 13 cancelled windows): TRADE_REQUEST_CANCEL and an unchanged
-- PLAYER_MONEY always come. The side that cancels (p) gets PLAYER_MONEY, TRADE_REQUEST_CANCEL and
-- TRADE_CLOSED twice at once; the other side TRADE_CLOSED twice, then PLAYER_MONEY and
-- TRADE_REQUEST_CANCEL 0.1 s later (recorded 0.08-0.15 s). Which side pressed Cancel is not in the
-- recording: the side that got everything at once came first, so it is read as the canceller.
-- tradeOrder = "old" (or "real" / "closeMoneyLine"): one TRADE_CLOSED each, nothing else.
function World:tradeCancel(p)
	p = p.player or p
	local t = p.trade
	if not t then return end
	local o = other(t, p)
	p.trade, o.trade = nil, nil
	if self.tradeOrder ~= nil then
		for _, x in ipairs({ p, o }) do
			if x.client and x.client.alive then x.client:fire("TRADE_CLOSED") end
		end
		return
	end
	local pc, oc = p.client, o.client
	if pc and pc.alive then
		pc:fire("PLAYER_MONEY")
		pc:fire("TRADE_REQUEST_CANCEL")
		pc:fire("PLAYER_TRADE_MONEY")
		pc:fire("TRADE_CLOSED")
		pc:fire("TRADE_CLOSED")
		pc:fire("UI_INFO_MESSAGE", 250, pc.env.ERR_TRADE_CANCELLED or "Trade cancelled.") -- (REC 22 Nov)
	end
	if oc and oc.alive then
		oc:fire("TRADE_CLOSED")
		oc:fire("TRADE_CLOSED")
		self:after(0.1, function()
			if not oc.alive then return end
			oc:fire("PLAYER_MONEY")
			oc:fire("TRADE_REQUEST_CANCEL")
			oc:fire("PLAYER_TRADE_MONEY")
			oc:fire("UI_INFO_MESSAGE", 250, oc.env.ERR_TRADE_CANCELLED or "Trade cancelled.")
		end, oc, "trade cancel")
	end
end

---------------------------------------------------------------------------
-- The world map and OpenMap
---------------------------------------------------------------------------

-- open the world map on a client at a map
function World:openMap(client, mapID)
	local wm = client.env.WorldMapFrame
	if mapID then wm:SetMapID(mapID) end
	wm:Show()
end

---------------------------------------------------------------------------
-- Client: one game window
---------------------------------------------------------------------------

local Client = {}
Client.__index = Client
H.Client = Client

function Client:fire(event, ...)
	if not self.alive then return end
	if H.CHAT18_EVENTS[event] and select("#", ...) < 18 then
		local a = padChat(event, ...)
		return Client.fireRaw(self, event, unpack(a, 1, a.n))
	end
	return Client.fireRaw(self, event, ...)
end

function Client.fireRaw(self, event, ...)
	if not H.KNOWN_EVENTS[event] and not (event == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" and self.world.whisperCheck) then error("the harness fired an event it doesn't list: " .. event) end
	if event == "PLAYER_ENTERING_WORLD" then self.pewAt = self.world.time end -- (the touchy period, sendAddon)
	local list = {}
	for _, f in ipairs(self.frames) do
		if S[f].events[event] then list[#list + 1] = f end
	end
	for _, f in ipairs(list) do
		local fn = S[f].scripts.OnEvent
		if fn then H.protect(self.world, self, "OnEvent " .. event, fn, f, event, ...) end
	end
end

-- a chat event: message filters decide whether the chat window shows it
function Client:chatEvent(event, ...)
	self:fire(event, ...)
	local args = padChat(event, ...)
	local hidden = false
	for _, fn in ipairs(self.chatFilters[event] or {}) do
		local ok, res = pcall(fn, self.env.ChatFrame1, event, unpack(args, 1, args.n))
		if not ok then self.world.errors[#self.world.errors + 1] = self.player.name .. " chat filter " .. event .. ": " .. tostring(res) end
		if ok and res then hidden = true break end
	end
	if not hidden then self.chatShown[#self.chatShown + 1] = { event = event, text = args[1], who = args[2] } end
end

-- a value as this client hands it out: secret when the test says so
function Client:secretArg(kind, v)
	if self.secrets[kind] then return SECRET end
	return v
end

-- (REC selftest.login) C_Map.GetBestMapForUnit and GetPlayerMapPosition answer nil until world time mapBlankUntil:
-- seen once in the game, at a loading screen 60 s after a login. Client:blankMap(s): from now for s seconds.
function Client:mapBlank() return self.mapBlankUntil ~= nil and self.world.time < self.mapBlankUntil end
function Client:blankMap(s) self.mapBlankUntil = self.world.time + s end

-- (#233) a frame the addon does not own that carries a secret aspect (a nameplate, a unit frame): its methods
-- listed in tests/fixtures/secret-api.lua (IsEventRegistered, GetScript, HasScript, GetChildren, GetWidth ...)
-- answer a secret value. on == false takes it off.
function Client:secretFrame(frame, on)
	S[frame].secretAspect = on ~= false or nil
	return frame
end

function Client:secret(...)
	for i = 1, select("#", ...) do self.secrets[(select(i, ...))] = true end
end

function Client:unsecret()
	self.secrets = {}
end

-- the addon (by file) that is running code now: for ADDON_ACTION_BLOCKED
function Client:callerAddon()
	for level = 2, 40 do
		local info = debug.getinfo(level, "S")
		if not info then break end
		local src = info.source or ""
		for name, dir in pairs(H.ADDONS) do
			if src:find(dir, 1, true) then return name end
		end
	end
	return "Wuber"
end

-- the player a unit token (or a group member's name) stands for on this client
function Client:unit(unit)
	local p = self.player
	if type(unit) ~= "string" then return nil end
	local u = unit:lower()
	if u == "player" then return p end
	if u == "target" then return p.target end
	if u == "npc" then return p.trade and other(p.trade, p) or nil end
	if u == "mouseover" then return self.mouseoverPlayer end
	local of = u:match("^(.+)target$")
	if of then
		local holder = self:unit(of)
		return holder and holder.target or nil
	end
	local np = u:match("^nameplate(%d+)$")
	if np then
		local pl = self.plates[tonumber(np)]
		return pl and pl.player or nil
	end
	local g = p.group
	local kind, index = u:match("^(%a+)(%d+)$")
	index = tonumber(index)
	if g and kind == "raid" and g.raid then return self.world:player(g.members[index]) end
	if g and kind == "party" and not g.raid then
		local n = 0
		for _, name in ipairs(g.members) do
			if name ~= p.name then
				n = n + 1
				if n == index then return self.world:player(name) end
			end
		end
		return nil
	end
	if kind then return nil end
	-- a name: only group members (and you) answer
	local other_ = self.world:player((unit:gsub("%-", " ")))
	if other_ == p then return p end
	if other_ and g and other_.group == g then return other_ end
	return nil
end

-- One click of the mouse on a frame, as the game sends it: for every click the button is
-- registered for (down, then up) PreClick, OnClick (for a secure button: its action, once),
-- PostClick. A hardware event is under way meanwhile.
function Client:runClick(f, button, down)
	local s = S[f]
	if s.otype ~= "Button" and s.otype ~= "CheckButton" then
		-- (r244) a click on an EditBox focuses it on the mouse down and, after the scripts, puts the cursor where it landed,
		-- which drops any selection a script made: a script that wants the text selected must select again a frame later
		if s.otype == "EditBox" then f:SetFocus() end
		runScript(f, "OnMouseDown", button)
		runScript(f, "OnMouseUp", button)
		if s.otype == "EditBox" then s.highlight = nil end
		return
	end
	if s.enabled == false then return end
	if s.otype == "CheckButton" then s.checked = not s.checked end
	runScript(f, "PreClick", button, down)
	if s.secure then
		local act = true
		if self.world.clickMode == "modern" then
			local useDown = s.attrs.useOnKeyDown
			if useDown == nil then useDown = self.cvars.ActionButtonUseKeyDown == "1" end
			act = (down and useDown) or (not down and not useDown)
			-- (a mouse click delivers both halves; a click from code delivers the one asked)
		end
		if act then
			local kind = s.attrs.type or s.attrs.type1
			if kind == "macro" then
				local text = s.attrs.macrotext or s.attrs.macrotext1
				if type(text) == "string" and text ~= "" then self.world:runMacro(self, text) end
			elseif kind == "click" then
				local target = s.attrs.clickbutton
				if isWidget(target) then target:Click(button) end
			elseif kind ~= nil then
				self.world.violations[#self.world.violations + 1] = self.player.name .. ": secure action type the harness doesn't know: " .. tostring(kind)
			end
		end
		if s.scripts.OnClick then runScript(f, "OnClick", button, down) end
	else
		runScript(f, "OnClick", button, down)
	end
	runScript(f, "PostClick", button, down)
end

-- The audit of a direct click (job 2766): when the environment variable WUBER_CLICK_AUDIT names a file (H.clickAuditFile does the same
-- for a test of the audit), a Client:click on a frame that is not what Client:topAt hits at its centre (covered, clipped out, off
-- screen) appends "<test name>	<frame>	<what is on top>" to it. The audit line is written before the strict check below stops the click.
local function debugPath(f)
	local parts = {}
	while f and #parts < 8 do
		parts[#parts + 1] = f:GetDebugName()
		f = S[f] and S[f].parent
	end
	return table.concat(parts, "<")
end
function Client:auditClick(f)
	local path = H.clickAuditFile or os.getenv("WUBER_CLICK_AUDIT")
	if not path or path == "" then return end
	local r = rect(f)
	local top = r and self:topAt(f)
	if top == f then return end
	local fh = io.open(path, "a")
	if not fh then return end
	local what = top and debugPath(top) or (r and "nothing" or "nothing (no position)")
	fh:write((H.testName or "?"):gsub("[\t\n]", " "), "\t", debugPath(f), "\t", what, "\n")
	fh:close()
end

function Client:click(f, button, alreadyHit)
	assert(isWidget(f), "click: not a widget")
	button = button or "LeftButton"
	local s = S[f]
	if not visible(f) then error("the test clicked a frame that is not visible: " .. tostring(f), 2) end
	if s.kind == "frame" and s.mouse == false then error("the test clicked a frame that does not take the mouse: " .. tostring(f), 2) end
	self:auditClick(f)
	do local fe = self.focusedEdit if fe and S[fe] and S[fe].focus and fe ~= f then H.rule("edit.focus-outside-click") end end
	-- (job 2790) strict, like a player's mouse: a frame drawn somewhere is clicked only when it is what the mouse reaches at its centre
	-- (Client:topAt). A covered, clipped-out (scrolled away) or off-screen frame fails the test; scroll it in (scrollIntoView), wait for a
	-- sheet to rise, close what covers it, or use clickOn. A frame with no position at all (a stand-alone widget, the fake trade button)
	-- cannot be judged and is still clicked: listed in tests/README.md "What tests cannot prove".
	local fr = not alreadyHit and rect(f)
	if fr then
		local top = self:topAt(f)
		local sr = rect(self.env.UIParent)
		local cx, cy = fr.l + fr.w / 2, fr.b + fr.h / 2
		if sr and (cx < sr.l or cx > sr.l + sr.w or cy < sr.b or cy > sr.b + sr.h) then top = nil end -- off the screen
		if top ~= f then
			error("the test clicked a frame a player cannot reach at its centre: " .. debugPath(f) .. "; on top there: "
				.. (top and debugPath(top) or "nothing (clipped out or off screen)"), 2)
		end
	end
	local w = self.world
	w.hardware = self
	self.mouseOver = f
	-- (fga f) a press anywhere reaches GLOBAL_MOUSE_DOWN(button) with the mouse already over the frame (SystemDocumentation); a world
	-- option mouseEvents = false turns it off
	if w.mouseEvents ~= false then H.rule("event.global-mouse-down") self:fire("GLOBAL_MOUSE_DOWN", button) end
	-- the mouse goes down on a toplevel frame (or inside one): the client raises it
	local tl = f
	while tl and not S[tl].toplevel do tl = S[tl].parent end
	if tl then raiseFrame(tl) end
	if s.otype == "Button" or s.otype == "CheckButton" then
		local clicks = s.clicks or {}
		local downs = clicks[button .. "Down"] or clicks.AnyDown
		local ups = clicks[button .. "Up"] or clicks.AnyUp
		if w.clickMode == "modern" and s.secure and not downs and not ups then
			-- registered for nothing: the button does nothing
		end
		-- (Design 1) the mouse goes down and comes up on the button, as in the game: its press look and
		-- click sound (T.Press) answer the mouse down, before any click script
		if s.enabled ~= false then
			runScript(f, "OnMouseDown", button)
			runScript(f, "OnMouseUp", button)
		end
		if downs then self:runClick(f, button, true) end
		if ups then self:runClick(f, button, false) end
	else
		self:runClick(f, button, false)
	end
	if w.mouseEvents ~= false then self:fire("GLOBAL_MOUSE_UP", button) end
	w.hardware = nil
	return true
end

-- The frame a mouse click at a screen point lands on: the topmost visible frame there that
-- takes the mouse, ranked as the real client ranks it (run 3, issue #36; proven by the Lab's GetMouseFoci samples,
-- 122 of 122 rows where level order and the game disagreed, none against):
--   * a frame cut off at the point by an ancestor that clips its children (SetClipsChildren) never takes the mouse;
--   * a frame inside a clipping ancestor competes with frames OUTSIDE that ancestor at the clipping ancestor's own
--     strata and level, not its own (a level-42 back arrow inside a level-2 clipping tab body loses to the level-2
--     header drag strip next to that body); at an equal level the frame outside the clipping ancestor wins (the
--     strip beat the tab body in every sample);
--   * otherwise strata, then frame level, then the newer frame.
local function clipCutsOff(f, x, y)
	local p = S[f].parent
	while p do
		local ps = S[p]
		if ps and ps.clips then
			local r = rect(p)
			if not r or x < r.l or x > r.l + r.w or y < r.b or y > r.b + r.h then H.rule("hit.clipped-child-no-mouse") return true end
		end
		p = ps and ps.parent
	end
	return false
end
local function chainOf(f) -- f, its parent, ... up to the root
	local out = {}
	while f do out[#out + 1] = f f = S[f] and S[f].parent end
	return out
end
-- the frame that stands for f when it is compared with a frame outside the subtree under stop: the clipping
-- ancestor of f nearest to stop (below it), or f itself when none clips
local function standIn(chain, stop)
	local who
	for i = 1, #chain do
		local g = chain[i]
		if g == stop then break end
		if i > 1 and S[g] and S[g].clips then who = g end
	end
	return who or chain[1], who ~= nil
end
local function hitKey(f) return (STRATA[f:GetFrameStrata()] or 3) * 1e5 + f:GetFrameLevel() end
-- true when a lies over b at the point (both take the mouse there); ia, ib = their creation order
local function hitsAbove(a, ia, b, ib)
	local ca, cb = chainOf(a), chainOf(b)
	local inB = {}
	for _, g in ipairs(cb) do inB[g] = true end
	local lca
	for _, g in ipairs(ca) do if inB[g] then lca = g break end end
	local ra, clipA = standIn(ca, lca)
	local rb, clipB = standIn(cb, lca)
	if clipA or clipB then H.rule("hit.clip-ancestor-level") end
	if ra ~= rb then
		local ka, kb = hitKey(ra), hitKey(rb)
		if ka ~= kb then return ka > kb end
		if clipA ~= clipB then H.rule("hit.equal-level-tie") return clipB end -- at an equal level the frame outside the clipping ancestor wins
	end
	local ka, kb = hitKey(a), hitKey(b)
	if ka ~= kb then return ka > kb end
	return ia > ib
end
-- the frames at a point that take the mouse (or, with wheel, also those that only take the wheel), as { frame, creation order }
local function hitCandidates(client, x, y, wheel)
	local out = {}
	for i, f in ipairs(client.frames) do
		local s = S[f]
		if (s.mouse or (wheel and s.wheel)) and visible(f) and not s.isUIParent then
			local r = rect(f)
			local h = s.hitIns
			if h then H.rule("hit.hitrect-insets") end
			if s.otype == "Button" and s.enabled == false then H.rule("hit.disabled-button-takes-mouse") end
			if s.alpha == 0 then H.rule("hit.alpha-zero-takes-mouse") end
			do -- a ScrollFrame's own rect is not a clip here (FAKE-GAPS "scroll clipping"): a child past its edge still takes the mouse
				local p = s.parent
				while p do
					if S[p] and S[p].otype == "ScrollFrame" and not S[p].clips then H.rule("hit.scrollframe-rect-clip") break end
					p = S[p] and S[p].parent
				end
			end
			if r and h then r = { l = r.l + h[1], b = r.b + h[4], w = r.w - h[1] - h[2], h = r.h - h[3] - h[4] } end
			if r and x >= r.l and x <= r.l + r.w and y >= r.b and y <= r.b + r.h and not clipCutsOff(f, x, y) then
				out[#out + 1] = { f, i }
			end
		end
	end
	return out
end
local function bestOf(cands)
	local best
	for k, c in ipairs(cands) do
		if not best or hitsAbove(c[1], c[2], cands[best][1], cands[best][2]) then best = k end
	end
	return best
end
function Client:frameAt(x, y)
	local cands = hitCandidates(self, x, y)
	local k = bestOf(cands)
	return k and cands[k][1] or nil
end
-- Every frame under a point that takes the mouse, top first (what GetMouseFoci answers). With opts.wheel: frames that only take the
-- mouse wheel count too (an assumption: no real sample has measured a wheel-only frame).
function Client:framesAt(x, y, opts)
	if opts and opts.wheel then H.rule("hit.wheel-only-frames") end
	local cands, out = hitCandidates(self, x, y, opts and opts.wheel), {}
	while #cands > 0 do
		local k = bestOf(cands)
		out[#out + 1] = cands[k][1]
		table.remove(cands, k)
	end
	return out
end

-- The mouse moves to a screen point (the units of a frame's rect). The frame on top there (Client:frameAt) is the one that hears
-- OnEnter, and the one the mouse leaves hears OnLeave first; frames it covers or that are clipped out there hear nothing.
-- GetCursorPosition follows (pixels). Returns the frame on top, or nil.
function Client:moveMouse(x, y)
	local focus = self:frameAt(x, y)
	local old = self.mouseAt and self.mouseAt.focus
	if old == nil and self.mouseAt == nil then old = self.mouseOver end
	local sc = H.effScale(self.env.UIParent) or 1
	self.cursorX, self.cursorY = x * sc, y * sc
	self.mouseAt = { x = x, y = y, focus = focus }
	self.mouseOver = focus
	if old ~= focus then
		if old and S[old] then runScript(old, "OnLeave", true) end
		if focus then runScript(focus, "OnEnter", true) end
	end
	return focus
end
-- The mouse moves to where a region is drawn (its centre); returns the frame that took it.
function Client:hoverOn(region)
	local r = rect(region)
	if not r then error("hoverOn: the region has no position: " .. tostring(region), 2) end
	if not visible(region) then error("hoverOn: the region is not visible: " .. tostring(region), 2) end
	return self:moveMouse(r.l + r.w / 2, r.b + r.h / 2)
end

-- One turn of the mouse wheel at a point. The top frame there that has the wheel enabled hears OnMouseWheel(delta); one with no
-- handler passes it to its nearest ancestor that has the wheel enabled and a handler. Returns the frame that heard it, or nil.
function Client:wheel(x, y, delta)
	local list = self:framesAt(x, y, { wheel = true })
	local target
	for _, f in ipairs(list) do
		if S[f].wheel then target = f break end
	end
	while target and not (S[target].wheel and S[target].scripts.OnMouseWheel) do target = S[target].parent end
	if not target then return nil end
	runScript(target, "OnMouseWheel", delta)
	return target
end
-- the wheel turns where a region is drawn (its centre)
function Client:wheelOn(region, delta)
	local r = rect(region)
	if not r then error("wheelOn: the region has no position: " .. tostring(region), 2) end
	return self:wheel(r.l + r.w / 2, r.b + r.h / 2, delta)
end

-- The frame on top at the centre of a region (what a click on it would reach), or nil
function Client:topAt(region)
	local r = rect(region)
	return r and self:frameAt(r.l + r.w / 2, r.b + r.h / 2) or nil
end

-- Clicks where a region is drawn (its centre), as the player would: whatever frame is on top
-- there gets the click. Returns that frame.
function Client:clickOn(region, button)
	local r = rect(region)
	if not r then error("clickOn: the region has no position: " .. tostring(region), 2) end
	if not visible(region) then error("clickOn: the region is not visible: " .. tostring(region), 2) end
	local f = self:topAt(region)
	if not f then error("clickOn: nothing takes the mouse at " .. tostring(region), 2) end
	-- (job 2833) f was just hit-tested at the REGION's centre; the strict check of Client:click would test f's own centre, a different
	-- point when f is a bigger or smaller frame than the region (a sheet whose body takes the click), and fail a click the player's mouse makes
	self:click(f, button, true)
	return f
end

-- true when the region's centre is drawn: no ancestor that clips its children cuts it off (scrolled out of view)
function Client:onScreen(region)
	local r = rect(region)
	return (r and visible(region) and not clipCutsOff(region, r.l + r.w / 2, r.b + r.h / 2)) or false
end

-- The player scrolls a control into view with the mouse wheel: the nearest ancestor that takes the wheel is turned, a notch at a time
-- (time moves on between notches), until the region's centre lies inside that ancestor's rectangle. Returns true when it does.
function Client:scrollIntoView(region, maxNotches)
	local r = rect(region)
	if not r then error("scrollIntoView: the region has no position: " .. tostring(region), 2) end
	local clip = S[region].parent
	while clip and not (S[clip].scripts and S[clip].scripts.OnMouseWheel) do clip = S[clip].parent end
	if not clip then return false end
	for _ = 1, maxNotches or 80 do
		local cr, rr = rect(clip), rect(region)
		local y = rr.b + rr.h / 2
		if y >= cr.b and y <= cr.b + cr.h then return true end
		-- the player holds the cursor over the scroll frame (its centre): whatever frame the wheel reaches there turns, as the game routes it
		self:moveMouse(cr.l + cr.w / 2, cr.b + cr.h / 2)
		self:wheel(cr.l + cr.w / 2, cr.b + cr.h / 2, y < cr.b and -1 or 1)
		self.world:advance(0.3)
	end
	local cr, rr = rect(clip), rect(region)
	local y = rr.b + rr.h / 2
	return y >= cr.b and y <= cr.b + cr.h
end

-- Clicks the visible text (exact, or a Lua pattern with opts.pattern). Returns the frame hit.
function Client:clickText(text, opts)
	opts = opts or {}
	local hits = {}
	for _, obj in ipairs(self.widgets) do
		local s = S[obj]
		if s.otype == "FontString" and s.text and visible(obj) then
			local t = s.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			if (opts.pattern and t:find(text)) or (not opts.pattern and t == text) then hits[#hits + 1] = obj end
		end
	end
	if #hits == 0 then error("no visible text " .. text, 2) end
	-- a player can only click text they see: copies cut off by a clipping ancestor (scrolled out) do not count while another
	-- copy is on screen; when none is, the player scrolls one into view
	local shown = {}
	for _, obj in ipairs(hits) do
		if self:onScreen(obj) then shown[#shown + 1] = obj end
	end
	if #shown == 0 then
		for _, obj in ipairs(hits) do
			if self:scrollIntoView(obj) then shown[1] = obj break end
		end
	end
	if #shown > 0 then hits = shown end
	return self:clickOn(hits[opts.index or 1], opts.button), hits
end

-- The player drags a frame (registered for drag) by dx, dy screen pixels and lets go.
-- (at = { x, y }: the press point; default the frame's centre)
function Client:drag(f, dx, dy, at)
	local s = S[f]
	assert(s.drag and #s.drag > 0, "drag: the frame is not registered for drag")
	-- the button goes down where the frame is drawn (its centre): the frame on top there takes the press, and only a frame
	-- registered for drag starts a drag
	local target = f
	local r = rect(f)
	if at or (r and visible(f)) then
		local top = at and self:frameAt(at[1] or at.x, at[2] or at.y) or self:topAt(f)
		if top ~= f then
			if top and S[top].drag and #S[top].drag > 0 then target = top
			else
				error("drag: the press " .. (at and "" or "at the centre ") .. "of " .. tostring(f) .. " lands on " .. (top and (top:GetDebugName() .. ", which is not registered for drag (the frame is covered)") or "nothing (the frame is covered or clipped out)"), 2)
			end
		end
	end
	local w = self.world
	w.hardware = self
	self.dragDX, self.dragDY = dx, dy
	runScript(target, "OnDragStart", "LeftButton")
	runScript(target, "OnDragStop")
	self.dragDX, self.dragDY = nil, nil
	w.hardware = nil
end

-- every visible text now (for messages in failing tests)
function Client:visibleTexts()
	local out = {}
	for _, obj in ipairs(self.widgets) do
		local s = S[obj]
		if s.otype == "FontString" and s.text and s.text ~= "" and visible(obj) then out[#out + 1] = s.text end
	end
	return out
end

-- the player types into a text box (and presses Enter)
function Client:type(box, text, enter)
	assert(S[box] and S[box].otype == "EditBox", "type: not an EditBox")
	local w = self.world
	w.hardware = self
	box:SetFocus()
	S[box].text = text
	runScript(box, "OnTextChanged", true)
	if enter ~= false then runScript(box, "OnEnterPressed") end
	w.hardware = nil
end

function Client:pressEscape()
	local w = self.world
	w.hardware = self
	local closed = false
	for _, name in ipairs(self.env.UISpecialFrames) do
		local f = self.env[name]
		if isWidget(f) and visible(f) then
			f:Hide()
			closed = true
		end
	end
	w.hardware = nil
	return closed
end

function Client:slash(line)
	local cmd, rest = line:match("^(/%S+)%s*(.*)$")
	for name, handler in pairs(self.env.SlashCmdList) do
		local i = 1
		while self.env["SLASH_" .. name .. i] do
			if self.env["SLASH_" .. name .. i]:lower() == cmd:lower() then
				local w = self.world
				w.hardware = self
				local ok = H.protect(w, self, "slash " .. line, handler, rest, self.env.ChatFrame1EditBox)
				w.hardware = nil
				return ok
			end
			i = i + 1
		end
	end
	error("no such slash command: " .. line, 2)
end

-- Enter in the chat box: the player sends what an addon put there (ChatFrame_OpenChat).
function Client:enter()
	local text = self.chatBox
	self.chatBox = nil
	if type(text) ~= "string" or text == "" then return false end
	local target, message = text:match("^/w%s+(%S+)%s+(.+)$")
	local w = self.world
	if target then return w:whisper(self, (target:gsub("%-", " ")), message, "user") end
	local index, rest = text:match("^/(%d+)%s+(.+)$")
	if index then
		local ch = w:channelOf(self.player, tonumber(index))
		if not ch then return false end
		w:publicLine(self.player.name, self.player.faction, rest, "CHANNEL", ch.name, "user", self)
		return true
	end
	w.typedLines = w.typedLines or {}
	w.typedLines[#w.typedLines + 1] = { from = self.player.name, text = text }
	return true
end

function Client:said(pattern)
	for _, line in ipairs(self.chatLines) do
		if line:find(pattern) then return true end
	end
	return false
end

-- every widget whose text (its own or a font string's) matches; visible ones only unless all
function Client:findText(pattern, all, plain)
	local out = {}
	for _, obj in ipairs(self.widgets) do
		local s = S[obj]
		if (s.otype == "FontString" or s.otype == "EditBox") and s.text and (all or visible(obj)) then
			if s.text:find(pattern, 1, plain) then out[#out + 1] = obj end
		end
	end
	return out
end

-- the clickable frame a region belongs to (itself or the nearest parent that takes clicks)
function Client:clickable(obj)
	while obj do
		local s = S[obj]
		if s.kind == "frame" and (s.otype == "Button" or s.otype == "CheckButton" or (s.mouse and (s.scripts.OnMouseUp or s.scripts.OnMouseDown))) then
			return obj
		end
		obj = s.parent
	end
	return nil
end

-- a visible button showing this text (exactly, or matching when a pattern is given)
function Client:button(text, opts)
	opts = opts or {}
	local found = {}
	for _, obj in ipairs(self.widgets) do
		local s = S[obj]
		if s.otype == "FontString" and s.text and visible(obj) then
			local t = s.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			local hit
			if opts.pattern then hit = t:find(text) else hit = (t == text) end
			if hit then
				local b = self:clickable(obj)
				if b and visible(b) and (not opts.secure or S[b].secure) then found[#found + 1] = b end
			end
		end
	end
	return found[1], found
end

function Client:secureButtons()
	local out = {}
	for _, f in ipairs(self.frames) do if S[f].secure then out[#out + 1] = f end end
	return out
end

local BASE = {
	string = string, table = table, math = math, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring,
	tonumber = tonumber, select = select, pcall = pcall, xpcall = xpcall, error = error, assert = assert, next = next,
	unpack = unpack, setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
	rawequal = rawequal, coroutine = coroutine, bit = nil, loadstring = loadstring,
}

---------------------------------------------------------------------------
-- The game API of one client
---------------------------------------------------------------------------

-- UnitClass: the class's name and id (read only; one table for every call, BRIEF21 S3)
local CLASS_NAMES = { WARLOCK = { "Warlock", 9 }, MAGE = { "Mage", 8 }, PRIEST = { "Priest", 5 }, WARRIOR = { "Warrior", 1 },
	DRUID = { "Druid", 11 }, ROGUE = { "Rogue", 4 }, HUNTER = { "Hunter", 3 } }

local function vector(x, y)
	local v = { x = x, y = y }
	function v.GetXY(self) return self.x, self.y end
	function v.SetXY(self, a, b) self.x, self.y = a, b end
	function v.Clone(self) return vector(self.x, self.y) end
	return v
end
H.vector = vector

local function color(r, g, b, a)
	local c = { r = r, g = g, b = b, a = a or 1 }
	function c.GetRGB(self) return self.r, self.g, self.b end
	function c.GetRGBA(self) return self.r, self.g, self.b, self.a end
	function c.SetRGBA(self, r_, g_, b_, a_) self.r, self.g, self.b, self.a = r_, g_, b_, a_ or 1 end
	function c.SetRGB(self, r_, g_, b_) self.r, self.g, self.b = r_, g_, b_ end
	function c.GenerateHexColor(self) return ("ff%02x%02x%02x"):format(self.r * 255, self.g * 255, self.b * 255) end
	function c.WrapTextInColorCode(self, text) return "|c" .. self:GenerateHexColor() .. text .. "|r" end
	return c
end

function World:addClient(name, opts)
	opts = opts or {}
	local p = self:player(name) or self:addBot(name, { spot = opts.spot, money = opts.money, class = opts.class or "WARLOCK", shards = opts.shards or 10,
		faction = opts.faction })
	if opts.spot then self:placePlayer(p, opts.spot) end
	if opts.money then p.money = opts.money end
	p.class = opts.class or p.class or "WARLOCK"
	p.knowsRitual = p.class == "WARLOCK" and opts.knowsRitual ~= false
	p.shards = opts.shards or p.shards or 10
	-- (REC login.channels.*) the game's own channels: five at /1 to /5 (the chat-cache.txt of all 11 characters on this
	-- PC: channel ids 1, 2, 22, 42, 46; the fake keeps its first four names and calls the fifth "Custom5"), so Wuber's
	-- channel takes /6 as in the game. A /reload (opts.keepChannels) keeps the list as it was, Wuber's channel too; a
	-- fresh login starts with none and gets these loginDelay s after PLAYER_ENTERING_WORLD ("atOnce": at once).
	local gameChannels = {}
	for i = 1, opts.channels or 5 do
		gameChannels[#gameChannels + 1] = { index = i, name = DEFAULT_CHANNELS[i] or ("Custom" .. i) }
	end
	local arrive = opts.channelsArrive or self.channelsArrive
	if not (opts.keepChannels and p.channels) then
		p.channels = {}
		if arrive ~= "real" then
			for _, c in ipairs(gameChannels) do p.channels[#p.channels + 1] = c end
		end
	end
	p.group = opts.group or p.group
	-- loadRR = "1.4.1" (Ritual Rides as it was) or "tombstone" (1.5.0, retired): adds RitualRides
	local addonList = opts.addons and { unpack(opts.addons) } or { "Wuber" }
	local addonDirs = opts.addonDirs
	if opts.loadRR then
		local has = false
		for _, a in ipairs(addonList) do if a == "RitualRides" then has = true end end
		if not has then addonList[#addonList + 1] = "RitualRides" end
		if opts.loadRR == "tombstone" then
			local d = {}
			for k, v in pairs(addonDirs or {}) do d[k] = v end
			d.RitualRides = H.RR_TOMBSTONE
			addonDirs = d
		end
	end
	-- addons the player switched off (C_AddOns.DisableAddOn) don't load after a reload
	p.disabledAddons = p.disabledAddons or {}
	do
		local keep = {}
		for _, a in ipairs(addonList) do if not p.disabledAddons[a] then keep[#keep + 1] = a end end
		addonList = keep
	end
	local client = setmetatable({
		world = self, player = p, frames = {}, widgets = {}, animGroups = {}, updaters = {}, updaterSet = {}, playing = {}, secrets = {}, prefixes = {}, popups = {},
		chatLines = {}, chatShown = {}, chatFilters = {}, sounds = {}, alive = true, missing = {},
		bucket = { tokens = self.throttleBurst, at = self.time }, addons = addonList, loadRR = opts.loadRR, spot = opts.spot,
		allAddons = opts.addons or { "Wuber" },
		saved = opts.saved or {}, mods = {}, texturePaths = {}, plates = {}, wantPlates = {}, tipPostCalls = {}, cvarSets = {},
		roundOne = opts.roundOne, addonDirs = addonDirs, mooLoaded = opts.mooLoaded, fired = {}, flashes = 0,
		-- whisper fallback: a trial account (every addon message refused), its internal realm,
		-- and which copy of a custom channel it lands in (see World:splitChannel)
		addonFails = opts.addonFails, realm = opts.realm, channelCopy = opts.channelCopy, layer = opts.layer,
		-- (BRIEF21 S5) opts.rewrite(addon, file, text) -> text: the source the client loads instead (old code from a fixture)
		rewrite = opts.rewrite,
	}, Client)
	client.cvars = setmetatable({}, { __index = self.cvars })
	p.client = client
	self.clients[#self.clients + 1] = client
	-- (REC login.channels.reload) the reloaded window is still in the channels it kept
	if opts.keepChannels then
		for _, c in ipairs(p.channels) do
			local ch = self.channels[c.name:lower()]
			if ch then ch.members[client] = true end
		end
	end
	-- (REC selftest.login) opts.mapBlank = s: C_Map answers nothing for s seconds after the login (Client:blankMap)
	if opts.mapBlank then client.mapBlankUntil = self.time + opts.mapBlank end
	-- (v2.4 fix3 LRN-08, FAKE-GAME-HINTS 34) opts.spellbookLate = s: the spellbook cannot be read for s seconds after the
	-- login (no spell is known, not even Shadow Bolt), then SPELLS_CHANGED fires, as a client that has not loaded it yet.
	if opts.spellbookLate then
		client.bookBlankUntil = self.time + opts.spellbookLate
		self:after(opts.spellbookLate, function() client:fire("SPELLS_CHANGED") end, client, "spellbook")
	end
	H.made[#H.made + 1] = client
	local w = self
	if opts.secrets then for _, k in ipairs(opts.secrets) do client.secrets[k] = true end end
	-- (probe pack) the calls a real client answered with a secret in the probe run (H.secretApi, tests/lib/probe_learn.lua)
	if H.secretApi then for name in pairs(H.secretApi) do client.secrets[H.SECRET_API_KEY[name] or name] = true end end

	local api = {}
	local env = api -- while the API is built; afterwards env is the addons' global table
	client.env = env
	client.api = api

	local function sec(kind, v) if client.secrets[kind] then H.rule("secret.api-returns") return SECRET end return v end

	-- frames
	env.CreateFrame = function(ftype, fname, parent, template, id) return H.createFrame(client, ftype, fname, parent, template, id) end
	-- CreateFont(name): a font object of its own (a name is registered as a global, as the game does)
	env.CreateFont = function(fname)
		if type(fname) ~= "string" then error("Usage: CreateFont(\"name\")", 2) end
		local o = { path = "Fonts\\FRIZQT__.TTF", size = 12, flags = "" }
		function o:SetFont(path, size, flags) o.path, o.size, o.flags = path, size, flags or "" return true end
		function o:SetFontObject(other) local f = fontObj(other) if f then o.path, o.size, o.flags = f.path, f.size, f.flags end end
		function o:GetFont() return o.path, o.size, o.flags end
		env[fname] = o
		H.fonts[o] = true -- (a named font object is the game's own kind of named thing, as a named frame is: the stray-global tests allow one named Wuber...)
		return o
	end
	local UIParent = H.createFrame(client, "Frame", "UIParent")
	S[UIParent].isUIParent = true
	S[UIParent].w, S[UIParent].h = opts.screenW or 1920, opts.screenH or 1080
	local function child(ftype, fname, parent)
		local f = H.createFrame(client, ftype, fname, parent or UIParent)
		return f
	end
	local chat = child("ScrollingMessageFrame", "DEFAULT_CHAT_FRAME")
	S[chat].isChat = true
	client.chat = chat
	env.NUM_CHAT_WINDOWS = 10
	for i = 1, 10 do
		local cf = i == 1 and chat or child("ScrollingMessageFrame", "ChatFrame" .. i)
		env["ChatFrame" .. i] = cf
		cf.channelList = {}
		cf.zoneChannelList = {}
	end
	env.ChatFrame1EditBox = child("EditBox", "ChatFrame1EditBox")
	S[env.ChatFrame1EditBox].shown = false
	env.UIErrorsFrame = child("MessageFrame", "UIErrorsFrame")
	env.GameTooltip = child("GameTooltip", "GameTooltip")
	S[env.GameTooltip].shown = false
	S[env.GameTooltip].modernTip = w.tooltipStyle == "processor"
	S[env.GameTooltip].lineFS = {}
	-- (round 13, I5) the game's tooltip background: a NineSlice that is a little see-through by default
	-- (what shows under it mixes into its text). Its strata stays the harness default so the transcript
	-- of every test keeps its GameTooltip line; Theme.Widgets' test sets the game's look itself.
	env.GameTooltip.NineSlice = { center = { 0.09, 0.09, 0.19, 0.8 },
		SetCenterColor = function(self, r, g, b, a) self.center = { r, g, b, a or 1 } end,
		GetCenterColor = function(self) return unpack(self.center) end,
		SetBorderColor = function() end }
	for i = 1, 30 do
		local fs = Frame.CreateFontString(env.GameTooltip, "GameTooltipTextLeft" .. i, "ARTWORK", "GameTooltipText")
		S[fs].shown = false
		S[env.GameTooltip].lineFS[i] = fs
		env["GameTooltipTextLeft" .. i] = fs
	end
	env.ItemRefTooltip = child("GameTooltip", "ItemRefTooltip")
	S[env.ItemRefTooltip].shown = false
	S[env.ItemRefTooltip].modernTip = w.tooltipStyle == "processor"
	env.Minimap = child("Frame", "Minimap")
	env.Minimap:SetSize(140, 140)
	env.Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
	env.MinimapCluster = child("Frame", "MinimapCluster")
	env.UISpecialFrames = {}
	env.STATICPOPUP_NUMDIALOGS = 4
	env.StaticPopupDialogs = {}

	-- the world map
	local wm = child("Frame", "WorldMapFrame")
	S[wm].shown = false
	wm:SetSize(1002, 668 + 70)
	wm:SetPoint("CENTER")
	local sc = H.createFrame(client, "ScrollFrame", nil, wm)
	sc:SetSize(1002, 668)
	sc:SetPoint("BOTTOM", wm, "BOTTOM")
	local canvas = H.createFrame(client, "Frame", nil, sc)
	canvas:SetSize(1002, 668)
	canvas:SetPoint("TOPLEFT", sc, "TOPLEFT")
	rawset(sc, "Child", canvas)
	rawset(wm, "ScrollContainer", sc)
	client.mapID = opts.mapShown or p.mapID
	client.canvasScale = 1
	rawset(sc, "GetCanvasScale", function(self) return client.canvasScale end)
	rawset(sc, "GetNormalizedCursorPosition", function(self) return client.mapCursorX or 0.5, client.mapCursorY or 0.5 end)
	rawset(sc, "GetCanvas", function(self) return canvas end)
	rawset(wm, "GetMapID", function(self) return client.mapID end)
	-- (tests/lib/maptaint.lua, rule c) Wuber's own code may not show or move the map with the game's Lua
	local wmShow = wm.Show
	rawset(wm, "Show", function(self) H.mapTaint.opener(client, "WorldMapFrame:Show()") return wmShow(self) end)
	rawset(wm, "SetMapID", function(self, id)
		H.mapTaint.opener(client, "WorldMapFrame:SetMapID()")
		if type(id) ~= "number" or not H.MAPS[id] then error("WorldMapFrame:SetMapID(): unknown map " .. tostring(id), 2) end
		if client.mapID == id then return end
		client.mapID = id
		self:OnMapChanged()
	end)
	rawset(wm, "OnMapChanged", function(self)
		if env.EventRegistry then env.EventRegistry:TriggerEvent("MapCanvas.MapSet", client.mapID) end
	end)
	rawset(wm, "GetCanvasContainer", function(self) return sc end)
	rawset(wm, "GetCanvas", function(self) return canvas end)
	rawset(wm, "RefreshAllDataProviders", function(self) end)
	rawset(wm, "IsMaximized", function(self) return false end)
	client.mapCanvas = canvas

	env.EventRegistry = {
		callbacks = {},
		RegisterCallback = function(self, event, fn, owner)
			self.callbacks[event] = self.callbacks[event] or {}
			table.insert(self.callbacks[event], { fn = fn, owner = owner })
		end,
		UnregisterCallback = function(self, event, owner)
			local list = self.callbacks[event] or {}
			for i = #list, 1, -1 do if list[i].owner == owner then table.remove(list, i) end end
		end,
		TriggerEvent = function(self, event, ...)
			for _, cb in ipairs(self.callbacks[event] or {}) do
				if cb.owner ~= nil then H.protect(w, client, "EventRegistry " .. event, cb.fn, cb.owner, ...)
				else H.protect(w, client, "EventRegistry " .. event, cb.fn, ...) end
			end
		end,
	}

	env.print = function(...)
		local parts = { ... }
		for i = 1, select("#", ...) do parts[i] = tostring(parts[i]) end
		client.chatLines[#client.chatLines + 1] = table.concat(parts, " ")
	end
	-- the client's tests for a secret: a secret is one value (rawequal: no compare is made on it), a table is not
	env.issecretvalue = function(v) return rawequal(v, SECRET) end
	env.canaccessvalue = function(v) return not rawequal(v, SECRET) end
	env.issecrettable = function() return false end
	env.canaccesstable = function() return true end
	env.GetTime = function() return w.time end
	-- the realm's clock (hours, minutes): starts at 19:17 and runs with the world's clock
	env.GetGameTime = function()
		local m = (19 * 60 + 17 + math.floor(w.time / 60)) % 1440
		return math.floor(m / 60), m % 60
	end
	env.GetServerTime = function() return H.EPOCH + math.floor(w.time) end
	env.time = function(t) if t then return os.time(t) end return H.EPOCH + math.floor(w.time) end
	env.date = function(fmt, t) return os.date(fmt, t or (H.EPOCH + math.floor(w.time))) end
	env.debugprofilestop = function() return w.time * 1000 end
	-- (speed job 2749) the memory calls the Lab's timing pass reads: this one Lua state's heap, in KB
	env.UpdateAddOnMemoryUsage = function() end
	env.GetAddOnMemoryUsage = function() return collectgarbage("count") end
	-- (REC build.number) the build of 20 Nov 2026 on (70938 of 12 Nov and 70959 of 13 Nov came before it)
	env.GetBuildInfo = function() return "1.60.1", "71037", "Nov 18 2026", 16001, "1.60.1", "release" end
	env.GetLocale = function() return "enGB" end
	-- (Forever's realm names carry the region and ruleset: "CAMWOW EU5 Realm 5 PvE")
	-- (REC realm.name.empty71037, D16) build 71037 names no realm: "" by default (H.DEFAULT_REALM). A world or client
	-- realm = false: both give nil; secrets "realm": a secret
	local function realmName()
		local r = client.realm
		if r == nil then r = client.world.realm end
		if r == nil then r = H.DEFAULT_REALM end
		return r
	end
	env.GetRealmName = function()
		if client.secrets.realm then return SECRET end
		local r = realmName()
		if r == "" then H.rule("env.realm-empty") end
		if r == false then return nil end
		return r
	end
	env.GetNormalizedRealmName = function()
		if client.secrets.realm then return SECRET end
		local r = realmName()
		if r == false then return nil end
		return (r:gsub("%s", ""))
	end
	-- (PF-054 L16, build 71037) the realm id is 0, the region 3, hardcore and war mode off
	env.GetRealmID = function() return 0 end
	env.GetCurrentRegion = function() return 3 end
	env.C_GameRules = { IsHardcoreActive = function() return false end }
	env.C_PvP = { IsWarModeActive = function() return false end, IsWarModeDesired = function() return false end }
	-- (PF-049 L13.style) mouse and keyboard
	env.C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
	env.GetFramerate = function() return 60 end
	env.InCombatLockdown = function() return p.combat end
	env.GetCameraZoom = function() return client.cameraZoom or 15 end
	env.IsMounted = function() return client.mounted == true end
	env.UnitAffectingCombat = function(unit) local u = client:unit(unit) return u and u.combat or false end
	env.IsShiftKeyDown = function() return client.mods.shift == true end
	env.IsControlKeyDown = function() return client.mods.ctrl == true end
	env.IsAltKeyDown = function() return client.mods.alt == true end
	env.IsModifierKeyDown = function() return client.mods.shift or client.mods.ctrl or client.mods.alt or false end
	env.IsMouseButtonDown = function() return false end
	-- the frames under the cursor, top first (the game's table); a test that only named the frame (client.mouseOver) gets that one
	env.GetMouseFoci = function()
		local at = client.mouseAt
		if at and client.mouseOver == at.focus then return client:framesAt(at.x, at.y) end
		return client.mouseOver and { client.mouseOver } or {}
	end
	env.GetCursorPosition = function() return client.cursorX or 960, client.cursorY or 540 end
	env.GetScreenWidth = function() return S[UIParent].w end
	env.GetScreenHeight = function() return S[UIParent].h end
	-- (a test may change client.physW / client.physH: the window is resized)
	env.GetPhysicalScreenSize = function() return client.physW or opts.physW or 3840, client.physH or opts.physH or 2160 end
	env.PlaySound = function(id, channel)
		if type(id) ~= "number" and type(id) ~= "string" then error("PlaySound(soundKitID [, channel]): bad soundKitID", 2) end
		client.sounds[#client.sounds + 1] = id
		return true, 1
	end
	env.PlaySoundFile = function(path, channel)
		H.checkFile(client, path, "sound", { ".ogg", ".mp3", ".wav" })
		client.sounds[#client.sounds + 1] = path
		return true, 1
	end
	env.SOUNDKIT = { RAID_WARNING = 8959, IG_MAINMENU_OPEN = 850, IG_MAINMENU_CLOSE = 851, IG_MAINMENU_OPTION_CHECKBOX_ON = 856,
		READY_CHECK = 8960, U_CHAT_SCROLL_BUTTON = 1115, IG_CHARACTER_INFO_TAB = 841, TELL_MESSAGE = 3081, MAP_PING = 3175,
		UI_BNET_TOAST = 18019, ALARM_CLOCK_WARNING_3 = 12889, IG_QUEST_LIST_OPEN = 875, IG_PLAYER_INVITE = 880 }
	env.SlashCmdList = {}
	env.hash_SlashCmdList = {}
	env.GetCVar = function(k) return client.cvars[k] end
	env.GetCVarBool = function(k) local v = client.cvars[k] if v == nil then return nil end return v == "1" end
	env.GetCVarDefault = function(k) return w.cvars[k] end
	-- nameplate CVars are protected in combat; an unknown CVar is not set
	env.SetCVar = function(k, v)
		if type(k) ~= "string" then error("Usage: SetCVar(name, value)", 2) end
		local who = H.caller(2) or "harness"
		if p.combat and k:lower():match("^nameplate") then
			w.violations[#w.violations + 1] = who .. ": SetCVar(" .. k .. ") in combat (protected)"
			client:fire("ADDON_ACTION_BLOCKED", client:callerAddon(), "SetCVar()")
			return false
		end
		if client.cvars[k] == nil then
			H.uncertain["CVar " .. k] = "unknown CVar: not set"
			return false
		end
		v = (v == true and "1") or (v == false and "0") or tostring(v)
		client.cvars[k] = v
		client.cvarSets[#client.cvarSets + 1] = { name = k, value = v, by = who, at = w.time }
		client:fire("CVAR_UPDATE", k, v)
		client:refreshPlates()
		return true
	end
	env.C_CVar = { GetCVar = env.GetCVar, GetCVarBool = env.GetCVarBool, SetCVar = env.SetCVar, GetCVarDefault = env.GetCVarDefault }
	env.UNKNOWNOBJECT, env.UNKNOWN = "Unknown", "Unknown"
	for k, v in pairs(H.SYSTEM_LINES) do env[k] = v end -- (fact chat.system.lines, World:join / leave / openTrade)
	env.ERR_TRADE_COMPLETE = "Trade complete."
	env.ERR_DECLINE_GROUP_S = "%s declines your group invitation."
	env.ERR_ALREADY_IN_GROUP_S = "%s is already in a group."
	env.ERR_BAD_PLAYER_NAME_S = "Cannot find player '%s'."
	env.ERR_IGNORING_YOU_S = "%s is ignoring you."
	env.ERR_GROUP_FULL = "Your party is full."
	env.CONVERT_TO_RAID = "Convert to Raid"
	env.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
	env.ERR_INVITE_PLAYER_S = "You have invited %s to join your group."
	env.ERR_NOT_LEADER = "You are not the party leader."
	env.MAX_TRADABLE_ITEMS = 6
	env.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
	env.Enum = { SendAddonMessageResult = H.SEND_RESULT, RegisterAddonMessagePrefixResult = H.REGISTER_RESULT, UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
	H.rule("env.project-id")
	env.WOW_PROJECT_ID = 18 -- (fga d) Blizzard_ProjectConstants/Camelot: WOW_PROJECT_ID = WOW_PROJECT_CAMELOT
	env.WOW_PROJECT_CAMELOT = 18
	env.WOW_PROJECT_CLASSIC = 2
	env.WOW_PROJECT_MAINLINE = 1
	env.RAID_CLASS_COLORS = { WARLOCK = color(0.53, 0.53, 0.93), MAGE = color(0.25, 0.78, 0.92), PRIEST = color(1, 1, 1), WARRIOR = color(0.78, 0.61, 0.43),
		DRUID = color(1, 0.49, 0.04), ROGUE = color(1, 0.96, 0.41), HUNTER = color(0.67, 0.83, 0.45) }
	env.NORMAL_FONT_COLOR = color(1, 0.82, 0)
	env.HIGHLIGHT_FONT_COLOR = color(1, 1, 1)
	env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
	for n, fo in pairs(FONT_OBJECTS) do env[n] = fo end

	-- Lua extras of the game
	env.strsplit = function(sep, s, limit)
		local out, n = {}, 0
		local pattern = "([^" .. sep:gsub("%p", "%%%0") .. "]*)"
		local start = 1
		while true do
			n = n + 1
			if limit and n >= limit then out[#out + 1] = s:sub(start) break end
			local a, b = s:find(sep, start, true)
			if not a then out[#out + 1] = s:sub(start) break end
			out[#out + 1] = s:sub(start, a - 1)
			start = b + 1
		end
		return unpack(out)
	end
	env.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
	env.strtrim = function(s, chars) chars = chars and ("[" .. chars:gsub("%p", "%%%0") .. "]") or "%s" return (s:gsub("^" .. chars .. "+", ""):gsub(chars .. "+$", "")) end
	env.strlower, env.strupper, env.strlen, env.strsub, env.strfind, env.strmatch = string.lower, string.upper, string.len, string.sub, string.find, string.match
	env.strrep, env.strbyte, env.strchar, env.strrev, env.gsub, env.gmatch, env.format = string.rep, string.byte, string.char, string.reverse, string.gsub, string.gmatch, string.format
	env.tinsert, env.tremove, env.tconcat, env.sort = table.insert, table.remove, table.concat, table.sort
	env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	env.table = setmetatable({ wipe = env.wipe }, { __index = table })
	env.floor, env.ceil, env.abs, env.min, env.max, env.sqrt, env.mod = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt, math.fmod
	env.sin = function(d) return math.sin(math.rad(d)) end
	env.cos = function(d) return math.cos(math.rad(d)) end
	env.random = math.random
	env.fastrandom = math.random
	env.tostringall = function(...) local t = { ... } for i = 1, select("#", ...) do t[i] = tostring(t[i]) end return unpack(t) end
	env.geterrorhandler = function() return function(e) w.errors[#w.errors + 1] = p.name .. " errorhandler: " .. tostring(e) end end
	env.seterrorhandler = function() end
	env.securecall = function(fn, ...) if type(fn) == "string" then fn = env[fn] end return fn(...) end
	env.issecurevariable = function() return false, "Wuber" end
	env.hooksecurefunc = function(a, b, c)
		local t, name, fn = a, b, c
		if type(a) == "string" then t, name, fn = api, a, b end
		local old = t[name]
		if type(old) ~= "function" then error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2) end
		if H.taint then H.taint.quiet = H.taint.quiet + 1 end -- the game's own hook installer writes it, not the addon
		t[name] = function(...)
			local r = { old(...) }
			fn(...)
			return unpack(r)
		end
		if H.taint then H.taint.quiet = H.taint.quiet - 1 H.taint.accept(client, t, name) end
	end
	env.Mixin = function(obj, ...)
		for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do obj[k] = v end end
		return obj
	end
	env.CreateFromMixins = function(...) return env.Mixin({}, ...) end
	env.CreateColor = color
	env.CreateVector2D = function(x, y) return vector(x, y) end
	env.GetCoinTextureString = function(copper)
		local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
		local out = {}
		if g > 0 then out[#out + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t" end
		if s > 0 then out[#out + 1] = s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t" end
		if c > 0 or #out == 0 then out[#out + 1] = c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
		return table.concat(out, " ")
	end
	env.GetMoneyString = env.GetCoinTextureString
	env.C_AddOns = {
		IsAddOnLoaded = function(n)
			for _, a in ipairs(client.addons) do if a == n then return true, true end end
			if n == "Moo" then return client.mooLoaded == true, true end
			return n == "OpenMap" and env.OpenMapAPI ~= nil, true
		end,
		GetAddOnMetadata = function(n, field) if field == "Version" then return n == "Wuber" and "1.0.0" or "1.4.0" end end,
		LoadAddOn = function(n) return false, "MISSING" end,
		-- switching an addon off takes effect at the next reload (as in the game)
		DisableAddOn = function(n, character)
			if type(n) ~= "string" then error("Usage: C_AddOns.DisableAddOn(name [, character])", 2) end
			p.disabledAddons[n] = true
			client.disabledCalls = (client.disabledCalls or 0) + 1
		end,
		EnableAddOn = function(n) if type(n) == "string" then p.disabledAddons[n] = nil end end,
		GetAddOnEnableState = function(n, character)
			if type(n) == "number" then return 2 end
			if p.disabledAddons[n] then return 0 end
			return 2
		end,
	}
	if w.noDisableAddOn then env.C_AddOns.DisableAddOn = nil end
	env.DisableAddOn = env.C_AddOns.DisableAddOn
	env.ReloadUI = function()
		client.reloadAsked = (client.reloadAsked or 0) + 1
		client.reloadForbidden = client.reloadForbidden or {} -- (#230) a test asserts this stays empty
		-- (PF-050 L13.blocked) "ReloadUI called from addon code is blocked": the game says so and nothing reloads
		if not w.reloadAllowed then
			H.rule("reload.from-addon-code")
			table.insert(client.reloadForbidden, client:callerAddon())
			client:fire("ADDON_ACTION_BLOCKED", client:callerAddon(), "ReloadUI()")
			return
		end
		-- the game reloads after the current frame
		w:after(0, function() if client.alive then w:reload(client) end end, client, "ReloadUI")
	end
	env.FlashClientIcon = function() client.flashes = client.flashes + 1 end
	env.IsAddOnLoaded = env.C_AddOns.IsAddOnLoaded
	env.GetAddOnMetadata = env.C_AddOns.GetAddOnMetadata

	-- timers
	env.C_Timer = {
		After = function(delay, fn)
			if type(delay) ~= "number" or type(fn) ~= "function" then error("Usage: C_Timer.After(seconds, callback)", 2) end
			w:after(delay, fn, client, "C_Timer.After")
		end,
		NewTicker = function(every, fn, iterations)
			if type(every) ~= "number" or type(fn) ~= "function" then error("Usage: C_Timer.NewTicker(seconds, callback [, iterations])", 2) end
			H.rule("timing.ticker")
			local ticker
			local t = w:after(every, function() fn(ticker) end, client, "C_Timer.NewTicker")
			t.every = every
			t.iterations = iterations
			ticker = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled == true end }
			return ticker
		end,
		NewTimer = function(delay, fn)
			if type(delay) ~= "number" or type(fn) ~= "function" then error("Usage: C_Timer.NewTimer(seconds, callback)", 2) end
			local timer
			local t = w:after(delay, function() fn(timer) end, client, "C_Timer.NewTimer")
			timer = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled == true end }
			return timer
		end,
	}

	-- units
	env.UnitName = function(unit)
		local u = client:unit(unit)
		if not u then return nil end
		if client.secrets.UnitName or client:secretPlateUnit(unit) then return SECRET, SECRET end
		return u.first, u.surname -- (PF-047 L12.self: "UnitName len 5" for the player too: the first name, then the surname)
	end
	env.UnitFullName = function(unit)
		local u = client:unit(unit)
		if not u then return nil end
		if client.secrets.UnitName then return SECRET, SECRET end
		return u.first, u.surname -- (D16) in game the second value is the surname, not a realm
	end
	env.GetUnitName = function(unit, showServer)
		local u = client:unit(unit)
		if not u then return nil end
		if client.secrets.UnitName or client:secretPlateUnit(unit) then return SECRET end
		return u.name
	end
	env.UnitClass = function(unit)
		local u = client:unit(unit)
		if not u then return end -- no values for a unit that is not there (A1)
		if client.secrets.UnitClass then return SECRET, SECRET, SECRET end
		local cls = u.class or "MAGE"
		local n = CLASS_NAMES[cls] or { cls, 0 }
		return n[1], cls, n[2]
	end
	env.UnitLevel = function(unit) local u = client:unit(unit) return u and u.level or 0 end
	env.UnitFactionGroup = function(unit) local u = client:unit(unit) if u then return u.faction or "Horde", u.faction or "Horde" end end
	env.UnitGUID = function(unit) local u = client:unit(unit) if u and client.secrets.guid then return SECRET end return u and ("Player-1-" .. key(u.name)) or nil end
	env.UnitExists = function(unit) return client:unit(unit) ~= nil end
	env.UnitIsUnit = function(a, b) local x, y = client:unit(a), client:unit(b) return x ~= nil and x == y end
	env.UnitIsPlayer = function(unit) return client:unit(unit) ~= nil end
	env.UnitIsConnected = function(unit) local u = client:unit(unit) return u ~= nil and u.online end
	env.UnitIsDeadOrGhost = function(unit) return false end
	env.UnitIsVisible = function(unit) local u = client:unit(unit) return u ~= nil and u.online and u.zone == p.zone end
	env.CheckInteractDistance = function(unit) local u = client:unit(unit) return u ~= nil and u.zone == p.zone end
	env.UnitInRange = function(unit) local u = client:unit(unit) return u ~= nil and u.zone == p.zone, true end
	env.UnitIsGroupLeader = function(unit) local u = client:unit(unit) return u ~= nil and u.group ~= nil and u.group.leader == u.name end
	env.UnitInParty = function(unit) local u = client:unit(unit) return u ~= nil and (u == p or (p.group ~= nil and u.group == p.group)) end
	-- the leader hands the lead to a member (a unit token or a name): not a protected call
	env.PromoteToLeader = function(unit)
		local g = p.group
		if not g or g.leader ~= p.name then return end
		local u = client:unit(unit) or (type(unit) == "string" and w:player((unit:gsub("%-", " "))))
		if not u or u.group ~= g or u == p then return end
		g.leader = u.name
		w.promotions = w.promotions or {}
		w.promotions[#w.promotions + 1] = { from = p.name, to = u.name, at = w.time }
		w:eachClient(g, function(c2) c2:fire("PARTY_LEADER_CHANGED") end)
		w:rosterChanged(g)
	end
	-- raid assists (SPEC4 3.1: a raid runner needs lead or assist). Forever 1.60.1 names are
	-- not certain: both UnitIsGroupAssistant and UnitIsRaidOfficer answer
	env.UnitIsGroupAssistant = function(unit)
		local u = client:unit(unit)
		return u ~= nil and u.group ~= nil and u.group.raid == true and (u.group.assists or {})[u.name] == true
	end
	env.UnitIsRaidOfficer = function(unit)
		local u = client:unit(unit)
		return u ~= nil and u.group ~= nil and u.group.raid == true
			and (u.group.leader == u.name or (u.group.assists or {})[u.name] == true)
	end
	env.PromoteToAssistant = function(unit)
		local g = p.group
		if not g or g.leader ~= p.name or not g.raid then return end
		local u = client:unit(unit) or (type(unit) == "string" and w:player((unit:gsub("%-", " "))))
		if not u or u.group ~= g or u == p then return end
		w:setAssist(u.name, true)
	end
	env.DemoteAssistant = function(unit)
		local g = p.group
		if not g or g.leader ~= p.name then return end
		local u = client:unit(unit) or (type(unit) == "string" and w:player((unit:gsub("%-", " "))))
		if u and u.group == g then w:setAssist(u.name, false) end
	end
	-- name, rank (2 leader, 1 assist, 0), subgroup, level, class, fileName, zone, online, isDead
	env.GetRaidRosterInfo = function(index)
		local g = p.group
		if not g or not g.raid or type(index) ~= "number" then return nil end
		local u = w:player(g.members[index])
		if not u then return nil end
		local rank = (g.leader == u.name and 2) or ((g.assists or {})[u.name] and 1) or 0
		local cls = u.class or "MAGE"
		local names = { WARLOCK = "Warlock", MAGE = "Mage", PRIEST = "Priest", WARRIOR = "Warrior", DRUID = "Druid" }
		return u.name, rank, math.floor((index - 1) / 5) + 1, u.level or 60, names[cls] or cls, cls, u.zone, u.online ~= false, false
	end
	env.UnitInRaid = function(unit)
		local u = client:unit(unit)
		if not u or not p.group or not p.group.raid then return nil end
		for i, n in ipairs(p.group.members) do if n == u.name then return i end end
	end
	env.IsInGroup = function() return p.group ~= nil end
	env.IsInRaid = function() return p.group ~= nil and p.group.raid end
	env.IsInGuild = function() return p.guild ~= nil and p.guild ~= "" end
	env.GetNumGroupMembers = function() return p.group and #p.group.members or 0 end
	env.GetNumSubgroupMembers = function() return p.group and (#p.group.members - 1) or 0 end
	-- a test puts a player in an instance with c.player.instance = true (or the kind: "party", "raid", "pvp")
	env.IsInInstance = function()
		if p.instance then return true, type(p.instance) == "string" and p.instance or "party" end
		return false, "none"
	end
	env.GetRealZoneText = function() return sec("zone", p.zone) end
	env.GetZoneText = function() return sec("zone", p.zone) end
	env.GetSubZoneText = function() return sec("zone", p.subZone or "") end
	env.GetMinimapZoneText = function() local s = p.subZone if s == "" or not s then s = p.zone end return sec("zone", s) end
	env.UnitPosition = function(unit)
		local u = client:unit(unit)
		if not u then return nil end
		if client.secrets.C_Map then return SECRET, SECRET, SECRET, SECRET end
		local cont, wx, wy = H.toWorld(u.mapID, u.x, u.y)
		return wy, wx, 0, cont
	end
	-- (fga d) the 11 values of UnitDocumentation: name, displayName, textureID, startMs, endMs, isTradeskill, castID, notInterruptible, spellID, castBarID, delayMs
	env.UnitCastingInfo = function(unit)
		local u = client:unit(unit or "player")
		local r = u and w.rituals and w.rituals[u.name]
		if r and r.stage == "cast" then
			return w.ritualName, w.ritualName, 136223, r.t0 * 1000, (r.t0 + 0.5) * 1000, false, r.guid, nil, w:spellId(), 0, 0
		end
		local tc = u and u.travelCast
		if tc then return tc.name, tc.name, 134414, tc.t0 * 1000, tc.t1 * 1000, false, tc.guid, nil, tc.spellID, 0, 0 end
	end
	env.UnitChannelInfo = function(unit)
		local u = client:unit(unit or "player")
		if not u then return nil end
		for _, r in pairs(w.rituals or {}) do
			if r.stage == "channel" and (r.caster == u or r.clicks[u.name]) then
				-- name, displayName, textureID, startMs, endMs, isTradeskill, notInterruptible, spellID, isEmpowered, numEmpowerStages, castBarID
				return w.ritualName, w.ritualName, 136223, r.t1 * 1000, (r.t1 + 120) * 1000, false, nil, w:spellId(), false, 0, nil
			end
		end
	end
	env.GetGuildInfo = function() return p.guild end

	-- (client:secret("GetItemCount"): the count is secret, as other addons guard for on this client: FAKE-GAME-HINTS part 2,
	-- SummonCircle Core/Game.lua:1-3, 21-24)
	env.C_Item = { GetItemCount = function(id)
		if client.secrets.GetItemCount then return SECRET end
		return id == 6265 and p.shards or 0
	end }
	env.GetItemCount = env.C_Item.GetItemCount
	env.C_Spell = {
		GetSpellInfo = function(spell)
			if client.bookBlankUntil and w.time < client.bookBlankUntil then return nil end
			if (spell == w.ritualName or spell == 698) and p.knowsRitual then return { name = w.ritualName, spellID = 698 } end
			return -- unknown spell: no values (A1)
		end,
		GetSpellName = function(id) if id == 698 then return w.ritualName end end,
		GetSpellCooldown = function(spell)
			if spell ~= w.ritualName and spell ~= 698 then return end -- unknown spell: no values (A1)
			local left = (p.cooldownUntil or 0) - w.time
			if left <= 0 then return { startTime = 0, duration = 0, isEnabled = true } end
			return { startTime = w.time, duration = left, isEnabled = true }
		end,
	}
	env.IsPlayerSpell = function(id) return env.IsSpellKnown(id) end -- (PF-041 L7: the real client has it)
	env.IsSpellKnown = function(id)
		if client.bookBlankUntil and w.time < client.bookBlankUntil then return false end
		if id == 686 then return p.class == "WARLOCK" end -- (Shadow Bolt: every Warlock has it from level 1; the spellbook-readable probe)
		return id == 698 and p.knowsRitual
	end

	-- key bindings (Ritual Rides)
	-- (override bindings belong to their owner frame: clearing one owner's leaves the others')
	env.SetOverrideBindingClick = function(owner, _, k, buttonName)
		if p.combat then w.violations[#w.violations + 1] = name .. ": SetOverrideBindingClick in combat" return end
		client.bindingOf = client.bindingOf or {}
		client.binding = { key = k, button = buttonName, owner = owner }
		client.bindingOf[owner or "?"] = client.binding
	end
	env.ClearOverrideBindings = function(owner)
		if p.combat then w.violations[#w.violations + 1] = name .. ": ClearOverrideBindings in combat" return end
		client.bindingOf = client.bindingOf or {}
		local had = client.bindingOf[owner or "?"]
		client.bindingOf[owner or "?"] = nil
		if had and client.binding == had then client.binding = select(2, next(client.bindingOf)) end
	end

	-- channels
	env.JoinTemporaryChannel = function(cname) return w:joinChannel(client, cname) end
	env.JoinChannelByName = function(cname) return w:joinChannel(client, cname) end
	env.JoinPermanentChannel = function(cname) return w:joinChannel(client, cname) end
	env.LeaveChannelByName = function(cname) w:leaveChannel(client, cname) end
	-- (internal notes, hint 21) the owner of a custom channel may clear its password; neutral unless a test sets an owner
	env.IsDisplayChannelOwner = function()
		for _, ch in pairs(w.channels) do if ch.owner == client then return true end end
		return false
	end
	env.SetChannelPassword = function(cname, pw)
		local ch = type(cname) == "string" and w.channels[cname:lower()] or nil
		if ch and ch.owner == client then
			if pw == "" or pw == nil then client.passwordClears = (client.passwordClears or 0) + 1 end
			ch.password = (pw ~= "" and pw) or nil
			-- the game announces every change to the members, the owner's own clear too, with the changer's name
			-- (argument 5; Lego_ChannelTransport.lua:1665-1666 skips its own name for that reason)
			for c in pairs(ch.members) do
				c:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", "", "", ch.name, client.player.name, "", "", 0, ch.name)
			end
		end
	end
	env.GetChannelName = function(id)
		if client.secrets.channels then return SECRET, SECRET, SECRET end
		for _, c in ipairs(p.channels) do
			if not c.pending and ((type(id) == "number" and c.index == id) or (type(id) == "string" and c.name:lower() == id:lower())) then
				return c.index, c.name, 0, false
			end
		end
		return 0, nil, 0, false
	end
	env.GetChannelList = function()
		local out = {}
		for _, c in ipairs(p.channels) do
			out[#out + 1], out[#out + 2], out[#out + 3] = c.index, c.name, false
		end
		return unpack(out)
	end
	env.GetNumDisplayChannels = function() return #p.channels end
	env.ChatFrame_RemoveChannel = function(frame, cname)
		if not isWidget(frame) then error("ChatFrame_RemoveChannel(frame, channel): bad frame", 2) end
		client.removedChannels = client.removedChannels or {}
		client.removedChannels[#client.removedChannels + 1] = cname
	end
	env.ChatFrame_AddMessageEventFilter = function(event, fn)
		if type(event) ~= "string" or type(fn) ~= "function" then error("Usage: ChatFrame_AddMessageEventFilter(event, filter)", 2) end
		client.chatFilters[event] = client.chatFilters[event] or {}
		table.insert(client.chatFilters[event], fn)
	end
	env.ChatFrame_RemoveMessageEventFilter = function(event, fn)
		local list = client.chatFilters[event] or {}
		for i = #list, 1, -1 do if list[i] == fn then table.remove(list, i) end end
	end
	env.ChatFrameUtil = {
		OpenChat = function(text) client.chatBox = text end,
		RemoveChannel = env.ChatFrame_RemoveChannel,
		AddMessageEventFilter = env.ChatFrame_AddMessageEventFilter,
	}
	env.ChatFrame_OpenChat = function(text) client.chatBox = text end

	-- chat
	local function chatLine(text, kind, _, target)
		w:whisper(client, target or "?", tostring(text), w.hardware == client and "addon-hw" or "addon")
	end
	env.SendChatMessage = function(text, kind, lang, target)
		-- (PF-058 LINE: a whisper sent from a button's own click goes out) a hardware event (a click) is not restricted
		-- (Wuber's own lines keep Wuber's own rules below; only another addon's click, like the Lab's, is let through)
		-- the caller must be a file of another addon (lab/ or a fake addon dir of H.ADDONS), never Wuber/, tests/ or the harness
		local viaClick = false
		if w.hardware == client then
			local other = false
			for level = 2, 40 do
				local info = debug.getinfo(level, "S")
				if not info then break end
				local src = info.source or ""
				if src:find(H.ADDONS.Wuber, 1, true) then other = false break end
				if src:find(H.root .. "/lab/", 1, true) then other = true end
				for name, dir in pairs(H.ADDONS) do
					if name ~= "Wuber" and src:find(dir, 1, true) then other = true end
				end
			end
			viaClick = other
		end
		if w.restricted and not viaClick then
			-- the one exception: Wuber's auto-reply whisper, inside its limits (H.replyRule); how = "reply"
			local why = H.replyRule(w, client, kind, target)
			if not why then
				w.replies = w.replies or {}
				w.replies[p.name] = w.replies[p.name] or {}
				w.replies[p.name][key(target)] = w.time
				w:whisper(client, target, tostring(text), "reply")
				return
			end
			-- the second exception: a line Wuber sends by itself to the driver's own rider, inside its limits
			-- (H.linesRule); how = "auto". Outside them: a violation, and the call raises.
			local site = H.chatSite(1)
			if site:sub(-#H.LINES_SITE) == H.LINES_SITE then
				local whyNot = H.linesRule(w, client, kind, target, site, tostring(text))
				if not whyNot then
					w.autoLines = w.autoLines or {}
					w.autoLines[p.name] = w.autoLines[p.name] or {}
					local log = w.autoLines[p.name]
					log[#log + 1] = { to = w:player(target).name, text = tostring(text), at = w.time }
					w:whisper(client, target, tostring(text), "auto")
					return
				end
				w.blocked[#w.blocked + 1] = { from = p.name, text = text, to = target }
				w.violations[#w.violations + 1] = p.name .. ": a self-sent line broke its rule (" .. whyNot .. "): to " .. tostring(target) .. ": " .. tostring(text)
				error("SendChatMessage: a self-sent line broke its rule (" .. whyNot .. ")", 2)
			end
			w.blocked[#w.blocked + 1] = { from = p.name, text = text, to = target }
			w.violations[#w.violations + 1] = p.name .. ": an addon called SendChatMessage (" .. tostring(kind) .. "): " .. tostring(text) .. " [" .. why .. "]"
			client:fire("ADDON_ACTION_BLOCKED", client:callerAddon(), "SendChatMessage()")
			return
		end
		w:whisper(client, target or "?", tostring(text), viaClick and "click" or "addon")
	end
	env.C_ChatInfo = {
		RegisterAddonMessagePrefix = function(prefix)
			if type(prefix) ~= "string" or #prefix > 16 or prefix == "" then return H.REGISTER_RESULT.InvalidPrefix end
			if client.prefixes[prefix] then return H.REGISTER_RESULT.DuplicatePrefix end
			client.prefixes[prefix] = true
			return H.REGISTER_RESULT.Success
		end,
		IsAddonMessagePrefixRegistered = function(prefix) return client.prefixes[prefix] == true end,
		-- (FAKE-GAME-HINTS 19: Lego_ChannelTransport.lua:1051, 1712-1714; Hireling Comms.lua:346-387) swaps the slot numbers of two channels
		SwapChatChannelsByChannelIndex = function(a, b)
			local ca, cb = w:channelOf(p, a), w:channelOf(p, b)
			if not (ca and cb) then return end
			ca.index, cb.index = cb.index, ca.index
			table.sort(p.channels, function(x, y) return x.index < y.index end)
			client.chanSwaps = (client.chanSwaps or 0) + 1
			client:fire("CHANNEL_UI_UPDATE")
		end,
		GetRegisteredAddonMessagePrefixes = function() local out = {} for k in pairs(client.prefixes) do out[#out + 1] = k end return out end,
		SendAddonMessage = function(prefix, text, chatType, target) return w:sendAddon(client, prefix, text, chatType, target) end,
		SendAddonMessageLogged = function(prefix, text, chatType, target) return w:sendAddon(client, prefix, text, chatType, target) end,
		AreOutgoingAddonChatMessagesRestricted = function() return w.restricted end,
		InChatMessagingLockdown = function() return client.chatLock == true end, -- (off unless a test turns it on)
		SendChatMessage = env.SendChatMessage,
	}
	-- (only when the world switches it on, see NewWorld's whisperCheck) the answer comes as an event, from the fake player's real state:
	-- 0 online and the same faction, 2 offline, 3 the other faction (wrong = true: 2 for everybody). The GUID is "Player-1-" .. key(name).
	if w.whisperCheck then
		client.whisperAsked = {}
		env.C_ChatInfo.RequestCanLocalWhisperTarget = function(guid)
			if type(guid) ~= "string" then error("Usage: C_ChatInfo.RequestCanLocalWhisperTarget(guid)", 2) end
			client.whisperAsked[#client.whisperAsked + 1] = guid
			local wc = w.whisperCheck
			if wc.silent then return end
			local who = w:player((guid:match("^Player%-1%-(.+)$")))
			local status = 2
			if who and who.online and not wc.wrong then
				status = (who.faction or "Horde") == (p.faction or "Horde") and 0 or 3
			end
			w:after(wc.delay or 0.2, function()
				client:fire("CAN_LOCAL_WHISPER_TARGET_RESPONSE", guid, status)
			end, client, "whisper check")
		end
	end
	env.RegisterAddonMessagePrefix = env.C_ChatInfo.RegisterAddonMessagePrefix
	env.SendAddonMessage = env.C_ChatInfo.SendAddonMessage

	-- groups
	local function needClick(what)
		if w.hardware ~= client then
			w.violations[#w.violations + 1] = p.name .. ": " .. what .. " without a hardware click"
			-- (REC trade.forbidden.func) the game never names the function
			client:fire("ADDON_ACTION_FORBIDDEN", client:callerAddon(), "UNKNOWN()")
			return true
		end
		return false
	end
	env.C_PartyInfo = {
		InviteUnit = function(target) w:invite(client, target) end,
		LeaveParty = function() w:leave(p.name) end,
		ConvertToRaid = function() if p.group then p.group.raid = true end end,
		PromoteToLeader = env.PromoteToLeader, -- (Forever 1.60.1: C_PartyInfo.PromoteToLeader(name))
		PromoteToAssistant = env.PromoteToAssistant,
	}
	env.InviteUnit = env.C_PartyInfo.InviteUnit
	H.fakeLfg.api(env, client, p, w, needClick) -- the Group Finder (tests/lib/fake_lfglist.lua)

	-- communities (only when the world has them)
	if w.clubsOn and not opts.noClub then
		local function member(c) return c and c.members[key(p.name)] end
		env.C_Club = {
			GetSubscribedClubs = function()
				local out = {}
				for _, c in ipairs(w.clubs or {}) do
					if member(c) then out[#out + 1] = w:clubInfo(c) end
				end
				return out
			end,
			GetClubInfo = function(id)
				local c = w:club(id)
				return c and member(c) and w:clubInfo(c) or nil
			end,
			GetStreams = function(id)
				local c = w:club(id)
				if not member(c) then return {} end
				local out = {}
				for _, st in ipairs(c.streams) do
					out[#out + 1] = { streamId = st.streamId, name = st.name, streamType = st.streamType,
						leadersAndModeratorsOnly = st.leadersAndModeratorsOnly == true, subject = "" }
				end
				return out
			end,
			-- the roster (SPEC5 community: Wuber reads it for whisper seeds): memberIds, and each
			-- member's name, role, presence (Enum.ClubMemberPresence) and classID. w.clubRosterRealm
			-- spells names "Name-Realm" as on another node.
			GetClubMembers = function(id)
				local c = w:club(id)
				if not member(c) then return {} end
				local out = {}
				for k in pairs(c.members) do out[#out + 1] = k end
				table.sort(out)
				c.memberIds = out
				local ids = {}
				for i = 1, #out do ids[i] = i end
				return ids
			end,
			GetMemberInfo = function(id, memberId)
				local c = w:club(id)
				if not member(c) or not c.memberIds then return nil end
				local k = c.memberIds[memberId]
				local who = k and w.players[k]
				if not k then return nil end
				local CLASS_IDS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
				local name = who and who.name or k
				if who and w.clubRosterRealm then name = name .. "-" .. w.clubRosterRealm end
				return { memberId = memberId, name = name, role = c.members[k], isSelf = who == p,
					presence = (who and who.online) and 1 or 3, classID = who and CLASS_IDS[who.class or ""] or nil }
			end,
			GetMemberInfoForSelf = function(id)
				local c = w:club(id)
				local role = member(c)
				if not role then return nil end
				return { isSelf = true, name = p.name, role = role, memberId = 1 }
			end,
			AddClubStreamChatChannel = function(id, streamId)
				local c = w:club(id)
				client.clubChannelAdds = (client.clubChannelAdds or 0) + 1
				if not member(c) then error("C_Club.AddClubStreamChatChannel: not a member", 2) end
				if w.noClubChannels then return end -- this client gives community streams no channel number
				w:joinChannel(client, "Community:" .. tostring(id) .. ":" .. tostring(streamId))
			end,
			GetInvitationsForSelf = function()
				local out = {}
				for _, c in ipairs(w.clubs or {}) do
					local inv = c.invites[key(p.name)]
					if inv and not member(c) then
						out[#out + 1] = { invitationId = #out + 1, club = w:clubInfo(c), inviter = { name = inv.inviter }, leaders = {} }
					end
				end
				return out
			end,
			AcceptInvitation = function(id)
				client.acceptInvitationCalls = (client.acceptInvitationCalls or 0) + 1
				if needClick("C_Club.AcceptInvitation()") then return end
				if w.acceptInvitationFails then error("C_Club.AcceptInvitation: failed", 2) end
				local c = w:club(id)
				if not c or not c.invites[key(p.name)] then return end
				w:after(w.latency, function()
					c.invites[key(p.name)] = nil
					c.members[key(p.name)] = 4
					client:fire("CLUB_INVITATION_REMOVED_FOR_SELF", 1)
					client:fire("CLUB_ADDED", id)
				end, client, "club accept")
			end,
			-- SendCharacterInvitation: forbidden in this client (tools/forbidden.lua; H.forbid replaces it)
			SendCharacterInvitation = function() end,
		}
		env.Chat_GetCommunitiesChannelName = function(id, streamId) return "Community:" .. tostring(id) .. ":" .. tostring(streamId) end
		env.Enum.ClubStreamType = { General = 0, Guild = 1, Officer = 2, Other = 3 }
		env.Enum.ClubRoleIdentifier = { Owner = 1, Leader = 2, Moderator = 3, Member = 4 }
		env.Enum.ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 }
	end
	env.LeaveParty = env.C_PartyInfo.LeaveParty
	env.UninviteUnit = function(n) w:uninvite(client, n) end
	-- accepting goes to the server and back: a decline sent meanwhile wins
	env.AcceptGroup = function()
		if w.acceptGroupNeedsClick and needClick("AcceptGroup()") then return end
		local inviter = p.pendingInvite
		if not inviter or p.group then return end
		p.pendingInvite = nil
		p.joining = inviter
		client.acceptedGroup = (client.acceptedGroup or 0) + 1
		w:after(w.latency, function()
			if p.joining ~= inviter then return end
			p.joining = nil
			if not p.group then w:join(inviter, p) end
		end, client, "accept group")
	end
	env.DeclineGroup = function()
		local inviter = p.pendingInvite or p.joining
		p.pendingInvite, p.joining = nil, nil
		if inviter then
			client.declinedGroup = (client.declinedGroup or 0) + 1
			if inviter.client then
				w:after(0.2, function() inviter.client:fire("CHAT_MSG_SYSTEM", ("%s declines your group invitation."):format(p.name)) end, inviter.client, "decline")
			end
		end
	end
	env.StaticPopup_FindVisible = function(which) return client.popups[which] end
	env.StaticPopup_Visible = function(which) if client.popups[which] then return "StaticPopup1", client.popups[which] end end
	env.StaticPopup_Hide = function(which)
		local d = client.popups[which]
		if not d then return end
		client.popups[which] = nil
		client.hiddenPopups = (client.hiddenPopups or 0) + 1
		if which == "PARTY_INVITE" and not d.inviteAccepted then
			-- Blizzard's popup (OnHide) declines the invite when hidden without inviteAccepted
			w.violations[#w.violations + 1] = p.name .. ": the PARTY_INVITE popup was hidden without inviteAccepted (its OnHide calls DeclineGroup)"
			env.DeclineGroup()
		end
	end
	env.StaticPopup_Show = function(which) client.popups[which] = { which = which } return client.popups[which] end

	-- summons
	env.C_SummonInfo = {
		ConfirmSummon = function()
			-- measured 32 of 32 from code with no click, and from a timer: allowed by default; a world can ask for the strict rule
			if w.confirmSummonNeedsClick and needClick("C_SummonInfo.ConfirmSummon()") then return end
			local s = p.pendingSummon
			if not s then return end
			client.confirmedSummons = (client.confirmedSummons or 0) + 1
			p.summonAnswer = { status = 2, at = w.time } -- (hint 40) the game says "accepted" from the click
			w:confirmSummon(p, s)
		end,
		CancelSummon = function()
			if p.pendingSummon then p.summonAnswer = { status = 3, at = w.time } end -- (hint 40) "declined"
			p.pendingSummon = nil
			client.popups.CONFIRM_SUMMON = nil
		end,
		GetSummonConfirmSummoner = function()
			local s = p.pendingSummon
			if s and s.nameLate and w.time - s.at < s.nameLate then H.rule("unit.unknown-after-load") return s.lateWord or "" end -- (lateWord: what the game says meanwhile, e.g. "Unknown")
			return s and sec("sender", s.shownBy or s.by.name) or nil
		end,
		GetSummonConfirmAreaName = function() local s = p.pendingSummon return s and sec("zone", s.sub ~= "" and s.sub or s.zone) or nil end,
		GetSummonConfirmTimeLeft = function() local s = p.pendingSummon return s and math.max(0, 120 - (w.time - s.at)) or 0 end,
		GetSummonReason = function() return 0 end,
		IsSummonSkippingStartExperience = function() return false end,
	}
	if w.incomingSummon then env.C_IncomingSummon = H.incomingSummonApi(w, client) end -- (hint 40; off by default)
	env.ConfirmSummon = env.C_SummonInfo.ConfirmSummon
	env.CancelSummon = env.C_SummonInfo.CancelSummon
	env.GetSummonConfirmSummoner = env.C_SummonInfo.GetSummonConfirmSummoner
	env.GetSummonConfirmAreaName = env.C_SummonInfo.GetSummonConfirmAreaName

	-- money and trade
	env.GetMoney = function() if client.secrets.GetMoney then return SECRET end return p.money end
	env.GetTargetTradeMoney = function() local t = p.trade return t and t.money[other(t, p).name] or 0 end
	env.GetPlayerTradeMoney = function() local t = p.trade return t and t.money[p.name] or 0 end
	-- WoW Forever forbids addons from putting gold in a trade (SPEC2 "In-game findings"): the
	-- old global is gone and C_TradeInfo.SetTradeMoney is for the Blizzard UI only.
	env.C_TradeInfo = {
		SetTradeMoney = function()
			w.violations[#w.violations + 1] = p.name .. ": C_TradeInfo.SetTradeMoney (only available to the Blizzard UI)"
			client:fire("ADDON_ACTION_FORBIDDEN", client:callerAddon(), "UNKNOWN()") -- (REC trade.forbidden.func, 7 of 7)
		end,
	}
	env.GetTradePlayerItemInfo = function() return nil end
	env.GetTradeTargetItemInfo = function() return nil end
	env.InitiateTrade = function(unit)
		local u = client:unit(unit)
		w.tradeOpens = (w.tradeOpens or 0) + 1
		if u then w:openTrade(p, u) end
	end
	env.AcceptTrade = function()
		if needClick("AcceptTrade()") then return end
		w:tradeAccept(p)
	end
	env.CancelTrade = function() w:tradeCancel(p) end
	local tradeButton = child("Button", "TradeFrameTradeButton")
	tradeButton:SetScript("OnClick", function() env.AcceptTrade() end)
	env.TradeFrame = child("Frame", "TradeFrame")
	S[env.TradeFrame].shown = false

	-- maps
	local function mapInfo(id)
		local m = H.MAPS[id]
		if not m then return end
		if client.secrets.C_Map then return { mapID = SECRET, name = SECRET, mapType = SECRET, parentMapID = SECRET, flags = 0 } end
		return { mapID = id, name = m[1], mapType = m[2], parentMapID = m[3] or 0, flags = 0 }
	end
	env.C_Map = {
		GetBestMapForUnit = function(unit)
			local u = client:unit(unit)
			if not u or u.inInstance or client:mapBlank() then return nil end
			if client.secrets.C_Map then return SECRET end
			return u.mapID
		end,
		GetPlayerMapPosition = function(mapID, unit)
			local u = client:unit(unit)
			if type(mapID) ~= "number" then error("Usage: C_Map.GetPlayerMapPosition(uiMapID, unitToken)", 2) end
			if not u or u.inInstance or client:mapBlank() then return nil end
			if client.secrets.C_Map then return vector(SECRET, SECRET) end
			if mapID == u.mapID then return vector(u.x, u.y) end
			local cont, wx, wy = H.toWorld(u.mapID, u.x, u.y)
			if not cont then return nil end
			local x, y = H.fromWorld(cont, wx, wy, mapID)
			if not x then return nil end
			return vector(x, y)
		end,
		GetMapInfo = function(id)
			if type(id) ~= "number" then error("Usage: C_Map.GetMapInfo(uiMapID)", 2) end
			return mapInfo(id)
		end,
		GetMapChildrenInfo = function(id)
			if not H.MAPS[id] then return end -- unknown map: no values (A1)
			local out = {}
			for cid, m in pairs(H.MAPS) do if m[3] == id then out[#out + 1] = mapInfo(cid) end end
			return out
		end,
		GetMapInfoAtPosition = function(id, x, y)
			if type(id) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
				error("Usage: C_Map.GetMapInfoAtPosition(uiMapID, x, y)", 2)
			end
			local best, bestArea
			for cid, m in pairs(H.MAPS) do
				if m[3] == id then
					local l, r, t, b = env.C_Map.GetMapRectOnMap(cid, id)
					if l and x >= l and x <= r and y >= t and y <= b then
						local area = (r - l) * (b - t)
						if not bestArea or area < bestArea then best, bestArea = cid, area end
					end
				end
			end
			if best then return mapInfo(best) end
		end,
		GetMapArtLayers = function(id)
			if not H.MAPS[id] then return end
			return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256, minScale = 1, maxScale = 1, additionalZoomSteps = 0 } }
		end,
		GetMapArtLayerTextures = function(id, layer)
			if not H.MAPS[id] or layer ~= 1 then return end
			local out = {}
			for i = 1, 12 do out[i] = id * 100 + i end
			return out
		end,
		GetMapArtID = function(id) return H.MAPS[id] and id or nil end,
		GetWorldPosFromMapPos = function(id, pos)
			if type(id) ~= "number" or type(pos) ~= "table" or type(pos.x) ~= "number" then
				error("Usage: C_Map.GetWorldPosFromMapPos(uiMapID, mapPosition)", 2)
			end
			local cont, wx, wy = H.toWorld(id, pos.x, pos.y)
			if not cont then return end
			return cont, vector(wx, wy)
		end,
		GetMapPosFromWorldPos = function(cont, pos, override)
			if type(cont) ~= "number" or type(pos) ~= "table" or type(pos.x) ~= "number" then
				error("Usage: C_Map.GetMapPosFromWorldPos(continentID, worldPosition [, overrideUiMapID])", 2)
			end
			local id = override or H.mapAt(cont, pos.x, pos.y)
			if not id then return end
			local x, y = H.fromWorld(cont, pos.x, pos.y, id)
			if not x then return end
			return id, vector(x, y)
		end,
		GetMapRectOnMap = function(id, top)
			local m, t = H.MAPS[id], H.MAPS[top]
			if not m or not t or not m[4] or not t[4] or H.continentOf(id) ~= H.continentOf(top) then return nil end
			local a, b = m[4], t[4]
			return (a[1] - b[1]) / b[3], (a[1] + a[3] - b[1]) / b[3], (a[2] - b[2]) / b[4], (a[2] + a[4] - b[2]) / b[4]
		end,
		GetMapGroupID = function() return nil end,
		GetFallbackWorldMapID = function() return 947 end,
	}
	-- the game's safe opener (C side; refused in combat). The Lua openers below taint the map when addon code calls
	-- them: tests/lib/maptaint.lua, rule c
	env.C_Map.OpenWorldMap = function(id)
		H.mapTaint.safeOpen(client, function()
			if id ~= nil then wm:SetMapID(id) end
			wm:Show()
		end)
	end
	env.OpenWorldMap = function(id) H.mapTaint.opener(client, "OpenWorldMap()") if id then wm:SetMapID(id) end wm:Show() end
	env.ToggleWorldMap = function()
		H.mapTaint.opener(client, "ToggleWorldMap()")
		if wm:IsShown() then wm:Hide() else wm:Show() end
	end
	env.ShowUIPanel = function(f)
		if f == wm then H.mapTaint.opener(client, "ShowUIPanel(WorldMapFrame)") end
		if isWidget(f) then f:Show() end
	end
	env.HideUIPanel = function(f) if isWidget(f) then f:Hide() end end
	env.CloseSpecialWindows = function() return client:pressEscape() end

	-- nameplates (see Client:showPlate)
	env.C_NamePlate = {
		GetNamePlateForUnit = function(unit, isSecure)
			if type(unit) ~= "string" then error("Usage: C_NamePlate.GetNamePlateForUnit(unit [, isSecure])", 2) end
			local n = unit:lower():match("^nameplate(%d+)$")
			local pl = n and client.plates[tonumber(n)]
			if not pl then
				-- a player's own token (target, mouseover...) finds that player's plate too
				local u = client:unit(unit)
				for _, x in pairs(client.plates) do if u and x.player == u then pl = x end end
			end
			return pl and pl.frame or nil
		end,
		GetNamePlates = function(isSecure)
			local out = {}
			for i = 1, 40 do
				local pl = client.plates[i]
				if pl and not pl.forbidden then out[#out + 1] = pl.frame end
			end
			return out
		end,
	}
	if w.tooltipStyle == "processor" then
		env.TooltipDataProcessor = {
			AllTypes = "ALL",
			AddTooltipPostCall = function(kind, fn)
				if type(fn) ~= "function" then error("Usage: TooltipDataProcessor.AddTooltipPostCall(dataType, func)", 2) end
				client.tipPostCalls[kind] = client.tipPostCalls[kind] or {}
				table.insert(client.tipPostCalls[kind], fn)
			end,
		}
		env.TooltipUtil = { GetDisplayedUnit = function(tt) local n, u = tt:GetUnit() return n, u end }
		env.Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4 }
	end

	-- OpenMap (optional)
	if opts.openMap then
		client.openMap = { stitched = opts.openMap.stitched ~= false, callbacks = {}, toggles = {}, shown = {} }
		local om = client.openMap
		env.OpenMapAPI = {
			major = 1, version = 4,
			IsStitched = function() return om.stitched end,
			WorldFromMap = function(id, x, y)
				if type(id) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return end
				local cont, wx, wy = H.toWorld(id, x, y)
				if not cont then return end
				return H.stitchedFromWorld(cont, wx, wy)
			end,
			MapFromWorld = function(id, u, v)
				if type(id) ~= "number" or type(u) ~= "number" or type(v) ~= "number" then return end
				if id == 947 then return u, v end
				local cont, wx, wy = H.worldFromStitched(u, v)
				return H.fromWorld(cont, wx, wy, id)
			end,
			ArtTopLevel = function() return om.artTop or 500 end,
			ShowWorld = function(u, v, zoom)
				if not om.stitched or type(u) ~= "number" or type(v) ~= "number" then return false end
				om.shown[#om.shown + 1] = { u = u, v = v, zoom = zoom }
				return true
			end,
			GetView = function() if om.stitched then return 0.5, 0.5, 1 end end,
			RegisterCallback = function(owner, event, method)
				if type(event) ~= "string" then error("Usage: RegisterCallback(owner, event, method)", 2) end
				if type(method) ~= "function" and type(method) ~= "string" then
					if method == nil and type(owner) == "table" and type(owner[event]) == "function" then method = event
					else error("RegisterCallback(): method must be a function or a method name", 2) end
				end
				om.callbacks[#om.callbacks + 1] = { owner = owner, event = event, method = method }
			end,
			UnregisterCallback = function(owner, event)
				for i = #om.callbacks, 1, -1 do
					local cb = om.callbacks[i]
					if cb.owner == owner and cb.event == event then table.remove(om.callbacks, i) end
				end
			end,
			RegisterMenuToggle = function(owner, spec)
				if type(owner) ~= "string" or type(spec) ~= "table" or type(spec.id) ~= "string" or type(spec.label) ~= "string"
					or type(spec.get) ~= "function" or type(spec.set) ~= "function" then
					error("OpenMapAPI.RegisterMenuToggle(owner, { id, label, get, set [, icon, tab, section] })", 2)
				end
				om.toggles[owner .. "." .. spec.id] = spec
			end,
			RegisterDungeonSection = function() end,
			MapAt = function(u, v) local cont, wx, wy = H.worldFromStitched(u, v) return H.mapAt(cont, wx, wy) end,
			CursorPosition = function() return nil end,
		}
	end

	-- round 8's fakes (tests/lib/fakes8.lua): bit, the combat log, UnitIsEnemy, GetZonePVPInfo (zonePvpInfo worlds only),
	-- TaxiNodePosition, TakeTaxiNode, UnitOnTaxi... (nothing the addon of 2.2.x reads)
	H.fakes8.api(api, client, p, w, sec)
	-- the mailbox (tests/lib/mail.lua): the two inbox readers; a test fills it with w:mail / w:openMailbox
	H.fakeMail.api(api, client)

	-- what this client forbids to addons (tools/forbidden.lua): calling one raises (H.forbid)
	for _, f in ipairs(H.FORBIDDEN or {}) do
		-- (#234) fake == false: the name is banned in the sources (check.lua) but the fake keeps its own answer (ReloadUI: blocked and recorded)
		local path = f.kind == "api" and f.fake ~= false and f.path
		local holder = path and api or nil
		for i = 1, path and #path - 1 or 0 do
			local nxt = type(holder) == "table" and rawget(holder, path[i]) or nil
			-- (#234) a namespace the fake has no other use for (C_PingSecure, C_CombatLogSecure) is made, so a call raises
			if nxt == nil and type(holder) == "table" and f.make ~= false and i == 1 then
				nxt = {}
				holder[path[i]] = nxt
			end
			holder = nxt
		end
		if type(holder) == "table" then
			local what = table.concat(path, ".") .. "()"
			holder[path[#path]] = function() H.forbid(client, what) end
		end
	end

	-- (#233) what the client answers with a secret value (tests/fixtures/secret-api.lua): the function returns
	-- one when the test said so (client:secret("UnitIsGroupLeader"), a whole namespace client:secret("C_Spell"),
	-- or client:secret("*") for every one); else it answers as before
	do
		local list = H.SECRET_API or { globals = {}, namespaced = {} }
		local function wrap(holder, key, name, nsName)
			local orig = rawget(holder, key)
			if type(orig) ~= "function" then return end
			holder[key] = function(...)
				local sec = client.secrets
				if sec["*"] or sec[name] or (nsName and sec[nsName]) then return SECRET end
				return orig(...)
			end
		end
		for _, n in ipairs(list.globals) do wrap(api, n, n) end
		for _, full in ipairs(list.namespaced) do
			local ns, fn = full:match("^(.-)%.(.+)$")
			if ns and type(rawget(api, ns)) == "table" then wrap(api[ns], fn, full, ns) end
		end
	end

	-- namespaces (C_Map...): reads are noted, like globals
	for k, v in pairs(api) do
		if type(k) == "string" and (k:match("^C_") or k == "OpenMapAPI" or k == "ChatFrameUtil" or k == "Enum") and type(v) == "table" then
			local inner = v
			api[k] = setmetatable({}, {
				__index = function(_, f)
					local x = inner[f]
					if type(f) == "string" then
						if x ~= nil then H.noteUse("api", k .. "." .. f, nil, 2)
						else local who = H.caller(2) if who then H.missingGlobals[k .. "." .. f] = who end end
					end
					return x
				end,
				__newindex = function(_, f, x) inner[f] = x end,
			})
		end
	end

	-- The addons' global table: reads come from the API (noted), writes are new globals
	-- (noted with the file and line that made them).
	client.globalWrites = {}
	-- (BRIEF21 S3, speed) Reads of the base library (pairs, type, string...) are most of the suite's global
	-- reads and are never noted: they are answered by a plain table (no Lua call per read), unless the API
	-- has its own (table, rawget). Everything else goes to the function, which notes API reads and misses.
	local slow = function(_, k)
		local v = api[k]
		if v ~= nil then
			if H.used.api[k] == nil and type(k) == "string" then H.noteUse("api", k, nil, 2) end
			return v
		end
		v = BASE[k]
		if v == nil and type(k) == "string" then
			local who = H.caller(2)
			if who then
				client.missing[k] = who
				H.missingGlobals[k] = who
			end
		end
		return v
	end
	local fast = setmetatable({}, { __index = slow }) -- filled below, once the API is complete
	env = setmetatable({}, {
		__index = fast,
		__newindex = function(t, k, v)
			local who = H.caller(2) or "harness"
			if client.globalWrites[k] == nil then client.globalWrites[k] = who end
			rawset(t, k, v)
			-- every W.Fire(name, ...) is recorded in client.fired, from the first one at login on
			if k == "Wuber" and type(v) == "table" and getmetatable(v) == nil then
				setmetatable(v, { __newindex = function(W, kk, vv)
					if kk == "Fire" and type(vv) == "function" then
						local fire = vv
						vv = function(name, ...)
							client.fired[#client.fired + 1] = { name = name, at = w.time, args = { ... } }
							return fire(name, ...)
						end
					end
					rawset(W, kk, vv)
				end })
			end
		end,
	})
	rawset(env, "_G", env)
	-- In the game the API lives in _G itself, so rawget(_G, "AcceptGroup") finds it; here it
	-- sits behind env's __index, so rawget on the global table looks there too.
	api.rawget = function(t, k)
		local v = rawget(t, k)
		if v == nil and t == env then v = api[k] end
		return v
	end
	for k, v in pairs(BASE) do if api[k] == nil then fast[k] = v end end
	client.env = env
	-- frames named before this point (UIParent, ChatFrame1...) are the game's
	for k, v in pairs(api) do if isWidget(v) then api[k] = v end end
	client.before = {}
	for k in pairs(api) do client.before[k] = true end
	-- lockEngine: a stand-in for Ritual Rides 1.4.1's global, so Wuber 2.0's engine stays locked
	-- off (SPEC3 3.3) and Net's own driver mode can be tested on its own
	if opts.lockEngine then rawset(env, "RitualRides", { VERSION = "1.4.1" }) client.lockEngine = true end
	H.fakeOptionsList(env, client, "new") -- this build has the Settings API only; a test's prepare may change it ("old", "none")
	if opts.prepare then opts.prepare(env, client) end
	if H.surface then H.surface:install(client) end -- (surface guard hook 2/3)
	if H.taint then H.taint.snap(client) end -- (tests/fakegame/taint-allow.lua) what the game owns, before any addon loads

	-- load the addons as the client does: every file of each TOC, called with (name, namespace)
	client.ns = {}
	client.addons = H.loadOrder(client.addons, client.addonDirs)
	for _, addon in ipairs(client.addons) do
		local files, dir = H.tocFiles(addon, client.addonDirs and client.addonDirs[addon])
		if not files then error("no TOC for " .. addon) end
		local ns = {}
		client.ns[addon] = ns
		local savedName = addon == "Wuber" and "WuberDB" or (addon .. "DB")
		if client.saved[addon] ~= nil then rawset(env, savedName, client.saved[addon]) end
		-- (2.4, Simple and Advanced) Wuber starts every player in Simple. The tests written before that
		-- are about everything Wuber can show, so a window starts in Advanced unless the test asks for
		-- the game's real start with opts.simple = true (or brings its own saved `advanced`).
		if addon == "Wuber" and not opts.simple then
			local db = rawget(env, savedName)
			if db == nil then db = {} rawset(env, savedName, db) end
			if type(db) == "table" and db.advanced == nil then db.advanced = true end
		end
		for _, file in ipairs(files) do
			local path = dir .. "/" .. file:gsub("\\", "/")
			if file:match("%.lua$") then
				if exists(path) then
					local chunk, err
					if client.rewrite then -- a test's changed source (tests/harness_draw.lua): never cached
						local fh = assert(io.open(path, "rb"))
						local text = fh:read("*a")
						fh:close()
						chunk, err = loadstring(client.rewrite(addon, file, text) or text, "@" .. path)
					else
						chunk, err = H.compiled(path)
					end
					if not chunk then error("parse error: " .. tostring(err)) end
					setfenv(chunk, env)
					local ok, lerr = xpcall(function() chunk(addon, ns) end, traceback)
					if not ok then
						w.errors[#w.errors + 1] = name .. " loading " .. addon .. "/" .. file .. ": " .. tostring(lerr)
					end
				elseif not opts.allowMissing then
					error("TOC lists a file that does not exist: " .. path)
				else
					client.skipped = client.skipped or {}
					client.skipped[#client.skipped + 1] = addon .. "/" .. file
				end
			elseif file:match("%.xml$") then
				error("the harness can't load XML: " .. path)
			end
		end
	end
	-- The game loads Bindings.xml from an addon's folder by itself (the TOC does not list it; a listed copy registers
	-- twice). Reads <Binding name header category>body</Binding> into client.gameBindings; nothing is bound until a test
	-- calls Client:setGameKey, so a world without Bindings.xml, or a test that never binds, sees no difference.
	client.gameBindings, client.gameKeys = {}, {}
	for _, addon in ipairs(client.addons) do
		local dir = client.addonDirs and client.addonDirs[addon] or H.ADDONS[addon]
		local fh = dir and io.open(dir .. "/Bindings.xml", "rb")
		if fh then
			local xml = fh:read("*a"):gsub("<!%-%-.-%-%->", "")
			fh:close()
			local pos = 1
			while true do
				local s, e, attrs, selfClose = xml:find("<Binding%s+([^>]-)(/?)>", pos)
				if not s then break end
				local b = { addon = addon, body = "" }
				for k, v in attrs:gmatch('([%w_]+)%s*=%s*"([^"]*)"') do b[k] = v end
				pos = e + 1
				if selfClose ~= "/" then
					local bs, be = xml:find("</Binding>", pos, true)
					if bs then b.body = xml:sub(pos, bs - 1) pos = be + 1 end
				end
				client.gameBindings[#client.gameBindings + 1] = b
			end
		end
	end
	client.W = client.ns.Wuber
	client.RR = client.ns.RitualRides
	-- (BRIEF15) opts.version: this window runs another Wuber version from login on (W.VERSION is read at
	-- run time; a test that needs it before PLAYER_LOGIN, e.g. the update notice's saved field, sets it here)
	if opts.version and client.W then client.W.VERSION = opts.version end
	-- Round 8: old tests run FOLDED ("idle = folded", SPEC7 8.2), so their transcripts keep 2.2.3's behaviour. The harness
	-- screen (1920 x 1080) has room to unfold, so UI.Fold.Fits answers "small" unless the test opts in: opts.wide at
	-- creation, client.wide = true at run time, or the player's own fold choices (W.db.fold, made by the fold controls).
	-- Nothing is saved and no frame changes; only the room check is wrapped (through the table, as Fold calls it).
	client.wide = opts.wide == true
	local fold = client.W and client.W.UI and client.W.UI.Fold
	if fold and type(fold.Fits) == "function" then
		local realFits = fold.Fits
		fold.Fits = function(...)
			local db = client.W.db
			if client.wide or (type(db) == "table" and db.fold ~= nil) then return realFits(...) end
			return false, "small"
		end
	end
	for _, addon in ipairs(client.addons) do client:fire("ADDON_LOADED", addon, false) end
	client:fire("VARIABLES_LOADED")
	client:fire("PLAYER_LOGIN")
	if opts.reload then
		-- (REC login.pew.reload, 26 of 26) a /reload: PLAYER_ENTERING_WORLD(false, true) and no zone event
		client:fire("PLAYER_ENTERING_WORLD", false, true)
	elseif arrive == "real" then
		client:fire("PLAYER_ENTERING_WORLD", true, false)
		-- (REC login.channels.fresh, login.pew.fresh) about 3 s later, in one frame: the game's channels
		-- (CHANNEL_UI_UPDATE), then ZONE_CHANGED_NEW_AREA (32 of 34 logins in that order)
		self:after(self.loginDelay, function()
			local used = {}
			for _, c in ipairs(p.channels) do used[c.index] = true end
			for _, c in ipairs(gameChannels) do
				if not used[c.index] then p.channels[#p.channels + 1] = { index = c.index, name = c.name } end
			end
			table.sort(p.channels, function(a, b) return a.index < b.index end)
			if #gameChannels > 0 then client:fire("CHANNEL_UI_UPDATE") end
			client:fire("ZONE_CHANGED_NEW_AREA")
		end, client, "login: the game's channels and the zone")
	else
		client:fire("PLAYER_ENTERING_WORLD", true, false)
		client:fire("ZONE_CHANGED_NEW_AREA")
	end
	return client
end

---------------------------------------------------------------------------
-- Nameplates and the mouse-over tooltip
---------------------------------------------------------------------------
-- A plate is a game frame (never the addon's): its geometry must not be read, a forbidden one
-- (in an instance) must not be touched at all. Plates and their unit tokens are reused, as in
-- the game. Friendly players' plates show only with nameplateShowFriends (or ...FriendlyPlayers) on.

local function friendlyShown(client)
	return client.cvars.nameplateShowFriends == "1" or client.cvars.nameplateShowFriendlyPlayers == "1"
end

function Client:plateIndexOf(name)
	local p = self.world:player(name)
	for i, pl in pairs(self.plates) do if pl.player == p then return i end end
	return nil
end

-- A player's plate comes into view. opts: forbidden, secretName, index (reuse that token without
-- a REMOVED first: a missed event), force (ignore the friendly CVar). Returns the unit token or nil.
function Client:showPlate(name, opts)
	opts = opts or {}
	local p = self.world:player(name)
	assert(p, "showPlate: no such player " .. tostring(name))
	if p == self.player then return nil end
	local friendly = (p.faction or "Horde") == (self.player.faction or "Horde")
	if friendly and not friendlyShown(self) and not opts.force then
		self.wantPlates[name] = opts
		return nil
	end
	self.wantPlates[name] = nil
	if self:plateIndexOf(name) and not opts.index then return "nameplate" .. self:plateIndexOf(name) end
	local index = opts.index
	if not index then
		index = 1
		while self.plates[index] do index = index + 1 end
	end
	self.plateFrames = self.plateFrames or {}
	local f = self.plateFrames[index]
	if not f then
		f = H.createFrame(self, "Frame", nil, self.env.UIParent)
		local s = S[f]
		f:SetSize(110, 45)
		f:SetPoint("CENTER", self.env.UIParent, "CENTER", -600 + index * 120, 200)
		s.plate = true
		self.plateFrames[index] = f
		self:fire(opts.forbidden and "FORBIDDEN_NAME_PLATE_CREATED" or "NAME_PLATE_CREATED", f)
	end
	S[f].forbidden = opts.forbidden and true or nil
	S[f].shown = true
	self.plates[index] = { player = p, frame = f, forbidden = opts.forbidden, secretName = opts.secretName, index = index }
	-- as Moo found: the game fires NAME_PLATE_UNIT_ADDED for every plate; a forbidden one says so through IsForbidden
	self:fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. index)
	if opts.forbidden then self:fire("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate" .. index) end
	return "nameplate" .. index
end

-- The plate goes out of view: NAME_PLATE_UNIT_REMOVED, then the game hides it for reuse.
function Client:hidePlate(name)
	self.wantPlates[name] = nil
	local index = self:plateIndexOf(name)
	if not index then return end
	local pl = self.plates[index]
	self:fire("NAME_PLATE_UNIT_REMOVED", "nameplate" .. index)
	if pl.forbidden then self:fire("FORBIDDEN_NAME_PLATE_UNIT_REMOVED", "nameplate" .. index) end
	self.plates[index] = nil
	S[pl.frame].shown = false
end

function Client:secretPlateUnit(unit)
	if type(unit) ~= "string" then return false end
	local n = unit:lower():match("^nameplate(%d+)$")
	local pl = n and self.plates[tonumber(n)]
	return pl and pl.secretName or false
end

-- friendly plates waiting for the CVar appear when it is turned on (and go when it is off)
function Client:refreshPlates()
	if friendlyShown(self) then
		for name, o in pairs(self.wantPlates) do self:showPlate(name, o) end
	else
		for i, pl in pairs(self.plates) do
			if (pl.player.faction or "Horde") == (self.player.faction or "Horde") then
				local name = pl.player.name
				self:hidePlate(name)
				self.wantPlates[name] = {}
			end
		end
	end
end

-- every visible frame of the addons attached to a plate (anchored to it or parented to it)
function Client:onPlate(name)
	local index = self:plateIndexOf(name)
	local pl = index and self.plates[index]
	if not pl then return {} end
	local out = {}
	for _, f in ipairs(self.frames) do
		local s = S[f]
		if f ~= pl.frame and not s.plate and visible(f) then
			local on = s.parent == pl.frame
			for _, pt in ipairs(s.points) do if pt.rel == pl.frame then on = true end end
			if on then out[#out + 1] = f end
		end
	end
	return out
end

-- every visible addon frame on any plate
function Client:plateFramesShown()
	local out = {}
	for _, f in ipairs(self.frames) do
		local s = S[f]
		if not s.plate and visible(f) then
			local on = s.parent and S[s.parent].plate
			for _, pt in ipairs(s.points) do if pt.rel and S[pt.rel].plate then on = true end end
			if on then out[#out + 1] = f end
		end
	end
	return out
end

-- The mouse goes over a player in the world: the game's tooltip shows the unit. Returns the lines.
function Client:hover(name)
	local p = self.world:player(name)
	self.mouseoverPlayer = p
	self:fire("UPDATE_MOUSEOVER_UNIT")
	local tt = self.env.GameTooltip
	tt:SetOwner(self.env.UIParent, "ANCHOR_CURSOR")
	tt:SetUnit("mouseover")
	local out = {}
	for i, l in ipairs(S[tt].tipLines or {}) do out[i] = l end
	return out
end

-- the window closes: it hears nothing more; the player stays (offline unless told)
function World:closeClient(client, offline)
	client.alive = false
	for i, c in ipairs(self.clients) do
		if c == client then table.remove(self.clients, i) break end
	end
	for _, ch in pairs(self.channels) do ch.members[client] = nil end
	if offline ~= false then client.player.online = false end
end

-- A /reload: the same character, fresh addons, saved variables kept.
function World:reload(client)
	local p = client.player
	if client.alive then client:fire("PLAYER_LOGOUT") end
	local saved = {}
	for _, addon in ipairs(client.allAddons or client.addons) do
		local sv = addon == "Wuber" and "WuberDB" or (addon .. "DB")
		local v = rawget(client.env, sv)
		if v == nil then v = client.saved[addon] end -- an addon switched off keeps its saved data on disk
		saved[addon] = v
	end
	self:closeClient(client, false)
	p.online = true
	self.reloads = (self.reloads or 0) + 1
	-- (REC login.pew.reload, login.channels.reload) a reload, not a login: channels and internal realm kept
	return self:addClient(p.name, { saved = saved, addons = client.allAddons or client.addons, class = p.class,
		reload = true, keepChannels = true, realm = client.realm,
		addonDirs = client.addonDirs, loadRR = client.loadRR, lockEngine = client.lockEngine, roundOne = client.roundOne,
		mooLoaded = client.mooLoaded, allowMissing = true, rewrite = client.rewrite })
end

-- The player logs out (PLAYER_LOGOUT, saved variables kept in w.savedOf[name]) and the window closes.
function World:logout(client)
	local p = client.player
	client:fire("PLAYER_LOGOUT")
	self.savedOf = self.savedOf or {}
	local saved = {}
	for _, addon in ipairs(client.allAddons or client.addons) do
		saved[addon] = rawget(client.env, addon == "Wuber" and "WuberDB" or (addon .. "DB"))
	end
	self.savedOf[p.name] = saved
	self:closeClient(client, true)
	return saved
end

-- The current game window of a player (a /reload makes a new one).
function World:clientOf(name)
	local p = self:player(name)
	return p and p.client
end

-- The key bound with SetOverrideBindingClick is pressed: the button is clicked by it.
-- The player sets a key in the game's own Key Bindings list for a binding of Bindings.xml ("name" as in the file,
-- e.g. "CLICK WuberDriveButton:LeftButton"); nil clears the key. False when the file has no such binding.
function Client:setGameKey(k, name)
	for _, b in ipairs(self.gameBindings or {}) do
		if b.name == name then self.gameKeys[k] = name return true end
	end
	if name == nil then self.gameKeys[k] = nil return true end
	return false
end

-- A key press. The game's order: an addon's override binding (SetOverrideBindingClick) beats the list's own key for
-- the same key, so one press is one action. A listed CLICK binding clicks the named button (a real key press); any
-- other listed binding runs its body in the addon's environment.
function Client:pressKey(k)
	local b = self.binding
	if not b or b.key ~= k then
		local name = self.gameKeys and self.gameKeys[k]
		if not name then return false end
		local button = name:match("^CLICK (.-):")
		if not button then
			for _, gb in ipairs(self.gameBindings) do
				if gb.name == name then
					local chunk = assert(loadstring(gb.body, "=" .. name))
					setfenv(chunk, self.env)
					local ok, err = pcall(chunk)
					if not ok then self.world.errors[#self.world.errors + 1] = name .. ": " .. tostring(err) end
					return true
				end
			end
			return false
		end
		b = { key = k, button = button }
	end
	local f = rawget(self.env, b.button)
	if not f then return false end
	if not visible(f) then
		-- a key works on a hidden button too (the binding clicks it)
		local w = self.world
		w.hardware = self
		self:runClick(f, "LeftButton", true)
		self:runClick(f, "LeftButton", false)
		w.hardware = nil
		return true
	end
	return self:click(f)
end

-- The rider types gold, silver and copper into the trade window (an addon can't: SPEC2).
function World:typeTradeMoney(p, g, s, c)
	local copper = (g or 0) * 10000 + (s or 0) * 100 + (c or 0)
	p = p.player or p
	self.typed = self.typed or {}
	self.typed[#self.typed + 1] = { by = p.name, copper = copper, at = self.time }
	return self:tradeMoney(p, copper)
end

-- OpenMap tells its callbacks something (CallbackHandler: a function gets (event, ...))
-- A flight master's map opens (SPEC5 flight costs): nodes = { { name = "Ratchet, The Barrens",
-- type = "CURRENT"|"REACHABLE"|"NONE", cost = copper }, ... }. NumTaxiNodes, TaxiNodeName,
-- TaxiNodeGetType and TaxiNodeCost answer from them, then TAXIMAP_OPENED fires.
function World:openTaxi(client, nodes)
	local env = client.env
	env.NumTaxiNodes = function() return #nodes end
	env.TaxiNodeName = function(i) return nodes[i] and nodes[i].name or nil end
	env.TaxiNodeGetType = function(i) return nodes[i] and nodes[i].type or "NONE" end
	env.TaxiNodeCost = function(i) return nodes[i] and nodes[i].cost or 0 end
	-- (REC 22 Nov: 18 flight-map closes on the real client, no TAXIMAP_OPENED at all) w.noTaxiOpened = true
	-- opens the map without it (default off: Wuber still depends on the event)
	if not self.noTaxiOpened then H.rule("event.taximap-opened") client:fire("TAXIMAP_OPENED", 1) end
end

function World:openMapFire(client, event, ...)
	local om = client.openMap
	if not om then return end
	for _, cb in ipairs(om.callbacks) do
		if cb.event == event then
			if type(cb.method) == "string" then
				H.protect(self, client, "OpenMap " .. event, cb.owner[cb.method], cb.owner, event, ...)
			else
				H.protect(self, client, "OpenMap " .. event, cb.method, event, ...)
			end
		end
	end
end

-- What this client forbids (round 12; round 15: one function, so a test can try a longer list and put
-- the shipped one back). Kind "event": RegisterEvent/RegisterUnitEvent/UnregisterEvent raise; kind
-- "api": each new client's function at that path raises (Client build, H.FORBIDDEN); kind "method":
-- every widget class that has the method raises before running it, and when no class has it every
-- widget gets one that only raises. Adding a restriction is one line in tools/forbidden.lua.
H.forbidWrapped = {}
function H.applyForbidden(list)
	for i = #H.forbidWrapped, 1, -1 do
		local wr = H.forbidWrapped[i]
		wr.class[wr.name] = wr.orig -- nil for a method the fake did not have
	end
	H.forbidWrapped = {}
	for k in pairs(H.FORBIDDEN_EVENTS) do H.FORBIDDEN_EVENTS[k] = nil end
	for k in pairs(H.FORBIDDEN_METHODS) do H.FORBIDDEN_METHODS[k] = nil end
	H.FORBIDDEN = list
	for _, f in ipairs(list) do
		if f.kind == "event" then H.FORBIDDEN_EVENTS[f.name] = true end
		if f.kind == "method" then H.FORBIDDEN_METHODS[f.name] = true end
	end
	for name in pairs(H.FORBIDDEN_METHODS) do
		local found = false
		for _, c in pairs(classes) do
			local orig = rawget(c, name)
			if type(orig) == "function" then
				found = true
				H.forbidWrapped[#H.forbidWrapped + 1] = { class = c, name = name, orig = orig }
				c[name] = function(self, ...)
					local s = S[self]
					H.forbid(s and s.client, name .. "()")
					return orig(self, ...)
				end
			end
		end
		if not found then
			H.forbidWrapped[#H.forbidWrapped + 1] = { class = classes.Object, name = name }
			classes.Object[name] = function(self)
				local s = S[self]
				H.forbid(s and s.client, name .. "()")
			end
		end
	end
end

-- Round 8's game fakes (SPEC7 section 8): tests/lib/fakes8.lua, next to this file
do
	local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
	local libdir = (src:match("^(.*)/[^/]*$") or ".") .. "/lib/"
	H.fakes8 = assert(loadfile(libdir .. "fakes8.lua"))()(H, World, Client)
	-- the Group Finder (docs/DESIGN-GROUP-FINDER.md): tests/lib/fake_lfglist.lua
	H.fakeLfg = assert(loadfile(libdir .. "fake_lfglist.lua"))()(H, World, Client)
	-- decisions round (group Q): the fake mailbox, tests/lib/mail.lua
	H.fakeMail = assert(loadfile(libdir .. "mail.lua"))()(H, World, Client)
	-- round 12: what this client forbids to addons (one list, tools/forbidden.lua)
	H.SECRET_API = assert(loadfile(libdir .. "../fixtures/secret-api.lua"))()
	for _, m in ipairs(H.SECRET_API.methods) do H.SECRET_METHODS[m] = true end
	H.applyForbidden(assert(loadfile(libdir .. "../../tools/forbidden.lua"))())
	-- decisions round: the world-map taint rules (tests/lib/maptaint.lua)
	H.mapTaint = assert(loadfile(libdir .. "maptaint.lua"))()(H, function(f, map)
		local s = S[f]
		while s and s.parent do
			if s.parent == map then return true end
			s = S[s.parent]
		end
		return false
	end)
	-- (#234) the protected widget methods (tests/fixtures/protected-methods.lua): on a protected frame in combat a call
	-- is a violation, as the ones above already are; wrapped only where no call of blocked() stands already
	do
		local guarded = { Show = true, Hide = true, SetShown = true, SetScale = true, SetParent = true, SetPoint = true,
			SetAllPoints = true, ClearAllPoints = true, SetWidth = true, SetHeight = true, SetSize = true, EnableMouse = true,
			StartMoving = true, SetAttribute = true }
		H.PROTECTED_METHODS = assert(loadfile(libdir .. "../fixtures/protected-methods.lua"))()
		for _, name in ipairs(H.PROTECTED_METHODS) do
			if not guarded[name] then
				for _, c in pairs(classes) do
					local orig = rawget(c, name)
					if type(orig) == "function" then
						c[name] = function(self, ...)
							if blocked(self, name) then return end
							return orig(self, ...)
						end
					end
				end
			end
		end
	end
end

-- The taint guard (tests/fakegame/taint-allow.lua; the idea from another addon's fake client, lesson 16 of the Polestar notes, no code taken).
-- The fake game fails a test when Wuber's code (a) writes into one of the game's own tables, (b) replaces a game global, (c) writes a field
-- of a game frame (a hook by direct assignment instead of hooksecurefunc) or (d) creates or moves a frame under a game window, unless
-- the case is in the allow file with a reason. (a), (b) and (c) are found by comparing with a copy made before the addons loaded, at
-- clean(w) and at the end of every test; (d) at the moment it happens, with the addon line. A client that replays old code (client.rewrite)
-- is not judged. WUBER_TAINT_LOG=<file> appends every case seen (discovery).
do
	local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
	local allowPath = (src:match("^(.*)/[^/]*$") or ".") .. "/fakegame/taint-allow.lua"
	local TG = { MARK = " (taint guard, tests/fakegame/taint-allow.lua)" }
	H.taint = TG
	function TG.load(path)
		local allow = assert(loadfile(path or allowPath))()
		for kind, set in pairs(allow) do
			for name, entry in pairs(set) do
				local reason = type(entry) == "table" and entry.reason or entry
				if type(reason) ~= "string" or #reason < 10 then error(("taint-allow.lua: %s.%s needs a reason"):format(kind, name), 0) end
			end
		end
		return allow
	end
	TG.allow = TG.load()
	local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
	-- Wuber's file and line now running (the first code that is neither C nor the harness); nil for a test or another addon
	local function addonCaller()
		for level = 3, 60 do
			local info = debug.getinfo(level, "Sl")
			if not info then return nil end
			if info.what ~= "C" and info.what ~= "tail" then
				local srcf = (info.source or ""):gsub("\\", "/")
				for name, dir in pairs(H.ADDONS) do
					local at = srcf:find(dir:gsub("\\", "/"), 1, true)
					if at then
						if not name:find("^Wuber") then return nil end
						return name .. "/" .. srcf:sub(at + #dir + 1) .. ":" .. tostring(info.currentline)
					end
				end
				if not (srcf:find("harness[%w_]*%.lua$") or srcf:find("tests/lib/", 1, true)) then return nil end
			end
		end
	end
	local function judged(client) return client and client.world and client.taintSnap and not client.rewrite end
	local function report(client, key, msg)
		client.taintSeen = client.taintSeen or {}
		local log = os.getenv("WUBER_TAINT_LOG")
		if log and log ~= "" and not client.taintSeen[key] then
			local f = io.open(log, "a")
			if f then f:write(key, "\n") f:close() end
		end
		if client.taintSeen[key] then return end
		client.taintSeen[key] = true
		local w = client.world
		w.violations[#w.violations + 1] = client.player.name .. ": " .. msg .. TG.MARK
	end
	-- called once per client, after the game's world is built and before any addon loads
	function TG.snap(client)
		local snap = { tables = {}, refs = {}, widgets = {}, names = {} }
		for k, v in pairs(client.api) do
			if type(v) == "table" and not isWidget(v) and v ~= client.api then snap.tables[k] = copy(v) snap.refs[k] = v end
		end
		for _, obj in ipairs(client.widgets) do snap.widgets[obj] = true end
		client.taintSnap = snap
	end
	TG.quiet = 0
	-- the game's own hook installer changed t[name] of a plain game table: not the addon's write
	function TG.accept(client, t, name)
		local snap = client and client.taintSnap
		if not snap then return end
		for k, ref in pairs(snap.refs) do if ref == t then snap.tables[k][name] = rawget(t, name) end end
	end
	-- (c) a field written onto a game frame, at the moment it happens (from the widgets' __newindex)
	function TG.field(obj, key)
		if TG.quiet > 0 then return end
		local s = S[obj]
		local client = s and s.client
		if not judged(client) or not client.taintSnap.widgets[obj] then return end
		local name = s.name or "(unnamed game frame)"
		if TG.allow.fields[name .. "." .. tostring(key)] then return end
		local at = addonCaller()
		if not at then return end
		report(client, "field | " .. name .. " | " .. tostring(key) .. " | " .. at, "a field written on the game frame " .. name .. "." .. tostring(key) .. " (" .. at .. "; a hook by assignment: use hooksecurefunc)")
	end
	-- (d) a frame made or moved under a game window
	function TG.parented(client, parent)
		if not judged(client) or not S[parent] or not client.taintSnap.widgets[parent] then return end
		local name = S[parent].name or "(unnamed game frame)"
		-- a game frame under an allowed window (the map's own children, the minimap's) is covered by that window's entry
		if TG.allow.parents[name] then return end
		local up = S[parent].parent
		while up do
			local un = S[up] and S[up].name
			if un and un ~= "UIParent" and un ~= "WorldFrame" and TG.allow.parents[un] then return end
			up = S[up] and S[up].parent
		end
		local at = addonCaller()
		if not at then return end
		report(client, "parent | " .. name .. " | " .. at, "a frame was put under the game window " .. name .. " (" .. at .. ")")
	end
	-- (a) (b) (c): what changed since the snapshot
	function TG.scan(client)
		if not judged(client) then return end
		local snap, allow = client.taintSnap, TG.allow
		for k, who in pairs(client.globalWrites or {}) do
			if client.before[k] and who ~= "harness" and who:find("^Wuber") and not allow.globals[k] then
				report(client, "global | " .. k, "addon code replaced the game's global " .. tostring(k) .. " (" .. who .. ")")
			end
		end
		for name, before in pairs(snap.tables) do
			local ref, rule = snap.refs[name], allow.tables[name]
			for k, v in pairs(ref) do
				local old = before[k]
				if old ~= v then
					local swapped = type(old) == "string" and type(v) == "string" and rule and rule.replace and #ref == #before
						and ((old:find(rule.replace[1]) and v:find(rule.replace[2])) or (old:find(rule.replace[2]) and v:find(rule.replace[1])))
					local appended = swapped or old == nil and rule and ((rule.append and type(k) == "number" and type(v) == "string" and (v:find(rule.append) or (rule.replace and v:find(rule.replace[2]))))
						or (rule.keys and type(k) == "string" and k:find(rule.keys)))
					if not appended then report(client, "table | " .. name .. " | " .. tostring(k), "a write into the game's table " .. name .. "[" .. tostring(k) .. "] = " .. tostring(v)) end
				end
			end
			for k in pairs(before) do
				if ref[k] == nil then report(client, "table | " .. name .. " | " .. tostring(k), "a key removed from the game's table " .. name .. "[" .. tostring(k) .. "]") end
			end
		end
	end
end

---------------------------------------------------------------------------
-- (probe pack, job 2861) what a real client's probe run taught the fake game: tests/lib/probe_learn.lua, tools/rec/probe-import.lua
---------------------------------------------------------------------------
-- H.secretApi[api name] = true: the real client answered that call with a secret value (the probe's secrets run). A new client then
-- starts with it secret, under the name the harness models it with (client.secrets[kind]); a name not listed is its own kind.
H.secretApi = nil
H.SECRET_API_KEY = { UnitGUID = "guid", GetRealmName = "realm", GetChannelName = "channels", GetBestMapForUnit = "C_Map" }

-- H.setSecretAccessors({ ["GetWidth"] = { "NamePlate1", ... } }): a frame with one of those global names answers that accessor with
-- secret values (an addon must test issecretvalue first). nil takes it away again. Wraps the class methods once, restores them.
do
local wrapped = {}
function H.setSecretAccessors(map)
	for _, w in ipairs(wrapped) do w.class[w.name] = w.orig end
	wrapped = {}
	H.secretAccessors, H.secretAccessorsMap = nil, map
	if not map or not next(map) then return end
	local byName = {}
	for acc, frames in pairs(map) do
		local set = {}
		for _, fname in ipairs(frames) do set[fname] = true end
		byName[acc] = set
	end
	H.secretAccessors = byName
	for acc, set in pairs(byName) do
		for _, c in pairs(classes) do
			local orig = rawget(c, acc)
			if type(orig) == "function" then
				wrapped[#wrapped + 1] = { class = c, name = acc, orig = orig }
				c[acc] = function(self, ...)
					local s = S[self]
					if s and s.name and set[s.name] then H.rule("secret.accessor-frames") return SECRET, SECRET, SECRET, SECRET end
					return orig(self, ...)
				end
			end
		end
	end
end
end

-- a REAL probe fixture (tests/fixtures/probe/game-*.lua, written by tools/rec/probe-import.lua from a session in the game) is loaded
-- by every run: file ids, text widths, the keys rules and the secrets. The newest by name wins. No such file: nothing changes.
-- (The synthetic stand-in, SYNTHETIC-standin.lua, is never loaded here; only the probe tests use it.)
H.probeFixture = nil
function H.loadProbeFixture(dir)
	local newest
	for _, f in ipairs(H.listFiles(dir, "lua")) do
		if f:match("/game%-[^/]*%.lua$") then newest = f end
	end
	if not newest then return nil end
	local L = dofile(here .. "/lib/probe_learn.lua")
	local fx = L.load(newest)
	if type(fx) ~= "table" then return nil end
	H.probeFixture = fx
	L.apply(H, fx)
	return fx, newest
end
H.loadProbeFixture(here .. "/fixtures/probe")

if os.getenv("WUBER_SURFACE") == "1" then -- (surface guard hook 3/3) opt-in
	H.surface = dofile(here .. "/surface-guard.lua").new(H, here)
	H.surface.installClasses()
end

return H
