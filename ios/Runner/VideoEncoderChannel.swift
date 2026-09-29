import AVFoundation
import Accelerate
import Flutter
import UIKit

/// Encodes a clip to MP4, one frame per call, for `VideoEncoder` in
/// `lib/features/lab/share/video_encoder.dart`.
///
/// The iOS half of `VideoEncoderChannel.kt`, with the same calls on the same
/// channel. The recipe is the one `docs/video-encoding-spike.md` asked an iOS
/// run to check: `AVAssetWriter` (H.264) fed `kCVPixelFormatType_32BGRA`
/// buffers from its pixel-buffer adaptor's pool, BT.709 tagged on the stream.
/// No third-party encoder.
///
/// | Call       | Arguments                            | Returns                    |
/// |------------|--------------------------------------|----------------------------|
/// | `begin`    | width, height, fps, fileName, format | session, path, codec       |
/// | `addFrame` | session, rgba (tightly packed)       | nothing                    |
/// | `pause`    | session                              | frames in finished parts   |
/// | `finish`   | session                              | path of the finished MP4   |
/// | `cancel`   | session                              | nothing; the file is gone  |
///
/// Frames arrive as `rgba` only: the NV12 that Android takes from `Nv12Packer`
/// is not sent here, and a session asked for it is refused as `bad_args`.
///
/// A clip is written in parts, because nothing on iOS may draw or encode in
/// the background and a writer left open there fails. When the app leaves,
/// the Dart side asks for `pause`: the part in hand is finished and closed,
/// and the frames in finished parts are counted back. The next frame starts
/// another part, and `finish` joins them without encoding anything again
/// (a passthrough export; every part starts on a keyframe). A part that
/// cannot be finished is dropped, and its frames are not counted, so the
/// Dart side draws them again.
///
/// The handler runs on a background task queue: serial, so one session's calls
/// stay in order, and never on the platform thread. A session keeps the screen
/// on from `begin` to `finish` or `cancel`.
///
/// Failures come back as error codes: `unsupported` where the writer takes no
/// H.264 at the size, `bad_args` for a call the Dart side should never make,
/// and `encode_failed` for anything the writer reports.
final class VideoEncoderChannel {
  static let name = "helixpeak/share/video_encoder"

  private let channel: FlutterMethodChannel
  private var sessions: [Int: Session] = [:]
  private var nextSession = 1

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: VideoEncoderChannel.name,
      binaryMessenger: messenger,
      codec: FlutterStandardMethodCodec.sharedInstance(),
      taskQueue: messenger.makeBackgroundTaskQueue?()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let id = args["session"] as? Int
    do {
      switch call.method {
      case "begin":
        try begin(args, result)
      case "addFrame":
        guard let session = sessionOf(id, result) else { return }
        guard let rgba = args["rgba"] as? FlutterStandardTypedData,
          rgba.data.count == session.width * session.height * 4
        else {
          result(FlutterError(
            code: "bad_args",
            message: "A frame is not \(session.width)x\(session.height) RGBA.",
            details: nil))
          return
        }
        try session.addFrame(rgba.data)
        result(nil)
      case "pause":
        guard let session = sessionOf(id, result) else { return }
        // The app is leaving: finish the part before it is suspended.
        let work = BackgroundWork("helixpeek.clip.part")
        let kept = session.pause()
        work.end()
        result(Int(kept))
      case "finish":
        guard let session = sessionOf(id, result) else { return }
        sessions[session.id] = nil
        keepScreenOn(!sessions.isEmpty)
        try session.finish()
        result(session.url.path)
      case "cancel":
        if let id { sessions.removeValue(forKey: id)?.cancel() }
        keepScreenOn(!sessions.isEmpty)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      // A writer that fails mid-session is not left holding its files.
      if let id { sessions.removeValue(forKey: id)?.cancel() }
      keepScreenOn(!sessions.isEmpty)
      // The details carry the whole error, domain and code and all, for a
      // log; the message is the one sentence the Dart side may show.
      result(FlutterError(
        code: "encode_failed", message: error.localizedDescription,
        details: String(describing: error)))
    }
  }

