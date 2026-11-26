-- The layout checker's Daylight pass (job 211, group C): one extra run with the fake Daylight UI pack loaded
-- (tests/lib/fakes_daylight.lua, job 206 BS2: a skin that resizes and moves the game's flight map after it opens, and a
-- "Flying to" bar at the top of the screen) over the flight screens: the flight map with Wuber's price tags, and the
-- in-flight card. At each stage E.check runs as in the tour (so the covered kind too, when tools/layout-check.lua wraps
-- E.check), and one more rule: a Wuber frame drawn over a Daylight frame (kind "daylight"). Every shot id starts with
-- "daylight/", so a problem here is told from the tour's.
--   local D = dofile(root .. "/tests/layout/daylight.lua")(H, E, root)
--   D.config({ w, h, ui, scale }, {}) -> { hits, errors, broken, notes, words, shots, secs }   (as tests/layout/run.lua)
local H, E, root = ...
local S = H.state
local D = {}
local ALLOW = dofile(root .. "/tests/layout/allow.lua")
local Daylight = dofile(root .. "/tests/lib/fakes_daylight.lua")
local TL = dofile(root .. "/tools/preview/textlayout.lua")

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

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}

local function rectOf(f)
	local r = H.rect(f)
	if not r or r.w <= 0 or r.h <= 0 then return nil end
	return { l = r.l, b = r.b, r = r.l + r.w, t = r.b + r.h }
end

-- Wuber frames drawn over a Daylight frame that is shown (kind "daylight"): the two share the screen
local function overlapHits(c)
	local out, foreign = {}, {}
	for _, f in ipairs(c.frames) do
		local nm = S[f].name
		if nm and nm:find("^DaylightUI") and H.visible(f) and (f:GetEffectiveAlpha() or 0) > 0.05 and rectOf(f) then foreign[#foreign + 1] = f end
	end
	for _, f in ipairs(c.frames) do
		local nm = S[f].name
		if nm and nm:find("^Wuber") and H.visible(f) and (f:GetEffectiveAlpha() or 0) > 0.05 and E.tagOf(f) == "Wuber" then
			local a = rectOf(f)
			-- (the Wuber frames of the flight: the in-flight card, the price tags' holder is a whole-map layer and is not a card)
			if a and (nm == "WuberInFlight") then
				for _, g in ipairs(foreign) do
					local b = rectOf(g)
					if a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t then
						out[#out + 1] = { kind = "daylight", what = nm, detail = nm .. " is drawn over " .. S[g].name, key = nm .. " over " .. S[g].name }
					end
				end
			end
		end
	end
	return out
end

local function record(res, shot, hits)
	local seen = {}
	for _, h in ipairs(hits) do
		local k = h.kind .. "|" .. h.key
		if not seen[k] then
			seen[k] = true
			h.shot = shot
			h.allowed, h.known = allowed(shot, h)
			res.hits[#res.hits + 1] = h
		end
	end
	res.shots = res.shots + 1
end

function D.config(cfg, opts)
	local t0 = os.clock()
	local res = { hits = {}, errors = {}, broken = {}, notes = {}, words = {}, shots = 0 }
	local unitH = 768 / cfg.ui
	local unitW = cfg.w / cfg.h * unitH
	H.textMetrics = TL
	TL.PX = cfg.h / unitH
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	if TL.resetCache then TL.resetCache() end
	TL.STRETCH = 1
	E.tag({ Wuber = H.ADDONS.Wuber })
	local w = H.NewWorld({})
	local r = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber" },
		screenW = unitW, screenH = unitH, physW = cfg.w, physH = cfg.h })
	w:advance(15)
	local W = r.W
	W.db.scale = cfg.scale
	if W.UI and W.UI.ApplyScale then pcall(W.UI.ApplyScale) end
	-- a driver to Tarren Mill (so the map shows a price tag) and a known flight time (so the card shows a time)
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3,
		service = "Mia Runner's Rides", heard = r.env.GetTime() }
	W.db.flights = W.db.flights or {}
	W.db.flights["H|undercity|tarren mill"] = { t = 240, tat = r.env.time(), tsrc = "own" }
	local errs = #w.errors
	local function stage(id)
		local ok, hits = pcall(E.check, r, { TL = TL })
		if not ok then res.broken[#res.broken + 1] = "daylight/" .. id .. ": the checker threw: " .. tostring(hits) return end
		for _, h in ipairs(overlapHits(r)) do hits[#hits + 1] = h end
		record(res, "daylight/" .. id, hits)
	end
	local okRun, why = pcall(function()
		Daylight.attach(H, w, r, { flightTimer = true, unitFrames = true, taxiDelay = 0.2, moveTo = { 180, -80 } })
		w:openTaxiMap(r, UC_TM)
		w:advance(0.5)
		stage("flightmap")
		w:fly(r, 2, 240, "Tarren Mill")
		w:advance(3)
		stage("inflight")
		w:advance(245)
	end)
	if not okRun then res.broken[#res.broken + 1] = "daylight: " .. tostring(why) end
	for i = errs + 1, #w.errors do res.errors[#res.errors + 1] = tostring(w.errors[i]):match("^[^\n]*") end
	res.secs = os.clock() - t0
	return res
end

return D
