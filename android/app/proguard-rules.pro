# Firebase SDKs ship their own consumer ProGuard rules, so no extra keep
# rules are needed here for firebase_core/auth/firestore/storage/messaging/functions.

# flutter_local_notifications: 예약 알림을 Gson으로 저장한다 (줄이면 예약이 깨진다).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * { @com.google.gson.annotations.SerializedName <fields>; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
