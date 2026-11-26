-- Module: Net.Portal
-- Purpose: the live portal tracker's wire (kind G, driver -> rider), the two-word passphrase, and
--   the founder's genuine gold portal check (W.FounderSummon; W.ride.summonedBy at CONFIRM_SUMMON).
-- API: W.SendRitual, W.Passphrase, W.PASS_WORDS, W.FounderSummon
-- Internals: ADJ, NOUN, PHASES, PK, out, heardCount, groupMember, foreignRealm, trustedCaster,
--   casterOf, sendNow, prune; hook slot heard (kind G, called by Net.Base's W.NetKind handler)
-- Uses: Net.Base, Net.Transport, Net.Requests
-- Later: (none)
-- Events: listens (none); fires RITUAL
-- Standalone: no
-- Test: tests/net/portal_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 sections 5.7, 5.10, 5.13; owner E)
--
-- Kind G (whisper, driver -> rider; SPEC7 5.10):
--   G~1~<rideId>~<phase q|t|c|h|s|f>~<tapped 0-9>~<need 0-9>~<caster <=24>~<danger 0-2>  (<= 45 bytes)
-- The network driver's window (Drive.Kitchen) calls W.SendRitual on each change. It goes only to
-- a rider whose R said 2.3.0 or later (field 6, kept by Net.Requests), on change only, at least
-- 1.5 s apart per ride (a newer one waits and replaces the older; "s" and "f" go at once), at
-- most 15 per ride, through the one outbox (a queued G for the same ride is replaced there too).
-- The rider believes a G only from its ride's driver, with its ride id, after the A; it is kept
-- in W.ride.ritual (session only) and fires RITUAL(ritual, ride).
--
--   W.SendRitual(rideId, buyer, phase, tapped, need, caster, danger) -> true when sent or waiting
--   W.Passphrase(rideId, riderKey) -> "Violet Otter" (nil without both)
--   W.FounderSummon(r, what) -> true only for a genuine founder's summon (any doubt: false = violet)

local _, W = ...
local Mod = W.Module("Net.Portal", { "Net.Base", "Net.Transport", "Net.Requests" })
local BaseMod = W.Mod("Net.Base")
local RequestsMod = W.Mod("Net.Requests")
local ENDED, address, clamp, localInt, myKey = BaseMod.ENDED, BaseMod.address, BaseMod.clamp, BaseMod.localInt, BaseMod.myKey
local netInt, now, rideId = BaseMod.netInt, BaseMod.now, BaseMod.rideId
local verByRide = RequestsMod.verByRide
local str = W.Str

local PHASES = { q = true, t = true, c = true, h = true, s = true, f = true }
local PK = { GAP = 1.5, MAX_SENT = 15, MAX_HEARD = 40, KEEP = 40, MIN_VER = "2.3.0" }

