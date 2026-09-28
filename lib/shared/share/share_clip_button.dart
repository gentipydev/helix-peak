import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog/protein_target.dart';
import '../../core/theme/app_spacing.dart';
import 'frame_renderer.dart';
import 'gene_link.dart';
import 'share_action.dart';
import 'video_encoder.dart';

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

/// Makes a flow into a clip and shares it: [painter] drawn offscreen at
/// every frame of [duration] ([FrameRenderer]), encoded to MP4
/// ([VideoEncoder]) and handed to the platform share sheet.
///
/// [painter] is given how far through the clip a frame is, 0 to 1; how that
/// maps onto the flow's own timeline is the caller's to say. Each frame also
/// carries the protein's name and its link, as a poster does, so a clip
/// seen on its own still says what it is.
///
/// Where clips cannot be made — everywhere but Android and iOS — the button
/// is not there at all, and the poster beside it is the way to share.
class ShareClipButton extends StatefulWidget {
  const ShareClipButton({
    required this.target,
    required this.painter,
    required this.duration,
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

  /// Null for the platform's own.
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
  late final VideoEncoder _encoder = widget.encoder ?? VideoEncoder();
  bool _working = false;

  int get _frames {
    final Duration clamped = widget.duration < ClipFormat.shortest
        ? ClipFormat.shortest
        : widget.duration > ClipFormat.longest
        ? ClipFormat.longest
        : widget.duration;
    return (clamped.inMilliseconds * widget.fps / 1000).round();
  }

  Future<void> _export() async {
    final ThemeData theme = Theme.of(context);
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final int total = _frames;
    final ValueNotifier<int> done = ValueNotifier<int>(0);
    final Completer<void> cancel = Completer<void>();
    setState(() => _working = true);

    // The dialog goes on the root navigator, so it is taken off the root
    // navigator too. The lab's routes sit in a shell with a navigator of its
    // own, and popping the nearest one closed the flow's page and left the
    // dialog standing over the picker.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (BuildContext context) => _ExportDialog(
          done: done,
          total: total,
          onCancel: () {
            if (!cancel.isCompleted) {
              cancel.complete();
            }
          },
        ),
      ),
    );

    final FrameRenderer renderer = FrameRenderer(
      painter: (double t) => _Titled(widget.painter(t), widget.target, theme),
      count: total,
      size: widget.size,
      pixelRatio: widget.pixelRatio,
      background: theme.colorScheme.surface,
    );
    final EncodeResult result = await _encoder.encode(
      renderer.frames(),
      widget.fps,
      fileName: '${widget.target.slug}-helix-peek.mp4',
      onFrame: (int n) => done.value = n,
      cancel: cancel.future,
    );
    if (navigator.mounted) {
      navigator.pop();
    }
    done.dispose();
    if (mounted) {
      setState(() => _working = false);
    }

    switch (result) {
      case EncodeSuccess(:final File file):
        try {
          await widget.shareFile(
            file: file,
            mimeType: 'video/mp4',
            text: posterText(widget.target),
            origin: origin,
          );
        } on Object catch (error) {
          debugPrint('helixpeek: could not share a clip ($error)');
          messenger?.showSnackBar(
            const SnackBar(content: Text('The clip could not be shared.')),
          );
        }
      case EncodeFailure(reason: EncodeFailureReason.cancelled):
        break;
      case EncodeFailure(:final EncodeFailureReason reason, :final message):
        messenger?.showSnackBar(
          SnackBar(
            content: Text(message),
            action: reason == EncodeFailureReason.interrupted && mounted
                ? SnackBarAction(label: 'Try again', onPressed: _export)
                : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_encoder.isSupported) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey<String>('share-clip'),
      tooltip: 'Share a clip',
      onPressed: _working ? null : _export,
      icon: const Icon(Icons.movie_outlined),
    );
  }
}

/// Frames counted as they are encoded, and a way to stop.
class _ExportDialog extends StatelessWidget {
  const _ExportDialog({
    required this.done,
    required this.total,
    required this.onCancel,
  });

  final ValueNotifier<int> done;
  final int total;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Making a clip'),
      content: ValueListenableBuilder<int>(
        valueListenable: done,
        builder: (BuildContext context, int n, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LinearProgressIndicator(value: total == 0 ? null : n / total),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Frame $n of $total. Keep the app open until it is done.',
              key: const ValueKey<String>('clip-progress'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

/// One frame of a clip with the protein's name above it and its link below.
class _Titled extends CustomPainter {
  _Titled(this.inner, this.target, this.theme);

  final CustomPainter inner;
  final ProteinTarget target;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    inner.paint(canvas, size);
    final ColorScheme scheme = theme.colorScheme;
    _line(
      canvas,
      size,
      target.display,
      (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurface,
      ),
      top: 24,
    );
    _line(
      canvas,
      size,
      geneLink(target).toString(),
      (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontFamily: 'JetBrainsMono',
        color: scheme.primary,
      ),
      bottom: 24,
    );
  }

  static void _line(
    Canvas canvas,
    Size size,
    String text,
    TextStyle style, {
    double? top,
    double? bottom,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, size.width - 48));
    final double y = top ?? size.height - bottom! - painter.height;
    painter
      ..paint(canvas, Offset((size.width - painter.width) / 2, y))
      ..dispose();
  }

  @override
  bool shouldRepaint(_Titled old) => true;
}
