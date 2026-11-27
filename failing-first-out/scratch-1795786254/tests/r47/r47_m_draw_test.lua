local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- (design 1) the halo is gone on purpose: s.halo is an object that takes every call and shows nothing
local function haloShown(h) return h.IsShown and h:IsShown() and true or false end
test("r47 m: AUD-162 raid mode, summons stopped: the status dot has no grey halo around it", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1)
	local s = d.W.Driver.ui.console.status
	ok(s and s.halo, "console status strip found")
	-- control: selling, closed: the halo is hidden
	ok(d.W.Drive.IsOpen() == false, "closed")
	ok(not haloShown(s.halo), "control: sell mode closed, halo hidden")
	d.W.Drive.SetMode("raid") w:advance(1)
	d.W.Driver.Refresh() w:advance(1)
	ok(d.W.Drive.Mode() == "raid" and not d.W.Drive.RaidOn(), "raid mode, stopped")
	ok(#d:findText("Stopped") > 0, "the strip says Stopped: " .. T.list(d:visibleTexts()):sub(1, 150))
	ok(not haloShown(s.halo), "raid mode Stopped: there is no halo glow around the status dot")
	T.clean(w)
end)

test("r47 m: AUD-163 the Join community card's subtitle wraps to two lines and the card is tall enough", function()
	local w = T.newWorld({ clubs = true, realm = T.H.FOUNDER_REALM })
	local club = w:addClub({ id = 77, name = "Wuber", members = { ["Anita Lift"] = 1 }, streams = {
		{ streamId = 2, name = "Wuber", streamType = 3, leadersAndModeratorsOnly = true },
		{ streamId = 1, name = "General", streamType = 0 } } })
	local d = w:addClient("Bob Stone", { spot = "Ratchet", class = "WARLOCK", money = 100000 })
	T.settle(w, 25)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1)
	w:clubInvite(club, "Anita Lift", "Bob Stone") w:advance(1)
	local fs = d:findText("Its member list helps riders find you across realms.")[1]
	ok(fs, "the Join card's line is on screen: " .. T.list(d:visibleTexts()):sub(1, 200))
	local card = fs:GetParent()
	ok(fs.wuberLines == 2, "the subtitle may wrap to 2 lines, not be cut with '...' (wuberLines=" .. tostring(fs.wuberLines) .. ")")
	ok(card:GetHeight() >= 68, "the card is taller to hold two lines, got " .. tostring(card:GetHeight()))
	T.clean(w)
end)
