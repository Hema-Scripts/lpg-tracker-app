package com.yourname.lpgtracker

import io.flutter.embedding.android.FlutterActivity

// Uses the current (v2) Flutter Android embedding. This file was missing
// from the project entirely — Flutter's build tooling detects a v2 project
// by finding an AndroidManifest.xml with the `flutterEmbedding=2` meta-data
// *and* an Activity that actually extends this v2 FlutterActivity class. An
// AndroidManifest.xml that references `.MainActivity` with no such class
// present is exactly what produces "Build failed due to use of deleted
// Android v1 embedding" — the class old apps used,
// `io.flutter.app.FlutterActivity`, no longer exists, and without this file
// the tool has no v2 class to find either.
class MainActivity : FlutterActivity()
