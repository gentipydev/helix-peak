import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layering of `lib/`, read off its import lines, so that the boundary
/// cannot erode one convenient import at a time.
///
/// Three rules:
///
/// 1. Nothing under `lib/features/lab/` imports the walk's screens or its
///    cubit. A new feature owns its own screen and its own state.
/// 2. Nothing under `lib/shared/` or `lib/core/` imports anything under
///    `lib/features/`. The layers below the features know none of them.
/// 3. No feature imports another feature's `presentation/`. What one feature
///    may take from another is its domain entities, [crossingPoint]: data, not
///    widgets.
///
/// The imports that broke a rule when this test was written are listed, rule
/// by rule, in [knownBreaches]. The list is a debt, not a licence: an import
/// that breaks a rule and is not on it fails the test, and so does an entry
/// that no longer breaks anything, so the list can only shrink. Close an entry
/// by moving code, never by adding one.

/// Where one feature may reach into another: its domain entities.
const String crossingPoint = 'domain/entities/';

/// Every rule's breaches as they stood on 2026-09-26, each as
/// `importing file -> imported file`.
const Map<String, Set<String>> knownBreaches = <String, Set<String>>{
  'lab': <String>{},
  'layers': <String>{
    // The composition root: dependency injection wires the walk's data layer.
    'lib/core/di/dependencies.dart -> lib/features/gene_lookup/data/datasources/gene_remote_data_source.dart',
    'lib/core/di/dependencies.dart -> lib/features/gene_lookup/data/repositories/gene_repository_impl.dart',
    'lib/core/di/dependencies.dart -> lib/features/gene_lookup/data/repositories/protein_catalog_repository.dart',
    'lib/core/di/dependencies.dart -> lib/features/gene_lookup/domain/repositories/gene_repository.dart',
    'lib/core/di/dependencies.dart -> lib/features/gene_lookup/domain/usecases/fetch_gene.dart',
    // The router builds every feature's screen, and the walk's cubit.
    'lib/core/router/app_router.dart -> lib/features/gene_lookup/data/repositories/protein_catalog_repository.dart',
    'lib/core/router/app_router.dart -> lib/features/gene_lookup/domain/usecases/fetch_gene.dart',
    'lib/core/router/app_router.dart -> lib/features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart',
    'lib/core/router/app_router.dart -> lib/features/gene_lookup/presentation/screens/gene_screen.dart',
    'lib/core/router/app_router.dart -> lib/features/home/presentation/screens/home_screen.dart',
    'lib/core/router/app_router.dart -> lib/features/search/presentation/screens/search_screen.dart',
  },
  'features': <String>{},
};

/// One `import` or `export` of a file under `lib/`, by a file under `lib/`.
final class Import {
  const Import(this.from, this.to, this.directive);

  /// Both paths are from the package root: `lib/...`.
  final String from;
  final String to;

  /// The directive as written, for the failure message.
  final String directive;

  String get key => '$from -> $to';

  @override
  String toString() => '$from\n      $directive';
}

final RegExp _directive = RegExp(
  r'^[ \t]*(?:import|export)\s[^;]*;',
  multiLine: true,
);
final RegExp _uri = RegExp(r'''['"]([^'"]+)['"]''');

