# Android 证书配置说明

## 概述

本文档说明如何为 ReAI Assistant Android 应用配置签名证书，用于发布 APK 到 Google Play Store 或其他渠道。

## 文件说明

Android 应用签名需要以下文件：

- **keystore 文件**: 包含公钥和私钥的密钥库文件
- **签名配置**: 在 `android/app/build.gradle.kts` 中配置签名信息

## 生成 Android 签名证书

### 方法1: 使用 Android Studio (推荐)

1. **打开 Android Studio**，导入项目
2. **选择 Build → Generate Signed Bundle / APK**
3. **选择 APK**
4. **创建新密钥库**:
   - 选择保存位置
   - 设置密钥库密码
   - 设置别名 (建议使用应用名称)
   - 设置有效期 (建议 25 年以上)
   - 填写组织信息

### 方法2: 使用 keytool 命令行工具

```bash
# 进入项目根目录
cd /Users/niklaslu/CODE/github.com/reai.com/reai-app-flutter

# 生成 keystore 文件
keytool -genkey -v -keystore \
  android/app/key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias reai_key \
  -dname "CN=ReAI Assistant, OU=Development, O=ReAI, L=Beijing, ST=Beijing, C=CN"
```

### 方法3: 使用现有证书

如果你已有签名证书，请将以下文件复制到 `android/app/` 目录：

```
your-keystore.jks  → android/app/key.jks
```

## 配置 build.gradle.kts

在 `android/app/build.gradle.kts` 中添加签名配置：

```kotlin
android {
    // ... 其他配置 ...

    signingConfigs {
        create("release") {
            storeFile = file("key.jks")
            storePassword = "your_store_password"
            keyAlias = "reai_key"
            keyPassword = "your_key_password"
        }
    }

    buildTypes {
        release {
            // 使用发布签名配置
            signingConfig = signingConfigs.getByName("release")
            // 启用代码压缩和混淆
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Debug版本使用默认签名（测试用）
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
```

## 构建发布 APK

### 调试版本 (Debug APK)

```bash
flutter build apk --debug
```

### 发布版本 (Release APK)

```bash
flutter build apk --release
```

### App Bundle (推荐用于 Google Play Store)

```bash
flutter build appbundle --release
```

## 证书文件安全

⚠️ **重要安全提示**:

1. **不要将 keystore 文件提交到版本控制系统**
2. **妥善保管密码和密钥文件**
3. **建议使用密码管理器存储密码**
4. **备份 keystore 文件到安全位置**

## .gitignore 配置

确保 `android/app/` 目录中的密钥文件被忽略：

```gitignore
# Android signing files
android/app/key.jks
android/app/key.properties
android/app/keystore.properties
```

## 常见问题

### Q: 发布时出现签名错误
A: 检查 keystore 文件路径和密码是否正确

### Q: Google Play Store 上传失败
A: 确保使用正式签名证书，而不是调试签名

### Q: 应用无法安装
A: 检查 APK 包名是否唯一，签名是否有效

## 应用包名修改

如需修改应用包名，请修改 `android/app/build.gradle.kts` 中的 `applicationId`：

```kotlin
android {
    defaultConfig {
        applicationId = "com.reai.dyj"  // 修改为你的包名
        // ...
    }
}
```

## 联系支持

如遇到证书配置问题，请参考：
- Flutter 官方文档: https://flutter.dev/docs/deployment/android
- Android 开发者文档: https://developer.android.com/studio/publish/app-signing

---

**ReAI Assistant Android 签名配置指南**