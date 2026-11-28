# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Myket Billing SDK
-keep class ir.myket.billingclient.** { *; }
-keep interface ir.myket.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }
-keepclassmembers class ir.myket.billingclient.util.** {
    public <fields>;
    public <methods>;
}
