import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../constants/dimensions.dart';

/// Reai App 标准卡片组件
/// 用于承载内容的白色圆角卡片
class StandardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final BoxShadow? shadow;
  final VoidCallback? onTap;
  final Border? border;

  const StandardCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.cardPadding),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppDimensions.cardMargin,
      vertical: AppDimensions.cardMargin / 2,
    ),
    this.borderRadius,
    this.backgroundColor,
    this.shadow,
    this.onTap,
    this.border,
  }) : super(key: key);

  /// 紧凑型卡片
  const StandardCard.compact({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.sm),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppDimensions.cardMargin,
      vertical: AppDimensions.xs,
    ),
    this.borderRadius = AppDimensions.smallCardRadius,
    this.backgroundColor,
    this.shadow,
    this.onTap,
    this.border,
  }) : super(key: key);

  /// 大尺寸卡片
  const StandardCard.large({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.lg),
    this.margin = const EdgeInsets.all(AppDimensions.cardMargin),
    this.borderRadius = AppDimensions.largeCardRadius,
    this.backgroundColor,
    this.shadow,
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.pureWhite,
        borderRadius: BorderRadius.circular(borderRadius ?? AppDimensions.cardRadius),
        border: border,
        boxShadow: [
          shadow ?? _defaultShadow,
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius ?? AppDimensions.cardRadius),
        child: card,
      );
    }

    return card;
  }

  /// 默认阴影
  static BoxShadow get _defaultShadow => BoxShadow(
        color: AppColors.shadow,
        blurRadius: AppDimensions.largeShadowBlur,
        offset: const Offset(0, AppDimensions.smallShadowOffset),
      );
}

/// 带标题的卡片
class TitledCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const TitledCard({
    Key? key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.padding,
    this.margin,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: EdgeInsets.zero,
      margin: margin,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Container(
            padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.outline,
                  width: AppDimensions.dividerHeight,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.headline4,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppDimensions.xs),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          // 内容区域
          Container(
            padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 功能卡片 - 用于展示功能入口
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  const FeatureCard({
    Key? key,
    required this.icon,
    required this.title,
    this.description,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (backgroundColor ?? AppColors.lightGreen).withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
            ),
            child: Icon(
              icon,
              size: AppDimensions.iconLarge,
              color: iconColor ?? AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          // 标题
          Text(
            title,
            style: AppTextStyles.headline4,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              description!,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}