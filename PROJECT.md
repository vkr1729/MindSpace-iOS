# MindSpace iOS refinement

## Outcome

MindSpace is a private, offline-capable meditation app. This refinement makes the current practice, Continue action, course progress, and playback controls easier to understand without changing the content, persistence model, playback engine, download behavior, or private GitHub configuration.

The release is for personal use on an iPhone 16 running iOS 26 or later. It remains compatible with the existing installed v2.4.0 data and keeps the current bundle identifier. This document is longer than the normal project blueprint because the requested redesign also requires a visual audit, design comparison, simulator UAT plan, release evidence, and migration note.

## Scope

- Current module: redesign and prove Today → course/session → player → completion → updated progress.
- Later modules: onboarding, Library, remaining progress views, Settings, deterministic UI-test fixtures, simulator UAT, and unsigned IPA publication.
- Not included: accounts, analytics, telemetry, subscriptions, a backend, content-management changes, social features, new meditation content, or physical-device automation.

## Architecture and why

The simplest suitable architecture keeps the existing SwiftUI screens, services, SwiftData models, audio engine, and catalog models. A small `MindSpaceTheme` supplies semantic colors, spacing, shapes, materials, buttons, cards, and category accents. Screens compose those primitives directly. No new navigation framework, coordinator, image pipeline, or view-model layer is needed.

Input flows from the bundled catalog or authenticated private GitHub content into the existing catalog and playback services. SwiftUI renders that state. Playback callbacks send completion and resume updates through `ProgressActor` into SwiftData. Keychain storage remains the only home for the PAT. Export and import continue through the existing transfer manager and document interfaces.

The main tradeoff is restraint: an image-free interface has less immediate visual variety than an imagery-led one, but it gives MindSpace clearer hierarchy, smaller assets, fewer contrast and crop failures, better Dynamic Type behavior, and longer visual life. The rejected alternative is a category-specific photography library with multiple aspect ratios. It would add asset direction, crop QA, download size, and ongoing mapping work without improving the core meditation journey.

## Repository safety and baseline

- Baseline HEAD: `60acf62` on `main`, tracking `origin/main`.
- User-owned changes preserved: modified `scripts/send_email.py`; untracked `artifacts/` containing Shortcuts and plists.
- Canonical remote remains `https://github.com/vkr1729/MindSpace-iOS.git`.
- No secondary remote existed at audit time. The intended private mirror `vkreddy1729-ops/MindSpace-iOS-UAT` also did not exist.
- Active GitHub identity was `vkr1729`; `vkreddy1729-ops` was available in the keyring but inactive.
- This host is Linux and has no Xcode, Swift toolchain, or iOS simulator. Local static checks are possible; compiled tests, screenshot capture, and IPA construction must run on the secondary account's macOS workflow.
- The latest historical primary-account run passed unit/simulator tests at `ea152c8`, before the manual-only workflow commit. It is baseline evidence only and will not be used as the redesign release gate.
- `scripts/verify_codebase.py` passed its seven legacy checks. Its planet-alpha check is obsolete and must become a no-celestial-asset invariant.
- The root `MindSpace.ipa` is stale: its payload reports v2.0.0 build 7 while the source of truth is v2.4.0 build 11. Its adjacent hash file does not match it. Neither artifact is release evidence.

## UI audit

| Area | Evidence | Change |
| --- | --- | --- |
| Literal celestial identity | Nine planet PNGs total 3,382,731 bytes; `CelestialPlanetView` is used on seven major surfaces | Delete the assets, view, enum, mappings, processing scripts, and obsolete tests |
| Decorative motion | Twinkling star field and looping floating/breathing planet effects | Remove looping decorative animation; retain only state communication and an optional non-literal breathing cue |
| Course differentiation | Unrelated content maps through repeated `PlanetStyle` cases and fallback planets | Use semantic accent, SF Symbol, title, metadata, availability, and progress |
| Progress clarity | Course sessions are drawn as a serpentine constellation and streak is presented as an Orbit | Use a linear accessible session list, plain practice-streak language, and unchanged progress calculations |
| Typography | 287 fixed-size `.font(.system(size:))` calls | Prefer Dynamic Type text styles and `@ScaledMetric` only for bounded visual measurements |
| Touch targets | Repeated 42×42 controls and compact icon-only actions | Give every interactive control a minimum 44×44 content shape and a meaningful label |
| Accessibility semantics | Only 14 explicit accessibility modifiers across the app | Combine card content intentionally, hide decorative shapes, label status and controls once, and expose progress values |
| Reduce Motion | Only three views currently read Reduce Motion | Centralize transition behavior and eliminate infinite animation where motion conveys no state |
| Navigation | Custom tab bar and direct destination links duplicate native behavior | Keep the four-tab information architecture but use native tab/navigation behavior where it preserves mini-player layout |
| Dense settings | Storage, verification, credentials, reminders, privacy, and transfer controls share one long custom surface | Group with native section hierarchy and progressive disclosure while preserving every destination |
| Persistence risk | `MindSpaceApp` deletes the SwiftData store after a generic container-open failure | Never erase an installed store automatically; fail safely and preserve recoverable data |
| Release workflow | Current job combines tests, build, and direct publication and targets old runner/Xcode fallbacks | Make UAT/build secondary-only and publication a separate, explicitly controlled primary-credential step |

