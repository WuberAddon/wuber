-- r50 group J: AU24-10 / AU24-35. A reminder waiting in the chat box is marked sent only
-- by the whisper that carries its words, however long it waited and whatever else was whispered.
local T = ...
local test = T.test

local function boxed(step)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	w:addBot("Dan Moss", { spot = "Undercity" })
	local DR = a.W.Drive
	local c = { name = "Dan Moss", key = "dan moss" }
	assert(DR.OpenBox(c, "pay") ~= false, "the reminder went to the chat box")
	return w, a, DR, c
end

local function wait(w, secs, step)
	local t = 0
	while t < secs do w:advance(step); t = t + step end
end

for _, step in ipairs({ 1, 5 }) do
	test("r50 J: the boxed line sent by Enter after 80 s is marked sent (step " .. step .. " s)", function()
		local w, a, DR, c = boxed(step)
		wait(w, 80, step)
		a:fire("CHAT_MSG_WHISPER_INFORM", DR.Text("pay", c), "Dan Moss")
		assert(c.reminded, "marked sent")
		assert(DR.boxed == nil, "no longer waiting")
		T.clean(w)
	end)

	test("r50 J: another whisper to the same rider does not mark it sent (step " .. step .. " s)", function()
		local w, a, DR, c = boxed(step)
		wait(w, 20, step)
		a:fire("CHAT_MSG_WHISPER_INFORM", "sure, one minute", "Dan Moss")
		assert(not c.reminded, "not marked")
		assert(DR.boxed and DR.boxed.c == c, "still waiting for its own Enter")
		a:fire("CHAT_MSG_WHISPER_INFORM", DR.Text("pay", c), "Dan Moss")
		assert(c.reminded, "its own line then marks it")
		T.clean(w)
	end)
end

-- guard: the same words to another rider never mark it (the name still has to match)
test("r50 J: the same words whispered to someone else do not mark it", function()
	local w, a, DR, c = boxed(1)
	w:addBot("Eve Ash", { spot = "Undercity" })
	a:fire("CHAT_MSG_WHISPER_INFORM", DR.Text("pay", c), "Eve Ash")
	assert(not c.reminded, "not marked")
	T.clean(w)
end)
