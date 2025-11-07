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
import '../services/app_permission_service.dart';
import 'ble_device_detail_page.dart';

/// BLE设备列表页面
class BLEDeviceListPage extends StatefulWidget {
  const BLEDeviceListPage({Key? key}) : super(key: key);

  @override
  State<BLEDeviceListPage> createState() => _BLEDeviceListPageState();
}

class _BLEDeviceListPageState extends State<BLEDeviceListPage> {
  final BLEService _bleService = BLEService();
  final AppPermissionService _permissionService = AppPermissionService();
  List<BLEDeviceModel> _devices = [];
  bool _isScanning = false;
  String _statusMessage = '准备就绪';
  bool _isInitialized = false;
  BLEDeviceModel? _currentConnectedDevice; // 当前连接的设备

  // Stream subscriptions
  StreamSubscription? _scanningSubscription;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();
    _clearDeviceList(); // 进入页面时先清空列表
    _setupListeners();

    // 自动初始化BLE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBLE();
    });

    // 监听蓝牙适配器状态变化
    _setupBluetoothStateListener();
  }

  @override
  void dispose() {
    // 取消所有stream订阅
    _scanningSubscription?.cancel();
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _bluetoothStateSubscription?.cancel();

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

    // 只检查权限状态，不主动请求权限
    Map<String, dynamic> permissionSummary = await _permissionService.getPermissionSummary();
    bool hasPermissions = _checkPermissionsFromSummary(permissionSummary);

    if (!hasPermissions) {
      setState(() {
        _statusMessage = '蓝牙权限未授予，请检查设置';
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
  }

  /// 从权限摘要检查权限状态（不请求权限）
  bool _checkPermissionsFromSummary(Map<String, dynamic> summary) {
    if (Platform.isIOS) {
      // iOS需要蓝牙和位置权限
      return summary['bluetooth'] == true && summary['location'] == true;
    } else {
      // Android需要蓝牙扫描、连接和位置权限
      return summary['bluetooth'] == true &&
             summary['bluetoothScan'] == true &&
             summary['bluetoothConnect'] == true &&
             summary['location'] == true;
    }
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

    // 监听连接状态变化
    _connectionStateSubscription = _bleService.connectionStateStream.listen((connectedDevice) {
      if (mounted) {
        setState(() {
          _currentConnectedDevice = connectedDevice;
        });
      }
    });

    // 初始化时获取当前连接设备
    setState(() {
      _currentConnectedDevice = _bleService.currentConnectedDeviceModel;
    });
  }

  /// 清空设备列表
  void _clearDeviceList() {
    setState(() {
      _devices = [];
      _statusMessage = '准备就绪';
    });
    // 同时清空BLE服务中的设备列表
    _bleService.clearDevicesList();
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
      // 开始扫描前先清空列表
      _clearDeviceList();
      await _bleService.startScan(timeout: const Duration(seconds: 5));
    }
  }

  /// 导航到设备详情页
  Future<void> _navigateToDeviceDetail(BLEDeviceModel device) async {
    // 进入详情页前停止扫描以节省电量
    if (_isScanning) {
      await _bleService.stopScan();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BLEDeviceDetailPage(device: device),
      ),
    );

    // 返回后清空设备列表，不自动扫描
    _clearDeviceList();
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
              _requestPermissionsAndRetry(); // 请求权限并重试
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 请求权限并重试
  Future<void> _requestPermissionsAndRetry() async {
    setState(() {
      _statusMessage = '正在请求权限...';
    });

    // 只有在用户点击重试时才真正请求权限
    bool hasPermissions = await _permissionService.checkAllPermissions(context);

    if (hasPermissions) {
      // 权限获取成功，重新初始化BLE
      _initializeBLE();
    } else {
      // 权限获取失败，显示设置提示
      _permissionService.showPermissionSettingsTip(context);
    }
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

    // 获取已连接设备（优先显示BLE服务维护的当前连接设备）
    final connectedDevices = <BLEDeviceModel>[];
    final unconnectedDevices = <BLEDeviceModel>[];

    // 如果有当前连接设备，添加到已连接列表
    if (_currentConnectedDevice != null) {
      connectedDevices.add(_currentConnectedDevice!);
    }

    // 处理扫描到的设备
    for (final device in _devices) {
      // 跳过已经在连接列表中的设备
      if (connectedDevices.any((connected) => connected.id == device.id)) {
        continue;
      }

      // 检查设备连接状态（处理其他可能连接但不是当前连接的设备）
      if (_bleService.isDeviceConnected(device.id)) {
        connectedDevices.add(device);
      } else {
        unconnectedDevices.add(device);
      }
    }

    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: CustomScrollView(
        slivers: [
          // 已连接设备区域
          if (connectedDevices.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.md, AppDimensions.md, AppDimensions.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bluetooth_connected,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.xs),
                        Text(
                          '已连接设备',
                          style: AppTextStyles.headline3.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${connectedDevices.length}台',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      '点击设备可查看详情和管理连接',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 已连接设备列表
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final device = connectedDevices[index];
                  return Container(
                    margin: const EdgeInsets.fromLTRB(AppDimensions.md, 0, AppDimensions.md, AppDimensions.sm),
                    child: _buildConnectedDeviceCard(device),
                  );
                },
                childCount: connectedDevices.length,
              ),
            ),
            // 分割线
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.gray200,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                      child: Text(
                        '其他设备',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.gray200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 未连接设备列表
          if (unconnectedDevices.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final device = unconnectedDevices[index];
                  return Container(
                    margin: const EdgeInsets.fromLTRB(AppDimensions.md, 0, AppDimensions.md, AppDimensions.sm),
                    child: _buildDeviceCard(device),
                  );
                },
                childCount: unconnectedDevices.length,
              ),
            ),

          // 空状态
          if (connectedDevices.isEmpty && unconnectedDevices.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
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
              ),
            ),
        ],
      ),
    );
  }

  /// 构建已连接设备卡片（特殊样式）
  Widget _buildConnectedDeviceCard(BLEDeviceModel device) {
    return StandardCard(
      margin: EdgeInsets.zero, // 外部已经控制了margin
      onTap: () => _navigateToDeviceDetail(device),
      border: Border.all(
        color: AppColors.primaryGreen.withOpacity(0.3),
        width: 2,
      ),
      child: Row(
        children: [
          // 设备图标 - 带连接状态指示
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
              border: Border.all(color: AppColors.primaryGreen, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    _getDeviceIcon(device.type),
                    size: AppDimensions.iconLarge + 4,
                    color: AppColors.primaryGreen,
                  ),
                ),
                // 连接状态点
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
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
                      style: AppTextStyles.headline4.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    // 已连接标识
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '已连接',
                            style: AppTextStyles.overline.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 快捷操作按钮 - 只保留详情按钮
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _buildQuickAction(
                        icon: Icons.info_outline,
                        tooltip: '查看详情',
                        onTap: () => _navigateToDeviceDetail(device),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'MAC: ${device.displayId}',
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
                    const SizedBox(width: AppDimensions.sm),
                    // 协议状态（仅DYJV2设备）
                    if (device.type == DeviceType.dyjV2 && _bleService.isProtocolConnected) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat,
                              size: 10,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '协议',
                              style: AppTextStyles.overline.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建快捷操作按钮
  Widget _buildQuickAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDestructive
                ? Colors.red
                : AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  
  /// 显示成功消息
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 显示错误消息
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.errorRed,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 构建设备卡片
  Widget _buildDeviceCard(BLEDeviceModel device) {
    // 检查设备是否为当前连接的设备
    bool isConnected = _bleService.isDeviceConnected(device.id) && _currentConnectedDevice?.id != device.id;

    return StandardCard(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      onTap: () => _navigateToDeviceDetail(device),
      child: Row(
        children: [
          // 设备图标
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getDeviceColor(device.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
              border: isConnected
                  ? Border.all(color: AppColors.primaryGreen, width: 2)
                  : null,
            ),
            child: Icon(
              _getDeviceIcon(device.type),
              size: AppDimensions.iconLarge,
              color: isConnected ? AppColors.primaryGreen : _getDeviceColor(device.type),
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
                      style: AppTextStyles.headline4.copyWith(
                        color: isConnected ? AppColors.primaryGreen : null,
                        fontWeight: isConnected ? FontWeight.bold : null,
                      ),
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
                    // 连接状��标识
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? AppColors.primaryGreen.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isConnected
                              ? AppColors.primaryGreen
                              : Colors.grey,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bluetooth_connected,
                            size: 12,
                            color: isConnected
                                ? AppColors.primaryGreen
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isConnected ? '已连接' : '未连接',
                            style: AppTextStyles.overline.copyWith(
                              color: isConnected
                                  ? AppColors.primaryGreen
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'MAC: ${device.displayId}',
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
                    if (isConnected) ...[
                      const SizedBox(width: AppDimensions.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '当前设备',
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取设��图标
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

  /// 设置蓝牙状态监听器
  void _setupBluetoothStateListener() {
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (!mounted) return;

      debugPrint('📱 蓝牙状态变化: $state');

      switch (state) {
        case BluetoothAdapterState.on:
          // 蓝牙开启时，如果未初始化则尝试初始化
          if (!_isInitialized) {
            debugPrint('🟢 蓝牙已开启，尝试初始化BLE');
            _initializeBLE();
          } else {
            debugPrint('🟢 蓝牙已开启，BLE已初始化');
          }
          break;
        case BluetoothAdapterState.off:
          setState(() {
            _statusMessage = '蓝牙已关闭，请开启蓝牙后重试';
          });
          break;
        case BluetoothAdapterState.unavailable:
          setState(() {
            _statusMessage = '蓝牙不可用';
          });
          break;
        default:
          break;
      }
    });
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