-- Module: FX.Effects
-- Purpose: the effects engine: art tables, the shared driver frame, flipbooks, crowns and badges, layered
--   screen effects, optional models (FX.Play, FX.Fullscreen, FX.Crown, FX.Badge...).
-- API: W.FX, FX.BADGE_IDS, FX.BadgeFirst, FX.Hash, FX.Mode, FX.FrameCoords, FX.TryNative, FX.Crown, FX.Badge,
--   FX.Flipbook, FX.Has, Handle:Stop, Handle:IsPlaying, FX.Play, FX.Fullscreen, FX.StopAll, FX.Refresh,
--   FX.Stats, FX.Model, FX.Goldify (the *_gold effects: portal_open_gold, portal_loop_gold, arrival_gold)
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/fx/effects_test.lua
-- From: FX.lua 1-1078 (Wuber 2.2.1)
--
-- Wuber: effects. Pre-rendered flipbooks (Media/fx, made by tools/make_fx.py: a Cycles-
-- rendered crown and badge tokens, numpy-shaded portal light) composited with sprite layers
-- (rune ring, rays, flares, rings) and particles (sparks, motes, coins), all moved here.
--
--   W.FX.Play(name, parent, opts) -> handle (:Stop(), :IsPlaying()) or nil
--       opts: size, loop, hold (seconds of loop before fading), alpha, scale, level, onDone, x, y
--   W.FX.Fullscreen(name, opts)   -> handle or nil: centred on the screen, click-through,
--       below Wuber's window and the game's popups, never in combat, nil on Light and Off; W.db.fx "full" | "light" | "off"
--       opts (both): gold = true plays the *_gold twin of a portal effect (FX.Goldify), name unchanged for
--       callers and hooks; ownRandom = true draws its particles from a private generator, so an effect
--       2.2.3 never played leaves the shared math.random sequence (ride ids) untouched
--   W.FX.Flipbook(parent, name, size) -> a looping flipbook frame
--   W.FX.Crown(parent, size, seed)    -> the founder's spinning crown (static when fx is off)
--   W.FX.Badge(parent, id, size)      -> a driver badge token (static unless fx is "full")
--   W.FX.Has(name), W.FX.Mode(), W.FX.Refresh(), W.FX.StopAll()
--
-- One shared driver frame: flipbooks step at 20 fps (at most MAX_LIVE at once, crowns
-- first); screen effects move every frame while they play (two seconds or so). Nothing runs
-- while nothing is shown. FX.lua also plays the ride's screen moments itself (RIDE: portal,
-- arrived) and the driver's bursts (paid, a 5-star RATING).

local _, W = ...
local Mod = W.Module("FX.Effects", {})

local FX = {}
W.FX = FX

local MEDIA = "Interface\\AddOns\\Wuber\\Media\\fx\\"
local FPS = 20
local STEP = 1 / FPS
local MAX_LIVE = 12           -- flipbooks animating at once (cards, pins, plates)
local FULL_ALPHA = 0.7        -- screen effects never cover more than this
local pi, sin, cos, exp, floor, min, max, sqrt = math.pi, math.sin, math.cos, math.exp, math.floor, math.min, math.max, math.sqrt

---------------------------------------------------------------------------
-- Art: sheets, books (frame runs), sprites
---------------------------------------------------------------------------

-- file, sheet size, cell size, columns, origin of the grid
local SHEETS = {
	crown = { file = "crown", w = 512, h = 256, cell = 64, cols = 8, blend = "BLEND" },
	badges = { file = "badges", w = 512, h = 512, cell = 64, cols = 8, blend = "BLEND" },
	portal_open = { file = "portal_open", w = 1024, h = 512, cell = 128, cols = 8, blend = "ADD" },
	portal_loop = { file = "portal_loop", w = 512, h = 512, cell = 128, cols = 4, blend = "ADD" },
	arrival = { file = "arrival", w = 1024, h = 512, cell = 128, cols = 8, blend = "ADD" },
	milestone = { file = "milestone", w = 512, h = 512, cell = 128, cols = 4, blend = "ADD" },
	-- founder gold (SPEC7 5.13): the same grids, recoloured offline (tools/make_fx.py --gold); lazy like the rest
	portal_open_gold = { file = "portal_open_gold", w = 1024, h = 512, cell = 128, cols = 8, blend = "ADD" },
	portal_loop_gold = { file = "portal_loop_gold", w = 512, h = 512, cell = 128, cols = 4, blend = "ADD" },
	arrival_gold = { file = "arrival_gold", w = 1024, h = 512, cell = 128, cols = 8, blend = "ADD" },
	coins = { file = "parts", w = 512, h = 256, cell = 64, cols = 8, y0 = 192, blend = "BLEND" },
}

-- Badge ids (W.BADGES, NET) -> their run of ten frames in badges.tga (row-major)
local BADGE_FIRST = { bolt = 0, star = 10, flame = 20, moon = 30, crystal = 40, skull = 50 }
FX.BADGE_IDS = { "bolt", "star", "flame", "moon", "crystal", "skull" }
function FX.BadgeFirst(id) return BADGE_FIRST[id] end

local BOOKS = {
	crown = { sheet = "crown", first = 0, count = 32, fps = 16, loop = true },
	portal_open = { sheet = "portal_open", first = 0, count = 32, fps = 20 },
	portal_loop = { sheet = "portal_loop", first = 0, count = 16, fps = 20, loop = true },
	arrival = { sheet = "arrival", first = 0, count = 32, fps = 20 },
	milestone = { sheet = "milestone", first = 0, count = 16, fps = 20 },
	portal_open_gold = { sheet = "portal_open_gold", first = 0, count = 32, fps = 20 },
	portal_loop_gold = { sheet = "portal_loop_gold", first = 0, count = 16, fps = 20, loop = true },
	arrival_gold = { sheet = "arrival_gold", first = 0, count = 32, fps = 20 },
	coin = { sheet = "coins", first = 0, count = 8, fps = 16, loop = true },
}
for id, first in pairs(BADGE_FIRST) do
	BOOKS["badge_" .. id] = { sheet = "badges", first = first, count = 10, fps = 12, loop = true, badge = id }
end

-- parts.tga (512x256): x, y, w, h. runes and rays are files of their own (they turn).
local PARTS = {
	glow = { 0, 0, 128, 128 }, ring = { 128, 0, 128, 128 }, flare = { 256, 0, 128, 128 }, star = { 384, 0, 128, 128 },
	spark = { 0, 128, 64, 64 }, mote = { 64, 128, 64, 64 }, streak = { 128, 128, 64, 64 }, twinkle = { 192, 128, 64, 64 },
}
local LONE = { runes = true, rays = true, runes_gold = true }

