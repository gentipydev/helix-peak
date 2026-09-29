package com.example.helixpeek

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** The clip encoder: `helixpeak/share/video_encoder`. */
    private var videoEncoder: VideoEncoderChannel? = null

    /** Keeps a clip going outside the app: `helixpeak/share/clip_keepalive`. */
    private var clipKeepAlive: ClipKeepAliveChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        videoEncoder = VideoEncoderChannel(applicationContext, messenger)
        clipKeepAlive = ClipKeepAliveChannel(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The engine making the clip is going, so nothing is left to keep going.
        clipKeepAlive?.dispose()
        clipKeepAlive = null
        videoEncoder?.dispose()
        videoEncoder = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
