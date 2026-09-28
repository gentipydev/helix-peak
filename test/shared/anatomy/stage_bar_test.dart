import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/anatomy/stage_bar.dart';

Future<List<int>> _tapped(
  WidgetTester tester,
  String label, {
  bool? reselectable,
}) async {
  final List<int> selected = <int>[];
  const List<String> labels = <String>['Gene', 'mRNA', 'Protein', 'Fold'];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Scaffold(
        body: Center(
          child: reselectable == null
              ? StageBar(labels: labels, index: 1, onSelect: selected.add)
              : StageBar(
                  labels: labels,
                  index: 1,
                  reselectable: reselectable,
                  onSelect: selected.add,
                ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(ValueKey<String>('stage-$label')));
  return selected;
}

void main() {
  testWidgets('by default, the page on screen is not reported again', (
    WidgetTester tester,
  ) async {
    expect(await _tapped(tester, 'mRNA'), isEmpty);
    expect(await _tapped(tester, 'Protein'), <int>[2]);
  });

  testWidgets('reselectable, the page on screen is reported too', (
    WidgetTester tester,
  ) async {
    expect(await _tapped(tester, 'mRNA', reselectable: true), <int>[1]);
    expect(await _tapped(tester, 'Gene', reselectable: true), <int>[0]);
  });
}
