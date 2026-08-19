# MindSpace: Offline iOS Development & Autonomous Implementation Plan (Final)

**Target Platform:** iOS 18.0+ (Swift 6, SwiftUI, SwiftData, AVFoundation)  
**Hardware Profile:** Modern iPhone (optimized for ProMotion 120Hz OLED displays)  
**Distribution:** Personal Sideload via SideStore & Linux USB (`ifuse`)  
**CI/CD Pipeline:** Autonomous GitHub Actions macOS Runner producing unsigned `.ipa`  
**Authoritative Blueprint:** Consolidated from Base Plan, Gemini Architectural Review, and Claude Review  

---

## 1. Executive Product Specification & Architecture Vision

MindSpace is a completely private, account-free native iOS meditation application designed to turn a user-supplied 15.81 GB offline library (905 audio/video files, 276 hours) into a seamless, fluid daily meditation journey.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MINDSPACE SYSTEM TOPOLOGY                          │
├─────────────────────────────────────┬───────────────────────────────────────┤
│        APP CONTAINER (IPA)          │        MEDIA LIBRARY (Documents)      │
│            (~25 MB Binary)          │               (15.81 GB)              │
├─────────────────────────────────────┼───────────────────────────────────────┤
│ • SwiftUI 6 UI & Fluid Navigation   │ • catalog.json & catalog.sha256       │
│ • "Quiet Cosmos" Design System      │ • Packs/ (8 Categories, 44 Courses)   │
│ • SwiftData Progression Engine      │ • Singles/ (15 Categories)            │
│ • Production AVPlayback Engine      │ • Artwork/ (Vector & Raster Icons)    │
│ • Local Notification Scheduler      │                                       │
│ • Progress Export/Import Engine     │ [Storage: Documents/MindSpaceLibrary] │
│ [Protection: CompleteUntilAuth]     │ [Backup: Excluded from iCloud]        │
└─────────────────────────────────────┴───────────────────────────────────────┘
```

### Core Product Principles

1. **Zero Network Traffic & Utmost Privacy:**
   - The app binary makes zero network calls, contains no third-party telemetry, ads, remote configs, or account logins.
   - All playback, recommendations, statistics, streaks, and search index operations execute deterministically on-device in Airplane Mode.
   - The GitHub repository is strictly private; media files are strictly excluded from git.
2. **Fluidity as Mindfulness ("Flow State"):**
   - The interface is designed around effortless, micro-animated interactions with 120Hz ProMotion transitions, soft cosmic glows, tactile CoreHaptics, and zero jarring layout shifts.
3. **App Binary vs. Content Library Decoupling:**
   - The IPA (~25 MB) is compiled on GitHub Actions and signed via SideStore.
   - The 15.81 GB media library is transferred once via USB (`ifuse`) or external drive into the app's `Documents/MindSpaceLibrary/` container and remains untouched during weekly SideStore app refreshes.
4. **Cross-Device Progress Portability Without Accounts:**
   - Complete user progression, history, streaks, and preferences can be exported to a lightweight, human-readable `.mindspace` JSON backup file and seamlessly imported onto any new device via the iOS Files app or AirDrop.

---

## 2. Design Language & UX System: "Quiet Cosmos" (Canonical Mockup Blueprint)

**Canonical Visual Reference:** [Mock Screen Codex.png](file:///home/kedarnath-reddy-vallaboina/MindSpace/Mock%20Screen%20Codex.png)  
The design philosophy emphasizes calmness, breathing room, and visual tranquility. Rather than busy commercial gamification, MindSpace uses celestial metaphors (orbits, constellations, starlight nodes, planetary artwork) rendered with subtle gradients and fluid physics.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          "QUIET COSMOS" COLOR PALETTE                       │
├───────────────────┬───────────────────┬───────────────────┬─────────────────┤
│  Deep Space Base  │   Cosmic Purple   │  Starlight Gold   │   Solar Coral   │
│      #0B0E17      │      #7C5CFC      │      #F6D06F      │     #FF7B72     │
├───────────────────┼───────────────────┼───────────────────┼─────────────────┤
│  Nebula Card Dark │   Aurora Teal     │  Celestial Blue   │   Sleep Abyss   │
│      #151B28      │      #4ECCA3      │      #3B82F6      │     #05070B     │
└───────────────────┴───────────────────┴───────────────────┴─────────────────┘
```

