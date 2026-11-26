-- Drive > Your crew > "Add by name": WoW Forever names are "First Surname" (Anita Lift, Farra Way). Typing "Wuber Rocks"
-- used to get the "That isn't a player's name" toast because DR.ValidName (strict, used by the field) refused any space.
-- Promise: one word or "First Surname" (single space, 2 to 12 letters each, optional -Realm) is offered; digits, symbols,
-- 3 words and a stray space (leading, trailing, double) are still refused with the same toast. The offer goes to the typed
-- name only. The click is the fake game's hit-tested click on the Add pill; the key path is Enter in the focused box.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local BAD = "That isn't a player's name. Type the name as the game shows it (each part 2 to 12 letters), with -Realm for another realm."
local function has(c, text) return #c:findText(text, false, true) > 0 end

local function crewPage()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("crew") w:advance(1)
	local s = d.W.Driver.ui.subs.crew
	return w, d, s, d.W.Drive
end

test("addbyname: 'Wuber Rocks' on Your crew sends an offer to that name, no bad-name toast", function()
	local w, d, s, DR = crewPage()
	ok(s and s.adder, "control: the crew page has the Add by name field")
	local sentTo = {}
	local real = DR.Whisper
	DR.Whisper = function(target, kind, ...) sentTo[#sentTo + 1] = target .. "/" .. tostring(kind) return real(target, kind, ...) end
	d:type(s.adder.field.edit, "Wuber Rocks", false)
	d:clickOn(s.adder.add) w:advance(0.5)
	ok(not has(d, BAD), "no bad-name toast")
	ok(has(d, "Crew offer sent to"), "the sent toast shows")
	eq(table.concat(sentTo, ","), "Wuber Rocks/TO", "one offer, to exactly the name typed")
	ok(has(d, "Wuber Rocks"), "the name is listed in the crew rows")
	T.clean(w)
end)

test("addbyname: Enter in the focused box does the same, and a realm may follow two words", function()
	local w, d, s, DR = crewPage()
	local sentTo = {}
	local real = DR.Whisper
	DR.Whisper = function(target, kind, ...) sentTo[#sentTo + 1] = target .. "/" .. tostring(kind) return real(target, kind, ...) end
	d:type(s.adder.field.edit, "Farra Way-Firemaw", true) w:advance(0.5)
	ok(not has(d, BAD), "no bad-name toast")
	eq(table.concat(sentTo, ","), "Farra Way-Firemaw/TO", "one offer, to exactly the name typed")
	T.clean(w)
end)

-- guard: names that were refused before must stay refused, so it passes on the base too
test("addbyname: digits, symbols, 3 words and stray spaces are still refused", function()
	for _, bad in ipairs({ "Wuber Rock5", "Wuber R0cks", "Wuber! Rocks", "Wuber Van Rocks", "Wuber  Rocks", "A Rocks", "Wuber Abcdefghijklm", "Wuber Rocks-Fire maw" }) do
		local w, d, s, DR = crewPage()
		d:type(s.adder.field.edit, bad, false)
		d:clickOn(s.adder.add) w:advance(0.5)
		ok(has(d, BAD), "refused: '" .. bad .. "'")
		ok(not has(d, "Crew offer sent to"), "nothing sent for '" .. bad .. "'")
		T.clean(w)
	end
end)

test("addbyname: the refused-name message tells the player to type the name as the game shows it", function()
	local w, d, s = crewPage()
	d:type(s.adder.field.edit, "W", false) d:clickOn(s.adder.add) w:advance(0.5)
	ok(has(d, "Type the name as the game shows it (each part 2 to 12 letters), with -Realm for another realm."), "new words show for a refused name")
	ok(not has(d, "Type one word of 2 to 12 letters"), "old words gone")
	T.clean(w)
	w, d, s = crewPage()
	d:type(s.adder.field.edit, "Wuber Rocks", false) d:clickOn(s.adder.add) w:advance(0.5)
	ok(not has(d, "That isn't a player's name"), "a two-word name is still accepted")
	ok(has(d, "Crew offer sent to"), "the offer is sent")
	T.clean(w)
end)

test("addbyname: ValidName strict rules", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	local V = d.W.Drive.ValidName
	for _, n in ipairs({ "Anita", "Anita Lift", "Wuber Rocks-Quel'Thalas" }) do ok(V(n), n) end
	for _, n in ipairs({ " Anita", "Anita ", "Anita  Lift", "Anita Lift Two", "Anita1 Lift", "Anita L" }) do ok(not V(n), "'" .. n .. "'") end
	T.clean(w)
end)
