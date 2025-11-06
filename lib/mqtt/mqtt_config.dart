import 'dart:math';

/// MQTT配置类
class MQTTConfig {
  static const String server = '14.103.243.230';
  static const int port = 1883;
  static const int sslPort = 8883; // SSL/TLS端口
  static const String username = 'device_user';
  static const String password = 'eedd1012ab2546fc3c41a0ab3b629ffb';

  // 连接模式：'tcp' 或 'ssl'
  static const String connectionMode = 'tcp'; // 使用TCP连接

  // 心跳设置 - 延长心跳间隔以提高后台连接稳定性
  static const int keepAlive = 120; // 2分钟心跳间隔，适合后台运行
  static const int pingTimeout = 30; // ping超时时间

  // QoS设置
  static const int defaultQos = 1;
  static const int willQos = 1;

  // 连接选项
  static const bool willRetain = false;
  static const bool startClean = true;

  // 重连设置
  static const List<Duration> reconnectIntervals = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  /// 生成客户端ID格式: device_{deviceId}_{randomNumber}
  static String generateClientId(String deviceId) {
    final randomSuffix = Random().nextInt(10000);
    return 'device_${deviceId}_$randomSuffix';
  }

  /// 获取重连间隔时间
  static Duration getReconnectInterval(int attemptCount) {
    if (attemptCount < reconnectIntervals.length) {
      return reconnectIntervals[attemptCount];
    }
    return reconnectIntervals.last;
  }

  /// 主题模板
  static String getDeviceStatusTopic(String deviceId) => 'device/$deviceId/status';
  static String getDeviceRequestTopic(String deviceId) => 'device/$deviceId/request';
  static String getDeviceResponseTopic(String deviceId) => 'device/$deviceId/response';
  static String getMessageRequestTopic(String deviceId) => 'message/$deviceId/request';
  static String getMessageResponseTopic(String deviceId) => 'message/$deviceId/response';

  /// 需要订阅的主题列表
  static List<String> getSubscriptionTopics(String deviceId) {
    return [
      getDeviceRequestTopic(deviceId),
      getMessageResponseTopic(deviceId),
    ];
  }

  /// 可发布的主题列表
  static List<String> getPublishTopics(String deviceId) {
    return [
      getDeviceStatusTopic(deviceId),
      getDeviceResponseTopic(deviceId),
      getMessageRequestTopic(deviceId),
    ];
  }
}