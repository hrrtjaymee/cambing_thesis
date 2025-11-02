# TensorFlow Lite ProGuard Rules
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep interface org.tensorflow.lite.gpu.** { *; }

# Keep GPU Delegate
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory** { *; }

# Suppress warnings for missing optional GPU classes
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
