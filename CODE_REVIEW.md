# MindSpace-iOS — Final Adversarial Review (Teardown)

Date: 2026-09-16 · Scope: full repo (`Sources/`, `Tests/`, `Resources/`, `scripts/`, `project.yml`, CI, distribution metadata) · Method: line-by-line static review + cross-file contract checks. No Xcode was available in this environment, so nothing was compiled or executed; every finding below cites inspected file:line evidence. First recommended gate: `xcodegen generate` + `xcodebuild test` — it will fail today (P0-1).

## Verdict: REJECT — not shippable, but recoverable in days

The app does not compile (one missing type), downloads cannot survive backgrounding, and playback failures are silent. Beneath that there is a genuinely well-built core: Keychain-backed PAT storage, mandatory SHA-256 install verification, staged backup import, an anti-scrub listening accumulator, correct `@ModelActor` isolation, and an honest degraded-storage banner. The defects cluster in lifecycle/async-boundary seams, not in the domain logic. Fix P0-1…P0-4 and P1-1…P1-7 before any release claim; the rest can follow in priority order.

---

## P0 — Ship blockers

### P0-1. `AppTab` is referenced but never defined — app AND tests fail to build
- `Sources/MindSpace/Views/ContentView.swift:23,154` uses `AppTab` (`@State … = .today`, `ForEach(AppTab.allCases)` with `tab.iconName`, `tab.title`); `Tests/MindSpaceTests/UATComprehensiveTests.swift:19-24` asserts 4 tabs in order Today/Library/Progress/Settings. A whole-workspace search finds zero definitions. Full cross-check of every other shared symbol (`PlanetStyle`/`CelestialPlanetStyle` typealias, `CosmicCard`, modifiers, theme tokens) resolves — this is the only missing type, likely deleted and never re-committed.
- Fix: add `Sources/MindSpace/Views/AppTab.swift`:
```swift
public enum AppTab: String, CaseIterable, Identifiable {
    case today, library, progress, settings
    public var id: String { rawValue }
    public var title: String {
        switch self { case .today: "Today"; case .library: "Library"; case .progress: "Progress"; case .settings: "Settings" }
    }
    public var iconName: String {
        switch self { case .today: "sun.max.fill"; case .library: "books.vertical.fill"; case .progress: "chart.bar.fill"; case .settings: "gearshape.fill" }
    }
}
```

### P0-2. Background `URLSession` is misused — sync cannot work as designed
- `Sources/MindSpace/Services/GitHubSyncService.swift:22-27`: `URLSessionConfiguration.background(...)` with `sessionSendsLaunchEvents = true`, created via `URLSession(configuration:)` with **no delegate**. There is no `AppDelegate` / `handleEventsForBackgroundURLSession` anywhere (verified by search), `Info.plist:25-28` declares only the `audio` background mode, and downloads use `await session.download(for:)` — the async API surface, which background sessions do not support (they require delegate callbacks). `timeoutInterval = 60` is also ignored on background configs. Net effect: downloads at best die the moment the app suspends, at worst fail outright; relaunch events go nowhere.
- Fix (recommended, fits the download-once model): drop the background configuration entirely; use a foreground `URLSessionConfiguration.default` session and wrap the queue in `UIApplication.beginBackgroundTask` so in-flight files finish on home-press. Delete `sessionSendsLaunchEvents`/`waitsForConnectivity` reliance. Alternative: a real delegate-based background session + AppDelegate + `fetch` mode — far more machinery for no benefit here.

