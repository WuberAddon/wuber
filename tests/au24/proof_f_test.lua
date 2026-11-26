-- Proof tests (audit-241), area F: Driver side jobs.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Promise: a public line that ASKS for a summon with an unmistakable buyer word (wtb, lf, lfs) is a buyer
-- even when it also says "whisper me" / "ready" (as "pst me" and "w me" already do: an ad phrase counts only
-- when the line asks for nothing), and a line that sells (wts, selling, no buyer word) is never a buyer.
proof("AU24-03", "a buyer line (wtb/lf + a place) that says 'whisper me' or 'ready' is a buyer, not dropped as an advert", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	-- controls: the same lines with 'pst me' / 'w me' are read as buyers; sellers are never buyers
	eq(DR.PublicWant("wtb summon to org, pst me"), "match", "control: pst me")
	eq(DR.PublicWant("wtb summon to org w me"), "match", "control: w me")
	eq(DR.PublicWant("WTS summons to org, whisper me"), nil, "control: seller")
	eq(DR.PublicWant("Selling summons to org ready, whisper me"), nil, "control: seller")
	local buyers = {
		"wtb summon to org, whisper me", "LF summon to org, whisper me", "LFS org whisper me",
		"wtb summon org, ready now", "lf summon to org, I'm ready",
	}
	local dropped = {}
	for _, l in ipairs(buyers) do
		if DR.PublicWant(l) ~= "match" then dropped[#dropped + 1] = l end
	end
	eq(#dropped, 0, "buyer lines dropped: " .. table.concat(dropped, " | "))
end)

proof("AU24-03", "the public reader lists and invites a 'WTB summon to Orgrimmar, whisper me' buyer in Trade", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	local faction = (a.player and a.player.faction) or "Horde"
	for i, line in ipairs({ "WTB summon to Orgrimmar pls", "WTB summon to Orgrimmar, whisper me" }) do
		local name = "Linker" .. string.char(64 + i) .. " Test"
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		w:chatFrom(name, line, "CHANNEL", "Trade", faction)
		w:advance(0.5)
		ok(DR.customers[key(name)] ~= nil, "a row for the buyer: " .. line)
	end
	T.clean(w)
end)
