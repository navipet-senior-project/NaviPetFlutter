package com.navipet.navipet

/** Holds a result that came back with no Dart call waiting, until Dart takes it once. */
class IndoorArResultSlot {
    private var held: String? = null

    fun put(json: String) {
        held = json
    }

    fun take(): String? = held.also { held = null }
}
