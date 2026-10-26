# 剪枝 · Prune Master

一款使用 Godot 4.7.2 和 GDScript 制作的休闲益智游戏。玩家扮演园艺师，按照节点之间的关联关系，把一屏树木逐步修剪干净。

- 20 个可玩关卡
- 每关实时计时
- 通关后按用时给出 S/A/B/C 评级
- 192 项自动化检查
- Android 优先，保留 iOS 打包方案

## 下载源码

在 GitHub 仓库页面选择 **Code > Download ZIP**，或者运行：

```bash
git clone https://github.com/Monologue-y/PruneMaster.git
```

## 运行项目

1. 安装 [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/)。
2. 使用 Godot 导入 `game/project.godot`。
3. 在编辑器中运行项目。

也可以通过命令行启动：

```powershell
godot --path .\game
```

运行自动化测试：

```powershell
godot --headless --path .\game --script res://tests/test_runner.gd
```

## 目录结构

```text
art_src/  美术源文件与生成提示词
docs/     游戏设计、开发计划、关卡格式、测试和平台说明
game/     Godot 工程源码、资源和关卡数据
tools/    项目辅助脚本
```

主要文档：

- `docs/design.md`：玩法与界面设计
- `docs/plan.md`：开发计划
- `docs/level_format.md`：关卡数据格式
- `docs/ios_packaging.md`：iOS 打包与体验说明

## 构建说明

APK、Godot 编辑器、JDK、Android SDK、导出模板和签名文件属于构建产物或本地依赖，不包含在源码仓库中。Android 导出前请在 Godot 中安装导出模板，并配置自己的 SDK 和签名信息。
