import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'video_encoder.dart';

/// Keeps a clip going while the app is away, where the platform can: on
/// Android a foreground service with the clip's progress in a notification
/// and a wake lock (`ClipExportService.kt`), on channel
/// `helixpeak/share/clip_keepalive`.
///
/// Where nothing answers on the other side (iOS, a desktop, a test), [begin]
/// says [ClipAway.stops] and the rest does nothing.
final class ClipKeepAlive {
  ClipKeepAlive({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  /// Namespaced to the app and the feature.
  static const MethodChannel defaultChannel = MethodChannel(
    'helixpeak/share/clip_keepalive',
  );

  /// The least time between two progress updates; the notification cannot
  /// show more, and Android drops them.
  static const Duration progressEvery = Duration(milliseconds: 250);

  final MethodChannel _channel;
  VoidCallback? _onCancel;
  VoidCallback? _onStopped;
  final Stopwatch _sinceProgress = Stopwatch();

  /// Starts keeping a clip of [title], [total] frames, going, and says what
  /// becomes of it when the reader leaves the app.
  ///
  /// [onCancel] hears the reader stop the clip from outside the app (its
  /// notification); [onStopped] hears the platform stop keeping it going
  /// (its time was up, or the app was swiped away).
  Future<ClipAway> begin({
    required String title,
    required int total,
    VoidCallback? onCancel,
    VoidCallback? onStopped,
  }) async {
    _onCancel = onCancel;
    _onStopped = onStopped;
    _sinceProgress
      ..reset()
      ..start();
    _channel.setMethodCallHandler(_heard);
    try {
      final String? kept = await _channel.invokeMethod<String>(
        'begin',
        <String, Object>{'title': title, 'total': total},
      );
      return kept == 'goes_on' ? ClipAway.goesOn : ClipAway.stops;
    } on MissingPluginException {
      return ClipAway.stops;
    } on PlatformException catch (error) {
      debugPrint('helixpeek: a clip could not be kept going ($error)');
      return ClipAway.stops;
    }
  }

  /// How far the clip has got, at most every [progressEvery], and always
  /// its last frame.
  void progress({
    required String title,
    required int done,
    required int total,
  }) {
    if (done < total && _sinceProgress.elapsed < progressEvery) {
      return;
    }
    _sinceProgress
      ..reset()
      ..start();
    unawaited(
      _quietly('progress', <String, Object>{
        'title': title,
        'done': done,
        'total': total,
      }),
    );
  }

  /// Stops keeping the clip going. A clip that is [ready] while the app is
  /// away is said by the platform too, where it can.
  Future<void> end({required String title, required bool ready}) async {
    _onCancel = null;
    _onStopped = null;
    _sinceProgress.stop();
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    await _quietly('end', <String, Object>{
      'title': title,
      'ready': ready,
      'inFront': state == null || state == AppLifecycleState.resumed,
    });
  }

  Future<Object?> _heard(MethodCall call) async {
    switch (call.method) {
      case 'cancel':
        _onCancel?.call();
      case 'stopped':
        _onStopped?.call();
    }
    return null;
  }

  Future<void> _quietly(String method, Map<String, Object> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Nothing keeps clips going here.
    } on PlatformException catch (error) {
      debugPrint('helixpeek: $method on a kept clip failed ($error)');
    }
  }
}
