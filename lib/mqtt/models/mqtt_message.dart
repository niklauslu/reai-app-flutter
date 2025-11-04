/// MQTT连接状态枚举
enum MQTTConnectionStatus {
  disconnected,  // 未连接
  connecting,    // 连接中
  connected,     // 已连接
  error,         // 连接错误
}

/// 简单的MQTT消息包装类
class MQTTTopicMessage {
  final String topic;
  final String payload;
  final DateTime timestamp;
  final int qos;

  MQTTTopicMessage({
    required this.topic,
    required this.payload,
    DateTime? timestamp,
    this.qos = 1,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 判断是否为设备状态主题
  bool get isDeviceStatusTopic => topic.contains('/status');

  /// 判断是否为设备请求主题
  bool get isDeviceRequestTopic => topic.contains('/request');

  /// 判断是否为响应主题
  bool get isResponseTopic => topic.contains('/response');

  /// 提取设备ID
  String? get deviceId {
    final parts = topic.split('/');
    if (parts.length >= 2) {
      return parts[1];
    }
    return null;
  }

  @override
  String toString() {
    return 'MQTTTopicMessage{topic: $topic, payload: $payload}';
  }
}