User-facing celestial terms will be removed: “Orbit” becomes “practice streak,” “Constellation Journey” becomes “course progress,” and celestial achievement names become plain milestones. Internal calculation types and stored IDs may retain old names when that avoids migration risk.

## Five-direction exploration

All directions use the same representative content and information architecture: onboarding, Today/Daily Journey, Library, course detail, full player and mini-player, completion, progress, and Settings/content configuration. Each board includes first-launch, offline, downloading, unavailable, completed, and configuration-error states.

Rendered boards:

- [Quiet Native](design-exploration/rendered/quiet.png)
- [Editorial Calm](design-exploration/rendered/editorial.png)
- [Nature Environments](design-exploration/rendered/nature.png)
- [Light, Water & Mist](design-exploration/rendered/abstract.png)
- [Restrained Cosmic](design-exploration/rendered/cosmic.png)

The source is [mindspace-directions.html](design-exploration/mindspace-directions.html). Exploration photographs are remote visual references, not approved production assets.

### Comparison matrix

Scores are 1–5, where 5 is strongest.

| Direction | Calmness | Navigation | Hierarchy | Accessibility | Longevity | iOS 26 fit | Simplicity | Consistency | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Quiet Native | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **40** |
| Editorial Calm | 5 | 4 | 5 | 4 | 4 | 4 | 4 | 4 | **34** |
| Nature Environments | 5 | 4 | 4 | 3 | 3 | 4 | 2 | 3 | **28** |
| Light, Water & Mist | 4 | 4 | 4 | 3 | 3 | 4 | 2 | 3 | **27** |
| Restrained Cosmic | 4 | 4 | 4 | 3 | 2 | 3 | 2 | 3 | **25** |

### Selected direction: Quiet Native

Quiet Native wins decisively. It makes Continue and playback unmistakable, avoids crop and contrast debt, supports Dynamic Type with the fewest exceptions, removes 3.38 MB of obsolete planet assets, and feels at home on modern iOS without turning material effects into decoration. Editorial Calm is a useful influence for generous typography, but a custom serif would add a second typographic system and reduce consistency across dense functional screens.

## Selected implementation reference

### Color

- Background: near-black neutral green, approximately `#090D0C`.
- Primary surface: `#111715`; elevated surface: `#18201D`.
- Primary text: `#F2F7F4`; secondary text: `#96A49E`.
- Primary action: quiet mint `#8BCAB7`; text on action: `#07110D`.
- Completion/success uses the same mint with a checkmark or text, never color alone.
- Warning uses a muted warm amber; destructive/error uses a softened red with explicit icon and copy.
- Category accents stay restrained and semantic. They may tint a symbol, progress fill, or selected state, never a large decorative object.

### Typography

- Use native SwiftUI text styles: `.largeTitle`, `.title2`, `.headline`, `.body`, `.subheadline`, `.caption`.
- Use rounded design only for compact time/progress metrics when it improves legibility. Body and navigation copy use the default system design.
- Permit multiline titles and descriptions. Avoid fixed frames around text. Apply `minimumScaleFactor` only to short numeric readouts, never body copy.

### Spacing and shape

- Base spacing scale: 4, 8, 12, 16, 20, 24, and 32 points.
- Minimum interactive target: 44×44 points with at least 8 points between adjacent targets.
- Control radius: 14; card radius: 18; emphasized surface radius: 24. Use capsules only for filters, compact status, and primary controls whose label remains legible.
- Cards separate meaningful groups. Do not wrap every row in an independent decorative container.

### Materials and depth

- Opaque surfaces are the default for low-light contrast and predictable screenshots.
- Native material may appear behind the bottom bar, mini-player, sheets, and transient overlays when content remains readable without relying on blur.
- Use one-pixel low-contrast separators and minimal shadow. No glow, star field, ornamental aura, or empty-space decoration.

### Icons and component states

- Use SF Symbols with native roles. Icon-only controls require a spoken label.
- A course row contains title, session count, progress, availability, and an optional semantic symbol. The symbol is supportive, not a hero image.
- Availability states are explicit: Downloaded, Downloading with progress and Cancel, Stream available, Offline unavailable, and configuration error with recovery guidance.
- The primary button has normal, pressed, disabled, and loading states. Pressed state uses small opacity/scale feedback only when Reduce Motion is off.
- Progress uses value plus text; completion uses a checkmark and plain confirmation that mindful time was recorded. Duplicate protection remains behavioral rather than test-oriented user-facing copy.

### Motion and accessibility