### 2.1 Concrete Color Tokens & Semantic Theme Modes

```swift
import SwiftUI

public enum CosmosTheme {
    // Core Backgrounds
    public static let spaceBackground     = Color(hex: "#0B0E17") // Deep midnight navy base
    public static let spaceCard           = Color(hex: "#151B28") // Elevated card surface
    public static let spaceCardBorder     = Color(hex: "#222D42") // Subtle outline border
    
    // Core Accents (Canonical Mockup Tokens)
    public static let cosmicPurple        = Color(hex: "#7C5CFC") // Primary buttons, active nodes, scrubber
    public static let starlightGold       = Color(hex: "#F6D06F") // Completed nodes, streak tips, badges
    public static let solarCoral          = Color(hex: "#FF7B72") // Orbit gauge gradient end & warm accents
    public static let auroraTeal          = Color(hex: "#4ECCA3") // Health & mindfulness accents
    public static let celestialBlue       = Color(hex: "#3B82F6") // Work & focus accents
    public static let moonLavender        = Color(hex: "#9D8DF1") // Secondary text & subtle highlights
    
    // Text Hierarchy
    public static let textPrimary         = Color(hex: "#F0F6FC") // Primary crisp white
    public static let textSecondary       = Color(hex: "#8B949E") // Muted subtext
    public static let textDisabled        = Color(hex: "#484F58") // Locked node text
    
    // Ultra-Dark Sleep Mode Palette
    public static let sleepAbyss          = Color(hex: "#05070B") // 99% OLED black
    public static let sleepCard           = Color(hex: "#0C1018") // Minimal contrast card
    public static let sleepWarmGold       = Color(hex: "#B89B4A") // Muted amber starlight
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### 2.2 Canonical Screen Specifications (Matched to [Mock Screen Codex.png](file:///home/kedarnath-reddy-vallaboina/MindSpace/Mock%20Screen%20Codex.png))

1. **Screen 1: Today Tab**
   - Header: "MindSpace" with notification bell.
   - Time-aware Greeting: *"Good evening / Take a breath. You're here."*
   - Orbit Streak Gauge: Circular gradient arc (`#7C5CFC` to `#FF7B72`) showing **"7 day Orbit / 7 / 14 days"**.
   - Daily Journey Checklist: 3 micro-steps (`Continue Basics — Day 4`, `5 min reset`, `Evening wind-down`).
   - Floating Mini-Player bar above bottom tab bar.
2. **Screen 2: Library & Category Explorer**
   - Search bar: *"🔍 Search courses, sessions, topics..."* with instant local query.
   - Top category chips: `[Courses]`, `[Singles]`, `[SOS]`, `[Sleep]`.
   - Planetary Category Cards: Foundation (Purple ringed planet), Health (Teal planet), Happiness (Coral planet), Work & Focus (Blue planet), Sleep Sounds (Crescent moon).
3. **Screen 3: Course View ("Managing Anxiety")**
   - Hybrid layout:
     - Top: Interactive Star Constellation Path (Nodes 1–4 completed gold, Node 5 active purple with glowing halo, Nodes 6–10 dim upcoming).
     - Prominent Action Button: **`Continue Day 5 ▶`** in solid cosmic purple.
     - Bottom: Structured Session List with exact durations and checkmarks.
4. **Screen 4: Minimalist Meditation Player**
   - Header: `⌄` minimize button, title "Basics — Day 4", subtle `• Offline` badge.
   - Central Visual: Serene 3D ringed celestial planet floating in deep space (switches to aspect-fit video for MP4 sessions).
   - Time Readout: Large digital `08:42 / of 10:00`.
   - Controls: Sleek purple scrubber, large Play/Pause with starlight glow, ±15s skips, `1.0x Speed` & `Timer` pill buttons.
5. **Screen 5: Completion Screen**
   - Title: **"Orbit continued / 12 mindful minutes"**.
   - Starlight constellation arc: *"You're building something beautiful."*
   - Milestone progress card: "7 / 14 days — Next milestone: 14 days".
   - Primary action: `[ Next session ]` and `[ Done ]`.
