local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-88: a Warlock who just joined the crew reads "not heard lately · not in your group" whole on the
-- Crew screen (a second line and a taller card), never cut short.

test("r31 e HUNT-88: the Crew screen shows 'not heard lately · not in your group' whole", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	DR.Crew = function()
		return { { name = a.player.name, key = W.myKey, role = "lock", app = true, me = true, here = true },
			{ name = "Fay Moss", key = "fay moss", role = "lock", app = true, here = false, silent = true, shards = 10 } }
	end
	T.openDrive(a)
	W.Driver.ShowScreen("crew")
	w:advance(2)
	local row = W.Driver.ui.subs.crew.members.list[1]
	ok(row.sub:GetText():find("not heard lately", 1, true) and row.sub:GetText():find("not in your group", 1, true), "text: " .. tostring(row.sub:GetText()))
	local tr = H.truncation(row.sub, true)
	ok(tr == nil, "the line is not cut" .. (tr and (" need " .. tostring(tr.need) .. " room " .. tostring(tr.room) .. " lines " .. tostring(tr.lines) .. " max " .. tostring(tr.max) .. " wrapOn " .. tostring(row.sub.wuberWrapOn) .. " h " .. tostring(row.sub:GetHeight())) or ""))
	ok(row:GetHeight() >= 60, "card height " .. tostring(row:GetHeight()))
	T.clean(w)
end)
