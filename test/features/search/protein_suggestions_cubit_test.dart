import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/features/search/presentation/cubit/protein_suggestions_cubit.dart';

import 'support/resolver_api.dart';

const Duration _pause = Duration(milliseconds: 300);

Map<String, dynamic> _page(String q) => <String, dynamic>{
  'q': q,
  'release': null,
  'suggestions': <Object?>[],
};

void main() {
  testWidgets('typing is asked about once it stops', (WidgetTester tester) async {
    final ResolverApi api = ResolverApi();
    final ProteinSuggestionsCubit cubit = ProteinSuggestionsCubit(ProteinResolver(api));
    addTearDown(cubit.close);

    cubit.query('i');
    expect(cubit.state, isA<SuggestionsIdle>());
    cubit.query('in');
    cubit.query('ins');
    expect(cubit.state, isA<SuggestionsLoading>());
    await tester.pump(_pause);
    expect(api.calls, <String>['GET /proteins/suggest?q=ins']);
    expect((cubit.state as SuggestionsShown).page.query, 'ins');
  });

  testWidgets('an older answer arriving last never replaces a newer one', (
    WidgetTester tester,
  ) async {
    final Map<String, Completer<Map<String, dynamic>>> waiting =
        <String, Completer<Map<String, dynamic>>>{};
    final ProteinSuggestionsCubit cubit = ProteinSuggestionsCubit(
      ProteinResolver(
        ResolverApi(
          suggest: (String q) =>
              (waiting[q] = Completer<Map<String, dynamic>>()).future,
        ),
      ),
    );
    addTearDown(cubit.close);

    cubit.query('ins');
    await tester.pump(_pause);
    cubit.query('insulin');
    await tester.pump(_pause);
    expect(waiting.keys, <String>['ins', 'insulin']);

    waiting['insulin']!.complete(_page('insulin'));
    await tester.pump();
    waiting['ins']!.complete(_page('ins'));
    await tester.pump();
    expect((cubit.state as SuggestionsShown).page.query, 'insulin');
  });

  testWidgets('clearing the query drops what was being asked', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi();
    final ProteinSuggestionsCubit cubit = ProteinSuggestionsCubit(ProteinResolver(api));
    addTearDown(cubit.close);

    cubit.query('insulin');
    cubit.query('');
    await tester.pump(_pause);
    expect(api.calls, isEmpty);
    expect(cubit.state, isA<SuggestionsIdle>());
  });
}
