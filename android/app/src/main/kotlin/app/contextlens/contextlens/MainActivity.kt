package app.contextlens.contextlens

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // While a report is open, keep it out of the recent apps thumbnail.
        // Screenshots still work: creators share their own reports.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "contextlens/privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPrivate" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            setRecentsScreenshotEnabled(call.arguments != true)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
