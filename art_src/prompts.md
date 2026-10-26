# 美术资源 AI 生成提示词存档（art_src/prompts.md）

> M3 实际使用的管线：**Pollinations.ai（免费、无需密钥）生成背景** + **PowerShell System.Drawing 程序化合成**芽苞/树皮/粒子 + **脚本合成 WAV 音效**。
> 本文档记录已用提示词，并为后续替换为商业生图工具（即梦 / Midjourney / DALL·E）预备提示词。

## 一、已实际使用（M3）

### 背景 bg_forest_01（AI 生成 · 已入库 `game/assets/art/backgrounds/`）

```
painterly 2D mobile game background, misty green forest grove, soft morning light
rays through canopy, layered foliage depth, muted desaturated green and teal tones,
vertical portrait composition, empty center area, no characters, no text,
subtle dark vignette
```

- 接口：`https://image.pollinations.ai/prompt/<urlencoded>?width=720&height=1280&nologo=true&seed=101`
- 后处理（`tools/fetch_ai_backgrounds.ps1`）：裁掉底部 6%（去水印）→ 缩放 720×1280 → 全局压暗 70/255 → 椭圆晕影

### 背景 bg_forest_02（程序化兜底 · 已入库）

- 计划提示词：`painterly 2D mobile game background, dense autumn forest with warm amber sunlight filtering through trees, soft bokeh, muted olive and warm brown tones, vertical portrait composition, no characters, no text, dark vignette edges`（seed=102）
- 实际：Pollinations 第二张请求返回 402（限流），自动降级为程序化雾林（渐变 + 四层树影 + 压暗），位于 `make/fetch` 脚本的 `New-ProceduralForest`。**后续可人工用商业工具重生成后覆盖同名文件。**

### 程序化合成（无提示词，代码生成）

| 资源 | 脚本 | 说明 |
|---|---|---|
| `buds/bud_01..05.png` | `tools/make_sprites.ps1` | 五色芽苞（绿/蓝/赭/紫/金），对应 5 棵树；渐变主体+描边+高光+芽尖 |
| `bark/bark_tile.png` | 同上 | 128×64 树皮平铺（sin 波纹周期 128 → 沿枝条方向无缝） |
| `particles/leaf_01.png`、`chip_01.png` | 同上 | 落叶 / 木屑粒子 |
| `audio/*.wav`（6 个） | `tools/make_sfx.ps1` | 44.1kHz 16bit 合成：snip/error/win/lose/click/bgm_wind |

## 二、备用提示词（若后续用商业工具重生成，产物放 `art_src/` 后用 `tools/process_art.ps1` 入库）

### 芽苞（建议 512×512，纯色或透明背景，工具抠图后缩到 128×128）

```
game asset icon, single leaf bud on a branch tip, glossy stylized 2D mobile game art,
vivid {green|blue|ochre|purple|gold}, strong dark outline, small highlight on top,
plain solid dark green background, centered, no text
```

### 断口/剪切点（可选增强）

```
game asset icon, freshly cut branch cross-section, light wood rings visible,
stylized 2D, warm tan and cream tones, dark outline, plain background, no text
```

### 远景森林背景（720×1280 竖构图）

```
见上文 bg_forest_01 / bg_forest_02 提示词，seed 换新的即可扩充更多变体。
```

### 木牌 UI（M6 打磨可选项）

```
wooden sign board UI element for mobile game, flat 2D cartoon style, warm brown
planks texture with rounded corners, subtle edge highlight, transparent background
```

## 三、使用注意

- Pollinations.ai 免费层会限流（连续请求可能 402），脚本已内置程序化兜底，**任何情况下都会产出可用背景**。
- 生成的 PNG/JPG 一律经过后处理（压暗 + 晕影）以保证前景节点对比度——这是玩法辨识度要求，不是装饰。
- 商业工具产物务必走 `process_art.ps1` 统一尺寸，不要直接把原图丢进 `game/assets/`。
