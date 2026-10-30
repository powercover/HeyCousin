"""Bumps the addon's version in its two places: python bump_version.py <old> <new>

Retail's test-mode TOC follows, if there is one here (link.py --retail).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from edits import edit  # noqa: E402
import link  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
old, new = sys.argv[1], sys.argv[2]
edit(ROOT, "HeyCousin.toc", [("## Version: " + old + "\n", "## Version: " + new + "\n")])
edit(ROOT, "Core.lua", [('HC.VERSION = "' + old + '"', 'HC.VERSION = "' + new + '"')])
if os.path.exists(link.STANDARD_TOC):
    link.write_standard_toc()
