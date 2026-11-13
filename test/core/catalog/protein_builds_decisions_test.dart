import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/network/api_exception.dart';

import '../../features/search/support/resolver_api.dart';

/// A stopped build, decided ([ProteinBuilds.keep], [ProteinBuilds.discard]),
/// and the stopped builds this phone left undecided pinned again
/// ([ProteinBuilds.restore]), on [ResolverApi] answering as the backend's
/// `/proteins/resolve/{gene}/keep`, `.../discard` and `/proteins/stopped` do.

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
  Map<String, dynamic>? build,
}) => <String, dynamic>{'slug': slug, 'state': state, 'reason': null, 'build': build};

Map<String, dynamic> _report(
  String step,
  double elapsed, {
  int? scored,
  int? residues,
  double? left,
  String? reason,
  bool stopped = false,
}) => <String, dynamic>{
  'step': step, 'ahead': null, 'scored': scored, 'residues': residues,
  'left': left, 'elapsed': elapsed, 'transcript': null, 'reason': reason,
  'stopped': stopped,
};

Map<String, dynamic> _stoppedScoring() => _said('stopped', slug: 'brca1',
    build: _report('scoring', 70, scored: 450, residues: 1863,
        reason: 'Stopped at 450 of 1,863 residues.', stopped: true));

Map<String, dynamic> _stoppedQueued() => _said('stopped',
    build: _report('queued', 12, reason: 'Stopped before it was built.', stopped: true));

/// A build of BRCA1 asked for by install-a and stopped, as [stop] says.
Future<(ProteinBuilds, ResolverApi)> _stopped(
  WidgetTester tester,
  Map<String, dynamic> Function() stop, {
  String? asker = 'install-a',
}) async {
  final ResolverApi api = ResolverApi(
    resolve: (String gene) async => _said('ready', slug: 'brca1',
        build: _report('scoring', 60, scored: 450, residues: 1863, left: 1100)),
    stop: (String gene) async => stop(),
  );
  final ProteinBuilds builds = ProteinBuilds(
    ProteinResolver(api),
    asker: asker == null ? null : () async => asker,
  );
  unawaited(builds.build(_brca1));
  await tester.pump();
  if (asker != null) {
    expect(await builds.stop('BRCA1'), isNull);
  }
  return (builds, api);
}

