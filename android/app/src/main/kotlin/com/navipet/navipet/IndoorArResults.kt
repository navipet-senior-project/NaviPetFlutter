package com.navipet.navipet

/**
 * Bridge contract v1 results the host builds itself, for outcomes Unity never
 * reports. Unity's own result JSON passes through untouched; Dart validates it.
 */
object IndoorArResults {
    const val REQUEST_EXTRA = "navipet.indoorAr.request"
    const val RESULT_EXTRA = "navipet.indoorAr.result"
    const val BAD_REQUEST = "BAD_REQUEST"
    const val UNITY_EXITED = "UNITY_EXITED"

    fun unavailable(): String =
        """{"status":"unavailable","localizationQueries":0,"durationMs":0}"""

    // code is always one of the constants above, so it needs no escaping.
    fun error(code: String, durationMs: Long): String =
        """{"status":"error","errorCode":"$code","localizationQueries":0,"durationMs":$durationMs}"""

    /** No result means Unity ended without answering: crash, kill, or an unhandled exit. */
    fun fromActivityResult(resultJson: String?, durationMs: Long): String =
        if (resultJson.isNullOrBlank()) error(UNITY_EXITED, durationMs) else resultJson
}
