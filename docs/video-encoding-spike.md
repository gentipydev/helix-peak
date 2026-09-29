# Video encoding spike

Playbook question: "Does native encoding work end to end?" (feature 12, Share
clips). Asked before session 22 so the share feature is not designed around an
encoder that does not exist. Run on 2026-09-26; the throwaway app has been
deleted.

| Platform | Answer | Evidence |
|---|---|---|
| Android | **Works.** MediaCodec plus MediaMuxer, no third-party package. | Measured on one device, below. |
| iOS | **Works on the simulator.** AVAssetWriter, no third-party package. | Run 2026-09-28 on the iOS simulator, below. Not yet on a phone. |

So the go/no-go is half answered. Before session 22 is designed, pick one:
run the iOS half on a Mac (the checks it must make are at the end), ship clips
on Android and posters only on iOS, or ship posters only.

## What ran

A throwaway Flutter app with the toolchain this repo uses (Flutter 3.47.5, AGP
9.1.0, Kotlin 2.4.0, Gradle 9.3.1). It drove the channel below from an
integration test, on a Galaxy S21 Ultra (SM-G998N, Exynos 2100) running
Android 15 (API 35). The encoder that `MediaCodecList.findEncoderForFormat`
chose was `c2.exynos.h264.encoder`, a hardware encoder.

The test rendered each frame with `PictureRecorder` and `Picture.toImage`,
read it back with `toByteData(format: ImageByteFormat.rawRgba)`, and sent it
to the native side. The MP4 was then read back through paths that share
nothing with the encoder: `MediaExtractor` and `MediaMetadataRetriever` on the
phone, and FFmpeg 8 (libavcodec 62.28, through PyAV) on the PC.

## The channel design tested

One `MethodChannel`, `helixpeak/share/video_encoder`, whose handler runs on
`binaryMessenger.makeBackgroundTaskQueue()`. It is serial, so one session's
calls stay in order, and nothing runs on the platform thread.

| Call | Arguments | Returns |
|---|---|---|
| `begin` | width, height, fps, file name | session id, codec name |
| `addFrame` | session id, RGBA bytes (`Uint8List`) | nothing the caller needs |
| `finish` | session id | path of the MP4 |
| `cancel` | session id | nothing |

Failures come back as `PlatformException` codes. `unsupported` means no
encoder accepts the format (`findEncoderForFormat` returned null), and
`encode_failed` covers everything else. The Dart side can turn these into the
clear failure session 22 asks for.

Frames cross one call at a time because one 1080×1920 RGBA frame is 8,294,400
bytes.

## Pixel-format conversion, Android

| Stage | Format |
|---|---|
| Flutter hands over | `rawRgba`: R, G, B, A bytes, tightly packed (row stride = width × 4), alpha premultiplied (irrelevant for opaque frames). Checked byte for byte: `#1E88E5` read back as `30 136 229 255`. |
| Codec asked for | `COLOR_FormatYUV420Flexible`. The configured input format stayed flexible (`0x7F420888`), stride 1080, slice height 1920. |
| Codec handed back (`getInputImage`) | Y: pixel stride 1, row stride 1080. U and V: pixel stride 2, row stride 1080. That is semi-planar (interleaved chroma), not I420. |
| Conversion | RGB to YCbCr with the BT.709 matrix, limited range (Y 16–235, Cb/Cr 16–240). Chroma is the average of each 2×2 block, and alpha is dropped. |
| Stream tagged | `KEY_COLOR_STANDARD` BT.709, `KEY_COLOR_RANGE` limited, `KEY_COLOR_TRANSFER` SDR video. The tags reach the file: `MediaExtractor` reads them back, and FFmpeg reports colorspace, primaries and trc as BT.709 with range tv. |

Write through the `Image` planes' `pixelStride` and `rowStride`, never an
assumed layout. With flexible input the codec chooses between semi-planar and
planar and may pad rows. This encoder happened not to pad 1080 (not a multiple
of 16), and another encoder may. The integer coefficients that produced the
colours below (x256, BT.709 scaled by 219/255 for luma and 224/255 for chroma):

