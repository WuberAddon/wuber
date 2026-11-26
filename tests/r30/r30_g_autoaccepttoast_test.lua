-- r30 group G (HUNT-11): with Auto-accept on and the invite accepted by Wuber, no toast says
-- "Accept the invite." (UI/Moments.lua onRide, UI/Rider/Ride.lua invitePending). Auto-accept off keeps it.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function run(auto)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = auto
	T.goOnline(d)
	w:advance(5)
	local seen = {}
	local UI = r.W.UI or r.env.Wuber_UI or r.UI
	local orig = UI.Toast
	UI.Toast = function(msg, ...) seen[#seen + 1] = tostring(msg); return orig(msg, ...) end
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(6)
	UI.Toast = orig
	return w, r, seen
end

local function has(seen, text)
	for _, s in ipairs(seen) do if s:find(text, 1, true) then return s end end
end

test("r30 G HUNT-11: auto-accept on and Wuber joined the group: no toast says Accept the invite", function()
	local w, r, seen = run(true)
	ok(r.W.ride.autoAccepted == true, "control: Wuber accepted the invite")
	ok(r.W.InGroup(), "control: the rider is in the group")
	ok(not has(seen, "Accept the invite"), "toast tells the rider to accept: " .. (has(seen, "Accept the invite") or "none"))
	T.clean(w)
end)

test("r30 G HUNT-11: auto-accept off: the toast still says Accept the invite", function()
	local w, r, seen = run(false)
	ok(has(seen, "invited you. Accept the invite."), "the toast stays when the rider must accept (toasts: " .. table.concat(seen, " | ") .. ")")
	T.clean(w)
end)
