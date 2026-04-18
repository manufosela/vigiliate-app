# =========================================================================
# ProGuard / R8 rules for the Vigiliate Flutter wrapper (release builds).
#
# These rules keep the plugin surfaces that R8 would otherwise strip or
# rename. Without them, release builds have been known to crash with
# NoClassDefFoundError the first time the WebView, Google Sign-In or
# flutter_local_notifications try to reflect into their Java side.
#
# Flutter itself ships most rules in the Flutter Gradle plugin; these are
# the extras we need for the specific plugins this app uses.
# =========================================================================

# --- Flutter ------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- webview_flutter ----------------------------------------------------
# The WebView plugin reflects into Android WebView internals.
-keep class android.webkit.** { *; }
-keep class androidx.webkit.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn androidx.webkit.**

# --- google_sign_in -----------------------------------------------------
# GoogleSignIn uses the com.google.android.gms.auth.api namespace.
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
-dontwarn com.google.android.gms.**

# --- flutter_local_notifications ---------------------------------------
# The broadcast receivers declared in the manifest must survive shrink.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**

# --- Play Core (required by Flutter splitcompat on R8 aggressive) ------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# --- Gson / JSON annotations (transitive via Google Sign-In) -----------
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# --- Kotlin standard library -------------------------------------------
-dontwarn kotlin.**
-dontwarn kotlinx.**
