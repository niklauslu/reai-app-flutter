#!/bin/bash

# Reai App 构建和部署脚本
# 功能：清理项目、构建APK并安装到设备

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_TYPE="debug"  # 默认debug构建
DEVICE_ID=""

echo -e "${BLUE}🚀 开始构建和部署 Reai App...${NC}"
echo -e "项目根目录: ${PROJECT_ROOT}"
echo ""

# 函数：打印步骤
print_step() {
    echo -e "${YELLOW}📝 $1${NC}"
}

# 函数：打印成功
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 函数：打印错误
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 函数：检查设备连接
check_device() {
    local devices=$(/Users/niklaslu/Library/Android/sdk/platform-tools/adb devices | grep -v "List of devices" | grep -v "^$" | awk '{print $1}')
    if [ -z "$devices" ]; then
        print_error "未发现连接的 Android 设备"
        echo -e "${YELLOW}请检查：${NC}"
        echo "  1. 设备已连接并开启USB调试"
        echo "  2. 已授权计算机调试权限"
        exit 1
    fi

    if [ $(echo "$devices" | wc -l) -gt 1 ]; then
        echo -e "${YELLOW}发现多个设备：${NC}"
        echo "$devices"
        if [ -z "$DEVICE_ID" ]; then
            echo -e "${BLUE}使用第一个设备: $(echo "$devices" | head -1)${NC}"
            DEVICE_ID=$(echo "$devices" | head -1)
        fi
    else
        DEVICE_ID="$devices"
    fi

    echo -e "${GREEN}找到设备: $DEVICE_ID${NC}"
}

# 函数：解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --release)
                BUILD_TYPE="release"
                shift
                ;;
            --device-id)
                DEVICE_ID="$2"
                shift 2
                ;;
            -h|--help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --release          构建 release 版本（默认 debug）"
                echo "  --device-id <id>   指定设备 ID"
                echo "  -h, --help         显示帮助信息"
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                echo "使用 -h 或 --help 查看帮助"
                exit 1
                ;;
        esac
    done
}

# 解析命令行参数
parse_args "$@"

echo -e "${BLUE}构建类型: ${BUILD_TYPE}${NC}"
echo ""

# 1. 清理项目
print_step "1. 清理项目缓存..."
cd "$PROJECT_ROOT"
flutter clean
print_success "项目缓存清理完成"

# 2. 获取依赖
print_step "2. 获取项目依赖..."
flutter pub get
print_success "依赖获取完成"

# 3. 检查设备连接
print_step "3. 检查设备连接..."
check_device

# 4. 构建 APK
print_step "4. 构建 APK ($BUILD_TYPE)..."
if [ "$BUILD_TYPE" = "release" ]; then
    flutter build apk --release
    APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
else
    flutter build apk --debug
    APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-debug.apk"
fi

if [ ! -f "$APK_PATH" ]; then
    print_error "APK 构建失败: 文件不存在 $APK_PATH"
    exit 1
fi

print_success "APK 构建完成: $APK_PATH"

# 5. 安装到设备
print_step "5. 安装到设备 $DEVICE_ID..."
/Users/niklaslu/Library/Android/sdk/platform-tools/adb -s "$DEVICE_ID" install -r "$APK_PATH"

# 检查安装结果
if [ $? -eq 0 ]; then
    print_success "APK 安装成功"
else
    print_error "APK 安装失败"
    exit 1
fi

# 6. 启动应用（可选）
print_step "6. 启动应用..."
PACKAGE_NAME="com.reai.dyj"
LAUNCH_ACTIVITY="com.reai.dyj.MainActivity"

/Users/niklaslu/Library/Android/sdk/platform-tools/adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 2>/dev/null || true

print_success "应用启动完成"

# 7. 显示完成信息
echo ""
echo -e "${GREEN}🎉 Reai App 构建和部署完成！${NC}"
echo ""
echo -e "${BLUE}构建信息：${NC}"
echo "  • 构建类型: $BUILD_TYPE"
echo "  • APK 路径: $APK_PATH"
echo "  • 目标设备: $DEVICE_ID"
echo "  • 包名: $PACKAGE_NAME"
echo ""
echo -e "${YELLOW}测试建议：${NC}"
echo "  1. 检查应用图标是否正确显示"
echo "  2. 测试 BLE 功能是否正常"
echo "  3. 验证硬件设备搜索和连接"
echo ""
echo -e "${GREEN}✨ 应用已成功安装并启动！${NC}"