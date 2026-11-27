local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("r33 j3 AUD-113: Test says 'sent' to the alert character while the game blocks addon whispers", function()
	local w = H.NewWorld({})
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	local ana = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	ana:slash("/wuber drive bell Wuber Rocks")
	w:advance(3)
	local function count()
		local n = 0
		for _, e in ipairs(w.addonLog) do
			if e.prefix == "WUBERT" and e.from == "Ana Smith" and e.chatType == "WHISPER" and (e.text or ""):match("^B[EH]~") and e.result == 0 then n = n + 1 end
		end
		return n
	end
	local okT, how = ana.W.Drive.BellTest()
	w:advance(4)
	eq(okT, true, "control: with nothing blocked the test goes out")
	eq(how, "sent")
	ok(count() >= 2, "control: the hello and the test alert reached the wire: " .. count())
	ok(wub:said("Test from Ana") or #wub.W.db.drive.bell.team > 0, "control: the alert character heard")
	-- the game refused addon messages once (what W.Try records in the saved variables)
	local before = count()
	ana.W.db.blockedBuild[ana.W.Build()] = { comm = true }
	w:advance(700) -- clear the 5 s repeat guard
	okT, how = ana.W.Drive.BellTest()
	w:advance(4)
	eq(count(), before, "no new alert whisper can go out while 'comm' is blocked")
	eq(okT, false, "Settings > Test says '" .. tostring(how) .. "' (ok=" .. tostring(okT) .. ") but nothing was sent: the whisper queue drops it because 'comm' is blocked")
	T.clean(w)
end)
