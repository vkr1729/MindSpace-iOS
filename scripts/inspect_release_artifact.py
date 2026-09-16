#!/usr/bin/env python3
"""Inspect an unsigned MindSpace IPA for release-critical structure and privacy."""

from __future__ import annotations

import hashlib
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parent.parent
EXPECTED_PLIST = ROOT / "Sources" / "MindSpace" / "Info.plist"
OUTPUT = ROOT / "TestResults" / "release-inspection.json"


def fail(message: str) -> None:
    raise SystemExit(f"Release inspection failed: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: inspect_release_artifact.py <MindSpace.ipa>")

    ipa = Path(sys.argv[1]).resolve()
    if not ipa.is_file():
        fail(f"IPA not found: {ipa}")

    expected = plistlib.loads(EXPECTED_PLIST.read_bytes())
    expected_identifier = expected["CFBundleIdentifier"]
    expected_version = expected["CFBundleShortVersionString"]
    expected_build = expected["CFBundleVersion"]

    sha256 = hashlib.sha256(ipa.read_bytes()).hexdigest()
    forbidden_names = (
        "planet_",
        "celestialplanetview",
        "starbackground",
        ".env",
        "id_rsa",
        ".pem",
        ".git/",
    )
    secret_patterns = {
        "classic GitHub PAT": re.compile(rb"ghp_[A-Za-z0-9]{20,}"),
        "fine-grained GitHub PAT": re.compile(rb"github_pat_[A-Za-z0-9_]{20,}"),
        "private repository identifier": re.compile(rb"vkr1729/MindSpace-Content", re.IGNORECASE),
        "private content checkout": re.compile(rb"MindSpace_Content_Repo", re.IGNORECASE),
        "developer home path": re.compile(rb"/home/kedarnath-reddy-vallaboina", re.IGNORECASE),
    }

    with zipfile.ZipFile(ipa) as archive:
        corrupt_entry = archive.testzip()
        if corrupt_entry:
            fail(f"ZIP CRC failure in {corrupt_entry}")

        names = archive.namelist()
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts:
                fail(f"unsafe archive path: {name}")
            lowered = name.lower()
            if any(token in lowered for token in forbidden_names):
                fail(f"forbidden release file: {name}")

        plist_names = [name for name in names if name == "Payload/MindSpace.app/Info.plist"]
        if plist_names != ["Payload/MindSpace.app/Info.plist"]:
            fail("expected exactly Payload/MindSpace.app/Info.plist")

        compiled = plistlib.loads(archive.read(plist_names[0]))
        executable_name = compiled.get("CFBundleExecutable")
        executable_path = f"Payload/MindSpace.app/{executable_name}"
        if not executable_name or executable_path not in names:
            fail("expected executable is missing")
        if archive.getinfo(executable_path).file_size == 0:
            fail("compiled executable is empty")

        assertions = {
            "bundle_identifier": compiled.get("CFBundleIdentifier") == expected_identifier,
            "version": compiled.get("CFBundleShortVersionString") == expected_version,
            "build": compiled.get("CFBundleVersion") == expected_build,
            "background_audio": "audio" in compiled.get("UIBackgroundModes", []),
            "file_sharing": compiled.get("UIFileSharingEnabled") is True,
            "opening_documents_in_place": compiled.get("LSSupportsOpeningDocumentsInPlace") is True,
            "native_launch_screen": compiled.get("UILaunchScreen") == {},
            "single_scene_lifecycle": compiled.get("UIApplicationSceneManifest", {}).get(
                "UIApplicationSupportsMultipleScenes"
            ) is False,
            "iphone_device_family": compiled.get("UIDeviceFamily") == [1],
        }
        failed = [name for name, passed in assertions.items() if not passed]
        if failed:
            fail(f"Info.plist assertions failed: {', '.join(failed)}")

        for name in names:
            if name.endswith("/"):
                continue
            data = archive.read(name)
            for label, pattern in secret_patterns.items():
                if pattern.search(data):
                    fail(f"{label} found in {name}")

        uncompressed_size = sum(item.file_size for item in archive.infolist())

    report = {
        "ipa": str(ipa),
        "size_bytes": ipa.stat().st_size,
        "uncompressed_size_bytes": uncompressed_size,
        "sha256": sha256,
        "bundle_identifier": expected_identifier,
        "version": expected_version,
        "build": expected_build,
        "zip_integrity": "passed",
        "privacy_scan": "passed",
        "retired_visual_asset_scan": "passed",
        "assertions": assertions,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
