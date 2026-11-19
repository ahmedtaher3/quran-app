# Picked up automatically by the Flutter Gradle plugin for release builds
# (R8 is on by default in `flutter build apk/appbundle --release`).

# Recitation stopped in release builds with a NullPointerException inside
# just_audio's AudioPlayer$ObserverRenderer (a Media3 NoSampleRenderer),
# called from ExoPlayer's MediaPeriodHolder. Debug builds are not shrunk.
# Keep just_audio and Media3 as they are.
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
