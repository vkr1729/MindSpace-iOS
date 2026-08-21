#!/usr/bin/env python3
"""
MindSpace Canonical Version Synchronization Tool
Enforces apps.json as the Single Source of Truth across:
- project.yml
- Sources/MindSpace/Info.plist
- dist/apps.json
- Compiled MindSpace.app/Info.plist
- Final packaged MindSpace.ipa
"""

import os
import sys
import json
import plistlib
import argparse
import tempfile
import zipfile
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent

def load_canonical_version():
    apps_path = ROOT_DIR / "apps.json"
    if not apps_path.exists():
        raise FileNotFoundError(f"apps.json not found at {apps_path}")
    with open(apps_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    app = data["apps"][0]
    version = str(app["version"]).strip()
    build = str(app.get("build", "10")).strip()
    return version, build

def sync_project_files(version, build):
    print(f"🔄 Syncing canonical version: {version} (Build {build})")
    
    # 1. Update Sources/MindSpace/Info.plist
    plist_path = ROOT_DIR / "Sources" / "MindSpace" / "Info.plist"
    if plist_path.exists():
        p = plistlib.load(open(plist_path, "rb"))
        p["CFBundleShortVersionString"] = version
        p["CFBundleVersion"] = build
        plistlib.dump(p, open(plist_path, "wb"))
        print(f"  ✓ Updated Sources/MindSpace/Info.plist -> {version} ({build})")
        
    # 2. Update project.yml
    proj_path = ROOT_DIR / "project.yml"
    if proj_path.exists():
        lines = proj_path.read_text(encoding="utf-8").splitlines()
        new_lines = []
        for line in lines:
            if "MARKETING_VERSION:" in line:
                indent = line[:line.find("MARKETING_VERSION:")]
                new_lines.append(f'{indent}MARKETING_VERSION: "{version}"')
            elif "CURRENT_PROJECT_VERSION:" in line:
                indent = line[:line.find("CURRENT_PROJECT_VERSION:")]
                new_lines.append(f'{indent}CURRENT_PROJECT_VERSION: "{build}"')
            elif "INFOPLIST_KEY_CFBundleShortVersionString:" in line:
                indent = line[:line.find("INFOPLIST_KEY_CFBundleShortVersionString:")]
                new_lines.append(f'{indent}INFOPLIST_KEY_CFBundleShortVersionString: "{version}"')
            elif "INFOPLIST_KEY_CFBundleVersion:" in line:
                indent = line[:line.find("INFOPLIST_KEY_CFBundleVersion:")]
                new_lines.append(f'{indent}INFOPLIST_KEY_CFBundleVersion: "{build}"')
            else:
                new_lines.append(line)
        proj_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
        print(f"  ✓ Updated project.yml -> {version} ({build})")
        
    # 3. Update dist/apps.json
    dist_apps = ROOT_DIR / "dist" / "apps.json"
    if dist_apps.exists():
        with open(dist_apps, "r", encoding="utf-8") as f:
            d = json.load(f)
        d["apps"][0]["version"] = version
        d["apps"][0]["build"] = build
        with open(dist_apps, "w", encoding="utf-8") as f:
            json.dump(d, f, indent=2)
        print(f"  ✓ Updated dist/apps.json -> {version} ({build})")

def sync_compiled_plist(plist_file, version, build):
    p_path = Path(plist_file)
    if not p_path.exists():
        print(f"❌ Target plist not found: {p_path}", file=sys.stderr)
        sys.exit(1)
        
    p = plistlib.load(open(p_path, "rb"))
    p["CFBundleShortVersionString"] = str(version)
    p["CFBundleVersion"] = str(build)
    
    # Enforce background audio & document sharing
    if "UIBackgroundModes" not in p or "audio" not in p.get("UIBackgroundModes", []):
        modes = list(p.get("UIBackgroundModes", []))
        if "audio" not in modes:
            modes.append("audio")
        p["UIBackgroundModes"] = modes
    p["UIFileSharingEnabled"] = True
    p["LSSupportsOpeningDocumentsInPlace"] = True
    p["UILaunchStoryboardName"] = "LaunchScreen"
    
    plistlib.dump(p, open(p_path, "wb"))
    
    # Verification
    verified = plistlib.load(open(p_path, "rb"))
    ver = verified.get("CFBundleShortVersionString")
    bld = verified.get("CFBundleVersion")
    print(f"  ✓ Injected into {p_path.name}: Version={ver}, Build={bld}")
    if ver != str(version):
        print(f"❌ FATAL: Plist injection verification failed: {ver} != {version}", file=sys.stderr)
        sys.exit(1)

def verify_ipa(ipa_path, expected_version):
    ipa_file = Path(ipa_path)
    if not ipa_file.exists():
        print(f"❌ IPA not found at {ipa_file}", file=sys.stderr)
        sys.exit(1)
        
    with zipfile.ZipFile(ipa_file, "r") as z:
        plist_names = [n for n in z.namelist() if n.endswith("MindSpace.app/Info.plist")]
        if not plist_names:
            print("❌ Info.plist not found inside IPA!", file=sys.stderr)
            sys.exit(1)
        plist_data = z.read(plist_names[0])
        p = plistlib.loads(plist_data)
        ver = p.get("CFBundleShortVersionString")
        bld = p.get("CFBundleVersion")
        print("==========================================================")
        print(f"🔍 Inspecting IPA: {ipa_file.name}")
        print(f"   Payload Info.plist CFBundleShortVersionString: '{ver}'")
        print(f"   Payload Info.plist CFBundleVersion:            '{bld}'")
        print(f"   Expected Canonical Version:                   '{expected_version}'")
        print("==========================================================")
        if ver != str(expected_version):
            print(f"❌ FATAL ERROR: Version mismatch inside IPA! Expected '{expected_version}', found '{ver}'", file=sys.stderr)
            sys.exit(1)
        print("🎉 SUCCESS: IPA version strictly matches canonical apps.json version!")

def main():
    parser = argparse.ArgumentParser(description="MindSpace Version Synchronization Engine")
    parser.add_argument("--sync-all", action="store_true", help="Sync version across all project source files")
    parser.add_argument("--inject-plist", type=str, help="Inject canonical version into compiled Info.plist")
    parser.add_argument("--verify-ipa", type=str, help="Verify version inside compiled .ipa file")
    
    args = parser.parse_args()
    version, build = load_canonical_version()
    
    if args.sync_all or (not args.inject_plist and not args.verify_ipa):
        sync_project_files(version, build)
        
    if args.inject_plist:
        sync_compiled_plist(args.inject_plist, version, build)
        
    if args.verify_ipa:
        verify_ipa(args.verify_ipa, version)

if __name__ == "__main__":
    main()
