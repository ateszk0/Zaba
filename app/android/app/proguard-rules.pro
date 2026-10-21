# R8 (the release shrinker) rules, picked up by the Flutter Gradle plugin.
#
# The preferences plugin (shared_preferences_android 2.5) is built with jnigen: the
# Dart side finds its Kotlin classes and methods BY NAME through JNI. R8 does not
# see that use, removes or renames the methods, and the release app then fails at
# startup with "NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll" and
# never leaves its first screen. (Found by running the release APK on an emulator;
# the debug build is not shrunk, so it hides the problem.)
#
# Looking a method up by name also needs the TYPES in its signature to keep their
# names: the lookup asks for `getAll(String, List, kotlin.coroutines.Continuation)`,
# and R8 had renamed the Continuation type to `a5`, so no method matched. The
# generated code also reaches for Kotlin's own classes by name (kotlin.Result,
# kotlin.coroutines.intrinsics.CoroutineSingletons, ...): one missing class after
# the other, so the Kotlin runtime is kept whole (it is small).
-keep class kotlin.** { *; }

# If another plugin starts to use jnigen, add its package here; `flutter pub deps`
# and the plugin's pubspec (a dependency on `jni`) tell which ones do.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
