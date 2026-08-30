#!/usr/bin/env python3
"""
MindSpace Offline Catalog Manifest Generator
Scans Content/ directory, extracts ffprobe metadata and SHA-256 digests,
normalizes course structures and video attachments, and emits
Resources/catalog.json and Resources/catalog.sha256.
"""

import os
import sys
import json
import hashlib
import subprocess
import uuid
import re
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor

NAMESPACE_MINDSPACE = uuid.UUID("a3f8c120-7e4d-4b92-8d2a-9e32f518a901")

def stable_uuid(relative_path: str) -> str:
    # Normalize forward slashes
    norm_path = relative_path.replace("\\", "/")
    return str(uuid.uuid5(NAMESPACE_MINDSPACE, norm_path))

def get_media_metadata(full_path: str):
    cmd = [
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration,size:stream=codec_name,width,height",
        "-of", "json", full_path
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Warning: ffprobe failed for {full_path}: {res.stderr}", file=sys.stderr)
        duration = 0.0
        size = os.path.getsize(full_path)
        codec = "unknown"
        width, height = None, None
        return duration, size, codec, width, height

    try:
        data = json.loads(res.stdout)
    except Exception:
        data = {}

    fmt = data.get("format", {})
    streams = data.get("streams", [{}])

    duration = float(fmt.get("duration", 0.0))
    size = int(fmt.get("size", os.path.getsize(full_path)))

    stream0 = streams[0] if streams else {}
    codec = stream0.get("codec_name", "unknown")
    width = stream0.get("width")
    height = stream0.get("height")

    # If stream0 had no width/height but stream1 (e.g. video) has, check all streams
    if width is None or height is None:
        for s in streams:
            if s.get("width") and s.get("height"):
                width = s.get("width")
                height = s.get("height")
                codec = s.get("codec_name", codec)
                break

    return duration, size, codec, width, height

def compute_sha256(full_path: str) -> str:
    h = hashlib.sha256()
    with open(full_path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def process_file(entry):
    full_path, rel_path = entry
    duration, size, codec, width, height = get_media_metadata(full_path)
    digest = compute_sha256(full_path)
    file_id = stable_uuid(rel_path)
    return rel_path, {
        "id": file_id,
        "relativePath": rel_path,
        "duration": duration,
        "sizeBytes": size,
        "sha256": digest,
        "codec": codec,
        "width": width,
        "height": height
    }

def clean_title_from_filename(filename: str) -> str:
    name, _ = os.path.splitext(filename)
    # Remove leading prefixes like "MindSpace - ", "Single - ", "MindSpace "
    name = re.sub(r"^(MindSpace\s*-\s*|Single\s*-\s*|MindSpace\s+)", "", name, flags=re.IGNORECASE)
    return name.strip()

def extract_day_number(filename: str) -> int:
    m = re.search(r"Day\s*(\d+)", filename, re.IGNORECASE)
    if m:
        return int(m.group(1))
    return 0

def get_pack_category_meta(cat_folder: str):
    meta = {
        "1 - Foundation": ("Foundation", "#8BCAB7", "figure.mind.and.body", "Build your daily practice with timeless fundamentals"),
        "2 - Health": ("Health", "#8BCAB7", "waveform.path.ecg", "Support your physical and emotional wellbeing"),
        "3 - Brave": ("Brave", "#D6BD92", "shield.fill", "Navigate difficult emotions and life transitions"),
        "4 - Happiness": ("Happiness", "#B7D6C8", "heart.fill", "Cultivate joy, relationships, and acceptance"),
        "5 - Work & Performance": ("Work & Performance", "#8CB9C4", "scope", "Clarity, focus, and sustainable productivity"),
        "6 - Students": ("Students", "#8CB9C4", "book.fill", "Study focus, exam calm, and campus life"),
        "7 - MindSpace Pro": ("MindSpace Pro", "#AAB8AE", "circle.grid.2x2.fill", "Deepen silence and extended meditation technique"),
        "8 - Sport": ("Sport", "#8BCAB7", "figure.run", "Training focus, competition calm, and recovery")
    }
    name, color, icon, desc = meta.get(cat_folder, (cat_folder, "#8BCAB7", "square.grid.2x2.fill", "Explore guided meditations"))
    return name, color, icon, desc

def get_singles_category_meta(cat_folder: str):
    meta = {
        "1 - Classics": ("Classics", "#3B82F6", "timer", "Guided and unguided timers"),
        "2 - SOS": ("SOS", "#FF7B72", "cross.circle.fill", "Immediate calm during high stress or sudden panic"),
        "3 - Good Morning": ("Good Morning", "#F6D06F", "sun.max.fill", "Start your morning with presence and focus"),
        "4 - Good Night": ("Good Night", "#9D8DF1", "moon.stars.fill", "Ease into restful, deep sleep"),
        "5 - Sleep Sounds": ("Sleep Sounds", "#7C5CFC", "waveform", "Calming ambient soundscapes and restful audio"),
        "6 - Unwind": ("Unwind", "#4ECCA3", "leaf.fill", "Transitions to help you decompress from your day"),
        "7 - Rough Day": ("Rough Day", "#FF7B72", "heart.circle.fill", "Gentle support when things feel heavy"),
        "8 - Anxious Moments": ("Anxious Moments", "#3B82F6", "shield.fill", "Quick tools for unexpected stress and worry"),
        "9 - At Home": ("At Home", "#F6D06F", "house.fill", "Mindfulness for chores, hobbies, and downtime"),
        "10 - At Work": ("At Work", "#3B82F6", "briefcase.fill", "Focus, presentations, and mindful breaks"),
        "11 - Walking": ("Walking", "#4ECCA3", "figure.walk", "Bring presence to movement and fresh air"),
        "12 - Travel": ("Travel", "#9D8DF1", "airplane", "Stay grounded during commutes, flights, and trips"),
        "13 - On-the-go": ("On-the-go", "#F6D06F", "figure.walk.motion", "Short pauses for busy daily moments"),
        "14 - Working Out": ("Working Out", "#FF7B72", "flame.fill", "Mindful stamina for workouts and training"),
        "15 - Sport Singles": ("Sport Singles", "#4ECCA3", "sportscourt.fill", "Pre-competition focus and recovery sessions")
    }
    name, color, icon, desc = meta.get(cat_folder, (cat_folder, "#7C5CFC", "sparkles", "Single standalone meditations"))
    return name, color, icon, desc

def main():
    content_dir = "Content"
    if not os.path.exists(content_dir):
        print(f"Error: {content_dir} directory not found!", file=sys.stderr)
        sys.exit(1)

    print("Scanning Content/ directory...")
    all_files = []
    for root, _, filenames in os.walk(content_dir):
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            if ext in [".mp3", ".mp4"]:
                full_path = os.path.join(root, f)
                rel_path = os.path.relpath(full_path, content_dir)
                all_files.append((full_path, rel_path))

    print(f"Found {len(all_files)} media files. Extracting metadata with ffprobe and computing SHA-256 (multithreaded)...")

    file_metadata_map = {}
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = executor.map(process_file, all_files)
        for rel_path, meta in results:
            file_metadata_map[rel_path] = meta

    print(f"Extracted metadata for all {len(file_metadata_map)} files.")

    # Now organize into Packs and Singles hierarchy
    packs_dir = os.path.join(content_dir, "Packs")
    singles_dir = os.path.join(content_dir, "Singles")

    pack_categories = []
    if os.path.exists(packs_dir):
        cat_folders = sorted(os.listdir(packs_dir))
        for order, cat_folder in enumerate(cat_folders, 1):
            cat_path = os.path.join(packs_dir, cat_folder)
            if not os.path.isdir(cat_path):
                continue
            cat_name, cat_color, cat_icon, cat_desc = get_pack_category_meta(cat_folder)
            cat_id = f"pack_cat_{order}_{re.sub(r'[^a-zA-Z0-9]', '_', cat_name.lower())}"

            courses = []
            course_folders = sorted(os.listdir(cat_path))
            for course_order, course_folder in enumerate(course_folders, 1):
                course_path = os.path.join(cat_path, course_folder)
                if not os.path.isdir(course_path):
                    continue

                course_files = sorted(os.listdir(course_path))
                clean_course_name = re.sub(r"^\d+\s*-\s*", "", course_folder)
                course_id = f"course_{order}_{course_order}_{re.sub(r'[^a-zA-Z0-9]', '_', clean_course_name.lower())}"

                intro_video = None
                day_audio_files = []
                day_video_files = []

                for cf in course_files:
                    cf_ext = os.path.splitext(cf)[1].lower()
                    cf_rel = os.path.relpath(os.path.join(course_path, cf), content_dir)
                    meta = file_metadata_map.get(cf_rel)
                    if not meta:
                        continue

                    # Check if intro video
                    if cf_ext == ".mp4" and ("intro" in cf.lower()):
                        intro_video = {
                            "id": meta["id"],
                            "title": f"{clean_course_name} — Introduction Video",
                            "relativePath": cf_rel,
                            "duration": meta["duration"],
                            "sizeBytes": meta["sizeBytes"],
                            "sha256": meta["sha256"],
                            "width": meta["width"],
                            "height": meta["height"],
                            "codec": meta["codec"]
                        }
                    elif cf_ext == ".mp4":
                        day_video_files.append((cf, meta))
                    elif cf_ext == ".mp3":
                        day_audio_files.append((cf, meta))

                # Sort audio files by day number
                def audio_sort_key(item):
                    day = extract_day_number(item[0])
                    return (day if day > 0 else 999, item[0])

                day_audio_files.sort(key=audio_sort_key)

                # Map sessions
                sessions = []
                for cf, meta in day_audio_files:
                    day_num = extract_day_number(cf)
                    sess_title = clean_title_from_filename(cf)
                    if not sess_title or sess_title.isdigit():
                        sess_title = f"{clean_course_name} — Day {day_num}" if day_num > 0 else clean_course_name

                    # Find matching day video attachments
                    attachments = []
                    for vf, vmeta in day_video_files:
                        vday = extract_day_number(vf)
                        if vday == day_num and day_num > 0:
                            vtitle = clean_title_from_filename(vf)
                            attachments.append({
                                "id": vmeta["id"],
                                "title": vtitle,
                                "relativePath": vmeta["relativePath"],
                                "duration": vmeta["duration"],
                                "sizeBytes": vmeta["sizeBytes"],
                                "sha256": vmeta["sha256"],
                                "width": vmeta["width"],
                                "height": vmeta["height"],
                                "codec": vmeta["codec"],
                                "placement": "beforeSession"
                            })

                    sessions.append({
                        "id": meta["id"],
                        "title": sess_title,
                        "dayNumber": day_num,
                        "relativePath": meta["relativePath"],
                        "duration": meta["duration"],
                        "sizeBytes": meta["sizeBytes"],
                        "sha256": meta["sha256"],
                        "codec": meta["codec"],
                        "videoAttachments": attachments
                    })

                has_gap_waiver = ("pregnancy" in course_folder.lower())

                courses.append({
                    "id": course_id,
                    "name": clean_course_name,
                    "folderName": course_folder,
                    "order": course_order,
                    "description": f"{len(sessions)} days of mindful practice in {clean_course_name}",
                    "totalSessions": len(sessions),
                    "hasGapWaiver": has_gap_waiver,
                    "introVideo": intro_video,
                    "sessions": sessions
                })

            pack_categories.append({
                "id": cat_id,
                "type": "pack",
                "name": cat_name,
                "folderName": cat_folder,
                "order": order,
                "description": cat_desc,
                "colorHex": cat_color,
                "iconName": cat_icon,
                "courses": courses
            })

    # Now organize Singles categories
    singles_categories = []
    if os.path.exists(singles_dir):
        cat_folders = sorted(os.listdir(singles_dir), key=lambda x: int(x.split(" - ")[0]) if " - " in x and x.split(" - ")[0].isdigit() else 999)
        for order, cat_folder in enumerate(cat_folders, 1):
            cat_path = os.path.join(singles_dir, cat_folder)
            if not os.path.isdir(cat_path):
                continue
            cat_name, cat_color, cat_icon, cat_desc = get_singles_category_meta(cat_folder)
            cat_id = f"single_cat_{order}_{re.sub(r'[^a-zA-Z0-9]', '_', cat_name.lower())}"

            sessions = []
            for root, _, sfiles in os.walk(cat_path):
                sub_rel = os.path.relpath(root, cat_path)
                sub_name = sub_rel if sub_rel != "." else None
                for sf in sorted(sfiles):
                    sf_ext = os.path.splitext(sf)[1].lower()
                    if sf_ext in [".mp3", ".mp4"]:
                        sf_rel = os.path.relpath(os.path.join(root, sf), content_dir)
                        meta = file_metadata_map.get(sf_rel)
                        if not meta:
                            continue
                        title = clean_title_from_filename(sf)
                        sessions.append({
                            "id": meta["id"],
                            "title": title,
                            "category": cat_name,
                            "subCategory": sub_name,
                            "relativePath": meta["relativePath"],
                            "duration": meta["duration"],
                            "sizeBytes": meta["sizeBytes"],
                            "sha256": meta["sha256"],
                            "codec": meta["codec"]
                        })

            singles_categories.append({
                "id": cat_id,
                "name": cat_name,
                "folderName": cat_folder,
                "order": order,
                "description": cat_desc,
                "colorHex": cat_color,
                "iconName": cat_icon,
                "sessions": sessions
            })

    total_duration = sum(m["duration"] for m in file_metadata_map.values())
    total_size_bytes = sum(m["sizeBytes"] for m in file_metadata_map.values())

    catalog_data = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "totalFiles": len(file_metadata_map),
        "totalDuration": total_duration,
        "totalDurationHours": round(total_duration / 3600.0, 2),
        "totalSizeBytes": total_size_bytes,
        "categories": pack_categories,
        "singlesCategories": singles_categories
    }

    output_json_path = os.path.join("Resources", "catalog.json")
    output_sha_path = os.path.join("Resources", "catalog.sha256")
    os.makedirs("Resources", exist_ok=True)

    print(f"Writing catalog to {output_json_path}...")
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(catalog_data, f, indent=2, ensure_ascii=False)

    json_sha = compute_sha256(output_json_path)
    with open(output_sha_path, "w", encoding="utf-8") as f:
        f.write(f"{json_sha}  catalog.json\n")

    print("\n--- CATALOG GENERATION SUMMARY ---")
    print(f"Total Files: {len(file_metadata_map)}")
    print(f"Total Duration: {total_duration:.2f} seconds ({round(total_duration / 3600.0, 2)} hours)")
    print(f"Total Size: {total_size_bytes:,} bytes ({total_size_bytes / (1024**3):.2f} GB)")
    print(f"Packs Categories: {len(pack_categories)}")
    total_courses = sum(len(c["courses"]) for c in pack_categories)
    print(f"Total Courses: {total_courses}")
    print(f"Singles Categories: {len(singles_categories)}")
    total_singles = sum(len(c["sessions"]) for c in singles_categories)
    print(f"Total Singles: {total_singles}")
    print(f"Catalog SHA-256: {json_sha}")
    print("Catalog generation complete!")

if __name__ == "__main__":
    main()
