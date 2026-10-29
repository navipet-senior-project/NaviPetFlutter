package com.navipet.navipet

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var indoorAr: IndoorArChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = IndoorArChannel(this, BuildConfig.UNITY_AR_ENABLED)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IndoorArChannel.CHANNEL)
            .setMethodCallHandler(channel)
        indoorAr = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        indoorAr?.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        indoorAr?.detach()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (indoorAr?.onActivityResult(requestCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
