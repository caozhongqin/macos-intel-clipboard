# Clipboard 剪贴板历史

一个轻量级的 macOS 剪贴板历史管理工具，常驻菜单栏，支持全局快捷键唤出、浏览历史记录并粘贴。

## 功能特性

- 📋 **自动记录** — 后台监听系统剪贴板，自动保存复制文本
- 🚀 **快速粘贴** — 双击或按 `Enter` 将历史内容粘贴到当前应用
- ⌨️ **全局快捷键** — `⌘` `⇧` `V` 唤出历史窗口
- 🗑️ **管理历史** — 支持删除单条记录或一键清空全部历史
- 📦 **智能去重** — 相同内容自动移至最前，最大存储 200 条
- 🎨 **原生界面** — 采用 macOS 毛玻璃效果，悬浮窗口设计
- 🔒 **隐私安全** — 粘贴完成后恢复原剪贴板内容

## 安装

### 方法一：使用 Makefile（推荐）

```bash
# 完整构建 + 打包 + 签名（适用于正式使用）
make bundle

# 构建 + 打包 + 签名，然后运行
make run

# 仅清理构建产物
make clean
```

`make bundle` 会自动完成：
1. 清理旧的构建产物
2. 编译 Swift 源码
3. 创建 `.app` 包结构
4. 使用开发者证书进行 `codesign` 签名

### 方法二：使用 Swift Package Manager

```bash
# 构建
swift build

# 运行（需在 .build/debug/ 下找到可执行文件）
.build/debug/ClipboardHistory
```

### 方法三：手动编译（无签名，仅用于调试）

```bash
mkdir -p .build
swiftc \
  Sources/ClipboardHistory/*.swift \
  -o .build/Clipboard \
  -framework AppKit \
  -framework Carbon \
  -framework CoreGraphics \
  -O \
  -whole-module-optimization
```

> ⚠️ **注意**：手动编译不会对 `.app` 进行签名。如需要可运行的应用包，请使用 `make bundle`。

## 使用说明

1. 启动应用后，菜单栏会出现 📋 图标
2. **记录剪贴板**：复制任意文本，自动记录
3. **唤出历史窗口**：按下 `⌘` `⇧` `V`
4. **粘贴选中的条目**：
   - 双击条目
   - 选中后按 `Enter`
5. **删除条目**：选中后按 `Delete`
6. **关闭窗口**：按 `Esc`

## 项目结构

```
Clipboard/
├── Info.plist                  # 应用配置（包名、版本等）
├── Makefile                    # 构建脚本
├── Package.swift               # Swift Package 配置
├── Sources/
│   └── ClipboardHistory/
│       ├── main.swift          # 应用入口
│       ├── AppDelegate.swift   # 应用代理（菜单栏、生命周期）
│       ├── ClipboardMonitor.swift  # 剪贴板监听
│       ├── HistoryManager.swift    # 历史记录管理
│       ├── HistoryWindowController.swift # 历史窗口 UI
│       ├── HotKeyManager.swift     # 全局快捷键
│       ├── Models.swift        # 数据模型
│       └── PasteManager.swift  # 粘贴管理
```

## 技术栈

- **语言**: Swift 5.7+
- **框架**: AppKit / Carbon / CoreGraphics
- **构建**: Swift Package Manager / Makefile
- **最低系统**: macOS 12 Monterey

## 许可证

Copyright © 2026 cao. All rights reserved.