import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:typed_data/typed_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_config.dart';
import 'models/mqtt_message.dart';
import 'models/mqtt_request_response.dart';
import '../services/device_id_service.dart';
import '../services/background_service_manager.dart';

/// MQTT服务类 (单例)
class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? _client;
  MQTTConnectionStatus _status = MQTTConnectionStatus.disconnected;
  String? _deviceId;
  Timer? _connectionCheckTimer;

  // 已处理的请求ID集合 - 用于防止重复处理
  final Set<String> _processedRequestIds = {};
  Timer? _cleanupTimer;

  // 连接状态流控制器
  final StreamController<MQTTConnectionStatus> _statusController =
      StreamController<MQTTConnectionStatus>.broadcast();
  Stream<MQTTConnectionStatus> get statusStream => _statusController.stream;

  // 消息接收流控制器
  final StreamController<MQTTTopicMessage> _messageController =
      StreamController<MQTTTopicMessage>.broadcast();
  Stream<MQTTTopicMessage> get messageStream => _messageController.stream;

  // 请求-响应管理器
  final MQTTRequestManager _requestManager = MQTTRequestManager();

  // 响应消息流控制器
  final StreamController<MQTTResponseMessage> _responseController =
      StreamController<MQTTResponseMessage>.broadcast();
  Stream<MQTTResponseMessage> get responseStream => _responseController.stream;

  // 请求消息流控制器 - 用于外部处理请求
  final StreamController<MQTTRequestMessage> _requestController =
      StreamController<MQTTRequestMessage>.broadcast();
  Stream<MQTTRequestMessage> get requestStream => _requestController.stream;

  // 当前状态
  MQTTConnectionStatus get currentStatus => _status;

  /// 初始化MQTT服务
  Future<void> initialize() async {
    print('🔧 正在初始化MQTT服务...');

    // 预先获取设备ID
    await _getDeviceId();

    // 设置MQTT发布器到请求管理器
    MQTTRequestManager.setMqttPublisher(publishMessage);

    print('✅ MQTT服务初始化完成');
  }

  /// 获取设备ID
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final deviceIdService = DeviceIdService();
    _deviceId = await deviceIdService.getDeviceId();
    return _deviceId!;
  }

  /// 获取遗嘱消息
  Future<String> _getWillMessage(String deviceId) async {
    final deviceIdService = DeviceIdService();
    final deviceName = await deviceIdService.getDeviceName();

    final willMessage = {
      'deviceId': deviceId,
      'type': 'offline', // 遗嘱消息表示设备意外离线
      'deviceName': deviceName,
      'deviceType': 'ReAIAssistantApp',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'isWill': true, // 标记这是遗嘱消息
    };

    return jsonEncode(willMessage);
  }

  /// 连接到MQTT服务器
  Future<void> connect() async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      print('MQTT已经连接');
      return;
    }

    try {
      _updateStatus(MQTTConnectionStatus.connecting);

      final deviceId = await _getDeviceId();
      final clientId = MQTTConfig.generateClientId(deviceId);

      print('正在连接MQTT服务器...');
      print('服务器: ${MQTTConfig.server}:${MQTTConfig.port}');
      print('客户端ID: $clientId');
      print('设备ID: $deviceId');

      // 根据配置选择端口和连接方式
      final useSsl = MQTTConfig.connectionMode == 'ssl';
      final port = useSsl ? MQTTConfig.sslPort : MQTTConfig.port;

      print('连接模式: ${useSsl ? "SSL/TLS" : "TCP"}');
      print('端口: $port');

      // 创建MQTT客户端
      _client = MqttServerClient.withPort(MQTTConfig.server, clientId, port);
      _client!.logging(on: false); // 关闭详细日志以提高性能
      _client!.keepAlivePeriod = MQTTConfig.keepAlive;

      // 设置遗嘱消息
      final willTopic = MQTTConfig.getDeviceStatusTopic(deviceId);
      final willMessage = await _getWillMessage(deviceId);
      print('📝 设置遗嘱消息 - 主题: $willTopic, 内容: $willMessage');

      // 设置连接消息，包含完整的遗嘱消息配置
      final connMessage = MqttConnectMessage()
        ..withClientIdentifier(clientId)
        ..authenticateAs(MQTTConfig.username, MQTTConfig.password)
        ..startClean()
        ..withWillTopic(willTopic)                    // 设置遗嘱消息主题
        ..withWillMessage(willMessage)                // 设置遗嘱消息内容
        ..withWillQos(MqttQos.atLeastOnce)            // 设置遗嘱消息QoS为1
        ..withWillRetain();                           // 设置遗嘱消息保留

      _client!.connectionMessage = connMessage;

      // 设置事件回调
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onSubscribeFail = _onSubscribeFail;

      print('开始连接...');
      print('🔍 网络连接诊断:');
      print('   - 服务器地址: ${MQTTConfig.server}');
      print('   - 端口: $port');
      print('   - SSL模式: $useSsl');
      print('   - 客户端ID: $clientId');
      print('   - 用户名: ${MQTTConfig.username.isNotEmpty ? MQTTConfig.username : "无"}');

      // 设置连接超时
      await _client!.connect();

    } catch (e) {
      print('MQTT连接失败: $e');
      _updateStatus(MQTTConnectionStatus.error);
      _reconnect();
    }
  }

  /// 连接成功回调
  void _onConnected() {
    print('✅ MQTT连接成功');
    _updateStatus(MQTTConnectionStatus.connected);

    // 订阅主题
    _subscribeToTopics();

    // 发送在线状态
    _sendOnlineStatus();

    // 启动连接检查
    _startConnectionCheck();

    // 启动清理定时器 - 每5分钟清理一次过期的请求ID
    _startCleanupTimer();
  }

  /// 连接断开回调
  void _onDisconnected() {
    print('❌ MQTT连接断开');
    _stopConnectionCheck();
    _stopCleanupTimer();
    _updateStatus(MQTTConnectionStatus.disconnected);

    // 如果在后台模式，立即尝试重连
    if (BackgroundServiceManager.isBackgroundMode) {
      print('🔄 检测到后台连接断开，5秒后自动重连...');
      Future.delayed(Duration(seconds: 5), () async {
        try {
          print('🚀 开始后台重连...');
          await connect();
        } catch (e) {
          print('❌ 后台自动重连失败: $e');
        }
      });
    }
  }

  /// 订阅成功回调
  void _onSubscribed(String topic) {
    print('✅ 订阅主题成功: $topic');
  }

  /// 订阅失败回调
  void _onSubscribeFail(String topic) {
    print('❌ 订阅主题失败: $topic');
  }

  /// 订阅主题
  void _subscribeToTopics() async {
    if (_client == null || _deviceId == null) return;

    final topics = MQTTConfig.getSubscriptionTopics(_deviceId!);

    for (final topic in topics) {
      try {
        await _client!.subscribe(topic, MqttQos.values[MQTTConfig.defaultQos]);

        // 监听这个主题的消息
        _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> event) {
          final recMess = event[0];
          final topic = recMess.topic;

          // 转换payload为字符串 - 使用UTF-8解码
          String payload;
          if (recMess.payload is MqttPublishMessage) {
            final publishMessage = recMess.payload as MqttPublishMessage;
            try {
              payload = utf8.decode(publishMessage.payload.message);
            } catch (e) {
              print('⚠️ UTF-8解码失败，使用默认解码: $e');
              payload = String.fromCharCodes(publishMessage.payload.message);
            }
          } else {
            payload = '';
          }

          _handleMessage(topic, payload);
        });
      } catch (e) {
        print('订阅主题失败 $topic: $e');
      }
    }
  }

  /// 处理接收到的消息
  void _handleMessage(String topic, String payload) {
    print('📨 收到MQTT消息:');
    print('   主题: $topic');
    print('   内容: $payload');

    final message = MQTTTopicMessage(topic: topic, payload: payload);

    // 预处理消息，检查重复请求
    if (!_shouldProcessMessage(message)) {
      print('🚫 消息被重复检查过滤，跳过处理');
      return;
    }

    // 首先发送到普通消息流
    _messageController.add(message);

    // 处理请求-响应逻辑
    _handleRequestResponseLogic(message);
  }

  /// 检查消息是否应该被处理（重复过滤）
  bool _shouldProcessMessage(MQTTTopicMessage message) {
    try {
      // 对于请求消息，检查重复ID
      if (message.isDeviceRequestTopic) {
        final request = MQTTRequestMessage.fromTopicMessage(message);
        final requestKey = '${request.id}_${request.method}';

        // 检查是否为重复请求ID
        if (_processedRequestIds.contains(requestKey)) {
          print('⚠️ 检测到重复请求ID，在消息入口处过滤: ${request.method}#${request.id}');
          return false;
        }

        // 标记请求ID为已处理
        _processedRequestIds.add(requestKey);
        print('🔥 通过重复检查的新请求: ${request.method}#${request.id}');
      }

      // 对于响应消息，也可以进行重复检查
      if (message.isResponseTopic) {
        final response = MQTTResponseMessage.fromTopicMessage(message);
        final responseKey = '${response.id}_${response.method}';

        // 检查是否为重复响应ID
        if (_processedRequestIds.contains(responseKey)) {
          print('⚠️ 检测到重复响应ID，在消息入口处过滤: ${response.method}#${response.id}');
          return false;
        }

        // 标记响应ID为已处理
        _processedRequestIds.add(responseKey);
        print('✅ 通过重复检查的新响应: ${response.method}#${response.id}');
      }

      return true;
    } catch (e) {
      print('❌ 消息重复检查失败，允许通过: $e');
      // 如果解析失败，允许消息通过处理
      return true;
    }
  }

  /// 处理请求-响应逻辑
  void _handleRequestResponseLogic(MQTTTopicMessage message) {
    try {
      // 处理响应消息
      if (message.isResponseTopic) {
        final response = MQTTResponseMessage.fromTopicMessage(message);

        // 检查是否为待处理请求的响应
        if (_requestManager.handleResponse(response)) {
          // 发送到响应流
          _responseController.add(response);
          print('✅ 处理响应消息: ${response.method}#${response.id}');
        } else {
          print('⚠️ 收到未知请求的响应: ${response.method}#${response.id}');
        }
        return;
      }

      // 处理请求消息 (重复检查已在_shouldProcessMessage中完成)
      if (message.isDeviceRequestTopic) {
        try {
          final request = MQTTRequestMessage.fromTopicMessage(message);
          print('🔥 处理新请求消息: ${request.method}#${request.id}');

          // 注册请求并设置5秒超时
          _requestManager.registerRequest(request, timeout: Duration(seconds: 5));

          // 将请求消息发送到流中，由外部组件处理
          _requestController.add(request);

        } catch (e) {
          print('❌ 解析请求消息失败: $e');
        }
      }
    } catch (e) {
      print('❌ 处理请求-响应逻辑失败: $e');
    }
  }

  
  /// 发送消息
  Future<void> publishMessage(String topic, String message) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      print('❌ MQTT未连接，无法发送消息');
      return;
    }

    try {
      // 使用UTF-8编码确保中文字符正确传输
      final Uint8Buffer payloadBuffer;

      // 检查消息是否包含非ASCII字符
      final hasNonAscii = message.codeUnits.any((unit) => unit > 127);

      if (hasNonAscii) {
        // 对于包含中文的消息，直接使用UTF-8字节数组
        final utf8Bytes = utf8.encode(message);
        payloadBuffer = Uint8Buffer();
        payloadBuffer.addAll(utf8Bytes);
        print('📝 使用UTF-8字节数组发送中文消息 (${payloadBuffer.length} bytes)');
      } else {
        // 对于纯ASCII消息，使用原始方法
        final builder = MqttClientPayloadBuilder();
        builder.addString(message);
        payloadBuffer = builder.payload!;
        print('📝 使用原始方法发送ASCII消息 (${payloadBuffer.length} bytes)');
      }

      await _client!.publishMessage(
        topic,
        MqttQos.values[MQTTConfig.defaultQos],
        payloadBuffer,
      );

      print('📤 发送MQTT消息成功:');
      print('   主题: $topic');
      print('   内容: $message');
    } catch (e) {
      print('❌ 发送MQTT消息失败: $e');
    }
  }

  /// 发送设备状态
  Future<void> _sendOnlineStatus() async {
    if (_deviceId == null) return;

    final deviceIdService = DeviceIdService();
    final deviceName = await deviceIdService.getDeviceName();

    final statusMessage = {
      'deviceId': _deviceId!,
      'type': 'online',
      'deviceName': deviceName,
      'deviceType': 'ReAIAssistantApp',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final topic = MQTTConfig.getDeviceStatusTopic(_deviceId!);
    await publishMessage(topic, jsonEncode(statusMessage));
  }

  /// 发送离线状态
  Future<void> sendOfflineStatus() async {
    if (_deviceId == null) return;

    final deviceIdService = DeviceIdService();
    final deviceName = await deviceIdService.getDeviceName();

    final statusMessage = {
      'deviceId': _deviceId!,
      'type': 'offline',
      'deviceName': deviceName,
      'deviceType': 'ReAIAssistantApp',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'isWill': false, // 标记这是正常离线，不是遗嘱消息
    };

    final topic = MQTTConfig.getDeviceStatusTopic(_deviceId!);
    await publishMessage(topic, jsonEncode(statusMessage));
  }

  /// 发送在线状态消息
  Future<void> sendOnlineStatus() async {
    await _sendOnlineStatus();
  }

  /// 发送心跳状态消息
  Future<void> sendHeartbeatStatus() async {
    if (_deviceId == null) return;

    final deviceIdService = DeviceIdService();
    final deviceName = await deviceIdService.getDeviceName();

    final heartbeatMessage = {
      'deviceId': _deviceId!,
      'type': 'heartbeat',
      'deviceName': deviceName,
      'deviceType': 'ReAIAssistantApp',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final topic = MQTTConfig.getDeviceStatusTopic(_deviceId!);
    await publishMessage(topic, jsonEncode(heartbeatMessage));
  }

  /// 更新连接状态
  void _updateStatus(MQTTConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      print('🔄 MQTT状态更新: ${newStatus.toString().split('.').last}');
    }
  }

  /// 重连机制
  Future<void> _reconnect() async {
    if (_status == MQTTConnectionStatus.connecting) return;

    int retryCount = 0;
    const int maxRetries = 10;

    while (retryCount < maxRetries && _status != MQTTConnectionStatus.connected) {
      retryCount++;

      // 指数退避策略: 5s, 10s, 20s, 30s, 60s...
      final delaySeconds = [5, 10, 20, 30, 60, 60, 60, 60, 60, 60][retryCount - 1];

      print('🔄 第${retryCount}次重连将在${delaySeconds}秒后尝试...');
      await Future.delayed(Duration(seconds: delaySeconds));

      if (_status != MQTTConnectionStatus.connected) {
        try {
          await connect();
          if (_status == MQTTConnectionStatus.connected) {
            print('✅ 重连成功');
            return;
          }
        } catch (e) {
          print('❌ 重连失败: $e');
        }
      }
    }

    if (retryCount >= maxRetries) {
      print('❌ 达到最大重连次数，停止重连');
      _updateStatus(MQTTConnectionStatus.error);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      await sendOfflineStatus();
      _client!.disconnect();
    }

    _updateStatus(MQTTConnectionStatus.disconnected);
  }

  /// 启动连接检查
  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
        print('⚠️ 连接检查发现连接异常，触发重连');
        _updateStatus(MQTTConnectionStatus.error);
        _reconnect();
      } else {
        print('💓 MQTT连接正常 (心跳检查)');
      }
    });
  }

  /// 停止连接检查
  void _stopConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  /// 启动清理定时器 - 定期清理过期的请求ID以防止内存泄漏
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _cleanupExpiredRequestIds();
    });
    print('🧹 启动请求ID清理定时器 (每5分钟清理一次)');
  }

  /// 停止清理定时器
  void _stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// 清理过期的请求ID (清理超过10分钟的记录)
  void _cleanupExpiredRequestIds() {
    if (_processedRequestIds.isEmpty) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final expiredThreshold = currentTime - (10 * 60 * 1000); // 10分钟前

    // 由于我们只存储ID没有时间戳，采用简单的集合大小限制策略
    // 如果集合大小超过500个，清空一半以防止内存泄漏
    if (_processedRequestIds.length > 500) {
      final idsToRemove = _processedRequestIds.take(250).toSet();
      _processedRequestIds.removeAll(idsToRemove);
      print('🧹 清理了${idsToRemove.length}个过期的请求ID，当前剩余${_processedRequestIds.length}个');
    }
  }

  /// 销毁服务
  void dispose() {
    _stopConnectionCheck();
    _stopCleanupTimer();
    _messageController.close();
    _statusController.close();
    _responseController.close();
    _requestController.close();
    _requestManager.clearAllRequests();
    _processedRequestIds.clear();
    if (_client != null) {
      _client!.disconnect();
    }
    _client = null;
  }

  /// 发送请求消息
  Future<void> sendRequest(String method, Map<String, dynamic> params, {String? deviceId}) async {
    if (_deviceId == null) {
      print('❌ 设备ID未初始化，无法发送请求');
      return;
    }

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final requestPayload = {
      'id': requestId,
      'method': method,
      'params': params,
      'deviceId': deviceId ?? _deviceId!,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final topic = MQTTConfig.getMessageRequestTopic(_deviceId!);
    await publishMessage(topic, jsonEncode(requestPayload));

    print('📤 发送MQTT请求: $method#$requestId');
  }

  /// 手动响应请求
  Future<void> respondToRequest(String requestId, String method, {
    required bool success,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (_deviceId == null) {
      print('❌ 设备ID未初始化，无法发送响应');
      return;
    }

    final response = MQTTResponseMessage(
      id: requestId,
      method: method,
      success: success,
      message: message,
      data: data ?? {},
      deviceId: _deviceId!,
      requestId: requestId,
    );

    final responseMessage = response.toTopicMessage();
    await publishMessage(responseMessage.topic, responseMessage.payload);

    print('📤 手动发送MQTT响应: $method#$requestId -> $message');
  }

  /// 获取待处理请求数量
  int get pendingRequestCount => _requestManager.pendingRequestCount;

  /// 获取待处理请求列表
  List<MQTTRequestMessage> get pendingRequests => _requestManager.pendingRequests;

  /// 标记请求已被外部处理完成，不会触发5秒超时默认回复
  void markRequestCompleted(String requestId, String method) {
    final requestKey = '${requestId}_${method}';
    _requestManager.markRequestCompleted(requestKey);
  }
}