package com.navipet.navipet

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

internal class FloorPressureStream(private val manager: SensorManager) :
    EventChannel.StreamHandler, SensorEventListener {
    companion object {
        const val CHANNEL = "navipet/floor_pressure"
    }

    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = manager.getDefaultSensor(Sensor.TYPE_PRESSURE)
        if (sensor == null) {
            events.error("NO_SENSOR", null, null)
        } else if (manager.registerListener(this, sensor, 1_000_000)) {
            sink = events
        } else {
            events.error("UNAVAILABLE", null, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val ageMicros = (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1_000
        val capturedAt = System.currentTimeMillis() * 1_000 - ageMicros
        sink?.success(listOf(event.values[0].toDouble(), capturedAt))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
