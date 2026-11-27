local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 f5: AUD-227 provider view with the retire card up and 6 requests: no card hangs below the window", function()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Ratchet", class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = {
		price = 50000, team = {}, templates = {}, blocklist = {}, log = { rides = {}, open = 0 }, stats = {} } } })
	c.W.Char().wizard = true
	c.W.db.coach = true
	for i = 1, 6 do
		-- six riders whose requests the engine still holds (the real entry shape, as after a /reload)
		c.W.RestoreIncoming("abcde" .. string.char(96 + i), "Rider" .. string.char(64 + i) .. " Test", "Orgrimmar", 50000, "accepted")
	end
	w:advance(1)
	local n = 0 for _ in pairs(c.W.incoming) do n = n + 1 end
	c.W.Driver.Toggle() w:advance(3)
	ok(#c:findText("Your old summoning addon is still on") > 0, "the retire card is up: " .. T.list(c:visibleTexts()):sub(1, 200))
	ok(n >= 6, "control: Wuber riders' requests listed on the provider view, " .. n)
	local frame = _G and nil
	local win = c.env.WuberFrame
	local wb = H.rect(win)
	local drawn = {}
	for _, fs in ipairs(c:findText("^Rider%a", true)) do
		local p = fs:GetParent()
		local rr = H.rect(p)
		if rr and H.visible(p) then drawn[#drawn + 1] = rr.b end
	end
	ok(#drawn >= 1 and #drawn < 6, "request cards drawn: " .. #drawn)
	local lowest = math.huge
	for _, b in ipairs(drawn) do if b < lowest then lowest = b end end
	ok(lowest >= wb.b - 0.5, "the lowest request card's bottom edge is " .. math.floor(wb.b - lowest) .. " px below the window's bottom edge (window bottom " .. math.floor(wb.b) .. ", card bottom " .. math.floor(lowest) .. "): the player cannot see or click it")
	T.clean(w)
end)
