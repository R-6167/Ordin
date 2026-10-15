# Personal Life OS — Implementation Roadmap

**Repository:** Ordin (R-6167/Ordin)  
**App:** Offline-first Flutter + SQLite personal life OS  
**Roadmap updated:** 2026-10-15  
**Current work:** Post–Phase 6 polish and device verification

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
- [x] Phase 2 navigation and nested Finance placement merged and passed CI (PR #100).
- [ ] Device verification remains required for several older stability items; see open work below.

### Phase 1 — Stabilize the Insights foundation

**Status: Complete; merged as part of PR #100.**

### Phase 2 — Primary navigation and Finance placement

**Status: Complete; merged as part of PR #100.**

### Phase 3 — Real analytics and progress visualization

**Status: Complete; merged in PR #101.**

### Phase 4 — Life hub layout and discoverability

**Status: Complete; merged in PR #102.**

### Phase 5 — Timeline and copy/visual cleanup

**Status: Complete.** Merged across PR #103–#105.

### Phase 6 — Reliability, accessibility, and release readiness

**Status: Complete** for implementable in-repo scope (PR #106–#108 + Life EmptyState + habit detail EmptyState). Device-only verification and domain-depth polish remain open below.

- [x] Run flutter analyze, unit/widget tests, and release APK via CI on each implementation PR.
- [x] Smoke coverage retained for primary navigation, Insights, nested Finance, and related flows (extend as regressions appear).
- [ ] Complete device checks for Day Plan empty-state/build behavior and Finance expense visibility in Recent ledger.
- [x] Shared `EmptyState` widget + tests; `SectionHeader` silverMuted (PR #108).
- [x] Life hub empty lists (goals, projects, habits, routines, notes) use `EmptyState`.
- [x] Habit detail empty recent history uses `EmptyState`.
- [x] First-run onboarding tip (Welcome dialog after unlock) — PR #107.
- [x] Branded launcher icon (`@drawable/ic_launcher_ordin` → `ordin_logo`).
- [x] Document release signing/Play-ready keystore setup (`docs/RELEASE_SIGNING.md`) — PR #106.
- [x] Cloud sync, multi-device live merge, and biometrics remain out of scope for v1.

## Existing stability work still open

### Day Plan / Schedule (device)
- [ ] Verify an empty day shows an empty state rather than a hard failure.
- [ ] Verify Build My Day succeeds on a normal day with open tasks.

### Finance (device + polish)
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
- [ ] Manual accessibility pass (large text, TalkBack) on a physical device.
- [ ] Verify import/export, bill payment, and habit completion end-to-end on device.

## Explicitly deferred / do not touch in these phases

- [ ] Persistent screen-refresh issue — owner has reserved this for separate work (see open PR #88 for investigation traces only).
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
