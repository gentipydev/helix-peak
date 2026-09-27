import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/structure/structure_view.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/room_scale.dart';

/// Opens a link outside the app; false where nothing could.
typedef LinkOpener = Future<bool> Function(Uri uri);

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
        ArScreen(target: target),
  );
}

/// The walk's own fold ([StructureView], shared), with a way to stand it in
/// the room at one angstrom to one centimetre.
///
/// The size is the `structure_ar` track's, from its provenance, and is said
/// on screen. Room view is Android's Scene Viewer, handed the track's `.glb`:
/// with no ARCore it falls back to a plain 3D view by itself. Where room view
/// cannot open — iOS, whose AR Quick Look half is not built, or a protein
/// whose room-size model is not published — the screen says so in a line
/// instead of offering a button that would do nothing.
class ArScreen extends StatelessWidget {
  const ArScreen({
    required this.target,
    this.open = _openOutside,
    this.platform,
    super.key,
  });

  final ProteinTarget target;
  final LinkOpener open;

  /// The platform to answer for, or null for the one this is running on.
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RoomScale? scale = RoomScale.of(target.tracks[TrackKind.structureAr]);
    final bool android =
        !kIsWeb &&
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    final TextStyle? line = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final List<Widget> footer = <Widget>[
      if (scale != null)
        Text(
          'Drawn at 1 Å to 1 cm, ${target.display} is '
          '${scale.longestAngstroms.toStringAsFixed(1)} cm across.',
          key: const ValueKey<String>('room-scale'),
          style: theme.textTheme.bodyLarge,
        ),
      if (scale == null)
        Text(
          'The room-size model of ${target.display} is not published yet.',
          key: const ValueKey<String>('room-unavailable'),
          style: line,
        )
      else if (android)
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
    ];

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
            Padding(
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewInRoom(BuildContext context, RoomScale scale) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    bool opened;
    try {
      opened = await open(scale.sceneViewer(title: target.display));
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
