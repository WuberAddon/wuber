-- Pass 3 proof tests of job 2620 (audit-241), area I: Rider screens.
local T = ...
local test = T.test
local ok, H = T.ok, T.H
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

proof("AU24-33", "every stop of the Custom tip picker has a tooltip", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local s = r.W.UI.state.screens.found
	ok(s.tipKeys[4]:IsShown(), "control: the Custom key shows (Advanced). Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	ok(s.tipKeys[1].wuberTip, "control: the quick keys have tips")
	s.tipKeys[4]:GetScript("OnClick")(s.tipKeys[4])
	w:advance(1)
	ok(s.pick:IsShown(), "the picker opens")
	local bare = 0
	for _, b in ipairs(s.pick.keys) do
		if b:IsShown() and not b.wuberTip then bare = bare + 1 end
	end
	ok(bare == 0, bare .. " of " .. #s.pick.keys .. " picker stops show no tooltip")
	T.clean(w)
end)
