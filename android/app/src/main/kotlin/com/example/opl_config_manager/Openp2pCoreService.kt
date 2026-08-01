package com.example.opl_config_manager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import openp2p.Openp2p
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Runs the native OpenP2P module outside the Flutter UI process.
 *
 * The current OpenP2P Android module can terminate its host process after a
 * websocket/control-channel failure. Keeping it in :core prevents that exit
 * from taking down the Flutter activity as well.
 */
class Openp2pCoreService : VpnService() {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val preferences by lazy {
        getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
    }
    @Volatile private var stopping = false
    @Volatile private var coreStarted = false

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            preferences.edit().putBoolean(KEY_DESIRED_RUNNING, false).apply()
            stopping = true
            stopSelf()
            return START_NOT_STICKY
        }

        val shouldStart = intent?.action == ACTION_START ||
            (intent == null && preferences.getBoolean(KEY_DESIRED_RUNNING, false))
        if (shouldStart) {
            if (coreStarted) {
                Log.w(TAG, "OpenP2P core is already running")
                return START_STICKY
            }
            val baseDir = intent?.getStringExtra(EXTRA_BASE_DIR)
                ?: preferences.getString(EXTRA_BASE_DIR, "").orEmpty()
            val token = intent?.getStringExtra(EXTRA_TOKEN)
                ?: preferences.getString(EXTRA_TOKEN, "").orEmpty()
            val shareBandwidth = intent?.getIntExtra(EXTRA_SHARE_BANDWIDTH, 0)
                ?: preferences.getInt(EXTRA_SHARE_BANDWIDTH, 0)
            val logLevel = intent?.getIntExtra(EXTRA_LOG_LEVEL, 1)
                ?: preferences.getInt(EXTRA_LOG_LEVEL, 1)
            preferences.edit()
                .putBoolean(KEY_DESIRED_RUNNING, true)
                .putString(EXTRA_BASE_DIR, baseDir)
                .putString(EXTRA_TOKEN, token)
                .putInt(EXTRA_SHARE_BANDWIDTH, shareBandwidth)
                .putInt(EXTRA_LOG_LEVEL, logLevel)
                .apply()
            stopping = false
            coreStarted = true

            executor.execute {
                runCore(baseDir, token, shareBandwidth, logLevel)
                coreStarted = false
                if (!stopping) {
                    Log.e(TAG, "OpenP2P core stopped unexpectedly; keeping UI process alive")
                }
                stopSelfResult(startId)
            }
        }

        return START_STICKY
    }

    private fun runCore(
        baseDir: String,
        token: String,
        shareBandwidth: Int,
        logLevel: Int,
    ) {
        var attempt = 0
        while (!stopping) {
            attempt++
            try {
                Log.d(TAG, "Starting core in isolated service process (attempt $attempt)")
                val network = Openp2p.runAsModule(
                    baseDir,
                    token,
                    shareBandwidth.toLong(),
                    logLevel.toLong(),
                )

                // The reference Android client explicitly connects the
                // returned P2PNetwork after runAsModule. Without this call
                // the websocket keep-alive worker never completes login and
                // eventually reports "wgReconnect.Wait() timeout".
                var connected = network.connect(CONNECT_TIMEOUT_MS)
                Log.i(TAG, "P2PNetwork connect result: $connected")
                while (!stopping && connected) {
                    Thread.sleep(CONNECT_POLL_INTERVAL_MS)
                    connected = network.connect(CONNECT_TIMEOUT_MS)
                }
                if (!stopping) {
                    Log.w(TAG, "P2PNetwork disconnected")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "OpenP2P core failed on attempt $attempt", t)
            }

            if (!stopping && attempt < MAX_RECONNECT_ATTEMPTS) {
                try {
                    Thread.sleep(RECONNECT_DELAY_MS)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }
            }

            if (!stopping && attempt >= MAX_RECONNECT_ATTEMPTS) {
                Log.w(TAG, "Waiting before background reconnect")
                try {
                    Thread.sleep(BACKGROUND_RECONNECT_DELAY_MS)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }
                attempt = 0
            }
        }
    }

    override fun onDestroy() {
        stopping = true
        coreStarted = false
        try {
            Openp2p.stopModule()
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to stop OpenP2P core", t)
        }
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundServiceNotification() {
        val channelId = "opl_core"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "OPL 核心服务",
                NotificationManager.IMPORTANCE_LOW,
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("OPL联机工具")
            .setContentText("核心服务运行中")
            .setOngoing(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val TAG = "OPL-Core"
        const val ACTION_START = "com.example.opl_config_manager.action.START_CORE"
        const val ACTION_STOP = "com.example.opl_config_manager.action.STOP_CORE"
        const val EXTRA_BASE_DIR = "baseDir"
        const val EXTRA_TOKEN = "token"
        const val EXTRA_SHARE_BANDWIDTH = "shareBandwidth"
        const val EXTRA_LOG_LEVEL = "logLevel"
        private const val MAX_RECONNECT_ATTEMPTS = 3
        private const val RECONNECT_DELAY_MS = 5000L
        private const val BACKGROUND_RECONNECT_DELAY_MS = 15000L
        private const val CONNECT_TIMEOUT_MS = 30000L
        private const val CONNECT_POLL_INTERVAL_MS = 1000L
        private const val NOTIFICATION_ID = 1337
        private const val PREFERENCES_NAME = "openp2p_core_service"
        private const val KEY_DESIRED_RUNNING = "desired_running"
    }
}
