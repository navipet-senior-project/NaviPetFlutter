package com.navipet.navipet

import android.content.Intent
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var indoorAr: IndoorArChannel? = null
    private var floorPressure: FloorPressureStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = IndoorArChannel(this, BuildConfig.UNITY_AR_ENABLED)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IndoorArChannel.CHANNEL)
            .setMethodCallHandler(channel)
        indoorAr = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navipet/indoor_wifi_scan")
            .setMethodCallHandler(IndoorWifiScanChannel(this))
        val pressure = FloorPressureStream(getSystemService(SENSOR_SERVICE) as SensorManager)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FloorPressureStream.CHANNEL)
            .setStreamHandler(pressure)
        floorPressure = pressure
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        floorPressure?.onCancel(null)
        floorPressure = null
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FloorPressureStream.CHANNEL)
            .setStreamHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (indoorAr?.onActivityResult(requestCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
