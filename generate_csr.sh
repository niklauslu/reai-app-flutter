#!/bin/bash

# iOS开发证书CSR生成脚本
# 此脚本将生成Apple Development证书所需的CSR文件

echo "🍎 iOS开发证书CSR文件生成器"
echo "================================"

# 获取用户输入
read -p "请输入你的开发者账号邮箱: " email
read -p "请输入你的姓名或公司名称: " common_name

# 验证输入
if [[ -z "$email" || -z "$common_name" ]]; then
    echo "❌ 错误: 邮箱和姓名不能为空"
    exit 1
fi

echo "📋 证书信息:"
echo "   邮箱: $email"
echo "   姓名: $common_name"
echo ""

read -p "确认信息是否正确? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ 已取消"
    exit 1
fi

echo "🔄 正在生成CSR文件..."

# 生成CSR文件和私钥
openssl req -new -newkey rsa:2048 -nodes -keyout certs/private.key -out certs/development_certificate.csr -subj "/emailAddress=$email/CN=$common_name"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ CSR文件生成成功!"
    echo "📁 文件位置:"
    echo "   CSR文件: certs/development_certificate.csr"
    echo "   私钥文件: certs/private.key"
    echo ""
    echo "📋 下一步:"
    echo "1. 访问 https://developer.apple.com"
    echo "2. 登录你的开发者账号"
    echo "3. 进入 Certificates, Identifiers & Profiles"
    echo "4. 点击 Certificates → 创建新证书 (+)"
    echo "5. 选择 'Apple Development'"
    echo "6. 上传 certs/development_certificate.csr 文件"
    echo "7. 下载并安装生成的证书"
    echo ""
    echo "⚠️  重要: 请妥善保管 private.key 文件，不要泄露给他人!"
else
    echo "❌ CSR文件生成失败，请检查openssl是否已安装"
    exit 1
fi