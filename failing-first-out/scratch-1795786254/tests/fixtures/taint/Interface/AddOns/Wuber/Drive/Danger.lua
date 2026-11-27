-- fixture for tests/tools/taint_test.lua (never loaded): an old build's lines
local f = CreateFrame("Frame")
local function listen()
	f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
local function open()
	DR.Open()
end
f:SetPassThroughButtons("LeftButton") listen() open()
