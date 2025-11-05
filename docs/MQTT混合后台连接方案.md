# 通用前台服务架构设计文档

## 🎯 方案概述

基于现有Flutter应用功能，设计一个通用的原生前台服务架构，支持MQTT、BLE等多种后台服务模块，实现低耗电、稳定可靠的后台常驻功能。

## 📊 方案对比

| 方案 | 耗电 | 稳定性 | 开发复杂度 | 实时性 | 跨平台 | 扩展性 | 当前状态 |
|------|------|--------|------------|--------|---------|--------|----------|
| 当前Flutter方案 | 高 | 一般 | 低 | 好 | ✅ | ❌ | ❌ 问题多 |
| 纯原生前台服务 | 低 | 优秀 | 高 | 优秀 | ❌ | ❌ | 需开发 |
| **通用前台服务方案** | **中** | **优秀** | **中** | **优秀** | ✅ | **优秀** | **推荐** |

## 🏗️ 通用前台服务架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              应用整体架构                                │
├─────────────────┬──────────────────────────┬─────────────────────────┤
│   Flutter UI    │      原生前台服务          │      外部服务           │
│   (交互界面)      │     (服务管理器)         │     (数据源/目标)        │
│                 │                          │                         │
│ • 状态显示        │ • 服务生命周期管理        │ • MQTT Broker          │
│ • 消息收发       │ • 通知管理              │ • BLE设备              │
│ • 用户交互       │ • 资源调度              │ • 其他IoT服务           │
│ • UI更新        │ • 事件分发              │                         │
└─────────────────┴──────────────────────────┴─────────────────────────┘
         │                     │                              │
         └─────────┬───────────┴──────────────┬───────────┘
                   │                              │
              Method Channel             WebSocket/Socket/BLE
              (Flutter原生通信)             (各种通信协议)
                   │                              │
        ┌──────────┴──────────┐              ┌───┴─────┐
        │     服务模块管理     │              │服务接口  │
        │ • MQTT服务模块      │              │ • MQTT  │
        │ • BLE服务模块       │              │ • BLE   │
        │ • 设备管理模块       │              │ • 其他  │
        │ • 未来扩展模块       │              └─────────┘
        └─────────────────────┘
```

## 🔧 核心组件设计

### 1. Flutter层 (保留现有优势)

**职责**：
- UI交互和状态显示
- 业务逻辑处理
- 与原生服务通信
- 服务模块管理
- 用户权限管理

**保留功能**：
- ✅ MQTTService完整功能
- ✅ BLEService完整功能
- ✅ 遗嘱消息配置
- ✅ 设备ID管理
- ✅ 消息收发逻辑

**优化功能**：
- 🔄 移除频繁定时检查
- 🔄 简化权限请求逻辑
- 🔄 添加原生服务管理器
- 🔄 统一的服务接口

### 2. 原生前台服务管理器 (新增)

**职责**：
- 系统级后台服务保活
- 多服务模块生命周期管理
- 资源调度和优化
- 持久通知管理
- 与Flutter层通信

**核心特性**：
- 🛡️ **前台服务保护**：系统级优先级保护
- 🔄 **模块化设计**：支持多种服务模块
- 📊 **资源优化**：智能资源调度
- 📱 **统一通知**：聚合状态显示
- 🔄 **事件分发**：服务间通信协调

### 3. 服务模块 (插件化)

#### MQTT服务模块
- MQTT连接管理
- 消息收发处理
- 遗嘱消息支持
- 自动重连机制

#### BLE服务模块
- BLE设备扫描
- 连接管理
- 后台数据收集
- 设备状态监控

#### 设备管理模块
- 设备状态同步
- 数据持久化
- 事件通知

#### 扩展模块
- 插件化架构
- 动态加载
- 标准接口

### 4. iOS后台服务 (新增)

**职责**：
- Background App Refresh优化
- 多模式后台保活
- 网络状态监听
- 与Flutter层通信

**核心特性**：
- 🍎 **Background Modes**：合法后台运行权限
- ⚡ **智能调度**：系统优化时机连接
- 🔄 **应用生命周期**：优雅的状态管理
- 📱 **多服务协调**：统一的后台管理

## 📱 实施阶段规划

### 阶段1：通用前台服务管理器
- 创建Android原生ForegroundService管理器
- 实现模块化服务架构
- 设计服务生命周期管理
- 添加Flutter-原生通信机制
- 优化统一通知显示

### 阶段2：MQTT服务模块
- 实现MQTT原生服务模块
- 集成MQTT客户端库
- 添加遗嘱消息支持
- 实现自动重连机制

### 阶段3：Flutter层集成
- 移除当前频繁检查机制
- 集成原生服务管理器
- 简化权限管理
- 统一服务接口设计

### 阶段4：BLE服务模块（扩展）
- 实现BLE原生服务模块
- 后台设备扫描功能
- 连接状态监控
- 数据收集和同步

### 阶段5：iOS后台服务
- 配置Background Modes
- 实现iOS服务管理器
- 优化应用生命周期管理
- 跨平台服务统一

### 阶段6：测试与优化
- 耗电测试和优化
- 连接稳定性测试
- 用户体验优化
- 性能监控完善
- 扩展性验证

## 🔄 通信机制设计

### 通用服务通信协议

```dart
// Flutter → 原生 (服务管理)
enum ServiceManagerMethod {
  startService,           // 启动服务
  stopService,            // 停止服务
  getServiceStatus,       // 获取服务状态
  getAllServiceStatus,    // 获取所有服务状态
  configureService,       // 配置服务参数
  sendCommand,            // 发送命令到服务
}

