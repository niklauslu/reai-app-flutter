# iOS真机调试设置指南

## 📋 已完成项目

✅ **CSR证书签名请求文件已生成**
- 文件位置：`certs/development_certificate.csr`
- 邮箱：ngo.kangkun@gmail.com
- 公司名称：点一几
- 私钥文件：`certs/private.key` (请妥善保管)

## 🔗 下一步操作指南

### 第1步：在Apple Developer Portal创建开发证书

1. **访问开发者门户**
   - 打开 https://developer.apple.com
   - 使用 `ngo.kangkun@gmail.com` 登录

2. **导航到证书管理**
   - 进入 "Certificates, Identifiers & Profiles"
   - 选择 "Certificates"

3. **创建新证书**
   - 点击右上角 "+" 按钮
   - 选择证书类型：**Apple Development**
   - 点击 "Continue"

4. **上传CSR文件**
   - 选择 "Choose File"
   - 上传 `certs/development_certificate.csr` 文件
   - 点击 "Continue"

5. **下载证书**
   - 生成后点击 "Download"
   - 保存 `.cer` 文件到 `certs/` 目录

### 第2步：安装证书到Mac

1. **安装下载的证书**
   ```bash
   # 双击下载的.cer文件，会自动添加到钥匙串
   # 或使用命令行安装
   security import certs/your_certificate.cer -k ~/Library/Keychains/login.keychain-db
   ```

2. **验证安装**
   - 打开 "钥匙串访问" (Keychain Access)
   - 在 "登录" 钥匙串中查看证书
   - 确保证书显示为 "有效"

### 第3步：注册测试设备

1. **获取设备UDID**
   ```bash
   # 方法1：使用Xcode
   # 打开Xcode → Window → Devices and Simulators
   # 连接iPhone，复制Identifier

   # 方法2：使用系统信息
   # 系统偏好设置 → 隐私与安全性 → 分析 → 查看设备信息
   ```

2. **在开发者门户注册设备**
   - 进入 "Certificates, Identifiers & Profiles"
   - 选择 "Devices"
   - 点击 "+" 添加设备
   - 输入设备名称和UDID

### 第4步：创建App ID和描述文件

1. **创建App ID**
   - 进入 "Identifiers"
   - 点击 "+" 创建新ID
   - 选择 "App IDs"
   - 输入描述和Bundle ID: `com.reai.dyj`

2. **创建开发描述文件**
   - 进入 "Profiles"
   - 点击 "+" 创建新profile
   - 选择 "iOS App Development"
   - 选择对应的App ID
   - 选择开发证书
   - 选择测试设备
   - 下载并安装描述文件

### 第5步：配置Xcode项目

1. **打开Xcode项目**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **配置签名**
   - 选择 "Runner" 项目
   - 选择 "Runner" target
   - 在 "Signing & Capabilities" 标签中：
     - Team: 选择你的开发者账号
     - Bundle Identifier: `com.reai.dyj`
     - 勾选 "Automatically manage signing"

3. **连接设备并运行**
   ```bash
   # 查看可用设备
   flutter devices

   # 在iPhone上运行应用
   flutter run -d <你的iPhone设备名称>
   ```

## 📱 设备信任设置

安装应用后，需要在iPhone上信任开发者：

1. **设置信任**
   - iPhone设置 → 通用 → VPN与设备管理
   - 找到你的开发者应用
   - 点击 "信任"

2. **允许应用权限**
   - 首次运行时会请求蓝牙、位置等权限
   - 根据需要授予相应权限

## 🚀 测试MQTT后台功能

应用安装后，可以测试以下功能：

1. **MQTT连接测试**
   - 打开应用，查看MQTT连接状态
   - 应显示绿色连接状态图标

2. **后台运行测试**
   - 将应用切换到后台
   - 观察MQTT连接是否保持活跃
   - 检查控制台日志输出

3. **锁屏测试**
   - 锁定手机屏幕
   - 解锁后检查MQTT连接状态
   - 验证后台保活机制是否正常工作

## 🔧 故障排除

### 常见问题

1. **证书问题**
   - 确保证书在"登录"钥匙串中
   - 检查证书是否过期
   - 重新下载并安装证书

2. **设备未识别**
   - 确保iPhone已信任此电脑
   - 检查USB连接线
   - 重启Xcode和设备

3. **签名失败**
   - 检查Bundle ID是否正确
   - 确认描述文件包含该设备
   - 清理项目后重新构建

4. **MQTT连接问题**
   - 检查网络连接
   - 验证MQTT服务器配置
   - 查看应用日志输出

### 清理和重新构建

```bash
# 清理Flutter项目
flutter clean

# 重新获取依赖
flutter pub get

# 清理iOS项目
cd ios && xcodebuild clean && cd ..

# 重新构建运行
flutter run -d <设备名称>
```

## 📁 文件参考

- `certs/development_certificate.csr` - CSR证书请求文件
- `certs/private.key` - 私钥文件（请妥善保管）
- `ios/Runner/Info.plist` - iOS应用配置
- `ios/Runner/BackgroundTaskManager.swift` - 后台任务管理
- `lib/services/ios_background_service.dart` - iOS后台服务

---

**📞 如需帮助**
如果在设置过程中遇到问题，请检查Xcode控制台输出的错误信息，或联系技术支持。