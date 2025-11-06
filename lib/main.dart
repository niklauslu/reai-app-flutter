import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'theme/app_theme.dart';
import 'components/cards/standard_card.dart';
import 'components/buttons/app_buttons.dart';
import 'components/mqtt_status_icon.dart';
import 'components/permission_status_banner.dart';
import 'pages/ble_device_list_page.dart';
import 'pages/loading_page.dart';
import 'theme/colors.dart';
import 'theme/text_styles.dart';
import 'constants/dimensions.dart';
import 'mqtt/mqtt_service.dart';
import 'mqtt/models/mqtt_message.dart';
import 'mqtt/models/mqtt_request_response.dart';
import 'ble/ble_service.dart';
import 'services/device_id_service.dart';
import 'services/background_service_manager.dart';
import 'services/native_service_manager.dart';
import 'services/ios_background_service.dart';
import 'services/app_permission_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 获取设备ID服务
  final deviceIdService = DeviceIdService();

  // 初始化原生服务管理器（仅Android）
  if (Platform.isAndroid) {
    try {
      await nativeServiceManager.initialize();
      print('✅ 原生服务管理器初始化成功');

      // 暂时禁用MQTT原生服务启动，避免重复连接问题
      print('📱 暂时禁用MQTT原生服务，使用Flutter MQTT服务');
      final success = false;
    } catch (e) {
      print('❌ 原生服务管理器初始化失败: $e');
    }

    // 使用Flutter MQTT服务
    print('📱 使用Flutter MQTT服务');
    final mqttService = MQTTService();
    await mqttService.initialize();
    print('✅ Flutter MQTT服务初始化成功');
  } else {
    // iOS平台使用统一的MQTT服务
    final mqttService = MQTTService();
    await mqttService.initialize();
    print('✅ iOS MQTT服务初始化成功');
  }

  // 初始化iOS后台服务（如果需要）
  if (Platform.isIOS) {
    await IOSBackgroundService.initialize();
    print('✅ iOS后台服务初始化成功');
  }

  // 初始化应用生命周期监听
  final appLifecycleService = AppLifecycleService();
  appLifecycleService.initialize();

  print('🚀 ReAI Assistant 启动完成');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  bool _initializationError = false;
  String? _errorMessage;
  final AppPermissionService _permissionService = AppPermissionService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// 初始化应用
  Future<void> _initializeApp() async {
    try {
      print('🚀 开始应用初始化...');

      // iOS网络权限触发 - 在应用启动时自动触发网络权限弹窗
      if (Platform.isIOS) {
        await _permissionService.triggerIOSNetworkPermission();
      }

      // 添加延迟以确保loading动画至少播放一段时间
      await Future.delayed(const Duration(milliseconds: 2000));

      setState(() {
        _isInitialized = true;
      });

      print('✅ 应用初始化完成');
    } catch (e) {
      print('❌ 应用初始化失败: $e');
      setState(() {
        _initializationError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReAI Assistant',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: _getHomePage(),
    );
  }

  Widget _getHomePage() {
    if (_initializationError) {
      return _buildErrorPage();
    } else if (_isInitialized) {
      return const MyHomePage(title: 'ReAI Assistant - 硬件AI助手');
    } else {
      return const LoadingPage();
    }
  }

  Widget _buildErrorPage() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.errorRed,
              ),
              const SizedBox(height: AppDimensions.lg),
              Text(
                '初始化失败',
                style: AppTextStyles.headline2.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                _errorMessage ?? '未知错误',
                style: AppTextStyles.bodyText1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.xl),
              PrimaryButton(
                text: '重试',
                onPressed: () {
                  setState(() {
                    _initializationError = false;
                    _errorMessage = null;
                  });
                  _initializeApp();
                },
              ),
            ],
          ),
        ),
      ),
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
  final DeviceIdService _deviceIdService = DeviceIdService();
  final MQTTService _mqttService = MQTTService();
  final BLEService _bleService = BLEService();
  final AppPermissionService _permissionService = AppPermissionService();

  String? _deviceId;
  String? _formattedDeviceId;
  StreamSubscription<MQTTRequestMessage>? _mqttRequestSubscription;

  // 权限状态
  bool _showNetworkWarning = false;
  bool _showBluetoothWarning = false;
  Timer? _permissionRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initDeviceId();
    _setupMqttRequestListener();

    // 延迟执行权限检测，确保UI已构建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });

    // 设置定期权限检查，确保权限状态动态更新
    _setupPermissionRefreshTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mqttRequestSubscription?.cancel();
    _permissionRefreshTimer?.cancel();
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


      print('✅ 设备ID初始化完成: $_formattedDeviceId');
    } catch (e) {
      print('❌ 设备ID初始化失败: $e');
    }
  }

  /// 设置MQTT请求监听器
  void _setupMqttRequestListener() {
    print('🔧 [MQTT回调] 设置MQTT请求监听器...');

    _mqttRequestSubscription = _mqttService.requestStream.listen((request) {
      print('📨 [MQTT回调] 收到请求消息:');
      print('   📋 ID: ${request.id}');
      print('   🔧 方法: ${request.method}');
      print('   📱 设备ID: ${request.deviceId}');
      print('   📦 参数: ${request.params}');
      print('   ⏰ 时间戳: ${request.timestamp}');

      // 处理BLE请求
      _handleMqttRequest(request);
    });

    print('✅ [MQTT回调] MQTT请求监听器设置完成');
  }

  /// 处理MQTT请求
  Future<void> _handleMqttRequest(MQTTRequestMessage request) async {
    print('🔧 [MQTT处理] 开始处理请求: ${request.method}#${request.id}');

    try {
      // 调用BLE服务的handleRequest方法
      final result = await _bleService.handleRequest(request.method, request.params);

      if (result != null) {
        print('✅ [MQTT处理] BLE处理成功:');
        print('   成功: ${result['success']}');
        print('   消息: ${result['message']}');
        print('   数据: ${result['data']}');

        // 发送MQTT响应
        await _mqttService.respondToRequest(
          request.id,
          request.method,
          success: result['success'],
          message: result['message'],
          data: result['data'] != null ? result["data"] : null,
        );

        // 标记MQTT请求已处理完成，防止5秒超时默认回复
        _mqttService.markRequestCompleted(request.id, request.method);

        print('📤 [MQTT处理] 响应已发送，请求已标记为完成');
      } else {
        print('❌ [MQTT处理] BLE处理返回null结果');

        // 发送失败响应
        await _mqttService.respondToRequest(
          request.id,
          request.method,
          success: false,
          message: 'BLE处理失败：返回结果为空',
        );

        // 即使失败也标记请求已处理完成，防止默认回复
        _mqttService.markRequestCompleted(request.id, request.method);
      }
    } catch (e) {
      print('💥 [MQTT处理] 处理异常: $e');

      // 发送异常响应
      await _mqttService.respondToRequest(
        request.id,
        request.method,
        success: false,
        message: '处理请求异常: $e',
      );

      // 即使异常也标记请求已处理完成，防止默认回复
      _mqttService.markRequestCompleted(request.id, request.method);
    }
  }

  
  
  /// 检测应用权限
  Future<void> _checkPermissions() async {
    try {
      debugPrint('🔍 开始应用级权限检测...');

      // 主动请求权限（这会触发iOS权限对话框）
      bool allOK = await _permissionService.checkAllPermissions(context);

      // 获取详细的权限状态
      final summary = await _permissionService.getPermissionSummary();

      setState(() {
        // 根据权限状态设置警告标志
        if (Platform.isIOS) {
          // iOS只需要检查蓝牙和位置权限
          _showBluetoothWarning = summary['bluetooth'] == false ||
                                  summary['location'] == false;
        } else {
          // Android需要检查所有蓝牙相关权限
          _showBluetoothWarning = summary['bluetooth'] == false ||
                                  summary['bluetoothScan'] == false ||
                                  summary['bluetoothConnect'] == false ||
                                  summary['location'] == false;
        }
      });

      debugPrint('✅ 权限检测完成，蓝牙警告: $_showBluetoothWarning');
    } catch (e) {
      debugPrint('❌ 权限检测失败: $e');
    }
  }

  /// 设置权限刷新定时器
  void _setupPermissionRefreshTimer() {
    // 每3秒检查一次权限状态，确保权限状态动态更新
    _permissionRefreshTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (mounted) {
        _checkPermissions();
      }
    });
    debugPrint('⏰ 权限刷新定时器已启动，每3秒检查一次');
  }

  /// 显示MQTT状态对话框
  void _showMQTTStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('MQTT连接状态'),
          content: StreamBuilder<MQTTConnectionStatus>(
            stream: MQTTService().statusStream,
            initialData: MQTTService().currentStatus,
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
                        MQTTService().connect();
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
                        MQTTService().disconnect();
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
            // 权限状态横幅
            PermissionStatusBanner(
              showNetworkWarning: _showNetworkWarning,
              showBluetoothWarning: _showBluetoothWarning,
              onSettingsTap: () {
                // 用户点击设置后重新检测权限
                Future.delayed(Duration(seconds: 2), () {
                  _checkPermissions();
                });
              },
            ),

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
                description: '多功能智��硬件开发平台，支持多种传感器和通信模块',
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
