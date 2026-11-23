package com.navipet.navipet

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Foreground-only Android Wi-Fi scan. Access point coordinates are not needed. */
class IndoorWifiScanChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null
    private var timeout: Runnable? = null

    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "scan") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("SCAN_BUSY", "A Wi-Fi scan is already running.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Grant location permission before scanning nearby Wi-Fi.", null)
            return
        }
        val manager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (manager == null || !manager.isWifiEnabled) {
            result.error("WIFI_DISABLED", "Turn on Wi-Fi before scanning.", null)
            return
        }
        pending = result
        val scanReceiver = object : BroadcastReceiver() {
            override fun onReceive(receiveContext: Context?, intent: Intent?) {
                if (intent?.action != WifiManager.SCAN_RESULTS_AVAILABLE_ACTION) return
                val isFresh = intent.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, false)
                if (!isFresh) {
                    finishError("STALE_SCAN", "Android did not provide fresh scan results. Wait briefly and retry.")
                    return
                }
                val aps = manager.scanResults.map { result ->
                    mapOf("bssid" to result.BSSID.lowercase(), "rssiDbm" to result.level,
                        "frequencyMhz" to result.frequency)
                }
                finishSuccess(mapOf("fresh" to true, "capturedAtEpochMs" to System.currentTimeMillis(),
                    "accessPoints" to aps))
            }
        }
        receiver = scanReceiver
        val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(scanReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(scanReceiver, filter)
        }
        timeout = Runnable { finishError("SCAN_TIMEOUT", "Timed out waiting for Android Wi-Fi scan results.") }
        mainHandler.postDelayed(timeout!!, 12_000)
        val started = manager.startScan()
        if (!started) finishError("SCAN_THROTTLED", "Android limited scan frequency. Wait a little and try again.")
    }

    private fun finishSuccess(value: Any) {
        val result = pending ?: return
        cleanup()
        result.success(value)
    }

    private fun finishError(code: String, message: String) {
        val result = pending ?: return
        cleanup()
        result.error(code, message, null)
    }

    private fun cleanup() {
        timeout?.let(mainHandler::removeCallbacks)
        timeout = null
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        receiver = null
        pending = null
    }
}
