# Handover Prompt — Fix MindSpace-iOS & Prove the Build on GitHub

Paste everything below the line to the fixing model (it needs the repo + `CODE_REVIEW.md` at root; it runs on **Ubuntu Linux x86_64** with an authenticated `gh` CLI — no macOS, no Xcode).

---

You are taking over the MindSpace-iOS repo. A full adversarial teardown exists at `CODE_REVIEW.md` in the repo root (verdict: REJECT — 4 P0s, 12 P1s, plus a P2 sweep, with file:line evidence and a suggested fix order). Your job: fix everything and prove the build + tests are green via GitHub Actions CI.

## Environment (read carefully)
- You are on **Ubuntu 26.04 LTS (x86_64)**. You **cannot** run `xcodebuild`, the iOS Simulator, or Swift compilation — do not attempt local Apple builds.
- `xcodegen` is known-broken on this host (compatibility issues on Ubuntu 26.04) — never install, troubleshoot, or work around it. Project generation is owned exclusively by CI (`macos-14` runs `xcodegen generate` on every run).
- All compilation, unit tests, and IPA packaging run on GitHub Actions (`macos-14`) via `.github/workflows/build-ipa.yml`, which runs `xcodegen generate` itself. All `project.yml` target sources use directory globs (`Sources/MindSpace/`, `Resources/`, `Tests/MindSpaceTests/`), so adding or editing Swift files never requires generating an `.xcodeproj`.
- You have an authenticated `gh` CLI with full `repo` and `workflow` permissions. CI is your compiler and test runner.

## Minute budget — macOS bills at 10x (hard constraint)
- Each CI run costs ~15–30 macOS minutes = **150–300 billed minutes**. You have a hard budget of **6 CI runs total**. Per-change verification is forbidden — batch strictly per the plan below.
- The workflow is already optimized for cost (`concurrency/cancel-in-progress`, conditional XcodeGen install, 60-min timeout, no redundant `clean`, fail-fast test-before-build). **Do NOT weaken any gate to get green**: no deleting/skipping tests, no skipping build/package steps, no lowering `SWIFT_STRICT_CONCURRENCY`, no editing the workflow except to fix a genuine breakage (report such edits explicitly).
- Never dispatch twice for the same commit. Check `gh run list --branch <branch>` before dispatching; always `gh run watch` the in-flight run to its verdict before pushing more, unless you are intentionally superseding it (cancel-in-progress kills the stale run — use this instead of letting two runs burn in parallel).

## Batch plan (1 run per batch)
- **Run 0 — Baseline (no code changes):** create branch `fix/code-review-remediation`, push as-is, dispatch CI. Expected: red (P0-1, missing `AppTab`). Purpose: prove the dispatch/watch/log loop works before you change anything.
- **Batch 1 → Run 1 — P0s:** P0-1 (AppTab) + P0-2 (foreground sync session) + P0-3 (surface playback errors) + P0-4 (settings creation race). Regression tests for each.
- **Batch 2 → Run 2 — P1 completion/data pipeline:** P1-1 (migrations) + P1-2 (reflection race) + P1-3 (outbox) + P1-4 (security-scoped import) + P1-8 (completion surfacing). Grouped because they share the completion/persistence seam.
- **Batch 3 → Run 3 — P1 sync/catalog/reliability:** P1-5 (catalog strategy) + P1-6 (streaming auth) + P1-7 (pass consumption) + P1-9 (seek-after-ready) + P1-10 (sync retry/resume) + P1-11 (stop committing IPAs, `.gitignore`) + P1-12 (honest telemetry copy + real test).
- **Batch 4 → Run 4 — P2 sweep:** render-path perf, attribution fidelity, nits, dead-code removal, CI/test hardening from the review. Expect green.
- **Runs 5–6 — Reserve:** red-run repairs only (see protocol). If you are green after Run 4, do not spend these.

## What to do (within each batch)
1. Fix root causes, smallest correct change per finding; keep strict-concurrency clean (CI treats build issues as failures).
2. For every P0 and P1, add/extend a regression test in `Tests/MindSpaceTests/` that fails before the fix and passes after (missing coverage is listed in the review: migration round-trip, outbox flush, background-completion surfacing, security-scoped import, sync retry/resume, seek-after-ready, no-duplicate-settings launch).
3. Do NOT commit binaries (`.ipa`, `.sha256`, build products). Keep `project.yml`, `Info.plist`, `apps.json`/`source.json` consistent via Tier 1.
4. Append to the Fix Log table at the bottom of `CODE_REVIEW.md` per finding: ID → fix summary → test(s) → commit SHA.

## Verification — 2-tier hierarchy (required)

### Tier 1: Local pre-flight on Ubuntu (before every push — this is your only free check, be thorough)
- `python3 scripts/sync_version.py --sync-all` — version consistency; commit the result if it changes files.
- Replicate CI's zero-telemetry grep scan locally on `Sources/` (same forbidden patterns and `URLSession`-outside-`GitHubSyncService` check as the workflow — if a review fix legitimately relocates networking, update workflow + test together).
- ext4 is case-sensitive: verify every filename, import path, and resource reference matches on-disk casing exactly.
- Self-review the full diff of the batch for Swift syntax/type errors before pushing — you cannot compile locally, so read every hunk twice. One careless typo costs a 10x run.

### Tier 2: Remote GitHub Actions gate (the real compiler)
- Push the batch to `fix/code-review-remediation`, then:
  ```bash
  gh workflow run "Build MindSpace Unsigned IPA & Automated Release" --ref fix/code-review-remediation
  gh run watch
  gh run view --log-failed
  ```
- **Red-run protocol (spends reserve runs):** diagnose from `--log-failed` only (Swift errors and XCTest failures pinpoint file:line — attribute the failure to a specific fix in the batch); fix on Ubuntu; Tier-1 pre-flight; push; re-dispatch. One dispatch per repair push, no speculative re-runs.
- **Release safety:** the workflow's public-distribution step is gated behind `github.ref == 'refs/heads/main'` — building on your fix branch only produces unsigned IPA artifacts and can never trigger a live public release. Do NOT push to or open a PR against `main` without explicit approval.

## Done criteria
- Every P0/P1/P2 in `CODE_REVIEW.md` is either fixed with a cited test, or explicitly deferred with a written reason I must approve.
- A fully green workflow run on the fix branch (paste the run URL) — the only accepted build proof. Report total runs consumed vs the 6-run budget.
- Fix Log complete in `CODE_REVIEW.md`.
- Final reply: short summary of what changed per severity, the green CI run URL, test counts, confirmation the public release step was correctly skipped (branch ≠ main), and anything unverifiable without Apple hardware (e.g. real-device smoke pass — list as residual risk, don't claim it).
