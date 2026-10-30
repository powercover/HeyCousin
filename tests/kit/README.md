# Test kit

Offline checks for the addon, on WoW's own Lua (5.1, through lupa). Nothing here ships: `.pkgmeta`
leaves `tests/` out of the release zip.

```
pip install lupa
python suite.py            # every check, in parallel; logs in suite_logs/
python suite.py --both     # also on Lua 5.5
python suite.py --release  # before a release: every text translated too
python suite.py --only core,lua51_lint
```

What runs:

- `lua51_lint.py`: compiles every file on Lua 5.1, fails on WoW's limits (200 locals, 60 upvalues
  per function) and on global writes; new global reads are compared with `lua51_globals.txt`
  (`--update` rewrites it, from a clean checkout).
- `forward_lint.py`, `locale_keys.py`, `locale_glyphs.py`: calls before definitions, translation keys
  and placeholders (a missing translation fails only with `--release`), characters the game's fonts
  can't draw (reads the game's font cache).
- `link.py --check`: Retail's test-mode TOC, if there is one, still matches `HeyCousin.toc`.
- `core_smoke.lua`: the addon loaded as the TOC lists it, on mocked game functions: saved settings,
  chat commands, Forever or Retail, secret names, caught errors (`run51.py` runs it on 5.1,
  `run55.py` on 5.5).

Tools:

- `link.py`: links WoW Forever's AddOns folder to this project with a junction, so the game reads
  the project folder itself. `--retail` links Retail's too, for the test mode, and writes the
  `HeyCousin_Standard.toc` Retail reads there (never committed: the release stays Forever only).
- `bump_version.py OLD NEW`: the version in the TOC and `Core.lua`.
- `edits.py`: exact-match edits that keep a file's line endings.
