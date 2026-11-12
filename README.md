# html2md

> 把一堆 HTML 一次性批量转成标准 GFM Markdown 的小工具。
> 一条命令，并行转换，输出到独立目录，不碰原文件。

## 快速开始

```powershell
# 进入项目目录，然后：
.\html2md.ps1                          # 转换当前目录下所有 html → md_output/
```

就这么简单。想指定位置或调参数，看下面的例子。

### 常用例子

```powershell
# 转某个目录（或通配符）
.\html2md.ps1 "D:\docs\*.html"
.\html2md.ps1 "ffmpeg-*\doc"

# 换输出目录、限制并行度
.\html2md.ps1 -OutDir "out" -Throttle 4

# 只转有变化的文件（再次运行很快）
.\html2md.ps1 -Incremental
```

### 参数速查

| 参数 | 默认 | 作用 |
|------|------|------|
| `Source`（位置参数） | `.` | 要转换的目录 / 通配符 / 单文件 |
| `-OutDir` | `md_output` | 输出根目录 |
| `-Throttle` | `0`=自动 | 并行度（0 表示用满 CPU 逻辑核） |
| `-Incremental` | 关 | 跳过「已存在且源未变」的 md |
| `-Quiet` | 关 | 不逐条打印成功文件 |
| `-IncludeBuildArtifacts` | 关 | 连 node_modules / build / dist 等也一起转 |

## 环境要求

- **Windows**（脚本用 PowerShell）
- **pandoc**（加入 PATH）。没装的话：
  ```powershell
  winget install JohnMacFarlane.Pandoc
  ```

## 行为说明

- **输出树镜像源目录**：`源路径/xxx/foo.html → md_output/xxx/foo.md`，同名文件不冲突。
- **默认跳过**构建与缓存目录：`node_modules`、`build`、`dist`、`.pubcache`、`_probe`、`.dsh-diag`、`.git`、`.venv`。需要一起转加 `-IncludeBuildArtifacts`。
- **不修改任何源文件**，转换结果只写进输出目录。
- 转换失败时脚本返回退出码 1，便于脚本化调用。

## 已知限制

- pandoc 无法 100% 剥离源 HTML 里的 `<div>`/`<span>` 包装标签，结果可能零星残留，但不影响 Markdown 解析器正常渲染正文。
- 前端 SPA 壳（`<div id="app">` + JS）转出的 md 几乎为空，属预期。

## 目录结构

```
html2md/
├── html2md.ps1     # 转换脚本（唯一要跑的）
├── README.md       # 本文档
└── docs/design.md  # 设计文档（背景与决策）
```

## 帮助

```powershell
Get-Help .\html2md.ps1 -Full
```
