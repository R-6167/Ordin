import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/app_data_bus.dart';

void main() {
  test('domainsAfterRouteReturn never invents full-domain reload', () {
    expect(
      domainsAfterRouteReturn(pending: {}, residualDirty: {}),
      isEmpty,
    );
    expect(
      domainsAfterRouteReturn(
        pending: {DataDomain.tasks},
        residualDirty: {},
      ),
      {DataDomain.tasks},
    );
    expect(
      domainsAfterRouteReturn(
        pending: {DataDomain.tasks},
        residualDirty: {DataDomain.today},
      ),
      {DataDomain.tasks, DataDomain.today},
    );
    expect(
      domainsAfterRouteReturn(pending: {}, residualDirty: {}).length,
      lessThan(DataDomain.values.length),
    );
  });

  test('takeDirty is empty after listener consumption pattern', () {
    final bus = AppDataBus.instance;
    bus.takeDirty();
    bus.tasksChanged();
    final first = bus.takeDirty();
    expect(first, contains(DataDomain.tasks));
    expect(bus.takeDirty(), isEmpty);
  });
}
