# Review notes — bugs found & fixed

## Round 4 — Gradle/AGP/Kotlin version bump (fixes "Gradle version lower than Flutter's minimum")

Codemagic's current Flutter stable build requires **Gradle 8.14.0 or newer**;
this project was pinned to Gradle 8.6, which is what the
`Build failed with an exception ... Your project's Gradle version (8.6.0) is
lower than Flutter's minimum supported version of 8.14.0` error was. Bumped
the whole toolchain together, since Gradle/AGP/Kotlin versions have to be a
mutually-compatible set, not adjusted one at a time:

- `android/gradle/wrapper/gradle-wrapper.properties` + the actual
  `gradle-wrapper.jar`: Gradle 8.6 → **8.14.5**
- `android/settings.gradle`: AGP 8.3.2 → **8.9.1**, Kotlin 1.9.23 → **2.1.0**
  (this pairing is a well-established compatible combination — AGP 8.9
  expects Gradle 8.11+, comfortably satisfied by 8.14.5)
- `android/app/build.gradle`: `compileSdk`/`targetSdk` 34 → **35**, and the
  Java/Kotlin bytecode target `VERSION_1_8` → **`VERSION_11`** (several of
  this project's plugins — `flutter_local_notifications`, `share_plus`,
  `file_picker` — have moved their own Android implementations past Java 8;
  staying on `VERSION_1_8` under a modern AGP/Gradle pairing is a common
  source of *next* build failure even after the version numbers above are
  fixed)

The build output also printed a generic "AGP 9+ new DSL" notice — that's a
boilerplate tip Flutter's tooling attaches to *any* Gradle-version error, not
a sign this project is actually on AGP 9. Deliberately stayed on AGP 8.x
(rather than jumping to 9) since AGP 9 has known breaking DSL changes that
Flutter's own Gradle plugin isn't fully settled on yet — no reason to take on
that risk when 8.9.1 satisfies the actual reported minimum.

