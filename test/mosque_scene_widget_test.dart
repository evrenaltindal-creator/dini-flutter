import 'package:dini_flutter/features/home/domain/mosque_scene_state.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MosqueSceneState _scene(MosqueScenePeriod period) => MosqueSceneState(
  period: period,
  sunProgress: .62,
  moonVisibility: period == MosqueScenePeriod.ishaNight ? .9 : 0,
  starVisibility: period == MosqueScenePeriod.ishaNight ? 1 : 0,
  skyProgress: .5,
  mosqueLightingLevel: .4,
  foregroundBrightness: .8,
  friday: false,
  ramadan: false,
);

void main() {
  const cases = {
    MosqueScenePeriod.fajr: 'assets/scenes/mosque_dawn.png',
    MosqueScenePeriod.dhuhr: 'assets/scenes/mosque_day.png',
    MosqueScenePeriod.asr: 'assets/scenes/mosque_asr.png',
    MosqueScenePeriod.ishaNight: 'assets/scenes/mosque_night.png',
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key.name} doğru sinematik sahneyi kullanır', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MosqueScene(state: _scene(entry.key), height: 600),
          ),
        ),
      );

      expect(find.byKey(ValueKey(entry.value)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
