# Video encoding spike

Playbook question: "Does native encoding work end to end?" (feature 12, Share
clips). Asked before session 22 so the share feature is not designed around an
encoder that does not exist. Run on 2026-09-26; the throwaway app has been
deleted.

| Platform | Answer | Evidence |
|---|---|---|
| Android | **Works.** MediaCodec plus MediaMuxer, no third-party package. | Measured on one device, below. |
| iOS | **Not run.** Unknown. | This machine is Windows: no macOS, no Xcode. Nothing here says anything about iOS. |

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
