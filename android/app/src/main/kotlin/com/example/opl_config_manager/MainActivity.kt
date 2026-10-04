package com.example.opl_config_manager

import android.content.Intent
import android.app.ActivityManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.opl_config_manager/core"
    private var pendingCoreResult: MethodChannel.Result? = null
    private var pendingCoreIntent: Intent? = null
    private val vpnRequestCode = 1338
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCore" -> {
                    val baseDir = call.argument<String>("baseDir") ?: ""
                    val token = call.argument<String>("token") ?: ""
                    val shareBandwidth = call.argument<Int>("shareBandwidth") ?: 0
                    val logLevel = call.argument<Int>("logLevel") ?: 1
                    val intent = Intent(this, Openp2pCoreService::class.java).apply {
                        action = Openp2pCoreService.ACTION_START
                        putExtra(Openp2pCoreService.EXTRA_BASE_DIR, baseDir)
                        putExtra(Openp2pCoreService.EXTRA_TOKEN, token)
                        putExtra(Openp2pCoreService.EXTRA_SHARE_BANDWIDTH, shareBandwidth)
                        putExtra(Openp2pCoreService.EXTRA_LOG_LEVEL, logLevel)
                    }
                    if (pendingCoreResult != null) {
                        result.error("CORE_STARTING", "VPN authorization is pending", null)
                        return@setMethodCallHandler
                    }
                    val permission = VpnService.prepare(this)
                    if (permission == null) {
                        launchCore(intent, result)
                    } else {
                        pendingCoreResult = result
                        pendingCoreIntent = intent
                        @Suppress("DEPRECATION")
                        startActivityForResult(permission, vpnRequestCode)
                    }
                }
                "stopCore" -> {
                    try {
                        val intent = Intent(this, Openp2pCoreService::class.java).apply {
                            action = Openp2pCoreService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Throwable) {
                        Log.e("OPL", "Failed to stop core service", e)
                        result.success(false)
                    }
                }
                "isCoreRunning" -> {
                    @Suppress("DEPRECATION")
                    val running = (getSystemService(ACTIVITY_SERVICE) as ActivityManager)
                        .getRunningServices(Int.MAX_VALUE)
                        .any { it.service.className == Openp2pCoreService::class.java.name }
                    result.success(running)
                }
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath").orEmpty()
                    val apkFile = File(apkPath)
                    if (!apkFile.isFile) {
                        result.error("APK_NOT_FOUND", "APK file does not exist", null)
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        val settingsIntent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(settingsIntent)
                        result.error(
                            "INSTALL_PERMISSION_REQUIRED",
                            "请允许此应用安装未知来源应用，然后重试更新",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            apkFile,
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Throwable) {
                        Log.e("OPL", "Failed to open APK installer", e)
                        result.error("APK_INSTALL_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun launchCore(intent: Intent, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
            else startService(intent)
            result.success(true)
        } catch (error: Throwable) {
            Log.e("OPL", "Failed to start core service", error)
            result.error("CORE_START_FAILED", error.message, null)
        }
    }

    @Deprecated("Legacy activity result bridge for FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != vpnRequestCode) return
        val result = pendingCoreResult
        val intent = pendingCoreIntent
        pendingCoreResult = null
        pendingCoreIntent = null
        if (result == null) return
        if (resultCode == RESULT_OK && intent != null) launchCore(intent, result)
        else result.success(false)
    }
}
