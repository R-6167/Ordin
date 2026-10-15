# Personal Life OS — Implementation Roadmap

**Repository:** Ordin (R-6167/Ordin)  
**App:** Offline-first Flutter + SQLite personal life OS  
**Roadmap updated:** 2026-10-15  
**Working branch:** feat/personal-insights-home-timeline

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
- [x] An Insights screen and Today summary card were added, with widget/service tests.
- [x] The Insights navigation test uses injected deterministic data rather than depending on platform-backed startup services.
- [ ] Device verification remains required for several older stability items; see open work below.

### Phase 1 — Stabilize the Insights foundation

**Status:** Implemented on the feature branch; the owner reported the build green before Phase 2.

- [x] Add PersonalInsightsService to aggregate activity, task completion, habit completion, money-related events, and prior-period task completion from local owner-scoped records.
- [x] Add Insights screen and a Today summary card that opens it.
- [x] Add focused service tests and a card-navigation smoke test.
- [x] Make the card's analytics service injectable so navigation tests can use deterministic data.
- [x] Avoid pumpAndSettle on screens with perpetual indeterminate loading animations.
- [ ] Phase acceptance: rerun CI against the final Phase 2 commit; do not infer green from an earlier commit.

### Phase 2 — Primary navigation and Finance placement

**Status:** Implementation committed to the feature branch; CI pending.

- [x] Keep Today, Insights, Life, and Timeline as the four primary destinations.
- [x] Remove Finance from the bottom navigation and primary-title index.
- [x] Preserve the existing FinanceHub and open it from a Finance entry inside Life, with a clear Finance app bar.
- [x] Update smoke-test expectations to verify the four primary destinations and the nested Finance route.
- [ ] Run full Flutter analyze/unit/widget tests and release APK workflow on the exact final commit.
- [ ] Review the run logs for failures; fix the cause and rerun before calling the phase green.
- [ ] Merge only after required checks pass and the owner approves the merge.

### Phase 3 — Real analytics and progress visualization

- [ ] Expand analytics beyond headline counts into trustworthy time-series aggregates from SQLite.
- [ ] Add daily/weekly completion chart(s) with clearly defined date ranges and empty states.
- [ ] Add real progress bars for goals/projects/habits only where a defensible target/denominator exists.
- [ ] Add period comparison and explain what each metric measures.
- [ ] Handle no history, partial history, zero denominators, and timezone/date boundaries safely.
- [ ] Add repository/service tests for chart buckets and aggregation edge cases.
- [ ] Verify charts use real data only and remain legible at narrow phone widths and large text settings.

### Phase 4 — Life hub layout and discoverability

- [ ] Replace long navigation-card stacks with a responsive compact grid for major Life areas and tools.
- [ ] Keep Finance within Life and ensure it remains reachable with accessible labels and large tap targets.
- [ ] Keep actual records (goals, projects, habits, routines, notes) in readable lists/cards where useful; grids are primarily for navigation/categories.
- [ ] Check project pages expose connected goals, milestones, tasks, progress, and relevant activity.
- [ ] Check task/project/milestone/goal linking and empty states through UI-level flows.
- [ ] Avoid unrelated data refreshes or changes to the deferred screen-refresh behavior.

### Phase 5 — Timeline and copy/visual cleanup

- [ ] Replace glass-card-per-event presentation with a plain chronological Activity list.
- [ ] Preserve date grouping, timestamp/context, tap targets, and navigation to the referenced entity where supported.
- [ ] Audit UI copy for unnecessary quotation marks around project/task/goal names.
- [ ] Apply consistent spacing, restrained accents, readable hierarchy, and responsive behavior without redesigning every screen at once.
- [ ] Add widget tests for activity ordering, empty state, and entity navigation.

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
