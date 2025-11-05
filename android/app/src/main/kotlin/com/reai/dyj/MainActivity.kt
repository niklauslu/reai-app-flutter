package com.reai.dyj

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import android.os.Bundle
import com.reaiapp.reai_assistant.NativeServiceManager
import com.reaiapp.reai_assistant.MqttServiceModule

class MainActivity : FlutterActivity() {

    private var nativeServiceManager: NativeServiceManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 启动前台服务
        startForegroundService()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化原生服务管理器
        nativeServiceManager = NativeServiceManager.getInstance()
        nativeServiceManager?.initializeFlutterCommunication(flutterEngine)
    }

    override fun onDestroy() {
        // 停止前台服务
        stopForegroundService()

        super.onDestroy()
    }

    /**
     * 启动前台服务
     */
    private fun startForegroundService() {
        val serviceIntent = Intent(this, NativeServiceManager::class.java).apply {
            action = "START_SERVICE"
            putExtra("service_type", NativeServiceManager.SERVICE_TYPE_MQTT)
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        // 注册MQTT服务模块
        nativeServiceManager?.let { manager ->
            manager.registerServiceModule(MqttServiceModule())
        }
    }

    /**
     * 停止前台服务
     */
    private fun stopForegroundService() {
        val serviceIntent = Intent(this, NativeServiceManager::class.java).apply {
            action = "STOP_SERVICE"
        }
        stopService(serviceIntent)
    }
}