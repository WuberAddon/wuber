#!/usr/bin/env python3
"""Tests for tools/contract-check.py (blind-spot check BS3, job 206). Run: python -m unittest tools/test_contract_check.py

Proves that the checker
1. exits 0 on this tree (the realm and flight-map fixes have fallbacks it knows) and lists both as
   COVERED_BY_FALLBACK, not hidden;
2. still exits 1 with both CRITICAL findings for source that relies on TAXIMAP_OPENED and GetRealmName()
   with no fallback (the old code, in a scratch Wuber folder) against recordings that show the real client
   never fires TAXIMAP_OPENED and gives an empty realm;
3. exits 0 for recordings that satisfy every contract.
It reads recordings read-only; the synthetic ones live in a temp folder.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOL = REPO_ROOT / "tools" / "contract-check.py"

BAD_REC = """
WuberRecDB = { sessions = { { seen = { ["TAXIMAP_CLOSED"] = 3, ["PLAYER_LOGIN"] = 1 },
  once = { client = { realmGot = { ["GetRealmName"] = "string:0" } } } } } }
"""
GOOD_REC = """
WuberRecDB = { sessions = { { seen = { ["TAXIMAP_OPENED"] = 2, ["TAXIMAP_CLOSED"] = 2 },
  once = { client = { realmGot = { ["GetRealmName"] = "string:23" } } } } } }
