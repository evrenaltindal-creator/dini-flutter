package com.dini.dini_flutter

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dini/widget_snapshot").setMethodCallHandler { call, result ->
            when (call.method) {
                "updateSnapshot" -> {
                    val snapshot = call.argument<String>("snapshot")
                    if (snapshot == null) { result.error("INVALID_SNAPSHOT", "Snapshot is required", null); return@setMethodCallHandler }
                    getSharedPreferences("dini_widget", Context.MODE_PRIVATE).edit().putString("snapshot", snapshot).apply()
                    DiniWidgetProvider.updateAll(this)
                    result.success(null)
                }
                "clearSnapshot" -> { getSharedPreferences("dini_widget", Context.MODE_PRIVATE).edit().clear().apply(); DiniWidgetProvider.updateAll(this); result.success(null) }
                "refreshWidgets" -> { DiniWidgetProvider.updateAll(this); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
