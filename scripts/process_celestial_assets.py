#!/usr/bin/env python3
"""
MindSpace Celestial Asset Processor:
Converts square opaque planet bitmaps into cinematic, sub-pixel feathered RGBA transparent assets
and refines the 1024x1024 AppIcon with deep space cosmic gradients and luminous nebula lighting.
"""

import os
from PIL import Image
import numpy as np

ASSETS_DIR = "/home/kedarnath-reddy-vallaboina/MindSpace/Resources/Assets.xcassets"
DIST_DIR = "/home/kedarnath-reddy-vallaboina/MindSpace/dist"

def process_spherical_planet(img_path, r_body=145, r_corona=205):
    im = Image.open(img_path).convert('RGBA')
    arr = np.array(im, dtype=np.float32)
    rgb = arr[:, :, :3]
    
    h, w = arr.shape[:2]
    y, x = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    r = np.sqrt((x - cx)**2 + (y - cy)**2)
    
    lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    
    alpha = np.zeros((h, w), dtype=np.float32)
    body_mask = r <= r_body
    alpha[body_mask] = 255.0
    
    corona_mask = (r > r_body) & (r <= r_corona)
    t = (r[corona_mask] - r_body) / (r_corona - r_body)
    falloff = 0.5 * (1.0 + np.cos(np.pi * t))
    lum_factor = np.clip((lum[corona_mask] - 15.0) / 40.0, 0.0, 1.0)
    alpha[corona_mask] = 255.0 * falloff * (0.35 + 0.65 * lum_factor)
    
    arr[:, :, 3] = np.clip(alpha, 0.0, 255.0)
    
    # Subtle mantle contrast polish
    mantle_mask = alpha > 10.0
    arr[mantle_mask, :3] = np.clip(arr[mantle_mask, :3] * 1.05, 0.0, 255.0)
    
    return Image.fromarray(arr.astype(np.uint8), mode='RGBA')

def process_ringed_planet(img_path):
    im = Image.open(img_path).convert('RGBA')
    arr = np.array(im, dtype=np.float32)
    rgb = arr[:, :, :3]
    
    h, w = arr.shape[:2]
    y, x = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    
    r_sphere = np.sqrt((x - cx)**2 + (y - cy)**2)
    
    angle = np.radians(22)
    cos_a, sin_a = np.cos(angle), np.sin(angle)
    xr = (x - cx) * cos_a - (y - cy) * sin_a
    yr = (x - cx) * sin_a + (y - cy) * cos_a
    
    r_ring_ellipse = np.sqrt((xr / 245.0)**2 + (yr / 75.0)**2)
    lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    
    alpha = np.zeros((h, w), dtype=np.float32)
    
    # 1. Sphere contribution
    sphere_mask = r_sphere <= 135.0
    alpha[sphere_mask] = 255.0
    
    sphere_corona = (r_sphere > 135.0) & (r_sphere <= 170.0)
    ts = (r_sphere[sphere_corona] - 135.0) / 35.0
    falloff_s = 0.5 * (1.0 + np.cos(np.pi * ts))
    alpha[sphere_corona] = np.maximum(alpha[sphere_corona], 255.0 * falloff_s)
    
    # 2. Ring contribution (elliptical band)
    ring_band = (r_ring_ellipse >= 0.45) & (r_ring_ellipse <= 1.0)
    tr = np.abs(r_ring_ellipse[ring_band] - 0.75) / 0.25
    falloff_r = 0.5 * (1.0 + np.cos(np.pi * tr))
    lum_factor_r = np.clip((lum[ring_band] - 18.0) / 35.0, 0.0, 1.0)
    alpha[ring_band] = np.maximum(alpha[ring_band], 255.0 * falloff_r * (0.4 + 0.6 * lum_factor_r))
    
    arr[:, :, 3] = np.clip(alpha, 0.0, 255.0)
    
    mantle_mask = alpha > 10.0
    arr[mantle_mask, :3] = np.clip(arr[mantle_mask, :3] * 1.05, 0.0, 255.0)
    
    return Image.fromarray(arr.astype(np.uint8), mode='RGBA')

