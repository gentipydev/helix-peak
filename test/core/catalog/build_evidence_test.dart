import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';

import '../../features/search/support/resolver_api.dart';

/// The step a build is at while its AlphaGenome and ClinVar tracks are made
/// (`evidence`): between its gene record and ESM-2, as the backend's
/// `/proteins/resolve` reports it since 2026-10-09, and on [ResolverApi] in
/// fake time.

const Duration _tick = Duration(seconds: 3);

const ProteinSuggestion _gjb2 = ProteinSuggestion(
  uniprot: 'P29033',
  gene: 'GJB2',
  name: 'Gap junction beta-2 protein',
  display: null,
  length: 226,
  slug: 'gjb2',
  status: SuggestionStatus.buildable,
  reason: null,
);

Map<String, dynamic> _said(String state, {String? slug, Map<String, dynamic>? build}) =>
    <String, dynamic>{'slug': slug, 'state': state, 'reason': null, 'build': build};

Map<String, dynamic> _report(
  String step,
  double elapsed, {
  int? ahead,
  int? scored,
  int? residues,
}) => <String, dynamic>{
  'step': step, 'ahead': ahead, 'scored': scored, 'residues': residues,
  'left': null, 'elapsed': elapsed, 'transcript': 'NM_004004.6', 'reason': null,
};

/// Answers in turn, the last one for as long as it is asked.
Future<Map<String, dynamic>> Function(String) _inTurn(
  List<Map<String, dynamic>> answers,
) =>
    (String gene) async => answers.length > 1 ? answers.removeAt(0) : answers.single;

void main() {
  test('the service\'s evidence step is read, after the record and before ESM-2', () {
    final BuildReport report = ResolveStatus.fromJson(
      _said('ready', slug: 'gjb2', build: _report('evidence', 53.4)),
    ).build!;
    expect(report.step, BuildStep.evidence);
    expect((report.reason, report.ahead, report.fraction), (null, null, null));
    expect(
      <String>[for (final BuildStep step in BuildStep.values) step.wire],
      <String>['queued', 'record', 'evidence', 'scoring', 'check', 'done'],
    );
  });

  testWidgets('a build at its evidence is under way, not to be stopped, and opens once scored', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      resolve: (String gene) async =>
          _said('pending', slug: 'gjb2', build: _report('queued', 0.2, ahead: 0)),
      status: _inTurn(<Map<String, dynamic>>[
        _said('ready', slug: 'gjb2', build: _report('evidence', 53)),
        _said('ready', slug: 'gjb2', build: _report('scoring', 172, ahead: 0)),
        _said('ready', slug: 'gjb2', build: _report('done', 211, scored: 226, residues: 226)),
      ]),
    );
    final ProteinBuilds builds = ProteinBuilds(
      ProteinResolver(api),
      asker: () async => 'install-a',
    );
    addTearDown(builds.dispose);
    final List<ProteinBuild> ended = <ProteinBuild>[];
    builds.ended.listen(ended.add);

    unawaited(builds.build(_gjb2));
    await tester.pump();
    expect(builds.of('GJB2')!.stoppable, isTrue);

    // Its row is ready from the moment its record is, and its AVI and ClinVar
    // are still to come: it does not open, and a stop, which ends ESM-2, is
    // not offered before ESM-2 begins.
    await tester.pump(_tick);
    final ProteinBuild fetching = builds.of('GJB2')!;
    expect(fetching.report!.step, BuildStep.evidence);
    expect(
      (fetching.stage, fetching.opens, fetching.stoppable),
      (BuildStage.building, false, false),
    );
    expect(ended, isEmpty);

    await tester.pump(_tick);
    final ProteinBuild scoring = builds.of('GJB2')!;
    expect((scoring.report!.step, scoring.stoppable), (BuildStep.scoring, true));

    await tester.pump(_tick);
    final ProteinBuild done = builds.of('GJB2')!;
    expect((done.stage, done.opens, done.slug), (BuildStage.ready, true, 'gjb2'));
    expect(ended.single.gene, 'GJB2');
  });
}
