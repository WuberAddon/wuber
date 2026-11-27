# tests/h24: the 2.4.1 hardening night (branch harden-241)

Two kinds of test, both loaded by run.lua like every other folder (files ending _test.lua):

- **Break-it guards** (`bk_<area>_test.lua`): each passes on the real 2.4.1 code and fails when a changed line
  of 2.4.1 is broken on purpose (the break is named in the test's comment). Tagged `-- guard: break-it ...`:
  they pass on the base by design.
- **Proof tests** (`proof_<area>_test.lua`): each proves one bug of BUGS-NEXT (H24-nn). It FAILS on 2.4.1-joust.
  So the suite stays green, the normal run wraps the body: the test passes while the body fails, and fails
  ("now passes: the bug looks fixed") once the fix lands; then turn it into a normal test.
  Run the bodies for real (they must fail before the fix, pass after):
  `WUBER_H24_PROOF=1 lua5.1 tests/run.lua "H24-"`

The helper, copied into each proof file (no shared file, so groups never conflict):

```lua
local function proof(id, name, fn)
	if os.getenv("WUBER_H24_PROOF") then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end
```