6. **Screen 6: Progress Dashboard ("Your journey")**
   - Top Metrics: `7 day Orbit`, `324 mindful minutes`, `28 sessions`.
   - Monthly Activity Heatmap: "May 2025" with 4-level dot indicators (M T W T F S S).
   - Course Progress & Celestial Achievement Badges (*First Orbit*, *Stellar Start*, *Deep Space*).

---

## 3. Content Audit, Normalization & Pipeline Engine

### 3.1 Content Audit Breakdown

| Metric | Verified Value |
|---|:---|
| **Total Media Files** | **905 files** |
| **Total Storage Size** | **15,810,896,818 bytes (15.81 GB / 14.72 GiB)** |
| **Total Audio/Video Runtime** | **275.99 hours (993,564 seconds)** |
| **Audio Format** | **828 MP3 files** (native AVFoundation hardware decoding) |
| **Video Format** | **77 MP4 files** (H.264 / AAC; 74 Day-videos + 3 Intros) |
| **Packs Hierarchy** | 8 Categories, 44 Courses/Levels, 754 Files (677 audio + 77 video) |
| **Singles Hierarchy** | 15 Categories, 151 Audio Files |

### 3.2 Content Normalization Rules

1. **Stable UUIDv5 Generation:**
   IDs must never be generated from display titles or sequential counters. They are generated via UUIDv5 using a canonical namespace and relative file path:
   `ID = uuid.uuid5(UUID_NAMESPACE_MINDSPACE, "Packs/1 - Foundation/1 - Basics/MindSpace - Basics 1 - Day 01.mp3")`
2. **Video Association Heuristic:**
   - Intro videos (`Basics Intro.MP4`, `Basics 3 Intro.MP4`, `Coping with Cancer Intro.MP4`) are mapped to `course.introVideo`.
   - Day-matched videos (`MindSpace - Pregnancy - Day 01.mp4`) are linked directly to their respective `session.videoAttachment` with `placement: "beforeSession"`.
3. **Pregnancy Pack Gap Handling (Days 27–29):**
   - `Packs/2 - Health/5 - Pregnancy` contains Days 1–26 and Day 30.
   - The catalog generator marks the course with `hasGapWaiver: true`.
   - The UI Constellation renders a gentle "Bridge of Reflection" node connecting Day 26 to Day 30 without crashing or blocking course completion.

### 3.3 Python Manifest Generator (`scripts/generate_catalog.py`)

A standalone script on Ubuntu runs before project build to inspect media with `ffprobe`, calculate metadata, verify SHA-256 digests, and emit `catalog.json` and `catalog.sha256`:

```python
#!/usr/bin/env python3
"""
MindSpace Manifest Generator
Scans Content/ directory, extracts ffprobe metadata, and emits catalog.json
"""
import os, sys, json, hashlib, subprocess, uuid

NAMESPACE_MINDSPACE = uuid.UUID("a3f8c120-7e4d-4b92-8d2a-9e32f518a901")

def get_media_metadata(file_path):
    cmd = [
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration,size:stream=codec_name,width,height",
        "-of", "json", file_path
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(res.stdout)
    fmt = data.get("format", {})
    streams = data.get("streams", [{}])
    
    duration = float(fmt.get("duration", 0.0))
    size = int(fmt.get("size", os.path.getsize(file_path)))
    width = streams[0].get("width")
    height = streams[0].get("height")
    codec = streams[0].get("codec_name", "unknown")
    return duration, size, codec, width, height

def compute_sha256(file_path):
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()
```

---

## 4. Media Playback & System Lifecycle Engine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PLAYBACK ENGINE STATE MACHINE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  [Idle] ──> [Loading Track] ──> [ReadyToPlay] ──> [Playing] ──> [Completed] │
│                                      │                │                     │
│                                      │                ▼ (Interruption/Route)│
│                                      └──────────> [Paused]                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Audio Session & Remote Controls

- **Audio Session Category:** `AVAudioSession.sharedInstance().setCategory(.playback, mode: .spacedSpokenAudio, policy: .longFormAudio)`
- **Lock Screen & Control Center (`MPNowPlayingInfoCenter`):**
  - Displays session title, course/category, artwork, duration, elapsed playback position, and playback rate.
