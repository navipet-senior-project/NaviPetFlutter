package com.navipet.navipet

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var indoorAr: IndoorArChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = IndoorArChannel(this, BuildConfig.UNITY_AR_ENABLED)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IndoorArChannel.CHANNEL)
            .setMethodCallHandler(channel)
        indoorAr = channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "navipet/indoor_pressure")
            .setStreamHandler(IndoorPressureStream(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navipet/indoor_wifi_survey")
            .setMethodCallHandler(IndoorWifiSurveyChannel(this))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (indoorAr?.onActivityResult(requestCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
