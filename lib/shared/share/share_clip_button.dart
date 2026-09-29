import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/catalog/protein_target.dart';
import 'clip_exporter.dart';
import 'clip_sheet.dart';
import 'frame_renderer.dart';
import 'nv12_packer.dart';
import 'share_action.dart';
import 'video_encoder.dart';

/// Makes a flow into a clip: [painter] drawn offscreen at every frame of
/// [duration] and encoded to MP4, as a job the whole app carries
/// ([ClipExporter]), shown in a sheet ([showClipSheet]) and shared from there.
///
/// [painter] is given how far through the clip a frame is, 0 to 1; how that
/// maps onto the flow's own timeline is the caller's to say. Each frame also
/// carries the protein's name and its link, so a clip seen on its own still
/// says what it is.
///
/// The clip goes on after the sheet is put away and after this button is
/// gone. While this protein's clip is being made the button wears its
/// progress as a ring, and a tap shows the sheet again. While another
/// protein's clip is being made, a tap shows that one's sheet instead of
/// starting a second.
///
/// Where clips cannot be made — everywhere but Android and iOS — the button
/// is not there at all.
class ShareClipButton extends StatefulWidget {
  const ShareClipButton({
    required this.target,
    required this.painter,
    required this.duration,
    this.exporter,
    this.encoder,
    this.shareFile = systemShareFile,
    this.size = const Size(360, 640),
    this.pixelRatio = 3,
    this.fps = ClipFormat.fps,
    super.key,
  });

  final ProteinTarget target;
  final FramePainter painter;

  /// How long the clip runs: [ClipFormat.shortest] to [ClipFormat.longest].
  final Duration duration;

  /// Null for the app's own, the [ClipExporter] above; where there is none,
  /// the button makes its own from [encoder] and [shareFile].
  final ClipExporter? exporter;

  /// Null for the platform's own, packing frames as NV12 where the platform
  /// takes them ([Nv12Packer.forPlatform]).
  final VideoEncoder? encoder;
  final FileShare shareFile;

  /// The logical size a frame is laid out at; times [pixelRatio] it is
  /// [ClipFormat.width] by [ClipFormat.height].
  final Size size;
  final double pixelRatio;
  final int fps;

  @override
  State<ShareClipButton> createState() => _ShareClipButtonState();
}

class _ShareClipButtonState extends State<ShareClipButton> {
  /// The button's own exporter, made only where no other is to be had.
  ClipExporter? _own;

  ClipExporter _exporterOf(BuildContext context) =>
      widget.exporter ??
      context.watch<ClipExporter?>() ??
      (_own ??= ClipExporter(
        encoder: widget.encoder ?? VideoEncoder(nv12: Nv12Packer.forPlatform),
        shareFile: widget.shareFile,
      ));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _open(ClipExporter exporter) {
    final ClipJob? job = exporter.job.value;
    final bool another = job != null && job.target.slug != widget.target.slug;
    // A clip of this protein, or one of another still being made, is shown;
    // otherwise this protein's is started.
    if (job == null || (another && !job.underway)) {
      exporter.start(
        target: widget.target,
        painter: widget.painter,
        duration: widget.duration,
        theme: Theme.of(context),
        size: widget.size,
        pixelRatio: widget.pixelRatio,
        fps: widget.fps,
      );
    }
    unawaited(showClipSheet(context, exporter));
  }

  @override
  Widget build(BuildContext context) {
    final ClipExporter exporter = _exporterOf(context);
    if (!exporter.isSupported) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<ClipJob?>(
      valueListenable: exporter.job,
      builder: (BuildContext context, ClipJob? job, _) => IconButton(
        key: const ValueKey<String>('share-clip'),
        tooltip: 'Share a clip',
        onPressed: () => _open(exporter),
        icon:
            job != null && job.underway && job.target.slug == widget.target.slug
            ? _Ring(progress: job.progress)
            : const Icon(Icons.movie_outlined),
      ),
    );
  }
}

/// The clip's icon inside a ring of its progress. The ring is drawn around
/// the icon without taking room of its own, so the button keeps its size.
class _Ring extends StatelessWidget {
  const _Ring({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: <Widget>[
      const Icon(Icons.movie_outlined),
      Positioned(
        left: -6,
        top: -6,
        right: -6,
        bottom: -6,
        child: CircularProgressIndicator(
          key: const ValueKey<String>('share-clip-progress'),
          value: progress,
          strokeWidth: 2,
          semanticsLabel: 'Making a clip',
        ),
      ),
    ],
  );
}