void main() {
  group('a stopped build', () {
    testWidgets('with something built, offers Keep and Discard; with nothing built, Discard', (
      WidgetTester tester,
    ) async {
      final (ProteinBuilds scored, _) = await _stopped(tester, _stoppedScoring);
      final ProteinBuild kept = scored.of('BRCA1')!;
      expect((kept.stage, kept.keepable, kept.discardable), (BuildStage.stopped, true, true));
      scored.dispose();

      final (ProteinBuilds queued, _) = await _stopped(tester, _stoppedQueued);
      final ProteinBuild withdrawn = queued.of('BRCA1')!;
      expect((withdrawn.keepable, withdrawn.discardable), (false, true));
      queued.dispose();
    });

    testWidgets('kept, it leaves the builds, and the service is told by this phone', (
      WidgetTester tester,
    ) async {
      final (ProteinBuilds builds, ResolverApi api) = await _stopped(tester, _stoppedScoring);
      final Completer<Map<String, dynamic>> answer = Completer<Map<String, dynamic>>();
      api.keep = (String gene) => answer.future;
      final List<String> decided = <String>[];
      final StreamSubscription<String> heard = builds.decided.listen(decided.add);

      final Future<String?> keeping = builds.keep('BRCA1');
      await tester.pump();
      // On its way: said so, and nothing else may be asked of it meanwhile.
      expect(builds.of('BRCA1')!.keeping, isTrue);
      expect((builds.of('BRCA1')!.keepable, builds.of('BRCA1')!.discardable), (false, false));
      answer.complete(<String, dynamic>{..._stoppedScoring(), 'state': 'ready'});
      expect(await keeping, isNull);
      await tester.pump();
      expect(builds.of('BRCA1'), isNull);
      expect(api.calls.last, 'POST /proteins/resolve/BRCA1/keep');
      expect(api.posted.last, <String, dynamic>{'asker': 'install-a'});
      expect(decided, <String>['BRCA1']);
      unawaited(heard.cancel());
      builds.dispose();
    });

    testWidgets('discarded, it leaves the builds, and the service is told by this phone', (
      WidgetTester tester,
    ) async {
      final (ProteinBuilds builds, ResolverApi api) = await _stopped(tester, _stoppedScoring);
      final Completer<Map<String, dynamic>> answer = Completer<Map<String, dynamic>>();
      api.discard = (String gene) => answer.future;
      final List<String> decided = <String>[];
      final StreamSubscription<String> heard = builds.decided.listen(decided.add);

      final Future<String?> discarding = builds.discard('BRCA1');
      await tester.pump();
      expect(builds.of('BRCA1')!.discarding, isTrue);
      expect((builds.of('BRCA1')!.keepable, builds.of('BRCA1')!.discardable), (false, false));
      answer.complete(_said('buildable', slug: 'brca1'));
      expect(await discarding, isNull);
      await tester.pump();
      expect(builds.of('BRCA1'), isNull);
      expect(api.calls.last, 'POST /proteins/resolve/BRCA1/discard');
      expect(api.posted.last, <String, dynamic>{'asker': 'install-a'});
      expect(decided, <String>['BRCA1']);
      unawaited(heard.cancel());
      builds.dispose();
    });

    testWidgets('a decision turned down says why, and the build stays as it was', (
      WidgetTester tester,
    ) async {
      final (ProteinBuilds builds, ResolverApi api) = await _stopped(tester, _stoppedScoring);
      api.discard = (String gene) async => throw const ServerApiException(
        statusCode: 409,
        detail: 'Its fold is still being made. Discard it in a moment.',
      );
      expect(await builds.discard('BRCA1'), contains('Discard it in a moment'));
      final ProteinBuild still = builds.of('BRCA1')!;
      expect((still.stage, still.discarding, still.keepable, still.pinned),
          (BuildStage.stopped, false, true, true));
      builds.dispose();
    });

    testWidgets('one under way, or another phone\'s, asks the service nothing', (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        resolve: (String gene) async => _said('ready', slug: 'brca1',
            build: _report('scoring', 60, scored: 450, residues: 1863, left: 1100)),
        status: (String gene) async => _said('ready', slug: 'brca1',
            build: _report('scoring', 63, scored: 450, residues: 1863, left: 1100)),
      );
      final ProteinBuilds builds = ProteinBuilds(
        ProteinResolver(api),
        asker: () async => 'install-a',
      );
      unawaited(builds.build(_brca1));
      await tester.pump();
      expect(await builds.keep('BRCA1'), isNull);
      expect(await builds.discard('BRCA1'), isNull);
      expect(builds.of('BRCA1')!.stage, BuildStage.building);
      expect(api.calls.where((String c) => c.endsWith('/keep') || c.endsWith('/discard')),
          isEmpty);
      builds.dispose();
    });
  });

  group('restore', () {
    testWidgets("pins this phone's undecided stopped builds as the service tells them", (
      WidgetTester tester,
    ) async {
      final ResolverApi api = ResolverApi(
        stopped: (String asker) async => <String, dynamic>{
          'proteins': <Object?>[
            <String, dynamic>{
              'uniprot': 'P38398', 'gene': 'BRCA1',
              'name': 'Breast cancer type 1 susceptibility protein', 'display': null,
              'length': 1863, 'slug': 'brca1', 'status': 'ready', 'reason': null,
              'building': false, 'stopped': true,
            },
          ],
          'next': null,
        },
        status: (String gene) async => _said('ready', slug: 'brca1',
            build: _report('scoring', 410, scored: 450, residues: 1863,
                reason: 'Stopped at 450 of 1,863 residues.', stopped: true)),
      );
      final ProteinBuilds builds = ProteinBuilds(
        ProteinResolver(api),
        asker: () async => 'install-a',
      );
      await builds.restore();
      final ProteinBuild back = builds.of('BRCA1')!;
      expect((back.stage, back.mine, back.pinned, back.opens, back.slug),
          (BuildStage.stopped, true, true, true, 'brca1'));
      expect(back.report!.reason, 'Stopped at 450 of 1,863 residues.');
      expect((back.keepable, back.discardable), (true, true));
      expect(api.calls, <String>['POST /proteins/stopped', 'GET /proteins/resolve/BRCA1']);
      expect(api.posted.single, <String, dynamic>{'asker': 'install-a'});
      builds.dispose();
    });

    testWidgets('asks nothing without an install id, and a service without the list pins nothing', (
      WidgetTester tester,
    ) async {
      final ResolverApi none = ResolverApi();
      final ProteinBuilds anonymous = ProteinBuilds(ProteinResolver(none));
      await anonymous.restore();
      expect(none.calls, isEmpty);
      anonymous.dispose();

      final ResolverApi older = ResolverApi(
        stopped: (String asker) async =>
            throw const ServerApiException(statusCode: 404, detail: 'Not Found'),
      );
      final ProteinBuilds builds = ProteinBuilds(
        ProteinResolver(older),
        asker: () async => 'install-a',
      );
      await builds.restore();
      expect(builds.builds.value, isEmpty);
      builds.dispose();
    });
  });
}
