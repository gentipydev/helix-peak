import Flutter

/// The iOS half of `ClipKeepAlive` (`lib/shared/share/clip_keep_alive.dart`),
/// on the channel Android answers with a foreground service.
///
/// Nothing may draw in the background on an iPhone: Flutter turns the GPU off
/// when the app leaves, and iOS offers background GPU time to no iPhone. So
/// here a clip does not go on while the app is away; it pauses with it, and
/// `VideoEncoderChannel` finishes the part in hand. `begin` says so, and
/// `progress` and `end` have nothing to do.
final class ClipKeepAliveChannel {
  static let name = "helixpeak/share/clip_keepalive"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: ClipKeepAliveChannel.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "begin":
        result("pauses")
      case "progress", "end":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
