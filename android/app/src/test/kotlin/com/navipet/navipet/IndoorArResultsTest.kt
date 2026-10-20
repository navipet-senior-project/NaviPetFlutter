package com.navipet.navipet

import org.junit.Assert.assertEquals
import org.junit.Test

class IndoorArResultsTest {
    @Test
    fun passesUnityResultThroughUntouched() {
        val json = """{"status":"cancelled","localizationQueries":0,"durationMs":5}"""
        assertEquals(json, IndoorArResults.fromActivityResult(json, 99))
    }

    @Test
    fun missingResultBecomesUnityExited() {
        assertEquals(
            """{"status":"error","errorCode":"UNITY_EXITED","localizationQueries":0,"durationMs":1500}""",
            IndoorArResults.fromActivityResult(null, 1500),
        )
    }

    @Test
    fun blankResultBecomesUnityExited() {
        assertEquals(
            """{"status":"error","errorCode":"UNITY_EXITED","localizationQueries":0,"durationMs":7}""",
            IndoorArResults.fromActivityResult(" ", 7),
        )
    }

    @Test
    fun unavailableMatchesTheDartContract() {
        assertEquals(
            """{"status":"unavailable","localizationQueries":0,"durationMs":0}""",
            IndoorArResults.unavailable(),
        )
    }

    @Test
    fun badRequestMatchesTheDartContract() {
        assertEquals(
            """{"status":"error","errorCode":"BAD_REQUEST","localizationQueries":0,"durationMs":0}""",
            IndoorArResults.error(IndoorArResults.BAD_REQUEST, 0),
        )
    }
}
