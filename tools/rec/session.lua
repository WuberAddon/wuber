-- tools/rec/session.lua: one saved WuberRec session (WuberRecDB.sessions[i], as the recorder addon
-- wrote it) -> the plain table the fixtures, the conformance tests and the replay use.
--
--   local SES = dofile("tools/rec/session.lua")
--   local fx = SES.convert(savedSession, "sim" | "game")
--
-- The saved form keeps events and snapshots in rings (events[((n - 1) % cap) + 1], n = rows ever
-- written) and rows as flat arrays; this unrolls the rings in time order and names the fields:
--   fx.events[i] = { t = seconds since the session began, e = "EVENT", n = argument count,
--                    a = { [1..n] } (a "<nil>" marker becomes a real nil; "<secret>" and "<->"
--                    (dropped by the privacy rules) stay as those strings; chat text is
--                    { len, w }, a system line { gs, a } or { len, w }),
--                    gap = rows only counted before this one, spell, db, wdb, li (login rows) }
--   fx.snaps[i]  = { t, id, why, d = the snapshot's table, err }
-- Snapshots kept beside the ring (session.once: client, atlas, settings, the newest screen) are in
-- fx.snaps too, at their own time.
-- Everything else (char, why, stop, seen, skip, shapes, unknownEvents, err, snapErr, boot, caps,
-- epoch, id, rec, data) is copied. fx.format = 1, fx.kind = "rec", fx.source as given,
-- fx.dropped = { events, snaps } rows lost to the rings.
-- Pure Lua 5.1, no I/O: safe to load anywhere.

local SES = {}
SES.NIL, SES.SECRET, SES.DROPPED = "<nil>", "<secret>", "<->"

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end
SES.copy = copy

-- the rows of a ring, oldest first: { rows, dropped }
local function unroll(ring, n, cap)
	local out = {}
	ring = type(ring) == "table" and ring or {}
	n = tonumber(n) or 0
	cap = tonumber(cap) or n
	if cap < 1 then cap = math.max(n, 1) end
	local kept = math.min(n, cap)
	local first = n - kept + 1
	for i = first, n do
		local row = ring[((i - 1) % cap) + 1]
		if type(row) == "table" then out[#out + 1] = row end
	end
	return out, n - kept
end
SES.unroll = unroll

local function byTime(a, b)
	if a.t ~= b.t then return a.t < b.t end
	return a.i < b.i
end

function SES.convert(s, source)
	assert(type(s) == "table", "a saved session (a table)")
	local caps = type(s.caps) == "table" and s.caps or {}
	local fx = { format = 1, kind = "rec", source = source or "game" }
	for _, k in ipairs({ "id", "char", "realm", "class", "faction", "why", "stop", "ended", "epoch", "rec", "data", "v", "asked", "untilEpoch", "sinceLoad" }) do fx[k] = s[k] end
	for _, k in ipairs({ "seen", "skip", "shapes", "unknownEvents", "err", "snapErr", "boot", "caps" }) do fx[k] = copy(s[k]) end
	local evs, dropE = unroll(s.events, s.n, caps.events)
	local sns, dropS = unroll(s.snaps, s.sn, caps.snaps)
	-- the once-a-session snapshots are kept beside the ring (session.once[id]): they join the list here
	if type(s.once) == "table" then
		local ids = {}
		for id in pairs(s.once) do ids[#ids + 1] = tostring(id) end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local row = s.once[id]
			local dup = false
			for _, r in ipairs(sns) do
				if r == row or (r[1] == row[1] and r[2] == row[2]) then dup = true end
			end
			if type(row) == "table" and not dup then sns[#sns + 1] = row end
		end
	end
	fx.dropped = { events = dropE, snaps = dropS }
	fx.events, fx.snaps = {}, {}
	for i, row in ipairs(evs) do
		local n = tonumber(row[3]) or 0
		local e = { t = tonumber(row[1]) or 0, e = tostring(row[2]), n = n, a = {}, i = i }
		for j = 1, n do
			local v = row[3 + j]
			if v == SES.NIL then v = nil end
			e.a[j] = copy(v)
		end
		for k, v in pairs(row) do
			if type(k) == "string" then e[k] = copy(v) end
		end
		fx.events[#fx.events + 1] = e
	end
	table.sort(fx.events, byTime)
	for i, row in ipairs(sns) do
		fx.snaps[#fx.snaps + 1] = { t = tonumber(row[1]) or 0, id = tostring(row[2]), why = row[3], d = copy(row[4]) or {}, err = row.err, i = i }
	end
	table.sort(fx.snaps, byTime)
	for _, list in ipairs({ fx.events, fx.snaps }) do
		for _, r in ipairs(list) do r.i = nil end
	end
	return fx
end

return SES
