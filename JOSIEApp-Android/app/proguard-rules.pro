# ---------------------------------------------------------------
# JNI Callback Protection
# ---------------------------------------------------------------
# Prevent R8 from renaming any class/method looked up by name
# from native code via JNI (GetMethodID, FindClass, etc.)

-keep class com.josie.ai.LlamaNative { *; }

# Keep any interface or class with an onToken method — this is
# called by name from generateStream() in llama-jni.cpp
-keepclassmembers class * {
    public void onToken(java.lang.String);
}

# Keep all callback-style interfaces in the package
-keep interface com.josie.ai.** { *; }

# ---------------------------------------------------------------
# Kotlin & Coroutines (standard rules)
# ---------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class kotlin.Metadata { *; }

# ---------------------------------------------------------------
# Jetpack Compose
# ---------------------------------------------------------------
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**
