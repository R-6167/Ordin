# Personal Life OS — Implementation Roadmap

**Repository:** Ordin (R-6167/Ordin)  
**App:** Offline-first Flutter + SQLite personal life OS  
**Roadmap updated:** 2026-10-16  
**Current work:** Device hardening (notifications, day plan, finance)

This is the durable project record. A checkbox means the work is implemented in the repository; items explicitly marked CI/device pending are not considered complete until the relevant checks pass. Do not merge a phase with red CI. The persistent screen-refresh issue is deliberately reserved by the owner and must not be changed as part of the redesign phases below.

## Product direction agreed

- **Today** remains the immediate action surface.
- **Insights** replaces the old top-level Tasks destination and becomes the home for measured progress, trends, charts, and useful summaries. Task access remains available from Life and Today.
- **Life** is **areas-first**: the Life tab maps life domains; goals/projects/tasks/habits/routines/notes open under an area. Tools (finance, schedule, practical life, …) stay as a secondary strip.
- **Timeline** remains a chronological activity feed.
- Analytics must come from the user's actual local data. Never fabricate chart points or progress values.

## Post–Phase 6 and life areas

- [x] Areas-first Life tab; area detail quick-add; habits/notes/routines linked (schema v31).
- [x] Soft assign area on create (goal/project/task/habit/routine).
- [x] Single Build My Day CTA on planning screen (duplicate card buttons removed).
- [x] Finance money cards enlarged; Record expense try/catch + snackbar feedback.
- [x] Expense form soft-loads accounts/categories so the dialog still opens.
- [x] Soften notification plugin failures (cancelAll/cancelId + budget alert path recorded, not fatal).

## Existing stability work still open

### Day Plan / Schedule (device)
- [ ] Verify an empty day shows an empty state rather than a hard failure.
- [ ] Verify Build My Day succeeds on a normal day with open tasks.

### Finance (device + polish)
- [ ] Confirm on device that a successfully recorded expense appears in the Recent ledger.
- [ ] Add cash-flow period reconciliation UI.
- [ ] Finish subscriptions lifecycle UI polish.

## Phase completion rule

Mark items complete only when code is on main and CI is green. Device-only checks stay unchecked until verified on a build.
