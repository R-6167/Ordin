# Personal Life OS — Implementation Roadmap

**Repository:** Ordin (R-6167/Ordin)  
**App:** Offline-first Flutter + SQLite personal life OS  
**Roadmap updated:** 2026-10-15  
**Current work:** Phase 5 — Timeline and copy/visual cleanup

This is the durable project record. A checkbox means the work is implemented in the repository; items explicitly marked CI/device pending are not considered complete until the relevant checks pass. Do not merge a phase with red CI. The persistent screen-refresh issue is deliberately reserved by the owner and must not be changed as part of the redesign phases below.

## Product direction agreed

- **Today** remains the immediate action surface.
- **Insights** replaces the old top-level Tasks destination and becomes the home for measured progress, trends, charts, and useful summaries. Task access remains available from Life and Today.
- **Life** becomes the place for goals, projects, milestones, tasks, habits, routines, notes, life areas, practical-life tools, and **Finance**.
- **Timeline** remains a chronological activity feed.
- Use compact, responsive two-column grids (three columns only when the available width supports them) for navigation/categories rather than endless stacks of navigation cards. Keep real records readable and accessible.
- Activity should be a plain chronological list, not a glass card for every event.
- Remove decorative quotation marks around in-app entity names (for example, Open Project Orion, not Open "Project Orion").
- Keep visual styling purposeful: restrained accent color, clear hierarchy, useful charts/progress indicators, and glass styling only where it adds value.
- Analytics must come from the user's actual local data. Never fabricate chart points or progress values.

## Current implementation record

### Existing stability and functional work

