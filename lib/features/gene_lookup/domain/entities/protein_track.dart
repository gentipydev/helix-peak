/// What the service says about one data family for one protein.
///
/// These four states replaced four booleans, and the reason is R9.3: an
/// unbaked gene, a snapshot still arriving and a gene the pipeline declined are
/// three different things, and a boolean can only tell the reader one of them.
/// "Not yet included" said about a track that lands in four minutes is exactly
/// the claim the rules forbid.
///
/// Deliberately free of any Flutter import. `protein_target.dart` pulls in
/// `material.dart` so [ChainTint] can name a colour; nothing here needs to.
library;

/// The six families a protein can carry, named as the service names them.
enum TrackKind {
  /// The GenBank record the walk opens on.
  record('record'),

  /// The per-residue ESM constraint track the protein page colours itself with.
  constraint('constraint'),

  /// The per-base AlphaGenome Variant Impact track over the gene record.
  impact('impact'),

  /// The ClinVar snapshot.
  clinvar('clinvar'),

  /// The baked fold, as a model the last page draws.
  structure('structure'),

  /// Exact-allele AVI contributions, a pilot over three genes.
  impactExplanations('impact_explanations');

  const TrackKind(this.wire);

  /// The key the service uses. Dart spells the last one in camel case and the
  /// wire spells it in snake case, so the two cannot simply share a name.
  final String wire;

  static TrackKind? fromWire(String wire) {
    for (final TrackKind kind in TrackKind.values) {
      if (kind.wire == wire) {
        return kind;
      }
    }
    return null;
  }
}

/// Where a track has got to.
enum TrackState {
  /// The object is there and [TrackRef.url] points at it.
  ready('ready'),

  /// A bake is queued or running. Arriving, not absent — the difference R9.3
  /// exists to keep.
  pending('pending'),

  /// Nothing was asked for and nothing is coming.
  absent('absent'),

  /// The pipeline declined, and [TrackRef.reason] is the sentence why: titin's
  /// exons exceed the page budget, no entry covers the mature chain. A refusal
  /// is a finding, not a failure.
  refused('refused');

  const TrackState(this.wire);

  final String wire;

  /// Anything the service invents later reads as [absent] rather than throwing.
  /// A track the client cannot classify is one it should not draw, and that is
  /// what absent already means.
  static TrackState fromWire(String? wire) {
    for (final TrackState state in TrackState.values) {
      if (state.wire == wire) {
        return state;
      }
    }
    return TrackState.absent;
  }
}

/// One track row as the service serves it.
///
/// [url] is non-null only where [state] is [TrackState.ready] — `tracks.py`
/// downgrades a stored-but-unaddressable row to [TrackState.refused] rather
/// than serving a ready one with nowhere to fetch from, so the client never has
/// to guess. [sha256] is the cache key the blob phases will use: the storage
/// path carries the digest, which is what makes `cache-control: immutable` true.
final class TrackRef {
  const TrackRef({
    required this.state,
    this.reason,
    this.url,
    this.format,
    this.bytes,
    this.sha256,
    this.contentEncoding,
    this.provenance = const <String, dynamic>{},
  });

  /// A state the client knows without asking, for a family this build bundles.
  const TrackRef.bundled()
    : state = TrackState.ready,
      reason = null,
      url = null,
      format = null,
      bytes = null,
      sha256 = null,
      contentEncoding = null,
      provenance = const <String, dynamic>{};

  factory TrackRef.fromJson(Map<String, dynamic> json) => TrackRef(
    state: TrackState.fromWire(json['state'] as String?),
    reason: json['reason'] as String?,
    url: json['url'] as String?,
    format: json['format'] as String?,
    bytes: json['bytes'] as int?,
    sha256: json['sha256'] as String?,
    contentEncoding: json['content_encoding'] as String?,
    provenance:
        (json['provenance'] as Map<String, dynamic>?) ??
        const <String, dynamic>{},
  );

  final TrackState state;

  /// The sentence a refusal carries, and null everywhere else.
  final String? reason;

  final String? url;
  final String? format;
  final int? bytes;

  /// The digest of the payload, and the name of the object holding it.
  final String? sha256;

  /// Null, and staying null: Supabase's CDN compresses in transit, so a blob
  /// stored pre-gzipped would be gzipped twice and decompressed twice for a
  /// 0.7% difference. The column is here for the packed binary formats.
  final String? contentEncoding;

  /// Which model, which method, which vocabulary. Two ESM provenances are going
  /// to coexist here indefinitely, so the About sheet has to read this rather
  /// than name a model in a string constant.
  final Map<String, dynamic> provenance;
}