-- the author's colours
local C = {
	violet = { 0.533, 0.247, 0.855 }, bright = { 0.804, 0.490, 0.961 }, magenta = { 0.894, 0.404, 0.988 },
	gold = { 0.976, 0.773, 0.243 }, deepgold = { 0.694, 0.529, 0.247 }, white = { 1, 1, 1 }, hot = { 1, 0.86, 1 },
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function now() return (W.Num(GetTime and GetTime()) or 0) end

local function call(obj, m, ...)
	if obj == nil then return nil end
	local f = obj[m]
	if type(f) ~= "function" then return nil end
	local ok, a, b = pcall(f, obj, ...)
	if ok then return a, b end
	return nil
end

local function clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 end return x end
local function easeOut(t) t = clamp01(t) return 1 - (1 - t) ^ 3 end

-- 0..1: rises over fin after t0, falls over fout before t1 (t1 nil = forever)
local function envelope(t, t0, t1, fin, fout)
	if t < t0 or (t1 and t > t1) then return 0 end
	local a = 1
	if fin and fin > 0 then a = min(a, (t - t0) / fin) end
	if t1 and fout and fout > 0 then a = min(a, (t1 - t) / fout) end
	return clamp01(a)
end

-- A small stable number from a name or number (spreads crowns' start frames).
local function hash(seed)
	if type(seed) == "number" then return floor(math.abs(seed)) % 997 end
	local s, h = tostring(seed or ""), 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 100003 end
	return h % 997
end
FX.Hash = hash

function FX.Mode()
	local TH, m = W.Theme, W.db and W.db.fx -- (#305) Reduce motion reads "off": no moving effects
	if (TH and TH.ReduceMotion and TH.ReduceMotion()) or m == "off" then return "off" end
	return m == "light" and m or "full"
end

local function setTex(tex, file, blend)
	local path = MEDIA .. file
	-- outside its edges a texture is clear: a turned sprite never shows a smeared border
	local ok = pcall(tex.SetTexture, tex, path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	if not ok then pcall(tex.SetTexture, tex, path) end
	if blend and tex.SetBlendMode then pcall(tex.SetBlendMode, tex, blend) end
end

local function frameCoords(sheet, index)
	local col = index % sheet.cols
	local row = floor(index / sheet.cols)
	local l = ((sheet.x0 or 0) + col * sheet.cell) / sheet.w
	local t = ((sheet.y0 or 0) + row * sheet.cell) / sheet.h
	return l, l + sheet.cell / sheet.w, t, t + sheet.cell / sheet.h
end
FX.FrameCoords = function(sheetName, index) return frameCoords(SHEETS[sheetName], index) end

local function partCoords(name)
	local p = PARTS[name]
	if not p then return 0, 1, 0, 1 end
	return p[1] / 512, (p[1] + p[3]) / 512, p[2] / 256, (p[2] + p[4]) / 256
end

-- A turned whole texture: the four corners turned round the middle.
local function turn(tex, a)
	local c, s = cos(a), sin(a)
	local function at(u, v) return 0.5 + u * c - v * s, 0.5 + u * s + v * c end
	local ulx, uly = at(-0.5, -0.5)
	local llx, lly = at(-0.5, 0.5)
	local urx, ury = at(0.5, -0.5)
	local lrx, lry = at(0.5, 0.5)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function tint(tex, col, a)
	col = col or C.white
	tex:SetVertexColor(col[1], col[2], col[3], a or 1)
end

---------------------------------------------------------------------------
-- The shared driver
---------------------------------------------------------------------------

local driver
local live, liveCount = {}, 0   -- flipbooks animating now
local waiting = {}               -- flipbooks that want to animate (over the cap): shown static
local playing = {}               -- screen effects running
local acc = 0
local stepList = {} -- the flipbooks to step this frame (a copy of `live`, reused)

local function driverOn()
	if not driver then return end
	if liveCount > 0 or next(playing) then driver:Show() else driver:Hide() end
end

local stepBook, applyFrame, updateEffect, releaseEffect, loadSprites

local function onUpdate(_, elapsed)
	elapsed = W.Num(elapsed) or 0
	local t = now()
	for fx in pairs(playing) do
		local ok, err = pcall(updateEffect, fx, t)
		if not ok then
			W.Error("fx " .. tostring(fx.name), err)
			playing[fx] = nil
			pcall(releaseEffect, fx)
		end
	end
	acc = acc + elapsed
	if acc >= STEP then
		local steps = min(3, floor(acc / STEP))
		acc = acc - steps * STEP
		if acc > STEP then acc = 0 end
		-- walk a copy: stepBook may unregister a book, and promote() then adds a key to `live`; adding a key
		-- while pairs() walks a table is undefined in Lua 5.1 (a book skipped or stepped twice, or "invalid key to 'next'")
		local n = 0
		for book in pairs(live) do n = n + 1; stepList[n] = book end
		for i = n + 1, #stepList do stepList[i] = nil end
		for i = 1, n do
			local book = stepList[i]
			stepList[i] = nil
			if live[book] then -- an earlier book's step may have taken it off already
				local ok, err = pcall(stepBook, book, steps, t)
				if not ok then
					W.Error("fx flipbook", err)
					if live[book] then
						live[book] = nil
						liveCount = liveCount - 1
					end
				end
			end
		end
	end
	driverOn()
end

local function ensureDriver()
	if driver then return driver end
	driver = CreateFrame("Frame", nil, UIParent)
	driver:Hide()
	driver:SetScript("OnUpdate", function(self, elapsed)
		local ok, err = pcall(onUpdate, self, elapsed)
		if not ok then W.Error("fx driver", err) end
	end)
	return driver
end

---------------------------------------------------------------------------
-- Flipbooks: frames whose texture steps through a run of cells
---------------------------------------------------------------------------

local books = setmetatable({}, { __mode = "k" }) -- every flipbook made (for Refresh)

local function wantsMotion(book)
	local mode = FX.Mode()
	if mode == "off" then return false end
	if book.still then return false end -- (round 13, I2) held face-on (SetStill)
	if book.badge and mode ~= "full" then return false end
	return book.def.loop == true or not book.done
end

applyFrame = function(book)
	local def = book.def
	if not book.texSet then
		setTex(book.tex, SHEETS[def.sheet].file, book.blend or SHEETS[def.sheet].blend)
		book.texSet = true
	end
	if book.nativeOn then return end -- the FlipBook animation turns the pages
	local idx = def.first + (floor(book.pos) % def.count)
	if idx ~= book.shown then
		book.shown = idx
		book.tex:SetTexCoord(frameCoords(SHEETS[def.sheet], idx))
	end
end

local function promote()
	while liveCount < MAX_LIVE do
		local best
		for b in pairs(waiting) do
			if not best or (b.priority or 1) > (best.priority or 1) then best = b end
		end
		if not best then return end
		waiting[best] = nil
		live[best] = true
		liveCount = liveCount + 1
	end
end

local function unregister(book)
	waiting[book] = nil
	if live[book] then
		live[book] = nil
		liveCount = liveCount - 1
		promote()
	end
	driverOn()
end

local function register(book)
	if live[book] then return end
	if liveCount >= MAX_LIVE then
		-- full: a crown may take the place of a lower-priority flipbook
		local victim
		for b in pairs(live) do
			if (b.priority or 1) < (book.priority or 1) and (not victim or (b.priority or 1) < (victim.priority or 1)) then victim = b end
		end
		if victim then
			live[victim] = nil
			liveCount = liveCount - 1
			waiting[victim] = true
		else
			waiting[book] = true
			return
		end
	end
	waiting[book] = nil
	live[book] = true
	liveCount = liveCount + 1
	ensureDriver()
	driverOn()
end

-- Whether the flipbook should move now; registers or unregisters it, and shows its rest frame.
local function refreshBook(book)
	local visible = W.Plain(call(book, "IsVisible")) == true
	if not visible and not book.texSet then
		unregister(book)
		return -- lazy: no texture until it is first seen
	end
	if visible and book.glow then loadSprites(book) end
	local moving = visible and wantsMotion(book)
	if moving then
		register(book)
	else
		unregister(book)
		if not wantsMotion(book) and not book.done then book.pos = book.restFrame or 0 end
	end
	if book.nativeGroup then
		if moving and not book.nativeOn then
			if not book.texSet then applyFrame(book) end
			book.tex:SetTexCoord(0, 1, 0, 1)
			book.nativeOn = true
			if not pcall(book.nativeGroup.Play, book.nativeGroup) then
				book.nativeOn, book.nativeGroup = false, nil
				book.shown = nil
			end
		elseif not moving and book.nativeOn then
			pcall(book.nativeGroup.Stop, book.nativeGroup)
			book.nativeOn = false
			book.shown = nil
		end
	end
	applyFrame(book)
	if book.extra then pcall(book.extra, book, now(), 0) end
end

stepBook = function(book, steps, t)
	if W.Plain(call(book, "IsVisible")) ~= true then
		unregister(book)
		return
	end
	local def = book.def
	if book.nativeOn then
		if book.extra then book.extra(book, t, steps) end
		return
	end
	book.pos = book.pos + steps * (def.fps / FPS) * (book.rate or 1)
	if book.pos >= def.count then
		if def.loop then
			book.pos = book.pos % def.count
		else
			book.pos = def.count - 1
			book.done = true
			unregister(book)
			if book.onDone then pcall(book.onDone, book) end
		end
	end
	applyFrame(book)
	if book.extra then book.extra(book, t, steps) end
end

local function newBook(parent, name, size, kind)
	local def = BOOKS[name]
	if not def then return nil end
	local f = CreateFrame("Frame") f:SetParent(parent or UIParent) -- no parent first, then parented (PST-01: one line, alpha-known.txt)
	size = W.Num(size) or 32
	f:SetSize(size, size)
	call(f, "EnableMouse", false)
	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(f)
	f.tex = tex
	f.def = def
	f.name = name
	f.kind = kind or "flipbook"
	f.badge = def.badge
	f.pos = 0
	f.restFrame = 0
	f.priority = 1
	f.wuberFX = true
	f:SetScript("OnShow", function(self)
		local ok, err = pcall(refreshBook, self)
		if not ok then W.Error("fx show", err) end
	end)
	f:SetScript("OnHide", function(self) pcall(unregister, self) end)
	-- methods
	f.SetSeed = function(self, seed)
		local n = hash(seed)
		self.pos = n % self.def.count
		self.rate = 0.92 + (n % 17) / 100 -- a touch faster or slower: never in step for long
	end
	f.Stop = function(self)
		unregister(self)
		self.pos = self.restFrame or 0
		self.done = true
		applyFrame(self)
	end
	f.Play = function(self)
		self.done = false
		self.pos = 0
		pcall(refreshBook, self)
	end
	f.Refresh = function(self) pcall(refreshBook, self) end
	-- (round 13, I2) SetStill(true): stands still on its rest frame (a badge face-on); false: moves again
	f.SetStill = function(self, on)
		on = on and true or false
		if self.still == on then return end
		self.still = on
		if on then self.pos = self.restFrame or 0 end
		pcall(refreshBook, self) -- (draws the rest frame once seen; no sheet is loaded before that)
	end
	f.SetBook = function(self, other)
		local d = BOOKS[other]
		if not d then return false end
		self.def, self.name, self.badge, self.shown = d, other, d.badge, nil
		self.texSet = false
		self.pos = 0
		pcall(refreshBook, self)
		return true
	end
	books[f] = true
	return f
end

-- A native FlipBook animation for a whole-sheet loop (the crown), when the client has one.
-- Tried once; if anything about it fails, the shared driver does the work from then on.
local nativeFailed = false
local function tryNative(book)
	if nativeFailed or FX.noNative or book.def.sheet ~= "crown" then return false end
	local sheet = SHEETS.crown
	local ok = pcall(function()
		local ag = book.tex:CreateAnimationGroup()
		local a = ag:CreateAnimation("FlipBook")
		if type(a.SetFlipBookRows) ~= "function" or type(a.SetFlipBookColumns) ~= "function"
			or type(a.SetFlipBookFrames) ~= "function" then
			error("no flipbook")
		end
		a:SetFlipBookRows(sheet.h / sheet.cell)
		a:SetFlipBookColumns(sheet.cols)
		a:SetFlipBookFrames(book.def.count)
		call(a, "SetFlipBookFrameWidth", 0)
		call(a, "SetFlipBookFrameHeight", 0)
		a:SetDuration(book.def.count / book.def.fps / (book.rate or 1))
		ag:SetLooping("REPEAT")
		book.nativeGroup = ag
		book.nativeAnim = a
	end)
	if not ok then
		nativeFailed = true
		return false
	end
	return true
end
FX.TryNative = tryNative

---------------------------------------------------------------------------
-- Crowns and badges
---------------------------------------------------------------------------

-- Spots on the crown where a glint flashes (x, y as parts of the frame size)
local GLINTS = { { 0.18, 0.08 }, { -0.2, -0.18 }, { 0.05, 0.3 }, { 0.26, -0.2 }, { -0.08, 0.02 } }

local function crownExtra(book, t, steps)
	local size = book.size or 32
	local mode = FX.Mode()
	local ph = book.phase or 0
	-- the violet glow breathing behind it
	if book.glow then
		local a = 0.42
		if mode ~= "off" then a = 0.36 + 0.14 * sin(t * 2.1 + ph) end
		book.glow:SetAlpha(a)
	end
	-- a glint flashing on a gem every few seconds
	if book.glint then
		if mode == "off" then
			book.glint:Hide()
		else
			local period = 2.6
			local u = ((t + ph) % period) / period
			local cyc = floor((t + ph) / period)
			if u < 0.16 then
				local spot = GLINTS[(cyc + floor(ph)) % #GLINTS + 1]
				local k = sin(u / 0.16 * pi)
				local s = size * (0.25 + 0.35 * k)
				book.glint:SetSize(s, s)
				book.glint:ClearAllPoints()
				book.glint:SetPoint("CENTER", book, "CENTER", spot[1] * size, spot[2] * size)
				book.glint:SetAlpha(k)
				book.glint:Show()
			else
				book.glint:Hide()
			end
		end
	end
	-- motes circling the crown (full effects only)
	if book.motes then
		for i, m in ipairs(book.motes) do
			if mode ~= "full" then
				m:Hide()
			else
				local a = t * 1.4 + ph + i * 2.094
				local depth = sin(a)                 -- in front when positive
				m:ClearAllPoints()
				m:SetPoint("CENTER", book, "CENTER", cos(a) * size * 0.56, -0.08 * size + depth * size * 0.12 + sin(t * 3 + i) * size * 0.05)
				local s = size * (0.12 + 0.05 * depth)
				m:SetSize(s, s)
				m:SetAlpha(0.35 + 0.45 * (depth + 1) / 2)
				m:Show()
			end
		end
	end
end

local function loadSprite(tex)
	local want = tex.wuberSprite
	if not want then return end
	tex.wuberSprite = nil
	if LONE[want.part] then
		setTex(tex, want.part, want.blend)
	else
		setTex(tex, "parts", want.blend)
		tex:SetTexCoord(partCoords(want.part))
	end
end

-- A sprite texture; lazy ones get their file only when first shown (loadSprites).
local function addSprite(frame, part, layer, sub, col, blend, lazy)
	local tex = frame:CreateTexture(nil, layer or "OVERLAY", nil, sub or 0)
	tex.wuberSprite = { part = part, blend = blend or "ADD" }
	if not lazy then loadSprite(tex) end
	tint(tex, col)
	return tex
end

loadSprites = function(book)
	if book.glow then loadSprite(book.glow) end
	if book.glint then loadSprite(book.glint) end
	for _, m in ipairs(book.motes or {}) do loadSprite(m) end
end

-- The founder's crown: glow behind, the Cycles-rendered crown turning, a glint on its gems
-- and motes circling it. seed (name or number) sets where in the turn it starts.
function FX.Crown(parent, size, seed)
	local ok, res = pcall(function()
		size = W.Num(size) or 32
		local book = newBook(parent, "crown", size, "crown")
		if not book then return nil end
		book.size = size
		book.priority = 2
		book:SetSeed(seed or 0)
		book.phase = (hash(seed or 0) % 100) / 100 * 2.6
		book.restFrame = 0
		if not (W.db and W.db.fxNoNative) then tryNative(book) end
		local glow = addSprite(book, "glow", "BACKGROUND", -1, C.violet, "ADD", true)
		glow:SetPoint("CENTER", book, "CENTER", 0, -size * 0.04)
		glow:SetSize(size * 1.7, size * 1.45)
		book.glow = glow
		book.glint = addSprite(book, "star", "OVERLAY", 3, { 1, 0.95, 0.8 }, "ADD", true)
		book.glint:Hide()
		book.motes = {}
		for i = 1, 3 do
			local m = addSprite(book, "spark", "OVERLAY", 2, i == 2 and C.gold or C.magenta, "ADD", true)
			m:Hide()
			book.motes[i] = m
		end
		book.extra = crownExtra
		book.SetCrownSize = function(self, s)
			s = W.Num(s) or self.size
			self.size = s
			self:SetSize(s, s)
			self.glow:SetSize(s * 1.7, s * 1.45)
		end
		pcall(refreshBook, book)
		return book
	end)
	if ok then return res end
	W.Error("fx crown", res)
	return nil
end

-- A driver's badge token (W.BADGES id). Unknown ids: nil (nothing shows).
function FX.Badge(parent, id, size)
	id = W.Str(id)
	if not id or not BADGE_FIRST[id] then return nil end
	local ok, res = pcall(function()
		local book = newBook(parent, "badge_" .. id, W.Num(size) or 20, "badge")
		if not book then return nil end
		book.restFrame = 0
		book.SetBadge = function(self, other)
			other = W.Str(other)
			if not other or not BADGE_FIRST[other] then return false end
			return self:SetBook("badge_" .. other)
		end
		pcall(refreshBook, book)
		return book
	end)
	if ok then return res end
	W.Error("fx badge", res)
	return nil
end

-- Any looping flipbook by name ("crown", "badge_star", "portal_loop", "coin", ...)
function FX.Flipbook(parent, name, size)
	if name == "crown" then return FX.Crown(parent, size) end
	local ok, res = pcall(function()
		local book = newBook(parent, name, size, "flipbook")
		if book then pcall(refreshBook, book) end
		return book
	end)
	if ok then return res end
	W.Error("fx flipbook", res)
	return nil
end

---------------------------------------------------------------------------
-- Screen effects: layered compositions
---------------------------------------------------------------------------
-- Layer kinds:
--   book:   the pre-rendered flipbook core (w: size as a part of the effect's size)
--   sprite: part, w (and h), colour, a (peak alpha), t0/t1, fin/fout, s0 -> s1 over sdur,
--           spin (degrees a second; runes and rays only), pulse
--   burst:  particles: part, n, at, life, speed, drag, grav, colours, size, spread, r0, line

local EFFECTS = {}

EFFECTS.portal_open = {
	size = 260, dur = 1.6, loopBook = "portal_loop",
	layers = {
		{ kind = "sprite", part = "glow", w = 1.25, col = C.violet, a = 0.55, t0 = 0, fin = 0.5, s0 = 0.2, s1 = 1, sdur = 0.7 },
		{ kind = "sprite", part = "runes", w = 1.12, col = C.bright, a = 0.9, t0 = 0.12, fin = 0.45, s0 = 0.6, s1 = 1, sdur = 0.8, spin = -22 },
		{ kind = "sprite", part = "runes", w = 0.82, col = C.magenta, a = 0.45, t0 = 0.3, fin = 0.5, s0 = 0.5, s1 = 1, sdur = 0.9, spin = 34 },
		{ kind = "book", book = "portal_open", w = 1.0, t0 = 0 },
		{ kind = "sprite", part = "rays", w = 1.2, col = C.magenta, a = 0.55, t0 = 0.24, t1 = 1.1, fin = 0.08, fout = 0.6, s0 = 0.5, s1 = 1.3, sdur = 0.8, spin = 40 },
		{ kind = "sprite", part = "flare", w = 1.6, h = 0.4, col = C.hot, a = 0.9, t0 = 0.26, t1 = 0.8, fin = 0.05, fout = 0.45, s0 = 0.4, s1 = 1.2, sdur = 0.5 },
		{ kind = "burst", part = "spark", n = 26, at = 0.3, life = { 0.6, 1.0 }, speed = { 0.5, 1.2 }, drag = 2.4, grav = 0,
			cols = { C.magenta, C.gold, C.bright }, size = { 0.025, 0.05 }, a = 1 },
	},
}

EFFECTS.portal_loop = {
	size = 220, dur = 0.8, loop = true,
	layers = {
		{ kind = "sprite", part = "glow", w = 1.25, col = C.violet, a = 0.5, t0 = 0, fin = 0.3, pulse = 0.1 },
		{ kind = "sprite", part = "runes", w = 1.12, col = C.bright, a = 0.85, t0 = 0, fin = 0.3, spin = -22 },
		{ kind = "book", book = "portal_loop", w = 1.0, t0 = 0, loop = true },
	},
}

EFFECTS.arrival = {
	size = 260, dur = 1.9,
	layers = {
		{ kind = "sprite", part = "runes", w = 1.12, col = C.bright, a = 0.8, t0 = 0, t1 = 0.4, fout = 0.35, s0 = 1, s1 = 0.3, sdur = 0.4, spin = -120 },
		{ kind = "book", book = "arrival", w = 1.0, t0 = 0 },
		{ kind = "sprite", part = "glow", w = 1.0, col = C.gold, a = 0.8, t0 = 0.3, t1 = 1.1, fin = 0.05, fout = 0.7, s0 = 0.3, s1 = 1.4, sdur = 0.5 },
		{ kind = "sprite", part = "ring", w = 1.0, col = C.gold, a = 0.9, t0 = 0.32, t1 = 1.05, fin = 0.03, fout = 0.6, s0 = 0.15, s1 = 1.9, sdur = 0.75 },
		{ kind = "sprite", part = "rays", w = 1.3, col = C.gold, a = 0.6, t0 = 0.3, t1 = 1.3, fin = 0.05, fout = 0.8, s0 = 0.6, s1 = 1.3, sdur = 1.0, spin = 25 },
		{ kind = "sprite", part = "flare", w = 2.0, h = 0.35, col = C.white, a = 0.9, t0 = 0.3, t1 = 0.75, fin = 0.03, fout = 0.4, s0 = 0.5, s1 = 1.3, sdur = 0.45 },
		{ kind = "burst", part = "mote", n = 30, at = 0.33, life = { 0.9, 1.5 }, speed = { 0.5, 1.4 }, drag = 2.2, grav = 0.35,
			cols = { C.gold, C.gold, C.bright, C.magenta }, size = { 0.03, 0.06 }, a = 0.9 },
		{ kind = "burst", part = "twinkle", n = 10, at = 0.36, life = { 0.8, 1.3 }, speed = { 0.4, 1.0 }, drag = 2.5, grav = 0.15,
			cols = { C.white, C.gold }, size = { 0.06, 0.1 }, a = 1, twinkle = true },
	},
}

EFFECTS.milestone = {
	size = 220, dur = 2.0,
	layers = {
		{ kind = "sprite", part = "rays", w = 1.3, col = C.gold, a = 0.55, t0 = 0.05, t1 = 2.0, fin = 0.2, fout = 0.8, s0 = 0.7, s1 = 1.05, sdur = 1.5, spin = 12 },
		{ kind = "sprite", part = "glow", w = 0.9, col = C.gold, a = 0.6, t0 = 0, t1 = 2.0, fin = 0.08, fout = 1.0, pulse = 0.15 },
		{ kind = "book", book = "milestone", w = 1.0, t0 = 0 },
		{ kind = "sprite", part = "ring", w = 1.0, col = C.bright, a = 0.7, t0 = 0.15, t1 = 0.95, fin = 0.03, fout = 0.5, s0 = 0.2, s1 = 1.5, sdur = 0.8 },
		{ kind = "burst", part = "star", n = 12, at = 0.05, life = { 1.0, 1.6 }, speed = { 0.45, 0.9 }, drag = 2.0, grav = -0.05,
			cols = { C.gold, C.white }, size = { 0.08, 0.13 }, a = 1, twinkle = true },
		{ kind = "burst", part = "spark", n = 18, at = 0.08, life = { 0.6, 1.1 }, speed = { 0.6, 1.3 }, drag = 2.6, grav = 0.1,
			cols = { C.gold, C.bright, C.magenta }, size = { 0.025, 0.045 }, a = 1 },
	},
}

EFFECTS.paid = {
	size = 130, dur = 1.0,
	layers = {
		{ kind = "sprite", part = "glow", w = 0.9, col = C.gold, a = 0.7, t0 = 0, t1 = 0.8, fin = 0.04, fout = 0.6, s0 = 0.4, s1 = 1.1, sdur = 0.4 },
		{ kind = "sprite", part = "ring", w = 1.0, col = C.gold, a = 0.9, t0 = 0, t1 = 0.6, fin = 0.02, fout = 0.4, s0 = 0.2, s1 = 1.3, sdur = 0.55 },
		{ kind = "sprite", part = "flare", w = 1.6, h = 0.3, col = C.white, a = 0.8, t0 = 0, t1 = 0.4, fin = 0.02, fout = 0.3, s0 = 0.5, s1 = 1.2, sdur = 0.35 },
		{ kind = "burst", part = "spark", n = 14, at = 0.02, life = { 0.45, 0.8 }, speed = { 0.7, 1.3 }, drag = 3, grav = 0.1,
			cols = { C.gold, C.gold, C.bright }, size = { 0.04, 0.07 }, a = 1 },
		{ kind = "burst", part = "coin", n = 5, at = 0.02, life = { 0.7, 0.9 }, speed = { 0.4, 0.8 }, drag = 1.2, grav = -1.4,
			spread = 120, dir = 90, size = { 0.14, 0.18 }, a = 1 },
	},
}

EFFECTS.coins = {
	size = 360, dur = 2.6,
	layers = {
		{ kind = "sprite", part = "glow", w = 1.2, col = C.gold, a = 0.35, t0 = 0, t1 = 2.6, fin = 0.2, fout = 1.2 },
		{ kind = "sprite", part = "rays", w = 1.1, col = C.gold, a = 0.4, t0 = 0, t1 = 2.2, fin = 0.15, fout = 1.2, spin = 15 },
		{ kind = "burst", part = "coin", n = 30, at = 0.0, spawn = 1.2, life = { 1.3, 1.7 }, speed = { 0, 0.08 }, drag = 0, grav = -1.3,
			line = 0.9, r0y = 0.55, size = { 0.075, 0.11 }, a = 1 },
		{ kind = "burst", part = "twinkle", n = 14, at = 0.1, spawn = 1.4, life = { 0.5, 0.9 }, speed = { 0, 0.05 }, drag = 0, grav = -0.2,
			line = 0.9, r0y = 0.3, cols = { C.white, C.gold }, size = { 0.04, 0.07 }, a = 1, twinkle = true },
	},
}

-- Founder gold (SPEC7 5.13): each portal effect again with the gold flipbooks and rune ring, and its
-- violets mapped to golds, so it reads as the same effect in gold. Built once at load from the
-- definitions above (no texture is touched until first play).
local GOLD_MAP = {
	[C.violet] = C.deepgold, [C.bright] = C.gold, [C.magenta] = C.gold, [C.hot] = { 1, 0.93, 0.7 },
}
local function goldOf(def)
	local g = {}
	for k, v in pairs(def) do g[k] = v end
	if def.loopBook then g.loopBook = def.loopBook .. "_gold" end
	g.layers = {}
	for i, L in ipairs(def.layers) do
		local n = {}
		for k, v in pairs(L) do n[k] = v end
		if L.book then n.book = L.book .. "_gold" end
		if L.part == "runes" then n.part = "runes_gold" end
		if L.col then n.col = GOLD_MAP[L.col] or L.col end
		if L.cols then
			n.cols = {}
			for j, c in ipairs(L.cols) do n.cols[j] = GOLD_MAP[c] or c end
		end
		g.layers[i] = n
	end
	return g
end
EFFECTS.portal_open_gold = goldOf(EFFECTS.portal_open)
EFFECTS.portal_loop_gold = goldOf(EFFECTS.portal_loop)
EFFECTS.arrival_gold = goldOf(EFFECTS.arrival)

-- The name to play for a portal moment: the gold twin for a genuine founder's summon.
function FX.Goldify(name, gold)
	if gold and (name == "portal_open" or name == "portal_loop" or name == "arrival") then return name .. "_gold" end
	return name
end

local LOOPS = { portal_open = true, portal_loop = true, portal_open_gold = true, portal_loop_gold = true }

function FX.Has(name)
	if type(name) ~= "string" then return false end
	if name == "crown" or EFFECTS[name] or BOOKS[name] then return true end
	return false
end

-- Pools of finished effects, by name
local pool = {}

-- Particles draw from math.random, except while an ownRandom effect is seeded: then from a private
-- Park-Miller generator (exact in doubles), so new effects never shift anyone else's random numbers.
local ownRng = nil
local function newRng(seed)
	local s = floor(math.abs(seed or 1)) % 2147483647
	if s == 0 then s = 1 end
	return function(a, b)
		s = (s * 16807) % 2147483647
		local x = (s - 1) / 2147483646
		if a == nil then return x end
		if b == nil then return floor(x * a) + 1 end
		return a + floor(x * (b - a + 1))
	end
end
local function rnd(a, b)
	if ownRng then return ownRng(a, b) end
	if a == nil then return math.random() end
	return math.random(a, b)
end

local function rand(r, seedState)
	return r[1] + (r[2] - r[1]) * rnd()
end

local function buildEffect(name, parent)
	local def = EFFECTS[name]
	local box = CreateFrame("Frame", nil, parent or UIParent)
	call(box, "EnableMouse", false)
	local fx = { name = name, def = def, box = box, layers = {} }
	for i, L in ipairs(def.layers) do
		local layer = { def = L }
		if L.kind == "book" then
			local b = newBook(box, L.book, 64, "layer")
			b:SetScript("OnShow", nil)
			b:SetScript("OnHide", nil)
			b:SetPoint("CENTER", box, "CENTER", 0, 0)
			call(b, "SetFrameLevel", (W.Num(call(box, "GetFrameLevel")) or 1) + 1)
			layer.book = b
		elseif L.kind == "sprite" then
			layer.tex = addSprite(box, L.part, "ARTWORK", i - 8 + 1, L.col)
			layer.tex:SetPoint("CENTER", box, "CENTER", 0, 0)
			layer.tex:Hide()
		elseif L.kind == "burst" then
			layer.p = {}
			local n = L.n
			for k = 1, n do
				local p = {}
				if L.part == "coin" then
					local cf = box:CreateTexture(nil, "OVERLAY", nil, 2)
					setTex(cf, "parts", "BLEND")
					p.tex = cf
				else
					p.tex = addSprite(box, L.part, "OVERLAY", 4, C.white)
				end
				p.tex:Hide()
				layer.p[k] = p
			end
		end
		fx.layers[i] = layer
	end
	return fx
end

local function seedBurst(fx, layer, scaleN)
	local L = layer.def
	local n = #layer.p
	local use = max(1, floor(n * scaleN + 0.5))
	for k, p in ipairs(layer.p) do
		p.on = k <= use
		if p.on then
			local spread = (L.spread or 360) * pi / 180
			local dir = (L.dir or 0) * pi / 180
			p.a = dir + (rnd() - 0.5) * spread
			if (L.spread or 360) >= 360 then p.a = rnd() * 2 * pi end
			p.v = rand(L.speed)
			p.life = rand(L.life)
			p.size = rand(L.size)
			p.delay = (L.spawn or 0) * rnd()
			p.x0 = L.line and (rnd() - 0.5) * 2 * L.line or 0
			p.y0 = L.r0y or 0
			p.frame = rnd(0, 7)
			p.fspd = 10 + rnd() * 10
			p.tw = rnd() * 6.28
			local cols = L.cols or { C.white }
			p.col = cols[(k - 1) % #cols + 1]
			if L.part ~= "coin" then tint(p.tex, p.col, 1) end
		end
		p.tex:Hide()
	end
end

local function resetEffect(fx, opts)
	opts = opts or {}
	fx.opts = opts
	fx.start = now()
	fx.stopAt, fx.fadeAt = nil, nil
	fx.looping = opts.loop == true and (EFFECTS[fx.name].loop or EFFECTS[fx.name].loopBook) and true or false
	local def = EFFECTS[fx.name]
	if def.loop then fx.looping = true end
	if fx.looping and opts.hold then
		fx.stopAt = fx.start + (def.loop and 0 or def.dur) + opts.hold
	end
	local scaleN = FX.Mode() == "light" and 0.4 or 1
	ownRng = opts.ownRandom == true and newRng(hash(fx.name) * 1000 + (fx.gen or 0)) or nil
	for _, layer in ipairs(fx.layers) do
		if layer.book then
			local b = layer.book
			b.def = BOOKS[layer.def.book]
			b.texSet, b.shown, b.pos, b.done = false, nil, 0, false
			b:Show()
			applyFrame(b)
			b.tex:SetAlpha(0)
		elseif layer.p then
			seedBurst(fx, layer, scaleN)
		elseif layer.tex then
			layer.tex:Hide()
		end
	end
	ownRng = nil
end

local function sizeOf(fx) return fx.size or EFFECTS[fx.name].size end

updateEffect = function(fx, tnow)
	local def = fx.def
	local t = tnow - fx.start
	local size = sizeOf(fx)
	-- the end: fade out, then release
	if not fx.looping and t >= def.dur then
		playing[fx] = nil
		releaseEffect(fx, true)
		return
	end
	if fx.stopAt and tnow >= fx.stopAt and not fx.fadeAt then fx.fadeAt = tnow end
	local fade = 1
	if fx.fadeAt then
		fade = 1 - (tnow - fx.fadeAt) / 0.45
		if fade <= 0 then
			playing[fx] = nil
			releaseEffect(fx, true)
			return
		end
	end
	fx.box:SetAlpha(clamp01(fade) * (fx.alpha or 1))
	local loopT = fx.looping and not def.loop and t > def.dur
	for _, layer in ipairs(fx.layers) do
		local L = layer.def
		if layer.book then
			local b = layer.book
			local bd = b.def
			local lt = t - (L.t0 or 0)
			if loopT and def.loopBook then
				if b.name ~= def.loopBook then
					b.name = def.loopBook
					b.def = BOOKS[def.loopBook]
					b.texSet, b.shown = false, nil
				end
				lt = t - def.dur
				bd = b.def
			elseif b.name ~= L.book then
				b.name = L.book
				b.def = BOOKS[L.book]
				b.texSet, b.shown = false, nil
				bd = b.def
			end
			local fr = floor(lt * bd.fps)
			if bd.loop or L.loop then
				fr = fr % bd.count
			elseif fr >= bd.count then
				fr = bd.count - 1
			end
			b.pos = max(0, fr)
			local w = size * (L.w or 1)
			b:SetSize(w, w)
			applyFrame(b)
			b.tex:SetAlpha(lt >= 0 and (L.a or 1) or 0)
		elseif layer.tex then
			local a = envelope(t, L.t0 or 0, L.t1, L.fin, L.fout)
			if L.pulse then a = a * (1 - L.pulse + L.pulse * sin(t * 3.2)) end
			a = a * (L.a or 1)
			if a <= 0.003 then
				layer.tex:Hide()
			else
				local s = 1
				if L.s0 then s = L.s0 + (L.s1 - L.s0) * easeOut((t - (L.t0 or 0)) / (L.sdur or 0.5)) end
				local w = size * (L.w or 1) * s
				layer.tex:SetSize(w, size * (L.h or L.w or 1) * s)
				if L.spin and LONE[L.part] then turn(layer.tex, (L.spin * t) * pi / 180) end
				layer.tex:SetAlpha(a)
				layer.tex:Show()
			end
		elseif layer.p then
			for _, p in ipairs(layer.p) do
				local lt = p.on and (t - (L.at or 0) - p.delay) or -1
				if not p.on or lt <= 0 or lt >= p.life then
					p.tex:Hide()
				else
					local k = L.drag or 0
					local d = (k > 0) and (p.v * (1 - exp(-k * lt)) / k) or (p.v * lt)
					local x = p.x0 + d * cos(p.a)
					local y = p.y0 + d * sin(p.a) + 0.5 * (L.grav or 0) * lt * lt
					local u = lt / p.life
					local a = (L.a or 1) * (1 - u) ^ 1.2
					if u < 0.08 then a = a * u / 0.08 end
					if L.twinkle then a = a * (0.55 + 0.45 * sin(p.tw + lt * 22)) end
					local s = size * p.size
					p.tex:SetSize(s, s)
					p.tex:ClearAllPoints()
					p.tex:SetPoint("CENTER", fx.box, "CENTER", x * size * 0.5, y * size * 0.5)
					if L.part == "coin" then
						local f = floor(p.frame + lt * p.fspd) % 8
						p.tex:SetTexCoord(frameCoords(SHEETS.coins, f))
						p.tex:SetAlpha(min(1, a * 1.6))
					else
						p.tex:SetAlpha(a)
					end
					p.tex:Show()
				end
			end
		end
	end
end

releaseEffect = function(fx, finished)
	playing[fx] = nil
	fx.box:Hide()
	fx.box:ClearAllPoints()
	pcall(fx.box.SetParent, fx.box, UIParent)
	local done = fx.opts and fx.opts.onDone
	fx.opts = nil
	pool[fx.name] = pool[fx.name] or {}
	table.insert(pool[fx.name], fx)
	driverOn()
	if finished and type(done) == "function" then
		local ok, err = pcall(done)
		if not ok then W.Error("fx onDone", err) end
	end
end

local Handle = {}
Handle.__index = Handle
function Handle:Stop(now_)
	local fx = self.fx
	if not fx or self.gen ~= fx.gen or not playing[fx] then return end
	if now_ then
		releaseEffect(fx, false)
	elseif not fx.fadeAt then
		fx.fadeAt = now()
	end
end
function Handle:IsPlaying()
	local fx = self.fx
	return fx ~= nil and self.gen == fx.gen and playing[fx] == true
end

local function start(name, parent, opts, fullscreen)
	opts = opts or {}
	local def = EFFECTS[name]
	if not def then return nil end
	local list = pool[name]
	local fx = list and table.remove(list)
	if not fx then
		-- none free: take over the oldest of this effect that is already fading out
		local oldest
		for other in pairs(playing) do
			if other.name == name and other.fadeAt and (not oldest or other.fadeAt < oldest.fadeAt) then oldest = other end
		end
		if oldest then
			releaseEffect(oldest, false)
			fx = table.remove(pool[name])
		end
	end
	fx = fx or buildEffect(name, parent)
	fx.gen = (fx.gen or 0) + 1
	local box = fx.box
	pcall(box.SetParent, box, parent or UIParent)
	box:ClearAllPoints()
	box:SetPoint("CENTER", parent or UIParent, "CENTER", W.Num(opts.x) or 0, W.Num(opts.y) or 0)
	fx.size = W.Num(opts.size) or def.size
	box:SetSize(fx.size, fx.size)
	call(box, "SetScale", W.Num(opts.scale) or 1)
	if fullscreen then
		call(box, "SetFrameStrata", "LOW")
		call(box, "SetFrameLevel", 1)
		fx.alpha = min(FULL_ALPHA, W.Num(opts.alpha) or FULL_ALPHA)
	else
		local pl = W.Num(call(parent, "GetFrameLevel")) or 1
		call(box, "SetFrameLevel", pl + (W.Num(opts.level) or 3))
		fx.alpha = clamp01(W.Num(opts.alpha) or 1)
	end
	call(box, "EnableMouse", false)
	resetEffect(fx, opts)
	box:SetAlpha(0)
	box:Show()
	playing[fx] = true
	ensureDriver()
	driverOn()
	return setmetatable({ fx = fx, gen = fx.gen, name = name }, Handle)
end

-- Plays an effect on a frame. Crown/badge names give their persistent frame instead.
function FX.Play(name, parent, opts)
	if type(name) ~= "string" then return nil end
	local ok, res = pcall(function()
		opts = type(opts) == "table" and opts or {}
		if name == "crown" then
			local c = FX.Crown(parent, opts.size or 32, opts.seed)
			if c then c:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0) end
			return c
		end
		local bid = name:match("^badge_(%w+)$")
		if bid then
			local b = FX.Badge(parent, bid, opts.size or 20)
			if b then b:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0) end
			return b
		end
		if FX.Mode() == "off" then return nil end
		if opts.gold then name = FX.Goldify(name, true) end
		if not EFFECTS[name] then return nil end
		return start(name, parent or UIParent, opts, false)
	end)
	if ok then return res end
	W.Error("fx play", res)
	return nil
end

local function screenHeight()
	local h = W.Num(call(UIParent, "GetHeight"))
	if not h or h <= 0 then h = 768 end
	return h
end

local fullscreen = {} -- running screen effects, so a new one replaces the old

-- A screen moment, centred and click-through, under Wuber's window and the game's popups.
function FX.Fullscreen(name, opts)
	if type(name) ~= "string" then return nil end
	local ok, res = pcall(function()
		opts = type(opts) == "table" and opts or {}
		local mode = FX.Mode()
		if mode == "off" or mode == "light" or W.InCombat() then return nil end -- Light: no full-screen effects
		if opts.gold then name = FX.Goldify(name, true) end
		local def = EFFECTS[name]
		if not def then return nil end
		local o = {}
		for k, v in pairs(opts) do o[k] = v end
		local h = screenHeight()
		o.size = W.Num(opts.size) or min(def.size * 1.9, h * 0.55)
		if name == "coins" then o.size = W.Num(opts.size) or h * 0.8 end
		if name == "paid" then o.size = W.Num(opts.size) or h * 0.24 end
		if o.loop and not o.hold then o.hold = 3 end
		o.y = W.Num(opts.y) or (name == "coins" and h * 0.05 or h * 0.06)
		for h_ in pairs(fullscreen) do
			if h_:IsPlaying() then h_:Stop(true) end
			fullscreen[h_] = nil
		end
		local handle = start(name, UIParent, o, true)
		if handle then fullscreen[handle] = true end
		return handle
	end)
	if ok then return res end
	W.Error("fx fullscreen", res)
	return nil
end

function FX.StopAll(fast)
	for h in pairs(fullscreen) do
		pcall(h.Stop, h, fast)
		fullscreen[h] = nil
	end
end

-- Settings changed: every flipbook re-checks whether it moves; "off" ends screen effects.
function FX.Refresh()
	if FX.Mode() == "off" then
		FX.StopAll(true)
		local live = {}
		for fx in pairs(playing) do live[#live + 1] = fx end -- snapshot: release edits playing
		for _, fx in ipairs(live) do pcall(releaseEffect, fx, false) end
	end
	for book in pairs(books) do
		if book.kind ~= "layer" then pcall(refreshBook, book) end
	end
end

-- Counts, for the self-test and the tests.
function FX.Stats()
	local n = 0
	for _ in pairs(playing) do n = n + 1 end
	local w = 0
	for _ in pairs(waiting) do w = w + 1 end
	return { live = liveCount, waiting = w, playing = n, driver = driver ~= nil and W.Plain(call(driver, "IsShown")) == true }
end

---------------------------------------------------------------------------
-- Optional: a real game model in a ModelScene (hidden flag W.db.fxModels, off by default)
---------------------------------------------------------------------------

local modelFailed = false
function FX.Model(parent, size, fileID)
	if modelFailed or not (W.db and W.db.fxModels == true) then return nil end
	fileID = W.Num(fileID)
	if not fileID then return nil end
	local ok, res = pcall(function()
		local scene = CreateFrame("ModelScene", nil, parent or UIParent)
		scene:SetSize(W.Num(size) or 128, W.Num(size) or 128)
		call(scene, "EnableMouse", false)
		local actor = scene:CreateActor()
		if not actor or not actor:SetModelByFileID(fileID) then error("no model") end
		return scene
	end)
	if ok and res then return res end
	modelFailed = true -- never tried again this session
	return nil
end
