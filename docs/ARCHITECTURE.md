# 架构与验证

## 运行结构

- `Settings`：持久化视角、大小、周期、幅度、眨眼、置顶、穿透、暂停、走动及自动模式。设置域为 `local.sv.ronova.imagepet`。
- `PetScene`：SpriteKit 28×42 网格、局部眼区着色器、随机眨眼。30fps，关闭额外网格细分。
- `PetView`：拖动、滚轮、双击和右键菜单。
- `Controller`：透明无边框窗口、状态栏、设置面板、屏幕边界及自动行为。

走路使用 `WalkingRig` 和独立的身体/单腿素材：身体不含腿部，单腿图层分别驱动近腿与远腿，后腿适当压暗。62% 支撑期与38% 摆动期相差半周期，髋膝踝解算控制屈膝，脚部保持刚性平移；实际水平位移决定步态相位。悬浮基础位移和旋转在走路时禁用。肩髋局部扭动，衣发按步频轻微滞后。窗口低速移动累积小数位移，避免系统位置取整造成原地踏步。

自动行为状态为 `walk → settle → rise → hover → land`。状态计时与渲染暂停一致，睡眠和拖动不累积自动行为时间。起浮最多32点且受屏幕可用区域限制。视角采用打乱列表，避免长期只用同一视角；切换不混合两张全身图片。

## 验证

执行 `scripts/verify.sh` 需要可用的 macOS GUI 会话，会暂时显示测试窗口；`--qa` 禁止写入用户设置。内置检查覆盖：

- 透明窗口、置顶、鼠标穿透和恢复。
- 眨眼间隔、暂停冻结时钟。
- 走动保持在屏内、边缘折返、拖动和暂停停止移动。
- 模拟随机循环并遍历全部五阶段、暂停和拖动冻结调度。
- 状态栏图标加载、显示尺寸及菜单事件绑定。

运行截图、JSON 和8秒动画导出位于 `.build/verification/`，不提交 Git。应人工检查全身比例、脚部方向、眼睛对齐和循环视觉效果；布尔检查不等于美术质量验证。

GitHub Actions 仅编译、验证签名并上传构建产物，不替代桌面 GUI 实测。当前版本已在开发用 Apple Silicon Mac 上运行验证；未作跨设备性能保证。

## 应用图标

`Icon/Ronova.icon` 是可编辑的 Icon Composer 分层文档，保留人物原色并使用暗酒红渐变背景；前景关闭玻璃折射，避免脸部变形。`scripts/compile-icon.sh` 调用 Xcode 的 actool 生成 `Assets.car` 和旧版系统使用的 ICNS。Info.plist 同时设置 CFBundleIconName 和 CFBundleIconFile。

`Assets/Compiled` 保存验证过的编译结果，方便只有 Command Line Tools 的 Mac 构建。缓存校验源文件 SHA-256，源文件变化时必须用完整 Xcode 重新生成，防止构建出旧图标。GitHub Actions 使用 macOS 26 环境编译。
