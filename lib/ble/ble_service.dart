import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_device_model.dart';
import 'ble_protocol_handler.dart';
import 'ble_protocol.dart';

/// BLE服务管理类
class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  bool _isScanning = false;
  final List<BLEDeviceModel> _scannedDevices = [];
  BluetoothDevice? _currentConnectedDevice; // 单设备连接管理
  BLEProtocolHandler? _protocolHandler; // 协议处理器
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription; // 扫描结果订阅

  // 状态流
  final StreamController<bool> _isScanningController = StreamController<bool>.broadcast();
  final StreamController<List<BLEDeviceModel>> _devicesController = StreamController<List<BLEDeviceModel>>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _protocolMessageController = StreamController<Map<String, dynamic>>.broadcast();

  // 连接状态变化流控制器
  final StreamController<BLEDeviceModel?> _connectionStateController = StreamController<BLEDeviceModel?>.broadcast();

  bool get isScanning => _isScanning;
  List<BLEDeviceModel> get scannedDevices => List.unmodifiable(_scannedDevices);
  BluetoothDevice? get currentConnectedDevice => _currentConnectedDevice;
  List<BluetoothDevice> get connectedDevices => _currentConnectedDevice != null ? [_currentConnectedDevice!] : [];
  BLEProtocolHandler? get protocolHandler => _protocolHandler;

  /// 获取当前连接设备的BLE设备模型
  BLEDeviceModel? get currentConnectedDeviceModel {
    if (_currentConnectedDevice == null) return null;
    return BLEDeviceModel.fromConnectedDevice(_currentConnectedDevice!);
  }

  Stream<bool> get isScanningStream => _isScanningController.stream;
  Stream<List<BLEDeviceModel>> get devicesStream => _devicesController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get protocolMessageStream => _protocolMessageController.stream;
  Stream<BLEDeviceModel?> get connectionStateStream => _connectionStateController.stream;

  /// 初始化BLE
  Future<bool> initialize() async {
    try {
      debugPrint('🔷 BLE初始化开始...');

      // 检查BLE支持（仅支持移动端）
      if (!Platform.isAndroid && !Platform.isIOS) {
        String msg = '❌ 当前平台不支持BLE功能';
        debugPrint(msg);
        _statusController.add(msg);
        return false;
      }

      String msg = '🔍 正在检查蓝牙支持...';
      debugPrint(msg);
      _statusController.add(msg);

      // 异步检查蓝牙支持
      bool isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        msg = '⚠️ 设备不支持蓝牙或蓝牙功能异常';
        debugPrint(msg);
        _statusController.add(msg);
        return false;
      }

      debugPrint('✅ 蓝牙支持检查通过');

      // 检查蓝牙适配器状态，增加等待和重试机制
      BluetoothAdapterState adapterState;
      int retryCount = 0;
      const maxRetries = 3;

      do {
        adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState == BluetoothAdapterState.on) {
          break;
        }

        retryCount++;
        if (retryCount < maxRetries) {
          msg = '📴 蓝牙未开启，等待开启... ($retryCount/$maxRetries)';
          debugPrint(msg);
          _statusController.add(msg);
          // 等待2秒再重试
          await Future.delayed(const Duration(seconds: 2));
        }
      } while (retryCount < maxRetries);

      if (adapterState != BluetoothAdapterState.on) {
        msg = '📴 蓝牙未开启，请开启蓝牙后重试';
        debugPrint(msg);
        _statusController.add(msg);
        return false;
      }

      debugPrint('🟢 蓝牙适配器已开启');

      // 监听蓝牙状态
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        switch (state) {
          case BluetoothAdapterState.on:
            msg = '🟢 蓝牙已开启';
            debugPrint(msg);
            _statusController.add(msg);
            break;
          case BluetoothAdapterState.off:
            msg = '📴 蓝牙已关闭';
            debugPrint(msg);
            _statusController.add(msg);
            break;
          case BluetoothAdapterState.unavailable:
            msg = '❌ 蓝牙不可用';
            debugPrint(msg);
            _statusController.add(msg);
            break;
          default:
            msg = '❓ 蓝牙状态未知';
            debugPrint(msg);
            _statusController.add(msg);
        }
      });

      msg = '🎉 BLE初始化成功';
      debugPrint(msg);
      _statusController.add(msg);
      return true;
    } catch (e) {
      String msg = '💥 BLE初始化失败: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
      return false;
    }
  }

  /// 请求权限
  Future<bool> requestPermissions() async {
    try {
      debugPrint('🔐 开始请求蓝牙权限...');

      if (Platform.isAndroid) {
        debugPrint('📱 Android平台权限请求');
        // Android权限请求
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        debugPrint('📋 权限请求结果: $statuses');
        bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted);

        if (!allGranted) {
          String msg = '❌ Android权限请求失败，请检查权限设置';
          debugPrint(msg);
          _statusController.add(msg);
          return false;
        }
      } else if (Platform.isIOS) {
        debugPrint('🍎 iOS平台权限请求');
        // iOS只需要蓝牙和位置权限
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ].request();

        debugPrint('📋 iOS权限请求结果: $statuses');
        bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted);

        if (!allGranted) {
          String msg = '❌ iOS权限请求失败，请检查权限设置';
          debugPrint(msg);
          _statusController.add(msg);
          return false;
        }
      }

      String msg = '✅ 权限请求成功';
      debugPrint(msg);
      _statusController.add(msg);
      return true;
    } catch (e) {
      String msg = '💥 权限请求异常: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
      return false;
    }
  }

  /// 开始扫描
  Future<bool> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    if (_isScanning) {
      debugPrint('⚠️ 扫描已在进行中，跳过重复请求');
      return true;
    }

    try {
      debugPrint('🚀 准备开始BLE设备扫描...');

      // 先停止之前的扫描
      await stopScan();

      _scannedDevices.clear();
      _isScanning = true;
      _isScanningController.add(true);
      String msg = '🔍 开始扫描设备 (超时: ${timeout.inSeconds}秒)...';
      debugPrint(msg);
      _statusController.add(msg);

      // 设置扫描超时
      Timer(timeout, () {
        if (_isScanning) {
          debugPrint('⏰ 扫描超时，自动停止');
          stopScan();
        }
      });

      // 开始扫描
      await FlutterBluePlus.startScan(timeout: timeout);
      debugPrint('✅ BLE扫描已启动');

      // 监听扫描结果
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
        debugPrint('📡 收到 ${results.length} 个扫描结果');
        _processScanResults(results);
      });

      return true;
    } catch (e) {
      _isScanning = false;
      _isScanningController.add(false);
      String msg = '💥 扫描启动失败: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
      return false;
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (!_isScanning) {
      debugPrint('ℹ️ 扫描未在进行中，无需停止');
      return;
    }

    try {
      debugPrint('🛑 正在停止BLE扫描...');

      // 取消扫描结果订阅
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;

      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _isScanningController.add(false);
      String msg = '✅ 扫描已停止，共发现 ${_scannedDevices.length} 个设备';
      debugPrint(msg);
      _statusController.add(msg);
    } catch (e) {
      String msg = '💥 停止扫描失败: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
    }
  }

  /// 清空设备列表
  void clearDevicesList() {
    debugPrint('🗑️ 清空设备列表');
    _scannedDevices.clear();
    _devicesController.add([]);
    _statusController.add('设备列表已清空');
  }

  /// 处理扫描结果
  void _processScanResults(List<ScanResult> results) {
    debugPrint('🔄 开始处理 ${results.length} 个扫描结果...');
    final List<BLEDeviceModel> newDevices = [];
    int filteredCount = 0;
    int nameTooLongCount = 0;
    int locationDeviceCount = 0;
    int emptyNameCount = 0;

    for (ScanResult result in results) {
      BLEDeviceModel device = BLEDeviceModel.fromScanResult(result);

      debugPrint('📱 发现设备: ${device.name} (RSSI: ${device.rssi})');

      // 过滤掉设备名称为空或null的设备
      if (device.name.isEmpty || device.name.trim().isEmpty) {
        emptyNameCount++;
        debugPrint('❌ 过滤空名称设备');
        continue;
      }

      // 筛选设备名字长度 - 限制最大长度为20个字符
      if (device.name.length > 20) {
        nameTooLongCount++;
        debugPrint('⚠️ 设备名称过长 (${device.name.length}字符): ${device.name.substring(0, 20)}...');
        // 可以选择截断名称而不是完全过滤
        continue;
      }

      // 过滤掉看起来像位置设备或MAC地址的设备
      if (_isLocationDevice(device.name)) {
        locationDeviceCount++;
        debugPrint('🚫 过滤位置追踪设备: ${device.name}');
        continue;
      }

      // 检查是否已存在
      int existingIndex = _scannedDevices.indexWhere((d) => d.id == device.id);
      if (existingIndex >= 0) {
        // 更新现有设备（保留更好的信号强度）
        if (device.rssi > _scannedDevices[existingIndex].rssi) {
          debugPrint('🔄 更新设备信号强度: ${device.name} (${_scannedDevices[existingIndex].rssi} → ${device.rssi})');
          _scannedDevices[existingIndex] = device;
        }
      } else {
        // 添加新设备
        debugPrint('➕ 添加新设备: ${device.name} (信号: ${device.rssi})');
        _scannedDevices.add(device);
      }

      newDevices.add(device);
    }

    filteredCount = emptyNameCount + nameTooLongCount + locationDeviceCount;
    debugPrint('📊 扫描结果统计: 新增${newDevices.length}个, 过滤${filteredCount}个 (空名:${emptyNameCount}, 过长:${nameTooLongCount}, 位置设备:${locationDeviceCount})');

    // 按信号强度排序 (信号强的排前面，RSSI值越大信号越好)
    _scannedDevices.sort((a, b) => b.rssi.compareTo(a.rssi));

    debugPrint('📶 设备按信号强度排序完成:');
    for (int i = 0; i < _scannedDevices.length && i < 5; i++) {
      debugPrint('  ${i + 1}. ${_scannedDevices[i].name} (RSSI: ${_scannedDevices[i].rssi})');
    }
    if (_scannedDevices.length > 5) {
      debugPrint('  ... 还有 ${_scannedDevices.length - 5} 个设备');
    }

    _devicesController.add(List.from(_scannedDevices));
  }

  /// 更新设备列表（包含已连接设备）
  void _updateDeviceList() {
    // 从已连接设备创建模型
    final List<BLEDeviceModel> connectedModels = [];
    if (_currentConnectedDevice != null) {
      connectedModels.add(BLEDeviceModel.fromConnectedDevice(_currentConnectedDevice!));
    }

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
      debugPrint('🔗 准备连接设备: ${device.name}');

      if (device.device == null) {
        String msg = '❌ 设备信息不完整，无法连接';
        debugPrint(msg);
        _statusController.add(msg);
        return false;
      }

      // 检查是否已有连接的设备
      if (_currentConnectedDevice != null) {
        debugPrint('⚠️ 已有连接设备 ${_currentConnectedDevice!.name}，先断开连接');
        await _currentConnectedDevice!.disconnect();
        _currentConnectedDevice = null;
        debugPrint('✅ 已断开之前的设备连接');
      }

      String msg = '🔌 正在连接 ${device.name}...';
      debugPrint(msg);
      _statusController.add(msg);

      await device.device!.connect();
      _currentConnectedDevice = device.device;

      debugPrint('✅ 设备连接成功: ${device.name}');

      // 检查是否为DYJV2设备，如果是则初始化协议
      if (device.type == DeviceType.dyjV2) {
        debugPrint('🔧 [BLE协议] 检测到DYJV2设备，初始化协议通信...');

        _protocolHandler = BLEProtocolHandler();
        bool protocolConnected = await _protocolHandler!.connect(device);

        if (protocolConnected) {
          debugPrint('✅ [BLE协议] DYJV2设备协议初始化成功');

          // 监听协议消息
          _protocolHandler!.messageStream.listen((messageData) {
            debugPrint('📨 [BLE协议] 收到协议消息: ${messageData['cmd']}');
            _protocolMessageController.add(messageData);
          });

          // 监听协议状态
          _protocolHandler!.statusStream.listen((status) {
            debugPrint('📊 [BLE协议] 状态更新: $status');
            _statusController.add('[协议] $status');
          });

          msg = '🎉 已连接 ${device.name} (协议已启用)';
        } else {
          debugPrint('⚠️ [BLE协议] DYJV2设备协议初始化失败，使用普通连接');
          _protocolHandler = null;
          msg = '🎉 已连接 ${device.name} (普通模式)';
        }
      } else {
        _protocolHandler = null;
        msg = '🎉 已连接 ${device.name}';
      }

      _updateDeviceList();

      // 发送连接状态变化通知
      _connectionStateController.add(currentConnectedDeviceModel);

      debugPrint(msg);
      _statusController.add(msg);
      return true;
    } catch (e) {
      String msg = '💥 连接失败: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
      return false;
    }
  }

  /// 断开设备连接
  Future<void> disconnectDevice(BLEDeviceModel device) async {
    try {
      debugPrint('🔌 准备断开设备: ${device.name}');

      // 先断开协议连接
      if (_protocolHandler != null && _protocolHandler!.isConnected) {
        debugPrint('🔧 [BLE协议] 断开协议连接...');
        await _protocolHandler!.disconnect();
        _protocolHandler = null;
        debugPrint('✅ [BLE协议] 协议连接已断开');
      }

      if (device.device == null) {
        debugPrint('⚠️ 设备信息为空，无需断开');
        return;
      }

      await device.device!.disconnect();

      // 检查是否是当前连接的设备
      if (_currentConnectedDevice?.remoteId.str == device.device!.remoteId.str) {
        _currentConnectedDevice = null;
        debugPrint('✅ 已清除当前连接设备记录');
      }

      debugPrint('✅ 设备断开成功: ${device.name}');
      _updateDeviceList();

      // 发送连接状态变化通知
      _connectionStateController.add(null);

      String msg = '👋 已断开 ${device.name}';
      debugPrint(msg);
      _statusController.add(msg);
    } catch (e) {
      String msg = '💥 断开连接失败: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
    }
  }

  /// 获取已连接设备列表
  Future<List<BluetoothDevice>> getConnectedDevices() async {
    try {
      debugPrint('📋 获取已连接设备列表...');
      List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;

      // 同步本地连接状态
      if (devices.isNotEmpty) {
        _currentConnectedDevice = devices.first;
        debugPrint('✅ 发现已连接设备: ${_currentConnectedDevice!.name}');
        // 发送连接状态变化通知
        _connectionStateController.add(currentConnectedDeviceModel);
      } else {
        if (_currentConnectedDevice != null) {
          debugPrint('⚠️ 本地有连接记录但系统显示无连接，清除本地记录');
          _currentConnectedDevice = null;
          // 发送连接状态变化通知
          _connectionStateController.add(null);
        }
      }

      debugPrint('✅ 当前已连接设备数量: ${devices.length}');
      for (var device in devices) {
        debugPrint('  - ${device.name} (${device.remoteId.str})');
      }
      return devices;
    } catch (e) {
      String msg = '💥 获取连接设备失败: ${e.toString()}';
      debugPrint(msg);
      _statusController.add(msg);
      return [];
    }
  }

  /// 获取蓝牙状态
  Future<BluetoothAdapterState> getBluetoothState() async {
    try {
      debugPrint('🔍 检查蓝牙适配器状态...');
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      String stateStr = state.toString().split('.').last;
      debugPrint('📱 当前蓝牙状态: $stateStr');
      return state;
    } catch (e) {
      debugPrint('💥 获取蓝牙状态失败: ${e.toString()}');
      return BluetoothAdapterState.unavailable;
    }
  }

  /// 请求开启蓝牙（仅支持Android）
  Future<void> turnOnBluetooth() async {
    if (Platform.isAndroid) {
      try {
        debugPrint('📱 尝试开启Android蓝牙...');
        await FlutterBluePlus.turnOn();
        debugPrint('✅ 蓝牙开启请求已发送');
      } catch (e) {
        String msg = '💥 开启蓝牙失败: ${e.toString()}';
        debugPrint(msg);
        _statusController.add(msg);
      }
    } else {
      debugPrint('⚠️ 当前平台不支持自动开启蓝牙功能');
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
      debugPrint('🚫 设备名称过短: "$deviceName"');
      return true;
    }

    // 检查是否为MAC地址格式（包含冒号）
    if (name.contains(':')) {
      debugPrint('🚫 疑似MAC地址格式: "$deviceName"');
      return true;
    }

    // 检查是否为纯十六进制字符
    RegExp hexPattern = RegExp(r'^[0-9a-f]+$', caseSensitive: false);
    if (hexPattern.hasMatch(name) && name.length <= 12) {
      debugPrint('🚫 疑似十六进制序列号: "$deviceName"');
      return true;
    }

    // 检查是否包含位置相关的关键词
    List<String> locationKeywords = [
      'location', 'tracker', 'tag', 'beacon', 'sensor',
      'tile', 'chipolo', 'airtag', 'finder', 'trackr',
      'smarttag', 'galaxy tag', 'find my'
    ];

    for (String keyword in locationKeywords) {
      if (name.contains(keyword)) {
        debugPrint('🚫 包含位置追踪关键词 "$keyword": "$deviceName"');
        return true;
      }
    }

    // 检查是否为常见设备类型但名称看起来是序列号
    if (RegExp(r'^[a-z0-9]{8,}$').hasMatch(name)) {
      debugPrint('🚫 疑似设备序列号: "$deviceName"');
      return true;
    }

    return false;
  }

  /// 检查设备是否已连接
  bool isDeviceConnected(String deviceId) {
    return _currentConnectedDevice?.remoteId.str == deviceId;
  }

  /// 获取当前连接设备的ID
  String? get currentConnectedDeviceId => _currentConnectedDevice?.remoteId.str;

  /// 发送协议消息 (仅对DYJV2设备有效)
  Future<bool> sendProtocolMessage(String cmd, {Map<String, dynamic>? jsonData}) async {
    if (_protocolHandler == null || !_protocolHandler!.isConnected) {
      debugPrint('❌ [BLE协议] 协议未连接，无法发送消息');
      return false;
    }

    return await _protocolHandler!.sendMessage(cmd, jsonData: jsonData);
  }

  /// 获取协议连接状态
  bool get isProtocolConnected => _protocolHandler?.isConnected ?? false;

  /// 获取协议状态描述
  String get protocolStatus => _protocolHandler?.connectionStatus ?? '未初始化';

  /// 获取当前MTU大小
  int get protocolMtu => _protocolHandler?.currentMtu ?? 20;

  /// 处理请求的通用方法
  Future<Map<String, dynamic>?> handleRequest(String method, Map<String, dynamic> params) async {
    debugPrint('🔧 [BLE服务] 处理请求: $method, 参数: $params');

    try {
      // 检查是否有连接的设备
      if (_currentConnectedDevice == null) {
        debugPrint('❌ [BLE服务] 没有连接的设备');
        return {
          'success': false,
          'message': '没有连接的BLE设备',
          'method': method,
          'params': params,
          'data': null
        };
      }

      // 检查协议是否连接（仅对DYJV2设备需要）
      if (_currentConnectedDevice != null) {
        // 通过设备名称判断是否为DYJV2设备
        String deviceName = _currentConnectedDevice!.name;
        if (deviceName.startsWith('DYJV2_') && _protocolHandler == null) {
          debugPrint('❌ [BLE服务] DYJV2设备但协议未连接');
          return {
            'success': false,
            'message': 'DYJV2设备协议未连接',
            'method': method,
            'params': params,
            'data': null
          };
        }
      }

      if (_protocolHandler == null || !_protocolHandler!.isConnected) {
        return {
          'success': false,
          'message': '协议未连接，无法发送命令',
          'method': method,
          'params': params,
          'data': null
        };
      }

      // 发送命令
      bool success = await _protocolHandler!.sendMessage(method, jsonData: params);
      if (!success) {
        return {
          'success': false,
          'message': '发送命令失败: $method',
          'method': method,
          'params': params,
          'data': null
        };
      }

      // 等待设备响应
      debugPrint('⏳ [BLE服务] 等待设备响应...');

      // 订阅消息流以获取响应
      Map<String, dynamic>? response;
      StreamSubscription? subscription;

      final completer = Completer<Map<String, dynamic>?>();

      subscription = _protocolHandler!.messageStream.listen((messageData) {
        debugPrint('📨 [BLE服务] 收到响应: $messageData');
        debugPrint('🔍 [BLE服务] 检查匹配: 期望cmd="$method", 实际cmd="${messageData['cmd']}"');

        // 检查是否是对应方法的响应
        if (messageData['cmd'] == method) {
          debugPrint('✅ [BLE服务] 响应匹配成功!');
          response = messageData;
          if (!completer.isCompleted) {
            completer.complete(response);
          }
        } else {
          debugPrint('❌ [BLE服务] 响应不匹配，继续等待...');
        }
      });

      // 等待响应，超时5秒
      try {
        response = await completer.future.timeout(Duration(seconds: 5));
        subscription?.cancel();

        return {
          'success': true,
          'message': '收到设备响应',
          'method': method,
          'params': params,
          'data': response?['json']
        };
      } catch (e) {
        subscription?.cancel();
        return {
          'success': false,
          'message': '等待响应超时',
          'method': method,
          'params': params,
          'data': null
        };
      }
    } catch (e) {
      debugPrint('💥 [BLE服务] 处理请求失败: $e');
      return {
        'success': false,
        'message': '处理请求失败: $e',
        'method': method,
        'params': params,
        'data': null
      };
    }
  }

  /// 清理资源
  void dispose() {
    debugPrint('🧹 开始清理BLE服务资源...');

    // 断开协议连接
    if (_protocolHandler != null) {
      _protocolHandler!.dispose();
      _protocolHandler = null;
    }

    stopScan();
    _isScanningController.close();
    _devicesController.close();
    _statusController.close();
    _protocolMessageController.close();
    _connectionStateController.close();

    debugPrint('✅ BLE服务资源清理完成');
  }
}