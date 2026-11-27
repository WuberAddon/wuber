local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 29 lead (found by the round's own review of AUD-109): the alert counter sits under a tall banner
-- while it is up and goes back to its usual place when the banner is gone or dismissed.
local LONG = "Anita: Three invites in a row went unanswered. If those players never saw one, invite by hand (/invite Name): they still become riders."

local function counterY(c)
	local _, _, _, _, y = c:GetPoint(1)
	return y
end

test("alert character: the alert counter sits under a tall banner and returns to its usual place once the banner is gone", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	wub.env.UIParent:SetSize(1024, 768)
	wub.W.Drive.BellAlert(LONG)
	w:advance(1)
	local b = wub.env.WuberBell
	local c = wub.env.WuberBellCount
	ok(b:GetHeight() > 120, "control: the banner grew (" .. b:GetHeight() .. ")")
	ok(c and c:IsShown(), "control: the counter is shown")
	eq(counterY(c), -126 - (b:GetHeight() - 120), "the counter is under the tall banner while it is up")
	w:advance(60)
	ok(not b:IsShown(), "control: the banner is gone")
	eq(counterY(c), -126, "the counter is back in its usual place")
	-- a second long alert, dismissed by a click
	wub.W.Drive.BellAlert(LONG .. " ")
	w:advance(1)
	ok(b:IsShown() and counterY(c) < -126, "control: the banner is up again and the counter under it")
	wub.W.Drive.BellDismiss()
	eq(counterY(c), -126, "after a dismiss the counter is back in its usual place")
	-- a short alert never moves it
	w:advance(6)
	wub.W.Drive.BellAlert("Anita: Summon Dan")
	w:advance(1)
	eq(b:GetHeight(), 120, "control: a short alert keeps the 120 high banner")
	eq(counterY(c), -126, "a short alert leaves the counter where it always was")
	T.clean(w)
end)
