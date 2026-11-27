-- tests/lib/contract.lua: the contract test every new module's test file starts with
-- (REFACTOR-MAP 4.2): the module is registered, its dependencies are exactly its header's
-- `Uses:`, its header names this test file, and every public name it promises exists with the
-- right type. Round 8 uses it for the 17 new modules.
--
--   local W, w, r, Mod = T.contract("Net.Portal", "tests/net/portal_test.lua",
--       { ["W.Passphrase"] = "function", ["W.Bounty.Demand"] = "function", ["Mod.Month"] = "function" })
--   ... the module's own checks ...
--   T.clean(w)
--
-- Roots for the names: W (the addon's namespace), UI (W.UI), DR (W.Drive), D (W.Driver), T
-- (W.Theme) and Mod (the module's own table, W.Mod(name)). A rider (the whole addon, logged in)
-- is made in a new world; the caller cleans it.

return function(T)
	local eq, ok, list = T.eq, T.ok, T.list

	local function header(src, field)
		local v = src:match("\n%-%- " .. field .. ": ([^\n]*)") or src:match("^%-%- " .. field .. ": ([^\n]*)")
		return v and (v:gsub("%s+$", "")) or nil
	end

	local function usesList(v)
		local out = {}
		if not v or v:match("^%(none") then return out end
		for name in v:gmatch("[%w%.]+") do out[#out + 1] = name end
		return out
	end

	local function resolve(roots, path)
		local root, rest = path:match("^([%a_]+)(.*)$")
		local v = roots[root]
		for part in rest:gmatch("%.([%w_]+)") do
			if type(v) ~= "table" then return nil end
			v = v[part]
		end
		return v
	end

	return function(name, testPath, api)
		local w = T.newWorld()
		local r = T.rider(w)
		local W = r.W
		ok(W and W.modules, "the addon loaded (W.modules)")
		local m = W.modules[name]
		ok(m, name .. " is registered (W.modules)")
		local file = name:gsub("%.", "/") .. ".lua"
		local src = T.readFile(T.dir .. "/../Wuber/" .. file)
		ok(src, "Wuber/" .. file .. " exists")
		eq(header(src, "Module"), name, "the header's Module")
		eq(list(m and m.deps or {}, ", "), list(usesList(header(src, "Uses")), ", "), name .. "'s deps = its header's Uses")
		eq(header(src, "Test"), testPath, "the header's Test names this file")
		local Mod = W.Mod(name)
		local roots = { W = W, UI = W.UI, DR = W.Drive, D = W.Driver, T = W.Theme, Mod = Mod }
		local names = {}
		for path in pairs(api or {}) do names[#names + 1] = path end
		table.sort(names)
		for _, path in ipairs(names) do
			eq(type(resolve(roots, path)), api[path], path)
		end
		eq(#w.errors, 0, "no errors at load: " .. list(w.errors, "\n"))
		return W, w, r, Mod
	end
end
