# ReAI Assistant Android 证书信息

## 当前配置

### 证书文件信息
- **文件位置**: `android/app/key.jks`
- **证书别名**: `reai_key`
- **存储密码**: `reai123456`
- **密钥密码**: `reai123456`
- **有效期**: 10,000天 (约27年)
- **算法**: RSA 2048位

### 应用信息
- **包名**: `com.reai.dyj`
- **应用名称**: ReAI Assistant
- **组织信息**:
  - 单位: Development
  - 组织: ReAI
  - 地区: Beijing, China

### 构建配置
- **签名配置**: 发布版本使用自定义签名
- **代码混淆**: 启用 (R8)
- **ProGuard规则**: `android/app/proguard-rules.pro`

## 快速命令

### 构建APK
```bash
# 构建发布版APK (已签名)
flutter build apk --release

# 构建调试版APK
flutter build apk --debug

# 构建App Bundle (用于Google Play)
flutter build appbundle --release
```

### 安装APK到设备
```bash
# 使用便捷脚本
./certs/install_apk.sh

# 手动安装
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 查看APK信息
```bash
# 查看APK内容
aapt dump badging build/app/outputs/flutter-apk/app-release.apk

# 验证签名
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

## 文件结构

```
certs/
├── README_Android_Setup.md     # 详细配置说明
├── install_apk.sh              # 安装脚本
├── certificate_info.md         # 本文件 - 快速参考
└── (keystore文件在android/app/key.jks)

android/app/
├── key.jks                     # 签名证书文件
├── build.gradle.kts            # 构建配置(包含签名配置)
└── proguard-rules.pro          # ProGuard混淆规则

build/app/outputs/flutter-apk/
└── app-release.apk             # 构建生成的APK文件
```

## 安全注意事项

⚠️ **重要**:
- keystore文件 (`android/app/key.jks`) 已添加到 `.gitignore`，不会提交到版本控制
- 请妥善保管密码和证书文件
- 建议将keystore文件备份到安全位置
- 如需更改密码，请使用 `keytool -keystore android/app/key.jks -storepasswd -new 新密码`

## 故障排除

### 构建失败
1. 清理构建缓存: `flutter clean && flutter pub get`
2. 检查Java版本: `java -version` (建议Java 11+)
3. 检查Android SDK配置

### 安装失败
1. 确保设备开启USB调试
2. 检查设备存储空间
3. 先卸载旧版本: `adb uninstall com.reai.dyj`

### 签名问题
1. 检查keystore文件是否存在: `ls -la android/app/key.jks`
2. 验证证书有效性: `keytool -list -v -keystore android/app/key.jks`

## 版本历史

- **v1.0** - 初始证书配置 (2025-11-07)
  - 生成10,000天有效期的RSA 2048位证书
  - 配置ProGuard混淆规则
  - 创建自动化安装脚本