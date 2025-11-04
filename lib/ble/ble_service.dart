import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_device_model.dart';

/// BLE服务管理类
class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  bool _isScanning = false;
  final List<BLEDeviceModel> _scannedDevices = [];
  final List<BluetoothDevice> _connectedDevices = [];

  // 状态流
  final StreamController<bool> _isScanningController = StreamController<bool>.broadcast();
  final StreamController<List<BLEDeviceModel>> _devicesController = StreamController<List<BLEDeviceModel>>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  bool get isScanning => _isScanning;
  List<BLEDeviceModel> get scannedDevices => List.unmodifiable(_scannedDevices);
  List<BluetoothDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  Stream<bool> get isScanningStream => _isScanningController.stream;
  Stream<List<BLEDeviceModel>> get devicesStream => _devicesController.stream;
  Stream<String> get statusStream => _statusController.stream;

  /// 初始化BLE
  Future<bool> initialize() async {
    try {
      // 检查BLE支持（仅支持移动端）
      if (!Platform.isAndroid && !Platform.isIOS) {
        _statusController.add('当前平台不支持BLE');
        return false;
      }

      _statusController.add('正在检查蓝牙支持...');

      // 异步检查蓝牙支持
      bool isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _statusController.add('设备不支持蓝牙或蓝牙功能异常');
        return false;
      }

      // 检查蓝牙适配器状态
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _statusController.add('蓝牙未开启，请开启蓝牙后重试');
        return false;
      }

      // 监听蓝牙状态
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        switch (state) {
          case BluetoothAdapterState.on:
            _statusController.add('蓝牙已开启');
            break;
          case BluetoothAdapterState.off:
            _statusController.add('蓝牙已关闭');
            break;
          case BluetoothAdapterState.unavailable:
            _statusController.add('蓝牙不可用');
            break;
          default:
            _statusController.add('蓝牙状态未知');
        }
      });

      _statusController.add('BLE初始化成功');
      return true;
    } catch (e) {
      _statusController.add('BLE初始化失败: ${e.toString()}');
      return false;
    }
  }

  /// 请求权限
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android权限请求
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted);

        if (!allGranted) {
          _statusController.add('权限请求失败');
          return false;
        }
      } else if (Platform.isIOS) {
        // iOS权限请求
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

        bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted);

        if (!allGranted) {
          _statusController.add('权限请求失败');
          return false;
        }
      }

      _statusController.add('权限请求成功');
      return true;
    } catch (e) {
      _statusController.add('权限请求异常: ${e.toString()}');
      return false;
    }
  }

  /// 开始扫描
  Future<bool> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    if (_isScanning) {
      return true;
    }

    try {
      // 先停止之前的扫描
      await stopScan();

      _scannedDevices.clear();
      _isScanning = true;
      _isScanningController.add(true);
      _statusController.add('开始扫描设备...');

      // 设置扫描超时
      Timer(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });

      // 开始扫描
      await FlutterBluePlus.startScan(timeout: timeout);

      // 监听扫描结果
      FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
        _processScanResults(results);
      });

      return true;
    } catch (e) {
      _isScanning = false;
      _isScanningController.add(false);
      _statusController.add('扫描失败: ${e.toString()}');
      return false;
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (!_isScanning) {
      return;
    }

    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _isScanningController.add(false);
      _statusController.add('扫描已停止');
    } catch (e) {
      _statusController.add('停止扫描失败: ${e.toString()}');
    }
  }

  /// 处理扫描结果
  void _processScanResults(List<ScanResult> results) {
    final List<BLEDeviceModel> newDevices = [];

    for (ScanResult result in results) {
      BLEDeviceModel device = BLEDeviceModel.fromScanResult(result);

      // 过滤掉设备名称为空或null的设备
      if (device.name.isEmpty || device.name.trim().isEmpty) {
        continue;
      }

      // 过滤掉看起来像位置设备或MAC地址的设备
      if (_isLocationDevice(device.name)) {
        continue;
      }

      // 检查是否已存在
      int existingIndex = _scannedDevices.indexWhere((d) => d.id == device.id);
      if (existingIndex >= 0) {
        // 更新现有设备
        _scannedDevices[existingIndex] = device;
      } else {
        // 添加新设备
        _scannedDevices.add(device);
      }

      newDevices.add(device);
    }

    // 按信号强度排序
    _scannedDevices.sort((a, b) => b.rssi.compareTo(a.rssi));

    _devicesController.add(List.from(_scannedDevices));
  }

  /// 更新设备列表（包含已连接设备）
  void _updateDeviceList() {
    // 从已连接设备创建模型
    final List<BLEDeviceModel> connectedModels = _connectedDevices
        .map((device) => BLEDeviceModel.fromConnectedDevice(device))
        .toList();

    // 移除已连接的扫描设备
    _scannedDevices.removeWhere((device) =>
        connectedModels.any((connected) => connected.id == device.id));

    // 将已连接设备添加到列表开头
    final List<BLEDeviceModel> allDevices = [...connectedModels, ..._scannedDevices];

    _devicesController.add(allDevices);
  }

  /// 连接设备
  Future<bool> connectToDevice(BLEDeviceModel device) async {
    try {
      if (device.device == null) {
        _statusController.add('设备信息不完整');
        return false;
      }

      _statusController.add('正在连接 ${device.name}...');
      await device.device!.connect();

      _updateDeviceList();
      _statusController.add('已连接 ${device.name}');
      return true;
    } catch (e) {
      _statusController.add('连接失败: ${e.toString()}');
      return false;
    }
  }

  /// 断开设备连接
  Future<void> disconnectDevice(BLEDeviceModel device) async {
    try {
      if (device.device == null) {
        return;
      }

      await device.device!.disconnect();
      _updateDeviceList();
      _statusController.add('已断开 ${device.name}');
    } catch (e) {
      _statusController.add('断开连接失败: ${e.toString()}');
    }
  }

  /// 获取已连接设备列表
  Future<List<BluetoothDevice>> getConnectedDevices() async {
    try {
      return FlutterBluePlus.connectedDevices;
    } catch (e) {
      _statusController.add('获取连接设备失败: ${e.toString()}');
      return [];
    }
  }

  /// 获取蓝牙状态
  Future<BluetoothAdapterState> getBluetoothState() async {
    try {
      return await FlutterBluePlus.adapterState.first;
    } catch (e) {
      return BluetoothAdapterState.unavailable;
    }
  }

  /// 请求开启蓝牙（仅支持Android）
  Future<void> turnOnBluetooth() async {
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        _statusController.add('开启蓝牙失败: ${e.toString()}');
      }
    }
  }

  /// 判断是否为位置设备或无名设备
  bool _isLocationDevice(String deviceName) {
    String name = deviceName.trim().toLowerCase();

    // 过滤条件：
    // 1. 只包含数字和字母的组合（MAC地址格式）
    // 2. 包含冒号的十六进制字符串
    // 3. 太短的名称（少于3个字符）
    // 4. 纯数字或纯十六进制

    if (name.length < 3) {
      return true;
    }

    // 检查是否为MAC地址格式（包含冒号）
    if (name.contains(':')) {
      return true;
    }

    // 检查是否为纯十六进制字符
    RegExp hexPattern = RegExp(r'^[0-9a-f]+$', caseSensitive: false);
    if (hexPattern.hasMatch(name) && name.length <= 12) {
      return true;
    }

    // 检查是否包含位置相关的关键词
    List<String> locationKeywords = [
      'location', 'tracker', 'tag', 'beacon', 'sensor',
      'tile', 'chipolo', 'airtag', 'finder'
    ];

    for (String keyword in locationKeywords) {
      if (name.contains(keyword)) {
        return true;
      }
    }

    // 检查是否为常见设备类型但名称看起来是序列号
    if (RegExp(r'^[a-z0-9]{8,}$').hasMatch(name)) {
      return true;
    }

    return false;
  }

  /// 清理资源
  void dispose() {
    stopScan();
    _isScanningController.close();
    _devicesController.close();
    _statusController.close();
  }
}