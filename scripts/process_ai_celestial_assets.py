#!/usr/bin/env python3
"""
MindSpace AI Celestial Asset Transparency Processor
Converts AI generated photorealistic celestial bodies on solid black into 100% native RGBA PNGs
with smooth atmospheric falloff and guaranteed zero rectangular/square artifacting.
"""

import sys
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT_DIR / "Resources" / "Assets.xcassets"
DIST_DIR = ROOT_DIR / "dist"
BRAIN_DIR = Path("/home/kedarnath-reddy-vallaboina/.gemini/antigravity-ide/brain/8bba5c89-34bc-42c5-83a6-261ccdd96db4")

GENERATED_ASSETS = {
    "planet_foundation": BRAIN_DIR / "planet_foundation_gen_1787290499776.jpg",
    "planet_health": BRAIN_DIR / "planet_health_gen_1787290513233.jpg",
    "planet_happiness": BRAIN_DIR / "planet_happiness_gen_1787290526740.jpg",
    "planet_sleep": BRAIN_DIR / "planet_sleep_gen_1787290539895.jpg",
    "planet_work": BRAIN_DIR / "planet_work_gen_1787290554693.jpg",
    "planet_brave": BRAIN_DIR / "planet_brave_gen_1787290568730.jpg",
    "planet_sport": BRAIN_DIR / "planet_sport_gen_1787290583597.jpg",
    "planet_students": BRAIN_DIR / "planet_students_gen_1787290607063.jpg",
    "planet_pro": BRAIN_DIR / "planet_pro_gen_1787290622125.jpg",
}

APP_ICON = BRAIN_DIR / "mindspace_app_icon_1787290366089.jpg"

def process_planet_image(src_path, dest_path):
    print(f"Processing {src_path.name} -> {dest_path.name}...")
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    
    h, w, _ = arr.shape
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    
    # Calculate luminance & max chromatic intensity
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    max_channel = np.maximum(r, np.maximum(g, b))
    
    # Smooth luminance-based alpha thresholding
    # Pure space background (black) has brightness < 10 -> alpha = 0.
    # Celestial body & glowing ring/corona transitions smoothly to 1.0.
    black_threshold = 12.0
    transition_width = 18.0
    
    alpha = np.clip((max_channel - black_threshold) / transition_width, 0.0, 1.0)
    
    # Distance-based radial mask from center to guarantee outer edges are 100% transparent
    cy, cx = h / 2.0, w / 2.0
    y_idx, x_idx = np.ogrid[:h, :w]
    dist_from_center = np.sqrt((x_idx - cx)**2 + (y_idx - cy)**2)
    max_radius = min(cx, cy) - 4.0
    
    edge_feather = np.clip((max_radius - dist_from_center) / 8.0, 0.0, 1.0)
    alpha = alpha * edge_feather
    
    arr[:, :, 3] = alpha * 255.0
    
    # Convert back to RGBA image and resize to standard 512x512 asset
    rgba_img = Image.fromarray(arr.astype(np.uint8), mode="RGBA")
    rgba_img = rgba_img.resize((512, 512), Image.Resampling.LANCZOS)
    
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    rgba_img.save(dest_path, "PNG")
    
    # Strict corner verification
    corners = [
        rgba_img.getpixel((0, 0)),
        rgba_img.getpixel((511, 0)),
        rgba_img.getpixel((0, 511)),
        rgba_img.getpixel((511, 511))
    ]
    corner_alphas = [c[3] for c in corners]
    assert all(a == 0 for a in corner_alphas), f"Corner alpha non-zero in {dest_path.name}: {corner_alphas}"
    print(f"  ✓ {dest_path.name} saved (512x512 RGBA, Corners transparent: {corner_alphas})")

def process_app_icon():
    print("Processing AppIcon-1024.png...")
    icon_img = Image.open(APP_ICON).convert("RGBA")
    icon_img = icon_img.resize((1024, 1024), Image.Resampling.LANCZOS)
    
    dest_asset = ASSETS_DIR / "AppIcon.appiconset" / "AppIcon-1024.png"
    dest_dist = DIST_DIR / "AppIcon-1024.png"
    
    dest_asset.parent.mkdir(parents=True, exist_ok=True)
    icon_img.save(dest_asset, "PNG")
    icon_img.save(dest_dist, "PNG")
    print(f"  ✓ AppIcon-1024.png saved to Assets and dist/ (1024x1024 RGBA)")

def main():
    print("=== Processing AI Generated Celestial Assets ===")
    for name, src in GENERATED_ASSETS.items():
        if not src.exists():
            print(f"❌ Missing generated image: {src}", file=sys.stderr)
            sys.exit(1)
        dest = ASSETS_DIR / f"{name}.imageset" / f"{name}.png"
        process_planet_image(src, dest)
        
    process_app_icon()
    print("\n🎉 ALL 9 AI PLANET ASSETS & APP ICON PROCESSED WITH 100% NATIVE ALPHA!")

if __name__ == "__main__":
    main()