If Codemagic's Flutter version moves again in the future and this class of
error recurs, the fix is always: read the exact minimum Gradle version from
the error, then pick an AGP version whose own minimum Gradle requirement is
at or below it (Android's own AGP release notes list this per version) —
don't just bump Gradle in isolation.

## Round 3 — dependency resolution failures

1. **`intl: ^0.19.0` conflicted with the Flutter SDK's own
   `flutter_localizations` package.** `flutter_localizations` is bundled
   with the Flutter SDK itself, and its required `intl` version moves with
   whatever Flutter version is installed — a newer stable Flutter (as
   Codemagic runs) requires `intl ^0.20.3`, which our `^0.19.0` pin
   couldn't satisfy, so `flutter pub get` failed outright before the build
   ever started. → Bumped to `intl: ^0.20.3`.

   If this class of error recurs on a future Flutter version bump, it's
   almost always `intl` again (since it's pinned by the SDK) — running
   `flutter pub add intl:^X.Y.Z` with whatever version the error message
   names is the fastest fix. Every other dependency in this project is a
   normal third-party package and isn't yoked to the SDK version the same
   way.

2. **`telephony: ^0.2.0` replaced with `another_telephony: ^0.4.1`.**
   `telephony` hasn't been updated since ~2021 and doesn't declare itself
   compatible with the plugin-registration structure current Flutter
   versions expect — this was the actual cause of a `Build failed due to
   use of deleted Android v1 embedding` error that surfaced even with a
   correct `MainActivity`/manifest (Flutter's tooling flags *any*
   dependency that still looks v1-only, not just the app's own code).
   `another_telephony` is an actively-maintained fork with an identical
   API (same `Telephony`/`SmsMessage` classes, same
   `com.shounakmulay.telephony.sms.IncomingSmsReceiver` class name in the
   manifest), so this was a one-line import change in
   `lib/services/sms_service.dart` plus the pubspec swap — no manifest or
   logic changes needed. Also removed the now-pointless
   `-keep class io.flutter.app.** { *; }` ProGuard rule, which referenced
   the deleted v1 package.

## Round 2 — Android build fully scaffolded (fixes "deleted v1 embedding" error)

The project previously shipped with only `AndroidManifest.xml` / `build.gradle`
/ `proguard-rules.pro` under `android/app`, on the assumption you'd run
`flutter create` first and layer these on top (see old note below). That
workflow is error-prone and was causing real build failures, so this zip now
ships a **complete, self-contained Android project** — no `flutter create`
step required:

- **`MainActivity.kt` was missing entirely.** This is the direct cause of
  `Build failed due to use of deleted Android v1 embedding` — Flutter's
  tooling looks for an Activity that actually extends the v2
  `io.flutter.embedding.android.FlutterActivity` class; with the class
  missing, it can't confirm v2 embedding even though the manifest's
  `flutterEmbedding=2` meta-data was already correct. Added at
  `android/app/src/main/kotlin/com/yourname/lpgtracker/MainActivity.kt`.
- Added `res/values/styles.xml` (`LaunchTheme`/`NormalTheme`, referenced by
  the manifest but never defined) and `res/drawable/launch_background.xml`.
- Added placeholder launcher icons at all five mipmap densities (solid
  brand-orange cylinder glyph) — replace with real artwork before publishing.
- Added the root `android/build.gradle`, `android/settings.gradle` (modern
  plugins-DSL, matching the plugin ids already used in `app/build.gradle`),
  and `android/gradle.properties`.
- Added a real, working Gradle wrapper (`gradlew`, `gradlew.bat`,
  `gradle/wrapper/gradle-wrapper.jar` + `.properties`, pinned to Gradle 8.6,
  compatible with AGP 8.3.2 / compileSdk 34).
- Fixed `app/build.gradle`'s Kotlin plugin id (`kotlin-android` →
  `org.jetbrains.kotlin.android`) to match the version pinned in the new
  `settings.gradle` — the old alias id and the versioned id in
  `pluginManagement` didn't reliably resolve to the same version.

You should now be able to run `flutter pub get` then
`flutter build appbundle` (or `--debug`) directly with no extra setup beyond
having Flutter/Android SDKs installed — `local.properties` is generated
automatically by the `flutter` CLI itself on every build, so nothing to do
there. Before publishing: replace the placeholder `com.yourname.lpgtracker`
applicationId/package and the placeholder launcher icons.

## Round 1

## Build-breaking bugs (app would not compile/run at all)

1. **Missing `url_launcher` dependency.** `safety_screen.dart` imports and uses
   `url_launcher` to dial emergency numbers, but it was never added to
   `pubspec.yaml` (the README even tells *you* to add it manually — it just
   wasn't done). → Added `url_launcher: ^6.3.0`.

2. **`NotificationService.scheduleBookingReminder` didn't compile.**
   `flutter_local_notifications: ^16.3.0`'s `zonedSchedule` requires a
   `tz.TZDateTime`, not a plain `DateTime`, and no longer has a
   `uiLocalNotificationDateInterpretation` parameter (removed years ago). →
   Added the `timezone` package, initialize timezone data, and convert the
   reminder time with `tz.TZDateTime.from(...)`. Also guards against
   scheduling into the past.

3. **`pubspec.yaml` declared `assets: - assets/` but no `assets/` folder
   exists anywhere in the project**, and nothing in `lib/` ever loads an
   asset. A `flutter pub get`/build fails outright when a declared asset
   directory doesn't exist. → Removed the unused `assets:` and `generate:
   true` (l10n codegen) entries; documented how to re-add them if you start
   using real assets/localization.

## Functional bugs (compiles, but behaves wrong)

4. **Settings → "Registered phone" never actually saved.** The text field
   saved to `notifications_phone` but loaded from (and the DB seeds)
   `registered_phone` — a typo'd key mismatch. Whatever you typed vanished
   on next app open. → Fixed the key.

5. **Settings → "Export history as PDF" was fake.** It just showed a
   "coming soon" snackbar even though `PdfExportService` (used correctly
   from the History tab) already does real PDF export/sharing. → Wired it
   up to `PdfExportService.sharePdf()` with a loading state and error
   handling, consistent with the History screen.

6. **Notification toggles in Settings did nothing.** Delivery/booking/
   safety notification switches were saved to the DB but never checked
   before actually firing a notification — toggling them off had zero
   effect. → `NotificationService` now reads the relevant setting before
   showing each notification type.

7. **Cylinder weight (and distributor phone) captured from a later SMS
   were silently dropped.** When a "delivered" SMS merges into an existing
   booking row (matched by `booking_id`), `_mergeBooking` only ever copied
   over DAC number, delivery date, price, and distributor name — weight and
   distributor phone were extracted by the parser but never written to the
   DB on merge. → Added both fields to the merge, and refreshed `raw_sms` to
   the latest message so the detail screen reflects the most recent status
   text instead of only the original booking SMS.

8. **Background SMS handler could be silently stripped in release builds.**
   `telephony`'s background isolate entry point needs
   `@pragma('vm:entry-point')` or R8/tree-shaking can remove it, breaking
   SMS auto-detection specifically in release APKs when the app isn't
   running. → Added the annotation.

9. **Emergency call buttons could silently no-op on Android 11+.**
   `canLaunchUrl(tel:...)` needs a `<queries>` block in the manifest to see
   the dialer app under Android's package-visibility rules; without it,
   tapping a number does nothing and no error is shown. → Added the
   `<queries>` block for `tel:` intents.

## Smaller improvements

10. **Monthly usage bar chart was hard-capped at `maxY: 3`.** Any month
    with 3+ cylinders would clip/flatten at the top of the chart. → `maxY`
    now scales to the actual max value in the dataset.

11. **SMS parser's generic booking-ID fallback could grab a phone number**
    (e.g. a "call us on 98xxxxxxxx" line) when no company-specific booking
    pattern matched. → Added a guard that skips 10-digit values matching the
    Indian mobile number format (`[6-9]XXXXXXXXX`) when using that fallback
    pattern specifically.

12. **Raw SQL string interpolation in `getMonthlyUsage`.** `year` was
    spliced directly into the SQL string. It was always an `int` so not
    exploitable in practice, but switched to a parameterized query as good
    practice.

## Known limitations (not fixed — out of scope / need real content)

- The **language dropdown in Settings is cosmetic** — no ARB files or
  `AppLocalizations` wiring exist, so picking Hindi/Tamil/etc. doesn't
  actually change any UI text. Real localization would need
  `lib/l10n/*.arb` files for all 10 listed languages plus
  `flutter_localizations` delegates in `MaterialApp`.
- The `telephony` package (SMS reading) hasn't been updated in a long time.
  It still works on current Android versions in testing, but there's no
  actively maintained alternative for background SMS listening in Flutter,
  so this is a known ecosystem risk rather than something in this codebase
  to fix.
- ~~This zip still assumes the workflow in the original README: run
  `flutter create lpg_tracker` first...~~ **No longer applies** — see
  "Round 2" above; the Android project is now fully self-contained.
- Before publishing: replace the placeholder `applicationId`/`namespace`
  (`com.yourname.lpgtracker`) in `android/app/build.gradle` and set up a
  real release signing config (it currently signs release builds with the
  debug key, which the build.gradle comment already flags).
