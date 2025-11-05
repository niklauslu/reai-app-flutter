import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import '../mqtt/mqtt_service.dart';
import '../mqtt/models/mqtt_message.dart';
import 'device_id_service.dart';

/// 后台服务管理器 - 使用FlutterBackground和生命周期管理
class BackgroundServiceManager {
  static bool _isInitialized = false;
  static bool _isBackgroundMode = false;
  static bool _isBackgroundExecutionEnabled = false;
  static Timer? _connectionCheckTimer;

  /// 初始化后台服务
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 不在启动时立即请求权限，避免显示耗电详情
      // 只在真正需要后台运行时才请求权限
      print('🔧 后台服务管理器已准备就绪');

      _isInitialized = true;
      print('✅ 后台服务管理器初始化成功');
    } catch (e) {
      print('❌ 后台服务管理器初始化失败: $e');
    }
  }

  /// 启用后台执行（带权限请求）
  static Future<bool> enableBackgroundExecution() async {
    if (!Platform.isAndroid || _isBackgroundExecutionEnabled) return true;

    try {
      // 先检查是否已有必要权限
      final hasPermissions = await _checkHasPermissions();

      if (!hasPermissions) {
        print('⚠️ 缺少后台运行权限，尝试请求...');
        final granted = await _requestPermissions();
        if (!granted) {
          print('❌ 权限请求被拒绝，启用备用后台检查机制');
          return false;
        }
      }

      return await _enableBackgroundExecutionSilent();
    } catch (e) {
      print('❌ 启用后台执行异常: $e');
      return false;
    }
  }

  /// 静默启用后台执行（不请求权限）
  static Future<bool> _enableBackgroundExecutionSilent() async {
    if (!Platform.isAndroid || _isBackgroundExecutionEnabled) return true;

    try {
      final androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: "ReAI Assistant",
        notificationText: "MQTT连接保持中，设备状态实时同步",
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        notificationImportance: AndroidNotificationImportance.high,
        enableWifiLock: true,
        showBadge: true,
      );

      final success = await FlutterBackground.initialize(androidConfig: androidConfig);

      if (success) {
        await FlutterBackground.enableBackgroundExecution();
        _isBackgroundExecutionEnabled = true;
        print('✅ 后台执行已启用（静默）');
        return true;
      } else {
        print('❌ 启用后台执行失败');
        return false;
      }
    } catch (e) {
      print('❌ 静默启用后台执行异常: $e');
      return false;
    }
  }

  /// 禁用后台执行
  static Future<void> disableBackgroundExecution() async {
    if (!Platform.isAndroid || !_isBackgroundExecutionEnabled) return;

    try {
      await FlutterBackground.disableBackgroundExecution();
      _isBackgroundExecutionEnabled = false;
      print('✅ 后台执行已禁用');
    } catch (e) {
      print('❌ 禁用后台执行失败: $e');
    }
  }

  /// 检查是否已有权限
  static Future<bool> _checkHasPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // 只检查通知权限，不检查电池优化豁免
      final notification = await Permission.notification.status;

      print('📋 权限检查 - 通知权限: ${notification.name} = ${notification.isGranted}');
      return notification.isGranted;
    } catch (e) {
      print('❌ 检查权限失败: $e');
      return false;
    }
  }

  /// 请求所有必要权限
  static Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      print('📋 请求后台运行权限...');

      // 只请求必要的通知权限，不请求电池优化豁免以避免耗电详情
      final notification = await Permission.notification.request();

      if (notification.isGranted) {
        print('✅ 通知权限已获取');
      } else {
        print('⚠️ 通知权限被拒绝');
      }

      return notification.isGranted;
    } catch (e) {
      print('❌ 请求后台权限失败: $e');
      return false;
    }
  }

  /// 记录权限状态
  static void _logPermissionStatus(Map<String, bool> permissions) {
    permissions.forEach((permission, granted) {
      final status = granted ? '✅ 已授权' : '❌ 被拒绝';
      print('$permission: $status');
    });
  }

  /// 检查权限状态
  static Future<Map<String, bool>> checkPermissions() async {
    if (!Platform.isAndroid) return {};

    try {
      final batteryOptimization = await Permission.ignoreBatteryOptimizations.status;
      final notification = await Permission.notification.status;

      return {
        'batteryOptimization': batteryOptimization.isGranted,
        'notification': notification.isGranted,
      };
    } catch (e) {
      print('❌ 检查权限失败: $e');
      return {};
    }
  }

  /// 设置后台模式
  static Future<void> setBackgroundMode(bool isBackground) async {
    if (_isBackgroundMode == isBackground) return;

    _isBackgroundMode = isBackground;
    print('🔄 后台模式: ${isBackground ? '开启' : '关闭'}');

    try {
      if (isBackground) {
        await _handleAppBackgrounded();
      } else {
        await _handleAppForegrounded();
      }
    } catch (e) {
      print('❌ 设置后台模式失败: $e');
    }
  }

  /// 处理应用进入后台
  static Future<void> _handleAppBackgrounded() async {
    if (Platform.isIOS) {
      // iOS: 尝试保持连接，但不强制断开
      print('🍎 iOS平台，尝试保持MQTT连接');
      // iOS对后台运行限制更严格，但尝试维持连接
      _setupConnectionCheck();
      return;
    }

    // Android: 静默尝试启用后台执行，避免重复权限请求
    print('🤖 Android平台，尝试保持MQTT连接');

    // 先尝试静默启用后台执行
    if (!_isBackgroundExecutionEnabled) {
      final hasPermissions = await _checkHasPermissions();
      if (hasPermissions) {
        final backgroundEnabled = await _enableBackgroundExecutionSilent();
        if (backgroundEnabled) {
          print('✅ 前台服务已启用，MQTT连接将在后台保持');
        } else {
          print('⚠️ 前台服务启用失败，将使用连接保活机制');
        }
      } else {
        print('⚠️ 缺少通知权限，跳过前台服务');
      }
    } else {
      print('✅ 前台服务已在运行');
    }

    // 发送在线状态消息保持连接活跃
    try {
      final mqttService = MQTTService();
      if (mqttService.currentStatus == MQTTConnectionStatus.connected) {
        print('📤 发送在线状态保持连接活跃');
        await mqttService.sendOnlineStatus();
      }
    } catch (e) {
      print('⚠️ 发送在线状态失败: $e');
    }

    // 设置连接保活定时器
    _setupConnectionCheck();
  }

  /// 处理应用回到前台
  static Future<void> _handleAppForegrounded() async {
    print('📱 应用回到前台');

    try {
      // 检查MQTT连接状态
      final mqttService = MQTTService();
      final currentStatus = mqttService.currentStatus;

      print('📊 MQTT当前状态: ${currentStatus.toString().split('.').last}');

      // 如果MQTT未连接，尝试重新连接
      if (currentStatus != MQTTConnectionStatus.connected) {
        print('🔄 重新连接MQTT...');
        await mqttService.connect();
      }

      // 在前台也保持后台检查，确保连接稳定
      print('📱 应用在前台，保持连接检查机制');
      // 不禁用后台执行，保持连接稳定性

    } catch (e) {
      print('❌ 处理应用回到前台失败: $e');
    }
  }

  /// 设置连接检查定时器
  static void _setupConnectionCheck() {
    _connectionCheckTimer?.cancel();

    print('⏰ 启动后台连接检查定时器');

    // 每30秒检查一次连接，更积极地保持连接稳定
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (!_isBackgroundMode) {
        timer.cancel();
        return;
      }

      try {
        final mqttService = MQTTService();
        final currentStatus = mqttService.currentStatus;

        print('🔍 后台连接检查 - 当前状态: ${currentStatus.toString().split('.').last}');

        if (currentStatus != MQTTConnectionStatus.connected) {
          print('🔄 检测到连接断开，立即尝试重连MQTT');
          try {
            await mqttService.connect();
            print('✅ 后台重连成功');
          } catch (e) {
            print('❌ 后台重连失败: $e');
          }
        } else {
          // 如果已连接，发送轻量级心跳保持连接活跃
          try {
            // 发送在线状态，这会保持连接和会话活跃
            await mqttService.sendOnlineStatus();
            print('💓 后台心跳保持成功');
          } catch (e) {
            print('⚠️ 后台心跳发送失败，连接可能已断开: $e');
            // 心跳失败，尝试重连
            try {
              await mqttService.connect();
              print('✅ 心跳失败后重连成功');
            } catch (reconnectError) {
              print('❌ 心跳失败后重连也失败: $reconnectError');
            }
          }
        }
      } catch (e) {
        print('❌ 后台连接检查异常: $e');
      }
    });
  }

  /// 清理资源
  static Future<void> dispose() async {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    await disableBackgroundExecution();
    _isInitialized = false;
    _isBackgroundMode = false;
  }

  /// 获取后台模式状态
  static bool get isBackgroundMode => _isBackgroundMode;
  static bool get isInitialized => _isInitialized;
  static bool get isBackgroundExecutionEnabled => _isBackgroundExecutionEnabled;
}