```kotlin
y = 16  + (( 47 * r + 157 * g +  16 * b + 128) shr 8)
u = 128 + ((-26 * r -  86 * g + 112 * b + 128) shr 8)   // u, v from the 2×2 average
v = 128 + ((112 * r - 102 * g -  10 * b + 128) shr 8)
```

Feed each frame to `queueInputBuffer` with its own presentation time,
`frame * 1_000_000 / fps` µs. Don't rely on arrival time.

## Results

| Run | File | Decoded back |
|---|---|---|
| 10 frames of solid `#1E88E5` (30, 136, 229), 1080×1920, 30 fps | 1,996 bytes; H.264 High, level 4.0; 10 samples at 0, 33,333 … 300,000 µs; 333 ms; 1 keyframe | Android: (30, 135, 227) at the centre and the corner, first and last frame. FFmpeg: (29, 134, 226). |
| 150 frames, one hue per frame, same size and rate | 559,074 bytes; 150 samples; 5.0 s; 5 keyframes | First and last frames decode to their own hues on both decoders, so order holds and the tail is not dropped. |

## Timings

Profile build, app in the foreground, 150 frames at 1080×1920. Figures are
means per frame.

| Step | ms |
|---|---|
| Render (`Picture.toImage`) | 1.6 |
| Read back (`toByteData`) | 5.1 |
| Channel call, total | 57 |
| – of which RGBA to YUV in Kotlin | 42 |
| – of which encoder queue and drain | 2 |
| – so moving 8.3 MB across the channel costs about | 13 |
| **Whole frame** | **64** |

That is about 2.1× slower than real time. A 5 s clip took 9.8 s, so a 15 s
clip would take about 29 s. The per-pixel Kotlin loop is most of it. In the
first run of each launch the conversion took 62–83 ms a frame while the JIT
warmed up.

## Surprises

1. **The planned Dart API cannot hold a real clip.** Session 22 specifies
   `encode(List<ui.Image> frames, int fps)`, and session 21's `FrameRenderer`
   returns a `List<ui.Image>`. At 1080×1920, 15 s × 30 fps is 450 images at
   8.3 MB each, or 3.7 GB; even 5 s is 1.2 GB. The spike rendered, read
   back, sent and disposed one frame at a time and never held more than one.
   Sessions 21 and 22 should stream: a frame builder (`int → ui.Image`) or a
   `Stream<ui.Image>`, not a list.
2. **Export needs the app in the foreground.**
   - Started with the phone locked: the encoder was created, then nothing
     more happened for 5 minutes. The test's own 3-minute timeout never
     fired either.
   - Sent Home in the middle of the 150-frame run with the screen on: the
     clip finished only after the app came back. It took 44 s instead of
     10 s. The Kotlin conversion went from 42 to 239 ms a frame, and render
     plus read-back went from 7 to 19 ms.
   - Samsung's freezer marked the app "important" throughout, so nothing was
     killed. It just crawled.

   Keep the screen on during export, and either pause and resume or cancel on
   `AppLifecycleState.paused`.
3. **The encoder picked H.264 High profile** (level 4.0) without being asked.
   Every current phone and messaging app plays it; the note matters only if a
   Baseline-only target turns up.
4. **`flutter test` on a device over wireless adb never connected** to the
   test's VM service (twice: "Connection closed before full header was
   received"). The app itself started fine. The way that worked was
   `flutter build apk --profile -t integration_test/<test>.dart`, installing
   it, launching it with `am start` and reading the results from logcat.

## iOS: what a run must answer

None of this was run. It is the design session 22 names, and what the Android
run suggests to check:

- `AVAssetWriter` with `AVAssetWriterInputPixelBufferAdaptor`, fed
  `kCVPixelFormatType_32BGRA` pixel buffers from the adaptor's pool. Flutter's
  RGBA must be swizzled to BGRA (swap bytes 0 and 2).
