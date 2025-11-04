import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import '../ble/ble_service.dart';
import '../ble/ble_device_model.dart';
import '../components/buttons/app_buttons.dart';
import '../components/cards/standard_card.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../constants/dimensions.dart';

/// BLE设备列表页面
class BLEDeviceListPage extends StatefulWidget {
  const BLEDeviceListPage({Key? key}) : super(key: key);

  @override
  State<BLEDeviceListPage> createState() => _BLEDeviceListPageState();
}

class _BLEDeviceListPageState extends State<BLEDeviceListPage> {
  final BLEService _bleService = BLEService();
  List<BLEDeviceModel> _devices = [];
  bool _isScanning = false;
  String _statusMessage = '准备就绪';
  bool _isInitialized = false;

  // Stream subscriptions
  StreamSubscription? _scanningSubscription;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBLE();
    _setupListeners();
  }

  @override
  void dispose() {
    // 取消所有stream订阅
    _scanningSubscription?.cancel();
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();

    // 停止扫描
    _bleService.stopScan();
    super.dispose();
  }

  /// 初始化BLE
  Future<void> _initializeBLE() async {
    // 检查平台支持
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _statusMessage = '仅支持Android和iOS平台';
      });
      _showPlatformUnsupportedDialog();
      return;
    }

    setState(() {
      _statusMessage = '正在初始化BLE...';
    });

    // 请求权限
    bool hasPermissions = await _bleService.requestPermissions();
    if (!hasPermissions) {
      setState(() {
        _statusMessage = '权限获取失败';
      });
      _showPermissionDeniedDialog();
      return;
    }

    // 初始化BLE
    bool initialized = await _bleService.initialize();
    if (!initialized) {
      setState(() {
        _statusMessage = 'BLE初始化失败';
      });
      return;
    }

    setState(() {
      _isInitialized = true;
      _statusMessage = 'BLE初始化成功';
    });

    // 自动开始扫描
    _toggleScan();
  }

  /// 设置监听器
  void _setupListeners() {
    // 监听扫描状态
    _scanningSubscription = _bleService.isScanningStream.listen((scanning) {
      if (mounted) {
        setState(() {
          _isScanning = scanning;
        });
      }
    });

    // 监听设备列表
    _devicesSubscription = _bleService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });

    // 监听状态消息
    _statusSubscription = _bleService.statusStream.listen((message) {
      if (mounted) {
        setState(() {
          _statusMessage = message;
        });
      }
    });
  }

  /// 切换扫描状态
  Future<void> _toggleScan() async {
    if (!_isInitialized) {
      _initializeBLE();
      return;
    }

    if (_isScanning) {
      await _bleService.stopScan();
    } else {
      await _bleService.startScan(timeout: const Duration(seconds: 5));
    }
  }

  /// 连接设备
  Future<void> _connectToDevice(BLEDeviceModel device) async {
    if (device.isConnected) {
      // 如果已连接，则断开
      await _bleService.disconnectDevice(device);
    } else {
      // 如果未连接，则连接
      bool success = await _bleService.connectToDevice(device);
      if (success) {
        _showConnectionSuccessDialog(device);
      } else {
        _showConnectionFailedDialog(device);
      }
    }
  }

  /// 刷新设备列表
  Future<void> _refreshDevices() async {
    if (_isScanning) {
      await _bleService.stopScan();
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await _bleService.startScan(timeout: const Duration(seconds: 5));
  }

  /// 显示平台不支持对话框
  void _showPlatformUnsupportedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('平台不支持'),
        content: const Text('BLE功能仅支持Android和iOS平台。请在移动设备上使用此功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示权限被拒绝对话框
  void _showPermissionDeniedDialog() {
    String content = Platform.isAndroid
        ? '应用需要蓝牙和位置权限才能搜索和连接设备。请在设置中开启相关权限。'
        : '应用需要蓝牙权限才能搜索和连接设备。请在设置中开启相关权限。';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('权限需要'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeBLE(); // 重新尝试
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 显示连接成功对话框
  void _showConnectionSuccessDialog(BLEDeviceModel device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('连接成功'),
        content: Text('已成功连接到 ${device.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示连接失败对话框
  void _showConnectionFailedDialog(BLEDeviceModel device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('连接失败'),
        content: Text('无法连接到 ${device.name}，请确保设备在范围内并重试。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BLE设备搜索'),
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.deepBlack,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _toggleScan,
            tooltip: _isScanning ? '停止扫描' : '开始扫描',
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            color: AppColors.pureWhite,
            child: Row(
              children: [
                Icon(
                  _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                  color: _isScanning ? AppColors.primaryGreen : AppColors.gray600,
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: AppTextStyles.bodyText2.copyWith(
                      color: AppColors.gray700,
                    ),
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
                    ),
                  ),
              ],
            ),
          ),

          // 操作按钮
          if (_isInitialized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: _isScanning ? '停止扫描' : '开始扫描',
                      onPressed: _toggleScan,
                      isLoading: _isScanning,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  SecondaryButton(
                    text: '刷新',
                    icon: Icon(Icons.refresh, size: AppDimensions.iconSmall),
                    size: ButtonSize.medium, // 改为中等尺寸与主按钮一致
                    onPressed: _refreshDevices,
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppDimensions.sm),

          // 设备列表
          Expanded(
            child: _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  /// 构建设备列表
  Widget _buildDeviceList() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: AppDimensions.iconXLarge * 2,
              color: AppColors.gray300,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              '未发现设备',
              style: AppTextStyles.headline3,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              _isScanning ? '正在搜索设备...' : '点击扫描按钮开始搜索',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.gray600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  /// 构建设备卡片
  Widget _buildDeviceCard(BLEDeviceModel device) {
    return StandardCard(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      onTap: () => _connectToDevice(device),
      child: Row(
        children: [
          // 设备图标
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getDeviceColor(device.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
            ),
            child: Icon(
              _getDeviceIcon(device.type),
              size: AppDimensions.iconLarge,
              color: _getDeviceColor(device.type),
            ),
          ),
          const SizedBox(width: AppDimensions.md),

          // 设备信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.name,
                      style: AppTextStyles.headline4,
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    if (device.version != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getDeviceColor(device.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          device.version!,
                          style: AppTextStyles.overline.copyWith(
                            color: _getDeviceColor(device.type),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    ConnectionIndicator(isConnected: device.isConnected),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'MAC: ${device.id}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
                const SizedBox(height: AppDimensions.xs),
                Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: AppDimensions.iconSmall,
                      color: _getSignalColor(device.rssi),
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Text(
                      '${device.rssi} dBm • ${device.signalStrength}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.dyjV1:
      case DeviceType.dyjV2:
      case DeviceType.dyjCard:
        return Icons.developer_board;
      case DeviceType.reaiGlass:
        return Icons.visibility;
      case DeviceType.other:
        return Icons.bluetooth;
    }
  }

  /// 获取设备颜色
  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.dyjV1:
        return AppColors.primaryGreen;
      case DeviceType.dyjV2:
        return AppColors.mediumGreen;
      case DeviceType.dyjCard:
        return AppColors.infoBlue;
      case DeviceType.reaiGlass:
        return AppColors.warningYellow;
      case DeviceType.other:
        return AppColors.gray500;
    }
  }

  /// 获取信号强度颜色
  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return AppColors.primaryGreen;
    if (rssi >= -70) return AppColors.warningYellow;
    return AppColors.errorRed;
  }
}

/// 连接状态指示器
class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;

  const ConnectionIndicator({Key? key, required this.isConnected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? AppColors.primaryGreen : AppColors.gray300,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimensions.xs),
        Text(
          isConnected ? '已连接' : '未连接',
          style: AppTextStyles.caption.copyWith(
            color: isConnected ? AppColors.primaryGreen : AppColors.gray600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}