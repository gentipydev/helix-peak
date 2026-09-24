import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/router/landscape_route.dart';
import 'package:helixpeek/core/theme/app_theme.dart';

/// What the app asked of the platform's chrome, in order.
final List<String> _asked = <String>[];

const String _immersive = 'setEnabledSystemUIMode SystemUiMode.immersiveSticky';
const String _bars =
    'setEnabledSystemUIOverlays [SystemUiOverlay.top, SystemUiOverlay.bottom]';
const String _landscape =
    'setPreferredOrientations [DeviceOrientation.landscapeLeft, '
    'DeviceOrientation.landscapeRight]';
const String _upright =
    'setPreferredOrientations [DeviceOrientation.portraitUp]';

/// A phone's screen, or a tablet's, upright. The view and its display are
/// set rather than a surface size, which reaches neither the display a page
/// tells a phone by nor the media query it turns by.
void _screen(WidgetTester tester, {bool phone = true}) {
  final Size upright = phone ? const Size(390, 844) : const Size(1024, 1366);
  tester.view.devicePixelRatio = 3;
  tester.view.display.size = upright * 3;
  tester.view.physicalSize = upright * 3;
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);
}

/// The screen as the platform leaves it once asked: on its side, or upright.
Future<void> _turn(WidgetTester tester, {required bool landscape}) async {
  final Size upright = tester.view.display.size;
  tester.view.physicalSize = landscape ? upright.flipped : upright;
  await tester.pumpAndSettle();
}

/// A page under which a landscape page is opened.
Future<void> _host(WidgetTester tester, {bool motion = false}) async {
  _asked.clear();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      const String chrome = 'SystemChrome.';
      if (call.method.startsWith(chrome) &&
          !call.method.contains('ApplicationSwitcher') &&
          !call.method.contains('OverlayStyle')) {
        _asked.add(
          '${call.method.substring(chrome.length)} ${call.arguments}',
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
        child: child!,
      ),
      home: const Scaffold(body: Text('list')),
    ),
  );
}

/// Opens a landscape page over the host, which closes with 'picked' from its
/// own key.
Future<String?> _open(WidgetTester tester) {
  final BuildContext context = tester.element(find.text('list'));
  return Navigator.of(context).push<String>(
    landscapeRoute<String>(
      context,
      (BuildContext context, void Function([String? result]) close) =>
          Scaffold(
            body: Column(
              children: <Widget>[
                const Text('chart'),
                TextButton(
                  key: const ValueKey<String>('close'),
                  onPressed: () => close('picked'),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
    ),
  );
}

void main() {
  testWidgets('a phone is kept upright; anything larger turns freely', (
    tester,
  ) async {
    _screen(tester);
    expect(appOrientations(tester.view.display), <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    _screen(tester, phone: false);
    expect(appOrientations(tester.view.display), isEmpty);
  });

  testWidgets('a phone turns behind a plain page, then the page appears', (
    tester,
  ) async {
    _screen(tester);
    await _host(tester);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    expect(_asked, <String>[_immersive, _landscape]);
    // The page underneath is covered, and nothing is drawn while the screen
    // turns.
    expect(find.text('list'), findsNothing);
    expect(find.text('chart'), findsNothing);
    await _turn(tester, landscape: true);
    expect(find.text('chart'), findsOneWidget);

    // Closing hands the screen back, and the page stays until the screen is
    // upright again: the page underneath is never laid out on its side.
    _asked.clear();
    await tester.tap(find.byKey(const ValueKey<String>('close')));
    await tester.pumpAndSettle();
    expect(_asked, <String>[_bars, _upright]);
    expect(find.text('chart'), findsNothing);
    expect(find.text('list'), findsNothing);
    await _turn(tester, landscape: false);
    expect(find.text('list'), findsOneWidget);
    expect(await result, 'picked');
  });

  testWidgets('Back leaves the same way', (tester) async {
    _screen(tester);
    await _host(tester);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    await _turn(tester, landscape: true);
    _asked.clear();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_asked, <String>[_bars, _upright]);
    expect(find.text('list'), findsNothing);
    await _turn(tester, landscape: false);
    expect(find.text('list'), findsOneWidget);
    expect(await result, isNull);
  });

  testWidgets('a screen that never turns shows the page all the same', (
    tester,
  ) async {
    _screen(tester);
    await _host(tester);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    expect(find.text('chart'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('chart'), findsOneWidget);
    // Still upright, so there is nothing to wait for on the way out.
    await tester.tap(find.byKey(const ValueKey<String>('close')));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(await result, 'picked');
  });

  testWidgets('a screen that never turns back lets the page go', (
    tester,
  ) async {
    _screen(tester);
    await _host(tester);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    await _turn(tester, landscape: true);
    await tester.tap(find.byKey(const ValueKey<String>('close')));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(await result, 'picked');
  });

  testWidgets('a tablet keeps its orientation, and still gets the screen', (
    tester,
  ) async {
    _screen(tester, phone: false);
    await _host(tester);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    expect(_asked, <String>[_immersive]);
    expect(find.text('chart'), findsOneWidget);
    _asked.clear();
    await tester.tap(find.byKey(const ValueKey<String>('close')));
    await tester.pumpAndSettle();
    expect(_asked, <String>[_bars]);
    expect(find.text('list'), findsOneWidget);
    expect(await result, 'picked');
  });

  testWidgets('with motion, the page fades in once the screen has turned', (
    tester,
  ) async {
    _screen(tester);
    await _host(tester, motion: true);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    expect(_asked, <String>[_immersive, _landscape]);
    tester.view.physicalSize = tester.view.display.size.flipped;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final double midway = tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('chart'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(midway, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('close')));
    await tester.pumpAndSettle();
    await _turn(tester, landscape: false);
    expect(find.text('list'), findsOneWidget);
    expect(await result, 'picked');
  });

  testWidgets('a page taken away without closing hands the screen back', (
    tester,
  ) async {
    _screen(tester);
    await _host(tester);
    final Future<String?> result = _open(tester);
    await tester.pumpAndSettle();
    await _turn(tester, landscape: true);
    _asked.clear();
    // Popped from outside, past its own way out.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(_asked, <String>[_bars, _upright]);
    expect(await result, isNull);
  });
}