### P0-3. `playbackError` is published but observed by nothing — missing/corrupt media fails silently
- `Sources/MindSpace/AudioEngine/PlaybackEngine.swift:105,239,468,497` sets `playbackError`; a Sources-wide search shows zero readers. When a file is missing and streaming is unavailable, `startAudioPhase` sets `state = .idle` + error — but every entry point except `CourseDetailView.playSession` (`Sources/MindSpace/Views/Course/CourseDetailView.swift:522-533`, the one correct guard) still sets `isFullPlayerPresented = true`. Result: a blank fullscreen player, dead play button, zero feedback. Same silence for `.failed` items and `AVPlayerItemFailedToPlayToEndTime`.
- Fix: observe `playbackError` in `MeditationPlayerView`/`MiniPlayerView` (alert + auto-dismiss the player), and make `loadAndPlay` report success (throw or return `Bool`) so callers don't present the player on failure. Unify on the `CourseDetailView` guard pattern.

### P0-4. Probable first-launch `UserSettings` double-insert poisons the main context's saves
- `Sources/MindSpace/MindSpaceApp.swift:86-96` (`ensureInitialSettings`, direct fetch+insert+save) races `Sources/MindSpace/Views/Settings/SettingsView.swift:66-74` (`getOrCreateSettings`, driven by a **stale `@Query` snapshot**) — and SettingsView is mounted at launch because ContentView keeps all tabs alive (`ContentView.swift:46-59`). Insert → unique-constraint violation on `id` (`SwiftDataModels.swift:94`) → swallowed by `try?`, leaving a pending duplicate insert that fails **every subsequent main-context save** (favorites, settings, reflections) until restart.
- Fix: one creation site; make `getOrCreateSettings` fetch-then-insert synchronously against the context (not the `@Query` snapshot); catch the unique violation explicitly, roll back the dup, and refetch.

## P1 — Data integrity, durability, and daily-driver reliability

### P1-1. No SwiftData migration story; "recovered from backup" actually wipes the store
- `MindSpaceApp.swift:20,32` builds a plain `Schema([...])` — no `VersionedSchema`, no migration plan — while `StoreSchema.swift` carries a decorative `version = 1` (`_ = StoreSchema.version`, line 26, is dead code). Any future model change trips the 134110/134130/134140 path, which renames `default.store` aside and starts **empty**, then shows "Library recovered from backup. Verify your history in Progress." Nothing was recovered; years of history sit in an unrestorable `default.store.corrupt_*` file. For a decades-long driver this is the highest-severity longevity defect.
- Fix: adopt `VersionedSchema` + `SchemaMigrationPlan` now (v1→v1 baseline costs little); correct the banner copy; add a "keep/export before reset" path reusing the existing `.mindspace` exporter.

### P1-2. Completion→reflection race drops reflections; nil-id path can attach to the wrong event
- `onSessionCompleted` (`ContentView.swift:195-233`) persists via an async actor task (+0.5 s retry), while `CompletionView.saveReflection` (`Sources/MindSpace/Views/Completion/CompletionView.swift:289-313`) queries the event synchronously: tap a reflection (or Done/X) before the write lands → "isn't in the store yet" → reflection lost on dismiss. When `completionId == nil`, reflection attaches to `completionEvents.first` — the latest global event, potentially another session's.
- Fix: make recording awaitable before presenting completion; gate the reflection UI on the event existing (retry on `@Query` update, not on tap); remove the nil-id fallback or resolve the id at the call site.

### P1-3. "Will retry on next launch" is false — there is no outbox
- After one 0.5 s retry, failed completions/resumes surface `errorRelay` messages claiming a next-launch retry (`ContentView.swift:229`). No pending-write ledger exists in `ProgressActor` or anywhere else: the session is lost. Same single-retry-then-loss for resume positions.
- Fix: add a small persistent outbox (e.g. `PendingCompletion` entity or JSON ledger) flushed on launch/foreground/background, or at minimum replace the copy with honest "not saved — kept in this session" behavior.

### P1-4. Files-app/Share/AirDrop backup import is missing security-scoped access
- `ContentView.swift:98-108` + `BackupImportView.onAppear` (`:323-328`) call `parseBackupDocument(from:)` directly on the `onOpenURL` URL. No `startAccessingSecurityScopedResource` exists anywhere (verified by search). In-place opens will fail to read. (The in-app picker path is fine — `ProgressBackupSheet.swift:31` uses `asCopy: true`.)
- Fix: wrap the onOpenURL path in start/stopAccessing, copy to a temp file, parse the copy; surface the real error instead of `try?`.

