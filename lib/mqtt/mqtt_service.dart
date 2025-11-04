import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_config.dart';
import 'models/mqtt_message.dart';
import '../services/device_id_service.dart';

/// MQTT服务类 (单例)
class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? _client;
  MQTTConnectionStatus _status = MQTTConnectionStatus.disconnected;
  String? _deviceId;
  Timer? _connectionCheckTimer;

  // 连接状态流控制器
  final StreamController<MQTTConnectionStatus> _statusController =
      StreamController<MQTTConnectionStatus>.broadcast();
  Stream<MQTTConnectionStatus> get statusStream => _statusController.stream;

  // 消息接收流控制器
  final StreamController<MQTTTopicMessage> _messageController =
      StreamController<MQTTTopicMessage>.broadcast();
  Stream<MQTTTopicMessage> get messageStream => _messageController.stream;

  // 当前状态
  MQTTConnectionStatus get currentStatus => _status;

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

      // 创建MQTT客户端
      _client = MqttServerClient.withPort(MQTTConfig.server, clientId, MQTTConfig.port);
      _client!.logging(on: false); // 关闭详细日志以提高性能
      _client!.keepAlivePeriod = MQTTConfig.keepAlive;

      // 设置连接消息 (遗嘱消息需要更复杂的设置，暂时简化)
      final connMessage = MqttConnectMessage()
        ..withClientIdentifier(clientId)
        ..authenticateAs(MQTTConfig.username, MQTTConfig.password)
        ..withWillQos(MqttQos.atLeastOnce)
        ..startClean();

      _client!.connectionMessage = connMessage;

      // 设置事件回调
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onSubscribeFail = _onSubscribeFail;

      print('开始连接...');

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
  }

  /// 连接断开回调
  void _onDisconnected() {
    print('❌ MQTT连接断开');
    _stopConnectionCheck();
    _updateStatus(MQTTConnectionStatus.disconnected);
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

          // 转换payload为字符串
          String payload;
          if (recMess.payload is MqttPublishMessage) {
            final publishMessage = recMess.payload as MqttPublishMessage;
            payload = String.fromCharCodes(publishMessage.payload.message);
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
    _messageController.add(message);
  }

  /// 发送消息
  Future<void> publishMessage(String topic, String message) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      print('❌ MQTT未连接，无法发送消息');
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      await _client!.publishMessage(
        topic,
        MqttQos.values[MQTTConfig.defaultQos],
        builder.payload!,
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

  /// 销毁服务
  void dispose() {
    _stopConnectionCheck();
    _messageController.close();
    _statusController.close();
    if (_client != null) {
      _client!.disconnect();
    }
    _client = null;
  }
}