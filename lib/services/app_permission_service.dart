import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

/// 应用级权限管理服务
/// 负责检测和引导用户设置应用所需的基本权限
class AppPermissionService {
  static final AppPermissionService _instance = AppPermissionService._internal();
  factory AppPermissionService() => _instance;
  AppPermissionService._internal();

  /// 权限状态缓存
  Map<String, bool> _permissionStatusCache = {};

  /// 检测所有必需权限
  Future<bool> checkAllPermissions(BuildContext context) async {
    debugPrint('🔍 开始检测应用权限...');

    // iOS网络权限通过应用首次网络请求自动触发，无需单独检测
    bool bluetoothOK = await _checkBluetoothPermissions(context);

    debugPrint('📋 权限检测结果: 蓝牙=$bluetoothOK');

    return bluetoothOK;
  }

  /// 触发iOS网络权限请求
  Future<void> triggerIOSNetworkPermission() async {
    if (!Platform.isIOS) {
      debugPrint('📱 此方法仅适用于iOS平台');
      return;
    }

    try {
      debugPrint('📱 触发iOS网络权限检查...');

      // 发起一个简单的HTTP请求来触发iOS网络权限弹窗
      // 使用一个常见且可靠的地址
      final response = await http.get(
        Uri.parse('https://httpbin.org/ip'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏰ 网络请求超时，但这通常意味着权限弹窗已经触发');
          return http.Response('timeout', 408);
        },
      );

      debugPrint('✅ iOS网络权限触发完成，状态码: ${response.statusCode}');
    } catch (e) {
      // 即使请求失败也没关系，目的是触发权限弹窗
      debugPrint('📡 iOS网络权限触发尝试: $e');
      debugPrint('💡 这通常意味着权限弹窗已被触发或网络不可用');
    }
  }

