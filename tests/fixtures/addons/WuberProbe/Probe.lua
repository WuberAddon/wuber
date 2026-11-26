-- Test fixture (tests/core/registry_test.lua): a module with a missing dependency and a late
-- ref to a module nobody defines. Wuber's PLAYER_LOGIN runs W.CheckModules, which reports both.
local W = Wuber
local Mod = W.Module("Probe.Main", { "Probe.Missing" })
local Ghost = W.Mod("Probe.Ghost")
Mod.ghost = Ghost
