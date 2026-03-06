# Keep JNI bridge
-keep class com.josie.ai.LlamaNative {
    *;
}

# Keep callback interface used by JNI
-keep interface com.josie.ai.LlamaNative$StreamCallback

# Keep ViewModels
-keep class com.josie.ai.JosieBrain { *; }

# Keep ChatMessage data model
-keep class com.josie.ai.ChatMessage { *; }

# Keep coroutine metadata
-keepclassmembers class kotlinx.coroutines.** { *; }

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Compose runtime safety
-keep class androidx.compose.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
