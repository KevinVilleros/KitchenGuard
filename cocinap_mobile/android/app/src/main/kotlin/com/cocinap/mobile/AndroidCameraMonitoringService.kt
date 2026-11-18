package com.cocinap.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class AndroidCameraMonitoringService : Service(), LifecycleOwner {
    companion object {
        const val ACTION_START = "com.cocinap.mobile.monitor.START"
        const val ACTION_SET_CAMERA_ACTIVE = "com.cocinap.mobile.monitor.SET_CAMERA_ACTIVE"
        const val EXTRA_CAMERA_ACTIVE = "camera_active"
        const val EXTRA_REMAINING_SECONDS = "remaining_seconds"
        const val EXTRA_CONFIDENCE = "confidence"
        const val EXTRA_NO_PERSON_SECONDS = "no_person_seconds"
        const val EXTRA_INTERVALS = "intervals"
        const val EXTRA_INTERVAL_ALERTS_ENABLED = "interval_alerts_enabled"
        const val EXTRA_REPEAT_LAST = "repeat_last"
        const val EXTRA_LANGUAGE = "language"

        private const val SERVICE_NOTIFICATION_ID = 901
        private const val ALERT_NOTIFICATION_ID = 902
        private const val SERVICE_CHANNEL_ID = "cocinap_camera_monitor"
        private const val ALERT_CHANNEL_ID = "cocinap_alarms"

        @Volatile
        var runningInstance: AndroidCameraMonitoringService? = null
            private set
    }

    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    private val mainHandler = Handler(Looper.getMainLooper())
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var poseDetector: PoseDetector? = null
    private var cameraActive = false
    private var remainingSeconds = 0
    private var deadlineMillis = 0L
    private var confidenceThreshold = 0.5
    private var noPersonAlertSeconds = 30
    private var alertIntervals = listOf(10, 15, 20, 30)
    private var intervalAlertsEnabled = true
    private var repeatLastInterval = true
    private var language = "es"
    private var statusMessage: String? = null
    private var lastPersonSeenMillis = System.currentTimeMillis()
    private var lastAlertMillis: Long? = null
    private var lastAlertInterval: Int? = null
    private var lastAlertMessage: String? = null
    private var personPresent = false
    private var lastDisplayedMinute = -1
    private var consecutivePresentFrames = 0
    private var consecutiveAbsentFrames = 0
    private val firedIntervals = mutableSetOf<Int>()
    private var stopped = false

    private val tick = object : Runnable {
        override fun run() {
            if (stopped) return
            remainingSeconds =
                ((deadlineMillis - System.currentTimeMillis()) / 1000L)
                    .coerceAtLeast(0L)
                    .toInt()
            if (remainingSeconds == 0) {
                stopSelf()
                return
            }
            maybeNotifyUnattended()
            val displayedMinute = remainingSeconds / 60
            if (displayedMinute != lastDisplayedMinute) {
                lastDisplayedMinute = displayedMinute
                updateForegroundNotification()
            }
            mainHandler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        runningInstance = this
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        poseDetector = PoseDetection.getClient(
            PoseDetectorOptions.Builder()
                .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
                .build()
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (lifecycleRegistry.currentState == Lifecycle.State.CREATED) {
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        }
        when (intent?.action) {
            ACTION_START -> {
                readConfiguration(intent)
                createNotificationChannels()
                stopped = false
                startAsForegroundService()
                deadlineMillis =
                    System.currentTimeMillis() + remainingSeconds * 1000L
                lastPersonSeenMillis = System.currentTimeMillis()
                personPresent = false
                consecutivePresentFrames = 0
                consecutiveAbsentFrames = 0
                firedIntervals.clear()
                lastAlertMillis = null
                lastAlertInterval = null
                lastAlertMessage = null
                lastDisplayedMinute = -1
                mainHandler.removeCallbacks(tick)
                mainHandler.post(tick)
            }
            ACTION_SET_CAMERA_ACTIVE -> {
                val shouldCapture = intent.getBooleanExtra(EXTRA_CAMERA_ACTIVE, false)
                setCameraCaptureActive(shouldCapture)
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    fun setCameraCaptureActive(active: Boolean) {
        if (active == cameraActive) return
        cameraActive = active
        if (cameraActive) {
            lastPersonSeenMillis = System.currentTimeMillis()
            consecutivePresentFrames = 0
            consecutiveAbsentFrames = 0
            personPresent = false
            firedIntervals.clear()
            lastAlertMillis = null
            lastAlertInterval = null
            lastAlertMessage = null
            startCamera()
        } else {
            stopCamera()
        }
        updateForegroundNotification()
    }

    fun setStatusMessage(status: String) {
        statusMessage = status
        updateForegroundNotification()
    }

    fun getMonitoringState(): Map<String, Any?> = mapOf(
        "cameraActive" to cameraActive,
        "personPresent" to personPresent,
        "consecutivePresentFrames" to consecutivePresentFrames,
        "consecutiveAbsentFrames" to consecutiveAbsentFrames,
        "lastPersonSeenMillis" to lastPersonSeenMillis,
        "firedIntervals" to firedIntervals.toList(),
        "lastAlertMillis" to lastAlertMillis,
        "lastAlertInterval" to lastAlertInterval,
        "lastAlertMessage" to lastAlertMessage
    )

    override fun onDestroy() {
        stopped = true
        mainHandler.removeCallbacks(tick)
        stopCamera()
        poseDetector?.close()
        poseDetector = null
        analysisExecutor.shutdown()
        runningInstance = null
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        super.onDestroy()
    }

    private fun readConfiguration(intent: Intent) {
        remainingSeconds = intent.getIntExtra(EXTRA_REMAINING_SECONDS, 0)
            .coerceAtLeast(0)
        confidenceThreshold = intent.getDoubleExtra(EXTRA_CONFIDENCE, 0.5)
            .coerceIn(0.2, 0.9)
        noPersonAlertSeconds = intent.getIntExtra(EXTRA_NO_PERSON_SECONDS, 30)
            .coerceIn(10, 120)
        alertIntervals = intent.getIntegerArrayListExtra(EXTRA_INTERVALS)
            ?.filter { it in 1..240 }
            ?.distinct()
            ?.sorted()
            ?: listOf(10, 15, 20, 30)
        intervalAlertsEnabled =
            intent.getBooleanExtra(EXTRA_INTERVAL_ALERTS_ENABLED, true)
        repeatLastInterval = intent.getBooleanExtra(EXTRA_REPEAT_LAST, true)
        language = intent.getStringExtra(EXTRA_LANGUAGE) ?: "es"
    }

    private fun startAsForegroundService() {
        val notification = buildServiceNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                SERVICE_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            )
        } else {
            startForeground(SERVICE_NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL_ID,
                if (language == "en") "Kitchen monitoring" else "Monitoreo de cocina",
                NotificationManager.IMPORTANCE_LOW
            )
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                if (language == "en") "Kitchen alerts" else "Alertas de cocina",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                        .build()
                )
            }
        )
    }

    private fun buildServiceNotification(): Notification {
        val content = statusMessage ?: when {
            cameraActive && language == "en" -> "Monitoring with the camera"
            cameraActive -> "Monitoreando con la cámara"
            language == "en" -> "Monitoring active"
            else -> "Monitoreo activo"
        }
        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("CocinaP")
            .setContentText(content)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    private fun updateForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(SERVICE_NOTIFICATION_ID, buildServiceNotification())
    }

    private fun startCamera() {
        if (imageAnalysis != null) return
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            if (!cameraActive || stopped) return@addListener
            try {
                val provider = providerFuture.get()
                cameraProvider = provider
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                analysis.setAnalyzer(analysisExecutor, ::analyzeFrame)
                imageAnalysis = analysis
                provider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    analysis
                )
            } catch (error: Exception) {
                cameraActive = false
                updateForegroundNotification()
                showAlarm(
                    if (language == "en") {
                        "Background camera unavailable. Open CocinaP to retry."
                    } else {
                        "Cámara en segundo plano no disponible. Abre CocinaP para reintentar."
                    }
                )
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun stopCamera() {
        val analysis = imageAnalysis ?: return
        imageAnalysis = null
        try {
            cameraProvider?.unbind(analysis)
        } catch (_: IllegalStateException) {
            // The camera provider may already have released this use case.
        }
    }

    private fun analyzeFrame(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (!cameraActive || mediaImage == null) {
            imageProxy.close()
            return
        }
        val input = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees
        )
        poseDetector?.process(input)
            ?.addOnSuccessListener(analysisExecutor) { pose ->
                val personDetected = isPerson(pose)
                mainHandler.post {
                    recordDetection(if (personDetected) 1 else 0)
                }
            }
            ?.addOnFailureListener(analysisExecutor) {
                // A failed inference is not evidence that the room is empty.
            }
            ?.addOnCompleteListener(analysisExecutor) {
                imageProxy.close()
            }
            ?: imageProxy.close()
    }

    private fun isPerson(pose: Pose): Boolean {
        val coreLandmarks = listOf(
            com.google.mlkit.vision.pose.PoseLandmark.NOSE,
            com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER,
            com.google.mlkit.vision.pose.PoseLandmark.RIGHT_SHOULDER,
            com.google.mlkit.vision.pose.PoseLandmark.LEFT_HIP,
            com.google.mlkit.vision.pose.PoseLandmark.RIGHT_HIP
        )
        val scores = coreLandmarks.mapNotNull {
            pose.getPoseLandmark(it)?.inFrameLikelihood
        }
        return scores.isNotEmpty() && scores.average() >= confidenceThreshold
    }

    private fun recordDetection(personCount: Int) {
        if (!cameraActive || stopped) return
        if (personCount > 0) {
            consecutivePresentFrames++
            consecutiveAbsentFrames = 0
            if (consecutivePresentFrames >= 2) {
                lastPersonSeenMillis = System.currentTimeMillis()
                personPresent = true
                firedIntervals.clear()
                lastAlertMillis = null
                lastAlertInterval = null
                lastAlertMessage = null
            }
        } else {
            consecutiveAbsentFrames++
            consecutivePresentFrames = 0
            if (consecutiveAbsentFrames >= 3) {
                personPresent = false
            }
        }
    }

    private fun maybeNotifyUnattended() {
        if (!cameraActive || !intervalAlertsEnabled || alertIntervals.isEmpty()) return
        val absenceSeconds =
            (System.currentTimeMillis() - lastPersonSeenMillis) / 1000L
        if (absenceSeconds < noPersonAlertSeconds || consecutiveAbsentFrames < 3) return

        val absenceMinutes = absenceSeconds / 60.0
        val dueInterval = alertIntervals.firstOrNull {
            absenceMinutes >= it && it !in firedIntervals
        } ?: if (repeatLastInterval && alertIntervals.all { it in firedIntervals }) {
            val last = alertIntervals.last()
            val previousAlert = lastAlertMillis
            if (absenceMinutes >= last &&
                (previousAlert == null ||
                    System.currentTimeMillis() - previousAlert >= last * 60_000L)
            ) {
                last
            } else {
                null
            }
        } else {
            null
        } ?: return

        firedIntervals.add(dueInterval)
        lastAlertMillis = System.currentTimeMillis()
        lastAlertInterval = dueInterval
        val message = if (language == "en") {
            "Kitchen unattended ($dueInterval min without a person)."
        } else {
            "Cocina desatendida ($dueInterval min sin persona)."
        }
        lastAlertMessage = message
        showAlarm(message)
    }

    private fun showAlarm(message: String) {
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(if (language == "en") "CocinaP alert" else "Alerta de CocinaP")
            .setContentText(message)
            .setAutoCancel(true)
            .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(ALERT_NOTIFICATION_ID, notification)
    }
}
