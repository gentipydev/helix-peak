import 'package:flutter/foundation.dart';

/// Which gene record to read, and how to name it.
///
/// The record is a stored track, found by [slug] like every other track the
/// walk reads. [accession] and [gene] say what the record is -- the loading
/// view names the accession while it arrives -- and are what the backend's
/// `/gene/{id}/{gene}` took as free parameters before the record moved to
/// storage.
@immutable
final class GeneQuery {
  const GeneQuery({
    required this.slug,
    required this.accession,
    required this.gene,
  });

  final String slug;
  final String accession;
  final String gene;

  @override
  bool operator ==(Object other) =>
      other is GeneQuery &&
      other.slug == slug &&
      other.accession == accession &&
      other.gene == gene;

  @override
  int get hashCode => Object.hash(slug, accession, gene);

  @override
  String toString() => 'GeneQuery($slug: $accession/$gene)';
}
