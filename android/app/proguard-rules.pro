# Google ML Kit Text Recognition - Keep classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Ignore missing optional language models (these are optional dependencies)
# These models are not included by default, so suppress warnings/errors
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Suppress errors for missing optional classes
-ignorewarnings
-dontnote com.google.mlkit.vision.text.chinese.**
-dontnote com.google.mlkit.vision.text.devanagari.**
-dontnote com.google.mlkit.vision.text.japanese.**
-dontnote com.google.mlkit.vision.text.korean.**

# Keep ML Kit Commons
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Prevent R8 from removing classes referenced via reflection
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

