# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Google Play (modular libraries)
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class com.google.ads.** { *; }
-dontwarn com.google.ads.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Socket.io / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep model classes for JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ExoPlayer (used by video_player and audioplayers)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Flutter CallKit Incoming
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# Dio / Retrofit (HTTP client)
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