/// Every import and export between files under `lib/`, read from disk.
List<Import> readImports() {
  final List<File> files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  return <Import>[
    for (final File file in files)
      ...importsOf(
        file.path.replaceAll(r'\', '/'),
        file.readAsStringSync(),
      ),
  ];
}

/// The imports in [source], the file at [path], that resolve under `lib/`.
List<Import> importsOf(String path, String source) {
  final Uri base = Uri.parse('file:///$path');
  return <Import>[
    for (final RegExpMatch directive in _directive.allMatches(source))
      for (final RegExpMatch uri in _uri.allMatches(directive[0]!))
        if (_resolve(base, uri[1]!) case final String target)
          Import(path, target, directive[0]!.trim().replaceAll(RegExp(r'\s+'), ' ')),
  ];
}

String? _resolve(Uri base, String uri) {
  if (uri.startsWith('package:helixpeek/')) {
    return 'lib/${uri.substring('package:helixpeek/'.length)}';
  }
  if (uri.startsWith('package:') || uri.startsWith('dart:')) {
    return null;
  }
  return base.resolve(uri).path.substring(1);
}

String? _feature(String path) =>
    RegExp(r'^lib/features/([^/]+)/').firstMatch(path)?.group(1);

/// Rule 1: a new flow does not reuse the walk's screen or its state.
bool breaksLab(Import i) =>
    i.from.startsWith('lib/features/lab/') &&
    (i.to.startsWith('lib/features/gene_lookup/presentation/screens/') ||
        i.to.startsWith('lib/features/gene_lookup/presentation/cubit/'));

/// Rule 2: the shared layer and core know no feature.
bool breaksLayers(Import i) =>
    (i.from.startsWith('lib/shared/') || i.from.startsWith('lib/core/')) &&
    i.to.startsWith('lib/features/');

/// Rule 3: one feature never imports another's presentation. Anything under
/// its [crossingPoint] is what crossing is for.
bool breaksFeatures(Import i) {
  final String? from = _feature(i.from);
  final String? to = _feature(i.to);
  return from != null &&
      to != null &&
      from != to &&
      i.to.startsWith('lib/features/$to/presentation/');
}

/// Fails, naming each file and import, if [rule] is broken anywhere its known
/// breaches do not cover, or if one of those no longer breaks it.
void expectRule(
  List<Import> imports,
  String rule,
  bool Function(Import) breaks,
  String why,
) {
  final Set<String> known = knownBreaches[rule]!;
  final List<Import> breaches = imports.where(breaks).toList();
  final List<Import> fresh = <Import>[
    for (final Import i in breaches)
      if (!known.contains(i.key)) i,
  ];
  final Set<String> closed = known.difference(<String>{
    for (final Import i in breaches) i.key,
  });
  expect(
    fresh,
    isEmpty,
    reason:
        '$why\n'
        '${fresh.length} import(s) break it:\n'
        '${fresh.map((Import i) => '  $i').join('\n')}\n',
  );
  expect(
    closed,
    isEmpty,
    reason:
        'These no longer break the rule. Take them off knownBreaches[$rule] '
        'so the list only shrinks:\n'
        '${closed.map((String key) => '  $key').join('\n')}\n',
  );
}

void main() {
  final List<Import> imports = readImports();

  test('the imports are read from every file under lib/', () {
    // A reader that found nothing would pass every rule below.
    expect(
      imports.map((Import i) => i.key),
      containsAll(<String>[
        'lib/app.dart -> lib/core/router/app_router.dart',
        'lib/main.dart -> lib/features/gene_lookup/data/repositories/protein_catalog_repository.dart',
      ]),
    );
  });

  test('the rules catch the imports they name', () {
    // Nothing is under lib/features/lab/ yet, so rule 1 has nothing to catch
    // today; these prove it will.
    Import edge(String from, String to) =>
        importsOf(from, "import '$to';").single;
    const String lab = 'lib/features/lab/mutate/mutate_screen.dart';
    expect(
      breaksLab(
        edge(lab, '../../gene_lookup/presentation/screens/gene_screen.dart'),
      ),
      isTrue,
    );
    expect(
      breaksLab(
        edge(
          lab,
          'package:helixpeek/features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart',
        ),
      ),
      isTrue,
    );
    expect(
      breaksFeatures(
        edge(lab, '../../gene_lookup/presentation/anatomy/anatomy_canvas.dart'),
      ),
      isTrue,
    );
    expect(
      breaksFeatures(
        edge(lab, '../../gene_lookup/domain/entities/gene_record.dart'),
      ),
      isFalse,
      reason: 'domain entities are the crossing point',
    );
    expect(
      breaksLayers(
        edge(
          'lib/shared/widgets/app_logo.dart',
          '../../features/home/presentation/widgets/wordmark.dart',
        ),
      ),
      isTrue,
    );
  });

  test('no lab flow imports the walk’s screens or its cubit', () {
    expectRule(
      imports,
      'lab',
      breaksLab,
      'A file under lib/features/lab/ imports lib/features/gene_lookup/'
      'presentation/screens/ or the gene_lookup cubit. A new feature owns its '
      'own screen and its own state.',
    );
  });

  test('nothing in shared or core imports a feature', () {
    expectRule(
      imports,
      'layers',
      breaksLayers,
      'A file under lib/shared/ or lib/core/ imports something under '
      'lib/features/. The layers below the features know none of them.',
    );
  });

  test('no feature imports another feature’s presentation', () {
    expectRule(
      imports,
      'features',
      breaksFeatures,
      'A file under lib/features/<a>/ imports lib/features/<b>/presentation/. '
      'Cross into another feature through its $crossingPoint '
      '(lib/features/<b>/$crossingPoint), or promote what both need into '
      'lib/shared/.',
    );
  });
}
