# MindSpace: offline iOS development plan

Date: 15 August 2026

## 1. Product decision

MindSpace should be a meditation app, not a medication app. It should be a small native iOS application with a large user-supplied media library. The app binary should contain the interface, content catalog, local progress engine, and gamification rules—but not the 15.81 GB media library. Media should be copied to the iPhone after the app is installed and played directly from the app's Documents container.

The product promise is:

> A private, account-free meditation practice that turns a large offline library into a gentle daily journey.

There are two different meanings of “offline” that must be separated:

- **MindSpace itself can be completely offline:** no account, API, analytics, ads, cloud sync, remote configuration, or network calls. All playback, recommendations, reminders, progress, and achievements are local.
- **SideStore still needs periodic internet access:** with a free Apple Account, SideStore signs MindSpace with a seven-day development profile and refreshes it before expiry. LocalDevVPN is used during install/refresh, and SideStore obtains signing data and talks to Apple. This is separate from MindSpace: once launched, MindSpace itself makes no network requests and all media/features work offline.

For a normal personal iPhone, the practical target is “the app makes zero network calls and all features work in Airplane Mode,” while accepting Apple's signing/verification rules.

## 2. Content audit

The folder at `/home/kedarnath-reddy-vallaboina/MindSpace/Content` was inspected with file-type detection and `ffprobe`.

| Metric | Result |
|---|---:|
| Total media | 905 files |
| Total size | 15,810,896,818 bytes (15.81 GB / 14.72 GiB) |
| Total runtime | 275.99 hours |
| MP3 audio | 828 files |
| MP4 video | 77 files |
| Course/pack branch | 754 files, 241.22 hours, 13.22 GB |
| Singles branch | 151 files, 34.76 hours, 2.59 GB |
| Pack categories | 8 |
| Individual courses/levels | 44 |
| Course audio sessions | 677 |

All 905 files were readable by `ffprobe`. The audio files use MP3; the video files use H.264 with AAC audio. These are supported natively by AVFoundation. Most videos are 640×360; two are portrait 406×722 and one is 720×576, so the player must use aspect-fit rather than assume 16:9.

### Pack categories

| Category | Files | Runtime | Size |
|---|---:|---:|---:|
| Foundation | 32 | 8.28 h | 0.42 GB |
| Health | 236 | 74.79 h | 4.05 GB |
| Brave | 70 | 25.07 h | 1.96 GB |
| Happiness | 142 | 43.38 h | 2.50 GB |
| Work & Performance | 107 | 32.51 h | 1.66 GB |
| Students | 20 | 7.16 h | 0.64 GB |
| MindSpace Pro | 67 | 21.58 h | 0.76 GB |
| Sport | 80 | 28.46 h | 1.23 GB |

The Singles branch has 15 categories, including Classics, SOS, Good Morning, Good Night, Sleep Sounds, Unwind, Rough Day, Anxious Moments, At Home, At Work, Walking, Travel, On-the-go, Working Out, and Sport Singles. Labeled 3/5/10/15/20/30/45/60-minute variants are within 75 seconds of their advertised lengths.

### Content issues to resolve before packaging

1. `Packs/2 - Health/5 - Pregnancy` contains Days 1–26 and Day 30 but is missing Days 27–29.
2. Extensions and naming are inconsistent (`.mp3`, `.MP3`, `.mp4`, `.MP4`; multiple Day-video naming patterns). Runtime code must never infer its catalog directly from display names on every launch.
3. Hashing found five exact duplicate groups containing 15 files, or ten redundant copies. The potential space saving is only about 60 MB. Several repeated MP4s appear to be shared instructional animations. The 3/5/10-minute “Flustered” and “Frustrated” MP3s are identical. Preserve separate catalog entries, but optionally map them to one underlying asset after a semantic review.
4. The 77 videos need explicit placement metadata such as `beforeSession`, `afterSession`, or `intro`; filename parsing alone cannot reliably determine presentation order.
5. Health topics such as depression, cancer, pain, pregnancy, and panic require a clear “wellness education, not medical care” notice and an offline emergency-help message. Do not make treatment claims.
6. Confirm that these recordings may legally be copied and used. Their taxonomy closely resembles commercial Headspace material. Keep this a personal sideload unless the necessary content rights are documented, and do not reuse Headspace artwork, characters, copy, or trademarks.

