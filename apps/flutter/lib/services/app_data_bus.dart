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
///   Repository write → AppDataBus.notify({DataDomain.tasks})
///   Tasks tab / Today tab listeners rebuild only their slice.
///
/// Dirty consumption is centralized in HomeShell ([takeDirty] once per
/// generation). Route-return handlers must not invent a full-domain reload
/// when the residual set is empty — use [domainsAfterRouteReturn].
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
    if (kDebugMode) {
      debugPrint('[RefreshTrace] AppDataBus notify generation=$_generation '
          'domains=${domains.map((d) => d.name).join(',')} '
          'dirty=${_dirty.map((d) => d.name).join(',')}');
    }
    notifyListeners();
  }

  /// Convenience for a single domain.
  void notifyDomain(DataDomain domain) => notifyDomains({domain});

  /// Tasks + Today summary (open/overdue/plan). Does not dirty life/timeline.
  void tasksChanged() => notifyDomains({DataDomain.tasks, DataDomain.today});

  /// Life hub data + Today bits that surface life items.
  void lifeChanged() => notifyDomains({DataDomain.life, DataDomain.today});

  void financeChanged() =>
      notifyDomains({DataDomain.finance, DataDomain.today});

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
