# Personal Life OS — Remaining work

**Current:** Flutter offline client · Ordin  
**Last updated:** 2026-10-13 — Stability waves (refresh / Schedule / notes / Timeline)

Keep this list ordered by **impact**. Check items off when merged to `main`.

---

## Stability waves (active)

### W1 — Refresh honesty
- [x] Root cause map: shell `setState` + over-broad `AppDataBus` notifies
- [ ] FAB `+ Add` uses **domain-scoped** notify (not `allChanged`)
- [ ] Finance **Record expense** refreshes only on successful save
- [ ] Schedule / Day plan: fix **unmodifiable list** (`Cannot add to an unmodifiable list`)
- [ ] Stable list keys on Tasks rows (follow-up if flash remains)

### W2 — Day plan / Schedule reliability
- [ ] Empty day = empty state, not hard failure
- [ ] Surface real engine errors cleanly
- [ ] Build My Day succeeds on a normal day with open tasks

### W3 — Notes writer path
- [ ] Life / + Add note opens **note editor** (not single-line popup)
- [ ] Multiline body + Enter creates real lines
- [ ] Turn lines → tasks respects paragraphs / bullets

### W4 — Finance expense path
- [ ] Record expense saves and shows on ledger
- [ ] Confirmation snackbar; no refresh on cancel

### W5 — More → Timeline
- [ ] Rename/repurpose More tab as **Timeline**
- [ ] Chronological activity (tasks, expenses, notes, habits, …)
- [ ] AI / intelligence suggestions on same screen
- [ ] Settings / backup only under Settings (AppBar)
- [ ] Remove duplicate search field (AppBar search only)

### Phase 7 (scoped refresh) — engineering done, verify on device
- [x] Debounce + stable tab keys (#57)
- [x] Narrower domain reloads (#58)
- [x] Sonar tools cleanup (#59)
- [x] Schedule nav generation gate + note cursor (#60)
- [x] Life hub nav generation gate (#61)
- [ ] Device sign-off after W1–W2

---

## Highest impact (active)

- [ ] Green APK every time (`flutter analyze` clean + release build)
- [ ] Milestone + task dependency UX polish
- [ ] Real branded app icon
- [ ] Short first-run onboarding tip
- [ ] Smoke tests: import/export, pay bill, complete habit

## Product depth

- [ ] Recurring tasks **UI** (picker on task detail)
- [ ] Calendar ↔ tasks bidirectional polish
- [ ] Cash-flow period reconciliation UI
- [ ] Subscriptions full **UI** lifecycle polish
- [ ] People ↔ notes ↔ projects linking UX
- [ ] Flexible / adaptive routines
- [ ] Vehicle / service records specialization
- [ ] Reminder deep-link from notification tap → entity screen

## Ship readiness

- [ ] CI pipeline (analyze + test + APK artifact)
- [ ] Release signing / Play-ready keystore docs
- [ ] Accessibility pass (semantics, large text)
- [ ] Empty states on every hub screen

## Explicitly out of scope (for now)

- Cloud sync / accounts
- Multi-device live merge (beyond backup file)
- Biometrics (PIN is enough for v1)
