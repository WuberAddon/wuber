-- Third-pass proofs of job 2620 (audit-241), area E: the big button and its plan.
local T = ...
local test = T.test
local H = T.H
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

-- AU24-35: a line left in the chat box and sent by Enter later still counts as sent.
proof("AU24-35", "a boxed line the driver sends with Enter more than a minute after the click is marked sent, not offered again", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	w:addBot("Dan Moss", { spot = "Undercity" })
	local DR = a.W.Drive
	local c = { name = "Dan Moss", key = "dan moss" }
	assert(DR.OpenBox(c, "pay") ~= false, "the reminder went to the chat box")
	w:advance(1)
	local line = a.chatBox
	assert(type(line) == "string" and line:find("Dan", 1, true), "control: the chat box holds the whisper: " .. tostring(line))
	-- the edit box stays open until Enter or Escape: the driver was busy for 80 s, then pressed Enter
	w:advance(80)
	a:fire("CHAT_MSG_WHISPER_INFORM", DR.Text("pay", c), "Dan Moss")
	assert(c.reminded, "the pay reminder went out by Enter after 80 s but is not marked sent, so the button offers it again and Dan hears it twice")
	T.clean(w)
end)
