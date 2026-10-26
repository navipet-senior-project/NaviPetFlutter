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
    private var pending: MethodChannel.Result? = null
    private var startedAt = 0L

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "launch") {
            result.notImplemented()
            return
        }
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
            result.success(IndoorArResults.unavailable())
        } catch (e: RuntimeException) {
            // SecurityException, IllegalStateException: never leave a call pending.
            pending = null
            Log.w(TAG, "startActivityForResult failed", e)
            result.success(IndoorArResults.error(IndoorArResults.UNITY_EXITED, 0))
        }
    }

    /** Returns true when the result belonged to the AR activity. */
    fun onActivityResult(requestCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        result.success(
            IndoorArResults.fromActivityResult(
                data?.getStringExtra(IndoorArResults.RESULT_EXTRA),
                SystemClock.elapsedRealtime() - startedAt,
            ),
        )
        return true
    }

    companion object {
        private const val TAG = "IndoorArChannel"
        const val CHANNEL = "navipet/indoor_ar"
        const val REQUEST_CODE = 4101

        // By name: the class exists only in builds that include the Unity library.
        const val UNITY_HOST_CLASS = "com.navipet.navipet.UnityHostActivity"
    }
}
