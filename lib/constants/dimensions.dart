/// Reai App 尺寸和间距常量
/// 基于 8dp 网格系统
class AppDimensions {
  AppDimensions._();

  // ==================== 基础间距 ====================
  /// 4dp - 最小间距
  static const double xs = 4.0;

  /// 8dp - 基础间距单位
  static const double sm = 8.0;

  /// 16dp - 标准间距
  static const double md = 16.0;

  /// 24dp - 大间距
  static const double lg = 24.0;

  /// 32dp - 超大间距
  static const double xl = 32.0;

  /// 48dp - 特大间距
  static const double xxl = 48.0;

  // ==================== 屏幕边距 ====================
  /// 页面水平边距 - 手机
  static const double screenHorizontalPadding = md;

  /// 页面水平边距 - 平板
  static const double screenHorizontalPaddingTablet = lg;

  /// 页面垂直边距
  static const double screenVerticalPadding = md;

  // ==================== 卡片间距 ====================
  /// 卡片内部间距
  static const double cardPadding = md;

  /// 卡片外部间距
  static const double cardMargin = 8.0;

  /// 卡片圆角
  static const double cardRadius = 12.0;

  /// 小卡片圆角
  static const double smallCardRadius = 8.0;

  /// 大卡片圆角
  static const double largeCardRadius = 16.0;

  // ==================== 按钮尺寸 ====================
  /// 按钮高度 - 大
  static const double buttonHeightLarge = 48.0;

  /// 按钮高度 - 中
  static const double buttonHeightMedium = 40.0;

  /// 按钮高度 - 小
  static const double buttonHeightSmall = 32.0;

  /// 按钮圆角
  static const double buttonRadius = 8.0;

  /// 按钮水平内边距 - 大
  static const double buttonHorizontalPaddingLarge = 24.0;

  /// 按钮水平内边距 - 中
  static const double buttonHorizontalPaddingMedium = 20.0;

  /// 按钮水平内边距 - 小
  static const double buttonHorizontalPaddingSmall = 16.0;

  // ==================== 输入框尺寸 ====================
  /// 输入框高度
  static const double inputHeight = 48.0;

  /// 输入框圆角
  static const double inputRadius = 8.0;

  /// 输入框内边距
  static const double inputPadding = 16.0;

  // ==================== 导航尺寸 ====================
  /// 底部导航栏高度
  static const double bottomNavHeight = 80.0;

  /// 应用栏高度
  static const double appBarHeight = 56.0;

  /// 侧边抽屉宽度
  static const double drawerWidth = 280.0;

  // ==================== 图标尺寸 ====================
  /// 小图标
  static const double iconSmall = 16.0;

  /// 中图标
  static const double iconMedium = 24.0;

  /// 大图标
  static const double iconLarge = 32.0;

  /// 特大图标
  static const double iconXLarge = 48.0;

  // ==================== 分割线 ====================
  /// 分割线高度
  static const double dividerHeight = 1.0;

  /// 粗分割线高度
  static const double thickDividerHeight = 2.0;

  // ==================== 阴影 ====================
  /// 小阴影偏移
  static const double smallShadowOffset = 2.0;

  /// 小阴影模糊半径
  static const double smallShadowBlur = 8.0;

  /// 大阴影偏移
  static const double largeShadowOffset = 4.0;

  /// 大阴影模糊半径
  static const double largeShadowBlur = 16.0;

  // ==================== 响应式断点 ====================
  /// 手机最大宽度
  static const double mobileMaxWidth = 768.0;

  /// 平板最大宽度
  static const double tabletMaxWidth = 1024.0;

  /// 桌面最小宽度
  static const double desktopMinWidth = 1024.0;

  /// 内容最大宽度
  static const double maxContentWidth = 1200.0;
}