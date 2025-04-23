# Keep TensorFlow Lite GPU delegate classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate$Options { *; }

# Keep TensorFlow Lite and GPU classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Specifically keep the missing classes
-keep class org.tensorflow.lite.gpu.GpuDelegate$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
