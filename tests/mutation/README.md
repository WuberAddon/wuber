# tests/mutation

Tests written from the mutation run (tools/audit/): each guards a line that no other test noticed when it was broken.
Every test here names the line it guards and was proven to fail with that line broken (tools/audit/prove_mutant.py).
run.lua loads every *_test.lua in this folder.
