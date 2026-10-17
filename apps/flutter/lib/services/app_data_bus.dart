import 'package:flutter/foundation.dart';

/// Domains that individual screens care about.
enum DataDomain {
  tasks,
  life,
  finance,
  today,
  timeline,
}

/// Lightweight pub/sub so mutations (assistant, forms, hubs) can tell
/// only the screens that need to refresh — not the whole HomeShell tree.
///
/// Flow:
///   UI mutation → AppDataBus.tasksChanged() / lifeChanged() / …
///   HomeShell + Insights + Activity listeners reload their slices.
///
/// Dirty consumption is centralized in HomeShell ([takeDirty] once per
/// generation). Route-return handlers should still call a scoped reload
/// so UI cannot stay stale if dirty was already consumed.
class AppDataBus extends ChangeNotifier {
  AppDataBus._();
  static final instance = AppDataBus._();

  final Set<DataDomain> _dirty = {};
  int _generation = 0;

  /// Monotonically increasing; widgets can compare to skip no-op rebuilds.
  int get generation => _generation;

  /// Domains marked dirty since the last [takeDirty] (or all if never taken).
  Set<DataDomain> get dirty => Set.unmodifiable(_dirty);

  /// Mark domains dirty and notify listeners.
  void notifyDomains(Set<DataDomain> domains) {
    if (domains.isEmpty) return;
    _dirty.addAll(domains);
    _generation++;
    notifyListeners();
  }

  /// Convenience for a single domain.
  void notifyDomain(DataDomain domain) => notifyDomains({domain});

  /// Tasks + Today + Timeline activity feed.
  void tasksChanged() =>
      notifyDomains({DataDomain.tasks, DataDomain.today, DataDomain.timeline});

  /// Life hub data + Today bits + Timeline.
  void lifeChanged() =>
      notifyDomains({DataDomain.life, DataDomain.today, DataDomain.timeline});

  void financeChanged() =>
      notifyDomains({DataDomain.finance, DataDomain.today, DataDomain.timeline});

  void allChanged() => notifyDomains(DataDomain.values.toSet());

  /// Consume dirty set (e.g. after a scoped reload).
  /// Prefer a single consumer (HomeShell) so residual sets stay meaningful.
  Set<DataDomain> takeDirty() {
    final out = Set<DataDomain>.from(_dirty);
    _dirty.clear();
    return out;
  }

  bool isDirty(DataDomain domain) => _dirty.contains(domain);
}

/// Merge pending + residual dirty after a route returns.
/// Intentionally never expands to [DataDomain.values] — empty means no reload.
@visibleForTesting
Set<DataDomain> domainsAfterRouteReturn({
  required Set<DataDomain> pending,
  required Set<DataDomain> residualDirty,
}) {
  return {...pending, ...residualDirty};
}