  private func begin(_ args: [String: Any], _ result: FlutterResult) throws {
    let width = args["width"] as? Int ?? 0
    let height = args["height"] as? Int ?? 0
    let fps = args["fps"] as? Int ?? 0
    let fileName = args["fileName"] as? String ?? ""
    let format = args["format"] as? String ?? "rgba"
    // 4:2:0 chroma is one sample per 2x2 block, so both sides must be even.
    if width <= 0 || height <= 0 || width % 2 != 0 || height % 2 != 0 || fps <= 0
      || fileName.isEmpty || fileName.contains("/") || format != "rgba"
    {
      result(FlutterError(
        code: "bad_args",
        message: "Cannot encode \(format) \(width)x\(height) at \(fps) fps to \"\(fileName)\".",
        details: nil))
      return
    }
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: width * height * fps / 8,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
      // BT.709 on the stream, as Android tags it; the writer converts the
      // BGRA it is given to limited-range YCbCr through this matrix.
      AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ],
    ]
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let url = caches.appendingPathComponent(fileName)
    try? FileManager.default.removeItem(at: url)
    let probe = try AVAssetWriter(outputURL: url, fileType: .mp4)
    guard probe.canApply(outputSettings: settings, forMediaType: .video) else {
      result(FlutterError(
        code: "unsupported",
        message: "This device has no H.264 encoder for \(width)x\(height) at \(fps) fps.",
        details: nil))
      return
    }
    let session = try Session(
      id: nextSession, width: width, height: height, fps: fps, url: url,
      settings: settings)
    nextSession += 1
    sessions[session.id] = session
    keepScreenOn(true)
    result(["session": session.id, "path": url.path, "codec": "AVAssetWriter H.264"])
  }

  private func sessionOf(_ id: Int?, _ result: FlutterResult) -> Session? {
    guard let id, let session = sessions[id] else {
      result(FlutterError(
        code: "bad_args", message: "No encoding session \(id.map(String.init) ?? "nil").",
        details: nil))
      return nil
    }
    return session
  }

  private func keepScreenOn(_ on: Bool) {
    DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
  }

  private struct EncodeError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
  }

  /// Time asked of iOS to finish something as the app leaves. It is ended when
  /// the work is, or by iOS when its time is up.
  private final class BackgroundWork {
    private var task: UIBackgroundTaskIdentifier = .invalid

    init(_ name: String) {
      task = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
        self?.end()
      }
    }

    func end() {
      guard task != .invalid else { return }
      UIApplication.shared.endBackgroundTask(task)
      task = .invalid
    }
  }

  /// One clip, written in parts ([Part]) and joined when it is finished.
  private final class Session {
    let id: Int
    let width: Int
    let height: Int
    let url: URL
    private let fps: Int32
    private let settings: [String: Any]

    /// The part being written, if any.
    private var part: Part?

    /// The parts finished so far, in order.
    private var parts: [Part] = []
    private var closed = false

    init(
      id: Int, width: Int, height: Int, fps: Int, url: URL, settings: [String: Any]
    ) throws {
      self.id = id
      self.width = width
      self.height = height
      self.fps = Int32(fps)
      self.url = url
      self.settings = settings
      // The first part is opened now, so a writer that will not start fails
      // `begin` rather than the first frame.
      part = try nextPart()
    }

    /// Frames in finished parts.
    var kept: Int64 { parts.reduce(0) { $0 + $1.frames } }

    func addFrame(_ rgba: Data) throws {
      let writing = try part ?? nextPart()
      part = writing
      try writing.addFrame(rgba)
    }

    /// Finishes the part in hand, if it has frames, and says how many frames
    /// the finished parts hold. A part that cannot be finished is dropped.
    func pause() -> Int64 {
      if let open = part {
        part = nil
        if open.frames > 0, (try? open.finish()) != nil {
          parts.append(open)
        } else {
          open.cancel()
        }
      }
      return kept
    }

    func finish() throws {
      _ = pause()
      closed = true
      guard !parts.isEmpty else { throw EncodeError("There were no frames to finish.") }
      try? FileManager.default.removeItem(at: url)
      if parts.count == 1 {
        try FileManager.default.moveItem(at: parts[0].url, to: url)
      } else {
        defer { for part in parts { try? FileManager.default.removeItem(at: part.url) } }
        try join()
      }
    }

    func cancel() {
      if closed { return }
      closed = true
      part?.cancel()
      part = nil
      for finished in parts { try? FileManager.default.removeItem(at: finished.url) }
      parts = []
      try? FileManager.default.removeItem(at: url)
    }

    private func nextPart() throws -> Part {
      let name = url.deletingPathExtension().lastPathComponent
      let partURL = url.deletingLastPathComponent()
        .appendingPathComponent("\(name).part\(parts.count + 1).mp4")
      return try Part(
        url: partURL, width: width, height: height, fps: fps, settings: settings)
    }

    /// The parts, one after another, as one MP4 at [url]: their samples are
    /// copied as they are, so nothing is encoded again.
    private func join() throws {
      let composition = AVMutableComposition()
      guard
        let track = composition.addMutableTrack(
          withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { throw EncodeError("The clip's parts could not be joined.") }
      // A track does not keep its asset alive, and one whose asset is gone
      // cannot be inserted (-11800, -12780), so the parts' assets are held
      // until the export is done.
      let assets = parts.map { AVURLAsset(url: $0.url) }
      var at = CMTime.zero
      for (asset, part) in zip(assets, parts) {
        guard let source = asset.tracks(withMediaType: .video).first
        else { throw EncodeError("A part of the clip had no video.") }
        let length = CMTime(value: part.frames, timescale: fps)
        try track.insertTimeRange(
          CMTimeRange(start: .zero, duration: length), of: source, at: at)
        at = CMTimeAdd(at, length)
      }
      guard
        let export = AVAssetExportSession(
          asset: composition, presetName: AVAssetExportPresetPassthrough)
      else { throw EncodeError("The clip's parts could not be joined.") }
      export.outputURL = url
      export.outputFileType = .mp4
      let done = DispatchSemaphore(value: 0)
      export.exportAsynchronously { done.signal() }
      done.wait()
      withExtendedLifetime(assets) {}
      guard export.status == .completed else {
        try? FileManager.default.removeItem(at: url)
        if let error = export.error { throw error }
        throw EncodeError("The clip's parts could not be joined.")
      }
    }
  }

  /// One stretch of a clip in its own MP4, every frame at its own time from
  /// the part's start.
  private final class Part {
    let url: URL
    private(set) var frames: Int64 = 0
    private let width: Int
    private let height: Int
    private let fps: Int32
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var closed = false

    init(url: URL, width: Int, height: Int, fps: Int32, settings: [String: Any]) throws {
      self.url = url
      self.width = width
      self.height = height
      self.fps = fps
      try? FileManager.default.removeItem(at: url)
      writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
      input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
      input.expectsMediaDataInRealTime = false
      adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
          kCVPixelBufferWidthKey as String: width,
          kCVPixelBufferHeightKey as String: height,
        ])
      writer.add(input)
      guard writer.startWriting() else {
        try? FileManager.default.removeItem(at: url)
        throw EncodeError(writer.error?.localizedDescription ?? "The writer did not start.")
      }
      writer.startSession(atSourceTime: .zero)
    }

    func addFrame(_ rgba: Data) throws {
      // Encoding is slower than the calls arrive only rarely; wait for room
      // rather than drop a frame, and give up if the writer has failed.
      while !input.isReadyForMoreMediaData {
        if writer.status != .writing { throw failure("The writer stopped.") }
        usleep(1000)
      }
      guard let pool = adaptor.pixelBufferPool else {
        throw failure("The writer gave no pixel buffers.")
      }
      var made: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made)
      guard let buffer = made else { throw failure("No pixel buffer was free.") }
      try writeBgra(rgba, into: buffer)
      // Each frame carries its own time, frame / fps s, not its arrival
      // time: rendering is slower than real time.
      let time = CMTime(value: frames, timescale: fps)
      guard adaptor.append(buffer, withPresentationTime: time) else {
        throw failure("A frame could not be written.")
      }
      frames += 1
    }

    func finish() throws {
      closed = true
      input.markAsFinished()
      // The last frame lasts a frame too, so parts join without a gap.
      writer.endSession(atSourceTime: CMTime(value: frames, timescale: fps))
      let done = DispatchSemaphore(value: 0)
      writer.finishWriting { done.signal() }
      done.wait()
      guard writer.status == .completed else {
        try? FileManager.default.removeItem(at: url)
        throw failure("The clip could not be finished.")
      }
    }

    func cancel() {
      if !closed {
        closed = true
        if writer.status == .writing { writer.cancelWriting() }
      }
      try? FileManager.default.removeItem(at: url)
    }

    private func failure(_ fallback: String) -> EncodeError {
      EncodeError(writer.error?.localizedDescription ?? fallback)
    }

    /// Flutter's `rawRgba` into the pool's BGRA buffer.
    ///
    /// - In: R, G, B, A bytes per pixel, rows packed with no padding (row
    ///   stride = width x 4). Frames are opaque, so alpha is kept as it is.
    /// - Out: B, G, R, A, and a row can be wider than width x 4, so the copy
    ///   goes through the buffer's own `bytesPerRow`, never an assumed one.
    private func writeBgra(_ rgba: Data, into buffer: CVPixelBuffer) throws {
      CVPixelBufferLockBaseAddress(buffer, [])
      defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
      guard let base = CVPixelBufferGetBaseAddress(buffer) else {
        throw failure("A pixel buffer had no memory.")
      }
      var copied: vImage_Error = kvImageNoError
      rgba.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
        var from = vImage_Buffer(
          data: UnsafeMutableRawPointer(mutating: source.baseAddress!),
          height: vImagePixelCount(height), width: vImagePixelCount(width),
          rowBytes: width * 4)
        var to = vImage_Buffer(
          data: base, height: vImagePixelCount(height), width: vImagePixelCount(width),
          rowBytes: CVPixelBufferGetBytesPerRow(buffer))
        let swap: [UInt8] = [2, 1, 0, 3]
        copied = vImagePermuteChannels_ARGB8888(&from, &to, swap, vImage_Flags(kvImageNoFlags))
      }
      if copied != kvImageNoError { throw failure("A frame could not be converted.") }
    }
  }
}
