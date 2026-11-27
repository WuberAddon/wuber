-- Proof tests of job 2620 (audit-241), area H: Driver screens.
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
local eq, ok = T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Promise: Close asks "N riders are still with you" only about riders who are still with the driver.
-- A rider who has paid and left the group (state paid, gone) is a finished ride, listed only until the thanks goes.
proof("AU24-19", "Close does not say a rider who paid and left is still with you", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	local DR = d.W.Drive
	local c = DR.customers[key(T.TESTCHAR)]
	ok(c and c.state == "joined", "setup: Wuber is in the group")
	DR.SetState(c, "paid")
	c.gone = true -- he paid and left the group (Drive.Queue left(c)); the thanks can still go out
	d.W.Driver.SetOnline(false)
	w:advance(1)
	local env = d.env
	local shown = env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS")
	local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
	if shown then env.StaticPopup_Hide("WUBER_CLOSE_RIDERS") end
	ok(not shown, "asked: " .. tostring(dlg and dlg.text))
	T.clean(w)
end)

-- Promise: the minimap line says what the driver earned today; earning nothing is "0g" (as the console's status strip says),
-- never the word "free" (which a player reads as "I gave rides away free today").
proof("AU24-20", "The minimap's driving line does not say 'free today' when nothing was earned", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	local line = d.W.UI.DriveSummary()
	ok(type(line) == "string" and line:find("Open", 1, true), "setup: open with a rider: " .. tostring(line))
	ok(not line:find("free", 1, true), "the line says: " .. line)
	T.clean(w)
end)