- [x] Flutter app uses local SQLite and an offline-first data model.
- [x] Root refresh/reload investigation documented; domain-scoped change notifications and coalesced reload work already exist.
- [x] Add flow emits domain-specific notifications instead of a blanket full refresh.
- [x] Schedule/day-plan unmodifiable-list crash was fixed.
- [x] Stable list keys were added for task/plan rows.
- [x] Life note creation uses a multiline editor; newline-to-task conversion is supported.
- [x] Expense entry validation and save feedback were added; finance refresh occurs only after successful save.
- [x] More was repurposed as Timeline; duplicate search UI was removed in favor of AppBar search.
- [x] Life hub navigation-generation guard and scoped reload work exist.
- [x] Project/task/milestone relationship and progress consistency tests exist.
- [x] Personal insights aggregation service reads owner-scoped activity history and compares recent task completion against the prior period.
- [x] Insights screen and Today summary card use local activity history; no app-usage or diagnostics telemetry is included.
- [x] Phase 2 navigation and nested Finance placement merged and passed CI (PR #100, merge commit `9e65bd1e78bd70360b3330909e55fa31d86ab5f1`; successful Flutter APK Build run [38696046237](https://github.com/R-6167/Ordin/actions/runs/38696046237)).
- [ ] Device verification remains required for several older stability items; see open work below.

### Phase 1 — Stabilize the Insights foundation

**Status: Complete; merged as part of PR #100.**

- [x] Add PersonalInsightsService to aggregate activity, task completion, habit completion, money-related events, and prior-period task completion from local owner-scoped records.
- [x] Add Insights screen and a Today summary card that opens it.
- [x] Add focused service tests and a card-navigation smoke test.
- [x] Make the card's analytics service injectable so navigation tests can use deterministic data.
- [x] Avoid pumpAndSettle on screens with perpetual indeterminate loading animations.
- [x] Validation: Flutter unit/smoke tests, analysis, release APK build and artifact upload passed in run 38696046237.

### Phase 2 — Primary navigation and Finance placement

**Status: Complete; merged as part of PR #100.**

- [x] Keep Today, Insights, Life, and Timeline as the four primary destinations.
- [x] Remove Finance from the bottom navigation and primary-title index.
- [x] Preserve the existing FinanceHub and open it from a Finance entry inside Life, with a clear Finance app bar.
- [x] Update smoke-test expectations to verify the four primary destinations and the nested Finance route.
- [x] Validation: all workflow steps passed on the final PR head, including unit/smoke tests, analysis, release APK build, and APK upload (run 38696046237).
- [x] Merge recorded: PR #100, merge commit `9e65bd1e78bd70360b3330909e55fa31d86ab5f1`.

### Phase 3 — Real analytics and progress visualization

**Status: Complete; merged in PR #101.** Merge commit `ef8ec080b9ce3793d8485b511f67d12e37244d86`; successful Flutter APK workflow run [38699081253](https://github.com/R-6167/Ordin/actions/runs/38699081253), including unit/smoke tests, analysis, release APK build and artifact upload. Artifact SHA-256: `baaa4b44573e1325dd72b28775a32163377f18a6c7207b00f1e24612044a9a0c`.

- [x] Add daily buckets for the last seven local calendar days, based on owner-scoped `activity_events`.
- [x] Show a real daily trend chart for task completions, habit completions, and money-related events; zero-activity days remain visible.
- [x] Add linked-work progress bars for goals and projects only when at least one non-archived linked task gives a meaningful denominator.
- [x] Keep counts and chart values local, owner-scoped, and separate from app-usage events and diagnostics.
- [x] Add tests for daily bucket totals, prior-period comparison, owner isolation, and goal/project progress calculations excluding archived tasks.
- [x] Flutter unit/smoke tests, static analysis, release APK build, and artifact upload passed on final PR head; PR #101 merged.
- [x] Review screen-reader chart descriptions, empty-history state, and local calendar-day bucketing; add explicit local-midnight / exclusive-end regression coverage in the Phase 4 validation branch.
- [x] Add a narrow-phone Life hub grid and semantics smoke test as part of Phase 4.
- [ ] Manual device review of chart readability and larger system text remains in release-readiness checks.

### Phase 4 — Life hub layout and discoverability

**Status: Complete; merged in PR #102.** Merge commit `a1f7622007f04a1026f8fefe48668ae7e4aa7fdf`; successful Flutter APK Build run [38703635035](https://github.com/R-6167/Ordin/actions/runs/38703635035).

- [x] Replace the long stack of navigation cards with a compact responsive two-column grid, expanding to three columns when width supports it.
- [x] Keep Finance inside Life with an accessible semantic label and a full card-sized tap target.
- [x] Keep goals, projects, habits, routines, and notes in readable record lists below the navigation grid.
- [x] Review project workspace flow: the workspace loader is owner-scoped and loads the linked goal, milestones, non-archived/non-cancelled tasks, progress totals, next action, schedule, notes, resources, and activity; existing repository/workspace contract tests cover linked relationships.
- [x] Add narrow-phone grid and semantics smoke coverage, plus explicit Insights local-day boundary regression coverage.
- [x] Run full Flutter unit/smoke tests, static analysis, and release APK build on the final Phase 4 commit.
- [x] Review CI logs and fix any failures before merge.
- [x] Add a project-detail widget regression test proving the connected goal, milestone, linked task, and progress summary are visible. Empty-project messaging is already present in the workspace sections and remains part of final visual review.
- [x] Keep the deferred screen-refresh investigation untouched.

### Phase 5 — Timeline and copy/visual cleanup

**Status: In progress on branch `feat/phase5-copy-audit-smoke`.** Plain-list slice merged in PR #103 (merge commit `32c4eafd0f1b990e76c1b4d9fc84ca94ee7f5d8b`).

- [x] Replace glass-card-per-event presentation with a plain chronological Activity list.
- [x] Preserve date grouping, timestamp/context, tap targets, and navigation to the referenced entity where supported.
- [x] Remove decorative quotation marks from activity timeline headlines (entity names no longer wrapped in quotes).
- [x] Align MoreHub activity rows with the same plain list style.
- [x] Audit remaining UI copy for unnecessary quotation marks around project/task/goal names (life-area archive dialog fixed; remaining matches are JSON metadata or intentional labels, not decorative entity quotes).
- [x] Add unit tests for activity day grouping, ordering, and formatTime; fixture headlines assert no decorative quotes.
- [x] Add widget-level Timeline empty-state smoke coverage (`activity_screen_smoke_test.dart`).
- [ ] Apply consistent spacing, restrained accents, readable hierarchy, and responsive behavior without redesigning every screen at once (light pass remaining).
- [ ] Run full Flutter unit/smoke tests, static analysis, and release APK build on this follow-up commit before merge.

### Phase 6 — Reliability, accessibility, and release readiness

- [ ] Run flutter analyze, all unit/widget tests, and release APK build for each implementation phase.
- [ ] Keep smoke coverage for primary navigation, Insights, nested Finance, import/export, bill payment, and habit completion.
- [ ] Complete device checks for Day Plan empty-state/build behavior and Finance expense visibility in Recent ledger.
- [ ] Add empty states across hubs, test large text/semantics, and check narrow-device layout.
- [ ] Replace the placeholder app icon with a real branded icon and add a short first-run onboarding tip.
- [ ] Document release signing/Play-ready keystore setup.
- [ ] Keep cloud sync, multi-device live merge, and biometrics out of scope for v1 unless explicitly reprioritized.

## Existing stability work still open

### Day Plan / Schedule
- [ ] Verify an empty day shows an empty state rather than a hard failure (device check).
- [ ] Verify Build My Day succeeds on a normal day with open tasks (device check).

### Finance
- [ ] Confirm on device that a successfully recorded expense appears in the Recent ledger.
- [ ] Add cash-flow period reconciliation UI.
- [ ] Finish subscriptions lifecycle UI polish.

### Timeline / reminders
- [ ] Add useful intelligence suggestions to Timeline without replacing the chronological feed.
- [ ] Add notification deep-linking to the referenced entity screen.

### Relationship and domain depth
- [ ] Polish milestone/task dependency UX.
- [ ] Finish recurring-task UI on task detail.
- [ ] Polish calendar ↔ tasks bidirectional behavior.
- [ ] Improve people ↔ notes ↔ projects linking.
- [ ] Add flexible/adaptive routines.
- [ ] Expand vehicle/service-record specialization.

### Ship readiness
- [ ] Ensure every CI run includes analysis, tests, and an APK artifact.
- [ ] Complete accessibility and empty-state pass.
- [ ] Verify import/export, bill payment, and habit completion end-to-end.

## Explicitly deferred / do not touch in these phases

- [ ] Persistent screen-refresh issue — owner has reserved this for separate work.
- Cloud sync/accounts.
- Multi-device live merge beyond backup/export.
- Biometrics (PIN is sufficient for v1).

## Phase completion rule

A phase is complete only when:
1. Its scope is implemented and reviewed.
2. Tests and static analysis pass on the exact phase commit.
3. The release APK workflow is green.
4. The roadmap is updated with commit/run references and any remaining device-only checks.
5. No unrelated or explicitly deferred behavior was changed.
