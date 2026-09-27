package com.example.helixpeek

import android.app.Activity
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.nio.ByteBuffer

/**
 * Encodes a clip to MP4, one frame per call, for `VideoEncoder` in
 * `lib/features/lab/share/video_encoder.dart`.
 *
 * The recipe is the one `docs/video-encoding-spike.md` measured on a Galaxy
 * S21 Ultra: MediaCodec (H.264) fed through its flexible YUV input images,
 * MediaMuxer to MP4, BT.709 limited range tagged on the stream. No third-party
 * encoder.
 *
 * | Call       | Arguments                          | Returns                    |
 * |------------|------------------------------------|----------------------------|
 * | `begin`    | width, height, fps, fileName       | session, path, codec       |
 * | `addFrame` | session, rgba (tightly packed)     | nothing                    |
 * | `finish`   | session                            | path of the finished MP4   |
 * | `cancel`   | session                            | nothing; the file is gone  |
 *
 * The handler runs on a background task queue: serial, so one session's calls
 * stay in order, and never on the platform thread. A session keeps the screen
 * on from `begin` to `finish` or `cancel`, because the spike found an export
 * with the screen off made no progress at all.
 *
 * Failures come back as error codes: `unsupported` where no encoder takes the
 * format, `bad_args` for a call the Dart side should never make, and
 * `encode_failed` for anything the codec or muxer throws.
 */
class VideoEncoderChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(
        messenger,
        NAME,
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )
    private val sessions = HashMap<Int, Session>()
    private var nextSession = 1

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        for (session in sessions.values) {
            session.cancel()
        }
        sessions.clear()
        keepScreenOn(false)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "begin" -> begin(call, result)
                "addFrame" -> {
                    val session = sessionOf(call, result) ?: return
                    val rgba = call.argument<ByteArray>("rgba")
                    if (rgba == null || rgba.size != session.width * session.height * 4) {
                        result.error("bad_args", "A frame is not ${session.width}x${session.height} RGBA.", null)
                        return
                    }
                    session.addFrame(rgba)
                    result.success(null)
                }
                "finish" -> {
                    val session = sessionOf(call, result) ?: return
                    sessions.remove(session.id)
                    keepScreenOn(sessions.isNotEmpty())
                    session.finish()
                    result.success(session.file.path)
                }
                "cancel" -> {
                    val id = call.argument<Int>("session")
                    sessions.remove(id)?.cancel()
                    keepScreenOn(sessions.isNotEmpty())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            // A codec that fails mid-session is not left holding the hardware.
            call.argument<Int>("session")?.let { sessions.remove(it)?.cancel() }
            keepScreenOn(sessions.isNotEmpty())
            result.error("encode_failed", error.message ?: error.toString(), null)
        }
    }

    private fun begin(call: MethodCall, result: MethodChannel.Result) {
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        val fps = call.argument<Int>("fps") ?: 0
        val fileName = call.argument<String>("fileName") ?: ""
        // 4:2:0 chroma is one sample per 2x2 block, so both sides must be even.
        if (width <= 0 || height <= 0 || width % 2 != 0 || height % 2 != 0 || fps <= 0 ||
            fileName.isEmpty() || fileName.contains('/')) {
            result.error("bad_args", "Cannot encode ${width}x$height at $fps fps to \"$fileName\".", null)
            return
        }
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, width * height * fps / 8)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
            setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
            setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }
        val codecName = MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(format)
        if (codecName == null) {
            result.error("unsupported", "This device has no H.264 encoder for ${width}x$height at $fps fps.", null)
            return
        }
        val file = File(activity.cacheDir, fileName)
        file.delete()
        val session = Session(nextSession++, width, height, fps, file, format, codecName)
        sessions[session.id] = session
        keepScreenOn(true)
        result.success(mapOf("session" to session.id, "path" to file.path, "codec" to codecName))
    }

    private fun sessionOf(call: MethodCall, result: MethodChannel.Result): Session? {
        val session = sessions[call.argument<Int>("session")]
        if (session == null) {
            result.error("bad_args", "No encoding session ${call.argument<Int>("session")}.", null)
        }
        return session
    }

    private fun keepScreenOn(on: Boolean) {
        activity.runOnUiThread {
            if (on) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    private class Session(
        val id: Int,
        val width: Int,
        val height: Int,
        private val fps: Int,
        val file: File,
        format: MediaFormat,
        codecName: String,
    ) {
        private val codec: MediaCodec = MediaCodec.createByCodecName(codecName)
        private val muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        private val info = MediaCodec.BufferInfo()
        private var track = -1
        private var frames = 0L
        private var closed = false

        init {
            try {
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                codec.start()
            } catch (error: Throwable) {
                codec.release()
                muxer.release()
                file.delete()
                throw error
            }
        }

        fun addFrame(rgba: ByteArray) {
            val index = inputIndex()
            // Read the capacity before taking the Image: asking for the buffer
            // afterwards would invalidate the Image.
            val capacity = codec.getInputBuffer(index)!!.capacity()
            val image = codec.getInputImage(index)
                ?: throw IllegalStateException("The encoder gave no input image.")
            writeYuv(rgba, image)
            // Each frame carries its own time, frame * 1e6 / fps µs, not its
            // arrival time: rendering is slower than real time.
            codec.queueInputBuffer(
                index,
                0,
                minOf(capacity, width * height * 3 / 2),
                frames * 1_000_000L / fps,
                0,
            )
            frames++
            drain(endOfStream = false)
        }

        fun finish() {
            val index = inputIndex()
            codec.queueInputBuffer(
                index,
                0,
                0,
                frames * 1_000_000L / fps,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            drain(endOfStream = true)
            close(keep = true)
        }

        fun cancel() {
            close(keep = false)
        }

        private fun close(keep: Boolean) {
            if (closed) return
            closed = true
            try {
                codec.stop()
            } catch (_: Throwable) {
            }
            codec.release()
            try {
                if (track >= 0) muxer.stop()
            } catch (_: Throwable) {
            }
            muxer.release()
            if (!keep) file.delete()
        }

        /** An input buffer, draining output while the encoder has none free. */
        private fun inputIndex(): Int {
            while (true) {
                val index = codec.dequeueInputBuffer(TIMEOUT_US)
                if (index >= 0) return index
                drain(endOfStream = false)
            }
        }

        private fun drain(endOfStream: Boolean) {
            while (true) {
                val index = codec.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        check(track < 0) { "The encoder changed its format twice." }
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                    }
                    index >= 0 -> {
                        val data = codec.getOutputBuffer(index)!!
                        // Codec config (SPS and PPS) is already in the track's
                        // format; writing it as a sample would add a bad frame.
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            info.size = 0
                        }
                        if (info.size > 0) {
                            check(track >= 0) { "The encoder wrote before naming its format." }
                            data.position(info.offset)
                            data.limit(info.offset + info.size)
                            muxer.writeSampleData(track, data, info)
                        }
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        /**
         * RGBA to the encoder's own YUV 4:2:0 layout.
         *
         * This is where encoding usually breaks, so each step is spelled out:
         *
         * - In: Flutter's `rawRgba`, R, G, B, A bytes per pixel, rows packed
         *   with no padding (row stride = width x 4). Alpha is premultiplied,
         *   and the frames are opaque, so it is dropped.
         * - Out: whatever the codec handed back in `getInputImage`. With
         *   COLOR_FormatYUV420Flexible the codec chooses planar (I420) or
         *   semi-planar (NV12/NV21, interleaved chroma) and may pad rows, so
         *   every write goes through the plane's own pixelStride and
         *   rowStride. The spike's encoder gave Y pixel stride 1, U and V
         *   pixel stride 2 (semi-planar); another may not.
         * - Colour: BT.709, limited range (Y 16-235, Cb and Cr 16-240), as
         *   the stream is tagged. Integer coefficients x256: BT.709 scaled by
         *   219/255 for luma and 224/255 for chroma. Chroma is taken from the
         *   average of each 2x2 block.
         */
        private fun writeYuv(rgba: ByteArray, image: Image) {
            val y = image.planes[0]
            val u = image.planes[1]
            val v = image.planes[2]
            val yBuffer: ByteBuffer = y.buffer
            val uBuffer: ByteBuffer = u.buffer
            val vBuffer: ByteBuffer = v.buffer
            val yRow = y.rowStride
            val yPixel = y.pixelStride
            for (row in 0 until height) {
                var from = row * width * 4
                var to = row * yRow
                for (col in 0 until width) {
                    val r = rgba[from].toInt() and 0xFF
                    val g = rgba[from + 1].toInt() and 0xFF
                    val b = rgba[from + 2].toInt() and 0xFF
                    yBuffer.put(to, (16 + ((47 * r + 157 * g + 16 * b + 128) shr 8)).toByte())
                    from += 4
                    to += yPixel
                }
            }
            val uRow = u.rowStride
            val uPixel = u.pixelStride
            val vRow = v.rowStride
            val vPixel = v.pixelStride
            for (row in 0 until height / 2) {
                for (col in 0 until width / 2) {
                    val a = ((row * 2) * width + col * 2) * 4
                    val c = a + width * 4
                    val r = ((rgba[a].toInt() and 0xFF) + (rgba[a + 4].toInt() and 0xFF) +
                        (rgba[c].toInt() and 0xFF) + (rgba[c + 4].toInt() and 0xFF) + 2) shr 2
                    val g = ((rgba[a + 1].toInt() and 0xFF) + (rgba[a + 5].toInt() and 0xFF) +
                        (rgba[c + 1].toInt() and 0xFF) + (rgba[c + 5].toInt() and 0xFF) + 2) shr 2
                    val b = ((rgba[a + 2].toInt() and 0xFF) + (rgba[a + 6].toInt() and 0xFF) +
                        (rgba[c + 2].toInt() and 0xFF) + (rgba[c + 6].toInt() and 0xFF) + 2) shr 2
                    uBuffer.put(row * uRow + col * uPixel, (128 + ((-26 * r - 86 * g + 112 * b + 128) shr 8)).toByte())
                    vBuffer.put(row * vRow + col * vPixel, (128 + ((112 * r - 102 * g - 10 * b + 128) shr 8)).toByte())
                }
            }
        }
    }

    companion object {
        const val NAME = "helixpeak/share/video_encoder"
        private const val TIMEOUT_US = 10_000L
    }
}
