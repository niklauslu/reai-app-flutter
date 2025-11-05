import 'dart:convert';
import 'dart:async';
import 'mqtt_message.dart';

/// MQTT请求消息模型
class MQTTRequestMessage {
  final String id;
  final String method;
  final Map<String, dynamic> params;
  final String deviceId;
  final DateTime timestamp;
  final Timer? timeoutTimer;

  MQTTRequestMessage({
    required this.id,
    required this.method,
    required this.params,
    required this.deviceId,
    DateTime? timestamp,
    this.timeoutTimer,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 从MQTT主题消息创建请求对象
  factory MQTTRequestMessage.fromTopicMessage(MQTTTopicMessage message) {
    try {
      final payload = jsonDecode(message.payload) as Map<String, dynamic>;
      return MQTTRequestMessage(
        id: payload['id']?.toString() ?? '',
        method: payload['method']?.toString() ?? '',
        params: payload['params'] as Map<String, dynamic>? ?? {},
        deviceId: message.deviceId ?? '',
      );
    } catch (e) {
      throw FormatException('Invalid MQTT request message format: $e');
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'params': params,
      'deviceId': deviceId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// 生成响应消息
  MQTTResponseMessage createResponse({
    bool success = true,
    String? message,
    Map<String, dynamic>? data,
  }) {
    return MQTTResponseMessage(
      id: id,
      method: method,
      success: success,
      message: message ?? (success ? '操作成功' : '操作失败'),
      data: data ?? {},
      deviceId: deviceId,
      requestId: id,
    );
  }

  
  @override
  String toString() {
    return 'MQTTRequestMessage{id: $id, method: $method, deviceId: $deviceId}';
  }
}

/// MQTT响应消息模型
class MQTTResponseMessage {
  final String id;
  final String method;
  final bool success;
  final String message;
  final Map<String, dynamic> data;
  final String deviceId;
  final String requestId;
  final DateTime timestamp;

  MQTTResponseMessage({
    required this.id,
    required this.method,
    required this.success,
    required this.message,
    required this.data,
    required this.deviceId,
    required this.requestId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 从MQTT主题消息创建响应对象
  factory MQTTResponseMessage.fromTopicMessage(MQTTTopicMessage message) {
    try {
      final payload = jsonDecode(message.payload) as Map<String, dynamic>;
      return MQTTResponseMessage(
        id: payload['id']?.toString() ?? '',
        method: payload['method']?.toString() ?? '',
        success: payload['success'] as bool? ?? false,
        message: payload['message']?.toString() ?? '',
        data: payload['data'] as Map<String, dynamic>? ?? {},
        deviceId: message.deviceId ?? '',
        requestId: payload['requestId']?.toString() ?? '',
      );
    } catch (e) {
      throw FormatException('Invalid MQTT response message format: $e');
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'success': success,
      'message': message,
      'data': data,
      'deviceId': deviceId,
      'requestId': requestId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// 转换为MQTT主题消息 - 使用简化格式
  MQTTTopicMessage toTopicMessage() {
    final responseJson = {
      'id': id,
      'method': method,
      'result': {
        'success': success,
        'message': message,
      },
    };

    return MQTTTopicMessage(
      topic: 'device/$deviceId/response',
      payload: jsonEncode(responseJson),
    );
  }

  /// 判断是否为指定请求的响应
  bool isResponseTo(String requestId) {
    return this.requestId == requestId;
  }

  @override
  String toString() {
    return 'MQTTResponseMessage{id: $id, method: $method, success: $success, deviceId: $deviceId}';
  }
}

/// MQTT请求管理器 - 处理超时和自动回复
class MQTTRequestManager {
  static final MQTTRequestManager _instance = MQTTRequestManager._internal();
  factory MQTTRequestManager() => _instance;
  MQTTRequestManager._internal();

  final Map<String, MQTTRequestMessage> _pendingRequests = {};
  final Map<String, Timer> _timeoutTimers = {};
  static const Duration _defaultTimeout = Duration(seconds: 5);

  /// MQTT服务实例（延迟注入）
  static Function(String, String)? _mqttPublisher;

  /// 设置MQTT发布函数
  static void setMqttPublisher(Function(String, String) publisher) {
    _mqttPublisher = publisher;
  }

  /// 注册请求并设置超时
  void registerRequest(MQTTRequestMessage request, {Duration? timeout}) {
    final requestId = '${request.id}_${request.method}';

    // 清理已存在的请求
    removeRequest(requestId);

    _pendingRequests[requestId] = request;

    // 设置超时定时器
    final timeoutDuration = timeout ?? _defaultTimeout;
    final timer = Timer(timeoutDuration, () {
      _handleRequestTimeout(requestId);
    });

    _timeoutTimers[requestId] = timer;
    print('⏰ 注册MQTT请求: ${request.method}#${request.id}, 超时: ${timeoutDuration.inSeconds}秒');
  }

  /// 移除请求
  void removeRequest(String requestId) {
    _pendingRequests.remove(requestId);
    final timer = _timeoutTimers.remove(requestId);
    timer?.cancel();
    print('✅ 移除MQTT请求: $requestId');
  }

  /// 处理响应消息
  bool handleResponse(MQTTResponseMessage response) {
    final requestId = '${response.id}_${response.method}';

    if (_pendingRequests.containsKey(requestId)) {
      removeRequest(requestId);
      print('✅ 收到MQTT响应: ${response.method}#${response.id}');
      return true;
    }

    return false;
  }

  /// 处理请求超时 - 发送"消息已发送"响应
  void _handleRequestTimeout(String requestId) {
    final request = _pendingRequests.remove(requestId);
    _timeoutTimers.remove(requestId);

    if (request != null) {
      // 创建"消息已发送"响应 - 确保使用字符串字面量避免编码问题
      final responseJson = <String, dynamic>{
        'id': request.id,
        'method': request.method,
        'result': <String, dynamic>{
          'success': true,
          'message': '消息已发送',
        },
      };

      print('⏰ MQTT请求5秒未收到回复，发送"消息已发送": ${request.method}#${request.id}');

      // 发布"消息已发送"响应
      _publishSentResponse(responseJson, request.deviceId);
    }
  }

  /// 发布"消息已发送"响应消息
  void _publishSentResponse(Map<String, dynamic> responseJson, String deviceId) {
    final topic = 'device/$deviceId/response';

    // 确保使用正确的UTF-8编码
    String payload;
    try {
      payload = jsonEncode(responseJson);

      // 验证编码结果
      final decoded = jsonDecode(payload);
      final originalMessage = responseJson['result']['message'];
      final decodedMessage = decoded['result']['message'];

      if (originalMessage != decodedMessage) {
        print('⚠️ JSON编码检测到字符问题，使用备用编码方式');
        // 使用备用方式确保中文字符正确编码
        final Map<String, dynamic> safeJson = Map<String, dynamic>.from(responseJson);
        if (safeJson['result'] is Map<String, dynamic>) {
          final result = Map<String, dynamic>.from(safeJson['result']);
          result['message'] = '消息已发送'; // 直接使用硬编码确保字符正确
          safeJson['result'] = result;
        }
        payload = jsonEncode(safeJson);
      }

    } catch (e) {
      print('❌ JSON编码失败，使用备用方案: $e');
      final fallbackJson = {
        'id': responseJson['id'],
        'method': responseJson['method'],
        'result': {
          'success': true,
          'message': 'Message sent', // 使用英文避免编码问题
        }
      };
      payload = jsonEncode(fallbackJson);
    }

    if (_mqttPublisher != null) {
      try {
        _mqttPublisher!(topic, payload);
        print('📤 发布"消息已发送"响应: ${responseJson['method']}#${responseJson['id']}');
        print('📝 响应内容: $payload');
      } catch (e) {
        print('❌ 发布"消息已发送"响应失败: $e');
      }
    } else {
      print('⚠️ MQTT发布器未设置，无法发布"消息已发送"响应: $payload');
    }
  }

  /// 获取待处理请求列表
  List<MQTTRequestMessage> get pendingRequests => _pendingRequests.values.toList();

  /// 清理所有请求
  void clearAllRequests() {
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _pendingRequests.clear();
    _timeoutTimers.clear();
    print('🧹 清理所有MQTT请求');
  }

  /// 获取待处理请求数量
  int get pendingRequestCount => _pendingRequests.length;
}