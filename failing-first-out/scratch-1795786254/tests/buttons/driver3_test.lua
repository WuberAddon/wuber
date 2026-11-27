-- "Every button works", page group driver3 (tests/buttons/lib.lua walks it; tests/buttons/effects.lua says what each control must do).
local T = ...
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)
Lib.groupTests(T, "driver3")
