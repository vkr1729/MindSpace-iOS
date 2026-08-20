#!/usr/bin/env python3
import os
import sys
import shutil
import time

SOURCE_DIR = "/home/kedarnath-reddy-vallaboina/MindSpace/Content"
TARGET_DIR = "/tmp/mindspace_mount/Documents/MindSpaceLibrary"

def get_all_files(src_dir):
    file_list = []
    for root, _, files in os.walk(src_dir):
        for f in files:
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, src_dir)
            size = os.path.getsize(full_path)
            file_list.append((rel_path, full_path, size))
    return file_list

def main():
    if not os.path.exists(TARGET_DIR):
        print(f"Error: Target directory {TARGET_DIR} not found. Is iPhone container mounted?")
        sys.exit(1)
        
    all_files = get_all_files(SOURCE_DIR)
    total_files = len(all_files)
    total_bytes = sum(f[2] for f in all_files)
    
    print(f"==================================================")
    print(f"🚀 MindSpace USB Media Library Sync to iPhone")
    print(f"📁 Source: {SOURCE_DIR}")
    print(f"📱 Destination: {TARGET_DIR}")
    print(f"📊 Total: {total_files} files ({total_bytes / (1024**3):.2f} GB)")
    print(f"==================================================")
    
    transferred_bytes = 0
    transferred_count = 0
    skipped_count = 0
    start_time = time.time()
    
    for idx, (rel_path, src_path, size) in enumerate(all_files, 1):
        dst_path = os.path.join(TARGET_DIR, rel_path)
        dst_dir = os.path.dirname(dst_path)
        
        # Ensure subdirectories exist
        os.makedirs(dst_dir, exist_ok=True)
        
        # Check if already copied with identical size
        if os.path.exists(dst_path) and os.path.getsize(dst_path) == size:
            skipped_count += 1
            transferred_bytes += size
            continue
            
        t0 = time.time()
        shutil.copy2(src_path, dst_path)
        t_copy = max(0.001, time.time() - t0)
        speed_mb = (size / (1024**2)) / t_copy
        
        transferred_bytes += size
        transferred_count += 1
        
        elapsed = time.time() - start_time
        overall_speed = (transferred_bytes / (1024**2)) / max(1, elapsed)
        progress_pct = (transferred_bytes / total_bytes) * 100
        
        # Progress line
        print(f"[{idx}/{total_files}] ({progress_pct:.1f}%) [{speed_mb:.1f} MB/s] -> {rel_path}", flush=True)

    print(f"\n==================================================")
    print(f"✅ Sync Complete!")
    print(f"Transferred: {transferred_count} files, Skipped (already up-to-date): {skipped_count} files")
    print(f"Total size: {total_bytes / (1024**3):.2f} GB in {time.time() - start_time:.1f} seconds")
    print(f"==================================================")

if __name__ == "__main__":
    main()
