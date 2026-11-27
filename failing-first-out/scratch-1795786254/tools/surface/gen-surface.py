#!/usr/bin/env python3
"""gen-surface.py: build tests/surface/apisurface.lua, the API surface the offline fake game's surface guard judges addon code by.

The input is the interface source of the WoW Forever client, the Gethe/wow-ui-source repository, branch "forever" (public, read-only):
the generated API documentation (Blizzard_APIDocumentationGenerated) says which functions exist and which are protected, secure-only
or secret-restricted; the other Blizzard Lua says which names the client's own UI defines and calls (so an undocumented classic C
function Blizzard itself uses is not a false alarm).

Regenerate on EVERY client patch (the build number is in the header of the output, so a patch shows up as a diff):
  python tools/surface/gen-surface.py --fetch <empty folder outside the repo>      clone / update the source in a container, then generate
  python tools/surface/gen-surface.py --ui <folder holding Interface/ and version.txt>   generate from a checkout you already have
Then run the suite once with WUBER_SURFACE=1 (tests/surface/README.md) and commit the new tests/surface/apisurface.lua.

--fetch runs git in the alpine/git container (docker): the container only reads the public repository and writes the clone into the
folder you name; nothing from the clone is executed, only read as text. Without docker it falls back to the local git.

Output (a Lua table, sorted, so a diff shows only real changes):
  globals[Name]   = flags   every documented global function
  ns[C_X][Name]   = flags   every documented namespace function
  methods[Name]   = flags   every documented widget method (merged over all objects)
  curated[Name]   = {mode}  a hand list that is NOT from the docs: never (secure code only), hw (needs a hardware click),
                            combat (blocked in combat). The hw modes are unmeasured: the guard keeps them off until a probe measures them.
  blizz[Name]     = true    global functions the interface Lua defines (allowed although undocumented)
  called.g/n/m              names the interface Lua calls: globals, C_X.Name, :Methods (so they exist in the client)
flags (only the true ones are written): p protected, so secure-only, sa SecretArguments=NotAllowed, sr secret returns (any kind, kept for the
  runtime guard), csa ConstSecretAccessor, hr HasRestrictions, combat (SecretWhenInCombat / combat-restricted).
  Secret kinds, told apart for tools/surface/static-surface.lua (always secret versus secret only when something holds):
    sra   SecretReturns=true: the result is ALWAYS a secret value
    sw    SecretWhen<X>Restricted ...: conditional, a string of the conditions joined with "|" (UnitName: "UnitIdentityRestricted")
    scl   SecretInChatMessagingLockdown: a chat function that answers secrets while chat is locked down
    sas   SecretReturnsForAspect={...}: secret only on an object that has that aspect, a string "Text|Alpha" (GetText, IsShown, GetAlpha ...)
    aut   SecretArguments=AllowedWhenUntainted (a secret argument is fine from Blizzard code, not from addon code)
"""
import argparse, glob, json, os, re, subprocess, sys

REPO = "https://github.com/Gethe/wow-ui-source"
BRANCH = "forever"

CURATED = {  # name -> (mode, note). A hand list, not from the docs. Namespaced names: "C_X.Name"
    "ReloadUI": ("never", "ReloadUI from addon code is blocked in WoW Forever"),
    "C_UI.Reload": ("never", "same as ReloadUI"),
    "Logout": ("hw", "hardware event needed"), "Quit": ("hw", "hardware event needed"),
    "ForceQuit": ("hw", "hardware event needed"), "CancelLogout": ("hw", "hardware event"),
    "InviteUnit": ("hw", "hardware event needed"), "C_PartyInfo.InviteUnit": ("hw", "hardware event needed"),
    "JoinChannelByName": ("hw", "hardware event needed"),
    "SetCVar": ("combat", "protected CVars in combat"), "C_CVar.SetCVar": ("combat", "protected CVars in combat"),
    "RunMacroText": ("never", "secure only"), "C_Macro.RunMacroText": ("never", "secure only"),
    "RunMacro": ("never", "secure only"), "CastSpellByName": ("never", "protected"), "CastSpellByID": ("never", "protected"),
    "CastSpell": ("never", "protected"), "TargetUnit": ("combat", "protected in combat"),
    "AssistUnit": ("combat", "protected"), "FocusUnit": ("combat", "protected"), "UseAction": ("never", "protected"),
    "UseContainerItem": ("never", "protected"), "UseItemByName": ("never", "protected"), "SpellStopCasting": ("never", "protected"),
    "TargetNearestEnemy": ("never", "protected"), "StartAttack": ("never", "protected"),
    "SendChatMessage": ("hw", "hardware event (CODE-RULES: no SendChatMessage from addon code)"),
    "C_ChatInfo.SendChatMessage": ("hw", "hardware event"), "AcceptTrade": ("hw", "hardware event"),
    "FollowUnit": ("never", "protected"),
    # AcceptGroup / ConfirmSummon / LeaveParty are left out on purpose: the harness notes say they were measured NOT to need a click
}


