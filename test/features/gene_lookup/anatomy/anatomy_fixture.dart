import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_record.dart';

/// The parsed NG_007114 payload the widget tests already use.
Map<String, dynamic> insulinJson() =>
    jsonDecode(File('assets/mock/gene_ins.json').readAsStringSync())
        as Map<String, dynamic>;

GeneRecord insulin() => GeneRecordDto.fromJson(insulinJson()).toEntity();

/// The same record with parts removed, for the "the stage list is derived"
/// tests. Editing the fixture rather than hand-writing a record keeps the
/// contrasting genes honest — they are real GenBank shapes, minus a feature.
GeneRecord insulinWithout({
  bool introns = false,
  bool cds = false,
  bool proprotein = false,
  bool splitProprotein = false,
  bool maturePeptides = false,
}) {
  final Map<String, dynamic> json = insulinJson();
  if (introns) {
    json['exons'] = <dynamic>[(json['exons']! as List<dynamic>).first];
    json['transcript'] = null;
  }
  if (cds) {
    json['protein'] = null;
  }
  if (proprotein) {
    json['proprotein'] = null;
  }
  if (splitProprotein) {
    // A hole punched in the middle of the proprotein, which is what a record
    // whose proprotein is not simply its precursor minus a leader looks like.
    // Nothing in GenBank forbids it, and the precursor page cannot draw it as
    // two named stretches, so the two stages have to stay two.
    final List<dynamic> segments =
        (json['proprotein']! as Map<String, dynamic>)['segments']!
            as List<dynamic>;
    (segments.first as Map<String, dynamic>)['end'] = 5350;
  }
  if (maturePeptides) {
    json['peptides'] = <dynamic>[];
  }
  return GeneRecordDto.fromJson(json).toEntity();
}

/// The app's real fonts, for a test that measures text rather than finding it.
///
/// Without this a widget test lays out in the test font, where every glyph is a
/// square of the point size — near enough for `find.text`, and nowhere near
/// enough to ask whether a sentence fits the box the header gives it.
Future<void> loadAppFonts() async {
  const Map<String, List<String>> families = <String, List<String>>{
    'SpaceGrotesk': <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ],
    'JetBrainsMono': <String>[
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Medium.ttf',
    ],
  };

  TestWidgetsFlutterBinding.ensureInitialized();
  for (final MapEntry<String, List<String>> family in families.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String path in family.value) {
      loader.addFont(
        Future<ByteData>.value(
          ByteData.view(File(path).readAsBytesSync().buffer),
        ),
      );
    }
    await loader.load();
  }
}
