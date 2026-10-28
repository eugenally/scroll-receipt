package com.eugenally.scroll_receipt

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val store = StatsStore(this)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getToday" -> result.success(store.today())
                    "isServiceEnabled" -> result.success(isServiceEnabled())
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "resetToday" -> { store.resetToday(); result.success(null) }
                    "launchedFromBubble" -> {
                        val from = intent?.getBooleanExtra(EXTRA_FROM_BUBBLE, false) ?: false
                        intent?.removeExtra(EXTRA_FROM_BUBBLE)
                        result.success(from)
                    }
                    "moveTaskToBack" -> { moveTaskToBack(true); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** 앱이 이미 떠 있을 때 플로팅 버튼을 누르면 여기로 들어온다 */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(EXTRA_FROM_BUBBLE, false)) {
            channel?.invokeMethod("showReceipt", null)
        }
    }

    private fun isServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val me = ComponentName(this, ScrollTrackerService::class.java).flattenToString()
        return enabled.split(':').any { it.equals(me, ignoreCase = true) }
    }

    companion object {
        const val CHANNEL = "scroll_receipt/tracker"
        const val EXTRA_FROM_BUBBLE = "from_bubble"
    }
}