-- The G caster's key. Drive.Kitchen sends a short name (W.Short: "Anita"): a name without a
-- space stands for the ride's payee or driver only when it is that full name or its first word
-- (then that full name's key); a short name that is neither: false (doubt).
local function casterOf(r, rit)
	local name = str(rit.caster)
	if not name then return rit.casterKey end
	if name:find(" ", 1, true) then return W.Key(name) end
	local k = W.Key(name)
	for _, field in ipairs({ "payee", "driver" }) do
		local fk = str(r[field]) and W.Key(str(r[field]))
		if fk and k and (fk == k or fk:match("^%S+") == k) then return fk end
	end
	return false
end

---------------------------------------------------------------------------
-- Driver side: sending G
---------------------------------------------------------------------------

local out = {}      -- rideId -> { key, addr, sent, at, sig, pending, waiting }
local outOrder = {}

local function prune(id)
	if out[id] then return end
	outOrder[#outOrder + 1] = id
	if #outOrder > PK.KEEP then out[table.remove(outOrder, 1)] = nil end
end

local function sendNow(id, s, args)
	if s.sent >= PK.MAX_SENT then
		s.pending = nil
		return false
	end
	local sent = W.SendTo(s.addr, "G", id, args[1], args[2], args[3], args[4], args[5])
	if sent then
		s.sent, s.at, s.sig = s.sent + 1, now(), args.sig
	end
	s.pending = nil
	return sent
end

-- The driver tells an app rider how the summon is going (kind G). phase: q in the queue, t
-- greeted / targeted, c casting, h a clicker tapped, s summon sent, f the summon failed.
-- tapped / need: clickers so far / needed (0-9); caster: who casts (a name, <= 24 bytes);
-- danger: the PvP level 0-2. Returns true when sent (or waiting for its 1.5 s), false when not
-- for this rider (no 2.3.0 R from them), unchanged, over the cap or bad.
function W.SendRitual(id, buyer, phase, tapped, need, caster, danger)
	id = rideId(id)
	local addr = address(buyer)
	local key = W.Key(addr)
	phase = str(phase)
	if not (id and key and phase and PHASES[phase]) then return false end
	local v = verByRide[id]
	if not (v and v.key == key and W.VerAtLeast(v.ver, PK.MIN_VER)) then return false end
	tapped = clamp(localInt(tapped) or 0, 0, 9)
	need = clamp(localInt(need) or 0, 0, 9)
	caster = W.CleanName(str(caster)) or ""
	caster = W.Clean(caster, 24)
	danger = clamp(localInt(danger) or 0, 0, 2)
	local s = out[id]
	if s and s.key ~= key then return false end -- (another rider with the same id: never)
	if not s then
		prune(id)
		s = { key = key, addr = addr, sent = 0 }
		out[id] = s
	end
	s.addr = addr
	local args = { phase, tapped, need, caster, danger }
	args.sig = table.concat(args, "|")
	if s.pending and s.pending.sig == args.sig then return true end
	if not s.pending and s.sig == args.sig then return false end -- on change only
	if s.sent >= PK.MAX_SENT then return false end
	local wait = s.at and (PK.GAP - (now() - s.at)) or 0
	if phase == "s" or phase == "f" or wait <= 0 then return sendNow(id, s, args) end
	s.pending = args -- the newest replaces one still waiting
	if not s.waiting then
		s.waiting = true
		W.After(wait, function()
			s.waiting = nil
			if s.pending then sendNow(id, s, s.pending) end
		end)
	end
	return true
end

---------------------------------------------------------------------------
-- Rider side: hearing G
---------------------------------------------------------------------------

local heardCount = {} -- rideId -> G heard (at most 40 believed per ride)

-- G: rideId, phase, tapped, need, caster, danger (Net.Inbox: by whisper only)
function Mod.heard(addr, name, key, f, chan)
	if chan ~= "WHISPER" then return end
	local r = W.ride
	local id = rideId(f[1])
	if not (r and id and r.id == id and r.driverKey == key and r.acceptedAt) or ENDED[r.state] then return end
	local phase = f[2]
	if not (phase and PHASES[phase]) then return end
	local n = (heardCount[id] or 0) + 1
	if n > PK.MAX_HEARD then return end
	heardCount[id] = n
	local caster = W.CleanName(f[5] or "")
	caster = caster and W.Key(caster) and caster or nil
	r.ritual = {
		phase = phase,
		tapped = netInt(f[3], 0, 9, 0),
		need = netInt(f[4], 0, 9, 0),
		caster = caster, -- (as sent: Drive.Kitchen's short name)
		casterKey = caster and casterOf(r, { caster = caster }) or nil, -- the full name's key; nil: doubt
		danger = netInt(f[6], 0, 2, 0),
		at = now(),
	}
	W.Fire("RITUAL", r.ritual, r)
end

---------------------------------------------------------------------------
-- The passphrase (SPEC7 5.7): two friendly words from the ride id and the rider; both sides
-- work it out alone, nothing is sent
---------------------------------------------------------------------------

local ADJ = {
	"Violet", "Amber", "Azure", "Crimson", "Golden", "Silver", "Jade", "Copper",
	"Ivory", "Emerald", "Scarlet", "Cobalt", "Coral", "Indigo", "Teal", "Bronze",
	"Pearl", "Ruby", "Sapphire", "Topaz", "Opal", "Russet", "Saffron", "Mossy",
	"Frosty", "Sunny", "Misty", "Starry", "Breezy", "Mellow", "Gentle", "Brave",
	"Clever", "Jolly", "Lucky", "Merry", "Nimble", "Plucky", "Quiet", "Swift",
	"Sleepy", "Cosy", "Bright", "Calm", "Happy", "Kind", "Proud", "Witty",
	"Bold", "Rosy", "Dusky", "Lunar", "Solar", "Arcane", "Stormy", "Snowy",
	"Leafy", "Sandy", "Velvet", "Cheery", "Dapper", "Noble", "Steady", "Wise",
}
local NOUN = {
	"Otter", "Murloc", "Gryphon", "Wyvern", "Kodo", "Raptor", "Owl", "Turtle",
	"Hawk", "Fox", "Wolf", "Bear", "Stag", "Hare", "Moth", "Beetle",
	"Toad", "Frog", "Crab", "Seal", "Whelp", "Drake", "Sprite", "Wisp",
	"Treant", "Furbolg", "Gnome", "Moonkin", "Strider", "Mammoth", "Yak", "Panda",
	"Lynx", "Sparrow", "Robin", "Heron", "Crane", "Swan", "Badger", "Squirrel",
	"Mouse", "Rabbit", "Kitten", "Pony", "Talbuk", "Elekk", "Phoenix", "Nightsaber",
	"Lobster", "Penguin", "Walrus", "Snail", "Lizard", "Parrot", "Raven", "Tiger",
	"Panther", "Ram", "Goat", "Firefly", "Dragonfly", "Hedgehog", "Owlet", "Tortoise",
}
W.PASS_WORDS = { adj = ADJ, noun = NOUN } -- (for the tests: every pair is checked)

-- The two words both sides show for one ride: h = (h * 31 + byte) % 2147483647 over
-- rideId .. "|" .. riderKey (no bit library), then ADJ[h % 64 + 1] .. " " .. NOUN[floor(h / 64)
-- % 64 + 1]. riderKey may be a name: it is made a key first. nil without both.
function W.Passphrase(id, riderKey)
	id, riderKey = str(id), W.Key(str(riderKey))
	if not id or id == "" or not riderKey then return nil end
	local s = id .. "|" .. riderKey
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return ADJ[h % 64 + 1] .. " " .. NOUN[math.floor(h / 64) % 64 + 1]
end

---------------------------------------------------------------------------
-- The founder's gold portal (SPEC7 5.13): never on a name in a message alone
---------------------------------------------------------------------------

-- Whether a group member's name as the game gives it carries another realm ("Name-Realm",
-- or a second part that is a realm rather than a surname).
local function foreignRealm(first, second)
	if second and W.IsRealmTail(second) then return true end
	local full = second and (first .. " " .. second) or first
	if full:match("^%S+ %S+%-.+$") then return true end
	local tail = full:match("%-([^%-]+)$")
	return tail ~= nil and W.IsRealmTail(tail)
end

-- Whether this key is in my party or raid now, under a name of my own realm.
local function groupMember(key)
	if type(UnitName) ~= "function" then return false end
	local units = {}
	for i = 1, 4 do units[#units + 1] = "party" .. i end
	for i = 1, 40 do units[#units + 1] = "raid" .. i end
	for _, unit in ipairs(units) do
		local ok, first, second = pcall(UnitName, unit)
		first, second = ok and str(first) or nil, ok and str(second) or nil
		if first then
			local full = second and (first .. " " .. second) or first
			if W.Key(full) == key or W.Key(first) == key then return not foreignRealm(first, second) end
		end
	end
	return false
end

-- Who cast the ride's summon, from the ride's trusted messages only: the G caster (from the
-- ride's driver), the S payee (the same), else the driver. Two that disagree: nil (doubt).
local function trustedCaster(r)
	local g = nil
	if type(r.ritual) == "table" then g = casterOf(r, r.ritual) end
	if g == false then return nil end -- (a short name that is neither payee nor driver: doubt)
	local p = r.payee and W.Key(str(r.payee)) or nil
	if g and p and g ~= p then return nil end
	return g or p or (r.driverKey and W.Key(str(r.driverKey))) or nil
end

-- true only when the ride's summoner is a genuine founder: a W.CREATOR name (W.IsCreator: on
-- the founders' ruleset) taken from the ride's trusted messages, in my group under a name of my
-- realm, and (once the game's summon box named its caster, W.ride.summonedBy, and always for
-- what = "arrival") the same person the game named. r.own (the founder's own screen): the
-- caster is me, a founder character on the founders' ruleset. Any doubt: false (violet).
function W.FounderSummon(r, what)
	if type(r) ~= "table" then return false end
	local me = myKey()
	if not W.OnFounderRuleset() then return false end
	if r.own then
		local c = r.caster and W.Key(str(r.caster)) or me
		return c == me and W.IsCreator(me)
	end
	local caster = trustedCaster(r)
	if not caster or caster == me or not W.IsCreator(caster) then return false end
	if not groupMember(caster) then return false end
	local by = r.summonedBy and W.Key(str(r.summonedBy)) or nil
	if what == "arrival" and not by then return false end
	if by and by ~= caster then return false end
	return true
end
