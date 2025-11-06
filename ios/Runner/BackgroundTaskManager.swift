import UIKit
import BackgroundTasks
import Flutter

@available(iOS 13.0, *)
class BackgroundTaskManager {

    static let shared = BackgroundTaskManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var mqttKeepaliveTask: BGAppRefreshTask?

    // 后台任务标识符
    let mqttKeepaliveIdentifier = "com.reaiapp.mqtt.keepalive"
    let bleMonitorIdentifier = "com.reaiapp.ble.monitor"

    private init() {}

    /// 注册后台任务
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: mqttKeepaliveIdentifier, using: nil) { task in
            self.handleMqttKeepalive(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: bleMonitorIdentifier, using: nil) { task in
            self.handleBleMonitor(task: task as! BGAppRefreshTask)
        }

        print("✅ iOS后台任务已注册")
    }

    /// 开始MQTT保活后台任务
    func startMqttKeepaliveTask() {
        let request = BGAppRefreshTaskRequest(identifier: mqttKeepaliveIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30秒后开始

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ MQTT保活任务已提交")
        } catch {
            print("❌ 提交MQTT保活任务失败: \(error)")
        }
    }

    /// 处理MQTT保活任务
    private func handleMqttKeepalive(task: BGAppRefreshTask) {
        print("🔄 执行MQTT保活任务")

        // 设置操作句柄
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            print("⏰ MQTT保活任务超时")
        }

        // 执行MQTT连接检查和保活
        let operationQueue = OperationQueue()
        let operation = BlockOperation {
            // 发送心跳包到Flutter端
            self.sendHeartbeatToFlutter()

            // 安排下一次保活任务
            self.scheduleNextMqttKeepalive()

            task.setTaskCompleted(success: true)
        }

        operationQueue.addOperation(operation)
        mqttKeepaliveTask = task
    }

    /// 处理BLE监控任务
    private func handleBleMonitor(task: BGAppRefreshTask) {
        print("🔄 执行BLE监控任务")

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            print("⏰ BLE监控任务超时")
        }

        let operationQueue = OperationQueue()
        let operation = BlockOperation {
            // 检查BLE连接状态
            self.checkBleConnectionStatus()

            task.setTaskCompleted(success: true)
        }

        operationQueue.addOperation(operation)
    }

    /// 发送心跳到Flutter端
    private func sendHeartbeatToFlutter() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let flutterViewController = window.rootViewController as? FlutterViewController else {
            print("⚠️ 无法获取FlutterViewController")
            return
        }

        let messenger = flutterViewController.engine.binaryMessenger
        let channel = FlutterMethodChannel(name: "com.reaiapp/background_heartbeat", binaryMessenger: messenger)

        channel.invokeMethod("heartbeat", arguments: ["timestamp": Date().timeIntervalSince1970])
    }

    /// 检查BLE连接状态
    private func checkBleConnectionStatus() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let flutterViewController = window.rootViewController as? FlutterViewController else {
            print("⚠️ 无法获取FlutterViewController进行BLE检查")
            return
        }

        let messenger = flutterViewController.engine.binaryMessenger
        let channel = FlutterMethodChannel(name: "com.reaiapp/ble_check", binaryMessenger: messenger)

        channel.invokeMethod("checkBleStatus", arguments: nil)
    }

    /// 安排下一次MQTT保活任务
    private func scheduleNextMqttKeepalive() {
        let request = BGAppRefreshTaskRequest(identifier: mqttKeepaliveIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 60秒后再次执行

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ 下一次MQTT保活任务已安排")
        } catch {
            print("❌ 安排下一次MQTT保活任务失败: \(error)")
        }
    }

    /// 开始应用后台任务（短期任务）
    func startBackgroundTask() {
        endBackgroundTask()

        backgroundTask = UIApplication.shared.beginBackgroundTask {
            self.endBackgroundTask()
        }

        print("✅ iOS后台任务已开始")
    }

    /// 结束应用后台任务
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("✅ iOS后台任务已结束")
        }
    }

    /// 取消所有后台任务
    func cancelAllBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: mqttKeepaliveIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: bleMonitorIdentifier)
        endBackgroundTask()
        print("✅ 所有后台任务已取消")
    }
}