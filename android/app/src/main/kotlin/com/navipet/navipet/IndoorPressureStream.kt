package com.navipet.navipet

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

/** Streams TYPE_PRESSURE in pascals; it does not request location permission. */
class IndoorPressureStream(context: Context) : EventChannel.StreamHandler,
    SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor = manager.getDefaultSensor(Sensor.TYPE_PRESSURE)
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        if (sensor == null) {
            events?.error("UNAVAILABLE", "This device has no pressure sensor.", null)
            return
        }
        manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val pressure = event?.values?.firstOrNull() ?: return
        sink?.success(pressure.toDouble())
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
