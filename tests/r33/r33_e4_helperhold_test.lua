local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local SPOT = "Undercity"

local function setup()
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Bo Second", { spot = SPOT })
	w:group({ ANITA, "Bob Helper", "Bo Second" })
	w:advance(1)
	local DR = lock.W.Drive
	DR.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar" })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	local helped = {}
	lock.W.Listen("DRIVE_RITUAL", function(name, phase, data)
		if phase == "h" and type(data) == "table" then helped[#helped + 1] = tostring(data.helperName or data.helper) end
	end)
	local b = lock.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is not shown")
	lock:click(b)
	w:advance(1)
	return w, lock, helped
end

-- what the game does when a group member without Wuber clicks or lets go of my portal:
-- UNIT_SPELLCAST_CHANNEL_START / _STOP for his party token (the fake only sends them for the caster)
local function token(lock, name)
	for i = 1, 4 do
		local t = "party" .. i
		if lock.W.UnitName(t) == name then return t end
	end
	local seen = {}
	for i = 1, 4 do seen[#seen + 1] = tostring(lock.env.UnitName("party" .. i)) .. "/" .. tostring(lock.W.UnitName("party" .. i)) end
	error("no party token for " .. name .. ": " .. table.concat(seen, ","))
	-- for " .. name)
end
local function click(w, lock, name)
	ok(w:clickPortal(name), name .. " clicks the portal")
	lock:fire("UNIT_SPELLCAST_CHANNEL_START", token(lock, name), "Help-" .. name, w:spellId())
end
local function letgo(w, lock, name)
	w:releasePortal(name)
	lock:fire("UNIT_SPELLCAST_CHANNEL_STOP", token(lock, name), "Help-" .. name, w:spellId())
end

local function has(helped, who)
	for _, h in ipairs(helped) do if h:lower():find(who:lower(), 1, true) then return true end end
	return false
end

test("r33 e4 AUD-100: control, a plain helper who holds the portal 3 s is credited", function()
	local w, lock, helped = setup()
	click(w, lock, "Bob Helper")
	w:advance(3)
	click(w, lock, "Bo Second")
	w:advance(3)
	ok(has(helped, "Bob"), "Bob held 3 s and should be credited as a helper, got: " .. table.concat(helped, ","))
	T.clean(w)
end)

test("r33 e4 AUD-100: a helper who lets go within 2 s and clicks again and holds 3 s is still credited", function()
	local w, lock, helped = setup()
	click(w, lock, "Bob Helper")
	w:advance(1)
	letgo(w, lock, "Bob Helper") -- breaks the channel after 1 s
	w:advance(1)
	click(w, lock, "Bob Helper")
	w:advance(3) -- holds the portal for 3 s this time
	click(w, lock, "Bo Second")
	w:advance(3)
	ok(has(helped, "Bob"), "Bob held the portal 3 s on his second try but the driver's crew never hears he helped (no credit in HELP, Cut or Kitchen): got " .. table.concat(helped, ","))
	T.clean(w)
end)
