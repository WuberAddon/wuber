-- Module: Core.Registry
-- Purpose: NEW. The module registry. Every other file starts with
--   local Mod = W.Module("Area.Name", { "Dep.One", ... })
-- and reaches another module's internals only through W.Mod("Area.Name").
-- Nothing here calls another module; W.CheckModules runs once, at PLAYER_LOGIN.
-- API: W.Module, W.Mod, W.modules, W.CheckModules
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: (none: Core.Runtime's PLAYER_LOGIN handler calls W.CheckModules)
-- Standalone: no
-- Test: tests/core/registry_test.lua
-- From: new (REFACTOR-MAP 3.2; the code was at the end of Core.lua since restructure step 0)
--
local _, W = ...

local tables, order, wanted = {}, {}, {}
W.modules = {} -- name -> { seq, deps, opts }: read by tools/map.lua (in game: /dump), tests

local function slot(name)
	local t = tables[name]
	if not t then
		t = {}
		tables[name] = t
	end
	return t
end

-- Defines a module; returns its private table (the same table W.Mod(name) gives anyone).
function W.Module(name, deps, opts)
	if W.modules[name] then error("Wuber: module " .. tostring(name) .. " is defined twice", 2) end
	order[#order + 1] = name
	W.modules[name] = { seq = #order, deps = deps or {}, opts = opts or {} }
	return slot(name)
end

-- Another module's private table. It may be filled later in the load (a late ref); it is
-- only checked at login.
function W.Mod(name)
	wanted[name] = true
	return slot(name)
end

-- Every declared dependency loaded, and loaded first (a module that names itself as a dependency
-- did not load before itself, so it is reported too); every W.Mod target exists (skipped when
-- the test harness loads only part of the addon: W.partialLoad). Problems go to W.Error
-- (so W.lastError fails every test); returns the list, sorted.
function W.CheckModules()
	local problems = {}
	for _, name in ipairs(order) do
		local me = W.modules[name]
		for _, dep in ipairs(me.deps) do
			local d = W.modules[dep]
			if not d then
				problems[#problems + 1] = name .. " needs " .. tostring(dep) .. ", which is not loaded"
			elseif d.seq >= me.seq then
				problems[#problems + 1] = name .. " loads before its dependency " .. dep
			end
		end
	end
	if not W.partialLoad then
		for name in pairs(wanted) do
			if not W.modules[name] then problems[#problems + 1] = "no module named " .. name end
		end
	end
	table.sort(problems)
	for _, p in ipairs(problems) do W.Error("modules", p) end
	return problems
end

-- the registry is a module too (registered once W.Module exists)
local Mod = W.Module("Core.Registry", {})
