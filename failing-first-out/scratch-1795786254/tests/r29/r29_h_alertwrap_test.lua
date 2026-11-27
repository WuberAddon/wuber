local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local LONG = "Anita: Three invites in a row went unanswered. If those players never saw one, invite by hand (/invite Name): they still become riders."

-- the text's real room: the two side points of the font string, and how many lines its width needs there
local function room(fs, uw)
	local l, r = 0, 0
	for i = 1, fs:GetNumPoints() do
		local p, _, rp, x = fs:GetPoint(i)
		if p == "LEFT" then l = x elseif p == "RIGHT" then r = -x end
	end
	return uw - l - r, l, r
end

test("alert character: a long alert wraps inside the banner so its whole text shows on a 1024 wide screen", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	wub.env.UIParent:SetSize(1024, 768)
	wub.W.Drive.BellAlert("Anita: Summon Dan")
	w:advance(1)
	local b = wub.env.WuberBell
	ok(b and b:IsShown(), "control: the banner is up")
	eq(b:GetHeight(), 120, "a short alert keeps the 120 high banner")
	w:advance(3)
	wub.W.Drive.BellAlert(LONG)
	w:advance(1)
	local uw = wub.env.UIParent:GetWidth()
	local rm, l, r = room(b.text, uw)
	ok(l > 0 and r > 0, "the text has a left and a right margin inside the banner")
	local need = b.text:GetUnboundedStringWidth()
	local lines = math.ceil(need / rm)
	ok(lines >= 2, "control: the long alert needs more than one line here (" .. lines .. ")")
	ok(b:GetHeight() >= 120 + 36 * (lines - 1), "the banner grows for " .. lines .. " lines, height " .. b:GetHeight())
	ok(b.text.GetWordWrap == nil or b.text:GetWordWrap(), "word wrap is on")
	eq(b.text:GetText(), LONG, "the text is not shortened")
	-- a short alert after it is as before
	w:advance(3)
	wub.W.Drive.BellAlert("Anita: Summon Dan")
	w:advance(1)
	eq(b:GetHeight(), 120, "a short alert after a long one is 120 high again")
	T.clean(w)
end)
