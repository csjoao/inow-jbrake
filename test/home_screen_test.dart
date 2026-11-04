import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inow_jbrake/features/bike/data/datasources/bike_local_datasource.dart';
import 'package:inow_jbrake/features/bike/presentation/providers/bike_providers.dart';
import 'package:inow_jbrake/features/bike/presentation/screens/home_screen.dart';

class _OneSavedBike extends BikeLocalDataSource {
  ({String id, String name})? saved = (id: 'AA:BB', name: 'Minha INOW');

  @override
  ({String id, String name})? get lastBike => saved;

  @override
  Future<void> forgetLastBike() async => saved = null;
}

void main() {
  Future<_OneSavedBike> open(WidgetTester t) async {
    final local = _OneSavedBike();
    await t.pumpWidget(
      ProviderScope(
        overrides: [bikeLocalProvider.overrideWithValue(local)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('Minha INOW'), findsOneWidget);
    await t.tap(find.byTooltip('Excluir veículo'));
    await t.pumpAndSettle();
    expect(find.text('Excluir veículo?'), findsOneWidget);
    return local;
  }

  testWidgets('excluir veículo pede confirmação e apaga', (t) async {
    final local = await open(t);
    await t.tap(find.text('Excluir'));
    await t.pumpAndSettle();

    expect(local.saved, isNull);
    expect(find.text('Minha INOW'), findsNothing);
    expect(find.text('Adicionar'), findsOneWidget);
  });

  testWidgets('cancelar mantém o veículo', (t) async {
    final local = await open(t);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();

    expect(local.saved, isNotNull);
    expect(find.text('Minha INOW'), findsOneWidget);
  });
}
