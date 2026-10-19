"""Create an explicitly named, private local fixture. Never modifies the source campaign.

Run only with the real campaign closed. Character content stays in .private or in
the local sandbox and must never be included in a public source distribution.
"""
from pathlib import Path
import copy
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def field(parent, name, value, kind="number"):
    ET.SubElement(parent, name, type=kind).text = str(value)

def create(data, source):
    DATA = Path(data).resolve()
    SOURCE = Path(source).resolve()
    TARGET = DATA / "campaigns" / "Damage_Workbench_Sandbox"
    if SOURCE == TARGET or not (SOURCE / "db.xml").is_file():
        raise SystemExit("Choose an existing source campaign, distinct from the sandbox")
    private = ROOT / ".private"
    private.mkdir(exist_ok=True)
    if TARGET.exists():
        raise SystemExit("Sandbox already exists; refusing to overwrite it")
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.iterdir() if p.is_file()}
    (private / "source-hashes.json").write_text(json.dumps(hashes, indent=2))
    source = ET.parse(SOURCE / "db.xml").getroot()
    root = ET.Element("root", version="5.1", dataversion="20260124", release="11|CoreRPG:8")
    chars = copy.deepcopy(source.find("charsheet"))
    # Nobody owns these test copies, so a local host can exercise owner routing.
    for parent in chars.iter():
        for child in list(parent):
            if child.tag == "holder":
                parent.remove(child)
    root.append(chars)
    ct = ET.SubElement(root, "combattracker")
    field(ct, "round", 1)
    entries = ET.SubElement(ct, "list")
    n = 1
    for char in list(chars):
        if not char.tag.startswith("id-") or not char.findtext("name"):
            continue
        entry = ET.SubElement(entries, f"id-{n:05d}")
        field(entry, "name", char.findtext("name"), "string")
        field(entry, "friendfoe", "friend", "string")
        link = ET.SubElement(entry, "link", type="windowreference")
        ET.SubElement(link, "class").text = "charsheet"
        ET.SubElement(link, "recordname").text = "charsheet." + char.tag
        field(entry, "initresult", 30 - n)
        field(entry, "active", 1 if n == 1 else 0)
        field(entry, "hp", 100)
        field(entry, "hptotal", 100)
        field(entry, "wounds", 0)
        field(entry, "ac", 10)
        n += 1
    entry = ET.SubElement(entries, "id-00999")
    link = ET.SubElement(entry, "link", type="windowreference")
    ET.SubElement(link, "class").text = "npc"
    ET.SubElement(link, "recordname").text = "combattracker.list.id-00999"
    field(entry, "name", "DWB Training Target", "string")
    field(entry, "friendfoe", "foe", "string")
    field(entry, "type", "construct", "string")
    field(entry, "initresult", 1)
    field(entry, "hp", 500)
    field(entry, "hptotal", 500)
    field(entry, "wounds", 0)
    field(entry, "ac", 1)
    field(entry, "tokenvis", 1)
    options = ET.SubElement(root, "options")
    field(options, "DWB_CONFIRM", "ask", "string")
    field(options, "SHRR", "off", "string")
    TARGET.mkdir()
    ET.ElementTree(root).write(TARGET / "db.xml", encoding="utf-8", xml_declaration=True)
    config = ET.Element("root", version="5.1", dataversion="20260124")
    ET.SubElement(config, "ruleset").text = "5E"
    ET.SubElement(config, "server").text = "lan"
    ET.SubElement(config, "port").text = "1803"
    ET.SubElement(config, "private").text = "true"
    ET.ElementTree(config).write(TARGET / "campaign.xml", encoding="utf-8", xml_declaration=True)
    extensions = ET.Element("extensionstate", version="5.1", dataversion="20260124")
    ET.SubElement(extensions, "extension", name="DamageWorkbench")
    ET.ElementTree(extensions).write(TARGET / "extensionstate.xml", encoding="utf-8", xml_declaration=True)
    shutil.copy2(ROOT / "dist" / "DamageWorkbench.ext", DATA / "extensions" / "DamageWorkbench.ext")
    print(f"Created local sandbox {TARGET}; {n-1} private character fixtures; original campaign untouched")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, help="Fantasy Grounds data directory")
    parser.add_argument("--source", required=True, help="Source campaign directory, read only")
    args = parser.parse_args()
    create(args.data, args.source)
