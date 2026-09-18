import 'package:flutter/foundation.dart';

/// Which gene, in which record, to ask the backend for.
///
/// The backend's `/gene/{id}/{gene}` takes both as free parameters, so which
/// gene to ask for is the client's decision. It is made one layer up, in
/// `ProteinCatalog`: every target there carries the pair it would be fetched
/// with, live or bundled, and this is only the pair.
@immutable
final class GeneQuery {
  const GeneQuery({required this.accession, required this.gene});

  final String accession;
  final String gene;

  @override
  bool operator ==(Object other) =>
      other is GeneQuery && other.accession == accession && other.gene == gene;

  @override
  int get hashCode => Object.hash(accession, gene);

  @override
  String toString() => 'GeneQuery($accession/$gene)';
}
