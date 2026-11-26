-- The layout checker's runs (tools/layout-check.lua; BRIEF21 S11): one game window and Wuber size, the photo
-- tour of Wuber Lab with E.check at every shot, then the late-font scenes (the font arrives after login).
--   local Run = dofile("tests/layout/run.lua")(H, E, root)
--   Run.config({ w, h, ui, scale }, { screens = { "trips", "side:driver" }, scenes = true })
--     -> { hits, errors, broken, notes, words, shots, secs }   (words: { shot, n, budget, kind } per tour shot: the word rule)
--   errors: Lua errors in the fake game; broken: the run itself went wrong (the checker threw, the tour did not
--   finish, a screen errored or a wanted screen got no shot); notes: the rest (a page that doesn't unfold here)
--   Run.shotList() -> { { id, side, title, views } }
local H, E, root = ...
local S = H.state
local Run = {}
local ALLOW = dofile(root .. "/tests/layout/allow.lua")
local WORDS = dofile(root .. "/tests/layout/words.lua")
local TYPE = dofile(root .. "/tests/layout/type.lua")

local TL = dofile(root .. "/tools/preview/textlayout.lua")
-- (speed) the same words are measured again and again while the tour lays its screens out: remember each answer
-- (TL.PX / SNAP are fixed for a run; the caches start empty for each run)
do
	local width, layout = TL.width, TL.layout
	local wc, lc = {}, {}
	function TL.resetCache() wc, lc = {}, {} end
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
end
-- every widget knows which addon's code made it (only Wuber's are checked)
E.tag({ Wuber = H.ADDONS.Wuber, WuberLab = H.ADDONS.WuberLab })

local function norm(p) return (tostring(p):gsub("\\", "/")) end

