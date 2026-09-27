package com.example.helixpeek

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** The lab's clip encoder: `helixpeak/share/video_encoder`. */
    private var videoEncoder: VideoEncoderChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoEncoder = VideoEncoderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        videoEncoder?.dispose()
        videoEncoder = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
