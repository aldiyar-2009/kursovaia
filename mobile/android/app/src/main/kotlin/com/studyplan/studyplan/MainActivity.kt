package com.studyplan.studyplan

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands `studyplan://connect?server=...` links (from the server's QR code) to
 * Dart: `getInitialLink` for a cold start, `onLink` while the app is running.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(connectLink(intent))
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        connectLink(intent)?.let { channel?.invokeMethod("onLink", it) }
    }

    private fun connectLink(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == "studyplan") data.toString() else null
    }

    companion object {
        const val CHANNEL = "studyplan/connect_link"
    }
}
