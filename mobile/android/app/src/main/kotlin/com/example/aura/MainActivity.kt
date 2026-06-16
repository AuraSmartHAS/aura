package com.example.aura

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

private const val CHANNEL = "com.aura/conversation"

// FlutterFragmentActivity is required by the `health` plugin for the Health
// Connect permission flow (wearable opt-in).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }
}
