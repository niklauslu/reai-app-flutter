import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_device_model.dart';

/// BLE协议处理器类 - 简化版
/// 负责处理DYJV2设备的CMD:JSON格式协议通信
class BLEProtocolHandler {
  // 协议配置
  final String serviceUuid;
  final String writeCharacteristicUuid;
  final String readCharacteristicUuid;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;

  // 消息缓存和数据记录
  final Map<String, String> _messageBuffers = {};
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 连接状态
  bool _isConnected = false;
  int _currentMtu = 20; // 默认MTU大小
  String _connectionStatus = '未连接';
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  BLEProtocolHandler({
    this.serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    this.writeCharacteristicUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    this.readCharacteristicUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  });

  /// 获取消息流
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// 获取状态流
  Stream<String> get statusStream => _statusController.stream;

  /// 获取连接状态
  bool get isConnected => _isConnected;

  /// 获取当前MTU大小
  int get currentMtu => _currentMtu;

  /// 获取连接状态描述
  String get connectionStatus => _connectionStatus;

  /// 连接设备并初始化协议
  Future<bool> connect(BLEDeviceModel device) async {
    try {
      _updateStatus('🔌 开始连接设备: ${device.name}');

      if (device.device == null) {
        _updateStatus('❌ 设备信息为空');
        return false;
      }

      _device = device.device!;

      // 连接设备
      await _device!.connect();
      _updateStatus('✅ 设备连接成功');

      // 协商MTU
      await _negotiateMtu();

      // 发现服务
      _updateStatus('🔍 正在发现服务...');
      List<BluetoothService> services = await _device!.discoverServices();
      _updateStatus('🔍 发现 ${services.length} 个服务');

      // 查找目标服务
      _updateStatus('🔍 正在查找目标服务: $serviceUuid');
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUuid) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        _updateStatus('❌ 未找到目标服务: $serviceUuid');
        await disconnect();
        return false;
      }

      _updateStatus('✅ 找到目标服务: $serviceUuid');

      // 查找特征值
      _updateStatus('🔍 正在查找特征值...');
      for (BluetoothCharacteristic characteristic in targetService.characteristics) {
        String uuid = characteristic.uuid.toString();

        if (uuid == writeCharacteristicUuid) {
          _writeCharacteristic = characteristic;
          _updateStatus('✅ 找到写入特征值: $uuid');
        }

        if (uuid == readCharacteristicUuid) {
          _readCharacteristic = characteristic;
          _updateStatus('✅ 找到读取特征值: $uuid');

          // 订阅通知
          await characteristic.setNotifyValue(true);
          characteristic.value.listen(_handleIncomingData);
          _updateStatus('📡 已订阅读取特征值通知');
        }
      }

      if (_writeCharacteristic == null || _readCharacteristic == null) {
        _updateStatus('❌ 未找到必要的特征值');
        await disconnect();
        return false;
      }