  /// 检测网络相关权限
  Future<bool> _checkNetworkPermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      // Android的网络权限通常在安装时授予，但Android 6.0+可能需要动态权限
      try {
        debugPrint('🤖 Android网络权限检查');
        // Android通常不需要单独的网络权限请求
        return true;
      } catch (e) {
        debugPrint('❌ Android网络权限检查失败: $e');
        return false;
      }
    } else {
      // iOS网络数据权限检查
      try {
        debugPrint('🍎 iOS网络数据权限检查');

        // 检查网络数据权限状态
        bool networkPermissionReady = await _checkIOSNetworkDataPermission();

        if (networkPermissionReady) {
          debugPrint('✅ iOS网络数据权限准备就绪');
          return true;
        } else {
          debugPrint('⚠️ iOS网络数据权限需要用户设置');
          return false;
        }
      } catch (e) {
        debugPrint('❌ iOS网络数据权限检查失败: $e');
        return false;
      }
    }
  }

  /// 检查iOS网络数据权限状态
  Future<bool> _checkIOSNetworkDataPermission() async {
    debugPrint('🍎 iOS网络数据权限检查');

    // iOS的无线数据权限是系统自动管理的
    // 权限设置出现在：设置 → 蜂窝网络 → [应用名称]
    // 提供三个选项：
    // - 关闭
    // - 无线局域网
    // - 无线局域网+蜂窝数据

    debugPrint('📱 iOS无线数据权限由系统自动管理');
    debugPrint('💡 用户可以在 设置 → 蜂窝网络 中配置应用的网络访问权限');

    // 这个权限不需要也不可以通过代码主动触发
    // 会在应用首次尝试网络访问时由系统自动处理

    return true;
  }

  /// 检测蓝牙权限
  Future<bool> _checkBluetoothPermissions(BuildContext context) async {
    try {
      debugPrint('🔵 开始检测蓝牙权限...');

      if (Platform.isAndroid) {
        // Android 12+ 蓝牙权限请求
        debugPrint('🤖 Android蓝牙权限请求');

        // 请求蓝牙权限（扫描、连接、广告）
        Map<Permission, PermissionStatus> bluetoothStatuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();

        debugPrint('📋 Android蓝牙权限状态: $bluetoothStatuses');

        // 检查蓝牙权限是否都授予了
        bool scanGranted = bluetoothStatuses[Permission.bluetoothScan]?.isGranted ?? false;
        bool connectGranted = bluetoothStatuses[Permission.bluetoothConnect]?.isGranted ?? false;

        // BLE扫描需要位置权限
        debugPrint('📍 请求位置权限（BLE扫描需要）');
        var locationStatus = await Permission.locationWhenInUse.request();
        debugPrint('📋 位置权限状态: $locationStatus');

        // 检查蓝牙服务是否启用
        var bluetoothServiceStatus = await Permission.bluetooth.serviceStatus;
        debugPrint('📋 蓝牙服务状态: $bluetoothServiceStatus');

        bool allPermissionsGranted = scanGranted && connectGranted && locationStatus.isGranted;
        bool bluetoothServiceEnabled = bluetoothServiceStatus.isEnabled;

        bool allOK = allPermissionsGranted && bluetoothServiceEnabled;

        if (allOK) {
          debugPrint('✅ Android蓝牙权限和服务已全部授予');
          return true;
        } else {
          debugPrint('⚠️ Android权限缺失: 扫描=$scanGranted, 连接=$connectGranted, 位置=${locationStatus.isGranted}, 蓝牙服务=$bluetoothServiceEnabled');
          return false;
        }

      } else {
        // iOS 蓝牙权限请求
        debugPrint('🍎 iOS蓝牙权限请求');

        // iOS 13+ 单个蓝牙权限
        var bluetoothStatus = await Permission.bluetooth.request();
        debugPrint('📋 iOS蓝牙权限状态: $bluetoothStatus');

        // iOS BLE扫描需要位置权限
        var locationStatus = await Permission.locationWhenInUse.request();
        debugPrint('📋 iOS位置权限状态: $locationStatus');

        // 检查蓝牙服务是否启用
        var bluetoothServiceStatus = await Permission.bluetooth.serviceStatus;
        debugPrint('📋 iOS蓝牙服务状态: $bluetoothServiceStatus');

        bool bluetoothGranted = bluetoothStatus.isGranted;
        bool locationGranted = locationStatus.isGranted;
        bool bluetoothServiceEnabled = bluetoothServiceStatus.isEnabled;

        bool allOK = bluetoothGranted && locationGranted && bluetoothServiceEnabled;

        if (allOK) {
          debugPrint('✅ iOS蓝牙权限和服务已全部授予');
          return true;
        } else {
          debugPrint('⚠️ iOS权限缺失: 蓝牙=$bluetoothGranted, 位置=$locationGranted, 蓝牙服务=$bluetoothServiceEnabled');
          return false;
        }
      }

    } catch (e) {
      debugPrint('💥 蓝牙权限检测异常: $e');
      return false;
    }
  }

  /// 获取权限的显示名称
  String _getPermissionDisplayName(Permission permission) {
    switch (permission) {
      case Permission.bluetooth:
        return '蓝牙';
      case Permission.bluetoothScan:
        return '蓝牙扫描';
      case Permission.bluetoothConnect:
        return '蓝牙连接';
      case Permission.location:
        return '位置';
      default:
        return permission.toString();
    }
  }

  /// 简单提示用户去设置
  void showPermissionSettingsTip(BuildContext context) {
    String message = Platform.isIOS
        ? '请设置权限：设置 → 隐私与安全性 → 本地网络，选择"无线局域网+蜂窝网络"'
        : '请在设置中开启必要权限';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 6),
        action: SnackBarAction(
          label: '去设置',
          onPressed: () {
            _openAppSettings();
          },
        ),
      ),
    );
  }

  /// 打开应用设置页面
  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('⚠️ 无法打开设置页面: $e');
    }
  }

  /// 显示Android网络权限对话框
  void _showAndroidNetworkPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('网络权限'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '检测到网络连接问题，请检查应用的网络权限设置。',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '💡 Android设备通常在安装时授予网络权限，如有问题请在应用设置中检查。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('稍后检查'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettingsMethod();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('去设置'),
            ),
          ],
        );
      },
    );
  }

  /// 检查特定权限状态
  Future<bool> checkSpecificPermission(Permission permission) async {
    try {
      PermissionStatus status = await permission.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('❌ 权限检查失败: $e');
      return false;
    }
  }

  /// 打开应用设置页面
  Future<void> openAppSettingsMethod() async {
    try {
      bool opened = await openAppSettings();
      if (!opened) {
        debugPrint('⚠️ 无法打开应用设置页面');
      }
    } catch (e) {
      debugPrint('💥 打开应用设置失败: $e');
    }
  }

  /// 获取权限状态摘要
  Future<Map<String, dynamic>> getPermissionSummary() async {
    Map<String, dynamic> summary = {};

    if (Platform.isIOS) {
      // iOS只有一个蓝牙权限
      summary['bluetooth'] = await checkSpecificPermission(Permission.bluetooth);
      summary['location'] = await checkSpecificPermission(Permission.locationWhenInUse);
    } else {
      // Android有细分的蓝牙权限
      summary['bluetooth'] = await checkSpecificPermission(Permission.bluetooth);
      summary['bluetoothScan'] = await checkSpecificPermission(Permission.bluetoothScan);
      summary['bluetoothConnect'] = await checkSpecificPermission(Permission.bluetoothConnect);
      summary['location'] = await checkSpecificPermission(Permission.locationWhenInUse);
    }

    return summary;
  }

  /// 显示Android权限对话框
  void _showAndroidPermissionDialog(BuildContext context, List<String> permissions, {required bool isPermanent}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.blue),
              SizedBox(width: 8),
              Text('权限需要授权'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPermanent
                    ? '以下权限被永久拒绝，需要在设置中手动开启：'
                    : '以下权限是应用正常运行所必需的：',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              ...permissions.map((permission) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(child: Text(permission)),
                  ],
                ),
              )).toList(),
              if (isPermanent) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '💡 提示：您也可以稍后在应用设置中开启这些权限',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            if (isPermanent)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettingsMethod();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('去设置'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 重新请求权限
                  _checkBluetoothPermissions(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('重新授权'),
              ),
          ],
        );
      },
    );
  }

  /// 显示iOS权限提示对话框
  void _showiOSPermissionTip(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('权限说明'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '蓝牙和位置权限是连接硬件设备所必需的，请在权限请求时选择"允许"。',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '📍 iOS权限位置：设置 → 隐私与安全性 → 蓝牙/定位服务',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  /// 检查iOS蓝牙可用性
  Future<bool> _checkBluetoothAvailability() async {
    try {
      // 在iOS上，蓝牙权限通过Info.plist自动弹出
      // 我们通过检查当前蓝牙权限状态来判断可用性
      PermissionStatus bluetoothStatus = await Permission.bluetooth.status;
      debugPrint('📋 iOS蓝牙权限状态: $bluetoothStatus');

      // 如果权限被拒绝或未设置，蓝牙不可用
      if (bluetoothStatus == PermissionStatus.denied ||
          bluetoothStatus == PermissionStatus.permanentlyDenied ||
          bluetoothStatus == PermissionStatus.restricted) {
        return false;
      }

      // 其他情况（包括granted和limited）认为蓝牙可用
      return true;
    } catch (e) {
      debugPrint('❌ 检查蓝牙可用性失败: $e');
      return false;
    }
  }

  /// 清除权限状态缓存
  void clearPermissionCache() {
    _permissionStatusCache.clear();
  }
}