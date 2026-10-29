package com.navipet.navipet

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class IndoorArChannelTest {
    @Test
    fun onActivityResultWithNoPendingStoresTheResult() {
        val channel = IndoorArChannel(Activity(), true)
        assertTrue(channel.onActivityResult(IndoorArChannel.REQUEST_CODE, null))
        val recorded = RecordingResult()
        channel.onMethodCall(MethodCall("pendingResult", null), recorded)
        assertEquals(unityExited, recorded.value)
    }

    @Test
    fun onActivityResultWithPendingAnswersThatCall() {
        val channel = IndoorArChannel(Activity(), true)
        val waiting = RecordingResult()
        channel.pending = waiting
        assertTrue(channel.onActivityResult(IndoorArChannel.REQUEST_CODE, null))
        assertEquals(unityExited, waiting.value)
        assertNull(channel.pending)
    }

    private class RecordingResult : MethodChannel.Result {
        var value: Any? = null

        override fun success(result: Any?) {
            value = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}

        override fun notImplemented() {}
    }

    companion object {
        private const val unityExited =
            """{"status":"error","errorCode":"UNITY_EXITED","localizationQueries":0,"durationMs":0}"""
    }
}
