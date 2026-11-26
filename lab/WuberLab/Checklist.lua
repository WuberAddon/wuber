-- Wuber Lab (developer only, never ship): the guided checklist. Steps depend on the window's
-- role (rider = Wuber Rocks, driver = Anita Lift, team = Farra Way / Hayley Cab; /lab role to
-- override). A step with `sig` ticks itself when that signal is seen (Hooks.lua sends them),
-- with the time since the step before it; every step can be marked Pass or Fail by hand,
-- with a note. Results: WuberLabDB.chars[name].checks[id] = { r = "auto"|"pass"|"fail", at,
-- took, note, by }.

local _, L = ...

local function notFake(info) return not (type(info) == "table" and info.fake) end
local function real(sig) return { sig = sig, test = notFake } end

-- { id, section, text, hint, sig (signal name or list), test(info), fakeOk }
local function S(id, sec, text, hint, auto)
	local step = { id = id, sec = sec, text = text, hint = hint }
	if type(auto) == "string" then
		step.sig = { auto }
	elseif type(auto) == "table" then
		step.sig = type(auto.sig) == "table" and auto.sig or { auto.sig }
		step.test = auto.test
	end
	step.manual = step.sig == nil
	return step
end

L.STEPS = {
	rider = {
		S("r_open", "Basics", "App opens", "Type /wuber or click the minimap button.", "app_open"),
		S("r_check", "Basics", "Check my game runs", "Wuber > gear > Check my game.", "selftest_ui"),
		S("r_tips", "Basics", "Tooltips show (3 different)", "Hover three buttons in Wuber.", { sig = "tip", test = function(n) return (tonumber(n) or 0) >= 3 end }),
		S("r_slider", "Basics", "A slider works", "Settings: move 'My time is worth' or the window size.", "slider"),
		S("r_minimap", "Basics", "Minimap button works", "Click the minimap button (then drag it round the rim).", "minimap"),
		S("r_booked", "Ride", "Booked a ride", "Pick the tester's team on Home, then Request.", real("ride_requesting")),
		S("r_whisper", "Ride", "Visible WTB whisper sent", "The Request click whispers 'WTB summon to ...' - check chat.", "whisper_wtb"),
		S("r_accepted", "Ride", "Driver accepted", "Wait for Anita's window to accept.", { sig = { "ride_accepted", "accept_msg" }, test = notFake }),
		S("r_queue", "Ride", "Queue position shown", "If the team is busy the card says 'You're 2nd in line'.", real("ride_position")),
		S("r_invite", "Ride", "Invite auto-accepted (no click)", "Don't click: the invite should be taken for you.", real("auto_accept")),
		S("r_summon", "Ride", "Summon popup / portal", "The summon box and the portal effect appear.", real("ride_portal")),
		S("r_arrived", "Ride", "Arrived", "Accept the summon (Wuber's button or the game's box).", real("ride_arrived")),
		S("r_payclick", "Ride", "Paid by typing the fare", "Driver opens trade; type what Wuber says (50 in silver), click Trade.", real("pay_done")),
		S("r_pay", "Ride", "Fare paid, trade done", "Wait for the driver to accept the trade.", real("pay_done")),
		S("r_left", "Ride", "Left the group by itself", "Wait 3 s after paying.", real("auto_left")),
		S("r_rated", "Ride", "Rating sent", "Tap the stars on the Done screen.", real("rated")),
		S("r_milestone", "Ride", "Milestone pop", "First Ride shows a pop card (use Fresh rider first).", "milestone_pop"),
		S("r_cancel", "Edge", "Cancel before accept", "Request, then Cancel at once (Anita closed or slow).", "cancel_early"),
		S("r_busy", "Edge", "Book a busy driver -> queue", "Book the tester's team while a ride is under way.", real("busy_queue")),
		S("r_combat", "Edge", "Request in combat", "Fight a mob, request; no whisper, request still goes.", "combat_request"),
		S("r_mapctrl", "Edge", "Map: Ctrl-click a place", "Open the map, Ctrl-click a town.", "map_ctrl"),
		S("r_mapbtn", "Edge", "Map: Ride here button", "Hover a town on the map, click 'Ride here'.", "map_button"),
		S("r_hide", "Edge", "Hide a driver", "Card menu > Hide this driver (try a fake).", "hidden"),
		S("r_fav", "Edge", "Favourite online toast", "Favourite Anita, she goes offline and on again.", "fav_toast"),
		S("r_decline", "Edge", "Declined -> try another", "Fake drivers: book 'Mid' or 'Dear'.", "ride_declined"),
		S("r_timeout", "Edge", "No answer -> timed out", "Fake drivers: book 'Spam' and wait 40 s.", "ride_timeout"),
		S("r_spam", "Edge", "Spammy service name hidden", "Fake drivers: 'Cheap Gold Sale' shows as a name.", "spam_filtered"),
		S("r_crown", "Looks", "Crown over the team's heads", "Nameplates on (Settings button), stand near the team."),
		S("r_badges", "Looks", "Badges on cards, pins, heads", "Fake drivers carry badges; check list and map."),
		S("r_fx", "Looks", "Effects play well", "Tools > Play every effect."),
		S("r_glow", "Looks", "Founder card glows brightest", "Fake drivers on: Anita's card glows most, cheap ones more."),
		S("r_sort", "Looks", "Sorting: open first, cheapest", "Fake drivers on: check the order of cards."),
	},
	driver = {
		S("d_provider", "Setup", "Ritual Rides drives for Wuber", "Log in with Wuber and Ritual Rides on.", "provider"),
		S("d_online", "Setup", "Beacon: open", "/rr on (group leader or main caster).", "beacon_open"),
		S("d_check", "Setup", "Check my game runs", "Wuber > gear > Check my game.", "selftest_ui"),
		S("d_seen", "Setup", "Team seen on the rider's list and map", "Look on Wuber Rocks' screen."),
		S("d_request", "Ride", "Wuber request arrives", "Wuber Rocks books the team.", "prov_request"),
		S("d_accept", "Ride", "Accepted (A sent)", "Ritual Rides accepts by itself.", "api_accept"),
		S("d_queue", "Ride", "Queue place sent", "Have one customer waiting when the rider books.", "api_queue"),
		S("d_invited", "Ride", "Invited", "Ritual Rides invites the rider.", "stage_invited"),
		S("d_summoning", "Ride", "Summoning", "Press the Ritual Rides button.", "stage_summoning"),
		S("d_portal", "Ride", "Portal up", "Farra and Hayley click the portal.", "stage_portal"),
		S("d_arrived", "Ride", "Arrived", "The rider accepts the summon.", "stage_arrived"),
		S("d_paid", "Ride", "Paid in trade", "Open trade with the rider; they click Pay.", "stage_paid"),
		S("d_rating", "Ride", "Rating received", "The rider taps the stars.", "prov_rating"),
		S("d_cancel", "Edge", "Rider cancelled -> dropped", "Rider books then cancels quickly.", "prov_cancel"),
		S("d_busy", "Edge", "Busy beacon during a ride", "A ride under way shows Busy on the rider's card.", "beacon_busy"),
		S("d_paused", "Edge", "Paused/closed -> declined", "/rr off or pause, rider books.", "api_decline_closed"),
		S("d_price", "Edge", "Price change -> new beacon", "/rr price 60s, check the rider's card.", "beacon_price"),
		S("d_one", "Edge", "One status per step", "Only Anita's window sends stages (see report)."),
		S("d_crown", "Looks", "Crown on the rider's screen", "Ask Wuber Rocks to look at you (nameplates on)."),
		S("d_paidfx", "Looks", "Paid burst plays", "After the trade completes.", "fx_paid"),
		S("d_coins", "Looks", "Coin shower on 5 stars", "Rider gives 5 stars.", "fx_coins"),
	},
	team = {
		S("t_open", "Setup", "App opens", "/wuber", "app_open"),
		S("t_check", "Setup", "Check my game runs", "Wuber > gear > Check my game.", "selftest_ui"),
		S("t_provider", "Setup", "Ritual Rides drives for Wuber", "Log in with both addons on.", "provider"),
		S("t_quiet", "Setup", "No beacon from this window", "Only Anita's window beacons (report shows D senders)."),
		S("t_summon", "Ride", "Helps with the ritual", "Click the portal when Anita casts."),
		S("t_cashier", "Ride", "Took a fare in trade", "If you are the cashier, open trade with the rider.", "cashier"),
		S("t_status", "Ride", "No double stage messages", "See report: stages only from one window."),
		S("t_crown", "Looks", "Crown over Anita (nameplates on)", "Look at Anita."),
	},
}
L.STEPS.other = L.STEPS.rider

