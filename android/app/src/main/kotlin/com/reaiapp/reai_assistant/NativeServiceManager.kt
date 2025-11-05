package com.reaiapp.reai_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.runBlocking
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import com.reai.dyj.MainActivity

/**
 * 通用前台服务管理器
 * 支持多种后台服务模块（MQTT、BLE等）
 */
class NativeServiceManager : Service() {

    companion object {
        private const val TAG = "NativeServiceManager"
        private const val NOTIFICATION_CHANNEL_ID = "reai_service_channel"
        private const val NOTIFICATION_ID = 1001
        private const val SERVICE_MANAGER_CHANNEL = "com.reaiapp/native_service_manager"
        private const val SERVICE_EVENT_CHANNEL = "com.reaiapp/service_events"

        // 服务类型常量
        const val SERVICE_TYPE_MQTT = "mqtt"
        const val SERVICE_TYPE_BLE = "ble"
        const val SERVICE_TYPE_DEVICE_MANAGER = "device_manager"
        const val SERVICE_TYPE_CUSTOM = "custom"

        // 服务状态常量
        const val SERVICE_STATUS_STOPPED = "stopped"
        const val SERVICE_STATUS_STARTING = "starting"
        const val SERVICE_STATUS_RUNNING = "running"
        const val SERVICE_STATUS_STOPPING = "stopping"
        const val SERVICE_STATUS_ERROR = "error"

        // 单例实例
        @Volatile
        private var instance: NativeServiceManager? = null

        fun getInstance(): NativeServiceManager {
            return instance ?: synchronized(this) {
                instance ?: NativeServiceManager().also { instance = it }
            }
        }

        // 获取服务状态
        fun getServiceStatus(serviceType: String): String {
            return getInstance().serviceModules[serviceType]?.status ?: SERVICE_STATUS_STOPPED
        }

        // 获取所有服务状态
        fun getAllServiceStatus(): Map<String, String> {
            return getInstance().serviceModules.mapValues { it.value.status }
        }
    }

    // 服务模块管理
    private val serviceModules = mutableMapOf<String, ServiceModule>()

    // Flutter通信
    private var methodChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var flutterEngine: FlutterEngine? = null

    // 服务状态
    private var isServiceRunning = false

    /**
     * 服务模块接口
     */
    interface ServiceModule {
        val serviceType: String
        var status: String
        var config: Map<String, Any>

        suspend fun onStart(context: Context, config: Map<String, Any>)
        suspend fun onStop(context: Context)
        suspend fun onCommand(context: Context, command: String, params: Map<String, Any>): Any?
        suspend fun onConfigure(config: Map<String, Any>)
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NativeServiceManager onCreate")

        // 创建通知渠道
        createNotificationChannel()

        // 初始化服务
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "NativeServiceManager onStartCommand")

        if (!isServiceRunning) {
            startForegroundService()
            isServiceRunning = true
        }

        // 处理服务命令
        intent?.let { handleServiceCommand(it) }

