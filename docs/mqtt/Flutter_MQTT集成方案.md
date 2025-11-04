# Flutter MQTT集成方案

## 概述

本文档描述如何在ReAI Assistant Flutter应用中集成MQTT服务，实现设备与中控系统的实时通信。

## 技术选型

### MQTT客户端库
推荐使用 `mqtt_client` 库：
```yaml
dependencies:
  mqtt_client: ^10.0.0
```

**选择理由**：
- 官方维护，稳定可靠
- 支持Flutter全平台
- 完整的MQTT 3.1.1和5.0协议支持
- 良好的异步处理和状态管理
- 支持SSL/TLS安全连接

## 架构设计

### 服务架构
```
ReAI App
├── MQTTService (单例)
│   ├── 连接管理
│   ├── 消息发布
│   ├── 消息订阅
│   └── 状态管理
├── MessageHandler
│   ├── 请求处理
│   ├── 响应处理
│   └── 状态上报
└── DeviceStateManager
    ├── 设备状态
    ├── 网络状态
    └── 重连机制
```

### 生命周期管理
- **应用启动**: 自动初始化MQTT连接
- **前台运行**: 保持实时通信
- **后台运行**: 维持连接，处理重要消息
- **应用暂停**: 智能断开，节省电量
- **恢复运行**: 自动重连
- **应用退出**: 清理资源

## 实现方案

### 1. 服务层设计

#### MQTTService (单例)
```dart
class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? _client;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _deviceId;

  // 连接状态
  StreamController<ConnectionStatus> _statusController;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  // 消息接收
  StreamController<MqttMessage> _messageController;
  Stream<MqttMessage> get messageStream => _messageController.stream;

  // 初始化连接
  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;
    final clientId = MQTTConfig.generateClientId(deviceId);

    _client = MqttServerClient(MQTTConfig.server, clientId);
    _client!.port = MQTTConfig.port;
    _client!.logging(on: true);

    // 设置认证信息
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onUnsubscribed = _onUnsubscribed;
    _client!.onSubscribed = _onSubscribed;
    _client!.onSubscribeFail = _onSubscribeFail;

    // 设置认证
    _client!.connectionMessage = MqttConnectMessage()
      ..withClientIdentifier(clientId)
      ..authenticateAs(MQTTConfig.username, MQTTConfig.password)
      ..keepAlive = 60
      ..withWillQos = MqttQos.atLeastOnce
      ..withWillRetain = false
      ..startClean();

    try {
      await _client!.connect();
    } catch (e) {
      print('MQTT连接失败: $e');
      disconnect();
    }
  }
}
```

#### 核心功能模块
1. **连接管理**: 建立连接、维持心跳、处理重连
2. **消息发布**: 设备状态、响应消息、主动请求
3. **消息订阅**: 接收中控请求、响应消息
4. **状态管理**: 连接状态、网络状态、错误处理

### 2. 消息处理系统

#### 消息模型
```dart
// 基础消息模型
class MQTTMessage {
  final String id;
  final String method;
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? result;
  final int? index;  // 分片索引

  // 序列化/反序列化方法
}

// 设备状态模型
class DeviceStatusMessage {
  final String deviceId;
  final String type;  // 'online' | 'offline'
  final String? deviceName;
  final String? deviceType;
  final int timestamp;
}
```

#### 消息处理器
```dart
class MessageHandler {
  // 处理中控请求
  void handleRequest(MQTTMessage message);

  // 处理响应消息
  void handleResponse(MQTTMessage message);

  // 发送设备状态
  void sendDeviceStatus(String status);

  // 发送响应
  void sendResponse(String requestId, String method, dynamic result);
}
```

### 3. 主题订阅策略

#### 订阅列表
```dart
final subscriptions = [
  'device/${deviceId}/request',      // 接收中控请求
  'message/${deviceId}/response',    // 接收响应消息
];
```

#### 发布主题
```dart
const topics = {
  'status': 'device/{deviceId}/status',      // 设备状态
  'response': 'device/{deviceId}/response',  // 响应消息
  'request': 'message/{deviceId}/request',   // 主动请求
};
```

### 4. 后台运行支持

#### Android配置
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<service
    android:name=".services.MQTTBackgroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

#### iOS配置
```xml
<!-- Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
    <string>remote-notification</string>
</array>
```

### 5. 错误处理与重连机制

#### 重连策略
```dart
class ReconnectPolicy {
  static const List<Duration> backoffIntervals = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  Duration getNextInterval(int attemptCount) {
    if (attemptCount < backoffIntervals.length) {
      return backoffIntervals[attemptCount];
    }
    return backoffIntervals.last;
  }
}
```

