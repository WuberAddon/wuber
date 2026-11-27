local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- In the real game StaticPopup_Show returns nil (no error) when all 4 popup slots are taken.
test("r33 j2 AUD-59: /wuber drive market on says nothing when the game has no free popup slot", function()
	local w = H.NewWorld({})
	local a = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "WARLOCK", shards = 10 })
	w:advance(15)
	local DR = a.W.Drive
	-- control: the popup shows -> 'asked', the question is on screen
	a:slash("/wuber drive market on")
	w:advance(1)
	ok(a.popups and a.popups[DR.PUBLIC_POPUP], "control: the warning is shown when the game can show it")
	a.popups[DR.PUBLIC_POPUP] = nil
	DR.SetAutoPublic(false) -- reset the waiting question state is kept by Core; answer via Cancel below
	local function answer(yes)
		local d = a.env.StaticPopupDialogs[DR.PUBLIC_POPUP]
		if yes then d.OnAccept() else d.OnCancel() end
	end
	answer(false)
	local function said1()
		for _, t in ipairs(a.chatLines or {}) do if t:find("can't be shown", 1, true) then return true end end
		return false
	end
	-- control: when the game raises an error instead, the message is said
	local good = a.env.StaticPopup_Show
	a.env.StaticPopup_Show = function() error("no popup") end
	a.chatLines = {}
	a:slash("/wuber drive market on")
	w:advance(1)
	ok(said1(), "control: with a popup error the player is told the warning can't be shown")
	-- the game has no free slot: StaticPopup_Show returns nil without an error
	a.env.StaticPopup_Show = function() return nil end
	a.chatLines = {}
	a:slash("/wuber drive market on")
	w:advance(1)
	local said = false
	for _, t in ipairs(a.chatLines or {}) do if t:find("can't be shown", 1, true) then said = true end end
	ok(said, "the player types '/wuber drive market on', no warning appears (no free popup slot) and Wuber says nothing; it should say 'the warning can't be shown right now'")
	T.clean(w)
end)
