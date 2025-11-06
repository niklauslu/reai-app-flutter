import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../ble/ble_device_model.dart';
import '../ble/ble_service.dart';
import '../components/buttons/app_buttons.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../constants/dimensions.dart';

/// BLE设备详情页面
class BLEDeviceDetailPage extends StatefulWidget {
  final BLEDeviceModel device;

  const BLEDeviceDetailPage({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  State<BLEDeviceDetailPage> createState() => _BLEDeviceDetailPageState();
}

class _BLEDeviceDetailPageState extends State<BLEDeviceDetailPage> {
  bool _isConnecting = false;
  bool _isConnected = false;
  String _connectionStatus = '未连接';
  final BLEService _bleService = BLEService();
  StreamSubscription<Map<String, dynamic>>? _protocolSubscription;
  StreamSubscription<String>? _statusSubscription;
  final List<Map<String, dynamic>> _protocolMessages = [];
  final List<String> _statusMessages = [];

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _setupProtocolListener();
  }

  @override
  void dispose() {
    _protocolSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  /// 设置协议监听器
  void _setupProtocolListener() {
    // 监听协议消息
    _protocolSubscription = _bleService.protocolMessageStream.listen((messageData) {
      setState(() {
        _protocolMessages.add(messageData);
        // 最多保留50条消息
        if (_protocolMessages.length > 50) {
          _protocolMessages.removeAt(0);
        }
      });
    });

    // 监听状态消息
    _statusSubscription = _bleService.statusStream.listen((status) {
      setState(() {
        _statusMessages.add(status);
        // 最多保留30条状态消息
        if (_statusMessages.length > 30) {
          _statusMessages.removeAt(0);
        }
        // 更新连接状态
        _checkConnectionStatus();
      });
    });
  }

  /// 检查设备连接状态
  void _checkConnectionStatus() {
    // 检查当前设备是否已连接（通过BLE服务检查）
    setState(() {
      _isConnected = _bleService.isDeviceConnected(widget.device.id);

      // 根据设备类型和协议状态更新连接状态描述
      if (_isConnected) {
        if (widget.device.type == DeviceType.dyjV2 && _bleService.isProtocolConnected) {
          _connectionStatus = '已连接 (协议模式)';
        } else {
          _connectionStatus = '已连接 (普通模式)';
        }
      } else {
        _connectionStatus = '未连接';
      }
    });
  }

  /// 连接/断开设备
  Future<void> _toggleConnection() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      if (_isConnected) {
        // 断开连接
        await _bleService.disconnectDevice(widget.device);
        setState(() {
          _isConnected = false;
          _connectionStatus = '已断开';
        });
        _showSnackBar('设备已断开连接', Colors.green);
      } else {
        // 连接设备
        bool success = await _bleService.connectToDevice(widget.device);
        setState(() {
          _isConnected = success;
          _connectionStatus = success ? '已连接' : '连接失败';
        });
        if (success) {
          _showSnackBar('设备连接成功', Colors.green);
        } else {
          _showSnackBar('设备连接失败', Colors.red);
        }
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _connectionStatus = '连接异常';
      });
      _showSnackBar('操作失败: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// 显示提示消息
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 获取信号强度描述
  String _getSignalStrengthDescription(int rssi) {
    if (rssi >= -50) return '信号极好';
    if (rssi >= -60) return '信号良好';
    if (rssi >= -70) return '信号一般';
    return '信号较弱';
  }

  /// 获取信号强度颜色
  Color _getSignalStrengthColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lime;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '设备详情',
          style: AppTextStyles.headline3.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 可滚动内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 设备基本信息卡片
                  _buildDeviceInfoCard(),
                  const SizedBox(height: AppDimensions.lg),

                  // 设备详细信息卡片（包含连接状态、MAC地址、信号强度）
                  _buildDeviceStatusCard(),
                  const SizedBox(height: AppDimensions.lg),

                  // 协议通信区域（仅DYJV2设备显示）
                  _buildProtocolSection(),
                ],
              ),
            ),
          ),

          // 底部操作区域（固定位置）
          Container(
            padding: const EdgeInsets.all(AppDimensions.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 连接操作按钮
                _buildConnectionButton(),
                const SizedBox(height: AppDimensions.sm),

                // 操作提示文字
                _buildOperationHint(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// �建设备基本信息卡片
  Widget _buildDeviceInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDeviceIcon(),
                  color: _getDeviceColor(),
                  size: 48,
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.name,
                        style: AppTextStyles.headline2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDeviceTypeDescription(),
                        style: AppTextStyles.bodyText2.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设备状态卡片（包含连接状态、MAC地址、信号强度）
  Widget _buildDeviceStatusCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  '设备状态',
                  style: AppTextStyles.headline3.copyWith(
                    color: AppColors.deepBlack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),

            // 连接状态
            _buildStatusItem(
              icon: _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              iconColor: _isConnected ? Colors.green : Colors.grey,
              label: '连接状态',
              value: _connectionStatus,
              valueColor: _isConnected ? Colors.green : Colors.grey,
              showBadge: _isConnected,
              badgeText: '当前设备',
              badgeColor: AppColors.primaryGreen,
            ),

            const Divider(height: AppDimensions.lg),

            // MAC地址
            _buildStatusItem(
              icon: Icons.perm_device_info,
              iconColor: AppColors.primaryGreen,
              label: 'MAC地址',
              value: widget.device.displayId,
              valueColor: AppColors.deepBlack,
            ),

            const Divider(height: AppDimensions.lg),

            // 信号强度
            _buildSignalStrengthItem(),
          ],
        ),
      ),
    );
  }

  /// 构建状态项组件
  Widget _buildStatusItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    bool showBadge = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.xs),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    value,
                    style: AppTextStyles.bodyText1.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showBadge && badgeText != null) ...[
                    const SizedBox(width: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText!,
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
    );
  }

  /// 构建信号强度项组件
  Widget _buildSignalStrengthItem() {
    Color signalColor = _getSignalStrengthColor(widget.device.rssi);
    String signalDescription = _getSignalStrengthDescription(widget.device.rssi);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.xs),
          decoration: BoxDecoration(
            color: signalColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.signal_cellular_alt,
            color: signalColor,
            size: 20,
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '信号强度',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '${widget.device.rssi} dBm',
                    style: AppTextStyles.bodyText1.copyWith(
                      color: signalColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  // 信号强度条
                  ...List.generate(4, (index) {
                    int threshold = -50 - (index * 20);
                    bool isActive = widget.device.rssi >= threshold;
                    return Container(
                      width: 4,
                      height: 8 + (index * 4),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: isActive ? signalColor : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  const SizedBox(width: AppDimensions.sm),
                  Text(
                    signalDescription,
                    style: AppTextStyles.caption.copyWith(
                      color: signalColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建操作提示文字
  Widget _buildOperationHint() {
    if (_isConnecting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Flexible(
              child: Text(
                '正在连接设备，请稍候...',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: AppDimensions.sm),
            Flexible(
              child: Text(
                '设备已连接，可以进行数据传输',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: AppDimensions.sm),
          Flexible(
            child: Text(
              '点击连接按钮开始配对设备',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建连接按钮
  Widget _buildConnectionButton() {
    return SizedBox(
      width: double.infinity,
      child: _isConnecting
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            )
          : ElevatedButton(
              onPressed: _toggleConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? Colors.red : AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                  vertical: AppDimensions.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                ),
                elevation: 0,
              ),
              child: Text(
                _isConnected ? '断开连接' : '连接设备',
                style: AppTextStyles.bodyText1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon() {
    switch (widget.device.type) {
      case DeviceType.dyjV1:
        return Icons.device_hub;
      case DeviceType.dyjV2:
        return Icons.memory;
      case DeviceType.dyjCard:
        return Icons.credit_card;
      case DeviceType.reaiGlass:
        return Icons.visibility;
      default:
        return Icons.bluetooth;
    }
  }

  /// 获取设备颜色
  Color _getDeviceColor() {
    switch (widget.device.type) {
      case DeviceType.dyjV1:
        return Colors.blue;
      case DeviceType.dyjV2:
        return Colors.purple;
      case DeviceType.dyjCard:
        return Colors.orange;
      case DeviceType.reaiGlass:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// 获取设备类型描述
  String _getDeviceTypeDescription() {
    switch (widget.device.type) {
      case DeviceType.dyjV1:
        return 'DYJ 第一代设备';
      case DeviceType.dyjV2:
        return 'DYJ 第二代设备';
      case DeviceType.dyjCard:
        return 'DYJ Card 设备';
      case DeviceType.reaiGlass:
        return 'ReAI Glass 设备';
      default:
        return '其他BLE设备';
    }
  }

  /// 发送协议消息
  Future<void> _sendProtocolMessage(String cmd, {Map<String, dynamic>? jsonData}) async {
    bool success = await _bleService.sendProtocolMessage(cmd, jsonData: jsonData);
    if (success) {
      _showSnackBar('消息发送成功: $cmd', Colors.green);
    } else {
      _showSnackBar('消息发送失败: $cmd', Colors.red);
    }
  }

  /// 获取设备基础信息
  Future<void> _getBaseInfo() async {
    await _sendProtocolMessage('BASE_INFO');
  }

  /// 同步时间
  Future<void> _syncTime() async {
    int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _sendProtocolMessage('SYNC_TIME', jsonData: {'timestamp': timestamp});
  }

  /// 清空协议消息
  void _clearProtocolMessages() {
    setState(() {
      _protocolMessages.clear();
    });
  }

  /// 构建协议信息显示
  Widget _buildProtocolInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '协议信息',
            style: AppTextStyles.bodyText2.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('状态', _bleService.protocolStatus),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _buildInfoItem('MTU', '${_bleService.protocolMtu} bytes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyText2.copyWith(
            color: AppColors.deepBlack,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 构建协议通信区域 (仅DYJV2设备显示)
  Widget _buildProtocolSection() {
    // 只有DYJV2设备才显示协议通信功能
    if (widget.device.type != DeviceType.dyjV2) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和状态
            Row(
              children: [
                Icon(
                  Icons.chat,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  '协议通信',
                  style: AppTextStyles.headline3.copyWith(
                    color: AppColors.deepBlack,
                  ),
                ),
                const Spacer(),
                if (_bleService.isProtocolConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '已连接',
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),

            // 协议信息
            _buildProtocolInfo(),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected && _bleService.isProtocolConnected ? _getBaseInfo : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                      ),
                    ),
                    child: Text(
                      '获取基础信息',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected && _bleService.isProtocolConnected ? _syncTime : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                      ),
                    ),
                    child: Text(
                      '同步时间',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),

            // 状态日志和消息记录
            Row(
              children: [
                Text(
                  '通信记录',
                  style: AppTextStyles.bodyText2.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _protocolMessages.clear();
                      _statusMessages.clear();
                    });
                  },
                  child: Text(
                    '清空全部',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),

            // 通信记录标签页
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: AppColors.primaryGreen,
                    tabs: [
                      Tab(
                        text: '协议消息 (${_protocolMessages.length})',
                      ),
                      Tab(
                        text: '状态日志 (${_statusMessages.length})',
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 250,
                    child: TabBarView(
                      children: [
                        // 协议消息列表
                        _buildProtocolMessagesList(),
                        // 状态日志列表
                        _buildStatusMessagesList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建协议消息列表
  Widget _buildProtocolMessagesList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: _protocolMessages.isEmpty
          ? Center(
              child: Text(
                '暂无协议消息',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.sm),
              itemCount: _protocolMessages.length,
              reverse: true, // 最新消息在底部
              itemBuilder: (context, index) {
                final message = _protocolMessages[index];
                return _buildMessageItem(message);
              },
            ),
    );
  }

  /// 构建状态消息列表
  Widget _buildStatusMessagesList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: _statusMessages.isEmpty
          ? Center(
              child: Text(
                '暂无状态日志',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.sm),
              itemCount: _statusMessages.length,
              reverse: true, // 最新日志在底部
              itemBuilder: (context, index) {
                final status = _statusMessages[index];
                return _buildStatusLogItem(status);
              },
            ),
    );
  }

  /// 构建状态日志项
  Widget _buildStatusLogItem(String status) {
    // 判断是否为错误状态
    bool isError = status.contains('❌') || status.contains('💥') || status.contains('⚠️');

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.xs),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: isError ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isError ? Colors.red[200]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 16,
            color: isError ? Colors.red[600] : Colors.grey[600],
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              status,
              style: AppTextStyles.caption.copyWith(
                color: isError ? Colors.red[800] : AppColors.deepBlack,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建消息项
  Widget _buildMessageItem(Map<String, dynamic> message) {
    String cmd = message['cmd'] ?? 'UNKNOWN';
    Map<String, dynamic>? jsonData = message['json'];
    int timestamp = message['timestamp'] ?? 0;

    DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.xs),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cmd,
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                timeStr,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          if (jsonData != null) ...[
            const SizedBox(height: AppDimensions.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.xs),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                jsonEncode(jsonData),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.deepBlack,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}