// 服务类型
enum ServiceType {
  mqtt,                   // MQTT服务
  ble,                    // BLE服务
  deviceManager,          // 设备管理服务
  custom,                 // 自定义服务
}

// 原生 → Flutter (服务事件)
enum ServiceEvent {
  serviceStatusChanged,   // 服务状态变化
  serviceStarted,         // 服务启动
  serviceStopped,         // 服务停止
  serviceError,           // 服务错误
  dataReceived,           // 收到数据
  notificationUpdated,    // 通知更新
}
```

### 服务模块通信协议

```dart
// MQTT服务特定方法
enum MqttServiceMethod {
  connect,                // 连接MQTT
  disconnect,             // 断开连接
  publish,                // 发布消息
  subscribe,              // 订阅主题
  unsubscribe,            // 取消订阅
  setWillMessage,         // 设置遗嘱消息
}

// BLE服务特定方法
enum BleServiceMethod {
  startScan,              // 开始扫描
  stopScan,               // 停止扫描
  connectDevice,          // 连接设备
  disconnectDevice,       // 断开设备
  readCharacteristic,     // 读取特征值
  writeCharacteristic,    // 写入特征值
}
```

### 数据传输格式

```dart
// 服务状态
class ServiceStatus {
  final ServiceType serviceType;
  final String serviceName;
  final bool isRunning;
  final String? error;
  final Map<String, dynamic>? config;
  final int timestamp;
}

// 通用服务数据
class ServiceData {
  final ServiceType serviceType;
  final String eventName;
  final Map<String, dynamic> data;
  final int timestamp;
}

// MQTT特定数据
class MqttMessageData {
  final String topic;
  final String payload;
  final int qos;
  final bool retain;
  final int timestamp;
}

// BLE特定数据
class BleDeviceData {
  final String deviceId;
  final String deviceName;
  final int rssi;
  final Map<String, dynamic> services;
  final int timestamp;
}
```

## 📋 技术栈选择

### Android原生
- **语言**：Kotlin (推荐) / Java
- **前台服务**：ForegroundService + ServiceManager
- **MQTT客户端**：HiveMQ MQTT Client / Paho
- **BLE客户端**：Android BLE API
- **通信**：Method Channel + Event Channel
- **架构**：模块化插件架构

### iOS原生
- **语言**：Swift
- **后台模式**：Background App Refresh + Background Modes
- **MQTT客户端**：CocoaMQTT / MQTTKit
- **BLE客户端**：Core Bluetooth
- **通信**：Method Channel + Event Channel
- **架构**：模块化插件架构

### Flutter
- **现有框架**：保持不变
- **通信包**：Method Channel, Event Channel
- **状态管理**：现有状态管理 + 原生状态同步
- **服务管理**：NativeServiceManager

## 🎯 预期效果

### 性能提升
- **耗电降低60-80%**：移除频繁定时器和心跳
- **连接稳定性提升90%**：原生服务保护
- **响应速度提升50%**：原生层快速处理
- **资源利用优化70%**：统一资源调度

### 用户体验
- **无感后台运行**：稳定的后台连接
- **智能通知**：聚合状态显示
- **流畅切换**：前后台无缝切换
- **多服务协同**：统一的用户体验

### 开发维护
- **代码复用高**：保留现有Flutter逻辑
- **模块化设计**：独立服务模块
- **跨平台兼容**：统一通信接口
- **易于扩展**：插件化架构
- **便于测试**：服务独立可测

### 扩展能力
- **新服务快速接入**：标准接口
- **第三方服务集成**：插件机制
- **配置化管理**：动态服务配置
- **监控和调试**：统一状态管理

## 🚀 下一步行动

### 立即实施计划
1. **阶段1**：创建Android通用前台服务管理器
2. **阶段2**：实施MQTT原生服务模块
3. **阶段3**：集成Flutter层通信机制
4. **阶段4**：扩展BLE服务模块
5. **阶段5**：实施iOS后台服务
6. **阶段6**：测试优化和扩展验证

### 开发优先级
- 🔥 **高优先级**：前台服务管理器 + MQTT模块
- ⚡ **中优先级**：Flutter集成 + BLE模块
- 🎯 **低优先级**：iOS支持 + 扩展功能

---

*此通用前台服务架构在保持现有Flutter优势的基础上，通过模块化设计大幅提升扩展性、稳定性和电池续航，是实现多种后台服务常驻运行的最佳选择。*