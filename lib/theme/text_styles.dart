import 'package:flutter/material.dart';
import 'colors.dart';

/// Reai App 文字样式配置
class AppTextStyles {
  AppTextStyles._();

  // ==================== 标题类 ====================

  /// 大标题 - 32px
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.deepBlack,
    height: 1.2,
    fontFamily: 'PingFang SC',
  );

  /// 中标题 - 24px
  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.deepBlack,
    height: 1.3,
    fontFamily: 'PingFang SC',
  );

  /// 小标题 - 20px
  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.deepBlack,
    height: 1.4,
    fontFamily: 'PingFang SC',
  );

  /// 次级标题 - 18px
  static const TextStyle headline4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.deepBlack,
    height: 1.4,
    fontFamily: 'PingFang SC',
  );

  // ==================== 正文类 ====================

  /// 正文大 - 16px
  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.deepBlack,
    height: 1.5,
    fontFamily: 'PingFang SC',
  );

  /// 正文小 - 14px
  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.gray700,
    height: 1.5,
    fontFamily: 'PingFang SC',
  );

  // ==================== 辅助文字 ====================

  /// 说明文字 - 12px
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.gray600,
    height: 1.4,
    fontFamily: 'PingFang SC',
  );

  /// 标签文字 - 10px
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.gray600,
    height: 1.6,
    fontFamily: 'PingFang SC',
    letterSpacing: 0.5,
  );

  // ==================== 按钮文字 ====================

  /// 大按钮文字
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
    height: 1.2,
    fontFamily: 'PingFang SC',
  );

  /// 中按钮文字
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
    height: 1.2,
    fontFamily: 'PingFang SC',
  );

  /// 小按钮文字
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
    height: 1.2,
    fontFamily: 'PingFang SC',
  );

  // ==================== 代码文字 ====================

  /// 代码样式 - 等宽字体
  static const TextStyle code = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.gray800,
    fontFamily: 'SF Mono',
    height: 1.4,
  );

  /// 小代码样式
  static const TextStyle codeSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.gray700,
    fontFamily: 'SF Mono',
    height: 1.4,
  );

  // ==================== 特殊文字 ====================

  /// 链接文字
  static const TextStyle link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryGreen,
    height: 1.4,
    fontFamily: 'PingFang SC',
    decoration: TextDecoration.underline,
  );

  /// 错误文字
  static const TextStyle error = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.errorRed,
    height: 1.4,
    fontFamily: 'PingFang SC',
  );

  /// 成功文字
  static const TextStyle success = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryGreen,
    height: 1.4,
    fontFamily: 'PingFang SC',
  );
}