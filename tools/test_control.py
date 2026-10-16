"""Run Lua event/lifecycle tests via lupa (python3 -m pip install lupa)."""
import os
from pathlib import Path

from lupa.lua52 import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
runtime = LuaRuntime()
runtime.execute((root / "tests" / "control.lua").read_text())
