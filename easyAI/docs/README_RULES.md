# README Update Rules

These rules define how README.md should be updated when the codebase changes.

## Scope to Scan
- `easyAI/`
- `easyAITests/`
- `easyAIUITests/`
- `Package.swift`
- `Info.plist`
- `assets/`
- `demo.gif`

## What to Look For
- New or removed features
- Configuration or settings changes
- System requirements changes (iOS / Xcode / Swift)
- Dependency changes
- Folder structure changes
- Demo or screenshot updates

## Update Mapping
- Features added/removed -> "功能特性" and "核心功能说明"
- Configuration changes -> "设置步骤"
- Dependency changes -> "系统要求" (and mention in "设置步骤" if needed)
- Folder structure changes -> "项目结构"
- Demo updates -> "Demo"
- Planned work -> "未来计划"

## Style and Guardrails
- Keep language concise and consistent with existing README tone (Chinese).
- Prefer bullets; avoid long paragraphs.
- If a section is no longer applicable, remove it.
- If a feature is partially implemented, clarify status.
- Do not include secrets (e.g., API keys).
