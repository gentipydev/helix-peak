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
/// | Call       | Arguments                          | Returns                    |
/// |------------|------------------------------------|----------------------------|
/// | `begin`    | width, height, fps, fileName       | session, path, codec       |
/// | `addFrame` | session, rgba (tightly packed)     | nothing                    |
/// | `finish`   | session                            | path of the finished MP4   |
/// | `cancel`   | session                            | nothing; the file is gone  |
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
      // A writer that fails mid-session is not left holding its file.
      if let id { sessions.removeValue(forKey: id)?.cancel() }
      keepScreenOn(!sessions.isEmpty)
      result(FlutterError(
        code: "encode_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func begin(_ args: [String: Any], _ result: FlutterResult) throws {
    let width = args["width"] as? Int ?? 0
    let height = args["height"] as? Int ?? 0
    let fps = args["fps"] as? Int ?? 0
    let fileName = args["fileName"] as? String ?? ""
    // 4:2:0 chroma is one sample per 2x2 block, so both sides must be even.
    if width <= 0 || height <= 0 || width % 2 != 0 || height % 2 != 0 || fps <= 0
      || fileName.isEmpty || fileName.contains("/")
    {
      result(FlutterError(
        code: "bad_args",
        message: "Cannot encode \(width)x\(height) at \(fps) fps to \"\(fileName)\".",
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
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
      result(FlutterError(
        code: "unsupported",
        message: "This device has no H.264 encoder for \(width)x\(height) at \(fps) fps.",
        details: nil))
      return
    }
    let session = try Session(
      id: nextSession, width: width, height: height, fps: fps, url: url,
      writer: writer, settings: settings)
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

  private final class Session {
    let id: Int
    let width: Int
    let height: Int
    let url: URL
    private let fps: Int32
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var frames: Int64 = 0
    private var closed = false

    init(
      id: Int, width: Int, height: Int, fps: Int, url: URL,
      writer: AVAssetWriter, settings: [String: Any]
    ) throws {
      self.id = id
      self.width = width
      self.height = height
      self.fps = Int32(fps)
      self.url = url
      self.writer = writer
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
      let done = DispatchSemaphore(value: 0)
      writer.finishWriting { done.signal() }
      done.wait()
      guard writer.status == .completed else {
        try? FileManager.default.removeItem(at: url)
        throw failure("The clip could not be finished.")
      }
    }

    func cancel() {
      if closed { return }
      closed = true
      if writer.status == .writing { writer.cancelWriting() }
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
