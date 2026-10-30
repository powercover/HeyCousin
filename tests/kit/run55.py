"""Runs a smoke test (or several, as one chunk) on lupa's default Lua (5.5), from the addon folder.

python run55.py core_smoke.lua
"""
import os
import sys

from lupa import LuaRuntime

here = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.environ.get("HC_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))))
lua = LuaRuntime(unpack_returned_tuples=True)
source = "\n".join(open(os.path.join(here, name), encoding="utf-8").read() for name in sys.argv[1:])
lua.execute(source)
