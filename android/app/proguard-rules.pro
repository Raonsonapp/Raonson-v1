# ── Flutter ──────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Plugins (reflection / native) ────────────────────────────────
# video_player (ExoPlayer / media3)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# record (паёми овозӣ)
-keep class com.llfbandit.record.** { *; }

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# image_picker / image compress
-keep class io.flutter.plugins.imagepicker.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# WebRTC / connectivity / secure storage
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Keep annotations & enums used by JSON / reflection
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepclassmembers enum * { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Suppress common false-positive warnings
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn kotlin.**