def fetch(dest):
    """clone (or update) the interface source into dest, inside a container when docker is there"""
    dest = os.path.abspath(dest)
    os.makedirs(dest, exist_ok=True)
    have = os.path.isdir(os.path.join(dest, ".git"))
    try:
        subprocess.run(["docker", "version"], check=True, capture_output=True)
        img = ["docker", "run", "--rm", "-v", dest + ":/ui", "alpine/git"]
        args = ["-C", "/ui", "pull", "--ff-only"] if have else ["clone", "--depth", "1", "--branch", BRANCH, REPO, "/ui"]
        subprocess.run(img + args, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print("docker route failed (%s): trying the local git" % e.__class__.__name__, file=sys.stderr)
        if have: subprocess.run(["git", "-C", dest, "pull", "--ff-only"], check=True)
        else: subprocess.run(["git", "clone", "--depth", "1", "--branch", BRANCH, REPO, dest], check=True)
    return dest


def read_docs(ui):
    """the generated API documentation Lua files -> list of entries (a line reader, nothing is run)"""
    out = []
    for f in sorted(glob.glob(os.path.join(ui, "Interface", "AddOns", "Blizzard_APIDocumentationGenerated", "*.lua"))):
        oname = otype = sec = ns = env = ent = None
        def flush():
            nonlocal ent
            if ent: out.append(ent)
            ent = None
        for ln in open(f, encoding="utf8", errors="replace").read().split("\n"):
            m = re.match(r'^\tType = "(\w+)"', ln)
            if m: otype = m.group(1)
            m = re.match(r'^\tName = "(\w+)"', ln)
            if m: oname = m.group(1)
            m = re.match(r'^\tNamespace = "(.*)"', ln)
            if m: ns = m.group(1)
            m = re.match(r'^\tEnvironment = "(\w+)"', ln)
            if m: env = m.group(1)
            m = re.match(r'^\t(Functions|Events|Tables) =$', ln)
            if m: flush(); sec = m.group(1); continue
            if re.match(r'^\t\t\{$', ln): flush(); ent = {"ns": ns, "sec": sec, "flags": [], "env": env, "obj": oname, "otype": otype}; continue
            if re.match(r'^\t\t\},?$', ln): flush(); continue
            if ent is None: continue
            m = re.match(r'^\t\t\t(\w+) = (true|"[^"]*"|\{[^}]*\}),?$', ln)
            if m:
                k, v = m.groups()
                if k == "Name" and "name" not in ent: ent["name"] = v.strip('"')
                elif k == "Environment": ent["env"] = v.strip('"')
                elif k not in ("Name", "Type", "Documentation"): ent["flags"].append(k if v == "true" else k + "=" + v.strip('"'))
        flush()
    return out


def read_lua(ui):
    """names the interface Lua defines (blizz) and calls (G globals, N C_X.Name, M :Methods), read as text from every non-generated .lua"""
    blizz, called = set(), {"G": set(), "N": set(), "M": set()}
    skip = os.sep + "Blizzard_APIDocumentationGenerated" + os.sep
    comment = re.compile(r"--.*$")
    defs = [re.compile(r"^function\s+([A-Za-z_]\w*)\s*\("), re.compile(r"^([A-Za-z_]\w*)\s*=\s*function\b")]
    callg = re.compile(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(")
    calln = re.compile(r"\b(C_\w+\.\w+)\s*\(")
    callm = re.compile(r":([A-Za-z_]\w*)\s*\(")
    for root, _, files in os.walk(os.path.join(ui, "Interface")):
        if skip in root + os.sep: continue
        for fn in files:
            if not fn.endswith(".lua"): continue
            for ln in open(os.path.join(root, fn), encoding="utf8", errors="replace"):
                for d in defs:
                    m = d.match(ln)
                    if m: blizz.add(m.group(1))
                ln = comment.sub("", ln)
                called["G"].update(callg.findall(ln)); called["N"].update(calln.findall(ln)); called["M"].update(callm.findall(ln))
    return sorted(blizz), {k: sorted(v) for k, v in called.items()}


def lf(f): return "{" + ",".join(('%s="%s"' % (k, f[k])) if isinstance(f[k], str) else "%s=true" % k for k in sorted(f)) + "}"


def merge(into, f):
    """a widget method of the same name on several objects: flags are or-ed, string flags (sw, sas) are unioned"""
    for k, v in f.items():
        if isinstance(v, str) and isinstance(into.get(k), str): into[k] = "|".join(sorted(set(into[k].split("|")) | set(v.split("|"))))
        else: into[k] = v


def build(ui, out):
    ver = open(os.path.join(ui, "version.txt")).read().strip() if os.path.exists(os.path.join(ui, "version.txt")) else "unknown"
    api = read_docs(ui)
    glob_, ns, meth = {}, {}, {}
    for e in api:
        if e.get("sec") != "Functions" or not e.get("name"): continue
        fl = e["flags"]; n = e["name"]; f = {}
        if "IsProtectedFunction" in fl: f["p"] = True
        if e.get("env") == "SecureOnly": f["so"] = True
        if any(x.startswith("SecretArguments=NotAllowed") for x in fl): f["sa"] = True
        if any(x.startswith(("SecretReturns", "SecretWhen", "SecretIn")) for x in fl): f["sr"] = True
        if "SecretReturns" in fl: f["sra"] = True
        sw = [x[len("SecretWhen"):] for x in fl if x.startswith("SecretWhen")]
        if sw: f["sw"] = "|".join(sw)
        if "SecretInChatMessagingLockdown" in fl: f["scl"] = True
        asp = [a for x in fl if x.startswith("SecretReturnsForAspect=") for a in re.findall(r"SecretAspect\.(\w+)", x)]
        if asp: f["sas"] = "|".join(asp)
        if "SecretArguments=AllowedWhenUntainted" in fl: f["aut"] = True
        if "ConstSecretAccessor" in fl: f["csa"] = True
        if "HasRestrictions" in fl: f["hr"] = True
        if any("Combat" in x for x in fl): f["combat"] = True
        if e.get("otype") == "ScriptObject": merge(meth.setdefault(n, {}), f)
        elif e.get("ns"): ns.setdefault(e["ns"], {})[n] = f
        else: glob_.setdefault(n, {}).update(f)
    if not glob_ or not ns or not meth:
        sys.exit("gen-surface: no API documentation found under %s/Interface/AddOns/Blizzard_APIDocumentationGenerated" % ui)
    blizz, called = read_lua(ui)
    o = ["-- apisurface.lua: GENERATED by tools/surface/gen-surface.py from the WoW Forever interface source. Do not edit.",
         "-- client build: %s (Gethe/wow-ui-source, branch %s). Regenerate on every client patch (tools/surface/README.md)." % (ver, BRANCH),
         "local S = { meta = { build = %s, globals = %d, ns = %d, nsfuncs = %d, methods = %d, blizz = %d } }" % (
             json.dumps(ver), len(glob_), len(ns), sum(len(v) for v in ns.values()), len(meth), len(blizz))]
    o.append("S.globals = {")
    for n in sorted(glob_): o.append(' ["%s"]=%s,' % (n, lf(glob_[n])))
    o.append("}\nS.ns = {")
    for k in sorted(ns): o.append(' ["%s"]={' % k + ",".join('["%s"]=%s' % (n, lf(ns[k][n])) for n in sorted(ns[k])) + "},")
    o.append("}\nS.methods = {")
    for n in sorted(meth): o.append(' ["%s"]=%s,' % (n, lf(meth[n])))
    o.append("}\nS.curated = {")
    def evidence(n):  # "docs" when the API docs flag the function protected / secure-only; else "brief" (the guard's "measured:<build>" comes from tests/fixtures/probe/measured-blocked.lua)
        d = ns.get(n.split(".")[0], {}).get(n.split(".", 1)[1]) if n.startswith("C_") else glob_.get(n)
        return "docs" if d and (d.get("so") or d.get("p")) else "brief"
    for n in sorted(CURATED): o.append(' ["%s"]={mode="%s",curated=true,ev="%s",note=%s},' % (n, CURATED[n][0], evidence(n), json.dumps(CURATED[n][1])))
    o.append("}\nS.blizz = {\n " + ",".join('["%s"]=true' % b for b in blizz))
    o.append("}\nS.called = {")
    for k in "GNM": o.append(" %s={%s}," % (k.lower(), ",".join('["%s"]=true' % x for x in called[k])))
    o.append("}\nreturn S")
    with open(out, "w", encoding="utf-8", newline="\n") as fh: fh.write("\n".join(o) + "\n")
    print("wrote %s: build %s, %d globals, %d namespaces (%d funcs), %d methods, %d curated, %d blizz-defined, called %d/%d/%d" % (
        out, ver, len(glob_), len(ns), sum(len(v) for v in ns.values()), len(meth), len(CURATED), len(blizz),
        len(called["G"]), len(called["N"]), len(called["M"])))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ui", help="folder holding Interface/ and version.txt (a Gethe/wow-ui-source checkout)")
    ap.add_argument("--fetch", metavar="DIR", help="clone or update the source into DIR (container), then use it as --ui")
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--out", default=os.path.join(here, "..", "..", "tests", "surface", "apisurface.lua"))
    a = ap.parse_args()
    ui = fetch(a.fetch) if a.fetch else a.ui
    if not ui: ap.error("give --ui <folder> or --fetch <folder>")
    build(ui, os.path.normpath(a.out))


main()
