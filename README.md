# 米遥 (MiAo) · WorkBuddy 语音控制版

> 小米蓝牙语音遥控器 → macOS 菜单栏桥接工具。
> 本仓库是「**WorkBuddy 语音控制版**」：按下遥控器语音键说话，松手后本地 Whisper 转写，
> 自动把文本**粘贴并回车发送**到 WorkBuddy 的对话框。

---

## 功能

- 连接小米蓝牙语音遥控器（ATVV 协议，ADPCM 16 kHz 音频流）。
- 语音键按下开始录音，松手触发本地 Whisper 转写（纯本地、零外部依赖）。
- 转写完成后自动激活 WorkBuddy，把文本粘贴进当前输入框并回车发送（force-submit 盲粘贴模式）。

## 目录结构

```
workxiaom/
├── README.md          # 本文件
├── .gitignore
├── LICENSE            # MIT
├── mi-ao/             # SwiftPM 源码工程（已打 WorkBuddy 补丁）
│   ├── Package.swift
│   ├── Sources/       # Swift 源码（CodexSubmitter / Configuration / BLEVoiceBridge 已改造）
│   ├── scripts/       # run.sh / run-with-mapping.sh 默认携带 --submit-to com.tencent.workbuddy.mac
│   ├── Resources/
│   ├── docs/
│   └── README.md      # 原始 MiAo 构建 / 使用文档
└── 米遥.app/          # 预编译好的 app（开箱即用，ad-hoc 签名）
```

## 快速开始（用预编译 app）

1. 打开 `米遥.app`。
   - 若 macOS 提示“无法验证开发者”被拦截：右键 → 打开，或在终端执行
     `xattr -cr ~/Desktop/workxiaom/米遥.app` 后再打开。
2. 首次会请求**辅助功能**权限：系统设置 → 隐私与安全 → 辅助功能 → 勾选「米遥」。
3. 打开 WorkBuddy，确保聊天输入框处于聚焦状态。
4. 按遥控器语音键说话，松手即把转写文本发送进 WorkBuddy。

> 提示：force-submit 为“盲粘贴”，松手瞬间请保证 WorkBuddy 输入框是聚焦的，文字才会落进对话框并发送。

## 从源码构建（`mi-ao/`）

要求：macOS 14+，Xcode 命令行工具 / Swift 6。

```bash
cd mi-ao
swift build                                  # 或用 scripts/build-app.sh
scripts/install-app.sh                       # 安装到 ~/Applications/米遥.app
```

`mi-ao/scripts/run.sh` 已默认携带
`--force-submit --submit-to com.tencent.workbuddy.mac`，
因此构建出的 app 即指向 WorkBuddy。

> 注：正常环境下直接用 `swift build` 即可（SwiftPM 会处理沙箱）。
> 若所在环境 SwiftPM 无法套沙箱，可改用直接编译：
> `swiftc -swift-version 6 -Onone Sources/MiAo/*.swift -o mi-ao
> -framework AppKit -framework ApplicationServices -framework CoreBluetooth
> -framework IOKit -framework ServiceManagement`

## 切换投递目标（可选）

`--submit-to` 可指向任意应用的 Bundle ID。例如回到 Codex：

```bash
./mi-ao run --force-submit --submit-to com.openai.codex
```

也可直接编辑 `mi-ao/scripts/run.sh` 把默认目标改掉。

## 原理 / 设计说明

- 原版 MiAo 通过辅助功能（Accessibility）树查找 Codex 唯一输入框再粘贴；这要求给 Codex 进程
  注入 `--force-renderer-accessibility` 参数。当该参数无法注入时，非 force 路径必然失败。
- 因此本版采用 `--force-submit`：跳过焦点检测，直接 `Cmd+V` + `Return` 把文本送入当前聚焦的输入框。
- 投递目标由 `Configuration.submitBundleID`（配置）/ `--submit-to`（命令行）控制；
  **二进制自身的默认值仍是 `com.openai.codex`**，是 app 内 `scripts/run.sh` 把默认目标固定成了 WorkBuddy。

## 启动路径与开机自启（重要）

只有**带 `--submit-to com.tencent.workbuddy.mac` 启动**时，文本才会投递到 WorkBuddy。

- ✅ 推荐：直接打开 `米遥.app`（app 内启动脚本已固定携带该参数，且会注入设备名、连接模式、按键预设等偏好）。
- ⚠️ 若用 LaunchAgent 或命令行**直接运行二进制**自启，必须自行补齐参数，否则会静默退回 Codex：

```bash
~/Applications/米遥.app/Contents/MacOS/mi-ao run \
  --name 小米蓝牙语音遥控器 \
  --voice-connection-mode always_ready \
  --preset pointer \
  --force-submit \
  --submit-to com.tencent.workbuddy.mac
```

> `--force-submit` 与 `--submit-to` 缺一不可：只有前者会投到 Codex。
> 直跑二进制不经过 `run-with-mapping.sh`，因此不会带上偏好参数，会出现
> 「实体按键动作已禁用」、语音连接模式不是「随时就绪」，蓝牙断连后也更容易按语音键无反应。
> 开机自启与手动打开 app **二选一**，同时存在两个实例会争抢蓝牙连接。

## 故障排查

- **桥接未启动 / 没有“桥接已就绪”**：确认遥控器已开机并与 Mac 蓝牙配对；菜单栏「米遥」图标应显示已连接。
- **文本没进 WorkBuddy**：先用 `pgrep -fl '米遥.app/Contents/MacOS/mi-ao'` 查看进程参数里是否有
  `--submit-to com.tencent.workbuddy.mac`。日志里的「已发送到 Codex」只是**历史遗留的硬编码文案**，
  不代表真实投递目标；真实目标看进程参数。
- **开机后“又不好用”**：检查是否有一个旧的 LaunchAgent 在开机时抢先启动（
  `launchctl print gui/$(id -u)/com.fanx.miao.bridge`），其参数是否遗漏 `--submit-to`。
- **按语音键没反应**：日志中 `interaction=0x00` 表示遥控器未进入录音交互态；
  重启桥（或重新按一下唤醒遥控器）后应变为 `interaction=0x03`。
- **文本没进 WorkBuddy（续）**：确认 WorkBuddy 正在运行、输入框在松手瞬间是聚焦态；确认「米遥」已授予辅助功能权限。
- **被 Gatekeeper 拦截**：见上方“快速开始”第 1 步的 `xattr -cr`。

## 许可证

见 [LICENSE](LICENSE)（MIT）。