- **Remote Commands (`MPRemoteCommandCenter`):**
  - Supports Play, Pause, TogglePlayPause, SkipForward (15s), SkipBackward (15s), and Scrubber seeking.

### 4.2 Interruption & Route Change Matrix

| Event | System Behavior | MindSpace Handler |
|---|---|---|
| **Phone Call / Alarm (Began)** | Audio interrupted | Save `wasPlaying = true`, pause player, pause accumulator. |
| **Phone Call / Alarm (Ended)** | Interruption ended | If `options.contains(.shouldResume)` & `wasPlaying`, resume smoothly. |
| **AirPods / Bluetooth Disconnected** | `routeChangeReason == .oldDeviceUnavailable` | **Mandatory pause**; never leak meditation audio to the phone speaker. |
| **Device Locked with Passcode** | Screen locked | Seamless continuation (guaranteed by `CompleteUntilAuth` protection). |

### 4.3 Anti-Scrubbing Listening Accumulator

Progress is awarded based on continuous listening time, not scrubber position:

$$\text{RequiredSeconds} = \max(60, \min(0.90 \times \text{Duration}, \text{Duration} - 30))$$

```swift
@MainActor
public final class ListeningAccumulator: ObservableObject {
    public let targetThreshold: Double
    @Published public private(set) var accumulatedSeconds: Double = 0.0
    private var lastObservedTime: Double?
    
    public init(duration: Double) {
        self.targetThreshold = max(60.0, min(duration * 0.90, duration - 30.0))
    }
    
    public func tick(currentTime: Double, isPlaying: Bool) {
        guard isPlaying else {
            lastObservedTime = nil
            return
        }
        if let last = lastObservedTime {
            let delta = currentTime - last
            if delta > 0.0 && delta < 1.5 { // Valid real-time increment
                accumulatedSeconds += delta
            }
        }
        lastObservedTime = currentTime
    }
    
    public var hasQualified: Bool {
        accumulatedSeconds >= targetThreshold
    }
}
```

---

## 5. Storage, Sandboxing & Cross-Device Progress Portability

### 5.1 Sandbox & Storage Hardening

1. **Target Directory:** `Documents/MindSpaceLibrary/`
2. **File Protection Key:**
   `NSFileProtectionCompleteUntilFirstUserAuthentication` applied recursively to all media and the SwiftData store to prevent locked-screen audio termination.
3. **iCloud Backup Exclusion:**
   `NSURLIsExcludedFromBackupKey = true` applied to `Documents/MindSpaceLibrary` to protect the user's iCloud storage quota.
4. **Relative Path Storage:**
   All SwiftData models store strictly relative paths (e.g. `Packs/1 - Foundation/...`). At runtime, paths are resolved dynamically against the active app container's `Documents` URL.

### 5.2 Cross-Device Progress Portability Specification

To support migrating progress when switching iPhones without accounts or servers:

```json
{
  "backupVersion": 1,
  "exportedAt": "2026-08-19T22:30:00Z",
  "appVersion": "1.0.0",
  "catalogSchemaVersion": 1,
  "stats": {
    "totalMindfulMinutes": 480,
    "completedSessionsCount": 42,
    "currentStreak": 14,
    "bestStreak": 14
  },
  "userSettings": {
    "defaultDurationMinutes": 10,
    "reminderTime": "08:00",
    "themeMode": "quiet_cosmos",
    "hideStreak": false,
    "compassionPassCount": 1
  },
  "completionEvents": [
    {
      "id": "c1f8a890-...",
      "sessionId": "sess_basics_1_d01",
      "timestamp": "2026-08-19T07:15:00Z",
      "timeZone": "America/New_York",
      "playedSeconds": 605.2,
      "reflection": "lighter"
    }
  ],
  "favorites": ["sess_basics_1_d01", "single_rough_day_3m"],
  "achievements": [
    { "id": "badge_first_step", "unlockedAt": "2026-08-01T08:00:00Z" },
    { "id": "badge_7_day_orbit", "unlockedAt": "2026-08-07T08:15:00Z" }
  ]
}
```

