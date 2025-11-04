import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设备ID管理服务
class DeviceIdService {
  static const String _deviceIdKey = 'reai_device_id';
  static const String _deviceNameKey = 'reai_device_name';
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// 获取设备ID
  Future<String> getDeviceId() async {
    // 如果已经缓存，直接返回
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 尝试从本地存储获取
      String? savedDeviceId = prefs.getString(_deviceIdKey);

      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        // 清理设备ID中的非法字符，只保留字母、数字、下划线和连字符
        savedDeviceId = savedDeviceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        _cachedDeviceId = savedDeviceId;
        print('✅ 从本地存储获取设备ID: $_cachedDeviceId');
        return _cachedDeviceId!;
      }

      // 如果没有保存过，获取系统设备ID
      final systemDeviceId = await _getSystemDeviceId();

      // 保存到本地存储
      await prefs.setString(_deviceIdKey, systemDeviceId);
      _cachedDeviceId = systemDeviceId;

      print('🆕 获取系统设备ID: $_cachedDeviceId');
      return _cachedDeviceId!;

    } catch (e) {
      print('❌ 设备ID获取失败: $e');
      // 如果出现错误，生成临时设备ID
      final tempDeviceId = 'TEMP_${DateTime.now().millisecondsSinceEpoch}';
      _cachedDeviceId = tempDeviceId;
      return _cachedDeviceId!;
    }
  }

  /// 获取系统设备ID
  Future<String> _getSystemDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // 使用 Android ID，添加reaiapp前缀
      final androidId = androidInfo.id;

      // 优先使用 Android ID，如果不为空且不是默认值则使用
      if (androidId.isNotEmpty) {
        return 'reaiapp_${androidId.replaceAll('.', '')}';
      }

      // 备用方案：使用品牌+型号+主板，添加reaiapp前缀
      final brand = androidInfo.brand;
      final model = androidInfo.model;
      final board = androidInfo.board;
      final fingerprint = androidInfo.fingerprint;

      return 'reaiapp_${brand}_${model}_${board}_${fingerprint.hashCode.abs()}'.replaceAll('.', '_');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      // 使用 identifierForVendor，添加reaiapp前缀
      final identifierForVendor = iosInfo.identifierForVendor;

      if (identifierForVendor != null && identifierForVendor!.isNotEmpty) {
        return 'reaiapp_${identifierForVendor!.replaceAll('.', '')}';
      }

      // 备用方案：使用设备型号和系统版本，添加reaiapp前缀
      final model = iosInfo.model;
      final systemVersion = iosInfo.systemVersion;
      final name = iosInfo.name;

      return 'reaiapp_${name}_${model}_${systemVersion}';
    }

    // 其他平台的备用方案
    return 'UNKNOWN_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 获取设备ID（同步版本，如果已缓存）
  String? getCachedDeviceId() {
    return _cachedDeviceId;
  }

  /// 获取设备名称
  Future<String> getDeviceName() async {
    // 如果已经缓存，直接返回
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 尝试从本地存储获取
      String? savedDeviceName = prefs.getString(_deviceNameKey);

      if (savedDeviceName != null && savedDeviceName.isNotEmpty) {
        _cachedDeviceName = savedDeviceName;
        print('✅ 从本地存储获取设备名称: $_cachedDeviceName');
        return _cachedDeviceName!;
      }

      // 如果没有保存过，生成新的设备名称
      final newDeviceName = _generateDeviceName();

      // 保存到本地存储
      await prefs.setString(_deviceNameKey, newDeviceName);
      _cachedDeviceName = newDeviceName;

      print('🆕 生成设备名称: $_cachedDeviceName');
      return _cachedDeviceName!;

    } catch (e) {
      print('❌ 设备名称获取失败: $e');
      // 如果出现错误，生成临时设备名称
      final tempDeviceName = 'ReAI_Assistant_${Random().nextInt(9999)}';
      _cachedDeviceName = tempDeviceName;
      return _cachedDeviceName!;
    }
  }

  /// 生成设备名称
  String _generateDeviceName() {
    final random = Random();
    final randomNum = random.nextInt(9999);
    return 'ReAI_Assistant_${randomNum.toString().padLeft(4, '0')}';
  }

  /// 重新获取设备ID（清除缓存后重新获取）
  Future<String> refreshDeviceId() async {
    try {
      _cachedDeviceId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);

      final newDeviceId = await getDeviceId();
      print('🔄 重新获取设备ID: $_cachedDeviceId');
      return _cachedDeviceId!;
    } catch (e) {
      print('❌ 设备ID重新获取失败: $e');
      throw e;
    }
  }

  /// 检查设备ID是否存在
  Future<bool> hasDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_deviceIdKey);
      return deviceId != null && deviceId.isNotEmpty;
    } catch (e) {
      print('❌ 检查设备ID失败: $e');
      return false;
    }
  }

  /// 清除设备ID
  Future<void> clearDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      _cachedDeviceId = null;
      print('🗑️ 清除设备ID');
    } catch (e) {
      print('❌ 清除设备ID失败: $e');
    }
  }

  /// 格式化设备ID显示（中间用...省略）
  String formatDeviceIdForDisplay(String deviceId, {int maxChars = 16}) {
    if (deviceId.length <= maxChars) {
      return deviceId;
    }

    final startChars = (maxChars / 2).floor();
    final endChars = maxChars - startChars - 3; // 减去省略号的长度

    return '${deviceId.substring(0, startChars)}...${deviceId.substring(deviceId.length - endChars)}';
  }
}