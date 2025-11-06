import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../mqtt/mqtt_service.dart';
import '../mqtt/models/mqtt_message.dart';

/// iOS后台服务管理器
/// 专门处理iOS平台的后台任务和MQTT保活
class IOSBackgroundService {
  static const MethodChannel _heartbeatChannel =
      MethodChannel('com.reaiapp/background_heartbeat');
  static const MethodChannel _bleChannel =
      MethodChannel('com.reaiapp/ble_check');

  static bool _isInitialized = false;
  static Timer? _heartbeatResponseTimer;

  /// 初始化iOS后台服务
  static Future<void> initialize() async {
    if (!Platform.isIOS || _isInitialized) return;

    try {
      print('🍎 初始化iOS后台服务...');

      // 设置心跳监听
      _heartbeatChannel.setMethodCallHandler(_handleHeartbeat);

      // 设置BLE检查监听
      _bleChannel.setMethodCallHandler(_handleBleCheck);

      _isInitialized = true;
      print('✅ iOS后台服务初始化成功');
    } catch (e) {
      print('❌ iOS后台服务初始化失败: $e');
    }
  }

  /// 处理来自iOS原生端的心跳
  static Future<dynamic> _handleHeartbeat(MethodCall call) async {
    if (call.method == 'heartbeat') {
      final arguments = call.arguments as Map<dynamic, dynamic>;
      final timestamp = arguments['timestamp'] as double;

      print('🍎 收到iOS后台心跳: ${DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())}');

      // 执行MQTT保活操作
      await _performMqttKeepalive();

      return {'status': 'success', 'timestamp': timestamp};
    }
    return null;
  }

  /// 处理BLE状态检查
  static Future<dynamic> _handleBleCheck(MethodCall call) async {
    if (call.method == 'checkBleStatus') {
      print('🍎 iOS后台BLE状态检查');

      // 这里可以添加BLE连接状态检查逻辑
      // 目前只是记录日志

      return {'status': 'checked'};
    }
    return null;
  }

  /// 执行MQTT保活操作
  static Future<void> _performMqttKeepalive() async {
    try {
      final mqttService = MQTTService();
      final currentStatus = mqttService.currentStatus;

      print('🍎 iOS后台MQTT保活检查 - 当前状态: ${currentStatus.toString().split('.').last}');

      if (currentStatus != MQTTConnectionStatus.connected) {
        print('🍎 iOS后台检测到MQTT断开，尝试重连...');
        try {
          await mqttService.connect();
          print('✅ iOS后台MQTT重连成功');
        } catch (e) {
          print('❌ iOS后台MQTT重连失败: $e');
        }
      } else {
        // 如果已连接，发送在线状态保持连接活跃
        try {
          await mqttService.sendOnlineStatus();
          print('💓 iOS后台MQTT心跳成功');
        } catch (e) {
          print('⚠️ iOS后台MQTT心跳失败: $e');

          // 心跳失败，尝试重连
          try {
            await mqttService.connect();
            print('✅ iOS后台心跳失败后重连成功');
          } catch (reconnectError) {
            print('❌ iOS后台心跳失败后重连也失败: $reconnectError');
          }
        }
      }

      // 确保连接状态在后台被正确更新
      print('🍎 iOS后台保活操作完成');

    } catch (e) {
      print('❌ iOS后台MQTT保活操作失败: $e');
    }
  }

  /// 启动心跳响应定时器（用于主动保活）
  static void startHeartbeatResponse() {
    if (!Platform.isIOS) return;

    _heartbeatResponseTimer?.cancel();

    print('🍎 启动iOS心跳响应定时器');

    // 每45秒执行一次保活操作（在iOS允许的时间范围内）
    _heartbeatResponseTimer = Timer.periodic(Duration(seconds: 45), (timer) async {
      if (Platform.isIOS) {
        await _performMqttKeepalive();
      }
    });
  }

  /// 停止心跳响应定时器
  static void stopHeartbeatResponse() {
    _heartbeatResponseTimer?.cancel();
    _heartbeatResponseTimer = null;
    print('🍎 iOS心跳响应定时器已停止');
  }

  /// 清理资源
  static Future<void> dispose() async {
    if (!Platform.isIOS || !_isInitialized) return;

    try {
      stopHeartbeatResponse();

      _heartbeatChannel.setMethodCallHandler(null);
      _bleChannel.setMethodCallHandler(null);

      _isInitialized = false;
      print('✅ iOS后台服务已清理');
    } catch (e) {
      print('❌ iOS后台服务清理失败: $e');
    }
  }

  /// 获取初始化状态
  static bool get isInitialized => _isInitialized;
}