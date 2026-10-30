"""Every check of the addon in one run, in parallel, on Lua 5.1 (WoW's Lua); `--both` adds Lua 5.5.

python suite.py [--root DIR] [--both] [--release] [--only NAME,...]

Prints one line per check (PASS/FAIL and its key output) and saves the full output under
suite_logs/. Exit code 1 if anything failed. `--release`, before a release: a text not translated
yet fails too.
"""
import concurrent.futures
import datetime
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[1:]
ROOT = os.environ.get("HC_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
if "--root" in args:
    ROOT = os.path.abspath(args[args.index("--root") + 1])
BOTH = "--both" in args
RELEASE = "--release" in args
ONLY = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None

PY = sys.executable
# name: (command, the line that says it passed, lines worth showing in the summary)
CHECKS = {
    "lua51_lint": ([PY, "lua51_lint.py"], "0 errors, 0 global writes, 0 new global reads", ["close to a limit"]),
    "forward_lint": ([PY, "forward_lint.py"], "forward lint: clean", []),
    "locale_keys": ([PY, "locale_keys.py", "--check"] + (["--release"] if RELEASE else []), "locale problems: 0",
                    ["not translated yet"]),
    "locale_glyphs": ([PY, "locale_glyphs.py"], None, []),
    "standard_toc": ([PY, "link.py", "--check"], "standard toc: ok", []),
    "core": ([PY, "run51.py", "core_smoke.lua"], "core checks passed", []),
}
if BOTH:
    CHECKS.update({
        "syntax55": ([PY, "syntax_check.py"], ", 0 errors", []),
        "core55": ([PY, "run55.py", "core_smoke.lua"], "core checks passed", []),
    })
if ONLY:
    CHECKS = {k: v for k, v in CHECKS.items() if k in ONLY}


def run(name, command, passed, keep):
    env = dict(os.environ, HC_ROOT=ROOT, PYTHONIOENCODING="utf-8")
    started = time.time()
    try:
        out = subprocess.run(command, cwd=HERE, env=env, capture_output=True, text=True, encoding="utf-8",
                             errors="replace", timeout=1500)
        text, code = out.stdout + out.stderr, out.returncode
    except subprocess.TimeoutExpired:
        text, code = "TIMEOUT", -1
    lines = text.splitlines()
    bad = [l for l in lines if "FAIL" in l and "PASS" not in l or "Traceback" in l or "LuaError" in l
           or l.startswith(("LUA 5.1 ERROR", "GLOBAL WRITE", "NEW GLOBAL READ", "SYNTAX ERROR"))]
    if name == "forward_lint":
        bad += [l for l in lines if "used before its definition" in l]
    if name == "locale_glyphs":
        bad += [l for l in lines if " U+" in l]
    ok = code == 0 and not bad and (passed is None or any(passed in l for l in lines))
    shown = [l for l in lines if any(k in l for k in keep)]
    return name, ok, time.time() - started, text, bad, shown


def main():
    stamp = datetime.datetime.now().strftime("%m%d_%H%M%S")
    os.makedirs(os.path.join(HERE, "suite_logs"), exist_ok=True)
    log_path = os.path.join(HERE, "suite_logs", "suite_%s.txt" % stamp)
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        futures = [pool.submit(run, name, *spec) for name, spec in CHECKS.items()]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    order = list(CHECKS)
    results.sort(key=lambda r: order.index(r[0]))
    failed = 0
    with open(log_path, "w", encoding="utf-8") as log:
        log.write("root: %s\n" % ROOT)
        for name, ok, took, text, bad, shown in results:
            log.write("=== %s (%s, %.0fs)\n%s\n" % (name, "PASS" if ok else "FAIL", took, text))
    print("root:", ROOT)
    for name, ok, took, text, bad, shown in results:
        failed += 0 if ok else 1
        print("%-13s %s  %4.0fs" % (name, "PASS" if ok else "FAIL", took))
        for line in bad[:8]:
            print("      ! " + line[:220])
        if not ok and not bad:
            for line in text.splitlines()[-6:]:
                print("      | " + line[:220])
        for line in shown:
            print("        " + line[:400])
    print("%d/%d checks passed  (log: %s)" % (len(results) - failed, len(results), log_path))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
