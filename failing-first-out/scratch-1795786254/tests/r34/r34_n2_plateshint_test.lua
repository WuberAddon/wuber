local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- The Settings plates button: when the game cannot switch friendly nameplates on,
-- the last message the player is left with must still say Shift+V.
test("r34 n2: the nameplates button that fails leaves the Shift+V hint as the last message", function()
	local w = T.newWorld()
	local a = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local W, UI = a.W, a.W.UI
	local toasts = {}
	local real = UI.Toast
	UI.Toast = function(text, kind) toasts[#toasts + 1] = tostring(text) end
	-- the game reads the setting but refuses to write it
	local P = W.Plates
	local old = P.TurnOnFriendlyPlates
	P.TurnOnFriendlyPlates = function()
		UI.Toast("Couldn't switch them on from here. Press Shift+V, or turn on friendly nameplates in the game's settings.", "error")
		return false
	end
	local Rows = W.Mod("UI.Settings.Rows")
	Rows.turnOnPlates()
	P.TurnOnFriendlyPlates = old
	UI.Toast = real
	ok(#toasts >= 1, "a message was shown")
	ok(toasts[#toasts]:find("Shift%+V"), "last message says Shift+V, got: " .. tostring(toasts[#toasts]))
end)
