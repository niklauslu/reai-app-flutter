# Reai App - 硬件AI助手 UI设计指导规范

## 1. 设计理念

### 1.1 核心理念
- **简洁高效**：界面简洁明了，操作路径最短
- **科技感**：体现AI和硬件结合的科技属性
- **专业性**：面向硬件开发者和工程师的专业工具
- **可信赖**：建立用户对AI助手的信任感

### 1.2 目标用户
- 硬件工程师
- 嵌入式开发者
- IoT设备开发者
- 电子爱好者

## 2. 色彩系统

### 2.1 主色调
- **白色 (#FFFFFF)**：背景主色，体现简洁、纯净
- **绿色 (#00D474)**：主题色，代表AI智能、成功、活跃
- **黑色 (#1A1A1A)**：文字主色，体现专业、稳重

### 2.2 色彩层级
```dart
// 主色调
static const Color primaryGreen = Color(0xFF00D474);
static const Color pureWhite = Color(0xFFFFFFFF);
static const Color deepBlack = Color(0xFF1A1A1A);

// 辅助色调
static const Color lightGreen = Color(0xFFE6FFF9);
static const Color mediumGreen = Color(0xFF66FFB3);
static const Color darkGreen = Color(0xFF00A85A);

// 灰度层级
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

// 功能色
static const Color errorRed = Color(0xFFEA4335);
static const Color warningYellow = Color(0xFFFBBC04);
static const Color infoBlue = Color(0xFF4285F4);
```

### 2.3 色彩使用规范
- **白色**：页面背景、卡片背景
- **绿色**：主要按钮、状态指示、重要信息
- **黑色**：主要文字、图标
- **浅绿色**：hover状态、选中背景
- **灰色**：次要文字、分割线、禁用状态

## 3. 字体系统

### 3.1 字体选择
- **中文字体**：PingFang SC / 苹方
- **英文字体**：SF Pro Display / Roboto
- **等宽字体**：SF Mono / Roboto Mono（代码显示）

### 3.2 字体层级
```dart
// 标题类
static const TextStyle headline1 = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w700,
  color: deepBlack,
  height: 1.2,
);

static const TextStyle headline2 = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  color: deepBlack,
  height: 1.3,
);

static const TextStyle headline3 = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: deepBlack,
  height: 1.4,
);

// 正文类
static const TextStyle bodyText1 = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: deepBlack,
  height: 1.5,
);

static const TextStyle bodyText2 = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: gray700,
  height: 1.5,
);

// 辅助文字
static const TextStyle caption = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: gray600,
  height: 1.4,
);

// 代码文字
static const TextStyle code = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: gray800,
  fontFamily: 'SF Mono',
  height: 1.4,
);
```

## 4. 布局系统

### 4.1 网格系统
- **基础间距**：8dp的倍数系统
- **内容边距**：16dp（手机）、24dp（平板）
- **组件间距**：8dp、16dp、24dp、32dp

### 4.2 卡片系统
```dart
// 标准卡片
class StandardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const StandardCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

## 5. 组件设计规范

### 5.1 按钮系统
```dart
// 主要按钮
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: pureWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: Text(text),
    );
  }
}

// 次要按钮
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(text),
    );
  }
}
```

### 5.2 输入框系统
```dart
class ReaiTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: pureWhite,
      ),
    );
  }
}
```

## 6. 页面架构

### 6.1 主要页面结构
```
├── 首页 (Dashboard)
│   ├── AI助手对话区
│   ├── 快捷功能入口
│   └── 最近项目
├── 硬件库 (Hardware Library)
│   ├── 硬件分类浏览
│   ├── 搜索和筛选
│   └── 硬件详情页
├── 项目管理 (Projects)
│   ├── 项目列表
│   ├── 项目详情
│   └── 代码编辑器
├── AI工具 (AI Tools)
│   ├── 代码生成
│   ├── 电路分析
│   └── 故障诊断
└── 设置 (Settings)
    ├── 个人资料
    ├── AI配置
    └── 偏好设置
```

### 6.2 导航设计
- **底部导航栏**：主要功能模块切换
- **侧边抽屉**：辅助功能和设置
- **面包屑导航**：层级页面导航

## 7. 图标系统

### 7.1 图标风格
- **风格**：线性图标，简洁现代
- **尺寸**：16dp、24dp、32dp、48dp
- **颜色**：主要使用绿色和黑色

### 7.2 核心图标
- **AI助手**：智能机器人/大脑图标
- **硬件库**：芯片/电路板图标
- **项目管理**：文件夹/文档图标
- **AI工具**：工具箱/齿轮图标
- **设置**：设置/用户图标

## 8. 动效设计

### 8.1 动效原则
- **微交互**：按钮点击、输入框聚焦等
- **转场动画**：页面切换的流畅过渡
- **加载动画**：体现AI思考过程

### 8.2 动效参数
```dart
// 标准动画时长
static const Duration fastDuration = Duration(milliseconds: 150);
static const Duration normalDuration = Duration(milliseconds: 300);
static const Duration slowDuration = Duration(milliseconds: 500);

// 标准动画曲线
static const Curve defaultCurve = Curves.easeInOut;
static const Curve bounceCurve = Curves.elasticOut;
```

## 9. 响应式设计

### 9.1 断点系统
- **手机**：< 768dp
- **平板**：768dp - 1024dp
- **桌面**：> 1024dp

### 9.2 适配原则
- **布局适配**：使用弹性布局和响应式组件
- **字体适配**：根据屏幕尺寸调整字体大小
- **交互适配**：触摸和鼠标交互都要考虑

## 10. 可访问性

### 10.1 语义化
- 合理使用语义化组件
- 提供完整的无障碍标签
- 支持屏幕阅读器

### 10.2 颜色对比
- 确保足够的颜色对比度
- 不仅依赖颜色传达信息
- 提供高对比度模式

## 11. 开发实现

### 11.1 主题配置
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryGreen,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  fontFamily: 'PingFang SC',
  textTheme: const TextTheme(
    // 这里引用前面定义的字体样式
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryGreen,
      // ... 其他样式
    ),
  ),
)
```

### 11.2 组件库结构
```
lib/
├── components/
│   ├── buttons/
│   ├── forms/
│   ├── cards/
│   └── navigation/
├── theme/
│   ├── app_theme.dart
│   ├── colors.dart
│   ├── text_styles.dart
│   └── spacing.dart
└── constants/
    ├── dimensions.dart
    └── durations.dart
```

## 12. 质量标准

### 12.1 性能要求
- 页面加载时间 < 2秒
- 动画帧率 ≥ 60fps
- 内存使用合理

### 12.2 兼容性要求
- 支持Flutter最新稳定版
- iOS 12+ / Android 7.0+
- Web端支持现代浏览器

---

*此设计规范为Reai App硬件AI助手的UI设计指导，所有设计决策都应基于此规范执行。*