## 3. Headspace UI findings and what to adopt

### Current public references

- [Current Headspace App Store listing](https://apps.apple.com/us/app/headspace-sleep-meditation/id493145008)
- [Headspace's June 2026 Today-tab description](https://help.headspace.com/hc/en-us/articles/51443842967195-Refreshed-Today-Tab-Experience-June-2026)
- [Headspace's Profile organization](https://help.headspace.com/hc/en-us/articles/6096184071323-Updated-Profile)
- [Headspace's run-streak behavior](https://help.headspace.com/hc/en-us/articles/215730567-How-does-the-run-streak-feature-work)
- [ScreensDesign Headspace flow breakdown](https://screensdesign.com/showcase/headspace-meditation-sleep)
- [Mobbin Headspace achievement screen](https://mobbin.com/explore/screens/e822a459-b5ee-479a-8ddc-4afe77921de8)

Current App Store UI screens:

| Pattern | Reference |
|---|---|
| Content categories | [Meditate, Sleep, Breathe, Focus, Move, Mental Health](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/41/75/02/4175024b-516c-40d9-5527-f662e0fc47eb/2.png/600x1300bb.webp) |
| Meditation/course detail | [Artwork, type/duration, description, teacher, Play](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/04/b9/d1/04b9d1fb-4e5a-c2d5-6d48-678469d46bad/3.png/600x1300bb.webp) |
| Sleep duration selection | [Dark presentation and length selector](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/8d/9c/a9/8d9ca98c-46ee-587f-1cef-de6298093e0e/4.png/600x1300bb.webp) |
| Offline/download affordance | [Content storage row and primary Play button](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/97/d8/6d/97d86df2-e7b7-9e8f-b04b-e3b4a78f90f0/5.png/600x1300bb.webp) |
| Collection and navigation | [Today, Explore, Ebb, Profile](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/a2/ae/fc/a2aefc1f-b550-651d-054f-f45f9641b12f/6.png/600x1300bb.webp) |

The strongest reusable ideas are:

- a time-aware Today screen with a short checklist instead of a huge library wall;
- one-tap continuation of the active course;
- large visual content cards with type and duration visible before tapping;
- a minimal player with secondary controls kept out of the way;
- explicit course structure and progress;
- Profile/Progress with stats, run streak, recent activity, and achievements;
- favorites and recents near the top of the product;
- short emergency/SOS sessions that can be reached in one or two taps.

Do not copy Headspace's orange/yellow identity, smiling-circle characters, screen layouts pixel-for-pixel, wording, Ebb AI, social features, subscriptions, or online personalization.

### Original MindSpace visual direction

Use a distinct “quiet cosmos” identity:

- deep midnight navy as the base, with soft lavender, coral, teal, and starlight yellow accents;
- system typography with rounded headings, strong Dynamic Type support, and large tap targets;
- abstract orbs, gradients, constellations, and gentle parallax—not Headspace characters;
- restrained completion animation and haptics, disabled by Reduce Motion;
- sleep mode that automatically uses a very dark palette and low visual contrast.

First visual concept: [MindSpace six-screen quiet-cosmos mockup board](/home/kedarnath-reddy-vallaboina/.codex/generated_images/01a004fd-2b09-7721-8d9b-fa0060cc16b2/exec-f67c6eda-9e2c-4c3c-9dbc-3d3d1ade39f7.png). It covers Today, Library, Course, Player, Completion, and Progress. Treat it as a direction-setting artifact rather than final production measurements.

## 4. Information architecture and screen plan

Use four primary tabs: **Today**, **Library**, **Progress**, and **Settings**. A persistent mini-player appears above the tab bar during playback.

### 1. First launch

- State that MindSpace is private and offline; no account is created.
- Pick goals from categories actually present in the library: Learn, Stress, Sleep, Focus, Happiness, Difficult Moments, Work, and Sport.
- Pick a default session length and optional local reminder time.
- Show Content Setup: “Copy library later” or “Choose a folder.”
- Show the wellness/medical disclaimer once and keep it accessible in Settings.

### 2. Today

- greeting and current “Orbit” streak;
- a three-item daily checklist: continue course, short practice, optional wind-down;
- time-aware morning/evening selection calculated on-device;
- quick buttons for 3, 5, 10, and 20 minutes;
- “Resume where you left off,” Recents, and Favorites;
- deterministic local recommendations based on selected goals, completion history, time of day, and duration—not machine learning or a server.

### 3. Library

- search titles and categories entirely on-device;
- top chips: Courses, Singles, SOS, Sleep, Work, Sport;
- browse the eight Pack categories and fifteen Singles categories;
- filters for duration, guided/unguided, audio/video, completed/unplayed, and favorite;
- clear missing-file and unavailable indicators rather than a failed Play button.

### 4. Course detail

- course artwork, summary, total sessions, total time, and completion percentage;
- a constellation path where each star is one Day/session;
- next session is prominent; previous sessions remain replayable;
- video lessons appear as distinct nodes attached to the relevant Day;
- optional “Guided order” locks future nodes visually, but an “Open course” setting permits any session.

### 5. Single-session detail

- display topic and available duration variants together;
- favorite, duration, and Play controls;
- related offline sessions from the same folder/category;
- SOS sessions always remain ungated and do not require a streak.

### 6. Player

- title, course/day, elapsed/remaining time, large Play/Pause, ±15 seconds, and scrubber;
- audio speed in a secondary sheet (0.75×, 1×, 1.25×); default 1×;
- optional end bell and sleep timer for suitable content;
- resume position, background playback, lock-screen controls, Control Center metadata, route changes, interruptions, and headphones-disconnect pause;
- aspect-fit MP4 video with orientation handled per asset;
- never auto-play the next meditation without an explicit opt-in.

### 7. Completion

- a short visual celebration;
- completed minutes, current Orbit, and progress toward the next milestone;
- next course node and a Done button;
- optional one-tap reflection (“lighter,” “same,” “heavier”) stored locally; skippable and never framed as a diagnosis.

### 8. Progress

- current and best Orbit streaks;
- total minutes, completed sessions, and active days;
- calendar heat map and weekly consistency ring;
- course/constellation progress;
- achievement gallery and recent activity;
- “Hide streak” option for users who find streaks stressful.

### 9. Settings and Storage

- reminder scheduling through local notifications;
- content folder status, file count, used space, rescan, missing files, and validation report;
- import/replace catalog;
- progress export/import as a local JSON backup;
- Reduce Motion, haptics, theme, text size link, and streak visibility;
- Offline & Privacy page that clearly states that the app has no network features.

## 5. Gamification: the “Inner Orbit” system

Gamification should reward consistency without punishing someone for needing rest.

### Completion rule

Track actual played time rather than scrubber position. A session qualifies when actual listening reaches:

`max(60 seconds, min(90% of duration, duration minus 30 seconds))`

Only guided/unguided meditation sessions advance the daily Orbit. Passive sleep sounds and technique videos remain in total listening statistics but do not advance the meditation streak. This mirrors Headspace's useful distinction between practice and passive content, while using simpler calendar-day rules.

### Orbit streak

- one qualifying completion per local calendar day advances the Orbit;
- store the completion timestamp, time-zone identifier, and GMT offset so DST and travel can be tested correctly;
- a “Compassion Pass” earned after seven active days can cover one missed day per rolling 30-day window;
- allow streak visibility to be turned off without disabling history;
- no leaderboard and no social comparison.

### Course constellations

- every course is a constellation and each session is a star node;
- completing a node lights the path to the next one;
- completing a course unlocks a cosmetic background or constellation color—never paid currency or essential content;
- Foundation/Basics becomes the recommended first constellation, not a hard gate for SOS or Sleep.

### Achievements

- First Step; 3, 7, 14, 30, 90, 180, and 365 active-day milestones;
- 60, 300, 1,000, 3,000, and 10,000 mindful minutes;
- complete Basics, first 10-day course, first 30-day course, and one course in each chosen goal;
- Morning, Evening, and Weekend routine badges;
- do not award badges for panic, depression, cancer, pain, or other sensitive-topic usage.

### Local quests

- Daily: complete one 3+ minute meditation.
- Weekly: practice on three days or complete 30 minutes.
- Journey: complete the next two nodes of the active course.
- Variety: try one course and one single without requiring a sensitive category.

Repeatedly replaying one session on the same day may add legitimate minutes but should not repeatedly grant quest credit or cosmetic rewards.

## 6. Offline technical architecture

### Platform

- Swift 6 and SwiftUI;
- minimum deployment target iOS 17 so SwiftData can be used while retaining broad recent-device support;
- an XcodeGen `project.yml` kept in source control so the Xcode project can be generated reproducibly without editing `.pbxproj` files on Ubuntu;
- AVFoundation/AVKit for MP3 and MP4 playback;
- MediaPlayer for lock-screen metadata and remote commands;
- UserNotifications for local reminders;
- no third-party SDKs.

### Modules

1. **Catalog** — decodes a versioned `catalog.json`; searches and groups 905 items.
2. **LibraryIndexer** — validates relative paths, sizes, media types, and optional checksums.
3. **PlaybackEngine** — owns `AVPlayer`, interruptions, routes, background state, and accumulated actual-play time.
4. **ProgressStore** — stores immutable completion events, resume positions, favorites, reflections, and settings in SwiftData.
5. **GamificationEngine** — derives streaks, quests, milestones, and course-node state from completion events.
6. **RecommendationEngine** — makes deterministic, testable offline suggestions.
7. **ImportExport** — scans an `ifuse`/Files-shared Documents library, chooses a directory when needed, and exports/imports progress JSON.

Keep the catalog immutable and user state separate. Use stable IDs from the generated manifest; never key progress by a mutable display title.

Suggested records:

- `CatalogCategory`, `CatalogCourse`, `CatalogSession`, `CatalogAsset`, `CatalogVariant` in JSON;
- `CompletionEvent`, `PlaybackResume`, `Favorite`, `Reflection`, `AchievementAward`, and `UserSettings` in SwiftData;
- every `CompletionEvent` records content ID, actual played seconds, start/end times, time zone, source, and app/catalog version.

### Media configuration

- set `AVAudioSession` to `.playback` and enable the Audio background mode;
- populate `MPNowPlayingInfoCenter` and register `MPRemoteCommandCenter` actions;
- observe audio interruptions and route changes;
- use file URLs only; no HTTP URL support in the catalog schema;
- exclude the media library from backups to avoid attempting a 15 GB iCloud/device backup, while keeping the tiny progress database exportable;
- use a file-protection class compatible with continuing playback after the device locks.

### Enforcing “no network”

- do not add networking packages, WebKit, URLSession calls, analytics, crash reporting, authentication, CloudKit, StoreKit, or remote notifications;
- keep all catalog URLs relative and reject `http`, `https`, and other remote schemes;
- include an automated source scan for common networking APIs and a runtime test in Airplane Mode;
- test with a network proxy/instrument to verify zero app-originated requests;
- document that iOS code-signing verification is outside the app process.

## 7. Content preparation pipeline

Create a small cross-platform Python command-line tool that runs on Ubuntu before installation:

1. Traverse `Content/Packs` and `Content/Singles` case-insensitively.
2. Read duration, codecs, channels, sample rate, and video dimensions with `ffprobe`.
3. Parse the numbered folders and Days into normalized category/course/session records.
4. Assign stable IDs that do not change if display wording is edited.
5. Explicitly attach each MP4 to a course/session and mark intro/technique placement.
6. Calculate SHA-256 once on Ubuntu; do not hash all 15 GB on every iPhone launch.
7. Emit `catalog.json`, `catalog.sha256`, and a human-readable validation report.
8. Fail the build on missing relative paths, duplicate IDs, unsupported codecs, or unexpected Day gaps; allow an explicit waiver for the known Pregnancy gap.

Recommended device folder:

```text
MindSpaceLibrary/
  catalog.json
  catalog.sha256
  Packs/
    ...existing hierarchy...
  Singles/
    ...existing hierarchy...
  Artwork/                 # original MindSpace art, added later
```

Do not rename hundreds of source files in place initially. Normalize titles in `catalog.json` and preserve the original files as the source of truth.

## 8. Moving the content to the iPhone

### Recommended on Ubuntu: USB + `ifuse`

This is the fastest and most storage-efficient method for 15.81 GB.

1. Add `UIFileSharingEnabled = YES` and `LSSupportsOpeningDocumentsInPlace = YES` to the IPA so the app's Documents folder is available through Apple's file-sharing service, Linux AFC tools, and the iPhone Files app.
2. Install MindSpace through SideStore and launch it once. This creates the app container. Do not transfer content before this first launch.
3. On Ubuntu, install/verify `usbmuxd`, `libimobiledevice` utilities, FUSE, and `ifuse`. Do not use `ifuse` 1.2.0 because its project documents a data-corruption bug fixed in 1.2.1; use 1.2.1 or later where possible.
4. Connect the unlocked iPhone over USB, tap **Trust**, and pair it. Run `ifuse --list-apps` to find the actual MindSpace bundle ID after SideStore signing rather than assuming it is unchanged.
5. Mount MindSpace's Documents folder and copy the library with a resumable tool:

   ```bash
   mkdir -p /tmp/mindspace-iphone-documents
   ifuse --documents ACTUAL_BUNDLE_ID /tmp/mindspace-iphone-documents
   rsync -ah --info=progress2 \
     /home/kedarnath-reddy-vallaboina/MindSpace/MindSpaceLibrary/ \
     /tmp/mindspace-iphone-documents/MindSpaceLibrary/
   sync
   fusermount3 -u /tmp/mindspace-iphone-documents
   ```

   If the distro provides `fusermount` rather than `fusermount3`, use that command. Never unplug the phone before `rsync`, `sync`, and unmount complete.
6. Open MindSpace and choose **Storage → Scan Library**. The expected result is 905 files, 44 courses/levels, 275.99 hours, and about 15.81 GB.
7. Keep the original `Content` folder on Ubuntu as the master backup.

The app should play files in place from `Documents/MindSpaceLibrary`; it should not copy them a second time into Application Support. Allow at least 18–20 GB of free iPhone storage before transfer. A zip-based importer can temporarily require close to twice the library size, so it is not the primary path.

The official [`ifuse` project](https://github.com/libimobiledevice/ifuse) supports mounting the Documents directory of a file-sharing-enabled iOS app with `ifuse --documents <appid> <mountpoint>`. Keep the copy operation restartable because a 15.81 GB AFC transfer may be interrupted.

### Alternative: external drive + Files

If the iPhone has USB-C, first copy `MindSpaceLibrary` from Ubuntu to a compatible external SSD. Attach the SSD to the iPhone and use Files to copy the folder to **On My iPhone → MindSpace**. Scan it from the Storage screen. Copy the files into the app container rather than storing only an external-drive bookmark, otherwise playback will fail when the drive is disconnected.

### Alternative: split pack archives

Generate one `.mindspacepack` zip per top-level category and import with SwiftUI `fileImporter`. This enables partial libraries and transfer through a local file-sharing tool, but it is slower and needs extraction space. The importer must call `startAccessingSecurityScopedResource`, validate, then stop access. It should be resumable and never delete the source until validation succeeds.

### Data-loss rule

Refreshing or sideloading an updated IPA over the existing MindSpace installation should preserve the container when the bundle identity stays stable, and SideStore explicitly advises not to remove the original app when retaining data. Deleting MindSpace removes its shared files. Never change the bundle identifier after content is loaded. Provide **Export Progress Backup** and keep the 15.81 GB master library on Ubuntu.

## 9. Sideloading plan

### Ubuntu development and remote build

Apple's iOS SDK and SwiftUI compiler are distributed with Xcode, so Ubuntu can own the source, content tooling, tests that do not require iOS, and release automation—but it cannot produce the final iOS binary by itself using Apple's supported toolchain. Use a GitHub Actions macOS job only for compilation:

1. Keep Swift sources, assets, tests, and an XcodeGen `project.yml` in the repository. Do not commit the 15.81 GB media folder.
2. Push source to a private GitHub repository. Add `/Content`, `/MindSpaceLibrary`, generated media manifests containing local paths, and media extensions to `.gitignore` so the recordings can never be uploaded accidentally.
3. Add `.github/workflows/build-ipa.yml` with a manual `workflow_dispatch` trigger and a macOS runner. Run the workflow only for deliberate test/release builds to conserve private-repository Actions minutes.
4. On the runner, install XcodeGen, generate `MindSpace.xcodeproj`, run unit tests, and build for a generic iOS device with `CODE_SIGNING_ALLOWED=NO`.
5. Package `Release-iphoneos/MindSpace.app` inside `Payload/` and zip it as `MindSpace.ipa`.
6. Upload the IPA with `actions/upload-artifact` using a short retention period, for example 14 days. GitHub supports downloading the artifact from the Actions run or with `gh run download`.
7. Download only the small unsigned IPA to Ubuntu/iPhone. No Apple signing certificate or Apple Account secret belongs in GitHub because SideStore re-signs the IPA on-device.

A representative CI packaging sequence is:

```bash
xcodegen generate
xcodebuild \
  -project MindSpace.xcodeproj \
  -scheme MindSpace \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO
mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/MindSpace.app Payload/
zip -qry MindSpace.ipa Payload
```

The build job should also emit a SHA-256 digest and a small JSON file containing commit SHA, build number, catalog schema version, and minimum iOS version. GitHub Actions artifacts are build outputs rather than permanent releases; create a tagged GitHub Release only for versions worth retaining.

### SideStore installation and refresh

1. Use the current [SideStore Linux prerequisite flow](https://docs.sidestore.io/docs/installation/prerequisites): `usbmuxd` plus `iloader` on Ubuntu, with LocalDevVPN on the iPhone.
2. Import `MindSpace.ipa` into SideStore from the Files app and install it.
3. Use a stable ASCII-only app name and bundle ID. Avoid widgets, app extensions, App Groups, HealthKit, CloudKit, and other entitlement-heavy capabilities in v1.
4. With a free Apple Account, SideStore permits three active apps including SideStore and ten App IDs in a seven-day period. MindSpace should therefore be one app with no extensions.
5. Refresh MindSpace before its seven-day profile expires. SideStore requires LocalDevVPN plus Wi-Fi/internet for installing and refreshing; MindSpace itself does not.
6. Install updates over the existing MindSpace app. Never delete it merely to update, because the 15.81 GB Documents library would be removed.

SideStore is a good fit here because only the small IPA is refreshed weekly; the separate media library remains inside the app container. Its [FAQ documents](https://docs.sidestore.io/docs/faq) the free-account three-app limit, periodic refresh, and data-preserving update behavior. A paid Apple Developer account can extend SideStore expiry to 365 days, but is not needed to prove the app.

## 10. Build phases

Estimated solo effort: roughly 20–25 focused engineering days, or four to six calendar weeks.

### Phase 0 — content and product definition (2 days)

- confirm personal-use rights and medical wording;
- resolve/waive Pregnancy Days 27–29;
- create the manifest generator and validation report;
- freeze the four-tab information architecture and original visual tokens.

Exit: reproducible `catalog.json` for all 905 files.

### Phase 1 — app shell and library (3–4 days)

- SwiftUI project, navigation, theme, onboarding, and SwiftData container;
- catalog decode, search, filters, course/single detail, favorites;
- storage scan and missing-file states.

Exit: browse and find every catalog item in Airplane Mode.

### Phase 2 — production player (4–5 days)

- MP3/MP4 playback, scrubbing, resume, interruptions, routes;
- background audio, Lock Screen, Control Center, and mini-player;
- accurate actual-play accumulation and completion events.

Exit: two-hour locked-screen playback and interruption tests pass on a physical iPhone.

### Phase 3 — progress and Inner Orbit (4–5 days)

- course constellation, daily/weekly progress, streak engine, Compassion Pass;
- achievements, quests, completion animation, calendar, stats;
- time-zone and DST tests.

Exit: all progression is reconstructable from the event log and survives relaunch/re-sign.

### Phase 4 — Today, reminders, and import polish (3–4 days)

- time-aware local Today checklist and deterministic recommendations;
- local notifications;
- Ubuntu `ifuse`/Files import UX, validation, progress backup/restore;
- storage and privacy pages.

Exit: a new install can receive the full library over USB and be ready without internet.

### Phase 5 — accessibility, QA, and sideload release (3–5 days)

- VoiceOver, Dynamic Type, contrast, Reduce Motion, haptics;
- low-storage, corrupt-file, missing-file, app-update, and large-library tests;
- performance profiling and zero-network verification;
- Ad Hoc archive instructions and a versioned release checklist.

Exit: signed build installed on the target iPhone with all acceptance criteria passing.

## 11. Acceptance criteria

- first launch and every feature work in Airplane Mode once signing permits launch;
- app-originated network request count is zero;
- catalog reports 905 files and 275.99 hours, with the Pregnancy gap explicitly reported;
- Library search/filter is effectively instant for 905 items;
- background audio and lock-screen controls work with the phone locked;
- calls, Siri, alarms, Bluetooth route changes, and headphone removal behave safely;
- progress is credited from actual play, not seeking;
- streak calculations pass local midnight, DST, manual clock change, and travel tests;
- content remains after normal SideStore refreshes and same-bundle-ID IPA updates;
- missing/corrupt files produce a repair message and never crash the app;
- VoiceOver can complete onboarding, find a session, control playback, and read progress;
- uninstall/data-loss warning appears before library replacement or destructive storage actions.

## 12. MCP/plugin assessment

Mobbin has the most directly relevant MCP for searching complete mobile-app flows, and its public Headspace achievement screen was useful here. That MCP is not present in the installed or curated plugin list for this workspace, so it could not be added through the available approval flow.

Recommended integrations, in priority order:

1. **GitHub — essential:** create/review source changes, run the macOS IPA workflow, inspect build failures, and retrieve artifacts without leaving Ubuntu.
2. **Figma — strongly recommended for the design phase:** convert approved mockups into editable screens, components, color/type tokens, layout measurements, and developer handoff. It does not provide Headspace's private source designs.
3. **Mobbin MCP — useful but optional:** inspect complete public interaction flows and compare patterns for onboarding, audio players, progress, search, and achievements. Use it for pattern research, not pixel copying. A Mobbin account/subscription may be required, and its MCP is not in the current curated plugin list.
4. **Codex Security — optional before release:** scan the repository and GitHub workflow for exposed secrets, unsafe file handling, dependency risk, and signing mistakes. It becomes more valuable if third-party packages are ever added.

Do not add Sentry, PostHog, Supabase, Firebase-like services, or analytics connectors to the iOS target. They conflict with the zero-network product requirement and are unnecessary for a personal offline app. Local logging plus exported diagnostics is sufficient.

## 13. Recommended first implementation slice

Build one vertical slice before attempting all gamification:

1. Generate `catalog.json` for Foundation/Basics plus the Singles/Classics folder.
2. Implement Today, Library, course detail, player, and a plain completion event.
3. Build the unsigned IPA with GitHub Actions, install it through SideStore, and copy only that subset through Ubuntu `ifuse`.
4. Test background playback, resume, and a seven-day streak on the physical iPhone.
5. Once stable, load all 905 files and add the constellation/achievement layer.

This validates the two hardest risks—large offline content and iOS playback/signing—before spending time on the full visual system.
