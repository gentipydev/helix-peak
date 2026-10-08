import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/features/search/presentation/widgets/build_card.dart';

/// [BuildCard]'s figures: the running clock, and the bar that glides between
/// the scorer's lines without ever claiming a residue the scorer has not
/// reached by more than one line.

BuildReport _scoring({int scored = 450, int residues = 4834, int? left, int? ran}) =>
    BuildReport(
      step: BuildStep.scoring,
      elapsed: const Duration(minutes: 7),
      scored: scored,
      residues: residues,
      left: left == null ? null : Duration(seconds: left),
      ran: ran == null ? null : Duration(seconds: ran),
    );

void main() {
  test('the clock reads minutes and seconds, and hours once there are any', () {
    expect(BuildCard.clock(Duration.zero), '00:00');
    expect(BuildCard.clock(const Duration(seconds: 97)), '01:37');
    expect(BuildCard.clock(const Duration(minutes: 64, seconds: 52)), '1:04:52');
    // Time left that has run out is not counted below nothing.
    expect(BuildCard.clock(const Duration(seconds: -4)), '00:00');
    expect(BuildCard.span(const Duration(seconds: 45)), '45 s');
    expect(BuildCard.span(const Duration(seconds: 534)), '9 min');
  });

  test('a residue takes the run\'s whole length over its residues', () {
    // HERC2 on the dev Mac: 344.7 s for 450 residues, 56.0 min left.
    final BuildReport herc2 = _scoring(left: 3360, ran: 345);
    expect(BuildCard.perResidue(herc2), const Duration(microseconds: 766446));
    // A service without `ran`: what is left over what is left to score.
    expect(BuildCard.perResidue(_scoring(left: 4384)), const Duration(seconds: 1));
    expect(BuildCard.perResidue(_scoring()), isNull);
  });

  test('the bar carries on at that rate from the scorer\'s count', () {
    final BuildReport report = _scoring(left: 4384, ran: 450); // 1 s a residue
    expect(BuildCard.advance(0, report, Duration.zero), 450);
    expect(BuildCard.advance(450, report, const Duration(seconds: 10)), closeTo(460, 1e-9));
    // Never past the scorer's next line, however long its line is in coming.
    expect(BuildCard.advance(460, report, const Duration(minutes: 5)), 475);
    // A newer count takes over from one that is behind it.
    final BuildReport later = _scoring(scored: 500, left: 4334, ran: 500);
    expect(BuildCard.advance(475, later, Duration.zero), 500);
  });

  test('a finished count, or one with no estimate, stands still', () {
    final BuildReport all = _scoring(scored: 4834, left: 0, ran: 3700);
    expect(BuildCard.advance(4834, all, const Duration(seconds: 30)), 4834);
    expect(BuildCard.advance(450, _scoring(), const Duration(seconds: 30)), 450);
  });
}
