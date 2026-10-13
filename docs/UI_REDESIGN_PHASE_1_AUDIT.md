# Ordin UI Redesign — Phase 1 Audit and Design System

Status: audit/design specification in progress  
Target app: `apps/flutter`  
Base: `main`  
Scope: visual system and interaction consistency; preserve existing domain behavior and local-first data model.

## Phase 1 goals

1. Establish a single, logo-led blue accent system for the app.
2. Inventory the highest-impact screens and reusable UI primitives before changing layouts.
3. Define interaction and accessibility rules that all redesigned screens follow.
4. Treat the persistent refresh/rebuild symptom as a parallel reliability track, not a cosmetic afterthought.
5. Make changes incrementally and validate each implementation slice with Flutter tests, analyzer, and Android release packaging.

## Source audit — current state

### Theme and visual primitives

- `lib/ui/theme.dart` currently describes and implements an amber, silver, metallic-grey, and warm-wood palette. Amber is the Material 3 seed and primary action/focus color.
- The current theme defines only `AppTheme.dark()`; `main.dart` installs it as the app theme. There is no explicit light theme or theme-mode selection in the app root.
- `lib/ui/widgets/glass.dart` applies blur, gradients, borders, shadows, and decorative color blobs globally through `GlassCard` and `GlassBackground`. This makes it a high-leverage point for the redesign, but also means a change there affects many screens at once.
- The current palette and glass treatments are tightly referenced through static constants in many screens. Keep compatibility aliases during migration rather than renaming every call site in one large patch.
- The logo is already registered as `assets/ordin_logo.png.png` in `pubspec.yaml`, and PR #80 merged the logo into the app bar and Android launcher. The blue accent should be sampled from the actual asset before the final hex value is committed; do not guess the brand color from memory.

### Navigation and dashboard

- `lib/ui/home_shell.dart` owns the top-level app shell, tab selection, initial data loading, app-data bus listener, dirty-domain queue, debounced reload, and single-flight reload handling.
- The current top-level destinations are Today, Tasks, Life, Finance, and Timeline.
- Because this shell combines navigation, data refresh coordination, and dashboard data, avoid a large visual rewrite that also restructures reload logic. Separate presentation changes from lifecycle/state changes.

### Project and task workspaces

- `lib/ui/screens/project_detail_screen.dart` is already intended as a full project workspace: overview, linked goal, progress, next action, milestones, tasks/subtasks, dependencies, schedule, notes/resources/activity, and deadline.
- Project workspace refresh behavior already preserves the last loaded workspace and avoids replacing it with a blocking loader on refresh. Retain that behavior.
- `lib/ui/screens/task_detail_screen.dart` has long-lived title and description controllers, plus editing, priority, due date, project, recurrence, and dependency state. Preserve controller identity across rebuilds and never re-seed edited text on ordinary widget updates.
- Project, goal, milestone, and task relationships should be visually explicit. Navigation should preserve the parent workspace's scroll position and refresh only after relevant data changes.

### Planning and schedule

- `planning_screen.dart` and `schedule_screen.dart` both build a day plan, show scheduled items, and allow scheduling interactions. Their app bars, loading/error patterns, spacing, and action styling should converge on shared components.
- Keep their domain behavior and drag/drop semantics unchanged during the first visual pass.

## Proposed design language

### Brand and color roles

- **Primary accent:** sampled from the supplied Ordin logo; used for primary actions, active navigation, focus rings, selected filters, links, and progress indicators.
- **Accent container:** a pale/low-opacity blue tint for selected chips, active rows, and subtle emphasis.
- **Background/surfaces:** deep navy-charcoal in dark mode; calm near-white/blue-grey surfaces if light mode is introduced later.
- **Text:** high-contrast near-white for primary text in dark mode; muted cool-grey for secondary labels.
- **Borders:** restrained cool-grey/blue, with clear focus and selected states.
- **Semantic colors:** reserve distinct success, warning, and destructive colors for status meaning; do not use the brand blue as a substitute for every status.
- Preserve dark mode as the initial supported mode. A complete light theme is a separate scoped decision, not an accidental side effect of palette refactoring.

### Component rules

- Use a consistent spacing scale based on 4/8-point increments.
- Standardize card radius, input radius, button height, icon sizing, section headers, chip padding, and dialog/bottom-sheet treatment.
- Reduce decorative blur and layered gradients where they reduce text clarity or make scrolling expensive; retain a subtle glass identity only where it improves hierarchy.
- Make selected, pressed, focused, disabled, loading, empty, error, and success states visually consistent.
- Avoid color-only meaning; pair status color with text/icon.
- Respect text scaling, keyboard insets, safe areas, touch-target sizing, and reduced-motion expectations.

## Screen redesign order

1. **Shared theme and primitives:** color roles, typography, shapes, spacing, buttons/inputs/chips, cards, section headers, dialogs, loading/empty/error states.
2. **Home shell / Today:** make today's next actions and attention items obvious; preserve current data loading and tab state.
3. **Project workspace:** project purpose and progress first, then linked goal, milestones, next action, tasks, schedule, and related resources.
4. **Task detail:** clearer task identity/status, project and milestone context, dependencies, due date, recurrence, and edit/save affordances.
5. **Planning and Schedule:** align date navigation, timeline rows, unscheduled items, drag/drop affordances, and confirmation/error feedback.
6. **Remaining screens:** Life/Finance hubs, Timeline, search, detail pages, forms, settings, and secondary panels.

## Refresh/rebuild reliability track (parallel priority)

Reported symptom: focusing/typing in an input, scrolling, tapping chips, or navigating can appear to refresh or rebuild the entire screen.

Instrumentation and test plan:
1. Reproduce one screen at a time; record whether state is lost, data reloads, scroll jumps, keyboard closes, or only a visual rebuild occurs.
2. Add temporary debug counters/logging at shell reload entry/exit and key screen init/dispose/load paths. Remove noisy instrumentation after diagnosis.
3. Audit parent `setState` boundaries, changing widget keys, route recreation, future creation in `build`, controller lifecycle, and app-data-bus notifications.
4. Distinguish normal Flutter rebuilds from destructive route/state recreation; optimize only the measured cause.
5. Add bounded, deterministic regression tests for typing/focus, chip selection, scrolling, opening/closing details, and mutation-triggered refresh. Avoid unbounded `pumpAndSettle()` for continuously animated glass UI.
6. Verify that refresh keeps controller text, focus/keyboard state where appropriate, scroll position, selected tab/filter, and last-known-good data.

Do not disable data refresh globally to hide the symptom. Data mutations must still become visible, with only affected domains reloaded.

## Acceptance criteria

- The primary accent is derived from the actual logo asset and used through semantic theme tokens, not hard-coded blue values scattered through screens.
- Existing routes, persistence, domain relationships, and interaction semantics remain unchanged in the theme/primitives slice.
- A focused widget test covers shared theme/component states, and existing test/analyzer/release packaging checks pass.
- A written before/after screen checklist exists for Today, Project, Task, Planning, and Schedule.
- Refresh investigation has a reproducible case and a regression test before broad screen redesign proceeds.
- Each implementation slice is small, reviewable, and CI-verified before the next one begins.

## First implementation slice after this audit

1. Sample the logo accent from `assets/ordin_logo.png.png`.
2. Add semantic blue tokens while keeping temporary compatibility aliases for existing references.
3. Update the shared glass background/card treatment to a restrained blue-led system.
4. Add focused theme/component tests and run the full CI pipeline.
5. Only then apply the shared language to the Today dashboard and project workspace.
