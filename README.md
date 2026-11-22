# StageCommander v2.0

**StageCommander** 是一款面向校园剧场、话剧排练与小型演出的跨平台舞台音效播控台（Show Control Workbench），从原 PyQt5/Matplotlib 单文件原型（Beta 8）全面重构为 **Flutter Desktop + 原生 C++ SoLoud 音频引擎 + 严格 Material Design 3 (MD3)** 架构，原生支持 **Windows (`.exe`)**、**macOS (`.app` / `.dmg`)** 与 **Linux (`.deb` / `.tar.gz`)**。

---

## 核心重构升级亮点

1. **原生低延迟混音引擎（替代 Qt QMediaPlayer + NumPy + Matplotlib）**
   - 基于 **SoLoud + miniaudio** 的原生 C++ 音频引擎，使用随应用提供的解码组件。
   - **BGM 独占总线**：切歌平滑淡出/交叉淡入，支持独立音量推子、循环开关与 **台词一键闪避（Ducking，平滑衰减至 30% 并可恢复）**。
   - **SFX 单例重触发（Retrigger）**：以 `cue.id` 为键精确管理，同条音效连击立即从头重触发避免叠音杂波，不同音效间支持多路并发混音。
   - **全格式波形图与拖拽寻道**：原生异步提取 **MP3 / WAV / OGG / FLAC / Opus** 音频振幅包络并绘制交互式对称波形进度条（支持悬停时间预览与直接拖拽跳转）。

2. **演出防误触保护与应用内热键**
   - 启动默认处于 **锁定态（Disarmed）**：顶部显示红色警示条，忽略所有音效热键。
   - **`Space` / GO 按钮**：解除保险栓进入 **激活态（Armed）**；另提供 **仅锁定热键** 按钮，可在不中断 BGM 的前提下重新上锁。
   - **`Esc` / 全部停止（PANIC）**：瞬间切断所有 BGM 与 SFX 输出并强制退回锁定态。
   - **物理键位匹配**：窗口处于前台时，可使用 `1..9`、`A..Z`、`F1..F12` 等物理键触发音效。编辑框获得焦点或打开弹窗时会暂停应用内热键。

3. **严格 Material Design 3（MD3）设计语言**
   - 默认提供护眼不刺眼的 **MD3 暗场剧场模式**，支持一键切换 **MD3 亮色模式** 与 4 组 **动态主题种子色**。
   - 遵循 MD3 Tonal Elevation（`surfaceContainerLow` / `surfaceContainer` / `surfaceContainerHigh`）层级、圆角规范（`16dp` 卡片、`28dp` 模态框、Pill 动作按钮）、表格等宽数字（Tabular Figures）与统一 `Rounded` 矢量图标。
   - 支持分栏拖拽调宽（默认约 3:7 比例）、剧幕拖拽排序/右键操作、音频文件拖拽批量导入、同幕热键冲突实时提示。

4. **绿色便携工程管理与 Beta 8 无缝迁移**
   - 自动在可执行文件同级目录（可写时）或用户文档目录维护 `StageCommander_Data/project.json` 与 `Media/`。
   - 导入音频时以内容摘要和文件名归档，并记录**跨平台相对路径**（`Media/xxxxxxxx_name.ext`），便于在三个平台间移动工程。
   - 支持直接导入旧版 **Beta 8 `project.json`** 自动迁移，并支持一键导出/导入 `.zip` 便携演出工程包。

---

## 安装与运行

- **Windows x64**：解压整个 ZIP，再运行其中的 `StageCommander.exe`。若系统缺少运行库，可安装微软的 [Visual C++ x64 Redistributable](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)。
- **macOS**：打开 DMG，将 `StageCommander.app` 拖入“应用程序”。构建产物未经过 Apple Developer ID 签名及公证，首次打开时可能被 Gatekeeper 拦截。
- **Linux x64**：在兼容的 Debian 或 Ubuntu 系统中运行 `sudo apt install ./StageCommander-linux-x64.deb`，或解压 `.tar.gz` 后运行 `./StageCommander`。

---

## 本地构建指南

需要 **Flutter 3.50.0+**（Dart 3.14+）。

### Windows (`.exe`)
> 需开启 Windows“开发人员模式”（`ms-settings:developers`）并安装 Visual Studio 2022 Desktop C++ 工具链。
```powershell
flutter pub get
flutter build windows --release
# 产物目录：build\windows\x64\runner\Release\StageCommander.exe
```

### Linux (可执行包 & `.deb`)
```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libasound2-dev libpulse-dev
flutter pub get
flutter build linux --release
# 产物目录：build/linux/x64/release/bundle/StageCommander
```

### macOS (`.app` / `.dmg`)
```bash
flutter pub get
flutter build macos --release
# 产物：build/macos/Build/Products/Release/StageCommander.app
```

---

## GitHub Actions 三端自动发布

仓库内置 [`.github/workflows/release.yml`](.github/workflows/release.yml)。推送 `main` 或开启针对 `main` 的拉取请求后，GitHub Actions 会检查代码、运行测试并构建三端产物。推送版本标签（例如 `git push origin v2.0.0`）后，流水线将产物上传到对应的 GitHub Release。

- `StageCommander-windows-x64.zip`（含 `StageCommander.exe`）
- `StageCommander-macos.dmg` & `StageCommander-macos.zip`（含 `StageCommander.app`）
- `StageCommander-linux-x64.deb` & `StageCommander-linux-x64.tar.gz`

---

## 测试

```bash
flutter analyze
flutter test
```
