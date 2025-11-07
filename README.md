# ReAI Assistant

硬件AI助手Flutter应用，具备BLE蓝牙设备管理和智能硬件控制功能。

## 项目介绍

ReAI Assistant 是一款专为硬件开发者设计的智能助手应用，提供：

- 🔍 **BLE设备扫描**: 自动发现和分类附近的蓝牙设备
- 📱 **设备管理**: 支持DYJ系列开发板、ReAI智能眼镜等多种硬件
- 🤖 **AI助手**: 硬件开发智能对话和建议 (界面已完成)
- 🛠️ **硬件展示**: 详细的产品介绍和规格参数

## 支持的硬件设备

### 点一机系列
- **DYJ V1** (`DYJ-*`): 第一代多功能智能硬件开发平台
- **DYJ V2** (`DYJV2_*`): 第二代多功能智能硬件开发平台
- **DYJ Card** (`*Card*`): 紧凑型卡片式开发板

### ReAI系列
- **ReAI Glass** (`*ReAI*/*Glass*`): 智能增强现实眼镜

### 其他设备
- 自动识别其他BLE设备并归类显示

## 功能特性

### BLE设备管理
- ✅ 智能设备扫描 (5秒快速扫描)
- ✅ 自动设备分类和识别
- ✅ 实时信号强度监控
- ✅ 设备连接状态管理
- ✅ 已连接设备专属显示区域
- ✅ 智能设备分区显示 (已连接/未连接)
- ✅ 连接状态实时同步
- ✅ MAC地址显示
- ✅ 智能过滤无关设备
- ✅ 优化的设备卡片设计
- ✅ DYJV2设备协议通信支持

### MQTT实时通信
- ✅ 跨平台MQTT连接管理
- ✅ 自动重连和心跳保活机制
- ✅ 重复请求防护系统
- ✅ 远程设备控制 (MQTT-BLE集成)
- ✅ 请求响应超时处理 (5秒自动回复)
- ✅ 统一的heartbeat心跳消息类型
- ✅ UTF-8编码支持，确保中文传输正确
- ✅ 实时设备状态同步

### 跨平台后台保活
- ✅ **iOS**: BGTaskScheduler系统级调度，电池友好
- ✅ **Android**: FlutterBackground + 前台服务，连接稳定
- ✅ 统一45-60秒心跳间隔配置
- ✅ 应用生命周期管理
- ✅ 智能权限检测和引导
- ✅ 后台任务状态监控

### 用户界面
- 🎨 白绿黑现代设计主题
- 📱 Material 3 设计规范
- 🔄 响应式布局
- 🎯 直观的设备卡片展示
- 🔒 防误操作设计 (已连接设备移除断开按钮)
- 📊 实时状态同步显示
- 📱 设备详情页面完整信息展示

## 技术栈

- **Flutter 3.9.2+**: 跨平台移动应用框架
- **Dart**: 编程语言
- **flutter_blue_plus**: BLE蓝牙功能库
- **mqtt_client**: MQTT通信协议库
- **Material 3**: Google设计系统
- **Riverpod**: 状态管理 (已配置)
- **原生前台服务**: Android后台保活支持

## 开发环境要求

- Flutter SDK 3.9.2 或更高版本
- Android SDK (Android开发)
- Xcode (iOS开发)
- 支持BLE的物理设备 (推荐)

## 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd reai_app_flutter
```

### 2. 安装依赖
```bash
flutter pub get
```

### 3. 运行应用
```bash
# Android设备
flutter run

# 指定设备运行
flutter run -d <设备ID>

# 调试构建
flutter build apk --debug
```

### 4. 安装到设备
```bash
# 构建APK
flutter build apk --debug

# 安装到Android设备
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── components/            # UI组件库
│   ├── buttons/          # 按钮组件
│   └── cards/            # 卡片组件
├── ble/                  # BLE功能
│   ├── ble_service.dart   # BLE服务管理
│   └── ble_device_model.dart # 设备数据模型
├── pages/                # 页面
│   └── ble_device_list_page.dart # BLE设备列表
├── theme/                # 主题系统
│   ├── app_theme.dart    # 主题配置
│   ├── colors.dart       # 颜色系统
│   └── text_styles.dart  # 文字样式
└── constants/            # 常量定义
    ├── dimensions.dart   # 尺寸和间距
    └── durations.dart    # 动画时长
```

## 开发指南

### 添加新的设备类型
1. 在 `ble/ble_device_model.dart` 中更新 `DeviceType` 枚举
2. 修改设备分类逻辑
3. 更新UI颜色和图标映射
4. 重新构建应用测试

### 更新应用主题
- 修改 `theme/colors.dart` 中的颜色定义
- 更新 `theme/text_styles.dart` 中的文字样式
- 调整 `constants/dimensions.dart` 中的尺寸规范

### BLE功能开发
- 核心逻辑: `ble/ble_service.dart`
- 设备模型: `ble/ble_device_model.dart`
- UI实现: `pages/ble_device_list_page.dart`

## 权限配置

### Android权限
- 蓝牙扫描权限
- 蓝牙连接权限
- 位置权限 (BLE扫描需要)
- 后台位置权限 (可选)

### iOS权限
- 蓝牙权限
- 位置权限

## 构建和发布

### 开发构建
```bash
flutter build apk --debug
```

### 生产构建
```bash
flutter build apk --release
flutter build ios --release
```

### 图标生成
```bash
dart run flutter_launcher_icons
```

## 故障排除

### 常见问题

**Q: 扫描不到设备**
A: 确保已授予蓝牙和位置权限，并开启手机蓝牙

**Q: 连接失败**
A: 检查设备是否在范围内，确保设备未被其他应用连接

**Q: 应用崩溃**
A: 查看日志，检查设备是否支持BLE功能

### 调试命令
```bash
# 查看连接设备
flutter devices

# 查看日志
flutter logs

# 清理项目
flutter clean
```

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 联系我们

- 项目主页: [GitHub Repository]
- 问题反馈: [GitHub Issues]
- 技术支持: [支持邮箱]

---

**ReAI Assistant** - 让硬件开发更智能 🚀
