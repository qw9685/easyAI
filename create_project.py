#!/usr/bin/env python3
"""
EasyAI Xcode项目自动创建脚本
此脚本会自动创建Xcode项目文件结构
"""

import os
import plistlib
import json
from pathlib import Path

PROJECT_NAME = "EasyAI"
BUNDLE_ID = "com.easyai.EasyAI"
CURRENT_DIR = Path(__file__).parent.absolute()
PROJECT_DIR = CURRENT_DIR / f"{PROJECT_NAME}.xcodeproj"

def create_xcodeproj():
    """创建Xcode项目文件结构"""
    
    print(f"🚀 正在创建Xcode项目: {PROJECT_NAME}")
    print(f"📁 项目目录: {PROJECT_DIR}")
    
    # 创建项目目录
    PROJECT_DIR.mkdir(exist_ok=True)
    
    # 创建project.pbxproj文件（简化版）
    pbxproj_content = create_pbxproj()
    (PROJECT_DIR / "project.pbxproj").write_text(pbxproj_content)
    
    # 创建xcworkspace
    workspace_dir = PROJECT_DIR.parent / f"{PROJECT_NAME}.xcworkspace"
    workspace_dir.mkdir(exist_ok=True)
    workspace_content = create_workspace()
    (workspace_dir / "contents.xcworkspacedata").write_text(workspace_content)
    
    # 创建scheme
    schemes_dir = PROJECT_DIR / "xcshareddata" / "xcschemes"
    schemes_dir.mkdir(parents=True, exist_ok=True)
    scheme_content = create_scheme()
    (schemes_dir / f"{PROJECT_NAME}.xcscheme").write_text(scheme_content)
    
    print(f"✅ Xcode项目已创建: {PROJECT_DIR}")
    print("\n⚠️  注意: 自动生成的.pbxproj文件可能不完整")
    print("   建议在Xcode中手动创建项目，然后添加现有文件")
    print("\n📖 详细步骤请查看: XCODE_SETUP.md")

def create_pbxproj():
    """创建project.pbxproj文件内容"""
    # 这是一个非常简化的版本，实际文件更复杂
    # 建议用户手动在Xcode中创建项目
    return """// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
	};
	rootObject = 000000000000000000000000 /* Project object */;
}
"""

def create_workspace():
    """创建workspace内容"""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:{PROJECT_NAME}.xcodeproj">
   </FileRef>
</Workspace>
"""

def create_scheme():
    """创建scheme文件"""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "TARGET_ID"
               BuildableName = "{PROJECT_NAME}.app"
               BlueprintName = "{PROJECT_NAME}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
</Scheme>
"""

if __name__ == "__main__":
    print("=" * 50)
    print("EasyAI Xcode项目创建工具")
    print("=" * 50)
    print()
    
    # 检查是否在正确的目录
    if not (CURRENT_DIR / "EasyAIApp.swift").exists():
        print("❌ 错误: 未找到EasyAIApp.swift文件")
        print(f"   当前目录: {CURRENT_DIR}")
        print("   请确保在项目根目录运行此脚本")
        exit(1)
    
    create_xcodeproj()
    
    print("\n" + "=" * 50)
    print("📝 下一步:")
    print("=" * 50)
    print("1. 打开Xcode")
    print(f"2. 打开项目: {PROJECT_DIR}")
    print("3. 添加所有.swift文件到项目")
    print("4. 配置API Key")
    print("5. 运行项目")
    print("\n详细说明请查看: XCODE_SETUP.md")

