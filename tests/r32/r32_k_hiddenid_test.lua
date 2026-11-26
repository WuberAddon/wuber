local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local ANITA, SPOT = "Anita Lift", "Undercity"

-- One solo driver (no Wuber crew), two helpers who click the portal, a rider elsewhere.
-- castSecs: how long the cast takes before the channel starts (the fake game uses 0.5 s;
-- the review says the real Ritual of Summoning takes about 5 s). The helpers click 3 s into the channel.
local function run(hidden, castSecs)
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bo Helper", { spot = SPOT })
	w:addBot("Bi Helper", { spot = SPOT })
	w.hideSpellIds = hidden
	local realAfter = w.after
	w.after = function(self, d, fn, c, where)
		if where == "ritual" then d = castSecs end
		return realAfter(self, d, fn, c, where)
	end
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss")
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	w:group({ ANITA, "Dan Moss", "Bo Helper", "Bi Helper" })
	w:advance(1)
	local DR = lock.W.Drive
	local b = lock.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is shown")
	lock:click(b)
	w:advance(castSecs + 3)            -- the channel has run 3 s
	ok(w.ritual and w.ritual.stage == "channel", "the portal is open")
	ok(w:clickPortal("Bo Helper"), "helper 1 clicks")
	ok(w:clickPortal("Bi Helper"), "helper 2 clicks")
	w:advance(2.5)
	local ends = {}
	for _, e in ipairs(w.addonLog) do
		local okFlag = e.text:match("^END~[^~]*~Dan Moss~(%d)")
		if okFlag then ends[#ends + 1] = okFlag end
	end
	return w, DR.customers["dan moss"], ends
end

test("r32 k: control: hidden spell id and a short cast: the finished summon is reported done (END ok)", function()
	local w, c, ends = run(true, 0.5)
	eq(ends[1], "1", "control: END says the summon went")
	eq(c.state, "waiting", "control: Dan is waiting to accept the summon")
	T.clean(w)
end)

test("r32 k: with hidden spell ids and a 5 s cast, a finished summon (both helpers clicked) is reported failed and Dan is back to joined", function()
	local w, c, ends = run(true, 5)
	ok(ends[1] == "1" and c.state == "waiting",
		"both helpers clicked the portal and the summon went out, but the driver's window sent END ok=" .. tostring(ends[1])
		.. " and shows Dan as '" .. tostring(c.state) .. "' (to be summoned again) instead of 'waiting'")
	T.clean(w)
end)
