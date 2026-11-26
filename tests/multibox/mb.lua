-- Multibox safety helpers (not a test file: tests/multibox/*_test.lua load it). The author runs several game windows on separate
-- accounts at once; these build such a set of own windows in the fake game, and a stranger who asks in public chat.
return function(T)
	local M = {}
	local eq, ok = T.eq, T.ok

	function M.key(name) return (name:lower():gsub("[%s%-]+", " ")) end

	-- n open Warlock windows (one account each) in Orgrimmar; returns the world and the list of windows
	function M.windows(names, opts)
		opts = opts or {}
		local w = T.newWorld()
		local cs = {}
		for i, name in ipairs(names) do cs[i] = T.driver(w, name, { spot = "Orgrimmar" }) end
		T.settle(w)
		for _, c in ipairs(cs) do
			local DR = c.W.Drive
			DR.opts().autoInvite = true
			DR.opts().watchPublic = true
			if opts.prepare then opts.prepare(c) end
			ok(DR.SetOpen(true), c.player.name .. " opens")
		end
		w:advance(opts.settle or 20)
		return w, cs
	end

	-- a stranger's clear request in Trade chat (8 s after the last whisper-back: Wuber's own gap)
	function M.ask(w, name, text)
		w:advance(9)
		if not w:player(name) then w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = "Horde" }) end
		w:chatFrom(name, text or "WTB summon to Orgrimmar", "CHANNEL", "Trade", "Horde")
		w:advance(0.5)
	end

	function M.replies(w, name) return #w:whispersTo(name, "reply") end

	-- /reload: the same character, the saved variables kept. Returns the new window, open again if it was.
	function M.reload(w, c)
		local nc = w:reload(c)
		return nc
	end

	-- logout and a later login of the same character (saved variables written at logout)
	function M.relog(w, c, gap)
		local name = c.player.name
		local saved = w:logout(c)
		w:advance(gap or 5)
		w:player(name).online = true
		return w:addClient(name, { saved = saved, class = "WARLOCK", spot = "Orgrimmar" })
	end

	-- a lost window: the game dies, no logout, nothing written. The next login reads the file as of its last write.
	function M.crash(w, c)
		local name = c.player.name
		w:closeClient(c, true)
		return name
	end

	function M.relaunch(w, name, saved)
		w:player(name).online = true
		return w:addClient(name, { saved = saved, class = "WARLOCK", spot = "Orgrimmar" })
	end

	return M
end
