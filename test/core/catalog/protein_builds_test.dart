import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/network/api_exception.dart';

import '../../features/search/support/resolver_api.dart';

/// [ProteinBuilds], the app's one list of builds, on [ResolverApi] answering
/// as the backend's `/proteins/resolve` does, in fake time.

const Duration _tick = Duration(seconds: 3);

const ProteinSuggestion _brca1 = ProteinSuggestion(
  uniprot: 'P38398',
  gene: 'BRCA1',
  name: 'Breast cancer type 1 susceptibility protein',
  display: null,
  length: 1863,
  slug: 'brca1',
  status: SuggestionStatus.buildable,
  reason: null,
);

Map<String, dynamic> _said(
  String state, {
  String? slug,
  String? reason,
  Map<String, dynamic>? build,
}) => <String, dynamic>{'slug': slug, 'state': state, 'reason': reason, 'build': build};

Map<String, dynamic> _report(
  String step,
  double elapsed, {
  int? ahead,
  int? scored,
  int? residues,
  double? left,
  String? reason,
}) => <String, dynamic>{
  'step': step, 'ahead': ahead, 'scored': scored, 'residues': residues,
  'left': left, 'elapsed': elapsed, 'transcript': null, 'reason': reason,
};

void main() {
  group('a report', () {
    test('reads every field the service sends', () {
      final ResolveStatus status = ResolveStatus.fromJson(_said('ready', slug: 'oca2',
          build: <String, dynamic>{
            ..._report('scoring', 331.5, scored: 450, residues: 838, left: 245.25),
            'transcript': 'NM_000275.3',
          }));
      final BuildReport report = status.build!;
      expect(report.step, BuildStep.scoring);
      expect(report.elapsed, const Duration(milliseconds: 331500));
      expect(report.left, const Duration(milliseconds: 245250));
      expect((report.scored, report.residues, report.transcript), (450, 838, 'NM_000275.3'));
      expect(report.fraction, closeTo(450 / 838, 1e-12));
      expect(report.ahead, isNull);
    });

    test('a step this build does not know, or none at all, is no report', () {
      expect(ResolveStatus.fromJson(_said('pending', build: _report('teleporting', 1))).build,
          isNull);
      expect(ResolveStatus.fromJson(<String, dynamic>{'state': 'pending'}).build, isNull);
      expect(ResolveStatus.fromJson(_said('pending', build: _report('queued', 0))).build!.fraction,
          isNull);
    });

    test('a suggestion says whether it is building, and an older service says nothing', () {
      final Map<String, dynamic> row = <String, dynamic>{
        'uniprot': 'P61769', 'gene': 'B2M', 'name': 'Beta-2-microglobulin',
        'display': null, 'length': 119, 'slug': 'b2m', 'status': 'ready', 'reason': null,
      };
      expect(ProteinSuggestion.fromJson(row).building, isFalse);
      expect(ProteinSuggestion.fromJson(<String, dynamic>{...row, 'building': true}).building,
          isTrue);
    });
  });

  group('a build', () {
    testWidgets('is asked for once, watched to the end, said once it ends, and then let be', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 0)),
        status: _inTurn(<Map<String, dynamic>>[
          _said('ready', slug: 'brca1',
              build: _report('scoring', 60, scored: 900, residues: 1863, left: 64)),
          _said('ready', slug: 'brca1',
              build: _report('done', 130, scored: 1863, residues: 1863)),
        ]),
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      final List<ProteinBuild> ended = <ProteinBuild>[];
      builds.ended.listen(ended.add);

      unawaited(builds.build(_brca1));
      unawaited(builds.build(_brca1)); // asked once, however often tapped
      await tester.pump();
      expect(builds.of('BRCA1')!.stage, BuildStage.building);
      expect(builds.of('BRCA1')!.report!.step, BuildStep.queued);

      await tester.pump(_tick);
      expect(builds.of('BRCA1')!.report!.scored, 900);
      await tester.pump(_tick);
      final ProteinBuild done = builds.of('BRCA1')!;
      expect((done.stage, done.slug, done.pinned), (BuildStage.ready, 'brca1', true));
      expect(ended.map((ProteinBuild b) => b.gene), <String>['BRCA1']);

      await tester.pump(_tick * 10);
      expect(api.calls, <String>[
        'POST /proteins/resolve BRCA1',
        'GET /proteins/resolve/BRCA1',
        'GET /proteins/resolve/BRCA1',
      ]);

      builds.opened('BRCA1');
      expect(builds.of('BRCA1')!.pinned, isFalse);
      expect(builds.of('BRCA1')!.slug, 'brca1');
      builds.dispose();
    });

    testWidgets('that stands still says for how long, by the service\'s clock, and is asked less', (
      WidgetTester tester,
    ) async {
      double elapsed = 0;
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 0, ahead: 1)),
        status: (String gene) async {
          elapsed += 60; // a minute of the service's for each answer
          return _said('pending', slug: 'brca1', build: _report('queued', elapsed, ahead: 1));
        },
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      unawaited(builds.build(_brca1));
      await tester.pump();

      await tester.pump(_tick * 9);
      expect(builds.of('BRCA1')!.unchangedFor, isNull);
      await tester.pump(_tick);
      expect(builds.of('BRCA1')!.unchangedFor, const Duration(minutes: 10));

      final int asked = api.calls.length;
      await tester.pump(_tick * 10);
      expect(api.calls.length, asked + 1);

      // Moving again, it is watched as before.
      elapsed += 60;
      api.status = (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('record', elapsed));
      await tester.pump(_tick * 10);
      expect(builds.of('BRCA1')!.unchangedFor, isNull);
      expect(builds.of('BRCA1')!.report!.step, BuildStep.record);
      builds.dispose();
    });

    testWidgets('the service gone quiet is said, and an answer clears it', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 0)),
        status: (String gene) async => throw const NetworkApiException(),
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      unawaited(builds.build(_brca1));
      await tester.pump();

      await tester.pump(_tick * 9);
      expect(builds.of('BRCA1')!.unheard, isFalse);
      await tester.pump(_tick);
      expect(builds.of('BRCA1')!.unheard, isTrue);
      expect(builds.of('BRCA1')!.stage, BuildStage.building);

      api.status = (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('record', 40));
      await tester.pump(_tick);
      expect(builds.of('BRCA1')!.unheard, isFalse);
      builds.dispose();
    });

    testWidgets('found under way by search is watched without being asked for', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        status: (String gene) async => _said('ready', slug: 'brca1',
            build: _report('scoring', 20, scored: 50, residues: 1863, left: 700)),
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      builds.watch(_brca1);
      builds.watch(_brca1);
      await tester.pump();
      expect(builds.of('BRCA1')!.report!.scored, 50);
      expect(api.calls, <String>['GET /proteins/resolve/BRCA1']);
      builds.dispose();
    });

    testWidgets('that search said was building, and is not, can be asked for again', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        status: (String gene) async => _said('buildable', slug: 'brca1'),
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      builds.watch(_brca1);
      await tester.pump();
      expect(builds.of('BRCA1')!.stage, BuildStage.failed);
      await tester.pump(_tick * 5);
      expect(api.calls, hasLength(1));
      builds.dispose();
    });

    testWidgets('asked for by this phone, it is this phone\'s to stop', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 0, ahead: 1)),
        status: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 3, ahead: 1)),
        stop: (String gene) async => _said('stopped', build: <String, dynamic>{
          ..._report('queued', 5, reason: 'Stopped before it was built.'),
          'stopped': true,
        }),
      );
      final ProteinBuilds builds = ProteinBuilds(
        ProteinResolver(api),
        asker: () async => 'install-a',
      );
      final List<ProteinBuild> ended = <ProteinBuild>[];
      builds.ended.listen(ended.add);
      unawaited(builds.build(_brca1));
      await tester.pump();
      expect(api.posted.single, <String, dynamic>{'gene': 'BRCA1', 'asker': 'install-a'});
      expect((builds.of('BRCA1')!.mine, builds.of('BRCA1')!.stoppable), (true, true));

      expect(await builds.stop('BRCA1'), isNull);
      final ProteinBuild stopped = builds.of('BRCA1')!;
      expect((stopped.stage, stopped.slug, stopped.opens), (BuildStage.stopped, null, false));
      expect(stopped.report!.stopped, isTrue);
      expect(api.posted.last, <String, dynamic>{'asker': 'install-a'});
      await tester.pump();
      expect(ended.map((ProteinBuild b) => b.stage), <BuildStage>[BuildStage.stopped]);

      // Watched no more; nothing to open, so it leaves search with search.
      final int asked = api.calls.length;
      await tester.pump(_tick * 3);
      expect(api.calls.length, asked);
      builds.unpinEnded();
      expect(builds.of('BRCA1')!.pinned, isFalse);
      builds.dispose();
    });

    testWidgets('stopped while scoring, it opens, and asking again scores it', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async => _said('ready', slug: 'brca1',
            build: _report('scoring', 60, scored: 450, residues: 1863, left: 1100)),
        stop: (String gene) async => _said('stopped', slug: 'brca1', build: <String, dynamic>{
          ..._report('scoring', 70, scored: 450, residues: 1863,
              reason: 'Stopped at 450 of 1,863 residues.'),
          'stopped': true,
        }),
      );
      final ProteinBuilds builds = ProteinBuilds(
        ProteinResolver(api),
        asker: () async => 'install-a',
      );
      unawaited(builds.build(_brca1));
      await tester.pump();
      expect(await builds.stop('BRCA1'), isNull);
      expect((builds.of('BRCA1')!.opens, builds.of('BRCA1')!.slug), (true, 'brca1'));
      // Something to open: it stays at the top of search until opened.
      builds.unpinEnded();
      expect(builds.of('BRCA1')!.pinned, isTrue);

      api.resolve = (String gene) async =>
          _said('ready', slug: 'brca1', build: _report('scoring', 0.1, ahead: 0));
      unawaited(builds.build(_brca1));
      await tester.pump();
      expect(builds.of('BRCA1')!.stage, BuildStage.building);
      expect(api.posted.last, <String, dynamic>{'gene': 'BRCA1', 'asker': 'install-a'});
      builds.dispose();
    });

    testWidgets('a stop turned down says why, and the build goes on', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 0)),
        status: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 3)),
        stop: (String gene) async => throw const ServerApiException(
          statusCode: 403, detail: 'Only the phone that asked for it can stop it.'),
      );
      final ProteinBuilds builds = ProteinBuilds(
        ProteinResolver(api),
        asker: () async => 'install-a',
      );
      unawaited(builds.build(_brca1));
      await tester.pump();
      expect(await builds.stop('BRCA1'), contains('Only the phone that asked'));
      expect((builds.of('BRCA1')!.stage, builds.of('BRCA1')!.stopping),
          (BuildStage.building, false));
      await tester.pump(_tick);
      expect(api.calls.last, 'GET /proteins/resolve/BRCA1');
      builds.dispose();
    });

    testWidgets('one this phone only watches, or asked without a name, it cannot stop', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 0)),
        status: (String gene) async =>
            _said('pending', slug: 'brca1', build: _report('queued', 3)),
      );
      final ProteinBuilds named = ProteinBuilds(
        ProteinResolver(api),
        asker: () async => 'install-a',
      );
      named.watch(_brca1);
      await tester.pump();
      expect(named.of('BRCA1')!.stoppable, isFalse);
      expect(await named.stop('BRCA1'), isNull);
      named.dispose();

      final ProteinBuilds nameless = ProteinBuilds(ProteinResolver(api));
      unawaited(nameless.build(_brca1));
      await tester.pump();
      expect(api.posted.last, <String, dynamic>{'gene': 'BRCA1'});
      expect(nameless.of('BRCA1')!.stoppable, isFalse);
      expect(api.calls.where((String c) => c.endsWith('/stop')), isEmpty);
      nameless.dispose();
    });

    testWidgets('stopped by the phone that asked, a watched build says so', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        status: (String gene) async => _said('ready', slug: 'brca1', build: <String, dynamic>{
          ..._report('scoring', 90, scored: 450, residues: 1863,
              reason: 'Stopped at 450 of 1,863 residues.'),
          'stopped': true,
        }),
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      builds.watch(_brca1);
      await tester.pump();
      expect((builds.of('BRCA1')!.stage, builds.of('BRCA1')!.opens), (BuildStage.stopped, true));
      builds.dispose();
    });

    testWidgets('declined, broken or capped ends at once, and leaves search when it is left', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async => switch (gene) {
          'BRCA1' => _said('refused', reason: 'Too long.', build: _report('record', 3)),
          'B2M' => throw const ServerApiException(statusCode: 429, detail: 'Taken.'),
          _ => throw const ServerApiException(statusCode: 503, detail: 'Down.'),
        },
      );
      final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
      for (final String gene in <String>['BRCA1', 'B2M', 'TTN']) {
        unawaited(builds.build(ProteinSuggestion(
          uniprot: gene, gene: gene, name: gene, display: null, length: 100,
          slug: gene.toLowerCase(), status: SuggestionStatus.buildable, reason: null,
        )));
      }
      await tester.pump();
      expect(
        <BuildStage>[for (final ProteinBuild b in builds.builds.value.values) b.stage],
        <BuildStage>[BuildStage.refused, BuildStage.capped, BuildStage.failed],
      );
      expect(builds.of('BRCA1')!.message, 'Too long.');
      expect(builds.builds.value.values.every((ProteinBuild b) => b.pinned), isTrue);

      builds.unpinEnded();
      expect(builds.builds.value.values.any((ProteinBuild b) => b.pinned), isFalse);
      builds.dispose();
    });
  });
}

/// Answers in turn, the last one for as long as it is asked.
Future<Map<String, dynamic>> Function(String) _inTurn(
  List<Map<String, dynamic>> answers,
) =>
    (String key) async => answers.length > 1 ? answers.removeAt(0) : answers.single;