L.STEP_BY_ID = {}
for _, list in pairs(L.STEPS) do
	for i, s in ipairs(list) do
		s.index = i
		L.STEP_BY_ID[s.id] = s
	end
end

function L.Steps(role) return L.STEPS[role or L.Role()] or L.STEPS.rider end

function L.Sections(role)
	local out, seen = {}, {}
	for _, s in ipairs(L.Steps(role)) do
		if not seen[s.sec] then
			seen[s.sec] = true
			out[#out + 1] = s.sec
		end
	end
	return out
end

local function checks()
	local c = L.Char()
	return c and c.checks or nil
end

function L.Result(id)
	local ch = checks()
	return ch and ch[id] or nil
end

local function done(rec) return type(rec) == "table" and (rec.r == "auto" or rec.r == "pass" or rec.r == "fail") end
L.IsDone = function(id) return done(L.Result(id)) end

L.sessionStart = L.Epoch()

-- Seconds since the step before this one (same section) was ticked this session.
local function took(step, at)
	local ch = checks()
	if not ch then return nil end
	local best
	for _, s in ipairs(L.Steps()) do
		if s.sec == step.sec and s.index < step.index then
			local rec = ch[s.id]
			if done(rec) and (rec.at or 0) >= L.sessionStart and (not best or rec.at > best) then best = rec.at end
		end
	end
	if not best then return nil end
	return at - best
end

L.changed = function() end -- the panel sets it

local function tick(step, by)
	local ch = checks()
	if not ch or done(ch[step.id]) then return false end
	local at = L.Epoch()
	local rec = ch[step.id] or {}
	rec.r, rec.at, rec.by = "auto", at, by
	rec.text, rec.sec = step.text, step.sec
	rec.took = took(step, at)
	ch[step.id] = rec
	L.Log("check", ("%s;auto;by=%s;took=%s;%s"):format(step.id, tostring(by), rec.took and ("%.1f"):format(rec.took) or "-", step.text))
	pcall(L.changed, step.id)
	return true
end

L.signalFns[#L.signalFns + 1] = function(name, info)
	for _, step in ipairs(L.Steps()) do
		if step.sig then
			for _, sg in ipairs(step.sig) do
				if sg == name and (not step.test or step.test(info)) then tick(step, name) end
			end
		end
	end
end

-- By hand: r = "pass" | "fail" | nil (clear). Keeps the note.
function L.MarkStep(id, r)
	local step = L.STEP_BY_ID[id]
	local ch = checks()
	if not step or not ch then return false end
	local rec = ch[id] or {}
	if r == nil then
		ch[id] = rec.note and { note = rec.note } or nil
		L.Log("check", id .. ";cleared;" .. step.text)
	else
		local at = L.Epoch()
		rec.took = rec.took or took(step, at)
		rec.r, rec.at, rec.by = r, at, "hand"
		rec.text, rec.sec = step.text, step.sec
		ch[id] = rec
		L.Log("check", ("%s;%s;took=%s;%s%s"):format(id, r, rec.took and ("%.1f"):format(rec.took) or "-", step.text,
			rec.note and (";note=" .. rec.note) or ""))
	end
	pcall(L.changed, id)
	return true
end

function L.SetNote(id, text)
	local step = L.STEP_BY_ID[id]
	local ch = checks()
	if not step or not ch then return false end
	text = tostring(text or ""):gsub("[\r\n|]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 200 then text = text:sub(1, 200) end
	local rec = ch[id] or {}
	rec.note = text ~= "" and text or nil
	rec.text, rec.sec = step.text, step.sec
	ch[id] = rec
	L.Log("check", id .. ";note;" .. (rec.note or "(cleared)"))
	pcall(L.changed, id)
	return true
end

function L.ResetChecks()
	local c = L.Char()
	if not c then return false end
	c.checks = {}
	L.sessionStart = L.Epoch()
	L.Log("check", "reset")
	pcall(L.changed)
	return true
end

-- The first step not done yet (in `section` if given, else anywhere): step or nil.
function L.NextStep(section)
	for _, s in ipairs(L.Steps()) do
		if (not section or s.sec == section) and not L.IsDone(s.id) then return s end
	end
	if section then return L.NextStep(nil) end
	return nil
end

function L.Progress()
	local n, d, f = 0, 0, 0
	for _, s in ipairs(L.Steps()) do
		n = n + 1
		local rec = L.Result(s.id)
		if done(rec) then d = d + 1 end
		if rec and rec.r == "fail" then f = f + 1 end
	end
	return d, n, f
end

-- The step list of this window's role, kept with the results so the report can show steps
-- not done yet: WuberLabDB.chars[name].steps = { { id, sec, text, manual }, ... }
function L.SaveStepList()
	local c = L.Char()
	if not c then return end
	local out = {}
	for _, s in ipairs(L.Steps()) do out[#out + 1] = { id = s.id, sec = s.sec, text = s.text, manual = s.manual or nil } end
	c.steps = out
	c.role = L.Role()
end

L.OnLogin(function() L.SaveStepList() end)
