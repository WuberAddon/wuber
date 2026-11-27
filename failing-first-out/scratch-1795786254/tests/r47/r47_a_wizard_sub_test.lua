local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- the width the line needs against the room left of the button, both in the row's own units
local function overlap(d, row)
		local s, b = H.rect(row.sub), H.rect(row.btn)
	local e = H.effScale(row.sub)
	local room = (b.l - s.l) / e
	local need = d.W.Theme.MeasureText(row.sub:GetText(), row.sub.wuberPx or 10, "regular")
	if row.sub.wuberWrapped then need = 0 end -- two lines: each line is shorter than the room
	return need, room
end
test("r47 a: 'No answer: Wanda may not have Wuber' runs behind the Add anyway button", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Wanda Lock", { spot = "Ratchet", class = "WARLOCK" })
	w:group({ T.ANITA, "Wanda Lock" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	d:clickText("^Send offers$", { pattern = true }) w:advance(26)
	local row = d.W.Driver.ui.subs.wizard.people.list[1]
	ok(H.visible(row.btn) and #d:findText("Add anyway") > 0, "control: the Add anyway button shows on the row")
	local need, room = overlap(d, row)
	ok((need > 0 or row.sub.wuberWrapped) and need < 400, "control: the line was measured (" .. tostring(need) .. ")")
	ok(need <= room, string.format("the line '%s' needs %.0f px but only %.0f px are free left of the Add anyway button: the last words hide behind it", row.sub:GetText(), need, room))
	T.clean(w)
end)