import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/router/rise_route.dart';

/// A page with a sheet up, from which a rising page opens: 'list' under the
/// sheet, 'sheet' on it, and 'risen' on the page that rises.
Future<Route<Object?>> _sheetUp(
  WidgetTester tester, {
  bool motion = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
        child: child!,
      ),
      home: const Scaffold(body: Text('list')),
    ),
  );
  final BuildContext context = tester.element(find.text('list'));
  Route<Object?>? sheet;
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        sheet = ModalRoute.of(context);
        return const SizedBox(height: 300, child: Text('sheet'));
      },
    ),
  );
  await tester.pumpAndSettle();
  return sheet!;
}

void _rise(WidgetTester tester, Route<Object?> over) {
  final BuildContext context = tester.element(find.text('sheet'));
  unawaited(
    Navigator.of(context).push<void>(
      riseRoute<void>(
        context,
        (BuildContext context) => const Scaffold(body: Text('risen')),
        over: over,
      ),
    ),
  );
}

void main() {
  testWidgets('a page rises over its sheet, then the sheet goes', (
    tester,
  ) async {
    final Route<Object?> sheet = await _sheetUp(tester);
    final Offset at = tester.getTopLeft(find.text('sheet'));
    _rise(tester, sheet);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(find.text('sheet')), at);
    expect(tester.getTopLeft(find.text('risen')).dy, inExclusiveRange(0, 844));
    await tester.pumpAndSettle();
    expect(sheet.isActive, isFalse);
    expect(find.text('sheet', skipOffstage: false), findsNothing);

    // It sinks back to what was under the sheet.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(find.text('risen')).dy, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(find.text('sheet'), findsNothing);
  });

  testWidgets('closed before it has risen, it leaves the sheet as it was', (
    tester,
  ) async {
    final Route<Object?> sheet = await _sheetUp(tester);
    _rise(tester, sheet);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(sheet.isActive, isTrue);
    expect(find.text('sheet'), findsOneWidget);
  });

  testWidgets('with motion reduced, it is simply there, and the sheet gone', (
    tester,
  ) async {
    final Route<Object?> sheet = await _sheetUp(tester, motion: false);
    _rise(tester, sheet);
    await tester.pump();
    expect(tester.getTopLeft(find.text('risen')), Offset.zero);
    await tester.pump();
    expect(sheet.isActive, isFalse);
  });
}