### P1-5. Catalog is frozen at build time; the sidecar mechanism can never update it
- `CatalogService.swift:49-102` trusts `Documents/catalog.json` only if its SHA-256 equals the **bundled** hash — i.e. only if it is byte-identical to the shipped catalog. Nothing ever downloads a catalog, `schemaVersion` (`CatalogModels.swift:5`) is decoded but never checked, and content-repo renames therefore surface as 404s/hash failures with no refresh path. The "immutable offline catalog" may be intentional, but then the companion-repo sync story only covers files already in the build.
- Fix: decide explicitly. Either ship versioned catalog updates (download + verify against a pinned key/hash chain, honor `schemaVersion` with a loud mismatch error), or document the freeze and add drift detection (report catalog↔repo mismatches in the Verify UI).

### P1-6. Streaming auth likely breaks on redirect
- `LibraryPathResolver.swift:97-130` builds an `AVURLAsset` with an `Authorization` header for `raw.githubusercontent.com`, which redirects (and AVFoundation does not forward custom headers across redirects). Expect 401s on the streaming path for private repos.
- Fix: verify against a real private repo; if broken, stream via the Contents API URL form or an `AVAssetResourceLoaderDelegate` that re-applies auth per request.

### P1-7. Compassion passes are infinite — consumption is never persisted
- `compassionPassCount`/`lastUsedCompassionPassDate` are read in 4 views but **written nowhere** in production (only `ProgressActor.updateSettings`, which has zero callers, and import). `OrbitCalculator.swift:96-99` derives availability as `max(stored=0, best/7)` fresh every launch, so used passes regenerate forever; the 30-day window's `lastUsedPassDate` is permanently nil. Tests mask this by injecting counts directly (`OrbitCalculatorTests.swift:55-58`, `ProgressSimulationTests.swift:73-75`).
- Fix: persist pass consumption (decrement + stamp date when a pass protects a miss) or remove the feature and simplify the streak calc.

### P1-8. Completion UI only fires on one path; background/mini-player completions go phantom
- `MeditationPlayerView.swift:411-416` presents `CompletionView` on `hasCompletedCurrentSession` change — only if that view is mounted. Track ends on the lock screen, in background, or after MiniPlayer-X `stop()` (which finalizes at 90%+, `PlaybackEngine.swift:300-310`): event recorded, celebration/reflection never shown, and reopening the player won't retrigger (no state change).
- Fix: move completion presentation to app-level state (e.g. ContentView sheet driven by `lastCompletionInfo` with an ack flag); distinguish "finished" from "threshold-finalized on stop/switch" in the recorded event and UI.

### P1-9. Resume seek races item readiness
- `PlaybackEngine.swift:250-253` seeks with zero tolerance immediately after creating the item, before `.readyToPlay`. Pre-ready seeks can be ignored → resume silently starts at 0.
- Fix: defer the initial seek until `status == .readyToPlay` (or use a boundary/time observer), with a fallback if ready never arrives.

### P1-10. Sync engine has no per-file retry/resume and misreports progress
- `GitHubSyncService.swift:336-386`: one raw attempt + one Contents-API attempt per file, no backoff, no resume-data, full restart per file on flaky networks; `completedTracks` counts only successes, so failures stall the bar. Combined with P0-2's ignored timeouts, a 15 GB library sync over real-world Wi-Fi is fragile.
- Fix (with the P0-2 foreground session): per-file retry with backoff (3×), `URLSessionDownloadTask` resume-data across app restarts for large files, progress over attempts (not successes), and a per-file error list instead of one last-error string.

