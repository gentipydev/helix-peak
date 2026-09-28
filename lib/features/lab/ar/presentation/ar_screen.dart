import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/structure/structure_view.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/room_scale.dart';

/// Opens a link outside the app; false where nothing could.
typedef LinkOpener = Future<bool> Function(Uri uri);

/// Every track row of one protein, URL and provenance included: what
/// [TrackClient.tracksOf] reads from `/protein/{slug}/tracks`.
typedef TrackRows = Future<Map<TrackKind, TrackRef>> Function(String slug);

Future<bool> _openOutside(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// `/lab/ar/<slug>`: one protein's fold, and the fold in the reader's room.
class ArRoute extends StatelessWidget {
  const ArRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) =>
        ArScreen(target: target, rows: context.read<TrackClient>().tracksOf),
  );
}

/// The walk's own fold ([StructureView], shared), with a way to stand it in
/// the room at one angstrom to one centimetre.
///
/// The size is the `structure_ar` track's, from its provenance, and is said
/// on screen. That row is read from [rows], not from [target]: a catalog row
/// carries each family's state and no URL or provenance, so the catalog alone
/// would call every ready model unpublished. Room view is Android's Scene
/// Viewer, handed the track's `.glb`: with no ARCore it falls back to a plain
/// 3D view by itself. Where room view cannot open — iOS, whose AR Quick Look
/// half is not built, or a protein whose room-size model is not published —
/// the screen says so in a line instead of offering a button that would do
/// nothing.
class ArScreen extends StatefulWidget {
  const ArScreen({
    required this.target,
    required this.rows,
    this.open = _openOutside,
    this.platform,
    super.key,
  });

  final ProteinTarget target;
  final TrackRows rows;
  final LinkOpener open;

  /// The platform to answer for, or null for the one this is running on.
  final TargetPlatform? platform;

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  late final Future<RoomScale?> _scale = widget
      .rows(widget.target.slug)
      .then(
        (Map<TrackKind, TrackRef> rows) =>
            RoomScale.of(rows[TrackKind.structureAr]),
      );

  @override
  Widget build(BuildContext context) {
    final ProteinTarget target = widget.target;
    return Scaffold(
      appBar: AppBar(title: Text('In your room · ${target.display}')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) =>
                    StructureView(viewport: box.biggest, target: target),
              ),
            ),
            FutureBuilder<RoomScale?>(
              future: _scale,
              builder: (BuildContext context, AsyncSnapshot<RoomScale?> read) =>
                  read.connectionState == ConnectionState.done
                  ? _footer(context, read)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AsyncSnapshot<RoomScale?> read) {
    final ThemeData theme = Theme.of(context);
    final ProteinTarget target = widget.target;
    final RoomScale? scale = read.data;
    final Object? error = read.error;
    final bool android =
        !kIsWeb &&
        (widget.platform ?? defaultTargetPlatform) == TargetPlatform.android;
    final TextStyle? line = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final List<Widget> footer = <Widget>[
      // A failed read is not a missing model, and is not called one.
      if (error != null)
        Text(
          error is ApiException
              ? error.userMessage
              : const UnknownApiException().userMessage,
          key: const ValueKey<String>('room-failed'),
          style: line,
        )
      else if (scale == null)
        Text(
          'The room-size model of ${target.display} is not published yet.',
          key: const ValueKey<String>('room-unavailable'),
          style: line,
        )
      else ...<Widget>[
        Text(
          'Drawn at 1 Å to 1 cm, ${target.display} is '
          '${scale.longestAngstroms.toStringAsFixed(1)} cm across.',
          key: const ValueKey<String>('room-scale'),
          style: theme.textTheme.bodyLarge,
        ),
        if (android)
          FilledButton.icon(
            key: const ValueKey<String>('room-view'),
            onPressed: () => _viewInRoom(context, scale),
            icon: const Icon(Icons.view_in_ar),
            label: const Text('View in your room'),
          )
        else
          Text(
            'Viewing it in your room works on Android for now. Turn the fold '
            'above with a finger.',
            key: const ValueKey<String>('room-unavailable'),
            style: line,
          ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < footer.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            footer[i],
          ],
        ],
      ),
    );
  }

  Future<void> _viewInRoom(BuildContext context, RoomScale scale) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    bool opened;
    try {
      opened = await widget.open(
        scale.sceneViewer(title: widget.target.display),
      );
    } on Object catch (error) {
      debugPrint('helixpeek: could not open Scene Viewer ($error)');
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Scene Viewer did not open. It comes with the Google app.',
          ),
        ),
      );
    }
  }
}
