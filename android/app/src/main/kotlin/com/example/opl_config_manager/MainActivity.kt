package com.example.opl_config_manager

import android.content.Context
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
                    startCoreNative(baseDir)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun startCoreNative(baseDir: String) {
        try {
            Log.d("OPL", "Starting core with baseDir: $baseDir")
            
            // Load the native library
            System.loadLibrary("openp2p")
            
            // Call the native function
            RunOHOS(baseDir)
            
            Log.d("OPL", "Core started successfully")
        } catch (e: Exception) {
            Log.e("OPL", "Failed to start core: ${e.message}", e)
        }
    }
    
    private external fun RunOHOS(baseDir: String)
}