### P1-11. Distribution story undermines "daily driver for decades"
- Unsigned IPA + SideStore sideloading (`build-ipa.yml`, `apps.json`/`source.json`): free-provisioned sideloads expire (7-day refresh treadmill), refresh depends on user-maintained automation, and there is no TestFlight/App Store channel. An 8.4 MB `MindSpace.ipa` (+sha) is also committed at repo root, with more IPAs under `dist/`, and `*.ipa` is missing from `.gitignore`.
- Fix: TestFlight (free, fits <5 users, solves refresh + updates); stop committing binaries; add `*.ipa` to `.gitignore`; document the sideload-refresh procedure until TestFlight lands.

### P1-12. "Zero Network / no network access" claim contradicts the product; its test is theater
- `SettingsView.swift:716-730` claims "no … network access" while the same screen ships GitHub sync + streaming. `ZeroNetworkTests.swift` greps Sources for symbols but exempts `GitHubSyncService.swift` (the file that networks) — and CI (`build-ipa.yml:31-55`) enforces the same hollow rule.
- Fix: honest copy ("no accounts/telemetry/ads; optional sync with your own private repo + PAT"); replace the grep test with a real assertion (e.g. no third-party telemetry SDKs, sync only touches `api.github.com`/`raw.githubusercontent.com`) or delete it.

## P2 — Robustness, performance, and maintainability (fix in rough order)

**Performance in render paths.**
- `getLibraryStorageSizeBytes()` enumerates the whole library on every body evaluation (`TodayView.swift:231`, `SettingsView.swift:86-88`). Cache in `@State`, refresh on appear/sync/scan.
- `orbitStats` is recomputed 2–3× per render (`ProgressDashboardView.swift:24-37`, similar elsewhere); each run walks all events plus a 3650-iteration loop. Compute once per render.
- `LibraryView.courseRow` stats every session per row per render (`LibraryView.swift:359`); `matchesFilters(course:)` calls full `isCourseAvailable` per course (`:665`). Memoize availability into a view-model keyed by sync state.
- Backup import inserts up to 100k rows on `@MainActor` (`ProgressTransferManager.swift:133-270`) — minutes of UI hang. Batch on a background context with progress + cancellation.

**Data fidelity (course/content attribution).**
- `courseId` stores the course display **name**, not a stable id, at every call site (`PlayableTrack.courseName` → `recordCompletion courseId:`). Catalog renames silently fork history; `nextCourseSession` (`CompletionView.swift:53-75`) matches by name and breaks. Migrate to stable ids.
- `TodayView` journey_3 hardcodes `courseName: "Sleep & Rest"` and `durationLabel: "10 min"` (`TodayView.swift:513-531`); Library search results set `courseName: nil` (`LibraryView.swift:480-495`); resume rebuild infers `contentType` from name substrings and drops `dayNumber`/`videoAttachmentPath` (`TodayView.swift:321-340`). `PlaybackResume` should store `contentType`, `dayNumber`, and video path so resume is lossless.

