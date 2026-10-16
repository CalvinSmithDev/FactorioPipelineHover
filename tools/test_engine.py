"""Run integration checks with a local Factorio 2.1.22+ executable.

Usage: python3 tools/test_engine.py /path/to/factorio[.exe]
Uses an isolated write-data and mod directory; never touches user saves/mods.
Supports a Windows executable launched from WSL.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

from build import ROOT, build


def main():
    executable = Path(sys.argv[1]).resolve()
    output = ROOT / ".test-output"
    mods = output / "mods"
    write_data = output / "data"
    mods.mkdir(parents=True, exist_ok=True)
    write_data.mkdir(exist_ok=True)
    package = build()
    shutil.copy2(package, mods / package.name)
    test_mod = mods / "pipeline-hover-tests_1.0.0"
    test_mod.mkdir(exist_ok=True)
    (test_mod / "info.json").write_text(json.dumps({
        "name": "pipeline-hover-tests", "version": "1.0.0", "title": "Pipeline Hover tests",
        "author": "Pipeline Hover contributors", "factorio_version": "2.1",
        "dependencies": ["pipeline-hover"],
    }))
    shutil.copy2(ROOT / "tests" / "engine.lua", test_mod / "control.lua")
    (mods / "mod-list.json").write_text(json.dumps({"mods": [
        {"name": name, "enabled": True} for name in
        ("base", "quality", "elevated-rails", "space-age", "pipeline-hover", "pipeline-hover-tests")
    ]}))

    def native(path):
        if executable.suffix == ".exe" and sys.platform != "win32":
            return subprocess.check_output(["wslpath", "-w", str(path)], text=True).strip()
        return str(path)

    config = output / "config.ini"
    config.write_text("[path]\nread-data=" + native(executable.parents[2] / "data")
                      + "\nwrite-data=" + native(write_data) + "\n")
    command = [str(executable), "--config", native(config), "--mod-directory", native(mods),
               "--create", native(output / "test-save.zip"), "--map-gen-seed", "1"]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    (output / "test.log").write_text(result.stdout)
    if result.returncode or "PIPELINE_HOVER_ENGINE_TESTS_PASSED" not in result.stdout:
        print(result.stdout)
        raise SystemExit("Factorio integration checks failed; see .test-output/test.log")
    command = [str(executable), "--config", native(config), "--mod-directory", native(mods),
               "--benchmark", native(output / "test-save.zip"), "--benchmark-ticks", "45"]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    (output / "reload.log").write_text(result.stdout)
    if result.returncode or "PIPELINE_HOVER_RELOAD_TESTS_PASSED" not in result.stdout:
        print(result.stdout)
        raise SystemExit("Factorio reload checks failed; see .test-output/reload.log")
    print("Factorio integration, save/reload, and rendering expiry checks passed.")


if __name__ == "__main__":
    main()