- **Export UI:** Located in **Settings → Progress Backup → Export Progress (.mindspace)**. Opens the standard iOS Share Sheet (save to Files, AirDrop, send via email).
- **Import UI:** Located in **Settings → Progress Backup → Import Progress**. Allows user to pick a `.mindspace` file with a clear preview dialog:
  - Shows incoming stats: *"Import 42 sessions, 14-day streak, and 2 achievements?"*
  - Options: **Merge with Existing** or **Restore Clean**.

---

## 6. Data Model & Concurrency Architecture

### 6.1 SwiftData Entities

```swift
import Foundation
import SwiftData

@Model
public final class CompletionEvent {
    @Attribute(.unique) public var id: UUID
    public var sessionStableId: String
    public var timestamp: Date
    public var timeZoneIdentifier: String
    public var gmtOffsetSeconds: Int
    public var actualPlayedSeconds: Double
    public var isQualifyingMeditation: Bool
    public var reflectionNote: String? // "lighter", "same", "heavier"
    
    public init(sessionStableId: String, actualPlayedSeconds: Double, isQualifying: Bool, reflection: String? = nil) {
        self.id = UUID()
        self.sessionStableId = sessionStableId
        self.timestamp = Date()
        self.timeZoneIdentifier = TimeZone.current.identifier
        self.gmtOffsetSeconds = TimeZone.current.secondsFromGMT()
        self.actualPlayedSeconds = actualPlayedSeconds
        self.isQualifyingMeditation = isQualifying
        self.reflectionNote = reflection
    }
}

@Model
public final class PlaybackResume {
    @Attribute(.unique) public var sessionStableId: String
    public var relativePath: String
    public var lastPositionSeconds: Double
    public var updatedAt: Date
    
    public init(sessionStableId: String, relativePath: String, position: Double) {
        self.sessionStableId = sessionStableId
        self.relativePath = relativePath
        self.lastPositionSeconds = position
        self.updatedAt = Date()
    }
}
```

### 6.2 Swift 6 `@ModelActor` Isolation

To avoid SQLite lock contention and concurrency violations, background logging runs inside a dedicated `ModelActor`:

```swift
import SwiftData

@ModelActor
public actor ProgressActor {
    public func recordCompletion(
        sessionStableId: String,
        playedSeconds: Double,
        isQualifying: Bool,
        reflection: String?
    ) throws {
        let event = CompletionEvent(
            sessionStableId: sessionStableId,
            actualPlayedSeconds: playedSeconds,
            isQualifying: isQualifying,
            reflection: reflection
        )
        modelContext.insert(event)
        try modelContext.save()
    }
}
```

---

## 7. Gamification & Progression: "Inner Orbit"

- **Daily Orbit Streak:**
  - 1 qualifying session ($\ge 3$ mins) per calendar day advances the Orbit.
  - Calculated using local start-of-day taking into account time zone transitions and travel.
- **The Compassion Pass:**
  - Earned automatically upon reaching a 7-day streak.
  - Automatically covers 1 missed day per rolling 30-day window, preventing streak reset guilt.
- **Constellation Milestones:**
  - Completing course constellations lights up celestial galaxy maps.
- **Sensitive Topics Exemption:**
  - Practice in topics like depression, grief, cancer, and panic is tracked in mindful minutes but **never awards gamification badges or competitive streak banners**.

---

## 8. Autonomous Development & CI/CD Pipeline

The project uses the configured **GitHub Plugin & MCP Server** and **Figma Plugin & MCP Server** to run autonomous end-to-end development.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AUTONOMOUS CI/CD PIPELINE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Ubuntu Workspace ──> Git Commit & Push ──> GitHub Actions (macos-14)       │
│                                                      │                      │
│                                                      ▼                      │
│ Unsigned MindSpace.ipa <── Download Artifact <── XcodeGen + xcodebuild      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.1 XcodeGen Specification (`project.yml`)