      _isConnected = true;
      _updateStatus('🎉 协议初始化完成，可以进行数据通信');
      return true;

    } catch (e) {
      _updateStatus('💥 连接失败: $e');
      await disconnect();
      return false;
    }
  }

  /// 协商MTU
  Future<void> _negotiateMtu() async {
    try {
      _updateStatus('📡 正在协商MTU...');
      int mtu = await _device!.requestMtu(247);
      _currentMtu = mtu - 3; // 减去协议头开销
      _updateStatus('✅ MTU协商完成: $mtu (可用数据包大小: $_currentMtu)');
    } catch (e) {
      _currentMtu = 20; // 使用默认值
      _updateStatus('⚠️ MTU协商失败，使用默认大小: $_currentMtu');
    }
  }

  /// 更新状态
  void _updateStatus(String status) {
    _connectionStatus = status;
    debugPrint('🔧 [BLE协议] $status');
    _statusController.add(status);
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      _updateStatus('🔌 开始断开连接');

      _isConnected = false;

      // 取消订阅
      if (_readCharacteristic != null) {
        await _readCharacteristic!.setNotifyValue(false);
      }

      // 断开设备连接
      if (_device != null) {
        await _device!.disconnect();
      }

      // 清理资源
      _writeCharacteristic = null;
      _readCharacteristic = null;
      _device = null;
      _messageBuffers.clear();

      _updateStatus('✅ 断开连接完成');
    } catch (e) {
      _updateStatus('💥 断开连接异常: $e');
    }
  }

  /// 发送CMD:JSON格式消息
  Future<bool> sendMessage(String cmd, {Map<String, dynamic>? jsonData}) async {
    if (!_isConnected || _writeCharacteristic == null) {
      debugPrint('❌ [BLE协议] 设备未连接，无法发送消息');
      return false;
    }

    try {
      // 构建CMD:JSON格式消息
      String message = cmd;
      if (jsonData != null) {
        message += ':${jsonEncode(jsonData)}';
      }

      debugPrint('📤 [BLE协议] 发送消息: $message');

      // 发送数据
      List<int> bytes = utf8.encode(message + '\r\n');
      await _writeCharacteristic!.write(bytes);

      debugPrint('✅ [BLE协议] 消息发送成功');
      return true;
    } catch (e) {
      debugPrint('💥 [BLE协议] 发送消息失败: $e');
      return false;
    }
  }

  /// 处理接收到的数据
  void _handleIncomingData(List<int> data) {
    try {
      String dataStr = utf8.decode(data);
      String deviceId = _device?.remoteId.str ?? 'unknown';

      debugPrint('📥 [BLE协议] 收到数据: $dataStr');

      // 缓存数据
      if (_messageBuffers.containsKey(deviceId)) {
        _messageBuffers[deviceId] = _messageBuffers[deviceId]! + dataStr;
      } else {
        _messageBuffers[deviceId] = dataStr;
      }

      String buffer = _messageBuffers[deviceId]!;

      // 检查是否有完整的消息（以\r\n结尾）
      while (buffer.contains('\r\n')) {
        int endIndex = buffer.indexOf('\r\n');
        String messageStr = buffer.substring(0, endIndex);
        buffer = buffer.substring(endIndex + 2);

        // 解析CMD:JSON格式
        Map<String, dynamic> messageData = _parseMessage(messageStr);

        // 发送到流
        _messageController.add(messageData);

        debugPrint('✅ [BLE协议] 消息解析完成: CMD=${messageData['cmd']}, JSON=${messageData['json']}');
      }

      // 更新缓存
      if (buffer.isNotEmpty) {
        _messageBuffers[deviceId] = buffer;
      } else {
        _messageBuffers.remove(deviceId);
      }

    } catch (e) {
      debugPrint('💥 [BLE协议] 处理接收数据异常: $e');
    }
  }

  /// 解析CMD:JSON格式消息
  Map<String, dynamic> _parseMessage(String messageStr) {
    try {
      // 查找命令和JSON部分的分隔符
      int colonIndex = messageStr.indexOf(':');

      if (colonIndex == -1) {
        // 没有JSON部分，只有命令
        return {
          'cmd': messageStr.trim(),
          'json': null,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      }

      // 提取命令和JSON部分
      String cmd = messageStr.substring(0, colonIndex).trim();
      String jsonStr = messageStr.substring(colonIndex + 1).trim();

      // 解析JSON
      Map<String, dynamic>? jsonData;
      if (jsonStr.isNotEmpty) {
        try {
          jsonData = jsonDecode(jsonStr);
        } catch (e) {
          debugPrint('⚠️ [BLE协议] JSON解析失败: $e');
          jsonData = {'raw': jsonStr};
        }
      }

      return {
        'cmd': cmd,
        'json': jsonData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('❌ [BLE协议] 消息解析失败: $e');
      return {
        'cmd': 'ERROR',
        'json': {'error': e.toString(), 'raw': messageStr},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// 清理资源
  void dispose() {
    _updateStatus('🧹 清理资源');
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}