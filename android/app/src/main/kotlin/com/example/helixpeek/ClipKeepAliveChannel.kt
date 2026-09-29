package com.example.helixpeek

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps a clip going while the app is away, for `ClipKeepAlive` in
 * `lib/shared/share/clip_keep_alive.dart`, through [ClipExportService].
 *
 * | Call       | Arguments                     | Returns                            |
 * |------------|-------------------------------|------------------------------------|
 * | `begin`    | title, total                  | `goes_on`, or `stops` if refused   |
 * | `progress` | title, done, total            | nothing                            |
 * | `end`      | title, ready, inFront         | nothing                            |
 *
 * And to Dart: `cancel` when the reader stops the clip from its notification,
 * and `stopped` when Android ends the service (its time is up, or the app was
 * swiped out of Recents), either of which the Dart side ends the clip for.
 *
 * The first clip also asks for leave to post notifications, where Android 13
 * and later want it. The clip does not wait for the answer: without it the
 * service still runs, and its notification shows only in the system's list
 * of running apps.
 */
class ClipKeepAliveChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler(this)
        ClipExportService.listener = { event -> channel.invokeMethod(event, null) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ClipExportService.listener = null
        ClipExportService.stop(activity.applicationContext)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity.applicationContext
        val title = call.argument<String>("title") ?: ""
        when (call.method) {
            "begin" -> {
                askToNotifyOnce()
                ClipExportService.start(context, title, call.argument<Int>("total") ?: 0) { started ->
                    result.success(if (started) "goes_on" else "stops")
                }
            }
            "progress" -> {
                ClipExportService.progress(
                    context,
                    title,
                    call.argument<Int>("done") ?: 0,
                    call.argument<Int>("total") ?: 0,
                )
                result.success(null)
            }
            "end" -> {
                ClipExportService.end(
                    context,
                    title,
                    ready = call.argument<Boolean>("ready") ?: false,
                    inFront = call.argument<Boolean>("inFront") ?: true,
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun askToNotifyOnce() {
        if (Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val asked = activity.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (asked.getBoolean(ASKED, false)) return
        asked.edit().putBoolean(ASKED, true).apply()
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFY)
    }

    companion object {
        const val NAME = "helixpeak/share/clip_keepalive"
        private const val PREFERENCES = "helixpeek.clips"
        private const val ASKED = "asked_to_notify"
        private const val REQUEST_NOTIFY = 7203
    }
}
