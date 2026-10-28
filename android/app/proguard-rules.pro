# Flutter / 插件相关的默认规则由 Flutter 插件自动追加，这里只需补充本项目特有配置。

# 保留注解与泛型签名，方便 release 构建下反射正常工作。
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# webview_flutter / mobile_scanner 通过平台通道与原生通信，保留其类。
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 混淆后仍要保留 JS 注入脚本用到的字段（WebHeaders.languageScript 中的标记名）。
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# 去除日志，减小包体积。
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** i(...);
    public static *** d(...);
    public static *** w(...);
}

# Flutter 引擎的 PlayStoreDeferredComponentManager 引用了 Play Core 的类，
# 但本应用用不到延迟下载组件，play-core 也没有打进依赖。
# 对这些缺失类做 dontwarn，避免 R8 因 "Missing class" 直接失败。
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.assetpacks.**
