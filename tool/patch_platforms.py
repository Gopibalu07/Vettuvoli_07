#!/usr/bin/env python3
"""Patches the android/ and ios/ folders created by `flutter create` with what
VettuVoli needs: microphone permissions, minSdk 24, iOS 14, app name.

Safe to run more than once.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
problems = []


def log(msg):
    print(f"[patch] {msg}")


# ---- Android: minSdk 24 (required by ffmpeg_kit_flutter_new) ---------------
patched_gradle = False
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    f = ROOT / name
    if not f.exists():
        continue
    text = f.read_text()
    new = re.sub(
        r"(minSdk(?:Version)?)(\s*=\s*|\s+)flutter\.minSdkVersion",
        r"\g<1>\g<2>24",
        text,
    )
    if new != text:
        f.write_text(new)
        log(f"{name}: minSdk set to 24")
        patched_gradle = True
    elif re.search(r"minSdk(?:Version)?\s*=?\s*24\b", text):
        log(f"{name}: minSdk already 24")
        patched_gradle = True
if not patched_gradle:
    problems.append("Could not set minSdk 24 in android/app/build.gradle(.kts) - set it manually.")

# ---- Android: permissions + label -----------------------------------------
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    text = manifest.read_text()
    perms = (
        '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
        '    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>\n'
    )
    if "android.permission.RECORD_AUDIO" not in text:
        text = text.replace("<application", perms + "    <application", 1)
        log("AndroidManifest.xml: added audio permissions")
    text = re.sub(r'android:label="[^"]*"', 'android:label="VettuVoli"', text, count=1)
    manifest.write_text(text)
else:
    problems.append("AndroidManifest.xml not found - run `flutter create` first.")

# ---- iOS: microphone usage text -------------------------------------------
plist = ROOT / "ios/Runner/Info.plist"
if plist.exists():
    text = plist.read_text()
    if "NSMicrophoneUsageDescription" not in text:
        entry = (
            "\t<key>NSMicrophoneUsageDescription</key>\n"
            "\t<string>VettuVoli records audio so it can remove background noise from it.</string>\n"
        )
        idx = text.rfind("</dict>")
        text = text[:idx] + entry + text[idx:]
        plist.write_text(text)
        log("Info.plist: added NSMicrophoneUsageDescription")
    else:
        log("Info.plist: microphone text already present")
else:
    log("ios/Runner/Info.plist not found (Android-only project?) - skipping iOS")

# ---- iOS: deployment target 14 --------------------------------------------
podfile = ROOT / "ios/Podfile"
if podfile.exists():
    text = podfile.read_text()
    new = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '14.0'", text, count=1)
    if new != text:
        podfile.write_text(new)
        log("Podfile: iOS 14.0")

if problems:
    for p in problems:
        print(f"[patch] WARNING: {p}", file=sys.stderr)
    sys.exit(1)
log("done")
