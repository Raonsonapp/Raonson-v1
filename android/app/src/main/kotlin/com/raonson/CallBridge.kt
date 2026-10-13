package com.raonson.app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Пули ягонаи занг байни Dart ва Android (канал 'raonson/call').
 *
 * Объект (на қисми Activity), зеро гуфтугӯ метавонад аз Activity дарозтар
 * зиндагӣ кунад: корбар барномаро аз «охиринҳо» мебарорад, Activity нест
 * мешавад, вале FlutterEngine (Dart, Agora, сокет) ва хизматрасонии
 * пешзамина кор мекунанд. Activity-и нав ҳамон engine-ро мегирад.
 */
object CallBridge {
    const val CHANNEL = "raonson/call"
    const val ENGINE_CACHE_KEY = "raonson_call_engine"

    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /** Activity ҳоло ба engine пайваст аст (ё не — танҳо engine зинда). */
    @Volatile var activityAttached = false

    /** Dart гуфт, ки занги видеоӣ фаъол аст (PiP иҷозат). */
    @Volatile var pipEligible = false

    /** Хизматрасонии занг кор мекунад — engine набояд нест шавад. */
    @Volatile var callActive = false

    fun attach(engine: FlutterEngine, context: Context, onPip: (Boolean) -> Unit) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        val app = context.applicationContext
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startOngoing", "updateOngoing" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        callActive = true
                        OngoingCallService.start(app, args)
                        result.success(null)
                    }
                    "stopOngoing" -> {
                        callActive = false
                        pipEligible = false
                        onPip(false)
                        OngoingCallService.stop(app)
                        result.success(null)
                    }
                    "setPipEligible" -> {
                        pipEligible = call.argument<Boolean>("enabled") == true
                        onPip(pipEligible)
                        result.success(null)
                    }
                    "audioDevices" -> result.success(audioDevices(app))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("call_native", e.message, null)
            }
        }
        channel = ch
    }

    fun detach() {
        // Канал бо engine мемонад: тугмаҳои огоҳинома бояд бе Activity
        // ҳам ба Dart расанд.
        activityAttached = false
    }

    /** Тугмаи огоҳинома → Dart (mute / speaker / end / open). */
    fun sendAction(name: String) {
        main.post { channel?.invokeMethod("action", name) }
    }

    fun sendPip(inPip: Boolean) {
        main.post { channel?.invokeMethod("pip", inPip) }
    }

    private fun audioDevices(context: Context): Map<String, Boolean> {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return mapOf("bluetooth" to false, "wired" to false)
        var bt = false
        var wired = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (d in am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                when (d.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> bt = true
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> wired = true
                }
            }
        }
        return mapOf("bluetooth" to bt, "wired" to wired)
    }
}
