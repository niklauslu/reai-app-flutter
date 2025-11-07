#!/bin/bash

# ReAI Assistant APK 安装脚本
# 用于将构建的APK安装到连接的Android设备

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"

echo -e "${BLUE}🚀 ReAI Assistant APK 安装脚本${NC}"
echo -e "${BLUE}===================================${NC}"

# 检查APK文件是否存在
if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}❌ 找不到APK文件: $APK_PATH${NC}"
    echo -e "${YELLOW}💡 请先运行以下命令构建APK:${NC}"
    echo -e "${YELLOW}   flutter build apk --release${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 找到APK文件: $APK_PATH${NC}"

# 检查adb是否可用
if ! command -v adb &> /dev/null; then
    echo -e "${RED}❌ 找不到adb命令${NC}"
    echo -e "${YELLOW}💡 请确保Android SDK已安装并配置到PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 找到adb工具${NC}"

# 检查设备连接
echo -e "${BLUE}📱 检查连接的Android设备...${NC}"
DEVICES=$(adb devices | grep -v "List of devices" | grep "device$")

if [ -z "$DEVICES" ]; then
    echo -e "${RED}❌ 没有找到连接的Android设备${NC}"
    echo -e "${YELLOW}💡 请确保:${NC}"
    echo -e "${YELLOW}   1. Android设备已连接并开启USB调试${NC}"
    echo -e "${YELLOW}   2. 已在设备上授权此计算机${NC}"
    exit 1
fi

# 显示连接的设备
echo -e "${GREEN}✅ 找到以下设备:${NC}"
echo "$DEVICES" | while read -r line; do
    DEVICE_ID=$(echo "$line" | awk '{print $1}')
    echo -e "   📱 $DEVICE_ID"
done

# 获取APK信息
APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
echo -e "${BLUE}📦 APK信息:${NC}"
echo -e "   📁 文件: $(basename "$APK_PATH")"
echo -e "   📏 大小: $APK_SIZE"
echo -e "   📅 构建时间: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$APK_PATH")"

echo
echo -e "${BLUE}🔄 开始安装APK...${NC}"

# 安装APK
if adb install -r "$APK_PATH"; then
    echo -e "${GREEN}🎉 APK安装成功!${NC}"
    echo -e "${GREEN}✅ ReAI Assistant已安装到设备${NC}"

    # 询问是否启动应用
    echo
    read -p "是否现在启动ReAI Assistant应用? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🚀 启动应用...${NC}"
        PACKAGE_NAME="com.reai.dyj"
        adb shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
        echo -e "${GREEN}✅ 应用已启动${NC}"
    fi
else
    echo -e "${RED}❌ APK安装失败${NC}"
    echo -e "${YELLOW}💡 可能的原因:${NC}"
    echo -e "${YELLOW}   1. 设备存储空间不足${NC}"
    echo -e "${YELLOW}   2. 应用版本冲突（尝试先卸载旧版本）${NC}"
    echo -e "${YELLOW}   3. 安装权限问题${NC}"
    exit 1
fi

echo
echo -e "${GREEN}🎯 安装完成!${NC}"
echo -e "${BLUE}📱 在设备上找到"ReAI Assistant"应用并开始使用${NC}"