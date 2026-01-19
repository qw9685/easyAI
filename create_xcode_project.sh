#!/bin/bash

# EasyAI Xcode项目创建脚本
# 此脚本将帮助您在Xcode中创建项目并添加所有必要的文件

echo "🚀 EasyAI Xcode项目设置脚本"
echo "================================"
echo ""

# 检查是否安装了Xcode命令行工具
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到Xcode命令行工具"
    echo "请先安装Xcode命令行工具: xcode-select --install"
    exit 1
fi

PROJECT_NAME="EasyAI"
PROJECT_DIR="$(pwd)"

echo "📁 项目目录: $PROJECT_DIR"
echo ""

# 创建Xcode项目
echo "📦 正在创建Xcode项目..."
echo ""

# 使用xcodegen或手动创建项目
# 由于xcodegen可能未安装，我们创建一个项目模板文件

cat > project.yml << 'EOF'
name: EasyAI
options:
  bundleIdPrefix: com.easyai
  deploymentTarget:
    iOS: "15.0"
targets:
  EasyAI:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes:
          - "*.md"
          - "*.sh"
          - "*.yml"
          - ".gitignore"
          - "README.md"
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.easyai.EasyAI
      INFOPLIST_FILE: Info.plist
      SWIFT_VERSION: "5.9"
      IPHONEOS_DEPLOYMENT_TARGET: "15.0"
EOF

echo "✅ 项目配置文件已创建"
echo ""
echo "📝 接下来的步骤:"
echo ""
echo "方法1 - 使用Xcode手动创建（推荐）:"
echo "  1. 打开Xcode"
echo "  2. 选择 'Create a new Xcode project'"
echo "  3. 选择 'iOS' > 'App'"
echo "  4. 填写信息:"
echo "     - Product Name: EasyAI"
echo "     - Team: 选择您的团队"
echo "     - Organization Identifier: com.easyai"
echo "     - Interface: SwiftUI"
echo "     - Language: Swift"
echo "  5. 选择保存位置（建议选择当前目录的上一级）"
echo "  6. 创建项目后，将所有.swift文件拖入Xcode项目"
echo ""
echo "方法2 - 使用XcodeGen（如果已安装）:"
echo "  运行: xcodegen generate"
echo ""
echo "⚠️  重要: 创建项目后，请记得:"
echo "  1. 在 Config/Config.swift 中设置您的OpenAI API Key"
echo "  2. 确保所有文件都已添加到项目中"
echo ""

