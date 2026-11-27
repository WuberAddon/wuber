local T = ...
local test, ok = T.test, T.ok

-- HUNT-30: a crew member who does not lead the crew must not be told "your crew uses it too" after Save.

local function saveToast(asMember)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if asMember then DR.char().captain = "Bea Jones" end
	T.openDrive(a)
	W.Driver.ShowScreen("messages")
	w:advance(2)
	local s = W.UI.drive.screens.messages
	s.edit("thanks")
	w:advance(1)
	local seen = {}
	local old = W.UI.Toast
	W.UI.Toast = function(text, kind) seen[#seen + 1] = tostring(text) return old and old(text, kind) end
	s.editor.field:SetText("Thank you, safe travels!")
	s.editor.save:GetScript("OnClick")(s.editor.save)
	W.UI.Toast = old
	T.clean(w)
	return table.concat(seen, " | ")
end

test("r32 j3: HUNT-30 a crew member's Save does not say the crew uses it", function()
	local t = saveToast(true)
	ok(t:find("Saved", 1, true), "it still says saved: " .. t)
	ok(not t:find("your crew", 1, true), "no crew claim for a member: " .. t)
end)

test("r32 j3: HUNT-30 the leader's Save still says the crew uses it", function()
	local t = saveToast(false)
	ok(t:find("your crew uses it too", 1, true), "leader: " .. t)
end)
