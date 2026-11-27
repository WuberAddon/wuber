-- Helpers for the conformance tests of lane B2 (tests/rec/real_*_test.lua): not a test file itself
-- (run.lua loads only *_test.lua); each test file does local L = dofile(T.dir .. "/rec/real_lib.lua").
local L = {}

-- Records the events a client gets (only the names in `only`, a set; nil: all), with the world
-- time and the arguments: rec.list = { { event, at, args... }, ... }. rec:stop() puts fire back.
function L.record(w, client, only)
	local rec = { list = {} }
	local real = client.fire
	client.fire = function(self, event, ...)
		if not only or only[event] then rec.list[#rec.list + 1] = { event, w.time, ... } end
		return real(self, event, ...)
	end
	function rec.stop() client.fire = nil end
	-- the names in order, "EVENT(a,b)" when it had arguments
	function rec.names(from)
		local out = {}
		for i = from or 1, #rec.list do
			local e = rec.list[i]
			local s = e[1]
			if #e > 2 then
				local a = {}
				for j = 3, #e do a[#a + 1] = tostring(e[j]) end
				s = s .. "(" .. table.concat(a, ",") .. ")"
			end
			out[#out + 1] = s
		end
		return table.concat(out, " ")
	end
	function rec.find(event, from)
		for i = from or 1, #rec.list do if rec.list[i][1] == event then return rec.list[i], i end end
	end
	return rec
end

function L.set(list)
	local s = {}
	for _, k in ipairs(list) do s[k] = true end
	return s
end

return L
