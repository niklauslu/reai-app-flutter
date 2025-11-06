import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';

/// BLE设备数据模型
class BLEDeviceModel {
  final String id;
  final String name;
  final String? version;
  final DeviceType type;
  final int rssi;
  final bool isConnected;
  final DateTime lastSeen;
  final BluetoothDevice? device;

  const BLEDeviceModel({
    required this.id,
    required this.name,
    this.version,
    required this.type,
    required this.rssi,
    this.isConnected = false,
    required this.lastSeen,
    this.device,
  });

  /// 从扫描结果创建设备模型
  factory BLEDeviceModel.fromScanResult(ScanResult result) {
    String deviceName = result.device.name;

    // 根据设备名称判断类型
    DeviceType type = DeviceType.other;
    String? version;

    if (deviceName.startsWith('DYJ-')) {
      // DYJ- 开头为1代产品 DYJV1
      type = DeviceType.dyjV1;
      version = 'DYJV1';
    } else if (deviceName.startsWith('DYJV2_')) {
      // DYJV2_ 开头为2代产品 DYJV2
      type = DeviceType.dyjV2;
      version = 'DYJV2';
    } else if (deviceName.contains('Card')) {
      type = DeviceType.dyjCard;
      version = 'DYJ Card';
    } else if (deviceName.contains('ReAI') || deviceName.contains('Glass')) {
      type = DeviceType.reaiGlass;
      version = 'ReAI Glass';
    }

    return BLEDeviceModel(
      id: result.device.id.id,
      name: deviceName,
      version: version,
      type: type,
      rssi: result.rssi,
      lastSeen: DateTime.now(),
      device: result.device,
    );
  }

  /// 从已连接设备创建模型
  factory BLEDeviceModel.fromConnectedDevice(BluetoothDevice device) {
    String deviceName = device.name;

    DeviceType type = DeviceType.other;
    String? version;

    if (deviceName.startsWith('DYJ-')) {
      // DYJ- 开头为1代产品 DYJV1
      type = DeviceType.dyjV1;
      version = 'DYJV1';
    } else if (deviceName.startsWith('DYJV2_')) {
      // DYJV2_ 开头为2代产品 DYJV2
      type = DeviceType.dyjV2;
      version = 'DYJV2';
    } else if (deviceName.contains('Card')) {
      type = DeviceType.dyjCard;
      version = 'DYJ Card';
    } else if (deviceName.contains('ReAI') || deviceName.contains('Glass')) {
      type = DeviceType.reaiGlass;
      version = 'ReAI Glass';
    }

    return BLEDeviceModel(
      id: device.id.id,
      name: deviceName,
      version: version,
      type: type,
      rssi: -50, // 默认值
      isConnected: true,
      lastSeen: DateTime.now(),
      device: device,
    );
  }

  BLEDeviceModel copyWith({
    String? id,
    String? name,
    String? version,
    DeviceType? type,
    int? rssi,
    bool? isConnected,
    DateTime? lastSeen,
    BluetoothDevice? device,
  }) {
    return BLEDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      type: type ?? this.type,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
      device: device ?? this.device,
    );
  }

  /// 获取设备描述
  String get description {
    switch (type) {
      case DeviceType.dyjV1:
        return '多功能智能硬件开发平台 1代';
      case DeviceType.dyjV2:
        return '多功能智能硬件开发平台 2代';
      case DeviceType.dyjCard:
        return '紧凑型卡片式开发板';
      case DeviceType.reaiGlass:
        return '智能增强现实眼镜';
      case DeviceType.other:
        return '其他BLE设备';
    }
  }

  /// 获取信号强度描述
  String get signalStrength {
    if (rssi >= -50) return '信号强';
    if (rssi >= -70) return '信号中';
    return '信号弱';
  }

  /// 获取设备颜色
  String get deviceColor {
    switch (type) {
      case DeviceType.dyjV1:
        return 'green';
      case DeviceType.dyjV2:
        return 'emerald';
      case DeviceType.dyjCard:
        return 'blue';
      case DeviceType.reaiGlass:
        return 'orange';
      case DeviceType.other:
        return 'gray';
    }
  }

  /// 获取用于显示的设备ID/MAC地址
  String get displayId {
    if (Platform.isIOS) {
      // iOS设备ID格式很长，取最后一个-后面的部分
      if (id.contains('-')) {
        return id.split('-').last;
      }
      // 如果没有-，取最后6位
      return id.length > 6 ? id.substring(id.length - 6) : id;
    } else {
      // Android显示完整的MAC地址格式
      return id;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BLEDeviceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BLEDeviceModel{id: $id, name: $name, type: $type, rssi: $rssi, isConnected: $isConnected}';
  }
}

/// 设备类型枚举
enum DeviceType {
  dyjV1,      // 点一机 DYJ 1代
  dyjV2,      // 点一机 DYJ 2代
  dyjCard,    // 点一机卡片版
  reaiGlass,  // ReAI 眼镜
  other,      // 其他设备
}

/// 连接状态枚举
enum ConnectionStatus {
  disconnected,  // 未连接
  connecting,    // 连接中
  connected,     // 已连接
  failed,        // 连接失败
}