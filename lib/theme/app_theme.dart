import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'text_styles.dart';
import '../constants/dimensions.dart';

/// Reai App 主主题配置
/// 白绿黑主色调，简洁现代风格
class AppTheme {
  AppTheme._();

  /// 浅色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ==================== 颜色方案 ====================
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        brightness: Brightness.light,
        primary: AppColors.primaryGreen,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.mediumGreen,
        onSecondary: AppColors.deepBlack,
        background: AppColors.background,
        onBackground: AppColors.onBackground,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceVariant: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.errorRed,
        onError: AppColors.pureWhite,
      ),

      // ==================== 字体主题 ====================
      fontFamily: 'PingFang SC',
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.headline1,
        displayMedium: AppTextStyles.headline2,
        displaySmall: AppTextStyles.headline3,
        headlineLarge: AppTextStyles.headline3,
        headlineMedium: AppTextStyles.headline4,
        headlineSmall: AppTextStyles.headline4,
        titleLarge: AppTextStyles.headline3,
        titleMedium: AppTextStyles.headline4,
        titleSmall: AppTextStyles.bodyText1,
        bodyLarge: AppTextStyles.bodyText1,
        bodyMedium: AppTextStyles.bodyText2,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.buttonMedium,
        labelMedium: AppTextStyles.buttonSmall,
        labelSmall: AppTextStyles.overline,
      ),

      // ==================== AppBar 主题 ====================
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.deepBlack,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppColors.primaryGreen,
        titleTextStyle: AppTextStyles.headline3,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ==================== 卡片主题 ====================
      cardTheme: CardThemeData(
        color: AppColors.pureWhite,
        elevation: 0,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.cardMargin,
          vertical: AppDimensions.cardMargin / 2,
        ),
      ),

      // ==================== 按钮主题 ====================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, AppDimensions.buttonHeightMedium),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.buttonHorizontalPaddingMedium,
            vertical: AppDimensions.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen, width: 1),
          minimumSize: const Size(0, AppDimensions.buttonHeightMedium),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.buttonHorizontalPaddingMedium,
            vertical: AppDimensions.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(0, AppDimensions.buttonHeightMedium),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.buttonHorizontalPaddingMedium,
            vertical: AppDimensions.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // ==================== 输入框主题 ====================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pureWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.inputPadding,
          vertical: AppDimensions.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: const BorderSide(
            color: AppColors.errorRed,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: BorderSide(color: AppColors.outline.withOpacity(0.5)),
        ),
        labelStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.gray600),
        hintStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.gray400),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.errorRed),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),

      // ==================== 底部导航栏主题 ====================
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.pureWhite,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.gray500,
        selectedLabelStyle: AppTextStyles.caption,
        unselectedLabelStyle: AppTextStyles.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ==================== 分割线主题 ====================
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: AppDimensions.dividerHeight,
        space: AppDimensions.dividerHeight,
      ),

      // ==================== 图标主题 ====================
      iconTheme: const IconThemeData(
        color: AppColors.deepBlack,
        size: AppDimensions.iconMedium,
      ),

      // ==================== 浮动按钮主题 ====================
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ==================== 对话框主题 ====================
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.pureWhite,
        elevation: 8,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        ),
        titleTextStyle: AppTextStyles.headline3,
        contentTextStyle: AppTextStyles.bodyText1,
      ),

      // ==================== Chip 主题 ====================
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGreen,
        selectedColor: AppColors.primaryGreen,
        disabledColor: AppColors.gray100,
        labelStyle: AppTextStyles.caption,
        secondaryLabelStyle: AppTextStyles.caption.copyWith(color: AppColors.onPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.smallCardRadius),
        ),
      ),

      // ==================== 列表瓦片主题 ====================
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.xs,
        ),
        titleTextStyle: AppTextStyles.bodyText1,
        subtitleTextStyle: AppTextStyles.bodyText2,
        leadingAndTrailingTextStyle: AppTextStyles.bodyText2,
      ),

      // ==================== 页面过渡动画 ====================
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// 获取当前主题
  static ThemeData of(BuildContext context) {
    return Theme.of(context);
  }

  /// 获取颜色方案
  static ColorScheme colorSchemeOf(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  /// 获取文字主题
  static TextTheme textThemeOf(BuildContext context) {
    return Theme.of(context).textTheme;
  }

  /// 是否为深色主题
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}