package com.raonson.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

/**
 * Гуфтугӯи ҷорӣ ҳамчун хизматрасонии пешзамина (мисли WhatsApp).
 *
 *  - Навъ: phoneCall | microphone (| camera — танҳо видео ва иҷозат бошад).
 *    Android барномаро бо хизматрасонии пешзамина намекушад ва микрофон/
 *    камера дар паснамо кор мекунанд.
 *  - Огоҳиномаи доимӣ: ном, аватар, вақтсанҷи зинда (chronometer),
 *    «Бесадо/Бо садо», «Баландгӯяк», «Қатъ». Пахш → экрани занг.
 *    Android 12+: Notification.CallStyle — система онро ҳамчун занг
 *    мешиносад (нишонаи сабз дар сатри ҳолат).
 *  - PARTIAL_WAKE_LOCK + WifiLock: экрани қулф садоро қатъ намекунад.
 *  - onTaskRemoved: занг идома меёбад (stopWithTask=false). Танҳо «Қатъ»
 *    (ё ҳамсӯҳбат) онро тамом мекунад.
 *
 * Ҳолат (ном, бесадо, вақт) аз Dart меояд; ин ҷо танҳо нишон дода мешавад.
 */
class OngoingCallService : Service() {

    companion object {
        private const val TAG = "OngoingCallService"
        private const val CHANNEL_ID = "call_ongoing_v1"
        private const val NOTIF_ID = 0x7a11
        private const val ACTION_UPDATE = "com.raonson.app.call.UPDATE"
        private const val ACTION_MUTE = "com.raonson.app.call.MUTE"
        private const val ACTION_SPEAKER = "com.raonson.app.call.SPEAKER"
        private const val ACTION_END = "com.raonson.app.call.END"
        const val ACTION_OPEN_CALL = "com.raonson.app.call.OPEN"

        @Volatile private var latest: Map<String, Any?> = emptyMap()

        @Volatile private var running: OngoingCallService? = null

        fun start(context: Context, args: Map<String, Any?>) {
            latest = args
            // Аллакай дар пешзамина — танҳо огоҳиномаро нав мекунем (аз
            // паснамо startForegroundService-и такрорӣ дар Android 12+ манъ).
            val svc = running
            if (svc != null && svc.foreground) {
                svc.main.post { svc.refresh() }
                return
            }
            val i = Intent(context, OngoingCallService::class.java).setAction(ACTION_UPDATE)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (e: Exception) {
                // Android 12+: аз паснамо оғоз кардан манъ аст. Хизматрасонӣ
                // аллакай кор мекунад — танҳо огоҳиномаро нав мекунем.
                Log.w(TAG, "start: ${e.message}")
            }
        }

        fun stop(context: Context) {
            latest = emptyMap()
            context.stopService(Intent(context, OngoingCallService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    @Volatile private var foreground = false
    private var avatarUrl: String = ""
    private var avatar: Bitmap? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        running = this
    }

    private fun refresh() {
        val args = latest
        if (args.isEmpty() || !foreground) return
        show(args)
        loadAvatar(args["avatarUrl"]?.toString() ?: "")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (val action = intent?.action) {
            ACTION_MUTE, ACTION_SPEAKER, ACTION_END -> {
                CallBridge.sendAction(
                    when (action) {
                        ACTION_MUTE -> "mute"
                        ACTION_SPEAKER -> "speaker"
                        else -> "end"
                    }
                )
                // Раванд аз нав сохта шуд ва занг нест — худро мебандем.
                if (!foreground) stopSelf()
            }
            else -> {
                val args = latest
                if (args.isEmpty()) {
                    // Бе маълумот: stop() пеш аз оғоз омад. startForeground
                    // ба ҳар ҳол лозим аст (вагарна Android 8+ барномаро
                    // барои «startForegroundService бе startForeground» мекушад).
                    ensureChannel()
                    startForegroundSafe(build(emptyMap(), callStyle = false), false)
                    stopSelf()
                    return START_NOT_STICKY
                }
                show(args)
                acquireLocks()
                loadAvatar(args["avatarUrl"]?.toString() ?: "")
            }
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Корбар барномаро аз «охиринҳо» баровард — мисли WhatsApp занг
        // идома меёбад; FlutterEngine дар CallBridge/MainActivity зинда аст.
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        if (running === this) running = null
        releaseLocks()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        foreground = false
        super.onDestroy()
    }

    // ── Огоҳинома ────────────────────────────────────────────────

    private fun show(args: Map<String, Any?>) {
        ensureChannel()
        val isVideo = args["isVideo"] == true
        val notification = try {
            build(args, callStyle = true)
        } catch (e: Exception) {
            build(args, callStyle = false)
        }
        if (!foreground) {
            foreground = startForegroundSafe(notification, isVideo)
            if (!foreground) {
                stopSelf()
                return
            }
        } else {
            try {
                nm().notify(NOTIF_ID, notification)
            } catch (e: Exception) {
                // CallStyle бе FGS рад мешавад — бе услуб.
                nm().notify(NOTIF_ID, build(args, callStyle = false))
            }
        }
    }

    private fun startForegroundSafe(n: Notification, isVideo: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return try {
                startForeground(NOTIF_ID, n); true
            } catch (e: Exception) {
                Log.w(TAG, "startForeground: ${e.message}"); false
            }
        }
        var mask = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 14+: навъи microphone/camera бе иҷозати додашуда
            // SecurityException медиҳад — танҳо онҳое, ки иҷозат доранд.
            if (granted(Manifest.permission.RECORD_AUDIO)) {
                mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            if (isVideo && granted(Manifest.permission.CAMERA)) {
                mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
        }
        val attempts = listOf(mask, ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
        for (m in attempts) {
            try {
                startForeground(NOTIF_ID, n, m)
                return true
            } catch (e: Exception) {
                Log.w(TAG, "startForeground(type=$m): ${e.message}")
            }
        }
        return false
    }

    private fun granted(p: String) =
        checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun nm() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm().getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID, label("channel", "Гуфтугӯи ҷорӣ"),
            NotificationManager.IMPORTANCE_LOW
        )
        ch.setSound(null, null)
        ch.enableVibration(false)
        ch.setShowBadge(false)
        nm().createNotificationChannel(ch)
    }

    @Suppress("UNCHECKED_CAST")
    private fun label(key: String, def: String): String {
        val labels = latest["labels"] as? Map<String, Any?> ?: return def
        return labels[key]?.toString()?.takeIf { it.isNotEmpty() } ?: def
    }

    private fun pending(action: String, req: Int): PendingIntent {
        val i = Intent(this, OngoingCallService::class.java).setAction(action)
        return PendingIntent.getService(
            this, req, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun openIntent(): PendingIntent {
        val i = Intent(this, MainActivity::class.java)
            .setAction(ACTION_OPEN_CALL)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            this, 1, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    @SuppressLint("NewApi")
    private fun build(args: Map<String, Any?>, callStyle: Boolean): Notification {
        val name = args["peerName"]?.toString().orEmpty().ifEmpty { "Raonson" }
        val status = args["status"]?.toString().orEmpty()
        val isVideo = args["isVideo"] == true
        val muted = args["muted"] == true
        val speakerOn = args["speakerOn"] == true
        val connectedAt = (args["connectedAtMs"] as? Number)?.toLong()

        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }
        b.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(name)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(openIntent())
        if (connectedAt != null && connectedAt > 0) {
            b.setUsesChronometer(true).setShowWhen(true).setWhen(connectedAt)
            b.setContentText(
                label(if (isVideo) "video" else "voice", if (isVideo) "Занги видеоӣ" else "Занги аудиоӣ")
            )
        } else {
            b.setShowWhen(false).setContentText(status)
        }
        avatar?.let { b.setLargeIcon(it) }

        val muteAction = Notification.Action.Builder(
            Icon.createWithResource(
                this,
                if (muted) android.R.drawable.ic_lock_silent_mode
                else android.R.drawable.ic_btn_speak_now
            ),
            if (muted) label("unmute", "Бо садо") else label("mute", "Бесадо"),
            pending(ACTION_MUTE, 10)
        ).build()
        val speakerAction = Notification.Action.Builder(
            Icon.createWithResource(this, android.R.drawable.ic_lock_silent_mode_off),
            if (speakerOn) label("speakerOff", "Гӯшак") else label("speaker", "Баландгӯяк"),
            pending(ACTION_SPEAKER, 11)
        ).build()
        val endIntent = pending(ACTION_END, 12)

        if (callStyle && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val person = Person.Builder().setName(name).setImportant(true)
            avatar?.let { person.setIcon(Icon.createWithBitmap(it)) }
            b.setStyle(Notification.CallStyle.forOngoingCall(person.build(), endIntent))
            // CallStyle «Қатъ»-ро худаш мегузорад; боқӣ — аз пас.
            b.addAction(muteAction)
            b.addAction(speakerAction)
        } else {
            b.addAction(muteAction)
            b.addAction(speakerAction)
            b.addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
                    label("end", "Қатъ"), endIntent
                ).build()
            )
        }
        val n = b.build()
        n.flags = n.flags or Notification.FLAG_NO_CLEAR or Notification.FLAG_ONGOING_EVENT
        return n
    }

    private fun loadAvatar(url: String) {
        if (url == avatarUrl || !url.startsWith("http")) return
        avatarUrl = url
        Thread {
            try {
                val c = URL(url).openConnection() as HttpURLConnection
                c.connectTimeout = 5000
                c.readTimeout = 5000
                val bmp = c.inputStream.use { BitmapFactory.decodeStream(it) }
                c.disconnect()
                if (bmp != null) {
                    val scaled = Bitmap.createScaledBitmap(bmp, 192, 192, true)
                    main.post {
                        if (avatarUrl == url && latest.isNotEmpty() && foreground) {
                            avatar = scaled
                            show(latest)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "avatar: ${e.message}")
            }
        }.start()
    }

    // ── Бедор нигоҳ доштан ──────────────────────────────────────

    @SuppressLint("WakelockTimeout")
    private fun acquireLocks() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "raonson:call").apply {
                setReferenceCounted(false)
                acquire(6 * 60 * 60 * 1000L)
            }
        }
        if (wifiLock == null) {
            try {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                } else {
                    @Suppress("DEPRECATION")
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF
                }
                wifiLock = wm.createWifiLock(mode, "raonson:call").apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } catch (e: Exception) {
                Log.w(TAG, "wifiLock: ${e.message}")
            }
        }
    }

    private fun releaseLocks() {
        try { wakeLock?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        try { wifiLock?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        wakeLock = null
        wifiLock = null
    }
}
