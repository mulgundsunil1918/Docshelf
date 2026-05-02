# ─── pdfx (PDF rendering, uses pdfium native lib) ──────────────────
-keep class com.shockwave.pdfium.** { *; }
-dontwarn com.shockwave.pdfium.**

# ─── local_auth ────────────────────────────────────────────────────
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# ─── flutter_local_notifications ──────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keep class * extends com.google.gson.TypeAdapter
-keep class * extends com.google.gson.TypeAdapterFactory
-keep class * extends com.google.gson.JsonSerializer
-keep class * extends com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ─── share_plus + open_filex via FileProvider ──────────────────────
-keep class androidx.core.content.FileProvider { *; }

# ─── receive_sharing_intent ────────────────────────────────────────
-keep class com.kasem.receive_sharing_intent.** { *; }

# ─── sqflite (auto-handled, kept for safety) ──────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ─── Keep R8 from stripping reflection-loaded plugin classes ──────
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
