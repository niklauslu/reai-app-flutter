import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../services/app_permission_service.dart';

/// 权限状态横幅组件
/// 显示在应用顶部，提示用户权限状态
class PermissionStatusBanner extends StatefulWidget {
  final VoidCallback? onSettingsTap;
  final bool showNetworkWarning;
  final bool showBluetoothWarning;

  const PermissionStatusBanner({
    super.key,
    this.onSettingsTap,
    this.showNetworkWarning = false,
    this.showBluetoothWarning = false,
  });

  @override
  State<PermissionStatusBanner> createState() => _PermissionStatusBannerState();
}

class _PermissionStatusBannerState extends State<PermissionStatusBanner> {
  final AppPermissionService _permissionService = AppPermissionService();
  Map<String, dynamic>? _permissionSummary;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final summary = await _permissionService.getPermissionSummary();
    if (mounted) {
      setState(() {
        _permissionSummary = summary;
      });
    }
  }

  bool _hasPermissionIssues() {
    // 直接使用外部传入的警告状态，不进行内部检测
    return widget.showNetworkWarning || widget.showBluetoothWarning;
  }

  List<Widget> _getPermissionWarnings() {
    List<Widget> warnings = [];

    if (widget.showNetworkWarning) {
      warnings.add(_buildNetworkWarning());
    }

    if (widget.showBluetoothWarning) {
      warnings.add(_buildBluetoothWarning());
    }

    return warnings;
  }

  Widget _buildNetworkWarning() {
    String message = Platform.isIOS
        ? '本地网络权限未设置，请选择"无线局域网+蜂窝网络"以确保连接稳定'
        : '网络权限请求失败，请检查应用权限设置';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _permissionService.showPermissionSettingsTip(context);
              widget.onSettingsTap?.call();
            },
            child: Text(
              '去设置',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothWarning() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.blue.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '蓝牙权限未授予，硬件设备功能将受限',
              style: TextStyle(
                color: Colors.blue[800],
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _permissionService.showPermissionSettingsTip(context);
              widget.onSettingsTap?.call();
            },
            child: Text(
              '去设置',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermissionIssues()) {
      return SizedBox.shrink();
    }

    final warnings = _getPermissionWarnings();

    return Column(
      children: warnings,
    );
  }
}

/// 权限状态指示器组件（小图标）
class PermissionStatusIndicator extends StatefulWidget {
  final double iconSize;
  final bool showLabels;

  const PermissionStatusIndicator({
    super.key,
    this.iconSize = 24,
    this.showLabels = false,
  });

  @override
  State<PermissionStatusIndicator> createState() => _PermissionStatusIndicatorState();
}

class _PermissionStatusIndicatorState extends State<PermissionStatusIndicator> {
  final AppPermissionService _permissionService = AppPermissionService();
  Map<String, dynamic>? _permissionSummary;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final summary = await _permissionService.getPermissionSummary();
    if (mounted) {
      setState(() {
        _permissionSummary = summary;
      });
    }
  }

  /// 获取蓝牙权限状态
  bool _getBluetoothStatus() {
    if (_permissionSummary == null) return false;

    if (Platform.isIOS) {
      // iOS需要检查蓝牙、位置权限
      return _permissionSummary!['bluetooth'] == true &&
             _permissionSummary!['location'] == true;
    } else {
      // Android需要检查所有蓝牙相关权限
      return _permissionSummary!['bluetooth'] == true &&
             _permissionSummary!['bluetoothScan'] == true &&
             _permissionSummary!['bluetoothConnect'] == true &&
             _permissionSummary!['location'] == true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionSummary == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.iconSize,
            height: widget.iconSize,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 网络状态指示器（iOS）
        if (widget.showLabels) ...[
          Icon(Icons.wifi,
                color: Colors.green,
                size: widget.iconSize),
          SizedBox(width: 4),
          Text('网络', style: TextStyle(fontSize: 12)),
          SizedBox(width: 8),
        ],

        // 蓝牙状态指示器
        _buildStatusIcon(
          icon: Icons.bluetooth,
          status: _getBluetoothStatus(),
          label: '蓝牙',
        ),
      ],
    );
  }

  Widget _buildStatusIcon({
    required IconData icon,
    required bool status,
    String? label,
  }) {
    Color color = status ? Colors.green : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: widget.iconSize),
        if (widget.showLabels && label != null) ...[
          SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: color,
          )),
          SizedBox(width: 8),
        ],
      ],
    );
  }
}