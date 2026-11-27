-- Proof tests of job 2620 (audit-241), pass 3, area H: Driver screens with many entries.
local T = ...
local test = T.test
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
local H, ok = T.H, T.ok

-- Promise: every line of the Blocked list is whole. A rider the addon blocked itself (left owing, Settings default on)
-- shows "<reason> (<amount>) · <date>" under the name; it must fit its room, or wrap, never end in a cut.
proof("AU24-34", "Blocked list: the reason line of a rider who left owing is not cut", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR, D = a.W.Drive, a.W.Driver
	DR.SetOpt("autoBlock", true)
	pcall(T.openDrive, a)
	local c = { name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1, caster = a.W.myKey }
	DR.NonPayer(c)
	w:advance(1)
	ok(DR.BlockEntry("dan rider"), "setup: the non-payer is on the blocked list")
	D.ShowScreen("blocked") w:advance(1)
	local s = a.W.UI.drive.screens.blocked
	local r = s.rows.list[1]
	ok(r and r:IsShown(), "setup: a row is listed")
	local cut = H.truncation(r.why)
	ok(cut == nil, "the line is cut: '" .. tostring(r.why:GetText()) .. "' in " .. tostring(r.why:GetWidth()) .. " px")
	T.clean(w)
end)
