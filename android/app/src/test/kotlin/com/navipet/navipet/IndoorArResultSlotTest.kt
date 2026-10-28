package com.navipet.navipet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IndoorArResultSlotTest {
    @Test
    fun returnsAHeldResultOnce() {
        val slot = IndoorArResultSlot()
        slot.put("""{"status":"cancelled","localizationQueries":0,"durationMs":5}""")
        assertEquals("""{"status":"cancelled","localizationQueries":0,"durationMs":5}""", slot.take())
        assertNull(slot.take())
    }

    @Test
    fun isEmptyByDefault() {
        assertNull(IndoorArResultSlot().take())
    }
}
