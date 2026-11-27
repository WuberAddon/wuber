# tests/r27: the 2.3.4 fix rounds' tests

Every `*_test.lua` here is loaded by tests/run.lua in name order (no line to add there).
One file per round group, named `r<round>_<group>_<topic>_test.lua`. Each starts with `local T = ...`
and uses these helpers:
T.test, T.eq, T.ok, T.H, T.newWorld, T.rider, T.driver, T.settle, T.clean, T.goOnline, T.take, T.fields, ...
