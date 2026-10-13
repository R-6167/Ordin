# Personal Life OS — Remaining work

**Current:** Flutter offline client · Ordin  
**Last updated:** 2026-10-13 — W1–W5 merged; stable list keys

Keep this list ordered by **impact**. Check items off when merged to `main`.

---

## Stability waves (active)

### W1 — Refresh honesty
- [x] Root cause map: shell `setState` + over-broad `AppDataBus` notifies
- [x] FAB `+ Add` uses **domain-scoped** notify (not `allChanged`) (#62)
- [x] Finance **Record expense** refreshes only on successful save (#62)
- [x] Schedule / Day plan: fix **unmodifiable list** (`Cannot add to an unmodifiable list`) (#62)
- [x] Stable list keys on Tasks / plan rows

### W2 — Day plan / Schedule reliability
- [x] Unmodifiable list crash fixed (#62) — primary load failure
- [ ] Empty day = empty state, not hard failure (verify on device)
- [ ] Build My Day succeeds on a normal day with open tasks (verify on device)

### W3 — Notes writer path
- [x] Life / + Add note opens **note editor** (not single-line popup) (#63)
- [x] Multiline body + Enter creates real lines (#63)
- [x] Turn lines → tasks splits on newlines (#63)

### W4 — Finance expense path
- [x] Validation feedback when amount/description missing
- [x] Success/error snackbar after save
- [x] Refresh ledger only when save succeeds (cancel stays put)
- [x] Amount label uses user currency (UserPrefs)
- [ ] Device confirm: expense appears on Recent ledger

### W5 — More → Timeline
- [x] Rename/repurpose More tab as **Timeline** (#65)
- [x] Chronological activity chips (#65)
- [ ] AI / intelligence suggestions on same screen
- [x] Settings / backup only under Settings (AppBar) (#65)
- [x] Remove duplicate search field (AppBar search only) (#65)

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
