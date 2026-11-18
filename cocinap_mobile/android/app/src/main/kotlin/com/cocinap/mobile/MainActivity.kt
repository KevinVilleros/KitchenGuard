package com.cocinap.mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private val backgroundMonitoringChannel = "com.cocinap.mobile/background_monitoring"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.cocinap.mobile/local_network"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    try {
                        if (multicastLock?.isHeld != true) {
                            val wifi = applicationContext
                                .getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifi.createMulticastLock("cocinap-onvif").apply {
                                setReferenceCounted(false)
                                acquire()
                            }
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("multicast_lock_failed", error.message, null)
                    }
                }
                "releaseMulticastLock" -> {
                    multicastLock?.let {
                        if (it.isHeld) it.release()
                    }
                    multicastLock = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backgroundMonitoringChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    if (checkSelfPermission(android.Manifest.permission.CAMERA) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        result.error(
                            "camera_permission_denied",
                            "Camera permission is required for background monitoring.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val arguments = call.arguments as? Map<*, *>
                    val remainingSeconds =
                        (arguments?.get("remainingSeconds") as? Number)?.toInt()
                    if (remainingSeconds == null || remainingSeconds <= 0) {
                        result.error(
                            "invalid_monitoring_duration",
                            "A positive remaining monitoring duration is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val intent = Intent(
                        this,
                        AndroidCameraMonitoringService::class.java
                    ).apply {
                        action = AndroidCameraMonitoringService.ACTION_START
                        putExtra(
                            AndroidCameraMonitoringService.EXTRA_REMAINING_SECONDS,
                            remainingSeconds
                        )
                        putExtra(
                            AndroidCameraMonitoringService.EXTRA_CONFIDENCE,
                            (arguments?.get("confidence") as? Number)?.toDouble() ?: 0.5
                        )
                        putExtra(
                            AndroidCameraMonitoringService.EXTRA_NO_PERSON_SECONDS,
                            (arguments?.get("noPersonAlertSeconds") as? Number)?.toInt() ?: 30
                        )
                        putIntegerArrayListExtra(
                            AndroidCameraMonitoringService.EXTRA_INTERVALS,
                            ArrayList(
                                (arguments?.get("alertIntervals") as? List<*>)
                                    .orEmpty()
                                    .mapNotNull { (it as? Number)?.toInt() }
                            )
                        )
                        putExtra(
                            AndroidCameraMonitoringService.EXTRA_INTERVAL_ALERTS_ENABLED,
                            arguments?.get("intervalAlertsEnabled") as? Boolean ?: true
                        )
                        putExtra(
                            AndroidCameraMonitoringService.EXTRA_REPEAT_LAST,
                            arguments?.get("repeatLastInterval") as? Boolean ?: true
                        )
                        putExtra(
                            AndroidCameraMonitoringService.EXTRA_LANGUAGE,
                            arguments?.get("language") as? String ?: "es"
                        )
                    }

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "monitoring_service_start_failed",
                            error.message,
                            null
                        )
                    }
                }
                "setCameraActive" -> {
                    val active = call.arguments as? Boolean
                    val service = AndroidCameraMonitoringService.runningInstance
                    if (active == null || service == null) {
                        result.error(
                            "monitoring_service_unavailable",
                            "The Android monitoring service is not running.",
                            null
                        )
                    } else {
                        service.setCameraCaptureActive(active)
                        result.success(null)
                    }
                }
                "updateStatus" -> {
                    val status = call.arguments as? String
                    val service = AndroidCameraMonitoringService.runningInstance
                    if (status == null) {
                        result.error(
                            "invalid_status",
                            "A monitoring status string is required.",
                            null
                        )
                    } else {
                        service?.setStatusMessage(status)
                        result.success(null)
                    }
                }
                "getMonitoringState" -> {
                    result.success(
                        AndroidCameraMonitoringService.runningInstance
                            ?.getMonitoringState()
                    )
                }
                "stopMonitoring" -> {
                    stopService(
                        Intent(this, AndroidCameraMonitoringService::class.java)
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        multicastLock?.let {
            if (it.isHeld) it.release()
        }
        multicastLock = null
        super.onDestroy()
    }
}