-- the world: the lab's tour client, at the game window's size in UIParent units
local function newClient(cfg, name, opts)
	local unitH = 768 / cfg.ui
	local unitW = cfg.w / cfg.h * unitH
	-- the tour: the shipped fonts' real metrics (tools/preview). The late-font scenes: the harness's own text
	-- rule, which models a string laid out before the font loaded (H.truncation's stale; button_test.lua)
	H.textMetrics = not (opts and opts.fontLate) and TL or nil
	TL.PX = cfg.h / unitH
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	TL.resetCache()
	local w = H.NewWorld({})
	if opts and opts.fontLate then w.fontReadyAt = (w.time or 0) + 25 end
	if not (opts and opts.alone) then w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" }) end
	local c = w:addClient(name or "Anita Lift", { spot = (opts and opts.spot) or "Undercity", class = "WARLOCK", money = 100000,
		addons = (opts and opts.addons) or { "Wuber", "WuberLab" }, screenW = unitW, screenH = unitH, physW = cfg.w, physH = cfg.h })
	-- the chat frame where the game puts it
	local chat = c.env.DEFAULT_CHAT_FRAME
	if chat then
		chat:ClearAllPoints()
		chat:SetPoint("BOTTOMLEFT", c.env.UIParent, "BOTTOMLEFT", 32, 95)
		chat:SetSize(430, 120)
	end
	return w, c
end

local function sizes(c, cfg)
	local W = c.W
	W.db.scale = cfg.scale
	local DR = W.Drive
	if DR and type(DR.SetScale) == "function" then pcall(DR.SetScale, cfg.scale) end
	if W.UI and type(W.UI.ApplyScale) == "function" then pcall(W.UI.ApplyScale) end
end

-- does a selector list take this screen? (an id, an id prefix, side:<side>)
local function wanted(sel, s)
	if not sel then return true end
	for _, x in ipairs(sel) do
		local side = x:match("^side:(.*)$")
		if side then
			if s.side == side then return true end
		elseif s.id == x or s.id:sub(1, #x) == x then return true end
	end
	return false
end
Run.wanted = wanted

local function allowed(shot, h)
	for _, a in ipairs(ALLOW) do
		if (not a.kind or a.kind == h.kind) and (not a.screen or shot:find(a.screen)) and (not a.key or h.key:find(a.key))
			and (not a.what or h.what:find(a.what)) and (not a.detail or h.detail:find(a.detail)) then
			if a.known then return a.known, true end
			return a.reason or "allowed"
		end
	end
	return nil
end
Run.allowed = allowed

-- the word rule: one "words" hit when the shot shows more words than its kind's budget; res.words gets a line per shot
function Run.wordHit(shot, n)
	local kind, budget = WORDS.budget(shot)
	local hit
	if n > budget then
		hit = { kind = "words", what = shot, detail = ("%d words, budget %d (%s)"):format(n, budget, kind), key = "words" }
	end
	return hit, kind, budget
end

local function record(res, shot, hits, nwords, typeHits)
	local seen = {}
	for _, h in ipairs(typeHits or {}) do hits[#hits + 1] = h end
	if nwords then
		local hit, kind, budget = Run.wordHit(shot, nwords)
		res.words[#res.words + 1] = { shot = shot, n = nwords, budget = budget, kind = kind }
		if hit then hits[#hits + 1] = hit end
	end
	for _, h in ipairs(hits) do
		local k = h.kind .. "|" .. h.key
		if not seen[k] then
			seen[k] = true
			h.shot = shot
			h.allowed, h.known = allowed(shot, h)
			res.hits[#res.hits + 1] = h
		end
	end
end

local function errorsFrom(res, w, from)
	for i = from + 1, #w.errors do
		local e = tostring(w.errors[i])
		res.errors[#res.errors + 1] = e:match("^[^\n]*")
	end
	return #w.errors
end

-- The Lab's own tour shots for two Settings rows this tree removed for good ("Who summons" and "Report a bug"). The
-- Lab's shot list stays as it is for older branches, so the tour skips them here ("no setting called ..."): they are
-- neither a broken run nor asked for. Nothing else is ever listed here.
local GONE_SHOTS = { settings_summoner = true, settings_bug = true }

-- the tour at this size: E.check at each Screenshot()
local function tour(cfg, res, sel)
	local w, c = newClient(cfg)
	w:advance(15)
	local W = c.W
	W.db.rides[#W.db.rides + 1] = { dest = "Ratchet", driver = "Real Driver", price = 5000, at = 1700000000, stars = 4 }
	W.db.favs["real driver"] = true
	W.db.tipPct = 10
	W.db.fx = W.db.fx or "full"
	sizes(c, cfg)
	local L = c.ns.WuberLab
	if not (L and L.TourStart and L.PHOTO_SCREENS) then error("Wuber Lab has no photo tour (L.TourStart)") end
	-- (BRIEF25 L1) the tip card and the new World map: tests/layout/extra_screens.lua adds them when their modules exist
	do
		local ch = loadfile(root .. "/tests/layout/extra_screens.lua")
		if ch then
			local okx, X = pcall(ch)
			if okx and type(X) == "table" then
				if X.stubWorld then pcall(X.stubWorld, c) end
				local oki, why = pcall(X.install, L, W)
				if not oki then res.broken[#res.broken + 1] = "extra screens: " .. tostring(why) end
			end
		end
	end
	-- (BRIEF24 B2) the game's flight map, open at a flight master's: the lab's gated "bird" shot (Wuber's "Skip the
	-- bird" card, UI.Bird, beside the map) is taken in every sweep. The harness can't time flights: Wuber's own
	-- lookups are answered like tests/ui/bird_test.lua does. (Mia, the demo driver, summons to Thunder Bluff.)
	W.FlightCost = function(_, to) if to == "Thunder Bluff" then return 4700, 1 elseif to == "Crossroads" then return 300, 1 end end
	W.FlightTime = function(_, to) if to == "Thunder Bluff" then return 420, "est" elseif to == "Crossroads" then return 150, "est" end end
	-- the longest bird card: a 12-letter short name, "Thunder Bluff", gold+silver+copper, "about", the "really" branch
	do
		local drivers = W.UI.Drivers
		W.UI.Drivers = function(...)
			local out = {}
			for i, d in ipairs(drivers(...)) do
				local x = {}
				for k, v in pairs(d) do x[k] = v end
				if x.dest == "Thunder Bluff" or x.key == "mia runner" then x.short, x.dest, x.price = "Wolfgangbert", "Thunder Bluff", 1234567 end
				out[i] = x
			end
			return out
		end
	end
	w:openTaxiMap(c, { { name = "Orgrimmar, Durotar", type = "CURRENT", cost = 0, x = 0.6, y = 0.3 },
		{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 300, x = 0.5, y = 0.5 },
		{ name = "Thunder Bluff, Mulgore", type = "REACHABLE", cost = 500, x = 0.4, y = 0.6 } }) -- (rec: TaxiFrame, the frame the real client shows, at its measured size)
	local ids
	if res.screens then
		ids = {}
		for _, s in ipairs(L.PhotoScreens and L.PhotoScreens() or L.PHOTO_SCREENS) do if wanted(res.screens, s) and not GONE_SHOTS[s.id] and (s.id == "bird" or not s.need) then ids[#ids + 1] = s.id end end
		if #ids == 0 then return 0 end
	end
	local n, byShot, wordsOf, typeOf = 0, {}, {}, {}
	c.env.Screenshot = function()
		n = n + 1
		local ok, hits, _, nwords, fonts = pcall(E.check, c, { TL = TL })
		if not ok then res.broken[#res.broken + 1] = "the checker threw: " .. tostring(hits) hits = {} nwords = nil end
		byShot[n] = hits
		wordsOf[n] = nwords
		typeOf[n] = ok and TYPE.judge(fonts, TYPE.allowed(c)) or nil
		c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end)
	end
	c:slash("/lab")
	w:advance(1)
	W.UI.Toggle(true)
	w:advance(2)
	-- why the lab skipped a shot (its log line "skip i/n <id> <view>: <why>")
	local skips = {}
	local log = L.Log
	L.Log = function(area, msg, ...)
		if area == "photo" then
			local id, view, why = tostring(msg):match("^skip %d+/%d+ (%S+) (%S+): (.*)$")
			if id then skips[#skips + 1] = { id = id, view = view, why = why } end
		end
		if log then return log(area, msg, ...) end
	end
	local errs = #w.errors
	if not L.TourStart(ids and { only = ids, subset = "layout" } or nil) then error("the tour did not start") end
	for _ = 1, 4000 do
		if not L.Touring() then break end
		w:advance(0.5)
	end
	L.Log = log
	if L.Touring() then res.broken[#res.broken + 1] = "the tour was still running after 33 game minutes" end
	local pt = c.env.WuberLabDB and c.env.WuberLabDB.photoTour or {}
	local got = {}
	for k = 1, n do
		local r = (pt.shots or {})[k] or {}
		if r.id then got[r.id] = true end
		record(res, tostring(r.id or ("shot" .. k)) .. "/" .. tostring(r.view or "?"), byShot[k] or {}, wordsOf[k], typeOf[k])
	end
	-- a page that doesn't unfold at this size is the tour's rule (a note); any other skip is a broken run
	local fine = {}
	for _, s in ipairs(skips) do
		if GONE_SHOTS[s.id] then
			res.notes[#res.notes + 1] = "skipped " .. s.id .. " " .. s.view .. ": " .. s.why .. " (a shot this tree no longer has)"
		elseif s.why:find("doesn't unfold here", 1, true) or s.why:find("its folded shot was skipped", 1, true) then
			fine[s.id] = true
			res.notes[#res.notes + 1] = "skipped " .. s.id .. " " .. s.view .. ": " .. s.why
		else
			res.broken[#res.broken + 1] = "the tour skipped " .. s.id .. " " .. s.view .. ": " .. s.why
		end
	end
	local lt = L.lastTour or {}
	for _, s in ipairs(lt.missed or {}) do if not GONE_SHOTS[tostring(s):match("^[%w_]+")] then res.broken[#res.broken + 1] = "the tour took no shot of " .. tostring(s) end end
	for _, id in ipairs(ids or {}) do
		if not got[id] and not fine[id] then res.broken[#res.broken + 1] = "no shot of " .. id .. " (asked for)" end
	end
	errorsFrom(res, w, errs)
	return n
end

---------------------------------------------------------------------------
-- Scenes the tour can't show: the font arrives after login (BRIEF18: the Paused bar, "Advertis...")
---------------------------------------------------------------------------

local SCENES = {}
-- the floating Drive bar, open and Paused, the window never opened; the font arrives 25 s after login
SCENES[#SCENES + 1] = { id = "login_paused", side = "driver", run = function(cfg, res)
	local w, c = newClient(cfg, "Anita Lift", { fontLate = true, alone = true, addons = { "Wuber" }, spot = "Orgrimmar" })
	w:advance(15)
	sizes(c, cfg)
	local W = c.W
	if not (W.Driver and W.Driver.SetOnline and W.Driver.SetPaused) then return "no W.Driver.SetPaused" end
	W.Driver.SetOnline(true)
	W.Driver.SetPaused(true)
	w:advance(1)
	w:advance(math.max(0, w.fontReadyAt - w.time) + 3)
	return E.check(c, { TL = TL }), w
end }
-- the window opened on the Drive tab while the font loads, then it arrives
SCENES[#SCENES + 1] = { id = "login_drive", side = "driver", run = function(cfg, res)
	local w, c = newClient(cfg, "Anita Lift", { fontLate = true, alone = true, addons = { "Wuber" }, spot = "Orgrimmar" })
	w:advance(15)
	sizes(c, cfg)
	local W = c.W
	W.db.coach = true
	W.Char().wizard = true
	W.UI.Toggle(true)
	w:advance(2)
	if not W.UI.SelectTab then return "no W.UI.SelectTab" end
	W.UI.SelectTab("Drive")
	w:advance(2)
	w:advance(math.max(0, w.fontReadyAt - w.time) + 3)
	return E.check(c, { TL = TL }), w
end }

function Run.config(cfg, opts)
	opts = opts or {}
	local t0 = os.clock()
	local res = { hits = {}, errors = {}, broken = {}, notes = {}, words = {}, shots = 0, screens = opts.screens }
	TL.STRETCH = opts.stretch and (1 + opts.stretch / 100) or 1 -- (tools/layout-check.lua --stretch N)
	res.shots = tour(cfg, res, opts.screens)
	if opts.scenes ~= false then
		for _, sc in ipairs(SCENES) do
			if wanted(opts.screens, sc) then
				local ok, hits, w = pcall(sc.run, cfg, res)
				if not ok then res.broken[#res.broken + 1] = sc.id .. ": " .. tostring(hits)
				elseif type(hits) == "string" then res.notes[#res.notes + 1] = sc.id .. " skipped: " .. hits
				else
					record(res, sc.id .. "/folded", hits)
					res.shots = res.shots + 1
					if w then errorsFrom(res, w, 0) end
				end
			end
		end
	end
	res.secs = os.clock() - t0
	return res
end

function Run.shotList()
	local cfg = { w = 1920, h = 1080, ui = 1, scale = 1 }
	local w, c = newClient(cfg)
	local L = c.ns.WuberLab
	local out = {}
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do
		out[#out + 1] = { id = s.id, side = s.side or "?", title = s.title or "", views = (s.only == "unfolded" and "unfolded") or (s.unfold and "folded+unfolded") or "folded" }
	end
	for _, s in ipairs(SCENES) do out[#out + 1] = { id = s.id, side = s.side, title = "(scene) the font arrives after login", views = "folded" } end
	return out
end
Run.SCENES = SCENES

return Run
