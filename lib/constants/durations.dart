import 'package:flutter/animation.dart';

/// Reai App 动画时长和曲线常量
class AppDurations {
  AppDurations._();

  // ==================== 动画时长 ====================
  /// 快速动画 - 150ms
  static const Duration fast = Duration(milliseconds: 150);

  /// 标准动画 - 300ms
  static const Duration normal = Duration(milliseconds: 300);

  /// 慢速动画 - 500ms
  static const Duration slow = Duration(milliseconds: 500);

  /// 超慢速动画 - 800ms
  static const Duration extraSlow = Duration(milliseconds: 800);

  // ==================== 动画曲线 ====================
  /// 默认缓动曲线
  static const Curve defaultCurve = Curves.easeInOut;

  /// 进入动画曲线
  static const Curve enterCurve = Curves.easeOutCubic;

  /// 退出动画曲线
  static const Curve exitCurve = Curves.easeInCubic;

  /// 弹性曲线
  static const Curve bounceCurve = Curves.elasticOut;

  /// 平滑曲线
  static const Curve smoothCurve = Curves.easeInOutCubic;

  /// 快速响应曲线
  static const Curve responsiveCurve = Curves.easeOut;

  // ==================== 微交互动画 ====================
  /// 按钮点击动画
  static const Duration buttonAnimation = fast;

  /// 输入框聚焦动画
  static const Duration inputAnimation = normal;

  /// 卡片悬停动画
  static const Duration cardHoverAnimation = fast;

  /// 页面切换动画
  static const Duration pageTransitionAnimation = normal;

  /// 模态框动画
  static const Duration modalAnimation = normal;

  /// 抽屉动画
  static const Duration drawerAnimation = slow;

  /// 底部表单动画
  static const Duration bottomSheetAnimation = normal;

  /// 提示消息动画
  static const Duration toastAnimation = fast;

  /// 加载动画
  static const Duration loadingAnimation = slow;
}