```yaml
name: MindSpace
options:
  bundleIdPrefix: com.mindspace
  deploymentTarget:
    iOS: "18.0"
  swiftVersion: "6.0"
  xcodeVersion: "16.0"
  createIntermediateGroups: true

settings:
  base:
    ENABLE_USER_SCRIPT_SANDBOXING: NO
    SWIFT_STRICT_CONCURRENCY: complete
    INFOPLIST_KEY_UIFileSharingEnabled: YES
    INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace: YES
    INFOPLIST_KEY_UIBackgroundModes: "audio"
    INFOPLIST_KEY_UILaunchScreen_Generation: YES
    INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait"

targets:
  MindSpace:
    type: application
    platform: iOS
    sources:
      - path: Sources/MindSpace
      - path: Resources
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.mindspace.offline
      PRODUCT_NAME: MindSpace
      CODE_SIGN_IDENTITY: ""
      CODE_SIGNING_REQUIRED: NO
      CODE_SIGNING_ALLOWED: NO
    dependencies: []

  MindSpaceTests:
    type: bundle.unit-testing
    platform: iOS
    sources:
      - path: Tests/MindSpaceTests
    dependencies:
      - target: MindSpace
```

### 8.2 GitHub Actions Workflow (`.github/workflows/build-ipa.yml`)

```yaml
name: Build MindSpace Unsigned IPA

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'Sources/**'
      - 'Resources/**'
      - 'Tests/**'
      - 'project.yml'
      - '.github/workflows/build-ipa.yml'

jobs:
  build:
    name: Build & Package IPA
    runs-on: macos-14
    timeout-minutes: 25

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Select Xcode 16
        run: sudo xcode-select -s /Applications/Xcode_16.0.app || sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Verify Zero-Network Rule (API Scan)
        run: |
          echo "Scanning for forbidden networking symbols..."
          if grep -rnw 'Sources/' -e 'URLSession' -e 'WebKit' -e 'CFNetwork' -e 'Network.framework'; then
            echo "ERROR: Network code detected in offline meditation app!"
            exit 1
          fi
          echo "PASS: Zero network APIs detected."

      - name: Generate Xcode Project
        run: xcodegen generate

      - name: Run Unit & Concurrency Tests
        run: |
          xcodebuild test \
            -project MindSpace.xcodeproj \
            -scheme MindSpace \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -derivedDataPath build

      - name: Compile Unsigned iOS Binary
        run: |
          xcodebuild clean build \
            -project MindSpace.xcodeproj \
            -scheme MindSpace \
            -sdk iphoneos \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY=""

      - name: Assemble & Zip IPA Payload
        run: |
          mkdir -p Payload
          cp -R build/Build/Products/Release-iphoneos/MindSpace.app Payload/
          zip -qry MindSpace.ipa Payload
          sha256sum MindSpace.ipa > MindSpace.ipa.sha256
          echo "IPA SHA-256 Digest: $(cat MindSpace.ipa.sha256)"

      - name: Upload IPA Artifact
        uses: actions/upload-artifact@v4
        with:
          name: MindSpace-Unsigned-IPA
          path: |
            MindSpace.ipa
            MindSpace.ipa.sha256
          retention-days: 14
```

---

## 9. Autonomous Execution Plan & Phased Roadmap

