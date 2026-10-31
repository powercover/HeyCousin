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
- `addon_smoke.lua` on `mock_wow.lua` (a small game in plain Lua, where only real methods exist): the
  whole addon loaded as the TOC lists it, on Retail (test mode) and Forever, in both themes: the
  setup, the window, the pop-up and its combat rule, the radar, chat, tooltips, layers, secret
  names, broken saved data. An error the addon catches fails it too (`run51.py` runs it on 5.1,
  `run55.py` on 5.5).
- `make_media.py`: draws every theme's art and makes the sounds (`--preview DIR` for a look).
- `make_font.py`: builds the addon's own pixel font from the letters drawn in it, as a TrueType
  file (`--preview OUT`); `ttf_cmap.py` lists the characters a font has.

Tools:

- `link.py`: links WoW Forever's AddOns folder to this project with a junction, so the game reads
  the project folder itself. `--retail` links Retail's too, for the test mode, and writes the
  `HeyCousin_Standard.toc` Retail reads there (never committed: the release stays Forever only).
- `bump_version.py OLD NEW`: the version in the TOC and `Core.lua`.
- `screens.py [OUT] [--lang CODE]`: pictures of every screen in both themes (the family, a
  cousin's page, the tree, stats, pop-ups, the setup's steps, minimap, tooltip, chat, crests, the
  name test, the family map), drawn from the addon's own frames on the mock game (`screens.lua`
  opens them) into `screens/` (not committed); `--lang` draws them in a translation, into
  `screens/CODE/`. It prints texts that don't fit, run into each other or spill out of their
  buttons. The game packs its fonts, so Georgia stands in for Friz Quadrata and Morpheus, and
  Windows' Malgun Gothic, YaHei and JhengHei for the game's Korean and Chinese; the minimap, the
  world map, chat, tooltip, class icons and 3D models are stand-ins.
- `locale_texts.py [--missing CODE]`: every text the addon shows, for translators, with the line of
  code that shows it, grouped by file; `--missing` lists only the ones a translation lacks.
- `edits.py`: exact-match edits that keep a file's line endings.
