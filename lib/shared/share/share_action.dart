import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog/protein_target.dart';
import 'gene_link.dart';

/// Hands one PNG and a line of text to whatever shares it.
typedef ShareSheet = Future<void> Function({
  required Uint8List png,
  required String fileName,
  required String text,
  Rect? origin,
});

/// The platform's own share sheet, through `share_plus`.
///
/// The PNG is written to the app's temporary directory first: a share sheet
/// hands other apps a file, not bytes.
Future<void> systemShareSheet({
  required Uint8List png,
  required String fileName,
  required String text,
  Rect? origin,
}) async {
  final Directory temporary = await getTemporaryDirectory();
  final File file = File('${temporary.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(png, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'image/png')],
      text: text,
      sharePositionOrigin: origin,
    ),
  );
}

/// Hands one finished file to whatever shares it.
typedef FileShare = Future<void> Function({
  required File file,
  required String mimeType,
  required String text,
  Rect? origin,
});

/// A file already on disk, to the platform's own share sheet.
Future<void> systemShareFile({
  required File file,
  required String mimeType,
  required String text,
  Rect? origin,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: mimeType)],
      text: text,
      sharePositionOrigin: origin,
    ),
  );
}

/// The words that go with a shared clip: the protein's name and its link.
String posterText(ProteinTarget target) =>
    '${target.display} in Helix Peek: ${geneLink(target)}';
