from pathlib import Path
import sys

path = Path('apps/flutter/lib/ui/home_shell.dart')
hs = path.read_text()

old_onbus = '''  void _onBus() {
    final gen = AppDataBus.instance.generation;
    if (gen == _busGen) return;
    _busGen = gen;
    final dirty = AppDataBus.instance.takeDirty();
    if (dirty.isEmpty) return;
    _pendingDomains.addAll(dirty);
    _scheduleReload();
  }'''

new_onbus = '''  /// Single place that moves bus dirty → pending (never discard without queueing).
  void _consumeDirtyFromBus() {
    final gen = AppDataBus.instance.generation;
    if (gen != _busGen) {
      _busGen = gen;
    }
    final dirty = AppDataBus.instance.takeDirty();
    if (dirty.isEmpty) return;
    _pendingDomains.addAll(dirty);
    _scheduleReload();
  }

  void _onBus() => _consumeDirtyFromBus();'''

old_asst = '''  Future<void> _openAssistant() async {
    final generationBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
    if (!mounted) return;
    if (AppDataBus.instance.generation == generationBefore) return;
    final dirty = AppDataBus.instance.takeDirty();
    final domains = dirty.isEmpty
        ? {DataDomain.tasks, DataDomain.life, DataDomain.finance, DataDomain.today}
        : dirty;
    await _reload(domains: domains);
  }'''

new_asst = '''  Future<void> _openAssistant() async {
    final generationBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
    if (!mounted) return;
    if (AppDataBus.instance.generation == generationBefore) return;
    // The bus listener may already have consumed dirty domains into
    // [_pendingDomains] while the assistant route was open. Never invent a
    // full-domain reload when the residual dirty set is empty.
    _consumeDirtyFromBus();
    if (_pendingDomains.isNotEmpty) {
      _scheduleReload();
    }
    if (_reloadInFlight != null) {
      await _reloadInFlight;
    }
  }'''

if old_onbus not in hs:
    if '_consumeDirtyFromBus' in hs:
        print('onBus already')
    else:
        sys.exit('onBus missing')
else:
    hs = hs.replace(old_onbus, new_onbus, 1)
    print('onBus ok')

if old_asst not in hs:
    if 'Never invent a' in hs:
        print('assistant already')
    else:
        sys.exit('assistant missing')
else:
    hs = hs.replace(old_asst, new_asst, 1)
    print('assistant ok')

path.write_text(hs)
