#!/usr/bin/env python3
"""Tiny uiautomator helper for the emulator smoke test (no dependencies)."""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


def adb(*args, check=True):
    return subprocess.run(["adb", *args], capture_output=True, text=True, check=check).stdout


def dump():
    for _ in range(5):
        out = adb("shell", "uiautomator", "dump", "/sdcard/ui.xml", check=False)
        if "dumped" in out:
            break
        time.sleep(1)
    adb("pull", "/sdcard/ui.xml", "/tmp/ui.xml", check=False)
    try:
        return ET.parse("/tmp/ui.xml").getroot()
    except Exception as error:  # noqa: BLE001
        print("dump failed:", error)
        return None


def nodes(root):
    result = []
    if root is None:
        return result
    for node in root.iter("node"):
        label = (node.get("text") or "").strip() or (node.get("content-desc") or "").strip()
        match = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds") or "")
        if not match:
            continue
        x1, y1, x2, y2 = map(int, match.groups())
        result.append(
            {
                "label": label,
                "center": ((x1 + x2) // 2, (y1 + y2) // 2),
                "class": node.get("class"),
                "clickable": node.get("clickable") == "true",
            }
        )
    return result


def show(title):
    items = [n for n in nodes(dump()) if n["label"]]
    print(f"--- UI: {title} ({len(items)} labelled nodes)")
    for n in items[:60]:
        print("   ", repr(n["label"][:70]), n["center"])
    return items


def tap(*needles, required=True):
    for n in nodes(dump()):
        if any(needle in n["label"] for needle in needles) and n["label"]:
            x, y = n["center"]
            print(f"tap {n['label'][:50]!r} at {x},{y}")
            adb("shell", "input", "tap", str(x), str(y))
            return True
    if required:
        print("NOT FOUND:", needles)
    return False


if __name__ == "__main__":
    show(sys.argv[1] if len(sys.argv) > 1 else "screen")
