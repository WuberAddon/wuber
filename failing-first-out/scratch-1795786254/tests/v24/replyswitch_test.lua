-- Wuber 2.4, auto-reply switch: tests the Driving settings row for autoReply. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end

local function dbHoldsTable(root, target, seen)
	if root == target then return true end
	if type(root) ~= "table" or seen[root] then return false end
	seen[root] = true
	for _, v in pairs(root) do
		if type(v) == "table" and dbHoldsTable(v, target, seen) then return true end
	end
	return false
end

test("v24 replyswitch: the Driving settings show Whisper back to public requests, on by default", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local t = st.controls["drive.autoReply"]
	ok(t, "the switch")
	local row = t.row or t:GetParent()
	ok(row and row.label and row.desc, "row has heading and description")
	ok(H.visible(row.label), "heading is visible")
	ok(H.visible(row.desc), "description is visible")
	eq(row.label:GetText(), "Whisper back to public requests", "heading text")
	eq(row.desc:GetText(), "Advanced: one whisper, then they whisper you.", "description text")
	eq(t.on, true, "toggle is on by default")
	eq(d.W.Drive.opts().autoReply, true, "DR.opts().autoReply is true")
	T.clean(w)
end)

test("v24 replyswitch: a click turns it off and it stays off", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local DR = d.W.Drive
	local t = st.controls["drive.autoReply"]
	ok(t, "the switch")
	ok(d:scrollIntoView(t), "the switch scrolls into view")
	d:click(t)
	w:advance(0.5)
	eq(t.on, false, "toggle is off after click")
	eq(DR.opts().autoReply, false, "DR.opts().autoReply is false")
	ok(dbHoldsTable(d.env.WuberDB, DR.opts(), {}), "WuberDB holds the saved opts table")
	d.W.UI.CloseSettings(true)
	w:advance(0.5)
	st = open(d, w, "driving")
	t = st.controls["drive.autoReply"]
	eq(t.on, false, "toggle stays off after reopening settings")
	eq(DR.opts().autoReply, false, "DR.opts().autoReply stays false")
	ok(d:scrollIntoView(t), "the switch scrolls into view again")
	d:click(t)
	w:advance(0.5)
	eq(t.on, true, "toggle is on after second click")
	eq(DR.opts().autoReply, true, "DR.opts().autoReply is true")
	DR.SetOpt("autoReply", false)
	d.W.UI.UpdateSettings()
	eq(t.on, false, "UpdateSettings refreshes toggle from saved value")
	T.clean(w)
end)

test("v24 replyswitch: the tooltip says what it does", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local t = st.controls["drive.autoReply"]
	ok(t, "the switch")
	local row = t.row or t:GetParent()
	local tip = row.wuberTip or t.wuberTip
	local body = tip and (type(tip.text) == "function" and tip.text(row) or tip.text) or ""
	ok(body:find("Whispers once to a clear public request for your place", 1, true), "tooltip says what it does (the 20 rewrites, W-3): " .. body)
	ok(body:find("Once an hour per person", 1, true), "tooltip states the hourly limit: " .. body)
	ok(body:find("never in combat, a raid, an instance or a ride", 1, true), "and the places it never whispers: " .. body)
	T.clean(w)
end)