/// 应用生命周期管理器
class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isInForeground = true;

  /// 初始化生命周期监听
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    print('✅ 应用生命周期服务已初始化');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('🔄 应用生命周期状态变化: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  /// 应用恢复到前台
  void _handleAppResumed() async {
    print('📱 应用恢复到前台');
    _isInForeground = true;
    await BackgroundServiceManager.setBackgroundMode(false);
  }

  /// 应用进入后台
  void _handleAppPaused() async {
    print('🔙 应用进入后台');
    _isInForeground = false;

    // 不发送离线状态，保持MQTT连接在后台运行
    // 遗嘱消息会在意外断开时自动发送
    print('📱 保持MQTT连接在后台运行');

    await BackgroundServiceManager.setBackgroundMode(true);
  }

  /// 应用即将销毁
  void _handleAppDetached() async {
    print('💀 应用即将销毁，发送离线状态...');
    _isInForeground = false;

    try {
      // 尝试发送离线状态
      final mqttService = MQTTService();

      // 如果MQTT已连接，立即发送离线状态
      if (mqttService.currentStatus == MQTTConnectionStatus.connected) {
        print('📤 MQTT已连接，发送离线状态...');
        await mqttService.sendOfflineStatus();
      } else {
        print('⚠️ MQTT未连接，跳过离线状态发送');
      }

      if (Platform.isAndroid) {
        await BackgroundServiceManager.setBackgroundMode(true);
      }

      print('✅ 应用销毁处理完成');
    } catch (e) {
      print('❌ 处理应用销毁失败: $e');
    }
  }

  /// 应用失去焦点但仍在可见
  void _handleAppInactive() {
    print('😴 应用失去焦点');
  }

  /// 应用被隐藏
  void _handleAppHidden() {
    print('👻 应用被隐藏');
    _handleAppPaused();
  }

  /// 获取当前应用状态
  bool get isInForeground => _isInForeground;
}