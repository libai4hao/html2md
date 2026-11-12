# html2md

把指定路径下的所有 HTML 文件批量转换为标准语法（GFM）的 Markdown，输出树与源目录镜像。

## 特性

- 基于 pandoc（本机 3.8），`-f html -t gfm`，无自研 HTML 解析。
- 输出统一到新目录（默认 `md_output/`），相对路径保留，同名文件不互相覆盖。
- 默认跳过 `node_modules` / `build` / `dist` / `.pubcache` / `_probe` / `.dsh-diag` / `.git` 等构建与缓存目录。
- 支持目录、单文件、通配符三种输入。

## 依赖

- [pandoc](https://pandoc.org/)（加入 PATH）
- PowerShell 5.1+（Windows 自带）

## 用法

```powershell
.\html2md.ps1                              # 当前目录下所有干净 html → md_output/
.\html2md.ps1 -Source "ffmpeg-*\doc"       # 指定目录 / 通配符
.\html2md.ps1 -Source "TradeSpar\*.html" -OutDir "out"
.\html2md.ps1 -IncludeBuildArtifacts       # 连构建产物一起转
```

### 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-Source` | `.` | 源路径：目录、单文件或通配符 |
| `-OutDir` | `md_output` | 输出根目录（相对当前工作目录） |
| `-IncludeBuildArtifacts` | 关闭 | 是否一并转换构建/缓存目录下的 html |

## 已知限制

- pandoc 无法 100% 剥离源 HTML 里的 `<div>`/`<span>` 等包装标签，转换结果可能零星残留这些标签，不影响 Markdown 解析器渲染正文。
- 对 SPA 壳（如 `<div id="app">` + 脚本）转出的 md 几乎为空，属预期行为。

## 目录结构

```
html2md/
├── html2md.ps1   # 转换脚本
└── docs/         # 设计文档
```
