"""Build an installable Factorio mod ZIP with only runtime and documentation files."""
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]


def build():
    info = json.loads((ROOT / "info.json").read_text())
    name = f"{info['name']}_{info['version']}"
    destination = ROOT / "dist" / f"{name}.zip"
    destination.parent.mkdir(exist_ok=True)
    files = [ROOT / path for path in (
        "info.json", "control.lua", "settings.lua", "README.md", "LICENSE", "changelog.txt"
    )]
    files += sorted((ROOT / "scripts").rglob("*.lua"))
    files += sorted((ROOT / "locale").rglob("*.cfg"))
    with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, f"{name}/{path.relative_to(ROOT).as_posix()}")
    print(destination)
    return destination


if __name__ == "__main__":
    build()
