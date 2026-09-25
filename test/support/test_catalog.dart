import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/features/gene_lookup/domain/entities/protein_ranking.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';

abstract final class TestCatalog {
  static final List<ProteinTarget> all = _load();

  static List<ProteinTarget> _load() {
    final body = jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
        as Map<String, dynamic>;
    final rows = (body['proteins'] as List<dynamic>).cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['catalog_order'] as int).compareTo(b['catalog_order'] as int));
    return rows.map(ProteinTarget.fromJson).toList();
  }

  static final ProteinTarget insulin = bySlug('insulin')!;
  static final ProteinTarget hemoglobin = bySlug('hemoglobin')!;
  static final ProteinTarget myoglobin = bySlug('myoglobin')!;
  static final ProteinTarget p53 = bySlug('p53')!;
  static final ProteinTarget lysozyme = bySlug('lysozyme')!;
  static final ProteinTarget relaxin = bySlug('relaxin')!;
  static final ProteinTarget oxytocin = bySlug('oxytocin')!;
  static final ProteinTarget somatotropin = bySlug('somatotropin')!;
  static final ProteinTarget ubiquitin = bySlug('ubiquitin')!;
  static final ProteinTarget dystrophin = bySlug('dystrophin')!;
  static final ProteinTarget vasopressin = bySlug('vasopressin')!;
  static final ProteinTarget glucagon = bySlug('glucagon')!;
  static final ProteinTarget app = bySlug('app')!;
  static final ProteinTarget cftr = bySlug('cftr')!;
  static final ProteinTarget erythropoietin = bySlug('erythropoietin')!;
  static final ProteinTarget leptin = bySlug('leptin')!;
  static final ProteinTarget tnf = bySlug('tnf')!;
  static final ProteinTarget sod1 = bySlug('sod1')!;
  static final ProteinTarget amylase = bySlug('amylase')!;
  static final ProteinTarget prion = bySlug('prion')!;
  static final ProteinTarget fallback = insulin;
  static final List<ProteinTarget> tracked = [insulin, relaxin, app];
  static ProteinTarget? bySlug(String slug) {
    for (final target in all) {
      if (target.slug == slug) return target;
    }
    return null;
  }
  static List<ProteinTarget> matching(String query) => rank(all, query);
}

extension FixtureAssets on ProteinTarget {
  String get mockAsset => 'test/fixtures/mock/gene_${gene.toLowerCase()}.json';
  String get constraintAsset => 'test/fixtures/constraint/${slug}_esm_constraint.json';
  String get impactAsset => 'test/fixtures/impact/${slug}_avi.json';
  String get clinvarAsset => 'test/fixtures/clinvar/${slug}_clinvar.json';
  String get structureAsset => 'test/fixtures/models/$slug.glb';
  String get impactExplanationsAsset => 'test/fixtures/impact_explanations/$slug.json';
  String? asset(TrackKind kind) => switch (kind) {
    TrackKind.record => mockAsset,
    TrackKind.constraint => constraintAsset,
    TrackKind.impact => impactAsset,
    TrackKind.clinvar => clinvarAsset,
    TrackKind.impactExplanations => impactExplanationsAsset,
    TrackKind.structure => structureAsset,
  };
}
