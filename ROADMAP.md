# Personal Life OS — Implementation Roadmap

**Repository:** Ordin (R-6167/Ordin)  
**App:** Offline-first Flutter + SQLite personal life OS  
**Roadmap updated:** 2026-10-17  
**Current work:** Goal → Project → Task relationship linking on create

This is the durable project record. A checkbox means the work is implemented in the repository; items explicitly marked CI/device pending are not considered complete until the relevant checks pass. Do not merge a phase with red CI. Screen-refresh is being tracked across screens separately.

## Product direction agreed

- **Today** remains the immediate action surface.
- **Insights** is measured progress; **Life** is areas-first; **Timeline** is activity.
- Analytics must come from the user's actual local data.

## Relationships (issue #10)

- [x] Schema + validator: goal / project / milestone / task graph.
- [x] Goal detail → add project with `goalId`; Project detail → add task with project/goal/milestone.
- [x] Global create: project optional **Goal**; task optional **Project** (inherits goal).
- [ ] Task detail: show/edit full chain (goal/project/milestone) in UI.
- [ ] Orphan / integrity polish on device.

## Post–Phase 6 and life areas (done)

- [x] Areas-first Life; habits/notes/routines linked; soft assign on create.
- [x] Planning single Build My Day CTA; finance card/expense polish; notif soft-catch.

## Existing stability work still open

### Day Plan / Schedule (device)
- [ ] Verify empty day empty state; Build My Day with open tasks.

### Finance (device + polish)
- [ ] Expense appears in Recent ledger on device.
- [ ] Cash-flow period reconciliation UI.
- [ ] Subscriptions lifecycle UI polish.

### Refresh
- [ ] Track and fix remaining stale screens (in progress).

## Phase completion rule

Mark items complete only when code is on main and CI is green. Device-only checks stay unchecked until verified on a build.
