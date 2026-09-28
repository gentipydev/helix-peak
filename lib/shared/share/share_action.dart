import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog/protein_target.dart';
import '../../core/network/track_source.dart';
import '../../core/theme/anatomy_colors.dart';
import '../anatomy/anatomy_stages.dart';
import 'fold_still.dart';
import 'gene_link.dart';
import 'poster_builder.dart';

/// Hands one PNG and a line of text to whatever shares it.
typedef ShareSheet = Future<void> Function({
  required Uint8List png,
  required String fileName,
  required String text,
  Rect? origin,
});

/// Draws the fold for a poster, or gives null where it cannot.
typedef FoldRenderer = Future<ui.Image?> Function({
  required ProteinTarget target,
  required TrackSource tracks,
  required AnatomyColors anatomy,
  required int width,
  required int height,
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

/// The words that go with a poster: the protein's name and its link.
String posterText(ProteinTarget target) =>
    '${target.display} in Helix Peek: ${geneLink(target)}';

/// Shares one protein as a poster ([PosterBuilder]) through the platform
/// share sheet.
///
/// The poster is made when the button is pressed, not before, and the button
/// shows it is working while it is: the fold alone can take a second the
/// first time a process draws it.
class SharePosterButton extends StatefulWidget {
  const SharePosterButton({
    required this.target,
    required this.model,
    this.shareSheet = systemShareSheet,
    this.renderFold = renderFoldStill,
    super.key,
  });

  final ProteinTarget target;
  final AnatomyModel model;
  final ShareSheet shareSheet;
  final FoldRenderer renderFold;

  @override
  State<SharePosterButton> createState() => _SharePosterButtonState();
}

class _SharePosterButtonState extends State<SharePosterButton> {
  bool _working = false;

  Future<void> _share() async {
    final ThemeData theme = Theme.of(context);
    final TrackSource? tracks = context.read<TrackSource?>();
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    setState(() => _working = true);
    ui.Image? fold;
    try {
      final PosterBuilder poster = PosterBuilder(
        target: widget.target,
        model: widget.model,
        theme: theme,
      );
      if (tracks != null) {
        // Drawn at twice the poster's pixels: the fold is framed for any
        // turn and fills about a third of its render, so it is cut down to
        // the molecule ([trimToContent]) and scaled up to the box. Twice
        // over, it arrives near the poster's own resolution.
        final Rect foldBox = poster.foldBox;
        fold = await widget.renderFold(
          target: widget.target,
          tracks: tracks,
          anatomy: theme.extension<AnatomyColors>() ?? AnatomyColors.dark,
          width: (foldBox.width * poster.pixelRatio * 2).round(),
          height: (foldBox.height * poster.pixelRatio * 2).round(),
        );
      }
      final Uint8List png = await poster.build(fold: fold);
      await widget.shareSheet(
        png: png,
        fileName: '${widget.target.slug}-helix-peek.png',
        text: posterText(widget.target),
        origin: origin,
      );
    } on Object catch (error) {
      debugPrint('helixpeek: could not share a poster ($error)');
      messenger?.showSnackBar(
        const SnackBar(content: Text('The poster could not be made.')),
      );
    } finally {
      fold?.dispose();
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('share-poster'),
      tooltip: 'Share a poster',
      onPressed: _working ? null : _share,
      icon: _working
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share),
    );
  }
}