#### 异常处理
- 网络连接失败
- 认证失败
- 服务器不可达
- 消息发布失败
- 订阅失败

## 安全考虑

### 1. 连接安全
- 使用SSL/TLS加密连接
- 验证服务器证书
- 避免明文传输敏感信息

### 2. 认证信息管理
```dart
class MQTTConfig {
  static const String server = '101.126.20.157';
  static const int port = 1883;
  static const String username = 'device_user';
  static const String password = 'eedd1012ab2546fc3c41a0ab3b629ffb';

  // 生成客户端ID格式: device_{deviceId}_{randomNumber}
  static String generateClientId(String deviceId) {
    final randomSuffix = Random().nextInt(10000);
    return 'device_${deviceId}_$randomSuffix';
  }
}
```

### 3. 客户端ID规范
- **格式**: `device_{deviceId}_{随机数}`
- **示例**: `device_REAI_123_9876`
- **用途**:
  - 确保每个连接的唯一性
  - 防止客户端ID冲突
  - 便于服务器端设备识别和管理
- **随机数**: 4位数字随机数，范围0-9999

### 4. 数据验证
- 验证消息格式
- 限制消息大小
- 防止恶意消息注入

## 性能优化

### 1. 消息批处理
- 合并频繁的状态更新
- 使用消息队列缓冲
- 避免网络拥塞

### 2. 心跳优化
```dart
// 配置心跳参数
client.keepAlive = 60;  // 60秒心跳
client.pingTimeout = 20; // 20秒ping超时
```

### 3. 内存管理
- 及时释放消息缓存
- 限制消息队列大小
- 定期清理过期数据

## 监控与调试

### 1. 日志系统
```dart
enum MQTTLogLevel {
  debug,
  info,
  warning,
  error,
}

class MQTTLogger {
  static void log(String message, MQTTLogLevel level) {
    // 输出到控制台和文件
  }
}
```

### 2. 状态监控
- 连接状态实时监控
- 消息发送成功率统计
- 网络质量评估

### 3. 调试工具
- 消息历史记录
- 连接状态可视化
- 性能指标展示

## 测试策略

### 1. 单元测试
- MQTT连接测试
- 消息序列化测试
- 错误处理测试

### 2. 集成测试
- 与MQTT Broker的连接测试
- 消息收发测试
- 重连机制测试

### 3. 设备测试
- 不同网络环境测试
- 后台运行稳定性测试
- 电量消耗测试

## 部署配置

### 1. 环境配置
```dart
enum MQTTEnvironment {
  development,
  staging,
  production,
}

class MQTTEnvironmentConfig {
  static MQTTConfig getConfig(MQTTEnvironment env) {
    switch (env) {
      case MQTTEnvironment.development:
        return MQTTConfig(/* 开发环境配置 */);
      case MQTTEnvironment.staging:
        return MQTTConfig(/* 测试环境配置 */);
      case MQTTEnvironment.production:
        return MQTTConfig(/* 生产环境配置 */);
    }
  }
}
```

### 2. 配置管理
- 支持多环境切换
- 敏感信息加密存储
- 运行时配置更新

## 维护指南

### 1. 常见问题
- 连接失败排查
- 消息丢失处理
- 性能瓶颈分析

### 2. 版本升级
- MQTT客户端库升级
- 协议版本兼容性
- 数据迁移方案

### 3. 运维监控
- 服务可用性监控
- 异常告警机制
- 性能指标收集

## 开发计划

### Phase 1: 基础框架 (1-2周)
- [ ] MQTTService基础架构
- [ ] 连接管理和状态监控
- [ ] 基础消息收发功能

### Phase 2: 消息处理 (1-2周)
- [ ] 消息模型和序列化
- [ ] 主题订阅和发布
- [ ] 消息路由和处理

### Phase 3: 高级功能 (2-3周)
- [ ] 后台运行支持
- [ ] 重连机制和错误处理
- [ ] 性能优化和安全加固

### Phase 4: 测试和优化 (1-2周)
- [ ] 完整的测试覆盖
- [ ] 性能调优
- [ ] 文档完善和代码审查

## 总结

本MQTT集成方案提供了完整的架构设计和实现指导，确保ReAI Assistant应用能够稳定、高效地与MQTT Broker通信，支持设备状态上报、指令接收等核心功能，同时具备良好的可扩展性和维护性。