        return START_STICKY // 确保服务重启
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "NativeServiceManager onDestroy")

        // 停止所有服务模块
        runBlocking {
            stopAllServiceModules()
        }

        // 停止前台服务
        stopForeground(true)
        stopSelf()

        isServiceRunning = false
        instance = null

        super.onDestroy()
    }

    /**
     * 处理服务命令
     */
    private fun handleServiceCommand(intent: Intent) {
        val action = intent.action
        val serviceType = intent.getStringExtra("service_type")
        val command = intent.getStringExtra("command")
        val params = intent.getStringExtra("params")?.let {
            try { JSONObject(it).toMap() } catch (e: Exception) { emptyMap() }
        } ?: emptyMap<String, Any>()

        Log.d(TAG, "处理服务命令: action=$action, serviceType=$serviceType, command=$command")

        when (action) {
            "START_SERVICE" -> {
                serviceType?.let {
                    runBlocking { startServiceModule(it, params) }
                }
            }
            "STOP_SERVICE" -> {
                serviceType?.let {
                    runBlocking { stopServiceModule(it) }
                }
            }
            "CONFIGURE_SERVICE" -> {
                serviceType?.let {
                    runBlocking { configureServiceModule(it, params) }
                }
            }
            "SEND_COMMAND" -> {
                serviceType?.let {
                    command?.let { cmd ->
                        runBlocking { sendServiceCommand(it, cmd, params) }
                    }
                }
            }
        }
    }

    /**
     * 启动前台服务
     */
    private fun startForegroundService() {
        val notification = createServiceNotification()
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "前台服务已启动")
    }

    /**
     * 创建通知渠道
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "ReAI服务",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "ReAI后台服务运行状态通知"
                setShowBadge(true)
                enableVibration(false)
                setSound(null, null)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * 创建服务通知
     */
    private fun createServiceNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("ReAI Assistant")
            .setContentText("后台服务运行中")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    /**
     * 更新服务通知
     */
    private fun updateNotification() {
        val runningServices = serviceModules.filter { it.value.status == SERVICE_STATUS_RUNNING }
        val serviceCount = runningServices.size
        val serviceNames = runningServices.keys.joinToString(", ") { getServiceDisplayName(it) }

        val notification = if (serviceCount > 0) {
            NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("ReAI Assistant")
                .setContentText("${serviceCount}个服务运行中: $serviceNames")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(getNotificationPendingIntent())
                .setOngoing(true)
                .setShowWhen(false)
                .build()
        } else {
            createServiceNotification()
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun getNotificationPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun getServiceDisplayName(serviceType: String): String {
        return when (serviceType) {
            SERVICE_TYPE_MQTT -> "MQTT"
            SERVICE_TYPE_BLE -> "BLE"
            SERVICE_TYPE_DEVICE_MANAGER -> "设备管理"
            else -> serviceType
        }
    }

    /**
     * 启动服务模块
     */
    private suspend fun startServiceModule(serviceType: String, config: Map<String, Any>) {
        Log.d(TAG, "启动服务模块: $serviceType")

        val module = serviceModules[serviceType]
        if (module == null) {
            Log.e(TAG, "服务模块不存在: $serviceType")
            sendServiceEvent(serviceType, "error", mapOf("message" to "服务模块不存在"))
            return
        }

        if (module.status == SERVICE_STATUS_RUNNING) {
            Log.w(TAG, "服务模块已在运行: $serviceType")
            return
        }

        try {
            module.status = SERVICE_STATUS_STARTING
            sendServiceEvent(serviceType, "status_changed", mapOf("status" to SERVICE_STATUS_STARTING))

            module.onStart(this, config)
            module.status = SERVICE_STATUS_RUNNING
            module.config = config

            sendServiceEvent(serviceType, "started", emptyMap())
            updateNotification()

            Log.d(TAG, "服务模块启动成功: $serviceType")
        } catch (e: Exception) {
            Log.e(TAG, "启动服务模块失败: $serviceType", e)
            module.status = SERVICE_STATUS_ERROR
            sendServiceEvent(serviceType, "error", mapOf(
                "message" to "启动失败: ${e.message}",
                "error" to e.toString()
            ))
        }
    }

    /**
     * 停止服务模块
     */
    private suspend fun stopServiceModule(serviceType: String) {
        Log.d(TAG, "停止服务模块: $serviceType")

        val module = serviceModules[serviceType] ?: return

        if (module.status == SERVICE_STATUS_STOPPED) {
            Log.w(TAG, "服务模块已停止: $serviceType")
            return
        }

        try {
            module.status = SERVICE_STATUS_STOPPING
            sendServiceEvent(serviceType, "status_changed", mapOf("status" to SERVICE_STATUS_STOPPING))

            module.onStop(this)
            module.status = SERVICE_STATUS_STOPPED

            sendServiceEvent(serviceType, "stopped", emptyMap())
            updateNotification()

            Log.d(TAG, "服务模块停止成功: $serviceType")
        } catch (e: Exception) {
            Log.e(TAG, "停止服务模块失败: $serviceType", e)
            module.status = SERVICE_STATUS_ERROR
            sendServiceEvent(serviceType, "error", mapOf(
                "message" to "停止失败: ${e.message}",
                "error" to e.toString()
            ))
        }
    }

    /**
     * 配置服务模块
     */
    private suspend fun configureServiceModule(serviceType: String, config: Map<String, Any>) {
        Log.d(TAG, "配置服务模块: $serviceType, config=$config")

        val module = serviceModules[serviceType] ?: return

        try {
            module.onConfigure(config)
            module.config = config
            sendServiceEvent(serviceType, "configured", config)
            Log.d(TAG, "服务模块配置成功: $serviceType")
        } catch (e: Exception) {
            Log.e(TAG, "配置服务模块失败: $serviceType", e)
            sendServiceEvent(serviceType, "error", mapOf(
                "message" to "配置失败: ${e.message}",
                "error" to e.toString()
            ))
        }
    }

    /**
     * 发送服务命令
     */
    private suspend fun sendServiceCommand(serviceType: String, command: String, params: Map<String, Any>) {
        Log.d(TAG, "发送服务命令: $serviceType, command=$command, params=$params")

        val module = serviceModules[serviceType] ?: return

        try {
            val result = module.onCommand(this, command, params)
            sendServiceEvent(serviceType, "command_result", mapOf(
                "command" to command,
                "result" to (result ?: "success")
            ))
            Log.d(TAG, "服务命令执行成功: $serviceType")
        } catch (e: Exception) {
            Log.e(TAG, "执行服务命令失败: $serviceType", e)
            sendServiceEvent(serviceType, "error", mapOf(
                "message" to "命令执行失败: ${e.message}",
                "error" to e.toString()
            ))
        }
    }

    /**
     * 停止所有服务模块
     */
    private suspend fun stopAllServiceModules() {
        Log.d(TAG, "停止所有服务模块")

        serviceModules.values.forEach { module ->
            if (module.status == SERVICE_STATUS_RUNNING) {
                try {
                    module.status = SERVICE_STATUS_STOPPING
                    module.onStop(this)
                    module.status = SERVICE_STATUS_STOPPED
                } catch (e: Exception) {
                    Log.e(TAG, "停止服务模块失败: ${module.serviceType}", e)
                }
            }
        }
    }

    /**
     * 注册服务模块
     */
    fun registerServiceModule(module: ServiceModule) {
        Log.d(TAG, "注册服务模块: ${module.serviceType}")
        serviceModules[module.serviceType] = module
        module.status = SERVICE_STATUS_STOPPED
        module.config = emptyMap()
    }

    /**
     * 发送服务事件到Flutter
     */
    private fun sendServiceEvent(serviceType: String, eventName: String, data: Map<String, Any>) {
        val eventData = mapOf(
            "serviceType" to serviceType,
            "eventName" to eventName,
            "data" to data,
            "timestamp" to System.currentTimeMillis()
        )

        // 确保在主线程发送Flutter事件
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(eventData)
        }
        Log.d(TAG, "📤 发送服务事件: $eventData")
    }

    /**
     * 初始化Flutter通信
     */
    fun initializeFlutterCommunication(engine: FlutterEngine) {
        Log.d(TAG, "初始化Flutter通信")

        this.flutterEngine = engine

        // 初始化方法通道
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, SERVICE_MANAGER_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        // 初始化事件通道
        EventChannel(engine.dartExecutor.binaryMessenger, SERVICE_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "🔌 Flutter事件通道已连接")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "🔌 Flutter事件通道已断开")
                }
            }
        )

        // 发送初始状态
        sendServiceEvent("system", "service_ready", mapOf(
            "version" to "1.0.0",
            "supported_services" to serviceModules.keys.toList()
        ))
    }

    /**
     * 处理Flutter方法调用
     */
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "📞 处理Flutter方法调用: ${call.method}")

        try {
            when (call.method) {
                "startService" -> {
                    val serviceType = call.argument<String>("service_type")!!
                    val config = call.argument<Map<String, Any>>("config") ?: emptyMap()

                    // 启动服务
                    Thread {
                        try {
                            runBlocking {
                                startServiceModule(serviceType, config)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ 启动服务失败", e)
                            result.error("SERVICE_START_FAILED", e.message, e.toString())
                        }
                    }.start()
                }

                "stopService" -> {
                    val serviceType = call.argument<String>("service_type")!!

                    Thread {
                        try {
                            runBlocking {
                                stopServiceModule(serviceType)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "⏹️ 停止服务失败", e)
                            result.error("SERVICE_STOP_FAILED", e.message, e.toString())
                        }
                    }.start()
                }

                "getServiceStatus" -> {
                    val serviceType = call.argument<String>("service_type")!!
                    val status = serviceModules[serviceType]?.status ?: SERVICE_STATUS_STOPPED
                    result.success(status)
                }

                "getAllServiceStatus" -> {
                    val statusMap = serviceModules.mapValues { it.value.status }
                    result.success(statusMap)
                }

                "configureService" -> {
                    val serviceType = call.argument<String>("service_type")!!
                    val config = call.argument<Map<String, Any>>("config") ?: emptyMap()

                    Thread {
                        try {
                            runBlocking {
                                configureServiceModule(serviceType, config)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "⚙️ 配置服务失败", e)
                            result.error("SERVICE_CONFIGURE_FAILED", e.message, e.toString())
                        }
                    }.start()
                }

                "sendCommand" -> {
                    val serviceType = call.argument<String>("service_type")!!
                    val command = call.argument<String>("command")!!
                    val params = call.argument<Map<String, Any>>("params") ?: emptyMap()

                    Thread {
                        try {
                            val commandResult = runBlocking {
                                sendServiceCommand(serviceType, command, params)
                            }
                            result.success(commandResult)
                        } catch (e: Exception) {
                            Log.e(TAG, "📤 发送命令失败", e)
                            result.error("COMMAND_FAILED", e.message, e.toString())
                        }
                    }.start()
                }

                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理方法调用异常", e)
            result.error("METHOD_CALL_ERROR", e.message, e.toString())
        }
    }
}

/**
 * JSONObject转Map扩展函数
 */
fun JSONObject.toMap(): Map<String, Any> {
    val map = mutableMapOf<String, Any>()
    keys().forEach { key ->
        map[key] = opt(key)
    }
    return map
}