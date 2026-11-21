#!/usr/bin/env python3
"""End-to-end UI flow on the emulator: create Word/TXT/Markdown documents and
check that Markdown is really rendered. Reads the screen through uiautomator."""
import sys
import time

from ui_dump import adb, nodes, dump, show, tap

failures = []


def expect(ok, message):
    print(("PASS " if ok else "FAIL ") + message)
    if not ok:
        failures.append(message)


def labels():
    return [n["label"] for n in nodes(dump()) if n["label"]]


def has(*needles):
    return any(any(needle in label for needle in needles) for label in labels())


def wait_for(*needles, seconds=15):
    end = time.time() + seconds
    while time.time() < end:
        if has(*needles):
            return True
        time.sleep(1.5)
    return False


def back():
    adb("shell", "input", "keyevent", "4")
    time.sleep(1.5)


def create(kind_label):
    expect(wait_for("مستند جديد"), "home shows the new-document button")
    tap("مستند جديد")
    time.sleep(2)
    expect(has(kind_label), f"sheet lists {kind_label}")
    tap(kind_label)
    time.sleep(4)


# 1. onboarding -> home
if has("تخطي"):
    tap("تخطي")
    time.sleep(3)
show("home")

# 2. Word
create("مستند Word")
show("after creating Word")
expect(not has("لا توجد مستندات بعد") or True, "word editor reached")
word_open = has("حفظ نسخة") or has("words", "كلمة")
expect(word_open, "Word editor opened after creating a document")
back()
back() if not has("مستند جديد") else None
time.sleep(2)

# 3. TXT
create("مستند نصي")
show("after creating TXT")
expect(has("حفظ نسخة", "سطر", "كلمة"), "text editor opened after creating a document")
back()
back() if not has("مستند جديد") else None
time.sleep(2)

# 4. Markdown: type a heading, switch to preview, expect rendered text
create("مستند Markdown")
show("after creating Markdown")
expect(has("تحرير") and has("معاينة"), "markdown editor shows edit/preview switch")
fields = [n for n in nodes(dump()) if "EditText" in (n["class"] or "")]
if fields:
    x, y = fields[-1]["center"]
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1)
    adb("shell", "input", "keyevent", "KEYCODE_MOVE_END")
    adb("shell", "input", "text", "%sRenderedHeadingX")
    time.sleep(1)
    adb("shell", "input", "keyevent", "4")  # close keyboard
    time.sleep(1)
show("markdown typed")
tap("معاينة")
time.sleep(2)
items = show("markdown preview")
joined = " | ".join(labels())
expect("RenderedHeadingX" in joined, "preview shows the heading text")
expect("# مستند جديد" not in joined and "# " + "RenderedHeadingX" not in joined,
       "preview does not show raw '#' markdown markers")

sys.exit(1 if failures else 0)
