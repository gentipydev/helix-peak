package com.example.helixpeek

import android.Manifest
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Keeps a clip being made while Helix Peek is away: a foreground service with
 * the clip's progress in a notification, and a partial wake lock, so that
 * the frames go on being drawn and encoded behind another app or a locked
 * screen.
 *
 * The spike found an export with the app sent Home crawled at a fifth of the
 * speed, and with the screen off made no progress at all
 * (`docs/video-encoding-spike.md`): the app was a background process. While
 * this service runs it is not. The work itself stays where it was, in the
 * app's Flutter engine; the service only keeps the process in the
 * foreground and the CPU awake.
 *
 * Its type is `mediaProcessing` from Android 15, the type for converting media
 * (up to six hours in a day), and `shortService` on Android 14, which has no
 * such type (about three minutes). Earlier Androids take no type.
 *
 * It is started from a tap, while the app is on screen, which is when Android
 * allows it; [ClipKeepAliveChannel] starts, updates and ends it.
 */
class ClipExportService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: ""
                val total = intent.getIntExtra(EXTRA_TOTAL, 0)
                val started = try {
                    ServiceCompat.startForeground(
                        this,
                        PROGRESS_ID,
                        progressNotification(this, title, 0, total),
                        foregroundType(),
                    )
                    true
                } catch (error: Exception) {
                    // Refused (a type or a start Android does not allow here):
                    // the clip is made as before, while the app is open.
                    false
                }
                if (started) {
                    holdWakeLock()
                } else {
                    stopSelf()
                }
                answer(started)
            }
            ACTION_CANCEL -> tell(EVENT_CANCEL)
        }
        return START_NOT_STICKY
    }

    /** Android 15: a `mediaProcessing` service has run its six hours. */
    override fun onTimeout(startId: Int, fgsType: Int) {
        stoppedBySystem()
    }

    /** Android 14: a `shortService` has run its three minutes. */
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onTimeout(startId: Int) {
        stoppedBySystem()
    }

    /** Swiped out of Recents: the engine making the clip goes with the task. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stoppedBySystem()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun stoppedBySystem() {
        tell(EVENT_STOPPED)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun holdWakeLock() {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "helixpeek:clip").apply {
            setReferenceCounted(false)
            // Released when the clip ends; the timeout is only a backstop.
            acquire(WAKE_LOCK_MS)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun foregroundType(): Int = when {
        Build.VERSION.SDK_INT >= 35 -> ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
        Build.VERSION.SDK_INT >= 34 -> ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE
        else -> 0
    }

    companion object {
        private const val ACTION_START = "com.example.helixpeek.clip.START"
        private const val ACTION_CANCEL = "com.example.helixpeek.clip.CANCEL"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TOTAL = "total"

        /** What the service tells the app: the reader or Android stopped it. */
        const val EVENT_CANCEL = "cancel"
        const val EVENT_STOPPED = "stopped"

        private const val PROGRESS_CHANNEL = "clip_progress"
        private const val READY_CHANNEL = "clip_ready"
        private const val PROGRESS_ID = 7201
        private const val READY_ID = 7202
        private const val WAKE_LOCK_MS = 10 * 60 * 1000L

        /** How long a start may take to reach the foreground before it is given up. */
        private const val START_PATIENCE_MS = 3_000L

        /** The least time between two progress updates: Android drops faster ones. */
        private const val PROGRESS_EVERY_MS = 250L

        private val main = Handler(Looper.getMainLooper())

        /** Hears [EVENT_CANCEL] and [EVENT_STOPPED], on the main thread. */
        var listener: ((String) -> Unit)? = null

        private var pendingStart: ((Boolean) -> Unit)? = null
        private var lastProgress = 0L

        /** Gives a start up that never reached the foreground. */
        private val giveUp = Runnable { answer(false) }

        /**
         * Starts the service for a clip of [title] in [total] frames; [started]
         * hears whether it reached the foreground.
         */
        fun start(context: Context, title: String, total: Int, started: (Boolean) -> Unit) {
            createChannels(context)
            answer(false)
            pendingStart = started
            val intent = Intent(context, ClipExportService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TOTAL, total)
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (error: Exception) {
                answer(false)
                return
            }
            main.postDelayed(giveUp, START_PATIENCE_MS)
        }

        /** The clip's progress, in the service's notification. */
        fun progress(context: Context, title: String, done: Int, total: Int) {
            val now = SystemClock.elapsedRealtime()
            if (done < total && now - lastProgress < PROGRESS_EVERY_MS) return
            lastProgress = now
            if (!mayNotify(context)) return
            try {
                NotificationManagerCompat.from(context)
                    .notify(PROGRESS_ID, progressNotification(context, title, done, total))
            } catch (error: SecurityException) {
                // Notifications were turned off in between; the clip goes on.
            }
        }

        /**
         * Stops the service. A clip that was made while the app was away is
         * said in a notification of its own, which opens the app to share it.
         */
        fun end(context: Context, title: String, ready: Boolean, inFront: Boolean) {
            stop(context)
            if (!ready || inFront || !mayNotify(context)) return
            val notification = NotificationCompat.Builder(context, READY_CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_clip)
                .setContentTitle("Clip ready · $title")
                .setContentText("Open Helix Peek to share it.")
                .setContentIntent(openApp(context))
                .setAutoCancel(true)
                .build()
            try {
                NotificationManagerCompat.from(context).notify(READY_ID, notification)
            } catch (error: SecurityException) {
                // Turned off in between: the app says it when it is opened.
            }
        }

        fun stop(context: Context) {
            answer(false)
            context.stopService(Intent(context, ClipExportService::class.java))
        }

        private fun answer(started: Boolean) {
            main.removeCallbacks(giveUp)
            val waiting = pendingStart ?: return
            pendingStart = null
            waiting(started)
        }

        private fun tell(event: String) {
            main.post { listener?.invoke(event) }
        }

        private fun mayNotify(context: Context): Boolean =
            Build.VERSION.SDK_INT < 33 ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED

        private fun createChannels(context: Context) {
            val manager = NotificationManagerCompat.from(context)
            manager.createNotificationChannel(
                NotificationChannelCompat.Builder(PROGRESS_CHANNEL, NotificationManagerCompat.IMPORTANCE_LOW)
                    .setName("Clips being made")
                    .setDescription("How far a clip has got while Helix Peek is in the background.")
                    .build(),
            )
            manager.createNotificationChannel(
                NotificationChannelCompat.Builder(READY_CHANNEL, NotificationManagerCompat.IMPORTANCE_DEFAULT)
                    .setName("Clips ready")
                    .setDescription("A clip made while Helix Peek was in the background.")
                    .build(),
            )
        }

        private fun progressNotification(context: Context, title: String, done: Int, total: Int) =
            NotificationCompat.Builder(context, PROGRESS_CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_clip)
                .setContentTitle("Making a clip · $title")
                .setContentText("Frame $done of $total")
                .setProgress(total, done, total == 0)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setContentIntent(openApp(context))
                .addAction(0, "Cancel", cancel(context))
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()

        private fun openApp(context: Context): PendingIntent? {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return null
            return PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun cancel(context: Context): PendingIntent = PendingIntent.getService(
            context,
            1,
            Intent(context, ClipExportService::class.java).setAction(ACTION_CANCEL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
