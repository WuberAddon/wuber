-- fixture for tests/tools/taint_test.lua (never loaded): the wrapper at the top of the stack
local function On(frame, event)
	pcall(frame.RegisterEvent, frame, event) -- the name is a variable here
end
return On
