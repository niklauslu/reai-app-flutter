import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../mqtt/mqtt_config.dart';

/// 服务类型枚举
enum ServiceType {
  mqtt,
  ble,
  deviceManager,
  custom,
}

/// 服务状态枚举
enum ServiceStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

/// 服务事件数据
class ServiceEvent {
  final ServiceType serviceType;
  final String eventName;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ServiceEvent({
    required this.serviceType,
    required this.eventName,
    required this.data,
    required this.timestamp,
  });

  factory ServiceEvent.fromMap(Map<String, dynamic> map) {
    return ServiceEvent(
      serviceType: _parseServiceType(map['serviceType']),
      eventName: map['eventName'],
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  static ServiceType _parseServiceType(String? type) {
    switch (type) {
      case 'mqtt':
        return ServiceType.mqtt;
      case 'ble':
        return ServiceType.ble;
      case 'device_manager':
        return ServiceType.deviceManager;
      case 'custom':
        return ServiceType.custom;
      default:
        return ServiceType.custom;
    }
  }
}

/// 服务状态数据
class ServiceStatusData {
  final ServiceType serviceType;
  final ServiceStatus status;
  final String? error;
  final Map<String, dynamic> config;
  final DateTime timestamp;

  ServiceStatusData({
    required this.serviceType,
    required this.status,
    this.error,
    this.config = const {},
    required this.timestamp,
  });

  factory ServiceStatusData.fromMap(Map<String, dynamic> map) {
    return ServiceStatusData(
      serviceType: ServiceEvent._parseServiceType(map['serviceType']),
      status: _parseStatus(map['status']),
      error: map['error'],
      config: Map<String, dynamic>.from(map['config'] ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  static ServiceStatus _parseStatus(String? status) {
    switch (status) {
      case 'stopped':
        return ServiceStatus.stopped;
      case 'starting':
        return ServiceStatus.starting;
      case 'running':
        return ServiceStatus.running;
      case 'stopping':
        return ServiceStatus.stopping;
      case 'error':
        return ServiceStatus.error;
      default:
        return ServiceStatus.stopped;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceType': serviceType.name,
      'status': status.name,
      if (error != null) 'error': error,
      if (config.isNotEmpty) 'config': config,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// 原生服务管理器
/// 管理Android原生前台服务中的各种服务模块
class NativeServiceManager {
  static const String _methodChannelName = 'com.reaiapp/native_service_manager';
  static const String _eventChannelName = 'com.reaiapp/service_events';

  static final NativeServiceManager _instance = NativeServiceManager._internal();
  factory NativeServiceManager() => _instance;
  NativeServiceManager._internal();

  final MethodChannel _methodChannel = const MethodChannel(_methodChannelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);
  StreamController<ServiceEvent>? _eventController;
  StreamSubscription? _eventSubscription;

  bool _isInitialized = false;
  final Map<ServiceType, ServiceStatusData> _serviceStatus = {};

  /// 初始化服务管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔧 初始化原生服务管理器...');

      // 初始化事件通道
      _eventController = StreamController<ServiceEvent>.broadcast();
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) {
          print('❌ 服务事件通道错误: $error');
        },
      );

      // 设置方法通道处理器
      _methodChannel.setMethodCallHandler(_handleMethodCall);

      _isInitialized = true;
      print('✅ 原生服务管理器初始化成功');
    } catch (e) {
      print('❌ 原生服务管理器初始化失败: $e');
      rethrow;
    }
  }

  /// 启动服务
  Future<bool> startService(
    ServiceType serviceType, {
    Map<String, dynamic>? config,
  }) async {
    try {
      print('🚀 启动服务: ${serviceType.name}');

      final args = <String, dynamic>{
        'service_type': serviceType.name,
        'config': config ?? {},
      };

      final result = await _methodChannel.invokeMethod('startService', args);
      return result == true;
    } catch (e) {
      print('❌ 启动服务失败: ${serviceType.name}, 错误: $e');
      return false;
    }
  }

  /// 停止服务
  Future<bool> stopService(ServiceType serviceType) async {
    try {
      print('⏹️ 停止服务: ${serviceType.name}');

      final args = <String, dynamic>{
        'service_type': serviceType.name,
      };

      final result = await _methodChannel.invokeMethod('stopService', args);
      return result == true;
    } catch (e) {
      print('❌ 停止服务失败: ${serviceType.name}, 错误: $e');
      return false;
    }
  }

  /// 获取服务状态
  Future<ServiceStatus?> getServiceStatus(ServiceType serviceType) async {
    try {
      final args = <String, dynamic>{
        'service_type': serviceType.name,
      };

      final result = await _methodChannel.invokeMethod('getServiceStatus', args);
      return _parseStatus(result);
    } catch (e) {
      print('❌ 获取服务状态失败: ${serviceType.name}, 错误: $e');
      return null;
    }
  }

  /// 获取所有服务状态
  Future<Map<ServiceType, ServiceStatus?>> getAllServiceStatus() async {
    try {
      final result = await _methodChannel.invokeMethod('getAllServiceStatus');
      if (result is Map<String, dynamic>) {
        final statusMap = <ServiceType, ServiceStatus?>{};
        result.forEach((key, value) {
          final serviceType = _parseServiceType(key);
          statusMap[serviceType] = _parseStatus(value);
        });
        return statusMap;
      }
      return {};
    } catch (e) {
      print('❌ 获取所有服务状态失败, 错误: $e');
      return {};
    }
  }

  /// 配置服务
  Future<bool> configureService(
    ServiceType serviceType,
    Map<String, dynamic> config,
  ) async {
    try {
      print('⚙️ 配置服务: ${serviceType.name}');

      final args = <String, dynamic>{
        'service_type': serviceType.name,
        'config': config,
      };

      final result = await _methodChannel.invokeMethod('configureService', args);
      return result == true;
    } catch (e) {
      print('❌ 配置服务失败: ${serviceType.name}, 错误: $e');
      return false;
    }
  }

  /// 发送服务命令
  Future<dynamic> sendCommand(
    ServiceType serviceType,
    String command, {
    Map<String, dynamic>? params,
  }) async {
    try {
      print('📤 发送命令: ${serviceType.name}.$command');

      final args = <String, dynamic>{
        'service_type': serviceType.name,
        'command': command,
        'params': params ?? {},
      };

      return await _methodChannel.invokeMethod('sendCommand', args);
    } catch (e) {
      print('❌ 发送命令失败: ${serviceType.name}.$command, 错误: $e');
      return null;
    }
  }

  /// 启动MQTT服务
  Future<bool> startMqttService({
    String? deviceId,
    String? server,
    int? port,
    String? username,
    String? password,
  }) async {
    final config = {
      'server': server ?? MQTTConfig.server,
      'port': port ?? MQTTConfig.port,
      'username': username ?? MQTTConfig.username,
      'password': password ?? MQTTConfig.password,
      'device_id': deviceId ?? '',
      'keep_alive': MQTTConfig.keepAlive,
      'qos': MQTTConfig.defaultQos,
      'will_topic': deviceId != null ? MQTTConfig.getDeviceStatusTopic(deviceId) : '',
      'will_message': deviceId != null ? _generateWillMessage(deviceId) : '',
    };

    return await startService(ServiceType.mqtt, config: config);
  }

  /// 停止MQTT服务
  Future<bool> stopMqttService() async {
    return await stopService(ServiceType.mqtt);
  }

  /// 发布MQTT消息
  Future<bool> publishMqttMessage(
    String topic,
    String message, {
    int? qos,
    bool? retain,
  }) async {
    final result = await sendCommand(
      ServiceType.mqtt,
      'publish',
      params: {
        'topic': topic,
        'message': message,
        'qos': qos ?? MQTTConfig.defaultQos,
        'retain': retain ?? false,
      },
    );

    return result == '消息发布成功';
  }

  /// 订阅MQTT主题
  Future<bool> subscribeMqttTopic(
    String topic, {
    int? qos,
  }) async {
    final result = await sendCommand(
      ServiceType.mqtt,
      'subscribe',
      params: {
        'topic': topic,
        'qos': qos ?? MQTTConfig.defaultQos,
      },
    );

    return result == '订阅成功';
  }

  /// 取消订阅MQTT主题
  Future<bool> unsubscribeMqttTopic(String topic) async {
    final result = await sendCommand(
      ServiceType.mqtt,
      'unsubscribe',
      params: {
        'topic': topic,
      },
    );

    return result == '取消订阅成功';
  }

  /// 获取服务事件流
  Stream<ServiceEvent> get eventStream {
    if (_eventController != null) {
      return _eventController!.stream;
    }
    return const Stream.empty();
  }

  /// 获取当前服务状态缓存
  ServiceStatusData? getServiceStatusCache(ServiceType serviceType) {
    return _serviceStatus[serviceType];
  }

  /// 清理资源
  Future<void> dispose() async {
    print('🧹 清理原生服务管理器...');

    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await _eventController?.close();
    _eventController = null;

    _methodChannel.setMethodCallHandler(null);

    _isInitialized = false;
    _serviceStatus.clear();

    print('✅ 原生服务管理器清理完成');
  }

  /// 处理事件
  void _handleEvent(dynamic event) {
    try {
      if (event is Map<String, dynamic>) {
        final serviceEvent = ServiceEvent.fromMap(event);
        print('📨 收到服务事件: ${serviceEvent.serviceType.name}.${serviceEvent.eventName}');

        // 更新状态缓存
        if (serviceEvent.eventName == 'status_changed') {
          final status = ServiceStatusData(
            serviceType: serviceEvent.serviceType,
            status: ServiceStatusData._parseStatus(serviceEvent.data['status']),
            timestamp: serviceEvent.timestamp,
          );
          _serviceStatus[serviceEvent.serviceType] = status;
        }

        // 发送到事件流
        _eventController?.add(serviceEvent);
      }
    } catch (e) {
      print('❌ 处理服务事件失败: $e');
    }
  }

  /// 处理方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'ping':
        return 'pong';
      default:
        throw PlatformException(
          code: 'Unimplemented',
          message: '方法 ${call.method} 未实现',
          details: null,
        );
    }
  }

  /// 解析服务类型
  ServiceType _parseServiceType(String type) {
    switch (type) {
      case 'mqtt':
        return ServiceType.mqtt;
      case 'ble':
        return ServiceType.ble;
      case 'device_manager':
        return ServiceType.deviceManager;
      case 'custom':
        return ServiceType.custom;
      default:
        return ServiceType.custom;
    }
  }

  /// 解析服务状态
  ServiceStatus? _parseStatus(dynamic status) {
    if (status is String) {
      switch (status) {
        case 'stopped':
          return ServiceStatus.stopped;
        case 'starting':
          return ServiceStatus.starting;
        case 'running':
          return ServiceStatus.running;
        case 'stopping':
          return ServiceStatus.stopping;
        case 'error':
          return ServiceStatus.error;
      }
    }
    return null;
  }

  /// 生成遗嘱消息
  String _generateWillMessage(String deviceId) {
    final willMessage = {
      'deviceId': deviceId,
      'type': 'offline',
      'deviceType': 'ReAIAssistantApp',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'isWill': true,
    };

    return jsonEncode(willMessage);
  }

  /// 获取管理器是否已初始化
  bool get isInitialized => _isInitialized;
}

/// 全局实例
final nativeServiceManager = NativeServiceManager();