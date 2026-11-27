
-- r32 m: AUD-92: another addon takes over driving (WuberAPI.SetDriver) while Wuber's big button is on
-- screen (keepClosed): Drive.Button's PROVIDER listener only re-binds the key and never re-places the
-- button, so it stays on screen although Wuber's engine is now off.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local DR = W.Drive
	local db = DR.db or DR.InitDB()
	db.button.keepClosed = true -- "Keep it on screen when closed"
	DR.Button.Refresh()
	w:advance(2)
	return w, d, W, DR
end

test("r32 m: AUD-92: when another driver addon takes over, Wuber's big button leaves the screen", function()
	local w, d, W, DR = setup()
	local b = d.env.WuberDriveButton
	ok(b:IsShown() and DR.Lock() == nil and DR.Active(), "control: the big button is on screen and Wuber's engine runs")
	d.env.WuberAPI.SetDriver({ name = "Other Driver", beacon = function() return nil end })
	w:advance(10)
	eq(DR.Lock(), "provider", "control: Wuber's engine is now locked by the provider")
	ok(not DR.Active(), "control: the engine is off")
	ok(not b:IsShown(), "10 s after another addon took over driving, Wuber's big button is still on screen (Lock = " .. tostring(DR.Lock()) .. ", engine off)")
	T.clean(w)
end)


-- r32 m: AUD-93: DR.SkipTarget falls back to the sell-mode customer list even in raid mode, so Skip stays
-- offered on the raid console and its click only prints "<name> is off the raid's summon list." (nothing is done).

test("r32 m: AUD-93: in raid mode Skip does not act on a leftover sell-mode customer", function()
	local w = H.NewWorld({})
	local a = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:addBot("Dan Miller", { spot = "Ratchet" })
	w:advance(15)
	local DR = a.W.Drive
	DR.opts().autoInvite = false
	DR.SetOpen(true) w:advance(3)
	w:botWhisper("Dan Miller", a, "summon pls")
	w:advance(1)
	local dan = DR.customers["dan miller"]
	eq(dan and dan.state, "queued", "control: Dan is queued while selling")
	local c0 = DR.SkipTarget()
	ok(c0 and c0.name == "Dan Miller", "control: selling, Skip is about Dan")
	ok(DR.SetMode("raid"), "the driver switches the console to raid summons")
	w:advance(1)
	a.W.UI.Toggle(true) w:advance(2) a.W.UI.SelectTab("Drive") w:advance(2)
	local printed = {}
	a.W.Print = function(t) printed[#printed + 1] = t end
	local target = DR.SkipTarget()
	ok(target == nil, "raid console: Skip is offered for " .. tostring(target and target.name) .. ", who is not in the raid queue")
	DR.Skip(false)
	ok(#printed == 0, "clicking Skip prints: " .. table.concat(printed, " | ") .. " (and changes nothing)")
	T.clean(w)
end)
