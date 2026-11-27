local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r32 d3: C09b-4: a founder hands out a driver last seen 40 days ago", function()
	local w = T.newWorld()
	local f = T.rider(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = f.W
	ok(W.AmFounder(), "setup: this client is a founder")
	local now = f.env.time()
	local dir = W.db.directory or {}
	W.db.directory = dir
	dir["fresh lock"] = { name = "Fresh Lock", lastSeen = now - 3600, ruleset = "EU-PvE" }
	dir["stale lock"] = { name = "Stale Lock", lastSeen = now - 40 * 86400, ruleset = "EU-PvE" }
	local names = W.DirectoryNames("some rider")
	local have = {}
	for _, n in ipairs(names) do have[n] = true end
	ok(have["Fresh Lock"], "control: the driver seen an hour ago is handed out")
	ok(not have["Stale Lock"], "a rider asking the founder is told about Stale Lock, a driver unseen for 40 days (names: " .. table.concat(names, ", ") .. ")")
	T.clean(w)
end)


test("r32 d3: C09b-5: a contact last heard 30 days ago is still asked (Q) after login", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local now = r.env.time()
	W.db.peers = W.db.peers or {}
	W.db.peers["fresh pal"] = { name = "Fresh Pal", addr = "Fresh Pal", at = now - 3600 }
	W.db.peers["old pal"] = { name = "Old Pal", addr = "Old Pal", at = now - 30 * 86400 }
	local have = {}
	for _, e in ipairs(W.Contacts()) do have[e.key] = true end
	ok(have["fresh pal"], "control: a contact from an hour ago is a contact")
	ok(not have["old pal"], "Old Pal, last heard 30 days ago (the limit is 14), is still a contact that gets whispered Qs")
	T.clean(w)
end)
