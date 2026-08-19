# MindSpace UI/UX Design System & Canonical Screen Blueprint

**Primary Visual Reference:** [Mock Screen Codex.png](file:///home/kedarnath-reddy-vallaboina/MindSpace/Mock%20Screen%20Codex.png)  
**Theme:** "Quiet Cosmos"  
**Target Platform:** iOS 18.0+ (Fluid 120Hz ProMotion, SF Pro Rounded, Dynamic Type, Canvas Rendering, SwiftUI Matched Geometry)  
**Core Aesthetic:** Deep Midnight Navy, Celestial Planetary Orbs, Glowing Orbit Arc Gauges, Cosmic Purple & Starlight Gold Highlights  

---

## 1. Canonical Screen Specifications (Matched to Mockup)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CANONICAL 6-SCREEN ARCHITECTURE                       │
├───────────────────┬───────────────────┬───────────────────┬─────────────────┤
│    1. Today       │    2. Library     │    3. Course      │    4. Player    │
│  Orbit Arc Gauge  │  Category Cards   │  Hybrid Constell. │  3D Floating    │
│  & Daily Journey  │  & Planet Glyphs  │  + Session List   │  Orb + Scrubber │
├───────────────────┼───────────────────┼───────────────────┼─────────────────┤
│   5. Complete     │    6. Progress    │                   │                 │
│  Starlight Arc    │  Heatmap, Stats   │                   │                 │
│  & Next Milestone │  & Cosmic Badges  │                   │                 │
└───────────────────┴───────────────────┴───────────────────┴─────────────────┘
```

---

### Screen 1: Today Tab
* **Header:**
  - Left: "MindSpace" (Bold SF Pro Rounded, `#F0F6FC`).
  - Right: Bell icon (`bell.fill` with subtle starlight badge).
  - Greeting: *"Good evening / Take a breath. You're here."* (Time-aware: adapts to Morning, Afternoon, Evening).
* **Orbit Streak Gauge:**
  - Dynamic circular gradient arc gauge (Cosmic Purple `#7C5CFC` to Solar Coral `#FF7B72` with glowing starlight tip `#F6D06F`).
  - Center readout: **"7 day Orbit / 7 / 14 days"**.
* **Daily Journey Checklist (3-Item Micro-Path):**
  - Item 1: `[✓] Continue Basics — Day 4 (10 min)` with solid purple `[Continue]` button.
  - Item 2: `[○] 5 min reset (5 min)` with clean circular tap checkbox.
  - Item 3: `[○] Evening wind-down (10 min)` with clean circular tap checkbox.
* **Persistent Mini-Player:**
  - Floating playback strip docked seamlessly above the custom bottom tab bar when a session is active.
* **Navigation Tab Bar:**
  - 4 clean line icons: **Today** (`house.fill`), **Library** (`books.vertical`), **Progress** (`chart.bar`), **Settings** (`gearshape`).

---

### Screen 2: Library & Category Explorer
* **Header & Search:**
  - Large title: **"Library"**.
  - Search bar: *"🔍 Search courses, sessions, topics..."* with instant sub-millisecond local filtering.
* **Top Filter Chips:**
  - Horizontal scrolling pill chips: `[Courses]`, `[Singles]`, `[SOS]`, `[Sleep]`.
* **Category Cards with Celestial Planetary Art:**
  - **Foundation:** *"Build your daily practice / 10 sessions"* — Stylized purple ringed planet.
  - **Health:** *"Support body and mind / 8 sessions"* — Glowing aurora teal planet.
  - **Happiness:** *"Cultivate daily joy / 10 sessions"* — Glowing solar coral/orange planet.
  - **Work & Focus:** *"Clarity and productivity / 7 sessions"* — Deep electric blue planet.
  - **Sleep Sounds:** *"Wind down and rest / 12 tracks"* — Deep purple horizon with glowing crescent moon.

---

### Screen 3: Course Detail ("Managing Anxiety")
* **Navigation Bar:**
  - Left: `<` Back chevron.
  - Center: Course title **"Managing Anxiety"** and subtitle **"10 sessions"**.
  - Right: `...` Options menu.
* **Course Header & Progress Gauge:**
  - Progress indicator: **"Your progress: 4 of 10"**.
* **Interactive Star Constellation Path (Top Half):**
  - Rendered via SwiftUI `Canvas` with smooth Bezier splines connecting 10 numbered celestial star nodes:
    - **Nodes 1–4 (Completed):** Glowing warm starlight gold (`#F6D06F`) numbered circles with connected solid golden lines.
    - **Node 5 (Active / Next):** Pulsing cosmic lavender (`#7C5CFC`) numbered circle with radiant outer halo.
    - **Nodes 6–10 (Upcoming):** Dim translucent numbered circles connected by delicate dashed spline lines.
* **Primary Action Button:**
  - Prominent full-width button: **`Continue Day 5 ▶`** in solid cosmic purple (`#7C5CFC`).
* **Session List (Bottom Half):**
  - Clean vertical list with track duration and completion checkmarks:
    - `1  Understanding anxiety  9:47  [✓]`
    - `2  Body awareness         9:12  [✓]`
    - `3  Calming the mind       9:58  [✓]`

---

### Screen 4: Minimalist Meditation Player
* **Navigation Bar:**
  - Left: `⌄` Down chevron (collapses to mini-player with `.matchedGeometryEffect`).
  - Center: Track title **"Basics — Day 4"** with subtle **"• Offline"** badge.
  - Right: `...` Audio settings menu.
* **Central Visual Anchor:**
  - A serene 3D ringed celestial planet floating in deep space with soft atmospheric glow and ambient starfield.
  - Automatically switches to an aspect-fit native video layer when playing an MP4 video session.
* **Time Readout & Scrubber:**
  - Large digital time: **"08:42 / of 10:00"**.
  - Smooth cosmic purple progress bar with elapsed (`08:42`) and total (`10:00`) timestamps.
* **Controls:**
  - Center: Large purple circular **Play / Pause** button with glowing starlight aura.
  - Left: `↺ 15` Skip backward 15 seconds.
  - Right: `↻ 15` Skip forward 15 seconds.
* **Bottom Pill Controls:**
  - Left: `[ 1.0x Speed ]` (toggles 0.75x, 1.0x, 1.25x).
  - Right: `[ ⏰ Timer ]` (sleep timer options).

---

### Screen 5: Completion Screen
* **Header:** Close button `✕` on top-right.
* **Celebration Banner:**
  - Title: **"Orbit continued"**.
  - Subtitle: **"12 mindful minutes"**.
* **Constellation Arc Visual:**
  - Glowing 7-star golden constellation arc with glowing center star.
  - Affirmation text: *"You're building something beautiful."*
* **Milestone Progress Card:**
  - Card with planet graphic: **"7 / 14 days — Next milestone: 14 days"**.
* **Action Buttons:**
  - Primary: `[ Next session ]` (solid purple button).
  - Secondary: `[ Done ]` (dark elevated button).

---

### Screen 6: Progress & Journey Dashboard
* **Header:** **"Your journey"** on left, Calendar icon on right.
* **Top Metric Badges:**
  - `[ 7 day Orbit / 7/14 days ]` (with circular gauge icon).
  - `[ 324 mindful minutes ]` (with clock icon).
  - `[ 28 sessions ]` (with star icon).
* **Monthly Activity Heatmap:**
  - Month indicator: *"May 2025"* with `<` and `>` navigation.
  - Day columns (M T W T F S S) with 4-level dot indicators from *Less* to *More*.
* **Course Progress Section (`View all >`):**
  - `Managing Anxiety` — *4 / 10 >* with green planet badge.
  - `Basics` — *6 / 10 >* with purple planet badge.
* **Achievements Gallery (`View all >`):**
  - `First Orbit` (7 days) — Star constellation badge.
  - `Stellar Start` (14 days) — Star constellation badge.
  - `Deep Space` (30 days) — Star constellation badge.

---

## 2. Concrete Design Tokens & SwiftUI Color Definitions

```swift
import SwiftUI

public enum CosmosTheme {
    // Core Backgrounds
    public static let spaceBackground     = Color(hex: "#0B0E17") // Deep midnight navy base
    public static let spaceCard           = Color(hex: "#151B28") // Elevated card background
    public static let spaceCardBorder     = Color(hex: "#222D42") // Subtle card border
    
    // Core Accents (Direct from Mockup)
    public static let cosmicPurple        = Color(hex: "#7C5CFC") // Primary buttons, active nodes, scrubber
    public static let starlightGold       = Color(hex: "#F6D06F") // Completed nodes, streak tips, badges
    public static let solarCoral          = Color(hex: "#FF7B72") // Orbit gauge gradient end & warm accents
    public static let auroraTeal          = Color(hex: "#4ECCA3") // Health & mindfulness accents
    public static let celestialBlue       = Color(hex: "#3B82F6") // Work & focus accents
    public static let moonLavender        = Color(hex: "#9D8DF1") // Secondary text highlights
    
    // Text Hierarchy
    public static let textPrimary         = Color(hex: "#F0F6FC") // Primary crisp white
    public static let textSecondary       = Color(hex: "#8B949E") // Muted subtext
    public static let textDisabled        = Color(hex: "#484F58") // Locked node text
    
    // Ultra-Dark Sleep Mode Palette
    public static let sleepAbyss          = Color(hex: "#05070B") // 99% OLED black
    public static let sleepCard           = Color(hex: "#0C1018") // Minimal contrast card
    public static let sleepWarmGold       = Color(hex: "#B89B4A") // Muted amber starlight
}
```

---

## 3. UI Component Architecture & Motion Specifications

1. **Constellation Spline Rendering (`ConstellationPathView.swift`):**
   - Connects coordinates $(x_i, y_i)$ of adjacent days using `path.addCurve(to:control1:control2:)` to achieve smooth cosmic S-curves.
   - Node 5 pulses with an infinite `animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true))` scale modifier.
2. **Player Transition (`MiniPlayerView` ↔ `FullPlayerView`):**
   - Uses `.matchedGeometryEffect(id: "player_container", in: playerAnimationNamespace)` with an interactive drag-to-dismiss gesture.
3. **CoreHaptics Integration:**
   - Soft feedback generator attached to `[Continue Day X ▶]` and play/pause buttons.