**Correctness nits with user-visible effects.**
- Streak loop cap `checkedCount < 3650` (`OrbitCalculator.swift:143`) truncates current streaks at ~10 years while `bestStreak` is uncapped — inconsistent, and the brief says decades. Raise/remove and note the bound.
- Rescan races reload: `rescanAndVerifyLibrary` calls `loadCatalog()` (async) then immediately verifies against the stale `manifest` (`SettingsView.swift:926-954`). Await the reload first.
- `CompletionView.nextCourseSession` hasGapWaiver/else branches are byte-identical (`CompletionView.swift:60-71`) — the "Day 26 → Day 30 waiver" comment describes behavior the code doesn't implement (it only works because days 27–29 are absent from the catalog). Collapse or implement.
- Defaults `CompletionView.init` (`:28-40`) contain realistic fake data ("Basics — Day 4"); require real parameters at call sites or mark preview-only.
- `Toggle favorite` (`MeditationPlayerView.swift:490-503`), settings toggles, and export (`SettingsView.swift:889-902`) swallow failures via `try?` with no user signal. Surface at least a toast/banner.
- MiniPlayer nests Buttons inside a Button (`MiniPlayerView.swift:27-94`) — the X tap can also open the fullscreen player. Restructure (row tap gesture + explicit buttons with high-priority gestures).
- `MediaFilter.audio` is a no-op (`LibraryView.swift:687-699` only excludes on `.video`); "N sessions available" counts filter matches, not on-disk files (`:419`); courseRow badge (sessions-only, `:359`) disagrees with `isCourseAvailable` (sessions+videos). Align all three on one definition.
- Progress calendar icon navigates to `SettingsView()` (`ProgressDashboardView.swift:69-77`) — mislabeled navigation.
- Settings tab-root "Back" button calls a no-op `dismiss()` (`SettingsView.swift:97-114`).
- Interruption end without `.shouldResume` leaves `state == .interrupted` forever (`AudioSessionManager.swift:87-93` + `PlaybackEngine.swift:565-579`); no `mediaServicesWereReset` recovery in the engine. Reset to `.paused` and rebuild the player on reset.
- Status observer sets `.playing` on `.readyToPlay` even if the user paused meanwhile (`PlaybackEngine.swift:457-475`). Track an explicit want-to-play flag.
- Now-playing: `UIImage(named: "AppIcon")` always returns nil (app icons aren't image assets) so artwork is always the SF fallback (`NowPlayingCoordinator.swift:129`); `unregisterRemoteCommands` never calls `endReceivingRemoteControlEvents`.
- Sleep timer pauses abruptly with no fade (`PlaybackEngine.swift:353-376`); minute granularity only.
- `ListeningAccumulator.tick` (`ListeningAccumulator.swift:49-68`) drops legitimate listening when main-thread stalls exceed ~2.5 s, and catalog-vs-asset duration drift silently makes tracks unqualifiable. Clamp against actual asset duration when known.
- `handleReminderToggle` spawns uncancellable `Task`s (`SettingsView.swift:836-874`); `NotificationScheduler.scheduleDailyReminder` (`NotificationScheduler.swift:20-44`) doesn't validate hour/minute ranges. Debounce; validate.
- `parseBackupDocument` has no size cap (multi-hundred-MB file → memory spike); `backupVersion <= 0` passes validation; merge import overwrites `selectedGoals` with stale non-empty lists (`ProgressTransferManager.swift:259-261`); achievements export fabricates `unlockedAt: now` (`:60-65`); `appVersion` default `"2.1.0"` (`UserDataTransfer.swift:19`) disagrees with 2.4.0.
- `Bundle.main.url(forResource:relativePath…)` with slash paths never matches (`LibraryPathResolver.swift:87`) — the bundle fallback is dead code; document-directory fallback to `temporaryDirectory` (`:52-55`) risks OS purge. Size-check silently passes on unreadable attributes (`:347-352`); `readData(ofLength:)` is deprecated — use `read(upToCount:)`.
- `verifyAndMoveFile` is `throws -> Bool` but returns `false` for hash mismatch instead of throwing (`GitHubSyncService.swift:466-500`) — callers can't distinguish "bad hash" from "I/O error" for the error list (see P1-10).
- `cancelSync` sets `isSyncing = false` synchronously while the detached task is still unwinding (`:502-508`); starting a new sync in that window is silently ignored (`guard !isSyncing`, also `:124,163,219,272,300`). Serialize via the task handle + user feedback.
- Hardcoded branch `"main"` (`GitHubSyncService.swift:401`, `LibraryPathResolver.swift:106`), hardcoded size strings ("15.81 GB", "275.99 hrs", "~300 MB", "15 GB", "8 Pack categories…"), and duplicated `github_sync_repo`/`github_sync_pat` key strings (constants live only in `GitHubSyncService`, retyped in `LibraryPathResolver`). Centralize; derive copy from the manifest.
- `CatalogService.loadError` doubles as the sidecar warning channel (`CatalogService.swift:39`) — warnings render as errors. Separate `loadWarning`.
- `DocumentPickerView` allows `[.json, .data]` instead of the exported `com.mindspace.backup` UTType (`ProgressBackupSheet.swift:31`) — shows unrelated files.
- `FullScreenVideoPlayerViewController.entersFullScreenWhenPlaybackBegins = true` inside an already-fullscreen cover (`VideoPlayerView.swift:106`) — double-fullscreen/rotation risk.
- `PersistenceErrorRelay.report` re-hops to MainActor at one call site that already wrapped it (`ContentView.swift:198-200`) — harmless; simplify.

**Dead / misleading code to delete.**
- `_ = StoreSchema.version` (`MindSpaceApp.swift:26`); `ProgressActor.updateSettings` (zero callers); `lastUsedCompassionPassDate` writes (none) — see P1-7; `pendingImportDocument` (written, never read, `SettingsView.swift:20`); `lastSavedResumePosition` write-only outside the 10 s check (fine, but note); `deinit` comment-only (`PlaybackEngine.swift:135-137`).

**Tests & CI.**
- `UATComprehensiveTests` fails to compile for the same P0-1 reason; several suites assert on hand-built fixtures that bypass production paths (pass counts, catalog trust). Add: migration v1→v2 round-trip, outbox flush, background-completion surfacing, security-scoped import, sync retry/resume, seek-after-ready, and a no-duplicate-settings launch test.
- CI (`build-ipa.yml`): pin `xcodegen` version; inject plist values **before** test+build so tests run against shipped bits; drop the grep-theater gate (P1-12) or make it meaningful; un-hardcode `2026-08-21`; avoid `gh release delete`+recreate (mutates published history); split test (PR gate) from release (tag gate) instead of manual-dispatch-only.

**Long-term notes.**
- Media lives in `Documents/` with `UIFileSharingEnabled` — users *can* corrupt the library from Files (detectable via Verify/Audit; acceptable for <5 trusted users, but document it). If sideloading via Files isn't needed, `Application Support` is safer.
- Only `print()` logging exists (`MindSpaceApp.swift:57`, `AudioSessionManager.swift:37,51`); no diagnostics export. For a decades-long driver, add a log ring + "Export diagnostics" next to the backup exporter.
- `SWIFT_STRICT_CONCURRENCY: complete` is set (good) — keep it green; the `@unchecked Sendable` sites (`PersistenceErrorRelay`, `DateFormatterCache` w/ NSLock, `HapticService`) are justified but should carry one-line rationale comments.

## What's genuinely good (keep)
Keychain (`…ThisDeviceOnly`, update-then-add) for the PAT; mandatory hash-before-install with safe-path gating; constant-memory streaming SHA-256; staged backup validation before touching live data; `@ModelActor` writes off-main with single-save transactions; range-union anti-scrub accumulator with speed-aware crediting; library hardening (backup exclusion + `completeUntilFirstUserAuthentication`); honest in-memory-degraded banner; deterministic, well-tested streak/backup/vault math for the pure functions.

## Suggested fix order
1. P0-1 (AppTab) → get CI green. 2. P0-2+P1-10 (foreground sync + retry/resume). 3. P0-3 (surface playback errors). 4. P0-4 (settings creation). 5. P1-1 (migrations) + P1-3 (outbox) + P1-2 (reflection race). 6. P1-4…P1-8. 7. P1-9…P1-12 + P2 sweep. 8. Re-run full suite + a real-device pass (background/lock screen, airplane mode, revoked PAT, corrupt file, 15 GB audit) before release.

## Fix Log (Batch 1 → Run 1 — P0s; CI runs consumed: 5/6 — see red-run repairs below)
| ID | Fix summary | Test(s) | Commit SHA |
|----|-------------|---------|------------|
| P0-1 | Added `Sources/MindSpace/Views/AppTab.swift` (`today/library/progress/settings` with `title` + `iconName` per review spec). Also fixed a latent build blocker found in the baseline red run: `CatalogService.loadCatalogData` returned `Result<…, String>` (`String` does not conform to `Error`) — introduced typed `CatalogLoadError` (`.notFound` / `.decodeFailed`) with identical user-facing copy via `.message`. | `P0RemediationTests.testP0_1_AppTabHasFourTabsInOrder`; existing `UATComprehensiveTests` AppTab assertions now compile | `d4b1569` |
| P0-2 | Replaced `URLSessionConfiguration.background` (no delegate, async `download(for:)` unsupported, `sessionSendsLaunchEvents` with no AppDelegate) with `URLSessionConfiguration.default` foreground session + `UIApplication.beginBackgroundTask(withName:"MindSpaceSync")` wrapping the download queue (expiry handler cancels sync; task always ended). Honest 60 s request / 1 h resource timeouts. | `P0RemediationTests.testP0_2_UsesForegroundSessionConfiguration` (structural pin); behavior verified by existing sync tests on CI | `d4b1569` |
| P0-3 | `loadAndPlay`/`startAudioPhase` now `@discardableResult -> Bool` (`false` + `playbackError` when media unavailable); added `clearPlaybackError()`; `MeditationPlayerView` presents a `playbackError` alert that auto-dismisses the fullscreen player; all 10 `loadAndPlay` call sites (Today/Library/Course/Completion) only set `isFullPlayerPresented = true` on success. | `P0RemediationTests.testP0_3_LoadAndPlayReturnsFalseForMissingMedia` + `testP0_3_LoadAndPlayReturnsTrueForLocalFile`; existing `testAttemptToPlayMissingFileProducesActionableErrorAndNoPlayingState` still passes | `d4b1569` |
| P0-4 | One creation site: new `SettingsStore.fetchOrCreate(in:)` (fetch-then-insert against the context, save, rollback + refetch on unique-violation race). `MindSpaceApp.ensureInitialSettings`, `SettingsView.getOrCreateSettings`, `MindfulReminderSheet.getOrCreateSettings`, and `OnboardingView.completeOnboarding` all route through it; removed the now-unused `@Query` snapshot in OnboardingView. `ProgressActor`/`ProgressTransferManager` already fetch-then-insert and were left as-is. | `P0RemediationTests.testP0_4_FetchOrCreateNeverDuplicatesSettings` + `testP0_4_ConcurrentSettingsCreationYieldsSingleRow` (no-duplicate-settings incl. save-poisoning check) | `d4b1569` |

### Red-run repairs (reserve runs; all green in Run 4)
| Run | Failure | Fix | Commit SHA |
|-----|---------|-----|------------|
| Run 1 `35049944542` | `TodayView.swift:136` — `NSCalendarDayChanged` is macOS-only (was masked behind the P0-1 compile failure) | iOS `UIApplication.significantTimeChangeNotification` for the midnight-rollover rebuild | `f68bb95` |
| Run 2 `35050129349` | 2 latent test failures newly surfaced (never ran on CI before — all prior runs died at compile): `testP2_02` asserted hardening on a never-hardened dir; headphone test asserted `.playing` synchronously for a dummy file that can never become ready | Test-only: apply-then-assert hardening with sim/device split; drive `.playing` via `play()` before the disconnect callback | `6fe40a7` |
| Run 3 `35050577269` | `applyHardeningAndProtection()` returns false on simulator (NSFileProtection step can't stick without the iOS kernel) | Sim branch sets + reads back only the backup-exclusion xattr; device keeps full apply + check | `232f106` |
| Run 4 `35050974912` | **SUCCESS** — full gate green (tests + unsigned build + IPA package) | — | `232f106` |
