# Keep SMS plugin classes (another_telephony reuses the original
# com.shounakmulay.telephony package/receiver names).
-keep class com.shounakmulay.telephony.** { *; }

# Keep flutter local notifications
-keep class com.dexterous.** { *; }

# Keep Dart/Flutter bridge (v2 embedding + plugin registrant classes).
# NOTE: the old `-keep class io.flutter.app.** { *; }` rule was removed —
# io.flutter.app was the deleted v1 embedding package; keeping a rule for a
# package that no longer exists is dead weight, not a build blocker by
# itself, but worth cleaning up now that the real v1-embedding culprit
# (the outdated `telephony` package) has been replaced.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent stripping of reflection-based code
-keepattributes *Annotation*
-keepattributes Signature