This execution plan is organized to run autonomously from start to finish without pausing until `MindSpace.ipa` is generated, tested, and downloaded.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AUTONOMOUS EXECUTION FLOW                         │
├─────────────┬───────────────────────────────────────────────────────────────┤
│ Phase 0     │ Content Pipeline & Catalog JSON Freeze                        │
│ Phase 1     │ Project Scaffolding, Models, Design System & Tokens           │
│ Phase 2     │ Production AVPlayer Engine & Background Audio State Machine   │
│ Phase 3     │ SwiftData Event Store, Inner Orbit Engine & Progress Export   │
│ Phase 4     │ Fluid SwiftUI Views: Today, Library, Constellation & Player   │
│ Phase 5     │ CI Push, GitHub Actions Dispatch, Build Verification & IPA DL │
└─────────────┴───────────────────────────────────────────────────────────────┘
```

### Phase 0: Content Pipeline & Catalog JSON Freeze
- Implement `scripts/generate_catalog.py` to extract `ffprobe` metadata, calculate stable UUIDv5 IDs, and resolve video attachments.
- Generate `catalog.json` and `catalog.sha256` for all 905 files.
- **Exit Gate:** `catalog.json` validates with 905 items and 275.99 hours total runtime.

### Phase 1: Project Scaffolding & Design System
- Setup folder hierarchy (`Sources/MindSpace`, `Resources`, `Tests`).
- Implement `CosmosTheme` color tokens, typography scales, and fluid motion modifiers.
- Extract any vector assets using Figma MCP or native SwiftUI Shape drawings.
- Create `project.yml` for XcodeGen.
- **Exit Gate:** `xcodegen generate` succeeds cleanly.

### Phase 2: Production AVPlayer Engine
- Implement `PlaybackEngine`, `ListeningAccumulator`, and `NowPlayingCoordinator`.
- Handle `AVAudioSession` interruptions, route changes (headphone disconnects), and speed options (0.75x, 1x, 1.25x).
- Implement portrait and landscape video presentation.
- **Exit Gate:** Unit tests pass verifying accumulator threshold heuristics and state transitions.

### Phase 3: SwiftData Store, Inner Orbit & Portability
- Implement `CompletionEvent`, `PlaybackResume`, `Favorite`, `UserSettings` models.
- Implement `@ModelActor` (`ProgressActor`) for thread-safe event writes.
- Implement `OrbitCalculator` with Compassion Pass and time-zone resilience.
- Implement `ProgressTransferManager` (JSON Export / Import).
- **Exit Gate:** Unit tests pass verifying streak calculation across DST transitions and export/import round-tripping.

### Phase 4: Fluid SwiftUI Views & Navigation
- **Today Tab:** Daily greeting, current Orbit ring, time-aware recommendations, and resume card.
- **Library Tab:** Fast in-memory filtering by pack, singles, duration chips, and search.
- **Course Detail Tab:** Custom interactive Constellation path view with glowing star nodes.
- **Player & Mini-Player:** Scrubber, fluid `.matchedGeometryEffect` expansion, and breathing radial glow.
- **Settings Tab:** Storage stats, Rescan Library button, and Progress Export/Import sheet.
- **Exit Gate:** UI builds cleanly with zero compiler warnings under Swift 6 strict concurrency.

### Phase 5: Autonomous CI Build & IPA Delivery
- Initialize local git repository, commit all sources, tests, and configuration.
- Push repository to private GitHub origin (`vkr1729/MindSpace-iOS`).
- Dispatch `.github/workflows/build-ipa.yml` via GitHub MCP / `gh workflow run`.
- Monitor build execution until completion.
- Download `MindSpace.ipa` and `MindSpace.ipa.sha256` into the local `dist/` directory.
- **Exit Gate:** Valid `MindSpace.ipa` artifact downloaded and ready for SideStore install.

---

## 10. Comprehensive Verification & Acceptance Matrix

| Category | Verification Test | Expected Result | Status Gate |
|---|---|---|:---:|
| **Zero Network** | Static binary symbol scan | 0 references to `URLSession`, `WebKit`, or remote networking. | **BLOCKER** |
| **Offline Mode** | Launch app in Airplane Mode | All tabs, search, player, and constellations work 100% offline. | **BLOCKER** |
| **Media Playback** | Lock device during audio playback | Audio continues uninterrupted via `CompleteUntilAuth` protection. | **BLOCKER** |
| **Interruption** | Simulated incoming call | Audio pauses; resumes smoothly when call ends. | **BLOCKER** |
| **Route Change** | Disconnect AirPods | Audio immediately pauses; does not spill to speaker. | **BLOCKER** |
| **Anti-Scrubbing** | Seek to 95% within 10s | Completion is not awarded; actual continuous listen required. | **BLOCKER** |
| **Streak Engine** | Simulate missed day after 7-day streak | Compassion Pass covers missed day; streak preserved. | **BLOCKER** |
| **Portability** | Export JSON → Clean wipe → Import JSON | 100% of completion history, streaks, and settings restored. | **BLOCKER** |
| **Storage Safety** | Inspect `Documents/MindSpaceLibrary` | Excluded from iCloud backup (`isExcludedFromBackup == true`). | **BLOCKER** |
| **CI / IPA Delivery** | GitHub Actions macOS build | `MindSpace.ipa` compiles unsigned and downloads to `./dist`. | **BLOCKER** |

---

## 11. Autonomous Execution Command

The plan is finalized, hardened, and ready for continuous autonomous execution. When triggered, the agent will proceed directly through **Phases 0 → 5** until the final unsigned `MindSpace.ipa` is generated and saved in the workspace.