def process_app_icon(base_icon_path):
    base_im = Image.open(base_icon_path).convert('RGBA')
    base_arr = np.array(base_im, dtype=np.float32)
    
    h, w = 1024, 1024
    y, x = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    r = np.sqrt((x - cx)**2 + (y - cy)**2)
    
    # 1. Deep Space Cosmic Background
    top_color = np.array([22.0, 15.0, 46.0])     # Deep Cosmic Purple
    bottom_color = np.array([8.0, 11.0, 21.0])   # Space Abyss
    
    t_y = (y / float(h))[:, :, np.newaxis]
    bg_gradient = (1.0 - t_y) * top_color + t_y * bottom_color
    
    # 2. Ambient Celestial Nebula Glow in center
    nebula_radial = np.clip(1.0 - (r / 480.0), 0.0, 1.0)**2.0
    nebula_color = np.array([124.0, 92.0, 252.0]) # Cosmic Purple
    gold_nebula = np.clip(1.0 - (r / 260.0), 0.0, 1.0)**2.5
    gold_color = np.array([246.0, 208.0, 111.0])  # Starlight Gold
    
    nebula_layer = (nebula_radial[:, :, np.newaxis] * nebula_color * 0.28 +
                    gold_nebula[:, :, np.newaxis] * gold_color * 0.18)
    
    composite_bg = bg_gradient + nebula_layer
    
    # 3. Extract central planet & ring from base_arr
    lum = 0.299 * base_arr[:, :, 0] + 0.587 * base_arr[:, :, 1] + 0.114 * base_arr[:, :, 2]
    
    angle = np.radians(22)
    cos_a, sin_a = np.cos(angle), np.sin(angle)
    xr = (x - cx) * cos_a - (y - cy) * sin_a
    yr = (x - cx) * sin_a + (y - cy) * cos_a
    r_ring_ellipse = np.sqrt((xr / 480.0)**2 + (yr / 150.0)**2)
    
    sphere_mask = r <= 270.0
    ring_mask = (r_ring_ellipse >= 0.40) & (r_ring_ellipse <= 1.0)
    
    alpha_planet = np.zeros((h, w), dtype=np.float32)
    alpha_planet[sphere_mask] = 1.0
    
    sphere_edge = (r > 270.0) & (r <= 340.0)
    ts = (r[sphere_edge] - 270.0) / 70.0
    alpha_planet[sphere_edge] = np.maximum(alpha_planet[sphere_edge], 0.5 * (1.0 + np.cos(np.pi * ts)))
    
    tr = np.abs(r_ring_ellipse[ring_mask] - 0.70) / 0.30
    falloff_r = 0.5 * (1.0 + np.cos(np.pi * tr))
    lum_r = np.clip((lum[ring_mask] - 15.0) / 40.0, 0.0, 1.0)
    alpha_planet[ring_mask] = np.maximum(alpha_planet[ring_mask], falloff_r * (0.35 + 0.65 * lum_r))
    
    planet_rgb = base_arr[:, :, :3]
    planet_rgb = np.clip(planet_rgb * 1.12, 0.0, 255.0)
    
    alpha_expanded = alpha_planet[:, :, np.newaxis]
    final_rgb = alpha_expanded * planet_rgb + (1.0 - alpha_expanded) * composite_bg
    
    final_arr = np.dstack([np.clip(final_rgb, 0.0, 255.0), np.full((h, w), 255.0)])
    return Image.fromarray(final_arr.astype(np.uint8), mode='RGBA')

def main():
    print("=== MindSpace Celestial Asset Processing ===")
    
    # Process planet assets
    spherical_planets = [
        'planet_health', 'planet_happiness', 'planet_sleep',
        'planet_work', 'planet_brave', 'planet_sport',
        'planet_students', 'planet_pro'
    ]
    
    for name in spherical_planets:
        p = os.path.join(ASSETS_DIR, f"{name}.imageset", f"{name}.png")
        if os.path.exists(p):
            processed = process_spherical_planet(p)
            processed.save(p, format="PNG")
            arr = np.array(processed)
            print(f"  ✅ Processed {name}: corners alpha = {arr[0,0,3]}, center alpha = {arr[256,256,3]}")
    
    # Process ringed planet
    ringed_path = os.path.join(ASSETS_DIR, "planet_foundation.imageset", "planet_foundation.png")
    if os.path.exists(ringed_path):
        processed_ringed = process_ringed_planet(ringed_path)
        processed_ringed.save(ringed_path, format="PNG")
        arr = np.array(processed_ringed)
        print(f"  ✅ Processed planet_foundation: corners alpha = {arr[0,0,3]}, center alpha = {arr[256,256,3]}")
    
    # Process AppIcon
    app_icon_path = os.path.join(ASSETS_DIR, "AppIcon.appiconset", "AppIcon-1024.png")
    if os.path.exists(app_icon_path):
        polished_icon = process_app_icon(app_icon_path)
        polished_icon.save(app_icon_path, format="PNG")
        
        dist_icon_path = os.path.join(DIST_DIR, "AppIcon-1024.png")
        polished_icon.save(dist_icon_path, format="PNG")
        print(f"  ✅ Polished AppIcon-1024.png in Assets.xcassets and dist/")
    
    print("🎉 All celestial assets and AppIcon successfully updated with transparent alpha!")

if __name__ == "__main__":
    main()
