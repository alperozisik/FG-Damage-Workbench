"""Build an extension containing original runtime files only."""
from pathlib import Path
import hashlib
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def build(test_harness=False):
    files = [ROOT / "extension.xml", ROOT / "strings.xml", ROOT / "LICENSE"]
    files += sorted((ROOT / "scripts").glob("*.lua"))
    files += sorted((ROOT / "ui").glob("*"))
    for path in files:
        if path.suffix == ".xml":
            ET.parse(path)
    target = ROOT / "dist" / ("DamageWorkbench-Test.ext" if test_harness else "DamageWorkbench.ext")
    target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            info = zipfile.ZipInfo(path.relative_to(ROOT).as_posix(), (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            contents = path.read_bytes()
            if test_harness and path.name == "extension.xml":
                doc = ET.fromstring(contents)
                ET.SubElement(doc.find("base"), "script", name="DWBHarness", file="tests/fg_harness.lua")
                contents = ET.tostring(doc, encoding="utf-8", xml_declaration=True)
            archive.writestr(info, contents)
        if test_harness:
            info = zipfile.ZipInfo("tests/fg_harness.lua", (2026,1,1,0,0,0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, (ROOT / "tests" / "fg_harness.lua").read_bytes())
    print(f"Built {target} ({target.stat().st_size} bytes)")
    print("SHA256 " + hashlib.sha256(target.read_bytes()).hexdigest())
    return target

def source_archive():
    """Explicit allow-list: never archive campaign data or extracted references."""
    files = [ROOT / name for name in ("extension.xml", "strings.xml", "README.md",
             "README.tr.md", "TESTING.md", "requirements-dev.txt", ".gitignore", "LICENSE")]
    for folder, pattern in (("scripts", "*.lua"), ("ui", "*"), ("tools", "*.py"),
                            ("tests", "*.py"), ("tests", "*.lua")):
        files += sorted((ROOT / folder).glob(pattern))
    target = ROOT / "dist" / "DamageWorkbench-Source.zip"
    target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            info = zipfile.ZipInfo("FG-Damage-Workbench/" + path.relative_to(ROOT).as_posix(), (2026,1,1,0,0,0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    print(f"Built {target} ({target.stat().st_size} bytes)")
    return target

if __name__ == "__main__":
    import sys
    build("--test-harness" in sys.argv)
    if "--source" in sys.argv:
        source_archive()
