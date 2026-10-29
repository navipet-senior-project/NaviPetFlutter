package com.navipet.navipet

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Starts the Unity AR activity for one request and answers the Dart call with
 * the result JSON once Unity finishes. Always replies with a result string,
 * never a platform error.
 */
class IndoorArChannel(
    private val activity: Activity,
    private val unityEnabled: Boolean,
) : MethodChannel.MethodCallHandler {
    internal var pending: MethodChannel.Result? = null
    private var startedAt = 0L
    private val unclaimed = IndoorArResultSlot()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "pendingResult") {
            // TODO: release path not built; only the debug room picker collects pendingResult (plan Deviation).
            result.success(unclaimed.take())
            return
        }
        if (call.method != "launch") {
            result.notImplemented()
            return
        }
        unclaimed.take()
        if (!unityEnabled) {
            result.success(IndoorArResults.unavailable())
            return
        }
        val request = call.arguments as? String
        if (request.isNullOrBlank() || pending != null) {
            result.success(IndoorArResults.error(IndoorArResults.BAD_REQUEST, 0))
            return
        }
        val intent = Intent()
            .setClassName(activity, UNITY_HOST_CLASS)
            .putExtra(IndoorArResults.REQUEST_EXTRA, request)
        pending = result
        startedAt = SystemClock.elapsedRealtime()
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pending = null
            startedAt = 0L
            result.success(IndoorArResults.unavailable())
        } catch (e: RuntimeException) {
            // SecurityException, IllegalStateException: never leave a call pending.
            pending = null
            startedAt = 0L
            Log.w(TAG, "startActivityForResult failed", e)
            result.success(IndoorArResults.error(IndoorArResults.UNITY_EXITED, 0))
        }
    }

    /** Returns true when the result belonged to the AR activity. */
    fun onActivityResult(requestCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        // startedAt is 0 in an activity recreated while Unity ran.
        val durationMs = if (startedAt == 0L) 0L else SystemClock.elapsedRealtime() - startedAt
        val json = IndoorArResults.fromActivityResult(
            data?.getStringExtra(IndoorArResults.RESULT_EXTRA),
            durationMs,
        )
        val result = pending
        pending = null
        startedAt = 0L
        if (result == null) {
            unclaimed.put(json)
        } else {
            result.success(json)
        }
        return true
    }

    /** Drops a launch whose Dart caller is gone, so the next launch is not BAD_REQUEST. */
    fun detach() {
        pending = null
        startedAt = 0L
    }

    companion object {
        private const val TAG = "IndoorArChannel"
        const val CHANNEL = "navipet/indoor_ar"
        const val REQUEST_CODE = 4101

        // By name: the class exists only in builds that include the Unity library.
        const val UNITY_HOST_CLASS = "com.navipet.navipet.UnityHostActivity"
    }
}
