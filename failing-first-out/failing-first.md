# Failing-first: 4 new test(s) since origin/main, run on the base addon (hook: patch)

| test | file | on base | note |
|---|---|---|---|
| #80 Simple, folded: Save on the advert line leaves the screen and lists no other message | simple80/advert_save_test.lua | FAIL (error, not an assertion) | tests/simple80/advert_save_test.lua:29: back on the console: expected console, got messages stack traceback:  [C]: in function 'error'  tests/run.lua:176: in function 'eq'  tests/simple80/advert_save_test.lua:29: in function <tests/simple80/advert_save_test.lua:24>  [C]: in function 'xpcall'  tests/ |
| #80 guard: Advanced, folded: Save shows the list of messages | simple80/advert_save_test.lua | PASS (guard) | Advanced keeps the list of messages after Save |
| #80 guard: Advanced, unfolded: the list stays beside the editor | simple80/advert_save_test.lua | PASS (guard) | Advanced unfolded keeps the list beside the editor |
| #80 guard: Simple on a wide screen stays folded: no side pane, no message rows | simple80/advert_save_test.lua | PASS (guard) | Simple mode is always folded, so the unfolded side pane can never list the other messages |