- Use short 150–250 ms state transitions. No continuous twinkle, floating, orbiting, or breathing decoration.
- When Reduce Motion is enabled, replace spatial transitions with an immediate or brief opacity change.
- Decorative gradients and shapes are accessibility-hidden and ignore hit testing.
- Cards combine their children only when they represent one action. Nested buttons remain separate VoiceOver elements.
- Dynamic Type through Accessibility XXXL must preserve the main action, permit vertical growth, and keep critical screens scrollable.
- Support bold text, increased contrast, VoiceOver, portrait, and supported landscape layouts. Never encode completion, availability, or errors by color alone.

## File map

| Path | What it contains | Why it exists / connects to |
| --- | --- | --- |
| `PROJECT.md` | Outcome, audit, selected design system, implementation map, UAT and release evidence | One maintained explanation and release record |
| `design-exploration/mindspace-directions.html` | Comparable visual prototypes using identical content | Makes selection about visual language rather than product differences |
| `design-exploration/rendered/*.png` | Five inspected 2048×2250 boards containing 393×852 screens | Records the visual baseline before SwiftUI changes |
| `Sources/MindSpace/DesignSystem/MindSpaceTheme.swift` | Semantic tokens and small reusable components | Replaces the celestial visual system without introducing architecture layers |
| Existing `Views/` files | Screen composition and user interaction | Preserve current behavior while adopting the selected primitives |
| Existing models/services/audio engine | Catalog, storage, playback, progress, Keychain, notifications, transfer | Remain the behavioral source of truth |
| `Tests/MindSpaceUITests/` | Deterministic end-to-end journeys and adaptive-layout checks | Exercises real simulator UI without private content or secrets |

## Implementation

1. Replace celestial theme/components in the complete Today → course → player → completion → progress journey, retain the existing data path, and verify the three core behaviors: Continue is reachable, playback controls work, and completion updates progress once.
2. Apply the same primitives to onboarding, Library, Settings, mini-player, empty/error/download states, and plain-language milestones. Remove obsolete assets and tests.
3. Add the UI-test target and deterministic launch fixtures, run secondary-account simulator UAT, fix failures, then build and inspect the unsigned IPA.

## Proof checks

1. Primary journey: UI test first launch → Today → Continue → player → completion → updated progress.
2. Material boundary: unit/UI tests prove duplicate completion does not inflate progress and persistence survives relaunch.
3. Privacy and packaging: static scan plus IPA inspection proves the expected bundle/version, no planet assets, and no PAT/token/private content.

Exact secondary workflow commands and run URLs will be recorded after the mirror exists.

## UAT plan

- Environment: an Xcode/iOS 26-capable macOS runner and an iPhone 16 simulator; portrait plus supported landscape; standard text and Accessibility XXXL; Reduce Motion on/off.
- First launch: onboarding controls, disclaimer, Today load, visible recommendation/Continue, mini-player clearance, and large-text reachability.
- Library: course/single browsing, search, filters, course navigation, session launch, downloaded/downloading/stream/unavailable/offline fixtures, and recovery messages.
- Playback: full/mini transitions, play/pause, skip/seek, speed, timer, minimize, resume, relaunch state, and completion callback. Lock-screen/Now Playing logic remains unit-tested; physical presentation is device-only.
- Completion/progress: qualifying completion recorded once, duplicate ID rejected, course/day/streak/heatmap update, and SwiftData persistence after relaunch.
- Settings/portability: every destination reachable, PAT field never echoed, Keychain-only storage checks, export/import round-trip, reminder UI, and device-only Files picker note.
- Accessibility: labels and roles, no duplicate decorative elements, 44-point targets, Accessibility XXXL, portrait/landscape, contrast, Reduce Motion, truncation, safe areas, and tab/mini-player overlap.
- Privacy/regression: networking remains confined to authenticated content sync/streaming, no telemetry, existing download/stream/offline/notification/progress/playback tests pass, and build artifacts contain no credential or private content strings.

## Final UAT result

Pending implementation and the secondary macOS workflow. This section will record the tested commit, environment, workflow URL, tests, screenshots, defects/fixes/reruns, remaining device-only checks, final IPA path/size/hash, and release URL. The app is not release-ready while this section is pending.

## Migration and release note

Planned next version: v3.0.0 build 12, subject to confirming build 12 does not already exist in the public distribution repository at release time. This is an additive release: the existing v2.4.0 release, tag, IPA, and metadata entry remain available and will not be deleted, replaced, or retagged.

MindSpace v3.0 refreshes the interface with a quiet, image-free design. It removes planet artwork and celestial progress language while preserving the existing catalog, downloaded media, playback behavior, favorites, reminders, private GitHub configuration, backups, and stored progress. No account, analytics, telemetry, or backend has been added. Existing identifiers and data models remain compatible so the installed v2.4.0 store can open without destructive migration.

## Run and limitations

Open the generated Xcode project, select an iPhone 16 simulator on iOS 26, and run the `MindSpace` scheme. The current Linux host cannot perform that step. SideStore installation, LiveContainer behavior, notification delivery, haptics, lock-screen presentation, and subjective touch comfort require the user's physical device after the simulator release gate passes.
