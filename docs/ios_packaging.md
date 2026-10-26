# iOS 打包预留方案

> 本项目 Android 优先；iOS 因无 Mac 硬件无法本地出包，但**技术选型与工程结构已全量预留**。
> 本文档给出三条可行的 iOS 出包路线与接入清单，需要时按单执行即可。

## 一、平台无关性审查结论（已通过）

| 审查项 | 结论 |
|---|---|
| 平台专用 API | 无。全工程仅使用 `OS.get_cmdline_user_args()`（跨平台，调试用），无 `OS.get_name` 分支、无 Android 权限/JNI/插件 |
| 渲染后端 | `gl_compatibility`（OpenGL ES 3.0），iOS 15+ 全机型支持 |
| 分辨率适配 | 720×1280 竖屏 + `canvas_items` 拉伸 + `expand`，刘海屏由安全区适配（HUD 已按锚点布局） |
| 纹理压缩 | `import_etc2_astc=true`：ASTC（iOS 原生）+ ETC2（Android）双格式导入 |
| 输入 | 触控事件走 `InputEventScreenTouch/Drag` + 手动双指捏合追踪，无鼠标依赖（鼠标路径仅 PC 调试用） |
| 音频 | WAV 合成音效/BGM，iOS 原生支持 |
| 字体 | Noto Sans SC OTF 内置打包，无系统字体依赖 |

**结论：iOS 迁移零代码改动，仅需导出工程与签名配置。**

## 二、三条出包路线对比

| 路线 | 成本 | 周期 | 适用 |
|---|---|---|---|
| **A. 云 Mac 租用**（MacinCloud / MacStadium） | ¥10~30/小时，按天约 ¥100+ | 1 天内 | 一次性出包、快速验证，**推荐首选** |
| **B. GitHub Actions macOS Runner** | 公开仓库免费；私有仓库约 $0.08/分钟 | 配置 0.5~1 天 | 需要持续集成、反复出包 |
| **C. 代工/淘宝代打包** | ¥50~300/次 | 1~3 天 | 无 Apple 开发者账号时的兜底 |

通用前置条件：
- Apple 开发者账号（个人 $99/年；仅本地调试可用免费账号，7 天签名有效期）
- Godot 4.7.2 导出模板（已内置在 `tools/export_templates/4.7.2.stable/`，含 iOS 模板）

## 三、出包步骤清单（路线 A 为例）

1. 云 Mac 安装 Xcode + Godot 4.7.2，拷贝本工程 `game/` 与导出模板
2. Godot 编辑器 → 项目 → 导出 → 添加 **iOS 预设**：
   - Bundle ID：`com.prunemaster.demo`（待定）
   - 图标槽位：将 `game/icon.svg` 导出为 1024×1024 PNG 填入 App Store Icon；启动图使用 Godot 默认启动屏配置（可填纯色 + 居中 Logo）
   - 签名：Xcode 自动管理签名（Personal Team 或开发者证书）
3. 导出 Xcode 工程 → Xcode 内 `Product → Archive` → 真机运行 / TestFlight 分发
4. 验收项：触控（单指点剪、双指缩放拖拽）、安全区、返回手势、帧率（100 节点困难关 ≥ 30fps）

## 四、风险与备注

- **性能**：困难关 100 节点 + ~150 枝条的 Polygon2D 绘制在 gl_compatibility 下负载很低，A12 及以上机型无压力；如需兜底可在 iOS 预设中限制旧机型。
- **合规**：Demo 无网络请求、无 SDK、无隐私采集，App Store 审核风险项为空。
- **图标资产**：当前仅有 `icon.svg` 占位；正式提审前需补 1024×1024 PNG 图标（设计稿可复用叶簇视觉）。