"""
# The old code: relies on the event and on the realm name with no fallback.
OLD_LUA = """
W.On("TAXIMAP_OPENED", function() end)
W.On("TAXIMAP_CLOSED", function() end)
function W.Ruleset() return GetRealmName() end
"""


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(TOOL), *args], cwd=str(REPO_ROOT), capture_output=True, text=True)


class ContractCheckTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        (self.tmp / "wtf").mkdir()
        (self.tmp / "fixtures").mkdir()
        (self.tmp / "bad.lua").write_text(BAD_REC, encoding="utf-8")
        (self.tmp / "good.lua").write_text(GOOD_REC, encoding="utf-8")
        (self.tmp / "oldaddon" / "Core").mkdir(parents=True)
        (self.tmp / "oldaddon" / "Core" / "Base.lua").write_text(OLD_LUA, encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def common(self, rec: str, wuber: Path | None = None) -> list[str]:
        a = ["--wtf", str(self.tmp / "wtf"), "--fixtures", str(self.tmp / "fixtures"), "--rec", str(self.tmp / rec)]
        if wuber:
            a += ["--wuber", str(wuber)]
        return a

    def test_this_tree_is_clean_and_fallbacks_are_listed(self) -> None:
        proc = run("--json", *self.common("bad.lua"))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        data = json.loads(proc.stdout)
        self.assertEqual(data["violations"], [])
        covered = {c["symbol"] for c in data["covered"]}
        self.assertEqual(covered, {"TAXIMAP_OPENED", "GetRealmName()"})

    def test_old_code_without_fallback_is_critical(self) -> None:
        proc = run("--json", *self.common("bad.lua", self.tmp / "oldaddon"))
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        symbols = {v["symbol"] for v in json.loads(proc.stdout)["violations"]}
        self.assertEqual(symbols, {"TAXIMAP_OPENED", "GetRealmName()"})

    def test_good_recording_passes_even_for_old_code(self) -> None:
        proc = run(*self.common("good.lua", self.tmp / "oldaddon"))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_a_fallback_must_really_be_in_the_code(self) -> None:
        # the file is named in FALLBACKS but lacks the fallback: still critical
        lua = self.tmp / "oldaddon" / "Core" / "Flights.lua"
        lua.write_text('W.On("TAXIMAP_OPENED", function() end)\n-- TaxiFrame HookScript "OnShow" (a comment only)\n', encoding="utf-8")
        proc = run("--json", *self.common("bad.lua", self.tmp / "oldaddon"))
        flights = [v for v in json.loads(proc.stdout)["violations"] if v["symbol"] == "TAXIMAP_OPENED"]
        self.assertTrue(any(loc["file"] == "Core/Flights.lua" for loc in flights[0]["locations"]))

    # --- --gate (job 211) ---
    def gate(self, rec: str, wuber: Path | None, known: str | None = None) -> subprocess.CompletedProcess:
        kf = self.tmp / "known.txt"
        kf.write_text(known or "", encoding="utf-8")
        return run("--gate", "--known", str(kf), *self.common(rec, wuber))

    def test_gate_old_code_fails_naming_both(self) -> None:
        proc = self.gate("bad.lua", self.tmp / "oldaddon")
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertIn("FAIL TAXIMAP_OPENED", proc.stdout)
        self.assertIn("FAIL GetRealmName()", proc.stdout)
        self.assertIn("Core/Base.lua:", proc.stdout)
        self.assertIn("contract-known.txt", proc.stdout)
        self.assertTrue(proc.stdout.strip().splitlines()[-1].startswith("GAUNTLET recordings result=fail unseen=2 "))

    def test_gate_known_line_clears_it(self) -> None:
        proc = self.gate("bad.lua", self.tmp / "oldaddon", "TAXIMAP_OPENED\tdeliberate\nGetRealmName()\tdeliberate\n")
        self.assertEqual(proc.returncode, 0, proc.stdout)
        self.assertIn("result=pass unseen=0 covered=0 known=2 ", proc.stdout.strip().splitlines()[-1])

    def test_gate_known_line_without_reason_does_not_count(self) -> None:
        proc = self.gate("bad.lua", self.tmp / "oldaddon", "TAXIMAP_OPENED\nGetRealmName()\t\n")
        self.assertEqual(proc.returncode, 1, proc.stdout)

    def test_gate_fallback_counts_as_covered(self) -> None:
        proc = self.gate("bad.lua", None)  # this tree: fallbacks cover both; the rest is unseen
        last = proc.stdout.strip().splitlines()[-1]
        self.assertIn("covered=2", last)
        self.assertNotIn("FAIL TAXIMAP_OPENED", proc.stdout)
        self.assertNotIn("FAIL GetRealmName()", proc.stdout)

    def test_gate_good_recording_passes(self) -> None:
        proc = self.gate("good.lua", self.tmp / "oldaddon")
        self.assertEqual(proc.returncode, 0, proc.stdout)
        self.assertIn("GAUNTLET recordings result=pass unseen=0 ", proc.stdout)

    def test_gate_bad_wuber_is_exit_2(self) -> None:
        proc = self.gate("good.lua", self.tmp / "nothere")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("result=error", proc.stdout.strip().splitlines()[-1])

    def test_gate_no_recordings_is_exit_2(self) -> None:
        empty = self.tmp / "empty.lua"
        empty.write_text("WuberRecDB = {}\n", encoding="utf-8")
        proc = run("--gate", "--wtf", str(self.tmp / "wtf"), "--fixtures", str(self.tmp / "fixtures"),
                   "--rec", str(empty), "--wuber", str(self.tmp / "oldaddon"))
        self.assertEqual(proc.returncode, 2, proc.stdout)
        self.assertIn("result=error", proc.stdout.strip().splitlines()[-1])

    def test_gate_target_fixtures_default_to_its_own_tests_folder(self) -> None:
        (self.tmp / "target" / "Wuber" / "Core").mkdir(parents=True)
        (self.tmp / "target" / "tests" / "fixtures" / "rec").mkdir(parents=True)
        (self.tmp / "target" / "Wuber" / "Core" / "A.lua").write_text('W.On("TAXIMAP_CLOSED", function() end)\n', encoding="utf-8")
        proc = run("--gate", "--wtf", str(self.tmp / "wtf"), "--rec", str(self.tmp / "good.lua"),
                   "--wuber", str(self.tmp / "target" / "Wuber"), "--known", str(self.tmp / "none.txt"), "--json")
        # json mode prints the report then the GAUNTLET line; sources must not include this repo's fixtures
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertNotIn(str(REPO_ROOT / "tests" / "fixtures" / "rec"), proc.stdout.replace("\\\\", "\\"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
