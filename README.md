# Ronova Desktop Pet · 若娜瓦桌面伴侣

一个原生 macOS 桌面角色应用：透明窗口、五个视角、随机眨眼、缓慢悬浮、小步走动，以及自动串联的随机生活动作。

<img src="Assets/AppIcon.png" alt="若娜瓦头像" width="160">

当前版本 **1.2.3**。使用 Swift、AppKit、SpriteKit 和 AVFoundation，无第三方运行依赖，可离线运行。

## 功能

- 五个离散视角，保持透明背景；眨眼仅替换眼部区域，避免整幅图换帧重影。
- 悬浮时全身、双脚一起缓慢移动，发丝与裙摆轻微跟随。
- 走动时切换脚掌放平的专用左右侧面，小步前进、肩胯轻微扭动，衣服轻摆。
- 屏幕边缘自动折返，停顿后换向；拖动、暂停和系统睡眠时停止移动。
- 随机生活循环：走动 20–38 秒 → 稍停 → 缓升 → 随机视角悬浮 20–34 秒 → 缓降 → 继续走动，期间随机致意或闭目片刻。
- 白色卡通头像状态栏入口，支持置顶、鼠标穿透、暂停、恢复位置和退出。
- 可调人物大小、悬浮周期、幅度和眨眼间隔；设置保存在 macOS UserDefaults。

## 使用

1. 将构建得到的 `若娜瓦.app` 拖入“应用程序”，双击打开。
2. 点击菜单栏白色头像，或右键人物打开菜单。
3. 勾选「随机生活 · 走动 / 悬浮 / 小动作」开启自动循环。
4. 拖动人物移动位置，滚轮缩放，双击轻轻致意。
5. 鼠标穿透开启后，通过状态栏菜单「恢复鼠标并移回屏幕」恢复操作。

手动选择视角或动作会退出随机循环；「暂停动作」保留自动模式，恢复后继续。新安装可从菜单开启随机生活，既有安装保留用户设置。

## 本地构建

需要 macOS 14 或更高版本，以及 Xcode Command Line Tools（包含 Swift、macOS SDK 和 `xcrun`）。

```sh
xcode-select --install  # 仅在未安装开发工具时执行
./build.sh
open 'dist/若娜瓦.app'
```

构建当前 Mac 的原生架构，不是 Universal Binary。本项目目前在 Apple Silicon Mac 上验证；Intel、Windows 和 Linux 未做运行验证。Windows 需要移植窗口和渲染代码，不能直接运行本项目的 `.app`。

```sh
./scripts/package.sh  # 构建并生成 DMG
./scripts/verify.sh   # GUI 会话中执行运行检查
```

输出均在 `dist/`，不会提交 Git。应用采用本机 ad-hoc 签名，未经过 Developer ID 签名或 Apple 公证，其他 Mac 上可能出现系统安全提示。

## 项目结构

```text
Sources/main.swift       原生窗口、动画、状态栏菜单与随机调度
Assets/                  全身图、眼部采样素材、走路姿态和图标
build.sh                 编译并签名 macOS App
scripts/package.sh       创建 DMG 安装包
scripts/verify.sh        执行内置运行检查
.github/workflows/       macOS 构建工作流
docs/                   架构、素材说明、上传步骤和版本摘要
```

## 效果与素材说明

动画基于二维图片网格变形，不是三维骨骼或真实物理模拟；五个视角为离散切换，走路为简化的小步动画。素材主要为 1024×1536 位图，过度放大不会增加细节。

角色素材依据参考图经图像生成及编辑制作，侧面细节含推演。角色及原始参考素材的权利归其权利人。本仓库没有为源码或美术素材指定开放许可证；公开仓库不等于授予素材再分发或商用授权，详见 [素材说明](docs/ASSETS.md)。

[架构与验证](docs/ARCHITECTURE.md) · [版本摘要](CHANGELOG.md) · [上传 GitHub](docs/GITHUB.md)
