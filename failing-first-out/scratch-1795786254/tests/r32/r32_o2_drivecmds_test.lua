local T = ...
-- Round 32 group O2 (HUNT-105, HUNT-106): /wuber drive status marks only real problems with the red
-- !!, and /wuber drive bell tells the refusal, not "Your alert character is ...", when it saves nothing.
local test, eq, ok = T.test, T.eq, T.ok

local function capture(W)
	local lines = {}
	W.Print = function(t) lines[#lines + 1] = tostring(t) end
	return lines
end

test("r32 o2: /wuber drive status: an information line (how whispers go out) is not marked !!", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local lines = capture(W)
	W.Drive.Command("status")
	local found
	for _, l in ipairs(lines) do
		if l:find("Whispers go out when you click the big button", 1, true) then found = l end
	end
	ok(found, "the whispers line is printed")
	ok(not found:find("!!", 1, true), "plain information has no !! mark: " .. tostring(found))
end)

test("r32 o2: /wuber drive status: a real problem still gets the !! mark", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.Readiness = function() return { { ok = false, text = "Something is wrong." }, { ok = true, text = "All fine." } } end
	local lines = capture(W)
	W.Drive.Command("status")
	local bad, good
	for _, l in ipairs(lines) do
		if l:find("Something is wrong.", 1, true) then bad = l end
		if l:find("All fine.", 1, true) then good = l end
	end
	ok(bad and bad:find("!!", 1, true), "problem marked")
	ok(good and not good:find("!!", 1, true), "ok line not marked")
end)

test("r32 o2: /wuber drive bell with a refused name prints the refusal, not the success line", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local DR = W.Drive
	local why = "Bea is in your crew - the alert character is a character on another account"
	DR.BellSet = function() return false, why end
	local lines = capture(W)
	DR.Command("bell Bea-Realm")
	local all = table.concat(lines, "\n")
	ok(all:find(why, 1, true), "refusal printed: " .. all)
	ok(not all:find("Your alert character is", 1, true), "no success line: " .. all)
end)

test("r32 o2: /wuber drive bell with an accepted name still says it is set", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.BellSet = function() return true end
	local lines = capture(W)
	W.Drive.Command("bell Zed-Realm")
	ok(table.concat(lines, "\n"):find("Your alert character is Zed-Realm.", 1, true), "success line")
end)
