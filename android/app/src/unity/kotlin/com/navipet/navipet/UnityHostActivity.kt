package com.navipet.navipet

import android.app.Activity
import android.content.Intent
import com.unity3d.player.UnityPlayerActivity

/**
 * Hosts the Unity AR player in the ":unity" process. Unity reads the request
 * from the launch intent (IndoorArResults.REQUEST_EXTRA) and answers through
 * [deliverResult].
 */
class UnityHostActivity : UnityPlayerActivity() {
    private var delivered = false

    /** Called from C# (IndoorArBridge) on the Unity thread. */
    fun deliverResult(json: String) {
        runOnUiThread {
            if (delivered) return@runOnUiThread
            delivered = true
            setResult(Activity.RESULT_OK, Intent().putExtra(IndoorArResults.RESULT_EXTRA, json))
            finish()
        }
    }
}
