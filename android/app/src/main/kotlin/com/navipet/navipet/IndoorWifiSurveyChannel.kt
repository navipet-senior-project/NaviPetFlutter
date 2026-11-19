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

/** Performs a single foreground scan and only returns confirmed fresh results. */
class IndoorWifiSurveyChannel(private val context: Context) :
    MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finishError("TIMEOUT", "Wi-Fi scan timed out.") }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "scan") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("BUSY", "A Wi-Fi scan is already running.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION", "Location permission is required to scan Wi-Fi.", null)
            return
        }
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifi == null || !wifi.isWifiEnabled) {
            result.error("UNAVAILABLE", "Wi-Fi is unavailable or turned off.", null)
            return
        }

        pending = result
        val scanReceiver = object : BroadcastReceiver() {
            override fun onReceive(receiverContext: Context?, intent: Intent?) {
                val fresh = intent?.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, false) == true
                if (!fresh) {
                    finishError("STALE", "Android did not provide a fresh scan. Try again later.")
                    return
                }
                try {
                    val accessPoints = wifi.scanResults.map { scan ->
                        mapOf(
                            "bssid" to scan.BSSID,
                            "rssiDbm" to scan.level,
                            "frequencyMhz" to scan.frequency,
                        )
                    }
                    finishSuccess(mapOf(
                        "fresh" to true,
                        "capturedAtEpochMs" to System.currentTimeMillis(),
                        "accessPoints" to accessPoints,
                    ))
                } catch (error: SecurityException) {
                    finishError("PERMISSION", "Android denied access to Wi-Fi scan results.")
                }
            }
        }
        receiver = scanReceiver
        val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(scanReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                context.registerReceiver(scanReceiver, filter)
            }
            if (!wifi.startScan()) {
                finishError("THROTTLED", "Android could not start a fresh scan. Wait before trying again.")
                return
            }
            handler.postDelayed(timeout, 20_000)
        } catch (error: SecurityException) {
            finishError("PERMISSION", "Android denied permission to scan Wi-Fi.")
        }
    }

    private fun finishSuccess(value: Map<String, Any>) {
        val reply = pending ?: return
        cleanup()
        reply.success(value)
    }

    private fun finishError(code: String, message: String) {
        val reply = pending ?: return
        cleanup()
        reply.error(code, message, null)
    }

    private fun cleanup() {
        handler.removeCallbacks(timeout)
        receiver?.let {
            try { context.unregisterReceiver(it) } catch (_: IllegalArgumentException) { }
        }
        receiver = null
        pending = null
    }
}
