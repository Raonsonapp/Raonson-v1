package com.raonson.app

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * Activity-и ягонаи Flutter.
 *
 * Зангҳо (ниг. CallBridge, OngoingCallService):
 *  - Агар гуфтугӯ идома дошта бошад ва корбар барномаро аз «охиринҳо»
 *    барорад, FlutterEngine нест намешавад (Dart, Agora ва сокет кор
 *    мекунанд). Activity-и нав ҳамон engine-ро мегирад ва экрани занг
 *    бетағйир бармегардад. Бе занг — рафтори пешфарзи Flutter.
 *  - Занги видеоӣ: ҳангоми баромадан (Home) — Picture-in-Picture 9:16.
 */
class MainActivity : FlutterActivity() {

    private val main = Handler(Looper.getMainLooper())

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        // Engine-и зинда аз гуфтугӯи ҷорӣ (Activity-и пешина нест шуд).
        FlutterEngineCache.getInstance().get(CallBridge.ENGINE_CACHE_KEY)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CallBridge.activityAttached = true
        CallBridge.attach(flutterEngine, this) { eligible -> updatePipParams(eligible) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CallBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * Занг идома дорад → engine-ро нигоҳ медорем (дар кэш), то Activity-и
     * оянда онро гирад. Вагарна — нест кардан (ва аз кэш баровардан).
     */
    override fun shouldDestroyEngineWithHost(): Boolean {
        val engine = flutterEngine
        if (CallBridge.callActive && engine != null && !isChangingConfigurations) {
            FlutterEngineCache.getInstance().put(CallBridge.ENGINE_CACHE_KEY, engine)
            return false
        }
        FlutterEngineCache.getInstance().remove(CallBridge.ENGINE_CACHE_KEY)
        return true
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleCallIntent(intent)
    }

    private fun handleCallIntent(intent: Intent?) {
        if (intent?.action == OngoingCallService.ACTION_OPEN_CALL) {
            // Пахши огоҳиномаи занг → экрани пурраи занг.
            main.postDelayed({ CallBridge.sendAction("open") }, 150)
        }
    }

    // ── Picture-in-Picture ─────────────────────────────────────────

    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun updatePipParams(eligible: Boolean) {
        if (!pipSupported()) return
        main.post {
            try {
                val b = PictureInPictureParams.Builder().setAspectRatio(Rational(9, 16))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+: худи система ҳамвор ба PiP мебарад.
                    b.setAutoEnterEnabled(eligible)
                    b.setSeamlessResizeEnabled(false)
                }
                setPictureInPictureParams(b.build())
            } catch (e: Exception) {
                // Баъзе дастгоҳҳо PiP-ро хомӯш кардаанд — огоҳинома боқӣ.
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 8–11: дастӣ. 12+ — setAutoEnterEnabled худаш мекунад.
        if (CallBridge.pipEligible && pipSupported() &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S
        ) {
            try {
                enterPictureInPictureMode(
                    PictureInPictureParams.Builder().setAspectRatio(Rational(9, 16)).build()
                )
            } catch (e: Exception) {
                // Иҷозат дар танзимот хомӯш — огоҳиномаи занг кифоя аст.
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        CallBridge.sendPip(isInPictureInPictureMode)
    }
}
