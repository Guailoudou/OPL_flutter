package com.example.opl_config_manager

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.opl_config_manager/core"
    
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
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Throwable) {
                        Log.e("OPL", "Failed to start core service", e)
                        result.success(false)
                    }
                }
                "stopCore" -> {
                    try {
                        val intent = Intent(this, Openp2pCoreService::class.java).apply {
                            action = Openp2pCoreService.ACTION_STOP
                        }
                        startService(intent)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Throwable) {
                        Log.e("OPL", "Failed to stop core service", e)
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