- A `CVPixelBuffer`'s `bytesPerRow` can be wider than width × 4. Copy row by
  row, as on Android.
- Tag the output BT.709 (`AVVideoColorPropertiesKey`) and check the decoded
  colour, as the Android test did.
- The same ten-frame test, the same 150-frame timing, and the same background
  check: iOS suspends a backgrounded app sooner than Android throttles it.

## iOS: what ran (2026-09-28)

`ios/Runner/VideoEncoderChannel.swift`, the design above: the same channel and
calls as Android, on a background task queue. `AVAssetWriter` to MP4 (H.264
High, auto level), fed from an `AVAssetWriterInputPixelBufferAdaptor` pool of
`kCVPixelFormatType_32BGRA` buffers. RGBA becomes BGRA with
`vImagePermuteChannels_ARGB8888`, written through the buffer's own
`bytesPerRow`. The writer does the BGRA to YCbCr conversion itself, through the
BT.709 matrix the output settings tag (`AVVideoColorPropertiesKey`). Each
frame's time is `frame / fps`.

A throwaway entry point (since deleted) drove `VideoEncoder` in a debug build
on the iPhone 17 simulator (iOS 26, on an Apple-silicon Mac). The MP4s were
copied out and decoded by a separate `AVAssetReader` script on the Mac.

| Run | Decoded back |
|---|---|
| 10 frames of solid `#1E88E5` (30, 136, 229), 1080×1920, 30 fps | 3,862 bytes; H.264, 1080×1920, 0.333 s; 10 frames at 0 … 0.3 s; primaries, transfer and matrix ITU-R 709, limited range; (30, 135, 229) at the centre, first and last frame |
| 150 frames, one hue per frame | 258,648 bytes; 150 frames at 0 … 4.967 s, 5.0 s; first frame (254, 1, 0), last (254, 0, 10), the 357.6° hue it was given |

The 150 frames took 1.46 s end to end, about 10 ms a frame, but that is the
Mac's hardware under the simulator and says nothing about a phone.

Still open, and needing a phone: the timing, and the background check. The
Dart side cancels on `AppLifecycleState.paused` on every platform, so a clip
sent Home is stopped and deleted either way; what a phone does in the
moment before is not measured.

## Follow-up: NV12 on the GPU (2026-09-29)

The timings above put 55 of the 64 ms a frame in the Kotlin RGBA-to-YUV loop
and in moving 8.3 MB across the channel. On Android, frames now cross as
NV12 instead:

- `shaders/nv12_pack.frag` packs a drawn frame into a (W/4) x (3H/2) image,
  four bytes a pixel, which reads back as one NV12 frame: luma, then Cb and
  Cr interleaved. It uses the integer coefficients above, so its bytes are
  the Kotlin loop's. It is drawn with `BlendMode.src`, because the alpha
  byte carries data too.
- `Nv12Packer` checks the shader once per launch against `nv12Reference`, the
  same formula in Dart, on an 8x4 frame whose pixels all differ. A device
  where they disagree (orientation, precision, a format that drops a byte)
  keeps the RGBA path.
- `writeNv12` in `VideoEncoderChannel.kt` copies luma a row at a time
  through the plane's `rowStride`. Chroma is copied a row at a time too when
  the codec is semi-planar with U first, which it tests by writing through U
  and reading back through V; any other layout takes a sample at a time.
- The Dart side draws and reads back frame n + 1 while the platform encodes
  frame n, with at most one call in flight.

iOS stays on RGBA. There, `Picture.toImage` renders in the layer's format,
which is `BGRA10_XR` on a wide-gamut iPhone (`FLTEnableWideGamut` is unset,
and it defaults to on), and vImage already does the swizzle quickly.

To time it, build `flutter build apk --profile --dart-define=CLIP_TIMING=true`.
Each finished clip then shows its time per frame, step by step, in a
snackbar and in the log. Add `--dart-define=CLIP_NV12=false` for the same
build on RGBA. The measurements are still to be taken on a phone.
