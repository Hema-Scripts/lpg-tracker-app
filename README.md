# Smart LPG Tracker — Flutter App

> **Reviewed & patched.** See `CHANGES.md` for the full list of bugs found and fixed in this copy.


A 100% free, offline-first Android app for tracking Indane, HP Gas, and Bharat Gas cylinder bookings via SMS parsing.

---

## Project Structure

```
lpg_tracker/
├── lib/
│   ├── main.dart                     ← App entry, splash screen, routing
│   ├── models/
│   │   └── cylinder_booking.dart     ← Data model for bookings
│   ├── services/
│   │   ├── sms_parser.dart           ← Regex SMS parsing (Indane/HP/Bharat)
│   │   ├── sms_service.dart          ← SMS reading + background listener
│   │   ├── database_service.dart     ← SQLite CRUD + analytics queries
│   │   ├── prediction_service.dart   ← Gas finish date + booking prediction
│   │   └── notification_service.dart ← Local push notifications
│   ├── screens/
│   │   ├── onboarding_screen.dart    ← 4-step permission + setup flow
│   │   ├── main_navigation.dart      ← Bottom nav shell
│   │   ├── dashboard_screen.dart     ← Home: cylinder status + stats
│   │   ├── history_screen.dart       ← Bar chart + booking history list
│   │   ├── safety_screen.dart        ← Emergency contacts + safety guides
│   │   └── settings_screen.dart      ← Notifications, language, export
│   └── widgets/
│       ├── cylinder_widget.dart      ← Animated cylinder fill visual
│       ├── stat_card.dart            ← Metric card (price, days, etc.)
│       └── timeline_widget.dart      ← Booking → DAC → Delivery timeline
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml       ← SMS + notification permissions
└── pubspec.yaml                      ← All dependencies
```

---

## Setup Instructions

### 1. Install dependencies

This zip is now a complete, self-contained Flutter project (Android). No
`flutter create` step needed — just run it from the folder containing
`pubspec.yaml`:

```bash
flutter pub get
```

### 2. Build

```bash
flutter build appbundle        # release, for Play Store
flutter build apk --debug      # quick local test build
```

Before publishing: replace the placeholder applicationId/package
(`com.yourname.lpgtracker` in `android/app/build.gradle` and the matching
`MainActivity.kt` path/package) and swap the placeholder launcher icons in
`android/app/src/main/res/mipmap-*/ic_launcher.png` for real artwork.

### 4. Android SDK minimum version

In `android/app/build.gradle`, set:
```gradle
minSdkVersion 21
targetSdkVersion 34
```

### 5. Run on your Android phone

```bash
# Connect your phone via USB, enable developer mode + USB debugging
flutter run
```

### 6. Build release APK

```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

---

## How SMS Detection Works

### What it detects automatically:

| SMS Type | What's extracted |
|----------|-----------------|
| Booking confirmation | Booking ID, company, date |
| DAC generation | DAC number, date |
| Out for delivery | Status update |
| Delivery confirmation | Delivery date, price, weight |

### Supported sender IDs:

**Indane:** INDANE, IOCGAS, IOCLPG, INDGAS, VM-INDANE, AM-INDANE...  
**HP Gas:** HPGAS, HPCGAS, HPCL, HPCLPG, VM-HPGAS...  
**Bharat Gas:** BHARATGAS, BPCGAS, BPCLLPG, VM-BPCL...

### Sample SMS it can parse:

```
From: VM-INDANE
"Your LPG booking no. 4821939 has been registered. 
DAC No: 902847. Your cylinder will be delivered 
by 20-03-2025. Amount: Rs. 903.50"
```

Extracted: BookingID=4821939, DAC=902847, Date=20 Mar 2025, Price=₹903.50

---

## Features

- ✅ Auto-reads SMS inbox on first launch
- ✅ Background listener for new SMS
- ✅ Extracts Booking ID, DAC number, delivery date, price
- ✅ Gas level prediction (linear model from history)
- ✅ Local notifications (delivery, reminder, safety)
- ✅ Bar chart for monthly usage
- ✅ Full booking history with prices
- ✅ Emergency safety contacts (1906, etc.)
- ✅ Safety guides (seal, weight, leak, regulator)
- ✅ All data stored locally — no internet needed
- ✅ No paid APIs

---

## Permissions Used

| Permission | Why |
|-----------|-----|
| READ_SMS | Read past LPG booking SMS from inbox |
| RECEIVE_SMS | Auto-detect new booking/delivery SMS |
| POST_NOTIFICATIONS | Delivery and reminder alerts |

---

## Play Store Compliance Notes

- App clearly states it is NOT affiliated with any LPG company
- SMS permission justified in onboarding screen
- Privacy policy: all data stays on device
- No misleading claims about LPG company integration
- No scraping or private APIs used
