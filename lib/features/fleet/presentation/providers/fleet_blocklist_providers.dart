import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/fleet_blocklist_local_datasource.dart';

final fleetBlocklistLocalProvider = Provider(
  (ref) => FleetBlocklistLocalDataSource(),
);

/// Bikes bloqueadas (id → nome): aparecem na lista, mas a operação pula.
final fleetBlocklistProvider =
    NotifierProvider<FleetBlocklist, Map<String, String>>(FleetBlocklist.new);

class FleetBlocklist extends Notifier<Map<String, String>> {
  FleetBlocklistLocalDataSource get _local =>
      ref.read(fleetBlocklistLocalProvider);

  @override
  Map<String, String> build() => _local.load();

  bool contains(String id) => state.containsKey(id);

  Future<void> block(String id, String name) async {
    state = {...state, id: name};
    await _local.add(id, name);
  }

  Future<void> unblock(String id) async {
    state = {...state}..remove(id);
    await _local.remove(id);
  }

  Future<void> toggle(String id, String name) =>
      contains(id) ? unblock(id) : block(id, name);
}
