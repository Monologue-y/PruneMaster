# 开发计划（M0 ~ M6）

> 每个里程碑结束必须通过对应的**测试关卡**才能进入下一阶段。测试命令见 README。

## 已确认决策

- 引擎 Godot 4.7 + GDScript；竖屏 720×1280，`canvas_items` 拉伸；`gl_compatibility` 渲染（低端机友好）。
- Android 优先；iOS 仅预留（无 Mac，最终打包走云 Mac / CI / 代工，见 M5 文档）。
- 目标：可玩 Demo（约 20 关），无变现、无 SDK。
- 美术与音频：最终交付版均由项目脚本程序化生成，保证风格统一与零版权依赖。
- 没有失败性倒计时或步数限制；记录每关用时并给出 S/A/B/C 评级；3 命；图结构以父→子定义，节点位置与树结构解耦。

## M0 · 环境与骨架 ✅

- [x] `F:\PuzzleGame` 目录骨架（game/docs/art_src/builds/tools）
- [x] Godot 4.7.2 便携版（tools/godot）
- [x] MinGit 便携版（C:\Users\Administrator\tools\mingit）+ git 仓库初始化
- [x] 文档：design.md / plan.md / level_format.md / README
- [x] Godot 工程初始化（project.godot / 目录规范 / GameState 单例）

**测试关卡 M0**：`git status` 干净可提交；Godot 能打开工程且无解析错误；`--import` 退出码 0。

## M1 · 核心玩法灰盒（3~5 天）

- [x] `GraphModel`：DAG 模型、可剪判定、剪枝、信号
- [x] `LevelData` / `LevelValidator`：JSON 解析 + 校验（无环/间距/边界/引用）
- [x] `LevelRunner`：生命、点错扣血、胜负流程
- [x] `NodeView` / `LinkView` / `BoardView`：灰盒渲染、点击、动画（颤抖/回缩）
- [x] `Hud`：生命心、剩余节点、重开按钮、胜负浮层
- [x] 3 个测试关卡（level_001~003.json）
- [x] `tests/test_runner.gd` headless 测试套件

**测试关卡 M1**（必须全绿）：
1. 图模型：可剪判定、剪枝状态流转、`all_pruned` 信号
2. 定理验证：随机 DAG ×10，任意合法顺序必然清空、每步必有可剪节点
3. 校验器：环 / 悬空引用 / 重复 id / 重复子引用 / 间距 / 越界 / lives 非法 全部被捕获
4. 流程：乱点 3 次失败；合法顺序通关；失败后输入被封锁
5. 关卡文件：全部 JSON 解析 + 校验通过 + 贪心剪枝可清空
6. 冒烟：主场景 headless 跑 60 帧无脚本错误

## M2 · 关卡系统与编辑器 ✅

- [x] 首页（标题 + 动态小树图标 + 开始游戏按钮）→ 选关界面（网格 + 返回首页）
- [x] 20 关数据：L1 手工教学关 + L2~L20 生成器产出（`game/tools/level_generator.gd`，难度曲线参数化：树数/节点数/共享概率/行距）
- [x] 新手引导（第 1 关脉冲提示环 + 顶部提示文案，5 次成功剪枝或首次失误后关闭）
- [x] HUD 增加返回菜单 + 提示条
- [x] **关卡编辑器**：`game/scenes/tools/level_editor.tscn`（PLACE/LINK/MOVE/DELETE 模式，跨树连线自动生成共享节点，实时校验，0 错误才允许保存）；核心逻辑独立为 `LevelEditorCore`（可 headless 测试）
- [x] 修复：JSON 数字解析为 float 导致的类型不一致（`LevelData.from_dict` 统一规范化 children/trees 为 int）

**测试关卡 M2（全部通过）**：145 checks green——20 关全部通过校验器 + 可清空模拟；编辑器核心（增/连/共享/删除/环防护/并集上限/导出校验/存取 roundtrip）；菜单/游戏（1/2/20 关）/编辑器场景冒烟无脚本错误。

## M3 · 美术与音效 ✅

- [x] 程序化树枝 `BranchView`：贝塞尔弯曲（id 哈希确定性）+ 树皮纹理 Polygon2D 渐窄（最终 17→4.5px）+ 两端缩进 + 回缩动画；无纹理时纯色兜底
- [x] AI 背景：Pollinations.ai 免费生图（bg_forest_01）+ 程序化雾林兜底（bg_forest_02，限流自动降级）；后处理裁水印/压暗/晕影（`tools/fetch_ai_backgrounds.ps1`）
- [x] 程序化 sprite：五色芽苞/树皮平铺/落叶/木屑（`tools/make_sprites.ps1`，System.Drawing 合成）
- [x] 程序化音效：snip/error/win/lose/click + 8s 无缝循环风声 BGM（`tools/make_sfx.ps1` WAV 合成，零版权风险）
- [x] `AudioManager` autoload：SFX 池（每类 4 实例）+ BGM 循环
- [x] 中文字体 Noto Sans SC（`gui/theme/custom_font`），全部 UI 文案中文（标题/提示/HUD/结算/编辑器）
- [x] 粒子迸发（木屑+落叶 CPUParticles2D）、点错屏幕微震、按钮音
- [x] `tools/process_art.ps1`（中心裁剪/缩放/压暗/晕影）+ `art_src/prompts.md`（已用提示词存档 + 商业工具备用提示词）
- [x] 调试截图（`--shot=PATH`），视觉验证菜单/L1/L2/L20 渲染正确

