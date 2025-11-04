import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'components/cards/standard_card.dart';
import 'components/buttons/app_buttons.dart';
import 'components/mqtt_status_icon.dart';
import 'pages/ble_device_list_page.dart';
import 'theme/colors.dart';
import 'theme/text_styles.dart';
import 'constants/dimensions.dart';
import 'mqtt/mqtt_service.dart';
import 'mqtt/models/mqtt_message.dart';
import 'services/device_id_service.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReAI Assistant',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'ReAI Assistant - 硬件AI助手'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final MQTTService _mqttService = MQTTService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  late StreamSubscription<MQTTTopicMessage> _messageSubscription;

  String? _deviceId;
  String? _formattedDeviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initDeviceId();
    _initMQTT();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageSubscription.cancel();
    super.dispose();
  }

  /// 初始化设备ID
  void _initDeviceId() async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final formattedId = _deviceIdService.formatDeviceIdForDisplay(deviceId);

      setState(() {
        _deviceId = deviceId;
        _formattedDeviceId = formattedId;
      });

      // 初始化MQTT连接
      _mqttService.connect();

      print('✅ 设备ID初始化完成: $_formattedDeviceId');
    } catch (e) {
      print('❌ 设备ID初始化失败: $e');
    }
  }

  /// 初始化MQTT
  void _initMQTT() {
    // 监听MQTT消息
    _messageSubscription = _mqttService.messageStream.listen((message) {
      print('收到MQTT消息: ${message.toString()}');
    });
  }

  /// 显示MQTT状态对话框
  void _showMQTTStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('MQTT连接状态'),
          content: StreamBuilder<MQTTConnectionStatus>(
            stream: _mqttService.statusStream,
            initialData: _mqttService.currentStatus,
            builder: (context, snapshot) {
              final status = snapshot.data ?? MQTTConnectionStatus.disconnected;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 设备ID显示
                  if (_deviceId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fingerprint,
                            size: 16,
                            color: AppColors.gray600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '设备ID: $_deviceId',
                              style: AppTextStyles.bodyText2.copyWith(
                                color: AppColors.gray600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 状态显示
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 操作按钮
                  if (status != MQTTConnectionStatus.connected &&
                      status != MQTTConnectionStatus.connecting)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mqttService.connect();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新连接'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (status == MQTTConnectionStatus.connected)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mqttService.disconnect();
                      },
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('断开连接'),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 获取状态图标
  IconData _getStatusIcon(MQTTConnectionStatus status) {
    switch (status) {
      case MQTTConnectionStatus.connected:
        return Icons.wifi;
      case MQTTConnectionStatus.connecting:
        return Icons.wifi_tethering;
      case MQTTConnectionStatus.disconnected:
        return Icons.wifi_off;
      case MQTTConnectionStatus.error:
        return Icons.error;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(MQTTConnectionStatus status) {
    switch (status) {
      case MQTTConnectionStatus.connected:
        return Colors.green;
      case MQTTConnectionStatus.connecting:
        return Colors.orange;
      case MQTTConnectionStatus.disconnected:
        return Colors.grey;
      case MQTTConnectionStatus.error:
        return Colors.red;
    }
  }

  /// 获取状态文本
  String _getStatusText(MQTTConnectionStatus status) {
    switch (status) {
      case MQTTConnectionStatus.connected:
        return '已连接到MQTT服务器';
      case MQTTConnectionStatus.connecting:
        return '正在连接...';
      case MQTTConnectionStatus.disconnected:
        return '未连接';
      case MQTTConnectionStatus.error:
        return '连接错误';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏
            _buildAppBar(),

            // 标签页内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildHardwareTab(),
                  _buildProjectsTab(),
                  _buildAIToolsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      // 底部导航栏
      bottomNavigationBar: _buildBottomNavigationBar(),
      // 浮动操作按钮
      floatingActionButton: const FloatingActionButtonWidget(
        icon: Icons.chat,
        tooltip: 'AI助手',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  /// 构建顶部标题栏
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          // Logo 和标题
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
                ),
                child: const Icon(
                  Icons.memory,
                  color: AppColors.onPrimary,
                  size: AppDimensions.iconMedium,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ReAI Assistant',
                    style: AppTextStyles.headline3,
                  ),
                  if (_formattedDeviceId != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          size: AppDimensions.iconSmall - 2,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '设备: $_formattedDeviceId',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.gray400,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Spacer(),
          // MQTT状态和操作按钮
          Row(
            children: [
              // MQTT连接状态图标
              MQTTStatusIconWithAction(
                size: 20,
                onTap: () => _showMQTTStatus(context),
              ),
              const SizedBox(width: AppDimensions.sm),
              IconButtonWidget(
                icon: Icons.search,
                tooltip: '搜索',
                onPressed: () {},
              ),
              IconButtonWidget(
                icon: Icons.notifications_outlined,
                tooltip: '通知',
                onPressed: () {},
              ),
              IconButtonWidget(
                icon: Icons.person_outline,
                tooltip: '个人中心',
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: AppDimensions.smallShadowBlur,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: AppColors.gray500,
        indicatorColor: AppColors.primaryGreen,
        labelStyle: AppTextStyles.caption,
        unselectedLabelStyle: AppTextStyles.caption,
        tabs: const [
          Tab(
            icon: Icon(Icons.dashboard_outlined),
            text: '首页',
          ),
          Tab(
            icon: Icon(Icons.hardware_outlined),
            text: '硬件',
          ),
          Tab(
            icon: Icon(Icons.folder_outlined),
            text: '项目',
          ),
          Tab(
            icon: Icon(Icons.psychology_outlined),
            text: 'AI工具',
          ),
        ],
      ),
    );
  }

  /// 构建首页标签页
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI助手对话区
          TitledCard(
            title: 'AI助手',
            subtitle: Text('有什么可以帮助您的吗？', style: AppTextStyles.bodyText2),
            action: IconButtonWidget(
              icon: Icons.expand_more,
              onPressed: () {},
            ),
            child: Column(
              children: [
                // 快捷回复建议
                Wrap(
                  spacing: AppDimensions.xs,
                  runSpacing: AppDimensions.xs,
                  children: [
                    _buildChip('帮我设计电路'),
                    _buildChip('代码生成'),
                    _buildChip('故障诊断'),
                    _buildChip('硬件选型'),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                // 输入框
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Text(
                          '请输入您的问题...',
                          style: AppTextStyles.bodyText2.copyWith(color: AppColors.gray400),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    IconButtonWidget(
                      icon: Icons.send,
                      tooltip: '发送',
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // 快捷功能入口
          Text(
            '快捷功能',
            style: AppTextStyles.headline3,
          ),
          const SizedBox(height: AppDimensions.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppDimensions.md,
            crossAxisSpacing: AppDimensions.md,
            childAspectRatio: 1.2,
            children: [
              FeatureCard(
                icon: Icons.code,
                title: '代码生成',
                description: 'AI智能生成硬件代码',
                onTap: () {},
              ),
              FeatureCard(
                icon: Icons.bug_report,
                title: '故障诊断',
                description: '快速定位硬件问题',
                onTap: () {},
              ),
              FeatureCard(
                icon: Icons.electrical_services,
                title: '电路设计',
                description: '智能电路辅助设计',
                onTap: () {},
              ),
              FeatureCard(
                icon: Icons.memory,
                title: '芯片选型',
                description: '硬件组件推荐',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // 最近项目
          Text(
            '最近项目',
            style: AppTextStyles.headline3,
          ),
          const SizedBox(height: AppDimensions.md),
          StandardCard(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
                ),
                child: const Icon(
                  Icons.developer_board,
                  color: AppColors.primaryGreen,
                ),
              ),
              title: Text('ESP32 智能家居', style: AppTextStyles.bodyText1),
              subtitle: Text('最后编辑: 2小时前', style: AppTextStyles.caption),
              trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建硬件标签页
  Widget _buildHardwareTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页面标题
          Text(
            '硬件产品',
            style: AppTextStyles.headline2,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            '探索我们的智能硬件产品线',
            style: AppTextStyles.bodyText2.copyWith(color: AppColors.gray600),
          ),
          const SizedBox(height: AppDimensions.lg),

          // 硬件产品卡片
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 1,
            mainAxisSpacing: AppDimensions.md,
            crossAxisSpacing: AppDimensions.md,
            childAspectRatio: 2.5,
            children: [
              _buildHardwareCard(
                name: '点一机 DYJ',
                version: 'v1',
                description: '多功能智能硬件开发平台，支持多种传感器和通信模块',
                icon: Icons.developer_board,
                color: AppColors.primaryGreen,
                onTap: () {},
              ),
              _buildHardwareCard(
                name: '点一机卡片版',
                version: 'DYJ Card',
                description: '紧凑型卡片式设计，适合便携式项目开发',
                icon: Icons.style,
                color: AppColors.infoBlue,
                onTap: () {},
              ),
              _buildHardwareCard(
                name: 'ReAI 眼镜',
                version: 'ReAI Glass',
                description: '智能增强现实眼镜，集成AI视觉处理和显示功能',
                icon: Icons.visibility,
                color: AppColors.warningYellow,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // BLE搜索入口
          StandardCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BLEDeviceListPage(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen.withOpacity(0.1),
                    AppColors.mediumGreen.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // BLE图标
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching,
                      size: AppDimensions.iconXLarge,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.lg),
                  // 文字内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BLE设备搜索',
                          style: AppTextStyles.headline3,
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          '搜索并连接附近的蓝牙设备',
                          style: AppTextStyles.bodyText2.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: AppDimensions.iconSmall,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: AppDimensions.xs),
                            Text(
                              '开始搜索设备',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: AppDimensions.iconSmall,
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建硬件产品卡片
  Widget _buildHardwareCard({
    required String name,
    required String version,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StandardCard(
      onTap: onTap,
      child: Row(
        children: [
          // 左侧图标
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            child: Icon(
              icon,
              size: AppDimensions.iconXLarge,
              color: color,
            ),
          ),
          const SizedBox(width: AppDimensions.lg),
          // 右侧内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.headline3,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                        vertical: AppDimensions.xs,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
                      ),
                      child: Text(
                        version,
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  description,
                  style: AppTextStyles.bodyText2.copyWith(color: AppColors.gray600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: AppDimensions.iconSmall,
                      color: color,
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Text(
                      '了解更多',
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
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

  /// 构建项目标签页
  Widget _buildProjectsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: AppDimensions.iconXLarge * 2,
            color: AppColors.gray300,
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            '项目管理',
            style: AppTextStyles.headline2,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            '管理您的硬件开发项目',
            style: AppTextStyles.bodyText2,
          ),
        ],
      ),
    );
  }

  /// 构建AI工具标签页
  Widget _buildAIToolsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: AppDimensions.iconXLarge * 2,
            color: AppColors.gray300,
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'AI工具集',
            style: AppTextStyles.headline2,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            '强大的AI辅助开发工具',
            style: AppTextStyles.bodyText2,
          ),
        ],
      ),
    );
  }

  /// 构建标签
  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.darkGreen),
      ),
    );
  }
}
