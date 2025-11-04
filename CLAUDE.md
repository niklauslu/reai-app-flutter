# CLAUDE.md

此文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 项目概览

**ReAI Assistant** - 硬件AI助手Flutter应用，具备BLE设备管理功能。

**技术栈**: Flutter 3.9.2+, Dart, Material 3, flutter_blue_plus, Riverpod (已配置但未使用)

**核心功能**:
- BLE设备扫描和连接管理
- 硬件设备分类 (DYJ V1/V2, DYJ Card, ReAI Glass)
- AI助手界面 (UI已完成，后端集成待实现)
- 硬件产品展示和管理

## 架构设计

### 应用结构
- **主入口**: `lib/main.dart` - 基于标签页的4部分架构
- **状态管理**: 当前使用StatefulWidget模式，Riverpod已配置供未来使用
- **导航**: Material Design TabBar导航，包含4个标签页 (仪表板、硬件、项目、AI工具)

### 核心目录结构
```
lib/
├── components/     # 可复用UI组件 (按钮、卡片)
├── ble/           # BLE功能 (服务、设备模型)
├── pages/         # 页面实现
├── theme/         # 设计系统 (颜色、文字样式、主题)
├── constants/     # 应用常量 (尺寸、时长)
└── services/      # 服务层 (为未来扩展预留)
```

### BLE架构
- **BLEService**: 单例服务，管理扫描、连接、权限
- **设备类型**: 根据设备名称模式自动分类
  - `DYJ-*` → dyjV1 (第一代)
  - `DYJV2_*` → dyjV2 (第二代)
  - `*Card*` → dyjCard
  - `*ReAI*/*Glass*` → reaiGlass
  - 其他 → other

### 设计系统
- **色彩方案**: 白绿黑主题
  - 主色: `#00D474` (绿色)
  - 背景: `#FFFFFF` (白色)
  - 文字: `#1A1A1A` (黑色)
- **排版**: 完整的文字样式系统
- **组件**: 自定义按钮和卡片变体，样式一致

## 开发命令

### 构建和运行
```bash
# 调试构建
flutter build apk --debug

# 安装到连接的Android设备
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 在指定设备上运行
flutter run -d <设备ID>

# 清理构建
flutter clean && flutter pub get
```

### 资源管理
```bash
# 生成应用图标 (使用flutter_launcher_icons)
dart run flutter_launcher_icons

# SVG转PNG (需要ImageMagick)
convert assets/app_icon.svg assets/app_icon.png
```

### 依赖管理
```bash
# 获取依赖
flutter pub get

# 更新依赖
flutter pub upgrade
```

## 平台配置

### Android
- **包配置**: 已配置Android BLE权限
- **目标SDK**: 使用自适应图标，命名为launcher_icon
- **权限**: 已配置蓝牙、位置和后台位置权限

### iOS
- **BLE支持**: 完整iOS支持，Info.plist配置正确
- **图标**: 生成App Store兼容图标

### 其他平台
- **Web/Linux/macOS/Windows**: 基础支持可用，BLE功能仅限移动端

## 核心实现细节

### BLE设备管理
- **扫描**: 5秒超时，智能设备过滤
- **过滤**: 移除空名称、MAC地址和位置跟踪设备
- **连接**: 基于流的连接状态管理，生命周期处理正确
- **UI**: 设备卡片显示MAC地址、信号强度、连接状态

### 组件系统
- **按钮**: PrimaryButton (填充), SecondaryButton (边框), TextButtonWidget
- **卡片**: StandardCard, TitledCard, FeatureCard，样式一致
- **尺寸**: 完整尺寸系统 (小、中、大)，间距合适

### 重要模式
- **流管理**: dispose()方法中正确的订阅取消
- **错误处理**: 权限和连接问题的用户友好错误对话框
- **状态更新**: setState()调用前的mounted检查
- **资源生成**: 通过flutter_launcher_icons插件管理图标

## 开发注意事项

### 代码质量
- **代码检查**: 配置flutter_lints包，分析选项严格
- **文档**: 整个代码库中有详细的中文注释
- **结构**: 清晰的关注点分离，模块化组件设计

### 测试
- 已配置测试框架 (`flutter_test`)，但需要实现测试覆盖
- BLE功能需要物理设备测试

### 性能考虑
- BLE扫描限制为5秒以保护电池
- 流订阅正确管理以防止内存泄漏
- 实现设备过滤以减少UI噪音

## 常见开发任务

### 添加新设备类型
1. 更新 `ble_device_model.dart` 中的 `DeviceType` 枚举
2. 修改 `fromScanResult()` 和 `fromConnectedDevice()` 中的设备分类逻辑
3. 更新 `_getDeviceColor()` 方法中的UI颜色映射
4. 在 `_getDeviceIcon()` 方法中添加适当图标

### 更新应用主题
- 在 `theme/colors.dart` 中修改颜色
- 在 `theme/text_styles.dart` 中更新文字样式
- 在 `constants/dimensions.dart` 中调整尺寸

### BLE功能开发
- 核心逻辑在 `ble/ble_service.dart`
- 设备模型在 `ble/ble_device_model.dart`
- UI实现在 `pages/ble_device_list_page.dart`