**测试关卡 M3（全部通过）**：里程碑当时 181 checks green（+36 项资产存在/可导入检查）；最终回归为 192 checks green。场景冒烟无脚本错误，截图人工视觉验收通过。

## M4 · Android 打包（1~2 天）

- [x] JDK 17（TUNA 镜像 Temurin 17.0.20.1）+ Android SDK（cmdline-tools/platform-tools/android-34/build-tools 34.0.0，腾讯镜像）+ 导出模板 4.7.2 + debug keystore——全部便携化在 `tools/` 下
- [x] 打包脚本固化：`tools/export_android.ps1`（环境检查 → 导入 → 导出 → apksigner 校验；`-Release` 出正式包），产物 `builds/PruneMaster_release.apk`（v1.0.0，40.4MB，arm64，release 签名通过）+ `builds/PruneMaster_debug.apk`
- [ ] APK 安装真机；触控/安全区/返回键/帧率验收（等待用户手机开启 USB 调试或手动安装）

**测试关卡 M4**：真机完整通关 20 关无崩溃；触控无死区；刘海屏安全区正确。（当前已完成：APK 构建 + apksigner 签名校验；真机项待设备接入）

## 视觉迭代（贯穿 M3~M6，已落地）

- [x] 节点统一绿色（取消按树分色），重绘为真实感叶簇 sprite（`foliage_green.png`，径向 18 叶 + 枝梗）
- [x] 背景统一固定亮色（`bg_bright.png` 暖纸→浅薄荷渐变 + 柔光斑），菜单/游戏一致；UI 文字改深色保证对比
- [x] 关卡布局随机化（最终版）：全部难度采用蜂窝点阵随机旋转 ±10° 散布 + 随机连边，位置与树结构完全解耦（早期迭代曾用有机生长算法，因简单关树形过于规律被全随机方案取代）
- [x] 修复树枝发灰：System.Drawing Bitmap 初始 alpha=0 残留导致纹理半透明（生成时 Clear 不透明底）+ Polygon2D UV 改像素空间（u=弧长 px, v=0..64）
- [x] 枝条方向可读性：父端 17px → 子端 4.5px 强渐窄尖尾（宽端=父、尖端=子），共享节点入边方向一眼可辨
- [x] 视角系统：Camera2D 双指捏合缩放（0.6×~3.2×，手动多点触控追踪）+ 拖拽平移 + 边界钳制；节点改松手判定防拖拽误剪
- [x] 节点去矩形：foliage 精灵移除烘焙枝梗，纯叶簇图标
- [x] 密集关卡连接可读性：枝条深色描边（交叉轮廓分离）+ **长按检查模式**（长按节点 ≥0.3s 高亮其真实连接的枝条/相邻节点、压暗其余；高亮常驻——轻点任意处退出、高亮期轻点不剪枝、平移/捏合不打断、长按他节点可切换）；相机输入改 `_input`（修复节点消费事件导致的密集棋盘平移/捏合失灵）

## M5 · iOS 预留 ✅

- [x] 平台无关性审查（零平台专用 API：无 Android 权限/分支调用；gl_compatibility + canvas_items + etc2/astc 双压缩 + 纯触控输入，iOS 迁移零代码改动）
- [x] App Store 图标/启动图槽位（图标源 `icon.svg`，1024×1024 PNG 导出与启动屏配置流程已文档化）
- [x] `docs/ios_packaging.md`：云 Mac / GitHub Actions macOS / 代工三路线对比 + 出包步骤清单

## M6 · 打磨与验收

- [x] 新手引导完善（第 1 关保留精炼规则文案，不直接标记可剪节点）
- [x] 失败/通关演出（胜负浮层、剪枝粒子迸发、点错红闪+屏幕微震、枝条回缩动画，M3 已落地）
- [x] 关卡计时与评级结果页（HUD 实时 `MM:SS`；胜负后冻结；按节点规模计算 S/A/B/C 阈值；通关页显示评级、用时、S 级目标、下一关/重试/返回选关；失败页显示本次用时）
- [x] 难度调参（4 关周期**从第 1 关起算**：L1 简/教学 → L2 中 → L3 中 → L4 难 → … → L20 难压轴；L1 手工调校为 19 节点，后续简单 26 / 中等 52 / 困难 100；**全难度位置随机散布**，简单关不再保留树形规律）
- [x] 20 关场景级回归脚本固化（`tools/regress_levels.ps1`，逐关真实场景 headless 运行捕获脚本错误；20/20 CLEAN）
- [x] 全关卡直接开放（选关无锁定）+ HUD 底栏上一关/下一关随时切换 + 菜单/重试
- [x] 界面缩放适配：进关自动取景（节点包围盒含叶簇半径，完整适配到 HUD 之间的可用区域，只缩不放，首屏即见全局不被按钮遮挡）；HUD 全部锚定化（expand 模式下贴住真实屏幕边缘，兼容 20:9 等长屏）
- [x] 移除可剪节点标记（脉冲环），第 1 关仅保留精炼规则文案
- [x] 交付：可运行源码 + 公开技术文档 + Android 构建产物

**最终自动化验收**：192 checks green；20/20 关场景级回归 CLEAN。结果页已在 720×1280 与 720×1600 两种比例下截图验收。APK 已完成构建与签名校验，真机完整通关与设备兼容性验收仍需在目标设备上执行。
