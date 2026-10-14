package com.raonson.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import io.agora.rtc2.extensions.MediaProjectionMgr

/**
 * Намоиши экран дар занг (Agora full-screen-sharing, MediaProjection).
 *
 * Тартиб (Android 10+/14): Dart `startScreenCapture` → Agora равзанаи
 * розигии система (LocalScreenCaptureAssistantActivity) → ПАС аз розигӣ
 * хизматрасонии пешзаминаи навъи mediaProjection-и худи Agora
 * (MediaProjectionMgr$LocalScreenSharingService, дар манифест) →
 * getMediaProjection → гирифтан. OngoingCallService (phoneCall|microphone|
 * camera) бетағйир мемонад: навъи mediaProjection бе розигии ҷорӣ дар
 * Android 14 SecurityException медиҳад, бинобар ин он дар хизматрасонии
 * алоҳидаи Agora аст.
 *
 * Ин ҷо танҳо:
 *  - огоҳиномаи он хизматрасонӣ: «Экран намоиш дода мешавад» + «Қатъ
 *    кардан» (ба ҷои огоҳиномаи пешфарзи Agora);
 *  - хатои розигӣ → Dart (`shareDenied`).
 */
object ScreenShareNative {
    private const val TAG = "ScreenShareNative"
    private const val CHANNEL_ID = "call_screen_share_v1"

    @Volatile private var installed = false

    fun install(context: Context) {
        if (installed) return
        installed = true
        val app = context.applicationContext
        try {
            MediaProjectionMgr.setConfigFactory(
                object : MediaProjectionMgr.ScreenCaptureConfigFactory {
                    override fun createNotification(): Notification = build(app)
                }
            )
            MediaProjectionMgr.setCaptureActionListener(
                object : MediaProjectionMgr.ScreenCaptureActionListener {
                    override fun screenCaptureRequest() {}

                    override fun screenCaptureResult(granted: Boolean) {
                        if (!granted) CallBridge.sendAction("shareDenied")
                    }

                    override fun dispose() {}
                }
            )
        } catch (e: Throwable) {
            // SDK бе модули screen-sharing — огоҳиномаи пешфарзи Agora.
            Log.w(TAG, "install: ${e.message}")
        }
    }

    private fun build(context: Context): Notification {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val title = OngoingCallService.sharedLabel("sharing", "Экран намоиш дода мешавад")
        val stopLabel = OngoingCallService.sharedLabel("stopShare", "Қатъ кардан")
        val peer = OngoingCallService.sharedPeerName()

        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID, title, NotificationManager.IMPORTANCE_LOW
                )
                ch.setSound(null, null)
                ch.enableVibration(false)
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val stop = PendingIntent.getService(
            context, 13,
            Intent(context, OngoingCallService::class.java)
                .setAction(OngoingCallService.ACTION_STOP_SHARE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val open = PendingIntent.getActivity(
            context, 14,
            Intent(context, MainActivity::class.java)
                .setAction(OngoingCallService.ACTION_OPEN_CALL)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        b.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(context, android.R.drawable.ic_menu_close_clear_cancel),
                    stopLabel, stop
                ).build()
            )
        if (peer.isNotEmpty()) b.setContentText(peer)
        val n = b.build()
        n.flags = n.flags or Notification.FLAG_NO_CLEAR or Notification.FLAG_ONGOING_EVENT
        return n
    }
}
