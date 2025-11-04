import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../constants/dimensions.dart';
import '../../constants/durations.dart';

/// Reai App 按钮组件集合

/// 主要按钮 - 绿色填充按钮
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonSize size;
  final Widget? icon;
  final double? width;
  final double? height;

  const PrimaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = ButtonSize.medium,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? _getButtonHeight(size);
    final horizontalPadding = _getHorizontalPadding(size);
    final textStyle = _getTextStyle(size);

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: _getIconSize(size),
        height: _getIconSize(size),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: AppDimensions.xs),
          Text(text, style: textStyle),
        ],
      );
    } else {
      child = Text(text, style: textStyle);
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.gray300,
          disabledForegroundColor: AppColors.gray600,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppDurations.fast,
          child: child,
        ),
      ),
    );
  }
}

/// 次要按钮 - 绿色边框按钮
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonSize size;
  final Widget? icon;
  final double? width;
  final double? height;

  const SecondaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = ButtonSize.medium,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? _getButtonHeight(size);
    final horizontalPadding = _getHorizontalPadding(size);
    final textStyle = _getTextStyle(size).copyWith(
      color: AppColors.primaryGreen,
    );

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: _getIconSize(size),
        height: _getIconSize(size),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: AppDimensions.xs),
          Text(text, style: textStyle),
        ],
      );
    } else {
      child = Text(text, style: textStyle);
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen, width: 1),
          disabledForegroundColor: AppColors.gray400,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppDurations.fast,
          child: child,
        ),
      ),
    );
  }
}

/// 文本按钮
class TextButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonSize size;
  final Widget? icon;
  final Color? color;

  const TextButtonWidget({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.size = ButtonSize.medium,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textStyle = _getTextStyle(size).copyWith(
      color: color ?? AppColors.primaryGreen,
    );

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: _getIconSize(size),
        height: _getIconSize(size),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: AppDimensions.xs),
          Text(text, style: textStyle),
        ],
      );
    } else {
      child = Text(text, style: textStyle);
    }

    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.primaryGreen,
        disabledForegroundColor: AppColors.gray400,
        padding: EdgeInsets.symmetric(
          horizontal: _getHorizontalPadding(size),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        ),
      ),
      child: AnimatedSwitcher(
        duration: AppDurations.fast,
        child: child,
      ),
    );
  }
}

/// 图标按钮
class IconButtonWidget extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final IconButtonSize size;
  final Color? color;
  final Color? backgroundColor;

  const IconButtonWidget({
    Key? key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = IconButtonSize.medium,
    this.color,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconSize = _getIconButtonSize(size);
    final buttonSize = iconSize + AppDimensions.sm;

    Widget button = Container(
      width: buttonSize,
      height: buttonSize,
      decoration: backgroundColor != null
          ? BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
            )
          : null,
      child: Icon(
        icon,
        size: iconSize,
        color: color ?? AppColors.deepBlack,
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
        child: button,
      ),
    );
  }
}

/// 悬浮操作按钮
class FloatingActionButtonWidget extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const FloatingActionButtonWidget({
    Key? key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.onPrimary,
      tooltip: tooltip,
      elevation: 4,
      child: Icon(icon),
    );
  }
}

// ==================== 辅助枚举和函数 ====================

/// 按钮尺寸枚举
enum ButtonSize { small, medium, large }

/// 图标按钮尺寸枚举
enum IconButtonSize { small, medium, large }

/// 根据按钮尺寸获取高度
double _getButtonHeight(ButtonSize size) {
  switch (size) {
    case ButtonSize.small:
      return AppDimensions.buttonHeightSmall;
    case ButtonSize.medium:
      return AppDimensions.buttonHeightMedium;
    case ButtonSize.large:
      return AppDimensions.buttonHeightLarge;
  }
}

/// 根据按钮尺寸获取水平内边距
double _getHorizontalPadding(ButtonSize size) {
  switch (size) {
    case ButtonSize.small:
      return AppDimensions.buttonHorizontalPaddingSmall;
    case ButtonSize.medium:
      return AppDimensions.buttonHorizontalPaddingMedium;
    case ButtonSize.large:
      return AppDimensions.buttonHorizontalPaddingLarge;
  }
}

/// 根据按钮尺寸获取文字样式
TextStyle _getTextStyle(ButtonSize size) {
  switch (size) {
    case ButtonSize.small:
      return AppTextStyles.buttonSmall;
    case ButtonSize.medium:
      return AppTextStyles.buttonMedium;
    case ButtonSize.large:
      return AppTextStyles.buttonLarge;
  }
}

/// 根据按钮尺寸获取图标尺寸
double _getIconSize(ButtonSize size) {
  switch (size) {
    case ButtonSize.small:
      return AppDimensions.iconSmall;
    case ButtonSize.medium:
      return AppDimensions.iconMedium;
    case ButtonSize.large:
      return AppDimensions.iconLarge;
  }
}

/// 根据图标按钮尺寸获取图标尺寸
double _getIconButtonSize(IconButtonSize size) {
  switch (size) {
    case IconButtonSize.small:
      return AppDimensions.iconSmall;
    case IconButtonSize.medium:
      return AppDimensions.iconMedium;
    case IconButtonSize.large:
      return AppDimensions.iconLarge;
  }
}