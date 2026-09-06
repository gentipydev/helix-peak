import '../../../../core/network/api_exception.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/nucleotide_counts.dart';
import '../../domain/entities/sequence_input.dart';
import '../../domain/repositories/sequence_repository.dart';

/// In-memory [SequenceRepository] used until the FastAPI backend exists.
///
/// Only the *transport* is fake. Every number it returns — base counts, GC
/// content, melting temperature, molecular weight — is genuinely computed from
/// the input, so the UI can be built and demonstrated against honest data and
/// screenshots are not fiction. The artificial delay exists so loading states
/// are actually visible during development rather than flashing past.
final class StubSequenceRepository implements SequenceRepository {
  const StubSequenceRepository();

  /// Long enough that the loading treatment is legible, short enough not to
  /// be irritating during development.
  static const Duration _latency = Duration(milliseconds: 900);

  /// Including this token in a sequence forces a failure, which is the only
  /// practical way to exercise the error state and its retry path before a
  /// real backend can fail on its own.
  static const String failureSentinel = 'XFAIL';

  @override
  Future<AnalysisResult> analyse(SequenceInput input) async {
    await Future<void>.delayed(_latency);

    if (input.bases.contains(failureSentinel) ||
        (input.fastaHeader?.contains(failureSentinel) ?? false)) {
      throw const ServerApiException(
        statusCode: 503,
        detail: 'Analysis service is unavailable (simulated failure).',
      );
    }

    final NucleotideCounts counts = NucleotideCounts.fromBases(input.bases);

    return AnalysisResult(
      id: 'stub-${input.bases.hashCode.toUnsigned(32).toRadixString(16)}',
      input: input,
      counts: counts,
      meltingTemperatureCelsius: _meltingTemperature(counts),
      molecularWeightDaltons: _molecularWeight(counts),
      generatedAt: DateTime.now(),
      predictions: _predictions(input, counts),
      warnings: _warnings(counts),
    );
  }

  /// Melting temperature, using the standard rule for the sequence's length.
  ///
  /// Short oligonucleotides use the Wallace rule; longer sequences use the
  /// GC-content formula, which is what the Wallace rule's assumptions break
  /// down for past roughly 14 bases.
  double _meltingTemperature(NucleotideCounts counts) {
    final int length = counts.total;
    if (length == 0) {
      return 0;
    }
    if (length < 14) {
      return 2.0 * (counts.adenine + counts.thymine) +
          4.0 * (counts.guanine + counts.cytosine);
    }
    return 64.9 +
        41 * (counts.guanine + counts.cytosine - 16.4) / length;
  }

  /// Approximate single-stranded molecular weight in daltons, using standard
  /// per-nucleotide monophosphate masses less one terminal phosphate.
  double _molecularWeight(NucleotideCounts counts) {
    if (counts.total == 0) {
      return 0;
    }
    return counts.adenine * 313.21 +
        counts.thymine * 304.20 +
        counts.guanine * 329.21 +
        counts.cytosine * 289.18 -
        61.96;
  }

  /// Placeholder stand-ins for the model outputs the backend will return.
  ///
  /// Derived from the sequence so they are stable across runs — the same input
  /// always yields the same predictions, which keeps the UI predictable while
  /// developing and avoids values that jitter on every rebuild.
  List<PropertyPrediction> _predictions(
    SequenceInput input,
    NucleotideCounts counts,
  ) {
    final int seed = input.bases.hashCode.toUnsigned(31);
    double confidence(int offset) => 0.72 + ((seed >> offset) % 27) / 100;

    final bool gcRich = counts.gcContentPercent >= 55;

    return <PropertyPrediction>[
      PropertyPrediction(
        label: 'Duplex stability',
        value: gcRich ? 'High' : 'Moderate',
        confidence: confidence(0),
      ),
      PropertyPrediction(
        label: 'Predicted structure',
        value: gcRich ? 'Hairpin likely' : 'Largely unstructured',
        confidence: confidence(4),
      ),
      PropertyPrediction(
        label: 'Coding potential',
        value: counts.total % 3 == 0 ? 'In frame' : 'Frame shift',
        confidence: confidence(8),
      ),
    ];
  }

  List<String> _warnings(NucleotideCounts counts) {
    return <String>[
      if (counts.other > 0)
        'Contains ${counts.other} ambiguous or gap character(s), excluded from '
            'base-specific statistics.',
      if (counts.total < 30)
        'Short sequence — composition statistics are indicative only.',
    ];
  }
}
