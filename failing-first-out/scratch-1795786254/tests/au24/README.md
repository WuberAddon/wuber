# tests/au24: audit of the areas unchanged since 2.4 (branch audit-241)

Proof tests (`proof_<area>_test.lua`): each proves one bug of BUGS-NEXT (AU24-nn) in a Wuber file that did not change
between the 2.4 release commit (662d7040) and 2.4.1-joust (5d8ec29f). Each FAILS on 2.4.1-joust.
So the suite stays green, the normal run wraps the body: the test passes while the body fails, and fails
("now passes: the bug looks fixed") once the fix lands; then turn it into a normal test.
Run the bodies for real (they must fail before the fix, pass after):
`WUBER_AU24_PROOF=1 lua5.1 tests/run.lua "AU24-"`

The helper, copied into each proof file (no shared file, so readers never conflict):

```lua
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end
```
