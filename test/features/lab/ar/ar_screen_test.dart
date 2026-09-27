import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/ar/domain/room_scale.dart';
import 'package:helixpeek/features/lab/ar/presentation/ar_screen.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

const String _usdz =
    'https://example.supabase.co/storage/v1/object/public/models/'
    'structure_ar/insulin.96ade3392dd3.usdz';

/// A `structure_ar` row as the backend's upload writes it.
Map<String, dynamic> _roomRow({String state = 'ready'}) => <String, dynamic>{
  'state': state,
  'url': state == 'ready' ? _usdz : null,
  'format': 'usdz',
  'provenance': <String, dynamic>{
    'pdb': '3I40',
    'bbox_angstrom': <double>[24.31, 18.66, 20.33],
    'scale': '1 A = 1 cm',
    'glb': <String, dynamic>{
      'path': 'structure_ar/insulin.89a577f9258e.glb',
      'sha256': '89a577f9258e',
      'bytes': 593008,
    },
  },
};

/// Insulin from the catalog fixture, with or without a room-size model.
ProteinTarget _insulin({Map<String, dynamic>? room}) {
  final Map<String, dynamic> catalog = jsonDecode(
    File('test/fixtures/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final Map<String, dynamic> row = Map<String, dynamic>.of(
    (catalog['proteins'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> p) => p['slug'] == 'insulin'),
  );
  row['tracks'] = <String, dynamic>{
    ...?(row['tracks'] as Map<String, dynamic>?),
    'structure_ar': ?room,
  };
  return ProteinTarget.fromJson(row);
}

void main() {
  group('RoomScale', () {
    test('reads the size and the .glb beside the USDZ', () {
      final RoomScale scale = RoomScale.of(
        _insulin(room: _roomRow()).tracks[TrackKind.structureAr],
      )!;
      expect(scale.box, <double>[24.31, 18.66, 20.33]);
      expect(scale.longestAngstroms, 24.31);
      expect(
        scale.glb.toString(),
        'https://example.supabase.co/storage/v1/object/public/models/'
        'structure_ar/insulin.89a577f9258e.glb',
      );
    });

    test('opens Scene Viewer on it, at its own size, AR where it can be', () {
      final Uri viewer = RoomScale.of(
        _insulin(room: _roomRow()).tracks[TrackKind.structureAr],
      )!.sceneViewer(title: 'Insulin');
      expect(viewer.host, 'arvr.google.com');
      expect(viewer.path, '/scene-viewer/1.2');
      expect(viewer.queryParameters, <String, String>{
        'file':
            'https://example.supabase.co/storage/v1/object/public/models/'
            'structure_ar/insulin.89a577f9258e.glb',
        'mode': 'ar_preferred',
        'resizable': 'false',
        'title': 'Insulin',
      });
    });

    test('is nothing without a ready row that says what it needs', () {
      expect(RoomScale.of(null), isNull);
      expect(
        RoomScale.of(
          _insulin(room: _roomRow(state: 'pending'))
              .tracks[TrackKind.structureAr],
        ),
        isNull,
      );
      final Map<String, dynamic> noGlb = _roomRow();
      (noGlb['provenance'] as Map<String, dynamic>).remove('glb');
      expect(
        RoomScale.of(_insulin(room: noGlb).tracks[TrackKind.structureAr]),
        isNull,
      );
    });
  });

  group('ArScreen', () {
    Future<List<Uri>> host(
      WidgetTester tester, {
      required ProteinTarget target,
      required TargetPlatform platform,
      bool opens = true,
    }) async {
      final List<Uri> opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          home: ArScreen(
            target: target,
            platform: platform,
            open: (Uri uri) async {
              opened.add(uri);
              return opens;
            },
          ),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('on Android: the fold, its size, and the room', (
      WidgetTester tester,
    ) async {
      final List<Uri> opened = await host(
        tester,
        target: _insulin(room: _roomRow()),
        platform: TargetPlatform.android,
      );
      expect(find.byType(StructureView), findsOneWidget);
      expect(
        find.text('Drawn at 1 Å to 1 cm, Insulin is 24.3 cm across.'),
        findsOneWidget,
      );
      await tester.tap(find.text('View in your room'));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(opened.single.queryParameters['mode'], 'ar_preferred');
    });

    testWidgets('says so when Scene Viewer does not open', (
      WidgetTester tester,
    ) async {
      await host(
        tester,
        target: _insulin(room: _roomRow()),
        platform: TargetPlatform.android,
        opens: false,
      );
      await tester.tap(find.text('View in your room'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Scene Viewer did not open'), findsOneWidget);
    });

    testWidgets('on iOS: the fold and its size, and a line, not a button', (
      WidgetTester tester,
    ) async {
      await host(
        tester,
        target: _insulin(room: _roomRow()),
        platform: TargetPlatform.iOS,
      );
      expect(find.byType(StructureView), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('room-scale')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('works on Android'), findsOneWidget);
    });

    testWidgets('with no room-size model yet: the fold, and why not', (
      WidgetTester tester,
    ) async {
      await host(tester, target: _insulin(), platform: TargetPlatform.android);
      expect(find.byType(StructureView), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('room-scale')), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(
        find.text('The room-size model of Insulin is not published yet.'),
        findsOneWidget,
      );
    });
  });
}
