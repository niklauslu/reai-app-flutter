import 'package:flutter/material.dart';
import '../mqtt/mqtt_service.dart';
import '../mqtt/models/mqtt_message.dart';

/// MQTT连接状态图标组件
class MQTTStatusIcon extends StatefulWidget {
  final double size;
  final bool showText;

  const MQTTStatusIcon({
    super.key,
    this.size = 24.0,
    this.showText = false,
  });

  @override
  State<MQTTStatusIcon> createState() => _MQTTStatusIconState();
}

class _MQTTStatusIconState extends State<MQTTStatusIcon> {
  MQTTConnectionStatus _status = MQTTConnectionStatus.disconnected;
  final MQTTService _mqttService = MQTTService();

  @override
  void initState() {
    super.initState();
    _initMQTTListener();
  }

  void _initMQTTListener() {
    // 监听MQTT状态变化
    _mqttService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    });

    // 如果还没有连接，尝试连接
    if (_mqttService.currentStatus == MQTTConnectionStatus.disconnected) {
      _mqttService.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(),
        if (widget.showText) ...[
          const SizedBox(width: 8),
          _buildStatusText(),
        ],
      ],
    );
  }

  Widget _buildStatusIcon() {
    IconData iconData;
    Color iconColor;
    double? iconSize;

    switch (_status) {
      case MQTTConnectionStatus.connected:
        iconData = Icons.wifi;
        iconColor = Colors.green;
        iconSize = widget.size;
        break;
      case MQTTConnectionStatus.connecting:
        iconData = Icons.wifi_tethering;
        iconColor = Colors.orange;
        iconSize = widget.size * 0.9;
        break;
      case MQTTConnectionStatus.disconnected:
        iconData = Icons.wifi_off;
        iconColor = Colors.grey;
        iconSize = widget.size * 0.8;
        break;
      case MQTTConnectionStatus.error:
        iconData = Icons.error;
        iconColor = Colors.red;
        iconSize = widget.size;
        break;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: iconSize,
    );
  }

  Widget _buildStatusText() {
    String statusText;
    Color textColor;

    switch (_status) {
      case MQTTConnectionStatus.connected:
        statusText = '已连接';
        textColor = Colors.green;
        break;
      case MQTTConnectionStatus.connecting:
        statusText = '连接中';
        textColor = Colors.orange;
        break;
      case MQTTConnectionStatus.disconnected:
        statusText = '未连接';
        textColor = Colors.grey;
        break;
      case MQTTConnectionStatus.error:
        statusText = '连接错误';
        textColor = Colors.red;
        break;
    }

    return Text(
      statusText,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// 带点击功能的状态图标
class MQTTStatusIconWithAction extends StatelessWidget {
  final double size;
  final bool showText;
  final VoidCallback? onTap;

  const MQTTStatusIconWithAction({
    super.key,
    this.size = 24.0,
    this.showText = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? _showMQTTStatusDialog,
      child: MQTTStatusIcon(
        size: size,
        showText: showText,
      ),
    );
  }

  void _showMQTTStatusDialog() {
    // 这里可以实现显示详细MQTT状态的对话框
    // 暂时简单显示一个说明
    print('显示MQTT状态详情');
  }
}