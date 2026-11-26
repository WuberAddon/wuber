#!/usr/bin/env python3
"""Contract checker for Wuber: extracts registered WoW events and game value
assumptions from repo/Wuber/**/*.lua and cross-checks them against real
WuberRec recordings and lab-real-facts fixtures.

Exits non-zero when critical contract violations are found (default / --strict).

--gate (gauntlet method "recordings"): every UNSEEN event or value contract (a registered event never seen in
the recordings, a value the recordings show unusable, an API the client lacks) is a FAILURE, unless a fallback
in FALLBACKS covers it or tools/contract-known.txt lists it (name<TAB>reason). Exit 0 pass / 1 fail / 2 could not
run. Last line: GAUNTLET recordings result=<pass|fail|error> unseen= covered= known= events= values=

Where the recordings come from: the real WuberRec SavedVariables (--wtf, default the game's _forever_/WTF
Account/*/SavedVariables/WuberRec.lua; --rec adds files) plus the fixtures folder (--fixtures; default
<target>/../tests/fixtures/rec when the target has its own, else this tool's repo): lab-real-facts.lua and any
game-*.lua. sim-*.lua (the fake game) never counts. A bare copy of an addon (only Wuber/) therefore borrows
the recordings of the repo this tool lives in.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


DEFAULT_WTF = Path("C:/Program Files (x86)/World of Warcraft/_forever_/WTF")
DEFAULT_WUBERREC_DATA = Path("lab/WuberRec/Data.lua")

# Paired events: if the counterpart is observed in real recordings while the
# target event is never observed, that is a critical contract violation.
EVENT_COUNTERPARTS: dict[str, list[str]] = {
    "TAXIMAP_OPENED": ["TAXIMAP_CLOSED"],
    "TAXIMAP_CLOSED": ["TAXIMAP_OPENED"],
    "PLAYER_CONTROL_LOST": ["PLAYER_CONTROL_GAINED"],
    "PLAYER_CONTROL_GAINED": ["PLAYER_CONTROL_LOST"],
    "TRADE_SHOW": ["TRADE_CLOSED"],
    "TRADE_CLOSED": ["TRADE_SHOW"],
    "PLAYER_REGEN_DISABLED": ["PLAYER_REGEN_ENABLED"],
    "PLAYER_REGEN_ENABLED": ["PLAYER_REGEN_DISABLED"],
    "CONFIRM_SUMMON": ["CANCEL_SUMMON"],
}

# Key game value / API contracts that Wuber relies on.
KEY_APIS = [
    "GetRealmName",
    "GetNormalizedRealmName",
    "IsInGroup",
    "IsInRaid",
    "AcceptGroup",
    "GetSummonConfirmSummoner",
    "GetZonePVPInfo",
    "C_IncomingSummon",
    "C_Map.GetMapInfoAtPosition",
    "C_ChatInfo.RequestCanLocalWhisperTarget",
    "C_Club",
]


# Known fallbacks (job 206, after the in-game run 1 fixes). A contract the real client breaks is only CRITICAL
# while some place that relies on it has no fallback. Each entry says, per source file (path under Wuber/), a regex
# that must match the comment-stripped code of that file; a file that matches is covered, a file that does not
# (or is not listed) stays CRITICAL. A covered finding is still printed, as [INFO] COVERED_BY_FALLBACK, never hidden.
# Add an entry only when the code really has the fallback, and say which commit made it.
FALLBACKS: dict[str, dict[str, str]] = {
    # c1327b2c: W.Ruleset asks UnitFullName("player") when GetRealmName / GetNormalizedRealmName give "";
    # Runtime.ownRealm gives "" when unknown and IsRealmTail then accepts a Forever server node (digits).
    "GetRealmName()": {
        "Core/Base.lua": r"UnitFullName",
        "Core/Runtime.lua": r"IsRealmTail[\s\S]*?%d",
        # RealmHere is only shown by /wuber status (the header says "" when unknown, "no logic"; code is matched, not comments): an empty name costs nothing
        "Net/Beacons.lua": r"W\.RealmHere[\s\S]*?CleanRealm[\s\S]*?return \"\"",
    },
    # in-game run 1: the real client fires TAXIMAP_CLOSED, never TAXIMAP_OPENED; the map frame's OnShow opens it too.
    "TAXIMAP_OPENED": {
        "Core/Flights.lua": r"TaxiFrame[\s\S]*?HookScript\s*,\s*f\s*,\s*\"OnShow\"",
        "UI/Bird.lua": r"FLIGHTMAP_SHOWN",
        "UI/FlightPins.lua": r"HookScript\s*,\s*f\s*,\s*\"OnShow\"",
    },
}


def split_by_fallback(symbol: str, locs: list[dict[str, Any]], wuber_dir: Path | None) -> tuple[list, list]:
    """Split locations into (uncovered, covered) by FALLBACKS[symbol] (see above)."""
    table = FALLBACKS.get(symbol)
    if not table or wuber_dir is None:
        return list(locs), []
    uncovered: list[dict[str, Any]] = []
    covered: list[dict[str, Any]] = []
    cache: dict[str, str] = {}
    for loc in locs:
        pat = table.get(loc["file"])
        ok = False
        if pat:
            if loc["file"] not in cache:
                try:
                    cache[loc["file"]] = strip_lua_comments((wuber_dir / loc["file"]).read_text(encoding="utf-8", errors="replace"))
                except OSError:
                    cache[loc["file"]] = ""
            ok = re.search(pat, cache[loc["file"]]) is not None
        (covered if ok else uncovered).append(loc)
    return uncovered, covered


def strip_lua_comments(src: str) -> str:
    """Strip Lua -- and --[[...]] comments while preserving newlines and strings."""
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            # Check for long comment --[=[ ... ]=]
            m = re.match(r"^--\[(=*)\[", src[i:])
            if m:
                eqs = m.group(1)
                end_pat = "]" + eqs + "]"
                end_idx = src.find(end_pat, i + len(m.group(0)))
                if end_idx == -1:
                    chunk = src[i:]
                    i = n
                else:
                    chunk = src[i : end_idx + len(end_pat)]
                    i = end_idx + len(end_pat)
                out.append(re.sub(r"[^\n]", " ", chunk))
            else:
                end_idx = src.find("\n", i)
                if end_idx == -1:
                    out.append(" " * (n - i))
                    i = n
                else:
                    out.append(" " * (end_idx - i))
                    i = end_idx
        elif ch in ('"', "'"):
            quote = ch
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == quote or src[j] == "\n":
                    j += 1
                    break
                j += 1
            out.append(src[i:j])
            i = j
        elif ch == "[":
            m = re.match(r"^\[(=*)\[", src[i:])
            if m:
                eqs = m.group(1)
                end_pat = "]" + eqs + "]"
                end_idx = src.find(end_pat, i + len(m.group(0)))
                if end_idx == -1:
                    out.append(src[i:])
                    i = n
                else:
                    end_pos = end_idx + len(end_pat)
                    out.append(src[i:end_pos])
                    i = end_pos
            else:
                out.append(ch)
                i += 1
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def line_number_at(src: str, pos: int) -> int:
    return src.count("\n", 0, pos) + 1


def scan_wuber_source(wuber_dir: Path) -> dict[str, Any]:
    """Scan repo/Wuber/**/*.lua for registered WoW events and key game value/API uses."""
    events: dict[str, list[dict[str, Any]]] = defaultdict(list)
    api_uses: dict[str, list[dict[str, Any]]] = defaultdict(list)
    lua_files = sorted(wuber_dir.rglob("*.lua"))

    re_direct_ev = re.compile(
        r"""\b(?:W\.On|RegisterEvent|RegisterUnitEvent)\s*\(\s*["']([A-Z][A-Z0-9_]+)["']"""
    )
    re_loop_ev = re.compile(
        r"""for\s+[\w_]+\s*,\s*([A-Za-z_]\w*)\s+in\s+ipairs\s*\(\s*\{([^}]*)\}\s*\)\s*do\b"""
    )
    re_var_on = re.compile(
        r"""\b(?:W\.On|RegisterEvent|RegisterUnitEvent)\s*\(\s*([A-Za-z_]\w*)\s*,"""
    )

    for path in lua_files:
        rel = path.relative_to(wuber_dir).as_posix()
        raw = path.read_text(encoding="utf-8", errors="replace")
        cleaned = strip_lua_comments(raw)

        # Direct W.On("EVENT", ...) / RegisterEvent("EVENT")
        for m in re_direct_ev.finditer(cleaned):
            ev = m.group(1)
            events[ev].append({"file": rel, "line": line_number_at(cleaned, m.start())})

        # Loop-fed W.On(ev, ...)
        loops = [(m.start(), m.group(1), m.group(2)) for m in re_loop_ev.finditer(cleaned)]
        for m in re_var_on.finditer(cleaned):
            var = m.group(1)
            pos = m.start()
            best_list = None
            for lpos, lvar, lbody in loops:
                if lpos < pos and lvar == var:
                    best_list = lbody
            if best_list:
                for sm in re.finditer(r"""["']([A-Z][A-Z0-9_]+)["']""", best_list):
                    events[sm.group(1)].append(
                        {"file": rel, "line": line_number_at(cleaned, m.start())}
                    )

        # Key APIs / game values
        for api in KEY_APIS:
            pat = re.compile(r"\b" + re.escape(api) + r"\b")
            for m in pat.finditer(cleaned):
                api_uses[api].append({"file": rel, "line": line_number_at(cleaned, m.start())})

    return {
        "files_scanned": len(lua_files),
        "events": dict(events),
        "api_uses": dict(api_uses),
    }


def _extract_balanced_block(text: str, start_brace: int) -> str:
    """Return substring from start_brace '{' to its matching '}'."""
    depth = 0
    i = start_brace
    n = len(text)
    in_str: str | None = None
    while i < n:
        ch = text[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = None
        else:
            if ch in ('"', "'"):
                in_str = ch
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return text[start_brace : i + 1]
        i += 1
    return text[start_brace:]


def parse_wuberrec_sv(path: Path) -> dict[str, Any]:
    """Parse a real WuberRec.lua SavedVariables file (read-only) for seen events,
    unknownEvents, realmGot, and missing APIs."""
    text = path.read_text(encoding="utf-8", errors="replace")
    seen_counts: dict[str, int] = defaultdict(int)
    unknown_events: set[str] = set()
    realm_got: list[dict[str, Any]] = []
    missing_apis: set[str] = set()
    present_apis: set[str] = set()
    sessions = 0

    # Count sessions by ["seen"] or seen = { blocks
    for m in re.finditer(r'(?:\["seen"\]|\bseen)\s*=\s*\{', text):
        sessions += 1
        block = _extract_balanced_block(text, m.end() - 1)
        for em in re.finditer(r'(?:\["([A-Z][A-Z0-9_]+)"\]|\b([A-Z][A-Z0-9_]+))\s*=\s*(\d+)', block):
            ev = em.group(1) or em.group(2)
            seen_counts[ev] += int(em.group(3))

    # Also check unknownEvents
    for m in re.finditer(r'(?:\["unknownEvents"\]|\bunknownEvents)\s*=\s*\{', text):
        block = _extract_balanced_block(text, m.end() - 1)
        for sm in re.finditer(r'"([A-Z][A-Z0-9_]+)"', block):
            unknown_events.add(sm.group(1))

    # Extract realmGot blocks
    for m in re.finditer(r'(?:\["realmGot"\]|\brealmGot)\s*=\s*\{', text):
        block = _extract_balanced_block(text, m.end() - 1)
        entry: dict[str, Any] = {"source": str(path)}
        for fn in ("GetRealmName", "GetNormalizedRealmName"):
            fm = re.search(rf'(?:\["{fn}"\]|\b{fn})\s*=\s*"([^"]*)"', block)
            if fm:
                entry[fn] = fm.group(1)
        if len(entry) > 1:
            realm_got.append(entry)

    # Extract missing APIs
    for m in re.finditer(r'\["missing"\]\s*=\s*\{', text):
        block = _extract_balanced_block(text, m.end() - 1)
        for am in re.finditer(r'"([A-Za-z_][A-Za-z0-9_.]*)"', block):
            missing_apis.add(am.group(1))

    # Extract present APIs
    for m in re.finditer(r'\["api"\]\s*=\s*\{', text):
        block = _extract_balanced_block(text, m.end() - 1)
        for am in re.finditer(r'\["([A-Za-z_][A-Za-z0-9_.]*)"\]\s*=\s*"[^"]+"', block):
            present_apis.add(am.group(1))

    return {
        "source": str(path),
        "sessions": sessions,
        "seen": dict(seen_counts),
        "unknown_events": sorted(unknown_events),
        "realm_got": realm_got,
        "missing_apis": sorted(missing_apis),
        "present_apis": sorted(present_apis),
    }


def parse_fixture_rec(path: Path) -> dict[str, Any]:
    """Parse an imported fixture (game-*.lua or sim-*.lua) in repo/tests/fixtures/rec."""
    text = path.read_text(encoding="utf-8", errors="replace")
    seen_counts: dict[str, int] = defaultdict(int)
    realm_got: list[dict[str, Any]] = []
    missing_apis: set[str] = set()

    for m in re.finditer(r'\be\s*=\s*"([A-Z][A-Z0-9_]+)"', text):
        seen_counts[m.group(1)] += 1
    for m in re.finditer(r'id\s*=\s*"api:([^"]+)"[^}]*v\s*=\s*"missing"', text):
        missing_apis.add(m.group(1))
    for m in re.finditer(r'id\s*=\s*"realmGot\.([^"]+)"[^}]*v\s*=\s*"([^"]*)"', text):
        realm_got.append({"source": str(path), m.group(1): m.group(2)})

    return {
        "source": str(path),
        "seen": dict(seen_counts),
        "realm_got": realm_got,
        "missing_apis": sorted(missing_apis),
    }


def parse_lab_real_facts(path: Path) -> dict[str, Any]:
    """Parse repo/tests/fixtures/rec/lab-real-facts.lua for known real-client facts."""
    text = path.read_text(encoding="utf-8", errors="replace")
    facts: dict[str, dict[str, str]] = {}
    for m in re.finditer(r'\{\s*id\s*=\s*"([^"]+)"', text):
        fid = m.group(1)
        block = _extract_balanced_block(text, m.start())
        fact_m = re.search(r'fact\s*=\s*"((?:[^"\\]|\\.)*)"', block)
        val_m = re.search(r'value\s*=\s*"((?:[^"\\]|\\.)*)"', block)
        verdict_m = re.search(r'verdict\s*=\s*"((?:[^"\\]|\\.)*)"', block)
        facts[fid] = {
            "fact": fact_m.group(1) if fact_m else "",
            "value": val_m.group(1) if val_m else "",
            "verdict": verdict_m.group(1) if verdict_m else "",
        }
    return facts


def collect_recordings(
    fixtures_dir: Path | None,
    wtf_dir: Path | None,
    rec_files: list[Path],
    include_sim: bool = False,
) -> dict[str, Any]:
    """Aggregate real recording evidence from WuberRec.lua files and fixtures."""
    seen_real: dict[str, int] = defaultdict(int)
    seen_sim: dict[str, int] = defaultdict(int)
    unknown_events: set[str] = set()
    realm_got: list[dict[str, Any]] = []
    missing_apis: set[str] = set()
    lab_facts: dict[str, dict[str, str]] = {}
    sources: list[str] = []

    sv_paths: list[Path] = list(rec_files)
    if wtf_dir and wtf_dir.exists():
        for p in sorted(wtf_dir.glob("Account/*/SavedVariables/WuberRec.lua")):
            if p not in sv_paths:
                sv_paths.append(p)

    for p in sv_paths:
        if not p.exists():
            continue
        sources.append(str(p))
        parsed = parse_wuberrec_sv(p)
        for ev, cnt in parsed["seen"].items():
            seen_real[ev] += cnt
        unknown_events.update(parsed["unknown_events"])
        realm_got.extend(parsed["realm_got"])
        missing_apis.update(parsed["missing_apis"])

    if fixtures_dir and fixtures_dir.exists():
        lrf = fixtures_dir / "lab-real-facts.lua"
        if lrf.exists():
            sources.append(str(lrf))
            lab_facts = parse_lab_real_facts(lrf)

        for p in sorted(fixtures_dir.glob("game-*.lua")):
            sources.append(str(p))
            parsed = parse_fixture_rec(p)
            for ev, cnt in parsed["seen"].items():
                seen_real[ev] += cnt
            realm_got.extend(parsed["realm_got"])
            missing_apis.update(parsed["missing_apis"])

        for p in sorted(fixtures_dir.glob("sim-*.lua")):
            parsed = parse_fixture_rec(p)
            for ev, cnt in parsed["seen"].items():
                seen_sim[ev] += cnt
            if include_sim:
                sources.append(str(p))
                for ev, cnt in parsed["seen"].items():
                    seen_real[ev] += cnt

    return {
        "sources": sources,
        "seen_real": dict(seen_real),
        "seen_sim": dict(seen_sim),
        "unknown_events": sorted(unknown_events),
        "realm_got": realm_got,
        "missing_apis": sorted(missing_apis),
        "lab_facts": lab_facts,
    }


def evaluate_contracts(
    wuber_scan: dict[str, Any],
    recordings: dict[str, Any],
    fail_on_all_unseen: bool = False,
    wuber_dir: Path | None = None,
) -> dict[str, Any]:
    """Cross-check Wuber's extracted events and API assumptions against real recordings."""
    violations: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    covered_notes: list[dict[str, Any]] = []
    unseen_events: list[str] = []

    reg_events: dict[str, list[dict[str, Any]]] = wuber_scan["events"]
    seen_real: dict[str, int] = recordings["seen_real"]
    seen_sim: dict[str, int] = recordings["seen_sim"]
    unknown_events: set[str] = set(recordings["unknown_events"])
    realm_got: list[dict[str, Any]] = recordings["realm_got"]
    missing_apis: set[str] = set(recordings["missing_apis"])
    lab_facts: dict[str, dict[str, str]] = recordings["lab_facts"]
    has_real_event_stream = len(seen_real) > 0

    # 1. Event contract checks
    for ev in sorted(reg_events.keys()):
        locs = reg_events[ev]
        loc_str = ", ".join(f"{x['file']}:{x['line']}" for x in locs[:4])
        if len(locs) > 4:
            loc_str += f" (+{len(locs) - 4} more)"

        if ev in unknown_events:
            violations.append(
                {
                    "severity": "CRITICAL",
                    "kind": "UNKNOWN_EVENT",
                    "symbol": ev,
                    "message": f"{ev} is registered by Wuber ({loc_str}) but refused by real client (unknownEvents).",
                    "locations": locs,
                }
            )
            continue

        count_real = seen_real.get(ev, 0)
        if has_real_event_stream and count_real == 0:
            unseen_events.append(ev)
            counterparts = EVENT_COUNTERPARTS.get(ev, [])
            seen_counterparts = [c for c in counterparts if seen_real.get(c, 0) > 0]
            sim_count = seen_sim.get(ev, 0)

            uncovered, covered = split_by_fallback(ev, locs, wuber_dir)
            if covered and (seen_counterparts or fail_on_all_unseen):
                covered_notes.append(
                    {
                        "severity": "INFO",
                        "kind": "COVERED_BY_FALLBACK",
                        "symbol": ev,
                        "message": f"{ev} never fires in the real client, but has a fallback at "
                        + ", ".join(f"{x['file']}:{x['line']}" for x in covered[:4]),
                        "locations": covered,
                    }
                )
            if (seen_counterparts or fail_on_all_unseen) and (uncovered or not covered):
                locs = uncovered or locs
                loc_str = ", ".join(f"{x['file']}:{x['line']}" for x in locs[:4])
                detail = (
                    f"counterpart {', '.join(f'{c}={seen_real[c]}' for c in seen_counterparts)} WAS seen"
                    if seen_counterparts
                    else "never seen in real recordings"
                )
                if sim_count > 0:
                    detail += f" (fake/sim fired it {sim_count}x!)"
                violations.append(
                    {
                        "severity": "CRITICAL",
                        "kind": "UNSEEN_EVENT",
                        "symbol": ev,
                        "message": f"{ev} registered at {loc_str} has NEVER been seen in real recordings ({detail}).",
                        "locations": locs,
                    }
                )
            else:
                warnings.append(
                    {
                        "severity": "WARN",
                        "kind": "UNSEEN_EVENT",
                        "symbol": ev,
                        "message": f"{ev} registered at {loc_str} was not observed in sampled real recordings.",
                        "locations": locs,
                    }
                )

    # 2. Game value / API contract checks
    api_uses: dict[str, list[dict[str, Any]]] = wuber_scan["api_uses"]

    # 2a. GetRealmName() returning "" / unusable
    if "GetRealmName" in api_uses:
        empty_samples = [
            r for r in realm_got if r.get("GetRealmName") in ("string:0", "", "nil", "secret", "missing")
        ]
        fact_empty = lab_facts.get("realm.name.empty71037")
        if empty_samples or fact_empty:
            all_locs = api_uses["GetRealmName"]
            locs, covered = split_by_fallback("GetRealmName()", all_locs, wuber_dir)
            if covered:
                covered_notes.append(
                    {
                        "severity": "INFO",
                        "kind": "COVERED_BY_FALLBACK",
                        "symbol": "GetRealmName()",
                        "message": "GetRealmName() is empty in the real client, but has a fallback at "
                        + ", ".join(f"{x['file']}:{x['line']}" for x in covered[:4]),
                        "locations": covered,
                    }
                )
        if (empty_samples or fact_empty) and locs:
            loc_str = ", ".join(f"{x['file']}:{x['line']}" for x in locs[:4])
            sample_vals = sorted({str(r.get("GetRealmName")) for r in empty_samples})
            evidence = (
                f"realmGot.GetRealmName={sample_vals}"
                if empty_samples
                else f"lab-real-facts: {fact_empty.get('value', 'unusable')}"
            )
            violations.append(
                {
                    "severity": "CRITICAL",
                    "kind": "VALUE_CONTRACT",
                    "symbol": "GetRealmName()",
                    "message": (
                        f"GetRealmName() returns empty string \"\" / unusable ({evidence}) in real recordings; "
                        f"impacts {loc_str} (W.Ruleset / seed drivers REC-02/REC-03)."
                    ),
                    "locations": locs,
                }
            )

    # 2b. CANCEL_SUMMON on group exit vs IsInGroup()
    if "CANCEL_SUMMON" in reg_events and "IsInGroup" in api_uses:
        cs_count = seen_real.get("CANCEL_SUMMON", 0)
        cs_fact = lab_facts.get("group.leave.cancel_summon")
        if cs_count > 0 or cs_fact:
            locs = reg_events["CANCEL_SUMMON"]
            loc_str = ", ".join(f"{x['file']}:{x['line']}" for x in locs[:3])
            warnings.append(
                {
                    "severity": "WARN",
                    "kind": "EVENT_ORDER_CONTRACT",
                    "symbol": "CANCEL_SUMMON",
                    "message": (
                        f"CANCEL_SUMMON fires on group exit in real client (seen={cs_count}); "
                        f"verify {loc_str} handles IsInGroup() before/after GROUP_ROSTER_UPDATE (REC-04)."
                    ),
                    "locations": locs,
                }
            )

    # 2c. APIs missing in real client that Wuber references
    for api in sorted(missing_apis):
        if api in api_uses:
            locs = api_uses[api]
            loc_str = ", ".join(f"{x['file']}:{x['line']}" for x in locs[:3])
            warnings.append(
                {
                    "severity": "WARN",
                    "kind": "MISSING_API",
                    "symbol": api,
                    "message": f"API {api} is missing on real client (WuberRec once.client.missing); referenced at {loc_str}.",
                    "locations": locs,
                }
            )

    return {
        "violations": violations,
        "warnings": warnings,
        "unseen_events": unseen_events,
        "covered": covered_notes,
    }


DEFAULT_KNOWN = Path(__file__).resolve().parent / "contract-known.txt"


def load_known(path: Path) -> dict[str, str]:
    """tools/contract-known.txt: one line 'name<TAB>reason'; # comments and blank lines are skipped."""
    known: dict[str, str] = {}
    if not path.exists():
        return known
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        name, _, reason = line.partition("\t")
        if name.strip() and reason.strip():
            known[name.strip()] = reason.strip()
    return known


def _locs(locs: list[dict[str, Any]]) -> str:
    s = ", ".join(f"{x['file']}:{x['line']}" for x in locs[:3])
    return s + (f" (+{len(locs) - 3} more)" if len(locs) > 3 else "")


def gate_findings(wuber_scan: dict[str, Any], recordings: dict[str, Any], result: dict[str, Any],
                  wuber_dir: Path, known: dict[str, str]) -> dict[str, Any]:
    """Classify every unseen event / unusable value as fail, covered (fallback) or known (listed)."""
    fails: list[str] = []
    n_known = 0
    done: set[str] = set()

    def judge(symbol: str, locs: list[dict[str, Any]], what: str, why: str) -> None:
        nonlocal n_known
        if symbol in done:
            return
        done.add(symbol)
        if symbol in known:
            n_known += 1
            return
        fails.append(
            f"FAIL {symbol}: {what} at {_locs(locs)}; {why}. Clear it: add a fallback (FALLBACKS in "
            f"tools/contract-check.py), record it with WuberRec, or add '{symbol}<TAB>reason' to tools/contract-known.txt."
        )

    reg = wuber_scan["events"]
    for v in result["violations"]:
        sym = v["symbol"]
        if v["kind"] == "UNKNOWN_EVENT":
            judge(sym, v["locations"], "event refused by the real client", "the handler can never run")
        elif v["kind"] == "VALUE_CONTRACT":
            judge(sym, v["locations"], "value unusable in the recordings", "code that relies on it breaks in the real client")
        else:
            judge(sym, v["locations"], "event never fires in the real client (its pair does)", "the feature waits for it forever")
    for ev in result["unseen_events"]:
        uncovered, _covered = split_by_fallback(ev, reg[ev], wuber_dir)
        if uncovered:
            judge(ev, uncovered, "registered event never seen in the recordings", "it may never fire, so the code behind it is untested against the real client")
    for w in result["warnings"]:
        if w["kind"] == "MISSING_API":
            judge(w["symbol"], w["locations"], "API missing on the real client", "calling it errors unless guarded")
    covered = len({c["symbol"] for c in result["covered"]})
    values = sum(1 for a in KEY_APIS if wuber_scan["api_uses"].get(a))
    return {"fails": fails, "covered": covered, "known": n_known,
            "unseen": len(fails), "events": len(reg), "values": values}


def main(argv: list[str] | None = None) -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Check Wuber event & game-value contracts against real recordings.")
    parser.add_argument("--wuber", type=Path, default=repo_root / "Wuber", help="Path to Wuber addon source directory.")
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=None,
        help="Recording fixtures directory (lab-real-facts.lua, game-*.lua). Default: <wuber>/../tests/fixtures/rec if it exists, else this repo's.",
    )
    parser.add_argument(
        "--wtf",
        type=Path,
        default=DEFAULT_WTF if DEFAULT_WTF.exists() else None,
        help="Optional WoW _forever_/WTF directory containing Account/*/SavedVariables/WuberRec.lua.",
    )
    parser.add_argument(
        "--rec",
        type=Path,
        action="append",
        default=[],
        help="Explicit path to a WuberRec.lua SavedVariables file (can be repeated).",
    )
    parser.add_argument(
        "--include-sim",
        action="store_true",
        help="Include sim-*.lua (fake-game) fixtures as event evidence (NOT recommended).",
    )
    parser.add_argument(
        "--fail-on-all-unseen",
        action="store_true",
        help="Treat every unseen registered event as CRITICAL instead of only paired/refused events.",
    )
    parser.add_argument(
        "--no-strict",
        action="store_true",
        help="Always exit 0 even when critical violations are found.",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON report.")
    parser.add_argument("--gate", action="store_true", help="Gauntlet gate: every unseen contract not covered or known fails (exit 0/1/2).")
    parser.add_argument("--known", type=Path, default=DEFAULT_KNOWN, help="Known-accepted list (name<TAB>reason), used by --gate.")
    args = parser.parse_args(argv)

    def fail_run(msg: str) -> int:
        print(f"ERROR: {msg}", file=sys.stderr)
        if args.gate:
            print("GAUNTLET recordings result=error unseen=0 covered=0 known=0 events=0 values=0")
        return 2

    if not args.wuber.is_dir() or not any(args.wuber.rglob("*.lua")):
        return fail_run(f"Wuber source directory not found or has no .lua files: {args.wuber}")
    if args.fixtures is None:
        own = args.wuber.resolve().parent / "tests" / "fixtures" / "rec"
        args.fixtures = own if own.is_dir() else repo_root / "tests" / "fixtures" / "rec"

    wuber_scan = scan_wuber_source(args.wuber)
    recordings = collect_recordings(
        fixtures_dir=args.fixtures,
        wtf_dir=args.wtf,
        rec_files=args.rec,
        include_sim=args.include_sim,
    )
    result = evaluate_contracts(
        wuber_scan,
        recordings,
        fail_on_all_unseen=args.fail_on_all_unseen,
        wuber_dir=args.wuber,
    )

    if args.gate and not recordings["seen_real"]:
        return fail_run("no real event recordings found (WuberRec.lua under --wtf, --rec, or game-*.lua in --fixtures)")

    payload = {
        "wuber_files_scanned": wuber_scan["files_scanned"],
        "registered_events_count": len(wuber_scan["events"]),
        "recording_sources": recordings["sources"],
        "real_events_distinct": len(recordings["seen_real"]),
        "violations": result["violations"],
        "warnings": result["warnings"],
        "unseen_events": result["unseen_events"],
        "covered": result["covered"],
    }

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(
            f"contract-check: scanned {payload['wuber_files_scanned']} Lua files, "
            f"{payload['registered_events_count']} registered events, "
            f"{len(payload['recording_sources'])} recording source(s)."
        )
        for v in result["violations"]:
            print(f"[{v['severity']}] {v['kind']}: {v['message']}")
        for w in result["warnings"]:
            print(f"[{w['severity']}] {w['kind']}: {w['message']}")
        for c in result["covered"]:
            print(f"[{c['severity']}] {c['kind']}: {c['message']}")
        print(
            f"Summary: {len(result['violations'])} critical violation(s), "
            f"{len(result['warnings'])} warning(s), "
            f"{len(result['unseen_events'])} unseen registered event(s)."
        )

    if args.gate:
        g = gate_findings(wuber_scan, recordings, result, args.wuber, load_known(args.known))
        for line in g["fails"]:
            print(line)
        res = "fail" if g["fails"] else "pass"
        print(f"GAUNTLET recordings result={res} unseen={g['unseen']} covered={g['covered']} known={g['known']} "
              f"events={g['events']} values={g['values']}")
        return 1 if g["fails"] else 0
    if result["violations"] and not args.no_strict:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
