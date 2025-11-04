import 'package:flutter/material.dart';

/// Reai App 颜色配置
/// 白绿黑主色调系统
class AppColors {
  AppColors._();

  // ==================== 主色调 ====================
  /// 白色 - 背景主色，体现简洁、纯净
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// 绿色 - 主题色，代表AI智能、成功、活跃
  static const Color primaryGreen = Color(0xFF00D474);

  /// 黑色 - 文字主色，体现专业、稳重
  static const Color deepBlack = Color(0xFF1A1A1A);

  // ==================== 辅助色调 ====================
  /// 浅绿色 - hover状态、选中背景
  static const Color lightGreen = Color(0xFFE6FFF9);

  /// 中绿色 - 强调色
  static const Color mediumGreen = Color(0xFF66FFB3);

  /// 深绿色 - 按按下状态
  static const Color darkGreen = Color(0xFF00A85A);

  // ==================== 灰度层级 ====================
  static const Color gray50 = Color(0xFFF8F9FA);
  static const Color gray100 = Color(0xFFF1F3F4);
  static const Color gray200 = Color(0xFFE8EAED);
  static const Color gray300 = Color(0xFFDADCE0);
  static const Color gray400 = Color(0xFFBDC1C6);
  static const Color gray500 = Color(0xFF9AA0A6);
  static const Color gray600 = Color(0xFF80868B);
  static const Color gray700 = Color(0xFF5F6368);
  static const Color gray800 = Color(0xFF3C4043);
  static const Color gray900 = Color(0xFF202124);

  // ==================== 功能色 ====================
  /// 错误色
  static const Color errorRed = Color(0xFFEA4335);

  /// 警告色
  static const Color warningYellow = Color(0xFFFBBC04);

  /// 信息色
  static const Color infoBlue = Color(0xFF4285F4);

  // ==================== 语义化颜色 ====================
  /// 背景色
  static const Color background = pureWhite;
  static const Color surface = pureWhite;
  static const Color surfaceVariant = gray50;

  /// 文字色
  static const Color onPrimary = pureWhite;
  static const Color onBackground = deepBlack;
  static const Color onSurface = deepBlack;
  static const Color onSurfaceVariant = gray700;

  /// 边框色
  static const Color outline = gray300;
  static const Color outlineVariant = gray200;

  // ==================== 阴影色 ====================
  static Color shadow = Colors.black.withOpacity(0.05);
  static Color shadowDark = Colors.black.withOpacity(0.1);
}