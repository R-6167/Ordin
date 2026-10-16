# Personal Life OS — Implementation Roadmap

**Repository:** Ordin (R-6167/Ordin)  
**App:** Offline-first Flutter + SQLite personal life OS  
**Roadmap updated:** 2026-10-16  
**Current work:** Life areas-first navigation (Life tab)

This is the durable project record. A checkbox means the work is implemented in the repository; items explicitly marked CI/device pending are not considered complete until the relevant checks pass. Do not merge a phase with red CI. The persistent screen-refresh issue is deliberately reserved by the owner and must not be changed as part of the redesign phases below.

## Product direction agreed

- **Today** remains the immediate action surface.
- **Insights** replaces the old top-level Tasks destination and becomes the home for measured progress, trends, charts, and useful summaries. Task access remains available from Life and Today.
- **Life** is **areas-first**: the Life tab maps life domains; goals/projects/tasks open under an area. Tools (finance, schedule, practical life, …) stay as a secondary strip. Habits/routines/notes remain creatable via Add until linked to areas in a later slice.
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
- [x] More was repurposed as tools/suggestions, not a second activity dump.

### Phase 1 — Stabilize the Insights foundation
- [x] Insights tab exists and loads personal progress from local activity.

### Phase 2 — Primary navigation and Finance placement
- [x] Bottom nav: Today · Insights · Life · Timeline.
- [x] Finance reachable from Life.

### Phase 3 — Real analytics and progress visualization
- [x] Insights charts and linked-work progress from local data.

### Phase 4 — Life hub layout and discoverability
- [x] Life hub navigation and empty states.

### Phase 5 — Timeline and copy/visual cleanup
- [x] Plain activity list; headline resolution; hierarchy polish.

### Phase 6 — Reliability, accessibility, and release readiness
- [x] Empty states, text scale clamp, release notes / signing notes as applicable.

## Post–Phase 6 polish

- [x] Notification deep-linking for task/project/goal/habit/routine (PR #111).
- [x] Timeline intelligence suggestions from local data (overdue, due today, open bills, pending habits) — does not replace the chronological feed.
- [x] Related links section: ROUTINE open, EmptyState, hierarchy accents.
- [x] Life tab **areas-first**: domain cards primary; global goals/projects/habits/routines/notes lists removed from Life home; tools strip secondary; unassigned goals/projects called out.

## Existing stability work still open

### Day Plan / Schedule (device)
- [ ] Verify an empty day shows an empty state rather than a hard failure.
- [ ] Verify Build My Day succeeds on a normal day with open tasks.

### Finance (device + polish)
- [ ] Confirm on device that a successfully recorded expense appears in the Recent ledger.
- [ ] Add cash-flow period reconciliation UI.
- [ ] Finish subscriptions lifecycle UI polish.

### Timeline / reminders
- [ ] Soften remaining notification plugin PlatformExceptions where possible.

### Life areas (next)
- [ ] Link habits / routines / notes to life areas (schema + UI).
- [ ] Soft prompt to assign area on create for goals/projects.
- [ ] Area detail: richer empty states and quick-add into that area.

## Phase completion rule

Mark items complete only when code is on main and CI is green. Device-only checks stay unchecked until verified on a build.
